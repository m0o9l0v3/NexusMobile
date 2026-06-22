import Foundation

protocol LogRepositoryProtocol {
    func sendLog(_ log: CreateLogRequestDTO) async throws -> AcceptedResponseDTO
    func sendLogsBatch(_ logs: [CreateLogRequestDTO]) async throws -> AcceptedResponseDTO
}

struct RemoteLogRepository: LogRepositoryProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func sendLog(_ log: CreateLogRequestDTO) async throws -> AcceptedResponseDTO {
        try await apiClient.post("/api/logs", body: log)
    }

    func sendLogsBatch(_ logs: [CreateLogRequestDTO]) async throws -> AcceptedResponseDTO {
        try await apiClient.post("/api/logs/batch", body: CreateLogBatchRequestDTO(logs: logs))
    }
}

struct MockLogRepository: LogRepositoryProtocol {
    func sendLog(_ log: CreateLogRequestDTO) async throws -> AcceptedResponseDTO {
        AcceptedResponseDTO(accepted: true)
    }

    func sendLogsBatch(_ logs: [CreateLogRequestDTO]) async throws -> AcceptedResponseDTO {
        AcceptedResponseDTO(accepted: true)
    }
}
