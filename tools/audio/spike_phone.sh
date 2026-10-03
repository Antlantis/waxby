#!/usr/bin/env bash
# The Phase 0 audio spikes on the phone (workstreams.md step 0.8). The debug
# build must already be on the phone (the integrator's export to
# ~/Developer/waxby-ios and devicectl install); this only launches it and reads
# its log. Each spike quits the app when it's done.
#
#   tools/audio/spike_phone.sh boot           first-boot render times (about 1-2 min). It wipes the
#                                             sound caches at its end, so it runs twice: the second
#                                             run's "live boot (cold ...)" line is a true first boot.
#   tools/audio/spike_phone.sh stems [min]    5 stems for 10 minutes (default) and their drift
#   tools/audio/spike_phone.sh stems-pcm [min]  the same with PCM stems (if QOA fails)
#
# Reads the [spike] lines out of Documents/logs/godot.log; the verdicts are
# the "[spike] RESULT" lines. The whole log lands in $WAXBY_OUT (default
# /private/tmp/claude-501/waxby-ws-a7/phone). Set WAXBY_DEVICE and
# WAXBY_BUNDLE for another phone or bundle id.
set -u
WHAT="${1:-boot}"
MIN="${2:-10}"
DEV="${WAXBY_DEVICE:-00008150-000024E2213A401C}"
APP="${WAXBY_BUNDLE:-com.ant.waxby}"
OUT="${WAXBY_OUT:-/private/tmp/claude-501/waxby-ws-a7/phone}"
mkdir -p "$OUT"

lines() {   # lines <spike> <log>: the [spike] lines of the last run of that spike; true once it's DONE
  awk -v a="start spike:$1 " 'index($0, a) {buf = ""; on = 1; found = 0}
    on && /\[spike\]/ {buf = buf $0 "\n"} on && /\[spike\] DONE/ {found = 1}
    END {printf "%s", buf; exit !found}' "$2" 2>/dev/null
}

run() {   # run <spike> <seconds allowed> <log file>
  local arg="$1" limit="$2" log="$3"
  rm -f "$log"
  echo "== launching --autoplay=spike:$arg on $DEV (allowing ${limit}s)"
  if ! xcrun devicectl device process launch --device "$DEV" --terminate-existing "$APP" -- "--autoplay=spike:$arg" >/dev/null; then
    echo "!! launch failed (is the phone unlocked, and the debug build installed?)"
    return 1
  fi
  local start; start=$(date +%s)
  while :; do
    sleep 15
    xcrun devicectl device copy from --device "$DEV" --domain-type appDataContainer --domain-identifier "$APP" \
      --source Documents/logs/godot.log --destination "$log" >/dev/null 2>&1
    if [ -f "$log" ] && lines "$arg" "$log" >/dev/null; then
      break
    fi
    local now; now=$(date +%s)
    if [ $(( now - start )) -gt "$limit" ]; then
      echo "!! no '[spike] DONE' after ${limit}s; what the log has so far:"
      break
    fi
    printf "   %ds...\n" $(( now - start ))
  done
  lines "$arg" "$log" || true
  echo "(the whole log: $log)"
}

case "$WHAT" in
  boot)
    run "boot" 300 "$OUT/spike_boot_1.log"
    echo
    echo "== again, now that the caches are gone: its 'live boot (cold' line is the true first boot"
    run "boot" 300 "$OUT/spike_boot_2.log"
    ;;
  stems)
    run "stems:$MIN" $(( ${MIN%.*} * 60 + 300 )) "$OUT/spike_stems.log"
    ;;
  stems-pcm)
    run "stems:$MIN:pcm" $(( ${MIN%.*} * 60 + 300 )) "$OUT/spike_stems_pcm.log"
    ;;
  *)
    echo "usage: $0 boot | stems [minutes] | stems-pcm [minutes]"
    exit 2
    ;;
esac
