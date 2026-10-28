import SwiftUI

/// A newer Sipli on the App Store.
struct AppUpdate: Identifiable, Equatable {
    let version: String
    let releaseNotes: String
    let storeURL: URL
    var id: String { version }
}

/// Asks the App Store whether a newer Sipli is out, and decides when to
/// offer it: at most every 12 hours, and after "Later" the same version
/// waits 3 days before asking again.
@MainActor
final class AppUpdateChecker: ObservableObject {
    nonisolated static let appStoreID = "6758851574"
    nonisolated static let bundleID = "com.waterquest.hydration"

    @Published var pendingUpdate: AppUpdate?

    private let defaults: UserDefaults
    private let session: URLSession
    private let currentVersion: String

    private enum Keys {
        static let lastCheck = "appUpdateLastCheck"
        static let dismissedVersion = "appUpdateDismissedVersion"
        static let dismissedAt = "appUpdateDismissedAt"
    }
    static let checkInterval: TimeInterval = 12 * 60 * 60
    static let snoozeInterval: TimeInterval = 3 * 24 * 60 * 60

    init(defaults: UserDefaults = .standard,
         session: URLSession = .shared,
         currentVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0") {
        self.defaults = defaults
        self.session = session
        self.currentVersion = currentVersion
    }

    /// Call on launch and when the app returns to the foreground.
    func checkIfDue(now: Date = Date()) async {
        #if DEBUG
        // Simulator QA: launch with SIPLI_FAKE_APP_UPDATE=1 to see the popup.
        if ProcessInfo.processInfo.environment["SIPLI_FAKE_APP_UPDATE"] == "1" {
            pendingUpdate = AppUpdate(version: "9.9",
                                      releaseNotes: "• A sample update for testing the popup.\n• Release notes from the App Store appear here.",
                                      storeURL: URL(string: "https://apps.apple.com/app/id\(Self.appStoreID)")!)
            return
        }
        #endif
        if let last = defaults.object(forKey: Keys.lastCheck) as? Date,
           now.timeIntervalSince(last) < Self.checkInterval { return }
        defaults.set(now, forKey: Keys.lastCheck)
        guard let update = await fetchLatest(), shouldOffer(update, now: now) else { return }
        pendingUpdate = update
    }

    func remindLater(now: Date = Date()) {
        guard let update = pendingUpdate else { return }
        defaults.set(update.version, forKey: Keys.dismissedVersion)
        defaults.set(now, forKey: Keys.dismissedAt)
        pendingUpdate = nil
    }

    // MARK: Rules (pure, tested)

    func shouldOffer(_ update: AppUpdate, now: Date) -> Bool {
        guard Self.isVersion(update.version, newerThan: currentVersion) else { return false }
        if defaults.string(forKey: Keys.dismissedVersion) == update.version,
           let at = defaults.object(forKey: Keys.dismissedAt) as? Date,
           now.timeIntervalSince(at) < Self.snoozeInterval {
            return false
        }
        return true
    }

    /// Numeric, component-wise: "6.10" > "6.9", "6.1" == "6.1.0".
    nonisolated static func isVersion(_ a: String, newerThan b: String) -> Bool {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0, y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    /// Parses the App Store lookup response.
    nonisolated static func parse(_ data: Data) -> AppUpdate? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let first = (json["results"] as? [[String: Any]])?.first,
              let version = first["version"] as? String
        else { return nil }
        let notes = (first["releaseNotes"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let url = (first["trackViewUrl"] as? String).flatMap(URL.init(string:))
            ?? URL(string: "https://apps.apple.com/app/id\(appStoreID)")!
        return AppUpdate(version: version, releaseNotes: notes, storeURL: url)
    }

    // MARK: Network

    private func fetchLatest() async -> AppUpdate? {
        var components = URLComponents(string: "https://itunes.apple.com/lookup")!
        components.queryItems = [
            URLQueryItem(name: "bundleId", value: Self.bundleID),
            // The App Store caches lookups; a changing value keeps results fresh.
            URLQueryItem(name: "t", value: String(Int(Date().timeIntervalSince1970 / 3600))),
        ]
        if let region = Locale.current.region?.identifier {
            components.queryItems?.append(URLQueryItem(name: "country", value: region.lowercased()))
        }
        guard let url = components.url else { return nil }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.httpMethod = "GET"
        guard let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        return Self.parse(data)
    }
}

// MARK: - Popup

struct AppUpdateSheet: View {
    let update: AppUpdate
    let onUpdate: () -> Void
    let onLater: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                SipliMark(size: 92)
                    .padding(.top, 28)

                VStack(spacing: 6) {
                    Text("A new Sipli is here")
                        .font(Theme.editorialSerif(28, weight: .semibold, relativeTo: .title))
                        .multilineTextAlignment(.center)
                    Text("Version \(update.version)")
                        .font(Theme.sipliMono(12, weight: .semibold, relativeTo: .caption))
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                }

                if !update.releaseNotes.isEmpty {
                    Text(update.releaseNotes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.card))
                }

                VStack(spacing: 10) {
                    Button {
                        Haptics.selection()
                        onUpdate()
                    } label: {
                        Text("Update now")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.lagoon)

                    Button("Later", action: onLater)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 6)
                }
                .padding(.top, 4)
            }
            .frame(maxWidth: 440)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity)
        }
        .background { AppWaterBackground().ignoresSafeArea() }
    }
}

/// Checks on launch and on foreground, and shows the popup when allowed.
private struct AppUpdatePromptModifier: ViewModifier {
    /// False while another sheet, celebration or invite is up.
    let canPresent: Bool
    @StateObject private var checker = AppUpdateChecker()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var shown: AppUpdate?

    func body(content: Content) -> some View {
        content
            .task {
                // After the splash and any first-launch prompts.
                try? await Task.sleep(for: .seconds(3))
                await checker.checkIfDue()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                present()
                Task { await checker.checkIfDue() }
            }
            .onChange(of: checker.pendingUpdate) { present() }
            .onChange(of: canPresent) { present() }
            .sheet(item: $shown, onDismiss: {
                // Swiping away counts as "Later".
                if checker.pendingUpdate != nil { checker.remindLater() }
            }) { update in
                AppUpdateSheet(update: update) {
                    openURL(update.storeURL)
                    checker.pendingUpdate = nil
                    shown = nil
                } onLater: {
                    checker.remindLater()
                    shown = nil
                }
                .presentationDetents([.medium, .large])
            }
    }

    private func present() {
        guard canPresent, shown == nil, let update = checker.pendingUpdate else { return }
        shown = update
    }
}

extension View {
    func appUpdatePrompt(canPresent: Bool) -> some View {
        modifier(AppUpdatePromptModifier(canPresent: canPresent))
    }
}
