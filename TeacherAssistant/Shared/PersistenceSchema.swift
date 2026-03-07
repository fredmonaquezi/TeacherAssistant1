import SwiftData

private enum TeacherAssistantSchemaModelCatalog {
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

enum TeacherAssistantSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        TeacherAssistantSchemaModelCatalog.models
    }
}

enum TeacherAssistantSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        TeacherAssistantSchemaModelCatalog.models
    }
}

enum TeacherAssistantMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [TeacherAssistantSchemaV1.self, TeacherAssistantSchemaV2.self]
    }

    static var stages: [MigrationStage] {
        []
    }
}

enum PersistenceSchema {
    typealias CurrentVersion = TeacherAssistantSchemaV2
    typealias MigrationPlan = TeacherAssistantMigrationPlan

    static var schema: Schema {
        Schema(CurrentVersion.models)
    }
}
