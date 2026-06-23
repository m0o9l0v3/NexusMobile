import SwiftUI

struct DetectionStateView: View {
    let state: MotionState

    var body: some View {
        GroupBox("Detection State") {
            HStack {
                Text("現在状態")
                Spacer()
                Text(state.displayName)
                    .bold()
            }
        }
    }
}
