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
}

struct StoredParticipantBundle: Equatable, Sendable {
    let bundle: ParticipantBundle
    let metadata: StoredBundleMetadata
}

enum PublishedBundleAcceptOutcome: Equatable, Sendable {
    /// 新しい版を保存し、現在の版にした。
    case stored(StoredParticipantBundle)
    /// 保存済みと同じ版・同じ中身だった。
    case unchanged(StoredParticipantBundle)
}

/// 公開データの bundle を端末に保存し、版を原子的に切り替える（E2-5 §6 規則2〜4）。
///
/// 版ごとに `v<bundle_version>/` へ本体と付帯情報を書き、現在の版と1つ前の版を
/// `pointer.json` の1ファイルで指す。ポインタは原子的に書き換えるため、
/// 書き込みの途中で異常終了しても、現在の版と旧版の組が混ざることはない。
/// 参照されていないディレクトリ（書きかけの一時ディレクトリを含む）は次回の読み込みで削除する。
actor PublishedBundleStore {
    private struct Pointer: Codable, Equatable {
        var current: String?
        var previous: String?
    }

    private static let pointerFileName = "pointer.json"
    private static let bundleFileName = "bundle.json"
    private static let metadataFileName = "meta.json"

    private let directory: URL
    private let now: @Sendable () -> Date
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

        var pointer = readPointer()
        var loaded: StoredParticipantBundle?
        if let current = pointer.current, let bundle = readGeneration(named: current) {
            loaded = bundle
        } else if let previous = pointer.previous, let bundle = readGeneration(named: previous) {
            // 現在の版が壊れている・欠けている。検証できる旧版へ戻す。
            loaded = bundle
            pointer = Pointer(current: previous, previous: nil)
            try writePointer(pointer)
        } else if pointer != Pointer() {
            pointer = Pointer()
            try writePointer(pointer)
        }

        removeUnreferencedEntries(keeping: pointer)
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

        if let current {
            let storedVersion = current.metadata.bundleVersion
            if version < storedVersion {
                throw ParticipantBundleError.olderThanStored(received: version, stored: storedVersion)
            }
            if version == storedVersion {
                guard headers.sha256 == current.metadata.sha256 else {
                    throw ParticipantBundleError.conflictingContentForVersion(version)
                }
                return .unchanged(current)
            }
        }

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

        let pointer = Pointer(current: generation, previous: readPointer().current)
        try writePointer(pointer)
        removeUnreferencedEntries(keeping: pointer)

        let stored = StoredParticipantBundle(bundle: bundle, metadata: metadata)
        cachedCurrent = stored
        return .stored(stored)
    }

    // MARK: - Files

    private static func generationName(for version: Int64) -> String {
        "v\(version)"
    }

    private var pointerURL: URL {
        directory.appendingPathComponent(Self.pointerFileName)
    }

    private func readPointer() -> Pointer {
        guard let data = try? Data(contentsOf: pointerURL),
              let pointer = try? JSONDecoder().decode(Pointer.self, from: data)
        else {
            return Pointer()
        }
        return pointer
    }

    private func writePointer(_ pointer: Pointer) throws {
        let data = try JSONEncoder().encode(pointer)
        try data.write(to: pointerURL, options: .atomic)
    }

    /// 1世代を読み、保存時と同じ検証をやり直す。少しでも合わなければ nil（壊れている扱い）。
    private func readGeneration(named name: String) -> StoredParticipantBundle? {
        let folder = directory.appendingPathComponent(name, isDirectory: true)
        guard let body = try? Data(contentsOf: folder.appendingPathComponent(Self.bundleFileName)),
              let metadataData = try? Data(contentsOf: folder.appendingPathComponent(Self.metadataFileName)),
              let metadata = try? Self.metadataDecoder.decode(StoredBundleMetadata.self, from: metadataData)
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
        guard let bundle = try? ParticipantBundleValidator.validate(body: body, headers: headers) else {
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
                // 同じ版の書きかけ（ポインタが指していないもの）が残っている。
                try fileManager.removeItem(at: destination)
            }
            try fileManager.moveItem(at: temporary, to: destination)
        } catch {
            try? fileManager.removeItem(at: temporary)
            throw error
        }
    }

    private func removeUnreferencedEntries(keeping pointer: Pointer) {
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
