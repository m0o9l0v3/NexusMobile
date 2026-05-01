import SwiftUI

struct LiveValuesView: View {
    let sample: SensorSample

    var body: some View {
        GroupBox("Live Values") {
            VStack(spacing: 8) {
                valueRow(label: "気圧(hPa)", value: String(format: "%.2f", sample.pressure))
                valueRow(label: "相対高度(m)", value: String(format: "%.4f", sample.relativeAltitude))
                valueRow(label: "フィルタ後高度(m)", value: String(format: "%.4f", sample.filteredAltitude))
            }
        }
    }

    private func valueRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
                .bold()
        }
    }
}
