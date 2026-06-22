import SwiftUI

struct ContentView: View {
    @StateObject private var altimeterService = AltimeterService()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    APIStatusView()

                    SensorStatusView(
                        isAvailable: altimeterService.isAltimeterAvailable,
                        isMonitoring: altimeterService.isMonitoring,
                        errorMessage: altimeterService.errorMessage
                    )

                    LiveValuesView(sample: altimeterService.currentSample)

                    DetectionStateView(state: altimeterService.currentState)

                    RecordingControlsView(
                        isRecording: altimeterService.isRecording,
                        onStart: altimeterService.startRecording,
                        onStop: altimeterService.stopRecording,
                        onExport: altimeterService.exportCSV,
                        onClear: altimeterService.clearLogs
                    )

                    GroupBox("Log Count") {
                        HStack {
                            Text("Samples")
                            Spacer()
                            Text("\(altimeterService.recordedSamples.count)")
                                .font(.headline)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Nexus Sensor Lab")
        }
        .onAppear {
            altimeterService.startMonitoring()
        }
        .onDisappear {
            altimeterService.stopMonitoring()
        }
        .sheet(isPresented: $altimeterService.isShareSheetPresented) {
            if let exportURL = altimeterService.exportFileURL {
                ActivityView(activityItems: [exportURL])
            }
        }
    }
}

#Preview {
    ContentView()
}
