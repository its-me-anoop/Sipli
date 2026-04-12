import HealthKit

@MainActor
final class WatchHealthKitManager: ObservableObject {
    @Published var isAuthorized = false

    private let healthStore = HKHealthStore()
    private let waterType = HKQuantityType(.dietaryWater)

    var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async {
        guard isAvailable else { return }

        let typesToWrite: Set<HKSampleType> = [waterType]
        let typesToRead: Set<HKObjectType> = [waterType]

        do {
            try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
            isAuthorized = healthStore.authorizationStatus(for: waterType) == .sharingAuthorized
        } catch {
            #if DEBUG
            print("Watch HealthKit authorization failed: \(error)")
            #endif
        }
    }

    func logWaterIntake(ml: Double) async {
        guard isAuthorized else { return }

        let quantity = HKQuantity(unit: .literUnit(with: .milli), doubleValue: ml)
        let sample = HKQuantitySample(type: waterType, quantity: quantity, start: Date(), end: Date())

        do {
            try await healthStore.save(sample)
        } catch {
            #if DEBUG
            print("Watch HealthKit save failed: \(error)")
            #endif
        }
    }
}
