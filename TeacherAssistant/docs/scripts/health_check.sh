#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROJECT_PATH="${PROJECT_PATH:-$APP_DIR/../TeacherAssistant.xcodeproj}"
MODULE_CACHE="${MODULE_CACHE:-/tmp/swift-module-cache}"
ALLOWLIST_FILE="${WARNING_ALLOWLIST_FILE:-$SCRIPT_DIR/health_warning_allowlist.txt}"
DIRECT_SAVE_ALLOWLIST_FILE="${DIRECT_SAVE_ALLOWLIST_FILE:-$SCRIPT_DIR/direct_save_allowlist.txt}"
WORK_DIR="$(mktemp -d /tmp/teacherassistant-health.XXXXXX)"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

PASS_COUNT=0
FAIL_COUNT=0

log_step() {
  echo
  echo "==> $1"
}

run_step() {
  local name="$1"
  shift
  local log_file="$WORK_DIR/${name// /_}.log"

  log_step "$name"
  if "$@" >"$log_file" 2>&1; then
    echo "PASS: $name"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    echo "FAIL: $name"
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "---- tail ($name) ----"
    tail -n 40 "$log_file" || true
    echo "------------------------"
  fi
}

run_step_shell() {
  local name="$1"
  local cmd="$2"
  run_step "$name" bash -lc "$cmd"
}

cd "$APP_DIR"

run_step "Build TeacherAssistant (iOS generic)" \
  xcodebuild -project "$PROJECT_PATH" -scheme TeacherAssistant -configuration Debug -destination "generic/platform=iOS" build CODE_SIGNING_ALLOWED=NO

run_step "Build TeacherAssistant (macOS)" \
  xcodebuild -project "$PROJECT_PATH" -scheme TeacherAssistant -configuration Debug -destination "platform=macOS" build CODE_SIGNING_ALLOWED=NO

run_step "Build TeacherAssistantMac (macOS)" \
  xcodebuild -project "$PROJECT_PATH" -scheme TeacherAssistantMac -configuration Debug -destination "platform=macOS" build CODE_SIGNING_ALLOWED=NO

run_step "Durability Tests (macOS)" \
  xcodebuild -project "$PROJECT_PATH" -scheme TeacherAssistant -destination "platform=macOS" test CODE_SIGNING_ALLOWED=NO

run_step_shell "Verifier: backup roundtrip" \
  "swiftc -module-cache-path '$MODULE_CACHE' -DBACKUP_VERIFY BackupModels.swift docs/scripts/BackupVerifierSupport.swift docs/scripts/verify_backup_roundtrip.swift -o /tmp/verify_backup_roundtrip && /tmp/verify_backup_roundtrip"

run_step_shell "Verifier: backup compatibility" \
  "swiftc -module-cache-path '$MODULE_CACHE' -DBACKUP_VERIFY BackupModels.swift docs/scripts/BackupVerifierSupport.swift docs/scripts/verify_backup_compat.swift -o /tmp/verify_backup_compat && /tmp/verify_backup_compat"

run_step_shell "Verifier: bootstrap recovery" \
  "swiftc -module-cache-path '$MODULE_CACHE' -DBACKUP_VERIFY Shared/BootstrapRecoveryState.swift docs/scripts/verify_bootstrap_recovery.swift -o /tmp/verify_bootstrap_recovery && /tmp/verify_bootstrap_recovery"

run_step_shell "Verifier: restore safety" \
  "swiftc -module-cache-path '$MODULE_CACHE' -DBACKUP_VERIFY Shared/RestoreExecutionCoordinator.swift docs/scripts/verify_restore_safety.swift -o /tmp/verify_restore_safety && /tmp/verify_restore_safety"

run_step_shell "Verifier: snapshot retention" \
  "swiftc -parse-as-library -module-cache-path '$MODULE_CACHE' -DBACKUP_VERIFY docs/scripts/verify_snapshot_retention.swift -o /tmp/verify_snapshot_retention && /tmp/verify_snapshot_retention"

log_step "Warning scan"
rg -n "warning:" "$WORK_DIR"/*.log > "$WORK_DIR/warnings.raw" || true

# Non-blocking in this repo unless AppIntents is explicitly adopted.
rg -v "Metadata extraction skipped\. No AppIntents\.framework dependency found\." "$WORK_DIR/warnings.raw" > "$WORK_DIR/warnings.filtered" || true

if [[ -s "$ALLOWLIST_FILE" ]]; then
  rg -v -f "$ALLOWLIST_FILE" "$WORK_DIR/warnings.filtered" > "$WORK_DIR/warnings.final" || true
else
  cp "$WORK_DIR/warnings.filtered" "$WORK_DIR/warnings.final"
fi

WARNING_COUNT=0
if [[ -s "$WORK_DIR/warnings.final" ]]; then
  WARNING_COUNT=$(wc -l < "$WORK_DIR/warnings.final" | tr -d ' ')
  echo "FAIL: warning scan ($WARNING_COUNT warnings)"
  tail -n 50 "$WORK_DIR/warnings.final" || true
  FAIL_COUNT=$((FAIL_COUNT + 1))
else
  echo "PASS: warning scan"
  PASS_COUNT=$((PASS_COUNT + 1))
fi

log_step "Direct save guard"
rg -n --glob '*.swift' '\b(?:try\s+)?context\.save\(\)' . > "$WORK_DIR/direct_saves.raw" || true

if [[ -s "$DIRECT_SAVE_ALLOWLIST_FILE" ]]; then
  rg -v -f "$DIRECT_SAVE_ALLOWLIST_FILE" "$WORK_DIR/direct_saves.raw" > "$WORK_DIR/direct_saves.final" || true
else
  cp "$WORK_DIR/direct_saves.raw" "$WORK_DIR/direct_saves.final"
fi

DIRECT_SAVE_COUNT=0
if [[ -s "$WORK_DIR/direct_saves.final" ]]; then
  DIRECT_SAVE_COUNT=$(wc -l < "$WORK_DIR/direct_saves.final" | tr -d ' ')
  echo "FAIL: direct save guard ($DIRECT_SAVE_COUNT unauthorized direct saves)"
  tail -n 50 "$WORK_DIR/direct_saves.final" || true
  FAIL_COUNT=$((FAIL_COUNT + 1))
else
  echo "PASS: direct save guard"
  PASS_COUNT=$((PASS_COUNT + 1))
fi

echo
echo "Summary: $PASS_COUNT passed, $FAIL_COUNT failed"
if (( FAIL_COUNT > 0 )); then
  exit 1
fi
