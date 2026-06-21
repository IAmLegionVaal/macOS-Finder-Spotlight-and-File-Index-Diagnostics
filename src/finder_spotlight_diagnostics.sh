#!/bin/bash
set -u

HOURS=24
OUTPUT_DIR=""

usage(){ echo "Usage: finder_spotlight_diagnostics.sh [--hours N] [--output DIR]"; }
while [ "$#" -gt 0 ]; do case "$1" in --hours) HOURS="${2:-24}"; shift 2;; --output) OUTPUT_DIR="${2:-}"; shift 2;; -h|--help) usage; exit 0;; *) echo "Unknown argument: $1" >&2; exit 2;; esac; done
case "$HOURS" in ''|*[!0-9]*) echo "--hours must be numeric" >&2; exit 2;; esac
[ "$(uname -s)" = Darwin ] || { echo "This tool must run on macOS." >&2; exit 1; }
STAMP=$(date +%Y%m%d_%H%M%S); OUTPUT_DIR="${OUTPUT_DIR:-./finder-spotlight-$STAMP}"; mkdir -p "$OUTPUT_DIR"
REPORT="$OUTPUT_DIR/finder-spotlight-report.txt"; CSV="$OUTPUT_DIR/volumes.csv"; JSON="$OUTPUT_DIR/summary.json"; ERRORS="$OUTPUT_DIR/command-errors.log"; :>"$REPORT"; :>"$ERRORS"
echo 'volume,filesystem,size_kib,used_kib,available_kib,capacity,index_state' > "$CSV"
section(){ t="$1"; shift; { printf '\n===== %s =====\n' "$t"; "$@"; } >>"$REPORT" 2>>"$ERRORS" || true; }
section "Metadata" /bin/bash -c 'date -u +%Y-%m-%dT%H:%M:%SZ; hostname; sw_vers; id'
section "Finder and Spotlight processes" /bin/bash -c 'ps -Ao pid,user,etime,comm,args | grep -Ei "Finder|mds|mdworker|metadata|corespotlightd|fileproviderd" | grep -v grep || true'
section "Spotlight status" /usr/bin/mdutil -as
section "Finder Sync extensions" /usr/bin/pluginkit -m -p com.apple.FinderSync
section "Mounted volumes" /bin/df -kP
section "Filesystem inventory" /usr/sbin/diskutil list
section "Basic metadata search" /usr/bin/mdfind -onlyin "$HOME" 'kMDItemFSName == "*.pdf"c'
section "Recent Finder and Spotlight events" /bin/bash -c "/usr/bin/log show --last ${HOURS}h --style compact --predicate '(process == \"Finder\") OR (process == \"mds\") OR (process CONTAINS[c] \"mdworker\") OR (subsystem CONTAINS[c] \"Spotlight\") OR (subsystem CONTAINS[c] \"FileProvider\")' 2>/dev/null | tail -n 4000"

VOLUME_COUNT=0
INDEX_DISABLED=0
while read -r filesystem size used available capacity mountpoint; do
  VOLUME_COUNT=$((VOLUME_COUNT+1))
  fstype=$(diskutil info "$mountpoint" 2>/dev/null | awk -F: '/File System Personality/{gsub(/^ +/,"",$2); print $2; exit}')
  index_state=$(mdutil -s "$mountpoint" 2>/dev/null | tail -n1 | sed 's/^[[:space:]]*//')
  echo "$index_state" | grep -qi disabled && INDEX_DISABLED=$((INDEX_DISABLED+1))
  printf '"%s","%s",%s,%s,%s,"%s","%s"\n' "$mountpoint" "$fstype" "$size" "$used" "$available" "$capacity" "${index_state//"/""}" >> "$CSV"
done < <(df -kP | tail -n +2)
FINDER_RUNNING=false; pgrep -x Finder >/dev/null 2>&1 && FINDER_RUNNING=true
MDS_RUNNING=false; pgrep -x mds >/dev/null 2>&1 && MDS_RUNNING=true
SEARCH_RESULTS=$(mdfind -onlyin "$HOME" 'kMDItemFSName == "*.pdf"c' 2>/dev/null | head -n 100 | wc -l | tr -d ' ')
OVERALL="Healthy"; { ! $FINDER_RUNNING || ! $MDS_RUNNING; } && OVERALL="Attention required"
cat > "$JSON" <<EOF
{"collected_at":"$(date -u +%Y-%m-%dT%H:%M:%SZ)","hostname":"$(hostname)","finder_running":$FINDER_RUNNING,"mds_running":$MDS_RUNNING,"volumes":$VOLUME_COUNT,"volumes_with_index_disabled":$INDEX_DISABLED,"sample_search_results":$SEARCH_RESULTS,"overall_status":"$OVERALL"}
EOF
printf '\nFinder and Spotlight diagnostics completed: %s\n' "$OUTPUT_DIR" | tee -a "$REPORT"
