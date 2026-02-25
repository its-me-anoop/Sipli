import Foundation
import HealthKit

@MainActor
final class HealthKitManager: ObservableObject {
    private let healthStore = HKHealthStore()
    private let waterEntryMetadataKey = "SipliEntryID"
    private var waterObserverQuery: HKObserverQuery?

    @Published var isAvailable: Bool = HKHealthStore.isHealthDataAvailable()
    @Published var isAuthorized: Bool = false

    func refreshAuthorizationStatus() async {
        isAvailable = HKHealthStore.isHealthDataAvailable()
        guard isAvailable else {
            isAuthorized = false
            return
        }

        guard let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else {
            isAuthorized = false
            return
        }

        let requestStatus = await authorizationRequestStatus()
        let canShareWater = healthStore.authorizationStatus(for: waterType) == .sharingAuthorized
        isAuthorized = requestStatus == .unnecessary && canShareWater
    }

    func requestAuthorization() async {
        guard isAvailable,
              let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater),
              let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return }
        let workoutType = HKObjectType.workoutType()

        let shareTypes: Set = [waterType]
        let readTypes: Set = [waterType, workoutType, energyType]

        do {
            try await healthStore.requestAuthorization(toShare: shareTypes, read: readTypes)
            await refreshAuthorizationStatus()
        } catch {
            isAuthorized = false
            #if DEBUG
            print("HealthKit auth failed: \(error)")
            #endif
        }
    }

    func fetchTodayWorkoutSummary() async -> WorkoutSummary {
        guard isAvailable else { return .empty }
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())

        let workoutMinutes = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                let workouts = samples as? [HKWorkout] ?? []
                let totalMinutes = workouts.reduce(0.0) { $0 + $1.duration / 60.0 }
                continuation.resume(returning: totalMinutes)
            }
            healthStore.execute(query)
        }

        let energy = await fetchActiveEnergy(predicate: predicate)
        return WorkoutSummary(exerciseMinutes: workoutMinutes, activeEnergyKcal: energy)
    }

    func fetchTodayWaterEntries() async -> [HydrationEntry]? {
        guard isAvailable else { return nil }

        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        return await fetchWaterEntries(predicate: predicate)
    }

    func fetchRecentWaterEntries(days: Int) async -> [HydrationEntry]? {
        guard isAvailable else { return nil }
        let cappedDays = max(1, min(30, days))
        let start = Calendar.current.date(byAdding: .day, value: -cappedDays + 1, to: Calendar.current.startOfDay(for: Date())) ?? Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date())
        return await fetchWaterEntries(predicate: predicate)
    }

    func startWaterIntakeObserver(
        days: Int = 7,
        onEntriesUpdated: @escaping @MainActor ([HydrationEntry]) -> Void
    ) async {
        guard isAvailable else { return }
        guard let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else { return }

        let status = await authorizationRequestStatus()
        if status == .shouldRequest {
            await requestAuthorization()
        } else {
            await refreshAuthorizationStatus()
        }

        guard isAuthorized else { return }

        if let existingQuery = waterObserverQuery {
            healthStore.stop(existingQuery)
            waterObserverQuery = nil
        }

        let query = HKObserverQuery(sampleType: waterType, predicate: nil) { [weak self] _, completionHandler, error in
            guard let self else {
                completionHandler()
                return
            }

            if let error {
                #if DEBUG
                print("HealthKit water observer error: \(error)")
                #endif
                completionHandler()
                return
            }

            Task { @MainActor in
                if let entries = await self.fetchRecentWaterEntries(days: days) {
                    onEntriesUpdated(entries)
                }
                completionHandler()
            }
        }

        waterObserverQuery = query
        healthStore.execute(query)
        do {
            try await healthStore.enableBackgroundDelivery(for: waterType, frequency: .immediate)
        } catch {
            #if DEBUG
            print("HealthKit background delivery error: \(error)")
            #endif
        }

        if let entries = await fetchRecentWaterEntries(days: days) {
            onEntriesUpdated(entries)
        }
    }

    func stopWaterIntakeObserver() {
        if let query = waterObserverQuery {
            healthStore.stop(query)
            waterObserverQuery = nil
        }

        guard let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else {
            return
        }

        Task {
            do {
                try await healthStore.disableBackgroundDelivery(for: waterType)
            } catch {
                #if DEBUG
            print("HealthKit disable background delivery error: \(error)")
            #endif
            }
        }
    }

    func saveWaterIntake(ml: Double, date: Date = Date(), entryID: UUID? = nil) async {
        guard isAvailable else { return }
        let status = await authorizationRequestStatus()
        if status == .shouldRequest {
            await requestAuthorization()
        } else {
            await refreshAuthorizationStatus()
        }

        guard isAuthorized else { return }

        guard let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else { return }
        let quantity = HKQuantity(unit: .literUnit(with: .milli), doubleValue: ml)
        var metadata: [String: Any] = [:]
        if let entryID {
            metadata[waterEntryMetadataKey] = entryID.uuidString
        }
        let sample = HKQuantitySample(type: waterType, quantity: quantity, start: date, end: date, metadata: metadata.isEmpty ? nil : metadata)
        do {
            try await healthStore.save(sample)
        } catch {
            #if DEBUG
            print("Failed to save water sample: \(error)")
            #endif
        }
    }

    /// Deletes a water sample from HealthKit that was created by this app (matched by SipliEntryID metadata).
    func deleteWaterIntake(entryID: UUID) async {
        guard isAvailable else { return }
        let status = await authorizationRequestStatus()
        guard status != .shouldRequest else { return }
        guard let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else { return }

        let predicate = HKQuery.predicateForObjects(withMetadataKey: waterEntryMetadataKey, allowedValues: [entryID.uuidString])
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: waterType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { [weak self] _, samples, _ in
                guard let self, let samples, !samples.isEmpty else {
                    continuation.resume(returning: ())
                    return
                }
                self.healthStore.delete(samples) { _, _ in
                    continuation.resume(returning: ())
                }
            }
            healthStore.execute(query)
        }
    }

    /// Deletes a water sample from HealthKit by its HealthKit sample UUID.
    /// Used for entries imported from HealthKit (where the entry ID is the sample UUID).
    func deleteWaterSample(uuid: UUID) async {
        guard isAvailable else { return }
        let status = await authorizationRequestStatus()
        guard status != .shouldRequest else { return }
        guard let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else { return }

        let predicate = HKQuery.predicateForObject(with: uuid)
        await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: waterType, predicate: predicate, limit: 1, sortDescriptors: nil) { [weak self] _, samples, _ in
                guard let self, let samples, !samples.isEmpty else {
                    continuation.resume(returning: ())
                    return
                }
                self.healthStore.delete(samples) { _, _ in
                    continuation.resume(returning: ())
                }
            }
            healthStore.execute(query)
        }
    }

    private func fetchActiveEnergy(predicate: NSPredicate) async -> Double {
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            return 0
        }
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: energyType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, _ in
                let kcal = statistics?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                continuation.resume(returning: kcal)
            }
            healthStore.execute(query)
        }
    }

    private func authorizationRequestStatus() async -> HKAuthorizationRequestStatus {
        let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater)
        let workoutType = HKObjectType.workoutType()
        let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)
        guard let waterType, let energyType else { return .unknown }

        let shareTypes: Set = [waterType]
        let readTypes: Set = [waterType, workoutType, energyType]
        return await withCheckedContinuation { continuation in
            healthStore.getRequestStatusForAuthorization(toShare: shareTypes, read: readTypes) { status, error in
                if let error {
                    #if DEBUG
                    print("HealthKit authorization status failed: \(error)")
                    #endif
                    continuation.resume(returning: .unknown)
                } else {
                    continuation.resume(returning: status)
                }
            }
        }
    }

    private func fetchWaterEntries(predicate: NSPredicate) async -> [HydrationEntry] {
        guard let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else {
            return []
        }

        return await withCheckedContinuation { continuation in
            let sort = [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            let query = HKSampleQuery(sampleType: waterType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: sort) { [waterEntryMetadataKey] _, samples, _ in
                let entries = (samples as? [HKQuantitySample] ?? []).compactMap { sample -> HydrationEntry? in
                    if sample.metadata?[waterEntryMetadataKey] != nil {
                        return nil
                    }
                    let ml = sample.quantity.doubleValue(for: .literUnit(with: .milli))
                    return HydrationEntry(id: sample.uuid, date: sample.startDate, volumeML: ml, source: .healthKit)
                }
                continuation.resume(returning: entries)
            }
            healthStore.execute(query)
        }
    }
}
