import XCTest
@testable import Nexus

/// 実機確認（#80）用の位置の記録（DEBUG のみ）。
@MainActor
final class LocationFixLogTests: XCTestCase {
    private let device = LocationFixLog.DeviceState(batteryPercent: 87, isLowPowerModeEnabled: false)
    private let base = Date(timeIntervalSince1970: 1_800_000_000)

    private func fix(accuracy: Double, at offset: TimeInterval) -> LocationFix {
        LocationFix(
            coordinate: CampusMapCoordinate(latitude: 42.7708, longitude: 141.6806),
            horizontalAccuracy: accuracy,
            timestamp: base.addingTimeInterval(offset)
        )
    }

    private func columns(_ line: String) -> [String] {
        line.components(separatedBy: ",")
    }

    func testHeaderAndLinesHaveSameColumnCount() {
        let headerCount = columns(LocationFixLog.header).count
        let line = LocationFixLog.line(
            .update(.fix(fix(accuracy: 12.34, at: 0))),
            receivedAt: base.addingTimeInterval(0.5),
            previousFixTimestamp: nil,
            settings: .provisional,
            device: device
        )
        XCTAssertEqual(columns(line).count, headerCount)
        let start = LocationFixLog.line(.start(.provisional), receivedAt: base, previousFixTimestamp: nil, settings: .provisional, device: device)
        XCTAssertEqual(columns(start).count, headerCount)
    }

    func testFixLineRecordsAccuracyAgeIntervalAndUsable() {
        let line = LocationFixLog.line(
            .update(.fix(fix(accuracy: 12.34, at: 3))),
            receivedAt: base.addingTimeInterval(3.25),
            previousFixTimestamp: base.addingTimeInterval(2),
            settings: .provisional,
            device: device
        )
        let values = columns(line)
        XCTAssertEqual(values[1], "fix")
        XCTAssertEqual(values[2], "12.3")
        XCTAssertEqual(values[3], "0.25")
        XCTAssertEqual(values[4], "1.00")
        XCTAssertEqual(values[5], "1")
        XCTAssertEqual(values[6], "87")
        XCTAssertEqual(values[7], "0")
    }

    func testFixWorseThanThresholdIsMarkedUnusable() {
        let line = LocationFixLog.line(
            .update(.fix(fix(accuracy: 65, at: 0))),
            receivedAt: base,
            previousFixTimestamp: nil,
            settings: .provisional,
            device: device
        )
        XCTAssertEqual(columns(line)[5], "0")
        XCTAssertEqual(columns(line)[4], "", "最初の点には間隔が無い")
    }

    /// 結果を Issue に貼っても構内の正確な位置が出ないよう、緯度・経度を書かない。
    func testLineNeverContainsCoordinates() {
        let line = LocationFixLog.line(
            .update(.fix(fix(accuracy: 5, at: 0))),
            receivedAt: base,
            previousFixTimestamp: nil,
            settings: .provisional,
            device: device
        )
        XCTAssertFalse(line.contains("42.77"))
        XCTAssertFalse(line.contains("141.68"))
    }

    func testStartLineDescribesSettings() {
        let line = LocationFixLog.line(.start(.provisional), receivedAt: base, previousFixTimestamp: nil, settings: .provisional, device: device)
        XCTAssertEqual(columns(line)[1], "start")
        XCTAssertEqual(
            columns(line)[8],
            "activity=otherNavigation;timeout_s=15.0;max_accuracy_m=50.0;min_interval_s=1.00;campus_margin_m=100.0"
        )
    }

    func testUnknownBatteryAndLowPowerMode() {
        let line = LocationFixLog.line(
            .update(.unavailable),
            receivedAt: base,
            previousFixTimestamp: nil,
            settings: .provisional,
            device: LocationFixLog.DeviceState(batteryPercent: nil, isLowPowerModeEnabled: true)
        )
        XCTAssertEqual(columns(line)[1], "unavailable")
        XCTAssertEqual(columns(line)[6], "")
        XCTAssertEqual(columns(line)[7], "1")
    }

    // MARK: - LoggingLocationUpdatesProvider

    func testLoggingProviderPassesEventsThroughAndRecordsThem() {
        let inner = StubLocationUpdatesProvider()
        let sink = MemoryLocationFixLogSink()
        var clock = base
        let provider = LoggingLocationUpdatesProvider(wrapping: inner, sink: sink, now: { clock }, deviceState: { self.device })
        var received: [LocationUpdateEvent] = []

        provider.start(settings: .provisional) { received.append($0) }
        XCTAssertEqual(inner.startCount, 1)

        clock = base.addingTimeInterval(1.2)
        inner.onEvent?(.fix(fix(accuracy: 8, at: 1)))
        clock = base.addingTimeInterval(2.2)
        inner.onEvent?(.fix(fix(accuracy: 9, at: 2)))
        inner.onEvent?(.unavailable)
        provider.stop()

        XCTAssertEqual(received.count, 3, "知らせはそのまま渡す（振る舞いを変えない）")
        XCTAssertEqual(inner.stopCount, 1)
        XCTAssertEqual(sink.lines.map { columns($0)[1] }, ["start", "fix", "fix", "unavailable", "stop"])
        XCTAssertEqual(columns(sink.lines[1])[4], "", "最初の点には間隔が無い")
        XCTAssertEqual(columns(sink.lines[2])[4], "1.00")
        XCTAssertEqual(columns(sink.lines[2])[3], "0.20")
    }

    func testRestartResetsIntervalAndClosesPreviousRun() {
        let inner = StubLocationUpdatesProvider()
        let sink = MemoryLocationFixLogSink()
        let provider = LoggingLocationUpdatesProvider(wrapping: inner, sink: sink, now: { self.base }, deviceState: { self.device })

        provider.start(settings: .provisional) { _ in }
        inner.onEvent?(.fix(fix(accuracy: 8, at: 0)))
        provider.start(settings: .provisional) { _ in }
        inner.onEvent?(.fix(fix(accuracy: 8, at: 30)))
        provider.stop()
        provider.stop()

        XCTAssertEqual(sink.lines.map { columns($0)[1] }, ["start", "fix", "stop", "start", "fix", "stop"])
        XCTAssertEqual(columns(sink.lines[4])[4], "", "始め直したら前の点との間隔を書かない")
    }

    func testFileSinkWritesHeaderOnceAndAppends() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocationFixLogTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }

        let sink = FileLocationFixLogSink(directory: directory, createdAt: base)
        XCTAssertFalse(FileManager.default.fileExists(atPath: sink.fileURL.path), "書くまでファイルを作らない")
        sink.append("a")
        sink.append("b")

        let again = FileLocationFixLogSink(directory: directory, createdAt: base)
        again.append("c")

        let text = try String(contentsOf: sink.fileURL, encoding: .utf8)
        XCTAssertEqual(text, LocationFixLog.header + "\na\nb\nc\n")
        XCTAssertTrue(sink.fileURL.lastPathComponent.hasPrefix("location-"))
        XCTAssertEqual(sink.fileURL.pathExtension, "csv")
    }

    // MARK: - Debug overrides

    func testOverridesReplaceProvisionalValues() {
        let settings = LocationAcquisitionSettings.provisional.applyingDebugOverrides([
            "Nexus",
            "-NexusLocationActivity", "fitness",
            "-NexusLocationTimeout", "20",
            "-NexusLocationMaxAccuracy", "30",
            "-NexusLocationMinInterval", "2.5",
        ])
        XCTAssertEqual(settings.activity, .fitness)
        XCTAssertEqual(settings.acquisitionTimeout, .seconds(20))
        XCTAssertEqual(settings.maximumHorizontalAccuracy, 30)
        XCTAssertEqual(settings.minimumUpdateInterval, .milliseconds(2500))
        XCTAssertEqual(settings.campusMarginMeters, 100)
    }

    func testOverridesIgnoreInvalidValues() {
        let settings = LocationAcquisitionSettings.provisional.applyingDebugOverrides([
            "-NexusLocationActivity", "car",
            "-NexusLocationTimeout", "0",
            "-NexusLocationMaxAccuracy", "abc",
            "-NexusLocationMinInterval",
        ])
        XCTAssertEqual(settings, .provisional)
    }

    func testNoArgumentsKeepsProvisional() {
        XCTAssertEqual(LocationAcquisitionSettings.provisional.applyingDebugOverrides([]), .provisional)
    }
}

@MainActor
final class MemoryLocationFixLogSink: LocationFixLogSink {
    private(set) var lines: [String] = []
    func append(_ line: String) { lines.append(line) }
}
