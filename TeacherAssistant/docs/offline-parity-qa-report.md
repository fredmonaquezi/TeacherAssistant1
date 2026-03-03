# Offline Parity QA Report

Date: 2026-03-03
Branch: `codex/offline-parity-matrix`

## Automated Verification Completed

- macOS debug build passed:
  - `xcodebuild -project ../TeacherAssistant.xcodeproj -scheme TeacherAssistant -configuration Debug -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO`
- iOS debug build passed:
  - `xcodebuild -project ../TeacherAssistant.xcodeproj -scheme TeacherAssistant -configuration Debug -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO`
- Backup compatibility harness passed:
  - compiled with `swiftc -module-cache-path /tmp/swift-module-cache -DBACKUP_VERIFY BackupModels.swift docs/scripts/verify_backup_compat.swift -o /tmp/verify_backup_compat`
  - executed `/tmp/verify_backup_compat`
  - result: legacy backups decoded successfully and the schema-3 fixture decode passed

## In-Scope Features Verified by Code + Build

- Group generation parity
- Assessment scored/ungraded parity
- Useful Links local CRUD + backup schema wiring
- Running Records filters/export/book-level/edit flow
- Preferences refresh behavior and default-landing restore handling

## Manual Smoke Pass Still Required

The following items still require live interaction in the macOS and/or iOS app:

- create, edit, delete, and reorder Useful Links
- open a Useful Link externally
- create and edit a Running Record with and without book level
- export Running Records as PDF, CSV, and JSON from the UI
- change date/time/default landing preferences and confirm immediate refresh
- perform a real backup export + restore round-trip from the UI
- run a full workflow pass across classes, attendance, gradebook, groups, random picker, timer, running records, and calendar

## Current Limit

This environment can validate builds and local scripts, but it cannot perform the live GUI interactions needed for the final manual smoke pass.
