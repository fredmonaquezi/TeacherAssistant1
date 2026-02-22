# Teacher Assistant v1.1 - iOS/Web Parity Update

Release date: 2026-02-22

## Highlights

- iOS parity pass completed against the web app baseline.
- Navigation behavior improved for deeper flows.
- Gradebook and assessment calculations aligned around percent-based behavior.
- Class metadata parity added with `schoolYear`.
- Group generator logic extracted and upgraded for constraint handling.
- Running Records expanded with filtering/sorting and additional export formats.
- New lightweight Preferences screen for date/time formatting and default landing section.

## What Is New

### 1) Data and Reliability Foundation

- Backup/import stability improvements across legacy and versioned formats.
- Compatibility handling for legacy field names and missing optional keys.
- Additional hardening around backup parsing and default values.

### 2) Gradebook and Assessment Parity

- Shared percentage utilities added and applied consistently.
- Max score behavior aligned in assessment flows.
- Backfill behavior enforced so new students/assessments receive complete result rows.

### 3) Navigation and UX Consistency

- Back navigation now returns to the previous context correctly in deep screens.
- Section routing behavior made more predictable across app flows.

### 4) Class Metadata Parity

- Added `schoolYear` to class create/edit/display surfaces.
- Included `schoolYear` in backup/export/import model payloads.

### 5) Group Engine Parity

- Grouping logic moved into a dedicated pure engine file for testability and maintainability.
- Added option parity:
  - `balanceGender`
  - `balanceAbility`
  - `pairSupportPartners`
  - `respectSeparations`
- Improved failure messaging and fallback strategy when constraints cannot be fully satisfied.

### 6) Running Records Parity

- Added rich filter/sort controls:
  - class, student, level, date range, search, sort
- Added CSV and JSON exports alongside existing PDF flow.
- Preserved the existing visual language (no redesign).

### 7) Preferences Parity

- New Preferences screen with:
  - date format preference
  - time format preference
  - default landing section
- Persisted via `AppStorage`.
- Formatting helpers wired into user-facing date/time displays.

## QA and Compatibility

- Pre-parity backup payloads successfully decode with current backup models.
- Post-parity schema-v3 payload path verified.
- macOS and iOS builds pass.
- Full details: `docs/phase7-qa-report.md`.

## Known Notes

- This release prioritizes parity and behavior consistency with the web app.
- Any remaining runtime migration checks that require an existing user DB must be validated on-device/in-app as part of release sign-off.
