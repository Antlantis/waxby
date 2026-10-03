"""The Tinker of Hours (W4's boss, story id `tinker`) and Master Tickwell,
for the story figures (story_figs_deep.py) and portraits
(story_faces_deep.py), drawn with the fight's own parts (tools/art/boss4.py,
A4; spec 6.6), as story_rootmother.py draws Gravebough: a walking clockwork
bell-body of brass and frosted wax, a domed head with two lamp-lens eyes and
a winding key, a frosted clock face for a chest (dashes, no numerals, its
hands frozen at one minute to midnight), the minute hand for a blade, a
gear-wheel hand, frost on its shoulders, and on its back a frosted case
holding Master Tickwell frozen round his lantern-watch, the mainspring
beside him (spec 5.3 and 6.5 edit 4).

Everything between the two "vendored" rules below is copied verbatim from
boss4.py (its outline helpers come from story_rootmother.py's copy of
boss3.py's, as boss4.py takes them from boss3.py). When boss4.py sits
beside this file (the merged tree) the story draws with it instead
(story_rootmother.attempt). `python3 tools/art/story.py --vendor` copies it
here again.

  tinker_boss       the fight's idle frame; the `heart` light is Tickwell's
                    watch behind the frosted glass
  portraits         his head and chest, mirrored to face left: ticking (the
                    lamp-lens eyes lit and calm, the chest's hands frozen,
                    frost on the rim), wrath (brass shutters half down over
                    the lenses, the hands spun to odd angles, the dial's
                    glass cracked)

Master Tickwell's own figure and portraits (story_figs_deep.tickwell,
story_faces_deep.tickwell) are the story's (the fight shows him only tiny,
in the case); they wear the fight's colours for him (SKIN, COAT, APRON,
HAIR, LENS, BRASS below) and his face, goggles and watch are drawn here.
"""
import math
import sys

import kit
from kit import Part, pth
from common import Ctx, RIM, svg, paint, line, dot, spec, star4, mix, gx, flame_d, CHAR_WEIGHTS
from boss import place, rot_pt, ell_d
from story_kit import weights
from story_rootmother import Points, smooth_d, poly_d, radial, motion
import story_rootmother as _RM

# ================================================================ vendored from boss4.py (A4): begin

L = '#1c1208'                                    # ink

BRASS, BRASS_SH, BRASS_HI, BRASS_DK = '#c8983a', '#8a6424', '#f0d080', '#5a3c14'

IRON, IRON_SH, IRON_HI = '#4a4a5a', '#30303e', '#7a7a90'

FROST, FROST_SH, FROST_HI = '#d8f0fc', '#9ac8e0', '#ffffff'

WAX, WAX_SH = '#ece6d6', '#c6bca6'              # frosted wax on his joints

FACEC, FACEC_SH = '#f4f0e0', '#cfc8b0'          # the clock face's cream

NAVY, NAVY_HI = '#1a2440', '#4a5a86'            # clock hands

LENS, LENS_CORE = '#9ad8f0', '#eaf8ff'          # his lamp eyes (not W4's tell accent e8fcff)

GOLD, GOLD_HI, GOLD_CORE = '#f2c040', '#ffe27a', '#fff6c8'

GLASS = '#bfe0f0'

SKIN, SKIN_SH = '#e8c8b0', '#c8a088'            # Tickwell

COAT, COAT_SH = '#4a5a8a', '#34406a'

APRON, APRON_SH = '#8a5a3a', '#6a4028'

HAIR = '#f4f4f4'

PAL = dict(line=L, rim=RIM, base=BRASS, shade=BRASS_SH)

FOOT = (192, 368)

GROUND = 368.0

PTS = Points()

FALL = 90.0                        # Chimed: the body turned this far (flat on his front), then FALL_T

FALL_T = (398.0, 64.0)

COIL = (214.0, 328.0, 36.0)        # Chimed: the sprung mainspring's coil on the floor (centre x, y, outer r)

HEAD_K = 1.18                      # his head, a touch bigger (chibi)


def brass(d, fill=BRASS, shade=BRASS_SH, off=(-3, -3), over='', hl='', under='', rim=True, lw=None, sil=True):
    return Part('fill', pth(d), fill=fill, shade=shade, off=off, over=over, hl=hl, under=under, rim=rim, lw=lw, sil=sil)


def gear_d(cx, cy, r, n=10, depth=0.22, rot=0.0):
    """A cog's outline: n square-ish teeth round a disc of radius r."""
    pts = []
    for i in range(n * 4):
        a = math.radians(rot) + (i / (n * 4.0)) * 2 * math.pi
        rr = r if (i % 4) in (1, 2) else r * (1 - depth)
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    return poly_d(pts)


def gear(cx, cy, r, n=10, rot=0.0, fill=BRASS, shade=BRASS_SH, hole=True, spokes=4):
    """A brass cog with a hub and spokes (Parts)."""
    over = ''
    if spokes:
        for i in range(spokes):
            a = math.radians(rot + i * 180.0 / spokes)
            over += line('M%.1f %.1f L%.1f %.1f' % (cx - math.cos(a) * r * 0.6, cy - math.sin(a) * r * 0.6,
                                                   cx + math.cos(a) * r * 0.6, cy + math.sin(a) * r * 0.6), BRASS_DK, max(1.2, r * 0.12))
    over += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="none" stroke="%s" stroke-width="%.1f" opacity="0.8"/>' % (
        cx, cy, r * 0.62, BRASS_DK, max(1.0, r * 0.08))
    if hole:
        over += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s" stroke="%s" stroke-width="1.2"/>' % (cx, cy, r * 0.2, BRASS_HI, L)
        over += dot(cx, cy, r * 0.08, L)
    return [brass(gear_d(cx, cy, r, n, rot=rot), fill=fill, shade=shade, off=(-r * 0.12, -r * 0.14), over=over,
                  hl=spec(cx - r * 0.4, cy - r * 0.45, r * 0.2, r * 0.1, rot=-35, op=0.7))]


def tube(a, b, w, fill=BRASS, hi=True):
    """A brass tube from a to b (an arm or leg segment)."""
    d = 'M%.1f %.1f L%.1f %.1f' % (a[0], a[1], b[0], b[1])
    over = ''
    if hi:
        ang = math.atan2(b[1] - a[1], b[0] - a[0])
        nx, ny = -math.sin(ang) * w * 0.25, math.cos(ang) * w * 0.25
        over = line('M%.1f %.1f L%.1f %.1f' % (a[0] - nx, a[1] - ny, b[0] - nx, b[1] - ny), BRASS_HI, max(1.2, w * 0.18), op=0.85)
        # two bands round it
        for t in (0.3, 0.7):
            x, y = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
            over += line('M%.1f %.1f L%.1f %.1f' % (x + nx * 2.1, y + ny * 2.1, x - nx * 2.1, y - ny * 2.1), BRASS_DK, 2.2, cap='butt')
    return Part('limb', pth(d), width=w, fill=fill, over=over)


def ball(x, y, r, fill=BRASS, shade=BRASS_SH, frost=False):
    over = ''
    if frost:
        over = '<path d="%s" fill="%s" opacity="0.85"/>' % (ell_d(x - r * 0.1, y - r * 0.5, r * 0.8, r * 0.45), FROST)
    return brass(ell_d(x, y, r, r), fill=fill, shade=shade, off=(-r * 0.25, -r * 0.3), over=over,
                 hl=spec(x - r * 0.35, y - r * 0.4, r * 0.3, r * 0.18, rot=-35, op=0.8))


def frost_clump(cx, cy, w, h, seed=0.0, icicles=2):
    """A crust of frost sitting on a ledge (its underside on y = cy), with icicles."""
    pts = []
    n = 9
    for i in range(n + 1):
        t = i / float(n)
        x = cx - w / 2 + w * t
        y = cy - h * (0.35 + 0.65 * math.sin(math.pi * t)) * (0.8 + 0.2 * math.sin(t * 9 + seed))
        pts.append((x, y))
    pts += [(cx + w / 2, cy + 2), (cx - w / 2, cy + 2)]
    P = [Part('fill', pth(smooth_d(pts)), fill=FROST, shade=FROST_SH, off=(-2, -2), lw=1.2,
              hl=line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (cx - w * 0.3, cy - h * 0.55, cx, cy - h * 0.9, cx + w * 0.25, cy - h * 0.6),
                      FROST_HI, 1.6, op=0.9))]
    for k in range(icicles):
        x = cx - w * 0.3 + (w * 0.6) * (k + 0.5) / icicles + math.sin(seed + k) * 3
        ln = 10 + 6 * abs(math.sin(seed * 3 + k * 2))
        P.append(Part('fill', pth('M%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (x - 3.2, cy, x + 3.2, cy, x + 0.4, cy + ln)),
                      fill=FROST, shade=FROST_SH, off=(-0.8, -0.8), lw=1.0))
    return P


def chest_face(ctx, cx, cy, r, mood='frozen', crack=False):
    """The frosted clock face (drawn over the bell): dashes for the hours,
    navy hands at one minute to midnight (frozen), blurred backwards
    (rewind), lit (watch)."""
    s = '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s" stroke="%s" stroke-width="2.6"/>' % (cx, cy, r + 5, BRASS_SH, L)
    s += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="none" stroke="%s" stroke-width="2"/>' % (cx - 0.8, cy - 1, r + 4, BRASS_HI)
    g = ctx.radgrad([(0, '#ffffff' if mood == 'lit' else FACEC), (0.7, FACEC), (1, FACEC_SH)])
    s += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s" stroke="%s" stroke-width="1.6"/>' % (cx, cy, r, g, L)
    for i in range(12):
        a = math.radians(i * 30 - 90)
        long_ = i % 3 == 0
        r0, r1 = r * (0.72 if long_ else 0.8), r * 0.9
        s += line('M%.1f %.1f L%.1f %.1f' % (cx + math.cos(a) * r0, cy + math.sin(a) * r0, cx + math.cos(a) * r1,
                                           cy + math.sin(a) * r1), NAVY, 3.2 if long_ else 2, cap='butt')
    # frost creeping in from the rim
    for a, k in ((200, 1.0), (320, 0.8), (60, 0.7), (140, 0.6)):
        fx, fy = cx + math.cos(math.radians(a)) * r * 0.78, cy + math.sin(math.radians(a)) * r * 0.78
        s += '<path d="%s" fill="%s" opacity="0.7"/>' % (ell_d(fx, fy, r * 0.34 * k, r * 0.2 * k, a + 90), FROST)
        s += line('M%.1f %.1f l%.1f %.1f' % (fx, fy, -math.cos(math.radians(a)) * 7 * k, -math.sin(math.radians(a)) * 7 * k), FROST_HI, 1.0, op=0.9)
    if mood == 'rewind':
        # the hands blurred into backward sweeps
        for rr, op in ((r * 0.72, 0.5), (r * 0.5, 0.7)):
            d = 'M%.1f %.1f A%.1f %.1f 0 1 0 %.1f %.1f' % (cx + rr, cy, rr, rr, cx, cy - rr)
            s += line(d, NAVY_HI, 3, op=op)
        s += '<path d="M%.1f %.1f l6 -4 l-1 7 Z" fill="%s"/>' % (cx + r * 0.72, cy + 2, NAVY)
    else:
        hands = ((-6, 0.8, 3.0), (-0.5, 0.52, 4.2)) if mood != 'spun' else ((130, 0.8, 3.0), (250, 0.52, 4.2))
        for deg, ln, w in hands:
            a = math.radians(deg - 90)
            tip = (cx + math.cos(a) * r * ln, cy + math.sin(a) * r * ln)
            back = (cx - math.cos(a) * r * 0.16, cy - math.sin(a) * r * 0.16)
            s += line('M%.1f %.1f L%.1f %.1f' % (back + tip), NAVY, w)
            s += '<path d="%s" fill="%s"/>' % (ell_d(tip[0] - math.cos(a) * 3, tip[1] - math.sin(a) * 3, w * 0.9, w * 1.6,
                                                     math.degrees(a) + 90), NAVY)
    s += '<circle cx="%.1f" cy="%.1f" r="4" fill="%s" stroke="%s" stroke-width="1.2"/>' % (cx, cy, BRASS, L)
    if crack:
        s += line('M%.1f %.1f l8 10 l-4 9 l10 12 M%.1f %.1f l-6 5' % (cx - 10, cy - r + 4, cx - 2, cy - r + 14), L, 2.2)
        s += line('M%.1f %.1f l8 10 l-4 9 l10 12' % (cx - 9, cy - r + 3), '#ffffff', 0.9, op=0.8)
    s += spec(cx - r * 0.45, cy - r * 0.5, r * 0.22, r * 0.1, rot=-40, op=0.7)
    if mood == 'lit':
        s = radial(ctx, cx, cy, r * 2.2, FACEC, 0.5) + s
    return s


def tickwell(ctx, x, y, s=1.0, pose='frozen'):
    """Master Tickwell, tiny, local to his seat (x, y): frozen (curled round
    his lantern-watch, eyes shut, frost on him) or awake (sitting up,
    blinking, the watch's candle lit)."""
    t = 'translate(%.1f %.1f) scale(%.2f)' % (x, y, s)
    P = []
    frozen = pose == 'frozen'
    # the curled body: coat and apron
    P.append(Part('fill', pth(smooth_d([(-14, 0), (-16, -14), (-10, -24), (4, -26), (14, -18), (16, -4), (10, 2)])),
                  fill=COAT, shade=COAT_SH, off=(-1.4, -1.4), lw=1.2))
    P.append(Part('fill', pth(smooth_d([(-6, -2), (-8, -16), (2, -20), (10, -12), (8, 0)])), fill=APRON, shade=APRON_SH,
                  off=(-1, -1), lw=1.0))
    # the lantern-watch in his arms
    watch_over = '<path d="%s" fill="%s"/>' % (flame_d(4, -8, 4, 7), '#ffd98a' if not frozen else '#cfe8f4')
    P.append(Part('fill', pth(ell_d(4, -12, 6.4, 6.4)), fill=BRASS, shade=BRASS_SH, off=(-1, -1), lw=1.0,
                  over='<circle cx="4" cy="-12" r="4.2" fill="%s"/>' % ('#3a2a20' if not frozen else '#9ab8c8') + watch_over))
    # the head: bald, a white fringe, brass goggles pushed up, a bristly moustache
    hy = -34 if frozen else -38
    face = ''
    if frozen:
        face += line('M-3 %.1f q2 1.6 4 0 M5 %.1f q2 1.6 4 0' % (hy + 1, hy + 0.4), L, 1.3)
    else:
        face += dot(-1.4, hy + 0.4, 1.6, L) + dot(6.6, hy, 1.6, L) + dot(-1.8, hy - 0.2, 0.5, '#ffffff') + dot(6.2, hy - 0.6, 0.5, '#ffffff')
    face += '<path d="M-4 %.1f Q2 %.1f 9 %.1f Q2 %.1f -4 %.1f Z" fill="%s" stroke="%s" stroke-width="0.8"/>' % (
        hy + 4, hy + 2.2, hy + 4, hy + 8, hy + 4, HAIR, L)
    face += '<path d="%s" fill="#e8a0a0" opacity="0.5"/>' % ell_d(-6, hy + 3, 2.2, 1.4)
    gog = ('<circle cx="-1" cy="%.1f" r="3.4" fill="%s" stroke="%s" stroke-width="1"/>' % (hy - 7, LENS, BRASS_DK)
           + '<circle cx="6" cy="%.1f" r="3.4" fill="%s" stroke="%s" stroke-width="1"/>' % (hy - 7.6, LENS, BRASS_DK)
           + line('M-4.4 %.1f L-9 %.1f M9.4 %.1f L12 %.1f' % (hy - 7, hy - 5, hy - 7.6, hy - 6), BRASS_DK, 1.2))
    P.append(Part('fill', pth(ell_d(2, hy, 10, 9.4)), fill=SKIN, shade=SKIN_SH, off=(-1.2, -1.2), lw=1.2,
                  over=face + gog + '<path d="%s" fill="%s"/>' % (ell_d(-8, hy + 1, 3.4, 4.4), HAIR),
                  hl=spec(-2, hy - 5, 2.4, 1.2, rot=-30, op=0.8)))
    P.append(Part('fill', pth(ell_d(-10.4, hy + 3, 2, 2.6)), fill=SKIN, shade=SKIN_SH, off=(-0.4, -0.4), lw=1.0))
    if not frozen:
        # little legs dangling, arms up in surprise
        P.append(Part('limb', pth('M-6 0 L-10 10'), width=3, fill=COAT))
        P.append(Part('limb', pth('M6 0 L10 10'), width=3, fill=COAT))
        P.append(Part('limb', pth('M-12 -18 L-20 -30'), width=3, fill=COAT))
        P.append(Part('limb', pth('M14 -18 L22 -30'), width=3, fill=COAT))
    return place(P, t)
BELL = [(164, 104), (152, 118), (146, 146), (142, 186), (134, 226), (120, 258), (100, 280), (92, 296), (196, 300),
        (300, 296), (292, 280), (272, 258), (258, 226), (250, 186), (246, 146), (240, 118), (228, 104), (196, 98)]

CASE = (62, 138, 64, 104)          # x, y, w, h of the glass case on his back (body-local)

SPRING = (92, 206)                 # the mainspring's centre inside it

TICK = (82, 176)                   # where Tickwell sits in it


def case_parts(ctx, open_=False, spring='dim', tick='frozen'):
    """The frosted glass case on his back, with Tickwell and the mainspring."""
    x, y, w, h = CASE
    P = []
    inner = '<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="%s"/>' % (x + 4, y + 4, w - 8, h - 8, '#2a3a4a')
    # the mainspring: a flat brass spiral
    sx, sy = SPRING
    if spring == 'bright':
        inner += radial(ctx, sx, sy, 34, GOLD, 0.8)
    if spring == 'out':
        # Chimed: the spring has sprung out of the case (popped_spring draws it):
        # only its arbor is left, and its warm light on the case's back
        inner += radial(ctx, sx, sy, 30, GOLD, 0.45)
        inner += '<circle cx="%.1f" cy="%.1f" r="7" fill="%s" stroke="%s" stroke-width="1.6"/>' % (sx, sy, BRASS, L)
        inner += dot(sx, sy, 2.4, L)
    d = 'M%.1f %.1f' % (sx, sy)
    for i in range(1, 60):
        t = i / 59.0
        a = t * 5.2 * math.pi
        rr = 2 + 18 * t
        d += ' L%.2f %.2f' % (sx + math.cos(a) * rr, sy + math.sin(a) * rr * 0.9)
    col = GOLD_HI if spring == 'bright' else BRASS
    if spring == 'bright':
        inner += radial(ctx, sx, sy, 22, GOLD_CORE, 0.95)
        inner += line(d, '#8a5a10', 7) + line(d, GOLD_HI, 4.8) + line(d, GOLD_CORE, 1.8)
    elif spring != 'out':
        inner += line(d, L, 5.2) + line(d, col, 3.2)
    if spring == 'bright':
        inner += star4(sx + 16, sy - 14, 6, '#ffffff', 0.95) + star4(sx - 14, sy + 12, 4, '#ffffff', 0.9)
    P.append(Part('fill', pth(poly_d([(x, y), (x + w, y), (x + w, y + h), (x, y + h)])), fill=BRASS_SH, shade=BRASS_DK,
                  off=(-2, -2), over=inner))
    P += tickwell(ctx, TICK[0], TICK[1] + 6, 0.95, tick)
    # the glass (frosted), or thrown open
    if not open_:
        gl = ('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="%s" opacity="0.55"/>' % (x + 4, y + 4, w - 8, h - 8, GLASS))
        for fx, fy, k in ((x + 10, y + 12, 1.0), (x + w - 12, y + h - 16, 0.8), (x + 14, y + h - 22, 0.7)):
            gl += line('M%.1f %.1f l6 -6 m-6 6 l7 1 m-7 -1 l2 8 m-2 -8 l-6 -3' % (fx, fy), FROST_HI, 1.2 * k, op=0.9)
        gl += '<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="%s" opacity="0.5"/>' % (x + 4, y + h - 22, w - 8, 18, FROST)
        gl += line('M%.1f %.1f L%.1f %.1f' % (x + 10, y + 16, x + 22, y + 8), '#ffffff', 2, op=0.7)
        P.append(Part('fill', pth(poly_d([(x + 4, y + 4), (x + w - 4, y + 4), (x + w - 4, y + h - 4), (x + 4, y + h - 4)])),
                      fill='none', no_shade=True, sil=False, rim=False, lw=0, over=gl))
    # the brass frame: posts, rails and rivets
    fr = ''
    for rx, ry, rw, rh in ((x, y, w, 7), (x, y + h - 7, w, 7), (x, y, 7, h), (x + w - 7, y, 7, h), (x + w / 2 - 2, y, 4, h)):
        fr += '<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="%s" stroke="%s" stroke-width="1.4"/>' % (rx, ry, rw, rh, BRASS, L)
    for rx, ry in ((x + 3.5, y + 3.5), (x + w - 3.5, y + 3.5), (x + 3.5, y + h - 3.5), (x + w - 3.5, y + h - 3.5)):
        fr += dot(rx, ry, 1.8, BRASS_HI)
    if open_ == 'flat':
        pass            # Chimed: its door is drawn swung open in the frame (case_door)
    elif open_:
        # the outer pane thrown open on its top hinge, swung out
        hx, hy = x, y
        pane = [(hx, hy), (hx - 40, hy - 26), (hx - 40 - 6, hy - 26 + 58), (hx - 6, hy + 32)]
        fr += '<path d="%s" fill="%s" opacity="0.45"/>' % (poly_d(pane), GLASS)
        fr += line('M%.1f %.1f L%.1f %.1f' % (pane[0][0] - 12, pane[0][1] + 4, pane[2][0] + 14, pane[2][1] - 16), FROST_HI, 1.6, op=0.8)
        ring = poly_d(pane)
        fr += '<path d="%s" fill="none" stroke="%s" stroke-width="7" stroke-linejoin="round"/>' % (ring, L)
        fr += '<path d="%s" fill="none" stroke="%s" stroke-width="4.4" stroke-linejoin="round"/>' % (ring, BRASS)
        fr += dot(hx, hy, 3, BRASS_HI)
    P.append(Part('fill', pth(poly_d([(x - 1, y - 1), (x + w + 1, y - 1), (x + w + 1, y + 2), (x - 1, y + 2)])),
                  fill=BRASS, no_shade=True, lw=0, sil=False, rim=False, over=fr))
    # frost on the case's top
    P += frost_clump(x + w / 2, y, w * 0.9, 10, seed=2.0, icicles=0)
    return P


def head_parts(ctx, hx, hy, eyes='lit', rot=0.0):
    """His domed head on the bell's crown, local to (hx, hy) (its brim's centre):
    two lamp lenses for eyes, a finial, the winding key out of the back."""
    P = []
    # the winding key, out of the back of his head
    kx0, ky0 = hx - 26, hy - 16
    P.append(tube((kx0, ky0), (kx0 - 24, ky0 - 6), 7, fill=BRASS))
    bow = smooth_d([(kx0 - 24, ky0 - 6), (kx0 - 30, ky0 - 22), (kx0 - 44, ky0 - 20), (kx0 - 42, ky0 - 6),
                    (kx0 - 44, ky0 + 8), (kx0 - 32, ky0 + 10)])
    P.append(brass(bow, over='<path d="%s" fill="%s"/>' % (ell_d(kx0 - 36, ky0 - 13, 4, 4), L)
                   + '<path d="%s" fill="%s"/>' % (ell_d(kx0 - 36, ky0 + 2, 4, 3.6), L)))
    PT = {'key': (kx0 - 36, ky0 - 5)}
    # the dome
    dome = smooth_d([(hx - 34, hy), (hx - 34, hy - 22), (hx - 20, hy - 40), (hx, hy - 46), (hx + 20, hy - 40), (hx + 34, hy - 22),
                     (hx + 34, hy)])
    P.append(brass(dome, off=(-5, -5), hl=spec(hx - 16, hy - 32, 7, 4, rot=-30, op=0.8)))
    P.append(brass(poly_d([(hx - 40, hy - 4), (hx + 40, hy - 4), (hx + 38, hy + 6), (hx - 38, hy + 6)]), fill=BRASS_SH, shade=BRASS_DK,
                   off=(-1, -1), over=''.join(dot(hx + i * 12, hy + 1, 1.6, BRASS_HI) for i in range(-3, 4))))
    P += frost_clump(hx - 8, hy - 40, 34, 9, seed=1.0, icicles=0)
    P.append(ball(hx, hy - 52, 6))
    # the lenses
    fx = ''
    for i, (ex, ey, r) in enumerate(((hx + 2, hy - 20, 11), (hx + 24, hy - 21, 9.4))):
        fx += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s" stroke="%s" stroke-width="2"/>' % (ex, ey, r + 3.2, BRASS_DK, L)
        if eyes in ('lit', 'glare', 'blaze', 'squint'):
            k = 1.5 if eyes == 'blaze' else 1.0
            fx += radial(ctx, ex, ey, r * 2.2 * k, LENS, 0.55)
            fx += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s"/>' % (ex, ey, r, LENS)
            fx += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s"/>' % (ex + 1.4, ey + 0.4, r * 0.48, LENS_CORE)
            fx += dot(ex - r * 0.35, ey - r * 0.4, r * 0.22, '#ffffff')
            if eyes in ('glare', 'squint') and (eyes == 'glare' or i == 1):
                # a brass shutter half down over the lens, angled
                fx += '<path d="M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z" fill="%s" stroke="%s" stroke-width="1.6"/>' % (
                    ex - r - 3, ey - r - 3, ex + r + 3, ey - r - 3, ex + r + 3, ey - r * 0.1 + (3 if i == 0 else -3), ex - r - 3,
                    ey - r * 0.1 - (3 if i == 0 else -3), BRASS, L)
        elif eyes == 'dizzy':
            fx += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s"/>' % (ex, ey, r, '#2a3a4a')
            d = 'M%.1f %.1f' % (ex, ey)
            for j in range(1, 23):
                t = j / 22.0
                a = t * 4.2 * math.pi
                d += ' L%.2f %.2f' % (ex + r * 0.8 * t * math.cos(a), ey + r * 0.8 * t * math.sin(a))
            fx += line(d, LENS, 1.8)
        else:   # dark: the lamps out, a crack
            fx += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s"/>' % (ex, ey, r, '#2a3a4a')
            fx += line('M%.1f %.1f l4 5 l-2 5' % (ex - 2, ey - r + 2), '#9ab8c8', 1.2)
            fx += dot(ex - r * 0.35, ey - r * 0.4, r * 0.18, '#6a8090')
    PT['eye_l'], PT['eye_r'] = (hx + 2, hy - 20), (hx + 24, hy - 21)
    t = 'translate(%.1f %.1f) rotate(%.1f) scale(%.2f) translate(%.1f %.1f)' % (hx, hy, rot, HEAD_K, -hx, -hy)
    PT = {k: rot_pt(hx + (v[0] - hx) * HEAD_K, hy + (v[1] - hy) * HEAD_K, hx, hy, rot) for k, v in PT.items()}
    return place(P, t), gx(fx, t), PT


def bell_parts(ctx, face='frozen', crack=False):
    """The bell body (local, upright): brass with a lip, frost on its shoulders."""
    P = []
    d = smooth_d(BELL)
    over = line('M100 284 Q196 294 292 284', BRASS_DK, 2, op=0.8) + line('M104 276 Q196 286 288 276', BRASS_HI, 2.4, op=0.85)
    over += line('M148 146 Q196 154 244 146', BRASS_DK, 1.6, op=0.7) + line('M150 140 Q196 148 242 140', BRASS_HI, 1.6, op=0.7)
    # rivets round the waist
    over += ''.join(dot(x, y, 1.8, BRASS_HI) + dot(x + 0.5, y + 0.6, 0.9, BRASS_DK) for x, y in
                    ((156, 262), (176, 266), (196, 267), (216, 266), (236, 262)))
    hl = line('M152 124 Q146 170 138 216 Q128 250 106 276', BRASS_HI, 4, op=0.8) + spec(160, 132, 5, 12, rot=10, op=0.6)
    P.append(brass(d, off=(-10, -6), over=over, hl=hl))
    return P


def leg_parts(hip, foot_x, knee_out=0.0, lift=0.0):
    """A stubby piston leg from the hip to a brass boot on the floor at foot_x."""
    fy = GROUND - lift
    knee = ((hip[0] + foot_x) / 2 + knee_out, (hip[1] + fy - 14) / 2 + 4)
    P = [tube(hip, knee, 17, fill=IRON), tube(knee, (foot_x, fy - 16), 15, fill=IRON)]
    P += gear(knee[0], knee[1], 10, 8, rot=15)
    boot = smooth_d([(foot_x - 16, fy), (foot_x - 16, fy - 10), (foot_x - 8, fy - 18), (foot_x + 10, fy - 18), (foot_x + 20, fy - 10),
                     (foot_x + 22, fy)])
    P.append(brass(boot, off=(-2, -2), hl=spec(foot_x - 4, fy - 13, 5, 2, op=0.7)))
    return P


def blade_parts(wrist, ang, length=128):
    """The minute hand for a blade, from its hub at the wrist toward ang degrees."""
    a = math.radians(ang)
    ux, uy = math.cos(a), math.sin(a)
    nx, ny = -uy, ux
    tip = (wrist[0] + ux * length, wrist[1] + uy * length)
    w0, w1 = 7.0, 4.4
    body = [(wrist[0] + nx * w0, wrist[1] + ny * w0),
            (wrist[0] + ux * length * 0.78 + nx * w1, wrist[1] + uy * length * 0.78 + ny * w1),
            (wrist[0] + ux * length * 0.78 + nx * 10, wrist[1] + uy * length * 0.78 + ny * 10),
            tip,
            (wrist[0] + ux * length * 0.78 - nx * 10, wrist[1] + uy * length * 0.78 - ny * 10),
            (wrist[0] + ux * length * 0.78 - nx * w1, wrist[1] + uy * length * 0.78 - ny * w1),
            (wrist[0] - nx * w0, wrist[1] - ny * w0)]
    edge = line('M%.1f %.1f L%.1f %.1f' % (wrist[0] + nx * 3, wrist[1] + ny * 3, tip[0], tip[1]), NAVY_HI, 1.6, op=0.9)
    frost = '<path d="%s" fill="%s" opacity="0.8"/>' % (ell_d(wrist[0] + ux * length * 0.4, wrist[1] + uy * length * 0.4, 12, 3.4,
                                                               math.degrees(a)), FROST)
    P = [Part('fill', pth(poly_d(body)), fill=NAVY, shade='#0e1428', off=(-1.5, -1.5), over=edge + frost)]
    # the counterweight behind the hub
    cw = (wrist[0] - ux * 16, wrist[1] - uy * 16)
    P.append(brass(ell_d(cw[0], cw[1], 9, 9), fill=NAVY, shade='#0e1428'))
    P.append(ball(wrist[0], wrist[1], 8))
    return P, tip


def gear_hand(wrist, ang, cog=False, watch=False):
    """The back hand: a spoked gear-wheel for a palm with three claw fingers
    (holding a cog to toss, or the pocket watch)."""
    a = math.radians(ang)
    ux, uy = math.cos(a), math.sin(a)
    nx, ny = -uy, ux
    c = (wrist[0] + ux * 12, wrist[1] + uy * 12)
    P = []
    for k in (-1, 0, 1):
        b = (c[0] + nx * k * 9 + ux * 8, c[1] + ny * k * 9 + uy * 8)
        fa = a + k * 0.4
        m = (b[0] + math.cos(fa) * 10, b[1] + math.sin(fa) * 10)
        t = (m[0] + math.cos(fa + 0.6) * 8, m[1] + math.sin(fa + 0.6) * 8)
        P.append(Part('limb', pth('M%.1f %.1f L%.1f %.1f L%.1f %.1f' % (b + m + t)), width=4.4, fill=IRON))
    P += gear(c[0], c[1], 14, 9, rot=ang)
    if cog:
        P += gear(c[0] + ux * 22, c[1] + uy * 22, 13, 8, rot=10, fill=BRASS_HI)
    if watch:
        w = (c[0] + ux * 24, c[1] + uy * 24)
        P.append(Part('limb', pth('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (c[0], c[1], c[0] + nx * 12, c[1] + ny * 12 + 10, w[0], w[1])),
                      width=1.6, fill=BRASS_HI))
    return P, c


def frame(name):
    ctx = Ctx('tk' + name[:4])
    fid = 'tinker_' + name
    over, under = '', ''
    eyes = 'lit'
    face = 'frozen'
    crack = False
    case_open = False
    spring = 'dim'
    tick = 'frozen'
    body_rot = 0.0                 # the whole figure turned about PIVOT (the Chimed fall)
    bob = 0.0
    lean = 0.0
    legs = ((162, 150, -4), (232, 246, 4))      # (hip x, foot x, knee out)
    head_rot = 0.0
    # arm poses: (shoulder -> elbow -> wrist), hand angle
    bs, fs = (146, 176), (248, 176)
    back = ((110, 222), (96, 262), 100)          # elbow, wrist, hand angle
    front = ((282, 222), (296, 256), 55)         # elbow, wrist, blade angle
    cog = watch = False
    if name == 'idle':
        pass
    elif name in ('walk1', 'walk2'):
        k = 1 if name == 'walk1' else -1
        legs = ((162, 150 + 22 * k, -4), (232, 246 - 22 * k, 4))
        bob = -4
        lean = 4
        back = ((112 - 10 * k, 222), (100 - 14 * k, 260), 100)
        front = ((280 + 6 * k, 220), (292 + 8 * k, 256), 58)
        over += motion('M60 330 L40 330 M66 346 L46 348', 1.8, 0.7)
    elif name == 'toss':
        lean = -8
        back = ((110, 140), (136, 104), -60)
        cog = True
        eyes = 'squint'
        over += motion('M150 80 L160 64 M170 76 L186 64 M104 160 L90 150', 2)
        over += star4(150, 76, 7, '#ffffff', 0.95)
    elif name == 'swing':
        lean = -10
        front = ((276, 136), (250, 112), -135)
        eyes = 'glare'
        head_rot = -4
        over += motion('M300 110 L318 96 M306 136 L328 128', 2.2)
    elif name == 'watch':
        back = ((150, 124), (188, 86), -50)
        watch = True
        face = 'lit'
        eyes = 'glare'
    elif name == 'chimed':
        # flat on his front (FALL), the head to the right: local +x (his front) is
        # world down, local +y (toward his feet) is world left
        body_rot = FALL
        case_open = 'flat'
        spring = 'out'
        eyes = 'dizzy'
        face = 'spun'
        back = ((150, 238), (156, 276), 90)      # tucked behind the bell
        front = ((288, 212), (292, 248), 88)     # the blade lying along the floor toward his feet
        legs = ((162, 138, -10), (232, 226, -6))
    elif name == 'rewind':
        lean = -14
        back = ((104, 150), (80, 116), -130)
        front = ((286, 176), (298, 214), 62)
        face = 'rewind'
        eyes = 'glare'
        over += rewind_fx(ctx)
    elif name == 'overwind':
        back = ((100, 150), (70, 128), -150)
        front = ((292, 150), (316, 136), -80)
        face = 'spun'
        crack = True
        eyes = 'blaze'
        head_rot = -6
    else:   # die
        case_open = True
        tick = 'awake'
        eyes = 'dark'
        crack = True
        face = 'spun'
        bob = 44
        legs = ((162, 120, 0), (232, 290, 0))
        back = ((112, 236), (100, 274), 120)
        front = ((270, 262), (240, 322), 8)
        head_rot = 14
    # ---- assemble, upright and body-local
    P = []
    hips = [(x + lean * 0.2, 294 + bob) for x, _, _ in legs]
    for (hx, fxx, ko), hip in zip(legs, hips):
        if name == 'chimed':
            P += leg_parts(hip, fxx, ko, lift=36)
        elif name == 'die':
            P += sat_leg(hip, fxx)
        else:
            P += leg_parts(hip, fxx + lean * 0.1, ko)

    def B(p):
        """body point after the lean and bob (upper body shifts by lean at the head)."""
        t = max(0.0, (300 - p[1]) / 200.0)
        return (p[0] + lean * t, p[1] + bob)
    # back arm (behind the bell)
    bsp = B(bs)
    el, wr, ha = back
    arm_back = [tube(bsp, el, 13, fill=BRASS_SH), tube(el, wr, 12, fill=BRASS_SH), ball(el[0], el[1], 8, frost=True)]
    hand_parts, hand_c = gear_hand(wr, ha, cog, watch)
    arm_back += hand_parts
    # the case, the bell, the frost, the head
    cparts = case_parts(ctx, case_open, spring, tick)
    bparts = bell_parts(ctx)
    frost = frost_clump(158, 162, 40, 14, 0.4, 2) + frost_clump(236, 162, 40, 14, 2.2, 2)
    hx, hy = B((196, 104))
    head, head_fx, hpts = head_parts(ctx, hx, hy, eyes, head_rot)
    # front arm and the blade
    fsp = B(fs)
    el, wr, ba = front
    blade, tip = blade_parts(wr, ba)
    arm_front = [tube(fsp, el, 14), tube(el, wr, 13), ball(el[0], el[1], 9, frost=True), ball(fsp[0], fsp[1], 11, frost=True)]
    shoulder_b = ball(bsp[0], bsp[1], 11, frost=True)
    # the lean moves the bell too: shear it through place()
    shear = 'translate(0 %.1f) matrix(1 0 %.4f 1 %.4f 0)' % (bob, -lean / 200.0, lean * 300 / 200.0)
    upper = place(cparts + [shoulder_b] + bparts + frost, shear)
    chest = gx(chest_face(ctx, 198, 206, 38, face, crack), shear)
    parts = [x for x in P] + arm_back + upper + head + blade + arm_front
    body_over = chest + head_fx
    if name == 'watch':
        # the pocket watch held up high, its face lit and ticking
        wx, wy = hand_c[0] + math.cos(math.radians(-50)) * 26, hand_c[1] + math.sin(math.radians(-50)) * 26
        parts.append(brass(ell_d(wx, wy, 17, 17), over=dot(wx, wy - 21, 4, BRASS)))
        body_over += radial(ctx, wx, wy, 44, FACEC, 0.7)
        body_over += '<circle cx="%.1f" cy="%.1f" r="12.5" fill="%s" stroke="%s" stroke-width="1.6"/>' % (wx, wy, '#ffffff', L)
        for i in range(12):
            a = math.radians(i * 30)
            body_over += line('M%.1f %.1f L%.1f %.1f' % (wx + math.cos(a) * 9, wy + math.sin(a) * 9, wx + math.cos(a) * 11.4,
                                                       wy + math.sin(a) * 11.4), NAVY, 1.4, cap='butt')
        body_over += line('M%.1f %.1f L%.1f %.1f M%.1f %.1f L%.1f %.1f' % (wx, wy, wx - 1, wy - 9, wx, wy, wx + 6, wy + 2), NAVY, 2)
        body_over += '<path d="M%.1f %.1f Q%.1f %.1f %.1f %.1f" fill="none" stroke="%s" stroke-width="1.6"/>' % (
            wx, wy - 24, wx - 16, wy - 40, hand_c[0], hand_c[1], BRASS_HI)
        over += motion('M%.1f %.1f l-10 -8 M%.1f %.1f l12 -6 M%.1f %.1f l14 4' % (wx - 22, wy - 12, wx + 22, wy - 14, wx + 24, wy + 6), 1.8)
        hand_c = (wx, wy)
    if name == 'overwind':
        body_over += springs_fx(ctx)
    if name == 'die':
        over += debris_fx(ctx)
    # ---- the fall: everything turned FALL degrees and set down along the floor,
    # front down, the head to the right and the case on top
    def W(p):
        if body_rot:
            c, s_ = math.cos(math.radians(body_rot)), math.sin(math.radians(body_rot))
            return (FALL_T[0] + p[0] * c - p[1] * s_, FALL_T[1] + p[0] * s_ + p[1] * c)
        return p

    def S(p):   # a point on the sheared upper body
        return (p[0] + lean * (300 - p[1]) / 200.0, p[1] + bob)
    if body_rot:
        t = 'translate(%.1f %.1f) rotate(%.1f)' % (FALL_T[0], FALL_T[1], body_rot)
        body_svg = gx(paint(ctx, parts, PAL) + body_over, t)
        over += case_door(ctx, W(S((CASE[0], CASE[1] + CASE[3]))), W(S((CASE[0] + CASE[2], CASE[1] + CASE[3]))))
        over += chimed_fx(ctx) + popped_spring(ctx, W(S(SPRING)))
    else:
        body_svg = paint(ctx, parts, PAL) + body_over
    body_svg_all = under + body_svg + over
    text = svg(ctx, body_svg_all, 384, 384)
    # ---- points (in the frame, after the fall)
    sp = W(S(SPRING))
    if body_rot:
        sp = COIL[:2]
        sbox = (COIL[0] - COIL[2] - 2, COIL[1] - COIL[2] - 2, COIL[2] * 2 + 4, GROUND - (COIL[1] - COIL[2] - 2))
    else:
        sbox = (sp[0] - 22, sp[1] - 22, 44, 44)
    cs = S((CASE[0] + CASE[2] / 2.0, CASE[1] + CASE[3] / 2.0))
    fc = S((198, 206))
    box = body_box(name, legs, lean, bob)
    PTS.mark(fid, spring=sp, spring_box=sbox, face=W(fc), key=W(hpts['key']), hand_l=W(hand_c), hand_r=W(wr), case=W(cs),
             blade_tip=W(tip), eye_l=W(hpts['eye_l']), eye_r=W(hpts['eye_r']),
             body=box if not body_rot else chimed_box(W))
    return text


def body_box(name, legs, lean, bob):
    """His box standing (frame units): the bell and head, not the blade."""
    top = 48 + bob
    return (92 + min(0, lean), top, 212 + abs(lean), GROUND - top)


def chimed_box(W):
    """Chimed: he lies along the floor, front down: the fallen bell and head
    (not the case on his back, the legs or the blade)."""
    pts = [W(p) for p in BELL] + [W((196, 50))]
    x0 = min(p[0] for p in pts)
    x1 = max(p[0] for p in pts)
    y0 = min(p[1] for p in pts)
    return (x0, y0, x1 - x0, GROUND - y0)


def case_door(ctx, a, b):
    """Chimed: the case's glass door flung open on its hinge (a..b, the case's
    edge nearest his feet), swung out toward us and back over his skirt."""
    ax, ay = a
    bx, by = b
    ln = math.hypot(bx - ax, by - ay)
    # swung out: the free edge up and back toward his feet, foreshortened
    fx, fy = -0.62 * ln, -0.22 * ln
    pane = [(ax, ay), (ax + fx, ay + fy), (bx + fx * 0.9, by + fy * 0.9), (bx, by)]
    ring = poly_d(pane)
    s = '<path d="%s" fill="%s" opacity="0.55"/>' % (ring, GLASS)
    for k in (0.3, 0.6):
        x0, y0 = ax + (bx - ax) * k, ay + (by - ay) * k
        s += line('M%.1f %.1f l%.1f %.1f' % (x0 + fx * 0.2, y0 + fy * 0.2, fx * 0.5, fy * 0.5), FROST_HI, 1.6, op=0.8)
    s += '<path d="%s" fill="%s" opacity="0.5"/>' % (poly_d([(ax + fx * 0.1, ay + fy * 0.1), (ax + fx * 0.9, ay + fy * 0.9),
                                                             (ax + fx * 0.9 + (bx - ax) * 0.25, ay + fy * 0.9 + (by - ay) * 0.25),
                                                             (ax + fx * 0.1 + (bx - ax) * 0.25, ay + fy * 0.1 + (by - ay) * 0.25)]), FROST)
    s += '<path d="%s" fill="none" stroke="%s" stroke-width="7" stroke-linejoin="round"/>' % (ring, L)
    s += '<path d="%s" fill="none" stroke="%s" stroke-width="4.4" stroke-linejoin="round"/>' % (ring, BRASS)
    s += dot(ax, ay, 3, BRASS_HI) + dot(bx, by, 3, BRASS_HI)
    return s


def popped_spring(ctx, arbor, coil=COIL):
    """Chimed: the mainspring sprung out of the open case on his back: a gold
    strip from its arbor looping down in front of him to a loose coil that
    stands on the floor (the window's target, low enough for a standing
    slash, a stomp and a floor wave)."""
    cx, cy, R = coil
    s = radial(ctx, cx, cy - R * 0.3, R * 2.1, GOLD, 0.6, squash=0.62)
    # a dark iron backing so the gold reads against his brass
    s += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s" stroke="%s" stroke-width="2.4"/>' % (cx, cy, R + 3, '#241808', L)
    s += radial(ctx, cx, cy, R * 0.9, GOLD_CORE, 0.55)
    # the coil: three turns from the centre out, its outer end at the top
    turns = 2.6
    d = ''
    n = 90
    for i in range(n + 1):
        t = i / float(n)
        a = -math.pi / 2 + (t - 1.0) * turns * 2 * math.pi
        r = 5 + (R - 5) * t
        d += ('M' if i == 0 else ' L') + '%.2f %.2f' % (cx + math.cos(a) * r, cy + math.sin(a) * r)
    # the strip: up from the coil's top, one springy loop, into the case's arbor
    top = (cx, cy - R)
    ax, ay = arbor
    # (round the right of his chest face, so the face still reads)
    d += ' C%.1f %.1f %.1f %.1f %.1f %.1f' % (cx + 30, top[1] - 6, cx + 50, top[1] - 60, cx + 30, top[1] - 96)
    d += ' S%.1f %.1f %.1f %.1f' % (ax + 18, ay - 2, ax, ay)
    s += line(d, L, 8.4) + line(d, '#8a5a10', 6.4) + line(d, GOLD_HI, 4.2) + line(d, GOLD_CORE, 1.4)
    s += '<circle cx="%.1f" cy="%.1f" r="5" fill="%s" stroke="%s" stroke-width="1.4"/>' % (cx, cy, GOLD_HI, L)
    s += star4(cx + R * 0.6, cy - R * 0.7, 7, '#ffffff', 0.95) + star4(cx - R * 0.75, cy + R * 0.35, 5, '#ffffff', 0.9)
    s += star4(cx + R * 0.95, cy + R * 0.5, 4, '#ffffff', 0.85)
    return s


def sat_leg(hip, foot_x):
    """die: a leg stuck out along the floor, sitting."""
    fy = GROUND
    knee = ((hip[0] + foot_x) / 2, fy - 18)
    P = [tube(hip, knee, 17, fill=IRON), tube(knee, (foot_x, fy - 12), 15, fill=IRON)]
    P += gear(knee[0], knee[1], 10, 8, rot=15)
    P.append(brass(smooth_d([(foot_x - 12, fy), (foot_x - 12, fy - 22), (foot_x - 4, fy - 26), (foot_x + 6, fy - 20), (foot_x + 8, fy)]),
                   off=(-2, -2)))
    return P


def rewind_fx(ctx):
    """Backward-running motion: counter-clockwise arcs round him, in pale ice."""
    s = ''
    for cx, cy, r, a0, a1 in ((196, 190, 150, 200, 320), (196, 190, 128, 20, 140)):
        x0, y0 = cx + r * math.cos(math.radians(a1)), cy + r * math.sin(math.radians(a1))
        x1, y1 = cx + r * math.cos(math.radians(a0)), cy + r * math.sin(math.radians(a0))
        d = 'M%.1f %.1f A%.1f %.1f 0 0 0 %.1f %.1f' % (x0, y0, r, r, x1, y1)
        s += line(d, '#0c1420', 5, op=0.5) + line(d, '#b8e0f4', 2.4, op=0.85)
        s += '<path d="M%.1f %.1f l-2 -9 l8 5 Z" fill="#b8e0f4"/>' % (x1, y1)
    return s


def springs_fx(ctx):
    """Overwound: coil springs bursting out of his seams, and steam."""
    s = ''
    for x, y, a in ((150, 150, -140), (246, 146, -40), (120, 250, 190), (276, 250, -10), (196, 102, -90)):
        d = 'M%.1f %.1f' % (x, y)
        ux, uy = math.cos(math.radians(a)), math.sin(math.radians(a))
        nx, ny = -uy, ux
        for i in range(1, 25):
            t = i / 24.0
            w = math.sin(t * 6 * math.pi) * 6
            d += ' L%.1f %.1f' % (x + ux * 36 * t + nx * w, y + uy * 36 * t + ny * w)
        s += line(d, L, 4.4) + line(d, BRASS_HI, 2.4)
    for x, y, r in ((130, 120, 10), (262, 116, 9), (112, 136, 7), (282, 132, 6)):
        s += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="#e8eef4" opacity="0.8" stroke="%s" stroke-width="1.2"/>' % (x, y, r, L)
    return s


def debris_fx(ctx):
    s = ''
    for x, y, r in ((70, 360, 9), (318, 358, 8), (344, 362, 6), (48, 364, 6)):
        s += '<path d="%s" fill="%s" stroke="%s" stroke-width="1.4"/>' % (gear_d(x, y, r, 7), BRASS, L)
    for x, y in ((120, 350), (300, 340), (240, 356)):
        s += '<path d="M%.1f %.1f l6 -4 l5 5 l-7 3 Z" fill="%s" stroke="%s" stroke-width="1.2"/>' % (x, y, FROST, L)
    return s


def chimed_fx(ctx):
    """Chimed: the hour's gold chime still ringing round the open case."""
    s = ''
    for x, y in ((150, 150), (218, 136), (120, 196)):
        s += star4(x, y, 7, '#ffffff', 0.9)
    s += motion('M60 300 L40 296 M64 318 L40 318', 1.8, 0.7)
    return s


# ================================================================ vendored from boss4.py (A4): end


# ================================================================ drawing with the fight's parts

THIS = sys.modules[__name__]
EYES = 'bfe8ff'          # the lamp-lens eye-lights


def figure():
    """The Tinker for the figure frame: {defs, body, eyes: [l, r], watch}
    (figure units)."""
    def draw(M):
        text = M.frame('idle')
        pts = M.PTS.d['tinker_idle']
        defs, body, _ = _RM.split_doc(text)
        # Tickwell's watch in the case (case_parts seats him at TICK, 0.95 of his
        # size; tickwell() holds the watch at (4, -12)); idle has no lean
        watch = (M.TICK[0] + 4 * 0.95, M.TICK[1] + 6 - 12 * 0.95)
        return {'defs': defs, 'body': _RM.placed(body, M.FOOT),
                'eyes': [_RM.to_fig(pts['eye_l'], M.FOOT), _RM.to_fig(pts['eye_r'], M.FOOT)],
                'watch': _RM.to_fig(watch, M.FOOT)}
    return _RM.attempt('boss4', THIS, draw)


PORTRAIT_K = 0.64
BUST = (196.0, 146.0)          # the point of the upright body put at the portrait's middle


def portrait(ctx, mood, lw):
    """His head and chest from the fight (head_parts, bell_parts, the frost,
    chest_face and the case's edge), mirrored to face left, in native
    portrait units (144 box). Returns svg."""
    def draw(M):
        wrath = mood == 'wrath'
        k = PORTRAIT_K
        t = 'translate(72 74) scale(%.3f %.3f) translate(%.2f %.2f)' % (-k, k, -BUST[0], -BUST[1])
        case = M.case_parts(ctx)
        shoulder_b = M.ball(146, 176, 11, frost=True)
        bell = M.bell_parts(ctx)
        frost = M.frost_clump(158, 162, 40, 14, 0.4, 2) + M.frost_clump(236, 162, 40, 14, 2.2, 2)
        head, head_fx, _ = M.head_parts(ctx, 196, 104, 'glare' if wrath else 'lit', -4 if wrath else 0)
        shoulder_f = M.ball(248, 176, 11, frost=True)
        with weights(tuple(w / k for w in lw)):
            art = paint(ctx, place(case + [shoulder_b] + bell + frost + head + [shoulder_f], t), M.PAL)
        chest = M.chest_face(ctx, 198, 206, 38, 'spun' if wrath else 'frozen', wrath)
        return art + gx(chest + head_fx, t)
    return _RM.attempt('boss4', THIS, draw)


# ================================================================ Master Tickwell (the story's)

def P(d, fill, shade, off=(-3, -3), **kw):
    return Part('fill', pth(d), fill=fill, shade=shade, off=off, **kw)


def LIMB(d, fill, width, **kw):
    return Part('limb', pth(d), fill=fill, width=width, **kw)


def tickwell_face(ctx, cx, cy, k=1.0, mood='dazed', lw=1.0):
    """Tickwell's face at (cx, cy): bald, a white fringe, round old cheeks, a
    bristly white moustache, brass magnifier goggles pushed up on his brow
    (askew when dazed); dazed: eyes wide and blinking, the moustache
    drooping; kind: a warm crinkled smile, the moustache lifted."""
    s = ''
    dazed = mood == 'dazed'
    ex1, ex2, ey = cx - 8 * k, cx + 11 * k, cy
    s += kit.blush(ex1 - 3 * k, cy + 9 * k, dict(blush='#f09080'), 5.6 * k, 3.2 * k, lines=False, op=0.6)
    s += kit.blush(ex2 + 3 * k, cy + 8.6 * k, dict(blush='#f09080'), 4.6 * k, 3 * k, lines=False, op=0.6)
    if dazed:
        for x, r in ((ex1, 5.2), (ex2, 4.6)):
            s += '<path d="%s" fill="#ffffff" stroke="%s" stroke-width="%.2f"/>' % (ell_d(x, ey, r * k, r * 1.1 * k), L, 1.4 * k * lw)
            s += dot(x + 0.6 * k, ey + 0.4 * k, r * 0.46 * k, '#2a1a10') + dot(x - 0.4 * k, ey - 0.8 * k, r * 0.16 * k, '#ffffff')
        # blink marks
        s += line('M%.2f %.2f l%.2f %.2f M%.2f %.2f l%.2f %.2f' % (ex2 + 7 * k, ey - 6 * k, 3 * k, -2 * k, ex2 + 8 * k, ey - 1 * k, 3.4 * k, 0),
                  L, 1.0 * k * lw)
    else:
        for x, w in ((ex1, 8), (ex2, 7)):
            s += line('M%.2f %.2f Q%.2f %.2f %.2f %.2f' % (x - w / 2 * k, ey + 1.2 * k, x, ey - 3.4 * k, x + w / 2 * k, ey + 1.2 * k), L, 2.0 * k * lw)
            s += line('M%.2f %.2f l%.2f %.2f' % (x + w / 2 * k + 0.6 * k, ey + 1 * k, 2 * k, 1.6 * k), L, 0.9 * k * lw, op=0.7)
    # a round nose
    s += '<path d="%s" fill="%s"/>' % (ell_d(cx + 3 * k, cy + 6.4 * k, 3.4 * k, 2.8 * k), SKIN_SH)
    s += dot(cx + 2 * k, cy + 5.4 * k, 0.9 * k, '#ffffff', 0.8)
    # the bristly white moustache (lifted or drooping)
    lift = -2.0 if not dazed else 2.4
    m = ('M%.2f %.2f C%.2f %.2f %.2f %.2f %.2f %.2f C%.2f %.2f %.2f %.2f %.2f %.2f C%.2f %.2f %.2f %.2f %.2f %.2f Z') % (
        cx - 8 * k, cy + 11 * k + lift * k, cx - 4 * k, cy + 7 * k, cx + 1 * k, cy + 8 * k, cx + 3 * k, cy + 9 * k,
        cx + 5 * k, cy + 8 * k, cx + 11 * k, cy + 7 * k, cx + 14 * k, cy + 11 * k + lift * k,
        cx + 8 * k, cy + 13 * k, cx - 2 * k, cy + 13 * k, cx - 8 * k, cy + 11 * k + lift * k)
    bristle = ''.join(line('M%.2f %.2f l%.2f %.2f' % (cx + dx * k, cy + 11.6 * k, 0.4 * k, 1.8 * k), '#c8c8d0', 0.7 * k) for dx in (-4, -1, 2, 5, 8, 11))
    s += '<path d="%s" fill="%s" stroke="%s" stroke-width="%.2f"/>' % (m, HAIR, L, 1.1 * k * lw) + bristle
    if not dazed:
        s += line('M%.2f %.2f Q%.2f %.2f %.2f %.2f' % (cx - 1 * k, cy + 14.4 * k, cx + 3 * k, cy + 16.4 * k, cx + 7 * k, cy + 14.4 * k), L, 1.3 * k * lw)
    else:
        s += '<path d="%s" fill="%s"/>' % (ell_d(cx + 3 * k, cy + 16 * k, 2.2 * k, 2.6 * k), L)
    return s


def goggles(cx, cy, k=1.0, tilt=0.0):
    """Brass magnifier goggles pushed up on the brow (the fight's lens blue)."""
    t = 'rotate(%.1f %.2f %.2f)' % (tilt, cx, cy)
    s = line('M%.2f %.2f Q%.2f %.2f %.2f %.2f' % (cx - 22 * k, cy + 4 * k, cx, cy - 4 * k, cx + 24 * k, cy + 4 * k), APRON_SH, 2.6 * k)
    for dx, r in ((-7, 6.2), (8, 6.8)):
        s += '<path d="%s" fill="%s" stroke="%s" stroke-width="%.2f"/>' % (ell_d(cx + dx * k, cy, r * k, r * k), LENS, BRASS, 2.4 * k)
        s += '<path d="%s" fill="none" stroke="%s" stroke-width="%.2f"/>' % (ell_d(cx + dx * k, cy, r * 1.18 * k, r * 1.18 * k), L, 0.8 * k)
        s += line('M%.2f %.2f q%.2f %.2f %.2f %.2f' % (cx + (dx - 3) * k, cy - 2 * k, 1.4 * k, -2 * k, 4 * k, -2.4 * k), '#ffffff', 1.0 * k)
    return gx(s, t) if tilt else s


def lantern_watch(cx, cy, k=1.0):
    """The round lantern-watch: a brass case with a ring, a candle inside its
    glass (the engine lights its flame). Returns (parts, flame base)."""
    parts = [LIMB('M%.2f %.2f L%.2f %.2f' % (cx, cy - 10 * k, cx, cy - 14 * k), BRASS, 1.6 * k)]
    over = '<path d="%s" fill="#fff4d0"/>' % ell_d(cx, cy, 7 * k, 7 * k)
    over += '<rect x="%.2f" y="%.2f" width="%.2f" height="%.2f" fill="#f4ecd8" stroke="%s" stroke-width="%.2f"/>' % (
        cx - 1.8 * k, cy - 1 * k, 3.6 * k, 6 * k, L, 0.5 * k)
    for i in range(12):
        a = math.radians(i * 30)
        over += dot(cx + math.cos(a) * 8.3 * k, cy + math.sin(a) * 8.3 * k, 0.5 * k, L)
    parts.append(Part('fill', pth(ell_d(cx, cy, 9.4 * k, 9.4 * k)), fill=BRASS, shade=BRASS_SH, off=(-1.2 * k, -1.2 * k), over=over,
                      under='<path d="%s" fill="none" stroke="%s" stroke-width="%.2f"/>' % (ell_d(cx, cy - 12.6 * k, 3 * k, 3 * k), BRASS, 1.6 * k)))
    return parts, (cx, cy - 1.4 * k)
