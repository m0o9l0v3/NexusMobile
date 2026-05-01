import CoreMotion
import Foundation
import SwiftUI

@MainActor
final class AltimeterService: NSObject, ObservableObject {
    @Published var isMonitoring = false
    @Published var isRecording = false
    @Published var isShareSheetPresented = false
    @Published var exportFileURL: URL?
    @Published var errorMessage: String?
    @Published var currentState: MotionState = .stationary
    @Published var recordedSamples: [SensorSample] = []
    @Published var currentSample = SensorSample(
        timestamp: Date(),
        pressure: 0,
        relativeAltitude: 0,
        filteredAltitude: 0,
        state: .stationary
    )

    let isAltimeterAvailable = CMAltimeter.isRelativeAltitudeAvailable()

    private let altimeter = CMAltimeter()
    private var filter = MovingAverageFilter(windowSize: 8)
    private let detector = MotionStateDetector(threshold: 0.05)
    private let csvExporter = CSVExportService()
    private var previousFilteredAltitude: Double?

    func startMonitoring() {
        guard isAltimeterAvailable else {
            errorMessage = "このデバイスはCMAltimeterをサポートしていません。実機(iPhone)で確認してください。"
            return
        }
        guard !isMonitoring else { return }

        errorMessage = nil

        altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, error in
            guard let self else { return }

            if let error {
                self.errorMessage = "センサー取得エラー: \(error.localizedDescription)"
                return
            }

            guard let data else { return }

            let pressure = data.pressure.doubleValue * 10 // kPa -> hPa
            let relativeAltitude = data.relativeAltitude.doubleValue
            let filtered = self.filter.append(relativeAltitude)
            let state = self.detector.detect(previous: self.previousFilteredAltitude, current: filtered)
            self.previousFilteredAltitude = filtered

            let sample = SensorSample(
                timestamp: Date(),
                pressure: pressure,
                relativeAltitude: relativeAltitude,
                filteredAltitude: filtered,
                state: state
            )

            self.currentState = state
            self.currentSample = sample

            if self.isRecording {
                self.recordedSamples.append(sample)
            }
        }

        isMonitoring = true
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        altimeter.stopRelativeAltitudeUpdates()
        isMonitoring = false
    }

    func startRecording() {
        isRecording = true
    }

    func stopRecording() {
        isRecording = false
    }

    func clearLogs() {
        recordedSamples.removeAll()
    }

    func exportCSV() {
        guard !recordedSamples.isEmpty else {
            errorMessage = "エクスポートできるログがありません。"
            return
        }

        do {
            let csv = csvExporter.makeCSV(from: recordedSamples)
            let url = try csvExporter.exportToTemporaryFile(csvString: csv)
            exportFileURL = url
            isShareSheetPresented = true
        } catch {
            errorMessage = "CSV出力に失敗しました: \(error.localizedDescription)"
        }
    }
}
