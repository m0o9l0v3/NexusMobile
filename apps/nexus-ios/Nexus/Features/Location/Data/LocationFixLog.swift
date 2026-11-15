#if DEBUG
import Foundation
import UIKit

/// 実機確認（#80）用の、位置の記録。**DEBUG のみ**。Release には入らない。
///
/// 起動引数 `-NexusLocationLog` で、本番の Core Location の取得（`CoreLocationUpdatesProvider`）を包み、
/// 届いた知らせを1行ずつ端末内の CSV（`Documents/NexusLocationLog/`）に書く。
/// **通信はしない**。ファイルは端末の中だけに残り、オーナーが Xcode か `devicectl` で取り出す
/// （Info.plist の約束「現在地は Nexus のサーバーへ送りません」を守る）。
///
/// 緯度・経度は書かない。結果を Issue に貼っても構内の正確な位置が出ないようにするため。
/// 書くのは、誤差・鮮度・間隔・電池だけ（`docs/verification/ios-gps-battery-check.md`）。
enum LocationFixLog {
    static let launchArgument = "-NexusLocationLog"
    static let directoryName = "NexusLocationLog"

    static let header = "received_at,event,horizontal_accuracy_m,age_s,interval_s,usable,battery_percent,low_power_mode,settings"

    /// 端末の状態（電池・低電力モード）。試験では決めた値を返す。
    struct DeviceState: Equatable, Sendable {
        /// 0...100。分からなければ nil。
        var batteryPercent: Int?
        var isLowPowerModeEnabled: Bool
    }

    enum Event: Equatable, Sendable {
        case start(LocationAcquisitionSettings)
        case update(LocationUpdateEvent)
        case stop
    }

    /// 1行を作る。
    /// - Parameters:
    ///   - previousFixTimestamp: 直前に届いた点の時刻（取り間引く前の、OS が出した間隔を見るため）。
    static func line(
        _ event: Event,
        receivedAt: Date,
        previousFixTimestamp: Date?,
        settings: LocationAcquisitionSettings,
        device: DeviceState
    ) -> String {
        var name = ""
        var accuracy = ""
        var age = ""
        var interval = ""
        var usable = ""
        var settingsText = ""
        switch event {
        case .start(let started):
            name = "start"
            settingsText = describe(started)
        case .stop:
            name = "stop"
        case .update(.unavailable):
            name = "unavailable"
        case .update(.ended):
            name = "ended"
        case .update(.fix(let fix)):
            name = "fix"
            accuracy = format(fix.horizontalAccuracy, digits: 1)
            age = format(receivedAt.timeIntervalSince(fix.timestamp), digits: 2)
            if let previousFixTimestamp {
                interval = format(fix.timestamp.timeIntervalSince(previousFixTimestamp), digits: 2)
            }
            let isUsable = fix.horizontalAccuracy >= 0 && fix.horizontalAccuracy <= settings.maximumHorizontalAccuracy
            usable = isUsable ? "1" : "0"
        }
        return [
            timestampFormatter.string(from: receivedAt),
            name,
            accuracy,
            age,
            interval,
            usable,
            device.batteryPercent.map(String.init) ?? "",
            device.isLowPowerModeEnabled ? "1" : "0",
            settingsText,
        ].joined(separator: ",")
    }

    /// 設定を1列に収める（区切りは `;`）。
    static func describe(_ settings: LocationAcquisitionSettings) -> String {
        [
            "activity=\(settings.activity)",
            "timeout_s=\(format(seconds(settings.acquisitionTimeout), digits: 1))",
            "max_accuracy_m=\(format(settings.maximumHorizontalAccuracy, digits: 1))",
            "min_interval_s=\(format(seconds(settings.minimumUpdateInterval), digits: 2))",
            "campus_margin_m=\(format(settings.campusMarginMeters, digits: 1))",
        ].joined(separator: ";")
    }

    /// 端末の現地時刻（秒の小数3桁、時差付き）。
    static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = .current
        return formatter
    }()

    private static func seconds(_ duration: Duration) -> Double {
        let parts = duration.components
        return Double(parts.seconds) + Double(parts.attoseconds) / 1e18
    }

    private static func format(_ value: Double, digits: Int) -> String {
        String(format: "%.\(digits)f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    /// 本番の端末の状態。
    @MainActor
    static func currentDeviceState() -> DeviceState {
        let device = UIDevice.current
        if !device.isBatteryMonitoringEnabled { device.isBatteryMonitoringEnabled = true }
        let level = device.batteryLevel
        return DeviceState(
            batteryPercent: level < 0 ? nil : Int((level * 100).rounded()),
            isLowPowerModeEnabled: ProcessInfo.processInfo.isLowPowerModeEnabled
        )
    }
}

/// 記録の書き先。
@MainActor
protocol LocationFixLogSink: AnyObject {
    func append(_ line: String)
}

/// 端末内のファイル（`Documents/NexusLocationLog/location-<作った時刻>.csv`）。
///
/// ファイルは最初の1行を書くときに作る（画面の作り直しで書き先が何度作られても、空のファイルを増やさない）。
@MainActor
final class FileLocationFixLogSink: LocationFixLogSink {
    let fileURL: URL
    private let directory: URL
    private var handle: FileHandle?

    init(directory: URL, createdAt: Date = Date()) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        self.directory = directory
        fileURL = directory.appendingPathComponent("location-\(formatter.string(from: createdAt)).csv")
    }

    /// 本番の書き先（アプリの Documents の下）。
    static func makeDefault() -> FileLocationFixLogSink {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return FileLocationFixLogSink(directory: documents.appendingPathComponent(LocationFixLog.directoryName))
    }

    func append(_ line: String) {
        guard let handle = openIfNeeded() else { return }
        // 1行ずつ書き切る（記録中にアプリが落ちても、それまでの行は残る）。
        try? handle.write(contentsOf: Data((line + "\n").utf8))
    }

    private func openIfNeeded() -> FileHandle? {
        if let handle { return handle }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: fileURL.path) {
                try Data((LocationFixLog.header + "\n").utf8).write(to: fileURL)
            }
            let opened = try FileHandle(forWritingTo: fileURL)
            try opened.seekToEnd()
            handle = opened
            return opened
        } catch {
            return nil
        }
    }
}

/// 本番の取得を包んで、届いた知らせを記録する。知らせはそのまま `CurrentLocationStore` へ渡す（振る舞いは変えない）。
@MainActor
final class LoggingLocationUpdatesProvider: LocationUpdatesProviding {
    private let inner: LocationUpdatesProviding
    private let sink: LocationFixLogSink
    private let now: @MainActor () -> Date
    private let deviceState: @MainActor () -> LocationFixLog.DeviceState
    private var settings: LocationAcquisitionSettings = .provisional
    private var previousFixTimestamp: Date?
    private var isRunning = false

    init(
        wrapping inner: LocationUpdatesProviding,
        sink: LocationFixLogSink,
        now: @escaping @MainActor () -> Date = { Date() },
        deviceState: @escaping @MainActor () -> LocationFixLog.DeviceState = { LocationFixLog.currentDeviceState() }
    ) {
        self.inner = inner
        self.sink = sink
        self.now = now
        self.deviceState = deviceState
    }

    func start(settings: LocationAcquisitionSettings, onEvent: @escaping @MainActor (LocationUpdateEvent) -> Void) {
        if isRunning { record(.stop) }
        self.settings = settings
        previousFixTimestamp = nil
        isRunning = true
        record(.start(settings))
        inner.start(settings: settings) { [weak self] event in
            self?.record(.update(event))
            onEvent(event)
        }
    }

    func stop() {
        inner.stop()
        guard isRunning else { return }
        isRunning = false
        record(.stop)
    }

    private func record(_ event: LocationFixLog.Event) {
        sink.append(LocationFixLog.line(
            event,
            receivedAt: now(),
            previousFixTimestamp: previousFixTimestamp,
            settings: settings,
            device: deviceState()
        ))
        if case .update(.fix(let fix)) = event {
            previousFixTimestamp = fix.timestamp
        }
    }
}

extension LocationAcquisitionSettings {
    /// 実機確認（#80）で仮の値以外を試すための起動引数。**DEBUG のみ**。
    /// - `-NexusLocationActivity <default|otherNavigation|fitness>`
    /// - `-NexusLocationTimeout <秒>`
    /// - `-NexusLocationMaxAccuracy <メートル>`
    /// - `-NexusLocationMinInterval <秒>`
    /// 読めない値は無視して、元の値を使う。
    func applyingDebugOverrides(_ arguments: [String]) -> LocationAcquisitionSettings {
        var result = self
        func value(after flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag), arguments.indices.contains(index + 1) else { return nil }
            return arguments[index + 1]
        }
        func positive(after flag: String) -> Double? {
            guard let text = value(after: flag), let number = Double(text), number.isFinite, number > 0 else { return nil }
            return number
        }
        switch value(after: "-NexusLocationActivity") {
        case "default": result.activity = .default
        case "otherNavigation": result.activity = .otherNavigation
        case "fitness": result.activity = .fitness
        default: break
        }
        if let seconds = positive(after: "-NexusLocationTimeout") {
            result.acquisitionTimeout = .milliseconds(Int((seconds * 1000).rounded()))
        }
        if let meters = positive(after: "-NexusLocationMaxAccuracy") {
            result.maximumHorizontalAccuracy = meters
        }
        if let seconds = positive(after: "-NexusLocationMinInterval") {
            result.minimumUpdateInterval = .milliseconds(Int((seconds * 1000).rounded()))
        }
        return result
    }
}
#endif
