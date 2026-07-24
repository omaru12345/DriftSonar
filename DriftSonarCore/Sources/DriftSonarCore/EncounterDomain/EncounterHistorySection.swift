import Foundation

/// A day's worth of encounters, for the すれ違い履歴 timeline (TASK-120).
public struct EncounterHistorySection {
    /// Start-of-day for every encounter in `events`, in the grouping calendar.
    public let day: Date
    /// Encounters on `day`, most recent first.
    public let events: [EncounteredEvent]

    public init(day: Date, events: [EncounteredEvent]) {
        self.day = day
        self.events = events
    }
}

public enum EncounterHistoryGrouping {
    /// Groups encounters into day sections, sections newest-first and events newest-first
    /// within each. Pure so the View's sectioning is unit-testable without SwiftData.
    /// - Parameter calendar: Injectable for deterministic tests; defaults to `.current`.
    public static func sections(
        from events: [EncounteredEvent],
        calendar: Calendar = .current
    ) -> [EncounterHistorySection] {
        let sorted = events.sorted { $0.encounteredAt > $1.encounteredAt }
        var order: [Date] = []
        var buckets: [Date: [EncounteredEvent]] = [:]
        for event in sorted {
            let day = calendar.startOfDay(for: event.encounteredAt)
            if buckets[day] == nil {
                buckets[day] = []
                order.append(day)
            }
            buckets[day]?.append(event)
        }
        return order.map { EncounterHistorySection(day: $0, events: buckets[$0] ?? []) }
    }
}
