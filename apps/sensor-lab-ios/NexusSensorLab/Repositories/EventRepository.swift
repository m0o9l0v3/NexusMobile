import Foundation

protocol EventRepositoryProtocol {
    func fetchTodayEvents() async throws -> [EventDTO]
}

struct RemoteEventRepository: EventRepositoryProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchTodayEvents() async throws -> [EventDTO] {
        try await apiClient.get("/api/events/today")
    }
}

struct MockEventRepository: EventRepositoryProtocol {
    var events: [EventDTO] = [
        EventDTO(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            title: "学校説明会",
            description: "Nexus のオープンキャンパス向け説明イベントです。",
            startTime: "10:00",
            endTime: "10:30",
            location: "ENTRANCE",
            spotCode: "ENTRANCE",
            imageUrl: nil,
            tags: ["説明会"]
        )
    ]

    func fetchTodayEvents() async throws -> [EventDTO] {
        events
    }
}
