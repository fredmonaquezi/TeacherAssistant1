import Foundation

#if BACKUP_VERIFY

struct VersionedBackupFileHarness: Codable {
    var schemaVersion: Int
    var createdAt: Date
    var appVersion: String
    var classes: [BackupClass]
    var runningRecords: [BackupRunningRecord]
    var rubricTemplates: [BackupRubricTemplate]
    var developmentScores: [BackupDevelopmentScore]
    var calendarEvents: [BackupCalendarEvent]
    var classDiaryEntries: [BackupClassDiaryEntry]
    var appSettings: BackupAppSettings?
}

private func summarize(_ backup: BackupFile) -> String {
    let classCount = backup.classes.count
    let studentCount = backup.classes.reduce(0) { $0 + $1.students.count }
    let subjectCount = backup.classes.reduce(0) { $0 + $1.subjects.count }
    let assessmentCount = backup.classes.reduce(0) { total, schoolClass in
        total + schoolClass.subjects.reduce(0) { subjectTotal, subject in
            subjectTotal + subject.units.reduce(0) { unitTotal, unit in
                unitTotal + unit.assessments.count
            }
        }
    }
    return "classes=\(classCount), students=\(studentCount), subjects=\(subjectCount), assessments=\(assessmentCount)"
}

@main
struct BackupCompatibilityVerifier {
    static func main() {
        let fileManager = FileManager.default
        let backupDirectory = "/Users/fred/Documents/BACKUP"
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]

        var failures: [String] = []

        guard let directoryItems = try? fileManager.contentsOfDirectory(atPath: backupDirectory) else {
            print("RESULT: FAIL")
            print("  - Could not read backup directory: \(backupDirectory)")
            exit(1)
        }

        let backupPaths = directoryItems
            .filter { !$0.hasPrefix(".") }
            .map { "\(backupDirectory)/\($0)" }
            .sorted()

        print("Pre-parity decode check:")
        for path in backupPaths {
            do {
                let data = try Data(contentsOf: URL(fileURLWithPath: path))
                if let versioned = try? decoder.decode(VersionedBackupFileHarness.self, from: data) {
                    let summary = summarize(BackupFile(classes: versioned.classes))
                    print("  [OK] \(path) (versioned v\(versioned.schemaVersion), \(summary))")
                } else {
                    let legacy = try decoder.decode(BackupFile.self, from: data)
                    print("  [OK] \(path) (legacy, \(summarize(legacy)))")
                }
            } catch {
                failures.append("\(path): \(error)")
                print("  [FAIL] \(path): \(error)")
            }
        }

        do {
            guard let seedPath = backupPaths.first(where: { $0.hasSuffix(".backup") }) else {
                throw NSError(domain: "Verifier", code: 1, userInfo: [NSLocalizedDescriptionKey: "No seed backup file found"])
            }

            let seedData = try Data(contentsOf: URL(fileURLWithPath: seedPath))
            let seedLegacy = try decoder.decode(BackupFile.self, from: seedData)

            let versioned = VersionedBackupFileHarness(
                schemaVersion: 3,
                createdAt: Date(),
                appVersion: "1.1.0",
                classes: seedLegacy.classes,
                runningRecords: [],
                rubricTemplates: [],
                developmentScores: [],
                calendarEvents: [],
                classDiaryEntries: [],
                appSettings: BackupAppSettings(
                    appLanguage: "en",
                    helperRotation: "",
                    guardianRotation: "",
                    lineLeaderRotation: "",
                    messengerRotation: "",
                    customCategoriesData: "",
                    customRotationData: ""
                )
            )

            let encoded = try encoder.encode(versioned)
            let fixturePath = "/tmp/TeacherAssistant-v1_1-schema3-fixture.backup"
            try encoded.write(to: URL(fileURLWithPath: fixturePath), options: .atomic)

            let decoded = try decoder.decode(
                VersionedBackupFileHarness.self,
                from: Data(contentsOf: URL(fileURLWithPath: fixturePath))
            )

            let summary = summarize(BackupFile(classes: decoded.classes))
            print("Post-parity decode check:")
            print("  [OK] \(fixturePath) (versioned v\(decoded.schemaVersion), \(summary))")
        } catch {
            failures.append("post-parity fixture: \(error)")
            print("Post-parity decode check:")
            print("  [FAIL] post-parity fixture: \(error)")
        }

        if failures.isEmpty {
            print("RESULT: PASS")
        } else {
            print("RESULT: FAIL (\(failures.count) issues)")
            for failure in failures {
                print("  - \(failure)")
            }
            exit(1)
        }
    }
}

#endif
