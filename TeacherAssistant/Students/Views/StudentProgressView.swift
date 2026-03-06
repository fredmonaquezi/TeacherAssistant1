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
    @State private var derivedData: StudentProgressDerivedData = .empty
    
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
    
    var overallAverageScore: Double {
        derivedData.overallAverageScore
    }

    var resultsForStudent: [StudentResult] {
        derivedData.resultsForStudent
    }

    var scoredResultsForStudent: [StudentResult] {
        derivedData.scoredResultsForStudent
    }

    var recentActivityViewModels: [StudentProgressRecentActivityViewModel] {
        derivedData.recentActivityViewModels
    }
    
    var attendanceRecordsForStudent: [AttendanceRecord] {
        derivedData.attendanceRecordsForStudent
    }
    
    // MARK: - Attendance Stats
    
    var attendanceSummary: StudentProgressAttendanceSummary {
        derivedData.attendanceSummary
    }

    var totalSessions: Int {
        attendanceSummary.totalSessions
    }
    
    var presentCount: Int {
        attendanceSummary.present
    }
    
    var absentCount: Int {
        attendanceSummary.absent
    }
    
    var earlyCount: Int {
        attendanceSummary.late
    }
    
    var attendancePercentage: Double {
        guard totalSessions > 0 else { return 0 }
        return (Double(presentCount) / Double(totalSessions)) * 100.0
    }
    
    // MARK: - Subjects
    
    var subjectOverviewViewModels: [StudentProgressSubjectOverviewViewModel] {
        derivedData.subjectOverviewViewModels
    }

    var subjectSectionViewModels: [StudentProgressSubjectSectionViewModel] {
        derivedData.subjectSectionViewModels
    }

    var subjectSummaries: [StudentProgressSubjectSummary] {
        derivedData.subjectSummaries
    }

    var runningRecordsDescending: [RunningRecord] {
        derivedData.runningRecordsDescending
    }

    var runningRecordCount: Int {
        runningRecordsDescending.count
    }

    private var refreshToken: String {
        [
            String(allResults.count),
            String(allAttendanceSessions.count),
            String(allDevelopmentScores.count),
            String(describing: student.id),
        ].joined(separator: "|")
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
        .task(id: refreshToken) {
            do {
                try await Task.sleep(nanoseconds: ViewBudget.filterDerivationDebounceMilliseconds * 1_000_000)
            } catch {
                return
            }
            await refreshDerivedData()
        }
        .macNavigationDepth()
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
            
            "Generated: \(Date().appDateString(systemStyle: .long))".draw(at: CGPoint(x: 50, y: currentY), withAttributes: infoAttrs)
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
                "Academic Average: \(String(format: "%.1f", self.overallAverageScore))",
                "Total Assessments: \(self.scoredResultsForStudent.count)",
                "Attendance Rate: \(String(format: "%.0f%%", self.attendancePercentage))",
                "Running Records: \(self.runningRecordCount)",
                "Development Areas: \(self.studentDevelopmentScores.count)"
            ]
            
            for stat in stats {
                stat.draw(at: CGPoint(x: 70, y: currentY), withAttributes: bodyAttrs)
                currentY += 22
            }
            
            currentY += 20
            
            // Subject Performance
            if !self.subjectSectionViewModels.isEmpty {
                "Subject Performance".draw(at: CGPoint(x: 50, y: currentY), withAttributes: sectionAttrs)
                currentY += 30
                
                for summary in self.subjectSummaries.prefix(8) {
                    let subjectText = "\(summary.subject.name): \(String(format: "%.1f", summary.averageScore))"
                    subjectText.draw(at: CGPoint(x: 70, y: currentY), withAttributes: bodyAttrs)
                    
                    let countText = "(\(summary.results.count) assessments)"
                    let countAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 12), .foregroundColor: UIColor.gray]
                    countText.draw(at: CGPoint(x: 350, y: currentY + 2), withAttributes: countAttrs)
                    
                    currentY += 22
                    
                    if currentY > pageRect.height - 100 { break }
                }
            }
            
            // Footer
            let footerFont = UIFont.systemFont(ofSize: 10)
            let footerAttrs: [NSAttributedString.Key: Any] = [.font: footerFont, .foregroundColor: UIColor.gray]
            let footerText = "Generated on \(Date().appDateString(systemStyle: .long)) • Student Progress Tracker"
            let footerSize = (footerText as NSString).size(withAttributes: footerAttrs)
            footerText.draw(at: CGPoint(x: (pageRect.width - footerSize.width) / 2, y: pageRect.height - 40), withAttributes: footerAttrs)
            
            // Page 2: Academics
            if !self.subjectSectionViewModels.isEmpty {
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
                
                let overallText = "Overall Average: \(String(format: "%.1f", self.overallAverageScore)) (\(self.scoredResultsForStudent.count) assessments)"
                overallText.draw(at: CGPoint(x: 50, y: currentY), withAttributes: bodyAttrs)
                currentY += 40
                
                for summary in self.subjectSummaries {
                    summary.subject.name.draw(at: CGPoint(x: 50, y: currentY), withAttributes: sectionAttrs)
                    
                    let avgText = "\(String(format: "%.1f", summary.averageScore))"
                    let avgFont = UIFont.boldSystemFont(ofSize: 24)
                    let avgAttrs: [NSAttributedString.Key: Any] = [.font: avgFont, .foregroundColor: UIColor.systemBlue]
                    avgText.draw(at: CGPoint(x: pageRect.width - 100, y: currentY - 5), withAttributes: avgAttrs)
                    
                    currentY += 25
                    
                    "Average: \(String(format: "%.1f", summary.averageScore)) • \(summary.results.count) assessments".draw(at: CGPoint(x: 70, y: currentY), withAttributes: bodyAttrs)
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
            if !self.runningRecordsDescending.isEmpty {
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
                
                let summary = "Total Records: \(self.runningRecordCount) • Average Accuracy: \(String(format: "%.1f%%", self.averageAccuracy))"
                summary.draw(at: CGPoint(x: 50, y: currentY), withAttributes: bodyAttrs)
                currentY += 40

                for record in self.runningRecordsDescending.prefix(20) {
                    record.textTitle.draw(at: CGPoint(x: 50, y: currentY), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 14), .foregroundColor: UIColor.black])
                    currentY += 20
                    
                    let details = "\(record.date.appDateString(systemStyle: .short)) • \(String(format: "%.1f%%", record.accuracy)) • \(self.readingLevelName(record.readingLevel))"
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
                        let criterionName = displayRubricText(score.criterionName)
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
                    "Academic Average: \(String(format: "%.1f", overallAverageScore))",
                    "Total Assessments: \(scoredResultsForStudent.count)",
                    "Attendance Rate: \(String(format: "%.0f%%", attendancePercentage))",
                    "Running Records: \(runningRecordCount)",
                    "Development Areas: \(studentDevelopmentScores.count)"
                ]
                
                for stat in stats {
                    stat.draw(at: CGPoint(x: 70, y: currentY), withAttributes: bodyAttrs)
                    currentY += 22
                }
                
            case .academics:
                let overallText = "Overall Average: \(String(format: "%.1f", overallAverageScore))"
                overallText.draw(at: CGPoint(x: 50, y: currentY), withAttributes: bodyAttrs)
                currentY += 40
                
                for summary in subjectSummaries {
                    summary.subject.name.draw(at: CGPoint(x: 50, y: currentY), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 16), .foregroundColor: UIColor.black])
                    currentY += 22
                    "Average: \(String(format: "%.1f", summary.averageScore)) • \(summary.results.count) assessments".draw(at: CGPoint(x: 70, y: currentY), withAttributes: bodyAttrs)
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
                "Total Records: \(runningRecordCount)".draw(at: CGPoint(x: 50, y: currentY), withAttributes: bodyAttrs)
                currentY += 30
                
                for record in runningRecordsDescending.prefix(15) {
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
                        let criterionName = displayRubricText(score.criterionName)
                        criterionName.draw(at: CGPoint(x: 70, y: currentY), withAttributes: bodyAttrs)
                        currentY += 20
                        let stars = String(repeating: "★", count: score.rating)
                        "\(stars) - \(score.ratingLabel)".draw(at: CGPoint(x: 90, y: currentY), withAttributes: [.font: UIFont.systemFont(ofSize: 12), .foregroundColor: UIColor.gray])
                        currentY += 25
                    }
                }
            }
            
            // Footer
            let footerText = "Generated on \(Date().appDateString(systemStyle: .long)) • Student Progress Tracker"
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
        
        let dateString = "Generated: \(Date().appDateString(systemStyle: .long))"
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
            "Academic Average: \(String(format: "%.1f", overallAverageScore))",
            "Total Assessments: \(scoredResultsForStudent.count)",
            "Attendance Rate: \(String(format: "%.0f%%", attendancePercentage))",
            "Running Records: \(runningRecordCount)",
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
        if !subjectSectionViewModels.isEmpty {
            ("Subject Performance" as NSString).draw(
                at: CGPoint(x: margin, y: currentY),
                withAttributes: [.font: sectionFont, .foregroundColor: UIColor.black]
            )
            currentY += 30
            
            for summary in subjectSummaries.prefix(10) {
                let subjectText = "\(summary.subject.name): \(String(format: "%.1f", summary.averageScore)) (\(summary.results.count) assessments)"
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
        
        let overallText = "Overall Average: \(String(format: "%.1f", overallAverageScore)) (\(scoredResultsForStudent.count) total assessments)"
        (overallText as NSString).draw(
            at: CGPoint(x: margin + 20, y: currentY),
            withAttributes: [.font: bodyFont, .foregroundColor: UIColor.black]
        )
        currentY += 40
        
        // Subject breakdown
        for summary in subjectSummaries {
            (summary.subject.name as NSString).draw(
                at: CGPoint(x: margin, y: currentY),
                withAttributes: [.font: UIFont.boldSystemFont(ofSize: 14), .foregroundColor: UIColor.black]
            )
            currentY += 20
            
            let avgText = "Average: \(String(format: "%.1f", summary.averageScore)) • \(summary.results.count) assessments"
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
        
        let summary = "Total Records: \(runningRecordCount) • Average Accuracy: \(String(format: "%.1f%%", averageAccuracy))"
        (summary as NSString).draw(
            at: CGPoint(x: margin + 20, y: currentY),
            withAttributes: [.font: bodyFont, .foregroundColor: UIColor.black]
        )
        currentY += 40
        
        for record in runningRecordsDescending.prefix(15) {
            (record.textTitle as NSString).draw(
                at: CGPoint(x: margin, y: currentY),
                withAttributes: [.font: UIFont.boldSystemFont(ofSize: 14), .foregroundColor: UIColor.black]
            )
            currentY += 20
            
            let details = "\(record.date.appDateString(systemStyle: .short)) • \(String(format: "%.1f%%", record.accuracy)) • \(readingLevelName(record.readingLevel))"
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
                let criterionName = displayRubricText(score.criterionName)
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
        
        let footerText = "Generated on \(Date().appDateString(systemStyle: .long)) • Student Progress Tracker"
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
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
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
        if !subjectSectionViewModels.isEmpty {
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
        if !runningRecordsDescending.isEmpty {
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
                "Academic Average: \(String(format: "%.1f", overallAverageScore))",
                "Total Assessments: \(scoredResultsForStudent.count)",
                "Attendance Rate: \(String(format: "%.0f%%", attendancePercentage))",
                "Running Records: \(runningRecordCount)",
                "Development Areas: \(studentDevelopmentScores.count)"
            ]
            
            for stat in stats {
                stat.draw(at: CGPoint(x: margin + 20, y: currentY), withAttributes: bodyAttrs as [NSAttributedString.Key : Any])
                currentY += 20
            }
            
        case "academics":
            "Overall Average: \(String(format: "%.1f", overallAverageScore))".draw(at: CGPoint(x: margin, y: currentY), withAttributes: bodyAttrs as [NSAttributedString.Key : Any])
            currentY += 30
            
            for summary in subjectSummaries.prefix(10) {
                summary.subject.name.draw(at: CGPoint(x: margin, y: currentY), withAttributes: nameAttrs as [NSAttributedString.Key : Any])
                currentY += 20
                "Average: \(String(format: "%.1f", summary.averageScore)) • \(summary.results.count) assessments".draw(at: CGPoint(x: margin + 20, y: currentY), withAttributes: bodyAttrs as [NSAttributedString.Key : Any])
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
            "Total Records: \(runningRecordCount)".draw(at: CGPoint(x: margin, y: currentY), withAttributes: bodyAttrs as [NSAttributedString.Key : Any])
            currentY += 30
            
            for record in runningRecordsDescending.prefix(15) {
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
                    let criterionName = displayRubricText(score.criterionName)
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
        let footerText = "Generated on \(Date().appDateString(systemStyle: .long)) • Student Progress Tracker"
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
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
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
        
        let dateString = NSAttributedString(string: "Generated: \(Date().appDateString(systemStyle: .long))", attributes: infoAttributes)
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
            "Academic Average: \(String(format: "%.1f", overallAverageScore))",
            "Total Assessments: \(scoredResultsForStudent.count)",
            "Attendance Rate: \(String(format: "%.0f%%", attendancePercentage))",
            "Running Records: \(runningRecordCount)",
            "Development Areas: \(studentDevelopmentScores.count)"
        ]
        
        for stat in stats {
            NSAttributedString(string: stat, attributes: bodyAttributes)
                .draw(at: CGPoint(x: margin + 20, y: currentY))
            currentY += 22
        }
        
        currentY += 20
        
        if !subjectSectionViewModels.isEmpty {
            NSAttributedString(string: "Subject Performance".localized, attributes: sectionAttributes)
                .draw(at: CGPoint(x: margin, y: currentY))
            currentY += 30
            
            for summary in subjectSummaries.prefix(8) {
                let subjectText = "\(summary.subject.name): \(String(format: "%.1f", summary.averageScore)) (\(summary.results.count) assessments)"
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
        
        let overallText = "Overall Average: \(String(format: "%.1f", overallAverageScore)) (\(scoredResultsForStudent.count) total assessments)"
        NSAttributedString(string: overallText, attributes: bodyAttributes)
            .draw(at: CGPoint(x: margin + 20, y: currentY))
        currentY += 40
        
        for summary in subjectSummaries {
            NSAttributedString(string: summary.subject.name, attributes: [.font: NSFont.boldSystemFont(ofSize: 14), .foregroundColor: NSColor(calibratedWhite: 0.0, alpha: 1.0)])
                .draw(at: CGPoint(x: margin, y: currentY))
            currentY += 20
            
            let avgText = "Average: \(String(format: "%.1f", summary.averageScore)) • \(summary.results.count) assessments"
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
        
        let summary = "Total Records: \(runningRecordCount) • Average Accuracy: \(String(format: "%.1f%%", averageAccuracy))"
        NSAttributedString(string: summary, attributes: bodyAttributes)
            .draw(at: CGPoint(x: margin + 20, y: currentY))
        currentY += 40
        
        for record in runningRecordsDescending.prefix(15) {
            NSAttributedString(string: record.textTitle, attributes: [.font: NSFont.boldSystemFont(ofSize: 14), .foregroundColor: NSColor(calibratedWhite: 0.0, alpha: 1.0)])
                .draw(at: CGPoint(x: margin, y: currentY))
            currentY += 20
            
            let details = "\(record.date.appDateString(systemStyle: .short)) • \(String(format: "%.1f%%", record.accuracy)) • \(readingLevelName(record.readingLevel))"
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
                let criterionName = displayRubricText(score.criterionName)
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
        
        let footerText = "Generated on \(Date().appDateString(systemStyle: .long)) • Student Progress Tracker"
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
                    value: String(format: "%.1f", overallAverageScore),
                    label: "Average".localized,
                    color: averageColor(overallAverageScore)
                )
                
                Divider()
                    .frame(height: 40)
                
                quickStat(
                    value: "\(scoredResultsForStudent.count)",
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
        StudentProgressOverviewTabView(
            overallAverageScore: overallAverageScore,
            attendancePercentage: attendancePercentage,
            runningRecordCount: runningRecordCount,
            developmentAreaCount: studentDevelopmentScores.count,
            subjectOverviewViewModels: subjectOverviewViewModels,
            recentActivityViewModels: recentActivityViewModels
        )
        .equatable()
    }
    
    // MARK: - Academics Tab
    
    var academicsTab: some View {
        StudentProgressAcademicsTabView(
            overallAverageScore: overallAverageScore,
            scoredResultsCount: scoredResultsForStudent.count,
            subjectSectionViewModels: subjectSectionViewModels
        )
        .equatable()
    }
    
    // MARK: - Attendance Tab
    
    var attendanceTab: some View {
        StudentProgressAttendanceTabView(
            totalSessions: totalSessions,
            presentCount: presentCount,
            absentCount: absentCount,
            lateCount: earlyCount,
            attendancePercentage: attendancePercentage
        )
        .equatable()
    }
    
    // MARK: - Running Records Tab
    
    var runningRecordsTab: some View {
        StudentProgressRunningRecordsTabView(
            runningRecordCount: runningRecordCount,
            averageAccuracy: averageAccuracy,
            latestRunningRecordViewModel: derivedData.latestRunningRecordViewModel,
            runningRecordViewModelsDescending: derivedData.runningRecordViewModelsDescending,
            runningRecordViewModelsAscending: derivedData.runningRecordViewModelsAscending
        )
        .equatable()
    }
    
    var averageAccuracy: Double {
        derivedData.runningRecordAverageAccuracy
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
    
    @MainActor
    private func refreshDerivedData() async {
        let token = await PerformanceMonitor.shared.beginInterval(.studentProgressDerive)
        let derived = await StudentProgressStore.deriveAsync(
            student: student,
            allResults: allResults,
            allAttendanceSessions: allAttendanceSessions,
            allDevelopmentScores: allDevelopmentScores
        )
        if Task.isCancelled {
            await PerformanceMonitor.shared.endInterval(token, success: false)
            return
        }

        derivedData = derived
        await PerformanceMonitor.shared.endInterval(token, success: true)
    }
    
    // MARK: - Development Tab
    
    var studentDevelopmentScores: [DevelopmentScore] {
        derivedData.studentDevelopmentScores
    }
    
    var latestDevelopmentScores: [DevelopmentScore] {
        derivedData.latestDevelopmentScores
    }

    var developmentCategoryViewModels: [StudentProgressDevelopmentCategoryViewModel] {
        derivedData.developmentCategoryViewModels
    }
    
    var developmentTab: some View {
        StudentProgressDevelopmentTabView(
            latestTrackedCount: latestDevelopmentScores.count,
            totalUpdatesCount: studentDevelopmentScores.count,
            developmentCategoryViewModels: developmentCategoryViewModels
        )
        .equatable()
        .environmentObject(languageManager)
    }

    func groupedDevelopmentScores() -> [(category: String, scores: [StudentProgressDevelopmentScoreViewModel])] {
        developmentCategoryViewModels.map { group in
            (category: group.category, scores: group.scores)
        }
    }

    func displayRubricText(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return value }
        let localized = languageManager.localized(trimmed)
        if localized != trimmed { return localized }
        return RubricLocalization.localized(trimmed, languageCode: languageManager.currentLanguage.rawValue)
    }
    
    func developmentCategorySection(category: String, scores: [StudentProgressDevelopmentScoreViewModel]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(displayRubricText(category))
                .font(.headline)
                .foregroundColor(.pink)
            
            ForEach(scores) { score in
                developmentScoreCard(score)
            }
        }
        .padding()
        .background(Color.pink.opacity(0.05))
        .cornerRadius(12)
    }
    
    func developmentScoreCard(_ score: StudentProgressDevelopmentScoreViewModel) -> some View {
        let color = ratingColor(for: score.rating)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(displayRubricText(score.criterionName))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                // Star rating
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= score.rating ? "star.fill" : "star")
                            .font(.caption)
                            .foregroundColor(star <= score.rating ? color : .gray.opacity(0.3))
                    }
                }
            }
            
            // Rating label
            Text(score.ratingLabel)
                .font(.caption)
                .foregroundColor(color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color.opacity(0.15))
                .cornerRadius(6)
            
            if !score.notes.isEmpty {
                Divider()
                
                Text(score.notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text(score.date.appDateString)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    func ratingColor(for rating: Int) -> Color {
        switch rating {
        case 5: return .green
        case 4: return .blue
        case 3: return .orange
        case 2: return .yellow
        case 1: return .red
        default: return .gray
        }
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
    
    func subjectSection(subject: StudentProgressSubjectSectionViewModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(subject.subjectName)
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Text("\(subject.assessmentCount) assessments")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(String(format: "%.1f", subject.averageScore))
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(averageColor(subject.averageScore))
            }
            
            if !subject.units.isEmpty {
                Divider()
                
                Text("Units")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                
                ForEach(subject.units) { unitSummary in
                    unitRow(unitSummary: unitSummary)
                }
            }
        }
        .padding()
        .background(cardBackgroundColor)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    func unitRow(unitSummary: StudentProgressUnitRowViewModel) -> some View {
        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(unitSummary.unitName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(unitSummary.criteriaCount) criteria")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(String(format: "%.1f", unitSummary.averageScore))
                .font(.headline)
                .foregroundColor(averageColor(unitSummary.averageScore))
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
