import MapKit
import SwiftUI

/// SwiftUI の MapKit で構内を描く描画面（M1-5）。
///
/// 建物の形（`MapPolygon`）・ラベル・ピン（`Annotation`）はアプリが持つ座標から描く。
/// Apple の地図タイルは背景にすぎず、通信できずタイルが読めなくても構内の表示は欠けない（#24 で検証）。
/// ズームに応じたピン・地点名の出し分けは `CampusMapZoomPolicy`（#26）。
/// 選んだ地点と所在する建物の強調、その地点へのカメラの移動は `CampusMapFocus`（#28）。
/// ピンを選ぶと `mapSpotSelectionHandler` で Map タブへ伝える（§5.1-3）。建物の Spot のピンは
/// ズームに関わらず出るので、建物はピンから選べる。建物のラベルは、ピンの地点名と重なって
/// シミュレーターで選べなかったため選べる部品にしていない。
/// 現在地の青い点と追従は `CurrentLocationStore`（#29、環境から受け取る）。利用者が地図を動かす・拡大縮小すると
/// 追従を止める。地点を選んでカメラを移したときも止める（次の点でカメラを引き戻さない）。
/// 地図を描けないとき（読込中・掲載なし・失敗）の表示は `MapSurfaceStateView`（#31）。
struct MapKitMapSurfaceView: View {
    let content: CampusMapContent
    let context: MapSurfaceContext
    /// 正式な地図データでないときに表示する注記。nil なら出さない。
    let provisionalNotice: String?

    @State private var position: MapCameraPosition
    /// 表示中の南北の幅（度）。カメラの移動が終わるたびに更新する。
    @State private var visibleLatitudeDelta: Double?
    /// 最後に止まったカメラ。追従を始めるときに、利用者が動かした位置をそのまま置き直すのに使う。
    @State private var lastCamera: MapCamera?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.mapSpotSelectionHandler) private var selectSpotHandler
    @Environment(\.scenePhase) private var scenePhase
    @Environment(CurrentLocationStore.self) private var currentLocation: CurrentLocationStore?

    init(content: CampusMapContent, context: MapSurfaceContext, provisionalNotice: String? = nil) {
        self.content = content
        self.context = context
        self.provisionalNotice = provisionalNotice
        let position = Self.initialPosition(for: content)
        _position = State(initialValue: position)
        _visibleLatitudeDelta = State(initialValue: position.region?.span.latitudeDelta)
    }

    private var zoomLevel: CampusMapZoomPolicy.Level {
        guard let policy = CampusMapZoomPolicy(content: content),
              let visibleLatitudeDelta
        else {
            return .detail
        }
        return policy.level(visibleLatitudeDelta: visibleLatitudeDelta)
    }

    var body: some View {
        Map(position: $position) {
            ForEach(content.buildings) { building in
                let isHighlighted = building.id == highlightedBuildingID
                MapPolygon(building.mkPolygon)
                    .foregroundStyle(isHighlighted ? NexusTheme.eventAccent.opacity(0.28) : Color.accentColor.opacity(0.16))
                    .stroke(
                        isHighlighted ? NexusTheme.eventAccent : Color.accentColor.opacity(0.7),
                        lineWidth: isHighlighted ? 3 : 1.5
                    )

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

            ForEach(visiblePins) { pin in
                // 地点名は Annotation の title に任せずアプリで描く。MapKit の title は地図の文字と一緒に描かれ、
                // 通信断でタイルが読めないと表示されなかった（#24 の検証）。
                Annotation("", coordinate: pin.coordinate.clLocationCoordinate, anchor: .bottom) {
                    Button { selectSpot(pin.spotID) } label: { pinLabel(for: pin) }
                        .buttonStyle(.plain)
                }
                .annotationTitles(.hidden)
            }

            // 現在地。架空の点は置かず、使える点が届いたときだけ描く（#29）。誤差の円は届いた誤差の半径。
            if let fix = currentLocation?.fix {
                MapCircle(center: fix.coordinate.clLocationCoordinate, radius: fix.horizontalAccuracy)
                    .foregroundStyle(Color.accentColor.opacity(0.14))
                    .stroke(Color.accentColor.opacity(0.35), lineWidth: 1)
                Annotation("", coordinate: fix.coordinate.clLocationCoordinate, anchor: .center) {
                    CurrentLocationDot()
                }
                .annotationTitles(.hidden)
            }
        }
        // 構内の表示に Apple の施設情報を混ぜない。
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .onMapCameraChange(frequency: .onEnd) { context in
            visibleLatitudeDelta = context.region.span.latitudeDelta
            lastCamera = context.camera
        }
        // 利用者が動かした・拡大縮小した（MapKit が positionedByUser の位置に置き換える）。追従を止める（決定 3-a）。
        .onChange(of: position.positionedByUser) { _, positionedByUser in
            if positionedByUser {
                currentLocation?.userMovedCamera()
            }
        }
        // 追従を始めたら、利用者が先に動かした位置を同じ位置のままアプリの位置として置き直す。
        // positionedByUser が true のままだと、最初の点を待つ間の地図操作で値が変わらず、追従を止められない
        // （PR #185 のレビュー）。
        .onChange(of: currentLocation?.isFollowing) { _, isFollowing in
            if isFollowing == true, position.positionedByUser, let lastCamera {
                position = .camera(lastCamera)
            }
        }
        .onChange(of: currentLocation?.cameraTarget) { _, target in
            if let target {
                moveCamera(toCurrentLocation: target.coordinate)
            }
        }
        .onAppear { currentLocation?.mapAppeared(contentBounds: content.bounds) }
        .onChange(of: content.bounds) { _, bounds in currentLocation?.mapAppeared(contentBounds: bounds) }
        .onDisappear { currentLocation?.mapDisappeared() }
        // 背面では取得しない。戻っても自動では再開しない（現在地ボタンを押し直す）。
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                currentLocation?.stop()
            }
        }
        // 選んだ地点へ移す。閉じた・地図上に無い地点（target が nil）では動かさない。
        // 選んだまま版が切り替わり、その地点の位置が変わったときも移し直す。
        .onChange(of: CampusMapFocus.target(for: context.focusedSpotID, in: content), initial: true) { _, target in
            moveCamera(to: target?.spotID)
        }
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

    private var highlightedBuildingID: String? {
        CampusMapFocus.highlightedBuildingID(for: context.focusedSpotID, in: content)
    }

    private func moveCamera(to focusedSpotID: CanonicalSpotID?) {
        guard let region = CampusMapFocus.region(
            for: focusedSpotID,
            in: content,
            visibleLatitudeDelta: visibleLatitudeDelta
        ) else {
            return
        }
        // 地点へ移したあとは、次の現在地でカメラを引き戻さない。
        currentLocation?.cameraMovedToSpot()
        setCamera(region)
    }

    /// 追従中の現在地へカメラを移す。縮尺は保つ（すでに寄っていればそのまま）。
    private func moveCamera(toCurrentLocation coordinate: CampusMapCoordinate) {
        guard let region = CurrentLocationCamera.region(
            centeredOn: coordinate,
            in: content,
            visibleLatitudeDelta: visibleLatitudeDelta
        ) else {
            return
        }
        setCamera(region)
    }

    private func setCamera(_ region: CampusMapFocus.Region) {
        let target = MapCameraPosition.region(MKCoordinateRegion(
            center: region.center.clLocationCoordinate,
            span: MKCoordinateSpan(latitudeDelta: region.latitudeDelta, longitudeDelta: region.longitudeDelta)
        ))
        // 視差効果を減らす設定では、動きを見せずに切り替える。
        if reduceMotion {
            position = target
        } else {
            withAnimation(.easeInOut(duration: 0.35)) {
                position = target
            }
        }
    }

    private var visiblePins: [CampusMapContent.Pin] {
        let level = zoomLevel
        return content.pins.filter {
            CampusMapZoomPolicy.showsPin($0, at: level, focusedSpotID: context.focusedSpotID)
        }
    }

    /// ピンを選んだ。Map タブが同じ canonical ID の地点詳細を開く（§5.1-3）。
    private func selectSpot(_ spotID: CanonicalSpotID) {
        selectSpotHandler(spotID)
    }

    private func pinLabel(for pin: CampusMapContent.Pin) -> some View {
        pinMark(isFocused: pin.spotID == context.focusedSpotID)
            // overlay は大きさに含まれないため、anchor はピンの下端のまま変わらない。
            .overlay(alignment: .bottom) {
                if CampusMapZoomPolicy.showsPinName(
                    pin,
                    at: zoomLevel,
                    focusedSpotID: context.focusedSpotID
                ) {
                    Text(pin.name)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, NexusTheme.spacing4)
                        .background(.background.opacity(0.75), in: Capsule())
                        .fixedSize()
                        .offset(y: 18)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                pin.spotID == context.focusedSpotID ? "選択中の地点、\(pin.name)" : "地点、\(pin.name)"
            )
    }

    private func pinMark(isFocused: Bool) -> some View {
        Image(systemName: "mappin.circle.fill")
            .font(.system(size: isFocused ? 30 : 22))
            .symbolRenderingMode(.palette)
            .foregroundStyle(NexusTheme.onAccent, isFocused ? NexusTheme.eventAccent : Color.accentColor)
    }

    private static func initialPosition(for content: CampusMapContent) -> MapCameraPosition {
        guard let bounds = content.bounds else { return .automatic }
        // 端の建物が画面の縁に掛からないよう、範囲の1割強を余白にする。
        let latitudeDelta = max(bounds.maxLatitude - bounds.minLatitude, 0.0005) * 1.25
        // 東西は余白を多めにする。地点名はピンの下に横長に出るため、東西の端のピンの名前が
        // 画面の外へはみ出さないように（#26 の確認で、西端のランドマークの名前が切れていた）。
        let longitudeDelta = max(bounds.maxLongitude - bounds.minLongitude, 0.0005) * 1.6
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
