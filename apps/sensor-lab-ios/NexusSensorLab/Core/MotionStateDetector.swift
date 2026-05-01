import Foundation

struct MotionStateDetector {
    // フィルタ後高度の差分に対するしきい値(メートル)
    let threshold: Double

    init(threshold: Double = 0.05) {
        self.threshold = threshold
    }

    func detect(previous: Double?, current: Double) -> MotionState {
        guard let previous else { return .stationary }
        let delta = current - previous

        if delta >= threshold {
            return .ascending
        } else if delta <= -threshold {
            return .descending
        } else {
            return .stationary
        }
    }
}
