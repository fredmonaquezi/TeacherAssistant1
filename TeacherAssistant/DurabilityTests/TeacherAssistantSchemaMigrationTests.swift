#if DURABILITY_TESTS
import SwiftData
import XCTest

@testable import TeacherAssistant

@MainActor
final class TeacherAssistantSchemaMigrationTests: XCTestCase {
    func testV1StoreOpensWithCurrentSchemaMigrationPlan() throws {
        let storeName = PersistenceMigrationTestHarness.uniqueStoreName()

        try PersistenceMigrationTestHarness.createLegacyV1Store(named: storeName) { context in
            let schoolClass = SchoolClass(name: "Migration Room", grade: "4")
            context.insert(schoolClass)
        }

        let migratedContainer = try PersistenceMigrationTestHarness.openCurrentStore(named: storeName)
        let restoredClasses = try migratedContainer.mainContext.fetch(FetchDescriptor<SchoolClass>())

        XCTAssertEqual(restoredClasses.count, 1)
        XCTAssertEqual(restoredClasses.first?.name, "Migration Room")
        XCTAssertEqual(restoredClasses.first?.grade, "4")
    }

    func testMigrationHarnessCanSeedLegacyRelationships() throws {
        let storeName = PersistenceMigrationTestHarness.uniqueStoreName()

        try PersistenceMigrationTestHarness.createLegacyV1Store(named: storeName) { context in
            let schoolClass = SchoolClass(name: "Migration Class", grade: "5")
            let student = Student(name: "Legacy Student")
            schoolClass.students.append(student)
            context.insert(schoolClass)
        }

        let migratedContainer = try PersistenceMigrationTestHarness.openCurrentStore(named: storeName)
        let restoredClasses = try migratedContainer.mainContext.fetch(FetchDescriptor<SchoolClass>())

        XCTAssertEqual(restoredClasses.count, 1)
        XCTAssertEqual(restoredClasses.first?.students.count, 1)
        XCTAssertEqual(restoredClasses.first?.students.first?.name, "Legacy Student")
    }
}
#endif
