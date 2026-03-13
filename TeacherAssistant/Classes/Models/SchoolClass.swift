import Foundation
import SwiftData

@Model
class SchoolClass {
    var name: String
    var grade: String
    var schoolYear: String?
    
    @Relationship(deleteRule: .cascade, inverse: \Student.schoolClass)
    var students: [Student] = []
    
    var categories: [AssessmentCategory]
    
    @Relationship(deleteRule: .cascade)
    var attendanceSessions: [AttendanceSession]
    
    @Relationship(deleteRule: .cascade, inverse: \Subject.schoolClass)
    var subjects: [Subject] = []

    @Relationship(deleteRule: .cascade, inverse: \SeatingChart.schoolClass)
    var seatingChart: SeatingChart?

    @Relationship(deleteRule: .cascade, inverse: \ParticipationEvent.schoolClass)
    var participationEvents: [ParticipationEvent] = []

    @Relationship(deleteRule: .cascade, inverse: \BehaviorSupportEvent.schoolClass)
    var behaviorSupportEvents: [BehaviorSupportEvent] = []

    @Relationship(deleteRule: .cascade, inverse: \LiveObservation.schoolClass)
    var liveObservations: [LiveObservation] = []
    
    var sortOrder: Int
    
    init(
        name: String,
        grade: String,
        schoolYear: String? = nil,
        sortOrder: Int = 0,
        students: [Student] = [],
        categories: [AssessmentCategory] = [],
        attendanceSessions: [AttendanceSession] = [],
        subjects: [Subject] = [],
        seatingChart: SeatingChart? = nil,
        participationEvents: [ParticipationEvent] = [],
        behaviorSupportEvents: [BehaviorSupportEvent] = [],
        liveObservations: [LiveObservation] = []
    ) {
        self.name = name
        self.grade = grade
        self.schoolYear = schoolYear
        self.students = students
        self.categories = categories
        self.attendanceSessions = attendanceSessions
        self.subjects = subjects
        self.seatingChart = seatingChart
        self.participationEvents = participationEvents
        self.behaviorSupportEvents = behaviorSupportEvents
        self.liveObservations = liveObservations
        self.sortOrder = sortOrder
    }
}
