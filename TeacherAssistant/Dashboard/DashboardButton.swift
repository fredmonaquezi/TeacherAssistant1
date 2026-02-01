import SwiftUI

struct DashboardButton: View {
    let title: String
    let systemImage: String
    let color: Color
    let action: (() -> Void)?

    init(title: String, systemImage: String, color: Color, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.color = color
        self.action = action
    }

    // For NavigationLink tiles
    init(title: String, systemImage: String, color: Color) {
        self.title = title
        self.systemImage = systemImage
        self.color = color
        self.action = nil
    }

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    content
                }
            } else {
                content
            }
        }
    }

    private var content: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 32))
                .foregroundColor(.white)

            Text(title)
                .font(.headline)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(color)
        .cornerRadius(16)
    }
}
