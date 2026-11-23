import Foundation

extension RoutingGraph {
    static func build(from map: MapGeoJSON) -> RoutingGraph {
        var nodes: [RoutingNode] = []
        var edges: [RoutingEdge] = []
        var destinations: [RoutingDestination] = []
        var malformed: [Diagnostic] = []
        for feature in map.features {
            switch feature.featureType {
            case "indoor_node", "outdoor_node":
                if let node = feature.routingNode { nodes.append(node); continue }
            case "walking_path", "formal_entrance":
                if let edge = feature.routingEdge { edges.append(edge); continue }
            case "building", "room", "landmark":
                if let destination = feature.routingDestination { destinations.append(destination); continue }
            default:
                continue
            }
            malformed.append(Diagnostic(id: feature.id, reason: .malformedFeature))
        }
        return RoutingGraph(nodes: nodes, edges: edges, destinations: destinations, malformedFeatures: malformed)
    }
}

private extension MapGeoJSON.Feature {
    var indoorLocation: RoutingLocation? {
        guard let buildingID, let floorID else { return nil }
        return .indoor(buildingID: buildingID, floorID: floorID)
    }

    var routingNode: RoutingNode? {
        guard let nodeKind, point != nil else { return nil }
        if featureType == "outdoor_node" {
            return RoutingNode(id: id, location: .campus, nodeKind: nodeKind)
        }
        guard let indoorLocation else { return nil }
        return RoutingNode(id: id, location: indoorLocation, nodeKind: nodeKind)
    }

    var routingDestination: RoutingDestination? {
        let kind: RoutingDestination.Kind
        switch featureType {
        case "room":
            guard let buildingID, let floorID else { return nil }
            kind = .room(buildingID: buildingID, floorID: floorID)
        case "landmark": kind = .landmark
        case "building": kind = .building
        default: return nil
        }
        return RoutingDestination(id: id, kind: kind, accessNodeID: accessNodeID)
    }

    var routingEdge: RoutingEdge? {
        guard let accessibility, let access = RoutingAccessibility(rawValue: accessibility) else { return nil }
        if featureType == "formal_entrance" {
            guard let outsideNodeID, let insideNodeID, let buildingID, let floorID, let isPrimary, let point
            else { return nil }
            let kind = RoutingEdge.Kind.formalEntrance(buildingID: buildingID, floorID: floorID,
                                                      isPrimary: isPrimary, name: name, openingHours: openingHours)
            return RoutingEdge(id: id, fromNodeID: outsideNodeID, toNodeID: insideNodeID, kind: kind,
                               bidirectional: true, accessibility: access, distanceMeters: 0,
                               estimatedSeconds: 0, coordinates: [point])
        }

        guard let fromNodeID, let toNodeID, let pathKind, let distanceMeters, let estimatedSeconds,
              let bidirectional, case .lineString(let positions) = geometry else { return nil }
        let location: RoutingLocation
        switch scope {
        case "campus" where buildingID == nil && floorID == nil: location = .campus
        case "indoor":
            guard let indoorLocation else { return nil }
            location = indoorLocation
        default: return nil
        }
        return RoutingEdge(id: id, fromNodeID: fromNodeID, toNodeID: toNodeID,
                           kind: .walkingPath(location: location, pathKind: pathKind), bidirectional: bidirectional,
                           accessibility: access, distanceMeters: distanceMeters,
                           estimatedSeconds: estimatedSeconds, coordinates: positions)
    }
}
