import Foundation

/// 保存済み bundle の付帯情報。保存版の表示（E2-5 §6 規則7）と、次回の条件付き GET に使う。
struct StoredBundleMetadata: Codable, Equatable, Sendable {
    let bundleVersion: Int64
    let releaseID: String
    let schemaVersion: String
    let sha256: String
    let byteLength: Int
    let publishedAt: String
    /// 受け取った値を解釈せずに保存し、そのまま `If-None-Match` に送る（§6 規則9）。
    let etag: String?
    let storedAt: Date

    func replacingETag(_ etag: String?) -> StoredBundleMetadata {
        StoredBundleMetadata(
            bundleVersion: bundleVersion,
            releaseID: releaseID,
            schemaVersion: schemaVersion,
            sha256: sha256,
            byteLength: byteLength,
            publishedAt: publishedAt,
            etag: etag,
            storedAt: storedAt
        )
    }
}

struct StoredParticipantBundle: Equatable, Sendable {
    let bundle: ParticipantBundle
    let metadata: StoredBundleMetadata
}

enum PublishedBundleAcceptOutcome: Equatable, Sendable {
    /// 新しい版を保存し、現在の版にした。
    case stored(StoredParticipantBundle)
    /// 保存済みと同じ版・同じ中身だった（ETag だけは最新の値に更新する）。
    case unchanged(StoredParticipantBundle)
}

/// 公開データの bundle を端末に保存し、版を原子的に切り替える（E2-5 §6 規則2〜4）。
///
/// 版ごとに `v<bundle_version>/` へ本体と付帯情報を書き、現在の版・1つ前の版・
/// これまでに受け入れた最高の版を `pointer.json` の1ファイルで持つ。ポインタは原子的に
/// 書き換えるため、書き込みの途中で異常終了しても、現在の版と旧版の組が混ざることはない。
/// 参照されていないディレクトリ（書きかけの一時ディレクトリを含む）は次回の読み込みで削除する。
actor PublishedBundleStore {
    private struct Pointer: Codable, Equatable {
        var current: String?
        var previous: String?
        /// これまでに受け入れた最高の版。壊れた版から旧版へ戻っても下げない（§6 規則4）。
        var highest: AcceptedVersion?
    }

    private struct AcceptedVersion: Codable, Equatable {
        let bundleVersion: Int64
        let sha256: String
    }

    private enum PointerState {
        case missing
        case unreadable
        case valid(Pointer)
    }

    private static let pointerFileName = "pointer.json"
    private static let bundleFileName = "bundle.json"
    private static let metadataFileName = "meta.json"
    private static let generationPrefix = "v"

    private let directory: URL
    private let now: @Sendable () -> Date
    private var pointer = Pointer()
    private var cachedCurrent: StoredParticipantBundle?
    private var hasLoaded = false

    init(directory: URL, now: @escaping @Sendable () -> Date = { Date() }) {
        self.directory = directory
        self.now = now
    }

    /// 現在の版を読み込む。壊れていれば1つ前の版へ戻す。どちらも使えなければ nil。
    func loadCurrent() throws -> StoredParticipantBundle? {
        if hasLoaded {
            return cachedCurrent
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        var loaded: StoredParticipantBundle?
        switch readPointer() {
        case .missing:
            pointer = Pointer()
        case .unreadable:
            // ポインタだけが壊れた。保存済みの世代は消さず、検証できる世代から組み立て直す。
            (pointer, loaded) = rebuildPointerFromGenerations()
            try writePointer(pointer)
        case .valid(let stored):
            pointer = stored
            if let current = pointer.current, let bundle = readGeneration(named: current) {
                loaded = bundle
            } else if let previous = pointer.previous, let bundle = readGeneration(named: previous) {
                // 現在の版が壊れている・欠けている。検証できる旧版へ戻す（最高受信版は保つ）。
                loaded = bundle
                pointer.current = previous
                pointer.previous = nil
                try writePointer(pointer)
            } else if pointer.current != nil || pointer.previous != nil {
                pointer.current = nil
                pointer.previous = nil
                try writePointer(pointer)
            }
        }

        removeUnreferencedEntries()
        cachedCurrent = loaded
        hasLoaded = true
        return loaded
    }

    /// 受信した bundle を検証し、新しい版なら保存して現在の版にする。
    ///
    /// 検証に失敗した場合や古い版の場合は例外を投げ、保存済みの版はそのまま残る。
    func accept(body: Data, headers: ParticipantBundleHeaders) throws -> PublishedBundleAcceptOutcome {
        let bundle = try ParticipantBundleValidator.validate(body: body, headers: headers)
        let current = try loadCurrent()
        let version = bundle.meta.bundleVersion

        if let highest = pointer.highest {
            if version < highest.bundleVersion {
                throw ParticipantBundleError.olderThanStored(received: version, stored: highest.bundleVersion)
            }
            if version == highest.bundleVersion, headers.sha256 != highest.sha256 {
                throw ParticipantBundleError.conflictingContentForVersion(version)
            }
        }

        if let current, current.metadata.bundleVersion == version {
            // 同じ版・同じ中身。edge の圧縮方式が変わると ETag の接尾辞が変わるため、
            // 最新の ETag を保存し直す（古い ETag では 304 にならず毎回全量を取得してしまう）。
            guard current.metadata.etag != headers.etag else {
                return .unchanged(current)
            }
            let refreshed = StoredParticipantBundle(
                bundle: current.bundle,
                metadata: current.metadata.replacingETag(headers.etag)
            )
            try writeMetadata(refreshed.metadata, toGeneration: Self.generationName(for: version))
            cachedCurrent = refreshed
            return .unchanged(refreshed)
        }

        // ここに来るのは、最高受信版より新しい版か、壊れて失った最高受信版の受け直し。
        let metadata = StoredBundleMetadata(
            bundleVersion: version,
            releaseID: bundle.meta.releaseID,
            schemaVersion: bundle.meta.schemaVersion,
            sha256: headers.sha256,
            byteLength: headers.byteLength,
            publishedAt: bundle.meta.publishedAt,
            etag: headers.etag,
            storedAt: now()
        )
        let generation = Self.generationName(for: version)
        try writeGeneration(named: generation, body: body, metadata: metadata)

        let previous = pointer.current
        pointer.current = generation
        pointer.previous = previous
        pointer.highest = AcceptedVersion(bundleVersion: version, sha256: headers.sha256)
        try writePointer(pointer)
        removeUnreferencedEntries()

        let stored = StoredParticipantBundle(bundle: bundle, metadata: metadata)
        cachedCurrent = stored
        return .stored(stored)
    }

    // MARK: - Pointer

    private static func generationName(for version: Int64) -> String {
        "\(generationPrefix)\(version)"
    }

    private var pointerURL: URL {
        directory.appendingPathComponent(Self.pointerFileName)
    }

    /// ポインタが無い（初回）ことと、読めない・壊れていることを区別する。
    private func readPointer() -> PointerState {
        guard FileManager.default.fileExists(atPath: pointerURL.path) else {
            return .missing
        }
        guard let data = try? Data(contentsOf: pointerURL),
              let stored = try? JSONDecoder().decode(Pointer.self, from: data)
        else {
            return .unreadable
        }
        return .valid(stored)
    }

    private func writePointer(_ pointer: Pointer) throws {
        let data = try JSONEncoder().encode(pointer)
        try data.write(to: pointerURL, options: .atomic)
    }

    /// 壊れたポインタの代わりに、検証できる世代を新しい順に2つ選んで組み立て直す。
    private func rebuildPointerFromGenerations() -> (Pointer, StoredParticipantBundle?) {
        let entries = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        let valid = entries
            .filter { $0.hasPrefix(Self.generationPrefix) }
            .compactMap { name in readGeneration(named: name).map { (name, $0) } }
            .sorted { $0.1.metadata.bundleVersion > $1.1.metadata.bundleVersion }

        guard let newest = valid.first else {
            return (Pointer(), nil)
        }
        let rebuilt = Pointer(
            current: newest.0,
            previous: valid.dropFirst().first?.0,
            highest: AcceptedVersion(bundleVersion: newest.1.metadata.bundleVersion, sha256: newest.1.metadata.sha256)
        )
        return (rebuilt, newest.1)
    }

    // MARK: - Generations

    /// 1世代を読み、保存時と同じ検証をやり直す。少しでも合わなければ nil（壊れている扱い）。
    private func readGeneration(named name: String) -> StoredParticipantBundle? {
        let folder = directory.appendingPathComponent(name, isDirectory: true)
        guard let body = try? Data(contentsOf: folder.appendingPathComponent(Self.bundleFileName)),
              let metadataData = try? Data(contentsOf: folder.appendingPathComponent(Self.metadataFileName)),
              let metadata = try? Self.metadataDecoder.decode(StoredBundleMetadata.self, from: metadataData),
              name == Self.generationName(for: metadata.bundleVersion)
        else {
            return nil
        }
        let headers = ParticipantBundleHeaders(
            sha256: metadata.sha256,
            byteLength: metadata.byteLength,
            bundleVersion: metadata.bundleVersion,
            schemaVersion: metadata.schemaVersion,
            etag: metadata.etag
        )
        guard let bundle = try? ParticipantBundleValidator.validate(body: body, headers: headers),
              // 付帯情報のうち本体から写した項目も照合する。壊れていれば偽の公開日時などを返さない。
              bundle.meta.releaseID == metadata.releaseID,
              bundle.meta.publishedAt == metadata.publishedAt,
              bundle.meta.schemaVersion == metadata.schemaVersion
        else {
            return nil
        }
        return StoredParticipantBundle(bundle: bundle, metadata: metadata)
    }

    /// 一時ディレクトリに書き終えてから、版のディレクトリへ移す。
    private func writeGeneration(named name: String, body: Data, metadata: StoredBundleMetadata) throws {
        let fileManager = FileManager.default
        let temporary = directory.appendingPathComponent("tmp-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: temporary, withIntermediateDirectories: true)
        do {
            try body.write(to: temporary.appendingPathComponent(Self.bundleFileName))
            try Self.metadataEncoder.encode(metadata)
                .write(to: temporary.appendingPathComponent(Self.metadataFileName))

            let destination = directory.appendingPathComponent(name, isDirectory: true)
            if fileManager.fileExists(atPath: destination.path) {
                // ポインタが指していない同じ版（書きかけ・壊れたもの）が残っている。
                try fileManager.removeItem(at: destination)
            }
            try fileManager.moveItem(at: temporary, to: destination)
        } catch {
            try? fileManager.removeItem(at: temporary)
            throw error
        }
    }

    /// 現在の世代の付帯情報だけを原子的に書き換える（ETag の更新）。
    private func writeMetadata(_ metadata: StoredBundleMetadata, toGeneration name: String) throws {
        let url = directory
            .appendingPathComponent(name, isDirectory: true)
            .appendingPathComponent(Self.metadataFileName)
        try Self.metadataEncoder.encode(metadata).write(to: url, options: .atomic)
    }

    private func removeUnreferencedEntries() {
        let fileManager = FileManager.default
        let keep = Set([pointer.current, pointer.previous].compactMap { $0 } + [Self.pointerFileName])
        guard let entries = try? fileManager.contentsOfDirectory(atPath: directory.path) else { return }
        for entry in entries where !keep.contains(entry) {
            try? fileManager.removeItem(at: directory.appendingPathComponent(entry))
        }
    }

    private static let metadataEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let metadataDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
