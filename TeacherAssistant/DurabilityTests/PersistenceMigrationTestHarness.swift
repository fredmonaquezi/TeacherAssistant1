#if DURABILITY_TESTS
import Foundation
import SwiftData

@testable import TeacherAssistant

@MainActor
enum PersistenceMigrationTestHarness {
    static func uniqueStoreName() -> String {
        "TeacherAssistantMigrationHarness-\(UUID().uuidString)"
    }

    static func createLegacyV1Store(
        named storeName: String,
        seed: (ModelContext) throws -> Void = { _ in }
    ) throws {
        let legacySchema = Schema(TeacherAssistantSchemaV1.models)
        let configuration = ModelConfiguration(
            storeName,
            schema: legacySchema,
            isStoredInMemoryOnly: false
        )
        let container = try ModelContainer(
            for: legacySchema,
            configurations: [configuration]
        )

        try seed(container.mainContext)

        if container.mainContext.hasChanges {
            try container.mainContext.save()
        }
    }

    static func openCurrentStore(named storeName: String) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            storeName,
            schema: PersistenceSchema.schema,
            isStoredInMemoryOnly: false
        )
        return try ModelContainer(
            for: PersistenceSchema.schema,
            migrationPlan: PersistenceSchema.MigrationPlan.self,
            configurations: [configuration]
        )
    }
}
#endif
