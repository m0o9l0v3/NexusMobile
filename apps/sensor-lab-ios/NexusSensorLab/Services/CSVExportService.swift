import Foundation

struct CSVExportService {
    private let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()



    private func formatDecimal(_ value: Double) -> String {
        // CSV互換性のため小数点は常に "." を使用
        String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    func makeCSV(from samples: [SensorSample]) -> String {
        var rows: [String] = ["timestamp,pressure,relativeAltitude,filteredAltitude,state"]

        rows.append(contentsOf: samples.map { sample in
            [
                formatter.string(from: sample.timestamp),
                formatDecimal(sample.pressure),
                formatDecimal(sample.relativeAltitude),
                formatDecimal(sample.filteredAltitude),
                sample.state.rawValue
            ].joined(separator: ",")
        })

        return rows.joined(separator: "\n")
    }

    func exportToTemporaryFile(csvString: String) throws -> URL {
        let filename = "nexus_sensor_log_\(Int(Date().timeIntervalSince1970)).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try csvString.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
