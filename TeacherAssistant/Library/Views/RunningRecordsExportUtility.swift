import Foundation

private struct RunningRecordExportRow: Codable {
    let studentName: String
    let className: String
    let recordDate: String
    let textTitle: String
    let level: String
    let accuracyPercent: Double
    let totalWords: Int
    let errors: Int
    let selfCorrections: Int
    let selfCorrectionRatio: String
    let notes: String
}

private struct RunningRecordJSONExportEnvelope: Codable {
    let exportedAt: String
    let appliedFilters: String?
    let totalRecords: Int
    let records: [RunningRecordExportRow]
}

enum RunningRecordsExportUtility {
    private static let fileDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()

    private static let rowDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let isoDateFormatter = ISO8601DateFormatter()

    static func exportCSV(records: [RunningRecord], appliedFilters: String?) -> URL? {
        let rows = normalizedRows(from: records)
        guard !rows.isEmpty else { return nil }

        let header = [
            "student_name",
            "class_name",
            "date",
            "text_title",
            "level",
            "accuracy_pct",
            "total_words",
            "errors",
            "self_corrections",
            "sc_ratio",
            "notes"
        ]

        let csvRows = rows.map { row in
            [
                row.studentName,
                row.className,
                row.recordDate,
                row.textTitle,
                row.level,
                String(format: "%.1f", row.accuracyPercent),
                "\(row.totalWords)",
                "\(row.errors)",
                "\(row.selfCorrections)",
                row.selfCorrectionRatio,
                row.notes
            ]
            .map { value in csvEscaped(value) }
            .joined(separator: ",")
        }

        var csvLines = [header.map { value in csvEscaped(value) }.joined(separator: ",")]
        if let appliedFilters, !appliedFilters.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            csvLines.append("# Filters: \(appliedFilters)")
        }
        csvLines.append(contentsOf: csvRows)

        let content = csvLines.joined(separator: "\n")
        return writeExportFile(
            content: content.data(using: .utf8),
            baseName: "RunningRecords-\(fileDateFormatter.string(from: Date()))",
            fileExtension: "csv"
        )
    }

    static func exportJSON(records: [RunningRecord], appliedFilters: String?) -> URL? {
        let rows = normalizedRows(from: records)
        guard !rows.isEmpty else { return nil }

        let envelope = RunningRecordJSONExportEnvelope(
            exportedAt: isoDateFormatter.string(from: Date()),
            appliedFilters: appliedFilters,
            totalRecords: rows.count,
            records: rows
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(envelope) else { return nil }

        return writeExportFile(
            content: data,
            baseName: "RunningRecords-\(fileDateFormatter.string(from: Date()))",
            fileExtension: "json"
        )
    }

    private static func normalizedRows(from records: [RunningRecord]) -> [RunningRecordExportRow] {
        records
            .sorted { $0.date > $1.date }
            .map { record in
                RunningRecordExportRow(
                    studentName: SecurityHelpers.sanitizeNotes(record.studentDisplayName),
                    className: SecurityHelpers.sanitizeNotes(record.classDisplayName),
                    recordDate: rowDateFormatter.string(from: record.date),
                    textTitle: SecurityHelpers.sanitizeNotes(record.textTitle),
                    level: record.readingLevel.rawValue,
                    accuracyPercent: record.accuracy,
                    totalWords: record.totalWords,
                    errors: record.errors,
                    selfCorrections: record.selfCorrections,
                    selfCorrectionRatio: record.selfCorrectionRatio,
                    notes: SecurityHelpers.sanitizeNotes(record.notes)
                )
            }
    }

    private static func writeExportFile(content: Data?, baseName: String, fileExtension: String) -> URL? {
        guard let content else { return nil }
        let safeBaseName = SecurityHelpers.sanitizeFilename(baseName)
        let safeFilename = SecurityHelpers.generateSecureFilename(baseName: safeBaseName, extension: fileExtension)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(safeFilename)
        do {
            try content.write(to: url, options: .atomic)
            return url
        } catch {
            SecureLogger.error("Failed to write running records export file", error: error)
            return nil
        }
    }

    private static func csvEscaped(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
