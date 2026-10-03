"""The Prism Saint (W5's boss, story id `saint`; the story draft's `prism`)
and Tessel, for the story figures (story_figs_deep.py) and portraits
(story_faces_deep.py), drawn with the fight's own parts (tools/art/boss5.py,
A4; spec 6.6), as story_rootmother.py draws Gravebough: a tall floating
saint of stained-glass panes in dark lead cames, drained to cold whites and
pale lilac, a lancet hood round a glass-oval mask with its eyes closed, a
gown of glass tapering to a point (no feet), hands cupping a floating
prism, a halo of prism rays (the fight's saint_halo part, behind her head),
and in her heart one clear pane showing a small girl with a candle on her
head: Tessel.

Everything between the two "vendored" rules below is copied verbatim from
boss5.py (its outline helpers come from story_rootmother.py's copy of
boss3.py's). When boss5.py sits beside this file (the merged tree) the
story draws with it instead (story_rootmother.attempt). `python3
tools/art/story.py --vendor` copies it here again.

  saint_boss        the fight's idle frame with its halo, at the size the
                    engine draws her (DRAW_SCALE)
  tessel_lit        the fight's last frame (lit from behind: every pane warm,
                    Tessel shining) with her eyes open and kind, and the halo
                    in the warm panes
  portraits         her hooded glass head, the halo behind: serene (eyes
                    closed), wrath (the eyes white slits, the glass cracked,
                    the halo flaring); Tessel's warm: gentle (eyes open, a shy
                    smile), sad (looking down, one blue pane like a tear)

Her eyes open (Tessel's) are the story's: A4's mask closes them in every
frame but the last, which smiles them shut.
"""
import math
import sys

import kit
from kit import Part, pth
from common import Ctx, RIM, svg, paint, line, dot, spec, star4, gx, flame_d, CHAR_WEIGHTS
from boss import place, rot_pt, ell_d
from story_kit import weights
from story_rootmother import Points, bez, smooth_d, poly_d, radial, motion, open_d, ribbon, along
import story_rootmother as _RM

# ================================================================ vendored from boss5.py (A4): begin

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

PTS = Points()


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


# ================================================================ vendored from boss5.py (A4): end


# ================================================================ drawing with the fight's parts

THIS = sys.modules[__name__]
EYES_COLD, EYES_WARM = 'f8f4ff', 'ffd8a0'
MASK_C = (128, 60)          # frame(): the mask's centre, before any head turn (idle and die turn none)
EYE_DX = (-11, 11)          # mask_parts(): the eyes either side of it


def kind_eyes(cx, cy, look='kind', ink='#221c30'):
    """Tessel's eyes open (the story's), on a mask centred (cx, cy): dark glass
    pupils with a glint under a lead lid line; kind looks out, down looks
    down."""
    s = ''
    down = look == 'down'
    for x, y in ((cx - 11, cy - 2), (cx + 11, cy - 3)):
        py = y + (1.6 if down else 0.0)
        s += '<path d="%s" fill="%s"/>' % (ell_d(x, py, 3.4, 4.2 if not down else 3.2), ink)
        s += dot(x - 1.0, py - (0.4 if down else 1.4), 1.2, '#ffffff') + dot(x + 1.2, py + 1.4, 0.6, '#ffffff', 0.8)
        s += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (x - 5.4, py - (2.2 if down else 3.6), x, py - (4.4 if down else 6.4),
                                                      x + 5.4, py - (2.2 if down else 3.6)), ink, 1.6)
    return s


def _with_mask(M, eyes_svg, fn):
    """fn() with M.mask_parts drawing no eyes of its own (a mode it doesn't
    know) and eyes_svg(cx, cy) over the mask instead."""
    orig = M.mask_parts

    def mask(ctx, cx, cy, eyes='closed', mouth='calm', rot=0.0, crack=False):
        part = orig(ctx, cx, cy, 'story', mouth, rot, crack)
        part.over += eyes_svg(cx, cy)
        return part
    M.mask_parts = mask
    try:
        return fn()
    finally:
        M.mask_parts = orig


def halo_doc(M, warm=False):
    """saint_halo's defs and body, in the warm panes for Tessel."""
    defs, body, _ = _RM.split_doc(M.part_halo())
    if warm:
        for c, w in zip(M.GLASS, M.WARM):
            body = body.replace(c, w)
        body = body.replace(M.PRISM_W, '#fff2c8')
    return defs, body


def figure(lit):
    """The Saint (or, lit, Tessel) for the figure frame: {defs, body, eyes,
    halo, prism, heart} (figure units)."""
    def draw(M):
        if lit:
            text = _with_mask(M, lambda cx, cy: kind_eyes(cx, cy, 'kind', M.L), lambda: M.frame('die'))
            pts = M.PTS.d['saint_die']
        else:
            text = M.frame('idle')
            pts = M.PTS.d['saint_idle']
        defs, body, _ = _RM.split_doc(text)
        hdefs, hbody = halo_doc(M, lit)
        hc = pts['halo_center']
        halo = '<g transform="translate(%.1f %.1f)">%s</g>' % (hc[0] - 128, hc[1] - 128, hbody)
        k = _RM.FIG_K * M.DRAW_SCALE
        mc = pts['mask']
        eyes = [(mc[0] + EYE_DX[0], mc[1] - 2), (mc[0] + EYE_DX[1], mc[1] - 3)]
        heart = pts['heart']
        return {'defs': hdefs + defs, 'body': _RM.placed(halo + body, M.FOOT, k),
                'eyes': [_RM.to_fig(e, M.FOOT, k) for e in eyes], 'halo': _RM.to_fig(hc, M.FOOT, k),
                'prism': _RM.to_fig(pts['prism'], M.FOOT, k),
                # the candle on the little girl's head in the heart pane (tessel_pane)
                'heart': _RM.to_fig((heart[0], heart[1] - M.HEART_R * 0.62), M.FOOT, k)}
    return _RM.attempt('boss5', THIS, draw)


PORTRAIT_K = 1.02


def portrait(ctx, mood, lw):
    """Her head from the fight (the hood of panes, the mask, the mantle and
    the bodice with Tessel's pane), the halo behind, mirrored to face left,
    in native portrait units (144 box). Returns svg."""
    def draw(M):
        lit = mood in ('gentle', 'sad')
        wrath = mood == 'wrath'
        k = PORTRAIT_K
        colors = M.WARM if lit else M.GLASS
        mc = MASK_C
        t = 'translate(72 72) scale(%.3f %.3f) translate(%.2f %.2f)' % (-k, k, -mc[0], -mc[1])
        # the halo behind the hood, bigger and brighter in wrath
        hdefs, hbody = halo_doc(M, lit)
        ctx.defs.append(hdefs)
        hk = 0.62 if not wrath else 0.74
        s = gx(hbody, t + ' translate(%.2f %.2f) scale(%.2f) translate(-128 -128)' % (mc[0], mc[1] - 4, hk))
        if wrath:
            s += gx(radial(ctx, 128, 128, 120, M.PRISM_W, 0.5), t + ' translate(%.2f %.2f) scale(%.2f) translate(-128 -128)' % (
                mc[0], mc[1] - 4, hk))
        md = M.mantle_d()
        parts = [Part('fill', pth(md), fill=colors[2], shade=M.GLASS_SH, off=(-4, -3), lw=2.6,
                      over=M.panes(ctx, md, [[(x, 80), (x + 16, 80), (x + 16 + (x - 120) * 0.35, 230), (x + (x - 128) * 0.35, 230)]
                                             for x in range(56, 200, 16)], [colors[2], colors[4], colors[6], colors[1]], seed=2))]
        bd = M.bodice_d()
        parts.append(Part('fill', pth(bd), fill=colors[3], shade=M.GLASS_SH, off=(-2, -2),
                          over=M.panes(ctx, bd, M.grid_cells(lambda y: 98, lambda y: 158, [92, 110, 130], [4, 4]), colors, seed=3)
                          + M.tessel_pane(ctx, M.HEART[0], M.HEART[1], M.HEART_R, lit)))
        hood = M.smooth_d(M.HOOD)
        parts.append(Part('fill', pth(hood), fill=colors[0], shade=M.GLASS_SH, off=(-3, -3),
                          over=M.panes(ctx, hood, M.hood_cells(), colors, seed=5)))
        if lit:
            look = 'down' if mood == 'sad' else 'kind'
            mask = M.mask_parts(ctx, mc[0], mc[1], 'story', 'calm' if mood == 'sad' else 'smile')
            mask.over += kind_eyes(mc[0], mc[1], look, M.L)
            mask.over += '<path d="%s" fill="#e8a0a8" opacity="0.55"/>' % ell_d(mc[0] - 15, mc[1] + 8, 5, 2.8)
            mask.over += '<path d="%s" fill="#e8a0a8" opacity="0.55"/>' % ell_d(mc[0] + 15, mc[1] + 7, 5, 2.8)
            if mood == 'sad':
                # one blue pane on her cheek, like a tear
                tear = 'M%.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f Z' % (
                    mc[0] + 12, mc[1] + 3, mc[0] + 16, mc[1] + 10, mc[0] + 12.5, mc[1] + 14, mc[0] + 8.6, mc[1] + 10, mc[0] + 12, mc[1] + 3)
                mask.over += '<path d="%s" fill="%s" stroke="%s" stroke-width="1.4"/>' % (tear, M.WARM[3], M.L)
        else:
            mask = M.mask_parts(ctx, mc[0], mc[1], 'white' if wrath else 'closed', 'open' if wrath else 'calm')
        parts.append(mask)
        with weights(tuple(w / k for w in lw)):
            s += paint(ctx, place(parts, t), M.PAL)
        if wrath:
            # the hood's panes cracking (the mask's own crack would split her eye at this size)
            cracks = ''
            for d in ('M86 24 l6 9 l-4 8 l7 10 l-3 9', 'M166 34 l-5 8 l5 7 l-4 10', 'M84 82 l8 5 l-2 8 l9 6'):
                cracks += line(d, M.L, 2.2) + line(d, '#ffffff', 0.8, op=0.9)
            s += gx(cracks, t)
        return s
    return _RM.attempt('boss5', THIS, draw)
