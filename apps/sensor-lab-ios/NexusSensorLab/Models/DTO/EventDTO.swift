import Foundation

struct EventDTO: Decodable, Identifiable, Equatable {
    let id: UUID
    let title: String
    let description: String?
    let startTime: String
    let endTime: String
    let location: String?
    let spotCode: String?
    let imageUrl: URL?
    let tags: [String]
}
