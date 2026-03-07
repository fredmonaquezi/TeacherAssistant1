# Refactor PR Gate Checklist

Use this checklist on every refactor PR. All items must pass before merge.

## Required Gates

- [ ] `bash docs/scripts/health_check.sh` passes with `0 failed`
- [ ] warning scan is clean (no new warnings outside allowlist)
- [ ] no new direct `context.save()` call sites are introduced
- [ ] durability tests pass
- [ ] performance tests pass
- [ ] backup restore path still validates and imports correctly
- [ ] startup recovery mode still works for failed primary-store open

## Reliability Checks

- [ ] save failures route through shared save/reliability handling
- [ ] user-facing error messages remain actionable and non-silent
- [ ] no data-loss behavior introduced in backup/export/import code paths

## Performance Checks

- [ ] changed screens keep derivation/debounce behavior
- [ ] no obvious main-thread heavy work added in interactive paths
- [ ] `ViewBudget` thresholds remain satisfied by test suite

## Scope Checks

- [ ] ticket IDs referenced in PR description
- [ ] migration risk and rollback note included for data-layer changes
- [ ] manual smoke notes added when UI behavior changed
