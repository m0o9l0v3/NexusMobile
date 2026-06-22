import Foundation

struct SpotDTO: Decodable, Identifiable, Equatable {
    let id: UUID
    let code: String
    let name: String
    let description: String?
    let imageUrl: URL?
    let latitude: Double?
    let longitude: Double?
    let isPublished: Bool
    let tags: [String]
    let arModelUrl: URL?
}

typealias SpotDetailDTO = SpotDTO

struct NearbySpotDTO: Decodable, Identifiable, Equatable {
    let id: UUID
    let code: String
    let name: String
    let distanceMeters: Double
    let latitude: Double
    let longitude: Double
    let tags: [String]
}
