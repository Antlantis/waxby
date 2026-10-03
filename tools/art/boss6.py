"""World 6's boss: the Hush (boss id hush), the quiet at the bottom of the world.

The Hush is an absence: black, silent, rimmed in silver (W6's rim, c8c8f0,
4 units) with pale edges (d8d4f0). It has no body of its own. In P2 it
wears the player's own rig at 3x, in black (the shadow Waxby: no art here);
what it has is drawn here as parts the fight poses:

  hush_eye_open / _half / _shut / _wince   the Eye (512 x 256): 3 tiles tall with its black
                   lids (an almond of white d8d4f0 inside them), a pale violet iris ringed
                   6a5a9a, the lids rimmed silver and no lashes (v2's post-credits Eye).
                   The pupil is not in it: hush_pupil tracks Wick over the iris (points:
                   iris_center, pupil_travel, pupil_band).
  hush_pupil       (64) the small black pupil (a fifth of the iris, as v2's) with a white glint
                   (it carries the gaze's Hush light)
  hush_eye_small   (96 x 48) P1's Eye, a tile across (the big frames have no mipmaps: never
                   draw them that small), lidded, its pupil drawn in
  hush_hand_rise / _grasp / _splay / _sink   (256) the Hands: black childlike hands, four
                   long fingers, a silver rim, pale fingertips; drawn rising from the water,
                   the wrist at (128, 244) (the waterline). _rise, _grasp and _sink fit the
                   Grasp's 40 x 64 px column; _splay is the open palm spread as wide as the
                   frame (the Snuff scales it up over its islet; its outline for the pale
                   tell is in points_hush.json)
  hush_core        (128) the Maw's core: a cold dead star (the choke window's target)
  stolen_flame     (64) one of the six flames it ate, warm, in a thin dark grip
                   (the finale's cold flame is this one modulated grey)

Props: sunken_bell and sunken_bell_smothered (64 x 96: an old bronze bell standing on
its islet, its base on y 88; smothered: under black ooze), ring_ledge (192 x 64: a pale
ring of light, 3 tiles wide, its one-way top at y 24).

points_hush.json (frame units; world offset = (p - anchor) / 2 px): the Eye's iris and
pupil band per frame, each hand's wrist, palm, tips and box, the splay's outline, the
core's centre and radius, the flame's base and tip, the bell's mouth and base, the
ring's top.
Run on its own: python3 tools/art/boss6.py [--check]
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import kit
from kit import Part, pth
from common import Ctx, svg, paint, line, dot, spec, star4, flame_d
from boss import ell_d
from boss3 import (Points, bez, smooth_d, poly_d, radial, check_art, ensure_imports, run_main, open_d, ribbon, ribbon_pts)

# ================================================================ the palette

INK = '#06050a'                                  # the Hush's black
INK_SH = '#020104'
INK_HI = '#1e1a2c'
SILVER = '#c8c8f0'                               # W6's rim
PALE = '#d8d4f0'                                 # the Eye's white, the fingertips
PALE_SH = '#aaa4cc'
IRIS, IRIS_DK, IRIS_RING, IRIS_HI = '#b0a4dc', '#8a78c0', '#6a5a9a', '#dcd6f6'
BRONZE, BRONZE_SH, BRONZE_HI = '#6e5a36', '#4a3c24', '#a08a5a'
PATINA, PATINA_SH = '#5a7a6a', '#3c5448'
FLAME, FLAME_MID, FLAME_CORE, FLAME_LINE = '#f2b84b', '#ffd98a', '#fff2c8', '#5a1e0c'
RIM_W6 = 4.0
PAL = dict(line=INK, rim=SILVER, base=INK, shade=INK_SH)

EYE = (512, 256)
EYE_C = (256.0, 128.0)
HAND_WRIST = (128.0, 244.0)
FRAMES_EYE = ['open', 'half', 'shut', 'wince']
FRAMES_HAND = ['rise', 'grasp', 'splay', 'sink']
PARTS = {'hush_pupil': (64, 64), 'hush_eye_small': (96, 48), 'hush_core': (128, 128), 'stolen_flame': (64, 64), 'sunken_bell': (64, 96),
         'sunken_bell_smothered': (64, 96), 'ring_ledge': (192, 64)}
BUDGET_MB = 16

PTS = Points()


def paint6(ctx, parts, pal=PAL):
    """Paint with W6's rim: silver, 4 units."""
    old = kit.RIM_W
    kit.RIM_W = RIM_W6
    try:
        return paint(ctx, parts, pal)
    finally:
        kit.RIM_W = old


# ================================================================ the Eye

def almond(cx, cy, w, top, bot, pinch=0.0):
    """An almond from corner to corner, its top curve reaching up to top and
    its bottom down to bot (pinch sharpens the corners)."""
    x0, x1 = cx - w / 2, cx + w / 2
    k = 0.30 + pinch
    return ('M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f '
            'C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z') % (
        x0, cy,
        x0 + w * k * 0.5, cy - (cy - top) * 0.62, cx - w * 0.28, top, cx, top,
        cx + w * 0.28, top, x1 - w * k * 0.5, cy - (cy - top) * 0.62, x1, cy,
        x1 - w * k * 0.5, cy + (bot - cy) * 0.62, cx + w * 0.28, bot, cx, bot,
        cx - w * 0.28, bot, x0 + w * k * 0.5, cy + (bot - cy) * 0.62, x0, cy)


def curve_pts(p0, p1, p2, p3, n=16):
    return bez(p0, p1, p2, p3, n)


def eye_frame(kind):
    ctx = Ctx('he' + kind[:2])
    cx, cy = EYE_C
    W = 448.0
    s = ''
    fid = 'hush_eye_' + kind
    # the lids' black mass round the almond (a wider, softer almond)
    outer = almond(cx, cy, W + 30, 30, 226, 0.05)
    s += '<path d="%s" fill="none" stroke="%s" stroke-width="%.1f" stroke-linejoin="round"/>' % (outer, SILVER, RIM_W6 * 2 + 3)
    s += '<path d="%s" fill="%s"/>' % (outer, INK)
    iris_r = 72.0
    band = None
    if kind in ('open', 'half'):
        top = 50 if kind == 'open' else 112
        white = almond(cx, cy, W, top, 208, 0.0) if kind == 'open' else almond(cx, cy + 6, W * 0.96, top, 208, 0.08)
        cid = ctx.clip('<path d="%s"/>' % white)
        g = ctx.radgrad([(0, '#f0eefc'), (0.55, PALE), (1, PALE_SH)], cx=0.5, cy=0.5, r=0.55)
        s += '<path d="%s" fill="%s"/>' % (white, g)
        s += '<g clip-path="%s">' % cid
        # the iris: pale violet, ringed, striated; the pupil is hush_pupil, on top
        ig = ctx.radgrad([(0, IRIS_HI), (0.45, IRIS), (0.85, IRIS_DK), (1, IRIS_RING)])
        s += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s"/>' % (cx, cy, iris_r, ig)
        for i in range(36):
            a = math.radians(i * 10 + 3)
            s += line('M%.1f %.1f L%.1f %.1f' % (cx + math.cos(a) * 30, cy + math.sin(a) * 30, cx + math.cos(a) * iris_r * 0.9,
                                                 cy + math.sin(a) * iris_r * 0.9), IRIS_RING, 1.4, op=0.45)
        s += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="none" stroke="%s" stroke-width="6"/>' % (cx, cy, iris_r - 3, IRIS_RING)
        s += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="none" stroke="%s" stroke-width="2" opacity="0.8"/>' % (cx, cy, 34, IRIS_HI)
        # the shadow of the upper lid across the white
        s += '<path d="%s" fill="%s" opacity="0.35"/>' % (almond(cx, top + 10, W * 0.9, top - 30, top + 26, 0.1), '#4a4470')
        s += '</g>'
        s += '<path d="%s" fill="none" stroke="%s" stroke-width="3"/>' % (white, INK)
        # the lid rims: silver along both lid edges (no lashes: v2's post-credits Eye has none)
        up_edge = curve_pts((cx - W / 2, cy + (6 if kind == 'half' else 0)), (cx - W * 0.28, top), (cx + W * 0.28, top),
                            (cx + W / 2, cy + (6 if kind == 'half' else 0)))
        lo_edge = curve_pts((cx - W / 2, cy), (cx - W * 0.28, 208), (cx + W * 0.28, 208), (cx + W / 2, cy))
        s += line(open_d(up_edge), SILVER, 5.4) + line(open_d(lo_edge), SILVER, 3.4, op=0.9)
        band = (top + 22, 190) if kind == 'open' else (top + 26, 190)
    elif kind == 'shut':
        # closed: all lid, one silver lid line sagging across the middle
        mid = curve_pts((cx - W / 2, cy - 4), (cx - W * 0.25, cy + 30), (cx + W * 0.25, cy + 30), (cx + W / 2, cy - 4))
        s += '<path d="%s" fill="%s" opacity="0.8"/>' % (almond(cx, cy + 2, W * 0.94, 56, 204, 0.0), INK_HI)
        s += line(open_d(mid), SILVER, 5.4)
        s += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (cx - W * 0.3, cy - 34, cx, cy - 52, cx + W * 0.3, cy - 34), SILVER, 2, op=0.45)
    else:   # wince: squeezed shut, the lid crumpled
        mid = []
        for i in range(17):
            t = i / 16.0
            x = cx - W / 2 + W * t
            y = cy + 14 * math.sin(t * math.pi) + (7 if i % 2 else -7) * math.sin(t * math.pi)
            mid.append((x, y))
        s += '<path d="%s" fill="%s" opacity="0.8"/>' % (almond(cx, cy, W * 0.9, 66, 190, 0.0), INK_HI)
        s += line(poly_d(mid)[:-2].replace('Z', ''), SILVER, 5)
        for k in (-1, 1):
            d = 'M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (cx - W * 0.34, cy + k * 36, cx, cy + k * 56, cx + W * 0.34, cy + k * 36)
            s += line(d, SILVER, 2.6, op=0.7)
    text = svg(ctx, s, EYE[0], EYE[1])
    PTS.mark(fid, iris_center=EYE_C, pupil=kind in ('open', 'half'),
             pupil_band=list(band) if band else None)
    return text


PUPIL_R = 14.0      # about a fifth of the iris (v2's post-credits Eye has a small pupil)


def part_pupil():
    """hush_pupil (64): a small black pupil (r PUPIL_R, a fifth of the iris as in
    v2's post-credits Eye), a thin violet edge and a white glint."""
    ctx = Ctx('hp')
    r = PUPIL_R
    s = radial(ctx, 32, 32, r * 2.2, IRIS_RING, 0.55)
    s += '<circle cx="32" cy="32" r="%.1f" fill="none" stroke="%s" stroke-width="2.4" opacity="0.8"/>' % (r + 1, IRIS_RING)
    s += '<circle cx="32" cy="32" r="%.1f" fill="%s"/>' % (r, INK)
    s += dot(32 - r * 0.38, 32 - r * 0.4, r * 0.3, '#ffffff')
    s += dot(32 + r * 0.4, 32 + r * 0.42, r * 0.12, PALE, 0.6)
    return svg(ctx, s, 64, 64)


def part_eye_small():
    """hush_eye_small (96 x 48): P1's Eye, a tile across (spec 5.5.2: lidded,
    swimming under the lake, surfacing by a rung bell): its almond 64 units
    (32 px) wide, heavy-lidded, the pupil and glint drawn in. Small, so it
    keeps its mipmaps and stays clean as it swims (the big frames have none)."""
    ctx = Ctx('hs')
    cx, cy, W = 48.0, 25.0, 64.0
    outer = almond(cx, cy, W + 10, 7, 43, 0.05)
    s = '<path d="%s" fill="none" stroke="%s" stroke-width="%.1f" stroke-linejoin="round"/>' % (outer, SILVER, RIM_W6 + 1.4)
    s += '<path d="%s" fill="%s"/>' % (outer, INK)
    white = almond(cx, cy + 2, W * 0.96, 15, 38, 0.08)
    cid = ctx.clip('<path d="%s"/>' % white)
    g = ctx.radgrad([(0, '#f0eefc'), (0.55, PALE), (1, PALE_SH)], cx=0.5, cy=0.5, r=0.55)
    s += '<path d="%s" fill="%s"/>' % (white, g)
    ig = ctx.radgrad([(0, IRIS_HI), (0.45, IRIS), (0.85, IRIS_DK), (1, IRIS_RING)])
    s += '<g clip-path="%s"><circle cx="%.1f" cy="%.1f" r="11" fill="%s"/>' % (cid, cx, cy + 2, ig)
    s += '<circle cx="%.1f" cy="%.1f" r="10" fill="none" stroke="%s" stroke-width="1.6"/>' % (cx, cy + 2, IRIS_RING)
    s += '<circle cx="%.1f" cy="%.1f" r="2.6" fill="%s"/>' % (cx, cy + 2, INK)
    s += '<path d="%s" fill="%s" opacity="0.35"/></g>' % (almond(cx, 18, W * 0.9, 9, 22, 0.1), '#4a4470')
    s += dot(cx - 3.4, cy - 1.2, 1.3, '#ffffff')
    up = curve_pts((cx - W * 0.48, cy + 2), (cx - W * 0.27, 15), (cx + W * 0.27, 15), (cx + W * 0.48, cy + 2))
    s += '<path d="%s" fill="none" stroke="%s" stroke-width="1.6"/>' % (white, INK)
    s += line(open_d(up), SILVER, 2.2)
    return svg(ctx, s, 96, 48)


# ================================================================ the Hands

def finger(base, ang, ln, w, curls=(0.0, 0.0), tip=True):
    """A long finger from its base toward ang degrees, bending by curls at
    its two knuckles; returns (ribbon points, the tip point)."""
    a = math.radians(ang)
    p = [base]
    seg = ln / 3.0
    x, y = base
    for c in (0.0,) + tuple(curls):
        a += c
        x, y = x + math.cos(a) * seg, y + math.sin(a) * seg
        p.append((x, y))
    c = bez(p[0], p[1], p[2], p[3], 12)
    return c, p[3]


def hand_parts(kind):
    """One Hand, the wrist at (128, 244): (parts, points, outline or None)."""
    wx, wy = HAND_WRIST
    P = []
    tips = []
    fw = (14, 12, 9.4)
    if kind == 'rise':
        # the Grasp's tell and rise: fingers up, inside the 40 x 64 px column (x 88..168, y 116..244)
        palm_c, palm_r = (128, 206), (24, 24)
        fing = [((110, 190), -99, 60, (0.03, 0.05)), ((122, 186), -93, 66, (0.02, 0.02)), ((134, 186), -87, 66, (-0.02, -0.02)),
                ((146, 190), -81, 58, (-0.04, -0.05))]
        thumb = ((148, 212), -48, 30, (-0.3, -0.2))
    elif kind == 'grasp':
        # closing on its column, the fingertips curled in over it (inside the column)
        palm_c, palm_r = (128, 204), (26, 26)
        fing = [((108, 190), -110, 60, (0.36, 0.44)), ((121, 184), -97, 68, (0.3, 0.4)), ((135, 184), -83, 68, (-0.3, -0.4)),
                ((148, 190), -70, 60, (-0.36, -0.44))]
        thumb = ((150, 214), -40, 30, (-0.6, -0.5))
    elif kind == 'splay':
        # the Snuff: spread as wide as the frame (it is scaled up over a 6-tile islet)
        palm_c, palm_r = (128, 176), (42, 40)
        fw = (19, 16, 12.5)
        fing = [((100, 156), -150, 100, (0.05, 0.06)), ((116, 142), -114, 108, (0.03, 0.04)), ((139, 140), -79, 110, (-0.03, -0.04)),
                ((157, 150), -41, 100, (-0.05, -0.06))]
        thumb = ((166, 194), 14, 58, (0.1, 0.08))
    else:   # sink: drooping, going under (inside the column)
        palm_c, palm_r = (128, 216), (24, 22)
        fing = [((110, 204), -124, 50, (0.5, 0.5)), ((122, 198), -104, 56, (0.45, 0.45)), ((134, 198), -76, 56, (-0.45, -0.45)),
                ((146, 204), -56, 50, (-0.5, -0.5))]
        thumb = ((146, 222), -44, 22, (0.4, 0.3))
    # the wrist rising out of the water
    ww = palm_r[0] * 1.3
    wrist = ribbon([(wx, wy), (wx, (wy + palm_c[1]) / 2), (palm_c[0], palm_c[1] + palm_r[1] * 0.6)], (ww, ww * 0.9, ww * 1.05),
                   caps=(False, True))
    P.append(Part('fill', pth(wrist), fill=INK, shade=INK_SH, off=(-3, -3)))
    outline = []
    for base, ang, ln, curls in fing:
        c, t = finger(base, ang, ln, 14, curls)
        pts = ribbon_pts(c, fw)
        P.append(Part('fill', pth(smooth_d(pts)), fill=INK, shade=INK_SH, off=(-2, -2),
                      hl=line(open_d(c[1:-3]), INK_HI, 2.4, op=0.9)))
        tips.append(t)
        outline.append(pts)
    c, t = finger(thumb[0], thumb[1], thumb[2], 14, thumb[3])
    P.append(Part('fill', pth(smooth_d(ribbon_pts(c, (fw[0] + 1, fw[1] - 1)))), fill=INK, shade=INK_SH, off=(-2, -2)))
    tips.append(t)
    P.append(Part('fill', pth(ell_d(palm_c[0], palm_c[1], palm_r[0], palm_r[1])), fill=INK, shade=INK_SH, off=(-4, -4),
                  hl=spec(palm_c[0] - 10, palm_c[1] - 12, 8, 3, rot=-30, op=0.18)))
    # pale fingertips
    over = ''
    for i, t in enumerate(tips):
        r = (6.4 if i < 4 else 5.6) * (1.0 if kind == 'splay' else 0.82)
        over += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s"/>' % (t[0], t[1], r + 1.2, PALE_SH)
        over += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s"/>' % (t[0], t[1], r, PALE)
        over += dot(t[0] - r * 0.3, t[1] - r * 0.35, r * 0.3, '#ffffff', 0.9)
    tips_c = (sum(t[0] for t in tips[:4]) / 4.0, sum(t[1] for t in tips[:4]) / 4.0)
    return P, over, dict(wrist=HAND_WRIST, palm=palm_c, tips=tips_c, fingertips=[[round(x, 1), round(y, 1)] for x, y in tips]), outline


def hand_frame(kind):
    ctx = Ctx('hh' + kind[:2])
    P, over, pts, outline = hand_parts(kind)
    ripple = ''
    if kind in ('rise', 'grasp', 'sink'):
        # the still water breaking round the wrist
        ripple = '<path d="%s" fill="none" stroke="%s" stroke-width="3" opacity="0.8"/>' % (ell_d(128, 244, 44, 4.4), SILVER)
        ripple += '<path d="%s" fill="none" stroke="%s" stroke-width="2" opacity="0.45"/>' % (ell_d(128, 245, 64, 5.4), SILVER)
    body = paint6(ctx, P)
    text = svg(ctx, body + over + ripple, 256, 256)
    fid = 'hush_hand_' + kind
    # its box: the hand above the waterline (the Grasp's 40 x 64 px column for rise and grasp)
    xs, ys = [], []
    for o in outline:
        xs += [p[0] for p in o]
        ys += [p[1] for p in o]
    x0, x1, y0 = min(xs) - 4, max(xs) + 4, min(ys) - 4
    box = (x0, y0, x1 - x0, HAND_WRIST[1] - y0)
    PTS.mark(fid, wrist=pts['wrist'], palm=pts['palm'], tips=pts['tips'], box=box, fingertips=pts['fingertips'])
    if kind == 'splay':
        PTS.d.setdefault('_splay_outline', [])
        PTS.d['_splay_outline'] = splay_outline(outline)
    return text


def splay_outline(fingers):
    """The open hand's silhouette as one polygon (frame units), for the Snuff's
    pale palm outline in glow: round the palm, out along each finger and back."""
    pts = []
    for f in fingers:
        n = len(f)
        # a ribbon's points: its left side, the tip, its right side back
        half = (n - 2) // 2
        pts.append(f[0])
        pts.append(f[half])
        pts.append(f[half + 1])
        pts.append(f[n - 2])
    # close through the wrist
    pts.append((150, 244))
    pts.append((106, 244))
    return [[round(x, 1), round(y, 1)] for x, y in pts]


# ================================================================ the core, the flame

def part_core():
    """hush_core (128): the Maw's core, a cold dead star: pale spikes round a
    black hole, ringed in silver sparks (centre (64, 64))."""
    ctx = Ctx('hc')
    cx = cy = 64
    s = radial(ctx, cx, cy, 58, PALE, 0.45)
    pts = []
    for i in range(16):
        a = math.radians(i * 22.5 - 90)
        r = 44 if i % 2 == 0 else 20
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    s += '<path d="%s" fill="none" stroke="%s" stroke-width="%.1f" stroke-linejoin="round"/>' % (poly_d(pts), SILVER, RIM_W6 * 2 + 2)
    s += '<path d="%s" fill="%s" stroke="%s" stroke-width="2.4" stroke-linejoin="round"/>' % (poly_d(pts), PALE, INK)
    s += '<circle cx="%d" cy="%d" r="15" fill="%s" stroke="%s" stroke-width="2"/>' % (cx, cy, INK, SILVER)
    s += '<circle cx="%d" cy="%d" r="6" fill="none" stroke="%s" stroke-width="1.4" opacity="0.7"/>' % (cx, cy, IRIS)
    for i in range(8):
        a = math.radians(i * 45 + 22)
        s += star4(cx + math.cos(a) * 52, cy + math.sin(a) * 52, 4, '#ffffff', 0.8)
    return svg(ctx, s, 128, 128)


def part_flame():
    """stolen_flame (64): a warm flame the Hush ate, in a thin dark grip (base (32, 54))."""
    ctx = Ctx('sf')
    s = radial(ctx, 32, 34, 28, FLAME, 0.6)
    s += '<path d="%s" fill="%s" stroke="%s" stroke-width="2.2" stroke-linejoin="round"/>' % (flame_d(32, 54, 22, 44), FLAME, FLAME_LINE)
    s += '<path d="%s" fill="%s"/>' % (flame_d(32.4, 52, 15, 31), FLAME_MID)
    s += '<path d="%s" fill="%s"/>' % (flame_d(31.8, 50, 9, 18), FLAME_CORE)
    # the grip: two thin black tendrils wound round its base, rimmed silver
    for d in ('M14 50 Q22 42 32 47 Q42 52 50 44', 'M16 44 Q26 55 40 52 Q46 50 48 54'):
        s += line(d, SILVER, 4.2, op=0.7) + line(d, INK, 2.6)
    return svg(ctx, s, 64, 64)


# ================================================================ the props

def bell(ctx, smothered):
    """A sunken bell standing on its islet (base y 88), bronze gone green-black."""
    body = smooth_d([(25, 26), (22, 38), (20, 54), (17, 70), (12, 81), (12, 87), (52, 87), (52, 81), (47, 70), (44, 54), (42, 38), (39, 26),
                     (32, 22)])
    over = line('M14 81 Q32 86 50 81', BRONZE_HI, 2, op=0.8) + line('M20 42 Q32 46 44 42', BRONZE_SH, 1.6, op=0.8)
    # patina blooms and barnacles
    over += '<path d="%s" fill="%s" opacity="0.8"/>' % (ell_d(24, 60, 7, 10, 10), PATINA)
    over += '<path d="%s" fill="%s" opacity="0.7"/>' % (ell_d(42, 72, 6, 5, 0), PATINA)
    for x, y in ((38, 50), (22, 76), (46, 80)):
        over += '<circle cx="%.1f" cy="%.1f" r="2.6" fill="%s" stroke="%s" stroke-width="1"/>' % (x, y, '#9aa89a', INK)
    P = [Part('fill', pth('M27 14 Q32 8 37 14 L37 24 L27 24 Z'), fill=BRONZE_SH, shade=INK, off=(-1, -1)),
         Part('fill', pth(body), fill=BRONZE, shade=BRONZE_SH, off=(-4, -3), over=over, hl=spec(24, 44, 2.6, 9, rot=10, op=0.45))]
    ooze = ''
    if smothered:
        goo = smooth_d([(21, 26), (32, 16), (43, 26), (45, 44), (47, 58), (45, 70), (42, 62), (38, 76), (34, 62), (30, 72), (26, 60),
                        (22, 74), (18, 62), (17, 58), (19, 44)])
        P.append(Part('fill', pth(goo), fill=INK, shade=INK_SH, off=(-2, -2),
                      over=line('M22 36 Q26 52 22 66 M40 32 Q44 46 42 58', INK_HI, 3, op=0.9)))
        ooze = ''.join('<path d="%s" fill="%s" stroke="%s" stroke-width="1.2"/>' % (ell_d(x, y, 2.6, 3.6), INK, SILVER)
                       for x, y in ((20, 82), (40, 84), (30, 80)))
    return P, ooze


def prop_bell(smothered):
    ctx = Ctx('sb' + ('s' if smothered else 'b'))
    P, ooze = bell(ctx, smothered)
    return svg(ctx, paint6(ctx, P) + ooze, 64, 96)


def prop_ring():
    """ring_ledge (192 x 64): a pale ring of light seen edge on, 3 tiles wide
    (x 4..188), its one-way top at y 24 (centre (96, 34))."""
    ctx = Ctx('rl')
    s = radial(ctx, 96, 34, 90, PALE, 0.45, 0.35)
    ring = ell_d(96, 34, 88, 14)
    s += '<path d="%s" fill="none" stroke="%s" stroke-width="12" opacity="0.35"/>' % (ring, PALE)
    s += '<path d="%s" fill="none" stroke="%s" stroke-width="6"/>' % (ring, '#eeeafc')
    s += '<path d="%s" fill="none" stroke="#ffffff" stroke-width="2.4"/>' % ring
    # the near rim brighter: the edge you stand on
    s += line('M10 30 Q96 18 182 30', '#ffffff', 3, op=0.9)
    for x in (30, 70, 118, 160):
        s += star4(x, 26 + (x % 3), 3.4, '#ffffff', 0.85)
    return svg(ctx, s, 192, 64)


# ================================================================ build

def points_json():
    head = {
        '_doc': "The Hush's parts (frame units; 2 units = 1 world px). The Eye (512 x 256): anchor its centre "
                '(256, 128); iris_center is where hush_pupil\'s centre goes at rest; move the pupil within '
                'pupil_travel of it toward Wick, and keep its centre inside pupil_band [y0, y1] (the open lids); '
                'no pupil on _shut and _wince. The Hands (256): anchor the wrist (128, 244) on the waterline; tips = '
                'the four fingertips\' centre; palm = the palm; box = the hand above the water [x, y, w, h] (hit it '
                'while Heard); fingertips = each pale fingertip (the thumb last): draw them on the glow layer too, since the '
                'fingertips are always seen, even in the black. _splay_outline is the open hand\'s silhouette (a polygon, wrist at the bottom) for '
                'the Snuff\'s pale palm outline: flip and scale it with the sprite. hush_eye_small is P1\'s Eye (anchor '
                'its centre (48, 25)). Every part is black with W6\'s silver rim (c8c8f0, 4 units) and pale edges (d8d4f0).',
        '_eye': {'frame': list(EYE), 'center': list(EYE_C), 'iris_center': list(EYE_C), 'iris_r': 72,
                 'pupil_travel': 36, 'almond': [32, 50, 448, 158], 'height_units': 196,
                 'note': 'P3\'s Eye at 1:1 (sprite scale 0.25): with its black lids 478 x 196 units = 239 x 98 px (3 tiles '
                         'tall); the white almond inside is 224 x 79 px. These frames have no mipmaps: draw them at 1:1 '
                         '(the roar may grow it from about 0.6 up). P1\'s Eye (a tile across) is hush_eye_small.'},
        '_eye_small': {'frame': [96, 48], 'center': [48, 25], 'almond': [16, 7, 64, 36], 'iris_center': [48, 27], 'iris_r': 11,
                       'note': 'P1\'s Eye at 1:1: 37 x 18 px with its lids, the almond a tile (32 px) across; it keeps '
                               'its mipmaps, so it can be drawn smaller or squashed (a blink) as it swims'},
        '_pupil': {'frame': [64, 64], 'center': [32, 32], 'r': PUPIL_R, 'glint': [round(32 - PUPIL_R * 0.38, 1), round(32 - PUPIL_R * 0.4, 1)]},
        '_hand': {'frame': [256, 256], 'wrist': list(HAND_WRIST), 'grasp_column': [88, 116, 80, 128],
                  'note': 'the Grasp\'s 40 x 64 px column is grasp_column: rise, grasp and sink are drawn inside it (their '
                          'box is it), so what you see is what hurts. The Snuff\'s splay spans about 240 x 150 units '
                          '(117 x 90 px): scale it about 1.65 to cover a 6-tile islet (a black silhouette softens little).'},
        '_core': {'frame': [128, 128], 'center': [64, 64], 'r': 44, 'hit_r': 30},
        '_flame': {'frame': [64, 64], 'base': [32, 54], 'tip': [32, 10], 'center': [32, 36]},
        '_bells': {'frame': [64, 96], 'base': [32, 88], 'mouth': [32, 86], 'center': [32, 56], 'box': [10, 12, 44, 76]},
        '_ring': {'frame': [192, 64], 'top': 24, 'center': [96, 34], 'span': [4, 188]},
    }
    return PTS.json(head)


def files():
    PTS.d.clear()
    out = {}
    for k in FRAMES_EYE:
        out['art/enemies/hush_eye_%s.svg' % k] = eye_frame(k)
    for k in FRAMES_HAND:
        out['art/enemies/hush_hand_%s.svg' % k] = hand_frame(k)
    out['art/enemies/hush_pupil.svg'] = part_pupil()
    out['art/enemies/hush_eye_small.svg'] = part_eye_small()
    out['art/enemies/hush_core.svg'] = part_core()
    out['art/enemies/stolen_flame.svg'] = part_flame()
    out['art/enemies/sunken_bell.svg'] = prop_bell(False)
    out['art/enemies/sunken_bell_smothered.svg'] = prop_bell(True)
    out['art/enemies/ring_ledge.svg'] = prop_ring()
    out['art/enemies/points_hush.json'] = points_json()
    return out


def expect():
    e = {'art/enemies/hush_eye_%s.svg' % k: EYE for k in FRAMES_EYE}
    e.update({'art/enemies/hush_hand_%s.svg' % k: (256, 256) for k in FRAMES_HAND})
    e.update({'art/enemies/%s.svg' % k: v for k, v in PARTS.items()})
    return e


def build(write):
    out = files()
    check_art(out, 'the Hush', BUDGET_MB, expect())
    for rel, text in out.items():
        write(rel, text)
    ensure_imports(out)


if __name__ == '__main__':
    run_main(files, 'the Hush', BUDGET_MB, expect)
