import Foundation
import Network

/// 参加者向け API の接続先（M1-3）。
///
/// ビルド構成ごとの xcconfig の `NEXUS_API_BASE_URL` を、Info.plist の `NexusAPIBaseURL` 経由で読む。
/// 値が空・URL として不完全なら nil で、アプリは「未接続」のまま起動する。
struct NexusAPIConfiguration: Equatable, Sendable {
    static let infoPlistKey = "NexusAPIBaseURL"

    let baseURL: URL

    /// `GET /api/v2/bundle`（E2-5 §4.1）。
    var bundleEndpoint: URL {
        baseURL.appendingPathComponent("api/v2/bundle")
    }

    init?(infoDictionary: [String: Any]?) {
        guard let raw = infoDictionary?[Self.infoPlistKey] as? String else { return nil }
        self.init(rawValue: raw)
    }

    /// xcconfig は `//` 以降をコメントとして捨てるため、書き方を誤ると `https:` だけが残る。
    /// scheme と host が揃った http(s) の URL だけを受け付け、不完全な値で通信しない。
    init?(rawValue: String) {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(), ["https", "http"].contains(scheme),
              let host = components.host, !host.isEmpty,
              let url = components.url
        else {
            return nil
        }
        baseURL = url
    }
}

/// 公開データの bundle を取得・保存し、画面へ渡す一式（#109）。
///
/// 接続先が設定されているときだけ作る。Map・探すの Client は `source` から読む。
struct PublishedBundleRuntime: Sendable {
    let store: PublishedBundleStore
    let fetcher: PublishedBundleFetcher
    let scheduler: PublishedBundleUpdateScheduler
    private let pathMonitor: NWPathMonitor

    var source: PublishedBundleSource {
        var source = PublishedBundleSource.fetcher(fetcher)
        source.recheck = { [scheduler] in await scheduler.recheck() }
        return source
    }

    init(configuration: NexusAPIConfiguration, directory: URL = PublishedBundleRuntime.defaultDirectory) {
        store = PublishedBundleStore(directory: directory)
        let fetcher = PublishedBundleFetcher(endpoint: configuration.bundleEndpoint, store: store, notifiesExpiry: true)
        self.fetcher = fetcher
        scheduler = PublishedBundleUpdateScheduler(check: {
            let outcome = await fetcher.check()
            await PublishedBundleExpiryNotice.post()
            return outcome
        })
        pathMonitor = NWPathMonitor()
        pathMonitor.pathUpdateHandler = { [weak fetcher] path in
            let isAvailable = path.status == .satisfied
            Task { await fetcher?.networkAvailabilityChanged(isAvailable: isAvailable) }
        }
        pathMonitor.start(queue: DispatchQueue(label: "Nexus.BundleNetworkPath"))
    }

    /// Application Support 配下。ユーザーが見る書類ではないため Documents には置かない。
    static var defaultDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PublishedBundle", isDirectory: true)
    }
}
