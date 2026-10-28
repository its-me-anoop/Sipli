import SwiftUI
import UIKit

/// Home Screen icons the user can pick in Settings. Classic is the primary
/// icon; the rest are alternate icons compiled from `WaterQuest/AppIcons/`
/// (rendered by `scripts/app-icon/render-variants.swift`).
enum AppIconChoice: String, CaseIterable, Identifiable {
    case classic, midnight, ocean, mint, sunrise, berry

    var id: String { rawValue }

    var title: String {
        switch self {
        case .classic: return "Classic"
        case .midnight: return "Midnight"
        case .ocean: return "Ocean"
        case .mint: return "Mint"
        case .sunrise: return "Sunrise"
        case .berry: return "Berry"
        }
    }

    /// Name for `setAlternateIconName`; `nil` restores the primary icon.
    var alternateName: String? { self == .classic ? nil : "AppIcon-\(title)" }

    /// Small flattened copy of the icon for the picker (alternate icons
    /// can't be loaded as images at runtime).
    var previewAsset: String { "IconPreview-\(title)" }
}

/// Keeps the Home Screen icon in line with the user's pick and Spooky Season.
@MainActor
enum AppIconManager {
    static let preferenceKey = "preferredAppIcon"
    static let spookyIconName = "AppIcon-Spooky"

    nonisolated static var preferred: AppIconChoice {
        AppIconChoice(rawValue: UserDefaults.standard.string(forKey: preferenceKey) ?? "") ?? .classic
    }

    /// The icon that should be showing: the Spooky icon while the user is in
    /// the event, otherwise their own pick.
    nonisolated static func desiredIconName(spooky: Bool, preferred: AppIconChoice) -> String? {
        spooky ? spookyIconName : preferred.alternateName
    }

    /// Switches the icon only when it differs, because iOS shows its own
    /// "icon changed" alert on every switch. iOS only allows this while the
    /// app is in the foreground, so it waits a moment after activation.
    static func sync(spooky: Bool, preferred: AppIconChoice = preferred) {
        let desired = desiredIconName(spooky: spooky, preferred: preferred)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            let app = UIApplication.shared
            guard app.supportsAlternateIcons,
                  app.applicationState == .active,
                  app.alternateIconName != desired
            else { return }
            do {
                try await app.setAlternateIconName(desired)
            } catch {
                // Not fatal: the next launch or foreground tries again.
                print("App icon change failed: \(error.localizedDescription)")
            }
        }
    }
}

/// Settings card for choosing the Home Screen icon.
struct AppIconPickerCard: View {
    @AppStorage(AppIconManager.preferenceKey) private var preferredRaw = AppIconChoice.classic.rawValue
    @Environment(\.spookyTheme) private var spookyTheme

    private var preferred: AppIconChoice { AppIconChoice(rawValue: preferredRaw) ?? .classic }
    private let columns = [GridItem(.adaptive(minimum: 76), spacing: 14)]

    var body: some View {
        DashboardCard(title: "App Icon", icon: "app.badge.fill") {
            VStack(alignment: .leading, spacing: 14) {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(AppIconChoice.allCases) { choice in
                        iconButton(choice)
                    }
                }
                if spookyTheme {
                    Label("Spooky Season shows the Spooky icon until 7 November. Your pick returns afterwards, or when you leave the event.",
                          systemImage: "moon.stars.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func iconButton(_ choice: AppIconChoice) -> some View {
        let selected = choice == preferred
        return Button {
            guard !selected else { return }
            Haptics.selection()
            preferredRaw = choice.rawValue
            AppIconManager.sync(spooky: spookyTheme, preferred: choice)
        } label: {
            VStack(spacing: 6) {
                Image(choice.previewAsset)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .stroke(selected ? Theme.lagoon : Color.clear, lineWidth: 2.5)
                            .padding(-3)
                    )
                    .overlay(alignment: .bottomTrailing) {
                        if selected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.body)
                                .foregroundStyle(.white, Theme.lagoon)
                                .offset(x: 6, y: 6)
                        }
                    }
                    .shadow(color: Theme.shadowColor.opacity(0.4), radius: 4, x: 0, y: 2)
                Text(choice.title)
                    .font(.caption.weight(selected ? .semibold : .regular))
                    .foregroundStyle(selected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(choice.title) app icon")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
