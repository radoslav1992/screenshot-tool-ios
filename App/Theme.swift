import SwiftUI

enum Palette {
    static let ink = Color(red: 0.09, green: 0.13, blue: 0.25)
    static let coral = Color(red: 0.97, green: 0.39, blue: 0.29)
    static let blue = Color(red: 0.23, green: 0.39, blue: 0.91)
    static let canvas = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? .systemGroupedBackground : UIColor(red: 0.98, green: 0.97, blue: 0.95, alpha: 1)
    })
    static let card = Color(uiColor: .secondarySystemGroupedBackground)
}
struct PrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity).padding(18)
            .background(Palette.blue, in: RoundedRectangle(cornerRadius: 20))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View { VStack(alignment: .leading, spacing: 10) { content }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 26)) }
}
struct Eyebrow: View {
    let text: String
    var body: some View { Text(text.uppercased()).font(.caption.weight(.bold)).tracking(2).foregroundStyle(.secondary) }
}
struct EmptyCard: View {
    let symbol: String; let title: String; let detail: String
    var body: some View { Card { VStack(alignment: .leading, spacing: 14) {
        Image(systemName: symbol).font(.largeTitle).foregroundStyle(Palette.blue)
        Text(title).font(.title2.bold()); Text(detail).foregroundStyle(.secondary)
    }.padding(.vertical, 16) } }
}
struct ShotImage: View {
    let url: URL?
    var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image { image.resizable().scaledToFill() }
            else { ZStack { Palette.blue.opacity(0.07); Image(systemName: phase.error == nil ? "viewfinder" : "photo.badge.exclamationmark").font(.largeTitle).foregroundStyle(Palette.blue.opacity(0.5)) } }
        }.accessibilityHidden(true)
    }
}
