#!/usr/bin/env python3
"""The render identity gate: the same deterministic shots in two trees, compared
pixel for pixel (W1-W2 must stay within 1/255 of v3-base).

  python3 tools/perf/shot_diff.py                      # v3-base vs this copy, every W1-W2 level
  python3 tools/perf/shot_diff.py --seam               # this copy through the v3 light seam (world_seam.gd)
  python3 tools/perf/shot_diff.py --seam --field quarter   # Plan B against v3-base (expect small differences)
  python3 tools/perf/shot_diff.py --levels 2-4 --xs 0.9 --story --actions
  python3 tools/perf/shot_diff.py --base <tree> --head <tree> --out <dir> --tol 1

Both trees run tools/shot_render.gd (from the head tree, by absolute path) with
--fixed-fps 60, one seed and a fresh default save and settings, so two runs of
the same tree match exactly. The base tree is rsynced into the output folder
first (with its import cache) and given its own user dir, so the snapshot
itself is never written to. Prints a table and exits 1 when any shot differs
by more than the tolerance.
"""
import argparse
import os
import re
import shutil
import subprocess
import sys

GODOT = os.environ.get("GODOT", "/Users/antmacpro/Downloads/Godot.app/Contents/MacOS/Godot")
HERE = os.path.dirname(os.path.abspath(__file__))
HEAD = os.path.abspath(os.path.join(HERE, "..", ".."))
BASE = os.path.expanduser("~/Developer/waxby-snapshots/v3-base")
OUT = "/private/tmp/claude-501/waxby-ws-w0render/shot_diff"


def sh(cmd, cwd=None, log=None):
    p = subprocess.run(cmd, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    if log:
        with open(log, "w") as f:
            f.write(p.stdout)
    return p.returncode, p.stdout


def prepare_base(base, out, user_dir="waxby-v3-shotdiff-base"):
    """rsync the base tree's game/ (with .godot) to out/base_tree, own user dir."""
    dst = os.path.join(out, "base_tree")
    os.makedirs(dst, exist_ok=True)
    code, text = sh(["rsync", "-a", "--delete", "--exclude", ".godot", os.path.join(base, "game") + "/", os.path.join(dst, "game") + "/"])
    if code != 0:
        sys.exit("rsync failed: " + text)
    pg = os.path.join(dst, "game", "project.godot")
    s = open(pg).read()
    s = re.sub(r'config/use_custom_user_dir=.*\n', '', s)
    s = re.sub(r'config/custom_user_dir_name=.*\n', '', s)
    s = s.replace("[application]\n", '[application]\n\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="%s"\n' % user_dir, 1)
    open(pg, "w").write(s)
    # The snapshot may come without its import cache: import once (and after
    # the art changes), or every texture fails to load.
    stamp = os.path.join(dst, "game", ".godot", "imported")
    if not os.path.isdir(stamp) or not os.listdir(stamp):
        print("importing the base copy (once)...")
        sh([GODOT, "--headless", "--path", os.path.join(dst, "game"), "--import"], log=os.path.join(out, "base_import.log"))
    return dst


def shots(tree, out_dir, harness, extra, log):
    if os.path.isdir(out_dir):
        shutil.rmtree(out_dir)
    os.makedirs(out_dir)
    cmd = [GODOT, "--path", os.path.join(tree, "game"), "--resolution", "1266x585", "--fixed-fps", "60",
           "--script", harness, "--", "--out", out_dir] + extra
    code, text = sh(cmd, log=log)
    n = len([f for f in os.listdir(out_dir) if f.endswith(".png")])
    errs = [l for l in text.splitlines() if ("SCRIPT ERROR" in l or l.startswith("ERROR")) and "at exit" not in l]
    return code, n, errs


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default=BASE)
    ap.add_argument("--head", default=HEAD)
    ap.add_argument("--out", default=OUT)
    ap.add_argument("--levels", default="")
    ap.add_argument("--xs", default="")
    ap.add_argument("--seam", action="store_true")
    ap.add_argument("--field", default="")
    ap.add_argument("--story", action="store_true")
    ap.add_argument("--actions", action="store_true")
    ap.add_argument("--tol", type=int, default=1)
    ap.add_argument("--user-dir", default="waxby-v3-shotdiff-base", help="the base copy's custom user dir")
    ap.add_argument("--same", action="store_true", help="base = head (the noise floor: two runs of one tree)")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    harness = os.path.join(a.head, "tools", "shot_render.gd")
    common = []
    if a.levels:
        common += ["--levels", a.levels]
    if a.xs:
        common += ["--xs", a.xs]
    if a.story:
        common.append("--story")
    if a.actions:
        common.append("--actions")
    head_extra = list(common)
    if a.seam:
        head_extra.append("--seam")
    if a.field:
        head_extra += ["--field", a.field]
    base_tree = a.head if a.same else prepare_base(a.base, a.out, a.user_dir)
    base_extra = head_extra if a.same else common
    dir_a = os.path.join(a.out, "base")
    dir_b = os.path.join(a.out, "head")
    ca, na, ea = shots(base_tree, dir_a, harness, base_extra, os.path.join(a.out, "base.log"))
    cb, nb, eb = shots(a.head, dir_b, harness, head_extra, os.path.join(a.out, "head.log"))
    print("base: %s  %d shots  exit %d%s" % (base_tree, na, ca, ("  errors: %d" % len(ea)) if ea else ""))
    print("head: %s  %d shots  exit %d%s%s" % (a.head, nb, cb, "  (seam%s)" % (", field " + a.field if a.field else "") if a.seam else "",
                                              ("  errors: %d" % len(eb)) if eb else ""))
    for e in (ea + eb)[:12]:
        print("   ", e)
    code, text = sh([GODOT, "--headless", "--path", os.path.join(a.head, "game"), "--script",
                     os.path.join(a.head, "tools", "perf", "img_diff.gd"), "--", dir_a, dir_b, str(a.tol), os.path.join(a.out, "diffs")])
    for line in text.splitlines():
        if line.startswith("[diff]"):
            print(line)
    ok = code == 0 and na > 0 and na == nb
    print("IDENTICAL within %d/255" % a.tol if ok else "NOT IDENTICAL (see %s/diffs)" % a.out)
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
