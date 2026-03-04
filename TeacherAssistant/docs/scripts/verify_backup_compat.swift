import Foundation

#if BACKUP_VERIFY

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

        let backupPaths = (try? fileManager.contentsOfDirectory(atPath: backupDirectory))?
            .filter { !$0.hasPrefix(".") }
            .map { "\(backupDirectory)/\($0)" }
            .sorted() ?? []

        print("Pre-parity decode check:")
        if backupPaths.isEmpty {
            print("  [SKIP] No seed backups found in \(backupDirectory)")
        } else {
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
        }

        do {
            let versioned: VersionedBackupFileHarness

            if let seedPath = backupPaths.first(where: { $0.hasSuffix(".backup") }) {
                let seedData = try Data(contentsOf: URL(fileURLWithPath: seedPath))
                let seedLegacy = try decoder.decode(BackupFile.self, from: seedData)
                var seededVersioned = makeSampleVersionedBackup(schemaVersion: 6)
                seededVersioned.classes = seedLegacy.classes
                versioned = seededVersioned
            } else {
                versioned = makeSampleVersionedBackup(schemaVersion: 6)
            }

            let encoded = try encoder.encode(versioned)
            let fixturePath = "/tmp/TeacherAssistant-schema6-fixture.backup"
            try encoded.write(to: URL(fileURLWithPath: fixturePath), options: .atomic)

            let decoded = try decoder.decode(
                VersionedBackupFileHarness.self,
                from: Data(contentsOf: URL(fileURLWithPath: fixturePath))
            )

            try require(decoded.libraryFolders.count == versioned.libraryFolders.count, "Library folders did not round-trip")
            try require(decoded.libraryFiles.count == versioned.libraryFiles.count, "Library files did not round-trip")
            try require(decoded.usefulLinks.count == versioned.usefulLinks.count, "Useful links did not round-trip")
            try require(decoded.appSettings?.defaultLandingSection == versioned.appSettings?.defaultLandingSection, "App settings did not round-trip")

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
