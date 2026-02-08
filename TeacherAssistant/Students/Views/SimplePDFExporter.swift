import Foundation
import SwiftData

#if os(macOS)
import AppKit

/// MINIMAL WORKING PDF EXPORTER FOR macOS
/// This uses NSPrintOperation which is the simplest, most reliable way
struct SimplePDFExporter {
    
    static func exportStudentReport(
        student: Student,
        schoolName: String,
        allResults: [StudentResult],
        allAttendanceSessions: [AttendanceSession],
        allDevelopmentScores: [DevelopmentScore] = []
    ) -> URL {
        
        // Generate plain text content
        let content = generateTextContent(
            student: student,
            schoolName: schoolName,
            allResults: allResults,
            allAttendanceSessions: allAttendanceSessions,
            allDevelopmentScores: allDevelopmentScores
        )
        
        // Create attributed string with formatting
        let attributedString = createFormattedReport(content: content, studentName: student.name)
        
        // Save to PDF using NSTextView and NSPrintOperation
        let safeFilename = SecurityHelpers.generateSecureFilename(baseName: "StudentReport", extension: "pdf")
        let pdfURL = saveToPDF(attributedString: attributedString, fileName: safeFilename)
        
        return pdfURL
    }
    
    private static func generateTextContent(
        student: Student,
        schoolName: String,
        allResults: [StudentResult],
        allAttendanceSessions: [AttendanceSession],
        allDevelopmentScores: [DevelopmentScore]
    ) -> String {
        
        var text = ""
        
        // DECORATIVE HEADER
        text += "◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆\n\n"
        
        // School Name - Prominent
        if !schoolName.isEmpty {
            text += "\(schoolName.uppercased())\n"
        }
        
        text += "STUDENT PROGRESS REPORT\n"
        
        let currentYear = Calendar.current.component(.year, from: Date())
        text += "Academic Year \(currentYear)\n\n"
        
        text += "◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆\n\n"
        
        // Student Information Box
        text += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        text += "STUDENT INFORMATION\n"
        text += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        text += "Student Name: \(student.name)\n"
        
        // Add class if available
        if let schoolClass = student.schoolClass {
            text += "Class: \(schoolClass.name)\n"
        }
        
        text += "Report Date: \(DateFormatter.localizedString(from: Date(), dateStyle: .long, timeStyle: .none))\n"
        text += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        text += "\n"
        
        // Student Notes (if any)
        if !student.notes.isEmpty {
            text += "Teacher Notes:\n"
            text += "\(student.notes)\n\n"
        }
        
        // Status Indicators
        text += "\n◆ ◆ ◆\n\n"
        text += "STATUS INDICATORS\n"
        text += "───────────────────────────────────────────────────────────\n"
        text += "Participating Well: \(student.isParticipatingWell ? "✓ Yes" : "○ No")\n"
        text += "Needs Additional Help: \(student.needsHelp ? "⚠ Yes" : "○ No")\n"
        text += "Missing Homework: \(student.missingHomework ? "⚠ Yes" : "○ No")\n"
        text += "\n"
        
        // Attendance
        text += "\n◆ ◆ ◆\n\n"
        let records: [AttendanceRecord] = allAttendanceSessions.flatMap { session in
            session.records.filter { $0.student.id == student.id }
        }
        
        let total = records.count
        let present = records.filter { $0.status == .present }.count
        let absent = records.filter { $0.status == .absent }.count
        let late = records.filter { $0.status == .late }.count
        let leftEarly = records.filter { $0.status == .leftEarly }.count
        let percentage = total > 0 ? Int((Double(present) / Double(total)) * 100) : 0
        
        text += "ATTENDANCE SUMMARY\n"
        text += "───────────────────────────────────────────────────────────\n"
        text += "Total Sessions: \(total)\n"
        text += "Present: \(present) (\(percentage)%)\n"
        text += "Absent: \(absent)\n"
        text += "Late: \(late)\n"
        if leftEarly > 0 {
            text += "Left Early: \(leftEarly)\n"
        }
        text += "\n"
        
        // Academic Results
        text += "\n◆ ◆ ◆\n\n"
        let results = allResults.filter { $0.student?.id == student.id }
        let average = results.averageScore
        
        text += "ACADEMIC PERFORMANCE\n"
        text += "───────────────────────────────────────────────────────────\n"
        text += "Overall Average: \(String(format: "%.1f", average))/10\n"
        text += "Total Assessments: \(results.count)\n"
        
        // Grade interpretation
        let interpretation: String
        if average >= 9.0 {
            interpretation = "Outstanding"
        } else if average >= 7.0 {
            interpretation = "Above Average"
        } else if average >= 5.0 {
            interpretation = "Satisfactory"
        } else if average >= 3.0 {
            interpretation = "Needs Improvement"
        } else {
            interpretation = "Requires Immediate Attention"
        }
        text += "Performance Level: \(interpretation)\n"
        text += "\n"
        
        // Subject Breakdown
        let subjects: [Subject] = {
            var unique: [Subject] = []
            for result in results {
                if let subject = result.assessment?.unit?.subject,
                   !unique.contains(where: { $0.id == subject.id }) {
                    unique.append(subject)
                }
            }
            return unique.sorted { $0.name < $1.name }
        }()
        
        if !subjects.isEmpty {
            text += "SUBJECT BREAKDOWN\n"
            text += "───────────────────────────────────────────────────────────\n"
            
            for subject in subjects {
                let subjectResults = results.filter {
                    $0.assessment?.unit?.subject?.id == subject.id
                }
                let subjectAvg = subjectResults.averageScore
                
                text += "\n\(subject.name)\n"
                text += "  Average Score: \(String(format: "%.1f", subjectAvg))/10\n"
                text += "  Number of Assessments: \(subjectResults.count)\n"
                
                // Show recent assessments
                let recentResults = subjectResults.sorted { 
                    ($0.assessment?.sortOrder ?? 0) > ($1.assessment?.sortOrder ?? 0)
                }.prefix(3)
                
                if !recentResults.isEmpty {
                    text += "  Recent Assessments:\n"
                    for result in recentResults {
                        if let assessment = result.assessment {
                            text += "    • \(assessment.title): \(String(format: "%.1f", result.score))/10\n"
                        }
                    }
                }
            }
            text += "\n"
        }
        
        // Running Records (Reading)
        if !student.runningRecords.isEmpty {
            text += "\n◆ ◆ ◆\n\n"
            let sortedRecords = student.runningRecords.sorted { $0.date > $1.date }
            let avgAccuracy = student.runningRecords.reduce(0.0) { $0 + $1.accuracy } / Double(student.runningRecords.count)
            
            text += "READING ASSESSMENT (Running Records)\n"
            text += "───────────────────────────────────────────────────────────\n"
            text += "Total Reading Assessments: \(student.runningRecords.count)\n"
            text += "Average Accuracy: \(String(format: "%.1f%%", avgAccuracy))\n"
            
            if let latest = sortedRecords.first {
                text += "\nMost Recent Reading Assessment:\n"
                text += "  Date: \(DateFormatter.localizedString(from: latest.date, dateStyle: .medium, timeStyle: .none))\n"
                text += "  Text: \(latest.textTitle)\n"
                text += "  Accuracy: \(String(format: "%.1f%%", latest.accuracy))\n"
                text += "  Level: \(readingLevelDescription(latest.readingLevel))\n"
                
                if !latest.notes.isEmpty {
                    text += "  Notes: \(latest.notes)\n"
                }
            }
            
            text += "\nReading Progress:\n"
            for record in sortedRecords.prefix(5) {
                let dateStr = DateFormatter.localizedString(from: record.date, dateStyle: .short, timeStyle: .none)
                text += "  \(dateStr): \(String(format: "%.1f%%", record.accuracy)) - \(readingLevelDescription(record.readingLevel))\n"
            }
            text += "\n"
        }
        
        // Development Tracking
        let developmentScores = allDevelopmentScores.filter { $0.student?.id == student.id }
        
        if !developmentScores.isEmpty {
            text += "\n◆ ◆ ◆\n\n"
            // Group by category
            var categorized: [String: [DevelopmentScore]] = [:]
            for score in developmentScores {
                let category = displayRubricText(score.criterion?.category?.name ?? "Other")
                categorized[category, default: []].append(score)
            }
            
            text += "DEVELOPMENT TRACKING\n"
            text += "───────────────────────────────────────────────────────────\n"
            
            for (category, scores) in categorized.sorted(by: { $0.key < $1.key }) {
                text += "\n\(category)\n"
                
                // Get latest score for each criterion
                var latestScores: [UUID: DevelopmentScore] = [:]
                for score in scores {
                    guard let criterionID = score.criterion?.id else { continue }
                    if let existing = latestScores[criterionID] {
                        if score.date > existing.date {
                            latestScores[criterionID] = score
                        }
                    } else {
                        latestScores[criterionID] = score
                    }
                }
                
                for score in latestScores.values.sorted(by: { ($0.criterion?.name ?? "") < ($1.criterion?.name ?? "") }) {
                    let criterionName = displayRubricText(score.criterion?.name ?? "Unknown")
                    let stars = String(repeating: "★", count: score.rating) + String(repeating: "☆", count: 5 - score.rating)
                    text += "  \(criterionName): \(stars) (\(score.rating)/5) - \(score.ratingLabel)\n"
                }
            }
            text += "\n"
        }
        
        // Footer
        text += "\n◆ ◆ ◆\n\n"
        text += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        text += "END OF REPORT\n"
        text += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
        text += "This report was generated automatically by the Teacher Assistant system.\n"
        text += "For questions or concerns, please contact the student's teacher.\n\n"
        text += "◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆◆\n"
        
        return text
    }
    
    private static func readingLevelDescription(_ level: ReadingLevel) -> String {
        switch level {
        case .independent:
            return "Independent (95%+ accuracy)"
        case .instructional:
            return "Instructional (90-94% accuracy)"
        case .frustration:
            return "Frustration (below 90% accuracy)"
        }
    }

    private static func displayRubricText(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return value }
        let localized = trimmed.localized
        if localized != trimmed { return localized }
        let savedLanguage = UserDefaults.standard.string(forKey: "appLanguage") ?? "en"
        let languageCode = savedLanguage == "pt" ? "pt-BR" : savedLanguage
        return RubricLocalization.localized(trimmed, languageCode: languageCode)
    }
    
    private static func createFormattedReport(content: String, studentName: String) -> NSAttributedString {
        let attributedString = NSMutableAttributedString()
        
        let lines = content.components(separatedBy: "\n")
        
        // Create paragraph styles with better spacing
        let titleParagraph = NSMutableParagraphStyle()
        titleParagraph.alignment = .center
        titleParagraph.paragraphSpacing = 25
        titleParagraph.paragraphSpacingBefore = 10
        
        let sectionParagraph = NSMutableParagraphStyle()
        sectionParagraph.paragraphSpacing = 8
        sectionParagraph.paragraphSpacingBefore = 25
        
        let bodyParagraph = NSMutableParagraphStyle()
        bodyParagraph.paragraphSpacing = 5
        bodyParagraph.lineSpacing = 3
        
        let indentedParagraph = NSMutableParagraphStyle()
        indentedParagraph.paragraphSpacing = 4
        indentedParagraph.firstLineHeadIndent = 20
        indentedParagraph.headIndent = 20
        indentedParagraph.lineSpacing = 2
        
        for line in lines {
            let attrs: [NSAttributedString.Key: Any]
            
            if line.contains("STUDENT PROGRESS REPORT") {
                // Main title - very large, bold, centered
                let title = NSMutableAttributedString(string: line + "\n", attributes: [
                    .font: NSFont.boldSystemFont(ofSize: 28),
                    .foregroundColor: NSColor.systemBlue,
                    .paragraphStyle: titleParagraph
                ])
                attributedString.append(title)
                continue
            } else if line.contains("◆◆◆◆◆") {
                // Decorative diamond borders
                let decorativeParagraph = NSMutableParagraphStyle()
                decorativeParagraph.alignment = .center
                decorativeParagraph.paragraphSpacing = 8
                attrs = [
                    .font: NSFont.systemFont(ofSize: 10),
                    .foregroundColor: NSColor.systemBlue,
                    .paragraphStyle: decorativeParagraph
                ]
            } else if line.contains("◆ ◆ ◆") && line.count < 10 {
                // Section dividers
                let dividerParagraph = NSMutableParagraphStyle()
                dividerParagraph.alignment = .center
                dividerParagraph.paragraphSpacing = 8
                dividerParagraph.paragraphSpacingBefore = 8
                attrs = [
                    .font: NSFont.systemFont(ofSize: 14),
                    .foregroundColor: NSColor.systemBlue.withAlphaComponent(0.6),
                    .paragraphStyle: dividerParagraph
                ]
            } else if line.contains("━━━━") {
                // Thick divider lines (like table borders)
                let heavyDividerParagraph = NSMutableParagraphStyle()
                heavyDividerParagraph.alignment = line.contains("STUDENT INFORMATION") || line.contains("END OF REPORT") ? .left : .center
                heavyDividerParagraph.paragraphSpacing = 4
                attrs = [
                    .font: NSFont.systemFont(ofSize: 10),
                    .foregroundColor: NSColor.systemBlue,
                    .paragraphStyle: heavyDividerParagraph
                ]
            } else if line.contains("STUDENT INFORMATION") || line.contains("END OF REPORT") {
                // Section box headers
                attrs = [
                    .font: NSFont.boldSystemFont(ofSize: 14),
                    .foregroundColor: NSColor.white,
                    .paragraphStyle: bodyParagraph,
                    .backgroundColor: NSColor.systemBlue
                ]
            } else if line.hasPrefix("Student Name:") || line.hasPrefix("Report Date:") {
                // Info labels within boxes
                attrs = [
                    .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                    .foregroundColor: NSColor.black,
                    .paragraphStyle: bodyParagraph
                ]
            } else if line.contains("Academic Year") {
                // Academic year subtitle
                let yearParagraph = NSMutableParagraphStyle()
                yearParagraph.alignment = .center
                yearParagraph.paragraphSpacing = 5
                attrs = [
                    .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                    .foregroundColor: NSColor.systemGray,
                    .paragraphStyle: yearParagraph
                ]
            } else if line.contains("STATUS INDICATORS") {
                // Status section with red theme
                attrs = [
                    .font: NSFont.boldSystemFont(ofSize: 17),
                    .foregroundColor: NSColor.systemRed,
                    .paragraphStyle: sectionParagraph,
                    .backgroundColor: NSColor.systemRed.withAlphaComponent(0.1)
                ]
            } else if line.contains("ATTENDANCE") {
                // Attendance section with green theme
                attrs = [
                    .font: NSFont.boldSystemFont(ofSize: 17),
                    .foregroundColor: NSColor.systemGreen,
                    .paragraphStyle: sectionParagraph,
                    .backgroundColor: NSColor.systemGreen.withAlphaComponent(0.1)
                ]
            } else if line.contains("ACADEMIC") || line.contains("SUBJECT BREAKDOWN") {
                // Academic section with purple theme
                attrs = [
                    .font: NSFont.boldSystemFont(ofSize: 17),
                    .foregroundColor: NSColor.systemPurple,
                    .paragraphStyle: sectionParagraph,
                    .backgroundColor: NSColor.systemPurple.withAlphaComponent(0.1)
                ]
            } else if line.contains("READING") {
                // Reading section with orange theme
                attrs = [
                    .font: NSFont.boldSystemFont(ofSize: 17),
                    .foregroundColor: NSColor.systemOrange,
                    .paragraphStyle: sectionParagraph,
                    .backgroundColor: NSColor.systemOrange.withAlphaComponent(0.1)
                ]
            } else if line.contains("DEVELOPMENT") {
                // Development section with pink theme
                attrs = [
                    .font: NSFont.boldSystemFont(ofSize: 17),
                    .foregroundColor: NSColor.systemPink,
                    .paragraphStyle: sectionParagraph,
                    .backgroundColor: NSColor.systemPink.withAlphaComponent(0.1)
                ]
            } else if line.uppercased() == line && line.count > 10 && !line.contains("◆") && !line.contains("━") && !line.contains("─") && !line.contains("STUDENT") && !line.contains("STATUS") && !line.contains("ATTENDANCE") && !line.contains("ACADEMIC") && !line.contains("READING") && !line.contains("DEVELOPMENT") {
                // School name at the top (all caps, long text)
                let schoolParagraph = NSMutableParagraphStyle()
                schoolParagraph.alignment = .center
                schoolParagraph.paragraphSpacing = 8
                attrs = [
                    .font: NSFont.boldSystemFont(ofSize: 20),
                    .foregroundColor: NSColor.systemBlue,
                    .paragraphStyle: schoolParagraph
                ]
            } else if line.hasPrefix("Student:") || line.hasPrefix("Class:") {
                // Important student info - larger, bold
                attrs = [
                    .font: NSFont.systemFont(ofSize: 15, weight: .bold),
                    .foregroundColor: NSColor.black,
                    .paragraphStyle: bodyParagraph
                ]
            } else if line.hasPrefix("Report Generated:") {
                // Date info
                attrs = [
                    .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                    .foregroundColor: NSColor.systemGray,
                    .paragraphStyle: bodyParagraph
                ]
            } else if line.hasPrefix("Teacher Notes:") || line.hasPrefix("Most Recent") || line.hasPrefix("Reading Progress:") {
                // Subsection headers
                attrs = [
                    .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                    .foregroundColor: NSColor.darkGray,
                    .paragraphStyle: sectionParagraph
                ]
            } else if line.contains("Performance Level:") {
                // Performance level - highlight it
                attrs = [
                    .font: NSFont.systemFont(ofSize: 13, weight: .bold),
                    .foregroundColor: NSColor.systemPurple,
                    .paragraphStyle: bodyParagraph,
                    .backgroundColor: NSColor.systemYellow.withAlphaComponent(0.2)
                ]
            } else if line.contains("─") || line.contains("═") {
                // Divider lines - thicker and colored
                attrs = [
                    .font: NSFont.systemFont(ofSize: 12),
                    .foregroundColor: NSColor.systemBlue.withAlphaComponent(0.3),
                    .paragraphStyle: bodyParagraph
                ]
            } else if line.hasPrefix("    •") {
                // Bullet points (deep indent)
                attrs = [
                    .font: NSFont.systemFont(ofSize: 11),
                    .foregroundColor: NSColor.darkGray,
                    .paragraphStyle: indentedParagraph
                ]
            } else if line.hasPrefix("  ") {
                // Indented items
                attrs = [
                    .font: NSFont.systemFont(ofSize: 12),
                    .foregroundColor: NSColor.darkGray,
                    .paragraphStyle: indentedParagraph
                ]
            } else if line.contains("⚠") {
                // Warning indicators - orange
                attrs = [
                    .font: NSFont.systemFont(ofSize: 13, weight: .medium),
                    .foregroundColor: NSColor.systemOrange,
                    .paragraphStyle: bodyParagraph,
                    .backgroundColor: NSColor.systemOrange.withAlphaComponent(0.1)
                ]
            } else if line.contains("✓") {
                // Success indicators - green
                attrs = [
                    .font: NSFont.systemFont(ofSize: 13, weight: .medium),
                    .foregroundColor: NSColor.systemGreen,
                    .paragraphStyle: bodyParagraph,
                    .backgroundColor: NSColor.systemGreen.withAlphaComponent(0.1)
                ]
            } else if line.contains("★") {
                // Star ratings - yellow/gold
                attrs = [
                    .font: NSFont.systemFont(ofSize: 13),
                    .foregroundColor: NSColor.systemOrange,
                    .paragraphStyle: bodyParagraph
                ]
            } else if line.contains("End of Report") {
                // Footer text - centered, smaller
                let footerParagraph = NSMutableParagraphStyle()
                footerParagraph.alignment = .center
                footerParagraph.paragraphSpacing = 5
                attrs = [
                    .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                    .foregroundColor: NSColor.systemGray,
                    .paragraphStyle: footerParagraph
                ]
            } else if line.isEmpty {
                // Empty lines - minimal spacing
                attrs = [
                    .font: NSFont.systemFont(ofSize: 4),
                    .paragraphStyle: bodyParagraph
                ]
            } else {
                // Regular body text - clean and readable
                attrs = [
                    .font: NSFont.systemFont(ofSize: 12),
                    .foregroundColor: NSColor.black,
                    .paragraphStyle: bodyParagraph
                ]
            }
            
            attributedString.append(NSAttributedString(string: line + "\n", attributes: attrs))
        }
        
        return attributedString
    }
    
    private static func saveToPDF(attributedString: NSAttributedString, fileName: String) -> URL {
        
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        // Create a text view with the content sized for A4 paper
        let pageWidth: CGFloat = 595.2 - 100  // A4 width minus margins
        let pageHeight: CGFloat = 841.8 - 100 // A4 height minus margins
        
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        textView.textStorage?.setAttributedString(attributedString)
        
        // Let the text view resize to fit all content
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)
        
        // Get the actual size needed
        let usedRect = textView.layoutManager!.usedRect(for: textView.textContainer!)
        textView.frame = NSRect(x: 0, y: 0, width: pageWidth, height: max(usedRect.height, pageHeight))
        
        // Generate PDF data directly from the view
        let pdfData = textView.dataWithPDF(inside: NSRect(x: 0, y: 0, width: pageWidth, height: textView.frame.height))
        
        do {
            try pdfData.write(to: url, options: [.atomic, .completeFileProtection])
            SecureLogger.debug("PDF saved successfully (\(pdfData.count) bytes)")
        } catch {
            SecureLogger.error("Error saving PDF", error: error)
        }
        
        return url
    }
}

#elseif os(iOS)

import UIKit

/// iOS version using UIGraphicsPDFRenderer (already working)
struct SimplePDFExporter {
    static func exportStudentReport(
        student: Student,
        schoolName: String,
        allResults: [StudentResult],
        allAttendanceSessions: [AttendanceSession],
        allDevelopmentScores: [DevelopmentScore] = []
    ) -> URL {
        // Use the existing iOS implementation from StudentReportExporter
        return StudentReportExporter.export(
            student: student,
            schoolName: schoolName,
            allResults: allResults,
            allAttendanceSessions: allAttendanceSessions
        )
    }
}

#endif
