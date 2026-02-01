import Foundation
import SwiftData

@Model
class StudentResult {

    var student: Student?
    var assessment: Assessment?
    var score: Double
    var notes: String

    init(student: Student, assessment: Assessment? = nil, score: Double = 0, notes: String = "") {
        self.student = student
        self.assessment = assessment
        self.score = score
        self.notes = notes
    }
}
