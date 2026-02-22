# iOS Parity Phase 0 Checklist

## Baseline Snapshot
- Captured at (UTC): 2026-02-20T08:57:27Z
- Baseline commit: `3fd0db9e63cbc299ef3283c8cab81561d7b4b0ee`
- Working branch: `codex/ios-parity-phase0`
- Notes: Repository already had local uncommitted changes when Phase 0 started.

## Step 0.1: Branch and Checkpoint
- [x] Create dedicated parity branch (`codex/ios-parity-phase0`).
- [x] Create/confirm git checkpoint tag for this baseline.

## Step 0.2: Backup Safety Gate (Required Before Model Changes)
- [x] Export full in-app backup from Dashboard -> Backup.
- [x] Save backup file outside the project workspace.
- [x] Perform one restore dry-run on a non-production copy (or secondary device/simulator).
- [x] Confirm restore includes classes, students, assessments, attendance, running records, rubrics, calendar entries.

## Step 0.3: Pre-Migration Smoke Checklist
- [ ] Classes: create, edit, delete class.
- [ ] Students: add/edit student, status flags, open detail.
- [ ] Gradebook: create subject/unit/assessment, enter scores, view averages.
- [ ] Attendance: create session, mark statuses, add notes.
- [ ] Groups: generate with advanced options, verify separation behavior.
- [ ] Running Records: create record and verify level/accuracy calculations.
- [ ] Rubrics: create/edit template and criteria; add development score.
- [ ] Calendar: create diary entry and event; verify day detail.
- [ ] Library/PDF: import PDF, tag to subject/unit, open item.
- [ ] Backup/Restore controls visible and functioning.

## Step 0.4: Parity Scope Confirmation
- [ ] Confirm P1 scope: assessment max score + percent grading, school year, improved grouping logic, running record filter/export parity.
- [ ] Confirm P2 scope (optional): profile/preferences parity.
- [ ] Confirm deferred scope: auth/cloud sync.

## Current Working Tree (Captured at Phase 0 Start)
```text
M App/AdvancedGroupGeneratorView.swift
M App/AttendanceSessionView.swift
M App/ContentView.swift
M App/StudentReportExporter_macOS_NEW.swift
M App/TeacherAssistantApp.swift
M Attendance/Models/AttendanceRecord.swift
M Attendance/Views/AttendanceListView.swift
M BackupManager.swift
M BackupModels.swift
M Calendar/Views/CalendarRootView.swift
M "Classes Overview/ClassOverviewView.swift"
M Classes/Views/ClassPickerView.swift
M Library/Views/NavigationHeaderView.swift
M Mac/MacNavigationState.swift
M Students/Views/SimplePDFExporter.swift
M Students/Views/StudentDetailView.swift
M Students/Views/StudentProgressView.swift
M Students/Views/StudentReportExporter.swift
?? ../TeacherAssistant.zip
```
