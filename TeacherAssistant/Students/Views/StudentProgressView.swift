import SwiftUI
import SwiftData
import Charts
import UniformTypeIdentifiers

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct StudentProgressView: View {
    
    let student: Student
    @EnvironmentObject var languageManager: LanguageManager
    
    @Query private var allResults: [StudentResult]
    @Query private var allAttendanceSessions: [AttendanceSession]
    @Query private var allDevelopmentScores: [DevelopmentScore]
    
    @State private var exportURL: URL?
    @State private var schoolName: String = ""
    @State private var showConfirmation = false
    @State private var selectedTab: ProgressTab = .overview
    
    enum ProgressTab: String, CaseIterable {
        case overview = "Overview"
        case academics = "Academics"
        case attendance = "Attendance"
        case runningRecords = "Reading"
        case development = "Development"
        
        var icon: String {
            switch self {
            case .overview: return "chart.bar.fill"
            case .academics: return "graduationcap.fill"
            case .attendance: return "calendar"
            case .runningRecords: return "book.fill"
            case .development: return "star.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .overview: return .blue
            case .academics: return .purple
            case .attendance: return .green
            case .runningRecords: return .orange
            case .development: return .pink
            }
        }
        
        var localizedName: String {
            switch self {
            case .overview: return "Overview".localized
            case .academics: return "Academics".localized
            case .attendance: return "Attendance".localized
            case .runningRecords: return "Reading".localized
            case .development: return "Development".localized
            }
        }
    }
    // MARK: - Data Filters
    
    var resultsForStudent: [StudentResult] {
        allResults.filter { $0.student?.id == student.id }
    }
    
    var attendanceRecordsForStudent: [AttendanceRecord] {
        allAttendanceSessions.flatMap { session in
            session.records.filter { $0.student.id == student.id }
        }
    }
    
    // MARK: - Attendance Stats
    
    var totalSessions: Int {
        attendanceRecordsForStudent.count
    }
    
    var presentCount: Int {
        attendanceRecordsForStudent.filter { $0.status == .present }.count
    }
    
    var absentCount: Int {
        attendanceRecordsForStudent.filter { $0.status == .absent }.count
    }
    
    var earlyCount: Int {
        attendanceRecordsForStudent.filter { $0.status == .late }.count
    }
    
    var attendancePercentage: Double {
        guard totalSessions > 0 else { return 0 }
        return (Double(presentCount) / Double(totalSessions)) * 100.0
    }
    
    // MARK: - Subjects
    
    var subjectsForStudent: [Subject] {
        let subjects = resultsForStudent.compactMap { $0.assessment?.unit?.subject }
        
        var unique: [Subject] = []
        for subject in subjects {
            if !unique.contains(where: { $0.id == subject.id }) {
                unique.append(subject)
            }
        }
        return unique.sorted { $0.name < $1.name }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Hero Header
            heroHeader
            
            // MARK: - Tab Picker
            tabPicker
            
            // MARK: - Content
            ScrollView {
                VStack(spacing: 24) {
                    switch selectedTab {
                    case .overview:
                        overviewTab
                    case .academics:
                        academicsTab
                    case .attendance:
                        attendanceTab
                    case .runningRecords:
                        runningRecordsTab
                    case .development:
                        developmentTab
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Detailed Progress".localized)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        exportToPDF()
                    } label: {
                        Label("Export Full Report".localized, systemImage: "doc.fill")
                    }
                    
                    Button {
                        exportCurrentTabToPDF()
                    } label: {
                        Label(String(format: "Export %@ Only".localized, selectedTab.localizedName), systemImage: "doc.text.fill")
                    }
                } label: {
                    Label("Export".localized, systemImage: "square.and.arrow.up")
                }
            }
        }

        #if os(iOS)
        .sheet(
            isPresented: Binding(
                get: { exportURL != nil },
                set: { newValue in
                    if !newValue {
                        exportURL = nil
                    }
                }
            )
        ) {
            if let url = exportURL {
                ShareSheet(activityItems: [url])
            }
        }
        #endif
        .alert("Export Complete".localized, isPresented: $showConfirmation) {
            Button("OK".localized) { }
        } message: {
            Text("Student progress report has been generated successfully!".localized)
        }
    }
    
    // MARK: - PDF Export Functions
    
    func exportToPDF() {
        #if os(iOS)
        let pdfURL = generateComprehensivePDF()
        exportURL = pdfURL
        #elseif os(macOS)
        // Use the new simple PDF exporter that actually works!
        let pdfURL = SimplePDFExporter.exportStudentReport(
            student: student,
            schoolName: schoolName,
            allResults: allResults,
            allAttendanceSessions: allAttendanceSessions,
            allDevelopmentScores: allDevelopmentScores
        )
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.nameFieldStringValue = "\(student.name) - Progress Report.pdf"
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? FileManager.default.copyItem(at: pdfURL, to: url)
                showConfirmation = true
            }
        }
        #endif
    }
    func exportCurrentTabToPDF() {
        #if os(iOS)
        let pdfURL = generateTabPDF(for: selectedTab)
        exportURL = pdfURL
        #elseif os(macOS)
        // Use the simple exporter (same as full report for now)
        let pdfURL = SimplePDFExporter.exportStudentReport(
            student: student,
            schoolName: schoolName,
            allResults: allResults,
            allAttendanceSessions: allAttendanceSessions,
            allDevelopmentScores: allDevelopmentScores
        )
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.pdf]
        savePanel.nameFieldStringValue = "\(student.name) - \(selectedTab.localizedName).pdf"
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                try? FileManager.default.copyItem(at: pdfURL, to: url)
                showConfirmation = true
            }
        }
        #endif
    }
    
    #if os(iOS)
    func generateComprehensivePDF() -> URL {
        let pdfMetaData = [
            kCGPDFContextCreator: "Student Progress Tracker",
            kCGPDFContextAuthor: schoolName.isEmpty ? "Teacher" : schoolName,
            kCGPDFContextTitle: "\(student.name) - Comprehensive Progress Report"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageWidth = 8.5 * 72.0
        let pageHeight = 11.0 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let data = renderer.pdfData { (context) in
            // Page 1: Overview
            context.beginPage()
            var currentY: CGFloat = 50
            
            // Title
            let titleFont = UIFont.boldSystemFont(ofSize: 28)
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.systemBlue
            ]
            "Student Progress Report".draw(at: CGPoint(x: 50, y: currentY), withAttributes: titleAttributes)
            currentY += 40
            
            // Line
            context.cgContext.setStrokeColor(UIColor.systemGray3.cgColor)
            context.cgContext.setLineWidth(1)
            context.cgContext.move(to: CGPoint(x: 50, y: currentY))
            context.cgContext.addLine(to: CGPoint(x: pageRect.width - 50, y: currentY))
            context.cgContext.strokePath()
            currentY += 30
            
            // Student Info
            let nameFont = UIFont.boldSystemFont(ofSize: 20)
            let infoFont = UIFont.systemFont(ofSize: 14)
            let nameAttrs: [NSAttributedString.Key: Any] = [.font: nameFont, .foregroundColor: UIColor.black]
            let infoAttrs: [NSAttributedString.Key: Any] = [.font: infoFont, .foregroundColor: UIColor.gray]
            
            student.name.draw(at: CGPoint(x: 50, y: currentY), withAttributes: nameAttrs)
            currentY += 30
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .long
            "Generated: \(dateFormatter.string(from: Date()))".draw(at: CGPoint(x: 50, y: currentY), withAttributes: infoAttrs)
            currentY += 25
            
            if !schoolName.isEmpty {
                schoolName.draw(at: CGPoint(x: 50, y: currentY), withAttributes: infoAttrs)
                currentY += 25
            }
            
            currentY += 20
            
            // Summary Section
            let sectionFont = UIFont.boldSystemFont(ofSize: 18)
            let bodyFont = UIFont.systemFont(ofSize: 14)
            let sectionAttrs: [NSAttributedString.Key: Any] = [.font: sectionFont, .foregroundColor: UIColor.black]
            let bodyAttrs: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: UIColor.black]
            
            "Summary".draw(at: CGPoint(x: 50, y: currentY), withAttributes: sectionAttrs)
            currentY += 30
            
            let stats = [
                "Academic Average: \(String(format: "%.1f", self.resultsForStudent.averageScore))",
                "Total Assessments: \(self.resultsForStudent.count)",
                "Attendance Rate: \(String(format: "%.0f%%", self.attendancePercentage))",
                "Running Records: \(self.student.runningRecords.count)",
                "Development Areas: \(self.studentDevelopmentScores.count)"
            ]
            
            for stat in stats {
                stat.draw(at: CGPoint(x: 70, y: currentY), withAttributes: bodyAttrs)
                currentY += 22
            }
            
            currentY += 20
            
            // Subject Performance
            if !self.subjectsForStudent.isEmpty {
                "Subject Performance".draw(at: CGPoint(x: 50, y: currentY), withAttributes: sectionAttrs)
                currentY += 30
                
                for subject in self.subjectsForStudent.prefix(8) {
                    let subjectResults = self.resultsForStudent.filter {
                        $0.assessment?.unit?.subject?.id == subject.id
                    }
                    let average = subjectResults.averageScore
                    
                    let subjectText = "\(subject.name): \(String(format: "%.1f", average))"
                    subjectText.draw(at: CGPoint(x: 70, y: currentY), withAttributes: bodyAttrs)
                    
                    let countText = "(\(subjectResults.count) assessments)"
                    let countAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 12), .foregroundColor: UIColor.gray]
                    countText.draw(at: CGPoint(x: 350, y: currentY + 2), withAttributes: countAttrs)
                    
                    currentY += 22
                    
                    if currentY > pageRect.height - 100 { break }
                }
            }
            
            // Footer
            let footerFont = UIFont.systemFont(ofSize: 10)
            let footerAttrs: [NSAttributedString.Key: Any] = [.font: footerFont, .foregroundColor: UIColor.gray]
            let footerText = "Generated on \(dateFormatter.string(from: Date())) • Student Progress Tracker"
            let footerSize = (footerText as NSString).size(withAttributes: footerAttrs)
            footerText.draw(at: CGPoint(x: (pageRect.width - footerSize.width) / 2, y: pageRect.height - 40), withAttributes: footerAttrs)
            
            // Page 2: Academics
            if !self.subjectsForStudent.isEmpty {
                context.beginPage()
                currentY = 50
                
                "Academic Performance".draw(at: CGPoint(x: 50, y: currentY), withAttributes: titleAttributes)
                currentY += 40
                
                context.cgContext.setStrokeColor(UIColor.systemGray3.cgColor)
                context.cgContext.setLineWidth(1)
                context.cgContext.move(to: CGPoint(x: 50, y: currentY))
                context.cgContext.addLine(to: CGPoint(x: pageRect.width - 50, y: currentY))
                context.cgContext.strokePath()
                currentY += 30
                
                let overallText = "Overall Average: \(String(format: "%.1f", self.resultsForStudent.averageScore)) (\(self.resultsForStudent.count) assessments)"
                overallText.draw(at: CGPoint(x: 50, y: currentY), withAttributes: bodyAttrs)
                currentY += 40
                
                for subject in self.subjectsForStudent {
                    let subjectResults = self.resultsForStudent.filter {
                        $0.assessment?.unit?.subject?.id == subject.id
                    }
                    let average = subjectResults.averageScore
                    
                    subject.name.draw(at: CGPoint(x: 50, y: currentY), withAttributes: sectionAttrs)
                    
                    let avgText = "\(String(format: "%.1f", average))"
                    let avgFont = UIFont.boldSystemFont(ofSize: 24)
                    let avgAttrs: [NSAttributedString.Key: Any] = [.font: avgFont, .foregroundColor: UIColor.systemBlue]
                    avgText.draw(at: CGPoint(x: pageRect.width - 100, y: currentY - 5), withAttributes: avgAttrs)
                    
                    currentY += 25
                    
                    "Average: \(String(format: "%.1f", average)) • \(subjectResults.count) assessments".draw(at: CGPoint(x: 70, y: currentY), withAttributes: bodyAttrs)
                    currentY += 30
                    
                    if currentY > pageRect.height - 150 {
                        context.beginPage()
                        currentY = 50
                        "Academic Performance (continued)".draw(at: CGPoint(x: 50, y: currentY), withAttributes: titleAttributes)
                        currentY += 60
                    }
                }
                
                footerText.draw(at: CGPoint(x: (pageRect.width - footerSize.width) / 2, y: pageRect.height - 40), withAttributes: footerAttrs)
            }
            
            // Page 3: Attendance
            if self.totalSessions > 0 {
                context.beginPage()
                currentY = 50
                
                "Attendance Report".draw(at: CGPoint(x: 50, y: currentY), withAttributes: titleAttributes)
                currentY += 40
                
                context.cgContext.setStrokeColor(UIColor.systemGray3.cgColor)
                context.cgContext.setLineWidth(1)
                context.cgContext.move(to: CGPoint(x: 50, y: currentY))
                context.cgContext.addLine(to: CGPoint(x: pageRect.width - 50, y: currentY))
                context.cgContext.strokePath()
                currentY += 30
                
                "Attendance Summary".draw(at: CGPoint(x: 50, y: currentY), withAttributes: sectionAttrs)
                currentY += 30
                
                let attendanceStats = [
                    "Total Sessions: \(self.totalSessions)",
                    "Present: \(self.presentCount) (\(self.totalSessions > 0 ? Int((Double(self.presentCount) / Double(self.totalSessions)) * 100) : 0)%)",
                    "Absent: \(self.absentCount) (\(self.totalSessions > 0 ? Int((Double(self.absentCount) / Double(self.totalSessions)) * 100) : 0)%)",
                    "Late: \(self.earlyCount) (\(self.totalSessions > 0 ? Int((Double(self.earlyCount) / Double(self.totalSessions)) * 100) : 0)%)",
                    "",
                    "Overall Attendance Rate: \(String(format: "%.1f%%", self.attendancePercentage))"
                ]
                
                for stat in attendanceStats {
                    stat.draw(at: CGPoint(x: 70, y: currentY), withAttributes: bodyAttrs)
                    currentY += 22
                }
                
                footerText.draw(at: CGPoint(x: (pageRect.width - footerSize.width) / 2, y: pageRect.height - 40), withAttributes: footerAttrs)
            }
            
            // Page 4: Running Records
            if !self.student.runningRecords.isEmpty {
                context.beginPage()
                currentY = 50
                
                "Reading Records".draw(at: CGPoint(x: 50, y: currentY), withAttributes: titleAttributes)
                currentY += 40
                
                context.cgContext.setStrokeColor(UIColor.systemGray3.cgColor)
                context.cgContext.setLineWidth(1)
                context.cgContext.move(to: CGPoint(x: 50, y: currentY))
                context.cgContext.addLine(to: CGPoint(x: pageRect.width - 50, y: currentY))
                context.cgContext.strokePath()
                currentY += 30
                
                let summary = "Total Records: \(self.student.runningRecords.count) • Average Accuracy: \(String(format: "%.1f%%", self.averageAccuracy))"
                summary.draw(at: CGPoint(x: 50, y: currentY), withAttributes: bodyAttrs)
                currentY += 40
                
                let sortedRecords = self.student.runningRecords.sorted { $0.date > $1.date }
                
                for record in sortedRecords.prefix(20) {
                    record.textTitle.draw(at: CGPoint(x: 50, y: currentY), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 14), .foregroundColor: UIColor.black])
                    currentY += 20
                    
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateStyle = .short
                    let details = "\(dateFormatter.string(from: record.date)) • \(String(format: "%.1f%%", record.accuracy)) • \(self.readingLevelName(record.readingLevel))"
                    let captionAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 12), .foregroundColor: UIColor.gray]
                    details.draw(at: CGPoint(x: 70, y: currentY), withAttributes: captionAttrs)
                    currentY += 30
                    
                    if currentY > pageRect.height - 150 {
                        context.beginPage()
                        currentY = 50
                        "Reading Records (continued)".draw(at: CGPoint(x: 50, y: currentY), withAttributes: titleAttributes)
                        currentY += 60
                    }
                }
                
                footerText.draw(at: CGPoint(x: (pageRect.width - footerSize.width) / 2, y: pageRect.height - 40), withAttributes: footerAttrs)
            }
            
            // Page 5: Development
            if !self.studentDevelopmentScores.isEmpty {
                context.beginPage()
                currentY = 50
                
                "Development Tracking".localized.draw(at: CGPoint(x: 50, y: currentY), withAttributes: titleAttributes)
                currentY += 40
                
                context.cgContext.setStrokeColor(UIColor.systemGray3.cgColor)
                context.cgContext.setLineWidth(1)
                context.cgContext.move(to: CGPoint(x: 50, y: currentY))
                context.cgContext.addLine(to: CGPoint(x: pageRect.width - 50, y: currentY))
                context.cgContext.strokePath()
                currentY += 30
                
                let grouped = self.groupedDevelopmentScores()
                
                for group in grouped {
                    displayRubricText(group.category).draw(at: CGPoint(x: 50, y: currentY), withAttributes: sectionAttrs)
                    currentY += 25
                    
                    for score in group.scores {
                        let criterionName = displayRubricText(score.criterion?.name ?? "Unknown")
                        let stars = String(repeating: "★", count: score.rating) + String(repeating: "☆", count: 5 - score.rating)
                        
                        criterionName.draw(at: CGPoint(x: 70, y: currentY), withAttributes: bodyAttrs)
                        currentY += 20
                        
                        "\(stars) - \(score.ratingLabel)".draw(at: CGPoint(x: 90, y: currentY), withAttributes: [.font: UIFont.systemFont(ofSize: 12), .foregroundColor: UIColor.gray])
                        currentY += 25
                        
                        if currentY > pageRect.height - 150 {
                            context.beginPage()
                            currentY = 50
                            "Development Tracking (continued)".localized.draw(at: CGPoint(x: 50, y: currentY), withAttributes: titleAttributes)
                            currentY += 60
                        }
                    }
                    
                    currentY += 15
                }
                
                footerText.draw(at: CGPoint(x: (pageRect.width - footerSize.width) / 2, y: pageRect.height - 40), withAttributes: footerAttrs)
            }
        }
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(student.name)_ProgressReport_\(Date().timeIntervalSince1970).pdf")
        
        try? data.write(to: tempURL)
        return tempURL
    }
    
    func generateTabPDF(for tab: ProgressTab) -> URL {
        let pdfMetaData = [
            kCGPDFContextCreator: "Student Progress Tracker",
            kCGPDFContextAuthor: schoolName.isEmpty ? "Teacher" : schoolName,
            kCGPDFContextTitle: "\(student.name) - \(tab.rawValue)"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageWidth = 8.5 * 72.0
        let pageHeight = 11.0 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let data = renderer.pdfData { (context) in
            context.beginPage()
            var currentY: CGFloat = 50
            
            // Title
            let titleFont = UIFont.boldSystemFont(ofSize: 28)
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.systemBlue
            ]
            tab.rawValue.draw(at: CGPoint(x: 50, y: currentY), withAttributes: titleAttributes)
            currentY += 40
            
            // Line
            context.cgContext.setStrokeColor(UIColor.systemGray3.cgColor)
            context.cgContext.setLineWidth(1)
            context.cgContext.move(to: CGPoint(x: 50, y: currentY))
            context.cgContext.addLine(to: CGPoint(x: pageRect.width - 50, y: currentY))
            context.cgContext.strokePath()
            currentY += 30
            
            // Student name
            let nameFont = UIFont.boldSystemFont(ofSize: 18)
            let nameAttrs: [NSAttributedString.Key: Any] = [.font: nameFont, .foregroundColor: UIColor.black]
            student.name.draw(at: CGPoint(x: 50, y: currentY), withAttributes: nameAttrs)
            currentY += 40
            
            // Content based on tab
            let bodyFont = UIFont.systemFont(ofSize: 14)
            let bodyAttrs: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: UIColor.black]
            
            switch tab {
            case .overview:
                "Summary Statistics".draw(at: CGPoint(x: 50, y: currentY), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 16), .foregroundColor: UIColor.black])
                currentY += 30
                
                let stats = [
                    "Academic Average: \(String(format: "%.1f", resultsForStudent.averageScore))",
                    "Total Assessments: \(resultsForStudent.count)",
                    "Attendance Rate: \(String(format: "%.0f%%", attendancePercentage))",
                    "Running Records: \(student.runningRecords.count)",
                    "Development Areas: \(studentDevelopmentScores.count)"
                ]
                
                for stat in stats {
                    stat.draw(at: CGPoint(x: 70, y: currentY), withAttributes: bodyAttrs)
                    currentY += 22
                }
                
            case .academics:
                let overallText = "Overall Average: \(String(format: "%.1f", resultsForStudent.averageScore))"
                overallText.draw(at: CGPoint(x: 50, y: currentY), withAttributes: bodyAttrs)
                currentY += 40
                
                for subject in subjectsForStudent {
                    let subjectResults = resultsForStudent.filter {
                        $0.assessment?.unit?.subject?.id == subject.id
                    }
                    let average = subjectResults.averageScore
                    
                    subject.name.draw(at: CGPoint(x: 50, y: currentY), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 16), .foregroundColor: UIColor.black])
                    currentY += 22
                    "Average: \(String(format: "%.1f", average)) • \(subjectResults.count) assessments".draw(at: CGPoint(x: 70, y: currentY), withAttributes: bodyAttrs)
                    currentY += 30
                }
                
            case .attendance:
                let attendanceStats = [
                    "Total Sessions: \(totalSessions)",
                    "Present: \(presentCount)",
                    "Absent: \(absentCount)",
                    "Late: \(earlyCount)",
                    "Attendance Rate: \(String(format: "%.1f%%", attendancePercentage))"
                ]
                
                for stat in attendanceStats {
                    stat.draw(at: CGPoint(x: 50, y: currentY), withAttributes: bodyAttrs)
                    currentY += 22
                }
                
            case .runningRecords:
                "Total Records: \(student.runningRecords.count)".draw(at: CGPoint(x: 50, y: currentY), withAttributes: bodyAttrs)
                currentY += 30
                
                for record in student.runningRecords.sorted(by: { $0.date > $1.date }).prefix(15) {
                    record.textTitle.draw(at: CGPoint(x: 50, y: currentY), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 14), .foregroundColor: UIColor.black])
                    currentY += 20
                    "\(String(format: "%.1f%%", record.accuracy)) - \(readingLevelName(record.readingLevel))".draw(at: CGPoint(x: 70, y: currentY), withAttributes: [.font: UIFont.systemFont(ofSize: 12), .foregroundColor: UIColor.gray])
                    currentY += 25
                }
                
            case .development:
                let grouped = groupedDevelopmentScores()
                for group in grouped {
                    displayRubricText(group.category).draw(at: CGPoint(x: 50, y: currentY), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 16), .foregroundColor: UIColor.black])
                    currentY += 25
                    
                    for score in group.scores {
                        let criterionName = displayRubricText(score.criterion?.name ?? "Unknown")
                        criterionName.draw(at: CGPoint(x: 70, y: currentY), withAttributes: bodyAttrs)
                        currentY += 20
                        let stars = String(repeating: "★", count: score.rating)
                        "\(stars) - \(score.ratingLabel)".draw(at: CGPoint(x: 90, y: currentY), withAttributes: [.font: UIFont.systemFont(ofSize: 12), .foregroundColor: UIColor.gray])
                        currentY += 25
                    }
                }
            }
            
            // Footer
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .long
            let footerText = "Generated on \(dateFormatter.string(from: Date())) • Student Progress Tracker"
            let footerFont = UIFont.systemFont(ofSize: 10)
            let footerAttrs: [NSAttributedString.Key: Any] = [.font: footerFont, .foregroundColor: UIColor.gray]
            let footerSize = (footerText as NSString).size(withAttributes: footerAttrs)
            footerText.draw(at: CGPoint(x: (pageRect.width - footerSize.width) / 2, y: pageRect.height - 40), withAttributes: footerAttrs)
        }
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(student.name)_\(tab.rawValue)_\(Date().timeIntervalSince1970).pdf")
        
        try? data.write(to: tempURL)
        return tempURL
    }
    
    // MARK: - PDF Drawing Functions
    
    func drawPDFHeader(context: UIGraphicsPDFRendererContext, pageRect: CGRect, title: String) {
        let titleFont = UIFont.boldSystemFont(ofSize: 24)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.systemBlue
        ]
        
        let titleString = title as NSString
        let titleRect = CGRect(x: 50, y: 50, width: pageRect.width - 100, height: 40)
        titleString.draw(in: titleRect, withAttributes: titleAttributes)
        
        // Horizontal line
        context.cgContext.setStrokeColor(UIColor.systemGray4.cgColor)
        context.cgContext.setLineWidth(2)
        context.cgContext.move(to: CGPoint(x: 50, y: 95))
        context.cgContext.addLine(to: CGPoint(x: pageRect.width - 50, y: 95))
        context.cgContext.strokePath()
    }
    
    func drawStudentInfo(context: UIGraphicsPDFRendererContext, pageRect: CGRect, yOffset: CGFloat) {
        let nameFont = UIFont.boldSystemFont(ofSize: 18)
        let infoFont = UIFont.systemFont(ofSize: 14)
        
        let nameAttributes: [NSAttributedString.Key: Any] = [.font: nameFont, .foregroundColor: UIColor.black]
        let infoAttributes: [NSAttributedString.Key: Any] = [.font: infoFont, .foregroundColor: UIColor.gray]
        
        (student.name as NSString).draw(at: CGPoint(x: 50, y: yOffset), withAttributes: nameAttributes)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        let dateString = "Generated: \(dateFormatter.string(from: Date()))"
        (dateString as NSString).draw(at: CGPoint(x: 50, y: yOffset + 25), withAttributes: infoAttributes)
        
        if !schoolName.isEmpty {
            (schoolName as NSString).draw(at: CGPoint(x: 50, y: yOffset + 45), withAttributes: infoAttributes)
        }
    }
    
    func drawOverviewSection(context: UIGraphicsPDFRendererContext, pageRect: CGRect, yOffset: CGFloat) {
        var currentY = yOffset
        let margin: CGFloat = 50
        
        // Summary Stats
        let sectionFont = UIFont.boldSystemFont(ofSize: 16)
        let bodyFont = UIFont.systemFont(ofSize: 14)
        
        ("Summary" as NSString).draw(
            at: CGPoint(x: margin, y: currentY),
            withAttributes: [.font: sectionFont, .foregroundColor: UIColor.black]
        )
        currentY += 30
        
        let stats = [
            "Academic Average: \(String(format: "%.1f", resultsForStudent.averageScore))",
            "Total Assessments: \(resultsForStudent.count)",
            "Attendance Rate: \(String(format: "%.0f%%", attendancePercentage))",
            "Running Records: \(student.runningRecords.count)",
            "Development Areas: \(studentDevelopmentScores.count)"
        ]
        
        for stat in stats {
            (stat as NSString).draw(
                at: CGPoint(x: margin + 20, y: currentY),
                withAttributes: [.font: bodyFont, .foregroundColor: UIColor.black]
            )
            currentY += 25
        }
        
        currentY += 20
        
        // Subject Performance
        if !subjectsForStudent.isEmpty {
            ("Subject Performance" as NSString).draw(
                at: CGPoint(x: margin, y: currentY),
                withAttributes: [.font: sectionFont, .foregroundColor: UIColor.black]
            )
            currentY += 30
            
            for subject in subjectsForStudent.prefix(10) {
                let subjectResults = resultsForStudent.filter {
                    $0.assessment?.unit?.subject?.id == subject.id
                }
                let average = subjectResults.averageScore
                
                let subjectText = "\(subject.name): \(String(format: "%.1f", average)) (\(subjectResults.count) assessments)"
                (subjectText as NSString).draw(
                    at: CGPoint(x: margin + 20, y: currentY),
                    withAttributes: [.font: bodyFont, .foregroundColor: UIColor.black]
                )
                currentY += 25
                
                if currentY > pageRect.height - 100 { break }
            }
        }
    }
    
    func drawAcademicsSection(context: UIGraphicsPDFRendererContext, pageRect: CGRect, yOffset: CGFloat) {
        var currentY = yOffset
        let margin: CGFloat = 50
        let sectionFont = UIFont.boldSystemFont(ofSize: 16)
        let bodyFont = UIFont.systemFont(ofSize: 14)
        let captionFont = UIFont.systemFont(ofSize: 12)
        
        ("Academic Performance" as NSString).draw(
            at: CGPoint(x: margin, y: currentY),
            withAttributes: [.font: sectionFont, .foregroundColor: UIColor.black]
        )
        currentY += 30
        
        let overallText = "Overall Average: \(String(format: "%.1f", resultsForStudent.averageScore)) (\(resultsForStudent.count) total assessments)"
        (overallText as NSString).draw(
            at: CGPoint(x: margin + 20, y: currentY),
            withAttributes: [.font: bodyFont, .foregroundColor: UIColor.black]
        )
        currentY += 40
        
        // Subject breakdown
        for subject in subjectsForStudent {
            let subjectResults = resultsForStudent.filter {
                $0.assessment?.unit?.subject?.id == subject.id
            }
            let average = subjectResults.averageScore
            
            (subject.name as NSString).draw(
                at: CGPoint(x: margin, y: currentY),
                withAttributes: [.font: UIFont.boldSystemFont(ofSize: 14), .foregroundColor: UIColor.black]
            )
            currentY += 20
            
            let avgText = "Average: \(String(format: "%.1f", average)) • \(subjectResults.count) assessments"
            (avgText as NSString).draw(
                at: CGPoint(x: margin + 20, y: currentY),
                withAttributes: [.font: captionFont, .foregroundColor: UIColor.gray]
            )
            currentY += 25
            
            if currentY > pageRect.height - 150 {
                context.beginPage()
                currentY = 50
                drawPDFHeader(context: context, pageRect: pageRect, title: "Academic Performance (cont.)")
                currentY = 120
            }
        }
    }
    
    func drawAttendanceSection(context: UIGraphicsPDFRendererContext, pageRect: CGRect, yOffset: CGFloat) {
        var currentY = yOffset
        let margin: CGFloat = 50
        let sectionFont = UIFont.boldSystemFont(ofSize: 16)
        let bodyFont = UIFont.systemFont(ofSize: 14)
        
        ("Attendance Summary" as NSString).draw(
            at: CGPoint(x: margin, y: currentY),
            withAttributes: [.font: sectionFont, .foregroundColor: UIColor.black]
        )
        currentY += 30
        
        let attendanceStats = [
            "Total Sessions: \(totalSessions)",
            "Present: \(presentCount) (\(totalSessions > 0 ? Int((Double(presentCount) / Double(totalSessions)) * 100) : 0)%)",
            "Absent: \(absentCount) (\(totalSessions > 0 ? Int((Double(absentCount) / Double(totalSessions)) * 100) : 0)%)",
            "Late: \(earlyCount) (\(totalSessions > 0 ? Int((Double(earlyCount) / Double(totalSessions)) * 100) : 0)%)",
            "",
            "Overall Attendance Rate: \(String(format: "%.1f%%", attendancePercentage))"
        ]
        
        for stat in attendanceStats {
            (stat as NSString).draw(
                at: CGPoint(x: margin + 20, y: currentY),
                withAttributes: [.font: bodyFont, .foregroundColor: UIColor.black]
            )
            currentY += 25
        }
    }
    
    func drawRunningRecordsSection(context: UIGraphicsPDFRendererContext, pageRect: CGRect, yOffset: CGFloat) {
        var currentY = yOffset
        let margin: CGFloat = 50
        let sectionFont = UIFont.boldSystemFont(ofSize: 16)
        let bodyFont = UIFont.systemFont(ofSize: 14)
        let captionFont = UIFont.systemFont(ofSize: 12)
        
        ("Running Records" as NSString).draw(
            at: CGPoint(x: margin, y: currentY),
            withAttributes: [.font: sectionFont, .foregroundColor: UIColor.black]
        )
        currentY += 30
        
        let summary = "Total Records: \(student.runningRecords.count) • Average Accuracy: \(String(format: "%.1f%%", averageAccuracy))"
        (summary as NSString).draw(
            at: CGPoint(x: margin + 20, y: currentY),
            withAttributes: [.font: bodyFont, .foregroundColor: UIColor.black]
        )
        currentY += 40
        
        let sortedRecords = student.runningRecords.sorted { $0.date > $1.date }
        
        for record in sortedRecords.prefix(15) {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            
            (record.textTitle as NSString).draw(
                at: CGPoint(x: margin, y: currentY),
                withAttributes: [.font: UIFont.boldSystemFont(ofSize: 14), .foregroundColor: UIColor.black]
            )
            currentY += 20
            
            let details = "\(dateFormatter.string(from: record.date)) • \(String(format: "%.1f%%", record.accuracy)) • \(readingLevelName(record.readingLevel))"
            (details as NSString).draw(
                at: CGPoint(x: margin + 20, y: currentY),
                withAttributes: [.font: captionFont, .foregroundColor: UIColor.gray]
            )
            currentY += 25
            
            if currentY > pageRect.height - 150 {
                context.beginPage()
                currentY = 50
                drawPDFHeader(context: context, pageRect: pageRect, title: "Running Records (cont.)")
                currentY = 120
            }
        }
    }
    
    func drawDevelopmentSection(context: UIGraphicsPDFRendererContext, pageRect: CGRect, yOffset: CGFloat) {
        var currentY = yOffset
        let margin: CGFloat = 50
        let sectionFont = UIFont.boldSystemFont(ofSize: 16)
        let bodyFont = UIFont.systemFont(ofSize: 14)
        let captionFont = UIFont.systemFont(ofSize: 12)
        
        ("Development Tracking".localized as NSString).draw(
            at: CGPoint(x: margin, y: currentY),
            withAttributes: [.font: sectionFont, .foregroundColor: UIColor.black]
        )
        currentY += 30
        
        let grouped = groupedDevelopmentScores()
        
        for group in grouped {
            (displayRubricText(group.category) as NSString).draw(
                at: CGPoint(x: margin, y: currentY),
                withAttributes: [.font: UIFont.boldSystemFont(ofSize: 14), .foregroundColor: UIColor.systemPink]
            )
            currentY += 25
            
            for score in group.scores {
                let criterionName = displayRubricText(score.criterion?.name ?? "Unknown")
                let stars = String(repeating: "★", count: score.rating) + String(repeating: "☆", count: 5 - score.rating)
                
                (criterionName as NSString).draw(
                    at: CGPoint(x: margin + 20, y: currentY),
                    withAttributes: [.font: bodyFont, .foregroundColor: UIColor.black]
                )
                currentY += 20
                
                ("\(stars) - \(score.ratingLabel)" as NSString).draw(
                    at: CGPoint(x: margin + 40, y: currentY),
                    withAttributes: [.font: captionFont, .foregroundColor: UIColor.gray]
                )
                currentY += 25
                
                if currentY > pageRect.height - 150 {
                    context.beginPage()
                    currentY = 50
                    drawPDFHeader(context: context, pageRect: pageRect, title: "Development Tracking (cont.)".localized)
                    currentY = 120
                }
            }
            
            currentY += 10
        }
    }
    
    func drawPDFFooter(context: UIGraphicsPDFRendererContext, pageRect: CGRect) {
        let footerFont = UIFont.systemFont(ofSize: 10)
        let footerAttributes: [NSAttributedString.Key: Any] = [
            .font: footerFont,
            .foregroundColor: UIColor.gray
        ]
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        let footerText = "Generated on \(dateFormatter.string(from: Date())) • Student Progress Tracker"
        let footerSize = (footerText as NSString).size(withAttributes: footerAttributes)
        
        let footerRect = CGRect(
            x: (pageRect.width - footerSize.width) / 2,
            y: pageRect.height - 40,
            width: footerSize.width,
            height: footerSize.height
        )
        
        (footerText as NSString).draw(in: footerRect, withAttributes: footerAttributes)
    }
    #endif
    
    // MARK: - macOS PDF Generation
    #if os(macOS)
    func generateComprehensivePDFMac() -> URL {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(student.name)_ProgressReport_\(Date().timeIntervalSince1970).pdf")
        
        let pdfData = NSMutableData()
        
        let pageWidth: CGFloat = 612.0  // 8.5 inches
        let pageHeight: CGFloat = 792.0 // 11 inches
        var pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        guard let consumer = CGDataConsumer(data: pdfData) else {
            return tempURL
        }
        
        var mediaBox = pageRect
        guard let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return tempURL
        }
        
        // Page 1: Overview
        pdfContext.beginPDFPage(nil)
        drawPDFContentMac(pdfContext: pdfContext, pageRect: pageRect, title: "Student Progress Report", section: "overview")
        pdfContext.endPDFPage()
        
        // Page 2: Academic Performance
        if !subjectsForStudent.isEmpty {
            pdfContext.beginPDFPage(nil)
            drawPDFContentMac(pdfContext: pdfContext, pageRect: pageRect, title: "Academic Performance", section: "academics")
            pdfContext.endPDFPage()
        }
        
        // Page 3: Attendance
        if totalSessions > 0 {
            pdfContext.beginPDFPage(nil)
            drawPDFContentMac(pdfContext: pdfContext, pageRect: pageRect, title: "Attendance Report", section: "attendance")
            pdfContext.endPDFPage()
        }
        
        // Page 4: Running Records
        if !student.runningRecords.isEmpty {
            pdfContext.beginPDFPage(nil)
            drawPDFContentMac(pdfContext: pdfContext, pageRect: pageRect, title: "Reading Records", section: "reading")
            pdfContext.endPDFPage()
        }
        
        // Page 5: Development Tracking
        if !studentDevelopmentScores.isEmpty {
            pdfContext.beginPDFPage(nil)
            drawPDFContentMac(pdfContext: pdfContext, pageRect: pageRect, title: "Development Tracking", section: "development")
            pdfContext.endPDFPage()
        }
        
        pdfContext.closePDF()
        
        pdfData.write(to: tempURL, atomically: true)
        return tempURL
    }
    
    func drawPDFContentMac(pdfContext: CGContext, pageRect: CGRect, title: String, section: String) {
        // Flip coordinate system for text drawing
        pdfContext.saveGState()
        pdfContext.translateBy(x: 0, y: pageRect.height)
        pdfContext.scaleBy(x: 1, y: -1)
        
        var currentY: CGFloat = 50
        let margin: CGFloat = 50
        
        // Title
        let titleFont = NSFont.boldSystemFont(ofSize: 24)
        let titleAttrs: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: NSColor(red: 0.0, green: 0.478, blue: 1.0, alpha: 1.0)]
        title.draw(at: CGPoint(x: margin, y: currentY), withAttributes: titleAttrs as [NSAttributedString.Key : Any])
        currentY += 35
        
        // Restore for line drawing
        pdfContext.restoreGState()
        
        // Draw line in PDF coordinates (not flipped)
        pdfContext.setStrokeColor(NSColor.systemGray.cgColor)
        pdfContext.setLineWidth(1)
        pdfContext.move(to: CGPoint(x: margin, y: pageRect.height - currentY))
        pdfContext.addLine(to: CGPoint(x: pageRect.width - margin, y: pageRect.height - currentY))
        pdfContext.strokePath()
        
        // Flip again for more text
        pdfContext.saveGState()
        pdfContext.translateBy(x: 0, y: pageRect.height)
        pdfContext.scaleBy(x: 1, y: -1)
        
        currentY += 25
        
        // Student name
        let nameFont = NSFont.boldSystemFont(ofSize: 16)
        let bodyFont = NSFont.systemFont(ofSize: 14)
        let nameAttrs: [NSAttributedString.Key: Any] = [.font: nameFont, .foregroundColor: NSColor(calibratedWhite: 0.0, alpha: 1.0)]
        let bodyAttrs: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: NSColor(calibratedWhite: 0.0, alpha: 1.0)]
        
        student.name.draw(at: CGPoint(x: margin, y: currentY), withAttributes: nameAttrs as [NSAttributedString.Key : Any])
        currentY += 30
        
        // Content based on section
        switch section {
        case "overview":
            let stats = [
                "Academic Average: \(String(format: "%.1f", resultsForStudent.averageScore))",
                "Total Assessments: \(resultsForStudent.count)",
                "Attendance Rate: \(String(format: "%.0f%%", attendancePercentage))",
                "Running Records: \(student.runningRecords.count)",
                "Development Areas: \(studentDevelopmentScores.count)"
            ]
            
            for stat in stats {
                stat.draw(at: CGPoint(x: margin + 20, y: currentY), withAttributes: bodyAttrs as [NSAttributedString.Key : Any])
                currentY += 20
            }
            
        case "academics":
            "Overall Average: \(String(format: "%.1f", resultsForStudent.averageScore))".draw(at: CGPoint(x: margin, y: currentY), withAttributes: bodyAttrs as [NSAttributedString.Key : Any])
            currentY += 30
            
            for subject in subjectsForStudent.prefix(10) {
                let subjectResults = resultsForStudent.filter {
                    $0.assessment?.unit?.subject?.id == subject.id
                }
                let average = subjectResults.averageScore
                
                subject.name.draw(at: CGPoint(x: margin, y: currentY), withAttributes: nameAttrs as [NSAttributedString.Key : Any])
                currentY += 20
                "Average: \(String(format: "%.1f", average)) • \(subjectResults.count) assessments".draw(at: CGPoint(x: margin + 20, y: currentY), withAttributes: bodyAttrs as [NSAttributedString.Key : Any])
                currentY += 25
                
                if currentY > pageRect.height - 100 { break }
            }
            
        case "attendance":
            let attendanceStats = [
                "Total Sessions: \(totalSessions)",
                "Present: \(presentCount) (\(totalSessions > 0 ? Int((Double(presentCount) / Double(totalSessions)) * 100) : 0)%)",
                "Absent: \(absentCount)",
                "Late: \(earlyCount)",
                "Attendance Rate: \(String(format: "%.1f%%", attendancePercentage))"
            ]
            
            for stat in attendanceStats {
                stat.draw(at: CGPoint(x: margin, y: currentY), withAttributes: bodyAttrs as [NSAttributedString.Key : Any])
                currentY += 20
            }
            
        case "reading":
            "Total Records: \(student.runningRecords.count)".draw(at: CGPoint(x: margin, y: currentY), withAttributes: bodyAttrs as [NSAttributedString.Key : Any])
            currentY += 30
            
            for record in student.runningRecords.sorted(by: { $0.date > $1.date }).prefix(15) {
                record.textTitle.draw(at: CGPoint(x: margin, y: currentY), withAttributes: nameAttrs as [NSAttributedString.Key : Any])
                currentY += 18
                "\(String(format: "%.1f%%", record.accuracy)) - \(readingLevelName(record.readingLevel))".draw(at: CGPoint(x: margin + 20, y: currentY), withAttributes: bodyAttrs as [NSAttributedString.Key : Any])
                currentY += 20
                
                if currentY > pageRect.height - 100 { break }
            }
            
        case "development":
            let grouped = groupedDevelopmentScores()
            for group in grouped.prefix(5) {
                displayRubricText(group.category).draw(at: CGPoint(x: margin, y: currentY), withAttributes: nameAttrs as [NSAttributedString.Key : Any])
                currentY += 20
                
                for score in group.scores.prefix(10) {
                    let criterionName = displayRubricText(score.criterion?.name ?? "Unknown")
                    let stars = String(repeating: "★", count: score.rating)
                    criterionName.draw(at: CGPoint(x: margin + 20, y: currentY), withAttributes: bodyAttrs as [NSAttributedString.Key : Any])
                    currentY += 18
                    "\(stars) - \(score.ratingLabel)".draw(at: CGPoint(x: margin + 40, y: currentY), withAttributes: bodyAttrs as [NSAttributedString.Key : Any])
                    currentY += 20
                    
                    if currentY > pageRect.height - 100 { break }
                }
                if currentY > pageRect.height - 100 { break }
            }
            
        default:
            break
        }
        
        // Footer
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        let footerText = "Generated on \(dateFormatter.string(from: Date())) • Student Progress Tracker"
        let footerFont = NSFont.systemFont(ofSize: 10)
        let footerAttrs: [NSAttributedString.Key: Any] = [.font: footerFont, .foregroundColor: NSColor(calibratedWhite: 0.5, alpha: 1.0)]
        footerText.draw(at: CGPoint(x: margin, y: pageRect.height - 40), withAttributes: footerAttrs as [NSAttributedString.Key : Any])
        
        pdfContext.restoreGState()
    }
    
    func generateTabPDFMac(for tab: ProgressTab) -> URL {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(student.name)_\(tab.rawValue)_\(Date().timeIntervalSince1970).pdf")
        
        let pdfData = NSMutableData()
        
        let pageWidth: CGFloat = 612.0
        let pageHeight: CGFloat = 792.0
        var pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        guard let consumer = CGDataConsumer(data: pdfData) else {
            return tempURL
        }
        
        var mediaBox = pageRect
        guard let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return tempURL
        }
        
        pdfContext.beginPDFPage(nil)
        drawPDFHeaderMac(context: pdfContext, pageRect: pageRect, title: tab.rawValue)
        drawStudentInfoMac(context: pdfContext, pageRect: pageRect, yOffset: 120)
        
        switch tab {
        case .overview:
            drawOverviewSectionMac(context: pdfContext, pageRect: pageRect, yOffset: 250)
        case .academics:
            drawAcademicsSectionMac(context: pdfContext, pageRect: pageRect, yOffset: 250)
        case .attendance:
            drawAttendanceSectionMac(context: pdfContext, pageRect: pageRect, yOffset: 250)
        case .runningRecords:
            drawRunningRecordsSectionMac(context: pdfContext, pageRect: pageRect, yOffset: 250)
        case .development:
            drawDevelopmentSectionMac(context: pdfContext, pageRect: pageRect, yOffset: 250)
        }
        
        drawPDFFooterMac(context: pdfContext, pageRect: pageRect)
        pdfContext.endPDFPage()
        pdfContext.closePDF()
        
        pdfData.write(to: tempURL, atomically: true)
        return tempURL
    }
    
    // MARK: - macOS PDF Drawing Functions
    
    func drawPDFHeaderMac(context: CGContext, pageRect: CGRect, title: String) {
        // TEST: Draw a simple black rectangle to verify rendering
        context.setFillColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        context.fill(CGRect(x: 50, y: 50, width: 100, height: 30))
        
        // Flip coordinate system for text
        context.saveGState()
        context.translateBy(x: 0, y: pageRect.height)
        context.scaleBy(x: 1, y: -1)
        
        // TEST: Try the simplest possible text drawing
        let simpleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 24),
            .foregroundColor: NSColor.black
        ]
        "TEST TEXT".draw(at: CGPoint(x: 200, y: 50), withAttributes: simpleAttrs)
        
        let titleFont = NSFont.boldSystemFont(ofSize: 24)
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: NSColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0)
        ]
        
        let titleString = NSAttributedString(string: title, attributes: titleAttributes)
        let titleRect = CGRect(x: 50, y: 50, width: pageRect.width - 100, height: 40)
        titleString.draw(in: titleRect)
        
        context.restoreGState()
        
        // Draw line in PDF coordinates
        context.setStrokeColor(NSColor.black.cgColor)
        context.setLineWidth(3)
        context.move(to: CGPoint(x: 50, y: pageRect.height - 95))
        context.addLine(to: CGPoint(x: pageRect.width - 50, y: pageRect.height - 95))
        context.strokePath()
    }
    
    func drawStudentInfoMac(context: CGContext, pageRect: CGRect, yOffset: CGFloat) {
        context.saveGState()
        context.translateBy(x: 0, y: pageRect.height)
        context.scaleBy(x: 1, y: -1)
        
        let nameFont = NSFont.boldSystemFont(ofSize: 18)
        let infoFont = NSFont.systemFont(ofSize: 14)
        
        let nameAttributes: [NSAttributedString.Key: Any] = [.font: nameFont, .foregroundColor: NSColor(calibratedWhite: 0.0, alpha: 1.0)]
        let infoAttributes: [NSAttributedString.Key: Any] = [.font: infoFont, .foregroundColor: NSColor(calibratedWhite: 0.5, alpha: 1.0)]
        
        let nameString = NSAttributedString(string: student.name, attributes: nameAttributes)
        nameString.draw(at: CGPoint(x: 50, y: yOffset))
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        let dateString = NSAttributedString(string: "Generated: \(dateFormatter.string(from: Date()))", attributes: infoAttributes)
        dateString.draw(at: CGPoint(x: 50, y: yOffset + 25))
        
        if !schoolName.isEmpty {
            let schoolString = NSAttributedString(string: schoolName, attributes: infoAttributes)
            schoolString.draw(at: CGPoint(x: 50, y: yOffset + 45))
        }
        
        context.restoreGState()
    }
    
    func drawOverviewSectionMac(context: CGContext, pageRect: CGRect, yOffset: CGFloat) {
        context.saveGState()
        context.translateBy(x: 0, y: pageRect.height)
        context.scaleBy(x: 1, y: -1)
        
        var currentY = yOffset
        let margin: CGFloat = 50
        
        let sectionFont = NSFont.boldSystemFont(ofSize: 16)
        let bodyFont = NSFont.systemFont(ofSize: 14)
        
        let sectionAttributes: [NSAttributedString.Key: Any] = [.font: sectionFont, .foregroundColor: NSColor(calibratedWhite: 0.0, alpha: 1.0)]
        let bodyAttributes: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: NSColor(calibratedWhite: 0.0, alpha: 1.0)]
        
        NSAttributedString(string: "Summary", attributes: sectionAttributes)
            .draw(at: CGPoint(x: margin, y: currentY))
        currentY += 30
        
        let stats = [
            "Academic Average: \(String(format: "%.1f", resultsForStudent.averageScore))",
            "Total Assessments: \(resultsForStudent.count)",
            "Attendance Rate: \(String(format: "%.0f%%", attendancePercentage))",
            "Running Records: \(student.runningRecords.count)",
            "Development Areas: \(studentDevelopmentScores.count)"
        ]
        
        for stat in stats {
            NSAttributedString(string: stat, attributes: bodyAttributes)
                .draw(at: CGPoint(x: margin + 20, y: currentY))
            currentY += 22
        }
        
        currentY += 20
        
        if !subjectsForStudent.isEmpty {
            NSAttributedString(string: "Subject Performance".localized, attributes: sectionAttributes)
                .draw(at: CGPoint(x: margin, y: currentY))
            currentY += 30
            
            for subject in subjectsForStudent.prefix(8) {
                let subjectResults = resultsForStudent.filter {
                    $0.assessment?.unit?.subject?.id == subject.id
                }
                let average = subjectResults.averageScore
                
                let subjectText = "\(subject.name): \(String(format: "%.1f", average)) (\(subjectResults.count) assessments)"
                NSAttributedString(string: subjectText, attributes: bodyAttributes)
                    .draw(at: CGPoint(x: margin + 20, y: currentY))
                currentY += 22
                
                if currentY > pageRect.height - 100 { break }
            }
        }
        
        context.restoreGState()
    }
    
    func drawAcademicsSectionMac(context: CGContext, pageRect: CGRect, yOffset: CGFloat) {
        context.saveGState()
        context.translateBy(x: 0, y: pageRect.height)
        context.scaleBy(x: 1, y: -1)
        
        var currentY = yOffset
        let margin: CGFloat = 50
        let sectionFont = NSFont.boldSystemFont(ofSize: 16)
        let bodyFont = NSFont.systemFont(ofSize: 14)
        let captionFont = NSFont.systemFont(ofSize: 12)
        
        let sectionAttributes: [NSAttributedString.Key: Any] = [.font: sectionFont, .foregroundColor: NSColor(calibratedWhite: 0.0, alpha: 1.0)]
        let bodyAttributes: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: NSColor(calibratedWhite: 0.0, alpha: 1.0)]
        let captionAttributes: [NSAttributedString.Key: Any] = [.font: captionFont, .foregroundColor: NSColor(calibratedWhite: 0.5, alpha: 1.0)]
        
        NSAttributedString(string: "Academic Performance", attributes: sectionAttributes)
            .draw(at: CGPoint(x: margin, y: currentY))
        currentY += 30
        
        let overallText = "Overall Average: \(String(format: "%.1f", resultsForStudent.averageScore)) (\(resultsForStudent.count) total assessments)"
        NSAttributedString(string: overallText, attributes: bodyAttributes)
            .draw(at: CGPoint(x: margin + 20, y: currentY))
        currentY += 40
        
        for subject in subjectsForStudent {
            let subjectResults = resultsForStudent.filter {
                $0.assessment?.unit?.subject?.id == subject.id
            }
            let average = subjectResults.averageScore
            
            NSAttributedString(string: subject.name, attributes: [.font: NSFont.boldSystemFont(ofSize: 14), .foregroundColor: NSColor(calibratedWhite: 0.0, alpha: 1.0)])
                .draw(at: CGPoint(x: margin, y: currentY))
            currentY += 20
            
            let avgText = "Average: \(String(format: "%.1f", average)) • \(subjectResults.count) assessments"
            NSAttributedString(string: avgText, attributes: captionAttributes)
                .draw(at: CGPoint(x: margin + 20, y: currentY))
            currentY += 25
            
            if currentY > pageRect.height - 150 { break }
        }
        
        context.restoreGState()
    }
    
    func drawAttendanceSectionMac(context: CGContext, pageRect: CGRect, yOffset: CGFloat) {
        context.saveGState()
        context.translateBy(x: 0, y: pageRect.height)
        context.scaleBy(x: 1, y: -1)
        
        var currentY = yOffset
        let margin: CGFloat = 50
        let sectionFont = NSFont.boldSystemFont(ofSize: 16)
        let bodyFont = NSFont.systemFont(ofSize: 14)
        
        let sectionAttributes: [NSAttributedString.Key: Any] = [.font: sectionFont, .foregroundColor: NSColor(calibratedWhite: 0.0, alpha: 1.0)]
        let bodyAttributes: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: NSColor(calibratedWhite: 0.0, alpha: 1.0)]
        
        NSAttributedString(string: "Attendance Summary", attributes: sectionAttributes)
            .draw(at: CGPoint(x: margin, y: currentY))
        currentY += 30
        
        let attendanceStats = [
            "Total Sessions: \(totalSessions)",
            "Present: \(presentCount) (\(totalSessions > 0 ? Int((Double(presentCount) / Double(totalSessions)) * 100) : 0)%)",
            "Absent: \(absentCount) (\(totalSessions > 0 ? Int((Double(absentCount) / Double(totalSessions)) * 100) : 0)%)",
            "Late: \(earlyCount) (\(totalSessions > 0 ? Int((Double(earlyCount) / Double(totalSessions)) * 100) : 0)%)",
            "",
            "Overall Attendance Rate: \(String(format: "%.1f%%", attendancePercentage))"
        ]
        
        for stat in attendanceStats {
            NSAttributedString(string: stat, attributes: bodyAttributes)
                .draw(at: CGPoint(x: margin + 20, y: currentY))
            currentY += 25
        }
        
        context.restoreGState()
    }
    
    func drawRunningRecordsSectionMac(context: CGContext, pageRect: CGRect, yOffset: CGFloat) {
        context.saveGState()
        context.translateBy(x: 0, y: pageRect.height)
        context.scaleBy(x: 1, y: -1)
        
        var currentY = yOffset
        let margin: CGFloat = 50
        let sectionFont = NSFont.boldSystemFont(ofSize: 16)
        let bodyFont = NSFont.systemFont(ofSize: 14)
        let captionFont = NSFont.systemFont(ofSize: 12)
        
        let sectionAttributes: [NSAttributedString.Key: Any] = [.font: sectionFont, .foregroundColor: NSColor(calibratedWhite: 0.0, alpha: 1.0)]
        let bodyAttributes: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: NSColor(calibratedWhite: 0.0, alpha: 1.0)]
        let captionAttributes: [NSAttributedString.Key: Any] = [.font: captionFont, .foregroundColor: NSColor(calibratedWhite: 0.5, alpha: 1.0)]
        
        NSAttributedString(string: "Running Records", attributes: sectionAttributes)
            .draw(at: CGPoint(x: margin, y: currentY))
        currentY += 30
        
        let summary = "Total Records: \(student.runningRecords.count) • Average Accuracy: \(String(format: "%.1f%%", averageAccuracy))"
        NSAttributedString(string: summary, attributes: bodyAttributes)
            .draw(at: CGPoint(x: margin + 20, y: currentY))
        currentY += 40
        
        let sortedRecords = student.runningRecords.sorted { $0.date > $1.date }
        
        for record in sortedRecords.prefix(15) {
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            
            NSAttributedString(string: record.textTitle, attributes: [.font: NSFont.boldSystemFont(ofSize: 14), .foregroundColor: NSColor(calibratedWhite: 0.0, alpha: 1.0)])
                .draw(at: CGPoint(x: margin, y: currentY))
            currentY += 20
            
            let details = "\(dateFormatter.string(from: record.date)) • \(String(format: "%.1f%%", record.accuracy)) • \(readingLevelName(record.readingLevel))"
            NSAttributedString(string: details, attributes: captionAttributes)
                .draw(at: CGPoint(x: margin + 20, y: currentY))
            currentY += 25
            
            if currentY > pageRect.height - 150 { break }
        }
        
        context.restoreGState()
    }
    
    func drawDevelopmentSectionMac(context: CGContext, pageRect: CGRect, yOffset: CGFloat) {
        context.saveGState()
        context.translateBy(x: 0, y: pageRect.height)
        context.scaleBy(x: 1, y: -1)
        
        var currentY = yOffset
        let margin: CGFloat = 50
        let sectionFont = NSFont.boldSystemFont(ofSize: 16)
        let bodyFont = NSFont.systemFont(ofSize: 14)
        let captionFont = NSFont.systemFont(ofSize: 12)
        
        let sectionAttributes: [NSAttributedString.Key: Any] = [.font: sectionFont, .foregroundColor: NSColor(calibratedWhite: 0.0, alpha: 1.0)]
        let bodyAttributes: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: NSColor(calibratedWhite: 0.0, alpha: 1.0)]
        let captionAttributes: [NSAttributedString.Key: Any] = [.font: captionFont, .foregroundColor: NSColor(calibratedWhite: 0.5, alpha: 1.0)]
        
        NSAttributedString(string: "Development Tracking".localized, attributes: sectionAttributes)
            .draw(at: CGPoint(x: margin, y: currentY))
        currentY += 30
        
        let grouped = groupedDevelopmentScores()
        
        for group in grouped {
            NSAttributedString(string: displayRubricText(group.category), attributes: [.font: NSFont.boldSystemFont(ofSize: 14), .foregroundColor: NSColor(red: 1.0, green: 0.4, blue: 0.7, alpha: 1.0)])
                .draw(at: CGPoint(x: margin, y: currentY))
            currentY += 25
            
            for score in group.scores {
                let criterionName = displayRubricText(score.criterion?.name ?? "Unknown")
                let stars = String(repeating: "★", count: score.rating) + String(repeating: "☆", count: 5 - score.rating)
                
                NSAttributedString(string: criterionName, attributes: bodyAttributes)
                    .draw(at: CGPoint(x: margin + 20, y: currentY))
                currentY += 20
                
                NSAttributedString(string: "\(stars) - \(score.ratingLabel)", attributes: captionAttributes)
                    .draw(at: CGPoint(x: margin + 40, y: currentY))
                currentY += 25
                
                if currentY > pageRect.height - 150 { break }
            }
            
            if currentY > pageRect.height - 150 { break }
            currentY += 10
        }
        
        context.restoreGState()
    }
    
    func drawPDFFooterMac(context: CGContext, pageRect: CGRect) {
        context.saveGState()
        context.translateBy(x: 0, y: pageRect.height)
        context.scaleBy(x: 1, y: -1)
        
        let footerFont = NSFont.systemFont(ofSize: 10)
        let footerAttributes: [NSAttributedString.Key: Any] = [
            .font: footerFont,
            .foregroundColor: NSColor(calibratedWhite: 0.5, alpha: 1.0)
        ]
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        let footerText = "Generated on \(dateFormatter.string(from: Date())) • Student Progress Tracker"
        let footerString = NSAttributedString(string: footerText, attributes: footerAttributes)
        let footerSize = footerString.size()
        
        let footerRect = CGRect(
            x: (pageRect.width - footerSize.width) / 2,
            y: pageRect.height - 40,
            width: footerSize.width,
            height: footerSize.height
        )
        
        footerString.draw(in: footerRect)
        
        context.restoreGState()
    }
    #endif
    
    // MARK: - Original Components Continue Below
    
    // MARK: - Hero Header
    
    var heroHeader: some View {
        VStack(spacing: 16) {
            // Student Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Text(student.name.prefix(1).uppercased())
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // Student Name
            Text(student.name)
                .font(.title)
                .fontWeight(.bold)
            
            // Quick Stats
            HStack(spacing: 24) {
                quickStat(
                    value: String(format: "%.1f", resultsForStudent.averageScore),
                    label: "Average".localized,
                    color: averageColor(resultsForStudent.averageScore)
                )
                
                Divider()
                    .frame(height: 40)
                
                quickStat(
                    value: "\(resultsForStudent.count)",
                    label: "Assessments".localized,
                    color: .blue
                )
                
                Divider()
                    .frame(height: 40)
                
                quickStat(
                    value: String(format: "%.0f%%", attendancePercentage),
                    label: "Attendance".localized,
                    color: .green
                )
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.blue.opacity(0.05), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    func quickStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    func averageColor(_ average: Double) -> Color {
        if average >= 7.0 { return .green }
        if average >= 5.0 { return .orange }
        return .red
    }
    
    // MARK: - Tab Picker
    
    var tabPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ProgressTab.allCases, id: \.self) { tab in
                    tabButton(tab)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color.gray.opacity(0.05))
    }
    
    func tabButton(_ tab: ProgressTab) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: tab.icon)
                    .font(.subheadline)
                
                Text(tab.localizedName)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(selectedTab == tab ? tab.color : Color.gray.opacity(0.1))
            .foregroundColor(selectedTab == tab ? .white : .primary)
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Overview Tab
    
    var overviewTab: some View {
        VStack(spacing: 20) {
            // Summary Cards
            HStack(spacing: 16) {
                summaryCard(
                    title: "Academic Average".localized,
                    value: String(format: "%.1f", resultsForStudent.averageScore),
                    icon: "chart.bar.fill",
                    color: .purple
                )
                
                summaryCard(
                    title: "Attendance Rate".localized,
                    value: String(format: "%.0f%%", attendancePercentage),
                    icon: "calendar",
                    color: .green
                )
            }
            
            HStack(spacing: 16) {
                summaryCard(
                    title: "Running Records".localized,
                    value: "\(student.runningRecords.count)",
                    icon: "book.fill",
                    color: .orange
                )
                
                summaryCard(
                    title: "Development Areas".localized,
                    value: "\(studentDevelopmentScores.count)",
                    icon: "star.fill",
                    color: .pink
                )
            }
            
            // Subject Performance Overview
            sectionHeader(title: "Subject Performance".localized, icon: "graduationcap.fill", color: .purple)
            
            if subjectsForStudent.isEmpty {
                emptyState(icon: "book.closed", message: "No academic results yet")
            } else {
                ForEach(subjectsForStudent, id: \.id) { subject in
                    subjectOverviewCard(subject: subject)
                }
            }
            
            // Recent Activity
            sectionHeader(title: "Recent Activity".localized, icon: "clock.fill", color: .blue)
            
            recentActivityList
        }
    }
    
    func summaryCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(16)
    }
    
    func subjectOverviewCard(subject: Subject) -> some View {
        let subjectResults = resultsForStudent.filter {
            $0.assessment?.unit?.subject?.id == subject.id
        }
        let average = subjectResults.averageScore
        
        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(subject.name)
                    .font(.headline)
                
                Text("\(subjectResults.count) \(subjectResults.count == 1 ? "assessment".localized : "assessments".localized)")                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(String(format: "%.1f", average))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(averageColor(average))
        }
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
    }
    
    var recentActivityList: some View {
        VStack(spacing: 12) {
            let recentResults = resultsForStudent
                .sorted { ($0.assessment?.sortOrder ?? 0) > ($1.assessment?.sortOrder ?? 0) }
                .prefix(5)
            
            if recentResults.isEmpty {
                emptyState(icon: "tray", message: "No recent activity")
            } else {
                ForEach(Array(recentResults), id: \.id) { result in
                    activityRow(result: result)
                }
            }
        }
    }
    
    func activityRow(result: StudentResult) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.purple.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .foregroundColor(.purple)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(result.assessment?.title ?? "Assessment")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let subject = result.assessment?.unit?.subject {
                    Text(subject.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text(String(format: "%.1f", result.score))
                .font(.headline)
                .foregroundColor(averageColor(result.score))
        }
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
    }
    
    // MARK: - Academics Tab
    
    var academicsTab: some View {
        VStack(spacing: 20) {
            // Overall Stats
            HStack(spacing: 16) {
                statCard(
                    title: "Overall Average",
                    value: String(format: "%.1f", resultsForStudent.averageScore),
                    icon: "chart.bar.fill",
                    color: averageColor(resultsForStudent.averageScore)
                )
                
                statCard(
                    title: "Total Assessments",
                    value: "\(resultsForStudent.count)",
                    icon: "list.bullet.clipboard",
                    color: .blue
                )
            }
            
            // Subjects
            sectionHeader(title: "Performance by Subject", icon: "graduationcap.fill", color: .purple)
            
            if subjectsForStudent.isEmpty {
                emptyState(icon: "book.closed", message: "No academic results yet")
            } else {
                ForEach(subjectsForStudent, id: \.id) { subject in
                    subjectSection(subject: subject)
                }
            }
        }
    }
    
    // MARK: - Attendance Tab
    
    var attendanceTab: some View {
        VStack(spacing: 20) {
            // Attendance Summary
            sectionHeader(title: "Attendance Summary", icon: "calendar", color: .green)
            
            if totalSessions == 0 {
                emptyState(icon: "calendar.badge.exclamationmark", message: "No attendance records yet")
            } else {
                // Stats Grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    attendanceStatCard(title: "Total Sessions", value: "\(totalSessions)", color: .blue)
                    attendanceStatCard(title: "Present", value: "\(presentCount)", color: .green)
                    attendanceStatCard(title: "Absent", value: "\(absentCount)", color: .red)
                    attendanceStatCard(title: "Late", value: "\(earlyCount)", color: .orange)
                }
                
                // Attendance Rate
                VStack(spacing: 12) {
                    Text("Attendance Rate")
                        .font(.headline)
                    
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                            .frame(width: 150, height: 150)
                        
                        Circle()
                            .trim(from: 0, to: attendancePercentage / 100)
                            .stroke(
                                attendancePercentage >= 90 ? Color.green : attendancePercentage >= 75 ? Color.orange : Color.red,
                                style: StrokeStyle(lineWidth: 20, lineCap: .round)
                            )
                            .frame(width: 150, height: 150)
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(), value: attendancePercentage)
                        
                        VStack(spacing: 4) {
                            Text(String(format: "%.0f%%", attendancePercentage))
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(attendancePercentage >= 90 ? .green : attendancePercentage >= 75 ? .orange : .red)
                            
                            Text("Present")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(cardBackgroundColor)
                .cornerRadius(16)
                .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
                
                // Attendance Breakdown
                sectionHeader(title: "Breakdown", icon: "chart.pie.fill", color: .blue)
                
                VStack(spacing: 12) {
                    attendanceBreakdownRow(label: "Present", count: presentCount, total: totalSessions, color: .green)
                    attendanceBreakdownRow(label: "Absent", count: absentCount, total: totalSessions, color: .red)
                    attendanceBreakdownRow(label: "Late", count: earlyCount, total: totalSessions, color: .orange)
                }
            }
        }
    }
    
    func attendanceStatCard(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
    
    func attendanceBreakdownRow(label: String, count: Int, total: Int, color: Color) -> some View {
        let percentage = total > 0 ? Double(count) / Double(total) : 0
        
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(count) (\(Int(percentage * 100))%)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * percentage, height: 8)
                        .animation(.spring(), value: percentage)
                }
            }
            .frame(height: 8)
        }
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
    }
    
    // MARK: - Running Records Tab
    
    var runningRecordsTab: some View {
        VStack(spacing: 20) {
            sectionHeader(title: "Running Records", icon: "book.fill", color: .orange)
            
            if student.runningRecords.isEmpty {
                emptyState(icon: "book.closed", message: "No running records yet")
            } else {
                // Stats
                HStack(spacing: 16) {
                    statCard(
                        title: "Total Records",
                        value: "\(student.runningRecords.count)",
                        icon: "doc.text.fill",
                        color: .orange
                    )
                    
                    statCard(
                        title: "Avg. Accuracy",
                        value: String(format: "%.1f%%", averageAccuracy),
                        icon: "checkmark.circle.fill",
                        color: .green
                    )
                }
                
                // Latest Level
                if let latestRecord = student.runningRecords.sorted(by: { $0.date > $1.date }).first {
                    VStack(spacing: 12) {
                        Text("Current Reading Level")
                            .font(.headline)
                        
                        HStack(spacing: 16) {
                            Image(systemName: latestRecord.readingLevel.systemImage)
                                .font(.system(size: 40))
                                .foregroundColor(readingLevelColor(latestRecord.readingLevel))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(readingLevelName(latestRecord.readingLevel))
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(readingLevelColor(latestRecord.readingLevel))
                                
                                Text(latestRecord.date, style: .date)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(readingLevelColor(latestRecord.readingLevel).opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                
                // Progress Chart
                if student.runningRecords.count >= 2 {
                    sectionHeader(title: "Progress Over Time", icon: "chart.line.uptrend.xyaxis", color: .blue)
                    
                    runningRecordsChart
                }
                
                // Records List
                sectionHeader(title: "All Records", icon: "list.bullet", color: .purple)
                
                ForEach(student.runningRecords.sorted(by: { $0.date > $1.date }), id: \.id) { record in
                    runningRecordCard(record)
                }
            }
        }
    }
    
    var runningRecordsChart: some View {
        let sortedRecords = student.runningRecords.sorted(by: { $0.date < $1.date })
        
        return VStack(spacing: 8) {
            Chart {
                ForEach(sortedRecords, id: \.id) { record in
                    LineMark(
                        x: .value("Date", record.date),
                        y: .value("Accuracy", record.accuracy)
                    )
                    .foregroundStyle(.orange)
                    .symbol(.circle)
                    .symbolSize(60)
                    
                    PointMark(
                        x: .value("Date", record.date),
                        y: .value("Accuracy", record.accuracy)
                    )
                    .foregroundStyle(.orange)
                }
                
                // Reference lines
                RuleMark(y: .value("Independent", 95))
                    .foregroundStyle(.green.opacity(0.3))
                    .lineStyle(StrokeStyle(dash: [5, 5]))
                
                RuleMark(y: .value("Instructional", 90))
                    .foregroundStyle(.orange.opacity(0.3))
                    .lineStyle(StrokeStyle(dash: [5, 5]))
            }
            .chartYScale(domain: 70...100)
            .frame(height: 200)
            .padding()
            .background(cardBackgroundColor)
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
            
            // Legend
            HStack(spacing: 16) {
                legendItem(color: .green, text: "95%+ Independent")
                legendItem(color: .orange, text: "90%+ Instructional")
                legendItem(color: .red, text: "<90% Frustration")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }
    
    func legendItem(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color.opacity(0.5))
                .frame(width: 20, height: 3)
            
            Text(text)
        }
    }
    
    func runningRecordCard(_ record: RunningRecord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.textTitle)
                        .font(.headline)
                    
                    Text(record.date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%.1f%%", record.accuracy))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(readingLevelColor(record.readingLevel))
                    
                    HStack(spacing: 4) {
                        Image(systemName: record.readingLevel.systemImage)
                            .font(.caption)
                        Text(readingLevelShortName(record.readingLevel))
                            .font(.caption)
                    }
                    .foregroundColor(readingLevelColor(record.readingLevel))
                }
            }
            
            if !record.notes.isEmpty {
                Divider()
                
                Text(record.notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 2)
    }
    
    var averageAccuracy: Double {
        guard !student.runningRecords.isEmpty else { return 0 }
        let total = student.runningRecords.reduce(0.0) { $0 + $1.accuracy }
        return total / Double(student.runningRecords.count)
    }
    
    func readingLevelColor(_ level: ReadingLevel) -> Color {
        switch level {
        case .independent: return .green
        case .instructional: return .orange
        case .frustration: return .red
        }
    }
    
    func readingLevelName(_ level: ReadingLevel) -> String {
        switch level {
        case .independent: return "Independent"
        case .instructional: return "Instructional"
        case .frustration: return "Frustration"
        }
    }
    
    func readingLevelShortName(_ level: ReadingLevel) -> String {
        switch level {
        case .independent: return "Ind."
        case .instructional: return "Inst."
        case .frustration: return "Frust."
        }
    }
    
    // MARK: - Development Tab
    
    var studentDevelopmentScores: [DevelopmentScore] {
        allDevelopmentScores.filter { $0.student?.id == student.id }
    }
    
    var latestDevelopmentScores: [DevelopmentScore] {
        var latestScores: [UUID: DevelopmentScore] = [:]
        
        for score in studentDevelopmentScores {
            guard let criterionID = score.criterion?.id else { continue }
            
            if let existing = latestScores[criterionID] {
                if score.date > existing.date {
                    latestScores[criterionID] = score
                }
            } else {
                latestScores[criterionID] = score
            }
        }
        
        return Array(latestScores.values).sorted {
            ($0.criterion?.sortOrder ?? 0) < ($1.criterion?.sortOrder ?? 0)
        }
    }
    
    var developmentTab: some View {
        VStack(spacing: 20) {
            sectionHeader(title: "Development Tracking".localized, icon: "star.fill", color: .pink)
            
            if studentDevelopmentScores.isEmpty {
                emptyState(icon: "star.circle", message: "No development tracking yet".localized)
            } else {
                // Summary
                HStack(spacing: 16) {
                    statCard(
                        title: "Areas Tracked",
                        value: "\(latestDevelopmentScores.count)",
                        icon: "star.fill",
                        color: .pink
                    )
                    
                    statCard(
                        title: "Total Updates",
                        value: "\(studentDevelopmentScores.count)",
                        icon: "arrow.clockwise",
                        color: .blue
                    )
                }
                
                // Development Categories
                let grouped = groupedDevelopmentScores()
                
                ForEach(grouped, id: \.category) { group in
                    developmentCategorySection(category: group.category, scores: group.scores)
                }
            }
        }
    }
    
    func groupedDevelopmentScores() -> [(category: String, scores: [DevelopmentScore])] {
        var grouped: [String: [DevelopmentScore]] = [:]
        
        for score in latestDevelopmentScores {
            let categoryName = score.criterion?.category?.name ?? "Other"
            grouped[categoryName, default: []].append(score)
        }
        
        return grouped.map { (category: $0.key, scores: $0.value) }
            .sorted { $0.category < $1.category }
    }

    func displayRubricText(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return value }
        let localized = languageManager.localized(trimmed)
        if localized != trimmed { return localized }
        return RubricLocalization.localized(trimmed, languageCode: languageManager.currentLanguage.rawValue)
    }
    
    func developmentCategorySection(category: String, scores: [DevelopmentScore]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(displayRubricText(category))
                .font(.headline)
                .foregroundColor(.pink)
            
            ForEach(scores, id: \.id) { score in
                developmentScoreCard(score)
            }
        }
        .padding()
        .background(Color.pink.opacity(0.05))
        .cornerRadius(12)
    }
    
    func developmentScoreCard(_ score: DevelopmentScore) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(displayRubricText(score.criterion?.name ?? "Unknown"))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                // Star rating
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= score.rating ? "star.fill" : "star")
                            .font(.caption)
                            .foregroundColor(star <= score.rating ? score.ratingColor : .gray.opacity(0.3))
                    }
                }
            }
            
            // Rating label
            Text(score.ratingLabel)
                .font(.caption)
                .foregroundColor(score.ratingColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(score.ratingColor.opacity(0.15))
                .cornerRadius(6)
            
            if !score.notes.isEmpty {
                Divider()
                
                Text(score.notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(score.date, style: .date)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Helper Views
    
    func sectionHeader(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
            
            Spacer()
        }
    }
    
    func emptyState(icon: String, message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Subject Section (for academics tab)
    
    func subjectSection(subject: Subject) -> some View {
        
        let subjectResults = resultsForStudent.filter {
            $0.assessment?.unit?.subject?.id == subject.id
        }
        
        let subjectAverage = subjectResults.averageScore
        
        let units = subjectResults.compactMap { $0.assessment?.unit }
        
        var uniqueUnits: [Unit] = []
        for unit in units {
            if !uniqueUnits.contains(where: { $0.id == unit.id }) {
                uniqueUnits.append(unit)
            }
        }
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(subject.name)
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Text("\(subjectResults.count) assessments")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(String(format: "%.1f", subjectAverage))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(averageColor(subjectAverage))
            }
            
            if !uniqueUnits.isEmpty {
                Divider()
                
                Text("Units")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                ForEach(uniqueUnits, id: \.id) { unit in
                    unitRow(unit: unit, subjectResults: subjectResults)
                }
            }
        }
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    func unitRow(unit: Unit, subjectResults: [StudentResult]) -> some View {
        
        let unitResults = subjectResults.filter {
            $0.assessment?.unit?.id == unit.id
        }
        
        let unitAverage = unitResults.averageScore
        
        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(unit.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(unitResults.count) criteria")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(String(format: "%.1f", unitAverage))
                .font(.headline)
                .foregroundColor(averageColor(unitAverage))
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(10)
    }
    
    // MARK: - Dark Mode Support
    
    var cardBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.secondarySystemBackground)
        #endif
    }
}
