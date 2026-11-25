import SwiftUI

/// Figma `2723:2729` GuidanceDetail / Access ・ `2722:5507` Guidance/Access/TransportPicker。
///
/// Figma がシステムのセグメント表示なので `Picker` + `.segmented` を使う。
/// 大きな文字サイズでは潰れるため、メニュー形式へ切り替える。
struct GuidanceAccessArticleView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let article: GuidanceArticle
    var onRelatedPlacesVisibilityChange: (Bool) -> Void = { _ in }
    var onHasRelatedPlacesChange: (Bool) -> Void = { _ in }
    @State private var selectedMode: GuidanceAccessMode?

    private var modes: [GuidanceAccessMode] {
        // Figma の Variant 順（電車・バス・自動車）を保つ。
        GuidanceAccessMode.allCases.filter { mode in
            article.accessSegments.contains { $0.mode == mode }
        }
    }

    private var activeMode: GuidanceAccessMode? {
        selectedMode ?? modes.first
    }

    private var activeSegment: GuidanceAccessSegment? {
        guard let activeMode else { return nil }
        return article.accessSegments.first { $0.mode == activeMode }
    }

    private var modePicker: some View {
        Picker(
            "交通手段",
            selection: Binding(
                get: { activeMode ?? modes[0] },
                set: { newMode in
                    if reduceMotion {
                        selectedMode = newMode
                    } else {
                        withAnimation(.snappy(duration: 0.22)) {
                            selectedMode = newMode
                        }
                    }
                }
            )
        ) {
            ForEach(modes) { mode in
                Text(mode.displayName).tag(mode)
            }
        }
    }

    var body: some View {
        Group {
            if modes.isEmpty {
                NexusStatusView(
                    message: NexusStateMessage(
                        title: "アクセス原稿は未提供です",
                        detail: "電車・バス・自動車の正式なアクセス案内が承認され次第、表示します。",
                        systemImageName: "doc.text"
                    )
                )
            } else {
                // PickerStyle は型が異なるため三項演算子で選べない。ブランチで分ける。
                // 通常サイズでは OS 標準の `.segmented`（iOS 26 は Liquid Glass サム）を使い、二重の glass は重ねない。
                Group {
                    if dynamicTypeSize.prefersVerticalControls {
                        HStack(spacing: NexusTheme.spacing12) {
                            if let activeMode {
                                Image(systemName: activeMode.systemImageName)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(Color.accentColor)
                                    .accessibilityHidden(true)
                            }
                            modePicker
                                .pickerStyle(.menu)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, NexusTheme.spacing16)
                        .padding(.vertical, NexusTheme.spacing8)
                        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                        .nexusFloatingGlass(
                            in: RoundedRectangle(cornerRadius: NexusTheme.primaryCardCornerRadius, style: .continuous),
                            interactive: false
                        )
                    } else {
                        modePicker
                            .pickerStyle(.segmented)
                            .controlSize(.large)
                    }
                }
                .accessibilityLabel("交通手段")
                .accessibilityValue(activeMode?.displayName ?? "")
                .sensoryFeedback(.selection, trigger: activeMode)

                if let activeSegment {
                    VStack(alignment: .leading, spacing: NexusTheme.spacing16) {
                        HStack(spacing: NexusTheme.spacing8) {
                            Circle()
                                .fill(NexusTheme.tintSurface)
                                .frame(width: 32, height: 32)
                                .overlay {
                                    Image(systemName: activeSegment.mode.systemImageName)
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(Color.accentColor)
                                }

                            Text("\(activeSegment.mode.displayName)でのアクセス")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                        }
                        .accessibilityHidden(true)

                        ForEach(activeSegment.sections) { section in
                            GuidanceArticleSectionView(section: section)
                        }
                    }
                    .padding(NexusTheme.spacing16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .nexusCard(cornerRadius: NexusTheme.primaryCardCornerRadius, elevation: .level1)

                    if !activeSegment.relatedPlaces.isEmpty {
                        GuidanceRelatedPlaceView(
                            places: activeSegment.relatedPlaces,
                            unresolvedNote: nil
                        )
                        .id(GuidanceArticleAnchor.relatedPlaces)
                        .onScrollVisibilityChange(threshold: 0.15, onRelatedPlacesVisibilityChange)
                    } else if article.unresolvedRelatedPlaceNote != nil {
                        GuidanceRelatedPlaceView(
                            places: [],
                            unresolvedNote: article.unresolvedRelatedPlaceNote
                        )
                    }
                }

                ForEach(article.sections) { section in
                    GuidanceArticleSectionView(section: section)
                }
            }
        }
        .onChange(of: activeSegment?.relatedPlaces.isEmpty == false, initial: true) { _, hasPlaces in
            onHasRelatedPlacesChange(hasPlaces)
            if !hasPlaces {
                onRelatedPlacesVisibilityChange(false)
            }
        }
    }
}

private extension GuidanceAccessMode {
    var systemImageName: String {
        switch self {
        case .train: "tram.fill"
        case .bus: "bus.fill"
        case .car: "car.fill"
        }
    }
}
