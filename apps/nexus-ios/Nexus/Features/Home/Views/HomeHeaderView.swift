import SwiftUI

struct HomeHeaderView: View {
    var body: some View {
        VStack(spacing: 4) {
            Text("Nexus")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.primary)

            Text("今日はどこへ行きますか？")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .padding(.bottom, 4)
        .accessibilityElement(children: .combine)
        .accessibilitySortPriority(100)
    }
}
