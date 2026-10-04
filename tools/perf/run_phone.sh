#!/usr/bin/env bash
# The phone perf run: export a debug build, install it, launch each run with
# --autoplay, wait, pull Documents/logs/godot.log, print the table and the gate.
# (W0-render wrote it; the integrator runs it. The phone must be unlocked.)
#
#   tools/perf/run_phone.sh spike:all                 # the GPU spike: lights48 Plan A + Plan B, scene33 (~2.5 min)
#   tools/perf/run_phone.sh --vulkan spike:all        # the same through MoltenVK: real GPU timestamps
#   tools/perf/run_phone.sh 2-4 1-1 2-2               # levels with the bot, 40 s each (the v2 check)
#   tools/perf/run_phone.sh --field quarter 2-4       # a level under Plan B
#   tools/perf/run_phone.sh --no-build --vulkan spike:lights48   # reuse the last .ipa
#
# Tall levels (the shapes plan's E3, not run yet: it needs the phone, and the
# owner runs it before the redraw): the render labs at 24 and 36 rows
# (python3 tools/levels/lab_tall.py writes them to game/levels/tall), the
# orchard and the glass, the slowest painters:
#   tools/perf/run_phone.sh tall/lab-tall-3-1-24 tall/lab-tall-5-3-24 tall/lab-tall-3-1-36 tall/lab-tall-5-3-36
# The bot plays the bottom storey (the level's lower nine rows; the storeys
# above are its terrain and scenery, in view as the camera climbs), so the
# frames carry the taller level's tiles, chunks and backdrop; the gate is the
# same. tools/perf/paint_probe.gd has the Mac's painter numbers to set
# against (a redraw's cost by height, both chunk layouts). Then the route
# that climbs and falls through the storeys, the orchard painter's Shapes
# layers and the camera's look-ahead in the measured frames (the bot rings
# its bell up the wall: tests/test_shaped.gd), and the levels whose load
# builds the walk map (clockwork.gd's and deep.gd's first-time barks: about
# 20-40 ms on the Mac at 24-36 rows; at the phone's 2-4x, read the load's
# time in the log):
#   tools/perf/run_phone.sh lab-shape-rootvault tall/lab-tall-4-1-24 tall/lab-tall-4-2-24 tall/lab-tall-6-1-24
# and each real tall level as it lands: 3-2, 3-3, 5-3 (its hold room's glass)
# and 2-2.
#
# Runs: a level id (1-1 ... 6-4, 1-S ...; <id>@<n> from its altar n, 0 the
# first: 4-3@2 past W4's weights, 3-4@1 / 4-4@1 at the boss's door), spike:all | spike:lights48 |
# spike:lights48b | spike:scene33, scene:<id>, descent:<d>, rush:<boss>,
# trial:<id>, screens (the routes main.gd has).
# Options:
#   --secs N        seconds each run plays before its log is pulled (levels 40, spikes 150)
#   --vulkan        launch with --rendering-driver vulkan (Metal reports no GPU time)
#   --field PLAN    launch with --light-field=PLAN (full | quarter | half)
#   --cutscene-field PLAN   launch with --cutscene-field=PLAN (the scenes' own
#                   plan: quarter by default since the GPU test, full for Plan A)
#   --cold          a run without --warm (the bot's level loads its art
#                   itself, as before; by default a level, scene, descent,
#                   rush or trial run passes --warm, so main warms v2's art and
#                   the level's WORLD_ART sets as a player's launch does, and
#                   the texture memory measured is the player's: a scene over
#                   the title's art, as a player always has it)
#   --story         a level run plays its story as a player's does (--story:
#                   the beats over the level, lines going by themselves, the
#                   boss's scene asked for ahead at the last altar): 3-4@1 and
#                   4-4@1 then measure boss_3_before / boss_4_before over the
#                   live level (with --vulkan, their GPU time)
#   --no-build      reuse the last .ipa        --no-install   build only
#   --device UDID   default 00008150-000024E2213A401C (the owner's iPhone 17 Pro Max)
#   --ipa PATH      default ~/Developer/waxby-ios/waxby.ipa
#   --out DIR       logs and the table (default /private/tmp/claude-501/waxby-perf/<time>)
# The build is exported from a copy of game/ (under --out), never from the tree
# itself. When main.gd has no spike route yet, the copy gets the spike as an
# autoload (scripts/perf_spike.gd, launched with --spike=<name>); when
# world.gd has no v3 light seam yet, the copy gets tools/perf/world_seam.gd as
# scripts/perf_world_seam.gd for the spike to use.
# Exit code: 0 when every run passes the gate, 1 when one fails, 2 on a
# build / install / launch error.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
G="${GODOT:-/Users/antmacpro/Downloads/Godot.app/Contents/MacOS/Godot}"
DEV="00008150-000024E2213A401C"
BUNDLE="com.ant.waxby"
IPA="$HOME/Developer/waxby-ios/waxby.ipa"
OUT="/private/tmp/claude-501/waxby-perf/$(date +%Y%m%d-%H%M%S)"
SECS=""
VULKAN=0
FIELD=""
CFIELD=""
BUILD=1
INSTALL=1
COLD=0
STORY=0
RUNS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --secs) SECS="$2"; shift ;;
    --vulkan) VULKAN=1 ;;
    --field) FIELD="$2"; shift ;;
    --cutscene-field) CFIELD="$2"; shift ;;
    --no-build) BUILD=0 ;;
    --cold) COLD=1 ;;
    --story) STORY=1 ;;
    --no-install) INSTALL=0 ;;
    --device) DEV="$2"; shift ;;
    --ipa) IPA="$2"; shift ;;
    --out) OUT="$2"; shift ;;
    -h|--help) sed -n '2,43p' "$0"; exit 0 ;;
    *) RUNS+=("$1") ;;
  esac
  shift
done
[ ${#RUNS[@]} -eq 0 ] && RUNS=("spike:all")
mkdir -p "$OUT" "$(dirname "$IPA")"
say() { echo "[run_phone] $*"; }

need_spike=0
for r in "${RUNS[@]}"; do case "$r" in spike:*) need_spike=1 ;; esac; done
route_spike=0
grep -q "perf_spike" "$ROOT/game/scripts/main.gd" && route_spike=1

if [ $BUILD -eq 1 ]; then
  EXP="$OUT/export"
  say "copying game/ to $EXP/game"
  mkdir -p "$EXP"
  rsync -a --delete "$ROOT/game/" "$EXP/game/" || { say "rsync failed"; exit 2; }
  PG="$EXP/game/project.godot"
  # This copy's own user dir lines (a workstream's) never ship.
  sed -i '' '/^config\/use_custom_user_dir=/d; /^config\/custom_user_dir_name=/d' "$PG"
  if [ $need_spike -eq 1 ] && [ $route_spike -eq 0 ]; then
    say "main.gd has no spike route: the spike goes in as an autoload"
    sed -i '' 's|^\[autoload\]$|[autoload]\
\
PerfSpike="*res://scripts/perf_spike.gd"|' "$PG"
  fi
  if ! grep -q "world_lights" "$ROOT/game/scripts/world.gd"; then
    say "world.gd has no v3 light seam: the spike uses tools/perf/world_seam.gd"
    cp "$ROOT/tools/perf/world_seam.gd" "$EXP/game/scripts/perf_world_seam.gd"
  fi
  say "importing"
  "$G" --headless --path "$EXP/game" --import > "$OUT/import.log" 2>&1
  say "exporting the debug build to $IPA (a few minutes)"
  rm -f "$IPA"
  "$G" --headless --path "$EXP/game" --export-debug "iOS" "$IPA" > "$OUT/export.log" 2>&1
  if [ ! -s "$IPA" ]; then
    say "export failed: see $OUT/export.log"; tail -20 "$OUT/export.log"; exit 2
  fi
  say "built $(du -h "$IPA" | cut -f1) $IPA"
fi

if [ $INSTALL -eq 0 ]; then say "--no-install: stopping here"; exit 0; fi
say "installing on $DEV"
xcrun devicectl device install app --device "$DEV" "$IPA" > "$OUT/install.log" 2>&1 || { say "install failed:"; tail -20 "$OUT/install.log"; exit 2; }

fail=0
for r in "${RUNS[@]}"; do
  args=()
  [ $VULKAN -eq 1 ] && args+=("--rendering-driver" "vulkan")
  [ -n "$FIELD" ] && args+=("--light-field=$FIELD")
  [ -n "$CFIELD" ] && args+=("--cutscene-field=$CFIELD")
  secs="${SECS:-40}"
  case "$r" in
    spike:*)
      secs="${SECS:-150}"
      if [ $route_spike -eq 1 ]; then args+=("--autoplay=$r"); else args+=("--spike=${r#spike:}"); fi ;;
    screens) args+=("--autoplay=$r") ;;
    scene:*) args+=("--autoplay=$r"); [ $COLD -eq 0 ] && args+=("--warm") ;;
    *) args+=("--autoplay=$r"); [ $COLD -eq 0 ] && args+=("--warm"); [ $STORY -eq 1 ] && args+=("--story") ;;
  esac
  tag="$(echo "$r" | tr ':/@' '___')$( [ $VULKAN -eq 1 ] && echo _vk )$( [ -n "$FIELD" ] && echo "_$FIELD" )$( [ -n "$CFIELD" ] && echo "_cs$CFIELD" )$( [ $STORY -eq 1 ] && echo _story )"
  say "launching $r (${args[*]}) for ${secs} s"
  if ! xcrun devicectl device process launch --device "$DEV" --terminate-existing "$BUNDLE" -- "${args[@]}" > "$OUT/$tag.launch.log" 2>&1; then
    say "launch failed (is the phone unlocked?):"; tail -10 "$OUT/$tag.launch.log"; exit 2
  fi
  sleep "$secs"
  xcrun devicectl device copy from --device "$DEV" --domain-type appDataContainer --domain-identifier "$BUNDLE" \
      --source Documents/logs/godot.log --destination "$OUT/$tag.log" > "$OUT/$tag.pull.log" 2>&1 \
      || { say "could not pull the log:"; tail -10 "$OUT/$tag.pull.log"; fail=1; continue; }
  xcrun devicectl device copy from --device "$DEV" --domain-type appDataContainer --domain-identifier "$BUNDLE" \
      --source Documents/autoplay_level.png --destination "$OUT/$tag.png" > /dev/null 2>&1 || true
  python3 "$ROOT/tools/perf/perf_report.py" "$OUT/$tag.log" || fail=1
done
say "logs in $OUT"
exit $fail
