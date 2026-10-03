#!/usr/bin/env python3
"""The play identity gate (workstreams.md 1.2: "W1-W2 play exactly as before,
the smoke bot with every calling"): test_integration.gd's two-thumb bot plays
every v2 level with every calling in two trees, and its per-run lines (damage
dealt, Specials, XP, embers, items, levels, distance, snuffs, boss damage)
must match line for line.

  python3 tools/play_identity.py                  # v3-base vs this tree
  python3 tools/play_identity.py --base <tree> --head <tree> --out <dir>

test_integration.gd as it is isn't deterministic: a real frame every 40 ticks
runs the rig's _process on the wall clock, and three kits aim from the rig's
pose (weapon_point / hand_point), and the global RNG is never seeded. So the
harness is made from the head tree's own test_integration.gd with three edits
(scratch only): the global RNG seeded per run, one warm-up run discarded, and
no real frames mid-play. Two runs of one tree then match exactly, under any
load. The base tree is rsynced into <out> with its own user dir.
"""
import argparse
import os
import re
import subprocess
import sys

GODOT = os.environ.get("GODOT", "/Users/antmacpro/Downloads/Godot.app/Contents/MacOS/Godot")
HEAD = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
BASE = os.path.expanduser("~/Developer/waxby-snapshots/v3-base")
OUT = "/private/tmp/claude-501/wick-play-identity"
LINE = re.compile(r"^  (knight|witch|runner|founder|sexton) ")


def harness(src):
    s = src
    old = "func _play(cls: String, id: String) -> Dictionary:\n"
    assert s.count(old) == 1, "test_integration.gd: _play not found"
    s = s.replace(old, old + "\tseed(hash(cls + id))   # (play identity: the global RNG too)\n")
    old = "func _test_play_all() -> void:\n"
    assert s.count(old) == 1, "test_integration.gd: _test_play_all not found"
    s = s.replace(old, old + "\tgame.reset()\n\t_hero_for(\"knight\", \"1-1\")\n\tawait _play(\"knight\", \"1-1\")   # (play identity: a warm-up, discarded)\n")
    s, n = re.subn(r"(if i % 40 == 0:\n\t+)await process_frame", r"\1pass   # (play identity: no real frames mid-play)", s)
    assert n >= 1, "test_integration.gd: the mid-play frames not found"
    return s


def base_copy(base, out, user_dir):
    dst = os.path.join(out, "base_tree")
    os.makedirs(dst, exist_ok=True)
    subprocess.run(["rsync", "-a", "--delete", "--exclude", ".godot", os.path.join(base, "game") + "/", os.path.join(dst, "game") + "/"], check=True)
    pg = os.path.join(dst, "game", "project.godot")
    s = open(pg).read()
    s = re.sub(r"config/use_custom_user_dir=.*\n", "", s)
    s = re.sub(r"config/custom_user_dir_name=.*\n", "", s)
    s = s.replace("[application]\n", '[application]\n\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="%s"\n' % user_dir, 1)
    open(pg, "w").write(s)
    if not os.path.isdir(os.path.join(dst, "game", ".godot", "imported")):
        subprocess.run([GODOT, "--headless", "--path", os.path.join(dst, "game"), "--import"], stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT)
    return dst


def lines(tree, script, log):
    p = subprocess.run([GODOT, "--headless", "--path", os.path.join(tree, "game"), "--script", script],
                       stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    open(log, "w").write(p.stdout)
    return [l for l in p.stdout.splitlines() if LINE.match(l)]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default=BASE)
    ap.add_argument("--head", default=HEAD)
    ap.add_argument("--out", default=OUT)
    ap.add_argument("--user-dir", default="waxby-play-identity-base")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    script = os.path.join(a.out, "play_identity_harness.gd")
    open(script, "w").write(harness(open(os.path.join(a.head, "game", "tests", "test_integration.gd")).read()))
    base = base_copy(a.base, a.out, a.user_dir)
    lb = lines(base, script, os.path.join(a.out, "base.log"))
    lh = lines(a.head, script, os.path.join(a.out, "head.log"))
    print("base: %s  %d runs" % (base, len(lb)))
    print("head: %s  %d runs" % (a.head, len(lh)))
    diff = [(x, y) for x, y in zip(lb, lh) if x != y]
    for x, y in diff:
        print("  base " + x.strip())
        print("  head " + y.strip())
    ok = len(lb) > 0 and len(lb) == len(lh) and not diff
    print("PLAY IDENTICAL (%d runs)" % len(lb) if ok else "PLAY DIFFERS (%d of %d runs; logs in %s)" % (len(diff), len(lb), a.out))
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
