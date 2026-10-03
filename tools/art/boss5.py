"""World 5's boss: the Prism Saint (boss id saint).

Tessel's glass image, filled with the stolen flame's cold, split light: a
tall floating saint of stained-glass panes in dark lead cames, drained to
cold whites and pale lilac. A pointed lancet hood frames a glass-oval mask
whose eyes are closed; a gown of glass tapers to a point (she has no feet);
her hands cup a floating prism. In her heart one clear pane shows a small
girl with a candle on her head: Tessel (the prism is always held below it,
so she is never covered). Her halo of prism rays is a
separate part (saint_halo) that turns slowly and spins up to attack.

Frames: viewBox 0 0 256 256 at 512 px (2 units = 1 world px), facing right,
anchor (128, 244): the point of her gown (she floats: put the anchor where
she hovers). She is about 238 units (119 px) from the top of her hood to
the gown's point and 142 wide; with her halo behind her head (saint_halo,
its solid rose 180 units across, its ray tips 236, centred on halo_center)
she and it stand about 90 x 138 px. The engine draws her at DRAW_SCALE (1.15: points' _draw_scale), where
she alone is 82 x 137 px and with the halo 104 x 159 px, over the 96 x 128 px
every boss must read at.

  saint_idle       floating, serene, eyes closed, the prism in her cupped hands
  saint_charge     Judgement Beam tell: the prism raised to her mask, light gathering
  saint_beam       the beam: eyes still closed, mouth open, the prism thrust forward
                   (the beam itself is drawn in glow, from mask)
  saint_rose       Rose of Blades tell: arms spread wide (the halo spins up: the part)
  saint_sing       Stained Choir / Gale Hymn: face raised, singing, colours flaring
  saint_refracted  the window: cracked, bowed and dazed, the prism dropped; low hover
  saint_hurt       a glassy recoil, chips flying
  saint_split      Scattered Dawn: bursting apart into three prism shards
  saint_die        lit from behind: every pane warm in every colour, Tessel shining

Parts: saint_halo (256: the rose-window halo, centred at (128, 128): put it
on halo_center), halo_shard (64 x 32: one white lancet blade pointing
right; modulate it to the panes' colours and turn it to its flight),
saint_shard_red / _gold / _blue (128: the three prism shards of Scattered
Dawn, centre (64, 64)). Props: mirror_shard and mirror_shard_dim (64 x 128:
a 16 x 56 px mirror pane with bright rims, centred at (32, 64); the dim one
for the 6 s after it reflects).

points_saint.json (frame units; world offset = (p - anchor) / 2 px): per
frame mask (the face: where the beam and the aim line start), halo_center,
prism, heart (Tessel's pane) and body (her box [x, y, w, h]); plus the
parts' and props' points.
Run on its own: python3 tools/art/boss5.py [--check]
"""
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from kit import Part, pth
from common import Ctx, RIM, svg, paint, line, spec, star4, gx, flame_d
from boss import place, rot_pt, ell_d
from boss3 import (Points, bez, smooth_d, poly_d, radial, motion, check_art, ensure_imports, run_main, open_d, ribbon, along)

# ================================================================ the palette

L = '#221c30'                                    # lead
GLASS = ['#f2eff8', '#d8cfee', '#bfb0e0', '#eae6f4', '#cbbfe6', '#f8f6fc', '#c6b8e2']   # cold whites and lilac
GLASS_SH = '#aea2cc'
MASK, MASK_SH = '#f6f2fc', '#d6ceea'
PRISM_W = '#f8f0ff'                              # W5's tell accent: the prism and the beam's light only
RAY = ['#e05a6a', '#f0b040', '#5ac06a', '#5a8ae8', '#a070e0']   # dispersion on the prism's edge (never a meaning)
WARM = ['#e8506a', '#f0a830', '#4aa86a', '#3a6ac8', '#e8c050', '#c860a0', '#f08040']      # die: lit in every colour
TESSEL_BG, TESSEL_GIRL = '#fff4d8', '#6a4a3a'
FLAME, FLAME_CORE = '#f2b84b', '#fff2c8'
PAL = dict(line=L, rim=RIM, base=GLASS[0], shade=GLASS_SH)

FOOT = (128, 244)
HEART, HEART_R = (128, 112), 13.0     # Tessel's pane in her bodice (the cupped prism is held below it)
DRAW_SCALE = 1.15                    # the engine draws her (frames, halo, shards) this much over 1:1: see points' _draw_scale
FRAMES = ['idle', 'charge', 'beam', 'rose', 'sing', 'refracted', 'hurt', 'split', 'die']
PARTS = {'saint_halo': (256, 256), 'halo_shard': (64, 32), 'saint_shard_red': (128, 128), 'saint_shard_gold': (128, 128),
         'saint_shard_blue': (128, 128), 'mirror_shard': (64, 128), 'mirror_shard_dim': (64, 128)}
BUDGET_MB = 14

PTS = Points()


# ================================================================ glass

def panes(ctx, outline_d, cells, colors, lead=1.6, seed=0, alpha=1.0):
    """Stained glass: the cells (polygons) filled from colors and leaded,
    clipped to outline_d."""
    cid = ctx.clip('<path d="%s"/>' % outline_d)
    s = '<g clip-path="%s">' % cid
    for i, c in enumerate(cells):
        col = colors[(i * 5 + seed) % len(colors)]
        s += '<path d="%s" fill="%s"%s/>' % (poly_d(c), col, '' if alpha >= 1 else ' opacity="%.2f"' % alpha)
        # a glassy sheen in the cell's upper left
        cx = sum(p[0] for p in c) / len(c)
        cy = sum(p[1] for p in c) / len(c)
        s += '<path d="%s" fill="#ffffff" opacity="0.28"/>' % ell_d(cx - 2, cy - 3, 3.2, 1.6, -30)
    for c in cells:
        s += '<path d="%s" fill="none" stroke="%s" stroke-width="%.1f" stroke-linejoin="round"/>' % (poly_d(c), L, lead)
    s += '</g>'
    return s


def grid_cells(x0, x1, ys, cols, bend=0.0, tip=None):
    """Cells between horizontal bands ys (each band's left and right edge from
    the functions x0(y), x1(y)), split into cols columns; tip closes the last
    band into a point."""
    cells = []
    for j in range(len(ys) - 1):
        ya, yb = ys[j], ys[j + 1]
        n = cols[j] if isinstance(cols, (list, tuple)) else cols
        for i in range(n):
            ta, tb = i / float(n), (i + 1) / float(n)
            def X(y, t):
                return x0(y) + (x1(y) - x0(y)) * t
            wob = bend * math.sin(i * 1.7 + j * 2.3)
            cells.append([(X(ya, ta), ya + wob), (X(ya, tb), ya - wob), (X(yb, tb), yb + wob), (X(yb, ta), yb - wob)])
    return cells


# ---------------------------------------------------------------- her shapes (facing right; nearly frontal)

def gown_pts(sway=0.0, flare=1.0):
    """The gown: a slim waist (y 124) flaring over the hips and tapering in a
    long curve to its point (128, 242), the point swaying by sway."""
    f = flare
    R = [(148, 124), (150 + 12 * f, 146), (150 + 22 * f, 172), (148 + 20 * f, 198), (140 + 12 * f, 220), (134, 236)]
    Lf = [(128 - (x - 128), y) for x, y in R]
    def sw(p):
        t = max(0.0, (p[1] - 124) / 118.0)
        return (p[0] + sway * t * t, p[1])
    return [sw(p) for p in R] + [sw((129, 244))] + [sw(p) for p in Lf[::-1]]


def mantle_d(sway=0.0, flare=1.0):
    """Her mantle: from the hood's hem it falls wide over her shoulders to a
    scalloped hem at mid-gown (behind the gown, which shows down its middle)."""
    f = flare
    pts = [(104, 92), (152, 92), (170, 110), (180 + 8 * f, 150), (188 + 8 * f, 188), (182 + 6 * f, 202), (170 + 4 * f, 196),
           (160 + 2 * f, 206), (148, 198), (108, 198), (96 - 2 * f, 206), (86 - 4 * f, 196), (74 - 6 * f, 202), (68 - 8 * f, 188),
           (76 - 8 * f, 150), (86, 110)]
    return smooth_d([(x + sway * max(0.0, (y - 120) / 118.0) ** 2, y) for x, y in pts])


def gown_d(sway=0.0, flare=1.0):
    return smooth_d(gown_pts(sway, flare))


def quarries(x0, y0, x1, y1, step=17.0):
    """Diamond quarries (the leaded glass lattice) covering a box."""
    cells = []
    h = step * 1.25
    j = 0
    y = y0 - h
    while y < y1 + h:
        off = (step / 2.0) if j % 2 else 0.0
        x = x0 - step + off
        while x < x1 + step:
            cx, cy = x, y
            cells.append([(cx, cy - h / 2), (cx + step / 2, cy), (cx, cy + h / 2), (cx - step / 2, cy)])
            x += step
        y += h / 2
        j += 1
    return cells


def gown_cells(sway=0.0, flare=1.0):
    return quarries(70, 118, 190, 250, 23.0)


HOOD = [(128, 12), (144, 24), (156, 44), (160, 68), (162, 88), (176, 106), (152, 104), (140, 97), (128, 93), (116, 97), (104, 104),
        (80, 106), (94, 88), (96, 68), (100, 44), (112, 24)]      # its hem arches up at the chest: Tessel's pane shows below


def hood_cells():
    """A lancet window: tall panes between mullions, a band across the brow."""
    cols = [70, 100, 114, 128, 142, 156, 186]
    cells = []
    for i in range(len(cols) - 1):
        for ya, yb in ((0, 40), (40, 72), (72, 112)):
            cells.append([(cols[i], ya), (cols[i + 1], ya), (cols[i + 1], yb), (cols[i], yb)])
    return cells


def bodice_d():
    return smooth_d([(106, 92), (150, 92), (154, 108), (150, 128), (106, 128), (102, 108)])


def tessel_pane(ctx, cx, cy, r, lit=False):
    """The clear pane in her heart: a small girl with a candle on her head.
    The pane is dusk-blue glass lit warm round the flame, so the dark little
    girl and her bright candle read at phone size (the pane is 14 x 16 px)."""
    s = radial(ctx, cx, cy - r * 0.35, r * 2.0, FLAME if lit else '#fff4d8', 0.55 if lit else 0.4)
    bg = ctx.radgrad([(0, '#fff2c8'), (0.45, '#f0c890' if lit else '#c8b8e0'), (1, '#f0a860' if lit else '#6a5a9a')],
                     cx=0.5, cy=0.3, r=0.75)
    s += '<path d="%s" fill="%s" stroke="%s" stroke-width="2.4"/>' % (ell_d(cx, cy, r, r * 1.12), bg, L)
    g = TESSEL_GIRL if not lit else '#8a3a30'
    # the girl: a round head, a little bell-shaped dress, arms out holding her skirt
    s += '<path d="%s" fill="%s"/>' % (smooth_d([(cx - r * 0.5, cy + r * 1.04), (cx - r * 0.24, cy + r * 0.3), (cx + r * 0.24, cy + r * 0.3),
                                                 (cx + r * 0.5, cy + r * 1.04)]), g)
    s += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s"/>' % (cx, cy + r * 0.06, r * 0.3, g)
    # the candle on her head: a white stick, a flame outlined dark with a hot core
    s += '<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="#fbf6ea" stroke="%s" stroke-width="0.8"/>' % (
        cx - r * 0.12, cy - r * 0.62, r * 0.24, r * 0.42, L)
    fy = cy - r * 0.62
    s += radial(ctx, cx, fy - r * 0.2, r * 0.75, '#ffe8a0', 0.95)
    s += '<path d="%s" fill="%s" stroke="%s" stroke-width="0.9"/>' % (flame_d(cx, fy, r * 0.3, r * 0.62), FLAME, '#8a4a18')
    s += '<path d="%s" fill="%s"/>' % (flame_d(cx, fy - r * 0.04, r * 0.15, r * 0.32), '#ffffff')
    s += '<path d="%s" fill="#ffffff" opacity="0.45"/>' % ell_d(cx - r * 0.45, cy - r * 0.55, r * 0.26, r * 0.12, -30)
    return s


def mask_parts(ctx, cx, cy, eyes='closed', mouth='calm', rot=0.0, crack=False):
    """Her glass-oval mask local to its centre: closed eyes drawn in lead."""
    s = ''
    E = ((cx - 11, cy - 2), (cx + 11, cy - 3))
    for i, (x, y) in enumerate(E):
        k = -1 if i == 0 else 1
        if eyes == 'closed':
            s += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (x - 6.4, y - 1, x, y + 4.4, x + 6.4, y - 1), L, 2.6)
            s += line('M%.1f %.1f l%.1f %.1f' % (x + k * 6.4, y - 1, k * 2.4, -1.6), L, 1.4)
        elif eyes == 'white':
            s += radial(ctx, x, y, 12, PRISM_W, 0.9)
            s += '<path d="%s" fill="#ffffff" stroke="%s" stroke-width="1.6"/>' % (ell_d(x, y, 6.4, 3.6), L)
        elif eyes == 'squeeze':
            s += line('M%.1f %.1f L%.1f %.1f L%.1f %.1f' % (x - k * 5.4, y - 4.4, x + k * 4, y, x - k * 5.4, y + 4.4), L, 2.6)
        elif eyes == 'dazed':
            s += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (x - 6, y + 1, x, y - 2.4, x + 6, y + 1), L, 2.4)
            s += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (x - 4, y + 4.4, x, y + 3.2, x + 4, y + 4.4), L, 1.2)
        elif eyes == 'peace':
            s += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (x - 6.4, y + 1, x, y - 4, x + 6.4, y + 1), L, 2.6)
    # brows: fine lead lines, serene
    for i, (x, y) in enumerate(E):
        s += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (x - 6, y - 9, x, y - 11.4, x + 6, y - 9), L, 1.2, op=0.8)
    mx, my = cx + 1, cy + 14
    if mouth == 'calm':
        s += line('M%.1f %.1f L%.1f %.1f' % (mx - 3.4, my, mx + 3.4, my), L, 1.8)
    elif mouth == 'sing':
        s += '<path d="%s" fill="%s" stroke="%s" stroke-width="1.6"/>' % (ell_d(mx, my + 1, 3.4, 4.6), '#4a3a6a', L)
    elif mouth == 'open':
        s += '<path d="%s" fill="%s" stroke="%s" stroke-width="1.6"/>' % (ell_d(mx, my + 1, 4.6, 3.2), '#4a3a6a', L)
    elif mouth == 'smile':
        s += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (mx - 4.4, my - 1, mx, my + 2.6, mx + 4.4, my - 1), L, 1.8)
    s += '<path d="%s" fill="#e8c8d8" opacity="0.5"/>' % ell_d(cx - 16, cy + 8, 4.4, 2.4)
    s += '<path d="%s" fill="#e8c8d8" opacity="0.5"/>' % ell_d(cx + 16, cy + 7, 4.4, 2.4)
    if crack:
        s += line('M%.1f %.1f l5 8 l-3 7 l6 9' % (cx + 4, cy - 26), L, 1.8) + line('M%.1f %.1f l5 8 l-3 7 l6 9' % (cx + 5, cy - 26), '#ffffff', 0.7, op=0.9)
    face = Part('fill', pth(ell_d(cx, cy, 24, 28)), fill=MASK, shade=MASK_SH, off=(-3, -3),
                hl=spec(cx - 10, cy - 14, 6, 3, rot=-30, op=0.8), over=s)
    return face


def prism_parts(ctx, cx, cy, s=1.0, rot=0.0, glow=0.0):
    """The floating prism: a clear triangle of glass, its edge split into colours."""
    t = 'translate(%.1f %.1f) rotate(%.1f) scale(%.2f)' % (cx, cy, rot, s)
    tri = [(0, -13), (12, 9), (-12, 9)]
    over = ''
    for i, col in enumerate(RAY):
        o = -2 + i
        over += line('M%.1f %.1f L%.1f %.1f' % (12 + o * 0.3, 9 + o * 0.9, 3 + o * 0.6, 11 + o * 1.2), col, 1.2, op=0.9)
    over += line('M0 -13 L-2 9', '#ffffff', 1.2, op=0.8) + line('M-2 9 L12 9', '#d8d0f0', 1, op=0.8)
    P = [Part('fill', pth(poly_d(tri)), fill=PRISM_W, shade='#d8d0f0', off=(-1.4, -1.4), over=over,
              hl=spec(-3, -3, 2, 5, rot=20, op=0.9))]
    fx = radial(ctx, 0, 0, 20 + glow * 16, PRISM_W, 0.5 + glow * 0.4) if glow or True else ''
    return place(P, t), gx(fx, t)


def sleeve(sh, el, hand, w=16):
    """A glass bell sleeve from the shoulder, widening to its cuff just short of the hand."""
    c = bez(sh, el, el, hand, 12)
    cut = [along(c, t) for t in [i / 12.0 * 0.82 for i in range(13)]]
    return ribbon(cut, (13, 17, 30), caps=(True, False))


# ---------------------------------------------------------------- one frame

def frame(name):
    ctx = Ctx('st' + name[:4])
    fid = 'saint_' + name
    eyes, mouth = 'closed', 'calm'
    sway, flare, lift = 0.0, 1.0, 0.0
    head_rot = 0.0
    colors = GLASS
    crack = False
    tessel_lit = False
    over, under = '', ''
    # the hands: (shoulder, elbow, hand) each side, and where the prism floats
    arms = (((104, 96), (88, 128), (118, 148)), ((152, 96), (168, 128), (140, 148)))
    prism = (129, 141, 1.0, 0.0, 0.0)
    if name == 'idle':
        pass
    elif name == 'charge':
        arms = (((104, 96), (96, 110), (124, 80)), ((152, 96), (164, 108), (140, 80)))
        prism = (132, 72, 1.1, -10, 0.7)
        head_rot = -4
        over += ''.join(star4(x, y, r, '#ffffff', 0.9) for x, y, r in ((150, 60, 5), (112, 58, 4), (136, 46, 3.4)))
    elif name == 'beam':
        eyes, mouth = 'closed', 'open'
        arms = (((104, 96), (100, 116), (150, 104)), ((152, 96), (176, 102), (196, 96)))
        prism = (206, 92, 1.2, 90, 1.0)
        sway = -10
    elif name == 'rose':
        arms = (((104, 96), (70, 96), (44, 80)), ((152, 96), (186, 96), (212, 80)))
        prism = (128, 143, 0.9, 20, 0.3)
        flare = 1.1
    elif name == 'sing':
        eyes, mouth = 'closed', 'sing'
        head_rot = -12
        arms = (((104, 96), (88, 126), (117, 146)), ((152, 96), (168, 126), (139, 146)))
        prism = (128, 140, 1.0, 0, 0.4)
        over += sing_fx(ctx)
    elif name == 'refracted':
        eyes, mouth = 'dazed', 'open'
        crack = True
        head_rot = 18
        arms = (((104, 100), (96, 132), (104, 150)), ((152, 100), (162, 132), (158, 152)))
        prism = (164, 168, 0.9, 60, 0.0)
        flare = 1.05
        sway = 8
    elif name == 'hurt':
        eyes, mouth = 'squeeze', 'open'
        crack = True
        head_rot = -14
        sway = 14
        arms = (((104, 96), (82, 86), (70, 70)), ((152, 96), (176, 88), (190, 72)))
        prism = (162, 144, 0.9, 30, 0.0)
        over += chips_fx(ctx)
    elif name == 'split':
        eyes, mouth = 'white', 'open'
        crack = True
        arms = (((104, 96), (72, 100), (50, 90)), ((152, 96), (184, 100), (206, 90)))
        prism = (128, 146, 1.0, 0, 1.0)
        over += split_fx(ctx)
    else:   # die
        eyes, mouth = 'peace', 'smile'
        colors = WARM
        tessel_lit = True
        arms = (((104, 96), (88, 128), (118, 150)), ((152, 96), (168, 128), (138, 150)))
        prism = (128, 143, 1.0, 0, 0.8)
        under += radial(ctx, 128, 120, 120, FLAME, 0.35)
    P = []
    oy = lift
    # the gown and its panes
    gd = gown_d(sway, flare)
    gd_t = gd if not oy else None
    t_body = 'translate(0 %.1f)' % oy
    g_over = panes(ctx, gd, gown_cells(sway, flare), colors, seed=1)
    cid = ctx.clip('<path d="%s"/>' % gd)
    band = colors[2] if colors is GLASS else colors[4]
    g_over += '<g clip-path="%s"><path d="%s" fill="none" stroke="%s" stroke-width="16"/><path d="%s" fill="none" stroke="%s" stroke-width="8.6" transform="translate(0 0)"/></g>' % (
        cid, gd, L, gd, band)
    # the centre fold: one leaded line from the waist to the point
    fold = [(128, 126), (127, 170), (128 + sway * 0.4, 204), (129 + sway, 240)]
    g_over += '<g clip-path="%s">%s</g>' % (cid, line(open_d(fold), L, 2.2))
    if crack:
        g_over += line('M118 150 l8 14 l-6 12 l10 16 M146 170 l-8 10 l4 12', L, 2.4) + line('M118 150 l8 14 l-6 12 l10 16', '#ffffff', 0.9, op=0.8)
    # her mantle behind the gown: glass falling from the hood's hem, spread wide
    md = mantle_d(sway, flare)
    m_cells = [[(x, 80), (x + 16, 80), (x + 16 + (x - 120) * 0.35, 230), (x + (x - 128) * 0.35, 230)] for x in range(56, 200, 16)]
    P.append(Part('fill', pth(md), fill=colors[2], shade=GLASS_SH, off=(-4, -3), lw=2.6,
                  over=panes(ctx, md, m_cells, [colors[2], colors[4], colors[6], colors[1]], seed=2)))
    P.append(Part('fill', pth(gd), fill=colors[1], shade=GLASS_SH, off=(-4, -3), over=g_over, lw=2.6))
    # the far sleeve behind the bodice
    (sh0, el0, h0), (sh1, el1, h1) = arms
    P.append(Part('fill', pth(sleeve(sh0, el0, h0)), fill=colors[2], shade=GLASS_SH, off=(-2, -2),
                  over=line(open_d([sh0, el0, h0]), L, 1.4, op=0.6)))
    # the bodice with Tessel's pane
    bd = bodice_d()
    P.append(Part('fill', pth(bd), fill=colors[3], shade=GLASS_SH, off=(-2, -2),
                  over=panes(ctx, bd, grid_cells(lambda y: 98, lambda y: 158, [92, 110, 130], [4, 4]), colors, seed=3)
                  + tessel_pane(ctx, HEART[0], HEART[1], HEART_R, tessel_lit)))
    # the hood (a lancet arch of panes) and the mask
    hood = smooth_d(HOOD)
    hc = (128, 58)
    P_head = [Part('fill', pth(hood), fill=colors[0], shade=GLASS_SH, off=(-3, -3),
                   over=panes(ctx, hood, hood_cells(), colors, seed=5))]
    P_head.append(mask_parts(ctx, 128, 60, eyes, mouth, crack=crack))
    P_head = place(P_head, 'rotate(%.1f %.1f %.1f)' % (head_rot, 128, 96))
    # the near sleeve and the hands
    P_near = [Part('fill', pth(sleeve(sh1, el1, h1)), fill=colors[4], shade=GLASS_SH, off=(-2, -2),
                   over=line(open_d([sh1, el1, h1]), L, 1.4, op=0.6))]
    for h in (h0, h1):
        P_near.append(Part('fill', pth(ell_d(h[0], h[1], 6.4, 5.4)), fill=MASK, shade=MASK_SH, off=(-1, -1)))
    px, py, ps, pr, pg = prism
    prism_p, prism_fx = prism_parts(ctx, px, py, ps, pr, pg)
    parts = P + P_head + P_near + prism_p
    parts = place(parts, t_body) if oy else parts
    body = paint(ctx, parts, PAL)
    fx = gx(prism_fx, t_body) if oy else prism_fx
    text = svg(ctx, under + body + fx + over, 256, 256)

    def R(p):
        q = rot_pt(p[0], p[1], 128, 96, head_rot)
        return (q[0], q[1] + oy)
    PTS.mark(fid, mask=R((128, 60)), halo_center=R(hc), prism=(px, py + oy), heart=(HEART[0], HEART[1] + oy),
             body=body_box(sway, flare, head_rot, oy))
    return text


def body_box(sway, flare, head_rot, oy=0.0):
    """Her box in one frame [x, y, w, h]: the hood (turned with her head), the
    mantle and the gown (swayed and flared), with their ink; not her hands."""
    pts = [rot_pt(x, y, 128, 96, head_rot) for x, y in HOOD] + gown_pts(sway, flare)
    f = flare
    pts += [(180 + 8 * f + sway * 0.4, 150), (188 + 8 * f + sway * 0.6, 188), (68 - 8 * f + sway * 0.6, 188), (76 - 8 * f, 150)]
    x0, x1 = min(p[0] for p in pts) - 3, max(p[0] for p in pts) + 3
    y0, y1 = min(p[1] for p in pts) - 3, max(p[1] for p in pts) + 2
    return (x0, y0 + oy, x1 - x0, y1 - y0)


def sing_fx(ctx):
    s = ''
    for x, y, r, c in ((178, 40, 5, RAY[0]), (196, 62, 4, RAY[1]), (72, 46, 4.4, RAY[3]), (58, 70, 3.4, RAY[4])):
        s += star4(x, y, r + 1.4, L, 0.8) + star4(x, y, r, c, 0.95)
    s += motion('M170 24 q8 -6 14 0 M78 26 q-8 -6 -14 0', 1.6, 0.8, ink=L)
    return s


def chips_fx(ctx):
    s = ''
    for x, y, a, c in ((186, 40, 20, GLASS[2]), (200, 70, -30, GLASS[1]), (66, 50, 50, GLASS[4]), (54, 90, -10, GLASS[0])):
        s += '<path d="M%.1f %.1f l7 2 l-4 6 Z" fill="%s" stroke="%s" stroke-width="1.2" transform="rotate(%d %.1f %.1f)"/>' % (x, y, c, L, a, x, y)
    s += motion('M200 20 L212 8 M44 30 L32 18', 1.8, 0.9, ink=L)
    return s


def split_fx(ctx):
    """Scattered Dawn: light bursting out between her panes, three shards leaving."""
    s = ''
    for i in range(12):
        a = math.radians(i * 30 + 8)
        s += line('M%.1f %.1f L%.1f %.1f' % (128 + math.cos(a) * 30, 120 + math.sin(a) * 30, 128 + math.cos(a) * 90,
                                           120 + math.sin(a) * 90), PRISM_W, 2.4, op=0.7)
    for (x, y), col in zip(((60, 60), (196, 60), (128, 214)), (RAY[0], RAY[1], RAY[3])):
        s += '<path d="%s" fill="%s" stroke="%s" stroke-width="1.8"/>' % (poly_d([(x, y - 12), (x + 7, y), (x, y + 12), (x - 7, y)]), col, L)
    return s


# ================================================================ parts

def part_halo():
    """saint_halo (256): a rose window of prism rays round a clear centre, (128, 128)."""
    ctx = Ctx('ha')
    cx = cy = 128
    s = ''
    # the prism rays: long thin spikes between the petals
    for i in range(16):
        a = math.radians(i * 22.5 + 11.25)
        ln = 118 if i % 2 == 0 else 100
        p0 = (cx + math.cos(a - 0.05) * 70, cy + math.sin(a - 0.05) * 70)
        p1 = (cx + math.cos(a) * ln, cy + math.sin(a) * ln)
        p2 = (cx + math.cos(a + 0.05) * 70, cy + math.sin(a + 0.05) * 70)
        s += '<path d="%s" fill="%s" stroke="%s" stroke-width="1.6" stroke-linejoin="round"/>' % (poly_d([p0, p1, p2]), PRISM_W, L)
    # the outer ring of petal panes
    for i in range(12):
        a0, a1 = math.radians(i * 30), math.radians(i * 30 + 30)
        am = (a0 + a1) / 2
        pts = [(cx + math.cos(a0) * 50, cy + math.sin(a0) * 50), (cx + math.cos(a0 + 0.1) * 78, cy + math.sin(a0 + 0.1) * 78),
               (cx + math.cos(am) * 90, cy + math.sin(am) * 90), (cx + math.cos(a1 - 0.1) * 78, cy + math.sin(a1 - 0.1) * 78),
               (cx + math.cos(a1) * 50, cy + math.sin(a1) * 50)]
        s += '<path d="%s" fill="%s" stroke="%s" stroke-width="2.4" stroke-linejoin="round"/>' % (smooth_d(pts, k=0.12), GLASS[i % len(GLASS)], L)
        s += '<path d="%s" fill="#ffffff" opacity="0.35"/>' % ell_d(cx + math.cos(am) * 70, cy + math.sin(am) * 70, 5, 2.4, math.degrees(am) + 90)
    # the inner ring and the clear centre
    for i in range(8):
        a0, a1 = math.radians(i * 45 + 22.5), math.radians(i * 45 + 67.5)
        pts = [(cx, cy), (cx + math.cos(a0) * 50, cy + math.sin(a0) * 50), (cx + math.cos(a1) * 50, cy + math.sin(a1) * 50)]
        s += '<path d="%s" fill="%s" stroke="%s" stroke-width="2.2" stroke-linejoin="round"/>' % (poly_d(pts), GLASS[(i + 3) % len(GLASS)], L)
    s += '<circle cx="%d" cy="%d" r="50" fill="none" stroke="%s" stroke-width="3.4"/>' % (cx, cy, L)
    s += '<circle cx="%d" cy="%d" r="88" fill="none" stroke="%s" stroke-width="2" opacity="0.8"/>' % (cx, cy, L)
    s += '<circle cx="%d" cy="%d" r="22" fill="%s" stroke="%s" stroke-width="2.4"/>' % (cx, cy, PRISM_W, L)
    rim = '<circle cx="%d" cy="%d" r="90" fill="none" stroke="%s" stroke-width="6.4" opacity="0.9"/>' % (cx, cy, RIM)
    return svg(ctx, radial(ctx, cx, cy, 110, PRISM_W, 0.25) + rim + s, 256, 256)


def part_blade():
    """halo_shard (64 x 32): a white glass lancet blade pointing right (tip (56, 16))."""
    ctx = Ctx('hs')
    d = smooth_d([(6, 16), (14, 9), (38, 8), (56, 16), (38, 24), (14, 23)], k=0.1)
    P = [Part('fill', pth(d), fill='#ffffff', shade='#e4e0ee', off=(-1.4, -1.4),
              over=line('M12 16 L52 16', '#d4d0e0', 1.2, op=0.9), hl=spec(28, 12, 8, 1.6, rot=0, op=0.9))]
    return svg(ctx, paint(ctx, P, dict(PAL, line='#3a3448')), 64, 32)


SHARDS = {'red': ('#d84a64', '#a02a44', '#ffb0c0'), 'gold': ('#e8b040', '#b07a1a', '#fff0b0'),
          'blue': ('#4a7ad8', '#2a4aa0', '#b8d0ff')}


def part_shard(col):
    """saint_shard_<col> (128): one of the three prism shards of Scattered Dawn:
    a tall faceted crystal with a sliver of her closed-eyed mask, centre (64, 64)."""
    ctx = Ctx('sh' + col[0])
    base, sh, hi = SHARDS[col]
    outline = [(64, 10), (88, 40), (84, 88), (64, 118), (44, 88), (40, 40)]
    facets = ''
    for a, b in (((64, 10), (64, 118)), ((40, 40), (84, 88)), ((88, 40), (44, 88))):
        facets += line('M%.1f %.1f L%.1f %.1f' % (a + b), L, 1.6, op=0.7)
    facets += '<path d="%s" fill="%s" opacity="0.7"/>' % (poly_d([(64, 10), (88, 40), (64, 60)]), hi)
    facets += '<path d="%s" fill="%s" opacity="0.5"/>' % (poly_d([(44, 88), (64, 118), (64, 80)]), sh)
    # her mask's sliver, eyes closed
    facets += '<path d="%s" fill="%s" stroke="%s" stroke-width="1.6"/>' % (ell_d(64, 56, 14, 16), MASK, L)
    facets += line('M55 54 Q59 57 63 54 M66 53 Q70 56 74 53', L, 1.8)
    facets += line('M62 64 L67 64', L, 1.4)
    P = [Part('fill', pth(poly_d(outline)), fill=base, shade=sh, off=(-3, -3), over=facets, hl=spec(52, 34, 3, 8, rot=20, op=0.9))]
    return svg(ctx, radial(ctx, 64, 64, 58, hi, 0.4) + paint(ctx, P, PAL), 128, 128)


def prop_mirror(dim):
    """mirror_shard / _dim (64 x 128): a 32 x 112 unit (16 x 56 px) mirror pane
    with bright rims, centred at (32, 64); not a platform."""
    ctx = Ctx('mr' + ('d' if dim else 'b'))
    x0, y0, w, h = 16, 8, 32, 112
    glass = ctx.lingrad([(0, '#e8eef8' if not dim else '#6a6e7c'), (0.45, '#b8c4dc' if not dim else '#4a4e5c'),
                         (0.55, '#f8faff' if not dim else '#707484'), (1, '#9aa8c8' if not dim else '#3e4250')], x1=0, y1=0, x2=1, y2=1)
    pts = [(x0 + 4, y0), (x0 + w - 4, y0), (x0 + w, y0 + 6), (x0 + w, y0 + h - 6), (x0 + w - 4, y0 + h), (x0 + 4, y0 + h),
           (x0, y0 + h - 6), (x0, y0 + 6)]
    s = '<path d="%s" fill="%s"/>' % (poly_d(pts), glass)
    s += '<path d="%s" fill="none" stroke="%s" stroke-width="3.4"/>' % (poly_d(pts), L)
    rim = PRISM_W if not dim else '#8a8e9c'
    s += '<path d="%s" fill="none" stroke="%s" stroke-width="2"/>' % (poly_d([(x0 + 4, y0 + 2.4), (x0 + w - 4, y0 + 2.4), (x0 + w - 2.4, y0 + 6),
                                                                           (x0 + w - 2.4, y0 + h - 6), (x0 + w - 4, y0 + h - 2.4),
                                                                           (x0 + 4, y0 + h - 2.4), (x0 + 2.4, y0 + h - 6), (x0 + 2.4, y0 + 6)]), rim)
    if not dim:
        s += line('M%.1f %.1f L%.1f %.1f' % (x0 + 8, y0 + 18, x0 + 20, y0 + 6), '#ffffff', 2.4, op=0.9)
        s += line('M%.1f %.1f L%.1f %.1f' % (x0 + 7, y0 + 40, x0 + 26, y0 + 20), '#ffffff', 1.4, op=0.7)
        s += star4(x0 + w - 7, y0 + 14, 5, '#ffffff', 0.95)
    outer = '<path d="%s" fill="none" stroke="%s" stroke-width="3" opacity="%s"/>' % (
        poly_d([(x0 + 2, y0 - 2.4), (x0 + w - 2, y0 - 2.4), (x0 + w + 2.4, y0 + 4), (x0 + w + 2.4, y0 + h - 4), (x0 + w - 2, y0 + h + 2.4),
                (x0 + 2, y0 + h + 2.4), (x0 - 2.4, y0 + h - 4), (x0 - 2.4, y0 + 4)]), RIM, '0.9' if not dim else '0.45')
    under = radial(ctx, 32, 64, 34, PRISM_W, 0.3) if not dim else ''
    return svg(ctx, under + outer + s, 64, 128)


# ================================================================ build

def points_json():
    head = {
        '_doc': "The Prism Saint's 256-unit frames: 2 units = 1 world px, drawn facing right (she is nearly frontal), "
                'anchor (128, 244) = the point of her gown (she floats: put the anchor where she hovers; Refracted '
                'hovers it about 40 px over the platform). World offset = (point - anchor) / 2 px, mirrored with the '
                'facing. mask = her face (the beam and the aim line start there); halo_center = where saint_halo\'s '
                'centre goes (drawn behind her); prism = the prism in her hands; heart = Tessel\'s pane; body = her '
                'box [x, y, w, h] in that frame (touch and chip hits: 5% through her glass). Refracted: at the spec\'s '
                'hover (her anchor about 40 px over the platform) a standing slash (8..42 px) only reaches her gown\'s '
                'point, so the window is for jump attacks and stomps (the Anvil Drop); to let standing slashes land '
                'too, hover the anchor at about 20 px (her lower gown then sits at 20..60 px).',
        '_draw_scale': DRAW_SCALE,
        '_draw_scale_note': 'REQUIRED: draw her frames, saint_halo and the saint_shard_* parts at %g x 1:1 (sprite scale '
                            '0.25 x %g) and scale every offset by it: world offset = (point - anchor) / 2 x %g px. At 1:1 '
                            'her glass is 71 x 119 px and her halo\'s solid rose 90 px across, under the 96 x 128 px every '
                            'boss must read at (spec 5.1); at %g she is 82 x 137 px, and with the halo behind her 104 x '
                            '159 px. The 512-texel frames stay sharp on the phone up to about 1.18. The mirrors, the '
                            'halo_shard blades and the beam are not scaled.' % (DRAW_SCALE, DRAW_SCALE, DRAW_SCALE, DRAW_SCALE),
        '_anchor': list(FOOT),
        '_height_units': 238,
        '_parts': {
            'saint_halo': {'frame': [256, 256], 'center': [128, 128], 'rim_r': 90, 'ray_r': 118,
                           'note': 'drawn behind her at halo_center; turn it slowly, spin it up for the Rose'},
            'halo_shard': {'frame': [64, 32], 'center': [32, 16], 'tip': [56, 16],
                           'note': 'white: modulate it to a pane colour; it points right, turn it to its flight'},
            'saint_shard_red': {'frame': [128, 128], 'center': [64, 64], 'mask': [64, 56], 'box': [40, 10, 48, 108]},
            'saint_shard_gold': {'frame': [128, 128], 'center': [64, 64], 'mask': [64, 56], 'box': [40, 10, 48, 108]},
            'saint_shard_blue': {'frame': [128, 128], 'center': [64, 64], 'mask': [64, 56], 'box': [40, 10, 48, 108],
                                 'note': 'each shard fires its beam from its mask; draw its crack in glow when reflected'},
            'mirror_shard': {'frame': [64, 128], 'center': [32, 64], 'pane': [16, 8, 32, 112],
                             'note': 'the 16 x 56 px pane; the track anchor is its top'},
            'mirror_shard_dim': {'frame': [64, 128], 'center': [32, 64], 'pane': [16, 8, 32, 112]},
        },
    }
    return PTS.json(head)


def files():
    PTS.d.clear()
    out = {}
    for n in FRAMES:
        out['art/enemies/saint_%s.svg' % n] = frame(n)
    out['art/enemies/saint_halo.svg'] = part_halo()
    out['art/enemies/halo_shard.svg'] = part_blade()
    for c in ('red', 'gold', 'blue'):
        out['art/enemies/saint_shard_%s.svg' % c] = part_shard(c)
    out['art/enemies/mirror_shard.svg'] = prop_mirror(False)
    out['art/enemies/mirror_shard_dim.svg'] = prop_mirror(True)
    out['art/enemies/points_saint.json'] = points_json()
    return out


def expect():
    e = {'art/enemies/saint_%s.svg' % n: (256, 256) for n in FRAMES}
    e.update({'art/enemies/%s.svg' % k: v for k, v in PARTS.items()})
    return e


def build(write):
    out = files()
    check_art(out, 'the Prism Saint', BUDGET_MB, expect())
    for rel, text in out.items():
        write(rel, text)
    ensure_imports(out)


if __name__ == '__main__':
    run_main(files, 'the Prism Saint', BUDGET_MB, expect)
