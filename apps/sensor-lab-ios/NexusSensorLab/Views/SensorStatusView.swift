import SwiftUI

struct SensorStatusView: View {
    let isAvailable: Bool
    let isMonitoring: Bool
    let errorMessage: String?

    var body: some View {
        GroupBox("Sensor Status") {
            VStack(alignment: .leading, spacing: 8) {
                statusRow(label: "CMAltimeter", value: isAvailable ? "利用可能" : "利用不可")
                statusRow(label: "Monitoring", value: isMonitoring ? "動作中" : "停止中")

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private func statusRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).bold()
        }
    }
}
