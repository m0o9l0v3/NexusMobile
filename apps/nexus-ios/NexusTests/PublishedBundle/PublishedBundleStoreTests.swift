import XCTest
@testable import Nexus

final class PublishedBundleStoreTests: XCTestCase {
    private var directory: URL!
    /// ISO 8601 で秒まで保存するため、試験の時刻は秒単位にする。
    private let fixedNow = Date(timeIntervalSince1970: 1_793_000_000)

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PublishedBundleStoreTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func makeStore() -> PublishedBundleStore {
        let now = fixedNow
        return PublishedBundleStore(directory: directory, now: { now })
    }

    private func accept(_ store: PublishedBundleStore, version: Int64) async throws -> PublishedBundleAcceptOutcome {
        let response = BundleFixtures.response(BundleFixtures.bundleObject(version: version))
        return try await store.accept(body: response.body, headers: response.headers)
    }

    private func entries() throws -> Set<String> {
        Set(try FileManager.default.contentsOfDirectory(atPath: directory.path))
    }

    // MARK: - 初回・再訪

    func testEmptyStoreHasNoCurrentBundle() async throws {
        let current = try await makeStore().loadCurrent()
        XCTAssertNil(current)
    }

    func testFirstBundleIsStoredWithMetadata() async throws {
        let store = makeStore()
        guard case .stored(let stored) = try await accept(store, version: 42) else {
            return XCTFail("保存されなかった")
        }

        XCTAssertEqual(stored.metadata.bundleVersion, 42)
        XCTAssertEqual(stored.metadata.publishedAt, "2026-11-01T09:00:00Z")
        XCTAssertEqual(stored.metadata.storedAt, fixedNow)
        // ETag は解釈せず、接尾辞も含めてそのまま保存する（§6 規則9）。
        XCTAssertEqual(stored.metadata.etag, "\"sha256-fixture-gzip\"")
    }

    /// アプリを再起動しても、保存済みの版を読み込める（オフライン起動）。
    func testStoredBundleSurvivesRelaunch() async throws {
        _ = try await accept(makeStore(), version: 42)

        let reloaded = try await makeStore().loadCurrent()
        XCTAssertEqual(reloaded?.metadata.bundleVersion, 42)
        XCTAssertEqual(reloaded?.bundle.spots.count, 3)
    }

    // MARK: - 版の更新

    func testNewerBundleBecomesCurrentAndPreviousIsKept() async throws {
        let store = makeStore()
        _ = try await accept(store, version: 42)
        _ = try await accept(store, version: 45)

        let current = try await store.loadCurrent()
        XCTAssertEqual(current?.metadata.bundleVersion, 45)
        // 旧版を1世代だけ残す。
        XCTAssertEqual(try entries(), ["pointer.json", "v45", "v42"])
    }

    func testOnlyOnePreviousGenerationIsKept() async throws {
        let store = makeStore()
        for version: Int64 in [42, 45, 50] {
            _ = try await accept(store, version: version)
        }
        XCTAssertEqual(try entries(), ["pointer.json", "v50", "v45"])
    }

    func testSameVersionAndContentIsUnchanged() async throws {
        let store = makeStore()
        _ = try await accept(store, version: 42)

        guard case .unchanged(let current) = try await accept(store, version: 42) else {
            return XCTFail("同じ版で変化なしにならなかった")
        }
        XCTAssertEqual(current.metadata.bundleVersion, 42)
    }

    /// 版を戻さない（§6 規則4）。Studio の復旧は大きい版として届く。
    func testOlderBundleIsRejectedAndCurrentIsKept() async throws {
        let store = makeStore()
        _ = try await accept(store, version: 45)

        do {
            _ = try await accept(store, version: 42)
            XCTFail("古い版を受け入れた")
        } catch {
            XCTAssertEqual(error as? ParticipantBundleError, .olderThanStored(received: 42, stored: 45))
        }
        let current = try await store.loadCurrent()
        XCTAssertEqual(current?.metadata.bundleVersion, 45)
    }

    func testSameVersionWithDifferentContentIsRejected() async throws {
        let store = makeStore()
        _ = try await accept(store, version: 42)

        var object = BundleFixtures.bundleObject(version: 42)
        object["spots"] = [BundleFixtures.spot(id: "mb", name: "教室棟（別の中身）", placement: BundleFixtures.placement(featureType: "building", buildingID: "mb"))]
        let response = BundleFixtures.response(object)

        do {
            _ = try await store.accept(body: response.body, headers: response.headers)
            XCTFail("同じ版で別の中身を受け入れた")
        } catch {
            XCTAssertEqual(error as? ParticipantBundleError, .conflictingContentForVersion(42))
        }
    }

    /// 検証に失敗した bundle は保存せず、保存済みの版を使い続ける。
    func testInvalidBundleDoesNotReplaceCurrent() async throws {
        let store = makeStore()
        _ = try await accept(store, version: 42)

        let response = BundleFixtures.response(BundleFixtures.bundleObject(version: 43))
        let corrupted = ParticipantBundleHeaders(
            sha256: String(repeating: "0", count: 64),
            byteLength: response.headers.byteLength,
            bundleVersion: 43,
            schemaVersion: "2.0.0",
            etag: nil
        )
        do {
            _ = try await store.accept(body: response.body, headers: corrupted)
            XCTFail("照合に失敗した bundle を受け入れた")
        } catch {
            XCTAssertEqual(error as? ParticipantBundleError, .checksumMismatch)
        }
        let current = try await store.loadCurrent()
        XCTAssertEqual(current?.metadata.bundleVersion, 42)
        XCTAssertEqual(try entries(), ["pointer.json", "v42"])
    }

    // MARK: - 異常終了・破損

    /// 書き込みの途中で終了して残った一時ディレクトリは、次回の読み込みで削除する。
    func testLeftoverTemporaryDirectoryIsRemovedOnLoad() async throws {
        _ = try await accept(makeStore(), version: 42)
        let leftover = directory.appendingPathComponent("tmp-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: leftover, withIntermediateDirectories: true)
        try Data("partial".utf8).write(to: leftover.appendingPathComponent("bundle.json"))

        let current = try await makeStore().loadCurrent()
        XCTAssertEqual(current?.metadata.bundleVersion, 42)
        XCTAssertEqual(try entries(), ["pointer.json", "v42"])
    }

    /// 現在の版の本体が壊れていたら、検証できる旧版へ戻す。
    func testCorruptedCurrentFallsBackToPrevious() async throws {
        let store = makeStore()
        _ = try await accept(store, version: 42)
        _ = try await accept(store, version: 45)
        try Data("broken".utf8).write(to: directory.appendingPathComponent("v45/bundle.json"))

        let current = try await makeStore().loadCurrent()
        XCTAssertEqual(current?.metadata.bundleVersion, 42)
        XCTAssertEqual(try entries(), ["pointer.json", "v42"])
    }

    func testCorruptedOnlyGenerationLeavesStoreEmpty() async throws {
        _ = try await accept(makeStore(), version: 42)
        try Data("broken".utf8).write(to: directory.appendingPathComponent("v42/meta.json"))

        let current = try await makeStore().loadCurrent()
        XCTAssertNil(current)
        XCTAssertEqual(try entries(), ["pointer.json"])
    }

    /// 旧版へ戻った後も、版は戻さない規則のもとで新しい版を受け入れられる。
    func testStoreAcceptsNewerBundleAfterFallback() async throws {
        let store = makeStore()
        _ = try await accept(store, version: 42)
        _ = try await accept(store, version: 45)
        try Data("broken".utf8).write(to: directory.appendingPathComponent("v45/bundle.json"))

        let recovered = makeStore()
        _ = try await recovered.loadCurrent()
        guard case .stored(let stored) = try await accept(recovered, version: 46) else {
            return XCTFail("新しい版を保存できなかった")
        }
        XCTAssertEqual(stored.metadata.bundleVersion, 46)
        XCTAssertEqual(try entries(), ["pointer.json", "v46", "v42"])
    }

    // MARK: - レビュー対応（PR #110）

    /// 壊れた版から旧版へ戻っても、最高受信版より古い版は受け入れない（§6 規則4）。
    func testFallbackKeepsHighestAcceptedVersion() async throws {
        let store = makeStore()
        _ = try await accept(store, version: 42)
        _ = try await accept(store, version: 45)
        try Data("broken".utf8).write(to: directory.appendingPathComponent("v45/bundle.json"))

        let recovered = makeStore()
        let current = try await recovered.loadCurrent()
        XCTAssertEqual(current?.metadata.bundleVersion, 42)

        do {
            _ = try await accept(recovered, version: 43)
            XCTFail("最高受信版より古い版を受け入れた")
        } catch {
            XCTAssertEqual(error as? ParticipantBundleError, .olderThanStored(received: 43, stored: 45))
        }
    }

    /// 壊れて失った最高受信版は、同じ中身なら受け直して復旧できる。
    func testLostHighestVersionCanBeReceivedAgain() async throws {
        let store = makeStore()
        _ = try await accept(store, version: 42)
        _ = try await accept(store, version: 45)
        try Data("broken".utf8).write(to: directory.appendingPathComponent("v45/bundle.json"))

        let recovered = makeStore()
        _ = try await recovered.loadCurrent()
        guard case .stored(let stored) = try await accept(recovered, version: 45) else {
            return XCTFail("最高受信版を受け直せなかった")
        }
        XCTAssertEqual(stored.metadata.bundleVersion, 45)
        XCTAssertEqual(try entries(), ["pointer.json", "v45", "v42"])
    }

    /// 同じ版でも ETag が変われば保存し直す（edge の圧縮方式の変化で接尾辞が変わる）。
    func testSameVersionWithNewETagUpdatesStoredETag() async throws {
        let store = makeStore()
        _ = try await accept(store, version: 42)

        let response = BundleFixtures.response(BundleFixtures.bundleObject(version: 42), etag: "\"sha256-fixture-zstd\"")
        guard case .unchanged(let refreshed) = try await store.accept(body: response.body, headers: response.headers) else {
            return XCTFail("同じ版で変化なしにならなかった")
        }
        XCTAssertEqual(refreshed.metadata.etag, "\"sha256-fixture-zstd\"")

        let reloaded = try await makeStore().loadCurrent()
        XCTAssertEqual(reloaded?.metadata.etag, "\"sha256-fixture-zstd\"")
        XCTAssertEqual(reloaded?.metadata.bundleVersion, 42)
    }

    /// ポインタだけが壊れても、保存済みの世代は消さずに組み立て直す。
    func testCorruptedPointerIsRebuiltWithoutDeletingGenerations() async throws {
        let store = makeStore()
        _ = try await accept(store, version: 42)
        _ = try await accept(store, version: 45)
        try Data("{broken".utf8).write(to: directory.appendingPathComponent("pointer.json"))

        let recovered = makeStore()
        let current = try await recovered.loadCurrent()
        XCTAssertEqual(current?.metadata.bundleVersion, 45)
        XCTAssertEqual(try entries(), ["pointer.json", "v45", "v42"])

        // 組み立て直したポインタでも、版は戻さない。
        do {
            _ = try await accept(recovered, version: 44)
            XCTFail("古い版を受け入れた")
        } catch {
            XCTAssertEqual(error as? ParticipantBundleError, .olderThanStored(received: 44, stored: 45))
        }
    }

    /// 付帯情報のうち本体から写した項目が壊れていれば、その世代は壊れている扱いにする。
    func testTamperedMetadataIsTreatedAsCorrupted() async throws {
        let store = makeStore()
        _ = try await accept(store, version: 42)
        _ = try await accept(store, version: 45)

        let metadataURL = directory.appendingPathComponent("v45/meta.json")
        var json = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: Data(contentsOf: metadataURL)) as? [String: Any]
        )
        json["publishedAt"] = "2099-01-01T00:00:00Z"
        try JSONSerialization.data(withJSONObject: json).write(to: metadataURL)

        let current = try await makeStore().loadCurrent()
        XCTAssertEqual(current?.metadata.bundleVersion, 42)
    }

    // MARK: - レビュー対応 2（PR #110）

    /// ポインタの書き込みに失敗しても、メモリ上の状態は元の現在の版・旧版のまま残る。
    /// 再試行が成功したとき、本来の旧版を1世代残せる。
    func testFailedPointerWriteKeepsInMemoryStateConsistent() async throws {
        let store = makeStore()
        _ = try await accept(store, version: 42)

        // pointer.json を空でないディレクトリに差し替え、原子的な書き込み（置き換え）を失敗させる。
        let pointerURL = directory.appendingPathComponent("pointer.json")
        let saved = try Data(contentsOf: pointerURL)
        try FileManager.default.removeItem(at: pointerURL)
        try FileManager.default.createDirectory(at: pointerURL, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: pointerURL.appendingPathComponent("blocker"))

        do {
            _ = try await accept(store, version: 45)
            XCTFail("ポインタを書けないのに成功した")
        } catch {
            XCTAssertNil(error as? ParticipantBundleError)
        }
        let afterFailure = try await store.loadCurrent()
        XCTAssertEqual(afterFailure?.metadata.bundleVersion, 42)

        // 書き込みできる状態に戻して再試行する。
        try FileManager.default.removeItem(at: pointerURL)
        try saved.write(to: pointerURL)
        guard case .stored(let stored) = try await accept(store, version: 45) else {
            return XCTFail("再試行で保存できなかった")
        }
        XCTAssertEqual(stored.metadata.bundleVersion, 45)
        // 旧版は本来の v42（失敗した v45 自身ではない）。
        XCTAssertEqual(try entries(), ["pointer.json", "v45", "v42"])
    }
}
