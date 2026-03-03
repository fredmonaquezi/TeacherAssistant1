# Offline Web-to-Native Parity Matrix

Date: 2026-03-03
Branch: `codex/offline-parity-matrix`

## Scope

This matrix treats the web app as the workflow reference for offline teaching features only.

Included:
- dashboard and navigation
- classes, students, attendance
- assessments, subjects, units
- rubrics
- groups
- random picker
- timer
- running records
- calendar
- useful links
- local preferences

Explicitly excluded:
- auth and sign-in
- password reset
- profile/account metadata synced to a backend
- cloud sync
- Supabase loading architecture

## Status Legend

- `Matched`: native feature exists and no known parity gap is currently identified.
- `Partial`: native feature exists, but there is known behavior, data, or UX work left.
- `Missing`: no native equivalent exists yet.

## Route Matrix

| Web Route | Web Surface | Native Surface | Status | Current Gap | Primary Native Files |
| --- | --- | --- | --- | --- | --- |
| `/` | Dashboard | Dashboard section | Partial | Core dashboard exists and now exposes Useful Links. Remaining work is the final workflow-level audit across the other parity features. | `Dashboard/DashboardView.swift`, `App/ContentView.swift` |
| `/classes` | Classes list | Classes section | Partial | Existing feature is present; needs route-by-route audit against web sort, create/delete, and summary behavior. | `Classes/Views/ClassesView.swift`, `Shared/AddClassView.swift` |
| `/classes/:classId` | Class detail | Class detail | Partial | Existing feature is present; needs parity audit for student ordering, subject creation, and linked drill-down behavior. | `Classes/Views/ClassDetailView.swift`, `Classes/Views/StudentCardView.swift` |
| `/students/:studentId` | Student detail | Student detail | Partial | Existing feature is present; needs parity audit for combined progress, attendance, running records, and rubric/development score behavior. | `Students/Views/StudentDetailView.swift`, `Students/Views/StudentProgressView.swift` |
| `/attendance` | Attendance sessions list | Attendance picker plus session list | Partial | Existing feature is present, but needs a parity pass for session creation flow, class selection behavior, and deletion UX. | `Classes/Views/ClassPickerView.swift`, `Attendance/Views/AttendanceListView.swift` |
| `/attendance/:sessionId` | Attendance session detail | Attendance session detail | Partial | Existing feature is present; needs parity audit for status editing, notes, and per-student row behavior. | `App/AttendanceSessionView.swift` |
| `/assessments` | Assessment overview | Gradebook picker plus overview | Partial | Existing feature is present, but the navigation path differs from web and needs a parity pass for listing, filters, and aggregate summaries. | `Classes/Views/ClassPickerView.swift`, `Dashboard/GradebookLauncherView.swift`, `Classes/UnitGradebookView.swift` |
| `/assessments/:assessmentId` | Assessment detail | Assessment detail | Matched | Score entry, percent/max-score math, graded-state handling, and aggregate displays are aligned for the offline workflow. Keep regression validation in smoke tests. | `Assessments/Views/AssessmentDetailView.swift`, `Assessments/Views/Averages.swift`, `Classes/ScoreEntrySheet.swift` |
| `/subjects/:subjectId` | Subject detail | Subject detail | Partial | Existing feature is present; needs parity audit for unit ordering, unit creation, and drill-down behavior. | `Classes/Views/SubjectDetailView.swift` |
| `/units/:unitId` | Unit detail | Unit detail | Partial | Existing feature is present; assessment creation and copy flows already exist, but need parity verification against web behavior. | `Classes/Views/UnitDetailView.swift`, `Classes/CopyCriteriaSheet.swift` |
| `/rubrics` | Rubric templates and criteria | Rubric manager | Partial | Existing feature is present; needs parity audit for seed, create, edit, delete-all, and criterion management flows. | `Students/Rubrics/RubricTemplateView.swift`, `Students/Rubrics/RubricTemplateEditorView.swift`, `Students/Rubrics/DefaultRubricTemplates.swift` |
| `/groups` | Group generator | Group generator | Matched | Native now derives grouping inputs from assessment performance, aligning ability balancing and support-partner eligibility with the offline web workflow. Keep deterministic test coverage as follow-up hardening. | `App/AdvancedGroupGeneratorView.swift`, `Shared/GroupingEngine.swift`, `Shared/GroupingAbilityProfileBuilder.swift` |
| `/random` | Random picker | Random picker | Partial | Existing feature is present, but native uses `AppStorage`-based category/rotation persistence and should be checked against web category and rotation behavior. | `Tools/RandomPicker/RandomPickerLauncherView.swift` |
| `/timer` | Timer | Timer | Matched | Feature set appears aligned at a high level; keep only regression validation in the final smoke pass. | `Timer/TimerPickerView.swift`, `Timer/ClassroomTimerManager.swift`, `Timer/TimerOverlayView.swift` |
| `/running-records` | Running records | Running records | Matched | Native now covers the web workflow filters, sort controls, edit/delete flow, export paths, and book-level support for offline use. Keep manual smoke validation for live store migration and export round-trips. | `Library/Views/RunningRecordsView.swift`, `Library/Views/AddRunningRecordView.swift`, `Library/Views/RunningRecordsExportUtility.swift` |
| `/calendar` | Calendar | Calendar | Partial | Existing feature is present; needs parity audit for diary entries, events, day detail editing, and filtering. | `Calendar/Views/CalendarRootView.swift` |
| `/useful-links` | Useful links | Useful Links section | Matched | Native now supports local create, edit, delete, reorder, open-link, and backup/restore for Useful Links. | `UsefulLinks/Views/UsefulLinksView.swift`, `UsefulLinks/Models/UsefulLink.swift`, `BackupManager.swift` |
| `/profile` | Profile plus preferences | Preferences only | Matched | Native intentionally replaces web Profile with local Preferences only, including date/time formatting controls, default landing behavior, immediate refresh, and restore-aware startup handling. | `Shared/PreferencesView.swift`, `Shared/AppPreferences.swift`, `App/ContentView.swift` |

## Cross-Cutting Gaps

### 1. Group Logic Contract

Completed in Phase 1 on this branch.

Web reference:
- `src/hooks/workspace/groupingEngine.js`
- `src/hooks/workspace/actions/groupActions.js`

Native current implementation:
- `Shared/GroupingEngine.swift`
- `App/AdvancedGroupGeneratorView.swift`
- `Students/Models/Student.swift`

Implemented native change:
- kept the stronger native engine structure
- replaced behavior-flag grouping inputs with assessment-derived ability and support-partner profiles
- preserved separation handling and fallback messaging already present in the native engine

### 2. Assessment Calculation Contract

Completed in Phase 1 on this branch.

Native already contains the right building blocks:
- `Assessments/Views/Averages.swift`
- `Assessments/Models/Assessment.swift`
- `Classes/ScoreEntrySheet.swift`

Implemented native change:
- normalized percent/max-score math across gradebook views
- introduced explicit graded-state tracking so `0` is a valid score and blank remains ungraded
- aligned summary/export/report surfaces to count only truly graded results

### 3. Running Records Verification

Completed on this branch during Phase 3.

Validated and aligned:
- class filter
- student filter
- level filter
- date range
- search
- sort
- PDF, CSV, and JSON exports
- book-level capture, display, edit, backup, and PDF output

### 4. Useful Links Data and Backup

Completed in Phase 2 on this branch.

Implemented native change:
- added a local `UsefulLink` SwiftData model
- added create, edit, delete, reorder, and open-link actions
- included useful links in backup export/import so the feature is not a parity outlier

### 5. Preferences as the Offline Replacement for Profile

Completed on this branch during Phase 3.

Native should not copy the web account-management parts of Profile.
It should only keep:
- date format
- time format
- default landing destination

Implemented native change:
- preferences now include a live format preview for date and time
- changing date/time preferences triggers an app refresh so shared-format screens update immediately
- default landing behavior is applied on launch and re-applied after backup restore

## Implementation Order

1. Run a full macOS and iOS smoke pass for every in-scope workflow.

## First Files To Change

### Phase 3: Verification and Hardening

- `Assessments/Views/Averages.swift`
- `Assessments/Views/AssessmentDetailView.swift`
- `Classes/ScoreEntrySheet.swift`
- `Library/Views/RunningRecordsView.swift`
- `Calendar/Views/CalendarRootView.swift`

## Phase 1 Completion

Phase 1 is complete on this branch.

Delivered:
- grouping parity now uses assessment-derived profiles through `Shared/GroupingAbilityProfileBuilder.swift`
- assessment parity now distinguishes ungraded from explicit zero scores
- grade summaries, student reports, and PDF exports now only count truly graded results
- backup export/import preserves the new graded-state contract

Validation completed:
- macOS build succeeded via `xcodebuild -project ../TeacherAssistant.xcodeproj -scheme TeacherAssistant -configuration Debug -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO`
- iOS build succeeded via `xcodebuild -project ../TeacherAssistant.xcodeproj -scheme TeacherAssistant -configuration Debug -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO`

Known caveat:
- legacy records that previously stored `0` without explicit graded-state metadata will still read as ungraded until edited or re-imported from a newer backup

## Phase 2 Completion

Phase 2 is complete on this branch.

Delivered:
- Useful Links now has a native offline section with local persistence
- the feature is wired into dashboard and top-level navigation
- Useful Links now round-trips through backup export/import

Validation completed:
- macOS build succeeded via `xcodebuild -project ../TeacherAssistant.xcodeproj -scheme TeacherAssistant -configuration Debug -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO`
- iOS build succeeded via `xcodebuild -project ../TeacherAssistant.xcodeproj -scheme TeacherAssistant -configuration Debug -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO`

## Definition of Done

Offline parity is complete when:
- every in-scope web workflow has a native equivalent
- Useful Links exists locally in native
- group generation behavior matches the web rules at the input/decision level
- assessment percentages and max-score behavior are consistent across native views
- all in-scope data survives backup and restore
- macOS and iOS smoke checks pass for the full offline workflow set
