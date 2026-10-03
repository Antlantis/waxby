"""Mother Gravebough, the Bone Gardener (W3's boss, story id `rootmother`),
for the story figures (story_figs_deep.py) and portraits
(story_faces_deep.py), drawn with the fight's own parts (tools/art/boss3.py,
A4; spec 6.6: "the boss figures copy the fight art's parts"), the way
story_snuffer.py draws the Snuffer with boss2.py's: the story shows the one
Gravebough the player fights.

Everything between the two "vendored" rules below is copied verbatim from
boss3.py (the drawing only: her palette, parts and frame(), and the outline
helpers boss4.py and boss5.py share, which story_tinker.py and
story_saint.py take from here). When boss3.py sits beside this file (the
merged tree), the story draws with boss3.py itself, so it follows the fight
art as A4 changes it; the copy draws her where boss3.py isn't (or where its
parts no longer fit the calls below: a note says so). `python3
tools/art/story.py --vendor` copies boss3/4/5.py's drawing here again.

  rootmother_boss   the fight's idle frame: rooted, the ember caged cold in
                    her chest, eyes nearly shut
  rootmother_open   (P1) she lets go: the fight's parts in the pose of its
                    last frame, the cage empty, her heart risen to bloom
                    warm in her crown, her eyes open and soft
  portraits         keeping (sleepy eyes, a smile, a skull fruit hanging by
                    her cheek), wrath (the eyes flared, a roar, roots curling
                    in at the frame's edges)

The figure frame (256, feet at (128, 244)) holds the fight's 384 frame at
FIG_K (story_snuffer's 0.6), at h FIG_H: she stands on a panel at the size
she fights at, beside Waxby. The helpers under the end rule (live, attempt,
split_doc, placed, to_fig) serve the Tinker's and the Saint's modules too.
"""
import json
import math
import os
import re
import sys

import kit
from kit import Part, pth
from common import Ctx, RIM, svg, paint, line, dot, spec, mix, gx, flame_d, CHAR_WEIGHTS
from boss import place, rot_pt, ell_d
from story_kit import weights

# ================================================================ vendored from boss3.py (A4): begin

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

PTS = Points()


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


# ================================================================ vendored from boss3.py (A4): end


# ================================================================ drawing with the fight's parts

import story_snuffer as _SN

FIG_K = _SN.FIG_K            # figure units per fight unit (2 fight units = 1 world px)
FIG_H = _SN.FIG_H            # the figure frame's height in panel units at that scale
HERE = os.path.dirname(os.path.abspath(__file__))
_DOC = re.compile(r'viewBox="0 0 ([0-9.]+) ([0-9.]+)">\s*<defs>(.*?)</defs>\s*(.*)</svg>\s*$', re.S)


def live(name):
    """A4's module when it sits beside this one (the merged tree), else None."""
    if not os.path.exists(os.path.join(HERE, name + '.py')):
        return None
    import importlib
    return importlib.import_module(name)


def attempt(name, copy, fn):
    """fn(module) with A4's own module when it is here, else (or when its parts
    no longer fit fn: a note says so) with the vendored copy."""
    m = live(name)
    if m is not None:
        try:
            with weights(CHAR_WEIGHTS):
                return fn(m)
        except Exception as e:      # A4 changed a part's shape: draw with the copy, and say so
            print('note: %s.py no longer fits the story (%s: %s); drawing with the copy in %s' % (
                name, type(e).__name__, e, copy.__name__))
    with weights(CHAR_WEIGHTS):
        return fn(copy)


def split_doc(text):
    """A fight frame's SVG document -> (its defs, its body, (w, h))."""
    m = _DOC.search(text)
    return m.group(3), m.group(4).strip(), (float(m.group(1)), float(m.group(2)))


def placed(body, foot, k=FIG_K):
    """Fight-frame drawing placed in the figure frame, its foot on (128, 244)."""
    return '<g transform="translate(128 244) scale(%.4f) translate(%.2f %.2f)">%s</g>' % (k, -foot[0], -foot[1], body)


def to_fig(p, foot, k=FIG_K):
    """A fight-frame point in the figure frame."""
    return (round(128 + (p[0] - foot[0]) * k, 2), round(244 + (p[1] - foot[1]) * k, 2))


# ---------------------------------------------------------------- Gravebough

THIS = sys.modules[__name__]
EYES_KEEP, EYES_OPEN = 'd8f0c0', 'f7d88a'       # the eye-lights: the fight's green-white, warm when she lets go
EMBER_COLD = 'a8d0ff'


def _open(M):
    """rootmother_open in the fight's 384 frame: frame('die')'s settled pose
    (arms at rest, warm petals falling, the cage empty, her heart a warm
    bloom at the top of her crown) with her eyes open and soft and a smile.
    Returns (svg text, points)."""
    ctx = Ctx('gbopen')
    dx, sy, rot = 6, 0.94, 6
    f = M.body_fn(dx, sy, 0.0)
    sb, sf = f(136, 222), f(274, 222)
    far = M.arm(sb, (100, 276), (82, 346), M.FAR_W, hand_ang=150, spread=0.9, curl=0.4, into=True)
    near = M.arm(sf, (310, 278), (318, 346), M.NEAR_W, hand_ang=34, spread=0.9, curl=0.4, into=True)
    over = M.petals_falling(ctx, 40, warm=True)
    roots = M.base_roots(ctx)
    trunk = M.trunk_parts(ctx, f, 'none', {})
    hx, hy = f(*M.NECK)
    hc = (hx + (M.HEAD_AT[0] - M.NECK[0]), hy + (M.HEAD_AT[1] - M.NECK[1]))
    hl = {}
    hparts, hover = M.head(ctx, eyes='watch', mouth='smile', crown='bloom', fx_out=hl)
    t = 'translate(%.1f %.1f) rotate(%.1f)' % (hc[0], hc[1], rot)
    hparts = place(hparts, t)
    hover = gx(hover, t)

    def H(p):
        return rot_pt(hc[0] + p[0], hc[1] + p[1], hc[0], hc[1], rot)
    body = paint(ctx, far + roots + trunk + near + hparts, M.PAL)
    text = svg(ctx, body + hover + over, 384, 384)
    return text, {'eye_l': H(hl['eye_l']), 'eye_r': H(hl['eye_r']), 'heart': H(hl['crown_heart'])}


def figure(pose):
    """Gravebough for the figure frame: {defs, body, eyes: [l, r], ember} (the
    points in figure units). pose: keep (the fight's idle) or open."""
    def draw(M):
        if pose == 'keep':
            text = M.frame('idle')
            pts = M.PTS.d['rootmother_idle']
        else:
            text, pts = _open(M)
        defs, body, _ = split_doc(text)
        return {'defs': defs, 'body': placed(body, M.FOOT),
                'eyes': [to_fig(pts['eye_l'], M.FOOT), to_fig(pts['eye_r'], M.FOOT)], 'ember': to_fig(pts['heart'], M.FOOT)}
    return attempt('boss3', THIS, draw)


PORTRAIT_K = 0.62          # fight units -> portrait native units


def portrait(ctx, mood, lw):
    """Her head from the fight (head(): the bark wimple, the moss shawl, the
    carved face and the crown), mirrored to face left, the face filling the
    circle, in native portrait units (144 box). keeping: sleepy eyes and a
    smile, a skull fruit hanging by her cheek; wrath: the eyes flared, a
    roar, roots curling in at the frame's edges. lw: the portraits' line
    weights. Returns svg."""
    def draw(M):
        wrath = mood == 'wrath'
        k = PORTRAIT_K
        hk = dict(eyes='glare', mouth='roar', crown='dead') if wrath else dict(eyes='sleepy', mouth='smile', crown='dead')
        parts, over = M.head(ctx, **hk)
        fc = M.FACE_C
        t = 'translate(72 76) scale(%.3f %.3f) translate(%.2f %.2f)' % (-k, k, -fc[0], -fc[1])
        extra = []
        fx = ''
        if wrath:
            # roots curling in at the frame's edges (the fight's root part), and
            # the wood of her brow split into the frown
            for c, w in (([(-112, -74), (-92, -64), (-74, -70), (-70, -52)], (16, 6)),
                         ([(146, -76), (126, -66), (108, -72), (104, -54)], (16, 6)),
                         ([(-114, 84), (-94, 70), (-74, 76), (-70, 60)], (14, 5)),
                         ([(148, 82), (128, 68), (110, 74), (106, 58)], (14, 5))):
                extra.append(M.root(M.bez(c[0], c[1], c[2], c[3], 10), w, n_groove=1))
            crack = 'M%.1f %.1f l-4 9 l6 6 l-5 10' % (fc[0] - 2, fc[1] - 60)
            fx = line(crack, M.L, 2.6) + line(crack, M.BARK_HI, 0.9, op=0.8)
        else:
            # a skull fruit hanging by her cheek, on a twig from the hood
            extra.append(M.root(M.bez((-46, -6), (-58, 8), (-58, 20), (-52, 32), 8), (6, 2.6), n_groove=0, hi=False))
            extra += M.skull_fruit(ctx, -50, 46, 0.9, 8)
        with weights(tuple(w / k for w in lw)):
            art = paint(ctx, place(parts + extra, t), M.PAL)
        return art + gx(over + fx, t)
    return attempt('boss3', THIS, draw)
