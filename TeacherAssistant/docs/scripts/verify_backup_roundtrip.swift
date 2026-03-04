import Foundation

#if BACKUP_VERIFY

@main
struct BackupRoundTripVerifier {
    static func main() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]

        do {
            let sample = makeSampleVersionedBackup()
            let encoded = try encoder.encode(sample)
            let decoded = try decoder.decode(VersionedBackupFileHarness.self, from: encoded)

            try require(decoded.schemaVersion == sample.schemaVersion, "Schema version changed during round-trip")
            try require(decoded.classes.count == 1, "Expected one class in decoded payload")
            try require(decoded.classes.first?.students.count == 1, "Expected one student in decoded payload")
            try require(decoded.classes.first?.students.first?.assessmentScores.count == 2, "Assessment scores did not round-trip")
            try require(decoded.runningRecords.count == 1, "Running records did not round-trip")
            try require(decoded.rubricTemplates.count == 1, "Rubric templates did not round-trip")
            try require(decoded.developmentScores.count == 1, "Development scores did not round-trip")
            try require(decoded.calendarEvents.count == 1, "Calendar events did not round-trip")
            try require(decoded.classDiaryEntries.count == 1, "Diary entries did not round-trip")
            try require(decoded.libraryFolders.count == 1, "Library folders did not round-trip")
            try require(decoded.libraryFiles.first?.pdfData == sample.libraryFiles.first?.pdfData, "PDF data changed during round-trip")
            try require(decoded.usefulLinks.first?.url == sample.usefulLinks.first?.url, "Useful link URL changed during round-trip")
            try require(decoded.appSettings?.timerCustomMinutes == 7, "Timer settings did not round-trip")

            let partialVersionedData = try makeLegacyCompatibleVersionedPayloadData(
                from: encoded,
                using: encoder
            )
            let partialDecoded = try decoder.decode(VersionedBackupFileHarness.self, from: partialVersionedData)

            try require(partialDecoded.libraryFolders.isEmpty, "Missing library folders should default to empty")
            try require(partialDecoded.libraryFiles.isEmpty, "Missing library files should default to empty")
            try require(partialDecoded.usefulLinks.isEmpty, "Missing useful links should default to empty")
            try require(
                partialDecoded.appSettings?.dateFormat == AppDateFormatPreference.system.rawValue,
                "Missing date format should fall back to system"
            )
            try require(
                partialDecoded.appSettings?.defaultLandingSection == AppSection.dashboard.rawValue,
                "Missing landing section should fall back to dashboard"
            )

            let legacyOnlyData = try encoder.encode(BackupFile(classes: sample.classes))
            let legacyDecoded = try decoder.decode(BackupFile.self, from: legacyOnlyData)
            try require(legacyDecoded.classes.count == sample.classes.count, "Legacy backup decode failed")

            print("RESULT: PASS")
            print("  - Versioned round-trip preserved full payload")
            print("  - Older versioned payload defaults decoded correctly")
            print("  - Legacy backup payload still decodes")
        } catch {
            print("RESULT: FAIL")
            print("  - \(error.localizedDescription)")
            exit(1)
        }
    }

    private static func makeLegacyCompatibleVersionedPayloadData(
        from encodedData: Data,
        using encoder: JSONEncoder
    ) throws -> Data {
        guard var jsonObject = try JSONSerialization.jsonObject(with: encodedData) as? [String: Any] else {
            throw NSError(
                domain: "BackupVerifier",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Could not parse encoded JSON payload"]
            )
        }

        jsonObject.removeValue(forKey: "libraryFolders")
        jsonObject.removeValue(forKey: "libraryFiles")
        jsonObject.removeValue(forKey: "usefulLinks")

        if var appSettings = jsonObject["appSettings"] as? [String: Any] {
            appSettings.removeValue(forKey: "dateFormat")
            appSettings.removeValue(forKey: "timeFormat")
            appSettings.removeValue(forKey: "defaultLandingSection")
            appSettings.removeValue(forKey: "timerCustomMinutes")
            appSettings.removeValue(forKey: "timerCustomSeconds")
            appSettings.removeValue(forKey: "timerCustomChecklistText")
            jsonObject["appSettings"] = appSettings
        }

        let normalized = try JSONSerialization.data(withJSONObject: jsonObject, options: [.sortedKeys])
        return normalized
    }
}

#endif
