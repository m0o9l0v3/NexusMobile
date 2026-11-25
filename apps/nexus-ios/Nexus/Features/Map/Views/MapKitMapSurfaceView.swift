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
    /// 地図の見た目の高さ。本番は `.flat`（改訂4 §6）。`.realistic` は DEBUG の比較用だけ。
    let elevation: MapStyle.Elevation

    @State private var position: MapCameraPosition
    /// 表示中の南北の幅（度）。カメラの移動が終わるたびに更新する。
    @State private var visibleLatitudeDelta: Double?
    /// 最後に止まったカメラ。追従を始めるときに、利用者が動かした位置をそのまま置き直すのに使う。
    @State private var lastCamera: MapCamera?
    /// 表示中のカメラの距離（m）。寄れる限りまで寄ったかを判定するのに使う。
    @State private var cameraDistance: Double?

    @ScaledMetric(relativeTo: .caption2) private var markerLabelClearance = NexusTheme.spacing12
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.mapSpotSelectionHandler) private var selectSpotHandler
    @Environment(\.scenePhase) private var scenePhase
    @Environment(CurrentLocationStore.self) private var currentLocation: CurrentLocationStore?

    init(content: CampusMapContent, context: MapSurfaceContext, provisionalNotice: String? = nil) {
        self.init(content: content, context: context, provisionalNotice: provisionalNotice, elevation: CampusMapCameraPolicy.elevation)
    }

    private init(
        content: CampusMapContent,
        context: MapSurfaceContext,
        provisionalNotice: String?,
        elevation: MapStyle.Elevation
    ) {
        self.content = content
        self.context = context
        self.provisionalNotice = provisionalNotice
        self.elevation = elevation
        let position = Self.initialPosition(for: content, route: context.activeRoute)
        _position = State(initialValue: position)
        _visibleLatitudeDelta = State(initialValue: position.region?.span.latitudeDelta)
    }

    private var zoomLevel: CampusMapZoomPolicy.Level {
        guard let policy = CampusMapZoomPolicy(content: content),
              let visibleLatitudeDelta
        else {
            return .detail
        }
        return policy.level(visibleLatitudeDelta: visibleLatitudeDelta, cameraDistance: cameraDistance)
    }

    var body: some View {
        MapReader { proxy in
            map
                .onTapGesture(coordinateSpace: .local) { location in
                    selectBuilding(at: location, proxy: proxy)
                }
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { _ in
            // 折り返しやステップの展開で地図に使える高さが変わったら、両端を収め直す。
            if context.activeRoute != nil, context.focusedSpotID == nil { fitRoute() }
        }
        // AX では大きくなる目的地ラベルの分もカメラの上側に確保する。
        .safeAreaPadding(.top, emphasizesRouteMarkers ? markerLabelClearance : 0)
        .safeAreaInset(edge: .top, spacing: 0) {
            if context.activeRoute != nil, context.focusedSpotID == nil, let provisionalNotice {
                Text(provisionalNotice)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, NexusTheme.spacing8)
                    .multilineTextAlignment(.center)
                    .background(NexusTheme.cardSurface, in: RoundedRectangle(cornerRadius: NexusTheme.spacing8))
            }
        }
        // 地図表示中は下部に 1 行で国土地理院の出典を常時表示する（K-3 §4.2）。
        // safeAreaInset で配置することで Apple Maps のロゴ・Legal 表記が自動的に本表示の上側へ退避する。
        .safeAreaInset(edge: .bottom, alignment: .leading, spacing: 0) {
            MapGSIAttributionView(reservesCurrentLocationButtonSpace: currentLocation != nil)
        }
    }

    private var map: some View {
        Map(
            position: $position,
            bounds: CampusMapCameraPolicy.cameraBounds,
            interactionModes: CampusMapCameraPolicy.interactionModes
        ) {
            // 建物は輪郭線を描かず、半透明の塗りだけにする（改訂4 §6・H-3・H-4 A）。輪郭線は Apple の建物との
            // 数 m のずれを見せてしまう。塗りは通信断でも形が見えるよう常に描く。
#if DEBUG
            // `-NexusMapOfflineLike`：通信断の見え方の近似（Apple の地図を不透明の面で覆う）。DEBUG のみ。
            if Self.coversTilesForOfflineCheck, let cover = content.bounds?.expanded(byMeters: 3000) {
                MapPolygon(coordinates: [
                    CLLocationCoordinate2D(latitude: cover.minLatitude, longitude: cover.minLongitude),
                    CLLocationCoordinate2D(latitude: cover.minLatitude, longitude: cover.maxLongitude),
                    CLLocationCoordinate2D(latitude: cover.maxLatitude, longitude: cover.maxLongitude),
                    CLLocationCoordinate2D(latitude: cover.maxLatitude, longitude: cover.minLongitude),
                ])
                .foregroundStyle(Color(.secondarySystemBackground))
            }
#endif
            let buildingIDsUsingPinNames = pinNamesVisibleOnBuildings
            ForEach(content.buildings) { building in
                MapPolygon(building.mkPolygon)
                    .foregroundStyle(
                        building.id == highlightedBuildingID ? NexusTheme.mapBuildingSelectedFill : NexusTheme.mapBuildingFill
                    )

                if let name = building.name, !emphasizesRouteMarkers, !buildingIDsUsingPinNames.contains(building.id) {
                    Annotation("", coordinate: building.labelCoordinate.clLocationCoordinate, anchor: .top) {
                        Text(name)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, NexusTheme.spacing4)
                            .background(.background.opacity(0.75), in: Capsule())
                            .padding(.top, NexusTheme.spacing8)
                            .allowsHitTesting(false)
                            .accessibilityLabel("建物、\(name)")
                    }
                    .annotationTitles(.hidden)
                }
            }

            if let route = context.activeRoute {
                routeOverlay(route)
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

            if currentLocation?.phase == .tracking {
                currentLocationAnnotation
            }

            if let route = context.activeRoute {
                marker(route.origin, isOrigin: true)
                marker(route.destination, isOrigin: false)
            }
        }
        // 構内の表示に Apple の施設情報を混ぜず、Apple の建物を目立たなくする（改訂4 §6、`.flat` に決定）。
        .mapStyle(CampusMapCameraPolicy.mapStyle(elevation: elevation))
        .onMapCameraChange(frequency: .onEnd) { context in
            visibleLatitudeDelta = context.region.span.latitudeDelta
            cameraDistance = context.camera.distance
            lastCamera = context.camera
#if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-NexusMapCameraLog") {
                print("NexusMapCamera distance=\(context.camera.distance) latDeltaM=\(context.region.span.latitudeDelta * 111_320) rectH=\(context.rect.size.height)")
            }
#endif
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
        .onAppear {
            currentLocation?.mapAppeared(contentBounds: content.bounds)
            if emphasizesRouteMarkers { fitRoute() }
        }
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
        .onChange(of: RouteCameraTrigger(routeID: context.activeRoute?.requestID, fitRevision: context.routeCameraFitRevision)) {
            fitRoute()
        }
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        // 下端はタブバーに隠れるため、検索欄の下に出す（描画面は下端の safe area を無視して置かれる）。
        .overlay(alignment: .topLeading) {
            if let provisionalNotice, context.activeRoute == nil || context.focusedSpotID != nil {
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

    /// 大きな文字で案内中は始終点のラベルを優先する。地点ピンの操作と読み上げ名は保持する。
    private var emphasizesRouteMarkers: Bool {
        typeSize.isAccessibilitySize && context.activeRoute != nil && context.focusedSpotID == nil
    }

    private struct RouteCameraTrigger: Equatable {
        let routeID: UUID?
        let fitRevision: Int
    }

    @MapContentBuilder
    private var currentLocationAnnotation: some MapContent {
#if DEBUG
        // MapKit の現在地表示にはフィクスチャの座標を渡せない。
        if CurrentLocationFixture.fromLaunchArguments(ProcessInfo.processInfo.arguments) != nil {
            if let fix = currentLocation?.fix {
                MapCircle(center: fix.coordinate.clLocationCoordinate, radius: fix.horizontalAccuracy)
                    .foregroundStyle(Color.accentColor.opacity(0.14))
                    .stroke(Color.accentColor.opacity(0.35), lineWidth: 1)
                Annotation("", coordinate: fix.coordinate.clLocationCoordinate, anchor: .center) {
                    CurrentLocationDot()
                }
                .annotationTitles(.hidden)
            }
        } else {
            UserAnnotation()
        }
#else
        UserAnnotation()
#endif
    }

    @MapContentBuilder
    private func routeOverlay(_ route: ResolvedRoute) -> some MapContent {
        ForEach(route.segments) { segment in
            if segment.coordinates.count >= 2 {
                let outdoor = segment.scope == .outdoor
                let dash: [CGFloat] = outdoor ? [] : [8, 6]
                let lineCap: CGLineCap = outdoor ? .round : .butt
                let line = MapPolyline(coordinates: segment.coordinates.map(\.clLocationCoordinate))
                line.stroke(NexusTheme.onAccent, style: StrokeStyle(lineWidth: outdoor ? 9 : 7, lineCap: lineCap, lineJoin: .round, dash: dash))
                line.stroke(Color.accentColor, style: StrokeStyle(lineWidth: outdoor ? 5 : 4, lineCap: lineCap, lineJoin: .round, dash: dash))
            }
        }
    }

    @MapContentBuilder
    private func marker(_ endpoint: RouteEndpoint, isOrigin: Bool) -> some MapContent {
        if let coordinate = endpoint.coordinate {
            Annotation("", coordinate: coordinate.clLocationCoordinate, anchor: isOrigin ? .center : .bottom) {
                CampusMapRouteMark(isOrigin: isOrigin, emphasizesLabel: emphasizesRouteMarkers)
                    .background { RouteMarkerPriorityView().allowsHitTesting(false).accessibilityHidden(true) }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(RouteAccessibilityText.marker(endpoint, isOrigin: isOrigin))
            }
            .annotationTitles(.hidden)
        }
    }

    private func fitRoute() {
        guard let route = context.activeRoute,
              let region = CampusMapRouteCamera.region(for: route, reservesSpaceAboveMarkers: context.focusedSpotID == nil)
        else { return }
        currentLocation?.cameraMovedToSpot()
        setCamera(region)
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
        let target = Self.position(for: region)
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

    /// 地図の建物をタップした。形を数 m 広げて判定し、その建物の Spot を選ぶ（`CampusMapHitTest`）。
    /// どの建物にも当たらなければ何もしない（選択は解かない）。
    private func selectBuilding(at location: CGPoint, proxy: MapProxy) {
        guard let tapped = proxy.convert(location, from: .local) else { return }
        // 指の大きさに当たる長さ（m）を、タップした位置の縮尺から測る。
        let fingerRadius = CampusMapHitTest.fingerRadiusPoints
        let metersPerPoint = proxy.convert(CGPoint(x: location.x, y: location.y + fingerRadius), from: .local)
            .map { CLLocation(latitude: $0.latitude, longitude: $0.longitude)
                .distance(from: CLLocation(latitude: tapped.latitude, longitude: tapped.longitude)) / fingerRadius }
            ?? 0
        let point = CampusMapCoordinate(latitude: tapped.latitude, longitude: tapped.longitude)
        if let spotID = CampusMapHitTest.spotID(
            at: point,
            in: content,
            toleranceMeters: CampusMapHitTest.toleranceMeters(metersPerPoint: metersPerPoint)
        ) {
            selectSpot(spotID)
        }
    }

    /// ピンを選んだ。Map タブが同じ canonical ID の地点詳細を開く（§5.1-3）。
    private func selectSpot(_ spotID: CanonicalSpotID) {
        selectSpotHandler(spotID)
    }

    private func pinLabel(for pin: CampusMapContent.Pin) -> some View {
        let isFocused = pin.spotID == context.focusedSpotID
        // 案内中は選択ピンの名前を上へ出し、先端付近の経路マーカーにかぶりにくくする。
        let showsNameAbove = isFocused && context.activeRoute != nil
        let nameOffset = NexusTheme.minimumTapTarget + (isFocused ? NexusTheme.spacing8 : NexusTheme.spacing4)
        return CampusMapSpotMark(appearance: pin.appearance, isFocused: isFocused)
            // タップ領域は上と左右に広げ、バッジの下端・選択ピンの先端は座標に置く。
            .frame(width: NexusTheme.minimumTapTarget, height: NexusTheme.minimumTapTarget, alignment: .bottom)
            .contentShape(Rectangle())
            .overlay(alignment: .top) {
                if !emphasizesRouteMarkers, showsPinName(pin) {
                    Text(pin.name)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, NexusTheme.spacing4)
                        .background(.background.opacity(0.75), in: Capsule())
                        .fixedSize()
                        .alignmentGuide(.top) { showsNameAbove ? $0[.bottom] : $0[.top] }
                        .offset(y: showsNameAbove ? 0 : nameOffset)
                        .allowsHitTesting(false)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                isFocused ? "選択中の地点、\(pin.name)" : "地点、\(pin.name)"
            )
    }

    // 同じ座標に同じ名前のカプセルが重なり、ピンの先端とリングを隠すのを防ぐ。
    private var pinNamesVisibleOnBuildings: Set<String> {
        Set(content.pins.compactMap { pin in
            pin.isNamedByBuildingLabel && showsPinName(pin) ? pin.buildingID : nil
        })
    }

    private func showsPinName(_ pin: CampusMapContent.Pin) -> Bool {
        CampusMapZoomPolicy.showsPinName(pin, at: zoomLevel, focusedSpotID: context.focusedSpotID)
    }

    private static func position(for region: CampusMapFocus.Region) -> MapCameraPosition {
        .region(MKCoordinateRegion(center: region.center.clLocationCoordinate,
                                   span: MKCoordinateSpan(latitudeDelta: region.latitudeDelta, longitudeDelta: region.longitudeDelta)))
    }

    private static func initialPosition(for content: CampusMapContent, route: ResolvedRoute?) -> MapCameraPosition {
        if let route, let region = CampusMapRouteCamera.region(for: route) { return position(for: region) }
        guard let bounds = content.bounds else { return .automatic }
#if DEBUG
        // `-NexusMapZoomLimit`：寄れる限りまで寄った状態で開く（改訂4 §6 の確認用）。カメラの範囲で止まる。
        if ProcessInfo.processInfo.arguments.contains("-NexusMapZoomLimit") {
            return .camera(MapCamera(
                centerCoordinate: CLLocationCoordinate2D(
                    latitude: (bounds.minLatitude + bounds.maxLatitude) / 2,
                    longitude: (bounds.minLongitude + bounds.maxLongitude) / 2
                ),
                distance: CampusMapCameraPolicy.expectedClosestDistance
            ))
        }
#endif
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

/// SwiftUI の Annotation には重なり順を指定する API がないため、MapKit の注釈ビューが祖先にあるとき優先度を付ける。
private struct RouteMarkerPriorityView: UIViewRepresentable {
    func makeUIView(context: Context) -> PriorityView { PriorityView() }

    func updateUIView(_ view: PriorityView, context: Context) {
        view.prioritizeAnnotation()
    }

    static func dismantleUIView(_ view: PriorityView, coordinator: ()) {
        view.restorePriority()
    }

    final class PriorityView: UIView {
        private weak var annotation: MKAnnotationView?
        private var previousPriority: MKAnnotationViewZPriority?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window == nil {
                restorePriority()
            } else {
                prioritizeAnnotation()
            }
        }

        func prioritizeAnnotation() {
            guard window != nil else { return }
            var ancestor = superview
            while let view = ancestor {
                if let annotationView = view as? MKAnnotationView {
                    if annotation !== annotationView {
                        restorePriority()
                        annotation = annotationView
                        previousPriority = annotationView.zPriority
                    }
                    annotationView.zPriority = .max
                    return
                }
                ancestor = view.superview
            }
        }

        func restorePriority() {
            // MapKit が注釈ビューを再利用しても、ほかのピンに優先度を引き継がない。
            if let annotation, let previousPriority, annotation.zPriority == .max {
                annotation.zPriority = previousPriority
            }
            annotation = nil
            previousPriority = nil
        }
    }
}

extension CampusMapContent.Building {
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
extension MapKitMapSurfaceView {
    static let coversTilesForOfflineCheck = ProcessInfo.processInfo.arguments.contains("-NexusMapOfflineLike")

    /// `.flat` と `.realistic` を見比べるための DEBUG 専用の入口（改訂4 §6・§7.2 の2）。本番は常に `.flat`。
    static func debugComparing(
        content: CampusMapContent,
        context: MapSurfaceContext,
        provisionalNotice: String?,
        elevation: MapStyle.Elevation
    ) -> MapKitMapSurfaceView {
        MapKitMapSurfaceView(content: content, context: context, provisionalNotice: provisionalNotice, elevation: elevation)
    }
}

extension MapSurfaceProvider {
    /// DEBUG 専用。`elevation` を変えて描く（`-NexusMapElevation realistic`）。
    static func mapKitComparing(content: CampusMapContent, provisionalNotice: String?, elevation: MapStyle.Elevation) -> MapSurfaceProvider {
        MapSurfaceProvider(identifier: "mapkit") { context in
            AnyView(MapKitMapSurfaceView.debugComparing(
                content: content,
                context: context,
                provisionalNotice: provisionalNotice,
                elevation: elevation
            ))
        }
    }
}

/// `.flat`（本番）と `.realistic`（比較用）を切り替えて見る。
private struct ElevationComparisonPreview: View {
    @State private var isRealistic = false
    @State private var focusedSpotID: CanonicalSpotID?

    var body: some View {
        MapKitMapSurfaceView.debugComparing(
            content: .offlineCheck,
            context: MapSurfaceContext(focusedSpotID: focusedSpotID, selectedFloorID: nil),
            provisionalNotice: CampusMapContent.offlineCheckNotice,
            elevation: isRealistic ? .realistic : .flat
        )
        .id(isRealistic)
        .environment(\.mapSpotSelectionHandler) { focusedSpotID = $0 }
        .overlay(alignment: .bottom) {
            Toggle("3D（.realistic）で比較", isOn: $isRealistic)
                .padding(NexusTheme.spacing16)
                .nexusCard()
                .padding(NexusTheme.spacing16)
        }
    }
}

#Preview("検証用の14棟") {
    MapKitMapSurfaceView(
        content: .offlineCheck,
        context: .empty,
        provisionalNotice: CampusMapContent.offlineCheckNotice
    )
}

#Preview("検証用の14棟・.flat と .realistic の比較") {
    ElevationComparisonPreview()
}
#endif
