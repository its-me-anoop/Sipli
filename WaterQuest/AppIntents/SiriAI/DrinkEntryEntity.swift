// Siri AI Developer Preview (iOS 27.3): a logged drink as an app entity.
//
// Everything in this file needs the iOS 27.3 SDK, so it only compiles when
// `SIRI_AI_PREVIEW` is set. The app target sets that flag automatically for
// the iphoneos27.3+/iphonesimulator27.3+ SDKs (see the
// SWIFT_ACTIVE_COMPILATION_CONDITIONS[sdk=...] build settings); builds with
// Xcode 27.2 or earlier leave it out and behave exactly as before.
#if SIRI_AI_PREVIEW
import AppIntents
import CoreSpotlight
import CoreTransferable
import SwiftUI

/// One drink in the person's Sipli log, so Siri can find it ("the coffee I
/// had this morning"), show it as a card, change or delete it, and pass it
/// to another app ("send today's log to Sam").
@available(iOS 27.3, *)
struct DrinkEntryEntity: AppEntity, IndexedEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Logged Drink",
        numericFormat: "\(placeholder: .int) logged drinks"
    )
    static let defaultQuery = DrinkEntryQuery()

    let id: UUID

    @Property(
        title: "Drink",
        description: "What the person drank, such as water, coffee, green tea or a latte."
    )
    var drink: FluidTypeAppEnum

    @Property(
        title: "Amount (mL)",
        description: "How much the person drank, in millilitres."
    )
    var amountML: Int

    @Property(
        title: "Hydration (mL)",
        description: "How much of the amount counts toward the daily water goal, in millilitres. Water counts fully; coffee, tea, milk and other drinks count for a little less."
    )
    var hydrationML: Int

    @Property(
        title: "Logged At",
        description: "The date and time the person had this drink."
    )
    var loggedAt: Date

    /// Free text the person typed; private to them, so Siri only reads it
    /// out after the device is unlocked.
    @Property(
        title: "Note",
        description: "A note the person added to this drink, if any.",
        authenticationPolicy: .requiresAuthentication
    )
    var note: String?

    /// Display-only values, not exposed to Siri as properties.
    let amountText: String
    let iconName: String

    init(snapshot: HydrationAssistantCore.EntrySnapshot) {
        self.id = snapshot.id
        self.amountText = snapshot.amountText
        self.iconName = snapshot.fluid.iconName
        self.drink = FluidTypeAppEnum.from(snapshot.fluid)
        self.amountML = snapshot.amountML
        self.hydrationML = snapshot.hydrationML
        self.loggedAt = snapshot.loggedAt
        self.note = snapshot.note
    }

    init(entry: HydrationEntry, unit: UnitSystem) {
        self.init(snapshot: HydrationAssistantCore.snapshot(of: entry, unit: unit))
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(amountText) \(drink.localizedTitle)",
            subtitle: "\(loggedAt.formatted(date: .abbreviated, time: .shortened))",
            image: DisplayRepresentation.Image(systemName: iconName)
        )
    }

    /// Text another app receives when Siri hands this drink over.
    var shareText: String {
        "\(amountText) \(drink.localizedTitle.lowercased()) at \(loggedAt.formatted(date: .abbreviated, time: .shortened)) (logged in Sipli)"
    }
}

@available(iOS 27.3, *)
extension FluidTypeAppEnum {
    /// The case's spoken title, e.g. "Latte".
    var localizedTitle: String {
        toFluidType().displayName
    }
}

// MARK: - Query

/// Looks drinks up in the shared state file. Siri mostly finds drinks
/// through the Spotlight index (`DrinkEntrySpotlightIndex`); this query
/// resolves identifiers and covers typed searches in Shortcuts.
@available(iOS 27.3, *)
struct DrinkEntryQuery: EntityStringQuery {
    private func load() -> PersistedState {
        PersistenceService.shared.load(PersistedState.self, fallback: .default)
    }

    func entities(for identifiers: [UUID]) async throws -> [DrinkEntryEntity] {
        let state = load()
        let wanted = Set(identifiers)
        return state.entries
            .filter { wanted.contains($0.id) }
            .map { DrinkEntryEntity(entry: $0, unit: state.profile.unitSystem) }
    }

    /// "latte", "coffee yesterday" typed in Shortcuts: drinks of that kind
    /// from the indexed window, newest first.
    func entities(matching string: String) async throws -> [DrinkEntryEntity] {
        let state = load()
        guard let fluid = DrinkAmount.fluid(in: string) else { return [] }
        return HydrationAssistantCore.indexableEntries(in: state, now: Date())
            .filter { $0.fluidType == fluid }
            .sorted { $0.date > $1.date }
            .map { DrinkEntryEntity(entry: $0, unit: state.profile.unitSystem) }
    }

    /// Today's drinks, newest first: what "that drink" most often means.
    func suggestedEntities() async throws -> [DrinkEntryEntity] {
        let state = load()
        let now = Date()
        return HydrationAssistantCore.entries(in: state, from: now, through: now)
            .reversed()
            .map { DrinkEntryEntity(entry: $0, unit: state.profile.unitSystem) }
    }
}

// MARK: - Card snippet

@available(iOS 27.3, *)
extension DrinkEntryEntity: SnippetRepresentableEntity {
    static var snippet: some EntitySnippetContent<DrinkEntryEntity> {
        CardSnippet(supportedFamilies: [.standard]) { entry, _ in
            DrinkEntryCardView(entry: entry)
        }
    }
}

/// Static card Siri shows for a drink. Snippets are archived ahead of time
/// and drawn out of process, so this uses only text, symbols and shapes.
@available(iOS 27.3, *)
struct DrinkEntryCardView: View {
    let entry: DrinkEntryEntity

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: entry.iconName)
                .font(.title2)
                .foregroundStyle(Theme.lagoon)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Theme.lagoon.opacity(0.15)))
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.drink.localizedTitle)
                    .font(.headline)
                Text(entry.loggedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let note = entry.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                Text(entry.amountText)
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                Text("\(entry.hydrationML) mL hydration")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(entry.amountText) of \(entry.drink.localizedTitle), \(entry.loggedAt.formatted(date: .abbreviated, time: .shortened))")
    }
}

// MARK: - Transferable

/// Lets Siri pass drinks to other apps as plain text, e.g. into Messages
/// or Notes.
@available(iOS 27.3, *)
extension DrinkEntryEntity: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(exporting: \.shareText)
    }
}

// MARK: - Spotlight

/// Keeps the last 30 days of drinks in a named Spotlight index so Siri can
/// find them by meaning ("the latte from Tuesday"). Rebuilds are debounced:
/// a burst of saves (a multi-drink request, a HealthKit sync) costs one pass.
@available(iOS 27.3, *)
@MainActor
enum DrinkEntrySpotlightIndex {
    static let indexName = "Sipli_DrinkEntries"
    private static var pending: Task<Void, Never>?

    static func scheduleReindex(delay: Duration = .seconds(2)) {
        pending?.cancel()
        pending = Task {
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            await reindex()
        }
    }

    static func reindex(now: Date = Date()) async {
        let state = PersistenceService.shared.load(PersistedState.self, fallback: .default)
        let unit = state.profile.unitSystem
        let entities = HydrationAssistantCore.indexableEntries(in: state, now: now)
            .map { DrinkEntryEntity(entry: $0, unit: unit) }
        let index = CSSearchableIndex(name: indexName)
        // The index holds only these entities, so clearing it drops deleted
        // and aged-out drinks before the current window goes back in.
        try? await index.deleteAllSearchableItems()
        try? await index.indexAppEntities(entities)
    }
}
#endif
