import SwiftUI

struct DashboardCard<Content: View>: View {
    let title: String
    var icon: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let icon = icon {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .foregroundStyle(Theme.lagoon)
                        .font(.headline)
                    Text(title)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.primary)
                }
            } else {
                Text(title)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            content
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Theme.card)
        )
        .shadow(color: Theme.shadowColor.opacity(0.5), radius: 10, x: 0, y: 5)
    }
}
