import SwiftUI

struct ManualRouteOriginSheetView: View {
    let store: ManualRouteOriginStore
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        NavigationStack {
            ScrollView {
                if let session = store.session {
                    VStack(alignment: .leading, spacing: NexusTheme.sectionSpacing) {
                        switch session.state {
                        case .loading:
                            destinationHeader(nil, id: session.destinationSpotID)
                            ProgressView("出発地を読み込み中")
                        case .failed(let message):
                            destinationHeader(nil, id: session.destinationSpotID)
                            NexusStatusView(message: message) { Task { await store.retryLoad() } }
                        case let .empty(destination, id, _, metadata, message):
                            destinationHeader(destination, id: id)
                            if let metadata { SavedContentBannerView(metadata: metadata) }
                            NexusStatusView(message: message)
                        case .loaded(let snapshot):
                            destinationHeader(snapshot.destination, id: snapshot.destinationSpotID)
                            if let metadata = snapshot.savedMetadata { SavedContentBannerView(metadata: metadata) }
                            VStack(alignment: .leading, spacing: 0) {
                                heading("出発地の候補")
                                ForEach(snapshot.options) { option in
                                    originRow(option, session: session)
                                }
                            }
                        }
                    }
                    .monospacedDigit()
                    .padding(NexusTheme.contentPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .background(Color(.systemBackground))
            .navigationTitle("出発地を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: store.cancelSelection) {
                        Text("キャンセル")
                            .frame(minWidth: NexusTheme.minimumTapTarget, minHeight: NexusTheme.minimumTapTarget)
                    }
                }
            }
        }
    }

    private func heading(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .accessibilityAddTraits(.isHeader)
    }

    private func destinationHeader(_ destination: SpotSummary?, id: CanonicalSpotID) -> some View {
        VStack(alignment: .leading, spacing: NexusTheme.spacing8) {
            heading("目的地")
            if let destination {
                SpotSummaryLabelView(summary: destination, titleFont: .headline)
                if destination.locationText.isEmpty {
                    // 共通ラベルは未提供の場所もすでに読み上げる。
                    Text("場所は未提供").font(.footnote).foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            } else {
                Text(id.rawValue).font(.headline)
            }
            if let notice = store.provisionalNotice {
                Text(notice).font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private func originRow(_ option: ManualRouteOriginOption, session: ManualRouteOriginStore.Session) -> some View {
        let selected = session.currentOriginSpotID == option.id
        let isDestination = session.destinationSpotID == option.id
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: NexusTheme.spacing4))
            : AnyLayout(HStackLayout(spacing: NexusTheme.spacing8))
        return Button {
            Task { await store.selectOrigin(option) }
        } label: {
            layout {
                SpotSummaryLabelView(summary: option.summary)
                if selected {
                    HStack(spacing: NexusTheme.spacing4) {
                        Image(systemName: "checkmark")
                            .foregroundStyle(NexusTheme.onAccent)
                            .padding(NexusTheme.spacing4)
                            .background(Color.accentColor, in: Circle())
                        Text("選択中")
                    }
                    .foregroundStyle(Color.accentColor)
                }
                if isDestination { Text("目的地").foregroundStyle(.secondary) }
            }
            .font(.footnote.weight(.semibold))
            .padding(.vertical, NexusTheme.spacing4)
            .nexusTappableRow(minHeight: 56)
        }
        .buttonStyle(.nexusPressableRow)
        .accessibilityLabel(option.summary.accessibilityLabelText)
        .accessibilityValue(isDestination ? "目的地" : "")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityHint("この地点を出発地にして経路を確認します")
    }
}
