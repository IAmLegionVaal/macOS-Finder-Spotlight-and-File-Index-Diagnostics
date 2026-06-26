#!/bin/bash
set -u

DO_REPAIR=false
DRY_RUN=false
ASSUME_YES=false
OUTPUT_DIR=""
REINDEX_PATH=""
ENABLE_PATH=""
FAILURES=0
ACTIONS=0

usage() {
  cat <<'EOF'
Usage: finder_spotlight_repair.sh [options]

  --repair          Restart Finder, Quick Look and Spotlight processes.
  --enable PATH     Enable Spotlight indexing for PATH.
  --reindex PATH    Erase and rebuild the Spotlight index for PATH.
  --dry-run         Show actions without changing the Mac.
  --yes             Skip confirmation prompts.
  --output DIR      Save logs and verification output in DIR.
  -h, --help        Show help.

Examples:
  ./src/finder_spotlight_repair.sh --repair
  ./src/finder_spotlight_repair.sh --repair --dry-run
  ./src/finder_spotlight_repair.sh --reindex /
  ./src/finder_spotlight_repair.sh --enable /Volumes/External
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repair) DO_REPAIR=true; shift ;;
    --enable) ENABLE_PATH="${2:-}"; DO_REPAIR=true; shift 2 ;;
    --reindex) REINDEX_PATH="${2:-}"; DO_REPAIR=true; shift 2 ;;
    --dry-run) DRY_RUN=true; shift ;;
    --yes) ASSUME_YES=true; shift ;;
    --output) OUTPUT_DIR="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage; exit 2 ;;
  esac
done

[ "$(uname -s)" = "Darwin" ] || { echo "This tool must run on macOS." >&2; exit 1; }
[ -z "$ENABLE_PATH" ] || [ -e "$ENABLE_PATH" ] || { echo "Enable path does not exist: $ENABLE_PATH" >&2; exit 2; }
[ -z "$REINDEX_PATH" ] || [ -e "$REINDEX_PATH" ] || { echo "Reindex path does not exist: $REINDEX_PATH" >&2; exit 2; }

STAMP="$(date +%Y%m%d_%H%M%S)"
OUTPUT_DIR="${OUTPUT_DIR:-./finder-spotlight-repair-$STAMP}"
mkdir -p "$OUTPUT_DIR"
LOG="$OUTPUT_DIR/repair.log"
VERIFY="$OUTPUT_DIR/verification.txt"
: > "$LOG"

log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG"; }
confirm() {
  $ASSUME_YES && return 0
  printf '%s [y/N]: ' "$1"
  read -r answer
  case "$answer" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}
run_action() {
  description="$1"; shift
  ACTIONS=$((ACTIONS + 1)); log "$description"
  if $DRY_RUN; then
    printf 'DRY-RUN:' >> "$LOG"; for arg in "$@"; do printf ' %q' "$arg" >> "$LOG"; done; printf '\n' >> "$LOG"; return 0
  fi
  if "$@" >> "$LOG" 2>&1; then log "SUCCESS: $description"; return 0; fi
  FAILURES=$((FAILURES + 1)); log "WARNING: $description failed"; return 1
}
run_admin() {
  description="$1"; shift
  if [ "$(id -u)" -eq 0 ]; then run_action "$description" "$@"; else run_action "$description" /usr/bin/sudo "$@"; fi
}
verify() {
  {
    echo "Collected: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Host: $(hostname)"
    echo
    echo "Finder and metadata processes:"
    ps -Ao pid,user,etime,comm,args | awk 'NR == 1 || /Finder|mds|mdworker|Spotlight|QuickLook/' || true
    echo
    echo "Spotlight status:"
    /usr/bin/mdutil -as 2>&1 || true
    if [ -n "$ENABLE_PATH" ]; then /usr/bin/mdutil -s "$ENABLE_PATH" 2>&1 || true; fi
    if [ -n "$REINDEX_PATH" ]; then /usr/bin/mdutil -s "$REINDEX_PATH" 2>&1 || true; fi
    echo
    echo "Quick Look generators:"
    /usr/bin/qlmanage -m plugins 2>/dev/null | head -n 150 || true
  } > "$VERIFY" 2>&1
}

verify
if ! $DO_REPAIR; then log "Verification-only mode completed. Use --repair to apply repairs."; exit 0; fi
if ! confirm "Restart Finder, Quick Look and Spotlight processes?"; then log "Repair cancelled by user."; exit 0; fi

run_action "Resetting Quick Look generator registration" /usr/bin/qlmanage -r || true
run_action "Clearing the Quick Look thumbnail cache" /usr/bin/qlmanage -r cache || true
for process_name in QuickLookUIService quicklookd sharedfilelistd; do
  if pgrep -x "$process_name" >/dev/null 2>&1; then run_action "Restarting $process_name" /usr/bin/killall "$process_name" || true; fi
done
if pgrep -x Finder >/dev/null 2>&1; then run_action "Restarting Finder" /usr/bin/killall Finder || true; fi
if pgrep -x mds >/dev/null 2>&1; then run_admin "Restarting Spotlight metadata service" /usr/bin/killall mds || true; fi

if [ -n "$ENABLE_PATH" ]; then
  if confirm "Enable Spotlight indexing for $ENABLE_PATH?"; then
    run_admin "Enabling Spotlight indexing for $ENABLE_PATH" /usr/bin/mdutil -i on "$ENABLE_PATH" || true
  fi
fi

if [ -n "$REINDEX_PATH" ]; then
  if confirm "Erase and rebuild the Spotlight index for $REINDEX_PATH? This can use significant CPU and disk resources."; then
    run_admin "Enabling Spotlight indexing for $REINDEX_PATH" /usr/bin/mdutil -i on "$REINDEX_PATH" || true
    run_admin "Requesting Spotlight reindex for $REINDEX_PATH" /usr/bin/mdutil -E "$REINDEX_PATH" || true
  fi
fi

if ! $DRY_RUN; then sleep 6; fi
verify

FINDER_OK=false
pgrep -x Finder >/dev/null 2>&1 && FINDER_OK=true
MDS_OK=false
pgrep -x mds >/dev/null 2>&1 && MDS_OK=true
if ! $FINDER_OK; then FAILURES=$((FAILURES + 1)); log "WARNING: Finder is not running after repair."; fi
if ! $MDS_OK; then FAILURES=$((FAILURES + 1)); log "WARNING: Spotlight metadata service is not running after repair."; fi

if [ "$FAILURES" -gt 0 ]; then log "Repair completed with $FAILURES warning(s)."; exit 1; fi
log "Repair completed successfully. Actions performed: $ACTIONS"
exit 0
