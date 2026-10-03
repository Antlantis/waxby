#!/usr/bin/env bash
# The audio spikes on the Mac, in a window (CoreAudio at 48 kHz, like the
# phone), printing the [spike] lines. See scripts/sfx_spike.gd.
#   tools/audio/spike_mac.sh boot | stems [minutes] | stems-pcm [minutes]
set -u
cd "$(dirname "$0")/../../game"
G="${GODOT:-/Users/antmacpro/Downloads/Godot.app/Contents/MacOS/Godot}"
WHAT="${1:-boot}"
MIN="${2:-10}"
case "$WHAT" in
  boot) ARG="spike:boot" ;;
  stems) ARG="spike:stems:$MIN" ;;
  stems-pcm) ARG="spike:stems:$MIN:pcm" ;;
  *) echo "usage: $0 boot | stems [minutes] | stems-pcm [minutes]"; exit 2 ;;
esac
"$G" --path . --resolution 844x390 -- "--autoplay=$ARG" 2>&1 | grep --line-buffered "\[spike\]"
