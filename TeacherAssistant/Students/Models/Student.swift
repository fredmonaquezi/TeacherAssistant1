import Foundation
import SwiftData

enum StudentGender: String, Codable, CaseIterable {
    case male = "Male"
    case female = "Female"
    case nonBinary = "Non-binary"
    case preferNotToSay = "Prefer not to say"
}

@Model
class Student {
    var uuid: UUID = UUID()
    var name: String
    var firstName: String?
    var lastName: String?
    var notes: String = ""
    var gender: String = "Prefer not to say" // Stores StudentGender rawValue
    
    var isParticipatingWell: Bool = false
    var needsHelp: Bool = false
    var missingHomework: Bool = false
    
    var sortOrder: Int = 0
    
    // Comma-separated UUID strings to avoid grouping with.
    // Legacy values using String(describing: PersistentIdentifier) are still read.
    var separationList: String = ""
    
    var schoolClass: SchoolClass?

    @Relationship(deleteRule: .cascade)
    var scores: [AssessmentScore] = []
    
    @Relationship(deleteRule: .cascade)
    var runningRecords: [RunningRecord] = []
    
    // Computed property for easier access
    var genderEnum: StudentGender {
        get { StudentGender(rawValue: gender) ?? .preferNotToSay }
        set { gender = newValue.rawValue }
    }
    
    init(
        name: String,
        notes: String = "",
        gender: StudentGender = .preferNotToSay,
        isParticipatingWell: Bool = false,
        needsHelp: Bool = false,
        missingHomework: Bool = false,
        scores: [AssessmentScore] = [],
        separationList: String = ""
    ) {
        self.uuid = UUID()
        self.name = name
        self.firstName = nil
        self.lastName = nil
        self.notes = notes
        self.gender = gender.rawValue
        self.isParticipatingWell = isParticipatingWell
        self.needsHelp = needsHelp
        self.missingHomework = missingHomework
        self.scores = scores
        self.sortOrder = 0
        self.separationList = separationList
    }

    var stableIDString: String {
        uuid.uuidString
    }

    var separationTokens: [String] {
        separationList
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    func hasSeparation(with other: Student) -> Bool {
        let legacyPersistentID = String(describing: other.id)
        return separationTokens.contains { token in
            token == other.stableIDString || token == legacyPersistentID
        }
    }

    var isSupportPartnerCandidate: Bool {
        !needsHelp && (isParticipatingWell || !missingHomework)
    }
}
