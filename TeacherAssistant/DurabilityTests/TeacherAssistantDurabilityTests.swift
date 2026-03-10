#if DURABILITY_TESTS
import SwiftData
import XCTest

@testable import TeacherAssistant

final class TeacherAssistantDurabilityTests: XCTestCase {
    private var testApplicationSupportRoot: URL?

    @MainActor
    override func setUpWithError() throws {
        try super.setUpWithError()
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("TeacherAssistantDurabilityTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true,
            attributes: nil
        )
        testApplicationSupportRoot = root
        BackupManager.setApplicationSupportDirectoryOverrideForTests(root)
    }

    @MainActor
    override func tearDownWithError() throws {
        BackupManager.setApplicationSupportDirectoryOverrideForTests(nil)
        if let root = testApplicationSupportRoot {
            try? FileManager.default.removeItem(at: root)
        }
        testApplicationSupportRoot = nil
        try super.tearDownWithError()
    }

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

    func testDerivationRunnerReturnsComputedResult() async {
        let derived = await DerivationRunner.runAsync(
            compute: { 21 },
            cancelledResult: -1
        ) { computation in
            computation * 2
        }

        XCTAssertEqual(derived, 42)
    }

    func testDerivationRunnerReturnsCancelledFallbackWhenTaskIsCancelled() async {
        let result = await Task.detached { () -> Int in
            withUnsafeCurrentTask { task in
                task?.cancel()
            }

            return await DerivationRunner.runAsync(
                compute: { 21 },
                cancelledResult: -1
            ) { computation in
                computation * 2
            }
        }.value

        XCTAssertEqual(result, -1)
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

    func testBootstrapStartupServiceFallsBackFromCorruptedStorePath() {
        let candidateStores = ["CorruptedStorePath", "TeacherAssistant-V5-WithGroups"]
        var attemptedStores: [String] = []
        var snapshotLookups = 0

        let resolution: BootstrapStoreStartupResolution<String> =
            BootstrapStoreStartupService.resolve(
                candidateStoreNames: candidateStores,
                openStore: { storeName in
                    attemptedStores.append(storeName)
                    if storeName == "CorruptedStorePath" {
                        throw NSError(
                            domain: "TeacherAssistantDurabilityTests",
                            code: 30,
                            userInfo: [NSLocalizedDescriptionKey: "Store is corrupted"]
                        )
                    }
                    return storeName
                },
                latestLocalSnapshotURL: {
                    snapshotLookups += 1
                    return URL(fileURLWithPath: "/tmp/should-not-be-requested.backup")
                }
            )

        switch resolution {
        case .opened(let openedStore):
            XCTAssertEqual(openedStore.storeName, "TeacherAssistant-V5-WithGroups")
            XCTAssertEqual(openedStore.store, "TeacherAssistant-V5-WithGroups")
        case .recovery:
            XCTFail("Expected startup service to recover by opening the primary store")
        }

        XCTAssertEqual(attemptedStores, candidateStores)
        XCTAssertEqual(snapshotLookups, 0)
    }

    func testBootstrapStartupServiceReturnsRecoveryStateWhenAllStoresFail() {
        let candidateStores = ["CorruptedStorePath", "TeacherAssistant-V5-WithGroups"]
        let expectedSnapshotURL = URL(fileURLWithPath: "/tmp/latest-local-snapshot.backup")
        var attemptedStores: [String] = []

        let resolution: BootstrapStoreStartupResolution<String> =
            BootstrapStoreStartupService.resolve(
                candidateStoreNames: candidateStores,
                openStore: { storeName in
                    attemptedStores.append(storeName)
                    throw NSError(
                        domain: "TeacherAssistantDurabilityTests",
                        code: 31,
                        userInfo: [NSLocalizedDescriptionKey: "Unable to open store \(storeName)"]
                    )
                },
                latestLocalSnapshotURL: { expectedSnapshotURL }
            )

        switch resolution {
        case .opened:
            XCTFail("Expected startup service to enter recovery mode when all startup stores fail")
        case .recovery(let recoveryState):
            XCTAssertEqual(recoveryState.startupFailureDescription, "The app could not open your data store.")
            XCTAssertEqual(recoveryState.latestLocalSnapshotURL, expectedSnapshotURL)
        }

        XCTAssertEqual(attemptedStores, candidateStores)
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
    func testBackupImportValidationFailurePreservesExistingStoreAndSkipsSafetySnapshot() async throws {
        let destinationContainer = try makePersistentContainer(named: "invalid-import")
        let destinationContext = destinationContainer.mainContext

        let existingClass = SchoolClass(name: "Existing Room", grade: "1", schoolYear: "2025-2026")
        destinationContext.insert(existingClass)
        try destinationContext.save()

        let snapshotDirectory = try preRestoreSnapshotDirectoryURL(createIfMissing: true)
        let snapshotsBefore = Set(preRestoreSnapshotFiles(in: snapshotDirectory))

        let invalidBackupURL = URL(fileURLWithPath: "/tmp/\(UUID().uuidString)-invalid.backup")
        try Data("not-json".utf8).write(to: invalidBackupURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: invalidBackupURL) }

        do {
            try await importBackupRetryingRateLimit(from: invalidBackupURL, context: destinationContext)
            XCTFail("Expected invalid backup import to fail")
        } catch BackupError.invalidData(let reason) {
            XCTAssertEqual(reason, "Backup file is not valid JSON")
        } catch {
            XCTFail("Unexpected error: \(error.localizedDescription)")
        }

        let restoredClasses = try destinationContext.fetch(FetchDescriptor<SchoolClass>())
        XCTAssertEqual(restoredClasses.count, 1)
        XCTAssertEqual(restoredClasses.first?.name, "Existing Room")

        let snapshotsAfter = Set(preRestoreSnapshotFiles(in: snapshotDirectory))
        XCTAssertEqual(snapshotsAfter, snapshotsBefore)
    }

    @MainActor
    func testBackupImportCreatesSafetySnapshotWithPreRestoreState() async throws {
        let sourceContainer = try makePersistentContainer(named: "snapshot-source")
        let destinationContainer = try makePersistentContainer(named: "snapshot-destination")

        let sourceContext = sourceContainer.mainContext
        let importedClass = SchoolClass(name: "Imported Room", grade: "4", schoolYear: "2025-2026")
        importedClass.students = [Student(name: "Imported Student")]
        sourceContext.insert(importedClass)
        try sourceContext.save()

        let backupURL = try await exportBackupRetryingRateLimit(context: sourceContext)
        defer { try? FileManager.default.removeItem(at: backupURL) }

        let destinationContext = destinationContainer.mainContext
        let existingClass = SchoolClass(name: "Existing Room", grade: "2", schoolYear: "2024-2025")
        destinationContext.insert(existingClass)
        try destinationContext.save()

        let snapshotDirectory = try preRestoreSnapshotDirectoryURL(createIfMissing: true)
        let snapshotsBefore = Set(preRestoreSnapshotFiles(in: snapshotDirectory))

        try await importBackupRetryingRateLimit(from: backupURL, context: destinationContext)

        let restoredClasses = try destinationContext.fetch(FetchDescriptor<SchoolClass>())
        XCTAssertEqual(restoredClasses.count, 1)
        XCTAssertEqual(restoredClasses.first?.name, "Imported Room")

        let snapshotsAfter = Set(preRestoreSnapshotFiles(in: snapshotDirectory))
        let newSnapshots = snapshotsAfter.subtracting(snapshotsBefore)
        XCTAssertFalse(newSnapshots.isEmpty, "Import should create a pre-restore safety snapshot")

        let newSnapshotURLs = Array(newSnapshots)
        defer {
            for url in newSnapshotURLs {
                try? FileManager.default.removeItem(at: url)
            }
        }

        let newestSnapshotURL = try XCTUnwrap(
            newSnapshotURLs.max(by: { lhs, rhs in snapshotTimestamp(for: lhs) < snapshotTimestamp(for: rhs) })
        )

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshotData = try Data(contentsOf: newestSnapshotURL)
        let snapshotPayload = try decoder.decode(VersionedBackupFile.self, from: snapshotData)

        XCTAssertTrue(snapshotPayload.classes.contains(where: { $0.name == "Existing Room" }))
        XCTAssertFalse(snapshotPayload.classes.contains(where: { $0.name == "Imported Room" }))
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
    func testStressVersionedBackupFixtureRestoresIntoPersistentStore() async throws {
        let destinationContainer = try makePersistentContainer(named: "stress-versioned-fixture")
        let fixture = makeVersionedStressBackupFixture(
            classCount: 18,
            studentsPerClass: 20,
            subjectsPerClass: 2,
            unitsPerSubject: 2,
            assessmentsPerUnit: 2,
            resultsPerAssessment: 4,
            usefulLinkCount: 30,
            libraryFolderCount: 24,
            libraryFileCount: 72
        )

        let fixtureURL = try writeVersionedFixtureToTemporaryFile(
            fixture,
            filePrefix: "stress-versioned-backup"
        )
        defer { try? FileManager.default.removeItem(at: fixtureURL) }

        try await importBackupRetryingRateLimit(
            from: fixtureURL,
            context: destinationContainer.mainContext
        )

        let restoredClasses = try destinationContainer.mainContext.fetch(FetchDescriptor<SchoolClass>())
        XCTAssertEqual(restoredClasses.count, 18)

        let restoredStudents = try destinationContainer.mainContext.fetch(FetchDescriptor<Student>())
        XCTAssertEqual(restoredStudents.count, 360)

        let restoredRunningRecords = try destinationContainer.mainContext.fetch(FetchDescriptor<RunningRecord>())
        XCTAssertEqual(restoredRunningRecords.count, 360)

        let restoredLinks = try destinationContainer.mainContext.fetch(FetchDescriptor<UsefulLink>())
        XCTAssertEqual(restoredLinks.count, 30)

        let restoredFolders = try destinationContainer.mainContext.fetch(FetchDescriptor<LibraryFolder>())
        XCTAssertEqual(restoredFolders.count, fixture.libraryFolders.count + 1)

        let restoredFiles = try destinationContainer.mainContext.fetch(FetchDescriptor<LibraryFile>())
        XCTAssertEqual(restoredFiles.count, fixture.libraryFiles.count)
    }

    func testStressVersionedBackupFixtureRejectsClassOverflow() throws {
        let oversizedClasses = (0..<1001).map { index in
            BackupClass(
                name: "Class \(index)",
                grade: "4",
                students: [],
                subjects: []
            )
        }

        let fixture = VersionedBackupFile(
            classes: oversizedClasses,
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

        let decodedPayload = try decodeVersionedFixturePayload(fixture)

        XCTAssertThrowsError(try BackupPayloadValidationService.validateTopLevelContents(decodedPayload.classes)) { error in
            guard case BackupError.invalidData(let reason) = error else {
                return XCTFail("Unexpected error type: \(error)")
            }
            XCTAssertEqual(reason, "Too many classes in backup")
        }
    }

    func testStressVersionedBackupFixtureRejectsStudentOverflow() throws {
        let oversizedStudents = (0..<10001).map { index in
            BackupStudent(
                name: "Student \(index)",
                sortOrder: index,
                isParticipatingWell: false,
                needsHelp: false,
                missingHomework: false
            )
        }

        let fixture = VersionedBackupFile(
            classes: [
                BackupClass(
                    name: "Overflow Room",
                    grade: "5",
                    students: oversizedStudents,
                    subjects: []
                )
            ],
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

        let decodedPayload = try decodeVersionedFixturePayload(fixture)

        XCTAssertThrowsError(try BackupPayloadValidationService.validateTopLevelContents(decodedPayload.classes)) { error in
            guard case BackupError.invalidData(let reason) = error else {
                return XCTFail("Unexpected error type: \(error)")
            }
            XCTAssertEqual(reason, "Too many students in a class")
        }
    }

    @MainActor
    func testAttendanceSessionNormalizationRepairsCollapsedStudentReferences() throws {
        let container = try makePersistentContainer(named: "attendance-collapsed-repair")
        let context = container.mainContext

        let schoolClass = SchoolClass(name: "Year 6", grade: "6")
        let students = [
            Student(name: "Carlos Eduardo"),
            Student(name: "Ana Souza"),
            Student(name: "Bruno Lima"),
            Student(name: "Davi Rocha")
        ]

        for (index, student) in students.enumerated() {
            student.sortOrder = index
            schoolClass.students.append(student)
        }

        let session = AttendanceSession(date: Date())
        session.records = [
            AttendanceRecord(student: students[0], status: .present),
            AttendanceRecord(student: students[0], status: .absent, notes: "Family trip"),
            AttendanceRecord(student: students[0], status: .late, notes: "Bus delay"),
            AttendanceRecord(student: students[0], status: .leftEarly, notes: "Doctor appointment")
        ]
        schoolClass.attendanceSessions.append(session)

        context.insert(schoolClass)
        try context.save()

        let repairedCount = session.normalizeRecordsIfNeeded(
            for: schoolClass.students,
            context: context
        )

        XCTAssertGreaterThanOrEqual(repairedCount, 3)
        XCTAssertEqual(session.records.count, 4)
        XCTAssertEqual(Set(session.records.compactMap { $0.student?.id }).count, 4)

        for student in students {
            XCTAssertEqual(session.records.filter { $0.student?.id == student.id }.count, 1)
        }

        let statusCounts = Dictionary(grouping: session.records.map(\.status), by: { $0 })
            .mapValues(\.count)
        XCTAssertEqual(statusCounts[.present], 1)
        XCTAssertEqual(statusCounts[.absent], 1)
        XCTAssertEqual(statusCounts[.late], 1)
        XCTAssertEqual(statusCounts[.leftEarly], 1)
    }

    @MainActor
    func testAssessmentCanonicalResultCollapsesDuplicateRowsPerStudent() throws {
        let container = try makePersistentContainer(named: "assessment-result-canonical")
        let context = container.mainContext

        let schoolClass = SchoolClass(name: "Year 6", grade: "6")
        let subject = Subject(name: "Math")
        let unit = Unit(name: "Fractions")
        let assessment = Assessment(title: "Quiz 1")
        let student = Student(name: "Carlos Eduardo")

        schoolClass.students.append(student)
        schoolClass.subjects.append(subject)
        subject.schoolClass = schoolClass
        subject.units.append(unit)
        unit.subject = subject
        unit.assessments.append(assessment)
        assessment.unit = unit

        let firstResult = StudentResult(
            student: student,
            score: 6,
            notes: "First observation",
            hasScore: true
        )
        firstResult.assessment = assessment
        assessment.results.append(firstResult)

        let duplicateResult = StudentResult(
            student: student,
            score: 8,
            notes: "Second observation",
            hasScore: true
        )
        duplicateResult.assessment = assessment
        assessment.results.append(duplicateResult)

        context.insert(schoolClass)
        if context.hasChanges {
            try context.save()
        }

        let collapsedCount = assessment.collapseDuplicateResults(context: context)
        XCTAssertGreaterThanOrEqual(collapsedCount, 1)

        let canonical = assessment.ensureCanonicalResult(for: student, context: context)
        let studentRows = assessment.results.filter { $0.student?.id == student.id }

        XCTAssertEqual(studentRows.count, 1)
        XCTAssertEqual(studentRows.first?.id, canonical.id)
        XCTAssertEqual(canonical.score, 8)
        XCTAssertTrue(canonical.hasScore)
        XCTAssertTrue(canonical.notes.contains("First observation"))
        XCTAssertTrue(canonical.notes.contains("Second observation"))
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

    private func writeVersionedFixtureToTemporaryFile(
        _ fixture: VersionedBackupFile,
        filePrefix: String
    ) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(filePrefix)-\(UUID().uuidString).backup")
        let data = try encodeVersionedFixtureData(fixture)
        try data.write(to: url, options: .atomic)
        return url
    }

    private func decodeVersionedFixturePayload(
        _ fixture: VersionedBackupFile
    ) throws -> DecodedBackupPayload {
        let data = try encodeVersionedFixtureData(fixture)
        return try BackupDecodeService.decodePayload(
            from: data,
            currentSchemaVersion: fixture.schemaVersion
        )
    }

    private func encodeVersionedFixtureData(_ fixture: VersionedBackupFile) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(fixture)
    }

    private func makeVersionedStressBackupFixture(
        classCount: Int,
        studentsPerClass: Int,
        subjectsPerClass: Int,
        unitsPerSubject: Int,
        assessmentsPerUnit: Int,
        resultsPerAssessment: Int,
        usefulLinkCount: Int,
        libraryFolderCount: Int,
        libraryFileCount: Int
    ) -> VersionedBackupFile {
        let now = Date()
        var classes: [BackupClass] = []
        var runningRecords: [BackupRunningRecord] = []
        var calendarEvents: [BackupCalendarEvent] = []
        var classDiaryEntries: [BackupClassDiaryEntry] = []
        var allStudentUUIDs: [UUID] = []

        for classIndex in 0..<classCount {
            let students: [BackupStudent] = (0..<studentsPerClass).map { studentIndex in
                let studentUUID = UUID()
                allStudentUUIDs.append(studentUUID)
                runningRecords.append(
                    BackupRunningRecord(
                        studentUUID: studentUUID,
                        date: now,
                        textTitle: "Text \(classIndex)-\(studentIndex)",
                        bookLevel: "L\(studentIndex % 8)",
                        totalWords: 120 + studentIndex,
                        errors: studentIndex % 6,
                        selfCorrections: studentIndex % 4,
                        notes: "Observation \(classIndex)-\(studentIndex)"
                    )
                )

                return BackupStudent(
                    uuid: studentUUID,
                    name: "Stress Student \(classIndex)-\(studentIndex)",
                    sortOrder: studentIndex,
                    isParticipatingWell: studentIndex.isMultiple(of: 2),
                    needsHelp: studentIndex.isMultiple(of: 5),
                    missingHomework: studentIndex.isMultiple(of: 7),
                    assessmentScores: [
                        BackupAssessmentScore(value: studentIndex % 5),
                        BackupAssessmentScore(value: (studentIndex + 2) % 5),
                        BackupAssessmentScore(value: (studentIndex + 4) % 5),
                    ]
                )
            }

            let subjects: [BackupSubject] = (0..<subjectsPerClass).map { subjectIndex in
                let units: [BackupUnit] = (0..<unitsPerSubject).map { unitIndex in
                    let assessments: [BackupAssessment] = (0..<assessmentsPerUnit).map { assessmentIndex in
                        let resultStudents = students.prefix(min(resultsPerAssessment, students.count))
                        let results: [BackupResult] = resultStudents.enumerated().map { offset, student in
                            BackupResult(
                                studentUUID: student.uuid,
                                studentName: student.name,
                                score: Double((offset % 6) + 4),
                                hasScore: true,
                                notes: "Result \(classIndex)-\(subjectIndex)-\(unitIndex)-\(assessmentIndex)-\(offset)"
                            )
                        }

                        return BackupAssessment(
                            title: "Assessment \(subjectIndex)-\(unitIndex)-\(assessmentIndex)",
                            details: "Stress fixture assessment",
                            date: now,
                            maxScore: 10,
                            sortOrder: assessmentIndex,
                            results: results
                        )
                    }

                    return BackupUnit(
                        name: "Unit \(subjectIndex)-\(unitIndex)",
                        sortOrder: unitIndex,
                        assessments: assessments
                    )
                }

                return BackupSubject(
                    name: "Subject \(subjectIndex)",
                    sortOrder: subjectIndex,
                    units: units
                )
            }

            let attendanceRecords = students.prefix(min(20, students.count)).map { student in
                BackupAttendanceRecord(
                    studentUUID: student.uuid,
                    studentName: student.name,
                    statusRaw: AttendanceStatus.present.rawValue,
                    notes: ""
                )
            }

            let backupClass = BackupClass(
                name: "Stress Class \(classIndex + 1)",
                grade: "\((classIndex % 9) + 1)",
                schoolYear: "2025-2026",
                sortOrder: classIndex,
                students: students,
                categories: [
                    BackupAssessmentCategory(title: "Reading"),
                    BackupAssessmentCategory(title: "Writing"),
                    BackupAssessmentCategory(title: "Math"),
                ],
                attendanceSessions: [
                    BackupAttendanceSession(
                        date: now,
                        records: attendanceRecords
                    )
                ],
                subjects: subjects
            )
            classes.append(backupClass)

            let firstSubjectID = subjects.first?.id
            let firstUnitID = subjects.first?.units.first?.id
            calendarEvents.append(
                BackupCalendarEvent(
                    title: "Event \(classIndex)",
                    date: now.addingTimeInterval(TimeInterval(classIndex * 3_600)),
                    startTime: now.addingTimeInterval(TimeInterval(classIndex * 3_600)),
                    endTime: now.addingTimeInterval(TimeInterval(classIndex * 3_600 + 2_700)),
                    details: "Stress fixture event",
                    isAllDay: false,
                    className: backupClass.name,
                    classGrade: backupClass.grade
                )
            )
            classDiaryEntries.append(
                BackupClassDiaryEntry(
                    date: now,
                    startTime: now,
                    endTime: now.addingTimeInterval(1_800),
                    plan: "Plan \(classIndex)",
                    objectives: "Objective \(classIndex)",
                    materials: "Materials \(classIndex)",
                    notes: "Notes \(classIndex)",
                    className: backupClass.name,
                    classGrade: backupClass.grade,
                    subjectID: firstSubjectID,
                    unitID: firstUnitID
                )
            )
        }

        var folders: [BackupLibraryFolder] = []
        folders.reserveCapacity(libraryFolderCount)
        for index in 0..<libraryFolderCount {
            let id = UUID()
            let parentID = index == 0 ? nil : folders[(index - 1) / 2].id
            folders.append(
                BackupLibraryFolder(
                    id: id,
                    name: "Folder \(index)",
                    parentID: parentID,
                    colorHex: index.isMultiple(of: 2) ? "#3B82F6" : "#10B981"
                )
            )
        }

        let fallbackParentID = folders.first?.id ?? UUID()
        let files: [BackupLibraryFile] = (0..<libraryFileCount).map { index in
            let parentFolderID = folders.isEmpty ? fallbackParentID : folders[index % folders.count].id
            return BackupLibraryFile(
                id: UUID(),
                name: "File \(index).pdf",
                pdfData: Data(repeating: UInt8((index % 251) + 1), count: 128),
                parentFolderID: parentFolderID,
                drawingData: index.isMultiple(of: 3)
                    ? Data(repeating: UInt8((index % 199) + 1), count: 16)
                    : nil,
                linkedSubjectID: nil,
                linkedUnitID: nil
            )
        }

        let criteria: [BackupRubricCriterion] = (0..<4).map { index in
            BackupRubricCriterion(
                id: UUID(),
                name: "Criterion \(index)",
                details: "Stress criterion \(index)",
                sortOrder: index
            )
        }
        let rubricTemplate = BackupRubricTemplate(
            id: UUID(),
            name: "Stress Rubric",
            gradeLevel: "5",
            subject: "Language Arts",
            sortOrder: 0,
            categories: [
                BackupRubricCategory(
                    id: UUID(),
                    name: "Communication",
                    sortOrder: 0,
                    criteria: criteria
                )
            ]
        )

        let developmentScores: [BackupDevelopmentScore] = allStudentUUIDs
            .prefix(120)
            .enumerated()
            .map { index, studentUUID in
                BackupDevelopmentScore(
                    id: UUID(),
                    studentUUID: studentUUID,
                    criterionID: criteria[index % criteria.count].id,
                    rating: (index % 5) + 1,
                    date: now,
                    notes: "Progress \(index)"
                )
            }

        let usefulLinks: [BackupUsefulLink] = (0..<usefulLinkCount).map { index in
            BackupUsefulLink(
                id: UUID(),
                title: "Resource \(index)",
                url: "https://example.com/resource/\(index)",
                description: "Stress fixture link \(index)",
                sortOrder: index,
                createdAt: now,
                updatedAt: now
            )
        }

        return VersionedBackupFile(
            classes: classes,
            runningRecords: runningRecords,
            rubricTemplates: [rubricTemplate],
            developmentScores: developmentScores,
            calendarEvents: calendarEvents,
            classDiaryEntries: classDiaryEntries,
            libraryFolders: folders,
            libraryFiles: files,
            usefulLinks: usefulLinks,
            appSettings: nil
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
    private func preRestoreSnapshotDirectoryURL(createIfMissing: Bool) throws -> URL {
        try BackupManager.applicationSupportSubdirectory(
            named: "PreRestoreSnapshots",
            createIfMissing: createIfMissing
        )
    }

    private func preRestoreSnapshotFiles(in directory: URL) -> [URL] {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return urls.filter { $0.pathExtension == "backup" }
    }

    private func snapshotTimestamp(for url: URL) -> Date {
        let values = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
        return values?.contentModificationDate ?? values?.creationDate ?? .distantPast
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
