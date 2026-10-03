#!/usr/bin/env bash
# Regenerate the levels, then run every Godot test file headless. Every file
# runs even if one fails; the exit code is non-zero if any failed.
#   tools/test.sh              all tests (the reachability bot runs one
#                              process per world, in parallel)
#   tools/test.sh core story   only test_core.gd and test_story.gd
#   WAXBY_FAST=1               skip the slow bot (and A6's check_music.py)
#   WAXBY_WORLD=3              the bot for world 3 only (0: the feel labs)
#   WAXBY_SLOW=1               the nightly checks too (the tests read it)
#   WAXBY_TIMEOUT=900          seconds a file may take before it counts as hung
# A file fails when Godot exits non-zero, when anything fails to parse
# ("Parse Error"), when it never prints its "N passed, M failed" line (it
# died, or hung past WAXBY_TIMEOUT), or when that line says M > 0. A test
# file a stream hasn't landed yet is listed and skipped.
cd "$(dirname "$0")/.."
fail=0
if ! python3 tools/make_levels.py; then echo "!! make_levels.py FAILED"; fail=1; fi
# The modes' rooms, rush arenas and trials are cut from the level modules and
# the N-4 files: regenerated with them (byte-identical when nothing moved).
for t in make_rooms make_modes make_trials; do
  if [ -f "tools/$t.py" ] && ! python3 "tools/$t.py" > /dev/null; then echo "!! $t.py FAILED"; fail=1; fi
done
MUSIC_LOG=""
if [ -z "$WAXBY_FAST" ] && [ $# -eq 0 ] && [ -f tools/audio/check_music.py ]; then
  # A6's music check (files, loudness, stems, the carillon's tick against the
  # level headers, every played note's mode): ~110 s, alongside the tests.
  MUSIC_LOG="$(mktemp "${TMPDIR:-/tmp}/waxby-music.XXXXXX")"
  ( python3 tools/audio/check_music.py > "$MUSIC_LOG" 2>&1; echo $? > "$MUSIC_LOG.code" ) &
fi
cd game
G="${GODOT:-/Users/antmacpro/Downloads/Godot.app/Contents/MacOS/Godot}"
TIMEOUT="${WAXBY_TIMEOUT:-900}"
LOGS="$(mktemp -d "${TMPDIR:-/tmp}/waxby-test.XXXXXX")"
# v2's files first, then v3's (the streams' files run once they exist).
known=(core classes progression screens story slots content sfx art monster_art monster_art3 boss_art story_art integration
       routes export render
       w3 w4 w5 w6 secrets monsters3 monsters4 bosses3 bosses4 rush_bosses kits3 modes world_art world_art2)
files=()
if [ $# -gt 0 ]; then
  files=("$@")
else
  files=("${known[@]}")
  # Any other test file (a stream's new one) runs too.
  for p in tests/test_*.gd; do
    n="${p#tests/test_}"; n="${n%.gd}"
    case " ${known[*]} " in *" $n "*) ;; *) files+=("$n");; esac
  done
fi

run_one() {  # run_one <name> <log> [env...]: runs tests/test_<name>.gd; prints its tail; returns 0/1
  local f="$1" log="$2"; shift 2
  env "$@" perl -e 'alarm shift; exec @ARGV' "$TIMEOUT" "$G" --headless --path . --script "res://tests/test_$f.gd" < /dev/null > "$log" 2>&1
  local code=$?
  local bad=0
  if [ "$code" != "0" ]; then echo "!! test_$f exited $code$( [ "$code" = "142" ] && echo " (hung past ${TIMEOUT}s)")"; bad=1; fi
  if grep -q "Parse Error\|Failed to load script" "$log"; then
    echo "!! test_$f: a script failed to parse:"; grep -A2 "Parse Error\|Failed to load script" "$log" | head -12; bad=1
  fi
  local summary
  summary=$(grep -E "[0-9]+ passed, [0-9]+ failed" "$log" | tail -1)
  if [ -z "$summary" ]; then echo "!! test_$f never printed its summary (it died or hung)"; bad=1
  elif echo "$summary" | grep -qvE " 0 failed"; then bad=1; fi
  local errs
  errs=$(grep -c "SCRIPT ERROR" "$log")
  if [ "$errs" != "0" ]; then echo "   (test_$f: $errs SCRIPT ERROR lines; see the log)"; fi
  return $bad
}

filter() { grep -Ev "^\s*$|leaked|still in use|_free_rids|object.cpp|resource.cpp|^\s+at: (cleanup|clear|_free_rids)" | tail -n 60; }

# The bot, one process per world, in the background (test_core itself then skips it).
bots=()
want_core=0
for f in "${files[@]}"; do [ "$f" = "core" ] && want_core=1; done
if [ "$want_core" = "1" ] && [ -z "$WAXBY_FAST" ]; then
  worlds=$(ls levels/*.txt 2>/dev/null | sed -E 's|levels/||' | awk -F- '{ if ($1 ~ /^[1-9]$/) print $1; else print 0 }' | sort -u)
  if [ -n "$WAXBY_WORLD" ]; then worlds="$WAXBY_WORLD"; fi
  for wn in $worlds; do
    ( run_one core "$LOGS/bot_$wn.log" WAXBY_WORLD="$wn" > "$LOGS/bot_$wn.verdict" 2>&1; echo $? > "$LOGS/bot_$wn.code" ) &
    bots+=("$wn")
  done
fi

for f in "${files[@]}"; do
  if [ ! -f "tests/test_$f.gd" ]; then echo "(no tests/test_$f.gd yet: skipped)"; continue; fi
  echo "== test_$f"
  if [ "$f" = "core" ]; then
    run_one core "$LOGS/$f.log" WAXBY_NOBOT=1; code=$?
  else
    run_one "$f" "$LOGS/$f.log"; code=$?
  fi
  filter < "$LOGS/$f.log"
  [ "$code" != "0" ] && fail=1
done

if [ ${#bots[@]} -gt 0 ]; then
  wait
  for wn in "${bots[@]}"; do
    echo "== test_core bot, world $wn"
    filter < "$LOGS/bot_$wn.log"
    cat "$LOGS/bot_$wn.verdict"
    [ "$(cat "$LOGS/bot_$wn.code" 2>/dev/null)" != "0" ] && fail=1
  done
fi
if [ -n "$MUSIC_LOG" ]; then
  wait
  echo "== check_music.py"
  grep -E "FAIL|^note|all music checks" "$MUSIC_LOG" | tail -n 12
  echo "check_music.py: $(grep -c '^PASS' "$MUSIC_LOG") PASS, $(grep -c '^FAIL' "$MUSIC_LOG") FAIL"
  if [ "$(cat "$MUSIC_LOG.code" 2>/dev/null)" != "0" ]; then echo "!! check_music.py FAILED"; fail=1; fi
  rm -f "$MUSIC_LOG" "$MUSIC_LOG.code"
fi
rm -rf "$LOGS"
exit $fail
