import Foundation

enum APIError: LocalizedError, Equatable {
    case invalidURL(String)
    case requestFailed(String)
    case invalidResponse
    case httpError(statusCode: Int, message: String?)
    case decodingError(String)
    case encodingError(String)
    case timeout
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "APIのURLが正しくありません。"
        case .requestFailed(let message):
            return "通信に失敗しました: \(message)"
        case .invalidResponse:
            return "サーバーから不正な応答を受け取りました。"
        case .httpError(let statusCode, let message):
            if let message, !message.isEmpty {
                return "サーバーエラーが発生しました (\(statusCode)): \(message)"
            }
            return "サーバーエラーが発生しました (\(statusCode))。"
        case .decodingError:
            return "サーバー応答の読み取りに失敗しました。"
        case .encodingError:
            return "送信データの作成に失敗しました。"
        case .timeout:
            return "通信がタイムアウトしました。ネットワーク状況を確認してください。"
        case .unknown(let message):
            return "予期しないエラーが発生しました: \(message)"
        }
    }

    var debugDescription: String {
        switch self {
        case .invalidURL(let value):
            return "invalidURL(\(value))"
        case .requestFailed(let message):
            return "requestFailed(\(message))"
        case .invalidResponse:
            return "invalidResponse"
        case .httpError(let statusCode, let message):
            return "httpError(statusCode: \(statusCode), message: \(message ?? "nil"))"
        case .decodingError(let message):
            return "decodingError(\(message))"
        case .encodingError(let message):
            return "encodingError(\(message))"
        case .timeout:
            return "timeout"
        case .unknown(let message):
            return "unknown(\(message))"
        }
    }
}
