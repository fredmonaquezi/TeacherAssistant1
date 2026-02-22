import SwiftData
import Foundation

#if os(iOS)

import UIKit

// ====================================
// MARK: - iOS IMPLEMENTATION
// ====================================

enum RunningRecordPDFExporter {

    static func export(
        student: Student,
        schoolName: String,
        runningRecords: [RunningRecord],
        appliedFilters: String? = nil
    ) -> URL {

        let pageWidth: CGFloat = 595.2   // A4
        let pageHeight: CGFloat = 841.8
        let margin: CGFloat = 40
        let contentWidth = pageWidth - margin * 2

        let renderer = UIGraphicsPDFRenderer(
            bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        )

        let safeFilename = SecurityHelpers.generateSecureFilename(
            baseName: "RunningRecords",
            extension: "pdf"
        )
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(safeFilename)

        let sorted = runningRecords.sorted { $0.date > $1.date }
        var currentPage = 0

        try? renderer.writePDF(to: url) { context in

            var y: CGFloat = margin

            // MARK: - Page Management

            func beginPage() {
                context.beginPage()
                currentPage += 1
                y = margin
                drawFooter(context: context, page: currentPage, pageWidth: pageWidth, pageHeight: pageHeight)
            }

            func spaceLeft() -> CGFloat {
                return pageHeight - margin - 40 - y
            }

            func startNewPageIfNeeded(_ needed: CGFloat) {
                if spaceLeft() < needed {
                    beginPage()
                }
            }

            // MARK: - Drawing Helpers

            func drawCentered(_ text: String, fontSize: CGFloat, bold: Bool = false, color: UIColor = .black) {
                let font = bold ? UIFont.boldSystemFont(ofSize: fontSize) : UIFont.systemFont(ofSize: fontSize)
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
                let size = text.size(withAttributes: attrs)
                text.draw(at: CGPoint(x: (pageWidth - size.width) / 2, y: y), withAttributes: attrs)
                y += size.height + 6
            }

            func drawLeft(_ text: String, fontSize: CGFloat, bold: Bool = false, color: UIColor = .black, indent: CGFloat = 0) {
                let font = bold ? UIFont.boldSystemFont(ofSize: fontSize) : UIFont.systemFont(ofSize: fontSize)
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
                text.draw(at: CGPoint(x: margin + indent, y: y), withAttributes: attrs)
                y += fontSize + 8
            }

            func drawWrapped(_ text: String, fontSize: CGFloat, bold: Bool = false, color: UIColor = .black, indent: CGFloat = 0) -> CGFloat {
                let font = bold ? UIFont.boldSystemFont(ofSize: fontSize) : UIFont.systemFont(ofSize: fontSize)
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.lineBreakMode = .byWordWrapping
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font, .foregroundColor: color, .paragraphStyle: paragraphStyle
                ]
                let drawWidth = contentWidth - indent
                let ns = NSString(string: text)
                let boundingRect = ns.boundingRect(
                    with: CGSize(width: drawWidth, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin],
                    attributes: attrs,
                    context: nil
                )
                ns.draw(
                    in: CGRect(x: margin + indent, y: y, width: drawWidth, height: boundingRect.height),
                    withAttributes: attrs
                )
                y += boundingRect.height + 4
                return boundingRect.height
            }

            func drawHorizontalLine(color: UIColor = .lightGray, thickness: CGFloat = 0.5) {
                let cgColor = color.cgColor
                context.cgContext.setStrokeColor(cgColor)
                context.cgContext.setLineWidth(thickness)
                context.cgContext.move(to: CGPoint(x: margin, y: y))
                context.cgContext.addLine(to: CGPoint(x: pageWidth - margin, y: y))
                context.cgContext.strokePath()
                y += thickness + 8
            }

            func drawThickLine(color: UIColor = .systemBlue, thickness: CGFloat = 2) {
                let cgColor = color.cgColor
                context.cgContext.setStrokeColor(cgColor)
                context.cgContext.setLineWidth(thickness)
                context.cgContext.move(to: CGPoint(x: margin, y: y))
                context.cgContext.addLine(to: CGPoint(x: pageWidth - margin, y: y))
                context.cgContext.strokePath()
                y += thickness + 10
            }

            func drawRoundedBox(x boxX: CGFloat, y boxY: CGFloat, width: CGFloat, height: CGFloat, fillColor: UIColor) {
                let rect = CGRect(x: boxX, y: boxY, width: width, height: height)
                let path = UIBezierPath(roundedRect: rect, cornerRadius: 6)
                fillColor.setFill()
                path.fill()
            }

            func levelUIColor(_ level: ReadingLevel) -> UIColor {
                switch level {
                case .independent: return .systemGreen
                case .instructional: return .systemOrange
                case .frustration: return .systemRed
                }
            }

            func levelDiagnosis(_ level: ReadingLevel) -> String {
                switch level {
                case .independent:
                    return "Independent — The student reads this text with ease and strong comprehension. Ready for more challenging material."
                case .instructional:
                    return "Instructional — The student can read this text with some support. Ideal level for guided reading instruction."
                case .frustration:
                    return "Frustration — The student struggles significantly with this text. Consider easier material to build confidence and fluency."
                }
            }

            // =========================================
            // MARK: - PAGE 1: HEADER & SUMMARY
            // =========================================

            beginPage()

            // School name
            if !schoolName.trimmingCharacters(in: .whitespaces).isEmpty {
                drawCentered(schoolName.uppercased(), fontSize: 14, bold: true, color: .darkGray)
                y += 2
            }

            // Decorative line
            drawThickLine(color: .systemBlue, thickness: 2)

            // Title
            drawCentered("Running Records Report", fontSize: 26, bold: true, color: .systemBlue)
            y += 4

            // Student info box
            let infoBoxY = y
            drawRoundedBox(x: margin, y: infoBoxY, width: contentWidth, height: 64, fillColor: UIColor.systemBlue.withAlphaComponent(0.08))
            y += 12
            drawLeft("Student: \(SecurityHelpers.sanitizeNotes(student.name))", fontSize: 16, bold: true, indent: 16)
            if let schoolClass = student.schoolClass {
                drawLeft("Class: \(schoolClass.name)  •  Grade: \(schoolClass.grade)", fontSize: 12, color: .darkGray, indent: 16)
            }
            y = infoBoxY + 64 + 12

            // Date
            drawLeft("Report Date: \(Date().appDateString(systemStyle: .long))", fontSize: 11, color: .gray)
            if let appliedFilters, !appliedFilters.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                drawLeft("Filters: \(appliedFilters)", fontSize: 10, color: .gray)
            }
            y += 8

            drawHorizontalLine()

            // MARK: - Summary Statistics

            drawLeft("Summary", fontSize: 18, bold: true)
            y += 4

            if sorted.isEmpty {
                drawLeft("No running records available for this student.", fontSize: 13, color: .gray)
            } else {
                // Calculate summary stats
                let totalRecords = sorted.count
                let avgAccuracy = sorted.reduce(0.0) { $0 + $1.accuracy } / Double(totalRecords)
                let latestLevel = sorted.first!.readingLevel

                // Trend: compare average of last 3 vs previous 3
                let trend: String = {
                    guard sorted.count >= 4 else { return "Not enough data" }
                    let recent3 = sorted.prefix(3).reduce(0.0) { $0 + $1.accuracy } / 3.0
                    let prev3 = sorted.dropFirst(3).prefix(3).reduce(0.0) { $0 + $1.accuracy } / min(3.0, Double(sorted.dropFirst(3).prefix(3).count))
                    if recent3 > prev3 + 1 { return "Improving ↑" }
                    else if recent3 < prev3 - 1 { return "Declining ↓" }
                    else { return "Stable →" }
                }()

                // Draw 4 stat boxes in a row
                let boxWidth = (contentWidth - 30) / 4
                let boxHeight: CGFloat = 56
                let boxY = y

                let statItems: [(String, String, UIColor)] = [
                    ("\(totalRecords)", "Total Records", .systemBlue),
                    (String(format: "%.1f%%", avgAccuracy), "Avg. Accuracy", avgAccuracy >= 95 ? .systemGreen : avgAccuracy >= 90 ? .systemOrange : .systemRed),
                    (levelShortName(latestLevel), "Current Level", levelUIColor(latestLevel)),
                    (trend, "Trend", .systemPurple)
                ]

                for (index, item) in statItems.enumerated() {
                    let boxX = margin + CGFloat(index) * (boxWidth + 10)
                    drawRoundedBox(x: boxX, y: boxY, width: boxWidth, height: boxHeight, fillColor: item.2.withAlphaComponent(0.1))

                    let valueAttrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.boldSystemFont(ofSize: 15),
                        .foregroundColor: item.2
                    ]
                    let labelAttrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 9),
                        .foregroundColor: UIColor.darkGray
                    ]

                    let valueSize = item.0.size(withAttributes: valueAttrs)
                    let labelSize = item.1.size(withAttributes: labelAttrs)
                    let totalTextHeight = valueSize.height + labelSize.height + 4
                    let textStartY = boxY + (boxHeight - totalTextHeight) / 2

                    item.0.draw(at: CGPoint(x: boxX + (boxWidth - valueSize.width) / 2, y: textStartY), withAttributes: valueAttrs)
                    item.1.draw(at: CGPoint(x: boxX + (boxWidth - labelSize.width) / 2, y: textStartY + valueSize.height + 4), withAttributes: labelAttrs)
                }

                y = boxY + boxHeight + 16
            }

            // MARK: - Reading Level Guide

            y += 4
            drawHorizontalLine()
            drawLeft("Reading Level Guide", fontSize: 14, bold: true, color: .darkGray)
            y += 2

            let levels: [(ReadingLevel, String)] = [
                (.independent, "Independent (95-100%) — Reads with ease, strong comprehension"),
                (.instructional, "Instructional (90-94%) — Reads with some support needed"),
                (.frustration, "Frustration (below 90%) — Significant difficulty, needs easier text")
            ]

            for (level, description) in levels {
                let dotColor = levelUIColor(level)
                // Draw colored dot
                let dotRect = CGRect(x: margin + 4, y: y + 3, width: 8, height: 8)
                let dotPath = UIBezierPath(ovalIn: dotRect)
                dotColor.setFill()
                dotPath.fill()

                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10),
                    .foregroundColor: UIColor.darkGray
                ]
                description.draw(at: CGPoint(x: margin + 18, y: y), withAttributes: attrs)
                y += 16
            }

            // =========================================
            // MARK: - INDIVIDUAL RECORD CARDS
            // =========================================

            y += 12
            drawHorizontalLine()
            drawLeft("Assessment History", fontSize: 18, bold: true)
            y += 4

            for (index, record) in sorted.enumerated() {
                let cardHeight: CGFloat = record.notes.isEmpty ? 160 : 190
                startNewPageIfNeeded(cardHeight)

                // Card background
                let cardY = y
                let cardBgColor = levelUIColor(record.readingLevel).withAlphaComponent(0.05)
                drawRoundedBox(x: margin, y: cardY, width: contentWidth, height: cardHeight - 10, fillColor: cardBgColor)

                // Left color bar
                let barColor = levelUIColor(record.readingLevel)
                let barRect = CGRect(x: margin, y: cardY, width: 4, height: cardHeight - 10)
                barColor.setFill()
                UIBezierPath(roundedRect: barRect, byRoundingCorners: [.topLeft, .bottomLeft], cornerRadii: CGSize(width: 6, height: 6)).fill()

                y += 10
                let inset: CGFloat = 16

                // Record number & date
                let headerText = "#\(index + 1)  •  \(record.date.appDateString(systemStyle: .medium))"
                drawLeft(headerText, fontSize: 10, color: .gray, indent: inset)

                // Book title
                let sanitizedTitle = SecurityHelpers.sanitizeNotes(record.textTitle)
                drawLeft(sanitizedTitle, fontSize: 15, bold: true, indent: inset)
                y += 2

                // Stats row: Words | Errors | Self-Corrections | SC Ratio
                let statsY = y
                let statColWidth = (contentWidth - inset * 2 - 30) / 4
                let miniStats: [(String, String)] = [
                    ("\(record.totalWords)", "Words"),
                    ("\(record.errors)", "Errors"),
                    ("\(record.selfCorrections)", "Self-Corr."),
                    (record.selfCorrectionRatio, "SC Ratio")
                ]

                for (i, stat) in miniStats.enumerated() {
                    let statX = margin + inset + CGFloat(i) * (statColWidth + 10)
                    let valAttrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.boldSystemFont(ofSize: 13),
                        .foregroundColor: UIColor.black
                    ]
                    let lblAttrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 8),
                        .foregroundColor: UIColor.gray
                    ]
                    stat.0.draw(at: CGPoint(x: statX, y: statsY), withAttributes: valAttrs)
                    stat.1.draw(at: CGPoint(x: statX, y: statsY + 16), withAttributes: lblAttrs)
                }

                y = statsY + 34

                // Accuracy & Diagnosis
                let accText = String(format: "%.1f%% Accuracy", record.accuracy)
                let accColor = levelUIColor(record.readingLevel)
                drawLeft(accText, fontSize: 16, bold: true, color: accColor, indent: inset)

                // Diagnosis text
                let diagnosisText = levelDiagnosis(record.readingLevel)
                _ = drawWrapped(diagnosisText, fontSize: 10, color: .darkGray, indent: inset)

                // Notes (if any)
                if !record.notes.isEmpty {
                    let sanitizedNotes = SecurityHelpers.sanitizeNotes(record.notes)
                    y += 2
                    _ = drawWrapped("Notes: \(sanitizedNotes)", fontSize: 9, color: .gray, indent: inset)
                }

                y = cardY + cardHeight + 4
            }
        }

        SecureLogger.debug("Running Records PDF generated")
        return url
    }

    // MARK: - Helpers

    private static func drawFooter(context: UIGraphicsPDFRendererContext, page: Int, pageWidth: CGFloat, pageHeight: CGFloat) {
        let footer = "Running Records Report  •  Page \(page)  •  Generated by Teacher Assistant"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 8),
            .foregroundColor: UIColor.gray
        ]
        let size = footer.size(withAttributes: attrs)
        footer.draw(
            at: CGPoint(x: (pageWidth - size.width) / 2, y: pageHeight - 28),
            withAttributes: attrs
        )
    }

    private static func levelShortName(_ level: ReadingLevel) -> String {
        switch level {
        case .independent: return "Independent"
        case .instructional: return "Instructional"
        case .frustration: return "Frustration"
        }
    }
}

#else

// ====================================
// MARK: - macOS IMPLEMENTATION
// ====================================

import AppKit

enum RunningRecordPDFExporter {

    static func export(
        student: Student,
        schoolName: String,
        runningRecords: [RunningRecord],
        appliedFilters: String? = nil
    ) -> URL {

        let sorted = runningRecords.sorted { $0.date > $1.date }
        let attributedString = createFormattedReport(
            student: student,
            schoolName: schoolName,
            records: sorted,
            appliedFilters: appliedFilters
        )

        let safeFilename = SecurityHelpers.generateSecureFilename(
            baseName: "RunningRecords",
            extension: "pdf"
        )
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(safeFilename)

        let pageWidth: CGFloat = 595.2 - 100
        let pageHeight: CGFloat = 841.8 - 100

        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        textView.textStorage?.setAttributedString(attributedString)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)

        let usedRect = textView.layoutManager!.usedRect(for: textView.textContainer!)
        textView.frame = NSRect(x: 0, y: 0, width: pageWidth, height: max(usedRect.height, pageHeight))

        let pdfData = textView.dataWithPDF(inside: NSRect(x: 0, y: 0, width: pageWidth, height: textView.frame.height))

        do {
            try pdfData.write(to: url, options: [.atomic])
            SecureLogger.debug("Running Records PDF saved (\(pdfData.count) bytes)")
        } catch {
            SecureLogger.error("Error saving Running Records PDF", error: error)
        }

        return url
    }

    // MARK: - Formatted NSAttributedString

    private static func createFormattedReport(
        student: Student,
        schoolName: String,
        records: [RunningRecord],
        appliedFilters: String?
    ) -> NSAttributedString {
        let attributedString = NSMutableAttributedString()

        let titleParagraph = NSMutableParagraphStyle()
        titleParagraph.alignment = .center
        titleParagraph.paragraphSpacing = 10

        let sectionParagraph = NSMutableParagraphStyle()
        sectionParagraph.paragraphSpacing = 8
        sectionParagraph.paragraphSpacingBefore = 12

        let bodyParagraph = NSMutableParagraphStyle()
        bodyParagraph.paragraphSpacing = 3
        bodyParagraph.lineSpacing = 2

        let footerParagraph = NSMutableParagraphStyle()
        footerParagraph.alignment = .center
        footerParagraph.paragraphSpacing = 2

        let separatorLine = String(repeating: "_", count: 82)

        let schoolFont = NSFontManager.shared.convert(
            NSFont.systemFont(ofSize: 22, weight: .bold),
            toHaveTrait: .italicFontMask
        )

        func append(_ text: String, attributes: [NSAttributedString.Key: Any]) {
            attributedString.append(NSAttributedString(string: text, attributes: attributes))
        }

        // Header
        append("Running Records Report\n", attributes: [
            .font: NSFont.systemFont(ofSize: 44, weight: .bold),
            .foregroundColor: NSColor.black,
            .paragraphStyle: titleParagraph
        ])

        if !schoolName.trimmingCharacters(in: .whitespaces).isEmpty {
            append("\(schoolName.uppercased())\n", attributes: [
                .font: schoolFont,
                .foregroundColor: NSColor(calibratedRed: 0.62, green: 0.18, blue: 0.25, alpha: 1.0),
                .paragraphStyle: titleParagraph
            ])
        }

        append(separatorLine + "\n\n", attributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .bold),
            .foregroundColor: NSColor.black,
            .paragraphStyle: bodyParagraph
        ])

        // Student info
        append("Student Information:\n", attributes: [
            .font: NSFont.systemFont(ofSize: 36, weight: .bold),
            .foregroundColor: NSColor.black,
            .paragraphStyle: sectionParagraph
        ])
        append("Student name: \(SecurityHelpers.sanitizeNotes(student.name))\n", attributes: [
            .font: NSFont.systemFont(ofSize: 19),
            .foregroundColor: NSColor.black,
            .paragraphStyle: bodyParagraph
        ])
        if let schoolClass = student.schoolClass {
            append("Class: \(schoolClass.name)\n", attributes: [
                .font: NSFont.systemFont(ofSize: 19),
                .foregroundColor: NSColor.black,
                .paragraphStyle: bodyParagraph
            ])
            append("Grade: \(schoolClass.grade)\n", attributes: [
                .font: NSFont.systemFont(ofSize: 19),
                .foregroundColor: NSColor.black,
                .paragraphStyle: bodyParagraph
            ])
        }
        append("Report Date: \(Date().appDateString(systemStyle: .long))\n\n", attributes: [
            .font: NSFont.systemFont(ofSize: 19),
            .foregroundColor: NSColor.black,
            .paragraphStyle: bodyParagraph
        ])

        if let appliedFilters, !appliedFilters.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            append("Filters: \(appliedFilters)\n\n", attributes: [
                .font: NSFont.systemFont(ofSize: 15),
                .foregroundColor: NSColor.darkGray,
                .paragraphStyle: bodyParagraph
            ])
        }
        append(separatorLine + "\n\n", attributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .bold),
            .foregroundColor: NSColor.black,
            .paragraphStyle: bodyParagraph
        ])

        // Summary
        append("Summary:\n", attributes: [
            .font: NSFont.systemFont(ofSize: 36, weight: .bold),
            .foregroundColor: NSColor.black,
            .paragraphStyle: sectionParagraph
        ])

        if records.isEmpty {
            append("No running records available for this student.\n\n", attributes: [
                .font: NSFont.systemFont(ofSize: 18),
                .foregroundColor: NSColor.darkGray,
                .paragraphStyle: bodyParagraph
            ])
        } else {
            let avg = records.reduce(0.0) { $0 + $1.accuracy } / Double(records.count)
            let latest = records.first!
            append("Total Records: \(records.count)\n", attributes: [
                .font: NSFont.systemFont(ofSize: 19),
                .foregroundColor: NSColor.black,
                .paragraphStyle: bodyParagraph
            ])
            append("Average Accuracy: \(String(format: "%.1f%%", avg))\n", attributes: [
                .font: NSFont.systemFont(ofSize: 19),
                .foregroundColor: NSColor.black,
                .paragraphStyle: bodyParagraph
            ])
            append("Current Reading Level: \(levelName(latest.readingLevel))\n\n", attributes: [
                .font: NSFont.systemFont(ofSize: 19),
                .foregroundColor: NSColor.black,
                .paragraphStyle: bodyParagraph
            ])
        }

        append(separatorLine + "\n\n", attributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .bold),
            .foregroundColor: NSColor.black,
            .paragraphStyle: bodyParagraph
        ])

        // Assessment history
        append("Assessment History:\n", attributes: [
            .font: NSFont.systemFont(ofSize: 36, weight: .bold),
            .foregroundColor: NSColor.black,
            .paragraphStyle: sectionParagraph
        ])

        for (index, record) in records.enumerated() {
            append("Record #\(index + 1) - \(record.date.appDateString(systemStyle: .medium))\n", attributes: [
                .font: NSFont.systemFont(ofSize: 26, weight: .bold),
                .foregroundColor: NSColor.systemBlue,
                .paragraphStyle: sectionParagraph
            ])
            append("Book/Text: \(SecurityHelpers.sanitizeNotes(record.textTitle))\n", attributes: [
                .font: NSFont.systemFont(ofSize: 18),
                .foregroundColor: NSColor.black,
                .paragraphStyle: bodyParagraph
            ])
            append("Total words: \(record.totalWords)  Errors: \(record.errors)  Self-corrections: \(record.selfCorrections)\n", attributes: [
                .font: NSFont.systemFont(ofSize: 18),
                .foregroundColor: NSColor.black,
                .paragraphStyle: bodyParagraph
            ])
            append("SC Ratio: \(record.selfCorrectionRatio)\n\n", attributes: [
                .font: NSFont.systemFont(ofSize: 18),
                .foregroundColor: NSColor.black,
                .paragraphStyle: bodyParagraph
            ])
            append("Accuracy: \(String(format: "%.1f%%", record.accuracy))\n", attributes: [
                .font: NSFont.systemFont(ofSize: 23, weight: .bold),
                .foregroundColor: NSColor.black,
                .paragraphStyle: bodyParagraph
            ])
            append("Reading level: \(levelName(record.readingLevel))\n", attributes: [
                .font: NSFont.systemFont(ofSize: 18),
                .foregroundColor: NSColor.black,
                .paragraphStyle: bodyParagraph
            ])
            append("Diagnosis: \(levelDiagnosis(record.readingLevel))\n", attributes: [
                .font: NSFont.systemFont(ofSize: 18),
                .foregroundColor: NSColor.black,
                .paragraphStyle: bodyParagraph
            ])

            if !record.notes.isEmpty {
                append("Notes: \(SecurityHelpers.sanitizeNotes(record.notes))\n", attributes: [
                    .font: NSFont.systemFont(ofSize: 17),
                    .foregroundColor: NSColor.darkGray,
                    .paragraphStyle: bodyParagraph
                ])
            }
            append("\n", attributes: [
                .font: NSFont.systemFont(ofSize: 10),
                .paragraphStyle: bodyParagraph
            ])
        }

        append(separatorLine + "\n\n", attributes: [
            .font: NSFont.systemFont(ofSize: 12, weight: .bold),
            .foregroundColor: NSColor.black,
            .paragraphStyle: bodyParagraph
        ])

        // Reading guide
        append("Reading Level Guide:\n", attributes: [
            .font: NSFont.systemFont(ofSize: 36, weight: .bold),
            .foregroundColor: NSColor.black,
            .paragraphStyle: sectionParagraph
        ])
        append("- Independent (95-100%) - Reads with ease, strong comprehension\n", attributes: [
            .font: NSFont.systemFont(ofSize: 18),
            .foregroundColor: NSColor.black,
            .paragraphStyle: bodyParagraph
        ])
        append("- Instructional (90-94%) - Reads with some support needed\n", attributes: [
            .font: NSFont.systemFont(ofSize: 18),
            .foregroundColor: NSColor.black,
            .paragraphStyle: bodyParagraph
        ])
        append("- Frustration (below 90%) - Shows difficulty, needs easier text\n\n", attributes: [
            .font: NSFont.systemFont(ofSize: 18),
            .foregroundColor: NSColor.black,
            .paragraphStyle: bodyParagraph
        ])

        append("Generated by Teacher Assistant\n", attributes: [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: NSColor.gray,
            .paragraphStyle: footerParagraph
        ])

        return attributedString
    }

    // MARK: - Helpers

    private static func levelName(_ level: ReadingLevel) -> String {
        switch level {
        case .independent: return "Independent (95-100%)"
        case .instructional: return "Instructional (90-94%)"
        case .frustration: return "Frustration (below 90%)"
        }
    }

    private static func levelDiagnosis(_ level: ReadingLevel) -> String {
        switch level {
        case .independent:
            return "The student reads this text with ease and strong comprehension. Ready for more challenging material."
        case .instructional:
            return "The student can read this text with some support. Ideal level for guided reading instruction."
        case .frustration:
            return "The student struggles significantly with this text. Consider easier material to build confidence and fluency."
        }
    }
}

#endif
