"""WAXBY's cutscene art: the story panels, the figures that stand on them and
the dialogue portraits, plus art/story/panels.json, the manifest the
cutscene player (scripts/cutscene.gd) reads.

  game/art/story/sets/<panel>_<layer>.svg      panel layers (story_sets.py)
  game/art/story/figures/<id>.svg              256 frame, feet (128, 244), px 4 (story_figs.py)
  game/art/story/portraits/<who>_<mood>.svg    128 frame, face near (64, 62), px 6 (story_faces.py)
  game/art/story/panels.json                   everything the engine needs to place and light them

v3 (A5): the deeper worlds' art lives in modules found by name, so a new
set of panels, figures or portraits plugs in by being dropped here:
  story_sets_*.py    PANELS [fn -> Panel]; EXTEND {panel id: fn(entry)}, the
                     manifest-only additions to a v2 panel (anchors, lights)
  story_figs_*.py    FIGURES [fn -> (Fig, svg)]; EXTEND {figure id: fn(entry)}
  story_faces_*.py   CAST [(who, moods, colour, fn(mood) -> (svg, flames))];
                     MOODS_ADD [(who, mood, fn)], new moods for a v2 speaker
(every story_sets*.py, story_figs*.py and story_faces*.py but the v2 module
of that name: story_sets_deep.py, story_figs_deep.py, story_faces_deep.py.
The bosses' story figures and portraits are drawn with the fight's own
parts, in story_rootmother.py, story_tinker.py and story_saint.py, the
story_snuffer.py way.) A light or figure light may carry "off": true (E6: it
starts every shot dark until a cue lights it). The "off" lights EXTEND adds
to v2's art (undercandle's under_warm, the hush_eye figure's pupil) are held
back while scripts/cutscene.gd doesn't read "off" (a player without E6 would
light them in W2's own scenes); rebuild once it does.

Run from the repo root: python3 tools/art/story.py   (or through build.py)
  python3 tools/art/story.py --vendor   copies boss3/4/5.py's drawing (A4)
                                        into the three boss modules again
Look at it: godot --headless --path game --script res://../tools/art/story_sheet.gd -- <out_dir>

panels.json (the keys W4's player reads; "_doc" repeats this):
  panels.<id>
    size [W, H]          panel units
    dark [r, g, b]|null  the darkness colour (null: no darkness, glass_legend)
    motes                dust | snow | embers | wax | moths | null
    layers [..]          tex, depth (parallax), lit (not shaded by the
                         darkness), px (texture pixels per unit), rect
                         [x, y, w, h] (the panel area the texture covers: the
                         whole panel, 10% more on every side for a near layer,
                         or one tile: glass_legend's lancets are three tiles
                         side by side so no texture is wider than 4096 px).
                         Drawn with the figures strictly by depth (a figure at
                         its anchor's depth + 0.001), ties in list order; so
                         light falling from a far window to the floor is split
                         in two lit layers that cross-fade (chapel_beam and
                         chapel_pool, belfry_shafts and belfry_pools)
    lights.<id>          p, r, s, kind (flame | glow | eyes | cold), h (flame
                         height, flame and cold kinds; eyes: their size, the
                         eyes 5.2 h apart), depth (the layer it rides on),
                         color (eyes and tinted lights; tint repeats it),
                         pts and dot (eyes: the two eye points and their dot
                         radius), hidden (a darkness light with no flame)
    anchors.<id>         p (the feet), depth, h (overrides the figure's h here),
                         flip (figures are drawn facing right: flip mirrors
                         the figure about its feet, flame and eye points too,
                         x -> 2 feet.x - x), face (the actor's facing hint)
  figures.<id>           tex, frame [256, 256], feet, px, h (panel units the
                         whole frame covers at an anchor without its own h),
                         flames {name: [x, y, h, kind(, color)]} (frame units:
                         the flame's base and height; eyes: the point between
                         them and their size, 5.2 h apart; light id
                         <anchor>.<name>), light {name: {kind, r (frame
                         units), s, color, pts (eyes: the two eye points), dot}}
                         (the exact look: read it when it is there)
  portraits.<who>        moods [..], color, flame [x, y, h] (128 frame units:
                         the first mood's first live flame; left out when it
                         has none), flames [[x, y, h]..] (every live flame),
                         mood_flames {mood: [[x, y, h]..]} (overrides flames).
                         h is the flame's full height. Drawn cropped to the
                         circle of radius 0.42 (53.8 units) around (64, 62);
                         every flame sits inside it with its holder
"""
import importlib
import json
import re
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import story_sets
import story_figs
import story_faces

GAME = os.path.join(HERE, '..', '..', 'game')

DOC = {
    'units': 'panel units; figure and portrait points are in their frame units',
    'layers': 'rect is the panel area the texture covers; px = texture pixels per unit (scale a layer by '
              'scale_d / px); lit layers are not shaded by the darkness. Layers and figures draw strictly by depth '
              '(a figure at its anchor depth + 0.001), ties in list order, so light falling from a far window to '
              'the floor comes as two lit layers that cross-fade (chapel beam + pool, belfry shafts + pools)',
    'glass_legend': 'three glass tiles (glass_a/b/c, one lancet each, x 0/800/1600) and four mullion tiles, '
                    'so every texture is at most 4096 px wide; tiles of one depth move together',
    'lights': 'depth = the layer a light rides on; kind flame/cold draws a Glow flame of height h at p; '
              'glow is a darkness light only; eyes: pts (the two eyes), dot, color, and h (their size: 5.2 h apart); '
              'hidden: true = no flame; color (= tint) = the light colour',
    'anchors': 'p = where the figure feet go; h overrides the figure h; figures are drawn facing right and flip '
               'mirrors one about its feet, its flame and eye points too (x -> 2 feet.x - x); face is the actor facing hint',
    'figures': 'flames {name: [x, y, h, kind, color?]} in frame units (base of the flame, height; eyes: the '
               'point between them and their size, 5.2 h apart); a figure at anchor A lights A.name; '
               'light.name gives the exact look: kind, r (frame units), s, color, pts and dot (eyes)',
    'portraits': 'flame [x, y, h] in the 128 frame: the first mood\'s first live flame, left out when there is '
                 'none; flames lists every live flame, mood_flames overrides it per mood; h is the full flame height; '
                 'the dialogue box crops the frame to the circle of radius 0.42 (53.8 units) around (64, 62)',
}

IMPORT_TEMPLATE = """[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
mipmaps/generate=false
mipmaps/limit=-1
process/fix_alpha_border=true
process/premult_alpha=false
process/size_limit=0
detect_3d/compress_to=1
svg/scale=1.0
editor/scale_with_editor_scale=false
editor/convert_colors_with_editor_theme=false
"""


def found(prefix):
    """The v3 modules named <prefix>*.py beside this one (but <prefix>.py, the
    v2 module), alphabetically."""
    names = sorted(f[:-3] for f in os.listdir(HERE) if f.startswith(prefix) and f.endswith('.py') and f[:-3] != prefix)
    return [importlib.import_module(n) for n in names]


def engine_reads_off():
    """Whether the cutscene player reads a light's "off" (E6)."""
    path = os.path.join(GAME, 'scripts', 'cutscene.gd')
    return os.path.exists(path) and 'get("off"' in open(path).read()


def hold_back(entry, before, key_lights, key_flames=None):
    """Drops the "off" lights an EXTEND added to a v2 entry (not in before).
    Returns their names."""
    out = []
    lights = entry.get(key_lights, {})
    for lid in list(lights):
        if lid not in before and lights[lid].get('off'):
            del lights[lid]
            if key_flames:
                entry[key_flames].pop(lid, None)
            out.append(lid)
    if key_lights in entry and not entry[key_lights] and key_flames:
        del entry[key_lights]
    return out


def portrait_entry(moods, col, per):
    """A portraits.<who> entry from each mood's live flames: flame is the
    first mood's first flame (left out when it has none), flames the first
    mood's list, mood_flames every mood whose list differs from it."""
    first = per[moods[0]]
    entry = {'moods': list(moods), 'color': col}
    if first:
        entry['flame'] = first[0]
    entry['flames'] = first
    differs = {m: per[m] for m in moods if per[m] != first}
    if differs:
        entry['mood_flames'] = differs
    return entry


def collect():
    """Every file (rel path under game/ -> text) and the manifest."""
    files = {}
    panels = {}
    for p in story_sets.panels():
        files.update(p.files)
        panels[p.id] = p.manifest()
    figs, fig_files = story_figs.figures()
    files.update(fig_files)
    ports, port_files = story_faces.portraits()
    files.update(port_files)
    # v3: the deeper worlds (see the top of this file)
    e6 = engine_reads_off()
    held = []
    for mod in found('story_sets'):
        for fn in getattr(mod, 'PANELS', []):
            p = fn()
            assert p.id not in panels, 'panel %s twice' % p.id
            files.update(p.files)
            panels[p.id] = p.manifest()
        for pid, fn in getattr(mod, 'EXTEND', {}).items():
            before = set(panels[pid].get('lights', {}))
            fn(panels[pid])
            if not e6:
                held += ['%s.%s' % (pid, n) for n in hold_back(panels[pid], before, 'lights')]
    for mod in found('story_figs'):
        for fn in getattr(mod, 'FIGURES', []):
            fig, svg = fn()
            assert fig.id not in figs, 'figure %s twice' % fig.id
            figs[fig.id] = fig.entry()
            files['art/story/figures/%s.svg' % fig.id] = svg
        for fid, fn in getattr(mod, 'EXTEND', {}).items():
            before = set(figs[fid].get('light', {}))
            fn(figs[fid])
            if not e6:
                held += ['figure %s.%s' % (fid, n) for n in hold_back(figs[fid], before, 'light', 'flames')]
    if held:
        print('note: scripts/cutscene.gd does not read "off" yet (E6), so these v2 additions are held back: %s '
              '(rebuild once it does)' % ', '.join(held))
    for mod in found('story_faces'):
        for who, mood, fn in getattr(mod, 'MOODS_ADD', []):
            e = ports[who]
            per = {m: e.get('mood_flames', {}).get(m, e['flames']) for m in e['moods']}
            svg, flames = fn(mood)
            files['art/story/portraits/%s_%s.svg' % (who, mood)] = svg
            per[mood] = flames
            ports[who] = portrait_entry(e['moods'] + [mood], e['color'], per)
        for who, moods, col, fn in getattr(mod, 'CAST', []):
            assert who not in ports, 'portraits for %s twice' % who
            per = {}
            for mood in moods:
                svg, flames = fn(mood)
                files['art/story/portraits/%s_%s.svg' % (who, mood)] = svg
                per[mood] = flames
            ports[who] = portrait_entry(moods, col, per)
    manifest = {'_doc': DOC, 'panels': panels, 'figures': figs, 'portraits': ports}
    check(manifest, files)
    # The HUD's bark faces (hud.gd draws a face at radius 17: about 115 px on
    # the phone): each portrait again at 128 px, so a bark holds 87 KB, not
    # 3 MB, and loads in well under a millisecond on the main thread (the
    # int2 review: four W3 barks held 12 MB for the session, one load 19 ms).
    # The scenes keep the 768 px ones (the dialogue box shows them large).
    for rel in sorted(r for r in files if r.startswith('art/story/portraits/') and r.endswith('.svg')):
        files[rel.replace('art/story/portraits/', 'art/story/portraits_hud/')] = hud_face(files[rel])
    files['art/story/panels.json'] = json.dumps(manifest, indent=1, sort_keys=False) + '\n'
    return files


def hud_face(svg):
    """A portrait's SVG drawn at 128 px (its 128-unit frame at 1 px a unit)."""
    head, rest = svg.split('>', 1)
    head = re.sub(r'\bwidth="[0-9.]+"', 'width="128"', head, count=1)
    head = re.sub(r'\bheight="[0-9.]+"', 'height="128"', head, count=1)
    return head + '>' + rest


def check(m, files):
    """What the engine relies on: every referenced texture is written, no layer
    is wider than 4096 px, depths follow the px rule, ids are unique."""
    have = set('res://' + k for k in files)
    bad = []
    for pid, p in m['panels'].items():
        for lay in p['layers']:
            if lay['tex'] not in have:
                bad.append('%s: missing %s' % (pid, lay['tex']))
            w = lay['rect'][2] * lay['px']
            if w > 4096.5:
                bad.append('%s: %s is %d px wide' % (pid, lay['tex'], w))
            if lay['depth'] <= 0.7 and lay['px'] > 2.0:
                bad.append('%s: %s at depth %s uses px %s' % (pid, lay['tex'], lay['depth'], lay['px']))
    for fid, f in m['figures'].items():
        if f['tex'] not in have:
            bad.append('figure %s: missing %s' % (fid, f['tex']))
    for who, p in m['portraits'].items():
        for mood in p['moods']:
            t = 'res://art/story/portraits/%s_%s.svg' % (who, mood)
            if t not in have:
                bad.append('portrait %s' % t)
    for rel, text in files.items():
        if '<text' in text or '<filter' in text:
            bad.append('%s uses <text> or <filter>' % rel)
    if bad:
        raise SystemExit('story art check failed:\n  ' + '\n  '.join(bad))


def ensure_imports(files):
    """Panel layers import without mipmaps (decisions: Story, texture sizes).
    Writes a .import beside a new set SVG, or turns mipmaps off in an old one;
    Godot fills in the rest on the next import."""
    for rel in files:
        if not rel.startswith('art/story/sets/') or not rel.endswith('.svg'):
            continue
        path = os.path.normpath(os.path.join(GAME, rel + '.import'))
        if os.path.exists(path):
            text = open(path).read()
            if 'mipmaps/generate=true' in text:
                open(path, 'w').write(text.replace('mipmaps/generate=true', 'mipmaps/generate=false'))
        else:
            os.makedirs(os.path.dirname(path), exist_ok=True)
            open(path, 'w').write(IMPORT_TEMPLATE)


def build(write):
    """build.py's hook: write(rel_path, text) writes under game/."""
    files = collect()
    for rel, text in files.items():
        write(rel, text)
    ensure_imports(files)
    return sorted(files)


def files():
    """The older build.py interface (rel path -> text)."""
    return collect()


# ---------------------------------------------------------------- --vendor

# (A4's module, the story module it is copied into, the definitions the story
# calls: vendor() adds everything they use, and every colour constant)
VENDOR = [
    ('boss3.py', 'story_rootmother.py',
     ['frame', 'head', 'face_parts', 'crown_parts', 'trunk_parts', 'body_fn', 'arm', 'base_roots', 'root', 'bark_part',
      'petals_falling', 'skull_fruit', 'blossom', 'ember', 'PTS', 'Points', 'FOOT', 'GROUND', 'NECK', 'HEAD_AT', 'FAR_W',
      'NEAR_W', 'FACE_C', 'FACE_R', 'PAL', 'bez', 'smooth_d', 'poly_d', 'radial', 'motion', 'open_d', 'ribbon', 'along',
      'sub', 'ribbon_pts']),
    ('boss4.py', 'story_tinker.py',
     ['frame', 'head_parts', 'chest_face', 'bell_parts', 'case_parts', 'tickwell', 'frost_clump', 'gear', 'ball', 'tube',
      'brass', 'PTS', 'FOOT', 'GROUND', 'CASE', 'TICK', 'SPRING', 'HEAD_K', 'BELL', 'PAL']),
    ('boss5.py', 'story_saint.py',
     ['frame', 'part_halo', 'mask_parts', 'prism_parts', 'panes', 'hood_cells', 'HOOD', 'bodice_d', 'grid_cells',
      'tessel_pane', 'mantle_d', 'PTS', 'FOOT', 'HEART', 'HEART_R', 'DRAW_SCALE', 'PAL', 'GLASS', 'WARM', 'PRISM_W']),
]


def vendored(src, roots):
    """The top-level definitions of src the roots need (the closure of the
    names they use, and every colour constant), verbatim and in source
    order, each with the comment lines just above it."""
    import ast
    lines = src.split('\n')
    tree = ast.parse(src)

    def names(node):
        if isinstance(node, (ast.FunctionDef, ast.ClassDef)):
            return [node.name]
        out = []
        if isinstance(node, ast.Assign):
            for t in node.targets:
                if isinstance(t, ast.Name):
                    out.append(t.id)
                elif isinstance(t, ast.Tuple):
                    out += [e.id for e in t.elts if isinstance(e, ast.Name)]
        return out

    def colours(node):
        v = getattr(node, 'value', None)
        vals = v.elts if isinstance(v, (ast.Tuple, ast.List)) else [v]
        return isinstance(node, ast.Assign) and all(
            isinstance(e, ast.Constant) and isinstance(e.value, str) and len(e.value) == 7 and e.value.startswith('#') for e in vals)
    defs = {}
    for node in tree.body:
        for n in names(node):
            defs.setdefault(n, []).append(node)
    keep, seen = set(), set()
    stack = list(roots) + [n for node in tree.body if colours(node) for n in names(node)]
    while stack:
        n = stack.pop()
        if n in seen or n not in defs:
            continue
        seen.add(n)
        for node in defs[n]:
            keep.add(id(node))
            stack += [x.id for x in ast.walk(node) if isinstance(x, ast.Name)]
    missing = [r for r in roots if r not in seen]
    out, prev = [], 0
    for node in tree.body:
        if id(node) in keep:
            c = node.lineno - 1
            while c - 1 >= prev and lines[c - 1].lstrip().startswith('#'):
                c -= 1
            chunk = '\n'.join(lines[c:node.end_lineno])
            if isinstance(node, (ast.FunctionDef, ast.ClassDef)):
                out.append('\n\n' + chunk)
            else:
                out.append(('\n' if out and not out[-1].startswith('\n\n') else '') + chunk)
        prev = node.end_lineno
    return '\n'.join(t.rstrip('\n') for t in out).strip('\n') + '\n', missing


def vendor():
    """Copies A4's boss drawing (boss3/4/5.py beside this file) into the story
    modules, between their "vendored from bossN.py (A4)" rules."""
    for src, dst, roots in VENDOR:
        path = os.path.join(HERE, src)
        if not os.path.exists(path):
            raise SystemExit('--vendor: %s is not here (it is A4\'s: run this in a tree that has it)' % src)
        text, missing = vendored(open(path).read(), roots)
        if missing:
            raise SystemExit('--vendor: %s no longer has %s (update the story module and VENDOR)' % (src, ', '.join(missing)))
        out = os.path.join(HERE, dst)
        cur = open(out).read()
        rule = '# ================================================================ vendored from %s (A4): ' % src
        i, j = cur.index(rule + 'begin\n') + len(rule + 'begin\n'), cur.index(rule + 'end\n')
        open(out, 'w').write(cur[:i] + '\n' + text + '\n\n' + cur[j:])
        print('copied %s into %s (%d lines)' % (src, dst, text.count('\n')))


def main():
    if '--vendor' in sys.argv:
        vendor()
        return

    def write(rel, text):
        path = os.path.normpath(os.path.join(GAME, rel))
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'w') as f:
            f.write(text)
    # drop old story SVGs this build no longer writes, so nothing stale ships
    out = build(write)
    root = os.path.normpath(os.path.join(GAME, 'art', 'story'))
    keep = set(os.path.normpath(os.path.join(GAME, r)) for r in out)
    for dirpath, _, names in os.walk(root):
        for n in names:
            p = os.path.join(dirpath, n)
            if n.endswith('.svg') and p not in keep:
                os.remove(p)
                if os.path.exists(p + '.import'):
                    os.remove(p + '.import')
    print('wrote %d story files under game/art/story' % len(out))


if __name__ == '__main__':
    main()
