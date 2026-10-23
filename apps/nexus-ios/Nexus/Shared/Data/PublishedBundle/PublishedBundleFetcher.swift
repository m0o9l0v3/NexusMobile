import Foundation

/// 1回の更新確認（`GET /api/v2/bundle` の条件付き GET）の結果。
///
/// どの結果でも、保存済みの版は壊れない（E2-5 §6 規則2・8・10）。次の確認の時期を決めるのは
/// 確認のスケジューラ（#109 の進め方3）で、ここでは応答から読める間隔だけを返す。
enum PublishedBundleCheckOutcome: Equatable, Sendable {
    /// 新しい版を保存した（200）。
    case updated(StoredParticipantBundle, recheckAfter: TimeInterval)
    /// 保存済みの版が最新だった（304、または同じ版の 200）。
    case unchanged(StoredParticipantBundle, recheckAfter: TimeInterval)
    /// まだ一度も公開されていない（404）。「掲載なし」として表示する（§4.3）。
    case notPublished(recheckAfter: TimeInterval)
    /// 未知のメジャー版。保存済みの版を使い続け、アプリの更新が必要と表示する（§6 規則6）。
    case updateRequired(recheckAfter: TimeInterval)
    /// 取得・検証に失敗した。`retryAfter` は 429・503 の `Retry-After`（秒）。それ以外は nil で、
    /// スケジューラが指数バックオフで次を決める。
    case failed(PublishedBundleFetchFailure, retryAfter: TimeInterval?)
}

enum PublishedBundleFetchFailure: Error, Equatable, Sendable {
    /// 通信できない・タイムアウト。
    case network
    /// 想定外の HTTP status（429・500・503 など）。
    case httpStatus(Int)
    /// `Nexus-Bundle-Sha256`・`-Length`・`-Version`・`-Schema` のいずれかが欠けている・読めない（§4.1.1）。
    case missingIntegrityHeaders
    /// 非圧縮の大きさが硬い上限（10 MiB）を超えた（§6 規則8）。本体は保存しない。
    case exceedsHardLimit
    /// 受信した本体が検証に通らなかった（§6 規則2）。
    case rejected(ParticipantBundleError)
    /// 304 の照合ヘッダーが保存済みの版と一致しない、または保存済みの版がない。
    case notModifiedMismatch
    /// 保存に失敗した（ディスクの不足など）。
    case storage
}

/// 公開データの bundle を取得し、検証してから保存する（E2-5 §6 規則1・2・8・9・10）。
///
/// - spot と地図を含む bundle の全量を1回の GET で取得する（規則1）。
/// - `URLCache` を使わない。保存済みの ETag を解釈せずに `If-None-Match` に送り、304 を自分で扱う（規則9）。
/// - 受信中に展開後のバイト数を数え、硬い上限を超えた時点で中断する（規則8）。
/// - 確認の頻度・再試行の間隔は扱わない（スケジューラの責務）。
actor PublishedBundleFetcher {
    static let defaultRecheckSeconds: TimeInterval = 300
    static let recheckRange: ClosedRange<TimeInterval> = 60...3600

    private let endpoint: URL
    private let store: PublishedBundleStore
    private let session: URLSession
    /// このプロセスで直近の確認が成功したか。起動直後は未確認（保存版として表示する）。
    private var lastCheckSucceeded = false
    /// このプロセスで確認を一度でも終えたか。
    private var hasCompletedCheck = false
    /// 実行中の確認。重ねて呼ばれたら同じ確認に合流する。
    private var inFlight: Task<PublishedBundleCheckOutcome, Never>?

    init(endpoint: URL, store: PublishedBundleStore, session: URLSession = PublishedBundleFetcher.makeSession()) {
        self.endpoint = endpoint
        self.store = store
        self.session = session
    }

    /// bundle の取得専用の設定。標準キャッシュを使わない（規則9）。
    static func makeSession(configuration: URLSessionConfiguration = .ephemeral) -> URLSession {
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }

    /// 画面に渡す現在の版。保存済みの版がなければ nil。
    ///
    /// 保存済みの版がなく、このプロセスでまだ確認を終えていない（初回起動の確認中など）場合は、
    /// その確認に合流して結果を待つ。確認を終えた後に保存済みの版がなければ nil を返す。
    func snapshot() async throws -> PublishedBundleSnapshot? {
        var current = try await store.loadCurrent()
        if current == nil, !hasCompletedCheck {
            _ = await check()
            current = try await store.loadCurrent()
        }
        guard let stored = current else { return nil }
        return PublishedBundleSnapshot(
            stored: stored,
            isConfirmedLatest: lastCheckSucceeded,
            lastConfirmedAt: stored.metadata.lastConfirmedAt
        )
    }

    /// 1回だけ確認する。実行中の確認があれば、それに合流する。
    func check() async -> PublishedBundleCheckOutcome {
        if let inFlight {
            return await inFlight.value
        }
        let task = Task { await self.performCheck() }
        inFlight = task
        let outcome = await task.value
        inFlight = nil
        hasCompletedCheck = true
        switch outcome {
        case .updated, .unchanged:
            lastCheckSucceeded = true
        case .notPublished, .updateRequired, .failed:
            lastCheckSucceeded = false
        }
        return outcome
    }

    private func performCheck() async -> PublishedBundleCheckOutcome {
        let stored: StoredParticipantBundle?
        do {
            stored = try await store.loadCurrent()
        } catch {
            return .failed(.storage, retryAfter: nil)
        }

        var request = URLRequest(url: endpoint, cachePolicy: .reloadIgnoringLocalCacheData)
        request.httpMethod = "GET"
        if let etag = stored?.metadata.etag {
            // 値の形式に依存しない。edge が付けた接尾辞（`-gzip` など）も取り除かない（規則9）。
            request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }

        let response: CappedResponse
        do {
            response = try await CappedDataTask.run(request, session: session, limit: ParticipantBundleValidator.hardLimitBytes)
        } catch {
            return .failed(.network, retryAfter: nil)
        }

        let http = response.response
        let recheckAfter = Self.recheckInterval(http.value(forHTTPHeaderField: "Nexus-Recheck-After"))
        switch http.statusCode {
        case 200:
            return await accept(response, recheckAfter: recheckAfter)
        case 304:
            return await confirmNotModified(http, recheckAfter: recheckAfter)
        case 404:
            return .notPublished(recheckAfter: recheckAfter)
        case 429, 503:
            return .failed(
                .httpStatus(http.statusCode),
                retryAfter: Self.retryAfterInterval(http.value(forHTTPHeaderField: "Retry-After"))
            )
        default:
            return .failed(.httpStatus(http.statusCode), retryAfter: nil)
        }
    }

    private func accept(_ response: CappedResponse, recheckAfter: TimeInterval) async -> PublishedBundleCheckOutcome {
        switch response.stop {
        case .missingIntegrityHeaders:
            return .failed(.missingIntegrityHeaders, retryAfter: nil)
        case .unsupportedMajor:
            return .updateRequired(recheckAfter: recheckAfter)
        case .exceedsHardLimit:
            return .failed(.exceedsHardLimit, retryAfter: nil)
        case .none:
            break
        }
        guard let headers = Self.integrityHeaders(response.response) else {
            return .failed(.missingIntegrityHeaders, retryAfter: nil)
        }
        do {
            switch try await store.accept(body: response.body, headers: headers) {
            case .stored(let stored):
                return .updated(stored, recheckAfter: recheckAfter)
            case .unchanged(let stored):
                return .unchanged(stored, recheckAfter: recheckAfter)
            }
        } catch ParticipantBundleError.unsupportedSchema(_) {
            return .updateRequired(recheckAfter: recheckAfter)
        } catch ParticipantBundleError.exceedsHardLimit(_) {
            return .failed(.exceedsHardLimit, retryAfter: nil)
        } catch let error as ParticipantBundleError {
            return .failed(.rejected(error), retryAfter: nil)
        } catch {
            return .failed(.storage, retryAfter: nil)
        }
    }

    private func confirmNotModified(_ response: HTTPURLResponse, recheckAfter: TimeInterval) async -> PublishedBundleCheckOutcome {
        guard let sha256 = response.value(forHTTPHeaderField: "Nexus-Bundle-Sha256"),
              let version = response.value(forHTTPHeaderField: "Nexus-Bundle-Version").flatMap(Int64.init)
        else {
            return .failed(.missingIntegrityHeaders, retryAfter: nil)
        }
        do {
            let stored = try await store.confirmNotModified(
                bundleVersion: version,
                sha256: sha256,
                etag: response.value(forHTTPHeaderField: "ETag")
            )
            return .unchanged(stored, recheckAfter: recheckAfter)
        } catch is PublishedBundleStoreError {
            return .failed(.notModifiedMismatch, retryAfter: nil)
        } catch {
            return .failed(.storage, retryAfter: nil)
        }
    }

    // MARK: - Headers

    /// 200 の照合ヘッダー。1つでも欠けていれば nil（検証できないものとして採用しない）。
    static func integrityHeaders(_ response: HTTPURLResponse) -> ParticipantBundleHeaders? {
        guard let sha256 = response.value(forHTTPHeaderField: "Nexus-Bundle-Sha256"),
              let length = response.value(forHTTPHeaderField: "Nexus-Bundle-Length").flatMap(Int.init),
              let version = response.value(forHTTPHeaderField: "Nexus-Bundle-Version").flatMap(Int64.init),
              let schema = response.value(forHTTPHeaderField: "Nexus-Bundle-Schema")
        else {
            return nil
        }
        return ParticipantBundleHeaders(
            sha256: sha256,
            byteLength: length,
            bundleVersion: version,
            schemaVersion: schema,
            etag: response.value(forHTTPHeaderField: "ETag")
        )
    }

    /// `Nexus-Recheck-After` を 60〜3600 秒に収める。無い・数値として読めなければ 300 秒（規則10）。
    static func recheckInterval(_ value: String?) -> TimeInterval {
        guard let value, let seconds = Int(value.trimmingCharacters(in: .whitespaces)) else {
            return defaultRecheckSeconds
        }
        return min(max(TimeInterval(seconds), recheckRange.lowerBound), recheckRange.upperBound)
    }

    /// `Retry-After`（秒数または HTTP-date、RFC 9110 §10.2.3）。読めなければ nil。
    static func retryAfterInterval(_ value: String?, now: Date = Date()) -> TimeInterval? {
        guard let value = value?.trimmingCharacters(in: .whitespaces), !value.isEmpty else { return nil }
        if let seconds = Int(value) {
            return TimeInterval(max(seconds, 0))
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        guard let date = formatter.date(from: value) else { return nil }
        return max(date.timeIntervalSince(now), 0)
    }
}

extension PublishedBundleSource {
    /// 取得クライアントが保存した現在の版と、このプロセスでの確認の状態を返す。
    static func fetcher(_ fetcher: PublishedBundleFetcher) -> PublishedBundleSource {
        PublishedBundleSource(current: { try await fetcher.snapshot() })
    }
}

// MARK: - 上限付きの受信

/// 受信を途中で止めた理由。
enum CappedStop: Equatable, Sendable {
    case missingIntegrityHeaders
    case unsupportedMajor
    case exceedsHardLimit
}

struct CappedResponse: Sendable {
    let response: HTTPURLResponse
    let body: Data
    let stop: CappedStop?
}

/// 本体を受信しながら展開後のバイト数を数え、上限を超えたら中断する（E2-5 §6 規則8）。
///
/// 200 では、照合ヘッダーが欠けている・`Nexus-Bundle-Length` が上限を超える・未知のメジャー版の場合、
/// 本体を受信せずに止める。`URLSession` は `Content-Encoding` を展開してから渡すため、数えるのは
/// 展開後のバイト数である。
final class CappedDataTask: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let limit: Int
    private let lock = NSLock()
    private var body = Data()
    private var response: HTTPURLResponse?
    private var stop: CappedStop?
    private var continuation: CheckedContinuation<CappedResponse, Error>?

    private init(limit: Int) {
        self.limit = limit
    }

    static func run(_ request: URLRequest, session: URLSession, limit: Int) async throws -> CappedResponse {
        let receiver = CappedDataTask(limit: limit)
        let task = session.dataTask(with: request)
        task.delegate = receiver
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                receiver.lock.withLock { receiver.continuation = continuation }
                task.resume()
            }
        } onCancel: {
            task.cancel()
        }
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard let http = response as? HTTPURLResponse else {
            completionHandler(.cancel)
            return
        }
        let stop = Self.stopBeforeBody(http, limit: limit)
        lock.withLock {
            self.response = http
            self.stop = stop
        }
        completionHandler(stop == nil ? .allow : .cancel)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let exceeded: Bool = lock.withLock {
            guard stop == nil else { return false }
            if body.count + data.count > limit {
                stop = .exceedsHardLimit
                body = Data()
                return true
            }
            body.append(data)
            return false
        }
        if exceeded {
            dataTask.cancel()
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        let (continuation, result): (CheckedContinuation<CappedResponse, Error>?, Result<CappedResponse, Error>) = lock.withLock {
            let continuation = self.continuation
            self.continuation = nil
            // 自分で止めた場合は、キャンセルのエラーではなく止めた理由を返す。
            if let response, stop != nil || error == nil {
                return (continuation, .success(CappedResponse(response: response, body: body, stop: stop)))
            }
            return (continuation, .failure(error ?? URLError(.badServerResponse)))
        }
        continuation?.resume(with: result)
    }

    /// 200 のときだけ、本体を受け取る前に止める条件を調べる。
    private static func stopBeforeBody(_ response: HTTPURLResponse, limit: Int) -> CappedStop? {
        guard response.statusCode == 200 else { return nil }
        guard let headers = PublishedBundleFetcher.integrityHeaders(response) else {
            return .missingIntegrityHeaders
        }
        if headers.byteLength > limit {
            return .exceedsHardLimit
        }
        if ParticipantBundleValidator.semanticMajorVersion(of: headers.schemaVersion) != ParticipantBundleValidator.supportedMajorVersion {
            return .unsupportedMajor
        }
        return nil
    }
}
