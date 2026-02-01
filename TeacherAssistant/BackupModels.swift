import Foundation

struct BackupFile: Codable {
    var classes: [BackupClass]
}

struct BackupClass: Codable {
    var name: String
    var grade: String
    var students: [BackupStudent]
    var subjects: [BackupSubject]
}

struct BackupStudent: Codable {
    var name: String
    var sortOrder: Int
    var isParticipatingWell: Bool
    var needsHelp: Bool
    var missingHomework: Bool
}


struct BackupSubject: Codable {
    var name: String
    var sortOrder: Int
    var units: [BackupUnit]
}

struct BackupUnit: Codable {
    var name: String
    var sortOrder: Int
    var assessments: [BackupAssessment]
}

struct BackupAssessment: Codable {
    var title: String
    var details: String
    var sortOrder: Int
    var results: [BackupResult]
}

struct BackupResult: Codable {
    var studentName: String
    var score: Double
    var notes: String
}
