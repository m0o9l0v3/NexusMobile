import SwiftUI

struct RecordingControlsView: View {
    let isRecording: Bool
    let onStart: () -> Void
    let onStop: () -> Void
    let onExport: () -> Void
    let onClear: () -> Void

    var body: some View {
        GroupBox("Recording Controls") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("記録状態")
                    Spacer()
                    Text(isRecording ? "記録中" : "停止中")
                        .bold()
                }

                HStack(spacing: 8) {
                    Button("Start Recording", action: onStart)
                        .buttonStyle(.borderedProminent)
                        .disabled(isRecording)

                    Button("Stop Recording", action: onStop)
                        .buttonStyle(.bordered)
                        .disabled(!isRecording)
                }

                HStack(spacing: 8) {
                    Button("Export CSV", action: onExport)
                        .buttonStyle(.bordered)
                    Button("Clear Logs", role: .destructive, action: onClear)
                        .buttonStyle(.bordered)
                }
            }
        }
    }
}
