import Foundation

/// Map タブの状態。
///
/// 経路目的地には**一切触れない**。地点を閲覧しただけで進行中の案内先が
/// 変わってはならないため（#85 M14）。
@MainActor
@Observable
final class MapStore {
    private(set) var selection: MapSelection?
    private(set) var detailState: MapSpotDetailState

    /// 検索オーバーレイの表示状態（Figma `2563:1628` / `2575:2019`）。
    var isSearchActive = false

    private let client: MapContentClient

    init(
        client: MapContentClient,
        initialSelection: MapSelection? = nil,
        initialDetailState: MapSpotDetailState = .none
    ) {
        self.client = client
        self.selection = initialSelection
        self.detailState = initialDetailState
    }

    func select(_ selection: MapSelection) async {
        self.selection = selection
        await loadDetail(for: selection.canonicalSpotID)
    }

    func clearSelection() {
        selection = nil
        detailState = .none
    }

    func retryDetail() async {
        guard let canonicalSpotID = selection?.canonicalSpotID else { return }
        await loadDetail(for: canonicalSpotID)
    }

    func surfaceContext() -> MapSurfaceContext {
        MapSurfaceContext(focusedSpotID: selection?.canonicalSpotID, selectedFloorID: nil)
    }

    private func loadDetail(for canonicalSpotID: CanonicalSpotID) async {
        detailState = .loading(canonicalSpotID)
        do {
            switch try await client.spotDetail(canonicalSpotID) {
            case .fresh(let presentation):
                detailState = .loaded(presentation)
            case .saved(let presentation, let metadata):
                detailState = .saved(presentation, metadata)
            case .unknownSpot(let unknownID):
                // 要求された ID をそのまま保持する。別地点へ置換しない。
                detailState = .unknown(unknownID)
            }
        } catch is CancellationError {
            detailState = .none
        } catch {
            detailState = .failed(canonicalSpotID, client.failureMessage)
        }
    }
}
