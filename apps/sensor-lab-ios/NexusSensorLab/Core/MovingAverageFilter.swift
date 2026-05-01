import Foundation

struct MovingAverageFilter {
    private(set) var windowSize: Int
    private var values: [Double] = []

    init(windowSize: Int = 8) {
        self.windowSize = max(1, windowSize)
    }

    mutating func append(_ value: Double) -> Double {
        values.append(value)
        if values.count > windowSize {
            values.removeFirst(values.count - windowSize)
        }
        let sum = values.reduce(0, +)
        return sum / Double(values.count)
    }

    mutating func reset() {
        values.removeAll()
    }
}
