import SwiftData

private enum TeacherAssistantSchemaModelCatalog {
    static var models: [any PersistentModel.Type] {
        [
            SchoolClass.self,
            SeatingChart.self,
            SeatingPlacement.self,
            ParticipationEvent.self,
            BehaviorSupportEvent.self,
            LiveObservation.self,
            LiveObservationChecklistResponse.self,
            LiveObservationTemplate.self,
            LiveObservationTemplateCriterion.self,
            Student.self,
            Subject.self,
            Unit.self,
            Assessment.self,
            Assignment.self,
            Intervention.self,
            StudentResult.self,
            StudentAssignment.self,
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
        [
            TeacherAssistantSchemaV1.self,
            TeacherAssistantSchemaV2.self,
            TeacherAssistantSchemaV3.self,
            TeacherAssistantSchemaV4.self,
            TeacherAssistantSchemaV5.self,
            TeacherAssistantSchemaV6.self,
            TeacherAssistantSchemaV7.self,
            TeacherAssistantSchemaV8.self,
            TeacherAssistantSchemaV9.self,
            TeacherAssistantSchemaV10.self,
            TeacherAssistantSchemaV11.self,
        ]
    }

    static var stages: [MigrationStage] {
        []
    }
}

enum TeacherAssistantSchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        TeacherAssistantSchemaModelCatalog.models
    }
}

enum TeacherAssistantSchemaV4: VersionedSchema {
    static let versionIdentifier = Schema.Version(4, 0, 0)

    static var models: [any PersistentModel.Type] {
        TeacherAssistantSchemaModelCatalog.models
    }
}

enum TeacherAssistantSchemaV5: VersionedSchema {
    static let versionIdentifier = Schema.Version(5, 0, 0)

    static var models: [any PersistentModel.Type] {
        TeacherAssistantSchemaModelCatalog.models
    }
}

enum TeacherAssistantSchemaV6: VersionedSchema {
    static let versionIdentifier = Schema.Version(6, 0, 0)

    static var models: [any PersistentModel.Type] {
        TeacherAssistantSchemaModelCatalog.models
    }
}

enum TeacherAssistantSchemaV7: VersionedSchema {
    static let versionIdentifier = Schema.Version(7, 0, 0)

    static var models: [any PersistentModel.Type] {
        TeacherAssistantSchemaModelCatalog.models
    }
}

enum TeacherAssistantSchemaV8: VersionedSchema {
    static let versionIdentifier = Schema.Version(8, 0, 0)

    static var models: [any PersistentModel.Type] {
        TeacherAssistantSchemaModelCatalog.models
    }
}

enum TeacherAssistantSchemaV9: VersionedSchema {
    static let versionIdentifier = Schema.Version(9, 0, 0)

    static var models: [any PersistentModel.Type] {
        TeacherAssistantSchemaModelCatalog.models
    }
}

enum TeacherAssistantSchemaV10: VersionedSchema {
    static let versionIdentifier = Schema.Version(10, 0, 0)

    static var models: [any PersistentModel.Type] {
        TeacherAssistantSchemaModelCatalog.models
    }
}

enum TeacherAssistantSchemaV11: VersionedSchema {
    static let versionIdentifier = Schema.Version(11, 0, 0)

    static var models: [any PersistentModel.Type] {
        TeacherAssistantSchemaModelCatalog.models
    }
}

enum PersistenceSchema {
    typealias CurrentVersion = TeacherAssistantSchemaV11
    typealias MigrationPlan = TeacherAssistantMigrationPlan

    static var schema: Schema {
        Schema(CurrentVersion.models)
    }
}
