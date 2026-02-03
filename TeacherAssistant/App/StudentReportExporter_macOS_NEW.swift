import Foundation
import SwiftData

#if os(macOS)
import AppKit

/// Simple, working macOS PDF exporter
enum StudentReportExporterMac {
    
    static func export(
        student: Student,
        schoolName: String,
        allResults: [StudentResult],
        allAttendanceSessions: [AttendanceSession]
    ) -> URL {
        
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("StudentReport-\(student.name).pdf")
        
        let pageWidth: CGFloat = 595.2   // A4
        let pageHeight: CGFloat = 841.8
        
        // Create an NSView to draw into
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        
        // Create PDF data
        let pdfData = contentView.dataWithPDF(inside: contentView.bounds)
        
        // OR use a simpler text-based approach
        let textContent = generateTextContent(
            student: student,
            schoolName: schoolName,
            allResults: allResults,
            allAttendanceSessions: allAttendanceSessions
        )
        
        // Create attributed string
        let attributedString = NSAttributedString(
            string: textContent,
            attributes: [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.black
            ]
        )
        
        // Create PDF from attributed string
        let printInfo = NSPrintInfo.shared
        printInfo.paperSize = NSSize(width: pageWidth, height: pageHeight)
        printInfo.topMargin = 40
        printInfo.bottomMargin = 40
        printInfo.leftMargin = 40
        printInfo.rightMargin = 40
        
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: pageWidth - 80, height: pageHeight - 80))
        textView.textStorage?.setAttributedString(attributedString)
        
        let printOperation = NSPrintOperation(view: textView, printInfo: printInfo)
        printOperation.showsPrintPanel = false
        printOperation.showsProgressPanel = false
        
        // Save to PDF
        printOperation.run()
        
        // Fallback: Just write the text content
        try? textContent.write(to: url.deletingPathExtension().appendingPathExtension("txt"), atomically: true, encoding: .utf8)
        
        // Create simple PDF with Core Graphics
        let actualPDFURL = createSimplePDF(
            student: student,
            schoolName: schoolName,
            allResults: allResults,
            allAttendanceSessions: allAttendanceSessions
        )
        
        return actualPDFURL
    }
    
    static func createSimplePDF(
        student: Student,
        schoolName: String,
        allResults: [StudentResult],
        allAttendanceSessions: [AttendanceSession]
    ) -> URL {
        
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("StudentReport-\(student.name).pdf")
        
        let pageWidth: CGFloat = 595.2
        let pageHeight: CGFloat = 841.8
        var pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        guard let pdfContext = CGContext(url as CFURL, mediaBox: &pageRect, [
            kCGPDFContextTitle as String: "Student Report".localized,
            kCGPDFContextCreator as String: "Teacher Assistant".localized
        ] as CFDictionary) else {
            print("❌ Failed to create PDF context")
            return url
        }
        
        pdfContext.beginPDFPage(nil)
        
        // CRITICAL: We need to use Core Text with proper text matrix
        // PDF coordinates have origin at bottom-left, so y increases upward
        
        var y: CGFloat = pageHeight - 50 // Start from top
        let margin: CGFloat = 50
        
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
            
            // Set text position (PDF coordinates: bottom-left origin)
            pdfContext.textPosition = CGPoint(x: margin, y: y)
            
            // Draw the line
            CTLineDraw(line, pdfContext)
            
            // Move y down for next line
            y -= (fontSize + 10)
        }
        
        // Draw background rectangle to test rendering
        pdfContext.setFillColor(red: 0.95, green: 0.95, blue: 1.0, alpha: 1.0)
        pdfContext.fill(CGRect(x: margin, y: pageHeight - 150, width: pageWidth - 2*margin, height: 100))
        
        // Draw title
        drawText("Student Progress Report".localized, fontSize: 28, bold: true)
        
        // Draw student info
        drawText(String(format: "Student: %@".localized, student.name), fontSize: 20, bold: true)
        drawText(
            String(
                format: "Date: %@".localized,
                DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .none)
            ),
            fontSize: 12
        )
        
        if !schoolName.isEmpty {
            drawText(String(format: "School: %@".localized, schoolName), fontSize: 12)
        }
        
        y -= 20 // Extra space
        
        // Attendance section
        let records: [AttendanceRecord] = allAttendanceSessions.flatMap { session in
            session.records.filter { $0.student.id == student.id }
        }
        
        let total = records.count
        let present = records.filter { $0.status == .present }.count
        let percentage = total > 0 ? Int((Double(present) / Double(total)) * 100) : 0
        
        drawText("Attendance".localized, fontSize: 20, bold: true)
        drawText(String(format: "Total sessions: %d".localized, total), fontSize: 14)
        drawText(String(format: "Present: %d (%d%%)".localized, present, percentage), fontSize: 14)
        drawText(
            String(
                format: "Absent: %d".localized,
                records.filter { $0.status == .absent }.count
            ),
            fontSize: 14
        )
        
        y -= 20
        
        // Academic section
        let results = allResults.filter { $0.student?.id == student.id }
        let average = results.averageScore
        
        drawText("Academic Performance".localized, fontSize: 20, bold: true)
        drawText(String(format: "Total Assessments: %d".localized, results.count), fontSize: 14)
        drawText(String(format: "Overall Average: %.1f".localized, average), fontSize: 14)
        
        // Draw footer
        let footerY: CGFloat = 30
        let footerText = "Generated by Teacher Assistant • Page 1"
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
        
        print("✅ PDF created at: \(url.path)")
        if FileManager.default.fileExists(atPath: url.path) {
            if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
               let fileSize = attributes[.size] as? Int {
                print("   File size: \(fileSize) bytes")
            }
        }
        
        return url
    }
    
    static func generateTextContent(
        student: Student,
        schoolName: String,
        allResults: [StudentResult],
        allAttendanceSessions: [AttendanceSession]
    ) -> String {
        var text = "Student Progress Report".localized.uppercased() + "\n\n"
        text += "School: \(schoolName)\n"
        text += "Student".localized + ": \(student.name)\n"
        text += "Date".localized + ": \(Date())\n\n"
        
        text += "Attendance".localized.uppercased() + "\n"
        let records: [AttendanceRecord] = allAttendanceSessions.flatMap { session in
            session.records.filter { $0.student.id == student.id }
        }
        text += "Total Sessions".localized + ": \(records.count)\n"
        text += "Present".localized + ": \(records.filter { $0.status == .present }.count)\n\n"
        
        text += "Academic Performance".localized.uppercased() + "\n"
        let results = allResults.filter { $0.student?.id == student.id }
        text += "Total Assessments".localized + ": \(results.count)\n"
        text += "Overall Average".localized + ": \(String(format: "%.1f", results.averageScore))\n"
        
        return text
    }
}

#endif
