import SwiftData
import Foundation

#if os(iOS)

import UIKit

// =======================
// ✅ iOS IMPLEMENTATION
// =======================

enum StudentReportExporter {

    static func export(
        student: Student,
        schoolName: String,
        allResults: [StudentResult],
        allAttendanceSessions: [AttendanceSession]
    ) -> URL {

        let pageWidth: CGFloat = 595.2   // A4
        let pageHeight: CGFloat = 841.8
        let margin: CGFloat = 40

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        // Use secure filename generation instead of directly using student name
        let safeFilename = SecurityHelpers.generateSecureFilename(
            baseName: "StudentReport",
            extension: "pdf"
        )
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(safeFilename)

        var currentPage = 1

        try? renderer.writePDF(to: url) { context in

            var y: CGFloat = margin

            func beginPage() {
                context.beginPage()
                y = margin
                drawFooter(page: currentPage)
                currentPage += 1
            }

            func startNewPageIfNeeded(_ needed: CGFloat) {
                if y + needed > pageHeight - margin - 40 {
                    beginPage()
                }
            }

            // Start first page
            beginPage()

            // MARK: - Header

            if !schoolName.trimmingCharacters(in: .whitespaces).isEmpty {
                let schoolAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 18)
                ]
                schoolName.draw(at: CGPoint(x: margin, y: y), withAttributes: schoolAttrs)
                y += 28
            }

            let title = "Student Report"
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 28)
            ]
            let titleSize = title.size(withAttributes: titleAttrs)
            title.draw(at: CGPoint(x: (pageWidth - titleSize.width) / 2, y: y), withAttributes: titleAttrs)
            y += titleSize.height + 16

            // Student name
            let nameAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 20, weight: .medium)
            ]
            ("Student: \(student.name)").draw(at: CGPoint(x: margin, y: y), withAttributes: nameAttrs)
            y += 32

            // Date
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            ("Date: \(dateFormatter.string(from: Date()))").draw(
                at: CGPoint(x: margin, y: y),
                withAttributes: [.font: UIFont.systemFont(ofSize: 12)]
            )
            y += 32

            // MARK: - Attendance

            let recordsForStudent: [AttendanceRecord] = allAttendanceSessions.flatMap { session in
                session.records.filter { $0.student.id == student.id }
            }

            let total = recordsForStudent.count
            let present = recordsForStudent.filter { $0.status == .present }.count
            let absent = recordsForStudent.filter { $0.status == .absent }.count
            let early = recordsForStudent.filter { $0.status == .late }.count
            let percentage = total == 0 ? 0 : Int((Double(present) / Double(total)) * 100)

            startNewPageIfNeeded(120)

            drawSectionTitle("Attendance", y: &y)

            let attendanceText = """
            Total sessions: \(total)
            Present: \(present)
            Absent: \(absent)
            Early: \(early)
            Attendance: \(percentage)%
            """

            y = drawParagraph(attendanceText, y: y) + 16

            // MARK: - Academic Results

            drawSectionTitle("Academic Progress", y: &y)

            let resultsForStudent = allResults.filter { $0.student?.id == student.id }

            let subjects: [Subject] = unique(
                resultsForStudent.compactMap { $0.assessment?.unit?.subject }
            )

            for subject in subjects.sorted(by: { $0.name < $1.name }) {

                startNewPageIfNeeded(80)

                let subjectResults = resultsForStudent.filter {
                    $0.assessment?.unit?.subject?.id == subject.id
                }

                let subjectAvg = subjectResults.averageScore

                drawSubTitle("\(subject.name) — Average: \(String(format: "%.1f", subjectAvg))", y: &y)

                let units: [Unit] = unique(
                    subjectResults.compactMap { $0.assessment?.unit }
                )

                for unit in units.sorted(by: { $0.name < $1.name }) {

                    startNewPageIfNeeded(60)

                    let unitResults = subjectResults.filter {
                        $0.assessment?.unit?.id == unit.id
                    }

                    let unitAvg = unitResults.averageScore

                    drawBoldLine("• \(unit.name) — Average: \(String(format: "%.1f", unitAvg))", y: &y)

                    for result in unitResults {
                        guard let assessment = result.assessment else { continue }

                        startNewPageIfNeeded(80)

                        let score = result.score == 0 ? "Not evaluated" : "\(Int(result.score))"

                        let line = "   - \(assessment.title): \(score)"
                        y = drawParagraph(line, y: y)

                        if !result.notes.isEmpty {
                            y = drawParagraph("      Notes: \(result.notes)", y: y)
                        }

                        y += 6
                    }

                    y += 12
                }

                y += 16
            }
        }

        return url
    }

    // MARK: - Drawing helpers (iOS)

    static func drawFooter(page: Int) {
        let footer = "Page \(page)"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.gray
        ]
        let size = footer.size(withAttributes: attrs)
        footer.draw(
            at: CGPoint(x: (595.2 - size.width) / 2, y: 841.8 - 30),
            withAttributes: attrs
        )
    }

    static func drawSectionTitle(_ text: String, y: inout CGFloat) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 20)
        ]
        text.draw(at: CGPoint(x: 40, y: y), withAttributes: attrs)
        y += 28
    }

    static func drawSubTitle(_ text: String, y: inout CGFloat) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 16)
        ]
        text.draw(at: CGPoint(x: 40, y: y), withAttributes: attrs)
        y += 24
    }

    static func drawBoldLine(_ text: String, y: inout CGFloat) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 13)
        ]
        text.draw(at: CGPoint(x: 40, y: y), withAttributes: attrs)
        y += 18
    }

    static func drawParagraph(_ text: String, y: CGFloat) -> CGFloat {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping

        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .paragraphStyle: paragraphStyle
        ]

        let width: CGFloat = 595.2 - 80
        let rect = CGRect(x: 40, y: y, width: width, height: 10_000)
        let ns = NSString(string: text)
        let used = ns.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            attributes: attrs,
            context: nil
        )

        ns.draw(in: CGRect(x: 40, y: y, width: width, height: used.height), withAttributes: attrs)

        return y + used.height
    }

    static func unique<T: AnyObject>(_ items: [T]) -> [T] {
        var result: [T] = []
        for item in items {
            if !result.contains(where: { $0 === item }) {
                result.append(item)
            }
        }
        return result
    }
}

#else

// =======================
// ✅ macOS IMPLEMENTATION
// =======================

import AppKit
import CoreGraphics

enum StudentReportExporter {

    static func export(
        student: Student,
        schoolName: String,
        allResults: [StudentResult],
        allAttendanceSessions: [AttendanceSession]
    ) -> URL {

        // Use secure filename generation instead of directly using student name
        let safeFilename = SecurityHelpers.generateSecureFilename(
            baseName: "StudentReport",
            extension: "pdf"
        )
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(safeFilename)

        let pageWidth: CGFloat = 595.2
        let pageHeight: CGFloat = 841.8
        var pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let margin: CGFloat = 40
        
        guard let pdfContext = CGContext(url as CFURL, mediaBox: &pageRect, [
            kCGPDFContextTitle as String: "Student Report",
            kCGPDFContextCreator as String: "Teacher Assistant"
        ] as CFDictionary) else {
            print("❌ Failed to create PDF context")
            return url
        }
        
        pdfContext.beginPDFPage(nil)
        
        var y: CGFloat = pageHeight - 50 // Start from top (PDF coords: bottom-left origin)
        
        // Helper to draw text using Core Text
        func drawText(_ text: String, fontSize: CGFloat, bold: Bool = false) {
            let fontName = bold ? "Helvetica-Bold" : "Helvetica"
            let font = CTFontCreateWithName(fontName as CFString, fontSize, nil)
            
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.black
            ]
            
            let attributedString = NSAttributedString(string: text, attributes: attributes)
            let line = CTLineCreateWithAttributedString(attributedString as CFAttributedString)
            
            pdfContext.textPosition = CGPoint(x: margin, y: y)
            CTLineDraw(line, pdfContext)
            
            y -= (fontSize + 10)
        }
        
        // Background test rectangle
        pdfContext.setFillColor(red: 0.95, green: 0.95, blue: 1.0, alpha: 1.0)
        pdfContext.fill(CGRect(x: margin, y: pageHeight - 150, width: pageWidth - 2*margin, height: 100))
        
        // Header
        if !schoolName.trimmingCharacters(in: .whitespaces).isEmpty {
            drawText(schoolName, fontSize: 16, bold: true)
        }
        
        drawText("Student Progress Report".localized, fontSize: 28, bold: true)
        drawText(String(format: "Student: %@".localized, student.name), fontSize: 20, bold: true)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        drawText(
            String(format: "Date: %@".localized, dateFormatter.string(from: Date())),
            fontSize: 12
        )
        
        y -= 20
        
        // Attendance
        let recordsForStudent: [AttendanceRecord] = allAttendanceSessions.flatMap { session in
            session.records.filter { $0.student.id == student.id }
        }
        
        let total = recordsForStudent.count
        let present = recordsForStudent.filter { $0.status == .present }.count
        let absent = recordsForStudent.filter { $0.status == .absent }.count
        let early = recordsForStudent.filter { $0.status == .late }.count
        let percentage = total > 0 ? Int((Double(present) / Double(total)) * 100) : 0
        
        drawText("Attendance".localized, fontSize: 20, bold: true)
        drawText(String(format: "Total sessions: %d".localized, total), fontSize: 14)
        drawText(String(format: "Present: %d (%d%%)".localized, present, percentage), fontSize: 14)
        drawText(String(format: "Absent: %d".localized, absent), fontSize: 14)
        drawText(String(format: "Late: %d".localized, early), fontSize: 14)
        
        y -= 20
        
        // Academic Results
        let resultsForStudent = allResults.filter { $0.student?.id == student.id }
        let average = resultsForStudent.averageScore
        
        drawText("Academic Progress".localized, fontSize: 20, bold: true)
        drawText(String(format: "Overall Average: %.1f".localized, average), fontSize: 14)
        drawText(String(format: "Total Assessments: %d".localized, resultsForStudent.count), fontSize: 14)
        
        y -= 10
        
        // Subject Breakdown
        let subjects: [Subject] = unique(resultsForStudent.compactMap { $0.assessment?.unit?.subject })
        
        for subject in subjects.sorted(by: { $0.name < $1.name }).prefix(10) {
            let subjectResults = resultsForStudent.filter {
                $0.assessment?.unit?.subject?.id == subject.id
            }
            let subjectAvg = subjectResults.averageScore
            
            drawText(String(format: "%@: %.1f".localized, subject.name, subjectAvg), fontSize: 14, bold: true)
            
            if y < 100 { break } // Don't overflow page
        }
        
        // Footer
        let footerY: CGFloat = 30
        let footerText = "Generated by Teacher Assistant • Page 1 • \(dateFormatter.string(from: Date()))"
        let footerFont = CTFontCreateWithName("Helvetica" as CFString, 10, nil)
        let footerAttrs: [NSAttributedString.Key: Any] = [
            .font: footerFont,
            .foregroundColor: NSColor.gray
        ]
        let footerAttrString = NSAttributedString(string: footerText, attributes: footerAttrs)
        let footerLine = CTLineCreateWithAttributedString(footerAttrString as CFAttributedString)
        pdfContext.textPosition = CGPoint(x: margin, y: footerY)
        CTLineDraw(footerLine, pdfContext)
        
        pdfContext.endPDFPage()
        pdfContext.closePDF()
        
        print("✅ PDF generated successfully at: \(url.path)")
        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
           let fileSize = attributes[.size] as? Int {
            print("   File size: \(fileSize) bytes")
        }

        return url
    }

    static func unique<T: AnyObject>(_ items: [T]) -> [T] {
        var result: [T] = []
        for item in items {
            if !result.contains(where: { $0 === item }) {
                result.append(item)
            }
        }
        return result
    }
}

#endif
