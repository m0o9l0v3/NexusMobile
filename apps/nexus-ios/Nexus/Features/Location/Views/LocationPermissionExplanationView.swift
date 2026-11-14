import SwiftUI

/// OS の許可ダイアログの前に出す、アプリの説明（#25）。
///
/// 「位置情報を使う」を押したときだけ OS のダイアログへ進む。「後で」では OS のダイアログを出さない。
struct LocationPermissionExplanationView: View {
    let onAllow: () -> Void
    let onLater: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: NexusTheme.spacing20) {
                VStack(alignment: .leading, spacing: NexusTheme.spacing12) {
                    Image(systemName: "location.circle")
                        .font(.largeTitle)
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)

                    Text("現在地を使いますか？")
                        .font(.title2.weight(.bold))
                        .accessibilityAddTraits(.isHeader)

                    Text("現在地を地図に表示し、経路案内の出発地に使います。")
                        .font(.body)
                }

                VStack(alignment: .leading, spacing: NexusTheme.spacing12) {
                    ForEach(Self.points, id: \.text) { point in
                        Label {
                            Text(point.text)
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: point.systemImageName)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                VStack(spacing: NexusTheme.spacing12) {
                    Button(action: onAllow) {
                        Text("位置情報を使う")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(NexusTheme.onAccent)
                            .frame(maxWidth: .infinity, minHeight: NexusTheme.minimumTapTarget)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button(action: onLater) {
                        Text("後で")
                            .font(.body)
                            .frame(maxWidth: .infinity, minHeight: NexusTheme.minimumTapTarget)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            .padding(NexusTheme.contentPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.systemBackground))
    }

    private struct Point {
        let text: String
        let systemImageName: String
    }

    /// プライバシーの説明。Info.plist の `NSLocationWhenInUseUsageDescription` と同じ内容にする。
    private static let points: [Point] = [
        Point(text: "使うのは、アプリを使っている間だけです。", systemImageName: "iphone"),
        Point(text: "現在地は Nexus のサーバーへ送りません。", systemImageName: "lock"),
        Point(text: "許可しなくても、出発地を自分で選んで使えます。", systemImageName: "hand.point.up.left"),
    ]
}

/// 位置情報を使えないときの理由と、次の操作（設定を開く・出発地を自分で選ぶ・もう一度試す）。
///
/// #31（Map の位置情報オフの状態）もこの表示を使える。
struct LocationPermissionStatusView: View {
    let guidance: LocationPermissionGuidance
    let onAction: (LocationPermissionGuidance.Action) -> Void
    var onDismiss: (() -> Void)?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // AX サイズでは記号を見出しの上に置き、文字の幅を確保する。
        let header = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: NexusTheme.spacing8))
            : AnyLayout(HStackLayout(alignment: .top, spacing: NexusTheme.spacing12))

        VStack(alignment: .leading, spacing: NexusTheme.spacing12) {
            HStack(alignment: .top, spacing: NexusTheme.spacing12) {
                header {
                    Image(systemName: guidance.message.systemImageName)
                        .font(.title3)
                        .foregroundStyle(NexusTheme.cautionAccent)
                        .frame(width: 28)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: NexusTheme.spacing4) {
                        Text(guidance.message.title)
                            .font(.headline)
                            .fixedSize(horizontal: false, vertical: true)
                        if let detail = guidance.message.detail {
                            Text(detail)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                }

                if let onDismiss {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: NexusTheme.minimumTapTarget, height: NexusTheme.minimumTapTarget)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.nexusPressableCircle)
                    .accessibilityLabel("閉じる")
                }
            }

            VStack(spacing: NexusTheme.spacing8) {
                ForEach(Array(guidance.actions.enumerated()), id: \.offset) { index, action in
                    actionButton(action, isPrimary: index == 0)
                }
            }
        }
        .padding(NexusTheme.spacing16)
        .nexusCard()
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func actionButton(_ action: LocationPermissionGuidance.Action, isPrimary: Bool) -> some View {
        let button = Button {
            onAction(action)
        } label: {
            Label(Self.title(for: action), systemImage: Self.systemImageName(for: action))
                .font(.body.weight(isPrimary ? .semibold : .regular))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, NexusTheme.spacing4)
                .foregroundStyle(isPrimary ? NexusTheme.onAccent : Color.accentColor)
                .frame(maxWidth: .infinity, minHeight: NexusTheme.minimumTapTarget)
        }
        .controlSize(.large)

        if isPrimary {
            button.buttonStyle(.borderedProminent)
        } else {
            button.buttonStyle(.bordered)
        }
    }

    static func title(for action: LocationPermissionGuidance.Action) -> String {
        switch action {
        case .openSettings: return "設定を開く"
        case .retry: return "もう一度試す"
        case .chooseStartManually: return "出発地を自分で選ぶ"
        }
    }

    private static func systemImageName(for action: LocationPermissionGuidance.Action) -> String {
        switch action {
        case .openSettings: return "gear"
        case .retry: return "arrow.clockwise"
        case .chooseStartManually: return "mappin.and.ellipse"
        }
    }
}

extension View {
    /// 位置情報の権限フローを画面に付ける：アプリの説明のシートと、使えないときの理由の表示。
    ///
    /// 「現在地を使う」などの操作では `store.requestLocation(for:)` を呼ぶ。
    func locationPermissionFlow(_ store: LocationPermissionStore) -> some View {
        modifier(LocationPermissionFlowModifier(store: store))
    }
}

private struct LocationPermissionFlowModifier: ViewModifier {
    let store: LocationPermissionStore
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var containerHeight: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { containerHeight = $0 }
            .safeAreaInset(edge: .bottom) {
                if let guidance = store.guidance {
                    let panel = LocationPermissionStatusView(
                        guidance: guidance,
                        onAction: handle,
                        onDismiss: { store.dismissGuidance() }
                    )
                    // 大きな文字で画面に収まらないときだけスクロールさせる（下の画面を隠しきらない）。
                    ViewThatFits(in: .vertical) {
                        panel
                        ScrollView { panel }
                    }
                    .frame(maxHeight: containerHeight > 0 ? containerHeight * 0.6 : nil)
                    .padding(.horizontal, NexusTheme.contentPadding)
                    .padding(.bottom, NexusTheme.spacing8)
                }
            }
            .sheet(isPresented: explanationBinding) {
                LocationPermissionExplanationView(
                    onAllow: { Task { await store.confirmExplanation() } },
                    onLater: { store.deferExplanation() }
                )
                .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium, .large])
                .presentationDragIndicator(.visible)
            }
            // 設定アプリから戻ったとき、変わった設定を読み直す。
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task { await store.refresh() }
                }
            }
    }

    /// スワイプで閉じたときも「後で」と同じに扱う（OS のダイアログは出さない）。
    private var explanationBinding: Binding<Bool> {
        Binding(
            get: { store.isExplanationPresented },
            set: { isPresented in
                if !isPresented, store.isExplanationPresented {
                    store.deferExplanation()
                }
            }
        )
    }

    private func handle(_ action: LocationPermissionGuidance.Action) {
        switch action {
        case .openSettings:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                openURL(url)
            }
        case .retry:
            store.retryAcquisition()
        case .chooseStartManually:
            store.chooseStartManually()
        }
    }
}
