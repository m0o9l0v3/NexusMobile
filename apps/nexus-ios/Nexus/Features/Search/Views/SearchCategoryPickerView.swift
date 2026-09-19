import SwiftUI

/// Figma `2646:1643` CategoryFilter。Figma 上は iOS 標準の Segmented control なので
/// `Picker` + `.segmented` を使う。独自チップは作らない。
///
/// アクセシビリティ用の大きな文字サイズでは segmented がつぶれるため、
/// メニュー形式へ切り替える。選択状態は色だけでなく選択トレイトでも伝える。
struct SearchCategoryPickerView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let categories: [SearchCategoryID]
    let selection: SearchCategoryID?
    let onSelect: (SearchCategoryID?) -> Void

    private var binding: Binding<String> {
        Binding(
            get: { selection?.rawValue ?? Self.allTag },
            set: { newValue in
                onSelect(newValue == Self.allTag ? nil : SearchCategoryID(rawValue: newValue))
            }
        )
    }

    private static let allTag = "__all__"

    var body: some View {
        // PickerStyle は型が異なるため三項演算子で選べない。ブランチで分ける。
        Group {
            if dynamicTypeSize.prefersVerticalControls {
                picker.pickerStyle(.menu)
            } else {
                picker.pickerStyle(.segmented)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel("種別で絞り込む")
        .accessibilityValue(selection?.displayName ?? "すべて")
    }

    private var picker: some View {
        Picker("種別で絞り込む", selection: binding) {
            Text("すべて").tag(Self.allTag)
            ForEach(categories) { category in
                Text(category.displayName).tag(category.rawValue)
            }
        }
    }
}
