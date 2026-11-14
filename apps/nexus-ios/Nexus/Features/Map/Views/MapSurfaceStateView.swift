import SwiftUI

/// 地図を描けないときの描画面（#31）：読込中・掲載なし・失敗・未提供。
///
/// 4つとも同じ置き場所（地図の面の中央、検索欄とタブバーの間）と同じ部品（`NexusStatusView`）を使い、
/// 文言・記号・再試行の有無だけを変える。読込中だけは文言のパネルを出さず、進捗を示す。
/// 地点を選んでいれば、その地点 ID を出したままにする（他画面から来た地点の強調を失わない）。
struct MapSurfaceStateView: View {
    enum Kind: Equatable {
        case loading
        case message(NexusStateMessage, allowsRetry: Bool)
    }

    let kind: Kind
    let focusedSpotID: CanonicalSpotID?
    var onRetry: (() -> Void)?

    /// 描画面は safe area の上に重ねた検索欄の下にあり、下端の safe area は無視して置かれる（`MapRootView`）ため、
    /// 検索欄とタブバーの分を自分で空ける。検索欄は文字の大きさに合わせて高くなるので、上側も合わせて広げる。
    @ScaledMetric(relativeTo: .body) private var scaledTopClearance: CGFloat = 88
    private static let maxTopClearance: CGFloat = 240
    private static let bottomClearance: CGFloat = 112

    private var topClearance: CGFloat {
        min(scaledTopClearance, Self.maxTopClearance)
    }

    var body: some View {
        ZStack {
            NexusTheme.surface

            // 大きな文字で収まらないときだけスクロールさせる。
            ViewThatFits(in: .vertical) {
                content
                ScrollView { content }
                    .scrollIndicatorsFlash(onAppear: true)
            }
            .padding(.top, topClearance)
            .padding(.bottom, Self.bottomClearance)
        }
    }

    private var content: some View {
        VStack(spacing: NexusTheme.spacing12) {
            switch kind {
            case .loading:
                VStack(spacing: NexusTheme.spacing12) {
                    ProgressView()
                        .controlSize(.large)
                    Text(MapContentStateMessage.loadingTitle)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(MapContentStateMessage.loadingTitle)
                .accessibilityAddTraits(.updatesFrequently)

            case .message(let message, let allowsRetry):
                NexusStatusView(message: message, onRetry: allowsRetry ? onRetry : nil)
            }

            if let focusedSpotID {
                Text("選択中の地点ID：\(focusedSpotID.rawValue)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, NexusTheme.spacing16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension MapSurfaceStateView.Kind {
    /// 地図の状態から。地図があるとき（`loaded`）は nil で、MapKit の描画面を出す。
    init?(_ state: MapContentState) {
        switch state {
        case .loading:
            self = .loading
        case .loaded:
            return nil
        case .empty(let message):
            self = .message(message, allowsRetry: false)
        case .failed(let message):
            self = .message(message, allowsRetry: true)
        }
    }
}

#if DEBUG
#Preview("読込中") {
    MapSurfaceStateView(kind: .loading, focusedSpotID: nil)
}

#Preview("掲載なし") {
    MapSurfaceStateView(kind: MapSurfaceStateView.Kind(.empty(MapContentStateMessage.notPublished))!, focusedSpotID: nil)
}

#Preview("失敗・地点選択中") {
    MapSurfaceStateView(
        kind: MapSurfaceStateView.Kind(.failed(MapContentStateMessage.loadFailed))!,
        focusedSpotID: CanonicalSpotID(rawValue: "mb_2f_cl_001"),
        onRetry: {}
    )
}
#endif
