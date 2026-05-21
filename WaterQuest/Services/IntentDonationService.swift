import AppIntents
import Foundation

/// Donates App Intents to the system so Siri can predict them on the
/// lock screen and in Shortcuts suggestions. Kept as a namespace enum
/// (no instances, no stored state) to honour single-responsibility:
/// it knows how to build and donate a LogWaterIntent, nothing more.
enum IntentDonationService {
    static func donateLogWater(amount: Double, fluidType: FluidType) {
        let intent = LogWaterIntent(
            amountInMilliliters: Int(amount.rounded()),
            fluidType: FluidTypeAppEnum.from(fluidType)
        )
        Task {
            try? await intent.donate()
        }
    }
}
