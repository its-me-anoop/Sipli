import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

#if canImport(FoundationModels)

// MARK: - Guided generation payloads

@available(iOS 26.0, *)
@Generable(description: "A short hydration coaching message shown on a card in the app")
struct CoachTipPayload: Equatable {
    @Guide(description: "One or two warm, specific sentences, at most 120 characters total. Plain text only: no emojis, hashtags, or markdown.")
    var message: String
}

@available(iOS 26.0, *)
@Generable(description: "A single-line hydration reminder for a push notification")
struct NudgePayload: Equatable {
    @Guide(description: "One friendly motivational sentence, at most 12 words. Plain text, no emojis, at most one exclamation mark.")
    var message: String
}

@available(iOS 26.0, *)
@Generable(description: "A brief personalized insight about the user's hydration habits")
struct InsightPayload: Equatable {
    @Guide(description: "Two to three encouraging sentences that reference the user's actual numbers. Plain text, no emojis.")
    var message: String
}

@available(iOS 26.0, *)
@Generable(description: "A weekly hydration recap")
struct WeeklyDigestPayload: Equatable {
    @Guide(description: "A punchy headline for the week, at most 40 characters, plain text")
    var headline: String
    @Guide(description: "Two or three sentences narrating the week's hydration story using the provided numbers. Plain text, no emojis.")
    var narrative: String
    @Guide(description: "One forward-looking sentence for next week, at most 90 characters")
    var encouragement: String
}

// MARK: - SipliIntelligence

/// Central owner of every FoundationModels interaction in the app.
///
/// Design (vs. the previous scattered one-shot sessions):
/// - One long-lived session per surface, so instructions are ingested once
///   and `prewarm()` can hide model-load latency before the first request.
/// - Guided generation (`@Generable` payloads) instead of free-form strings —
///   schema-constrained decoding removes the empty-string/format-drift
///   failure modes and the manual trimming.
/// - Explicit `GenerationOptions`: temperature + top-k sampling for varied
///   copy, and `maximumResponseTokens` so the notification path reliably
///   finishes inside its 2-second budget.
/// - Locale guard: on unsupported locales the static fallbacks win instantly
///   instead of burning latency on a doomed request.
/// - Typed error handling: a context-window overflow resets that surface's
///   session; other generation errors just fall back.
///
/// iOS 27 (fenced with compiler(>=6.4) — the App Store toolchain is
/// Xcode 26.6 until Xcode 27 goes GM): the Weekly Digest upgrades itself to
/// `PrivateCloudComputeLanguageModel`, Apple's larger server model on Private
/// Cloud Compute (bigger context, better narrative), with quota awareness and
/// silent fallback to the on-device model. Notifications and tips stay
/// on-device — network latency would blow their budgets.
@available(iOS 26.0, *)
@MainActor
final class SipliIntelligence {
    static let shared = SipliIntelligence()

    enum Surface {
        case coach
        case notifications
        case insights
        case digest
    }

    private var sessions: [ObjectIdentifierBox: LanguageModelSession] = [:]

    /// Hashable wrapper so Surface can key the dictionary without
    /// making the enum public API more complex.
    private struct ObjectIdentifierBox: Hashable {
        let raw: String
        init(_ surface: Surface) {
            switch surface {
            case .coach: raw = "coach"
            case .notifications: raw = "notifications"
            case .insights: raw = "insights"
            case .digest: raw = "digest"
            }
        }
    }

    /// True when the on-device model is ready and supports the user's locale.
    var isReady: Bool {
        SystemLanguageModel.default.availability == .available
            && SystemLanguageModel.default.supportsLocale()
    }

    /// Whether the last digest came from the Private Cloud Compute model —
    /// surfaced in the UI as a small provenance note.
    private(set) var lastDigestUsedCloudModel = false
    /// Which model backs the currently cached digest session.
    private var digestSessionIsCloud = false

    // MARK: Prewarm

    /// Loads the model and pre-processes the surface's instructions ahead of
    /// the first request. Call when a surface is about to become active
    /// (dashboard appear, scheduling pass, insights tab).
    func prewarm(_ surface: Surface) {
        guard isReady else { return }
        session(for: surface).prewarm()
    }

    // MARK: Coach tips

    func coachTip(context: String) async -> String? {
        await generate(
            surface: .coach,
            prompt: context,
            generating: CoachTipPayload.self,
            options: Self.options(top: 40, temperature: 0.8, maxTokens: 80)
        )?.message
    }

    // MARK: Notification copy

    /// Tight token cap: this call races a 2-second timeout in
    /// `NotificationScheduler` — a 12-word nudge must finish fast.
    func notificationNudge(context: String) async -> String? {
        await generate(
            surface: .notifications,
            prompt: context,
            generating: NudgePayload.self,
            options: Self.options(top: 40, temperature: 0.9, maxTokens: 40)
        )?.message
    }

    // MARK: Insights

    func insight(context: String) async -> String? {
        await generate(
            surface: .insights,
            prompt: context,
            generating: InsightPayload.self,
            options: Self.options(top: 30, temperature: 0.7, maxTokens: 140)
        )?.message
    }

    // MARK: Weekly digest

    func weeklyDigest(stats: WeeklyStats) async -> WeeklyDigestPayload? {
        let prompt = Self.digestPrompt(stats: stats)
        let payload = await generate(
            surface: .digest,
            prompt: prompt,
            generating: WeeklyDigestPayload.self,
            options: Self.options(top: 30, temperature: 0.7, maxTokens: 220)
        )
        // Provenance follows the session that actually produced this digest;
        // a failed generation must not carry a stale cloud label.
        lastDigestUsedCloudModel = payload != nil && digestSessionIsCloud
        return payload
    }

    /// Top-k sampling + temperature + response cap, spelled for both
    /// toolchains: the iOS 27 SDK renamed the init's `sampling:` label to
    /// `samplingMode:` (back-deployed), while the App Store toolchain
    /// (Xcode 26.6 / Swift 6.3) still has the original label.
    private nonisolated static func options(top: Int, temperature: Double, maxTokens: Int) -> GenerationOptions {
        #if compiler(>=6.4)
        return GenerationOptions(
            samplingMode: .random(top: top),
            temperature: temperature,
            maximumResponseTokens: maxTokens
        )
        #else
        return GenerationOptions(
            sampling: .random(top: top),
            temperature: temperature,
            maximumResponseTokens: maxTokens
        )
        #endif
    }

    nonisolated static func digestPrompt(stats: WeeklyStats) -> String {
        var lines = [
            "Write this user's weekly hydration recap.",
            "Total this week: \(Int(stats.totalML)) ml across \(stats.activeDays) active days.",
            "Goal met on \(stats.goalHits) of 7 days. Daily average \(Int(stats.averageML)) ml.",
        ]
        if let best = stats.bestDayName {
            lines.append("Best day: \(best) with \(Int(stats.bestDayML)) ml.")
        }
        if let wow = stats.weekOverWeekPercent {
            lines.append("Change vs last week: \(Int(wow))%.")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Generation core

    private func generate<Payload: Generable & Sendable>(
        surface: Surface,
        prompt: String,
        generating type: Payload.Type,
        options: GenerationOptions
    ) async -> Payload? {
        guard isReady else { return nil }
        let session = session(for: surface)
        guard !session.isResponding else { return nil }

        do {
            let response = try await session.respond(
                to: prompt,
                generating: Payload.self,
                options: options
            )
            return response.content
        } catch let error as LanguageModelSession.GenerationError {
            switch error {
            case .exceededContextWindowSize:
                // Long-lived session filled its context — start fresh next time.
                resetSession(for: surface)
            default:
                break
            }
            return nil
        } catch {
            return nil
        }
    }

    private func session(for surface: Surface) -> LanguageModelSession {
        let key = ObjectIdentifierBox(surface)
        if let existing = sessions[key] { return existing }
        let created = makeSession(for: surface)
        sessions[key] = created
        return created
    }

    private func resetSession(for surface: Surface) {
        sessions[ObjectIdentifierBox(surface)] = nil
    }

    private func makeSession(for surface: Surface) -> LanguageModelSession {
        switch surface {
        case .coach:
            return LanguageModelSession {
                """
                You are a friendly hydration coach inside a water tracking app called Sipli. \
                You write short motivational messages about drinking water. Be warm, \
                specific to the user's context, and varied.
                """
            }
        case .notifications:
            return LanguageModelSession {
                """
                You are a cheerful hydration coach inside a mobile app called Sipli. \
                You write short, warm, motivational nudges to help people drink more water. \
                Be encouraging, never guilt-tripping.
                """
            }
        case .insights:
            return LanguageModelSession {
                """
                You are a hydration coach inside Sipli, a mobile hydration tracking app. \
                You provide brief, personalized, encouraging insights about the user's \
                hydration habits, always referencing their specific numbers.
                """
            }
        case .digest:
            return makeDigestSession()
        }
    }

    private func makeDigestSession() -> LanguageModelSession {
        digestSessionIsCloud = false
        #if compiler(>=6.4)
        // iOS 27: Apple's server-scale model on Private Cloud Compute — larger
        // context and noticeably better narrative for the weekly recap. Quota
        // aware; anything short of fully available falls back to on-device.
        if #available(iOS 27.0, *) {
            let cloud = PrivateCloudComputeLanguageModel()
            if cloud.isAvailable, !cloud.quotaUsage.isLimitReached {
                digestSessionIsCloud = true
                return LanguageModelSession(model: cloud) {
                    Self.digestInstructions
                }
            }
        }
        #endif
        return LanguageModelSession {
            Self.digestInstructions
        }
    }

    private static let digestInstructions = """
        You are a hydration coach inside Sipli, a water tracking app. Once a week \
        you write the user's hydration recap: a headline, a short narrative of how \
        their week went using their real numbers, and one encouraging line for the \
        week ahead. Warm and concrete, never preachy.
        """
}

#endif
