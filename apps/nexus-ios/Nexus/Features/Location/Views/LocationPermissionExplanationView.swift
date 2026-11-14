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
    /// 外側の見た目。単独で置くときはカード、下のシート（`.locationPermissionFlow`）の中では枠なし。
    enum Chrome {
        case card
        case plain
    }

    let guidance: LocationPermissionGuidance
    let onAction: (LocationPermissionGuidance.Action) -> Void
    var onDismiss: (() -> Void)?
    var chrome: Chrome = .card

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
        .modifier(StatusChrome(chrome: chrome))
        .accessibilityElement(children: .contain)
    }

    private struct StatusChrome: ViewModifier {
        let chrome: Chrome

        func body(content: Content) -> some View {
            switch chrome {
            case .card:
                content
                    .padding(NexusTheme.spacing16)
                    .nexusCard()
            case .plain:
                content
            }
        }
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

/// 下のシートの寸法。Figma「v1.0 | 現在地UI 下部バー連結 案｜2026-11」の案B（`2812:1710`）。
enum LocationStatusSheetLayout {
    /// 中身が使える高さの上限（画面の高さに対する割合）。超えるのは AX サイズのときだけの想定。
    static let maxContentFraction: CGFloat = 0.6
    static let topPadding: CGFloat = NexusTheme.spacing20
    static let horizontalPadding: CGFloat = NexusTheme.spacing20
    /// 中身の下端とタブバーの上端の間。
    static let bottomPadding: CGFloat = NexusTheme.spacing16

    /// - Parameter containerHeight: シートを差し引く前の画面（タブの中身）の高さ。0 は未計測。
    static func maxContentHeight(containerHeight: CGFloat) -> CGFloat? {
        containerHeight > 0 ? containerHeight * maxContentFraction : nil
    }
}

/// タブバーから伸びる下のシート。中身はセーフエリア（タブバー）の上に置き、面だけをタブバーの下へ伸ばす。
/// iOS 26 では Liquid Glass のタブバーが面の内側にはまって見え、iOS 18 では不透明なタブバーの下に面が続く。
struct LocationStatusSheet<Content: View>: View {
    let maxContentHeight: CGFloat?
    @ViewBuilder let content: Content

    var body: some View {
        // `.frame(maxHeight:)` は上限まで広がってしまうので、中身の高さのまま上限だけを掛ける。
        CappedHeightLayout(maxHeight: maxContentHeight) { content }
            .padding(.top, LocationStatusSheetLayout.topPadding)
            .padding(.horizontal, LocationStatusSheetLayout.horizontalPadding)
            .padding(.bottom, LocationStatusSheetLayout.bottomPadding)
            .background {
                NexusAttachedSheetBackground()
                    .padding(.bottom, NexusTheme.attachedSheetMargin)
                    .ignoresSafeArea(edges: .bottom)
            }
            .padding(.horizontal, NexusTheme.attachedSheetMargin)
    }
}

/// 子に「上限までの高さ」を提案し、子が返した高さをそのまま使う（上限より低ければ縮む）。
/// 子の `ViewThatFits` は、収まれば枠なしの中身（自分の高さ）、収まらなければ ScrollView（上限の高さ）を選ぶ。
struct CappedHeightLayout: Layout {
    var maxHeight: CGFloat?

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let child = subviews.first else { return .zero }
        return child.sizeThatFits(cappedProposal(proposal))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(width: bounds.width, height: bounds.height))
    }

    private func cappedProposal(_ proposal: ProposedViewSize) -> ProposedViewSize {
        guard let maxHeight else { return proposal }
        return ProposedViewSize(width: proposal.width, height: min(proposal.height ?? maxHeight, maxHeight))
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
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let guidance = store.guidance {
                    let panel = LocationPermissionStatusView(
                        guidance: guidance,
                        onAction: handle,
                        onDismiss: { store.dismissGuidance() },
                        chrome: .plain
                    )
                    // 大きな文字で上限を超えるときだけ、シートの中でスクロールさせる（シートの形は切らない）。
                    LocationStatusSheet(maxContentHeight: LocationStatusSheetLayout.maxContentHeight(containerHeight: containerHeight)) {
                        ViewThatFits(in: .vertical) {
                            panel
                            ScrollView { panel }
                                .scrollIndicatorsFlash(onAppear: true)
                        }
                    }
                }
            }
            // シートを差し引く前の高さを測る（safeAreaInset の外側）。内側で測ると、シートが出るたびに
            // 測った高さが縮み、上限が下がって標準の文字サイズでもスクロールになっていた。
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { containerHeight = $0 }
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
