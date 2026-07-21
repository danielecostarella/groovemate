import Foundation
import GrooveModel

/// Persists completed practice sessions to UserDefaults as JSON — no
/// database needed for a list that stays small and never needs querying.
struct PracticeHistoryStore {
    private let key = "com.groovemate.practiceHistory"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func all() -> [PracticeRecord] {
        guard let data = defaults.data(forKey: key),
              let records = try? JSONDecoder().decode([PracticeRecord].self, from: data)
        else { return [] }
        return records.sorted { $0.date > $1.date }
    }

    func add(_ record: PracticeRecord) {
        var records = all()
        records.insert(record, at: 0)
        // Keep the list from growing forever; recent history is what matters.
        if records.count > 100 { records.removeLast(records.count - 100) }
        guard let data = try? JSONEncoder().encode(records) else { return }
        defaults.set(data, forKey: key)
    }
}
