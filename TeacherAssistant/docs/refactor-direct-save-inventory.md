# Direct `context.save()` Inventory

Generated: 2026-03-07 (updated after TA-201)  
Goal: remove non-framework direct saves from feature/service code and route through coordinated save handling where appropriate.

## Current Direct Save Call Sites (3)

1. `BackupManager.swift:148`
- Location: backup export preflush in `encodedBackupData(from:)`
- Intent: ensure pending UI edits are included before export fetches
- Owner ticket: TA-201
- Migration note: retained intentionally as pre-export consistency boundary.

2. `Shared/BackupImportServices.swift:451`
- Location: final persist in `BackupPayloadApplyService.apply(_:to:clearExistingData:)`
- Intent: atomic end-of-restore commit
- Owner ticket: TA-201
- Migration note: retained intentionally as the restore-persistence boundary after TA-201 extraction.

3. `Shared/SaveCoordinator.swift:56`
- Location: canonical save implementation `saveResult(...)`
- Intent: framework-authorized save boundary
- Owner ticket: TA-104 (allowlist rule)
- Migration note: keep as canonical direct-save site.

## Resolved

- TA-101: `UsefulLinks/Views/UsefulLinksView.swift` now uses `SaveCoordinator` with explicit save reasons for create/edit/delete/reorder.
- TA-102: `Shared/DevelopmentScoreMaintenanceService.swift` now uses `SaveCoordinator.saveResult(...)` and throws a localized error on coordinated save failure.
- TA-103: `Shared/DuplicateStudentCleanupService.swift` now uses `SaveCoordinator.saveResult(...)` and throws a localized error on coordinated save failure.
- TA-201: backup decode/validate/apply logic extracted from `BackupManager` into `Shared/BackupImportServices.swift`.

## Guard Rule Status (TA-104)

Implemented in `docs/scripts/health_check.sh` as `Direct save guard`.

Current allowlist in `docs/scripts/direct_save_allowlist.txt`:

- `Shared/SaveCoordinator.swift`
- `BackupManager.swift`
- `Shared/BackupImportServices.swift`
