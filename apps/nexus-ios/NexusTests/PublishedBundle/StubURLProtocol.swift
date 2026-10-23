import Foundation
@testable import Nexus

/// 取得クライアントの試験用に、通信せず決めた応答を返す `URLProtocol`。
///
/// 本体は `chunks` の単位で順に渡す（受信中の上限の検査を試すため）。受け取った要求は `requests` に残す。
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    struct Reply {
        var status: Int
        var headers: [String: String] = [:]
        var chunks: [Data] = []
        /// 応答の代わりに返す通信エラー。
        var error: URLError?
    }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var replies: [Reply] = []
    nonisolated(unsafe) private static var recorded: [URLRequest] = []

    /// 次の要求から順に返す応答を設定する。
    static func enqueue(_ reply: Reply) {
        lock.withLock { replies.append(reply) }
    }

    static func reset() {
        lock.withLock {
            replies = []
            recorded = []
        }
    }

    static var requests: [URLRequest] {
        lock.withLock { recorded }
    }

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        return PublishedBundleFetcher.makeSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let reply: Reply? = Self.lock.withLock {
            Self.recorded.append(request)
            return Self.replies.isEmpty ? nil : Self.replies.removeFirst()
        }
        guard let reply else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotConnectToHost))
            return
        }
        if let error = reply.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: reply.status,
            httpVersion: "HTTP/1.1",
            headerFields: reply.headers
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        for chunk in reply.chunks {
            client?.urlProtocol(self, didLoad: chunk)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
