import SwiftUI

/// Home 検索の種別の絞り込み。検索欄の右に置く1つの丸いボタンで、押すと選択肢のメニューが広がる。
///
/// 以前は「すべて / 教室 / 施設 / サービス」のチップを横に並べていたが、文言で幅が変わり
/// まとまりが無かったため、幅が一定の1ボタンにまとめた。メニューは標準の `Menu` + `Picker` を使い、
/// iOS 26 以降は OS の Liquid Glass のメニューで開く（独自の glass を重ねない）。
/// 絞り込み中はアイコンを強調色にし、右上に点を付ける。何で絞っているかは VoiceOver の値で読み上げる。
struct SearchCategoryFilterMenu: View {
    @ScaledMetric(relativeTo: .body) private var diameter: CGFloat = 56

    let categories: [SearchCategoryID]
    let selection: SearchCategoryID?
    let onSelect: (SearchCategoryID?) -> Void

    private var isFiltering: Bool { selection != nil }

    var body: some View {
        Menu {
            Picker("種別で絞り込む", selection: Binding(get: { selection }, set: onSelect)) {
                Label("すべて", systemImage: "square.grid.2x2")
                    .tag(SearchCategoryID?.none)
                ForEach(categories) { category in
                    Label(category.displayName, systemImage: category.systemImage)
                        .tag(SearchCategoryID?.some(category))
                }
            }
            .pickerStyle(.inline)
        } label: {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.body.weight(.semibold))
                .foregroundStyle(isFiltering ? Color.accentColor : Color.primary)
                .frame(width: diameter, height: diameter)
                .overlay(alignment: .topTrailing) {
                    if isFiltering {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 10, height: 10)
                            .offset(x: -diameter * 0.2, y: diameter * 0.2)
                            .accessibilityHidden(true)
                    }
                }
                .nexusFloatingGlass(in: Circle(), interactive: true)
        }
        .accessibilityLabel("絞り込み")
        .accessibilityValue(selection?.displayName ?? "すべて")
        .accessibilityHint("地点の種別で絞り込みます")
    }
}

private extension SearchCategoryID {
    var systemImage: String {
        switch self {
        case .classroom:
            return "studentdesk"
        case .facility:
            return "building.2"
        case .service:
            return "person.2"
        }
    }
}
