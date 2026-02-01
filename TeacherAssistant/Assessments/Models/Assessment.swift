import Foundation
import SwiftData

@Model
class Assessment {
    var title: String
    var details: String
    var date: Date
    var sortOrder: Int

    var unit: Unit?

    @Relationship(deleteRule: .cascade, inverse: \StudentResult.assessment)
    var results: [StudentResult] = []

    init(title: String, details: String = "", date: Date = Date(), results: [StudentResult] = []) {
        self.title = title
        self.details = details
        self.date = date
        self.results = results
        self.unit = nil
        self.sortOrder = 0
    }
}
