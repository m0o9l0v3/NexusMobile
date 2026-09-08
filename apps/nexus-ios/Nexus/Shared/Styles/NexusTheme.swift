import SwiftUI

enum NexusTheme {
    static let contentPadding: CGFloat = 20
    static let sectionSpacing: CGFloat = 20
    static let cardCornerRadius: CGFloat = 16

    static let surface = Color("Surface")
    static let border = Color("NexusBorder")
    static let tintSurface = Color.accentColor.opacity(0.12)
    static let eventAccent = Color(red: 1, green: 141 / 255, blue: 40 / 255)
    static let cardShadow = Color.black.opacity(0.07)
}

extension View {
    func nexusCard() -> some View {
        background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: NexusTheme.cardCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: NexusTheme.cardCornerRadius, style: .continuous)
                    .stroke(NexusTheme.border, lineWidth: 1)
            }
            .shadow(color: NexusTheme.cardShadow, radius: 5, y: 2)
    }
}
