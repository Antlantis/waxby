#!/usr/bin/env python3
"""The App Store submission's export settings, made from the playtest's.

game/export_presets.cfg as committed is the playtest build's (TestFlight
build 5 on): its "iOS App Store" preset opens Documents to the Files app
(user_data/accessible_from_files_app and user_data/accessible_from_itunes_sharing,
so playlog.json can be sent) and carries the custom feature "playtest", which
turns Godot's file log on (project.godot: debug/file_logging/
enable_file_logging.playtest=true; it is off in a release build without it).

For the submission, tools/ios_release.sh --store runs this on the presets
for the length of the export, then puts the file back: in that one preset
Files access and file sharing go off and the "playtest" feature goes, and
nothing else changes (the build number above all). Nobody edits the preset
by hand.

    python3 tools/store_preset.py game/export_presets.cfg          # print the submission's presets
    python3 tools/store_preset.py --apply game/export_presets.cfg  # rewrite the file in place
    python3 tools/store_preset.py --build game/export_presets.cfg  # print the preset's build number

Exits 1 (and changes nothing) if the preset or any of its keys is missing.
"""
import re
import sys

PRESET = "iOS App Store"
FEATURE = "playtest"
OFF = ["user_data/accessible_from_files_app", "user_data/accessible_from_itunes_sharing"]


def _target(lines: list) -> str:
    ## Which [preset.N] is the App Store's.
    section, target = "", ""
    for line in lines:
        m = re.match(r"^\[(preset\.\d+)\]$", line)
        if m:
            section = m.group(1)
        elif section and line == 'name="%s"' % PRESET:
            target = section
    if target == "":
        raise SystemExit('store_preset: no preset named "%s"' % PRESET)
    return target


def build_number(text: str) -> str:
    ## The App Store preset's application/version (the build number App
    ## Store Connect lists), as ios_release.sh prints it.
    lines = text.split("\n")
    target, section = _target(lines), ""
    for line in lines:
        m = re.match(r"^\[(.+)\]$", line)
        if m:
            section = m.group(1)
        elif section == target + ".options" and line.startswith("application/version="):
            return line[len("application/version="):].strip('"')
    raise SystemExit("store_preset: %s has no application/version" % PRESET)


def store(text: str) -> str:
    lines = text.split("\n")
    target = _target(lines)
    out, section, seen = [], "", set()
    for line in lines:
        m = re.match(r"^\[(.+)\]$", line)
        if m:
            section = m.group(1)
        if section == target and line.startswith("custom_features="):
            feats = [f.strip() for f in line[len('custom_features="'):-1].split(",") if f.strip()]
            line = 'custom_features="%s"' % ",".join(f for f in feats if f != FEATURE)
            seen.add("custom_features")
        elif section == target + ".options":
            for key in OFF:
                if line.startswith(key + "="):
                    line = key + "=false"
                    seen.add(key)
        out.append(line)
    missing = [k for k in ["custom_features"] + OFF if k not in seen]
    if missing:
        raise SystemExit("store_preset: %s has no %s" % (PRESET, ", ".join(missing)))
    return "\n".join(out)


def main(argv: list) -> int:
    apply = "--apply" in argv
    paths = [a for a in argv if not a.startswith("--")]
    if len(paths) != 1:
        print(__doc__.strip())
        return 2
    text = open(paths[0]).read()
    if "--build" in argv:
        print(build_number(text))
        return 0
    new = store(text)
    if apply:
        with open(paths[0], "w") as f:
            f.write(new)
    else:
        sys.stdout.write(new)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
