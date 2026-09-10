import SwiftUI

/// 地図描画面の注入境界。
///
/// Figma の `MapBase / Placeholder` は表示境界であり、本番地図ではない。
/// 実際の描画方式（MapKit / 自前描画 / 構内 SVG）の採用は #85・#24 の判断であり、
/// ここでは決めない。#85 はこのプロトコルへ実地図の View を conform させれば接続できる。
@MainActor
protocol MapSurfaceProviding {
    associatedtype Surface: View

    /// テストで「本番既定が未提供プレースホルダである」ことを描画せずに確認するための識別子。
    var identifier: String { get }

    @ViewBuilder
    func makeSurface(for context: MapSurfaceContext) -> Surface
}

/// 型消去した地図描画面。
///
/// `NexusAppShell` をジェネリックにしないためにこの形を採る
/// （Swift にジェネリック引数の既定値がないため、ジェネリックにすると
/// 既存の `NexusAppShell(homeClient:)` 呼び出しが壊れる）。
struct MapSurfaceProvider: Sendable {
    let identifier: String
    let makeSurface: @MainActor @Sendable (MapSurfaceContext) -> AnyView

    init(
        identifier: String,
        makeSurface: @escaping @MainActor @Sendable (MapSurfaceContext) -> AnyView
    ) {
        self.identifier = identifier
        self.makeSurface = makeSurface
    }
}

extension MapSurfaceProvider {
    /// 本番の既定値。構内地図が未提供であることを明示する。
    static let unavailable = MapSurfaceProvider(identifier: "unavailable") { context in
        AnyView(UnavailableMapSurfaceView(context: context))
    }
}
