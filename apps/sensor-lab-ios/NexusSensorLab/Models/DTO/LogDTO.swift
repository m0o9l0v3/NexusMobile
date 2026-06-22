import Foundation

struct CreateLogRequestDTO: Encodable, Equatable {
    let sessionId: String
    let eventType: LogEventType
    let spotCode: String?
    let payload: [String: String]?
    let occurredAt: Date?
    let locationLat: Double?
    let locationLng: Double?
    let locationAccuracy: Double?
}

struct CreateLogBatchRequestDTO: Encodable, Equatable {
    let logs: [CreateLogRequestDTO]
}

struct AcceptedResponseDTO: Decodable, Equatable {
    let accepted: Bool
}

enum LogEventType: String, Encodable, Equatable {
    case spotView = "spot_view"
    case qrScan = "qr_scan"
    case eventTap = "event_tap"
    case nearbyOpen = "nearby_open"
}
