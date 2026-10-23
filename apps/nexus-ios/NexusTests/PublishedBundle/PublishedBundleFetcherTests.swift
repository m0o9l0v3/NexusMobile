import XCTest
@testable import Nexus

/// bundle の取得クライアント（E2-5 §6 規則1・2・8・9・10、#109 の受入条件）。
final class PublishedBundleFetcherTests: XCTestCase {

    private var directory: URL!
    private var store: PublishedBundleStore!
    private var fetcher: PublishedBundleFetcher!
    private let endpoint = URL(string: "https://nexus.test/api/v2/bundle")!

    override func setUp() async throws {
        StubURLProtocol.reset()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("fetcher-tests-\(UUID().uuidString)", isDirectory: true)
        store = PublishedBundleStore(directory: directory)
        fetcher = PublishedBundleFetcher(endpoint: endpoint, store: store, session: StubURLProtocol.makeSession())
    }

    override func tearDown() async throws {
        StubURLProtocol.reset()
        try? FileManager.default.removeItem(at: directory)
    }

    // MARK: - 応答の組み立て

    private func ok(
        _ object: [String: Any] = BundleFixtures.bundleObject(),
        etag: String? = "\"sha256-fixture-gzip\"",
        recheckAfter: String? = "300",
        overriding: [String: String?] = [:],
        chunkSize: Int = 64 * 1024
    ) -> StubURLProtocol.Reply {
        let response = BundleFixtures.response(object, etag: etag)
        var headers: [String: String] = [
            "Content-Type": "application/json; charset=utf-8",
            "Nexus-Bundle-Sha256": response.headers.sha256,
            "Nexus-Bundle-Length": String(response.headers.byteLength),
            "Nexus-Bundle-Version": String(response.headers.bundleVersion),
            "Nexus-Bundle-Schema": response.headers.schemaVersion,
        ]
        if let etag { headers["ETag"] = etag }
        if let recheckAfter { headers["Nexus-Recheck-After"] = recheckAfter }
        for (key, value) in overriding {
            headers[key] = value
        }
        return StubURLProtocol.Reply(status: 200, headers: headers, chunks: Self.chunks(response.body, size: chunkSize))
    }

    private func notModified(version: Int64 = 42, sha256: String, etag: String? = "\"sha256-fixture-gzip\"") -> StubURLProtocol.Reply {
        var headers = ["Nexus-Bundle-Sha256": sha256, "Nexus-Bundle-Version": String(version), "Nexus-Recheck-After": "300"]
        if let etag { headers["ETag"] = etag }
        return StubURLProtocol.Reply(status: 304, headers: headers)
    }

    private static func chunks(_ data: Data, size: Int) -> [Data] {
        stride(from: 0, to: data.count, by: size).map { data.subdata(in: $0..<min($0 + size, data.count)) }
    }

    @discardableResult
    private func storeInitialVersion() async throws -> StoredParticipantBundle {
        StubURLProtocol.enqueue(ok())
        guard case .updated(let stored, _) = await fetcher.check() else {
            throw XCTSkip("初回の取得に失敗した")
        }
        return stored
    }

    private func currentVersion() async throws -> Int64? {
        try await store.loadCurrent()?.metadata.bundleVersion
    }

    // MARK: - 初回・304

    func testFirstFetchStoresBundleAndConfirmsIt() async throws {
        StubURLProtocol.enqueue(ok())

        let outcome = await fetcher.check()

        guard case .updated(let stored, let recheckAfter) = outcome else {
            return XCTFail("保存されなかった: \(outcome)")
        }
        XCTAssertEqual(stored.metadata.bundleVersion, 42)
        XCTAssertEqual(recheckAfter, 300)
        XCTAssertNil(StubURLProtocol.requests.first?.value(forHTTPHeaderField: "If-None-Match"))
        let snapshot = try await fetcher.snapshot()
        XCTAssertEqual(snapshot?.isConfirmedLatest, true)
        XCTAssertNotNil(snapshot?.lastConfirmedAt)
    }

    func testNotModifiedSendsStoredETagAsIsAndConfirms() async throws {
        let stored = try await storeInitialVersion()
        StubURLProtocol.enqueue(notModified(sha256: stored.metadata.sha256))

        let outcome = await fetcher.check()

        guard case .unchanged(let confirmed, _) = outcome else {
            return XCTFail("304 が最新の確認にならなかった: \(outcome)")
        }
        // 接尾辞付きの ETag を取り除かずに送り返す（規則9）。
        XCTAssertEqual(StubURLProtocol.requests.last?.value(forHTTPHeaderField: "If-None-Match"), "\"sha256-fixture-gzip\"")
        XCTAssertEqual(confirmed.metadata.bundleVersion, 42)
        XCTAssertNotNil(confirmed.metadata.lastConfirmedAt)
    }

    func testNotModifiedForDifferentVersionIsNotAConfirmation() async throws {
        try await storeInitialVersion()
        StubURLProtocol.enqueue(notModified(sha256: String(repeating: "b", count: 64)))

        let outcome = await fetcher.check()

        XCTAssertEqual(outcome, .failed(.notModifiedMismatch, retryAfter: nil))
        let snapshot = try await fetcher.snapshot()
        XCTAssertEqual(snapshot?.isConfirmedLatest, false)
        XCTAssertEqual(snapshot?.stored.metadata.bundleVersion, 42)
    }

    func testWeakETagIsSentBackUninterpreted() async throws {
        StubURLProtocol.enqueue(ok(etag: "W/\"anything-at-all\""))
        _ = await fetcher.check()
        let stored = try await store.loadCurrent()
        StubURLProtocol.enqueue(notModified(sha256: stored!.metadata.sha256, etag: nil))

        _ = await fetcher.check()

        XCTAssertEqual(StubURLProtocol.requests.last?.value(forHTTPHeaderField: "If-None-Match"), "W/\"anything-at-all\"")
    }

    // MARK: - 初回の確認への合流

    /// 初回起動で確認が終わる前に画面が読んでも、失敗にせず確認の結果を待つ。
    func testSnapshotJoinsFirstCheckWhenNothingIsStored() async throws {
        StubURLProtocol.enqueue(ok())

        async let launchCheck = fetcher.check()
        async let screenRead = fetcher.snapshot()
        let (outcome, snapshot) = try await (launchCheck, screenRead)

        guard case .updated = outcome else {
            return XCTFail("起動時の確認が保存しなかった: \(outcome)")
        }
        XCTAssertEqual(snapshot?.stored.metadata.bundleVersion, 42)
        XCTAssertEqual(StubURLProtocol.requests.count, 1, "同じ確認に合流し、2回通信しない")
    }

    func testSnapshotTriggersFirstCheckWhenNoneHasRun() async throws {
        StubURLProtocol.enqueue(ok())

        let snapshot = try await fetcher.snapshot()

        XCTAssertEqual(snapshot?.stored.metadata.bundleVersion, 42)
        XCTAssertEqual(StubURLProtocol.requests.count, 1)
    }

    func testSnapshotDoesNotRecheckAfterFailedFirstCheck() async throws {
        StubURLProtocol.enqueue(StubURLProtocol.Reply(status: 503, headers: ["Retry-After": "30"]))
        _ = await fetcher.check()

        let snapshot = try await fetcher.snapshot()

        XCTAssertNil(snapshot)
        XCTAssertEqual(StubURLProtocol.requests.count, 1, "失敗した後の再試行はスケジューラに任せる")
    }

    // MARK: - 失敗しても保存済みの版を使い続ける

    func testCorruptedBodyIsRejectedAndStoredVersionKept() async throws {
        try await storeInitialVersion()
        StubURLProtocol.enqueue(ok(BundleFixtures.bundleObject(version: 43), overriding: ["Nexus-Bundle-Sha256": String(repeating: "c", count: 64)]))

        let outcome = await fetcher.check()

        XCTAssertEqual(outcome, .failed(.rejected(.checksumMismatch), retryAfter: nil))
        let version = try await currentVersion()
        XCTAssertEqual(version, 42)
    }

    func testInterruptedTransferKeepsStoredVersion() async throws {
        try await storeInitialVersion()
        StubURLProtocol.enqueue(StubURLProtocol.Reply(status: 200, error: URLError(.networkConnectionLost)))

        let outcome = await fetcher.check()

        XCTAssertEqual(outcome, .failed(.network, retryAfter: nil))
        let version = try await currentVersion()
        XCTAssertEqual(version, 42)
        let snapshot = try await fetcher.snapshot()
        XCTAssertEqual(snapshot?.isConfirmedLatest, false)
    }

    func testOlderVersionIsNotAdopted() async throws {
        StubURLProtocol.enqueue(ok(BundleFixtures.bundleObject(version: 43)))
        _ = await fetcher.check()
        StubURLProtocol.enqueue(ok(BundleFixtures.bundleObject(version: 42)))

        let outcome = await fetcher.check()

        XCTAssertEqual(outcome, .failed(.rejected(.olderThanStored(received: 42, stored: 43)), retryAfter: nil))
        let version = try await currentVersion()
        XCTAssertEqual(version, 43)
    }

    func testUnknownMajorVersionKeepsStoredVersionAndAsksForUpdate() async throws {
        try await storeInitialVersion()
        StubURLProtocol.enqueue(ok(BundleFixtures.bundleObject(version: 43, schemaVersion: "3.0.0")))

        let outcome = await fetcher.check()

        XCTAssertEqual(outcome, .updateRequired(recheckAfter: 300))
        let version = try await currentVersion()
        XCTAssertEqual(version, 42)
    }

    func testMissingIntegrityHeaderIsRejected() async throws {
        for header in ["Nexus-Bundle-Sha256", "Nexus-Bundle-Length", "Nexus-Bundle-Version", "Nexus-Bundle-Schema"] {
            StubURLProtocol.enqueue(ok(overriding: [header: nil]))

            let outcome = await fetcher.check()

            XCTAssertEqual(outcome, .failed(.missingIntegrityHeaders, retryAfter: nil), header)
        }
        let version = try await currentVersion()
        XCTAssertNil(version)
    }

    func testDeclaredLengthOverHardLimitIsRejectedWithoutBody() async throws {
        StubURLProtocol.enqueue(ok(overriding: ["Nexus-Bundle-Length": String(ParticipantBundleValidator.hardLimitBytes + 1)]))

        let outcome = await fetcher.check()

        XCTAssertEqual(outcome, .failed(.exceedsHardLimit, retryAfter: nil))
    }

    /// `Content-Length` が無い（edge が圧縮した）場合でも、受信中に数えて上限で止める。
    func testBodyOverHardLimitIsAbortedWhileReceiving() async throws {
        var reply = ok()
        reply.chunks = Self.chunks(Data(repeating: 0x20, count: ParticipantBundleValidator.hardLimitBytes + 1), size: 256 * 1024)
        StubURLProtocol.enqueue(reply)

        let outcome = await fetcher.check()

        XCTAssertEqual(outcome, .failed(.exceedsHardLimit, retryAfter: nil))
        let version = try await currentVersion()
        XCTAssertNil(version)
    }

    func testNotPublishedIsDistinctFromFailure() async throws {
        StubURLProtocol.enqueue(StubURLProtocol.Reply(status: 404, headers: ["Content-Type": "application/problem+json"]))

        let outcome = await fetcher.check()

        XCTAssertEqual(outcome, .notPublished(recheckAfter: 300))
    }

    // MARK: - 再試行の間隔

    func testRetryAfterIsReadFor429And503() async throws {
        StubURLProtocol.enqueue(StubURLProtocol.Reply(status: 429, headers: ["Retry-After": "120"]))
        StubURLProtocol.enqueue(StubURLProtocol.Reply(status: 503, headers: ["Retry-After": "30"]))
        StubURLProtocol.enqueue(StubURLProtocol.Reply(status: 500, headers: ["Retry-After": "30"]))

        let tooMany = await fetcher.check()
        let unavailable = await fetcher.check()
        let integrity = await fetcher.check()

        XCTAssertEqual(tooMany, .failed(.httpStatus(429), retryAfter: 120))
        XCTAssertEqual(unavailable, .failed(.httpStatus(503), retryAfter: 30))
        // 500 などは Retry-After に従わず、スケジューラの指数バックオフに任せる。
        XCTAssertEqual(integrity, .failed(.httpStatus(500), retryAfter: nil))
    }

    func testRetryAfterAcceptsHTTPDate() {
        let now = Date(timeIntervalSince1970: 1_793_523_600) // Sun, 01 Nov 2026 09:00:00 GMT
        XCTAssertEqual(PublishedBundleFetcher.retryAfterInterval("Sun, 01 Nov 2026 09:02:00 GMT", now: now), 120)
        XCTAssertEqual(PublishedBundleFetcher.retryAfterInterval("Sun, 01 Nov 2026 08:00:00 GMT", now: now), 0)
        XCTAssertNil(PublishedBundleFetcher.retryAfterInterval("soon", now: now))
        XCTAssertNil(PublishedBundleFetcher.retryAfterInterval(nil, now: now))
    }

    func testRecheckAfterIsClampedAndDefaultsTo300() {
        XCTAssertEqual(PublishedBundleFetcher.recheckInterval("120"), 120)
        XCTAssertEqual(PublishedBundleFetcher.recheckInterval("10"), 60)
        XCTAssertEqual(PublishedBundleFetcher.recheckInterval("99999"), 3600)
        XCTAssertEqual(PublishedBundleFetcher.recheckInterval(nil), 300)
        XCTAssertEqual(PublishedBundleFetcher.recheckInterval("abc"), 300)
        XCTAssertEqual(PublishedBundleFetcher.recheckInterval("-5"), 60)
    }

    func testRecheckAfterFromResponseIsReturned() async throws {
        StubURLProtocol.enqueue(ok(recheckAfter: "5"))

        guard case .updated(_, let recheckAfter) = await fetcher.check() else {
            return XCTFail("保存されなかった")
        }
        XCTAssertEqual(recheckAfter, 60)
    }

    // MARK: - URLCache を使わない

    func testSessionDoesNotUseURLCache() async throws {
        XCTAssertNil(PublishedBundleFetcher.makeSession().configuration.urlCache)
        XCTAssertEqual(
            PublishedBundleFetcher.makeSession().configuration.requestCachePolicy,
            .reloadIgnoringLocalCacheData
        )

        StubURLProtocol.enqueue(ok())
        StubURLProtocol.enqueue(ok())
        _ = await fetcher.check()
        _ = await fetcher.check()

        // 2回とも通信し、2回目はアプリが保存した ETag だけを送る。
        XCTAssertEqual(StubURLProtocol.requests.count, 2)
        XCTAssertEqual(StubURLProtocol.requests[1].value(forHTTPHeaderField: "If-None-Match"), "\"sha256-fixture-gzip\"")
    }

    // MARK: - 上限付近の大きさ（O-4a、合成データは試験専用）

    func testSyntheticBundleNearHardLimitIsReceivedDecodedAndStored() async throws {
        let padding = String(repeating: "あ", count: 300) // UTF-8 で900バイト
        var spots: [[String: Any]] = []
        for index in 1...9_400 {
            var spot = BundleFixtures.spot(id: String(format: "syn_%05d", index), name: "合成地点\(index)")
            spot["search_aliases"] = [padding]
            spots.append(spot)
        }
        let object = BundleFixtures.bundleObject(spots: spots)
        let size = BundleFixtures.data(object).count
        XCTAssertGreaterThan(size, 8 * 1024 * 1024)
        XCTAssertLessThan(size, ParticipantBundleValidator.hardLimitBytes)
        StubURLProtocol.enqueue(ok(object, chunkSize: 512 * 1024))

        let outcome = await fetcher.check()

        guard case .updated(let stored, _) = outcome else {
            return XCTFail("上限付近の bundle を保存できなかった: \(outcome)")
        }
        XCTAssertEqual(stored.bundle.spots.count, 9_400)
        XCTAssertEqual(stored.metadata.byteLength, size)
    }
}
