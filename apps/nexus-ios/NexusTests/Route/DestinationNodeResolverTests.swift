import XCTest
@testable import Nexus

final class DestinationNodeResolverTests: XCTestCase {
    private typealias F = RoutingTestFixtures
    private let room = RoutingDestination.Kind.room(buildingID: "b", floorID: "1F")

    private var nodes: [RoutingNode] {
        [F.node("outside"), F.node("land", kind: "destination"), F.node("inside", F.first),
         F.node("desk", F.first, kind: "destination"), F.node("upper", F.second, kind: "destination"),
         F.node("other", .indoor(buildingID: "otherBuilding", floorID: "1F"), kind: "destination")]
    }

    func testRoomLandmarkAndBuildingResolveDeclaredDestinationNodes() {
        let destinations = [
            RoutingDestination(id: "room", kind: room, accessNodeID: "desk"),
            RoutingDestination(id: "landmark", kind: .landmark, accessNodeID: "land"),
            RoutingDestination(id: "b", kind: .building, accessNodeID: "upper")
        ]
        let engine = F.engine(nodes, [F.entrance("main", "outside", "inside")], destinations)
        for (id, node) in [("room", "desk"), ("landmark", "land"), ("b", "upper")] {
            XCTAssertEqual(engine.resolveDestinationNode(for: id, approach: .fromOutdoor), .success(node))
        }
    }

    func testMissingAccessNodeAndBuildingPrimaryEntranceCardinality() {
        let destinations = [RoutingDestination(id: "b", kind: .building, accessNodeID: nil),
                            RoutingDestination(id: "room", kind: room, accessNodeID: nil),
                            RoutingDestination(id: "landmark", kind: .landmark, accessNodeID: nil)]
        let side = F.entrance("side", "outside", "inside", primary: false)
        let main = F.entrance("main", "land", "inside")
        let noPrimary = F.engine(nodes, [side], destinations)
        for destination in destinations {
            XCTAssertEqual(noPrimary.resolveDestinationNode(for: destination.id, approach: .fromOutdoor),
                           .failure(.notRoutable(.missingAccessNode)))
        }
        let one = F.engine(nodes, [side, main], destinations)
        XCTAssertEqual(one.resolveDestinationNode(for: "b", approach: .fromIndoor(buildingID: "b")), .success("land"))
        let two = F.engine(nodes, [main, F.entrance("second", "outside", "inside")], destinations)
        XCTAssertEqual(two.resolveDestinationNode(for: "b", approach: .fromOutdoor),
                       .failure(.notRoutable(.ambiguousPrimaryEntrance)))
    }

    func testInvalidAccessNodeRejectsWrongKindLocationAndUnknownID() {
        let invalid: [(String, RoutingDestination.Kind, [String])] = [
            ("room", room, ["missing", "DESK", "inside", "land", "upper", "other", "door"]),
            ("landmark", .landmark, ["missing", "outside", "desk"]),
            ("b", .building, ["missing", "inside", "land", "other"])
        ]
        for (id, kind, accessIDs) in invalid {
            for accessID in accessIDs {
                let destination = RoutingDestination(id: id, kind: kind, accessNodeID: accessID)
                let engine = F.engine(nodes, [F.entrance("door", "outside", "inside")], [destination])
                XCTAssertEqual(engine.resolveDestinationNode(for: id, approach: .fromOutdoor),
                               .failure(.notRoutable(.invalidAccessNode(accessID))), "\(id) → \(accessID)")
            }
        }
    }

    func testEntranceApproachIsInferredFromStartBuilding() throws {
        let engine = F.engine(nodes, [F.entrance("door", "outside", "inside"),
                                      F.edge("corridor", "upper", "inside", kind: .transition(label: "下り")),
                                      F.edge("link", "other", "outside", kind: .transition(label: "接続"))])
        for (approach, expected) in [(RoutingApproach.fromOutdoor, "outside"), (.fromIndoor(buildingID: "b"), "inside"),
                                     (.fromIndoor(buildingID: "otherBuilding"), "outside")] {
            XCTAssertEqual(engine.resolveDestinationNode(for: "door", approach: approach), .success(expected))
        }
        F.assertSamePoint(engine.findRoute(from: "outside", toDestination: "door"), at: "outside")
        XCTAssertEqual(try F.found(engine.findRoute(from: "upper", toDestination: "door")).nodeIDs, ["upper", "inside"])
        XCTAssertEqual(try F.found(engine.findRoute(from: "other", toDestination: "door")).nodeIDs, ["other", "outside"])
    }

    func testDestinationToDestinationSharesNodeAndAcceptsEntranceStartApproach() throws {
        let engine = F.engine(nodes, [F.entrance("door", "outside", "inside"),
                                      F.edge("hall", "inside", "desk", kind: .walkingPath(location: F.first, pathKind: "corridor"))],
                              [RoutingDestination(id: "R", kind: room, accessNodeID: "desk"),
                               RoutingDestination(id: "r", kind: room, accessNodeID: "desk")])
        F.assertSamePoint(engine.findRoute(fromDestination: "R", toDestination: "r"), at: "desk", floors: ["1F"])
        let path = try F.found(engine.findRoute(fromDestination: "door", toDestination: "r"))
        XCTAssertEqual(path.nodeIDs, ["outside", "inside", "desk"])
        let indoor = try F.found(engine.findRoute(fromDestination: "door", toDestination: "r", approach: .fromIndoor(buildingID: "b")))
        XCTAssertEqual(indoor.nodeIDs, ["inside", "desk"])
    }

    func testUnknownDestinationNodeAndWalkingEdgeAreNeverSubstituted() {
        let engine = F.engine(nodes, [F.edge("p", "outside", "land")],
                              [RoutingDestination(id: "Room", kind: room, accessNodeID: "desk")])
        for id in ["room", "missing", "desk", "p"] {
            XCTAssertEqual(engine.resolveDestinationNode(for: id, approach: .fromOutdoor), .failure(.unknownDestination(id)))
            XCTAssertEqual(engine.findRoute(from: "land", toDestination: id), .failure(.unknownDestination(id)))
            XCTAssertEqual(engine.findRoute(fromDestination: id, toDestination: "Room"), .failure(.unknownDestination(id)))
        }
        XCTAssertEqual(engine.findRoute(from: "Land", toDestination: "Room"), .failure(.unknownNode("Land")))
    }
}
