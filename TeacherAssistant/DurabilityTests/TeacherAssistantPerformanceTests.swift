#if DURABILITY_TESTS
import XCTest

@testable import TeacherAssistant

final class TeacherAssistantPerformanceTests: XCTestCase {
    private enum PerformanceRegressionBudget {
        static let runningRecordsDeriveMilliseconds: Double = 180
        static let calendarDeriveMilliseconds: Double = 140
        static let calendarDayLookupMilliseconds: Double = 140
        static let studentDetailDeriveMilliseconds: Double = 220
        static let studentProgressDeriveMilliseconds: Double = 260
    }

    @MainActor
    func testRunningRecordsDeriveCompletesWithinBudget() {
        let fixture = makeRunningRecordsFixture(classCount: 12, studentsPerClass: 20, recordsPerStudent: 4)

        let measurement = measureMedianMilliseconds {
            RunningRecordsStore.derive(
                allStudents: fixture.students,
                allRunningRecords: fixture.records,
                selectedClass: fixture.classes.first,
                selectedStudent: nil,
                filterLevel: .instructional,
                selectedDateRange: .last90Days,
                customDateStart: Date().addingTimeInterval(-60 * 60 * 24 * 90),
                customDateEnd: Date(),
                sortOption: .dateDescending,
                searchText: "record"
            )
        }

        assertWithinRegressionThreshold(
            measurement.elapsedMilliseconds,
            threshold: PerformanceRegressionBudget.runningRecordsDeriveMilliseconds,
            operationName: "RunningRecordsStore.derive"
        )
        let derived = measurement.result
        XCTAssertFalse(derived.classOptions.isEmpty)
    }

    @MainActor
    func testCalendarDeriveCompletesWithinBudget() {
        let schoolClass = SchoolClass(name: "Room 12", grade: "4")
        let entries = (0..<240).map { offset in
            ClassDiaryEntry(
                date: Date().addingTimeInterval(Double(offset) * 86_400),
                startTime: nil,
                endTime: nil,
                plan: "Plan \(offset)",
                objectives: "Objectives",
                materials: "Materials",
                notes: "Notes",
                schoolClass: schoolClass,
                subject: nil,
                unit: nil
            )
        }
        let events = (0..<240).map { offset in
            CalendarEvent(
                title: "Event \(offset)",
                date: Date().addingTimeInterval(Double(offset) * 86_400),
                startTime: nil,
                endTime: nil,
                details: "Details",
                isAllDay: false,
                schoolClass: schoolClass
            )
        }

        let measurement = measureMedianMilliseconds {
            CalendarStore.derive(
                classes: [schoolClass],
                diaryEntries: entries,
                events: events,
                selectedClassID: schoolClass.persistentModelID
            )
        }

        assertWithinRegressionThreshold(
            measurement.elapsedMilliseconds,
            threshold: PerformanceRegressionBudget.calendarDeriveMilliseconds,
            operationName: "CalendarStore.derive"
        )
        let derived = measurement.result
        XCTAssertEqual(derived.filteredEvents.count, events.count)
        XCTAssertEqual(derived.filteredDiaryEntries.count, entries.count)
    }

    @MainActor
    func testCalendarDayMapLookupCompletesWithinBudget() {
        let schoolClass = SchoolClass(name: "Room 20", grade: "5")
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: Date())

        var entries: [ClassDiaryEntry] = []
        var events: [CalendarEvent] = []

        for dayOffset in 0..<365 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: startDay) else { continue }
            for slot in 0..<3 {
                let entryDate = day.addingTimeInterval(Double(slot) * 3_600)
                entries.append(
                    ClassDiaryEntry(
                        date: entryDate,
                        startTime: entryDate,
                        endTime: entryDate.addingTimeInterval(2_700),
                        plan: "Plan \(dayOffset)-\(slot)",
                        objectives: "Objectives",
                        materials: "Materials",
                        notes: "Notes",
                        schoolClass: schoolClass,
                        subject: nil,
                        unit: nil
                    )
                )
            }

            for slot in 0..<2 {
                let eventDate = day.addingTimeInterval(Double(slot) * 7_200)
                events.append(
                    CalendarEvent(
                        title: "Event \(dayOffset)-\(slot)",
                        date: eventDate,
                        startTime: eventDate,
                        endTime: eventDate.addingTimeInterval(1_800),
                        details: "Details",
                        isAllDay: false,
                        schoolClass: schoolClass
                    )
                )
            }
        }

        let derived = CalendarStore.derive(
            classes: [schoolClass],
            diaryEntries: entries,
            events: events,
            selectedClassID: schoolClass.persistentModelID
        )

        let visibleDays = (0..<365).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: startDay)
        }

        let measurement = measureMedianMilliseconds {
            var resolvedCount = 0
            for day in visibleDays {
                let normalizedDay = calendar.startOfDay(for: day)
                resolvedCount += derived.diaryEntriesByDay[normalizedDay]?.count ?? 0
                resolvedCount += derived.eventsByDay[normalizedDay]?.count ?? 0
            }
            return resolvedCount
        }

        assertWithinRegressionThreshold(
            measurement.elapsedMilliseconds,
            threshold: PerformanceRegressionBudget.calendarDayLookupMilliseconds,
            operationName: "CalendarStore day map lookup"
        )
        XCTAssertEqual(measurement.result, entries.count + events.count)
    }

    @MainActor
    func testStudentDetailDeriveCompletesWithinBudget() {
        let fixture = makeStudentAnalyticsFixture(
            studentsInClass: 28,
            subjectsPerClass: 6,
            unitsPerSubject: 4,
            assessmentsPerUnit: 4,
            attendanceSessionCount: 120,
            runningRecordsPerStudent: 10,
            developmentCategories: 4,
            criteriaPerCategory: 5,
            scoreRevisionsPerCriterion: 2
        )

        let measurement = measureMedianMilliseconds {
            StudentDetailStore.derive(
                student: fixture.targetStudent,
                allResults: fixture.allResults,
                allAttendanceSessions: fixture.allAttendanceSessions,
                allScores: fixture.allDevelopmentScores
            )
        }

        assertWithinRegressionThreshold(
            measurement.elapsedMilliseconds,
            threshold: PerformanceRegressionBudget.studentDetailDeriveMilliseconds,
            operationName: "StudentDetailStore.derive"
        )
        let derived = measurement.result
        XCTAssertEqual(derived.subjectSummaries.count, 6)
        XCTAssertFalse(derived.recentResults.isEmpty)
    }

    @MainActor
    func testStudentProgressDeriveCompletesWithinBudget() {
        let fixture = makeStudentAnalyticsFixture(
            studentsInClass: 28,
            subjectsPerClass: 6,
            unitsPerSubject: 4,
            assessmentsPerUnit: 4,
            attendanceSessionCount: 120,
            runningRecordsPerStudent: 10,
            developmentCategories: 4,
            criteriaPerCategory: 5,
            scoreRevisionsPerCriterion: 2
        )

        let measurement = measureMedianMilliseconds {
            StudentProgressStore.derive(
                student: fixture.targetStudent,
                allResults: fixture.allResults,
                allAttendanceSessions: fixture.allAttendanceSessions,
                allDevelopmentScores: fixture.allDevelopmentScores,
                allLiveObservations: []
            )
        }

        assertWithinRegressionThreshold(
            measurement.elapsedMilliseconds,
            threshold: PerformanceRegressionBudget.studentProgressDeriveMilliseconds,
            operationName: "StudentProgressStore.derive"
        )
        let derived = measurement.result
        XCTAssertEqual(derived.subjectSummaries.count, 6)
        XCTAssertEqual(derived.runningRecordsDescending.count, 10)
        XCTAssertFalse(derived.groupedLatestDevelopmentScores.isEmpty)
    }

    private func measureMedianMilliseconds<T>(
        sampleCount: Int = 7,
        operation: () -> T
    ) -> (elapsedMilliseconds: Double, result: T) {
        precondition(sampleCount > 0, "sampleCount must be greater than zero")

        // Warm up paths before collecting timings to reduce first-hit noise.
        var latestResult = operation()
        var samples: [Double] = []
        samples.reserveCapacity(sampleCount)

        for _ in 0..<sampleCount {
            let start = ContinuousClock().now
            latestResult = operation()
            let elapsed = start.duration(to: ContinuousClock().now)
            samples.append(milliseconds(from: elapsed))
        }

        let medianMilliseconds = samples.sorted()[sampleCount / 2]
        return (medianMilliseconds, latestResult)
    }

    private func assertWithinRegressionThreshold(
        _ elapsedMilliseconds: Double,
        threshold: Double,
        operationName: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertLessThan(
            elapsedMilliseconds,
            threshold,
            "\(operationName) regression threshold exceeded: \(elapsedMilliseconds)ms > \(threshold)ms",
            file: file,
            line: line
        )
    }

    private func milliseconds(from duration: Duration) -> Double {
        Double(duration.components.seconds) * 1000 + Double(duration.components.attoseconds) / 1_000_000_000_000_000
    }

    private func makeRunningRecordsFixture(
        classCount: Int,
        studentsPerClass: Int,
        recordsPerStudent: Int
    ) -> (classes: [SchoolClass], students: [Student], records: [RunningRecord]) {
        var classes: [SchoolClass] = []
        var students: [Student] = []
        var records: [RunningRecord] = []

        for classIndex in 0..<classCount {
            let schoolClass = SchoolClass(name: "Class \(classIndex + 1)", grade: "\((classIndex % 8) + 1)")
            classes.append(schoolClass)

            for studentIndex in 0..<studentsPerClass {
                let student = Student(name: "Student \(classIndex)-\(studentIndex)")
                student.schoolClass = schoolClass
                student.sortOrder = studentIndex
                students.append(student)

                for recordIndex in 0..<recordsPerStudent {
                    let record = RunningRecord(
                        date: Date().addingTimeInterval(Double(-(recordIndex * 86_400))),
                        textTitle: "Record \(recordIndex)",
                        bookLevel: "M",
                        totalWords: 120,
                        errors: recordIndex % 5,
                        selfCorrections: recordIndex % 3,
                        notes: "Fixture note"
                    )
                    record.student = student
                    records.append(record)
                }
            }
        }

        return (classes, students, records)
    }

    private func makeStudentAnalyticsFixture(
        studentsInClass: Int,
        subjectsPerClass: Int,
        unitsPerSubject: Int,
        assessmentsPerUnit: Int,
        attendanceSessionCount: Int,
        runningRecordsPerStudent: Int,
        developmentCategories: Int,
        criteriaPerCategory: Int,
        scoreRevisionsPerCriterion: Int
    ) -> (
        targetStudent: Student,
        allResults: [StudentResult],
        allAttendanceSessions: [AttendanceSession],
        allDevelopmentScores: [DevelopmentScore]
    ) {
        let schoolClass = SchoolClass(name: "Room Perf", grade: "5")
        var students: [Student] = []

        for studentIndex in 0..<studentsInClass {
            let student = Student(name: "Student \(studentIndex + 1)")
            student.sortOrder = studentIndex
            student.schoolClass = schoolClass
            students.append(student)
        }
        schoolClass.students = students
        guard let targetStudent = students.first else {
            fatalError("Fixture must include at least one student")
        }

        var subjects: [Subject] = []
        var assessments: [Assessment] = []
        for subjectIndex in 0..<subjectsPerClass {
            let subject = Subject(name: "Subject \(subjectIndex + 1)")
            subject.sortOrder = subjectIndex
            subject.schoolClass = schoolClass

            var units: [TeacherAssistant.Unit] = []
            for unitIndex in 0..<unitsPerSubject {
                let unit = TeacherAssistant.Unit(name: "Unit \(subjectIndex + 1)-\(unitIndex + 1)")
                unit.sortOrder = unitIndex
                unit.subject = subject

                var unitAssessments: [Assessment] = []
                for assessmentIndex in 0..<assessmentsPerUnit {
                    let assessment = Assessment(
                        title: "Assessment \(subjectIndex + 1)-\(unitIndex + 1)-\(assessmentIndex + 1)",
                        maxScore: 10
                    )
                    assessment.sortOrder = assessmentIndex
                    assessment.unit = unit
                    unitAssessments.append(assessment)
                }
                unit.assessments = unitAssessments
                assessments.append(contentsOf: unitAssessments)
                units.append(unit)
            }

            subject.units = units
            subjects.append(subject)
        }
        schoolClass.subjects = subjects

        var allResults: [StudentResult] = []
        for (studentIndex, student) in students.enumerated() {
            for (assessmentIndex, assessment) in assessments.enumerated() {
                let scoreValue = Double((studentIndex + assessmentIndex) % 11)
                let result = StudentResult(
                    student: student,
                    assessment: assessment,
                    score: scoreValue,
                    notes: "Result note",
                    hasScore: true
                )
                allResults.append(result)
            }
        }

        var allAttendanceSessions: [AttendanceSession] = []
        for sessionIndex in 0..<attendanceSessionCount {
            var records: [AttendanceRecord] = []
            for (studentIndex, student) in students.enumerated() {
                let status: AttendanceStatus
                switch (sessionIndex + studentIndex) % 4 {
                case 0:
                    status = .present
                case 1:
                    status = .late
                case 2:
                    status = .absent
                default:
                    status = .leftEarly
                }
                records.append(AttendanceRecord(student: student, status: status, notes: ""))
            }
            let sessionDate = Date().addingTimeInterval(Double(-sessionIndex) * 86_400)
            allAttendanceSessions.append(AttendanceSession(date: sessionDate, records: records))
        }

        var allDevelopmentScores: [DevelopmentScore] = []
        for categoryIndex in 0..<developmentCategories {
            let category = RubricCategory(name: "Category \(categoryIndex + 1)")
            category.sortOrder = categoryIndex

            var criteria: [RubricCriterion] = []
            for criterionIndex in 0..<criteriaPerCategory {
                let criterion = RubricCriterion(name: "Criterion \(categoryIndex + 1)-\(criterionIndex + 1)")
                criterion.sortOrder = criterionIndex
                criterion.category = category
                criteria.append(criterion)
            }
            category.criteria = criteria

            for criterion in criteria {
                for (studentIndex, student) in students.enumerated() {
                    for revision in 0..<scoreRevisionsPerCriterion {
                        let rating = ((studentIndex + revision) % 5) + 1
                        let scoreDate = Date().addingTimeInterval(Double(-(revision + studentIndex)) * 86_400)
                        allDevelopmentScores.append(
                            DevelopmentScore(
                                student: student,
                                criterion: criterion,
                                rating: rating,
                                notes: "Score note",
                                date: scoreDate
                            )
                        )
                    }
                }
            }
        }

        for (studentIndex, student) in students.enumerated() {
            var records: [RunningRecord] = []
            for recordIndex in 0..<runningRecordsPerStudent {
                let record = RunningRecord(
                    date: Date().addingTimeInterval(Double(-(recordIndex + studentIndex)) * 86_400),
                    textTitle: "Text \(recordIndex + 1)",
                    bookLevel: "M",
                    totalWords: 120,
                    errors: recordIndex % 7,
                    selfCorrections: recordIndex % 4,
                    notes: "Record note"
                )
                record.student = student
                records.append(record)
            }
            student.runningRecords = records
        }

        return (
            targetStudent: targetStudent,
            allResults: allResults,
            allAttendanceSessions: allAttendanceSessions,
            allDevelopmentScores: allDevelopmentScores
        )
    }
}
#endif
