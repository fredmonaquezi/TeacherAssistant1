import SwiftUI

struct SelectableTile: View {

    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                LibraryItemTileView(
                    title: title,
                    systemImage: systemImage
                )

                if isSelected {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.accentColor, lineWidth: 4)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.accentColor)
                        .background(Color.white.clipShape(Circle()))
                        .offset(x: 40, y: -40)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
