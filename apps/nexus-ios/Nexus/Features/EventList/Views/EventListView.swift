import SwiftUI

/// C. すべてのイベント（Home v1.0 下書き、Figma `2799:1665` / `2799:1728` / `2799:1785`）。
/// 公開中のすべての枠を時間で絞らずに、日ごと・開始の早い順に並べる。中止の枠も「中止」として残す。
struct EventListView: View {
    @StateObject private var store: EventListStore
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.appRouteRequestHandler) private var onRouteRequest

    init(client: EventListClient, initialState: EventListViewState = .idle) {
        _store = StateObject(wrappedValue: EventListStore(client: client, initialState: initialState))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                content
            }
            .padding(.horizontal, NexusTheme.contentPadding)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color(.systemBackground))
        // スクロールすると見出しが上部に縮む（Figma `2799:1785`）。
        .navigationTitle("すべてのイベント")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await store.refresh()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await store.refresh() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .publishedBundleCheckDidFinish)) { _ in
            Task { await store.refresh() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch store.state {
        case .idle, .loading:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 160)
                .accessibilityLabel("イベントを読み込み中")

        case .loaded(let snapshot):
            loaded(snapshot)

        case .saved(let snapshot, let metadata):
            // 保存版の表示中は、今の Home と同じバナーを上に出す（Figma 未作成。下書き §4 質問7）。
            SavedHomeBannerView(metadata: metadata)
            loaded(snapshot)

        case .empty(let message, let saved):
            if let saved {
                SavedHomeBannerView(metadata: saved)
            }
            HomeStatusView(message: message)

        case .failed(let message):
            HomeStatusView(message: message) {
                Task { await store.retry() }
            }
        }
    }

    @ViewBuilder
    private func loaded(_ snapshot: EventListSnapshot) -> some View {
        if !snapshot.categories.isEmpty {
            EventListCategoryFilterView(
                categories: snapshot.categories,
                selectedCategoryID: $store.selectedCategoryID
            )
        }

        Text(snapshot.summaryText(in: store.selectedCategoryID))
            .font(.footnote)
            .foregroundStyle(.secondary)

        let days = store.visibleDays
        if days.isEmpty {
            HomeStatusView(message: EventListClient.noEventsInCategoryMessage)
        } else {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(days) { day in
                    EventListDaySectionView(day: day, onRouteRequest: onRouteRequest)
                }
            }
        }
    }
}

/// カテゴリの絞り込み（Figma `EventListDraft/CategoryChip`）。選択中は塗り＋チェックで示す（色だけに頼らない）。
private struct EventListCategoryFilterView: View {
    let categories: [EventListCategory]
    @Binding var selectedCategoryID: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(id: nil, name: "すべて")
                ForEach(categories) { category in
                    chip(id: category.id, name: category.name)
                }
            }
            .padding(.trailing, NexusTheme.contentPadding)
        }
        .scrollClipDisabled()
        .accessibilityLabel("カテゴリで絞り込む")
    }

    private func chip(id: String?, name: String) -> some View {
        let isSelected = selectedCategoryID == id
        return Button {
            selectedCategoryID = id
        } label: {
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.footnote.weight(.semibold))
                        .accessibilityHidden(true)
                }
                Text(name)
                    .font(isSelected ? .subheadline.weight(.semibold) : .subheadline)
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(.horizontal, 16)
            .frame(minHeight: NexusTheme.minimumTapTarget)
            .background(isSelected ? Color.accentColor : NexusTheme.surface, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct EventListDaySectionView: View {
    let day: EventListDay
    let onRouteRequest: (AppRouteRequest) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(day.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                if day.isToday {
                    Text("今日")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(NexusTheme.tintSurface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            VStack(spacing: 0) {
                ForEach(Array(day.slots.enumerated()), id: \.element.id) { index, slot in
                    if index > 0 {
                        Divider()
                    }
                    EventListSlotRowView(
                        slot: slot,
                        onDetails: {
                            onRouteRequest(.eventDetails(eventID: slot.eventID, canonicalSpotID: slot.canonicalSpotID))
                        },
                        onRoute: {
                            onRouteRequest(.route(destinationSpotID: slot.canonicalSpotID))
                        }
                    )
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: NexusTheme.cardCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: NexusTheme.cardCornerRadius, style: .continuous)
                    .stroke(Color(.separator), lineWidth: 1)
            }
        }
    }
}

/// Figma `EventListHIG/SlotRow`。行のタップでイベント詳細、ボタンでマップの経路。中止はボタンなし。
struct EventListSlotRowView: View {
    @ScaledMetric(relativeTo: .headline) private var timeColumnWidth: CGFloat = 56

    let slot: EventListSlot
    let onDetails: () -> Void
    let onRoute: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(slot.startText)
                            .font(.headline.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                        Text("〜\(slot.endText)")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: timeColumnWidth, alignment: .leading)

                    VStack(alignment: .leading, spacing: 3) {
                        if let categoryName = slot.categoryName {
                            Text(categoryName)
                                .font(.caption2)
                                .foregroundStyle(Color.accentColor)
                        }
                        Text(slot.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                        Label(slot.locationName, systemImage: "mappin.and.ellipse")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let modeText = slot.modeText {
                            Text(modeText)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        // 色だけに頼らず文字で示す（EV-O1）。
                        if slot.isCancelled {
                            Label(slot.cancelNote.map { "中止：\($0)" } ?? "中止", systemImage: "xmark.octagon")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.red)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .labelStyle(.titleAndIcon)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityText)
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("イベント詳細への遷移要求を送ります")
                .accessibilityAction(.default, onDetails)

                // 中止の枠は会場へ向かう必要がないため、経路の操作を出さない。
                if !slot.isCancelled {
                    Button(action: onRoute) {
                        MapRouteButtonLabel()
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 12)
                            .frame(minHeight: NexusTheme.minimumTapTarget)
                            .background(NexusTheme.tintSurface, in: Capsule())
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, timeColumnWidth + 12)
                    .accessibilityHint("この地点への経路要求を送ります")
                }
            }

            Image(systemName: "chevron.right")
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture(perform: onDetails)
    }

    private var accessibilityText: String {
        let parts = [
            slot.isCancelled ? "中止" : nil,
            "\(slot.startText)から\(slot.endText)",
            slot.categoryName,
            slot.title,
            slot.locationName,
            slot.modeText,
            slot.isCancelled ? slot.cancelNote : nil,
        ]
        return parts.compactMap { $0 }.joined(separator: "、")
    }
}
