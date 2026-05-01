import Foundation

struct SensorSample: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let pressure: Double
    let relativeAltitude: Double
    let filteredAltitude: Double
    let state: MotionState

    init(
        id: UUID = UUID(),
        timestamp: Date,
        pressure: Double,
        relativeAltitude: Double,
        filteredAltitude: Double,
        state: MotionState
    ) {
        self.id = id
        self.timestamp = timestamp
        self.pressure = pressure
        self.relativeAltitude = relativeAltitude
        self.filteredAltitude = filteredAltitude
        self.state = state
    }
}
