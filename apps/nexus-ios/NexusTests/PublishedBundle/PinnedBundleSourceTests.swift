import XCTest
@testable import Nexus

/// 表示中の版の固定と切替（E2-5 §6 規則5、M1-7）。
///
/// 上流（保存ポインタ）は `MutableUpstream` で差し替え、「表示中に新しい版が保存された」状態を作る。
final class PinnedBundleSourceTests: XCTestCase {

    func testFirstReadIsPinnedUntilAdvance() async throws {
        let upstream = MutableUpstream(try PinnedFixtures.snapshot(version: 1))
        let pin = PinnedBundleSource(upstream: upstream.source)

        let first = try await pin.current()
        await upstream.set(try PinnedFixtures.snapshot(version: 2))
        let second = try await pin.current()

        XCTAssertEqual(first?.stored.metadata.bundleVersion, 1)
        XCTAssertEqual(second?.stored.metadata.bundleVersion, 1, "保存ポインタを読み直してはならない")
    }

    func testAdvanceSwitchesToNewerVersion() async throws {
        let upstream = MutableUpstream(try PinnedFixtures.snapshot(version: 1))
        let pin = PinnedBundleSource(upstream: upstream.source)
        _ = try await pin.current()

        await upstream.set(try PinnedFixtures.snapshot(version: 2))
        let switched = await pin.advance()
        let current = try await pin.current()

        XCTAssertTrue(switched)
        XCTAssertEqual(current?.stored.metadata.bundleVersion, 2)
    }

    func testAdvanceWithoutChangeReportsNoSwitch() async throws {
        let upstream = MutableUpstream(try PinnedFixtures.snapshot(version: 1))
        let pin = PinnedBundleSource(upstream: upstream.source)
        _ = try await pin.current()

        let switched = await pin.advance()

        XCTAssertFalse(switched)
    }

    /// 同じ版でも、最新だと確認できたら保存版の表示が変わるので切り替える。
    func testAdvanceSwitchesWhenConfirmationChanges() async throws {
        let upstream = MutableUpstream(try PinnedFixtures.snapshot(version: 1, isConfirmedLatest: false))
        let pin = PinnedBundleSource(upstream: upstream.source)
        _ = try await pin.current()

        await upstream.set(try PinnedFixtures.snapshot(version: 1, isConfirmedLatest: true))
        let switched = await pin.advance()
        let current = try await pin.current()

        XCTAssertTrue(switched)
        XCTAssertEqual(current?.isConfirmedLatest, true)
    }

    /// 上流を読めないときは表示中の版を失わない。
    func testAdvanceKeepsPinnedVersionWhenUpstreamFails() async throws {
        let upstream = MutableUpstream(try PinnedFixtures.snapshot(version: 1))
        let pin = PinnedBundleSource(upstream: upstream.source)
        _ = try await pin.current()

        await upstream.fail()
        let switched = await pin.advance()
        let current = try await pin.current()

        XCTAssertFalse(switched)
        XCTAssertEqual(current?.stored.metadata.bundleVersion, 1)
    }

    /// 読めなかったことは固定しない。次に読むときに上流を読み直す。
    func testReadFailureIsNotPinned() async throws {
        let upstream = MutableUpstream(nil)
        await upstream.fail()
        let pin = PinnedBundleSource(upstream: upstream.source)

        do {
            _ = try await pin.current()
            XCTFail("上流の失敗が伝わらなかった")
        } catch {}

        await upstream.set(try PinnedFixtures.snapshot(version: 3))
        let current = try await pin.current()

        XCTAssertEqual(current?.stored.metadata.bundleVersion, 3)
    }

    /// 保存版がない状態も固定する。最初の版が届いたら、切替点で切り替える。
    func testMissingVersionIsPinnedAndAdvancesToFirstVersion() async throws {
        let upstream = MutableUpstream(nil)
        let pin = PinnedBundleSource(upstream: upstream.source)

        let initial = try await pin.current()
        await upstream.set(try PinnedFixtures.snapshot(version: 1))
        let beforeAdvance = try await pin.current()
        let switched = await pin.advance()
        let afterAdvance = try await pin.current()

        XCTAssertNil(initial)
        XCTAssertNil(beforeAdvance)
        XCTAssertTrue(switched)
        XCTAssertEqual(afterAdvance?.stored.metadata.bundleVersion, 1)
    }

    /// 同時に読まれても全員が同じ版を受け取る（地図と詳細が別々の版を固定しない）。
    func testConcurrentFirstReadsReceiveTheSameVersion() async throws {
        let upstream = MutableUpstream(try PinnedFixtures.snapshot(version: 1))
        let pin = PinnedBundleSource(upstream: upstream.source)
        let later = try PinnedFixtures.snapshot(version: 2)

        async let first = pin.current()
        await upstream.set(later)
        async let second = pin.current()
        let versions = try await [first, second].map { $0?.stored.metadata.bundleVersion }

        XCTAssertEqual(versions[0], versions[1])
    }
}

/// 差し替えられる保存ポインタ。
actor MutableUpstream {
    private var snapshot: PublishedBundleSnapshot?
    private var failing = false

    init(_ snapshot: PublishedBundleSnapshot?) {
        self.snapshot = snapshot
    }

    func set(_ snapshot: PublishedBundleSnapshot?) {
        self.snapshot = snapshot
        failing = false
    }

    func fail() {
        failing = true
    }

    func read() throws -> PublishedBundleSnapshot? {
        if failing {
            throw TestStubError.simulated
        }
        return snapshot
    }

    nonisolated var source: PublishedBundleSource {
        PublishedBundleSource(current: { try await self.read() })
    }
}

enum PinnedFixtures {
    static let confirmedAt = Date(timeIntervalSince1970: 1_793_523_900) // 2026-11-01 18:05 JST

    /// 版ごとに部屋の名前を変え、どの版から読んだかを画面の値で確かめられるようにする。
    static func snapshot(version: Int64, isConfirmedLatest: Bool = true) throws -> PublishedBundleSnapshot {
        var spots = BundleFixtures.validSpots()
        spots[0]["name"] = roomName(version: version)
        let response = BundleFixtures.response(BundleFixtures.bundleObject(version: version, spots: spots))
        let bundle = try ParticipantBundleValidator.validate(body: response.body, headers: response.headers)
        let metadata = StoredBundleMetadata(
            bundleVersion: bundle.meta.bundleVersion,
            releaseID: bundle.meta.releaseID,
            schemaVersion: bundle.meta.schemaVersion,
            sha256: response.headers.sha256,
            byteLength: response.headers.byteLength,
            publishedAt: bundle.meta.publishedAt,
            etag: response.headers.etag,
            storedAt: confirmedAt
        )
        return PublishedBundleSnapshot(
            stored: StoredParticipantBundle(bundle: bundle, metadata: metadata),
            isConfirmedLatest: isConfirmedLatest,
            lastConfirmedAt: isConfirmedLatest ? confirmedAt : nil
        )
    }

    static func roomName(version: Int64) -> String {
        "2A教室（版\(version)）"
    }

    static let roomID = CanonicalSpotID(rawValue: "mb_2f_cl_001")
    static let landmarkID = CanonicalSpotID(rawValue: "campus_lm_001")
}
