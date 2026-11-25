import SwiftUI
import UIKit

/// SwiftUI が表示する標準タブバーに、案内記事から戻るときの縦方向の動きだけを加える。
struct GuidanceTabBarTransition: UIViewControllerRepresentable {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let isGuideSelected: Bool
    let showsArticle: Bool

    func makeUIViewController(context: Context) -> Controller {
        let controller = Controller()
        controller.view.isUserInteractionEnabled = false
        return controller
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        let wasShowingSelectedArticle = controller.wasShowingSelectedArticle
        controller.wasShowingSelectedArticle = isGuideSelected && showsArticle
        // 戻るスワイプがキャンセルされたときは NavigationStack のパスが変わらない。
        guard wasShowingSelectedArticle, isGuideSelected, !showsArticle, !reduceMotion else { return }
        controller.revealTabBar()
    }

    final class Controller: UIViewController {
        var wasShowingSelectedArticle = false

        func revealTabBar() {
            guard traitCollection.userInterfaceIdiom == .phone,
                  let tabBar = tabBarController?.tabBar else { return }

            // 標準の表示切り替えやセーフエリアを維持するため、表示中の位置に一時的な変位を加える。
            let slide = CABasicAnimation(keyPath: "transform.translation.y")
            slide.fromValue = tabBar.bounds.height + tabBar.safeAreaInsets.bottom
            slide.toValue = 0
            slide.isAdditive = true
            slide.duration = 0.24
            slide.timingFunction = CAMediaTimingFunction(name: .easeOut)
            tabBar.layer.add(slide, forKey: "guidanceTabBarReveal")
        }
    }
}
