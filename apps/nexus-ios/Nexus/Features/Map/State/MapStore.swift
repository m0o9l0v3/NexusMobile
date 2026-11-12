import Foundation

/// Map タブの状態。
///
/// 経路目的地には**一切触れない**。地点を閲覧しただけで進行中の案内先が
/// 変わってはならないため（#85 M14）。
///
/// 表示する bundle の版は `snapshotBoundary` の向こうで1つに固定され、地図・ピン・地点詳細・
/// Map の検索はすべて同じ版から読む（M1-7）。版を切り替えるのは、地点詳細を閉じたときと
/// Map タブを開き直したときだけで、そのときは Map 全体をまとめて読み直す。
@MainActor
@Observable
final class MapStore {
    private(set) var selection: MapSelection?
    private(set) var detailState: MapSpotDetailState
    /// 表示中の版を切り替えるたびに増える。描画面はこの値が変わったときだけ描く内容を読み直す。
    private(set) var contentRevision = 0

    /// 検索オーバーレイの表示状態（Figma `2563:1628` / `2575:2019`）。
    var isSearchActive = false

    private let client: MapContentClient
    private let snapshotBoundary: MapSnapshotBoundary
    /// Map の検索オーバーレイ。版を切り替えたら同じ条件で読み直す。
    private let overlaySearch: SearchStore?
    /// 地点詳細の読み込みの通し番号。古い読み込みの結果で新しい表示を上書きしない。
    private var detailLoadID = 0

    init(
        client: MapContentClient,
        snapshotBoundary: MapSnapshotBoundary = .none,
        overlaySearch: SearchStore? = nil,
        initialSelection: MapSelection? = nil,
        initialDetailState: MapSpotDetailState = .none
    ) {
        self.client = client
        self.snapshotBoundary = snapshotBoundary
        self.overlaySearch = overlaySearch
        self.selection = initialSelection
        self.detailState = initialDetailState
    }

    func select(_ selection: MapSelection) async {
        self.selection = selection
        await loadDetail(for: selection.canonicalSpotID, showsLoading: true)
    }

    /// 地点詳細を閉じる。閉じた時点が版の切替点になる（M1-7）。
    func clearSelection() async {
        detailLoadID += 1
        selection = nil
        detailState = .none
        await reachSnapshotBoundary()
    }

    /// Map タブを開き直したときに呼ぶ。版の切替点になる（M1-7）。
    func mapTabDidOpen() async {
        await reachSnapshotBoundary()
    }

    func retryDetail() async {
        guard let canonicalSpotID = selection?.canonicalSpotID else { return }
        await loadDetail(for: canonicalSpotID, showsLoading: true)
    }

    func surfaceContext() -> MapSurfaceContext {
        MapSurfaceContext(
            focusedSpotID: selection?.canonicalSpotID,
            selectedFloorID: nil,
            contentRevision: contentRevision
        )
    }

    /// 新しい版があれば、地図・地点詳細・検索をまとめてその版へ切り替える。
    /// 詳細だけ・地図だけを切り替えることはしない。
    private func reachSnapshotBoundary() async {
        guard await snapshotBoundary.advance() else { return }
        contentRevision += 1
        if let canonicalSpotID = selection?.canonicalSpotID {
            // 開いている詳細も同じ版で読み直す。地点自体は変えず、読込中の表示も挟まない。
            await loadDetail(for: canonicalSpotID, showsLoading: false)
        }
        await overlaySearch?.reloadIfLoaded()
    }

    private func loadDetail(for canonicalSpotID: CanonicalSpotID, showsLoading: Bool) async {
        detailLoadID += 1
        let loadID = detailLoadID
        if showsLoading {
            detailState = .loading(canonicalSpotID)
        }
        let newState: MapSpotDetailState
        do {
            switch try await client.spotDetail(canonicalSpotID) {
            case .fresh(let presentation):
                newState = .loaded(presentation)
            case .saved(let presentation, let metadata):
                newState = .saved(presentation, metadata)
            case .unknownSpot(let unknownID):
                // 要求された ID をそのまま保持する。別地点へ置換しない。
                newState = .unknown(unknownID)
            }
        } catch is CancellationError {
            newState = .none
        } catch {
            newState = .failed(canonicalSpotID, client.failureMessage)
        }
        // 読み込み中に別の地点を選んだ・閉じた・版を切り替えた場合は、この結果を捨てる。
        guard loadID == detailLoadID else { return }
        detailState = newState
    }
}
