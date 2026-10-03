"""World 3's boss: Mother Gravebough, the Bone Gardener (boss id rootmother).

A colossal hunched mother-tree rooted into the right quarter of her arena: a
chibi grandmother of pale bark. A wimple of bark and moss frames a kind old
carved face whose eyelids are nearly shut. She has a long knotted root nose,
long root-arms and a crown of grey dead blossoms with little bone skulls
hanging in it like fruit. In her chest a hollow caged by roots holds a cold
blue ember: Mother Yarrow, grieving. During the Heart Run it runs out of her
along her roots and blooms at a socket (the bloom_* props), and her chest
goes dark (rootmother_hollow).

Frames: viewBox 0 0 384 384 at 768 px (2 units = 1 world px, like every
character), facing right (in her arena she faces left: flip the sprite),
root line (the "feet") at (192, 368). She stands about 360 units (180 px,
3.5 x Waxby) from her roots to the top of her crown, and about 345 units
(172 px) wide from hand to hand.

  rootmother_idle        rooted, swaying: the chest ember cold blue, both arms resting on the floor
  rootmother_dig         Root Spear tell: hunched over, both arms plunged into the soil, which cracks
  rootmother_sweep_low   Bough Sweep (low) tell: crouched, leaning into it; NO bough arm (see below)
  rootmother_sweep_high  Bough Sweep (high) tell: drawn up tall, leaning back; NO bough arm
  rootmother_breath      Spore Breath tell: her face swollen (x 1.18), cheeks puffed, the hood's hem
                         flared and its gills fanned out as broad fins glowing chartreuse
  rootmother_hollow      the Heart Run: the chest cage empty and dark, the ember gone
  rootmother_hurt        recoil: >< eyes, bark chips and petals flying
  rootmother_wilt        WILTED! and the phase roars: crown drooping and shedding, dizzy, sagging
  rootmother_bare        the P3 roar ("Deep Roots"): tearing herself up out of the soil, both arms
                         flung up, roaring, the ember flaring (drawn rooted like every frame: see P3)
  rootmother_die         the heart blooms in her crown (warm), eyes closed, settled and still

The bough: her near (front) arm in the two sweep frames is the three parts
rootmother_bough1 (shoulder root), _bough2 (a middle root that chains with
itself: repeat it joint to joint for any length) and _bough3 (the hand),
each a 224 x 96 frame drawn pointing right from its pivot (40, 48) to its
joint (184, 48), 52 units (26 px) thick: the Bough Sweep's 28 px band. The
code poses them from the frame's `bough` point (the shoulder), each turned
about its pivot; points_rootmother.json has the pivots, joints and the tell
and strike poses (each a chain of parts and absolute angles, 0 = the facing
direction, positive turns down). Every other frame draws that arm itself.
The strikes lie on the hurt bands: low 15 px (28 px tall: jump it), high
86 px (a thinner bough, x 0.6: its hurt band 78..94 px, its art 76..96 px,
over a standing Waxby's candle flame, under a row-10 ledge).

P3 ("Deep Roots": she tears her lower roots out and her trunk rises a
tile): the engine draws every frame RISE units (32 px) higher and the part
rootmother_legs (384 x 128: mangrove-like stilt roots, its floor line at
y 112) behind it, so every tell keeps its own frame; the *_p3 bough poses
start from the lifted shoulder.

Props (in art/enemies, 64-unit frames unless noted): bloom_bud (a pale
closed bud: modulate it toward amber for the blush), bloom_open (the amber
blossom, the hit target: its 56 x 56 unit box is the 28 x 28 px blossom
box), bloom_decoy (pale violet, unlit), root_spear (64 x 128: the 26 x 64 px
pillar the whole frame high, a flat root cap on top for its one-way ledge),
skull_seed, thorn (points down), root_hump (128 x 64: a solid block one
tile tall).

points_rootmother.json (frame units; world offset = (p - anchor) / 2 px):
per frame heart, eye_l, eye_r, face, mouth, crown, bough and trunk (the
body's box [x, y, w, h]); plus the bough parts, the poses, P3, where to
root her in her arena, the props' boxes and how a bloom sits on its socket.

This file also holds the helpers boss4.py, boss5.py and boss6.py share:
smooth outlines, tapered ribbons, the budget, the no-mipmap import and the
points file. Run on its own: python3 tools/art/boss3.py [--check] (--check writes nothing: it checks the
frames, the budget, the bough poses and that the big frames' .import files have mipmaps off).
"""
import json
import math
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import kit
from kit import Part, pth
from common import Ctx, RIM, svg, paint, line, dot, spec, mix, gx, flame_d
from boss import place, rot_pt, ell_d

GAME = os.path.normpath(os.path.join(HERE, '..', '..', 'game'))

# ================================================================ shared by boss3..boss6

MB = 1000000.0
NO_MIPS_FROM = 256        # frames this many units or more (either side) import without mipmaps
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
_HDR = re.compile(r'width="(\d+)" height="(\d+)" viewBox="0 0 (\d+) (\d+)"')


def header(text):
    """(px width, px height, viewBox width, viewBox height) of one of our SVGs."""
    m = _HDR.search(text)
    return tuple(int(m.group(i)) for i in range(1, 5)) if m else None


def no_mips(text):
    h = header(text)
    return h is not None and max(h[2], h[3]) >= NO_MIPS_FROM


def tex_bytes(text):
    """What the texture costs in video memory: RGBA8, plus a third for
    mipmaps when it keeps them (the small props do)."""
    w, h, _, _ = header(text)
    b = w * h * 4
    return b if no_mips(text) else b * 4 / 3.0


def budget(files):
    """Every texture's bytes and the total, in MB (10^6 bytes)."""
    rows = [(rel, tex_bytes(t) / MB) for rel, t in sorted(files.items()) if rel.endswith('.svg')]
    return rows, sum(r[1] for r in rows)


def check_art(files, who, limit_mb, expect):
    """The contract for one boss: every expected file is made, at the right
    frame (viewBox w x h at 2 px a unit), with no <text> or filters, and
    the whole set fits its texture budget. expect: {rel: (vw, vh)}."""
    bad = []
    for rel, (vw, vh) in expect.items():
        t = files.get(rel)
        if t is None:
            bad.append('%s is missing' % rel)
            continue
        h = header(t)
        if h != (vw * 2, vh * 2, vw, vh):
            bad.append('%s is %s, not a %dx%d frame at 2 px a unit' % (rel, h, vw, vh))
    for rel, t in files.items():
        if rel.endswith('.svg') and ('<text' in t or '<filter' in t):
            bad.append('%s uses <text> or <filter>' % rel)
    _, total = budget(files)
    if total > limit_mb:
        bad.append('%s uses %.2f MB of textures (budget %d MB)' % (who, total, limit_mb))
    if bad:
        raise SystemExit('%s art check failed:\n  %s' % (who, '\n  '.join(bad)))
    return total


def ensure_imports(files):
    """Frames of NO_MIPS_FROM units and up import without mipmaps (spec
    11.5: they are drawn about 1:1 on the phone, so mipmaps only cost a
    third more memory). Writes a .import beside a new SVG, or turns mipmaps
    off in an old one; Godot fills in the rest on the next --import."""
    for rel, text in files.items():
        if not rel.endswith('.svg') or not no_mips(text):
            continue
        path = os.path.normpath(os.path.join(GAME, rel + '.import'))
        if os.path.exists(path):
            old = open(path).read()
            if 'mipmaps/generate=false' not in old:
                open(path, 'w').write(old.replace('mipmaps/generate=true', 'mipmaps/generate=false'))
        else:
            os.makedirs(os.path.dirname(path), exist_ok=True)
            open(path, 'w').write(IMPORT_TEMPLATE)


def check_imports(files):
    """The imports on disk: every big frame's .import has mipmaps off (a missing
    .import is only a note: Godot writes it on --import, and build() fixes it)."""
    bad, missing = [], []
    for rel, text in sorted(files.items()):
        if not rel.endswith('.svg') or not no_mips(text):
            continue
        path = os.path.normpath(os.path.join(GAME, rel + '.import'))
        if not os.path.exists(path):
            missing.append(rel)
        elif 'mipmaps/generate=false' not in open(path).read():
            bad.append(rel)
    return bad, missing


def report(files, who, limit_mb):
    rows, total = budget(files)
    print('%s: %d textures, %.2f MB of %d MB' % (who, len(rows), total, limit_mb))
    for rel, mb in rows:
        print('   %6.3f MB  %s%s' % (mb, rel, '' if no_mips(files[rel]) else '  (mipmaps)'))


def run_main(files_fn, who, limit_mb, expect_fn):
    """The command line every boss module shares: write the files (and the
    no-mipmap imports), or with --check only check and report them."""
    files = files_fn()
    check_art(files, who, limit_mb, expect_fn())
    if '--check' not in sys.argv:
        import build as _b
        for rel, text in files.items():
            _b.write(rel, text)
        ensure_imports(files)
        print('wrote %d files under game/' % len(files))
    report(files, who, limit_mb)
    bad, missing = check_imports(files)
    for rel in missing:
        print('   note: %s has no .import yet (run --import)' % rel)
    if bad:
        raise SystemExit('%s: these import WITH mipmaps (run this module without --check, then --import):\n  %s'
                         % (who, '\n  '.join(bad)))


class Points:
    """Named points per frame, in frame units."""

    def __init__(self):
        self.d = {}

    def mark(self, frame, **pts):
        row = self.d.setdefault(frame, {})
        for k, v in pts.items():
            if isinstance(v, (tuple, list)) and len(v) in (2, 4) and not isinstance(v[0], (tuple, list)):
                row[k] = [round(float(c), 1) for c in v]
            else:
                row[k] = v

    def json(self, head):
        doc = dict(head)
        doc.update({k: v for k, v in sorted(self.d.items())})
        return json.dumps(doc, indent=1, sort_keys=True) + '\n'


# ---------------------------------------------------------------- outlines

def bez(p0, p1, p2, p3, n=12):
    """n + 1 points along a cubic Bezier."""
    out = []
    for i in range(n + 1):
        t = i / float(n)
        u = 1 - t
        out.append((u * u * u * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t * t * t * p3[0],
                    u * u * u * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t * t * t * p3[1]))
    return out


def smooth_d(pts, closed=True, k=1 / 6.0):
    """A smooth path through pts (Catmull-Rom as cubic Beziers)."""
    n = len(pts)

    def P(i):
        return pts[i % n] if closed else pts[min(max(i, 0), n - 1)]
    d = 'M%.2f %.2f' % tuple(pts[0])
    for i in range(n if closed else n - 1):
        p0, p1, p2, p3 = P(i - 1), P(i), P(i + 1), P(i + 2)
        c1 = (p1[0] + (p2[0] - p0[0]) * k, p1[1] + (p2[1] - p0[1]) * k)
        c2 = (p2[0] - (p3[0] - p1[0]) * k, p2[1] - (p3[1] - p1[1]) * k)
        d += ' C%.2f %.2f %.2f %.2f %.2f %.2f' % (c1 + c2 + tuple(p2))
    return d + (' Z' if closed else '')


def poly_d(pts):
    return 'M' + ' L'.join('%.2f %.2f' % tuple(p) for p in pts) + ' Z'


def _normals(pts):
    n = len(pts)
    out = []
    for i in range(n):
        a, b = pts[max(i - 1, 0)], pts[min(i + 1, n - 1)]
        tx, ty = b[0] - a[0], b[1] - a[1]
        ln = math.hypot(tx, ty) or 1.0
        out.append((-ty / ln, tx / ln, tx / ln, ty / ln))
    return out


def ribbon_pts(pts, widths, caps=(True, True)):
    """The outline points of a tapered ribbon along the centreline pts;
    widths is one width per point, or (start, end), or (start, mid, end)."""
    n = len(pts)
    if len(widths) != n:
        if len(widths) == 2:
            widths = [widths[0] + (widths[1] - widths[0]) * i / (n - 1.0) for i in range(n)]
        else:
            a, m, b = widths
            widths = []
            for i in range(n):
                t = i / (n - 1.0)
                widths.append(a * (1 - t) * (1 - 2 * t) + m * 4 * t * (1 - t) + b * t * (2 * t - 1))
    nm = _normals(pts)
    left = [(p[0] + q[0] * w / 2, p[1] + q[1] * w / 2) for p, q, w in zip(pts, nm, widths)]
    right = [(p[0] - q[0] * w / 2, p[1] - q[1] * w / 2) for p, q, w in zip(pts, nm, widths)]
    ring = list(left)
    if caps[1]:
        e, q, w = pts[-1], nm[-1], widths[-1]
        ring.append((e[0] + q[2] * w * 0.42, e[1] + q[3] * w * 0.42))
    ring += right[::-1]
    if caps[0]:
        s, q, w = pts[0], nm[0], widths[0]
        ring.append((s[0] - q[2] * w * 0.42, s[1] - q[3] * w * 0.42))
    return ring


def ribbon(pts, widths, caps=(True, True)):
    return smooth_d(ribbon_pts(pts, widths, caps))


def along(pts, t, off=0.0):
    """The point t (0..1) along a polyline, pushed off its left side by off."""
    n = len(pts) - 1
    f = min(max(t, 0.0), 1.0) * n
    i = min(int(f), n - 1)
    u = f - i
    (x0, y0), (x1, y1) = pts[i], pts[i + 1]
    ln = math.hypot(x1 - x0, y1 - y0) or 1.0
    return (x0 + (x1 - x0) * u - (y1 - y0) / ln * off, y0 + (y1 - y0) * u + (x1 - x0) / ln * off)


def sub(pts, t0, t1, off=0.0, n=10):
    """A stretch of a polyline from t0 to t1, pushed off its side."""
    return [along(pts, t0 + (t1 - t0) * i / float(n), off) for i in range(n + 1)]


def open_d(pts):
    return smooth_d(pts, closed=False)


def radial(ctx, cx, cy, r, col, op=0.6, squash=1.0):
    """A soft round glow (no outline): light, not a thing."""
    g = ctx.radgrad([(0, col, op), (0.45, col, op * 0.42), (1, col, 0)])
    return '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s"/>' % (cx, cy, r, r * squash, g)


def motion(d, w=2.0, op=0.9, ink='#0c0812'):
    return line(d, ink, w + 1.8, op=0.6) + line(d, '#ffffff', w, op=op)


# ================================================================ Gravebough's palette

L = '#1e140e'                                    # ink
BARK, BARK_SH, BARK_HI, BARK_DK = '#a8977a', '#7a6a52', '#d2c4a6', '#5c4e3c'
HOOD, HOOD_SH, HOOD_HI = '#cbbd9f', '#9a8a6c', '#ebe0c6'   # the wimple, a paler bark
FACE, FACE_SH, FACE_HI = '#e8dcc2', '#c4b594', '#f6eedc'
MOSS, MOSS_SH, MOSS_HI = '#6e8a44', '#4c6630', '#96ae62'
PETAL, PETAL_SH, PETAL_CORE = '#c9c1c6', '#9c93a0', '#6e6674'     # the dead grey blossoms
BONE, BONE_SH = '#ece2c6', '#bcae8c'
VOID = '#0c0806'
COLD, COLD_CORE, COLD_DEEP = '#a8d0ff', '#eef6ff', '#5a86c8'       # the caged ember
EYE_GLOW, EYE_CORE = '#d8f0c0', '#f6ffe8'
AMBER, AMBER_HI, AMBER_SH, AMBER_CORE = '#f2b84b', '#ffd98a', '#c8862a', '#fff2c8'
ROSE, ROSE_SH = '#f0c4cc', '#d894a4'                               # her crown in bloom (die)
VIOLET, VIOLET_SH, VIOLET_HI = '#c4b0e0', '#9682b8', '#e2d6f4'     # the decoy
SPORE = '#c8d46a'                                                  # W3's tell accent (the breath's gills only)
BLUSH = '#e0a0a0'
SOIL, SOIL_SH = '#5a4430', '#3a2a1c'
PAL = dict(line=L, rim=RIM, base=BARK, shade=BARK_SH)

FOOT = (192, 368)
GROUND = 368.0
FRAMES = ['idle', 'dig', 'sweep_low', 'sweep_high', 'breath', 'hollow', 'hurt', 'wilt', 'bare', 'die']
PROPS = {'bloom_bud': (64, 64), 'bloom_open': (64, 64), 'bloom_decoy': (64, 64), 'root_spear': (64, 128),
         'skull_seed': (64, 64), 'thorn': (64, 64), 'root_hump': (128, 64)}
BOUGH = (224, 96)
BOUGH_PIVOT, BOUGH_JOINT, BOUGH_W = (40.0, 48.0), (184.0, 48.0), 52.0
BUDGET_MB = 28
PLACE_WALL_DX = 48.0      # her anchor this many px right of R_ARENA's right wall face (see points' _placement)

PTS = Points()


# ================================================================ her pieces

def bark_part(d, fill=BARK, shade=BARK_SH, off=(-5, -4), over='', hl='', under='', rim=True, lw=None):
    return Part('fill', pth(d), fill=fill, shade=shade, off=off, over=over, hl=hl, under=under, rim=rim, lw=lw)


def grooves(pts, widths, n=2, col=BARK_DK, w=1.4, op=0.75, t0=0.12, t1=0.88):
    """Bark grooves running along a ribbon's centreline."""
    s = ''
    if isinstance(widths, (int, float)):
        widths = (widths, widths)
    for i in range(n):
        k = (i + 1.0) / (n + 1) - 0.5
        a, b = t0 + 0.05 * i, t1 - 0.07 * (n - i)
        off = k * (widths[0] + widths[-1]) * 0.36
        s += line(open_d(sub(pts, a, b, off, 8)), col, w, op=op)
    return s


def root(pts, widths, fill=BARK, shade=BARK_SH, n_groove=1, hi=True, caps=(True, True), rim=True):
    """A root: a tapered bark ribbon with a groove and a lit edge."""
    over = grooves(pts, widths, n_groove) if n_groove else ''
    hl = ''
    if hi:
        w0 = widths[0] if not isinstance(widths, (int, float)) else widths
        hl = line(open_d(sub(pts, 0.08, 0.7, w0 * 0.3, 8)), BARK_HI, 1.8, op=0.8)
    return bark_part(ribbon(pts, widths, caps), fill=fill, shade=shade, off=(-2.5, -3), over=over, hl=hl, rim=rim)


def hand_parts(wrist, ang, spread=1.0, curl=0.0, into=False, k=1.0):
    """A knobbly root hand at the wrist, its fingers toward ang degrees: a
    knot of a palm and four long twig fingers (and a thumb). into: the
    finger tips bend down into the soil (they end on the floor)."""
    x, y = wrist
    a = math.radians(ang)
    ux, uy = math.cos(a), math.sin(a)
    nx, ny = -uy, ux
    P = []
    palm = (x + ux * 14 * k, y + uy * 14 * k)
    for i, (off, ln, bend) in enumerate(((-1.5, 34, -0.35), (-0.5, 42, -0.12), (0.5, 40, 0.1), (1.5, 32, 0.32))):
        o = off * 8 * spread * k
        base = (palm[0] + nx * o + ux * 6 * k, palm[1] + ny * o + uy * 6 * k)
        fa = a + (bend * spread + curl * 0.5) * 1.0
        tip = (base[0] + math.cos(fa) * ln * k, base[1] + math.sin(fa) * ln * k)
        mid = (base[0] + math.cos(fa - curl * 0.4) * ln * 0.55 * k, base[1] + math.sin(fa - curl * 0.4) * ln * 0.55 * k)
        if into:
            tip = (tip[0], GROUND + 1)
            mid = (mid[0], min(mid[1], GROUND - 4))
        pts = bez(base, mid, mid, tip, 8)
        P.append(root(pts, (11 * k, 4.4 * k), n_groove=0, hi=False))
    th = (palm[0] - nx * 14 * k - ux * 2, palm[1] - ny * 14 * k - uy * 2)
    tt = (th[0] - nx * 12 * k + ux * 16 * k, th[1] - ny * 12 * k + uy * 16 * k)
    if into:
        th, tt = (th[0], min(th[1], GROUND - 4)), (tt[0], min(tt[1], GROUND))
    P.append(root(bez(th, th, tt, tt, 6), (10 * k, 4 * k), n_groove=0, hi=False))
    P.append(bark_part(ell_d(palm[0], palm[1], 17 * k, 14 * k, ang), off=(-2, -2.4),
                       over=line('M%.1f %.1f q4 -3 8 0' % (palm[0] - 4, palm[1] - 2), BARK_DK, 1.4, op=0.8)))
    return P


def arm(shoulder, elbow, wrist, w=(50, 36), hand_ang=0.0, spread=1.0, curl=0.0, into=False, hand=True):
    """A long root arm from the shoulder through the elbow to the wrist."""
    pts = bez(shoulder, elbow, elbow, wrist, 14)
    P = [root(pts, (w[0], (w[0] + w[1]) * 0.5, w[1]), n_groove=2)]
    # a knot ring round the elbow
    ex, ey = along(pts, 0.5)
    P[0].over += line('M%.1f %.1f q6 5 12 0' % (ex - 6, ey - 4), BARK_DK, 1.6, op=0.8)
    if hand:
        P += hand_parts(wrist, hand_ang, spread, curl, into)
    return P


def skull_fruit(ctx, x, y, s=1.0, rot=0.0):
    """A little bone skull hanging like a fruit, its stem's top at (x, y)."""
    t = 'translate(%.1f %.1f) rotate(%.1f) scale(%.2f)' % (x, y, rot, s)
    head = 'M0 6 C8 6 13 12 13 20 C13 26 10 29 7 30 L7 34 L-7 34 L-7 30 C-10 29 -13 26 -13 20 C-13 12 -8 6 0 6 Z'
    face = ('<path d="%s" fill="%s"/>' % (ell_d(-5, 20, 3.6, 4, -8), L) + '<path d="%s" fill="%s"/>' % (ell_d(5, 20, 3.6, 4, 8), L)
            + '<path d="M-1.4 26 L0 23.6 L1.4 26 Z" fill="%s"/>' % L
            + line('M-5 31.4 L5 31.4 M-2.6 30 L-2.6 33.6 M0 30 L0 33.6 M2.6 30 L2.6 33.6', L, 1.0, op=0.85))
    P = [Part('limb', pth('M0 0 Q2 3 0 7'), width=1.8, fill=BARK_SH),
         Part('fill', pth(head), fill=BONE, shade=BONE_SH, off=(-2, -2), over=face,
              hl=spec(-5, 12, 3, 1.8, rot=-30, op=0.8)),
         Part('fill', pth('M1 1 C5 -4 11 -3 13 0 C9 2 5 3 1 1 Z'), fill=MOSS, shade=MOSS_SH, off=(-0.6, -0.8))]
    return place(P, t)


def blossom(ctx, x, y, r, col=PETAL, sh=PETAL_SH, core=PETAL_CORE, rot=0.0, droop=0.0, n=5, glow=None):
    """A five-petal blossom seen face on (droop squashes it, hanging)."""
    t = 'translate(%.1f %.1f) rotate(%.1f) scale(1 %.2f)' % (x, y, rot, 1.0 - droop * 0.45)
    P = []
    for i in range(n):
        a = math.radians(-90 + i * 360.0 / n)
        cx, cy = math.cos(a) * r * 0.55, math.sin(a) * r * 0.55
        P.append(Part('fill', pth(ell_d(cx, cy, r * 0.52, r * 0.4, math.degrees(a))), fill=col, shade=sh, off=(-1, -1.2),
                      lw=1.1))
    c = Part('fill', pth(ell_d(0, 0, r * 0.3, r * 0.3)), fill=core, shade=mix(core, L, 0.35), off=(-0.6, -0.6), lw=1.0)
    if glow:
        c.over = dot(0, 0, r * 0.14, glow)
    P.append(c)
    return place(P, t)


def ember(ctx, cx, cy, h, col=COLD, core=COLD_CORE, deep=COLD_DEEP, halo=1.0):
    """The caged heart: a teardrop flame with a soft halo (no ink: it's light)."""
    s = radial(ctx, cx, cy - h * 0.35, h * 1.3 * halo, col, 0.7)
    s += '<path d="%s" fill="%s" stroke="%s" stroke-width="1.4"/>' % (flame_d(cx, cy, h * 0.62, h), col, deep)
    s += '<path d="%s" fill="%s"/>' % (flame_d(cx, cy - h * 0.05, h * 0.36, h * 0.62), core)
    return s


# ---------------------------------------------------------------- the head

WIMPLE = [(16, -92), (62, -82), (96, -50), (106, -4), (102, 42), (92, 76), (62, 94), (16, 100), (-32, 98), (-74, 90),
          (-98, 64), (-106, 18), (-100, -34), (-76, -70), (-36, -90)]
FACE_C = (18, 10)


def hood_outline(n=64, bump=3.6, lobes=13):
    """WIMPLE sampled smooth, its upper edge scalloped into overlapping bark plates."""
    m = len(WIMPLE)
    out = []
    for i in range(n):
        f = i * m / float(n)
        j = int(f)
        t = f - j
        p0, p1, p2, p3 = WIMPLE[(j - 1) % m], WIMPLE[j], WIMPLE[(j + 1) % m], WIMPLE[(j + 2) % m]
        # Catmull-Rom
        x = 0.5 * ((2 * p1[0]) + (-p0[0] + p2[0]) * t + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t * t
                   + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t * t * t)
        y = 0.5 * ((2 * p1[1]) + (-p0[1] + p2[1]) * t + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t * t
                   + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t * t * t)
        if y < 50:
            k = abs(math.sin(i / float(n) * lobes * math.pi)) * bump * min(1.0, (50 - y) / 40.0)
            ln = math.hypot(x - 8, y + 10) or 1.0
            x, y = x + (x - 8) / ln * k, y + (y + 10) / ln * k
        out.append((x, y))
    return out
FACE_R = (62, 62)
FACE_SWELL = 1.18          # Spore Breath: her face swells this much
HOOD_FLARE = 0.16          # ...and the hood's hem flares out this much


def gill_fins(ctx, FL):
    """Spore Breath: the hood's gills fanned out from under its sides as broad
    fins glowing W3's chartreuse (the only place SPORE is used), each with a
    soft r 30 glow under it."""
    P = []
    for side in (-1, 1):
        for i, y in enumerate((-18, 6, 30)):
            ex = FL((side * 103.0, y))[0]
            xb = ex - side * 8
            ln = (32, 38, 30)[i]
            fin = smooth_d([(xb, y - 7), (xb + side * ln * 0.5, y - 9), (xb + side * ln, y + 1 + i),
                            (xb + side * ln * 0.5, y + 8), (xb, y + 7)])
            core = 'M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (xb + side * 3, y, xb + side * ln * 0.5, y - 2, xb + side * (ln - 5), y + 1 + i)
            P.append(Part('fill', pth(fin), fill=SPORE, shade=mix(SPORE, MOSS_SH, 0.45), off=(-1.5, -1.5), lw=2.0,
                          under=radial(ctx, xb + side * ln * 0.55, y, 30, SPORE, 0.42),
                          over=line(core, '#f4fac8', 2.2, op=0.95)))
    return P


def head(ctx, eyes='sleepy', mouth='smile', crown='dead', puff=False, gills=False, fx_out=None):
    """Her head local to its centre (0, 0): the bark wimple with its moss
    shawl, the carved face in its opening (shifted right: she faces right),
    the crown of branches on top. crown: dead (grey blossoms and skull
    fruit), droop (shedding), bare (twigs), bloom (warm, her heart in it).
    Returns (parts, over) and leaves the local points in fx_out."""
    P = []
    over = ''
    pts = fx_out if fx_out is not None else {}
    # Spore Breath swells her: the face puffs out (x FACE_SWELL) and the hood
    # flares wide at its hem (HOOD_FLARE), its gills out as glowing fins
    flare = HOOD_FLARE if puff else 0.0

    def FL(p):
        t = min(1.0, max(0.0, (p[1] + 40.0) / 110.0))
        return (p[0] * (1.0 + flare * t), p[1])
    # ---- the crown, behind the wimple
    P += crown_parts(ctx, crown, pts)
    if gills:
        P += gill_fins(ctx, FL)
    # ---- the wimple: bark plates (a scalloped edge), grooves following the dome
    wd = smooth_d([FL(q) for q in hood_outline()])
    f = ''
    for x0, x1, b in ((-70, -92, -6), (-44, -72, -2), (46, 78, 2), (70, 96, 6)):
        f += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (x0 * 0.6 + 8, -84, x1 + b, -20, x1 * 1.02, 60), HOOD_SH, 2.2, op=0.9)
    f += line('M-8 -88 Q-16 -64 -14 -56 M36 -88 Q44 -66 44 -56', HOOD_SH, 2, op=0.8)
    # knots
    f += '<path d="%s" fill="%s"/>' % (ell_d(-82, 26, 6, 8), HOOD_SH) + '<path d="%s" fill="%s"/>' % (ell_d(-82, 26, 2.8, 4.2), L)
    gx_ = ((-1, -92), (1, 98))
    if not gills:
        for side, x in gx_:
            for y in (-12, 6, 24):
                f += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (x, y, x + side * 5, y + 6, x, y + 12), L, 2, op=0.6)
    hl = line('M-76 -52 Q-54 -80 -12 -88', HOOD_HI, 3.6, op=0.9) + line('M-96 -10 Q-96 -32 -86 -46', HOOD_HI, 2.2, op=0.7)
    P.append(Part('fill', pth(wd), fill=HOOD, shade=HOOD_SH, off=(-7, -7), over=f, hl=hl))
    # ---- the moss shawl under the face and round the hem
    moss = smooth_d([FL(q) for q in [(-100, 50), (-64, 66), (-20, 72), (26, 72), (66, 64), (98, 48), (100, 66), (88, 86),
                                    (76, 98), (62, 90), (48, 104), (32, 94), (16, 108), (0, 96), (-16, 108), (-32, 96),
                                    (-50, 106), (-64, 92), (-80, 100), (-94, 84), (-104, 68)]])
    mo = ''.join(dot(x, y, r, MOSS_HI, 0.8) for x, y, r in ((-76, 78, 2.6), (-44, 84, 2.2), (-8, 86, 2.8), (34, 82, 2.2),
                                                             (68, 76, 2.6), (-58, 94, 1.8), (14, 98, 1.8)))
    P.append(Part('fill', pth(moss), fill=MOSS, shade=MOSS_SH, off=(-2, -3), over=mo,
                  hl=line('M-90 58 Q-40 76 20 76', MOSS_HI, 2, op=0.8)))
    # ---- the face in its opening
    fcx, fcy = FACE_C
    rx, ry = FACE_R[0] * (FACE_SWELL if puff else 1.0), FACE_R[1] * (FACE_SWELL if puff else 1.0)
    face_d = ell_d(fcx, fcy, rx, ry)
    P.append(Part('fill', pth(face_d), fill=FACE, shade=FACE_SH, off=(-4, -5),
                  hl=spec(fcx - 32, fcy - 32, 11, 5.4, rot=-30, op=0.55)))
    over += face_parts(ctx, fcx, fcy, eyes, mouth, puff, pts)
    # a lip of bark round the opening (drawn over the face's edge)
    over += '<path d="%s" fill="none" stroke="%s" stroke-width="6"/>' % (face_d, HOOD_SH)
    over += '<path d="%s" fill="none" stroke="%s" stroke-width="1.8"/>' % (ell_d(fcx, fcy, rx + 3.2, ry + 3.2), L)
    over += '<path d="%s" fill="none" stroke="%s" stroke-width="1.4" opacity="0.9"/>' % (face_d, L)
    pts['face'] = (fcx, fcy + 6)
    return P, over


def face_parts(ctx, cx, cy, eyes, mouth, puff, pts):
    """The carved face: heavy-lidded eyes over a glowing slit, crow's feet,
    a long knotted root nose, blush and a small mouth."""
    s = ''
    E = [(cx - 27, cy - 6, 34), (cx + 26, cy - 8, 32)]
    pts['eye_l'], pts['eye_r'] = (E[0][0], E[0][1] + 4), (E[1][0], E[1][1] + 4)
    # brows: soft bark ridges
    for i, (x, y, w) in enumerate(E):
        k = -1 if i == 0 else 1
        if eyes in ('fierce', 'glare'):
            d = 'M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (x - w * 0.55, y - 17 + 4 * k, x, y - 17, x + w * 0.55, y - 17 - 4 * k)
            s += line(d, FACE_SH, 6) + line(d, L, 2.2)
        elif eyes == 'sad' or eyes == 'glare_sad':
            d = 'M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (x - w * 0.55, y - 14 - 4 * k, x, y - 19, x + w * 0.55, y - 14 + 4 * k)
            s += line(d, FACE_SH, 6) + line(d, L, 2.0)
        else:
            d = 'M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (x - w * 0.5, y - 14, x, y - 20, x + w * 0.5, y - 14)
            s += line(d, FACE_SH, 5, op=0.9) + line(d, BARK_DK, 1.4, op=0.8)
    for i, (x, y, w) in enumerate(E):
        k = -1 if i == 0 else 1
        hw = w / 2.0
        if eyes in ('sleepy', 'watch', 'fierce', 'glare', 'sad', 'glare_sad'):
            open_h = {'sleepy': 4.6, 'watch': 8.0, 'fierce': 9.0, 'glare': 12.0, 'sad': 7.0, 'glare_sad': 11.0}[eyes]
            # the socket: dark under the heavy lid
            sock = 'M%.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f Z' % (
                x - hw, y, x, y - open_h * 1.4, x + hw, y, x, y + open_h * 0.9, x - hw, y)
            s += '<path d="%s" fill="%s"/>' % (sock, '#2a2016')
            # the glowing slit between the lids
            s += radial(ctx, x, y + 1, w * 0.9, EYE_GLOW, 0.5, 0.5)
            slit = 'M%.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f Z' % (
                x - hw * 0.8, y + 0.4, x, y - open_h * 0.9, x + hw * 0.8, y + 0.4, x, y + open_h * 0.55, x - hw * 0.8, y + 0.4)
            s += '<path d="%s" fill="%s"/>' % (slit, EYE_GLOW)
            if open_h > 6:
                s += dot(x + 2, y - 0.6, min(open_h * 0.34, 3.4), EYE_CORE)
            # the heavy upper lid: a thick carved curve drooping over it
            lid = 'M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (x - hw - 2, y + 1.2, x, y - open_h * 1.2 - 2, x + hw + 2, y + 1.2)
            s += line(lid, L, 4.2)
            s += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (x - hw + 3, y - open_h - 3.5, x, y - open_h * 1.4 - 6,
                                                          x + hw - 3, y - open_h - 3.5), FACE_SH, 2.4, op=0.9)
            # lower lid line and crow's feet
            s += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (x - hw * 0.7, y + open_h * 0.7 + 1.6, x, y + open_h + 3, x + hw * 0.7,
                                                          y + open_h * 0.7 + 1.6), BARK_DK, 1.2, op=0.7)
            ox = x + k * (hw + 3)
            s += line('M%.1f %.1f l%.1f %.1f M%.1f %.1f l%.1f %.1f' % (ox, y - 1, k * 6, -3, ox, y + 2, k * 6, 2), BARK_DK, 1.2, op=0.75)
        elif eyes in ('strain', 'hurt'):
            s += line('M%.1f %.1f L%.1f %.1f L%.1f %.1f' % (x - k * hw * 0.8, y - 7, x + k * hw * 0.6, y - 0.6, x - k * hw * 0.8, y + 5.4), L, 4.2)
            s += line('M%.1f %.1f l%.1f %.1f' % (x + k * (hw + 2), y - 6, k * 6, -4), BARK_DK, 1.4)
        elif eyes == 'shut':
            d = 'M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (x - hw, y - 1, x, y + 5, x + hw, y - 1)
            s += line(d, L, 4.2)
            s += line('M%.1f %.1f l%.1f %.1f M%.1f %.1f l%.1f %.1f' % (x + k * hw, y - 4, k * 6, -4, x + k * hw, y + 1, k * 7, 0), BARK_DK, 1.4)
        elif eyes == 'dizzy':
            s += '<path d="%s" fill="%s"/>' % (ell_d(x, y, hw * 0.8, 8), '#2a2016')
            d = 'M%.1f %.1f' % (x, y)
            for j in range(1, 23):
                t = j / 22.0
                a = t * 4.2 * math.pi
                d += ' L%.2f %.2f' % (x + 7.4 * t * math.cos(a), y + 7.4 * t * math.sin(a) * 0.9)
            s += line(d, EYE_GLOW, 2.0)
        elif eyes == 'peace':
            d = 'M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (x - hw, y - 2, x, y + 6, x + hw, y - 2)
            s += line(d, L, 4.0)
            s += line('M%.1f %.1f l%.1f %.1f M%.1f %.1f l%.1f %.1f' % (x - hw + 3, y + 2, -2, 4, x + hw - 3, y + 2, 2, 4), L, 1.6, op=0.8)
    # blush
    for x, y in ((cx - 32, cy + 20), (cx + 34, cy + 17)):
        if puff:
            k = -1 if x < cx else 1
            x, y = x + k * 8, y + 6
            s += '<path d="%s" fill="%s" opacity="0.5"/>' % (ell_d(x, y, 19, 14), BLUSH)
            s += line('M%.1f %.1f q4 -6 10 -3' % (x - 10, y - 8), FACE_HI, 2.6, op=0.9)
            s += line('M%.1f %.1f q%.1f 8 0 16' % (x + k * 14, y - 6, k * 6), FACE_SH, 2.0, op=0.8)
        else:
            s += '<path d="%s" fill="%s" opacity="0.38"/>' % (ell_d(x, y, 11, 6.4), BLUSH)
    # the long knotted root nose, between the eyes and a little right
    nx, ny = cx + 4, cy + 2
    s += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (nx - 1, ny - 12, nx + 2, ny - 2, nx + 3, ny + 8), FACE_SH, 5, op=0.9)
    s += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (nx - 1, ny - 12, nx + 2, ny - 2, nx + 3, ny + 8), BARK_DK, 1.4, op=0.8)
    knob = smooth_d([(nx - 8, ny + 14), (nx - 2, ny + 6), (nx + 8, ny + 5), (nx + 14, ny + 12), (nx + 12, ny + 21),
                     (nx + 3, ny + 24), (nx - 6, ny + 21)])
    s += '<path d="%s" fill="%s" stroke="%s" stroke-width="2" stroke-linejoin="round"/>' % (knob, mix(FACE, HOOD, 0.45), L)
    s += '<path d="%s" fill="%s" opacity="0.9"/>' % (ell_d(nx + 1, ny + 11, 4.4, 2.8, -20), FACE_HI)
    s += line('M%.1f %.1f q3 2 6 0' % (nx - 1, ny + 19), BARK_DK, 1.2, op=0.7)
    # the mouth
    mx, my = cx + 8, cy + 42
    pts['mouth'] = (mx, my)
    if mouth == 'smile':
        s += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (mx - 12, my - 1, mx, my + 6, mx + 12, my - 2), L, 2.6)
        s += line('M%.1f %.1f l-2 -2 M%.1f %.1f l2 -2' % (mx - 12, my - 1, mx + 12, my - 2), L, 1.6)
    elif mouth == 'sad':
        s += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (mx - 11, my + 3, mx, my - 3, mx + 11, my + 3), L, 2.6)
    elif mouth == 'tight':
        s += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f' % (mx - 12, my, mx - 6, my + 3, mx, my, mx + 6, my - 3, mx + 12, my), L, 2.6)
    elif mouth == 'o':
        s += '<path d="%s" fill="%s" stroke="%s" stroke-width="2"/>' % (ell_d(mx + 4, my + 2, 6.4, 7.4), '#2a1810', L)
        s += line('M%.1f %.1f q-4 -2 -6 1 M%.1f %.1f q4 -2 6 1' % (mx - 4, my - 4, mx + 12, my - 4), BARK_DK, 1.4)
    elif mouth in ('open', 'roar'):
        h = 12 if mouth == 'open' else 18
        m = 'M%.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f Z' % (mx - 14, my - 2, mx, my - 5, mx + 14, my - 3, mx, my + h, mx - 14, my - 2)
        s += '<path d="%s" fill="%s" stroke="%s" stroke-width="2.4" stroke-linejoin="round"/>' % (m, '#2a1810', L)
        s += '<path d="M%.1f %.1f Q%.1f %.1f %.1f %.1f Z" fill="%s" opacity="0.9"/>' % (mx - 6, my + h * 0.6, mx, my + h * 0.3, mx + 6, my + h * 0.6, '#c87070')
    elif mouth == 'sigh':
        s += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (mx - 9, my, mx, my + 5, mx + 9, my - 1), L, 2.4)
        s += '<path d="%s" fill="%s" stroke="%s" stroke-width="1.6"/>' % (ell_d(mx + 1, my + 2.4, 3, 2.2), '#2a1810', L)
    # two soft wrinkles on the forehead
    s += line('M%.1f %.1f q10 -3 20 0 M%.1f %.1f q8 -2 14 0' % (cx - 12, cy - 38, cx - 8, cy - 32), BARK_DK, 1.2, op=0.5)
    return s


# The crown's branches, local to the head's centre: centreline and widths.
CROWN = [
    ([(-34, -80), (-69, -100), (-101, -100), (-126, -82)], (12, 5)),
    ([(-12, -88), (-22, -104), (-34, -112), (-52, -114)], (10, 4)),
    ([(21, -90), (29, -104), (43, -112), (60, -114)], (10, 4)),
    ([(46, -82), (77, -100), (105, -100), (126, -84)], (12, 5)),
    ([(-67, -62), (-95, -68), (-112, -60), (-124, -44)], (10, 3.6)),
    ([(74, -60), (98, -68), (114, -60), (124, -46)], (10, 3.6)),
]
SKULLS = [(-126, -82, 1.05, 6), (126, -84, 1.05, -6), (-83, -100, 0.85, 4), (89, -100, 0.8, -4)]
BLOSSOMS = [(-103, -102, 12), (-115, -92, 9), (-69, -102, 10), (-34, -112, 12), (-52, -116, 9), (-21, -104, 8),
            (43, -112, 12), (60, -116, 9), (28, -104, 8), (105, -102, 12), (72, -102, 10), (117, -94, 9),
            (-112, -60, 9), (114, -60, 9), (-126, -46, 7), (126, -48, 7)]


def crown_parts(ctx, mode, pts):
    P = []
    droop = 1.0 if mode == 'droop' else 0.0
    short = 0.72 if mode == 'bare' else 1.0
    for cl, w in CROWN:
        c = [(x, y) for x, y in cl]
        if droop:
            # the branches sag toward their tips
            c = [(x, y + (i * 9.0) + (i * i * 2.4)) for i, (x, y) in enumerate(c)]
        if short != 1.0:
            c = [(c[0][0] + (x - c[0][0]) * short, c[0][1] + (y - c[0][1]) * short) for x, y in c]
        P.append(root(bez(c[0], c[1], c[2], c[3], 10), w, n_groove=0, hi=True))
        # a twig off each branch
        tx, ty = along(bez(c[0], c[1], c[2], c[3], 10), 0.55)
        sgn = -1 if c[-1][0] < 0 else 1
        tip = (tx + sgn * 8, ty - 16 * short + droop * 18)
        P.append(root([(tx, ty), ((tx + tip[0]) / 2, (ty + tip[1]) / 2 - 2), tip], (5, 2.4), n_groove=0, hi=False))
    if mode in ('dead', 'droop'):
        for i, (x, y, r) in enumerate(BLOSSOMS):
            if droop:
                j = min(3, int(abs(x) / 36.0))
                y += j * 9 + j * j * 2.4
                if i % 3 == 1:
                    continue      # shed
            P += blossom(ctx, x, y, r, rot=i * 23, droop=droop)
        for x, y, s, r in SKULLS:
            P += skull_fruit(ctx, x, y + (26 if droop and abs(x) > 100 else 0), s, r + (14 if droop else 0))
    elif mode == 'bare':
        for x, y, s, r in SKULLS[:2]:
            P += skull_fruit(ctx, x * 0.78, -74 + (y + 74) * short, s * 0.9, r)
    elif mode == 'bloom':
        for i, (x, y, r) in enumerate(BLOSSOMS):
            col, sh = (ROSE, ROSE_SH) if i % 2 else (AMBER_HI, AMBER)
            P += blossom(ctx, x, y, r * 1.15, col=col, sh=sh, core=AMBER, rot=i * 23, glow=AMBER_CORE)
        # the heart itself, blooming at the crown's top
        P += blossom(ctx, 2, -100, 20, col=AMBER_HI, sh=AMBER, core=AMBER_CORE, rot=8, glow='#ffffff')
        pts['crown_heart'] = (2, -100)
    # two twigs sprouting from the hood's shoulders
    for side in (-1, 1):
        base = (side * 96 + 8, -30)
        c = [base, (side * 112 + 8, -44), (side * 122 + 8, -52), (side * 132 + 8, -50)]
        if droop:
            c = [(x, y + i * 8) for i, (x, y) in enumerate(c)]
        P.append(root(bez(c[0], c[1], c[2], c[3], 8), (9, 3.4), n_groove=0, hi=False))
        if mode in ('dead', 'droop'):
            P += blossom(ctx, c[3][0], c[3][1], 8, rot=side * 30, droop=droop)
        elif mode == 'bloom':
            P += blossom(ctx, c[3][0], c[3][1], 9, col=ROSE, sh=ROSE_SH, core=AMBER, rot=side * 30, glow=AMBER_CORE)
    pts['crown'] = (0, -100 if mode != 'bare' else -84)
    return P


# ---------------------------------------------------------------- the trunk

TRUNK = [(80, 358), (104, 338), (120, 304), (126, 266), (122, 230), (132, 200), (166, 186), (206, 182), (246, 186),
         (276, 200), (286, 230), (280, 266), (282, 304), (296, 338), (318, 358), (262, 362), (200, 364), (140, 362)]
CAGE = (206, 284)


def bark_edge(pts, n=72, bump=3.0, lobes=17):
    """A closed outline resampled smooth, its sides (not its top under the
    hood, nor its base in the soil) knobbled like old bark."""
    m = len(pts)
    out = []
    for i in range(n):
        f = i * m / float(n)
        j = int(f)
        t = f - j
        p0, p1, p2, p3 = pts[(j - 1) % m], pts[j], pts[(j + 1) % m], pts[(j + 2) % m]
        x = 0.5 * ((2 * p1[0]) + (-p0[0] + p2[0]) * t + (2 * p0[0] - 5 * p1[0] + 4 * p2[0] - p3[0]) * t * t
                   + (-p0[0] + 3 * p1[0] - 3 * p2[0] + p3[0]) * t * t * t)
        y = 0.5 * ((2 * p1[1]) + (-p0[1] + p2[1]) * t + (2 * p0[1] - 5 * p1[1] + 4 * p2[1] - p3[1]) * t * t
                   + (-p0[1] + 3 * p1[1] - 3 * p2[1] + p3[1]) * t * t * t)
        if 214 < y < 340:
            k = abs(math.sin(i / float(n) * lobes * math.pi)) * bump
            x += k if x > 200 else -k
        out.append((x, y))
    return out


def body_fn(dx, sy, lift=0.0, base=356.0, top=182.0):
    """The lean: points shift by dx at the shoulders (y top), none at the
    base; sy squashes toward the ground; lift raises everything above it."""
    def f(x, y):
        t = (base - y) / (base - top)
        return x + dx * t, base - (base - y) * sy - lift
    return f


def trunk_parts(ctx, f, heart='cold', pts=None):
    """The trunk bent by f, with its chest cage and the ember (cold, dark,
    bright or none)."""
    tp = [f(x, y) for x, y in bark_edge(TRUNK)]
    d = smooth_d(tp)
    gro = ''
    for pts_ in ([(112, 346), (128, 310), (134, 270), (132, 236)], [(152, 354), (150, 330), (154, 312)],
                 [(290, 346), (272, 310), (270, 272)], [(262, 214), (268, 234)], [(184, 352), (180, 326)],
                 [(236, 354), (240, 328)]):
        gro += line(open_d([f(x, y) for x, y in pts_]), BARK_DK, 1.8, op=0.75)
    hl = line(open_d([f(x, y) for x, y in ((104, 336), (118, 300), (122, 262), (126, 226))]), BARK_HI, 3, op=0.85)
    sx_, sy_ = f(206, 226)
    shadow = ('<ellipse cx="%.1f" cy="%.1f" rx="78" ry="24" fill="%s"/>'
              % (sx_, sy_, ctx.radgrad([(0, L, 0.55), (0.6, L, 0.3), (1, L, 0)])))
    P = [bark_part(d, over=shadow + gro, hl=hl, off=(-7, -5))]
    # the chest cage: a knotted ring of roots round a hollow, root ribs across it
    cx, cy = f(*CAGE)
    hol = ell_d(cx, cy, 32, 36)
    inner = '<path d="%s" fill="%s"/>' % (hol, VOID)
    if heart == 'cold':
        inner += radial(ctx, cx, cy + 4, 34, COLD, 0.5) + ember(ctx, cx, cy + 20, 40)
    elif heart == 'bright':
        inner += radial(ctx, cx, cy + 2, 40, COLD, 0.8) + ember(ctx, cx, cy + 22, 50, halo=1.2)
    elif heart == 'dark':
        # a last wisp where it left
        inner += line('M%.1f %.1f q6 -8 2 -16 q-4 -8 4 -16' % (cx + 4, cy + 18), COLD, 1.6, op=0.45)
    P[0].over += inner
    ribs = ''
    for ox, bend in ((-20, -6), (-7, -2), (7, 2), (20, 6)):
        dd = 'M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (cx + ox * 0.8, cy - 34, cx + ox * 1.25 + bend, cy, cx + ox * 0.8, cy + 34)
        ribs += line(dd, L, 8.6) + line(dd, BARK, 5.2) + line(dd, BARK_HI, 1.4, op=0.7)
    ring = '<path d="%s" fill="none" stroke="%s" stroke-width="12"/>' % (ell_d(cx, cy, 34, 38), L)
    ring += '<path d="%s" fill="none" stroke="%s" stroke-width="8.6"/>' % (ell_d(cx, cy, 34, 38), BARK_SH)
    ring += '<path d="%s" fill="none" stroke="%s" stroke-width="2" opacity="0.8"/>' % (ell_d(cx - 1.5, cy - 2, 33, 37), BARK_HI)
    for a in (20, 110, 200, 290):
        kx, ky = cx + 34 * math.cos(math.radians(a)), cy + 38 * math.sin(math.radians(a))
        ring += '<path d="%s" fill="%s" stroke="%s" stroke-width="1.6"/>' % (ell_d(kx, ky, 6, 5, a), BARK, L)
    P[0].over += ring + ribs
    if pts is not None:
        pts['heart'] = (cx, cy + 8)
        pts['cage'] = (cx, cy)
    return P


ROOTS = [
    ([(122, 336), (98, 350), (78, 358), (58, 366)], (34, 9)),
    ([(152, 346), (142, 356), (130, 362), (116, 366)], (28, 10)),
    ([(204, 348), (206, 356), (208, 360), (210, 362)], (34, 22)),
    ([(248, 348), (262, 356), (282, 362), (300, 366)], (30, 9)),
    ([(276, 334), (300, 346), (320, 356), (338, 366)], (28, 7)),
]


def base_roots(ctx):
    """The roots she stands in, spreading into the floor, with soil at the
    places they go in."""
    P = []
    for c, w in ROOTS:
        P.append(root(bez(c[0], c[1], c[2], c[3], 10), w, n_groove=1))
    soil = ''
    for x, rx in ((66, 14), (118, 14), (210, 18), (298, 14), (334, 12)):
        soil += '<path d="M%.1f 368 Q%.1f %.1f %.1f 368 Q%.1f 372 %.1f 368 Z" fill="%s" stroke="%s" stroke-width="1.6"/>' % (
            x - rx, x, 358 - rx * 0.1, x + rx, x, x - rx, SOIL, L)
    P[-1].over += soil
    return P


RISE = 64.0          # P3 "Deep Roots": every frame is drawn this many units (a tile, 32 px) higher, over rootmother_legs
LEGS = (384, 128)    # rootmother_legs' frame; its anchor (192, LEGS_FLOOR) goes on her anchor
LEGS_FLOOR = 112.0
STILTS = [      # mangrove-like prop roots: arching out from under her, then down into the soil
    ([(130, 292), (84, 290), (52, 322), (46, 362)], (38, 26, 13)),
    ([(166, 296), (164, 324), (126, 332), (118, 362)], (34, 24, 12)),
    ([(206, 298), (190, 324), (220, 342), (210, 362)], (38, 28, 15)),
    ([(248, 296), (258, 320), (286, 330), (290, 362)], (34, 24, 12)),
    ([(280, 290), (330, 288), (362, 322), (360, 362)], (36, 24, 12)),
    ([(72, 304), (84, 330), (84, 350), (88, 363)], (18, 12, 8)),       # a thinner root off the far-left one
    ([(342, 300), (330, 330), (326, 350), (326, 363)], (16, 11, 8)),   # and off the far-right one
]


def legs_part():
    """rootmother_legs (384 x 128): P3's torn-up roots standing as stilt legs,
    from under her trunk (lifted RISE units) to the floor (y LEGS_FLOOR),
    planted in soil. Drawn behind the body frame (whose own roots then hang
    over them like a skirt), its anchor on hers."""
    ctx = Ctx('lg')
    oy = GROUND - LEGS_FLOOR
    fl = LEGS_FLOOR
    under = ('<ellipse cx="204" cy="%.1f" rx="170" ry="9" fill="%s"/>'
             % (fl - 1, ctx.radgrad([(0, L, 0.5), (0.7, L, 0.25), (1, L, 0)])))
    P = []
    for c, w in STILTS:
        pts = [(x, y - oy) for x, y in bez(c[0], c[1], c[2], c[3], 12)]
        r = root(pts, w, n_groove=1)
        # a knot on each stilt, and a root hair or two off it
        kx, ky = along(pts, 0.42)
        r.over += '<path d="%s" fill="%s" stroke="%s" stroke-width="1.4"/>' % (ell_d(kx, ky, 5, 3.6), BARK_DK, L)
        P.append(r)
    fx = ''
    for c, w in STILTS:
        x = c[3][0]
        rx = w[2] + 5
        fx += '<path d="M%.1f %.1f Q%.1f %.1f %.1f %.1f Z" fill="%s" stroke="%s" stroke-width="1.6"/>' % (
            x - rx, fl + 1, x, fl - rx * 0.7, x + rx, fl + 1, SOIL, L)
    # torn root hairs between them, soil still clinging high up
    for x, y in ((104, 44), (178, 46), (238, 46), (318, 42)):
        d = 'M%.1f %.1f q-3 10 1 18 q3 7 -2 13' % (x, y)
        fx += line(d, L, 5.6) + line(d, BARK_SH, 3)
    for x, y, r in ((116, 36, 6), (298, 34, 5)):
        fx += '<path d="%s" fill="%s" stroke="%s" stroke-width="1.4"/>' % (ell_d(x, y, r * 1.2, r), SOIL, L)
    return svg(ctx, under + paint(ctx, P, PAL) + fx, LEGS[0], LEGS[1])


# ---------------------------------------------------------------- one frame

HEAD_AT = (208, 142)
FAR_W, NEAR_W = (32, 22), (36, 24)
NECK = (204, 188)


def frame(name):
    ctx = Ctx('gb' + name[:4])
    fid = 'rootmother_' + name
    under, over = '', ''
    heart = 'cold'
    lift = 0.0
    near = None          # the near arm's parts (None: the bough parts are its arm)
    far = []
    hp = {}
    if name == 'idle':
        dx, sy, rot = 8, 1.0, 5
        hk = dict(eyes='sleepy', mouth='smile', crown='dead')
    elif name == 'dig':
        dx, sy, rot = 18, 0.9, 6
        hk = dict(eyes='strain', mouth='tight', crown='dead')
    elif name == 'sweep_low':
        dx, sy, rot = 16, 0.9, 4
        hk = dict(eyes='fierce', mouth='open', crown='dead')
    elif name == 'sweep_high':
        dx, sy, rot = -18, 1.0, -8
        hk = dict(eyes='fierce', mouth='open', crown='dead')
    elif name == 'breath':
        dx, sy, rot = -8, 1.0, -6
        hk = dict(eyes='shut', mouth='o', crown='dead', puff=True, gills=True)
    elif name == 'hollow':
        dx, sy, rot = 14, 0.98, 4
        hk = dict(eyes='sad', mouth='sad', crown='dead')
        heart = 'dark'
    elif name == 'hurt':
        dx, sy, rot = -24, 0.98, -9
        hk = dict(eyes='hurt', mouth='open', crown='dead')
    elif name == 'wilt':
        dx, sy, rot = 10, 0.88, 8
        hk = dict(eyes='dizzy', mouth='sad', crown='droop')
    elif name == 'bare':
        # the P3 roar: tearing herself up out of the soil (drawn rooted like every
        # frame: in P3 the engine lifts every frame RISE over rootmother_legs)
        dx, sy, rot = 10, 1.0, 0
        hk = dict(eyes='glare_sad', mouth='roar', crown='dead')
        heart = 'bright'
    else:   # die
        dx, sy, rot = 6, 0.94, 6
        hk = dict(eyes='peace', mouth='sigh', crown='bloom')
        heart = 'none'
    f = body_fn(dx, sy, lift)
    # ---- the arms
    sb, sf = f(136, 222), f(274, 222)
    if name == 'idle':
        far = arm(sb, (84, 262), (70, 334), FAR_W, hand_ang=112, spread=1.0, into=True)
        near = arm(sf, (326, 258), (320, 334), NEAR_W, hand_ang=72, spread=1.0, into=True)
    elif name == 'dig':
        far = arm(sb, (92, 282), (104, 342), FAR_W, hand_ang=85, spread=0.7, curl=0.3, into=True)
        near = arm(sf, (330, 272), (320, 344), NEAR_W, hand_ang=95, spread=0.7, curl=0.3, into=True)
        over += dig_fx(ctx, (108, 366)) + dig_fx(ctx, (322, 366))
    elif name == 'sweep_low':
        far = arm(sb, (86, 290), (74, 340), FAR_W, hand_ang=112, spread=1.1, into=True)
        over += motion('M80 200 L60 196 M76 220 L54 222 M90 180 L74 170', 2.2)
    elif name == 'sweep_high':
        far = arm(sb, (84, 252), (72, 326), FAR_W, hand_ang=112, spread=1.1, into=True)
        over += motion('M120 60 L106 44 M150 40 L144 20 M92 90 L74 80', 2.2)
    elif name == 'breath':
        far = arm(sb, (86, 262), (72, 336), FAR_W, hand_ang=112, into=True)
        near = arm(sf, (324, 254), (318, 336), NEAR_W, hand_ang=72, into=True)
    elif name == 'hollow':
        far = arm(sb, (88, 262), (74, 338), FAR_W, hand_ang=112, into=True)
        near = arm(sf, (330, 262), (322, 338), NEAR_W, hand_ang=70, spread=1.1, into=True)
    elif name == 'hurt':
        far = arm(sb, (90, 206), (74, 164), FAR_W, hand_ang=-112, spread=1.2, curl=-0.4)
        near = arm(sf, (318, 200), (318, 160), NEAR_W, hand_ang=-72, spread=1.2, curl=-0.4)
        over += hurt_fx(ctx)
    elif name == 'wilt':
        far = arm(sb, (96, 292), (80, 348), FAR_W, hand_ang=150, spread=0.8, curl=0.5, into=True)
        near = arm(sf, (314, 292), (320, 348), NEAR_W, hand_ang=30, spread=0.8, curl=0.5, into=True)
        over += petals_falling(ctx, 60)
    elif name == 'bare':
        far = arm(sb, (84, 214), (60, 172), FAR_W, hand_ang=-112, spread=1.3, curl=-0.3)
        near = arm(sf, (326, 206), (334, 160), NEAR_W, hand_ang=-78, spread=1.3, curl=-0.3)
        over += motion('M40 120 L24 110 M44 146 L22 146 M352 100 L368 88 M350 126 L372 124', 2.2)
        over += tear_fx(ctx) + petals_falling(ctx, 60)
    else:   # die
        far = arm(sb, (100, 276), (82, 346), FAR_W, hand_ang=150, spread=0.9, curl=0.4, into=True)
        near = arm(sf, (310, 278), (318, 346), NEAR_W, hand_ang=34, spread=0.9, curl=0.4, into=True)
        over += petals_falling(ctx, 40, warm=True)
    # ---- the body
    roots = base_roots(ctx)
    tpts = {}
    trunk = trunk_parts(ctx, f, heart, tpts)
    hx, hy = f(*NECK)
    hc = (hx + (HEAD_AT[0] - NECK[0]), hy + (HEAD_AT[1] - NECK[1]))
    hscale = 1.0
    hl = {}
    hparts, hover = head(ctx, fx_out=hl, **hk)
    t = 'translate(%.1f %.1f) rotate(%.1f) scale(%.2f)' % (hc[0], hc[1], rot, hscale)
    hparts = place(hparts, t)
    hover = gx(hover, t)

    def H(p):
        return rot_pt(hc[0] + p[0] * hscale, hc[1] + p[1] * hscale, hc[0], hc[1], rot)
    shoulder = f(274, 222)
    if near is None:
        # the sweep frames: a knot where the bough attaches (the parts are the arm)
        sx, sy_ = shoulder
        stump = [bark_part(ell_d(sx, sy_, 30, 28), off=(-3, -3),
                           over=line('M%.1f %.1f q8 -6 16 0 M%.1f %.1f q6 5 12 0' % (sx - 12, sy_ - 6, sx - 6, sy_ + 8), BARK_DK, 1.6))]
        near = stump
        stumped = True
    else:
        stumped = False
    parts = far + roots + trunk + near + hparts if not stumped else far + roots + trunk + hparts + near
    body_svg = paint(ctx, parts, PAL)
    svg_text = svg(ctx, under + body_svg + hover + over, 384, 384)
    # ---- the points
    heart_pt = tpts['heart'] if heart != 'none' else H(hl['crown_heart'])
    tb = trunk_box(f, hc[1] - 92 * hscale)
    PTS.mark(fid, heart=heart_pt, eye_l=H(hl['eye_l']), eye_r=H(hl['eye_r']), face=H(hl['face']), mouth=H(hl['mouth']),
             crown=H(hl['crown']), bough=shoulder, trunk=tb)
    return svg_text


def trunk_box(f, top):
    """Her body's box (frame units): the trunk and the hooded head down to her
    roots, not the arms or the crown."""
    x0 = min(f(96, 300)[0], f(130, 206)[0]) - 4
    x1 = max(f(290, 280)[0], f(268, 202)[0]) + 4
    return (x0, top, x1 - x0, GROUND - top)


def tear_fx(ctx):
    """The P3 roar: her roots ripping out of the soil, clods flung up."""
    s = ''
    for x, y, r, a in ((52, 330, 7, 20), (88, 312, 5, -30), (150, 334, 6, 40), (250, 330, 6, -20), (322, 314, 5.4, 30),
                       (352, 336, 7, 10), (200, 340, 4.4, 0)):
        s += '<path d="%s" fill="%s" stroke="%s" stroke-width="1.6"/>' % (ell_d(x, y, r * 1.2, r, a), SOIL, L)
    d = 'M40 369 L28 373 M100 369 L108 373 M290 369 L300 373 M350 369 L362 372'
    s += line(d, L, 2.6) + motion('M60 318 l-8 -12 M330 300 l8 -12 M160 322 l-4 -12', 1.8, 0.85)
    return s


def dig_fx(ctx, p):
    """Soil bursting where a hand plunges in: clods and cracks."""
    x, y = p
    s = ''
    for dx, dy, r in ((-30, -14, 6), (-20, -26, 4.4), (22, -18, 5.4), (32, -8, 4), (-6, -30, 3.4), (10, -28, 4)):
        s += '<path d="%s" fill="%s" stroke="%s" stroke-width="1.6"/>' % (ell_d(x + dx, y + dy, r * 1.2, r, dx * 3), SOIL, L)
    d = 'M%.1f 369 L%.1f 372 M%.1f 369 L%.1f 373 M%.1f 369 L%.1f 372' % (x - 34, x - 44, x + 26, x + 38, x - 4, x + 2)
    s += line(d, L, 2.6) + line('M%.1f %.1f l-8 -10 M%.1f %.1f l8 -12' % (x - 24, y - 34, x + 20, y - 36), '#ffffff', 2, op=0.8)
    return s


def hurt_fx(ctx):
    s = ''
    for x, y, r, a in ((300, 90, 5, 20), (320, 130, 4, -30), (110, 70, 4.4, 40), (330, 200, 3.6, 10)):
        s += '<path d="M%.1f %.1f l%.1f %.1f l%.1f %.1f Z" fill="%s" stroke="%s" stroke-width="1.4" transform="rotate(%d %.1f %.1f)"/>' % (
            x, y, r * 2, r * 0.6, -r * 0.8, r * 1.6, BARK, L, a, x, y)
    s += petals_falling(ctx, 20)
    s += motion('M340 60 L356 44 M352 90 L372 84 M60 100 L44 88', 2.2)
    return s


def petals_falling(ctx, n, warm=False):
    s = ''
    for i in range(n // 10):
        x = 60 + (i * 97) % 270
        y = 110 + (i * 53) % 170
        col = (AMBER_HI if i % 2 else ROSE) if warm else PETAL
        s += '<path d="%s" fill="%s" stroke="%s" stroke-width="1.2" transform="rotate(%d %.1f %.1f)"/>' % (
            ell_d(x, y, 5.4, 3, 0), col, L, i * 47, x, y)
    return s


# ================================================================ the bough parts

def knot_d(cx, cy, r, seed):
    """A lumpy bark knot round (cx, cy)."""
    pts = []
    for i in range(11):
        a = i / 11.0 * 2 * math.pi
        k = 1.0 + 0.09 * math.sin(a * 3 + seed * 1.7) + 0.06 * math.cos(a * 5 + seed)
        pts.append((cx + math.cos(a) * r * k, cy + math.sin(a) * r * 0.96 * k))
    return smooth_d(pts)


def bough_part(n, prefix=None):
    """rootmother_bough<n>: a root segment pointing right from its pivot
    (40, 48) to its joint (184, 48), 52 units thick; bough3 is the hand."""
    ctx = Ctx(prefix or 'bg%d' % n)
    px, py = BOUGH_PIVOT
    jx, jy = BOUGH_JOINT
    P = []
    if n in (1, 2):
        pts = [(px + (jx - px) * i / 12.0, py + 1.2 * math.sin(i / 12.0 * math.pi * (1.4 if n == 1 else 2.0))) for i in range(13)]
        w = (BOUGH_W + 2, BOUGH_W, BOUGH_W - 2) if n == 1 else (BOUGH_W, BOUGH_W - 3, BOUGH_W)
        r = root(pts, w, n_groove=3)
        # knots, and a twig or two
        r.over += '<path d="%s" fill="%s" stroke="%s" stroke-width="1.6"/>' % (ell_d(112, 40, 7, 5), BARK_DK, L)
        r.over += '<path d="%s" fill="%s"/>' % (ell_d(112, 40, 3, 2.2), L)
        P.append(r)
        tw = [(134, 28), (142, 18), (154, 13)] if n == 1 else [(88, 66), (99, 72), (111, 74)]
        P.append(root(tw, (7, 2.6), n_groove=0, hi=False))
        # the knot at the pivot that hides the joint with the segment before
        P.append(bark_part(knot_d(px, py, 26, n), off=(-3, -3),
                           over=line('M%.1f %.1f q8 -6 16 0 M%.1f %.1f q5 4 11 1' % (px - 12, py - 6, px - 2, py + 8), BARK_DK, 1.6)))
        if n == 2:
            P.append(Part('fill', pth(smooth_d([(66, 24), (80, 21), (90, 25), (80, 29), (70, 29)])), fill=MOSS, shade=MOSS_SH, off=(-1, -1)))
    else:
        pts = [(px + (132 - px) * i / 8.0, py) for i in range(9)]
        P.append(root(pts, (BOUGH_W, BOUGH_W - 8), n_groove=2))
        P.append(bark_part(knot_d(px, py, 26, 3), off=(-3, -3)))
        P += hand_parts((130, 48), 0, spread=1.25, curl=0.2, k=1.0)
    body = paint(ctx, P, PAL)
    return svg(ctx, body, BOUGH[0], BOUGH[1])


# ================================================================ the props

def prop_bloom(kind):
    """bloom_bud, bloom_open, bloom_decoy: a blossom on a short root stem
    whose base (32, 62) stands on the socket's floor; the flower's centre
    is (32, 29), its box 56 x 56 units round it (the 28 px blossom box)."""
    ctx = Ctx('bl' + kind[:2])
    P = []
    stem = [(32, 63), (31, 56), (33, 48), (32, 40)]
    P.append(root(stem, (9, 6), n_groove=0, hi=False))
    P.append(Part('fill', pth(smooth_d([(32, 52), (20, 46), (10, 48), (18, 56), (30, 56)])), fill=MOSS, shade=MOSS_SH, off=(-1, -1)))
    P.append(Part('fill', pth(smooth_d([(33, 50), (46, 44), (55, 47), (47, 55), (34, 55)])), fill=MOSS, shade=MOSS_SH, off=(-1, -1)))
    over = ''
    under = ''
    if kind == 'bud':
        # a closed bud, pale (the engine blushes it amber with modulate)
        P.append(Part('fill', pth(smooth_d([(32, 46), (20, 40), (16, 28), (22, 14), (32, 8), (42, 14), (48, 28), (44, 40)])),
                      fill='#f2e8dc', shade='#d0bca8', off=(-2, -2),
                      over=line('M32 42 Q24 30 30 10 M32 42 Q40 30 36 12', '#b8a090', 1.4, op=0.9),
                      hl=spec(24, 22, 3, 7, rot=10, op=0.8)))
        for sx in (-1, 1):
            P.append(Part('fill', pth(smooth_d([(32, 46), (32 + sx * 12, 40), (32 + sx * 16, 30), (32 + sx * 8, 34), (32 + sx * 3, 42)])),
                          fill=MOSS, shade=MOSS_SH, off=(-1, -1)))
    elif kind == 'open':
        under = radial(ctx, 32, 31, 28, AMBER, 0.55)
        for i in range(6):
            a = math.radians(-90 + i * 60 + 12)
            cx, cy = 32 + math.cos(a) * 13, 31 + math.sin(a) * 13
            P.append(Part('fill', pth(ell_d(cx, cy, 12, 9, math.degrees(a))), fill=AMBER, shade=AMBER_SH, off=(-2, -2), lw=1.4,
                          hl=spec(cx - math.cos(a) * 3, cy - math.sin(a) * 3, 3, 1.6, rot=math.degrees(a), op=0.7),
                          over='<path d="%s" fill="%s" opacity="0.8"/>' % (ell_d(cx + math.cos(a) * 6, cy + math.sin(a) * 6, 5, 4, math.degrees(a)), AMBER_HI)))
        over += ember(ctx, 32, 38, 18, col=AMBER, core=AMBER_CORE, deep=AMBER_SH, halo=0.8)
        over += '<circle cx="32" cy="31" r="10.5" fill="none" stroke="%s" stroke-width="2.2"/>' % L
        over += '<circle cx="32" cy="31" r="10.5" fill="none" stroke="%s" stroke-width="0.9" opacity="0.9"/>' % AMBER_CORE
    else:   # decoy: pale violet, open but unlit, breathing
        for i in range(6):
            a = math.radians(-90 + i * 60 + 12)
            cx, cy = 32 + math.cos(a) * 12, 31 + math.sin(a) * 12 + 1.5
            P.append(Part('fill', pth(ell_d(cx, cy, 12, 8.4, math.degrees(a) + 8)), fill=VIOLET, shade=VIOLET_SH, off=(-2, -2), lw=1.4,
                          hl=spec(cx, cy - 2, 3, 1.6, rot=math.degrees(a), op=0.5)))
        P.append(Part('fill', pth(ell_d(32, 32, 9, 9)), fill='#7a6a8a', shade='#5a4c6a', off=(-1, -1),
                      over=''.join(dot(32 + 4 * math.cos(k), 32 + 4 * math.sin(k), 1.3, '#cfc2e0') for k in (0.4, 2.3, 4.1))))
    body = paint(ctx, P, PAL)
    return svg(ctx, under + body + over, 64, 64)


def prop_spear():
    """root_spear (64 x 128): a thorny root pillar 52 wide (26 px) bursting
    from the floor (y 128) the whole frame high (64 px), a flat root cap on
    top (its top at y 1: the one-way ledge)."""
    ctx = Ctx('sp')
    body = smooth_d([(10, 130), (8, 90), (9, 50), (9, 22), (12, 12), (32, 8), (52, 12), (55, 22), (55, 50), (56, 90),
                     (54, 130)])
    gro = line('M20 124 Q17 80 22 26 M44 124 Q47 84 42 28 M32 120 Q30 90 33 56', BARK_DK, 1.8, op=0.8)
    thorns = ''
    for y, s_ in ((34, -1), (60, 1), (84, -1), (104, 1), (48, 1), (96, -1)):
        x = 10 if s_ < 0 else 54
        thorns += '<path d="M%.1f %.1f L%.1f %.1f L%.1f %.1f Z" fill="%s" stroke="%s" stroke-width="1.6" stroke-linejoin="round"/>' % (
            x + s_ * -2, y - 7, x + s_ * 7, y - 11, x + s_ * -2, y + 4, BONE, L)
    P = [bark_part(body, over=gro + thorns, hl=line('M13 110 Q10 70 14 20', BARK_HI, 2.4, op=0.85), off=(-4, -3))]
    cap = smooth_d([(5, 10), (9, 3), (22, 1.6), (32, 2.4), (44, 1.6), (55, 3), (59, 10), (49, 16), (32, 14), (15, 16)])
    P.append(bark_part(cap, fill=BARK_HI, shade=BARK, off=(-2, -2),
                       over=line('M12 7 Q32 3 52 7', BARK_DK, 1.4, op=0.7)))
    soil = '<path d="M5 127 Q12 118 22 125 Q32 118 42 125 Q52 118 59 127 Z" fill="%s" stroke="%s" stroke-width="1.6"/>' % (SOIL, L)
    return svg(ctx, paint(ctx, P, PAL) + soil, 64, 128)


def prop_seed():
    """skull_seed: a bony seed pod with a skull's face and a sprouting fuse."""
    ctx = Ctx('sd')
    P = []
    P.append(root([(32, 20), (30, 14), (34, 9)], (4, 2), n_groove=0, hi=False))
    P.append(Part('fill', pth(smooth_d([(34, 11), (42, 7), (48, 11), (42, 15)])), fill=MOSS, shade=MOSS_SH, off=(-1, -1)))
    face = ('<path d="%s" fill="%s"/>' % (ell_d(25, 36, 5, 6, -10), L) + '<path d="%s" fill="%s"/>' % (ell_d(39, 36, 5, 6, 10), L)
            + '<path d="M30 44 L32 41 L34 44 Z" fill="%s"/>' % L
            + line('M24 50 Q32 54 40 50 M28 49 L28 53 M32 50 L32 54 M36 49 L36 53', L, 1.2)
            + dot(26.6, 34.4, 1.4, EYE_GLOW) + dot(40.6, 34.4, 1.4, EYE_GLOW))
    P.append(Part('fill', pth(smooth_d([(32, 16), (46, 22), (52, 36), (48, 50), (38, 58), (26, 58), (16, 50), (12, 36), (18, 22)])),
                  fill=BONE, shade=BONE_SH, off=(-3, -3), over=face + line('M40 20 L44 28 L42 32', BONE_SH, 1.2),
                  hl=spec(22, 26, 4, 2.4, rot=-40, op=0.85)))
    return svg(ctx, paint(ctx, P, PAL), 64, 64)


def prop_thorn():
    """thorn: a long bone-tipped thorn falling point down."""
    ctx = Ctx('th')
    d = smooth_d([(24, 8), (40, 8), (38, 20), (35, 36), (32, 56), (29, 36), (26, 20)], k=0.12)
    P = [bark_part(d, fill=BARK_SH, shade=BARK_DK, off=(-2, -2), over=line('M30 14 Q31 30 32 48', BARK_HI, 1.6, op=0.8))]
    P.append(Part('fill', pth(smooth_d([(29.4, 38), (34.6, 38), (32, 56)], k=0.05)), fill=BONE, shade=BONE_SH, off=(-1, -1)))
    return svg(ctx, paint(ctx, P, PAL), 64, 64)


def prop_hump():
    """root_hump (128 x 64): a solid mound of knotted roots bulging out of the
    floor, a full tile tall (its top at y 1) and nearly two wide: a block,
    with nothing to walk under."""
    ctx = Ctx('hm')
    P = []
    mound = smooth_d([(30, 66), (9, 63), (10, 40), (19, 14), (40, 3), (64, 1.4), (88, 3), (109, 14), (118, 40), (119, 63),
                      (98, 66)])
    gro = line('M20 60 Q24 30 46 12 M44 62 Q50 36 70 18 M84 62 Q84 40 100 20 M106 60 Q104 44 112 30', BARK_DK, 2, op=0.8)
    P.append(bark_part(mound, over=gro, hl=line('M16 40 Q30 12 64 5', BARK_HI, 2.6, op=0.85), off=(-5, -4)))
    # roots coiling over it
    P.append(root(bez((20, 64), (28, 20), (74, 3), (96, 40), 12), (18, 14), n_groove=1))
    P.append(root(bez((60, 14), (96, 5), (110, 30), (106, 64), 12), (18, 18), n_groove=1))
    P.append(root(bez((36, 66), (44, 42), (62, 32), (74, 46), 8), (14, 9), n_groove=0))
    soil = '<path d="M4 63 Q17 55 34 61 Q64 53 94 61 Q111 55 124 63 Z" fill="%s" stroke="%s" stroke-width="1.6"/>' % (SOIL, L)
    return svg(ctx, paint(ctx, P, PAL) + soil, 128, 64)


# ================================================================ the points file

LOW_BAND, HIGH_BAND = 15.0, 86.0      # the sweep bands' centres, px above the floor
LOW_THICK, HIGH_THICK = 1.0, 0.6      # the bough parts' thickness (sprite scale across them) in each sweep
LOW_HURT, HIGH_HURT = 28.0, 16.0      # the hurt bands' heights, px
# A standing Waxby's candle flame tops out at 66..80 px over his feet (measured per calling at
# full life, its tallest flicker: glow.gd's flame on wick_rig's flame_point), and a row-10
# ledge's top is 96 px up. The high sweep lashes a thinner bough (x 0.6: its art 86 +- 9.6 px,
# its hurt band 78..94 px) through that gap: it clears the flame of the Candleknight, the
# Sootrunner and the Bellfounder, grazes only the last flicker of the Taperwitch's and the
# Sexton's taller candles (2..3 px), and passes under a Waxby standing on a row-10 ledge.


def _lay(sh_y, band_px, rise=0.0, copies=5):
    """A strike's chain: from a shoulder at sh_y (frame units, before the
    rise) bend down (or up) onto the band, then run level along it (repeat
    the level bough2 to reach the far wall). One bend when bough1 alone can
    reach the band; else bough1 drops steeply and the first bough2 finishes."""
    ln = BOUGH_JOINT[0] - BOUGH_PIVOT[0]
    drop = (GROUND - band_px * 2) - (sh_y - rise)
    if abs(drop) <= ln * 0.92:
        a1 = math.degrees(math.asin(drop / ln))
        return [[1, round(a1, 1)]] + [[2, 0.0]] * copies + [[3, 0.0]]
    a1 = 66.0 if drop > 0 else -66.0
    a2 = math.degrees(math.asin(max(-1.0, min(1.0, (drop - ln * math.sin(math.radians(a1))) / ln))))
    return [[1, a1], [2, round(a2, 1)]] + [[2, 0.0]] * (copies - 1) + [[3, 0.0]]


def _chain(a1, a2, a3, copies):
    return [[1, a1]] + [[2, a2]] * copies + [[3, a3]]


def poses():
    """The bough's poses. chain: each part in order ([part 1..3, absolute
    angle in degrees]; 0 = her facing, positive turns down), from the frame's
    bough point (lifted `rise` units in P3). The tells rear the arm back
    (low from her hip, high over her head); the strikes lay it along the
    band (extend: add level bough2 copies before the hand to reach the far
    wall). angles/copies: the same chain in short, for the one-bend poses."""
    sl, sh = 'rootmother_sweep_low', 'rootmother_sweep_high'
    ly, hy = PTS.d[sl]['bough'][1], PTS.d[sh]['bough'][1]
    out = {
        'sweep_low_tell': {'frame': sl, 'rise': 0.0, 'thick': LOW_THICK, 'chain': _chain(40, 178, 206, 1), 'angles': [40, 178, 206], 'copies': 1,
                           'what': 'the arm drops low from her hip and lies back along the floor, the hand cocked behind her'},
        'sweep_high_tell': {'frame': sh, 'rise': 0.0, 'thick': HIGH_THICK, 'chain': _chain(-40, -100, -150, 1), 'angles': [-40, -100, -150],
                            'copies': 1, 'what': 'the arm rears up over her head, the hand high and cocked back'},
        'sweep_low_strike': {'frame': sl, 'rise': 0.0, 'thick': LOW_THICK, 'chain': _lay(ly, LOW_BAND), 'band_px': LOW_BAND,
                             'hurt_px': LOW_HURT, 'extend': True,
                             'what': 'lashed along the floor: the band\'s centre %g px up' % LOW_BAND},
        'sweep_high_strike': {'frame': sh, 'rise': 0.0, 'thick': HIGH_THICK, 'chain': _lay(hy, HIGH_BAND), 'band_px': HIGH_BAND,
                              'hurt_px': HIGH_HURT, 'extend': True,
                              'what': 'lashed over a standing Waxby: the band\'s centre %g px up (its art %g..%g px: over his '
                                      'flame, under a row-10 ledge)' % (HIGH_BAND, HIGH_BAND - 16 * HIGH_THICK,
                                                                         HIGH_BAND + 16 * HIGH_THICK)},
        # P3 "Deep Roots": the same frames lifted RISE over rootmother_legs, the arm from the higher shoulder
        'sweep_low_tell_p3': {'frame': sl, 'rise': RISE, 'thick': LOW_THICK, 'chain': _chain(62, 178, 206, 1),
                              'what': 'P3: the arm drops from her lifted hip and lies back low along the floor'},
        'sweep_high_tell_p3': {'frame': sh, 'rise': RISE, 'thick': HIGH_THICK, 'chain': _chain(-40, -100, -150, 1),
                               'what': 'P3: the arm rears up over her head'},
        'sweep_low_strike_p3': {'frame': sl, 'rise': RISE, 'thick': LOW_THICK, 'chain': _lay(ly, LOW_BAND, RISE), 'band_px': LOW_BAND,
                                'hurt_px': LOW_HURT, 'extend': True,
                                'what': 'P3: slammed down from the lifted shoulder and lashed along the floor (%g px)' % LOW_BAND},
        'sweep_high_strike_p3': {'frame': sh, 'rise': RISE, 'thick': HIGH_THICK, 'chain': _lay(hy, HIGH_BAND, RISE),
                                 'band_px': HIGH_BAND, 'hurt_px': HIGH_HURT, 'extend': True, 'what': 'P3: lashed over a standing Waxby (%g px)' % HIGH_BAND},
    }
    for k in ('sweep_low_strike', 'sweep_high_strike'):
        c = out[k]['chain']
        if len(c) == 7 and all(a == 0.0 for _, a in c[1:]):
            out[k]['angles'], out[k]['copies'] = [c[0][1], 0.0, 0.0], 5
    return out


def pose_joints(pose):
    """The chain's joints (frame units) for one pose, from the frame's bough
    point lifted by the pose's rise."""
    ps = poses()[pose]
    x, y = PTS.d[ps['frame']]['bough']
    y -= ps['rise']
    ln = BOUGH_JOINT[0] - BOUGH_PIVOT[0]
    out = [(x, y)]
    for _, a in ps['chain']:
        x += math.cos(math.radians(a)) * ln
        y += math.sin(math.radians(a)) * ln
        out.append((x, y))
    return out


def check_poses():
    """No pose puts the bough into the floor or through the roof of her arena
    (rows 2..12 are open: 11 tiles over the floor), and each strike's level
    run lies on its band."""
    bad = []
    for name, ps in poses().items():
        js = pose_joints(name)
        for x, y in js:
            if y > GROUND - BOUGH_W / 2 + 2 or y < GROUND - 11 * 64 + BOUGH_W / 2:
                bad.append('%s: a joint at (%.0f, %.0f) is outside the arena' % (name, x, y))
        if 'band_px' in ps:
            want = GROUND - ps['band_px'] * 2
            if abs(js[-1][1] - want) > 1.0:
                bad.append('%s ends at y %.1f, not on its band (y %.1f)' % (name, js[-1][1], want))
    if bad:
        raise SystemExit('Gravebough bough poses:\n  ' + '\n  '.join(bad))


def _inner(svg_text):
    """An SVG document's contents without its outer <svg> tags."""
    return svg_text[svg_text.index('>') + 1:svg_text.rindex('</svg>')]


def pose_svg(pose):
    """A picture of one bough pose as the engine would draw it: the frame,
    then the bough parts chained from its bough point (for checking the
    poses by eye; build() doesn't write it)."""
    ps = poses()[pose]
    fname = ps['frame'][len('rootmother_'):]
    body = frame(fname)
    sh = PTS.d[ps['frame']]['bough']
    rise = ps['rise']
    W = 384 + 144 * (len(ps['chain']) + 1) + 200
    out = '<g transform="translate(200 %.1f)">' % RISE
    if rise:
        out += '<g transform="translate(0 %.1f)">%s</g>' % (GROUND - LEGS_FLOOR, _inner(legs_part()))
    out += '<g transform="translate(0 %.1f)">%s</g>' % (-rise, _inner(body))
    x, y = sh[0], sh[1] - rise
    L_ = BOUGH_JOINT[0] - BOUGH_PIVOT[0]
    for i, (n, a) in enumerate(ps['chain']):
        t = 'translate(%.2f %.2f) rotate(%.2f) scale(1 %.2f) translate(%.2f %.2f)' % (x, y, a, ps['thick'], -BOUGH_PIVOT[0], -BOUGH_PIVOT[1])
        out += '<g transform="%s">%s</g>' % (t, _inner(bough_part(n, 'pv%d' % i)))
        x += math.cos(math.radians(a)) * L_
        y += math.sin(math.radians(a)) * L_
    out += '</g>'
    H = 384 + RISE
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">\n%s\n</svg>\n'
            % (W * 2, H * 2, W, H, out))


def points_json():
    head = {
        '_doc': "Mother Gravebough's 384-unit frames: 2 units = 1 world px, drawn facing right (flip her in the arena), "
                'anchor (her root line) at (192, 368). World offset = (point - anchor) / 2 px, mirrored with the facing. '
                'heart = the caged ember (in _die the heart blooming in her crown); eye_l, eye_r = her glowing eye slits; '
                'face = the face (chip target); mouth = where Spore Breath comes out; crown = the crown (Seedfall shakes '
                'it; the skull seeds fall from it); bough = the near shoulder, where rootmother_bough1\'s pivot goes; '
                'trunk = her body box [x, y, w, h] (touch and chip hits; not the arms).',
        '_anchor': list(FOOT),
        '_bough': {
            'parts': ['rootmother_bough1', 'rootmother_bough2', 'rootmother_bough3'],
            'frame': list(BOUGH), 'pivot': list(BOUGH_PIVOT), 'joint': list(BOUGH_JOINT), 'thick': BOUGH_W,
            'length': BOUGH_JOINT[0] - BOUGH_PIVOT[0], 'hand_reach': 200 - BOUGH_PIVOT[0],
            'how': 'Each part is drawn pointing right from its pivot to its joint. Walk a pose\'s chain: the first '
                   'part\'s pivot on the frame\'s bough point (raised by the pose\'s rise, as the frame is), turned to '
                   'its angle; each next part\'s pivot on the last one\'s joint (length units along its angle), turned '
                   'to its own angle. A strike (extend) runs level along its band: add level bough2 copies before '
                   'the hand until it reaches the far wall. Facing left (her arena): flip each part\'s sprite like the '
                   'body (scale.x < 0) and turn it by -angle; the next joint is then length / 2 px along (-cos a, '
                   'sin a). Draw them over the body (the near arm). Only the sweep frames leave the arm out: every '
                   'other frame draws its own. thick: scale each part\'s sprite across its length by it (scale.y; '
                   'the high sweep lashes a thinner bough). A strike\'s hurt band is hurt_px tall round band_px (its '
                   'centre, px over the floor). Low %g px, %g px tall: jump it (its art -1..31 px). High %g px, %g px '
                   'tall (%g..%g px): its art (%g..%g px) passes over a standing Waxby\'s candle flame (66..80 px by '
                   'calling: only the Taperwitch\'s and the Sexton\'s tallest flicker grazes it) and under a row-10 '
                   'ledge\'s top (96 px): stay down, or stand on a ledge.'
                   % (LOW_BAND, LOW_HURT, HIGH_BAND, HIGH_HURT, HIGH_BAND - HIGH_HURT / 2, HIGH_BAND + HIGH_HURT / 2,
                      HIGH_BAND - 16 * HIGH_THICK, HIGH_BAND + 16 * HIGH_THICK),
            'poses': poses()},
        '_p3': {
            'rise': RISE, 'rise_px': RISE / 2, 'legs': 'rootmother_legs', 'legs_frame': list(LEGS),
            'legs_anchor': [192, LEGS_FLOOR], 'legs_box': [40, 20, 330, LEGS_FLOOR - 20],
            'how': 'P3 "Deep Roots" (spec 5.2: she tears her lower roots out and her trunk rises a tile). From the P3 '
                   'roar on, draw EVERY frame (the roar\'s rootmother_bare included) rise_px higher than her anchor, '
                   'and rootmother_legs behind it with its anchor (192, %g) on her anchor: her own roots then hang '
                   'over the stilt legs like a skirt. Every tell keeps its frame (the sweeps, dig, breath, hurt, wilt), '
                   'so nothing pops. Every point of a frame moves up by rise units with it; the bough uses the *_p3 '
                   'poses (from the lifted shoulder). The roar: show rootmother_bare and ease the rise from 0 to '
                   'rise_px over it (the legs appear from under her as she lifts); rootmother_bare, lifted, also suits '
                   'the Thorn Crown tell (arms up, the crown shaking). Her touch box in P3 is the frame\'s trunk box '
                   'lifted, plus legs_box (legs part units, the stilts; about 32 px tall) over the floor. On a retry '
                   'she is rooted again (rise 0, no legs).' % LEGS_FLOOR},
        '_props': {
            'bloom_bud': {'frame': [64, 64], 'base': [32, 62], 'center': [32, 28],
                          'note': 'pale on purpose: modulate it toward amber (about Color(1.0, 0.72, 0.42)) for the target\'s blush'},
            'bloom_open': {'frame': [64, 64], 'base': [32, 62], 'center': [32, 31], 'box': [4, 3, 56, 56],
                           'note': 'the blossom box (28 x 28 px) is box; the heart glows at center (a light r 40..70 there)'},
            'bloom_decoy': {'frame': [64, 64], 'base': [32, 62], 'center': [32, 32], 'box': [4, 4, 56, 56],
                            'note': 'unlit: give it no light; breathe it with a scale pulse, never a glow'},
            'root_spear': {'frame': [64, 128], 'base': [32, 128], 'body': [6, 0, 52, 128], 'top': 1,
                           'note': 'the 26 x 64 px pillar is body (the whole frame high); its one-way ledge is its cap, '
                                   'the top of body'},
            'skull_seed': {'frame': [64, 64], 'center': [32, 38]},
            'thorn': {'frame': [64, 64], 'tip': [32, 56], 'center': [32, 30], 'note': 'points down; turn it to its fall'},
            'root_hump': {'frame': [128, 64], 'base': [64, 64], 'top': 1, 'body': [6, 0, 116, 64],
                          'note': 'a solid block one tile tall (32 px) and 60 px wide, nothing to pass under: body'},
        },
        '_placement': {
            'anchor_from_wall_px': PLACE_WALL_DX, 'anchor_x_r_arena': 896 + PLACE_WALL_DX,
            'extent_px': {'near': 95, 'far': 88, 'trunk_near': 53, 'trunk_far': 49, 'up': 182},
            'how': 'Where to root her in R_ARENA (spec 3.4.4: her trunk is the wall columns 28..35, rooted into the '
                   'right quarter): her anchor %g px right of the right wall\'s face (x 896, the left edge of col 28), '
                   'so x %g (29.5 tiles), on the floor (row 13\'s top), facing left. Then her trunk box begins 5 px '
                   'in front of the wall face (chip hits reach it from the floor), her far side ends over col 32, '
                   'and her nearest reach (a hand on the floor, 95 px ahead of the anchor) stops at x 849, 17 px '
                   'clear of the col-25 vine lane (and under the V2 socket at (26, 6) by 28 px). The bough starts '
                   'at the wall face (the sweep frames\' bough point, 47 px ahead) and extends about 12 segments to '
                   'the far wall. Do not anchor her on the map\'s X (27, 12): there her near hand crosses the vine. '
                   'At 1:1 she is 173 x 186 px (5.4 x 5.8 tiles), not the 8-tile trunk the arena map draws: see A4\'s '
                   'request to W0 (keep 1:1; her roots can fill the rest of the wall in the arena art).'
                   % (PLACE_WALL_DX, 896 + PLACE_WALL_DX)},
        '_sockets': {
            'floor': 'a floor or ledge socket (F1, F2, L1, L2): the bloom\'s base on the top of the solid cell under '
                     'the anchor cell, at the cell\'s centre x',
            'vine': 'a vine socket (V1, V2): the bloom\'s center on the anchor cell\'s centre',
        },
        '_height_units': 360,
    }
    return PTS.json(head)


# ================================================================ build

def files():
    PTS.d.clear()
    out = {}
    for n in FRAMES:
        out['art/enemies/rootmother_%s.svg' % n] = frame(n)
    for i in (1, 2, 3):
        out['art/enemies/rootmother_bough%d.svg' % i] = bough_part(i)
    out['art/enemies/rootmother_legs.svg'] = legs_part()
    out['art/enemies/bloom_bud.svg'] = prop_bloom('bud')
    out['art/enemies/bloom_open.svg'] = prop_bloom('open')
    out['art/enemies/bloom_decoy.svg'] = prop_bloom('decoy')
    out['art/enemies/root_spear.svg'] = prop_spear()
    out['art/enemies/skull_seed.svg'] = prop_seed()
    out['art/enemies/thorn.svg'] = prop_thorn()
    out['art/enemies/root_hump.svg'] = prop_hump()
    check_poses()
    out['art/enemies/points_rootmother.json'] = points_json()
    return out


def expect():
    e = {'art/enemies/rootmother_%s.svg' % n: (384, 384) for n in FRAMES}
    e.update({'art/enemies/rootmother_bough%d.svg' % i: BOUGH for i in (1, 2, 3)})
    e['art/enemies/rootmother_legs.svg'] = LEGS
    e.update({'art/enemies/%s.svg' % k: v for k, v in PROPS.items()})
    return e


def build(write):
    out = files()
    check_art(out, 'Mother Gravebough', BUDGET_MB, expect())
    for rel, text in out.items():
        write(rel, text)
    ensure_imports(out)


if __name__ == '__main__':
    if '--poses' in sys.argv:
        # python3 boss3.py --poses <dir>: the bough poses as SVGs, for a look
        d = sys.argv[sys.argv.index('--poses') + 1]
        PTS.d.clear()
        for n in FRAMES:
            frame(n)
        for name in poses():
            open(os.path.join(d, 'pose_%s.svg' % name), 'w').write(pose_svg(name))
    else:
        run_main(files, 'Mother Gravebough', BUDGET_MB, expect)
