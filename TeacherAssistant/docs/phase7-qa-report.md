# Phase 7 QA Report (v1.1 Parity)

Date: 2026-02-22
Branch: `codex/ios-parity-phase0`

## 1) Migration Verification

Status: `PASS` (automated checks)

- Verified that current app builds and launches model code successfully on both platforms (see build validation below).
- Verified that legacy backup payloads (pre-parity format with top-level `classes`) decode with current backup models.
- Added and executed repeatable verifier:
  - Script: `docs/scripts/verify_backup_compat.swift`
  - Compile/run command:
    - `swiftc -DBACKUP_VERIFY BackupModels.swift docs/scripts/verify_backup_compat.swift -o /tmp/verify_backup_compat && /tmp/verify_backup_compat`
  - Result: `PASS`
- Note: verifier entrypoint is gated by compile flag `BACKUP_VERIFY` to avoid app-target duplicate `@main`.

Note:
- Direct runtime verification of an existing on-disk SwiftData store from an older app binary requires opening that exact user store in-app (GUI/manual step). This cannot be fully automated in this environment.

## 2) Backup Restore Compatibility

Status: `PASS` (decode-compatibility verification)

Verified pre-parity backups from `/Users/fred/Documents/BACKUP`:
- `TeacherAssistant-2026-01-29-0927.backup`
- `TeacherAssistant-2026-01-29-0935.backup`
- `TeacherAssistant-2026-01-29-1411.backup`
- `Correct Backup`
- `Correct Backup2`
- `Correct backup 3`

All decoded successfully with current `BackupModels.swift`.

Verified post-parity path:
- Generated schema-v3 fixture at `/tmp/TeacherAssistant-v1_1-schema3-fixture.backup` and decoded successfully with versioned model.

## 3) Regression/Build Validation

Status: `PASS`

Executed:
- `xcodebuild -project ../TeacherAssistant.xcodeproj -scheme TeacherAssistant -configuration Debug -destination 'platform=macOS' build CODE_SIGNING_ALLOWED=NO`
- `xcodebuild -project ../TeacherAssistant.xcodeproj -scheme TeacherAssistant -configuration Debug -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO`

Results:
- macOS: `BUILD SUCCEEDED`
- iOS: `BUILD SUCCEEDED`
- Build warning cleanup: removed stale `LIBRARY_SEARCH_PATHS` entry pointing to `teacher-assistant-web/node_modules/@rollup/rollup-darwin-arm64`.

## 4) Manual Release Checklist

Status legend:
- `[x]` done in this phase
- `[ ]` pending in-app/manual execution

- [x] Build passes (macOS + iOS)
- [x] Legacy backup decode compatibility
- [x] Versioned backup decode compatibility
- [ ] Open app with real pre-parity user store and confirm all classes/students/assessments load
- [ ] In-app restore from a pre-parity backup and verify data integrity
- [ ] In-app restore from a post-parity backup and verify data integrity
- [ ] Smoke test critical flows:
  - [ ] Navigation/back behavior
  - [ ] Gradebook percentages/maxScore behavior
  - [ ] Groups generation constraints/fallback messaging
  - [ ] Running Records filters/sort/export (PDF/CSV/JSON)
  - [ ] Preferences date/time/default landing section persistence

## 5) Regressions Fixed During QA Window

- No new functional regressions identified in this Phase 7 pass.
- Previously identified warning-only issues were cleaned in Phase 6.1C.
