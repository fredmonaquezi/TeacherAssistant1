import Foundation

extension Array where Element == StudentResult {
    var averageScore: Double {
        let valid = self.filter { $0.score > 0 }
        guard !valid.isEmpty else { return 0 }
        return valid.map(\.score).reduce(0, +) / Double(valid.count)
    }
}
