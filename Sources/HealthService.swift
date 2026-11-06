import Foundation
import HealthKit

final class HealthService {
    private let store = HKHealthStore()
    private var observers: [HKObserverQuery] = []
    private let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
    private let workoutType = HKObjectType.workoutType()
    private let stepType = HKObjectType.quantityType(forIdentifier: .stepCount)!
    var available: Bool { HKHealthStore.isHealthDataAvailable() }

    func authorize() async throws {
        guard available else { throw HealthFailure.unavailable }
        try await store.requestAuthorization(toShare: [], read: [sleepType, workoutType, stepType])
        // Successful request means the dialog finished, not that read access was granted.
    }

    func observe(onChange: @escaping (@escaping () -> Void) -> Void,
                 onError: @escaping (Error) -> Void) {
        guard observers.isEmpty, available else { return }
        for type in [sleepType as HKSampleType, workoutType as HKSampleType, stepType] {
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
        for type in [sleepType as HKObjectType, workoutType as HKObjectType, stepType] {
            store.disableBackgroundDelivery(for: type) { _, _ in }
        }
    }

    struct Reading {
        var intervals: [HealthInterval] = []
        var sampleCount = 0
        var error: String?
        var diagnostic: String {
            if let error { return "读取失败：" + error }
            if sampleCount == 0 { return "未读到记录（也可能未获读取权限）" }
            if intervals.isEmpty { return "读到记录，但没有符合结算规则的时段" }
            return "已读到 \(intervals.count) 个可结算时段"
        }
    }

    func fetch(since start: Date) async -> (sleep: Reading, workouts: Reading) {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: [])
        async let sleep = read(type: sleepType, predicate: predicate, sleep: true)
        async let workouts = read(type: workoutType, predicate: predicate, sleep: false)
        return await (sleep, workouts)
    }

    private func read(type: HKSampleType, predicate: NSPredicate, sleep: Bool) async -> Reading {
        do {
            let all = try await samples(type: type, predicate: predicate)
            let values = Set([HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                              HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                              HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                              HKCategoryValueSleepAnalysis.asleepREM.rawValue])
            let intervals = all.compactMap { sample -> HealthInterval? in
                guard (sample.metadata?[HKMetadataKeyWasUserEntered] as? Bool) != true else { return nil }
                if sleep {
                    guard let item = sample as? HKCategorySample, values.contains(item.value) else { return nil }
                }
                return HealthInterval(start: sample.startDate, end: sample.endDate)
            }
            return Reading(intervals: intervals, sampleCount: all.count)
        } catch { return Reading(error: error.localizedDescription) }
    }

    func dailySteps(since start: Date) async throws -> [String: Int] {
        let end = Date()
        let anchor = Calendar.current.startOfDay(for: start)
        let dates = HKQuery.predicateForSamples(withStart: anchor, end: end)
        let manual = HKQuery.predicateForObjects(withMetadataKey: HKMetadataKeyWasUserEntered, allowedValues: [NSNumber(value: true)])
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [dates, NSCompoundPredicate(notPredicateWithSubpredicate: manual)])
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(quantityType: stepType, quantitySamplePredicate: predicate,
                options: .cumulativeSum, anchorDate: anchor, intervalComponents: DateComponents(day: 1))
            query.initialResultsHandler = { _, collection, error in
                if let error { continuation.resume(throwing: error); return }
                var totals: [String: Int] = [:]
                collection?.enumerateStatistics(from: anchor, to: end) { statistic, _ in
                    if let quantity = statistic.sumQuantity() {
                        totals[Growth.dayID(statistic.startDate)] = Int(quantity.doubleValue(for: .count()))
                    }
                }
                continuation.resume(returning: totals)
            }
            store.execute(query)
        }
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
