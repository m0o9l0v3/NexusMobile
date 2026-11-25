import SwiftUI

/// Figma `2723:2729` GuidanceDetail / Access ・ `2722:5507` Guidance/Access/TransportPicker。
///
/// Figma がシステムのセグメント表示なので `Picker` + `.segmented` を使う。
/// 大きな文字サイズでは潰れるため、メニュー形式へ切り替える。
struct GuidanceAccessArticleView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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
                set: { selectedMode = $0 }
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
                Group {
                    if dynamicTypeSize.prefersVerticalControls {
                        modePicker.pickerStyle(.menu)
                    } else {
                        modePicker.pickerStyle(.segmented)
                    }
                }
                .accessibilityLabel("交通手段")
                .accessibilityValue(activeMode?.displayName ?? "")

                if let activeSegment {
                    ForEach(activeSegment.sections) { section in
                        GuidanceArticleSectionView(section: section)
                    }

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
