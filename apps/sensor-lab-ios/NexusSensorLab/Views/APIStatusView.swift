import SwiftUI

struct APIStatusView: View {
    @State private var isChecking = false
    @State private var statusMessage = "未確認"
    @State private var errorMessage: String?

    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    var body: some View {
        GroupBox("Public API") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Health")
                    Spacer()
                    if isChecking {
                        ProgressView()
                    } else {
                        Text(statusMessage)
                            .font(.headline)
                    }
                }

                Text(apiClient.baseURL.absoluteString)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button("Check /health") {
                    Task {
                        await checkHealth()
                    }
                }
                .disabled(isChecking)
            }
        }
    }

    @MainActor
    private func checkHealth() async {
        isChecking = true
        errorMessage = nil
        defer { isChecking = false }

        do {
            let response = try await apiClient.health()
            statusMessage = response.status
        } catch let error as APIError {
            statusMessage = "エラー"
            errorMessage = error.errorDescription
        } catch {
            statusMessage = "エラー"
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    APIStatusView()
        .padding()
}
