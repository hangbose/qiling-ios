import Foundation
import HealthKit

final class HealthService {
    private let store = HKHealthStore()
    private var observers: [HKObserverQuery] = []
    private let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
    private let workoutType = HKObjectType.workoutType()
    var available: Bool { HKHealthStore.isHealthDataAvailable() }

    func authorize() async throws {
        guard available else { throw HealthFailure.unavailable }
        try await store.requestAuthorization(toShare: [], read: [sleepType, workoutType])
        // Successful request means the dialog finished, not that read access was granted.
    }

    func observe(onChange: @escaping (@escaping () -> Void) -> Void,
                 onError: @escaping (Error) -> Void) {
        guard observers.isEmpty, available else { return }
        for type in [sleepType as HKSampleType, workoutType as HKSampleType] {
            let query = HKObserverQuery(sampleType: type, predicate: nil) { _, completion, error in
                if let error { onError(error); completion(); return }
                onChange(completion)
            }
            observers.append(query)
            store.execute(query)
            store.enableBackgroundDelivery(for: type, frequency: .hourly) { _, error in
                if let error { onError(error) }
            }
        }
    }

    func stop() {
        observers.forEach { store.stop($0) }
        observers.removeAll()
        for type in [sleepType as HKObjectType, workoutType as HKObjectType] {
            store.disableBackgroundDelivery(for: type) { _, _ in }
        }
    }

    func fetch(since start: Date) async throws -> (sleep: [HealthInterval], workouts: [HealthInterval]) {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: [])
        async let sleepSamples = samples(type: sleepType, predicate: predicate)
        async let workoutSamples = samples(type: workoutType, predicate: predicate)
        let (sleep, workouts) = try await (sleepSamples, workoutSamples)
        let asleepValues = Set([
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue
        ])
        func isAutomatic(_ sample: HKSample) -> Bool {
            (sample.metadata?[HKMetadataKeyWasUserEntered] as? Bool) != true
        }
        return (
            sleep.compactMap { sample in
                guard let item = sample as? HKCategorySample,
                      asleepValues.contains(item.value), isAutomatic(item) else { return nil }
                return HealthInterval(start: item.startDate, end: item.endDate)
            },
            workouts.filter(isAutomatic).map { HealthInterval(start: $0.startDate, end: $0.endDate) }
        )
    }

    private func samples(type: HKSampleType, predicate: NSPredicate) async throws -> [HKSample] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate,
                                      limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: samples ?? []) }
            }
            store.execute(query)
        }
    }
}

enum HealthFailure: LocalizedError {
    case unavailable
    var errorDescription: String? { "当前设备不支持 Apple 健康。可以先进入演示模式。" }
}
