#if DEBUG
import SwiftUI

/// 位置情報の権限フローの確認用画面（DEBUG のみ）。
///
/// 地図データが無く、本番の画面にはまだ「現在地を使う」の入口が無い（#29・経路の作業で置く）。
/// それまではこの画面とプレビュー・単体試験だけで確かめる。
/// 起動引数 `-NexusLocationPermissionPreview <case>` で開く（`Case` の rawValue）。
struct LocationPermissionPreviewHost: View {
    enum Case: String, CaseIterable {
        /// 説明を出した直後。
        case explanation
        case deferred
        case denied
        case servicesOff
        case restricted
        case unavailable
        case reducedAccuracy
        case allowed

        var snapshot: LocationPermissionSnapshot {
            switch self {
            case .explanation, .deferred:
                return LocationPermissionSnapshot(authorization: .notDetermined)
            case .denied:
                return LocationPermissionSnapshot(authorization: .denied)
            case .servicesOff:
                return LocationPermissionSnapshot(authorization: .denied, servicesEnabled: false)
            case .restricted:
                return LocationPermissionSnapshot(authorization: .restricted)
            case .unavailable, .allowed:
                return LocationPermissionSnapshot(authorization: .authorizedWhenInUse)
            case .reducedAccuracy:
                return LocationPermissionSnapshot(authorization: .authorizedWhenInUse, accuracy: .reduced)
            }
        }
    }

    let previewCase: Case
    @State private var store: LocationPermissionStore
    @State private var lastHandoff: String?

    init(previewCase: Case) {
        self.previewCase = previewCase
        _store = State(initialValue: LocationPermissionStore(
            provider: PreviewLocationPermissionProvider(snapshot: previewCase.snapshot)
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: NexusTheme.spacing16) {
                    Text("地図の現在地ボタンと、経路の出発地の「現在地」から開く流れの確認用です。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button {
                        Task { await store.requestLocation(for: .showCurrentLocation) }
                    } label: {
                        Label("現在地を使う", systemImage: "location")
                            .frame(maxWidth: .infinity, minHeight: NexusTheme.minimumTapTarget)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    if let lastHandoff {
                        Text(lastHandoff)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(NexusTheme.contentPadding)
            }
            .background(Color(.systemBackground))
            .navigationTitle("現在地")
        }
        .locationPermissionFlow(store)
        .task {
            store.onReady = { _ in lastHandoff = "現在地の表示へ引き継ぎます（#29）" }
            store.onChooseStartManually = { lastHandoff = "出発地を選ぶ画面へ引き継ぎます（S04）" }
            await store.requestLocation(for: .showCurrentLocation)
            switch previewCase {
            case .deferred:
                store.deferExplanation()
            case .unavailable:
                store.reportAcquisitionFailure()
            default:
                break
            }
        }
    }
}

#Preview("説明") { LocationPermissionPreviewHost(previewCase: .explanation) }
#Preview("後で") { LocationPermissionPreviewHost(previewCase: .deferred) }
#Preview("拒否") { LocationPermissionPreviewHost(previewCase: .denied) }
#Preview("サービスオフ") { LocationPermissionPreviewHost(previewCase: .servicesOff) }
#Preview("機能制限") { LocationPermissionPreviewHost(previewCase: .restricted) }
#Preview("取得不能") { LocationPermissionPreviewHost(previewCase: .unavailable) }
#Preview("精度不足") { LocationPermissionPreviewHost(previewCase: .reducedAccuracy) }
#endif
