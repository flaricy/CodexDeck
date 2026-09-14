import Foundation

/// Only the current deck is visible; historical records do not fill empty keys.
struct SessionCandidate {
    let id: String
    let active: Bool
    let updatedAt: Double
}
struct SessionSelection: Codable {
    var selected: [String] = []
    var hidden: Set<String> = []
    var seen: [String: Double] = [:]
    var initialized = false
    mutating func reconcile(_ candidates: [SessionCandidate]) {
        let available = Set(candidates.map(\.id))
        selected.removeAll { !available.contains($0) || hidden.contains($0) }
        let eligible = candidates.filter { !hidden.contains($0.id) }
        if !initialized {
            let active = eligible.filter(\.active)
            selected = Array((active.isEmpty ? Array(eligible.prefix(1)) : active).prefix(3).map(\.id))
            initialized = true
        } else {
            for c in eligible where !selected.contains(c.id) {
                let isNew = seen[c.id] == nil && c.updatedAt >= (seen.values.max() ?? 0)
                let resumed = c.active && c.updatedAt > (seen[c.id] ?? 0)
                if selected.count < 3 && (isNew || resumed) { selected.append(c.id) }
            }
        }
        for c in candidates { seen[c.id] = c.updatedAt }
    }
    mutating func hide(_ id: String) { hidden.insert(id);selected.removeAll { $0 == id } }
    mutating func show(_ id: String) {
        guard selected.count < 3 || selected.contains(id) else { return }
        hidden.remove(id)
        if !selected.contains(id) { selected.append(id) }
    }
}
