"""Writes game/levels/*.txt from the level modules in tools/levels/.

Each module (w1.py ... w6.py, secrets.py, lab.py) exports LEVELS, a list of
entries whose sections are drawn side by side with common.block(); see
tools/levels/common.py for the format, the overlay row and the header
writers, and game/scripts/level_data.gd for the legend. A module that isn't
there yet is skipped, so a partial build still writes what it has.

World 1 (the Sunken Cathedral) keeps its v1 layouts with the v2 retrofit;
World 2 (the Tallow Deep) its four v2 levels: both are written byte for byte
as v2 wrote them (tests/test_export.gd holds their checksums).
The reachability bot in tests/test_core.gd must reach every sigil and bell;
tests/test_content.gd runs it again with the waxfalls on.

    python3 tools/make_levels.py            every module
    python3 tools/make_levels.py w1 lab     only these
"""
import importlib
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, 'levels'))
sys.dont_write_bytecode = True   # no __pycache__ beside the level modules

import common  # noqa: E402

# secrets before w3/w4: 3-3's and 4-2's set pieces are written only once 3-S.txt
# and 4-S.txt exist (w3.py SECRET_3S, w4.py SECRET_4S), so one pass from a clean
# tree writes them too.
MODULES = ['w1', 'w2', 'secrets', 'w3', 'w4', 'w5', 'w6', 'lab']


def main(names):
    written = []
    for name in names:
        if not os.path.exists(os.path.join(HERE, 'levels', name + '.py')):
            continue
        mod = importlib.import_module(name)
        for entry in getattr(mod, 'LEVELS', []):
            common.build(entry)
            written.append(entry['id'])
    return written


if __name__ == '__main__':
    main(sys.argv[1:] or MODULES)
