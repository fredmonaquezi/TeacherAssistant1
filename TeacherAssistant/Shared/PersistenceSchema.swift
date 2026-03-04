import SwiftData

enum TeacherAssistantSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            SchoolClass.self,
            Student.self,
            Subject.self,
            Unit.self,
            Assessment.self,
            StudentResult.self,
            AssessmentCategory.self,
            AssessmentScore.self,
            AttendanceSession.self,
            AttendanceRecord.self,
            LibraryFolder.self,
            LibraryFile.self,
            RubricTemplate.self,
            RubricCategory.self,
            RubricCriterion.self,
            DevelopmentScore.self,
            RunningRecord.self,
            CalendarEvent.self,
            ClassDiaryEntry.self,
            UsefulLink.self,
        ]
    }
}

enum TeacherAssistantMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [TeacherAssistantSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}

enum PersistenceSchema {
    typealias CurrentVersion = TeacherAssistantSchemaV1
    typealias MigrationPlan = TeacherAssistantMigrationPlan

    static var schema: Schema {
        Schema(CurrentVersion.models)
    }
}
