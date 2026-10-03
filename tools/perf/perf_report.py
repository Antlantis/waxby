#!/usr/bin/env python3
"""Reads godot.log files with [perf] and [spike] lines and checks the gate.

  python3 tools/perf/perf_report.py <godot.log> [...] [--dc-warn 650] [--dc-max 900]

The gate (decisions.md, spec §13.1), after the first 3 s of each run:
  every 2 s window >= 119 fps; worst frame <= 16.7 ms, i.e. at most one dropped
  frame (counted in vsync intervals: under 20.8 ms); average GPU <= 5.0 ms
  (when the driver reports it); draw calls <= 900 (a warning above 650);
  texmem <= 160 MB (the larger of the engine's count and the line's art
  estimate, which a freed scene can't make read low).
The spike's ramp windows (ids ending "+<n>") are stress by design and only
reported. Reads v2's line ("fps F worst frame W ms, draw calls D") and v3's
("fps F worst frame W ms dc D | gpu G ms rcpu R ms | ... | texmem X MB").
Exit 1 when a run fails the gate.
"""
import re
import sys

V3 = re.compile(r"\[perf\] (?P<id>\S+) fps (?P<fps>[\d.]+) worst(?: frame)? (?P<worst>[\d.]+) ms dc (?P<dc>\d+) \| gpu (?P<gpu>[\d.]+|n/a) ms "
                r"rcpu (?P<rcpu>[\d.]+) ms \| proc (?P<proc>[\d.]+) ms phys (?P<phys>[\d.]+) ms(?: bot (?P<bot>[\d.]+) ms)? \| lights (?P<lights>\d+) hush (?P<hush>\d+) "
                r"tint (?P<tint>\d+) refl (?P<refl>\d+) \| sparks (?P<sparks>\d+) motes (?P<motes>\d+) \| texmem (?P<tex>[\d.]+|n/a) MB"
                r"(?: art (?P<art>[\d.]+|n/a) MB)?")
V2 = re.compile(r"\[perf\] (?P<id>\S+) fps (?P<fps>[\d.]+) worst frame (?P<worst>[\d.]+) ms, draw calls (?P<dc>\d+)")
SKIP_WINDOWS = 2          # the first 3 s: two 2 s windows
WORST_MAX = 20.8          # ms: one dropped frame at 120 Hz reads 16.7-17.x; two read 25


def main():
    args = sys.argv[1:]
    dc_warn, dc_max = 650, 900
    files = []
    i = 0
    while i < len(args):
        if args[i] == "--dc-warn":
            dc_warn = int(args[i + 1]); i += 1
        elif args[i] == "--dc-max":
            dc_max = int(args[i + 1]); i += 1
        else:
            files.append(args[i])
        i += 1
    bad = 0
    for path in files:
        try:
            text = open(path, errors="replace").read()
        except OSError as e:
            print("%s: %s" % (path, e)); bad += 1; continue
        runs = {}
        spike = []
        hitches = 0
        for line in text.splitlines():
            m = V3.search(line) or V2.search(line)
            if m:
                runs.setdefault(m.group("id"), []).append(m.groupdict())
            elif "[spike]" in line:
                spike.append(line[line.index("[spike]"):])
            elif "hitch" in line and "[perf]" in line:
                hitches += 1
        print("== %s" % path)
        if not runs and not spike:
            print("   no [perf] lines (did the run start? is it a debug build?)"); bad += 1; continue
        print("   %-28s %5s %6s %6s %6s %5s %6s %6s %s" % ("run", "wins", "minfps", "worst", "gpu", "dc", "lights", "texMB", "gate"))
        for rid, ws in runs.items():
            stress = re.search(r"\+\d+$", rid) is not None
            # The spike warms up before it measures; a level's first 3 s are its build.
            use = ws if rid.startswith("spike:") or len(ws) <= SKIP_WINDOWS else ws[SKIP_WINDOWS:]
            minfps = min(float(w["fps"]) for w in use)
            worst = max(float(w["worst"]) for w in use)
            gpus = [float(w["gpu"]) for w in use if w.get("gpu") not in (None, "n/a")]
            gpu = sum(gpus) / len(gpus) if gpus else None
            dc = max(int(w["dc"]) for w in use)
            lights = max(int(w.get("lights") or 0) for w in use)
            texs = [float(w["tex"]) for w in use if w.get("tex") not in (None, "n/a") and float(w["tex"]) < 1e6]
            # The art estimate too (perf_meter: the engine's count reads low
            # once a scene has freed its pictures): the gate takes the larger.
            texs += [float(w["art"]) for w in use if w.get("art") not in (None, "n/a")]
            tex = max(texs) if texs else 0.0
            fails = []
            if minfps < 119.0:
                fails.append("fps")
            # One dropped frame is tolerated: frames come in vsync intervals
            # (8.33 ms), so anything under 2.5 intervals is at most one drop.
            if worst > WORST_MAX:
                fails.append("worst")
            if gpu is not None and gpu > 5.0:
                fails.append("gpu")
            if dc > dc_max:
                fails.append("dc")
            if tex > 160.0:
                fails.append("texmem")
            warn = " (dc > %d)" % dc_warn if dc > dc_warn and "dc" not in fails else ""
            verdict = "stress" if stress else ("ok" + warn if not fails else "FAIL " + ",".join(fails))
            if fails and not stress:
                bad += 1
            print("   %-28s %5d %6.1f %6.1f %6s %5d %6d %6.0f %s" % (rid, len(ws), minfps, worst, "%.2f" % gpu if gpu is not None else "n/a",
                                                             dc, lights, tex, verdict))
        if hitches:
            print("   hitch lines: %d" % hitches)
        for s in spike:
            print("   " + s)
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
