import Foundation

protocol SpotRepositoryProtocol {
    func fetchSpots() async throws -> [SpotDTO]
    func fetchSpot(code: String) async throws -> SpotDetailDTO
    func fetchNearby(latitude: Double, longitude: Double, radius: Double) async throws -> [NearbySpotDTO]
}

struct RemoteSpotRepository: SpotRepositoryProtocol {
    private let apiClient: APIClient

    init(apiClient: APIClient = .shared) {
        self.apiClient = apiClient
    }

    func fetchSpots() async throws -> [SpotDTO] {
        try await apiClient.get("/api/spots/public")
    }

    func fetchSpot(code: String) async throws -> SpotDetailDTO {
        try await apiClient.get("/api/spots/by-code/\(code)")
    }

    func fetchNearby(latitude: Double, longitude: Double, radius: Double = 500) async throws -> [NearbySpotDTO] {
        try await apiClient.get("/api/nearby", queryItems: [
            URLQueryItem(name: "lat", value: String(latitude)),
            URLQueryItem(name: "lng", value: String(longitude)),
            URLQueryItem(name: "radius", value: String(radius))
        ])
    }
}

struct MockSpotRepository: SpotRepositoryProtocol {
    var spots: [SpotDTO] = [
        SpotDTO(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            code: "ENTRANCE",
            name: "正門受付",
            description: "オープンキャンパス受付スポットです。",
            imageUrl: nil,
            latitude: 35.681236,
            longitude: 139.767125,
            isPublished: true,
            tags: ["受付", "案内"],
            arModelUrl: nil
        )
    ]

    func fetchSpots() async throws -> [SpotDTO] {
        spots
    }

    func fetchSpot(code: String) async throws -> SpotDetailDTO {
        if let spot = spots.first(where: { $0.code.caseInsensitiveCompare(code) == .orderedSame }) {
            return spot
        }
        throw APIError.httpError(statusCode: 404, message: "Spot not found")
    }

    func fetchNearby(latitude: Double, longitude: Double, radius: Double = 500) async throws -> [NearbySpotDTO] {
        spots.compactMap { spot in
            guard let spotLatitude = spot.latitude, let spotLongitude = spot.longitude else { return nil }
            return NearbySpotDTO(
                id: spot.id,
                code: spot.code,
                name: spot.name,
                distanceMeters: 0,
                latitude: spotLatitude,
                longitude: spotLongitude,
                tags: spot.tags
            )
        }
    }
}
