"""Writes every generated SVG into the game:
  game/art/wick/<part>.svg        Wick's parts rig and head faces   (wick.py, the fallback rig)
  game/art/heroes/<cls>/*         the five Callings' rigs, rig.json, portraits (heroes.py)
  game/art/items/<item>.svg       the loot icons                    (items_art.py)
  game/art/enemies/<frame>.svg    Rattle, Flit and Thornback        (enemies.py)
  game/art/enemies/boss_*.svg     Old Tollgrave, the World 1 boss   (boss.py)
  game/art/props/<prop>.svg       reliquaries, pickups, altar, bell (props.py)
  game/art/relics/<id>.svg        relic icons                       (relics.py)
  game/art/ui/<piece>.svg         HUD, touch buttons, the logo      (ui.py, logo.py)
  game/icon.svg                   the app icon                      (icon.py)
and whatever else lives here: every tools/art/*.py module that defines
build(write) is run with write(rel_path, text), which writes under game/;
a module that defines files() -> {rel_path: text} has those written. So a
new art module plugs in just by being dropped into this folder.
Run from the repo root: python3 tools/art/build.py [module ...]
Check the look with tools/art/sheet.gd (contact sheet PNGs).
"""
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

GAME = os.path.join(HERE, '..', '..', 'game')

# The known modules run first, in this order; anything else found in the
# folder runs after them, alphabetically.
MODULES = ['wick', 'heroes', 'items_art', 'enemies', 'boss', 'props', 'relics', 'ui', 'logo', 'icon']
HELPERS = {'build', 'common', 'kit'}   # imported by the others, never run


def write(rel, text):
    if '<text' in text or '<filter' in text:
        raise SystemExit('%s uses <text> or <filter>, which ThorVG cannot draw' % rel)
    path = os.path.normpath(os.path.join(GAME, rel))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w') as f:
        f.write(text)
    return rel


def modules():
    """Every art module in this folder, the known ones first."""
    found = sorted(f[:-3] for f in os.listdir(HERE) if f.endswith('.py') and f[:-3] not in HELPERS)
    return [m for m in MODULES if m in found] + [m for m in found if m not in MODULES]


def run(name, out):
    """Imports one module and writes what it makes. False if it has neither
    build(write) nor files() (a helper someone added: skipped)."""
    mod = __import__(name)
    if hasattr(mod, 'build'):
        mod.build(lambda rel, text: out.append(write(rel, text)))
    elif hasattr(mod, 'files'):
        for rel, text in mod.files().items():
            out.append(write(rel, text))
    else:
        return False
    return True


def main():
    only = sys.argv[1:]
    unknown = [m for m in only if m not in modules()]
    if unknown:
        raise SystemExit('no such art module: %s' % ', '.join(unknown))
    out = []
    for name in modules():
        if only and name not in only:
            continue
        try:
            if not run(name, out) and only:
                print('%s has no build(write) or files()' % name)
        except ImportError as e:
            if only:
                raise
            print('skip %s (%s)' % (name, e))
    print('wrote %d files under game/' % len(out))


if __name__ == '__main__':
    main()
