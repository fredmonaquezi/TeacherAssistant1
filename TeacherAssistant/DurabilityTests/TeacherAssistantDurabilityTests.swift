#if DURABILITY_TESTS
import SwiftData
import XCTest

@testable import TeacherAssistant

final class TeacherAssistantDurabilityTests: XCTestCase {
    @MainActor
    func testVersionedBackupDecodesOlderPayloadDefaults() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let backupClass = BackupClass(
            name: "Room 12",
            grade: "4",
            students: [
                BackupStudent(
                    name: "Alex Smith",
                    sortOrder: 0,
                    isParticipatingWell: false,
                    needsHelp: false,
                    missingHomework: false
                )
            ],
            subjects: []
        )

        let payload = VersionedBackupFile(
            classes: [backupClass],
            runningRecords: [],
            rubricTemplates: [],
            developmentScores: [],
            calendarEvents: [],
            classDiaryEntries: [],
            libraryFolders: [],
            libraryFiles: [],
            usefulLinks: [],
            appSettings: nil
        )

        let encodedPayload = try encoder.encode(payload)
        guard var jsonObject = try JSONSerialization.jsonObject(with: encodedPayload) as? [String: Any] else {
            XCTFail("Failed to parse encoded backup payload")
            return
        }

        jsonObject.removeValue(forKey: "libraryFolders")
        jsonObject.removeValue(forKey: "libraryFiles")
        jsonObject.removeValue(forKey: "usefulLinks")
        jsonObject["appSettings"] = [
            "appLanguage": "en",
            "helperRotation": "",
            "guardianRotation": "",
            "lineLeaderRotation": "",
            "messengerRotation": "",
            "customCategoriesData": "",
            "customRotationData": "",
        ]

        let legacyCompatibleData = try JSONSerialization.data(withJSONObject: jsonObject, options: [.sortedKeys])

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedPayload = try decoder.decode(VersionedBackupFile.self, from: legacyCompatibleData)

        XCTAssertEqual(decodedPayload.classes.count, 1)
        XCTAssertTrue(decodedPayload.libraryFolders.isEmpty)
        XCTAssertTrue(decodedPayload.libraryFiles.isEmpty)
        XCTAssertTrue(decodedPayload.usefulLinks.isEmpty)
        XCTAssertEqual(decodedPayload.appSettings?.dateFormat, AppDateFormatPreference.system.rawValue)
        XCTAssertEqual(decodedPayload.appSettings?.timeFormat, AppTimeFormatPreference.system.rawValue)
        XCTAssertEqual(decodedPayload.appSettings?.defaultLandingSection, AppSection.dashboard.rawValue)
    }

    func testSnapshotRetentionPolicyKeepsNewestAndDailyHistory() {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_709_478_000)
        let files = [
            RetainedSnapshotFile(url: url(named: "snapshot-0"), createdAt: now),
            RetainedSnapshotFile(url: url(named: "snapshot-1"), createdAt: now.addingTimeInterval(-3_600)),
            RetainedSnapshotFile(url: url(named: "snapshot-2"), createdAt: now.addingTimeInterval(-7_200)),
            RetainedSnapshotFile(url: url(named: "snapshot-3"), createdAt: calendar.date(byAdding: .day, value: -1, to: now)!),
            RetainedSnapshotFile(url: url(named: "snapshot-4"), createdAt: calendar.date(byAdding: .day, value: -1, to: now)!.addingTimeInterval(-3_600)),
            RetainedSnapshotFile(url: url(named: "snapshot-5"), createdAt: calendar.date(byAdding: .day, value: -2, to: now)!),
            RetainedSnapshotFile(url: url(named: "snapshot-6"), createdAt: calendar.date(byAdding: .day, value: -4, to: now)!),
        ]

        let retained = SnapshotRetentionPolicy.urlsToKeep(
            files: files,
            keepLatestCount: 3,
            keepOnePerDayForLastDays: 3,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(retained.count, 5)
        XCTAssertTrue(retained.contains(url(named: "snapshot-0")))
        XCTAssertTrue(retained.contains(url(named: "snapshot-1")))
        XCTAssertTrue(retained.contains(url(named: "snapshot-2")))
        XCTAssertTrue(retained.contains(url(named: "snapshot-3")))
        XCTAssertTrue(retained.contains(url(named: "snapshot-5")))
        XCTAssertFalse(retained.contains(url(named: "snapshot-4")))
        XCTAssertFalse(retained.contains(url(named: "snapshot-6")))
    }

    func testRestoreExecutionCoordinatorPreservesSafetySnapshotOnApplyFailure() {
        let expectedSnapshotURL = URL(fileURLWithPath: "/tmp/pre-restore.backup")

        do {
            _ = try RestoreExecutionCoordinator.prepareAndApply(
                loadPayload: { ["replacement"] },
                validatePayload: { _ in },
                createSafetySnapshot: { expectedSnapshotURL },
                applyPayload: { _ in
                    throw NSError(
                        domain: "TeacherAssistantDurabilityTests",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Apply failed"]
                    )
                }
            )
            XCTFail("Expected restore apply to fail")
        } catch let RestoreExecutionError.applyFailed(preRestoreSnapshotURL, underlyingError) {
            XCTAssertEqual(preRestoreSnapshotURL, expectedSnapshotURL)
            XCTAssertEqual(underlyingError.localizedDescription, "Apply failed")
        } catch {
            XCTFail("Unexpected error: \(error.localizedDescription)")
        }
    }

    func testBootstrapRecoveryStateCapturesStartupFailure() {
        let expectedSnapshotURL = URL(fileURLWithPath: "/tmp/latest-local-snapshot.backup")
        let startupError = NSError(
            domain: "TeacherAssistantDurabilityTests",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: "Primary store is corrupted"]
        )

        let recoveryState = BootstrapRecoveryState.from(
            startupError: startupError,
            latestLocalSnapshotURL: expectedSnapshotURL
        )

        XCTAssertEqual(recoveryState.startupFailureDescription, "Primary store is corrupted")
        XCTAssertEqual(recoveryState.latestLocalSnapshotURL, expectedSnapshotURL)
    }

    @MainActor
    func testBackupRoundTripBetweenPersistentStores() async throws {
        let sourceContainer = try makePersistentContainer(named: "source")
        let destinationContainer = try makePersistentContainer(named: "destination")

        let sourceContext = sourceContainer.mainContext
        let schoolClass = SchoolClass(name: "Room 7", grade: "2", schoolYear: "2025-2026")
        schoolClass.categories = [AssessmentCategory(title: "Reading")]

        let student = Student(name: "Alex Smith")
        student.scores = [AssessmentScore(value: 4)]
        schoolClass.students.append(student)
        sourceContext.insert(schoolClass)
        sourceContext.insert(
            UsefulLink(
                title: "Reading Practice",
                url: "https://example.com/reading",
                linkDescription: "Small-group activity"
            )
        )
        try sourceContext.save()

        let backupURL = try await exportBackupRetryingRateLimit(context: sourceContext)
        defer { try? FileManager.default.removeItem(at: backupURL) }

        try await importBackupRetryingRateLimit(
            from: backupURL,
            context: destinationContainer.mainContext
        )

        let restoredClasses = try destinationContainer.mainContext.fetch(FetchDescriptor<SchoolClass>())
        XCTAssertEqual(restoredClasses.count, 1)
        XCTAssertEqual(restoredClasses.first?.name, "Room 7")
        XCTAssertEqual(restoredClasses.first?.students.count, 1)
        XCTAssertEqual(restoredClasses.first?.students.first?.name, "Alex Smith")
        XCTAssertEqual(restoredClasses.first?.students.first?.scores.count, 1)
        XCTAssertEqual(restoredClasses.first?.students.first?.scores.first?.value, 4)

        let restoredLinks = try destinationContainer.mainContext.fetch(FetchDescriptor<UsefulLink>())
        XCTAssertEqual(restoredLinks.count, 1)
        XCTAssertEqual(restoredLinks.first?.url, "https://example.com/reading")
    }

    @MainActor
    func testLegacyBackupFixtureRestoresIntoPersistentStore() async throws {
        let destinationContainer = try makePersistentContainer(named: "legacy-fixture")

        try await importBackupRetryingRateLimit(
            from: fixtureURL(named: "legacy-backup-v1.backup"),
            context: destinationContainer.mainContext
        )

        let restoredClasses = try destinationContainer.mainContext.fetch(FetchDescriptor<SchoolClass>())
        XCTAssertEqual(restoredClasses.count, 1)

        let restoredClass = try XCTUnwrap(restoredClasses.first)
        XCTAssertEqual(restoredClass.name, "Legacy Room")
        XCTAssertEqual(restoredClass.grade, "3")
        XCTAssertEqual(restoredClass.schoolYear, "2023-2024")
        XCTAssertEqual(restoredClass.sortOrder, 2)
        XCTAssertEqual(restoredClass.categories.count, 1)
        XCTAssertEqual(restoredClass.categories.first?.title, "Writing")

        XCTAssertEqual(restoredClass.students.count, 1)
        let restoredStudent = try XCTUnwrap(restoredClass.students.first)
        XCTAssertEqual(restoredStudent.name, "Legacy Student")
        XCTAssertEqual(restoredStudent.sortOrder, 1)
        XCTAssertTrue(restoredStudent.isParticipatingWell)
        XCTAssertTrue(restoredStudent.missingHomework)
        XCTAssertEqual(restoredStudent.scores.count, 1)
        XCTAssertEqual(restoredStudent.scores.first?.value, 0)

        XCTAssertEqual(restoredClass.subjects.count, 1)
        let restoredSubject = try XCTUnwrap(restoredClass.subjects.first)
        XCTAssertEqual(restoredSubject.name, "Language Arts")
        XCTAssertEqual(restoredSubject.sortOrder, 0)

        XCTAssertEqual(restoredSubject.units.count, 1)
        let restoredUnit = try XCTUnwrap(restoredSubject.units.first)
        XCTAssertEqual(restoredUnit.name, "Narrative Unit")

        XCTAssertEqual(restoredUnit.assessments.count, 1)
        let restoredAssessment = try XCTUnwrap(restoredUnit.assessments.first)
        XCTAssertEqual(restoredAssessment.title, "Personal Narrative")
        XCTAssertEqual(restoredAssessment.details, "Draft submission")
        XCTAssertEqual(restoredAssessment.maxScore, 20)
        XCTAssertEqual(restoredAssessment.sortOrder, 0)
        XCTAssertEqual(restoredAssessment.results.count, 1)
        let restoredResult = try XCTUnwrap(restoredAssessment.results.first)
        XCTAssertEqual(restoredResult.student?.name, "Legacy Student")
        XCTAssertEqual(restoredResult.score, 18)
        XCTAssertEqual(restoredResult.notes, "Strong detail")

        let restoredLinks = try destinationContainer.mainContext.fetch(FetchDescriptor<UsefulLink>())
        XCTAssertTrue(restoredLinks.isEmpty)
    }

    @MainActor
    func testOlderVersionedBackupFixtureRestoresIntoPersistentStore() async throws {
        let destinationContainer = try makePersistentContainer(named: "versioned-v5-fixture")
        let preservedDefaults = preserveUserDefaults(for: [
            "appLanguage",
            "helperRotation",
            AppPreferencesKeys.dateFormat,
            AppPreferencesKeys.timeFormat,
            AppPreferencesKeys.defaultLandingSection
        ])
        defer { restoreUserDefaults(preservedDefaults) }

        try await importBackupRetryingRateLimit(
            from: fixtureURL(named: "versioned-backup-v5.backup"),
            context: destinationContainer.mainContext
        )

        let restoredClasses = try destinationContainer.mainContext.fetch(FetchDescriptor<SchoolClass>())
        XCTAssertEqual(restoredClasses.count, 1)

        let restoredClass = try XCTUnwrap(restoredClasses.first)
        XCTAssertEqual(restoredClass.name, "Versioned Room")
        XCTAssertEqual(restoredClass.grade, "5")
        XCTAssertEqual(restoredClass.schoolYear, "2024-2025")
        XCTAssertEqual(restoredClass.categories.count, 1)
        XCTAssertEqual(restoredClass.categories.first?.title, "Science")

        let restoredStudent = try XCTUnwrap(restoredClass.students.first)
        XCTAssertEqual(restoredStudent.name, "Versioned Student")
        XCTAssertEqual(restoredStudent.scores.count, 1)
        XCTAssertEqual(restoredStudent.scores.first?.value, 3)

        let restoredRunningRecords = try destinationContainer.mainContext.fetch(FetchDescriptor<RunningRecord>())
        XCTAssertEqual(restoredRunningRecords.count, 1)
        let restoredRunningRecord = try XCTUnwrap(restoredRunningRecords.first)
        XCTAssertEqual(restoredRunningRecord.student?.name, "Versioned Student")
        XCTAssertEqual(restoredRunningRecord.textTitle, "Volcanoes")
        XCTAssertEqual(restoredRunningRecord.bookLevel, "R")
        XCTAssertEqual(restoredRunningRecord.totalWords, 120)
        XCTAssertEqual(restoredRunningRecord.errors, 4)
        XCTAssertEqual(restoredRunningRecord.selfCorrections, 2)
        XCTAssertEqual(restoredRunningRecord.notes, "Needed help with two words")

        let restoredLinks = try destinationContainer.mainContext.fetch(FetchDescriptor<UsefulLink>())
        XCTAssertTrue(restoredLinks.isEmpty)

        let defaults = UserDefaults.standard
        XCTAssertEqual(defaults.string(forKey: "appLanguage"), "pt-BR")
        XCTAssertEqual(defaults.string(forKey: "helperRotation"), "Ada")
        XCTAssertEqual(defaults.string(forKey: AppPreferencesKeys.dateFormat), AppDateFormatPreference.system.rawValue)
        XCTAssertEqual(defaults.string(forKey: AppPreferencesKeys.timeFormat), AppTimeFormatPreference.system.rawValue)
        XCTAssertEqual(defaults.string(forKey: AppPreferencesKeys.defaultLandingSection), AppSection.dashboard.rawValue)
    }

    @MainActor
    private func makePersistentContainer(named suffix: String) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "TeacherAssistantDurabilityTests-\(suffix)-\(UUID().uuidString)",
            schema: PersistenceSchema.schema,
            isStoredInMemoryOnly: false
        )

        return try ModelContainer(
            for: PersistenceSchema.schema,
            migrationPlan: PersistenceSchema.MigrationPlan.self,
            configurations: [configuration]
        )
    }

    private func url(named name: String) -> URL {
        URL(fileURLWithPath: "/tmp/\(name)")
    }

    private func fixtureURL(named name: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("DurabilityTestFixtures", isDirectory: true)
            .appendingPathComponent(name)
    }

    @MainActor
    private func exportBackupRetryingRateLimit(context: ModelContext) async throws -> URL {
        try await performBackupOperationWithRetry {
            try BackupManager.exportBackup(context: context)
        }
    }

    @MainActor
    private func importBackupRetryingRateLimit(from url: URL, context: ModelContext) async throws {
        _ = try await performBackupOperationWithRetry {
            try BackupManager.importBackup(from: url, context: context)
            return ()
        }
    }

    @MainActor
    private func performBackupOperationWithRetry<T>(
        maxAttempts: Int = 4,
        operation: () throws -> T
    ) async throws -> T {
        precondition(maxAttempts > 0, "maxAttempts must be greater than zero")
        var attempt = 1

        while true {
            do {
                return try operation()
            } catch BackupError.rateLimited(let remainingSeconds) where attempt < maxAttempts {
                attempt += 1
                let retryDelaySeconds = max(remainingSeconds + 1, 1)
                let nanoseconds = UInt64(retryDelaySeconds) * 1_000_000_000
                try await Task.sleep(nanoseconds: nanoseconds)
            } catch {
                throw error
            }
        }
    }

    private func preserveUserDefaults(for keys: [String]) -> [String: Any?] {
        let defaults = UserDefaults.standard
        return Dictionary(
            uniqueKeysWithValues: keys.map { key in
                (key, defaults.object(forKey: key))
            }
        )
    }

    private func restoreUserDefaults(_ snapshot: [String: Any?]) {
        let defaults = UserDefaults.standard
        for (key, value) in snapshot {
            if let value {
                defaults.set(value, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
    }
}
#endif
