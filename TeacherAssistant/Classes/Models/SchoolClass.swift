import Foundation
import SwiftData

@Model
class SchoolClass {
    var name: String
    var grade: String
    
    @Relationship(deleteRule: .cascade, inverse: \Student.schoolClass)
    var students: [Student] = []
    
    var categories: [AssessmentCategory]
    
    @Relationship(deleteRule: .cascade)
    var attendanceSessions: [AttendanceSession]
    
    @Relationship(deleteRule: .cascade, inverse: \Subject.schoolClass)
    var subjects: [Subject] = []
    
    var sortOrder: Int
    
    init(
        name: String,
        grade: String,
        sortOrder: Int = 0,
        students: [Student] = [],
        categories: [AssessmentCategory] = [],
        attendanceSessions: [AttendanceSession] = [],
        subjects: [Subject] = []
    ) {
        self.name = name
        self.grade = grade
        self.students = students
        self.categories = categories
        self.attendanceSessions = attendanceSessions
        self.subjects = subjects
        self.sortOrder = sortOrder
    }
}
