import Foundation
import SwiftData

@Model
class StudentResult {

    var student: Student?
    var assessment: Assessment?
    var score: Double
    var hasScore: Bool
    var notes: String

    init(
        student: Student,
        assessment: Assessment? = nil,
        score: Double = 0,
        notes: String = "",
        hasScore: Bool? = nil
    ) {
        self.student = student
        self.assessment = assessment
        self.score = score
        self.hasScore = hasScore ?? (score > 0)
        self.notes = notes
    }

    var isScored: Bool {
        hasScore || score > 0
    }
}
