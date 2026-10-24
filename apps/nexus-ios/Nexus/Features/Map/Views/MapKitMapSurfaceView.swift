import MapKit
import SwiftUI

/// SwiftUI の MapKit で構内を描く描画面（M1-5）。
///
/// 建物の形（`MapPolygon`）・ラベル・ピン（`Annotation`）はアプリが持つ座標から描く。
/// Apple の地図タイルは背景にすぎず、通信できずタイルが読めなくても構内の表示は欠けない（#24 で検証）。
/// 見た目は #84 の承認前の仮のもので、#26・#85 で整える。
struct MapKitMapSurfaceView: View {
    let content: CampusMapContent
    let context: MapSurfaceContext
    /// 正式な地図データでないときに表示する注記。nil なら出さない。
    let provisionalNotice: String?

    @State private var position: MapCameraPosition

    init(content: CampusMapContent, context: MapSurfaceContext, provisionalNotice: String? = nil) {
        self.content = content
        self.context = context
        self.provisionalNotice = provisionalNotice
        _position = State(initialValue: Self.initialPosition(for: content))
    }

    var body: some View {
        Map(position: $position) {
            ForEach(content.buildings) { building in
                MapPolygon(building.mkPolygon)
                    .foregroundStyle(Color.accentColor.opacity(0.16))
                    .stroke(Color.accentColor.opacity(0.7), lineWidth: 1.5)

                if let name = building.name {
                    Annotation("", coordinate: building.labelCoordinate.clLocationCoordinate, anchor: .center) {
                        Text(name)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, NexusTheme.spacing4)
                            .background(.background.opacity(0.75), in: Capsule())
                            .accessibilityLabel("建物、\(name)")
                    }
                    .annotationTitles(.hidden)
                }
            }

            ForEach(content.pins) { pin in
                // 地点名は Annotation の title に任せずアプリで描く。MapKit の title は地図の文字と一緒に描かれ、
                // 通信断でタイルが読めないと表示されなかった（#24 の検証）。
                Annotation("", coordinate: pin.coordinate.clLocationCoordinate, anchor: .bottom) {
                    pinMark(isFocused: pin.spotID == context.focusedSpotID)
                        // overlay は大きさに含まれないため、anchor はピンの下端のまま変わらない。
                        .overlay(alignment: .bottom) {
                            Text(pin.name)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.primary)
                                .padding(.horizontal, NexusTheme.spacing4)
                                .background(.background.opacity(0.75), in: Capsule())
                                .fixedSize()
                                .offset(y: 18)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("地点、\(pin.name)")
                }
                .annotationTitles(.hidden)
            }
        }
        // 構内の表示に Apple の施設情報を混ぜない。
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        // 下端はタブバーに隠れるため、検索欄の下に出す（描画面は下端の safe area を無視して置かれる）。
        .overlay(alignment: .topLeading) {
            if let provisionalNotice {
                Text(provisionalNotice)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, NexusTheme.spacing8)
                    .padding(.vertical, NexusTheme.spacing4)
                    .background(.background.opacity(0.85), in: Capsule())
                    .padding(.top, 84)
                    .padding(.leading, NexusTheme.spacing16)
            }
        }
    }

    private func pinMark(isFocused: Bool) -> some View {
        Image(systemName: "mappin.circle.fill")
            .font(.system(size: isFocused ? 30 : 22))
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, isFocused ? NexusTheme.eventAccent : Color.accentColor)
    }

    private static func initialPosition(for content: CampusMapContent) -> MapCameraPosition {
        guard let bounds = content.bounds else { return .automatic }
        // 端の建物が画面の縁に掛からないよう、範囲の1割強を余白にする。
        let latitudeDelta = max(bounds.maxLatitude - bounds.minLatitude, 0.0005) * 1.25
        let longitudeDelta = max(bounds.maxLongitude - bounds.minLongitude, 0.0005) * 1.25
        return .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (bounds.minLatitude + bounds.maxLatitude) / 2,
                longitude: (bounds.minLongitude + bounds.maxLongitude) / 2
            ),
            span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        ))
    }
}

private extension CampusMapContent.Building {
    /// 穴を内側の多角形として持つ MapKit の多角形。
    var mkPolygon: MKPolygon {
        let interiors = holes.map { ring in
            MKPolygon(coordinates: ring.map(\.clLocationCoordinate), count: ring.count)
        }
        return MKPolygon(
            coordinates: outline.map(\.clLocationCoordinate),
            count: outline.count,
            interiorPolygons: interiors
        )
    }
}

extension MapSurfaceProvider {
    /// MapKit の描画面。`provisionalNotice` は正式な地図データでないときの注記。
    static func mapKit(content: CampusMapContent, provisionalNotice: String? = nil) -> MapSurfaceProvider {
        MapSurfaceProvider(identifier: "mapkit") { context in
            AnyView(MapKitMapSurfaceView(
                content: content,
                context: context,
                provisionalNotice: provisionalNotice
            ))
        }
    }
}

#if DEBUG
#Preview("検証用の14棟") {
    MapKitMapSurfaceView(
        content: .offlineCheck,
        context: .empty,
        provisionalNotice: CampusMapContent.offlineCheckNotice
    )
}
#endif
