import Foundation

enum GradebookExportUtility {
    nonisolated private static let watchlistAverageThresholdPercent = 50.0

    private static let fileDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()

    static func exportUnitGradebookCSV(
        unit: Unit,
        students: [Student],
        assessments: [Assessment]
    ) -> URL? {
        guard !students.isEmpty, !assessments.isEmpty else { return nil }

        let header = ["student_name"] + assessments.map { assessmentColumnTitle(for: $0) } + ["average_percent"]
        let rows = students.map { student in
            let results = assessments.compactMap { $0.canonicalResult(for: student) }
            let average = results.filter(\.isScored).averagePercent

            let columns = [student.name] + assessments.map { assessment in
                gradebookValue(for: assessment.canonicalResult(for: student), assessment: assessment)
            } + [averageText(for: results.filter(\.isScored).isEmpty ? nil : average)]

            return columns.map(csvEscaped).joined(separator: ",")
        }

        let csv = ([header.map(csvEscaped).joined(separator: ",")] + rows).joined(separator: "\n")
        let baseName = [
            "Gradebook",
            unit.subject?.schoolClass?.name,
            unit.subject?.name,
            unit.name,
            fileDateFormatter.string(from: Date()),
        ]
        .compactMap { value in
            guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return value
        }
        .joined(separator: "-")

        return writeExportFile(content: csv.data(using: .utf8), baseName: baseName, fileExtension: "csv")
    }

    static func exportClassSummaryCSV(
        schoolClass: SchoolClass,
        students: [Student],
        selectedSubject: Subject?,
        filteredResults: [StudentResult],
        allAttendanceSessions: [AttendanceSession]
    ) -> URL? {
        guard !students.isEmpty else { return nil }

        let header = [
            "student_name",
            "subject_scope",
            "average_percent",
            "scored_results",
            "pending_results",
            "absent_results",
            "excused_results",
            "attendance_percent",
            "missing_assignments",
            "active_interventions",
            "needs_help",
            "watch_flags",
        ]

        let rows = students.map { student in
            let studentResults = filteredResults.filter { $0.student?.id == student.id }
            let scoredResults = studentResults.filter(\.isScored)
            let average = scoredResults.averagePercent
            let resolvedCount = studentResults.filter(\.isResolved).count
            let pendingCount = max(studentResults.count - resolvedCount, 0)
            let absentCount = studentResults.filter { $0.status == .absent }.count
            let excusedCount = studentResults.filter { $0.status == .excused }.count
            let attendancePercent = attendancePercent(for: student, sessions: allAttendanceSessions)
            let missingAssignments = student.assignmentEntries.filter { entry in
                guard let assignment = entry.assignment else { return false }
                return entry.trackingState(relativeTo: assignment.dueDate) == .missing
            }.count
            let activeInterventions = student.interventions.filter { $0.status != .resolved }.count
            let flags = watchFlags(
                average: scoredResults.isEmpty ? nil : average,
                attendancePercent: attendancePercent,
                missingAssignments: missingAssignments,
                activeInterventions: activeInterventions,
                needsHelp: student.needsHelp,
                missingHomework: student.missingHomework
            )

            let columns = [
                student.name,
                selectedSubject?.name ?? "All Subjects",
                averageText(for: scoredResults.isEmpty ? nil : average),
                "\(scoredResults.count)",
                "\(pendingCount)",
                "\(absentCount)",
                "\(excusedCount)",
                averageText(for: attendancePercent),
                "\(missingAssignments)",
                "\(activeInterventions)",
                student.needsHelp ? "Yes" : "No",
                flags.joined(separator: " | "),
            ]

            return columns.map(csvEscaped).joined(separator: ",")
        }

        let csv = ([header.map(csvEscaped).joined(separator: ",")] + rows).joined(separator: "\n")
        let baseName = [
            "ClassSummary",
            schoolClass.name,
            selectedSubject?.name,
            fileDateFormatter.string(from: Date()),
        ]
        .compactMap { value in
            guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return value
        }
        .joined(separator: "-")

        return writeExportFile(content: csv.data(using: .utf8), baseName: baseName, fileExtension: "csv")
    }

    nonisolated private static func assessmentColumnTitle(for assessment: Assessment) -> String {
        "\(assessment.title) (\(formattedScore(assessment.safeMaxScore)) max)"
    }

    nonisolated private static func gradebookValue(for result: StudentResult?, assessment: Assessment) -> String {
        guard let result else { return "" }
        switch result.status {
        case .ungraded:
            return ""
        case .scored:
            return "\(formattedScore(result.score))/\(formattedScore(assessment.safeMaxScore))"
        case .absent:
            return "Absent"
        case .excused:
            return "Excused"
        }
    }

    nonisolated private static func attendancePercent(for student: Student, sessions: [AttendanceSession]) -> Double? {
        let records = sessions
            .flatMap(\.records)
            .filter { $0.student?.id == student.id }

        guard !records.isEmpty else { return nil }

        let presentCount = records.filter { $0.status == .present }.count
        return (Double(presentCount) / Double(records.count)) * 100
    }

    nonisolated private static func watchFlags(
        average: Double?,
        attendancePercent: Double?,
        missingAssignments: Int,
        activeInterventions: Int,
        needsHelp: Bool,
        missingHomework: Bool
    ) -> [String] {
        var flags: [String] = []

        if let average, average < watchlistAverageThresholdPercent {
            flags.append("Low Average")
        }
        if let attendancePercent, attendancePercent < 90 {
            flags.append("Low Attendance")
        }
        if missingAssignments > 0 {
            flags.append("\(missingAssignments) missing work")
        }
        if activeInterventions > 0 {
            flags.append("\(activeInterventions) active plans")
        }
        if needsHelp {
            flags.append("Needs Help")
        }
        if missingHomework {
            flags.append("Missing HW")
        }

        return flags
    }

    nonisolated private static func averageText(for value: Double?) -> String {
        guard let value else { return "" }
        return String(format: "%.1f", value)
    }

    nonisolated private static func formattedScore(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
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
            SecureLogger.error("Failed to write gradebook export file", error: error)
            return nil
        }
    }

    nonisolated private static func csvEscaped(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
