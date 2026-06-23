import Foundation

enum MotionState: String, CaseIterable, Codable {
    case stationary
    case ascending
    case descending

    var displayName: String {
        switch self {
        case .stationary: return "停止"
        case .ascending: return "上昇"
        case .descending: return "下降"
        }
    }
}
