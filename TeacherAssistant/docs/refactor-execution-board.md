# Refactor Execution Board

Last updated: 2026-03-07
Branch: `main`
Baseline commit: `63e9b21`

## Sprint 1 (Phase 0 + Reliability setup)

| ID | Priority | Track | Ticket | Estimate | Depends On | Status |
| --- | --- | --- | --- | --- | --- | --- |
| TA-001 | P0 | Reliability | Baseline health snapshot and freeze metrics | 0.5d | - | Completed |
| TA-002 | P0 | Reliability | Add refactor gate doc with pass/fail checklist | 0.5d | TA-001 | Completed |
| TA-003 | P0 | Reliability | Inventory all direct `context.save()` call sites | 0.5d | TA-001 | Completed |
| TA-101 | P0 | Reliability | Migrate Useful Links write path to `SaveCoordinator` | 0.5d | TA-003 | Completed |
| TA-102 | P0 | Reliability | Migrate `DevelopmentScoreMaintenanceService` writes to coordinator path | 0.5d | TA-003 | Completed |
| TA-103 | P0 | Reliability | Migrate `DuplicateStudentCleanupService` writes to coordinator path | 0.5d | TA-003 | Completed |
| TA-104 | P0 | Reliability | Add guard script to fail on unauthorized direct saves | 0.5d | TA-101 | Completed |
| TA-105 | P0 | Reliability | Define typed app error model for persistence/backup/recovery | 1d | TA-101 | Completed |

## Sprint 2 (Performance + backup hardening)

| ID | Priority | Track | Ticket | Estimate | Depends On | Status |
| --- | --- | --- | --- | --- | --- | --- |
| TA-201 | P0 | Reliability | Extract backup decode/validate/apply services from monolith | 2d | TA-105 | Completed |
| TA-202 | P0 | Reliability | Add backup import integration tests for rollback + safety snapshot | 1d | TA-201 | Completed |
| TA-203 | P1 | Reliability | Add startup recovery integration tests for corrupted store path | 1d | TA-201 | Completed |
| TA-301 | P1 | Performance | Create shared derivation runner utility | 1d | TA-001 | Completed |
| TA-302 | P1 | Performance | Adopt derivation runner in Student Progress store/view | 1.5d | TA-301 | Completed |
| TA-303 | P1 | Performance | Adopt derivation runner in Calendar + Student Detail + Library + Running Records stores | 2d | TA-301 | Completed |
| TA-304 | P1 | Performance | Strengthen performance tests with regression thresholds per store | 1d | TA-303 | Completed |

## Sprint 3 (Decomposition + release hardening)

| ID | Priority | Track | Ticket | Estimate | Depends On | Status |
| --- | --- | --- | --- | --- | --- | --- |
| TA-401 | P1 | Maintainability | Split `StudentProgressView` into section components + action coordinator | 2d | TA-302 | Completed |
| TA-402 | P1 | Maintainability | Split `CalendarRootView` into header/filter/sheet modules | 1.5d | TA-303 | Completed |
| TA-403 | P1 | Maintainability | Split `LibraryGrids` into card/renderer/action files | 2d | TA-303 | Completed |
| TA-404 | P1 | Maintainability | Refactor `ContentView` routing into section coordinator | 1.5d | TA-402 | Completed |
| TA-501 | P2 | Reliability | Introduce schema v2 + migration test harness scaffold | 1d | TA-203 | Completed |
| TA-502 | P2 | Reliability | Expand backup stress fixture coverage in durability tests | 1d | TA-202 | Completed |
| TA-503 | P2 | Release | Final smoke checklist and sign-off run | 1d | All | Completed |
