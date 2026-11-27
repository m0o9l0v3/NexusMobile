import MapKit
import SwiftUI

/// 外部タイルが読めなくても、固定した bundle の建物、線、ピンを表示する。
struct RoutePreviewMap: View {
    let route: ResolvedRoute
    let buildings: [CampusMapContent.Building]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Map(initialPosition: position, interactionModes: []) {
#if DEBUG
            if MapKitMapSurfaceView.coversTilesForOfflineCheck,
               let cover = CampusMapContent(buildings: buildings, pins: []).bounds?.expanded(byMeters: 3000) {
                MapPolygon(coordinates: [
                    .init(latitude: cover.minLatitude, longitude: cover.minLongitude),
                    .init(latitude: cover.minLatitude, longitude: cover.maxLongitude),
                    .init(latitude: cover.maxLatitude, longitude: cover.maxLongitude),
                    .init(latitude: cover.maxLatitude, longitude: cover.minLongitude)
                ])
                .foregroundStyle(Color(.secondarySystemBackground))
                .mapOverlayLevel(level: .aboveRoads)
            }
#endif
            ForEach(buildings) { building in
                MapPolygon(building.mkPolygon)
                    .foregroundStyle(NexusTheme.mapBuildingFill)
                    .mapOverlayLevel(level: .aboveRoads)
            }
            ForEach(route.segments) { segment in
                let line = MapPolyline(coordinates: segment.coordinates.map(\.clLocationCoordinate))
                let dash: [CGFloat] = segment.scope == .outdoor ? [] : [6, 4]
                line.stroke(NexusTheme.onAccent, style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round, dash: dash))
                    .mapOverlayLevel(level: .aboveLabels)
                line.stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round, dash: dash))
                    .mapOverlayLevel(level: .aboveLabels)
            }

            if let origin = route.origin.coordinate {
                Annotation("", coordinate: origin.clLocationCoordinate, anchor: .center) {
                    Circle()
                        .fill(NexusTheme.mapRouteOriginPin)
                        .overlay { Circle().strokeBorder(NexusTheme.mapRoutePinCenter, lineWidth: 2) }
                        .frame(width: 15, height: 15)
                }
                .annotationTitles(.hidden)
            }
            if let destination = route.destination.coordinate {
                Annotation("", coordinate: destination.clLocationCoordinate, anchor: .center) {
                    Image(systemName: "mappin")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(NexusTheme.mapRoutePinCenter)
                        .frame(width: 30, height: 30)
                        .background(NexusTheme.mapDestinationPin, in: Circle())
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(CampusMapCameraPolicy.mapStyle(elevation: .flat))
        .transaction { if reduceMotion { $0.animation = nil } }
    }

    private var position: MapCameraPosition {
        guard let region = CampusMapRouteCamera.region(for: route) else { return .automatic }
        return .region(MKCoordinateRegion(
            center: region.center.clLocationCoordinate,
            span: .init(latitudeDelta: region.latitudeDelta, longitudeDelta: region.longitudeDelta)
        ))
    }
}
