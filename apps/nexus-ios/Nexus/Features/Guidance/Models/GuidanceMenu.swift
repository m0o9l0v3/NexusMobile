import Foundation

/// P09 の目次に表示する項目。rawValue は原稿の標準 ID。
enum GuidanceMenuTopic: String, Equatable, Sendable {
    case health
    case help
    case reception
    case access
    case facility
    case manners
    case department
    case schoolLife
    case dormitory
    case faq
    case about

    var defaultArticleID: GuidanceArticleID { GuidanceArticleID(rawValue: rawValue) }

    var title: String {
        switch self {
        case .health: "気分が悪くなったら"
        case .help: "困ったとき"
        case .reception: "受付のご案内"
        case .access: "交通アクセス"
        case .facility: "施設利用・学食"
        case .manners: "注意事項・マナー"
        case .department: "学科紹介"
        case .schoolLife: "学校生活"
        case .dormitory: "学生寮"
        case .faq: "よくある質問（FAQ）"
        case .about: "このアプリについて"
        }
    }

    var systemImageName: String {
        switch self {
        case .health: "cross.case"
        case .help: "person.crop.circle.badge.questionmark"
        case .reception: "person.crop.circle"
        case .access: "bus"
        case .facility: "building.2"
        case .manners: "exclamationmark.circle"
        case .department: "book"
        case .schoolLife: "person.2"
        case .dormitory: "bed.double"
        case .faq: "questionmark.circle"
        case .about: "info.circle"
        }
    }
}

struct GuidanceMenuItem: Identifiable, Equatable, Sendable {
    let topic: GuidanceMenuTopic
    let articleID: GuidanceArticleID?

    var id: GuidanceMenuTopic { topic }
}

struct GuidanceMenuSection: Identifiable, Equatable, Sendable {
    enum Kind: CaseIterable, Sendable {
        case emergency
        case eventDay
        case school

        var heading: String {
            switch self {
            case .emergency: "困ったとき・緊急"
            case .eventDay: "当日のご案内"
            case .school: "学校を知る"
            }
        }

        var systemImageName: String {
            switch self {
            case .emergency: "exclamationmark.triangle.fill"
            case .eventDay: "calendar"
            case .school: "graduationcap"
            }
        }

        var topics: [GuidanceMenuTopic] {
            switch self {
            case .emergency: [.health, .help]
            case .eventDay: [.reception, .access, .facility, .manners]
            case .school: [.department, .schoolLife, .dormitory, .faq, .about]
            }
        }
    }

    let kind: Kind
    let items: [GuidanceMenuItem]

    var id: Kind { kind }
}

struct GuidanceTopSnapshot: Equatable, Sendable {
    let sections: [GuidanceMenuSection]
}
