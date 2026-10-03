"""The story panels (sets): gothic storybook scenes in panel units, painted in
full local colour for the darkness shader to light. Each panel places its
lights first, then paints toward them; faces and focal points sit in the
upper two thirds (the dialogue box covers the bottom quarter of the view)
inside the central 900 x 420.

P0: glass_legend, lanternfold, chapel, callings, crypt_row, belfry.
P1: tallow_vista, undercandle, bells_all, dawn_rise, hush_eye.
(Cut in decisions.md: spire, tower_window, deep_mouth, helmet, moth_face.)
"""
import math

import kit
from kit import Part, ell, pth
from common import (Ctx, GOLD, GOLD_SH, GOLD_HI, GOLD_LINE, WAX, WAX_SH, FLAME, FLAME_CORE, line, dot, flame_d, spec,
                    star4, mix, gx)
from story_kit import (Panel, P, E, LIMB, draw, fillp, rect_d, rrect_d, ell_d, poly_d, arch_d, round_arch_d, radial,
                       vgrad, Rand, candle, candle_stand, bell_parts, bell_d, crest_svg, snowcap, moon_svg, cloud_d,
                       smoke_curl, unlit_wick, Glass, GLASS, CAME, FRONT_W, MID_W, BACK_W, weights_for, shade_of,
                       light_of, fade, hexc, rgb, BRONZE, BRONZE_SH, BRONZE_HI, BRONZE_LINE)

INK = '#140e1c'
WOOD, WOOD_SH, WOOD_HI, WOOD_LINE = '#8a5a36', '#5e3a22', '#b07a4c', '#241208'
PLUM, PLUM_SH = '#6a2e62', '#48204a'
IRON, IRON_SH, IRON_HI = '#4a4458', '#2e2a3a', '#7a7490'


# ================================================================ shared set pieces

def ashlar(rng, x0, y0, x1, y1, row_h, col, mortar, w_min=50, w_max=95, hl=None, op_var=0.08):
    """A wall of cut stone blocks: rows of row_h, staggered, each block a
    touch lighter or darker, with a lit top edge."""
    s = fillp(rect_d(x0, y0, x1, y1), mortar)
    y = y0
    row = 0
    while y < y1:
        x = x0 - (rng.u(0, w_min) if row % 2 else 0)
        h = min(row_h, y1 - y)
        while x < x1:
            w = rng.u(w_min, w_max)
            bx0, bx1 = max(x0, x + 1.2), min(x1, x + w - 1.2)
            if bx1 - bx0 > 4:
                c = mix(col, '#ffffff' if rng.f() > 0.5 else '#000000', rng.u(0, op_var))
                s += fillp(rrect_d(bx0, y + 1.2, bx1, y + h - 1.2, 2.5), c)
                if hl:
                    s += line('M%.1f %.1f L%.1f %.1f' % (bx0 + 3, y + 2.6, bx1 - 4, y + 2.6), hl, 1.1, op=0.55)
            x += w
        y += row_h
        row += 1
    return s


def flagstones(rng, y0, y1, vx, col, joint, rows=5, x0=-20, x1=1020):
    """A stone floor in perspective from y0 (the back) to y1, joints running to vx."""
    s = fillp(rect_d(x0, y0, x1, y1), joint)
    ys = [y0]
    t = 0.0
    for i in range(rows):
        t += 1.0 + i * 0.55
        ys.append(t)
    ys = [y0 + (y1 - y0) * (v / ys[-1]) if i else y0 for i, v in enumerate(ys)]
    for i in range(rows):
        ya, yb = ys[i], ys[i + 1]
        n = 7 + i
        step = (x1 - x0) / float(n)
        off = rng.u(0, step * 0.5)
        k = (ya - y0 + 30) / (y1 - y0 + 30)
        for j in range(-1, n + 1):
            xa = x0 + off + j * step
            xb = xa + step
            # joints lean toward the vanishing point
            def at(x, y):
                return vx + (x - vx) * ((y - y0 + 30) / (yb - y0 + 30))
            pa0, pa1 = at(xa, ya) + 1.5, at(xb, ya) - 1.5
            pb0, pb1 = xa + 1.5, xb - 1.5
            c = mix(col, '#ffffff' if rng.f() > 0.5 else '#000000', rng.u(0.0, 0.1))
            s += fillp(poly_d([(pa0, ya + 1.2), (pa1, ya + 1.2), (pb1, yb - 1.2), (pb0, yb - 1.2)]), c)
            s += line('M%.1f %.1f L%.1f %.1f' % (pa0 + 3, ya + 2.4, pa1 - 3, ya + 2.4), light_of(col, 0.3), 1.0, op=0.5)
    return s


def banner(ctx, x0, x1, top, bottom, cloth, cloth_sh, trim, line_col, w=MID_W):
    """A hanging banner on a rod: gold-trimmed, swallowtail hem, the Vigil crest."""
    cx = (x0 + x1) / 2.0
    notch = bottom - (x1 - x0) * 0.32
    d = poly_d([(x0, top), (x1, top), (x1, bottom), (cx, notch), (x0, bottom)])
    trim_d = poly_d([(x0 + 5, top + 4), (x1 - 5, top + 4), (x1 - 5, bottom - 8), (cx, notch - 6), (x0 + 5, bottom - 8)])
    over = '<path d="%s" fill="none" stroke="%s" stroke-width="3.2" stroke-linejoin="round"/>' % (trim_d, trim)
    over += crest_svg(cx, top + (bottom - top) * 0.45, (x1 - x0) * 0.42, trim, line_col, '#fff2c8', 1.4)
    folds = line('M%.1f %.1f L%.1f %.1f M%.1f %.1f L%.1f %.1f' % (x0 + (x1 - x0) * 0.28, top + 12, x0 + (x1 - x0) * 0.26, bottom - 14,
                                                                x0 + (x1 - x0) * 0.74, top + 12, x0 + (x1 - x0) * 0.76, bottom - 14), cloth_sh, 2.0, op=0.7)
    parts = [P(d, cloth, cloth_sh, off=(-6, -2), over=folds + over)]
    rod = [LIMB('M%.1f %.1f L%.1f %.1f' % (x0 - 12, top, x1 + 12, top), GOLD_SH, 3.4),
           E(x0 - 14, top, 4.2, 4.2, GOLD, GOLD_SH, off=(-1, -1)), E(x1 + 14, top, 4.2, 4.2, GOLD, GOLD_SH, off=(-1, -1))]
    cord = line('M%.1f %.1f L%.1f %.1f L%.1f %.1f' % (x0 - 10, top, cx, top - 34, x1 + 10, top), GOLD_SH, 1.6)
    return cord + draw(ctx, rod + parts, line_col, w)


# ================================================================ chapel (P0)

def chapel():
    p = Panel('chapel', 1000, 460, [0.30, 0.25, 0.42], 'dust')
    WALL = 284      # where the back wall meets the floor
    FLOOR = 302     # where figures stand (Taper on the chancel step, a little higher)
    STEP = 279
    # lights first: the lectern's three candles, the hearth, the oculus and
    # the pool of moonlight it throws on the rug where the novice stands
    lx = 262
    p.light('lectern1', lx - 32, STEP - 63, 100, 0.9, 'flame', h=8)
    p.light('lectern2', lx, STEP - 81, 118, 1.0, 'flame', h=10)
    p.light('lectern3', lx + 32, STEP - 67, 100, 0.9, 'flame', h=8)
    p.light('hearth', 862, WALL - 14, 205, 1.0, 'flame', h=24)
    p.light('window', 520, 136, 165, 0.55, 'glow', depth=0.5)
    p.light('moonpool', 606, 262, 150, 0.7, 'glow', tint='c8ccff')
    p.anchor('taper', 334, STEP)
    p.anchor('novice', 615, FLOOR, flip=True)
    p.anchor('actor', 615, FLOOR, h=120, face=-1)
    p.anchor('hollin', 742, FLOOR, flip=True)
    rng = Rand(1407)
    # ---------------------------------------------------------------- bg (0.5)
    ctx = Ctx('chb')
    STONE, MORTAR, STONE_HI = '#a08478', '#5a3e44', '#c0a296'
    s = ''
    s += ashlar(rng, 0, 0, 1000, WALL, 34, STONE, MORTAR, hl=STONE_HI)
    s += fillp(rect_d(0, WALL - 20, 1000, WALL + 2), '#6e5054') + line('M0 %d L1000 %d' % (WALL - 19, WALL - 19), STONE_HI, 1.2, op=0.6)
    roof = [P(rect_d(-10, 0, 1010, 22), WOOD, WOOD_SH, off=(0, -4))]
    for x in range(40, 1000, 120):
        roof.append(P('M%.1f 18 L%.1f 18 L%.1f 36 Q%.1f 44 %.1f 36 Z' % (x - 9, x + 9, x + 7, x, x - 7), WOOD, WOOD_SH, off=(-2, -2)))
    s += draw(ctx, roof, WOOD_LINE, BACK_W)
    # the oculus: a stone ring, quatrefoil tracery, the night sky and stars
    ox, oy, orr = 520, 136, 72
    sky = ctx.radgrad([(0, '#3a4a8a'), (0.7, '#232a5a'), (1, '#161a3a')], cx=0.45, cy=0.4, r=0.6)
    s += '<circle cx="%d" cy="%d" r="%d" fill="%s"/>' % (ox, oy, orr, sky)
    r2 = Rand(77)
    for i in range(14):
        a = r2.u(0, 2 * math.pi)
        rr = r2.u(8, orr - 10)
        s += star4(ox + rr * math.cos(a), oy + rr * math.sin(a), r2.u(1.6, 3.6), '#fff2c8', r2.u(0.6, 1.0))
    s += star4(ox + 30, oy - 26, 6, '#fff6d8', 1.0)
    tr = ''
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        tr += '<circle cx="%.1f" cy="%.1f" r="30" fill="none" stroke="#7a6a80" stroke-width="5"/>' % (ox + 30 * math.cos(a), oy + 30 * math.sin(a))
    tr += '<circle cx="%d" cy="%d" r="14" fill="none" stroke="#7a6a80" stroke-width="5"/>' % (ox, oy)
    tr += line('M%d %d L%d %d M%d %d L%d %d' % (ox - orr, oy, ox + orr, oy, ox, oy - orr, ox, oy + orr), '#7a6a80', 3.4)
    s += '<g clip-path="%s">%s</g>' % (ctx.clip('<circle cx="%d" cy="%d" r="%d"/>' % (ox, oy, orr)), tr)
    ring = []
    for k in range(16):
        a0, a1 = k * math.pi / 8, (k + 1) * math.pi / 8
        pts = [(ox + (orr + 1) * math.cos(a0), oy + (orr + 1) * math.sin(a0)), (ox + (orr + 18) * math.cos(a0), oy + (orr + 18) * math.sin(a0)),
               (ox + (orr + 18) * math.cos(a1), oy + (orr + 18) * math.sin(a1)), (ox + (orr + 1) * math.cos(a1), oy + (orr + 1) * math.sin(a1))]
        ring.append(P(poly_d(pts), '#b89a8e' if k % 2 else '#a88a80', '#7a5e5a', off=(-2, -2)))
    s += draw(ctx, ring, INK, BACK_W)
    # a niche of burnt-out candle stubs (the Vigil's candles, all out but the lectern's)
    s += niche_of_stubs(ctx, rng, 400, 142, 246)
    # the Vigil banner (plum and gold, the crest) behind the lectern
    s += banner(ctx, 150, 236, 48, 218, PLUM, PLUM_SH, GOLD, INK, BACK_W)
    s += hearth(ctx, 862, WALL)
    p.layer('bg', 0.5, s, ctx=ctx)
    # ---------------------------------------------------------------- beam (0.5, lit): the oculus's moonlight
    # The engine draws layers and figures strictly by depth (a lit layer is
    # only left unshaded), so the moonbeam comes in two parts: its top at the
    # window's depth, and (after fg) the rest of it and the pool it throws on
    # the rug at the floor's depth, under the figures standing in it. They
    # cross-fade high up (y 205-250), so however the camera moves the top
    # stays on the window and the foot stays on the novice, and parallax only
    # shears the beam's soft middle.
    ctx = Ctx('chm')
    outer, inner = 'M478 190 L562 190 L668 330 L560 330 Z', 'M500 192 L540 192 L626 312 L578 312 Z'
    g = ctx.lingrad([(0, '#e8e8ff', 0.2), (0.12, '#e4e2ff', 0.16), (0.3, '#dcd8ff', 0.05), (0.43, '#dcd8ff', 0.0)],
                    x1=0, y1=190, x2=0, y2=330, units='userSpaceOnUse')
    beam = '<path d="%s" fill="%s"/>' % (outer, g) + '<path d="%s" fill="%s" opacity="0.8"/>' % (inner, g)
    p.layer('beam', 0.5, beam, lit=True, ctx=ctx, note='the top of the oculus moonbeam; the rest of it is chapel_pool')
    # ---------------------------------------------------------------- fg (1.0)
    ctx = Ctx('chf')
    s = ''
    s += flagstones(rng, WALL, 470, 520, '#86685e', '#3e2c30', rows=6)
    rc = FLOOR + 22
    s += '<path d="%s" fill="#3a1a36"/>' % ell_d(600, rc + 4, 262, 40)
    s += '<path d="%s" fill="#8a3a5a"/>' % ell_d(600, rc, 256, 38)
    s += '<path d="%s" fill="none" stroke="%s" stroke-width="5"/>' % (ell_d(600, rc, 236, 32), GOLD)
    s += '<path d="%s" fill="none" stroke="#b85a7a" stroke-width="3" stroke-dasharray="10 8"/>' % ell_d(600, rc, 208, 27)
    s += '<path d="%s" fill="#a84a6a"/>' % ell_d(600, rc - 2, 160, 19)
    s += crest_svg(600, rc + 2, 28, GOLD, '#3a1a36', '#fff2c8', 1.2)
    # the chancel step Taper stands on, the lectern on it
    t = STEP + 3
    step = [P('M232 %d L432 %d L440 %d L440 %d L226 %d L226 %d Z' % (t - 10, t - 10, t, t + 22, t + 22, t), '#a08478', '#6e5054', off=(-3, -4),
              over=line('M232 %.1f L432 %.1f' % (t - 8.5, t - 8.5), '#c8aa9c', 1.6) + line('M226 %d L440 %d' % (t + 1, t + 1), '#5a3e44', 1.4, op=0.7))]
    s += draw(ctx, step, INK, FRONT_W)
    s += lectern(ctx, lx, STEP)
    s += basket(ctx, 150, FLOOR + 22)
    for x0, sx in ((-10, 1), (1010, -1)):
        pew = [P('M%.1f 470 L%.1f 392 Q%.1f 370 %.1f 366 Q%.1f 356 %.1f 350 Q%.1f 362 %.1f 380 L%.1f 470 Z' % (
            x0, x0, x0 + sx * 30, x0 + sx * 54, x0 + sx * 70, x0 + sx * 84, x0 + sx * 100, x0 + sx * 104, x0 + sx * 104),
            '#6a4028', '#44260e', off=(-sx * 6, -3),
            over=line('M%.1f 404 L%.1f 404 M%.1f 436 L%.1f 436' % (x0 + sx * 8, x0 + sx * 96, x0 + sx * 8, x0 + sx * 96), '#44260e', 2, op=0.8)
            + crest_svg(x0 + sx * 56, 404, 20, '#8a5a36', '#2a160a', '#b07a4c', 1.2))]
        s += draw(ctx, pew, INK, FRONT_W)
    p.layer('fg', 1.0, s, ctx=ctx)
    # ---------------------------------------------------------------- pool (1.0, lit): the beam's foot on the rug
    ctx = Ctx('chp')
    g = ctx.lingrad([(0, '#dcd8ff', 0.0), (0.1, '#dcd8ff', 0.0), (0.36, '#dcd8ff', 0.13), (0.68, '#dcd8ff', 0.1),
                     (0.86, '#dcd8ff', 0.08), (1, '#dcd8ff', 0.0)], x1=0, y1=190, x2=0, y2=330, units='userSpaceOnUse')
    pool = '<path d="%s" fill="%s"/>' % (outer, g) + '<path d="%s" fill="%s" opacity="0.8"/>' % (inner, g)
    pg = ctx.radgrad([(0, '#e8e8ff', 0.26), (0.55, '#dcd8ff', 0.12), (1, '#dcd8ff', 0.0)])
    pool += '<ellipse cx="612" cy="312" rx="92" ry="20" fill="%s"/>' % pg
    p.layer('pool', 1.0, pool, lit=True, ctx=ctx, note='the moonbeam down to its pool on the rug, under the figures')
    return p


def niche_of_stubs(ctx, rng, cx, top, bottom):
    """A round-arched wall niche with two shelves of burnt-out candle stubs."""
    w = 86
    x0, x1 = cx - w / 2, cx + w / 2
    s = '<path d="%s" fill="#3a2e44"/>' % round_arch_d(x0, x1, top, bottom)
    s += '<path d="%s" fill="#2a2034"/>' % round_arch_d(x0 + 6, x1 - 6, top + 8, bottom)
    s += '<path d="%s" fill="none" stroke="#a894a8" stroke-width="3"/>' % round_arch_d(x0 - 2, x1 + 2, top - 2, bottom)
    parts = []
    for sy in (top + 62, bottom - 6):
        parts.append(P(rect_d(x0 + 2, sy, x1 - 2, sy + 7), WOOD, WOOD_SH, off=(0, -2)))
    wicks = ''
    for sy in (top + 62, bottom - 6):
        x = x0 + 12
        while x < x1 - 10:
            h = rng.u(8, 24)
            w2 = rng.u(8, 11)
            cp, wk, _ = candle(ctx, x, sy, w2, h, INK, drips=((0.3, 0.3), (0.75, rng.u(0.2, 0.6))))
            parts += cp
            wicks += wk
            x += w2 + rng.u(4, 9)
    return s + draw(ctx, parts, INK, BACK_W) + wicks


def hearth(ctx, cx, floor):
    """The chapel's fireplace on a floor line: a stone surround with a mantel,
    a soot mouth, logs and a bed of embers (the engine draws the fire's flame
    on top), a chimney breast up into the roof."""
    s = ''
    parts = []
    parts.append(P(rect_d(cx - 70, floor - 330, cx + 70, floor - 96), '#8e7c92', '#62526a', off=(-6, 0),
                   over=''.join(line('M%d %d L%d %d' % (cx - 70, floor - y, cx + 70, floor - y), '#5a4a62', 1.2, op=0.7) for y in (130, 180, 230, 280))))
    parts.append(P(rect_d(cx - 92, floor - 96, cx + 92, floor - 82), '#a894a8', '#6e5e76', off=(-3, -3)))
    mouth = round_arch_d(cx - 50, cx + 50, floor - 62, floor)
    parts.append(P('M%d %d L%d %d L%d %d L%d %d Z' % (cx - 80, floor - 82, cx + 80, floor - 82, cx + 80, floor, cx - 80, floor), '#9a88a0', '#6a5a72',
                   off=(-4, -3)))
    s += draw(ctx, parts, INK, BACK_W)
    soot = ctx.radgrad([(0, '#6a2a14'), (0.55, '#2a120c'), (1, '#120808')], cx=0.5, cy=0.85, r=0.7)
    s += '<path d="%s" fill="%s" stroke="%s" stroke-width="2"/>' % (mouth, soot, INK)
    logs = [P('M%d %d L%d %d Q%d %d %d %d L%d %d Q%d %d %d %d Z' % (cx - 40, floor - 6, cx + 20, floor - 20, cx + 26, floor - 17,
                                                                  cx + 22, floor - 12, cx - 36, floor + 1, cx - 42, floor - 1, cx - 40, floor - 6),
              '#6a4028', '#40240e', off=(-1, -2)),
            P('M%d %d L%d %d Q%d %d %d %d L%d %d Q%d %d %d %d Z' % (cx + 40, floor - 5, cx - 18, floor - 19, cx - 24, floor - 16,
                                                                  cx - 20, floor - 11, cx + 36, floor + 1, cx + 42, floor - 1, cx + 40, floor - 5),
              '#7a4a2c', '#48280e', off=(-1, -2))]
    s += draw(ctx, logs, INK, BACK_W)
    for i, (dx, dy, r) in enumerate(((-24, -6, 4), (-8, -3, 5), (10, -5, 4.4), (26, -3, 3.6), (0, -12, 3), (-16, -14, 2.6), (18, -13, 2.8))):
        s += dot(cx + dx, floor + dy, r, '#ff8a3a' if i % 2 else '#ffb85a') + dot(cx + dx - r * 0.3, floor + dy - r * 0.3, r * 0.4, '#fff0b0')
    for dx, h in ((-22, 16), (20, 13)):
        s += '<path d="%s" fill="%s" stroke="%s" stroke-width="1.2"/>' % (flame_d(cx + dx, floor - 10, 8, h, 1.5), FLAME, '#5a1e0c')
        s += '<path d="%s" fill="%s"/>' % (flame_d(cx + dx, floor - 11, 4, h * 0.55, 0.8), FLAME_CORE)
    # on the mantel: two unlit candlesticks and an hourglass
    m = floor - 96
    parts = []
    wicks = ''
    for dx in (-66, 58):
        parts.append(P('M%d %d L%d %d L%d %d L%d %d Z' % (cx + dx - 7, m, cx + dx + 7, m, cx + dx + 4, m - 8, cx + dx - 4, m - 8), GOLD, GOLD_SH, off=(-1, -1)))
        cp, wk, _ = candle(ctx, cx + dx, m - 8, 8, 26, INK)
        parts += cp
        wicks += wk
    hg = [P('M%d %d L%d %d L%d %d L%d %d Z M%d %d L%d %d L%d %d L%d %d Z' % (cx - 12, m, cx + 12, m, cx + 11, m - 4, cx - 11, m - 4,
                                                                          cx - 11, m - 24, cx + 11, m - 24, cx + 12, m - 28, cx - 12, m - 28), WOOD, WOOD_SH, off=(0, -1)),
          P('M%d %d L%d %d Q%d %d %d %d Q%d %d %d %d L%d %d Q%d %d %d %d Q%d %d %d %d Z' % (
              cx - 9, m - 24, cx + 9, m - 24, cx + 9, m - 14, cx + 2, m - 14, cx + 9, m - 14, cx + 9, m - 4, cx - 9, m - 4, cx - 9, m - 14,
              cx - 2, m - 14, cx - 9, m - 14, cx - 9, m - 24), '#c8d0e8', '#8a90b0', off=(-1, -1),
            over='<path d="M%d %d L%d %d L%d %d Z" fill="#e8c88a"/>' % (cx - 7, m - 4, cx + 7, m - 4, cx, m - 10))]
    s += draw(ctx, parts + hg, INK, BACK_W) + wicks
    return s


def lectern(ctx, cx, floor):
    """A carved lectern with a big open book and three candles on its desk."""
    parts = []
    # the foot and the turned column
    parts.append(P('M%d %d L%d %d L%d %d L%d %d Z' % (cx - 30, floor, cx + 30, floor, cx + 18, floor - 10, cx - 18, floor - 10),
                   WOOD, WOOD_SH, off=(-3, -2)))
    parts.append(P('M%d %d L%d %d L%d %d L%d %d Z' % (cx - 8, floor - 10, cx + 8, floor - 10, cx + 6, floor - 30, cx - 6, floor - 30),
                   WOOD, WOOD_SH, off=(-2, 0)))
    parts.append(E(cx, floor - 34, 11, 6, WOOD, WOOD_SH, off=(-2, -1)))
    parts.append(P('M%d %d L%d %d L%d %d L%d %d Z' % (cx - 6, floor - 36, cx + 6, floor - 36, cx + 5, floor - 22 - 0, cx - 5, floor - 22),
                   WOOD, WOOD_SH, off=(-1, 0)))
    # the slanted desk
    parts.append(P('M%d %d L%d %d L%d %d L%d %d Z' % (cx - 44, floor - 36, cx + 44, floor - 36, cx + 38, floor - 54, cx - 38, floor - 46),
                   WOOD, WOOD_SH, off=(-3, -3), over=line('M%d %d L%d %d' % (cx - 40, floor - 39, cx + 40, floor - 39), WOOD_HI, 1.4, op=0.8)))
    # the open book
    book = [P('M%d %d Q%d %d %d %d L%d %d Q%d %d %d %d Z' % (cx - 34, floor - 44, cx - 17, floor - 54, cx, floor - 50,
                                                           cx, floor - 40, cx - 17, floor - 43, cx - 34, floor - 36), '#f4ead6', '#d8c8a8', off=(-2, -1)),
            P('M%d %d Q%d %d %d %d L%d %d Q%d %d %d %d Z' % (cx + 34, floor - 52, cx + 17, floor - 58, cx, floor - 50,
                                                           cx, floor - 40, cx + 17, floor - 45, cx + 34, floor - 40), '#fff6e6', '#dccca8', off=(1, -1))]
    lines = ''
    for i in range(4):
        y = floor - 47 + i * 2.6
        lines += line('M%d %.1f Q%d %.1f %d %.1f' % (cx - 29, y + 2, cx - 16, y - 3, cx - 5, y - 1), '#8a7a6a', 0.9, op=0.7)
        lines += line('M%d %.1f Q%d %.1f %d %.1f' % (cx + 5, y - 2, cx + 16, y - 5, cx + 29, y - 3), '#8a7a6a', 0.9, op=0.7)
    ribbon = line('M%d %d Q%d %d %d %d' % (cx + 2, floor - 40, cx + 4, floor - 26, cx - 2, floor - 16), '#c83a4a', 2.4)
    # three candles on little brass pans (their flames are the lectern lights)
    wicks = ''
    for x, base, h in ((cx - 32, floor - 42, 14), (cx, floor - 50, 24), (cx + 32, floor - 46, 14)):
        parts.append(P('M%d %d L%d %d L%d %d L%d %d Z' % (x - 7, base, x + 7, base, x + 4, base - 3, x - 4, base - 3), GOLD, GOLD_SH, off=(-1, -1)))
        cp, wk, _ = candle(ctx, x, base - 3, 7, h, INK)
        parts += cp
        wicks += wk
    return draw(ctx, parts + book, INK, FRONT_W) + lines + ribbon + wicks


def basket(ctx, cx, floor):
    parts = [P('M%d %d L%d %d L%d %d L%d %d Z' % (cx - 34, floor - 34, cx + 34, floor - 34, cx + 28, floor, cx - 28, floor),
               '#a87a4a', '#6e4a28', off=(-4, -2),
               over=line(' '.join('M%d %d L%d %d' % (cx - 30 + i * 10, floor - 34, cx - 26 + i * 9, floor) for i in range(7)), '#6e4a28', 1.2, op=0.8)
               + line('M%d %d L%d %d M%d %d L%d %d' % (cx - 33, floor - 22, cx + 33, floor - 22, cx - 31, floor - 11, cx + 31, floor - 11), '#6e4a28', 1.2, op=0.8))]
    tops = []
    for dx, h, lean in ((-18, 24, -8), (-6, 30, -3), (6, 28, 4), (16, 22, 9)):
        tops.append(LIMB('M%d %d L%d %d' % (cx + dx, floor - 30, cx + dx + lean, floor - 30 - h), WAX, 7))
    handle = [LIMB('M%d %d Q%d %d %d %d' % (cx - 30, floor - 34, cx, floor - 78, cx + 30, floor - 34), '#a87a4a', 4)]
    return draw(ctx, handle + tops + parts, INK, FRONT_W)


# ================================================================ Lanternfold (P0)

def window_candle(ctx, x, y, w, h, frame_col, line_col, lit=True, arch=True):
    """A cottage window, warm glass if lit, a candle stub on its sill whose
    wick tip is at (x, y + h/2 - ...). (x, y) is the window's centre.
    Returns (svg, wick_tip)."""
    x0, x1, y0, y1 = x - w / 2, x + w / 2, y - h / 2, y + h / 2
    d = round_arch_d(x0, x1, y0, y1) if arch else rect_d(x0, y0, x1, y1)
    if lit:
        g = ctx.radgrad([(0, '#fff0b8'), (0.55, '#ffc868'), (1, '#e8903a')], cx=0.5, cy=0.7, r=0.7)
    else:
        g = ctx.lingrad([(0, '#3a4a78'), (1, '#1e2444')])
    s = '<path d="%s" fill="%s"/>' % (d, g)
    parts = []
    wick = ''
    tip = None
    if lit:
        cp, wk, tip = candle(ctx, x, y1 - 1.5, w * 0.2, h * 0.24, line_col, drips=((0.3, 0.3), (0.72, 0.5)))
        parts += cp
        wick = wk
    s += draw(ctx, parts, line_col, MID_W) + wick
    s += line('M%.1f %.1f L%.1f %.1f M%.1f %.1f L%.1f %.1f' % (x, y0, x, y1 - h * 0.28, x0, y - h * 0.08, x1, y - h * 0.08), frame_col, 2.4)
    s += '<path d="%s" fill="none" stroke="%s" stroke-width="3.4"/>' % (d, frame_col)
    s += '<path d="%s" fill="none" stroke="%s" stroke-width="1.2"/>' % (d, line_col)
    # the sill, with snow on it
    s += fillp(rrect_d(x0 - 5, y1 - 1, x1 + 5, y1 + 5, 1.5), frame_col) + snowcap(rrect_d(x0 - 6, y1 - 4, x1 + 6, y1 + 0.5, 2), lw=0.8)
    return s, tip


def house(ctx, rng, x0, x1, base, wall_top, peak, wall, roof, lean=0.0, timber=False, chimney=None, windows=(), line_col=INK,
          door=None):
    """A crooked chibi cottage: walls from wall_top to base, a steep snowy roof
    to peak (leaning by lean), a chimney (x, height) with a smoke curl, windows
    [(x, y, w, h, lit)]. Returns (svg, {window index: wick tip})."""
    cx = (x0 + x1) / 2.0
    parts = []
    wd = 'M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (x0 + 2, base, x0, wall_top, x1, wall_top + lean * 0.2, x1 - 2, base)
    over = ''
    if timber:
        tb = '#4a2e1c'
        over += line('M%.1f %.1f L%.1f %.1f M%.1f %.1f L%.1f %.1f M%.1f %.1f L%.1f %.1f' % (
            x0 + 2, wall_top + (base - wall_top) * 0.45, x1 - 2, wall_top + (base - wall_top) * 0.45,
            x0 + (x1 - x0) * 0.33, wall_top, x0 + (x1 - x0) * 0.33, base, x0 + (x1 - x0) * 0.67, wall_top, x0 + (x1 - x0) * 0.67, base), tb, 4)
        over += line('M%.1f %.1f L%.1f %.1f M%.1f %.1f L%.1f %.1f' % (
            x0 + 4, wall_top + 4, x0 + (x1 - x0) * 0.33, wall_top + (base - wall_top) * 0.45,
            x1 - 4, wall_top + 4, x0 + (x1 - x0) * 0.67, wall_top + (base - wall_top) * 0.45), tb, 3)
    else:
        for i in range(int((base - wall_top) / 16)):
            yy = wall_top + 10 + i * 16 + rng.u(-2, 2)
            xa = x0 + rng.u(6, (x1 - x0) * 0.5)
            over += line('M%.1f %.1f L%.1f %.1f' % (xa, yy, xa + rng.u(10, 26), yy), shade_of(wall, 0.8), 1.4, op=0.6)
    parts.append(P(wd, wall, shade_of(wall, 0.78), off=(-6, 0), over=over))
    if chimney:
        chx, chh = chimney
        cy_top = peak + (wall_top - peak) * 0.35 - chh
        parts.append(P(rect_d(chx - 9, cy_top, chx + 9, wall_top - 6), '#7a5a5a', '#5a3e40', off=(-3, 0),
                       over=fillp(rect_d(chx - 11, cy_top - 4, chx + 11, cy_top + 3), '#5a3e40')))
    ov = (x1 - x0) * 0.12
    rd = 'M%.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f L%.1f %.1f Z' % (
        x0 - ov, wall_top + 6, cx + lean, peak, cx + lean + 2, peak + 1, cx + lean + 4, peak + 2, x1 + ov, wall_top + 8)
    shingles = ''
    for k in range(1, 5):
        t = k / 5.0
        ya = peak + (wall_top + 6 - peak) * t
        xa = cx + lean + (x0 - ov - cx - lean) * t
        xb = cx + lean + 4 + (x1 + ov - cx - lean - 4) * t
        shingles += line('M%.1f %.1f L%.1f %.1f' % (xa + 3, ya, xb - 3, ya + 1), shade_of(roof, 0.75), 1.4, op=0.8)
    parts.append(P(rd, roof, shade_of(roof, 0.72), off=(-5, -3), over=shingles))
    s = draw(ctx, parts, line_col, MID_W)
    # snow along the roof edges, a drift on the ridge
    sn = 'M%.1f %.1f L%.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f L%.1f %.1f Z' % (
        x0 - ov - 2, wall_top + 7, cx + lean, peak - 3, x1 + ov + 2, wall_top + 9,
        x1 + ov - 6, wall_top + 13, x1 - (x1 - x0) * 0.2, wall_top - 8 + 2,
        cx + lean + 8, peak + 16, cx + lean - 4, peak + 10,
        x0 + (x1 - x0) * 0.2, wall_top - 8, x0 - ov + 4, wall_top + 12, x0 - ov - 2, wall_top + 7)
    s += snowcap(sn, '#eef2ff', '#aab4dc', line_col, 1.4)
    if chimney:
        s += smoke_curl(chx, cy_top - 6, 60, '#c8cce0', 5, 0.35, 1.0) + smoke_curl(chx + 2, cy_top - 10, 44, '#e8ecf8', 2, 0.5, -0.8)
        s += snowcap(rrect_d(chx - 12, cy_top - 8, chx + 12, cy_top - 2, 3), lw=1)
    tips = {}
    for i, (wx, wy, ww, wh, lit) in enumerate(windows):
        w_s, tip = window_candle(ctx, wx, wy, ww, wh, '#5a3a28', line_col, lit)
        s += w_s
        if tip:
            tips[i] = tip
    if door:
        dx, dw = door
        s += draw(ctx, [P(round_arch_d(dx - dw / 2, dx + dw / 2, base - dw * 1.5, base), '#6a3a2a', '#4a2418', off=(-3, 0),
                          over=line('M%.1f %.1f L%.1f %.1f' % (dx, base - dw * 1.3, dx, base), '#3a1a10', 1.6)
                          + dot(dx + dw * 0.3, base - dw * 0.6, 2, GOLD))], line_col, MID_W)
    return s, tips


def street_lamp(ctx, x, floor, top):
    """An iron street lamp: a post, a curled bracket and a glass lantern whose
    candle's wick tip is returned (the lamp's light)."""
    parts = []
    parts.append(P('M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (x - 12, floor, x + 12, floor, x + 7, floor - 14, x - 7, floor - 14),
                   IRON, IRON_SH, off=(-2, -2)))
    parts.append(LIMB('M%.1f %.1f L%.1f %.1f' % (x, floor - 14, x, top + 40), IRON, 6))
    parts.append(LIMB('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (x, top + 60, x + 14, top + 58, x + 12, top + 44), IRON, 3))
    parts.append(LIMB('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (x, top + 60, x - 14, top + 58, x - 12, top + 44), IRON, 3))
    # the lantern head
    parts.append(P('M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (x - 20, top + 12, x + 20, top + 12, x + 8, top, x - 8, top),
                   IRON, IRON_SH, off=(-2, -2), over=dot(x, top - 3, 3.4, IRON)))
    glass = ctx.radgrad([(0, '#fff6d0'), (0.6, '#ffd070'), (1, '#e8983a')], cx=0.5, cy=0.7, r=0.7)
    parts.append(Part('fill', pth('M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (x - 16, top + 12, x + 16, top + 12, x + 12, top + 40, x - 12, top + 40)),
                      fill=glass, no_shade=True,
                      over=line('M%.1f %.1f L%.1f %.1f' % (x, top + 12, x, top + 40), IRON, 2)))
    parts.append(P(rect_d(x - 14, top + 40, x + 14, top + 46), IRON, IRON_SH, off=(-1, -1)))
    cp, wk, tip = candle(ctx, x, top + 40, 6, 9, INK)
    s = draw(ctx, parts + cp, INK, FRONT_W) + wk
    s += snowcap('M%.1f %.1f Q%.1f %.1f %.1f %.1f L%.1f %.1f Z' % (x - 21, top + 12, x, top - 6, x + 21, top + 12, x - 21, top + 12), lw=1.2)
    return s, tip


def cat_on_wall(ctx, x, top):
    """A little black cat sitting on the wall at (x, top), tail curled down."""
    C, CS = '#2a2434', '#1a1622'
    parts = [LIMB('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (x + 12, top - 4, x + 30, top + 2, x + 24, top + 22), C, 5),
             P('M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z' % (
                 x - 14, top, x - 16, top - 20, x - 8, top - 30, x, top - 30, x + 8, top - 30, x + 16, top - 20, x + 14, top), C, CS, off=(-2, -2)),
             P('M%.1f %.1f L%.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f L%.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f Z' % (
                 x - 12, top - 34, x - 12, top - 52, x - 5, top - 45, x, top - 47, x + 5, top - 45, x + 12, top - 52, x + 12, top - 34,
                 x + 12, top - 22, x, top - 22, x - 12, top - 22, x - 12, top - 34), C, CS, off=(-2, -2))]
    s = draw(ctx, parts, INK, FRONT_W)
    s += '<path d="M%.1f %.1f L%.1f %.1f L%.1f %.1f Z M%.1f %.1f L%.1f %.1f L%.1f %.1f Z" fill="#6a4a6a"/>' % (
        x - 10, top - 44, x - 10, top - 49, x - 6, top - 45, x + 10, top - 44, x + 10, top - 49, x + 6, top - 45)
    return s


# crooked cottages left to right: (x0, x1, wall_top, peak, wall, roof, lean, timber, chimney, windows)
LF_HOUSES = [(-30, 120, 250, 170, '#b8a0c8', '#4a3a6a', -6, False, (70, 30), [(40, 300, 26, 32, False)]),
             (180, 320, 238, 156, '#d8c0a0', '#5a3a4a', 8, True, (290, 34), [(262, 272, 30, 38, True)]),
             (320, 450, 196, 112, '#a8b4d0', '#3a3a64', -10, False, (350, 26), [(390, 238, 30, 40, True), (420, 312, 22, 28, False)]),
             (460, 590, 268, 196, '#e0c8a8', '#6a3a48', 5, True, None, [(520, 298, 30, 36, True)]),
             (590, 712, 222, 138, '#c0a8c8', '#443a6a', -8, False, (690, 34), [(648, 258, 30, 40, True)]),
             (712, 800, 262, 204, '#d8c8b0', '#5a3a4a', 4, True, None, [(770, 292, 28, 34, True)]),
             (880, 990, 268, 200, '#b0bcd8', '#3a3a64', -6, False, (960, 28), [(912, 306, 28, 34, True)]),
             (990, 1150, 232, 150, '#d8c0a0', '#5a3a4a', 10, True, (1100, 34), [(1030, 284, 24, 30, False)]),
             (1150, 1260, 256, 180, '#b8a0c8', '#4a3a6a', -4, False, None, [])]
LF_STREET = (140, 1060)


def lanternfold_town(ctx, rng, tint=None):
    """Lanternfold's cottages; returns (svg, wick tips of the lit windows).
    tint (colour, amount) warms every wall and roof toward a colour (dawn)."""
    s = ''
    lamps = []
    for (x0, x1, wt, pk, wall, roof, lean, timber, ch, wins) in LF_HOUSES:
        if tint:
            wall, roof = mix(wall, tint[0], tint[1]), mix(roof, tint[0], tint[1] * 0.7)
        hs, tips = house(ctx, rng, x0, x1, 400, wt, pk, wall, roof, lean, timber, ch, wins)
        s += hs
        for i in sorted(tips):
            lamps.append(tips[i])
    return s, lamps


def lanternfold():
    p = Panel('lanternfold', 1200, 460, [0.22, 0.24, 0.40], 'snow')
    rng = Rand(2203)
    # lights first. Windows (town, 0.65) hold a candle each; the two street
    # lamps stand in the lane (1.0); the moon glows over it all.
    p.light('moon', 930, 90, 220, 0.4, 'glow', depth=0.3)
    # ---------------------------------------------------------------- sky (0.3)
    ctx = Ctx('lfs')
    sky = vgrad(ctx, [(0, '#40508c'), (0.55, '#6a74b8'), (1, '#9aa0d8')])
    s = '<rect x="0" y="0" width="1200" height="460" fill="%s"/>' % sky
    # far hills, Evenbell's spire tip tilting out of the far one
    s += fillp('M0 300 Q120 250 260 272 Q380 236 520 262 Q640 230 760 250 Q820 226 900 246 Q1040 220 1200 262 L1200 460 L0 460 Z', '#4a4c80')
    s += fillp('M0 330 Q160 290 330 306 Q470 280 600 300 Q760 272 880 292 Q1020 276 1200 300 L1200 460 L0 460 Z', '#3a3c6c')
    s += spire_tip(ctx, 826, 262, 12)
    s += fillp('M700 272 Q780 238 840 256 Q900 248 960 266 L960 300 L700 300 Z', '#4a4c80')
    p.layer('sky', 0.3, s, ctx=ctx)
    # ---------------------------------------------------------------- moon (0.3, lit)
    ctx = Ctx('lfm')
    s = ''
    r2 = Rand(58)
    for i in range(46):
        x, y = r2.u(10, 1190), r2.u(8, 128)
        if math.hypot(x - 930, y - 90) < 90:
            continue
        s += star4(x, y, r2.u(1.4, 3.4), '#fff4d8', r2.u(0.4, 0.95))
    s += moon_svg(ctx, 930, 90, 44)
    # a cloud drifting across its lower half
    s += '<path d="%s" fill="#b8b8e8" opacity="0.85"/>' % cloud_d(858, 122, 150, 36)
    s += '<path d="%s" fill="#8a8ac8" opacity="0.7"/>' % cloud_d(870, 128, 120, 16)
    p.layer('moon', 0.3, s, lit=True, ctx=ctx, note='the moon and stars; kept above y 140, clear of the roofs')
    # ---------------------------------------------------------------- town (0.65)
    ctx = Ctx('lft')
    s = ''
    town, lamps = lanternfold_town(ctx, rng)
    s += town
    p.layer('town', 0.65, s, ctx=ctx)
    # ---------------------------------------------------------------- lane (1.0)
    ctx = Ctx('lfl')
    s = ''
    # the snowy lane: cobbles under a blanket of snow, drifts at the edges
    s += fillp('M-10 372 L1210 372 L1210 470 L-10 470 Z', '#6a6a98')
    for row, (y0, y1, n) in enumerate(((378, 392, 30), (392, 410, 26), (410, 432, 22), (432, 470, 18))):
        step = 1220.0 / n
        off = rng.u(0, step * 0.5)
        for j in range(-1, n + 1):
            xa = -10 + off + j * step
            s += fillp(rrect_d(xa + 2, y0 + 2, xa + step - 2, y1 - 1.5, 5), mix('#8a8ab8', '#ffffff', rng.u(0, 0.12)))
    s += fillp('M-10 366 Q200 358 400 368 Q600 376 800 366 Q1000 358 1210 368 L1210 384 Q900 378 600 388 Q300 380 -10 386 Z', '#e8ecff')
    s += fillp('M-10 440 Q180 426 360 446 Q560 462 760 444 Q980 428 1210 446 L1210 470 L-10 470 Z', '#dfe4ff')
    # a stone wall with a cat on it, picket fences either side
    wall = [P(rect_d(430, 330, 770, 380), '#8a86a8', '#62608a', off=(-4, -3),
              over=''.join(line('M%d %d L%d %d' % (x, 330, x, 380), '#4a4870', 1.4, op=0.7) for x in range(470, 770, 44))
              + line('M430 355 L770 355', '#4a4870', 1.4, op=0.7))]
    s += draw(ctx, wall, INK, FRONT_W)
    s += snowcap('M424 334 Q480 318 540 326 Q600 320 660 326 Q720 318 776 332 L776 338 L424 338 Z', lw=1.4)
    s += cat_on_wall(ctx, 560, 326)
    for fx0, fx1 in ((250, 430), (770, 990)):
        pk = []
        for x in range(int(fx0) + 8, int(fx1), 20):
            pk.append(P('M%d 384 L%d 346 L%d 338 L%d 346 L%d 384 Z' % (x - 6, x - 6, x, x + 6, x + 6), '#c8b89a', '#8a7a64', off=(-2, 0)))
        pk.append(P(rect_d(fx0, 352, fx1, 358), '#a8987a', '#7a6a54', off=(0, -1)))
        pk.append(P(rect_d(fx0, 370, fx1, 376), '#a8987a', '#7a6a54', off=(0, -1)))
        s += draw(ctx, pk, INK, FRONT_W)
    # the old well (a bucket on a rope, a little roof)
    s += well(ctx, 190, 396)
    # the street lamps at either end
    for lx in LF_STREET:
        ls, tip = street_lamp(ctx, lx, 404, 190)
        s += ls
        lamps.append(tip)
    p.layer('lane', 1.0, s, ctx=ctx)
    # the eight lamps, numbered left to right (lamp1 and lamp8 the street lamps)
    lamps.sort(key=lambda t: t[0])
    for i, (x, y) in enumerate(lamps):
        street = i in (0, len(lamps) - 1)
        p.light('lamp%d' % (i + 1), x, y, 110 if street else 84, 1.0 if street else 0.9, 'flame', h=13 if street else 8,
                depth=1.0 if street else 0.65)
    p.light('cat', 560, 283, 26, 0.35, 'eyes', depth=1.0, color='e8d86a', pts=[[554.5, 284], [565.5, 284]], dot=1.8)
    return p


def spire_tip(ctx, x, y, tilt):
    """Evenbell's spire tip poking out of the far hill at (x, y), tilted: a
    belfry with a tiny dark bell under a pointed spire and a finial."""
    t = 'rotate(%.1f %.1f %.1f)' % (tilt, x, y)
    stone, sh = '#6a5a92', '#4a3e72'
    s = ''
    s += fillp('M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (x - 26, y + 10, x - 24, y - 70, x + 24, y - 70, x + 26, y + 10), stone)
    s += fillp(arch_d(x - 14, x + 14, y - 64, y - 26), '#1a1630')
    s += fillp(bell_d(x, y - 50, 14, 14), '#3a2e48')
    s += fillp('M%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (x - 30, y - 70, x, y - 150, x + 30, y - 70), sh)
    s += fillp('M%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (x - 30, y - 70, x, y - 150, x - 6, y - 70), stone)
    for k in range(1, 4):
        yy = y - 70 - k * 20
        ww = 30 * (1 - k * 20 / 80.0)
        s += dot(x - ww - 2, yy, 2.6, stone) + dot(x + ww + 2, yy, 2.6, sh)
    s += line('M%.1f %.1f L%.1f %.1f M%.1f %.1f L%.1f %.1f' % (x, y - 150, x, y - 166, x - 6, y - 160, x + 6, y - 160), '#8a7ab8', 2.4)
    return '<g transform="%s">%s</g>' % (t, s)


def well(ctx, x, floor):
    parts = [LIMB('M%.1f %.1f L%.1f %.1f M%.1f %.1f L%.1f %.1f' % (x - 34, floor - 30, x - 34, floor - 96, x + 34, floor - 30, x + 34, floor - 96), WOOD, 5),
             P('M%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (x - 50, floor - 92, x, floor - 128, x + 50, floor - 92), '#5a3a4a', '#3a2432', off=(-3, -2)),
             LIMB('M%.1f %.1f L%.1f %.1f' % (x - 34, floor - 76, x + 34, floor - 76), WOOD, 4),
             LIMB('M%.1f %.1f L%.1f %.1f' % (x + 4, floor - 76, x + 4, floor - 54), '#c8a060', 1.6),
             P('M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (x - 5, floor - 54, x + 13, floor - 54, x + 11, floor - 40, x - 3, floor - 40), WOOD, WOOD_SH, off=(-1, -1)),
             P('M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (x - 40, floor, x + 40, floor, x + 38, floor - 36, x - 38, floor - 36), '#8a86a8', '#62608a',
               off=(-4, -2), over=line('M%.1f %.1f L%.1f %.1f M%.1f %.1f L%.1f %.1f' % (x - 38, floor - 18, x + 38, floor - 18, x - 10, floor - 36, x - 10, floor), '#4a4870', 1.4, op=0.7))]
    s = draw(ctx, parts, INK, FRONT_W)
    s += snowcap('M%.1f %.1f L%.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f Z' % (x - 52, floor - 90, x, floor - 130, x + 52, floor - 90, x, floor - 108, x - 52, floor - 90), lw=1.2)
    s += snowcap('M%.1f %.1f Q%.1f %.1f %.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (x - 42, floor - 34, x, floor - 46, x + 42, floor - 34, x + 42, floor - 30, x - 42, floor - 30), lw=1.2)
    return s


# ================================================================ glass_legend (P0): three stained-glass lancets

LANCET = (90, 710, 16, 444, 200)    # x0, x1, apex, sill, spring (tile-local units; the lancet centred on x 400)


def lancet_d(inset=0.0):
    x0, x1, apex, sill, spring = LANCET
    x0, x1, apex, sill = x0 + inset, x1 - inset, apex + inset * 1.3, sill - inset
    cx = (x0 + x1) / 2.0
    w = x1 - x0
    return 'M%.1f %.1f L%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f L%.1f %.1f Z' % (
        x0, sill, x0, spring, x0, spring - 80, cx - w * 0.27, apex + 24, cx, apex,
        cx + w * 0.27, apex + 24, x1, spring - 80, x1, spring, x1, sill)


def lancet_outline(inset, step):
    """Points (x, y, tangent angle) every step units along the lancet outline, inset."""
    x0, x1, apex, sill, spring = LANCET
    x0, x1, apex, sill = x0 + inset, x1 - inset, apex + inset * 1.3, sill - inset
    cx = (x0 + x1) / 2.0
    w = x1 - x0

    def cubic(p0, p1, p2, p3, t):
        u = 1 - t
        return (u * u * u * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t * t * t * p3[0],
                u * u * u * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t * t * t * p3[1])
    pts = []
    for i in range(60):
        pts.append((x0, sill - (sill - spring) * i / 60.0))
    for i in range(80):
        pts.append(cubic((x0, spring), (x0, spring - 80), (cx - w * 0.27, apex + 24), (cx, apex), i / 80.0))
    for i in range(80):
        pts.append(cubic((cx, apex), (cx + w * 0.27, apex + 24), (x1, spring - 80), (x1, spring), i / 80.0))
    for i in range(61):
        pts.append((x1, spring + (sill - spring) * i / 60.0))
    out = []
    acc = step / 2.0
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        seg = math.hypot(bx - ax, by - ay)
        while acc <= seg and seg > 0:
            t = acc / seg
            out.append((ax + (bx - ax) * t, ay + (by - ay) * t, math.degrees(math.atan2(by - ay, bx - ax))))
            acc += step
        acc -= seg
    return out


def mosaic(G, rng, x0, y0, x1, y1, cw, ch, color_at, came=3.4):
    """A background of jittered quarry panes; color_at(x, y, rng) picks each colour."""
    cols = int((x1 - x0) / cw) + 2
    rows = int((y1 - y0) / ch) + 2
    grid = {}
    for j in range(rows + 1):
        for i in range(cols + 1):
            jx = rng.u(-cw * 0.28, cw * 0.28) if 0 < i < cols else 0
            jy = rng.u(-ch * 0.28, ch * 0.28) if 0 < j < rows else 0
            grid[(i, j)] = (x0 - cw * 0.5 + i * cw + jx, y0 - ch * 0.5 + j * ch + jy)
    s = ''
    for j in range(rows):
        for i in range(cols):
            q = [grid[(i, j)], grid[(i + 1, j)], grid[(i + 1, j + 1)], grid[(i, j + 1)]]
            mx = sum(p_[0] for p_ in q) / 4
            my = sum(p_[1] for p_ in q) / 4
            s += G.quad(q, color_at(mx, my, rng), came)
    return s


def pane(G, d, col, box, came=6.0):
    return G.pane(d, col, came, box=box)


def keeper(G, x, y, k, robe, face_right=True):
    """A tiny kneeling keeper in glass: a hooded head with a candle, a robe."""
    sx = 1 if face_right else -1
    s = ''
    body = 'M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f L%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z' % (
        x - 26 * k * sx, y, x - 30 * k * sx, y - 26 * k, x - 14 * k * sx, y - 48 * k, x + 4 * k * sx, y - 48 * k,
        x + 24 * k * sx, y - 26 * k, x + 30 * k * sx, y - 10 * k, x + 30 * k * sx, y - 6 * k, x + 28 * k * sx, y)
    s += pane(G, body, robe, (x - 30 * k, y - 48 * k, x + 30 * k, y), 5)
    hd = ell_d(x + 6 * k * sx, y - 58 * k, 15 * k, 14 * k)
    s += pane(G, hd, robe, (x - 10 * k, y - 72 * k, x + 20 * k, y - 44 * k), 5)
    s += pane(G, ell_d(x + 12 * k * sx, y - 56 * k, 7 * k, 8 * k), GLASS['flame'], None, 3.4)
    s += pane(G, rect_d(x + 2 * k * sx - 4 * k, y - 84 * k, x + 2 * k * sx + 4 * k, y - 71 * k), GLASS['ivory'], None, 3)
    s += pane(G, flame_d(x + 2 * k * sx, y - 84 * k, 10 * k, 18 * k), GLASS['gold'], None, 3)
    # hands together toward the light
    s += pane(G, ell_d(x + 24 * k * sx, y - 30 * k, 7 * k, 6 * k), GLASS['flame'], None, 3.4)
    return s


def glass_bell(G, cx, top, w, h, rot, crack=False):
    t = 'rotate(%.1f %.1f %.1f)' % (rot, cx, top)
    s = pane(G, bell_d(cx, top, w, h), GLASS['bronze'], (cx - w / 2, top, cx + w / 2, top + h), 5)
    s += pane(G, rect_d(cx - w * 0.3, top + h * 0.16, cx - w * 0.12, top + h * 0.8), '#e8b860', None, 3)
    s += pane(G, ell_d(cx, top + h + 5, w * 0.12, w * 0.12), '#7a5a3a', None, 3.4)
    if crack:
        s += line('M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f' % (cx + w * 0.1, top + 2, cx - w * 0.06, top + h * 0.35,
                                                             cx + w * 0.14, top + h * 0.6, cx - w * 0.02, top + h), CAME, 5)
    return '<g transform="%s">%s</g>' % (t, s)


def cathedral_glass(G, cx, base, k, cracked=False, bell_rot=(0, 0), stone='#d8cce8', stone2='#b0a0d0', roof='#7a5a8a'):
    """Evenbell in glass from outside: two tall belfry towers with spires, a
    nave with a steep roof and a rose window."""
    s = ''
    for tx, rot in ((cx - 128 * k, bell_rot[0]), (cx + 128 * k, bell_rot[1])):
        s += pane(G, rect_d(tx - 36 * k, base - 250 * k, tx + 36 * k, base), stone2, (tx - 36 * k, base - 250 * k, tx + 36 * k, base))
        s += pane(G, 'M%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (tx - 42 * k, base - 250 * k, tx, base - 340 * k, tx + 42 * k, base - 250 * k),
                  roof, (tx - 42 * k, base - 340 * k, tx + 42 * k, base - 250 * k))
        s += pane(G, arch_d(tx - 24 * k, tx + 24 * k, base - 236 * k, base - 160 * k), '#1e2a5a', (tx - 24 * k, base - 236 * k, tx + 24 * k, base - 160 * k), 5)
        s += glass_bell(G, tx, base - 226 * k, 38 * k, 40 * k, rot, crack=cracked)
        s += pane(G, arch_d(tx - 11 * k, tx + 11 * k, base - 128 * k, base - 80 * k), '#3a6ab8', None, 4)
    s += pane(G, rect_d(cx - 92 * k, base - 176 * k, cx + 92 * k, base), stone, (cx - 92 * k, base - 176 * k, cx + 92 * k, base))
    s += pane(G, 'M%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (cx - 100 * k, base - 176 * k, cx, base - 262 * k, cx + 100 * k, base - 176 * k),
              roof, (cx - 100 * k, base - 262 * k, cx + 100 * k, base - 176 * k))
    rr = 26 * k
    s += pane(G, ell_d(cx, base - 132 * k, rr, rr), GLASS['gold'], None, 5)
    for a in range(0, 360, 45):
        t = math.radians(a)
        s += pane(G, ell_d(cx + rr * 0.55 * math.cos(t), base - 132 * k + rr * 0.55 * math.sin(t), rr * 0.28, rr * 0.28), GLASS['ruby'], None, 3)
    for dx in (-54, 54):
        s += pane(G, arch_d(cx + dx * k - 14 * k, cx + dx * k + 14 * k, base - 120 * k, base - 50 * k), '#3a6ab8', None, 4)
    s += pane(G, arch_d(cx - 20 * k, cx + 20 * k, base - 70 * k, base), '#4a3040', None, 4)
    return s


def cathedral_cut(G, cx, base, k):
    """Evenbell in cross-section: its walls a stone frame, the bells swinging
    in the towers, the Undercandle burning big in the crypt, and the bells'
    breath flowing down to it in cobalt bands."""
    s = ''
    stone, stone2, inside = '#d8cce8', '#b0a0d0', '#1e2a5a'
    # the building's outline, then its dark inside
    for tx in (cx - 132 * k, cx + 132 * k):
        s += pane(G, rect_d(tx - 44 * k, base - 262 * k, tx + 44 * k, base), stone2, (tx - 44 * k, base - 262 * k, tx + 44 * k, base))
        s += pane(G, 'M%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (tx - 50 * k, base - 262 * k, tx, base - 344 * k, tx + 50 * k, base - 262 * k),
                  GLASS['ruby'], (tx - 50 * k, base - 344 * k, tx + 50 * k, base - 262 * k))
    s += pane(G, rect_d(cx - 88 * k, base - 190 * k, cx + 88 * k, base), stone, (cx - 88 * k, base - 190 * k, cx + 88 * k, base))
    s += pane(G, 'M%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (cx - 96 * k, base - 190 * k, cx, base - 268 * k, cx + 96 * k, base - 190 * k),
              GLASS['ruby'], (cx - 96 * k, base - 268 * k, cx + 96 * k, base - 190 * k))
    for tx in (cx - 132 * k, cx + 132 * k):
        s += pane(G, rect_d(tx - 28 * k, base - 248 * k, tx + 28 * k, base - 14 * k), inside, None, 5)
        s += pane(G, rect_d(tx - 28 * k, base - 176 * k, tx + 28 * k, base - 168 * k), stone2, None, 3)
    s += pane(G, 'M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (
        cx - 74 * k, base - 14 * k, cx - 74 * k, base - 176 * k, cx, base - 236 * k, cx + 74 * k, base - 176 * k, cx + 74 * k, base - 14 * k),
        inside, None, 5)
    # the crypt floor and the candle, burning big
    s += pane(G, rect_d(cx - 74 * k, base - 22 * k, cx + 74 * k, base - 14 * k), stone2, None, 3)
    s += pane(G, rect_d(cx - 11 * k, base - 62 * k, cx + 11 * k, base - 22 * k), GLASS['ivory'], None, 4)
    s += pane(G, flame_d(cx, base - 62 * k, 50 * k, 84 * k, 3), GLASS['gold'], None, 4)
    s += pane(G, flame_d(cx + 1, base - 64 * k, 28 * k, 48 * k, 2), GLASS['flame'], None, 3)
    # the breath: a band from each bell down and in to the flame
    for sx in (-1, 1):
        bx = cx + sx * 132 * k
        d = ('M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f '
             'L%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z') % (
            bx - sx * 12 * k, base - 196 * k, bx - sx * 30 * k, base - 150 * k, bx + sx * 20 * k, base - 120 * k, bx - sx * 8 * k, base - 80 * k,
            bx - sx * 28 * k, base - 50 * k, cx + sx * 40 * k, base - 110 * k, cx + sx * 12 * k, base - 76 * k,
            cx + sx * 26 * k, base - 72 * k, cx + sx * 54 * k, base - 118 * k, bx - sx * 12 * k, base - 56 * k, bx + sx * 10 * k, base - 84 * k,
            bx + sx * 36 * k, base - 122 * k, bx - sx * 8 * k, base - 150 * k, bx + sx * 10 * k, base - 196 * k)
        s += pane(G, d, '#8ab8f0', (min(bx, cx) - 20, base - 196 * k, max(bx, cx) + 20, base - 50 * k), 4)
    for tx, rot in ((cx - 132 * k, 20), (cx + 132 * k, -20)):
        s += glass_bell(G, tx, base - 244 * k, 40 * k, 42 * k, rot)
        for r0 in (32, 42):
            sx = 1 if rot > 0 else -1
            s += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (tx - sx * r0 * k, base - 238 * k, tx - sx * (r0 + 10) * k, base - 214 * k,
                                                         tx - sx * r0 * k, base - 190 * k), GLASS['flame'], 4)
    return s


def glass_tile(idx):
    """One lancet (0 The Undercandle, 1 The Bells, 2 The Sinking), tile-local
    coordinates 0..800, with the dark wall and stone moulding around it."""
    ctx = Ctx('gl%d' % idx)
    G = Glass(ctx)
    rng = Rand(4000 + idx * 17)
    s = ''
    # the dark wall and its courses
    s += fillp(rect_d(0, 0, 800, 460), '#1d1526')
    y = 0
    row = 0
    while y < 460:
        x = -(rng.u(0, 60) if row % 2 else 0)
        while x < 800:
            w = rng.u(70, 120)
            s += fillp(rrect_d(x + 2, y + 2, x + w - 2, y + 44, 3), mix('#261c32', '#000000', rng.u(0, 0.2)))
            x += w
        y += 46
        row += 1
    # the moulding round the window
    s += '<path d="%s" fill="#3a3148"/>' % lancet_d(-18)
    s += '<path d="%s" fill="none" stroke="#54496a" stroke-width="4"/>' % lancet_d(-14)
    s += '<path d="%s" fill="#140e1c"/>' % lancet_d(-3)
    clip = ctx.clip('<path d="%s"/>' % lancet_d(22))
    pic = ''
    if idx == 0:
        def col(x, y, r):
            if y > 356:
                return r.pick([GLASS['hush_dk'], GLASS['hush'], '#3a2c64'])
            if y > 300:
                return r.pick([GLASS['green'], '#4a8a50', GLASS['green']])
            return r.pick([GLASS['cobalt'], GLASS['cobalt'], '#2a4a8a', '#4a7ac8'])
        pic += mosaic(G, rng, 100, 30, 700, 440, 46, 40, col)
        # a sunburst behind the flame
        cx, cy = 400, 112
        for k in range(36):
            a0 = math.radians(k * 10 - 5)
            a1 = math.radians(k * 10 + 5)
            q = [(cx, cy), (cx + 420 * math.cos(a0), cy + 420 * math.sin(a0)), (cx + 420 * math.cos(a1), cy + 420 * math.sin(a1))]
            pic += G.quad(q, GLASS['gold'] if k % 2 else '#f0d27a', 4.4)
        pic += pane(G, ell_d(cx, cy, 104, 104), '#f6e2a0', None, 5)
        # the ground round the pit, then the pit: rings of Hush violet, two tiny pale eyes
        pic += pane(G, 'M100 296 Q250 262 400 268 Q550 262 700 296 L700 460 L100 460 Z', GLASS['green'], (100, 262, 700, 460))
        pic += pane(G, 'M100 360 Q250 340 400 350 Q550 340 700 360 L700 460 L100 460 Z', '#3a2c64', (100, 340, 700, 460))
        for rx, ry, c in ((236, 56, GLASS['hush']), (176, 42, '#3a2c64'), (114, 27, GLASS['hush_dk']), (58, 14, '#120c20')):
            pic += pane(G, ell_d(400, 326, rx, ry), c, (400 - rx, 326 - ry, 400 + rx, 326 + ry), 5)
        for ex in (385, 415):
            pic += pane(G, ell_d(ex, 326, 6.4, 4.2), '#e8e4ff', None, 3)
        # the Undercandle on its gold stand, its great flame
        pic += pane(G, 'M350 300 L450 300 L438 284 L362 284 Z', GLASS['gold'], (350, 284, 450, 300))
        pic += pane(G, 'M378 314 L422 314 L412 300 L388 300 Z', GLASS['gold'], None, 5)
        pic += pane(G, rect_d(364, 176, 436, 286), GLASS['ivory'], (364, 176, 436, 286))
        pic += pane(G, rect_d(414, 176, 436, 286), '#cdbf9c', None, 4)
        for dx, ln in ((378, 40), (402, 62), (426, 28)):
            pic += pane(G, rrect_d(dx - 7, 172, dx + 7, 172 + ln, 7), '#fffaec', None, 4)
        pic += pane(G, flame_d(400, 180, 110, 128, 6), GLASS['gold'], (345, 52, 455, 180))
        pic += pane(G, flame_d(401, 176, 74, 90, 4), '#ffd98a', None, 5)
        pic += pane(G, flame_d(402, 172, 40, 52, 2), GLASS['flame'], None, 4)
        # three keepers kneeling round it, candles on their heads
        pic += keeper(G, 206, 300, 1.35, GLASS['ruby'], True)
        pic += keeper(G, 290, 318, 1.05, GLASS['green'], True)
        pic += keeper(G, 594, 302, 1.35, '#6a5ab8', False)
    elif idx == 1:
        def col(x, y, r):
            if y > 330:
                return r.pick([GLASS['green'], '#4a8a50'])
            return r.pick([GLASS['cobalt'], '#2a4a8a', GLASS['cobalt'], '#4a7ac8'])
        pic += mosaic(G, rng, 100, 30, 700, 440, 46, 40, col)
        for x, y, r in ((170, 90, 10), (620, 70, 9), (540, 150, 7), (250, 170, 7), (660, 200, 8), (140, 240, 8), (400, 50, 9)):
            pic += G.pane(poly_d([(x, y - r), (x + r * 0.3, y - r * 0.3), (x + r, y), (x + r * 0.3, y + r * 0.3), (x, y + r),
                                   (x - r * 0.3, y + r * 0.3), (x - r, y), (x - r * 0.3, y - r * 0.3)]), GLASS['gold'], 3, sliver=False)
        # the hill, and Evenbell in cross-section on it
        pic += pane(G, 'M100 360 Q260 322 400 332 Q560 322 700 350 L700 460 L100 460 Z', GLASS['green'], (100, 322, 700, 460))
        pic += pane(G, 'M100 400 Q260 380 400 388 Q560 380 700 396 L700 460 L100 460 Z', '#4a8a50', (100, 380, 700, 460))
        pic += cathedral_cut(G, 400, 358, 0.8)
    else:
        def col(x, y, r):
            edge = min(x - 100, 700 - x)
            if y > 300 - (160 - edge) * 1.4 and edge < 160:
                return r.pick([GLASS['hush'], GLASS['hush_dk'], '#3a2c64'])
            return r.pick(['#2a4a8a', '#23407a', GLASS['cobalt'], '#34306e'])
        pic += mosaic(G, rng, 100, 30, 700, 440, 46, 40, col)
        # the crescent moon and a few stars
        moon = 'M596 92 C566 94 550 124 560 150 C570 176 604 184 628 168 C606 172 584 160 578 138 C572 114 580 100 596 92 Z'
        pic += pane(G, moon, GLASS['flame'], (550, 92, 628, 184), 5)
        for x, y, r in ((210, 90, 7), (320, 60, 6), (640, 210, 6)):
            pic += G.pane(poly_d([(x, y - r), (x + r * 0.3, y - r * 0.3), (x + r, y), (x + r * 0.3, y + r * 0.3), (x, y + r),
                                   (x - r * 0.3, y + r * 0.3), (x - r, y), (x - r * 0.3, y - r * 0.3)]), '#e8c860', 3, sliver=False)
        # the cathedral tilting into the hill, its bells hanging still and cracked
        pic += '<g transform="rotate(-11 380 330)">%s</g>' % cathedral_glass(G, 372, 366, 0.84, cracked=True)
        pic += pane(G, 'M100 292 Q210 250 330 280 Q420 300 520 262 Q620 232 700 262 L700 460 L100 460 Z', GLASS['earth'], (100, 232, 700, 460))
        pic += pane(G, 'M100 360 Q260 330 400 352 Q560 370 700 334 L700 460 L100 460 Z', GLASS['earth_dk'], (100, 330, 700, 460))
        # the small flame, still burning through a crack in the hill
        pic += pane(G, 'M394 318 L410 300 L426 318 L416 330 L402 330 Z', '#140e1c', None, 3)
        pic += pane(G, flame_d(410, 318, 12, 20, 1), GLASS['gold'], None, 3)
        # the Hush creeping up both sides
        for sx in (-1, 1):
            x0 = 400 + sx * 300
            d = 'M%.1f 460 C%.1f 400 %.1f 330 %.1f 250 C%.1f 200 %.1f 160 %.1f 120 C%.1f 170 %.1f 220 %.1f 280 C%.1f 340 %.1f 400 %.1f 460 Z' % (
                x0, x0 - sx * 40, x0 - sx * 70, x0 - sx * 40, x0 - sx * 20, x0 - sx * 50, x0 - sx * 10,
                x0 + sx * 10, x0, x0 - sx * 10, x0 - sx * 120, x0 - sx * 150, x0 - sx * 110)
            pic += pane(G, d, GLASS['hush'], (min(x0, x0 - sx * 150), 120, max(x0, x0 - sx * 150), 460), 5)
            for ey in (300, 372):
                pic += pane(G, ell_d(x0 - sx * 52, ey, 5, 3.4), '#e8e4ff', None, 2.6)
    # the iron saddle bars across the glass
    pic += line('M100 176 L700 176 M100 300 L700 300', CAME, 6)
    s += '<g clip-path="%s">%s</g>' % (clip, pic)
    # the border of little squares round the picture
    for i, (x, y, a) in enumerate(lancet_outline(10, 17)):
        c = (GLASS['ruby'], GLASS['cobalt'], GLASS['gold'])[i % 3]
        t = 'rotate(%.1f %.1f %.1f)' % (a, x, y)
        s += '<g transform="%s">%s</g>' % (t, G.pane(rect_d(x - 7, y - 7, x + 7, y + 7), c, 2.6, sliver=False))
    s += '<path d="%s" fill="none" stroke="%s" stroke-width="7"/>' % (lancet_d(0), CAME)
    s += '<path d="%s" fill="none" stroke="%s" stroke-width="6"/>' % (lancet_d(20), CAME)
    return ctx, s


def mullion(ctx, x):
    """A stone column (a near layer) standing between two lancets."""
    parts = [P(rect_d(x - 26, -46, x + 26, 510), '#3a3148', '#2a2236', off=(-10, 0),
               over=line('M%.1f -46 L%.1f 510' % (x - 16, x - 16), '#54496a', 3, op=0.9) + line('M%.1f -46 L%.1f 510' % (x + 12, x + 12), '#221a2c', 2, op=0.8)),
             P('M%.1f 148 L%.1f 148 L%.1f 166 L%.1f 166 Z' % (x - 44, x + 44, x + 28, x - 28), '#4a3f5e', '#2e2640', off=(-4, -3),
               over=line('M%.1f 152 Q%.1f 162 %.1f 152 M%.1f 152 Q%.1f 162 %.1f 152' % (x - 34, x - 18, x - 4, x + 4, x + 18, x + 34), '#221a2c', 1.6)),
             P(rect_d(x - 50, 136, x + 50, 148), '#54496a', '#3a3148', off=(-3, -3)),
             P('M%.1f 420 L%.1f 420 L%.1f 446 L%.1f 446 Z' % (x - 30, x + 30, x + 44, x - 44), '#4a3f5e', '#2e2640', off=(-4, -3)),
             P(rect_d(x - 50, 446, x + 50, 510), '#3a3148', '#2a2236', off=(-4, -3))]
    return draw(ctx, parts, '#0c0812', FRONT_W)


def glass_legend():
    p = Panel('glass_legend', 2400, 460, None, None, shimmer=True,
              tiles='glass_a/b/c are the three lancets side by side (x 0, 800, 1600); mullions m0..m3 stand at x 0, 800, 1600, 2400')
    for i, name in enumerate(('a', 'b', 'c')):
        ctx, body = glass_tile(i)
        p.layer('glass_' + name, 1.0, body, lit=True, rect=(i * 800, 0, 800, 460), ctx=ctx,
                note=('The Undercandle', 'The Bells', 'The Sinking')[i])
        p.files['art/story/sets/glass_legend_glass_%s.svg' % name] = p.files.pop('art/story/sets/glass_legend_glass_%s.svg' % name).replace(
            'viewBox="%d 0 800 460"' % (i * 800), 'viewBox="0 0 800 460"')
    for i in range(4):
        ctx = Ctx('glm%d' % i)
        x = i * 800
        p.layer('m%d' % i, 1.12, '<g transform="translate(%d 0)">%s</g>' % (x - 90, mullion(ctx, 90)), lit=True,
                rect=(x - 90, -46, 180, 552), ctx=ctx)
        key = 'art/story/sets/glass_legend_m%d.svg' % i
        vb = 'viewBox="%s -46 180 552"' % (x - 90)
        p.files[key] = p.files[key].replace(vb, 'viewBox="0 -46 180 552"').replace(
            '<g transform="translate(%d 0)">' % (x - 90), '<g>')
    return p


# ================================================================ callings (P0): the apse of five plinths

def cushion(ctx, cx, top, w):
    """A velvet cushion with gold tassels, its top at y top."""
    parts = [P('M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z' % (
        cx - w / 2, top + 10, cx - w / 2 + 4, top - 4, cx + w / 2 - 4, top - 4, cx + w / 2, top + 10,
        cx + w / 2 - 6, top + 20, cx - w / 2 + 6, top + 20, cx - w / 2, top + 10), '#9a2a42', '#6a1a2e', off=(-4, -3),
        over=line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (cx - w * 0.36, top + 4, cx, top, cx + w * 0.36, top + 4), '#c85a70', 2, op=0.8))]
    for sx in (-1, 1):
        x = cx + sx * (w / 2 - 2)
        parts.append(LIMB('M%.1f %.1f L%.1f %.1f' % (x, top + 10, x + sx * 3, top + 22), GOLD, 3))
        parts.append(E(x + sx * 3, top + 24, 3.4, 4, GOLD, GOLD_SH, off=(-1, -1)))
    return draw(ctx, parts, INK, FRONT_W)


def plinth(ctx, cx, top, floor, w):
    parts = [P(rect_d(cx - w * 0.5, floor - 16, cx + w * 0.5, floor), '#8a7a90', '#5e5068', off=(-4, -3)),
             P(rect_d(cx - w * 0.36, top + 14, cx + w * 0.36, floor - 16), '#a494aa', '#6e6078', off=(-8, 0),
               over=line('M%.1f %.1f L%.1f %.1f' % (cx - w * 0.2, top + 22, cx - w * 0.2, floor - 22), '#c8b8cc', 2.2, op=0.8)
               + line('M%.1f %.1f L%.1f %.1f' % (cx + w * 0.16, top + 22, cx + w * 0.16, floor - 22), '#6e6078', 1.6, op=0.8)),
             P('M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (cx - w * 0.54, top, cx + w * 0.54, top, cx + w * 0.44, top + 14, cx - w * 0.44, top + 14),
               '#b4a4b8', '#7a6c84', off=(-3, -3))]
    return draw(ctx, parts, INK, FRONT_W)


def hg_knight(ctx, cx, base):
    """The Candleknight's kettle helm: a ridged dome and a broad sloping brim,
    its mail coif draped over the cushion, a gold cup and candle on its crown."""
    mail = P('M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f L%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z' % (
        cx - 30, base - 14, cx - 34, base - 4, cx - 30, base + 2, cx - 20, base + 4, cx + 20, base + 4, cx + 30, base + 2, cx + 34, base - 4,
        cx + 30, base - 14), '#8e93ad', '#686c88', off=(-3, -2),
        over=line(' '.join('M%.1f %.1f q2.2 2.4 4.4 0' % (x, y) for y in (base - 10, base - 5, base) for x in range(int(cx - 30), int(cx + 28), 5)),
                  '#1c1830', 0.8, op=0.45))
    brim = P('M%.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f Z' % (
        cx - 40, base - 10, cx - 30, base - 22, cx, base - 23, cx + 30, base - 22, cx + 40, base - 10, cx + 30, base - 12,
        cx, base - 13, cx - 30, base - 12, cx - 40, base - 10), '#c3c7d6', '#8b90a8', off=(-2, -2),
        over=''.join(dot(cx + dx, base - 15.5, 1.1, GOLD) for dx in (-24, -12, 0, 12, 24)))
    dome = P('M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z' % (
        cx - 22, base - 20, cx - 24, base - 42, cx - 10, base - 50, cx, base - 50, cx + 14, base - 50, cx + 24, base - 42, cx + 22, base - 20),
        '#c3c7d6', '#8b90a8', off=(-4, -4), over=line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (cx + 1, base - 50, cx + 6, base - 38, cx + 7, base - 22), '#1c1830', 0.9, op=0.5)
        + line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (cx - 1, base - 49, cx + 3, base - 38, cx + 4, base - 23), '#f2f4fb', 1.1, op=0.8),
        hl=spec(cx - 13, base - 38, 4.6, 2.2, rot=-45, op=0.9))
    cup = P('M%.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f Z' % (cx - 7, base - 52, cx + 7, base - 52, cx + 6, base - 48, cx, base - 47,
                                                                           cx - 6, base - 48, cx - 7, base - 52), GOLD, GOLD_SH, off=(-1, -1))
    cp, wk, tip = candle(ctx, cx, base - 51, 9, 12, INK)
    return draw(ctx, [mail, dome, brim, cup] + cp, INK, FRONT_W) + wk, tip


def hg_founder(ctx, cx, base):
    """The Bellfounder's iron pot-helm with riveted rim and cheek flaps, a
    little brazier dish on top holding the candle."""
    parts = [P(rect_d(cx - 34, base - 22, cx - 24, base + 2), '#5a5a6e', '#3e3e50', off=(-2, -1)),
             P(rect_d(cx + 24, base - 22, cx + 34, base + 2), '#5a5a6e', '#3e3e50', off=(-2, -1)),
             P('M%.1f %.1f L%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z' % (cx - 30, base - 12, cx + 30, base - 12, cx + 30, base - 50, cx - 30, base - 50, cx - 30, base - 12),
               '#6a6a80', '#46465a', off=(-6, -3), over=line('M%.1f %.1f L%.1f %.1f' % (cx - 22, base - 42, cx - 20, base - 16), '#9a9ab0', 2, op=0.8)
               + '<ellipse cx="%.1f" cy="%.1f" rx="5" ry="3" fill="#2a2a34" opacity="0.6"/>' % (cx + 10, base - 30)),
             P(rrect_d(cx - 34, base - 16, cx + 34, base - 8, 3), '#5a5a6e', '#3e3e50', off=(-2, -2),
               over=''.join(dot(cx + dx, base - 12, 1.6, '#a8a8c0') for dx in (-28, -18, -8, 2, 12, 22))),
             P('M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (cx - 20, base - 58, cx + 20, base - 58, cx + 12, base - 48, cx - 12, base - 48),
               '#3e3e50', '#2a2a36', off=(-1, -1), over=''.join(dot(cx + dx, base - 58, 2.6, '#8a3a2a') for dx in (-12, -5, 6, 13)))]
    cp, wk, tip = candle(ctx, cx, base - 58, 9, 13, INK)
    return draw(ctx, parts + cp, INK, FRONT_W) + wk, tip


def hg_witch(ctx, cx, base):
    """The Taperwitch's plum pointed hat: a wide brim, a cream wax-drip band, a
    rose ribbon, its tip curling forward into a tall taper."""
    parts = [E(cx, base - 5, 44, 8, '#3a2450', '#27163a', off=(-2, -3)),
             P('M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f L%.1f %.1f Z' % (
                 cx - 24, base - 8, cx - 20, base - 40, cx - 6, base - 68, cx + 14, base - 84,
                 cx + 20, base - 88, cx + 26, base - 84, cx + 22, base - 78, cx + 24, base - 8),
               '#3a2450', '#27163a', off=(-5, -3)),
             P('M%.1f %.1f L%.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f Z' % (
                 cx - 24, base - 10, cx - 22, base - 22, cx + 23, base - 22, cx + 22, base - 14, cx + 16, base - 12, cx + 12, base - 6,
                 cx + 8, base - 12, cx - 24, base - 10), '#f4ead6', '#d4c4a4', off=(-2, -1)),
             P(rect_d(cx - 22, base - 28, cx + 23, base - 22), '#d86a8a', '#a8486a', off=(-1, -1))]
    cp, wk, tip = candle(ctx, cx + 20, base - 86, 7, 16, INK)
    return draw(ctx, parts + cp, INK, FRONT_W) + wk, tip


def hg_runner(ctx, cx, base):
    """The Sootrunner's charcoal hood, two fuzzy moth feelers, and a tiny
    tealight under a brass snuffer-cone hung from its curled tip."""
    parts = [LIMB('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (cx - 10, base - 40, cx - 26, base - 70, cx - 14, base - 82), '#bca68a', 3.4),
             LIMB('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (cx + 2, base - 44, cx + 2, base - 76, cx + 16, base - 84), '#bca68a', 3.4)]
    for x, y in ((cx - 14, base - 82), (cx + 16, base - 84)):
        parts.append(E(x, y, 5, 4, '#d8c4a4', '#bca68a', off=(-1, -1)))
    parts.append(P('M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z' % (
        cx - 30, base - 4, cx - 34, base - 34, cx - 16, base - 52, cx + 4, base - 50, cx + 24, base - 48, cx + 36, base - 40, cx + 40, base - 30,
        cx + 30, base - 16, cx + 30, base - 4, cx - 30, base - 4), '#2e2a3e', '#1e1a2a', off=(-5, -4),
        over='<path d="M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z" fill="#141220"/>' % (cx - 12, base - 6, cx - 10, base - 30, cx + 16, base - 34, cx + 22, base - 6)))
    # the curled tip, the snuffer-cone and the tealight hanging from it
    parts.append(LIMB('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (cx + 38, base - 32, cx + 50, base - 38, cx + 50, base - 26), '#2e2a3e', 6))
    parts.append(LIMB('M%.1f %.1f L%.1f %.1f' % (cx + 50, base - 26, cx + 50, base - 18), '#9a7028', 1.4))
    parts.append(P('M%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (cx + 43, base - 12, cx + 57, base - 12, cx + 50, base - 22), '#d8a84a', '#9a7028', off=(-1, -1)))
    parts.append(P(rrect_d(cx + 45, base - 12, cx + 55, base - 6, 1.6), '#b8bcc8', '#80849a', off=(-1, -1)))
    tip = (cx + 50, base - 11)
    return draw(ctx, parts, INK, FRONT_W) + unlit_wick(cx + 50, base - 9, 3, w=1.2), tip


def hg_sexton(ctx, cx, base):
    """The Sexton's crooked stovepipe hat, a lavender ribbon, and a tiny round
    smiling skull on its crown holding the candle."""
    parts = [E(cx, base - 5, 36, 7, '#2a2238', '#1a1426', off=(-2, -3)),
             P('M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (cx - 20, base - 8, cx - 24, base - 64, cx + 20, base - 70, cx + 22, base - 8),
               '#2a2238', '#1a1426', off=(-5, -2), over=line('M%.1f %.1f L%.1f %.1f' % (cx - 14, base - 60, cx - 12, base - 14), '#4a3e5e', 2, op=0.8)),
             P('M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (cx - 21, base - 20, cx - 22, base - 30, cx + 21, base - 32, cx + 22, base - 22),
               '#a89ad8', '#7a6aa8', off=(-1, -1)),
             E(cx, base - 76, 11, 10, '#efe6d2', '#c9bfa6', off=(-2, -2),
               over=dot(cx - 4, base - 77, 2.4, '#2a2030') + dot(cx + 4, base - 77, 2.4, '#2a2030')
               + line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (cx - 5, base - 71, cx, base - 68, cx + 5, base - 71), '#2a2030', 1.2))]
    cp, wk, tip = candle(ctx, cx, base - 84, 7, 10, INK)
    return draw(ctx, parts + cp, INK, FRONT_W) + wk, tip


def callings():
    p = Panel('callings', 1000, 460, [0.26, 0.22, 0.38], 'dust')
    rng = Rand(5150)
    # ---------------------------------------------------------------- bg (0.5): the apse
    ctx = Ctx('cab')
    s = ''
    s += ashlar(rng, 0, 0, 1000, 350, 36, '#8a7a90', '#4e4058', hl='#a894a8')
    # the half dome's ribs and the apse's lancets
    s += '<path d="M-20 0 L1020 0 L1020 40 Q500 -30 -20 40 Z" fill="#5e5068"/>'
    for x in (250, 750):
        s += '<path d="%s" fill="#3a2e44"/>' % arch_d(x - 44, x + 44, 64, 286)
        g = ctx.lingrad([(0, '#4a5a9a'), (1, '#2a2e5a')])
        s += '<path d="%s" fill="%s"/>' % (arch_d(x - 34, x + 34, 76, 280), g)
        s += line('M%d 150 L%d 280 M%d 150 L%d 150' % (x, x, x - 34, x + 34), '#3a2e44', 4)
        s += '<path d="%s" fill="none" stroke="#b4a4b8" stroke-width="4"/>' % arch_d(x - 46, x + 46, 60, 288)
    for x in (110, 390, 610, 890):
        s += draw(ctx, [P(rect_d(x - 14, 40, x + 14, 350), '#9a8aa0', '#6a5c74', off=(-5, 0)),
                        P(rect_d(x - 20, 40, x + 20, 52), '#b4a4b8', '#7a6c84', off=(-2, -2))], INK, BACK_W)
    # the crest carved above the middle plinth, gilded
    s += '<circle cx="500" cy="104" r="52" fill="#6e5e76"/><circle cx="500" cy="104" r="45" fill="#8a7a90" stroke="#b4a4b8" stroke-width="3"/>'
    s += crest_svg(500, 106, 58, GOLD, '#4a3408', '#fff2c8', 2.2)
    # the floor: a semicircle of steps under the plinths
    s += fillp('M-20 350 L1020 350 L1020 470 L-20 470 Z', '#5e5068')
    s += '<path d="M60 470 Q60 356 500 350 Q940 356 940 470 Z" fill="#7a6c84"/>'
    s += '<path d="M130 470 Q130 372 500 366 Q870 372 870 470 Z" fill="#8a7a90"/>'
    # the wall sconces
    wicks = ''
    tips = []
    for x in (66, 934):
        parts = [P('M%d 214 L%d 214 L%d 224 L%d 224 Z' % (x - 14, x + 14, x + 8, x - 8), IRON, IRON_SH, off=(-1, -1)),
                 LIMB('M%d 224 Q%d 240 %d 250' % (x, x - 4 if x < 500 else x + 4, x - 12 if x < 500 else x + 12), IRON, 3)]
        cp, wk, tip = candle(ctx, x, 214, 9, 20, INK)
        s += draw(ctx, parts + cp, INK, BACK_W)
        wicks += wk
        tips.append(tip)
    s += wicks
    p.layer('bg', 0.5, s, ctx=ctx)
    p.light('sconce_l', tips[0][0], tips[0][1], 130, 0.85, 'flame', h=11, depth=0.5)
    p.light('sconce_r', tips[1][0], tips[1][1], 130, 0.85, 'flame', h=11, depth=0.5)
    # ---------------------------------------------------------------- plinths (1.0)
    ctx = Ctx('cap')
    s = ''
    order = [('knight', 180, 302, 404, 1.0), ('founder', 340, 294, 396, 0.96), ('witch', 500, 290, 392, 0.94),
             ('runner', 660, 294, 396, 0.96), ('sexton', 820, 302, 404, 1.0)]
    hg = {'knight': hg_knight, 'founder': hg_founder, 'witch': hg_witch, 'runner': hg_runner, 'sexton': hg_sexton}
    grow = {'knight': 1.4, 'founder': 1.35, 'witch': 1.18, 'runner': 1.3, 'sexton': 1.3}
    for cls, x, top, floor, k in order:
        s += plinth(ctx, x, top, floor, 104 * k)
        s += cushion(ctx, x, top - 14, 88 * k)
        g = grow[cls]
        bx, by = x, top - 12
        art, tip = hg[cls](ctx, bx, by)
        s += '<g transform="translate(%.1f %.1f) scale(%.2f) translate(%.1f %.1f)">%s</g>' % (bx, by, g, -bx, -by, art)
        tx, ty = bx + (tip[0] - bx) * g, by + (tip[1] - by) * g
        p.light('plinth_' + cls, tx, ty, 110, 1.0, 'flame', h=11)
    p.layer('plinths', 1.0, s, ctx=ctx)
    return p


# ================================================================ crypt_row (P0): a crypt corridor in one-point perspective

VP = (570.0, 205.0)
CRYPT_S = [1.0, 0.78, 0.62, 0.5, 0.41, 0.34, 0.285, 0.245]   # the eight candles' depths (1 = nearest)
FAR_S = 0.22                                                   # the far wall


def cp_(x, y, s):
    """A point at relative (x, y) from the vanishing point, at depth scale s."""
    return (VP[0] + x * s, VP[1] + y * s)


def crypt_rib(ctx, s_, stone, sh, hi, w=MID_W):
    """A pointed rib arch across the corridor at depth s_, with its pillars."""
    L, R, SP, AP, FL = -520, 480, -150, -262, 210
    bw = 26
    lx0, rx0 = cp_(L, 0, s_)[0], cp_(R, 0, s_)[0]
    sp, ap, fl = cp_(0, SP, s_)[1], cp_(0, AP, s_)[1], cp_(0, FL, s_)[1]
    b = bw * s_
    ax = VP[0] + (L + R) / 2.0 * s_
    outer = 'M%.1f %.1f L%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f L%.1f %.1f L%.1f %.1f ' % (
        lx0 - b, fl, lx0 - b, sp, lx0 - b, sp - 70 * s_, ax - 150 * s_, ap - b + 16 * s_, ax, ap - b,
        ax + 150 * s_, ap - b + 16 * s_, rx0 + b, sp - 70 * s_, rx0 + b, sp, rx0 + b, fl, rx0, fl)
    outer += 'L%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f L%.1f %.1f Z' % (
        rx0, sp, rx0, sp - 64 * s_, ax + 140 * s_, ap + 18 * s_, ax, ap, ax - 140 * s_, ap + 18 * s_, lx0, sp - 64 * s_, lx0, sp, lx0, fl)
    parts = [P(outer, stone, sh, off=(-4 * s_, -3 * s_),
               over=line('M%.1f %.1f L%.1f %.1f' % (lx0 - b * 0.6, fl, lx0 - b * 0.6, sp), hi, max(1.0, 2.4 * s_), op=0.8))]
    # capitals where the rib springs
    for x in (lx0 - b / 2, rx0 + b / 2):
        parts.append(P(rect_d(x - b * 0.9, sp - 4 * s_, x + b * 0.9, sp + 8 * s_), hi, stone, off=(-1, -1)))
    return draw(ctx, parts, '#0a1010', w)


def crypt_wall_courses(s0, s1, y_rel_top, y_rel_bot, x_rel, col, n=6):
    """Mortar courses running to the vanishing point on a side wall."""
    out = ''
    for k in range(n + 1):
        y = y_rel_top + (y_rel_bot - y_rel_top) * k / float(n)
        a, b = cp_(x_rel, y, s0), cp_(x_rel, y, s1)
        out += 'M%.1f %.1f L%.1f %.1f ' % (a[0], a[1], b[0], b[1])
    return line(out, col, 1.4, op=0.55)


def coffin_niche(ctx, s_, stone_dk, lid, lid_sh):
    """A coffin niche in the right wall at depth s_: a dark recess, a stone lid
    with the Vigil's flame carved on it, and a skull resting at its head."""
    R = 480
    x_near, x_far = cp_(R, 0, s_)[0], cp_(R, 0, s_ * 0.86)[0]
    y_top_n, y_bot_n = cp_(0, 40, s_)[1], cp_(0, 150, s_)[1]
    y_top_f, y_bot_f = cp_(0, 40, s_ * 0.86)[1], cp_(0, 150, s_ * 0.86)[1]
    rec = poly_d([(x_far, y_top_f), (x_near, y_top_n), (x_near, y_bot_n), (x_far, y_bot_f)])
    s = '<path d="%s" fill="%s"/>' % (rec, stone_dk)
    lid_d = poly_d([(x_far - 2, y_bot_f - 20 * s_ * 0.86), (x_near - 6 * s_, y_bot_n - 26 * s_), (x_near - 6 * s_, y_bot_n - 4 * s_), (x_far - 2, y_bot_f - 2)])
    fx, fy = (x_far + x_near) / 2, (y_bot_f + y_bot_n) / 2 - 16 * s_
    parts = [P(lid_d, lid, lid_sh, off=(-3 * s_, -2 * s_),
               over='<path d="%s" fill="none" stroke="%s" stroke-width="%.1f"/>' % (flame_d(fx, fy + 8 * s_, 10 * s_, 14 * s_, 0), lid_sh, max(1, 2 * s_)))]
    kx, ky = x_far + 10 * s_, y_bot_f - 26 * s_
    parts.append(E(kx, ky, 11 * s_, 10 * s_, '#d8ccb4', '#a89c84', off=(-2 * s_, -2 * s_),
                   over=dot(kx - 3 * s_, ky, 2.8 * s_, '#1a1414') + dot(kx + 4 * s_, ky - 0.5 * s_, 2.4 * s_, '#1a1414')))
    return s + draw(ctx, parts, '#0a1010', MID_W)


def crypt_row():
    p = Panel('crypt_row', 1000, 460, [0.24, 0.30, 0.32], 'dust')
    rng = Rand(611)
    STONE, SH, HI = '#6a7a76', '#46544f', '#8a9a94'
    FLOOR, FJ = '#56625e', '#2e3836'
    # ---------------------------------------------------------------- vault (0.6): the whole corridor
    ctx = Ctx('crv')
    s = fillp(rect_d(0, 0, 1000, 460), '#1e2826')
    L, R, SP, AP, FL = -520, 480, -150, -262, 210
    # the side walls, receding
    for x_rel, col in ((L, '#5e6e6a'), (R, '#56665f')):
        pts = [cp_(x_rel, SP, 1.4), cp_(x_rel, FL, 1.4), cp_(x_rel, FL, FAR_S), cp_(x_rel, SP, FAR_S)]
        s += fillp(poly_d(pts), col)
        s += crypt_wall_courses(1.4, FAR_S, SP, FL, x_rel, '#2a3634', 7)
    # the vault overhead, dark
    s += fillp(poly_d([cp_(L, SP, 1.4), cp_(L, SP, FAR_S), cp_(0, AP, FAR_S), cp_(R, SP, FAR_S), cp_(R, SP, 1.4), (1100, -60), (-100, -60)]), '#26302e')
    for x_rel in (-300, 0, 260):
        a, b = cp_(x_rel, AP * (1 - abs(x_rel) / 700.0), 1.4), cp_(x_rel, AP * (1 - abs(x_rel) / 700.0), FAR_S)
        s += line('M%.1f %.1f L%.1f %.1f' % (a[0], a[1], b[0], b[1]), '#3a4644', 3, op=0.8)
    # the floor: flagstones running to the vanishing point
    s += fillp(poly_d([cp_(L, FL, 1.4), cp_(R, FL, 1.4), cp_(R, FL, FAR_S), cp_(L, FL, FAR_S)]), FLOOR)
    fl = ''
    for x_rel in range(-500, 500, 90):
        a, b = cp_(x_rel, FL, 1.4), cp_(x_rel, FL, FAR_S)
        fl += 'M%.1f %.1f L%.1f %.1f ' % (a[0], a[1], b[0], b[1])
    sv = 1.0
    while sv > FAR_S:
        a, b = cp_(L, FL, sv), cp_(R, FL, sv)
        fl += 'M%.1f %.1f L%.1f %.1f ' % (a[0], a[1], b[0], b[1])
        sv *= 0.8
    s += line(fl, FJ, 1.6)
    # the far wall and its tall window of green glass (the Snuffer stands against it)
    fw = poly_d([cp_(L, SP, FAR_S), cp_(L, FL, FAR_S), cp_(R, FL, FAR_S), cp_(R, SP, FAR_S), cp_(0, AP, FAR_S)])
    s += fillp(fw, '#4e5e5a')
    win = arch_d(VP[0] - 62, VP[0] + 62, 139, 251, 0.7)
    g = ctx.radgrad([(0, '#c8f0d8'), (0.5, '#7ac0a0'), (1, '#4a8a70')], cx=0.5, cy=0.55, r=0.6)
    s += '<path d="%s" fill="%s"/>' % (win, g)
    s += line('M%.1f 155 L%.1f 251 M%.1f 197 L%.1f 197 M%.1f 225 L%.1f 225' % (VP[0], VP[0], VP[0] - 62, VP[0] + 62, VP[0] - 62, VP[0] + 62), '#1e2e28', 3)
    s += '<path d="%s" fill="none" stroke="#1e2e28" stroke-width="5"/>' % win
    s += '<path d="%s" fill="none" stroke="%s" stroke-width="3"/>' % (arch_d(VP[0] - 70, VP[0] + 70, 131, 253, 0.7), HI)
    # the ribs, far to near (the nearest is in the floor layer)
    for s_ in (0.26, 0.31, 0.38, 0.47, 0.6, 0.76):
        s += crypt_rib(ctx, s_, STONE, SH, HI, MID_W if s_ > 0.4 else BACK_W)
    # coffin niches down the right wall
    for s_ in (0.64, 0.46, 0.35, 0.28):
        s += coffin_niche(ctx, s_, '#141c1a', '#8a968e', '#5e6a64')
    # the far candles (c3..c8) on their iron stands along the left wall
    wicks = ''
    tips = {}
    for i, s_ in enumerate(CRYPT_S):
        if i < 2:
            continue
        base = cp_(-420, FL, s_)
        parts, wk, tip = candle_stand(ctx, base[0], base[1], 110 * s_, 30 * s_, INK)
        s += draw(ctx, parts, '#0a1010', MID_W if s_ > 0.4 else BACK_W)
        wicks += wk
        tips[i] = tip
    s += wicks
    p.layer('vault', 0.6, s, ctx=ctx)
    # ---------------------------------------------------------------- floor (1.0): the near rib, near flagstones, c1 and c2
    ctx = Ctx('crf')
    s = ''
    s += crypt_rib(ctx, 1.0, STONE, SH, HI, FRONT_W)
    # a skull and scattered bones by the near pillar, cobwebs in the corner
    parts = [E(118, 428, 16, 13, '#d8ccb4', '#a89c84', off=(-3, -3),
               over=dot(112, 426, 3.4, '#1a1414') + dot(122, 425, 3, '#1a1414') + line('M110 434 L126 434', '#1a1414', 1.4)),
             LIMB('M140 432 L176 422', '#d8ccb4', 5), E(140, 432, 4, 4, '#d8ccb4', '#a89c84', off=(-1, -1)), E(176, 422, 4, 4, '#d8ccb4', '#a89c84', off=(-1, -1))]
    s += draw(ctx, parts, '#0a1010', FRONT_W)
    web = ''
    for k in range(5):
        a = math.radians(90 + k * 20)
        web += 'M78 90 L%.1f %.1f ' % (78 + 90 * math.cos(a) * -1, 90 + 90 * math.sin(a))
    for r0 in (30, 55, 80):
        web += 'M%.1f 90 Q%.1f %.1f 78 %.1f ' % (78 + r0, 78 + r0 * 0.6, 90 + r0 * 0.6, 90 + r0)
    s += line(web, '#b8c8c0', 1.1, op=0.5)
    wicks = ''
    for i in (0, 1):
        s_ = CRYPT_S[i]
        base = cp_(-420, FL, s_)
        parts, wk, tip = candle_stand(ctx, base[0], base[1], 110 * s_, 30 * s_, INK)
        s += draw(ctx, parts, '#0a1010', FRONT_W)
        wicks += wk
        tips[i] = tip
    s += wicks
    p.layer('floor', 1.0, s, ctx=ctx)
    radii = [120, 100, 86, 74, 64, 56, 50, 44]
    for i in range(8):
        x, y = tips[i]
        p.light('c%d' % (i + 1), x, y, radii[i], 1.0, 'flame', h=round(15 * CRYPT_S[i] + 2, 1), depth=1.0 if i < 2 else 0.6)
    p.light('far_glass', VP[0], 201, 150, 0.55, 'glow', depth=0.6)
    # the Snuffer, small with distance, silhouetted against the far window
    p.anchor('far', 600, 275, depth=0.6, h=137, flip=True)
    return p


# ================================================================ belfry (P0)

BAT, BAT_SH, BAT_LINE, BAT_HI = '#6a4a8a', '#4a3068', '#1a0e26', '#9a7abc'


def hanging_flit(ctx, x, y, k=1.0, flip=False):
    """A Flit asleep upside down, its feet on the beam at (x, y), wings folded."""
    sx = -1 if flip else 1
    t = 'translate(%.1f %.1f) scale(%.2f %.2f)' % (x, y, k * sx, k)
    parts = [LIMB('M-3 0 L-3 6 M3 0 L3 6', BAT_SH, 1.6),
             P('M0 6 C-12 6 -16 16 -14 30 C-12 40 -6 46 0 46 C6 46 12 40 14 30 C16 16 12 6 0 6 Z', '#5a3c7a', '#3e2a5a', off=(-2, -2),
               over=line('M-6 12 Q-10 26 -6 40 M6 12 Q10 26 6 40', '#3e2a5a', 1.2)),
             P('M0 30 C-8 30 -10 36 -10 42 C-10 50 -5 54 0 54 C5 54 10 50 10 42 C10 36 8 30 0 30 Z', BAT, BAT_SH, off=(-1.5, -1.5),
               over='<path d="M-5 42 Q-3 40 -1 42 M1 42 Q3 40 5 42" fill="none" stroke="%s" stroke-width="1.1"/>' % BAT_LINE
               + '<ellipse cx="-6.5" cy="46" rx="2" ry="1.2" fill="#ff7ab0" opacity="0.7"/><ellipse cx="6.5" cy="46" rx="2" ry="1.2" fill="#ff7ab0" opacity="0.7"/>'),
             P('M-8 52 L-11 62 L-3 54 Z', BAT, BAT_SH, off=(0, 0)), P('M8 52 L11 62 L3 54 Z', BAT, BAT_SH, off=(0, 0))]
    body = draw(ctx, parts, BAT_LINE, FRONT_W)
    return '<g transform="%s">%s</g>' % (t, body)


def louver_arch(ctx, cx, w, apex, sill, broken=False, sky_g=None):
    """A tall louvered belfry opening: sloped wooden slats with slivers of the
    moonlit sky between them; broken, it gapes onto the sky."""
    x0, x1 = cx - w / 2, cx + w / 2
    d = arch_d(x0, x1, apex, sill, 0.7)
    s = '<path d="%s" fill="%s"/>' % (d, sky_g)
    clip = ctx.clip('<path d="%s"/>' % d)
    slats = ''
    y = apex + 24
    i = 0
    while y < sill - 6:
        if broken and i not in (0, 8, 9):
            y += 22
            i += 1
            continue
        tilt = 0 if not broken else (18 if i == 8 else -10)
        cxs = cx + (18 if broken and i == 8 else 0)
        slats += '<g transform="rotate(%d %.1f %.1f)">' % (tilt, cxs, y)
        slats += fillp(poly_d([(x0 - 4, y), (x1 + 4, y), (x1 + 4, y + 14), (x0 - 4, y + 14)]), '#6e4a32')
        slats += fillp(poly_d([(x0 - 4, y), (x1 + 4, y), (x1 + 4, y + 4), (x0 - 4, y + 4)]), '#9a6e48')
        slats += line('M%.1f %.1f L%.1f %.1f' % (x0 - 4, y + 14, x1 + 4, y + 14), '#1a0e08', 2)
        slats += '</g>'
        y += 22
        i += 1
    if broken:
        # jagged stumps of slats at the sides
        for yy in range(int(apex + 60), int(sill - 20), 22):
            slats += fillp(poly_d([(x0, yy), (x0 + 16 + (yy % 13), yy + 2), (x0 + 8, yy + 13), (x0, yy + 13)]), '#6e4a32')
            slats += fillp(poly_d([(x1, yy + 4), (x1 - 12 - (yy % 11), yy + 6), (x1 - 6, yy + 15), (x1, yy + 15)]), '#6e4a32')
    s += '<g clip-path="%s">%s</g>' % (clip, slats)
    s += '<path d="%s" fill="none" stroke="#1a1020" stroke-width="3"/>' % d
    s += '<path d="%s" fill="none" stroke="#8a7e9e" stroke-width="10"/>' % arch_d(x0 - 8, x1 + 8, apex - 8, sill, 0.7)
    s += '<path d="%s" fill="none" stroke="#1a1020" stroke-width="2"/>' % arch_d(x0 - 13, x1 + 13, apex - 13, sill, 0.7)
    s += fillp(rect_d(x0 - 16, sill, x1 + 16, sill + 12), '#9a8eae') + line('M%.1f %.1f L%.1f %.1f' % (x0 - 16, sill + 12, x1 + 16, sill + 12), '#1a1020', 2)
    return s


def rope_coil(ctx, cx, cy):
    """A coil of bell rope lying on the boards: a flat spiral, its end trailing off."""
    d = 'M%.1f %.1f' % (cx + 8, cy)
    for i in range(1, 80):
        a = i * 0.32
        r = 8 + i * 0.62
        d += ' L%.1f %.1f' % (cx + r * math.cos(a), cy + r * 0.3 * math.sin(a))
    d += ' Q%.1f %.1f %.1f %.1f' % (cx + 90, cy + 20, cx + 130, cy + 8)
    return line(d, '#1a0e08', 8.6) + line(d, '#c8a060', 5.4) + line(d, '#8a6630', 1.2, op=0.7)


def belfry():
    p = Panel('belfry', 1000, 460, [0.26, 0.28, 0.46], 'dust')
    rng = Rand(7070)
    FLOOR = 330     # where figures stand
    WALL = 302      # where the back wall meets the boards
    APEX, SILL = 44, 262
    # lights first: three moon shafts (the broken arch brightest), the bell beam
    p.light('moon1', 230, 196, 150, 0.45, 'glow', depth=0.4, tint='c0c8f0')
    p.light('moon2', 500, 186, 150, 0.45, 'glow', depth=0.4, tint='c0c8f0')
    p.light('moon3', 770, 150, 175, 0.85, 'glow', depth=0.4, tint='c0c8f0')
    p.light('bell_beam', 500, 92, 210, 0.95, 'glow')
    p.anchor('boss', 520, FLOOR, flip=True)
    p.anchor('sit', 575, FLOOR, flip=True)
    p.anchor('actor_after', 360, FLOOR, h=120)
    # the Snuffer's taunt: he stands in the broken arch against the moon
    p.anchor('sill', 770, SILL, depth=0.4, h=274, flip=True)
    # ---------------------------------------------------------------- louvers (0.4)
    ctx = Ctx('bfl')
    s = ''
    s += ashlar(rng, 0, 0, 1000, WALL, 32, '#7a6e94', '#3e3456', hl='#9a8eb4')
    sky = ctx.lingrad([(0, '#3a4a8a'), (0.6, '#6a7ac0'), (1, '#98a4dc')])
    for cx, broken in ((230, False), (500, False), (770, True)):
        s += louver_arch(ctx, cx, 150, APEX, SILL, broken, sky)
    clip = ctx.clip('<path d="%s"/>' % arch_d(695, 845, APEX, SILL, 0.7))
    s += '<g clip-path="%s">%s%s%s</g>' % (clip, moon_svg(ctx, 792, 124, 46, halo=False),
                                          '<path d="%s" fill="#c8c8f0" opacity="0.8"/>' % cloud_d(700, 184, 130, 28),
                                          ''.join(star4(x, y, r, '#fff4d8', 0.9) for x, y, r in ((730, 96, 3), (820, 214, 2.4), (716, 150, 2))))
    s += fillp(rect_d(0, 0, 1000, 22), '#3e2a1e')
    for x in range(-40, 1040, 170):
        s += fillp(poly_d([(x, 0), (x + 20, 0), (x + 110, 22), (x + 90, 22)]), '#4e3424')
    s += fillp(rect_d(0, WALL - 20, 1000, WALL + 2), '#5a4e72')
    p.layer('louvers', 0.4, s, ctx=ctx)
    # ---------------------------------------------------------------- shafts (0.4, lit): moonlight through the slats
    # Layers and figures draw strictly by depth, so each shaft comes in two
    # parts that cross-fade over the wall's foot: the shaft at the louvers'
    # depth (here), and where it falls across the boards (pools, after the
    # floor, under the figures standing in it).
    def shafts(ctx, stops):
        s = ''
        for cx, op in ((230, 0.2), (500, 0.18), (770, 0.3)):
            g = ctx.lingrad([(y / 420.0, '#c0c8f0', op * k) for y, k in stops], x1=0, y1=0, x2=0, y2=420,
                            units='userSpaceOnUse')
            n = 6 if cx != 770 else 1
            for i in range(n):
                if n == 1:
                    a0, a1 = cx - 60, cx + 60
                else:
                    a0 = cx - 66 + i * 22
                    a1 = a0 + 12
                ty = 76 + (i * 20 if n > 1 else 0)
                s += '<path d="M%.1f %.1f L%.1f %.1f L%.1f %d L%.1f %d Z" fill="%s"/>' % (a0, ty, a1, ty, a1 - 170, 420, a0 - 170, 420, g)
        return s
    ctx = Ctx('bfs')
    p.layer('shafts', 0.4, shafts(ctx, ((0, 1.0), (200, 0.75), (272, 0.5), (300, 0.12), (308, 0.0))), lit=True, ctx=ctx,
            note='moonlight through the louvers, down to the wall\'s foot; the rest is belfry_pools')
    # ---------------------------------------------------------------- floor (1.0)
    ctx = Ctx('bff')
    s = ''
    s += fillp(rect_d(-10, WALL, 1010, 470), '#5a3a26')
    for i in range(-14, 16):
        s += line('M%.1f %d L%.1f 470' % (500 + i * 40, WALL, 500 + i * 110), '#2e1c10', 2)
    for y in (316, 340, 374, 418):
        s += line('M-10 %d L1010 %d' % (y, y), '#3a2416', 1.2, op=0.6)
    for k in range(40):
        x, y = rng.u(0, 1000), rng.u(WALL + 10, 460)
        s += line('M%.1f %.1f l%.1f 0' % (x, y, rng.u(8, 26)), '#7a5236', 1.2, op=0.7)
    s += line('M-10 %d L1010 %d' % (WALL, WALL), '#1a0e08', 3)
    parts = []
    for x in (60, 940):
        parts.append(P(rect_d(x - 18, 40, x + 18, WALL + 50), WOOD, WOOD_SH, off=(-6, 0),
                       over=line('M%d 60 L%d %d' % (x - 8, x - 8, WALL + 40), WOOD_HI, 2, op=0.7)))
        sx = 1 if x < 500 else -1
        parts.append(LIMB('M%d 170 L%d 62' % (x + sx * 16, x + sx * 120), WOOD, 14))
    parts.append(P(rect_d(-10, 30, 1010, 72), WOOD, WOOD_SH, off=(0, -8),
                   over=line('M-10 38 L1010 38', WOOD_HI, 2, op=0.7) + line('M40 52 Q300 48 520 54 Q760 58 980 50', '#4a2c16', 1.4, op=0.8)))
    for x in (200, 360, 640, 800):
        parts.append(P(rect_d(x - 6, 28, x + 6, 74), IRON, IRON_SH, off=(-1, -1), over=dot(x, 40, 2, IRON_HI) + dot(x, 62, 2, IRON_HI)))
    parts.append(P('M478 72 L522 72 L516 92 L484 92 Z', IRON, IRON_SH, off=(-2, -2), over=dot(488, 80, 2.4, IRON_HI) + dot(512, 80, 2.4, IRON_HI)))
    parts.append(LIMB('M500 92 C492 104 508 110 500 120', IRON, 4))
    parts.append(LIMB('M660 72 C664 150 652 230 660 %d' % (FLOOR - 6), '#c8a060', 5,
                      over=line(' '.join('M%d %d l3 -2' % (658 + (k % 2) * 2, y) for k, y in enumerate(range(90, FLOOR - 10, 40))), '#8a6630', 1.2)))
    s += draw(ctx, parts, INK, FRONT_W)
    s += rope_coil(ctx, 150, FLOOR + 44)
    p.layer('floor', 1.0, s, ctx=ctx)
    # ---------------------------------------------------------------- pools (1.0, lit): the shafts across the boards
    ctx = Ctx('bfp')
    p.layer('pools', 1.0, shafts(ctx, ((0, 0.0), (284, 0.0), (304, 0.55), (350, 0.4), (420, 0.0))), lit=True, ctx=ctx,
            note='the moon shafts where they fall across the boards, under the figures')
    # ---------------------------------------------------------------- rafters (1.3, near): beams, ropes and three sleeping Flits
    ctx = Ctx('bfr')
    s = ''
    parts = [P(poly_d([(-100, -46), (-20, -46), (230, 60), (230, 80), (-100, 16)]), '#3a2618', '#24160c', off=(0, -6)),
             P(poly_d([(1100, -46), (1020, -46), (770, 60), (770, 80), (1100, 16)]), '#3a2618', '#24160c', off=(0, -6)),
             P(rect_d(-100, -46, 1100, -10), '#3a2618', '#24160c', off=(0, -6))]
    parts.append(LIMB('M60 -10 C58 60 66 110 60 170', '#a88040', 4))
    parts.append(LIMB('M1010 -10 C1014 50 1004 100 1010 140', '#a88040', 4))
    s += draw(ctx, parts, '#0c0608', FRONT_W)
    s += hanging_flit(ctx, 120, 20, 1.3) + hanging_flit(ctx, 170, 42, 1.1, True) + hanging_flit(ctx, 880, 22, 1.25, True)
    p.layer('rafters', 1.3, s, ctx=ctx)
    return p


# ================================================================ wax set pieces (World 2)

WAXC, WAXC_SH, WAXC_DK, WAXC_HI = '#efe6cc', '#cdbf9c', '#6a5a48', '#fffaf0'


def waxfall(ctx, x, top, bottom, w, rng, col=WAXC, sh=WAXC_SH):
    """A frozen curtain of wax pouring from above: a rippled sheet with long
    drips at its foot."""
    pts_l, pts_r = [], []
    n = 8
    for i in range(n + 1):
        t = i / float(n)
        y = top + (bottom - top) * t
        pts_l.append((x - w / 2 + rng.u(-6, 6) - t * 8, y))
        pts_r.append((x + w / 2 + rng.u(-6, 6) + t * 8, y))
    d = 'M' + ' L'.join('%.1f %.1f' % q for q in pts_l)
    # the drips along the foot
    xs = [pts_l[-1][0] + (pts_r[-1][0] - pts_l[-1][0]) * k / 6.0 for k in range(7)]
    for k in range(6):
        a, b = xs[k], xs[k + 1]
        ln = rng.u(10, 40)
        d += ' Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f' % ((a + b) / 2 - 3, bottom + ln, (a + b) / 2, bottom + ln, (a + b) / 2 + 3, bottom + ln, b, bottom)
    d += ' L' + ' L'.join('%.1f %.1f' % q for q in reversed(pts_r)) + ' Z'
    streaks = ''
    for k in range(4):
        sx = x - w * 0.3 + k * w * 0.2
        streaks += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (sx, top, sx + rng.u(-8, 8), (top + bottom) / 2, sx + rng.u(-6, 6), bottom), sh, 3, op=0.7)
    streaks += line('M%.1f %.1f L%.1f %.1f' % (x - w * 0.38, top, x - w * 0.42, bottom), WAXC_HI, 3, op=0.8)
    return P(d, col, sh, off=(-w * 0.12, 0), over=streaks)


def drip_column(ctx, x, base, h, w, col=WAXC, sh=WAXC_SH):
    """An organ-pipe drip column: a tall cylinder of wax rounded at its top,
    melted drips down its sides."""
    d = 'M%.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f L%.1f %.1f Z' % (
        x - w / 2, base, x - w / 2, base - h + w * 0.4, x - w / 2, base - h, x, base - h, x + w / 2, base - h, x + w / 2, base - h + w * 0.4, x + w / 2, base)
    drips = ''
    for dx, ln in ((-0.3, 0.35), (0.25, 0.22)):
        xx = x + dx * w
        drips += '<path d="M%.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f L%.1f %.1f Z" fill="%s"/>' % (
            xx - w * 0.1, base - h + w * 0.3, xx - w * 0.1, base - h + h * ln, xx, base - h + h * ln + w * 0.14, xx + w * 0.1, base - h + h * ln, xx + w * 0.1, base - h + w * 0.3, WAXC_HI)
    return P(d, col, sh, off=(-w * 0.22, 0), over=drips + line('M%.1f %.1f L%.1f %.1f' % (x - w * 0.3, base - h + w * 0.5, x - w * 0.3, base - 4), WAXC_HI, max(1.0, w * 0.06), op=0.8))


def wick_reed(ctx, x, base, h, lean=0.0):
    """A wick-reed: a thin black stalk with a nub of wax, its flame the engine's."""
    tx, ty = x + lean, base - h
    parts = [LIMB('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (x, base, x + lean * 0.2, base - h * 0.5, tx, ty + 6), '#2a2018', 2.6),
             E(tx, ty + 7, 3.4, 3, WAXC, WAXC_SH, off=(-1, -1))]
    return parts, (tx, ty + 3)


def melt_terrace(ctx, x0, x1, top, bottom, rng, col=WAXC, sh=WAXC_SH):
    """A terrace of old candles melted together: a wavy top lip with drips,
    the stubs of candles standing out of it."""
    n = int((x1 - x0) / 30)
    d = 'M%.1f %.1f' % (x0, bottom)
    d += ' L%.1f %.1f' % (x0, top + rng.u(0, 10))
    for k in range(1, n + 1):
        x = x0 + (x1 - x0) * k / float(n)
        y = top + rng.u(-6, 8)
        d += ' Q%.1f %.1f %.1f %.1f' % (x - (x1 - x0) / n / 2, y - 8, x, y)
    d += ' L%.1f %.1f Z' % (x1, bottom)
    drips = ''
    for k in range(n):
        if rng.f() < 0.6:
            xx = x0 + (x1 - x0) * (k + 0.5) / n
            ln = rng.u(12, 36)
            drips += '<path d="M%.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f L%.1f %.1f Z" fill="%s" stroke="%s" stroke-width="1.2"/>' % (
                xx - 5, top + 4, xx - 5, top + ln, xx, top + ln + 7, xx + 5, top + ln, xx + 5, top + 4, WAXC_HI, sh)
    return P(d, col, sh, off=(-8, -6), over=drips + line('M%.1f %.1f L%.1f %.1f' % (x0 + 6, top + 12, x1 - 6, top + 14), WAXC_HI, 2, op=0.6))


def big_moth(ctx, x, y, k=1.0):
    """A moth as big as a bell, resting, its wings folded like a tent, fuzzy
    and faintly glowing green."""
    t = 'translate(%.1f %.1f) scale(%.2f)' % (x, y, k)
    G_, GS = '#c8e0c0', '#8aa888'
    parts = [P('M0 -40 C-40 -30 -70 10 -76 40 C-50 46 -20 44 0 36 Z', G_, GS, off=(-5, -3),
               over='<circle cx="-40" cy="12" r="10" fill="#5a7a5a"/><circle cx="-40" cy="12" r="5" fill="#e8f4d8"/>'
               + line('M-8 -30 Q-40 0 -64 36', GS, 2, op=0.8)),
             P('M0 -40 C40 -30 70 10 76 40 C50 46 20 44 0 36 Z', mix(G_, '#6a8a6a', 0.2), GS, off=(-5, -3),
               over='<circle cx="40" cy="12" r="10" fill="#5a7a5a"/><circle cx="40" cy="12" r="5" fill="#e8f4d8"/>'),
             P('M0 -52 C12 -52 16 -40 14 -24 C12 -8 6 0 0 0 C-6 0 -12 -8 -14 -24 C-16 -40 -12 -52 0 -52 Z', '#f4f8e8', '#c8d8b8', off=(-2, -2)),
             E(0, -58, 12, 11, '#fffcf0', '#d8e4c8', off=(-2, -2),
               over=dot(-4.6, -59, 2.6, '#2a3a2a') + dot(4.6, -59, 2.4, '#2a3a2a') + line('M-4 -53 Q0 -50 4 -53', '#2a3a2a', 1)),
             LIMB('M-5 -66 Q-18 -90 -34 -92', '#d8e4c8', 3.4), LIMB('M5 -66 Q18 -90 34 -92', '#d8e4c8', 3.4)]
    return '<g transform="%s">%s</g>' % (t, draw(ctx, parts, '#1e2a1e', FRONT_W))


# ================================================================ tallow_vista (P1)

def tallow_vista():
    """The Tallow Deep from its lip: a thousand years of wax melted into a
    cavern of waxfalls and organ-pipe drips, terraces stepping down either
    side into a gulf, and at the very bottom, tiny and gold, the Undercandle.
    Wick and Waxley stand on the near ledge; a moth as big as a bell rests."""
    p = Panel('tallow_vista', 1400, 460, [0.32, 0.28, 0.26], 'wax')
    rng = Rand(9191)
    D = p.dark
    # ---------------------------------------------------------------- far (0.3): the gulf and the Undercandle
    ctx = Ctx('tvf')
    g = vgrad(ctx, [(0, '#2a1e26'), (0.5, '#5a3e40'), (1, '#8a6250')])
    s = '<rect x="0" y="0" width="1400" height="460" fill="%s"/>' % g
    # the far walls closing in toward the bottom, in receding bands
    for k, col in enumerate(('#6a4e4c', '#80605a', '#9a7666', '#b48c74')):
        y0 = 150 + k * 50
        inset = 120 + k * 110
        s += fillp('M-10 %d L%d %d Q%d %d %d %d L%d 470 L-10 470 Z' % (y0, inset, y0 + 30, inset + 120, y0 + 60, inset + 180, y0 + 140, inset + 150), col)
        s += fillp('M1410 %d L%d %d Q%d %d %d %d L%d 470 L1410 470 Z' % (y0 - 10, 1400 - inset, y0 + 20, 1280 - inset, y0 + 56, 1220 - inset, y0 + 140, 1250 - inset), col)
    # the gold haze of the Undercandle down in the gulf, and the candle itself
    s += radial(ctx, 700, 380, 260, '#ffc860', 0.45, 0.4)
    s += fillp('M540 470 Q600 400 700 392 Q800 400 860 470 Z', '#c89868')
    s += draw(ctx, [P(rect_d(692, 360, 708, 396), '#fff6e0', '#e8d8b8', off=(-3, 0))], '#3a2820', BACK_W)
    s += '<path d="%s" fill="#ffd060" stroke="#8a4a1a" stroke-width="1"/>' % flame_d(700, 360, 8, 16, 0.4)
    # waxfall curtains and organ-pipe drips on the far walls
    parts = []
    for x, w, bot in ((70, 90, 300), (230, 60, 250), (1180, 70, 240), (1330, 100, 320)):
        parts.append(waxfall(ctx, x, -10, bot, w, rng, fade(WAXC, D, 0.3), fade(WAXC_SH, D, 0.3)))
    for x0, n in ((330, 5), (980, 6)):
        for k in range(n):
            parts.append(drip_column(ctx, x0 + k * 22, 300 + k % 2 * 10, rng.u(120, 230), 20, fade(WAXC, D, 0.35), fade(WAXC_SH, D, 0.35)))
    s += draw(ctx, parts, '#3a2820', BACK_W)
    # drips hanging from the cavern roof
    roof = []
    for x in range(20, 1400, 70):
        ln = rng.u(20, 90)
        w = rng.u(18, 32)
        roof.append(P('M%.1f -10 L%.1f %.1f Q%.1f %.1f %.1f %.1f L%.1f -10 Z' % (x - w / 2, x - w / 3, ln, x, ln + w * 0.6, x + w / 3, ln, x + w / 2),
                      fade(WAXC, D, 0.4), fade(WAXC_SH, D, 0.4), off=(-w * 0.2, 0)))
    s += draw(ctx, roof, '#3a2820', BACK_W)
    p.layer('far', 0.3, s, ctx=ctx)
    p.light('under_far', 700, 364, 90, 0.85, 'glow', depth=0.3)
    # ---------------------------------------------------------------- terraces (0.65): stepping down either side of the gulf
    ctx = Ctx('tvt')
    s = ''
    reeds = []
    tiers = [(-20, 330, 262, 470), (-20, 520, 330, 470), (1060, 1420, 256, 470), (860, 1420, 324, 470)]
    for x0, x1, top, bot in tiers:
        s += draw(ctx, [melt_terrace(ctx, x0, x1, top, bot, rng, fade(WAXC, D, 0.12), fade(WAXC_SH, D, 0.12))], '#2e2018', MID_W)
        stubs = []
        for k in range(int((x1 - x0) / 70)):
            xx = x0 + 40 + k * 70 + rng.u(-14, 14)
            cpp, wk, tip = candle(ctx, xx, top + 12, rng.u(12, 22), rng.u(18, 46), '#2e2018')
            stubs += cpp
        s += draw(ctx, stubs, '#2e2018', MID_W)
    for x, base, h, lean in ((60, 268, 58, -4), (140, 264, 76, 6), (230, 268, 52, -2), (330, 336, 70, 5), (410, 334, 56, -6), (480, 338, 64, 3),
                             (900, 330, 70, -5), (980, 328, 58, 4), (1110, 262, 66, -3), (1200, 260, 80, 5), (1290, 264, 60, -4), (1370, 262, 52, 2)):
        rp, tip = wick_reed(ctx, x, base, h, lean)
        s += draw(ctx, rp, '#1a120c', MID_W)
        reeds.append(tip)
    p.layer('terraces', 0.65, s, ctx=ctx)
    for i, (x, y) in enumerate(reeds):
        p.light('reed%d' % (i + 1), x, y, 74, 0.85, 'flame', h=8, depth=0.65)
    # ---------------------------------------------------------------- ledge (1.0)
    ctx = Ctx('tvl')
    s = ''
    parts = []
    parts.append(P('M-40 300 Q120 290 260 298 Q380 306 440 300 Q480 308 492 340 L470 470 L-40 470 Z', WAXC, WAXC_SH, off=(-10, -6),
                   over=line('M-30 306 Q200 298 460 308', WAXC_HI, 3, op=0.8)))
    for x, ln in ((360, 70), (410, 44), (452, 60)):
        parts.append(P('M%.1f 304 L%.1f %.1f Q%.1f %.1f %.1f %.1f L%.1f 304 Z' % (x - 9, x - 9, 304 + ln, x, 304 + ln + 12, x + 9, 304 + ln, x + 9), WAXC, WAXC_SH, off=(-3, 0)))
    parts.append(P('M1060 470 Q1080 372 1180 362 Q1290 364 1320 470 Z', WAXC, WAXC_SH, off=(-12, -6)))
    s += draw(ctx, parts, '#2e2018', FRONT_W)
    s += big_moth(ctx, 1190, 342, 1.05)
    dr = []
    for x, ln, w in ((20, 90, 34), (70, 140, 26), (120, 70, 22), (1250, 110, 30), (1310, 160, 36), (1370, 90, 26)):
        dr.append(P('M%.1f -10 L%.1f %.1f Q%.1f %.1f %.1f %.1f L%.1f -10 Z' % (x - w / 2, x - w / 3, ln, x, ln + w * 0.7, x + w / 3, ln, x + w / 2), WAXC, WAXC_SH, off=(-w * 0.2, 0)))
    s += draw(ctx, dr, '#2e2018', FRONT_W)
    p.layer('ledge', 1.0, s, ctx=ctx)
    p.light('moth', 1190, 310, 150, 0.35, 'glow', tint='a8e0d0')
    # world_2 opens here now (deep_mouth was cut): Wick and Waxley on the ledge
    p.anchor('edge', 200, 297, h=120)
    p.anchor('actor', 200, 297, h=120)
    # Waxley turns back to talk to Waxby (figures face right; flip turns him)
    p.anchor('waxley', 320, 299, flip=True)
    return p


def melt_terrace_svg(ctx, rng, x0, x1, top, bottom, col, sh):
    return draw(ctx, [melt_terrace(ctx, x0, x1, top, bottom, rng, col, sh)], '#2e2018', BACK_W)


# ================================================================ undercandle (P1)

def undercandle():
    p = Panel('undercandle', 1000, 600, [0.20, 0.18, 0.30], 'wax')
    rng = Rand(3131)
    FLOOR = 500
    # ---------------------------------------------------------------- chamber (0.4)
    ctx = Ctx('ucc')
    s = fillp(rect_d(0, 0, 1000, 600), '#2a2640')
    stone, stone_sh = '#7a7498', '#56507a'
    # rings of old balconies curving round the chamber
    for k, (y, rx) in enumerate(((150, 560), (270, 540), (390, 520))):
        s += '<path d="M%.1f %.1f Q500 %.1f %.1f %.1f L%.1f %.1f Q500 %.1f %.1f %.1f Z" fill="%s"/>' % (
            500 - rx, y - 60, y + 30, 500 + rx, y - 60, 500 + rx, y - 40, y + 52, 500 - rx, y - 40, fade(stone_sh, p.dark, 0.2))
        for a in range(-9, 10):
            t = a / 9.0
            x = 500 + rx * 0.92 * math.sin(t * 1.3)
            yy = y - 60 + 90 * (1 - (t * 1.3) ** 2 * 0.36) - 30
            s += fillp(arch_d(x - 18, x + 18, yy - 86, yy - 8), '#1a1628')
        s += '<path d="M%.1f %.1f Q500 %.1f %.1f %.1f" fill="none" stroke="%s" stroke-width="10"/>' % (500 - rx, y - 60, y + 30, 500 + rx, y - 60, fade(stone, p.dark, 0.2))
        for a in range(-12, 13, 2):
            t = a / 12.0
            x = 500 + rx * 0.95 * math.sin(t * 1.2)
            s += line('M%.1f %.1f l0 18' % (x, y - 50 + 80 * (1 - (t * 1.2) ** 2 * 0.4) - 22), fade(stone, p.dark, 0.2), 4)
    # cold pipes up the walls
    parts = []
    for x0 in (40, 880):
        for k in range(5):
            x = x0 + k * 18
            parts.append(drip_column(ctx, x, 560, 420 + (k % 3) * 60, 14, '#9aa6c8', '#6a7498'))
    s += draw(ctx, parts, '#141224', BACK_W)
    p.layer('chamber', 0.4, s, ctx=ctx)
    # ---------------------------------------------------------------- candle (0.8): the Undercandle
    ctx = Ctx('ucu')
    s = ''
    cx, top, base = 500, 72, 482
    # a round stone dais it stands on
    s += '<path d="%s" fill="#4a4466"/>' % ell_d(cx, base + 4, 170, 24)
    s += '<path d="%s" fill="#6a6488"/>' % ell_d(cx, base - 2, 156, 18)
    body = ('M%d %d C%d %d %d %d %d %d C%d %d %d %d %d %d C%d %d %d %d %d %d C%d %d %d %d %d %d Z' % (
        cx - 128, base, cx - 118, base - 160, cx - 104, top + 120, cx - 102, top + 20,
        cx - 60, top, cx + 60, top, cx + 102, top + 20,
        cx + 104, top + 120, cx + 118, base - 160, cx + 128, base,
        cx + 60, base + 12, cx - 60, base + 12, cx - 128, base))
    carve = crest_svg(cx, 300, 76, '#e0d2b0', '#8a7a5a', '#fff6e0', 2)
    parts = [P(body, WAXC, WAXC_SH, off=(-50, 0),
               over=line('M%d %d C%d %d %d %d %d %d' % (cx - 84, top + 40, cx - 86, top + 160, cx - 94, base - 120, cx - 100, base - 10), WAXC_HI, 6, op=0.7) + carve)]
    # thick drips running down from the melted crown, pooling at the foot
    for dx, ln, w in ((-92, 190, 22), (-58, 100, 16), (-20, 260, 24), (28, 140, 20), (66, 320, 24), (96, 120, 16)):
        x = cx + dx
        parts.append(P('M%.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f L%.1f %.1f Z' % (x - w / 2, top + 10, x - w / 2 - dx * 0.04, top + ln, x, top + ln + w, x + w / 2 - dx * 0.04, top + ln, x + w / 2, top + 10),
                       '#f8f0dc', WAXC_SH, off=(-w * 0.3, 0)))
    for dx, w in ((-112, 40), (70, 56), (-30, 34)):
        parts.append(P('M%.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f Z' % (cx + dx - w / 2, base + 6, cx + dx, base - 10, cx + dx + w / 2, base + 6,
                                                                                cx + dx, base + 14, cx + dx - w / 2, base + 6), '#f8f0dc', WAXC_SH, off=(-3, -2)))
    parts.append(P('M%d %d C%d %d %d %d %d %d C%d %d %d %d %d %d C%d %d %d %d %d %d Z' % (
        cx - 110, top + 24, cx - 104, top - 4, cx - 40, top - 10, cx, top - 10, cx + 40, top - 10, cx + 104, top - 4, cx + 110, top + 24,
        cx + 60, top + 36, cx - 60, top + 36, cx - 110, top + 24), '#fffaf0', '#e0d4b4', off=(-6, -4),
        over='<ellipse cx="%d" cy="%d" rx="66" ry="10" fill="#d8caa8"/>' % (cx, top + 10)))
    s += draw(ctx, parts, '#2e2418', MID_W)
    s += unlit_wick(cx, top + 6, 22, w=4)
    # the Hush curling thick round its foot: violet coils, lighter at their edges
    for k in range(6):
        r0 = 140 + k * 20
        d = 'M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f' % (cx - r0 * 0.8, base - 34 + k * 3, cx - r0 * 0.3, base - 4, cx + r0 * 0.4, base - 76 - k * 4, cx + r0 * 0.8, base - 36)
        s += line(d, '#2a2048', 20 - k * 2, op=0.85 - k * 0.08) + line(d, '#6a5a9a', 3, op=0.6 - k * 0.06)
    for ex, ey in ((cx - 118, base - 30), (cx + 128, base - 36)):
        s += dot(ex, ey, 2.2, '#c8c0f0', 0.8) + dot(ex + 7, ey - 1, 2, '#c8c0f0', 0.8)
    p.layer('candle', 0.8, s, ctx=ctx)
    p.light('under_flame', cx, top - 14, 700, 1.0, 'cold', h=60, depth=0.8, tint='a8c8ff')
    # ---------------------------------------------------------------- floor (1.0): the ring floor and the fallen bells
    ctx = Ctx('ucf')
    s = ''
    # the ring floor, its back edge just in front of the candle's dais
    s += '<path d="%s" fill="#4a4466"/>' % ell_d(500, 560, 660, 96)
    s += '<path d="%s" fill="#5a5478"/>' % ell_d(500, 554, 580, 74)
    for k in range(16):
        a = math.radians(k * 22.5)
        s += line('M%.1f %.1f L%.1f %.1f' % (500 + 300 * math.cos(a), 554 + 38 * math.sin(a), 500 + 580 * math.cos(a), 554 + 74 * math.sin(a)), '#3a3456', 2, op=0.8)
    parts = []
    for x, y, rot, k in ((150, 492, -78, 1.0), (880, 500, 70, 1.1), (290, 548, -100, 0.8)):
        parts += bell_parts(x, y - 30, 70 * k, 64 * k, rot, crack=True)
    s += draw(ctx, parts, BRONZE_LINE, FRONT_W)
    reeds = []
    for x, base_y, h, lean in ((90, 506, 90, -5), (230, 514, 66, 4), (770, 514, 70, -3), (940, 506, 86, 5)):
        rp, tip = wick_reed(ctx, x, base_y, h, lean)
        s += draw(ctx, rp, '#1a120c', FRONT_W)
        reeds.append(tip)
    p.layer('floor', 1.0, s, ctx=ctx)
    for i, (x, y) in enumerate(reeds):
        p.light('reed%d' % (i + 1), x, y, 80, 0.8, 'flame', h=8)
    p.anchor('boss', 650, FLOOR, flip=True)
    p.anchor('cone', 640, FLOOR)
    p.anchor('hollin', 575, FLOOR, flip=True)
    p.anchor('actor_near', 430, FLOOR, h=120)
    return p


# ================================================================ bells_all (P1): Evenbell as a dollhouse, every bell ringing

def singing_rattle(ctx, x, floor, k=1.0, lean=0.0):
    """A tiny Rattle of the old choir, mouth open in song."""
    B, BS, BL = '#efe6d2', '#c9bfa6', '#2a2030'
    t = 'translate(%.1f %.1f) rotate(%.1f) scale(%.2f)' % (x, floor, lean, k)
    parts = [LIMB('M-5 0 L-4 -16 M5 0 L4 -16', B, 3.4),
             P('M-9 -16 L9 -16 L7 -34 L-7 -34 Z', B, BS, off=(-1, -1), over=line('M-6 -21 L6 -21 M-6 -26 L6 -26 M-5 -31 L5 -31', BL, 1)),
             LIMB('M-7 -32 Q-16 -40 -12 -48 M7 -32 Q16 -40 12 -48', B, 3),
             E(0, -48, 13, 12, B, BS, off=(-2, -2),
               over=dot(-4.6, -50, 3.2, BL) + dot(4.6, -50, 3, BL) + '<ellipse cx="0" cy="-41" rx="4" ry="4.6" fill="%s"/>' % BL
               + '<ellipse cx="0" cy="-40" rx="2" ry="2" fill="#ff7f7f"/>')]
    return '<g transform="%s">%s</g>' % (t, draw(ctx, parts, BL, FRONT_W))


def note_glyph(x, y, k, col, line_col):
    return ('<g transform="translate(%.1f %.1f) scale(%.2f)"><ellipse cx="0" cy="0" rx="5" ry="3.8" transform="rotate(-20)" fill="%s" stroke="%s" stroke-width="1.4"/>'
            '<path d="M4.4 -1 L4.4 -18 Q10 -16 12 -10" fill="none" stroke="%s" stroke-width="2"/></g>') % (x, y, k, col, line_col, line_col)


def bells_all():
    p = Panel('bells_all', 1000, 1100, [0.28, 0.24, 0.40], 'dust')
    rng = Rand(8484)
    STONE, STONE_SH, INSIDE, INSIDE_SH = '#9a8ab8', '#6a5a8a', '#5a4e78', '#403660'
    FLOORS = (920, 700, 480, 260)
    BELLS = [(180, 800), (820, 780), (180, 580), (820, 560), (180, 360), (820, 340), (500, 330), (500, 120)]
    ctx = Ctx('bac')
    s = fillp(rect_d(0, 0, 1000, 1100), '#2a2440')
    # the stars behind the spires
    for k in range(40):
        x, y = rng.u(0, 1000), rng.u(0, 300)
        s += star4(x, y, rng.u(1.4, 3), '#fff4d8', rng.u(0.4, 0.9))
    # the outer walls: two towers, the nave between, the central belfry above it
    parts = []
    for x0, x1, top in ((40, 320, 220), (680, 960, 200)):
        parts.append(P(rect_d(x0, top, x1, 1100), STONE, STONE_SH, off=(-10, 0)))
        cx = (x0 + x1) / 2
        parts.append(P('M%d %d L%d %d L%d %d Z' % (x0 - 10, top, cx, top - 180, x1 + 10, top), '#7a5a8a', '#56406a', off=(-8, -4)))
    parts.append(P(rect_d(320, 480, 680, 1100), STONE, STONE_SH, off=(-10, 0)))
    parts.append(P('M300 480 L500 380 L700 480 Z', '#7a5a8a', '#56406a', off=(-8, -4)))
    parts.append(P(rect_d(410, 60, 590, 480), STONE, STONE_SH, off=(-8, 0)))
    parts.append(P('M396 60 L500 -60 L604 60 Z', '#7a5a8a', '#56406a', off=(-6, -4)))
    s += draw(ctx, parts, INK, FRONT_W)
    # the cutaway: the insides, floor by floor
    insides = [rect_d(64, 240, 296, 1076), rect_d(704, 220, 936, 1076), rect_d(344, 500, 656, 1076), rect_d(430, 80, 570, 500)]
    for d in insides:
        s += '<path d="%s" fill="%s"/>' % (d, INSIDE)
    for x0, x1 in ((64, 296), (704, 936), (344, 656)):
        for y in range(260, 1080, 36):
            s += line('M%d %d L%d %d' % (x0, y, x1, y), INSIDE_SH, 1.2, op=0.6)
    for y in FLOORS:
        for x0, x1 in ((64, 296), (704, 936), (344, 656)):
            if y < 480 and x0 == 344:
                continue
            s += draw(ctx, [P(rect_d(x0, y, x1, y + 12), WOOD, WOOD_SH, off=(0, -3))], INK, MID_W)
    s += draw(ctx, [P(rect_d(430, 260, 570, 272), WOOD, WOOD_SH, off=(0, -3))], INK, MID_W)
    # tall windows of the nave, a spiral stair
    for x in (390, 610):
        s += fillp(arch_d(x - 24, x + 24, 520, 660), '#3a6ab8') + '<path d="%s" fill="none" stroke="%s" stroke-width="3"/>' % (arch_d(x - 24, x + 24, 520, 660), INK)
    st = []
    for k in range(10):
        y = 912 - k * 20
        st.append(P(rect_d(600 + (k % 2) * 8, y, 650, y + 8), WOOD, WOOD_SH, off=(0, -2)))
    s += draw(ctx, st, INK, MID_W)
    # the crypt and the Undercandle in it
    s += draw(ctx, [P(rect_d(344, 1060, 656, 1076), '#4a4466', '#34304a', off=(0, -2))], INK, MID_W)
    cparts, wk, tip = candle(ctx, 500, 1062, 70, 90, INK)
    s += draw(ctx, cparts, INK, FRONT_W) + wk
    p.light('under_flame', tip[0], tip[1], 330, 1.0, 'flame', h=40)
    # the old choir, singing, on the nave floor
    for i, x in enumerate((380, 430, 480, 530, 580)):
        s += singing_rattle(ctx, x, 920, 1.3, rng.u(-6, 6))
        s += note_glyph(x + 14, 836 - (i % 2) * 14, 1.1, '#fff2c8', INK)
    # the eight bells, each on its beam, ringing (tilted)
    bparts = []
    for i, (x, y) in enumerate(BELLS):
        bparts.append(P(rect_d(x - 50, y - 70, x + 50, y - 58), WOOD, WOOD_SH, off=(0, -3)))
        bparts += bell_parts(x, y - 56, 80, 76, (-1) ** i * 14)
    s += draw(ctx, bparts, BRONZE_LINE, FRONT_W)
    # motion arcs by each bell
    for i, (x, y) in enumerate(BELLS):
        sx = (-1) ** i
        for r0 in (52, 66):
            s += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (x - sx * r0, y - 30, x - sx * (r0 + 12), y, x - sx * r0, y + 30), '#fff2c8', 3, op=0.9)
    p.layer('cutaway', 1.0, s, ctx=ctx)
    for i, (x, y) in enumerate(BELLS):
        p.light('bell%d' % (i + 1), x, y - 10, 165, 0.9, 'glow')
    # ---------------------------------------------------------------- beams (1.0, lit): gold rising from the Undercandle to every bell
    ctx = Ctx('bab')
    g = ctx.lingrad([(0, '#ffe7a0', 0.0), (0.15, '#ffe7a0', 0.34), (1, '#ffd060', 0.22)], x1=0, y1=1, x2=0, y2=0)
    s = '<path d="M478 1040 L522 1040 L512 150 L488 150 Z" fill="%s"/>' % g
    for i, (x, y) in enumerate(BELLS[:6]):
        sy = y + 40
        s += '<path d="M500 %.1f L500 %.1f L%.1f %.1f L%.1f %.1f Z" fill="%s"/>' % (sy + 60, sy + 20, x, y + 6, x, y + 26, g)
    s += radial(ctx, 500, 1000, 200, '#ffd070', 0.35)
    # not lit: the beams show only where the Undercandle and the bells light
    # them, so they grow bell by bell as the ending's chain runs
    p.layer('beams', 1.0, s, px=2.0, ctx=ctx, note='soft light only, so px 2 is enough at depth 1; shaded, so it shows as the bells light')
    return p


# ================================================================ dawn_rise (P1)

def dawn_rise():
    p = Panel('dawn_rise', 1200, 460, [0.25, 0.25, 0.40], 'embers')
    rng = Rand(2203)
    # ---------------------------------------------------------------- sky (0.25)
    ctx = Ctx('drs')
    sky = vgrad(ctx, [(0, '#a8c8ec'), (0.45, '#ffd9a0'), (0.85, '#f2a57a'), (1, '#e8906a')])
    s = '<rect x="0" y="0" width="1200" height="460" fill="%s"/>' % sky
    s += radial(ctx, 840, 200, 300, '#fff2c0', 0.8)
    s += '<circle cx="840" cy="200" r="64" fill="#fff6d8"/>'
    for k in range(18):
        a = math.radians(-190 + k * 20)
        s += '<path d="M%.1f %.1f L%.1f %.1f L%.1f %.1f Z" fill="#fff2c0" opacity="0.32"/>' % (
            840 + 74 * math.cos(a - 0.05), 200 + 74 * math.sin(a - 0.05), 840 + 420 * math.cos(a), 200 + 420 * math.sin(a),
            840 + 74 * math.cos(a + 0.05), 200 + 74 * math.sin(a + 0.05))
    for x, y, w in ((120, 120, 200), (420, 70, 160), (980, 110, 190), (700, 190, 140)):
        s += '<path d="%s" fill="#ffc8b0" opacity="0.8"/>' % cloud_d(x, y, w, w * 0.22)
        s += '<path d="%s" fill="#ffe8d8" opacity="0.8"/>' % cloud_d(x + w * 0.1, y - 4, w * 0.7, w * 0.16)
    s += fillp('M0 330 Q200 290 420 312 Q640 282 860 304 Q1040 288 1200 310 L1200 460 L0 460 Z', '#b88ab0')
    p.layer('sky', 0.25, s, ctx=ctx)
    p.light('sun', 840, 200, 400, 0.9, 'glow', depth=0.25)
    # ---------------------------------------------------------------- cathedral (0.55): Evenbell rising
    ctx = Ctx('drc')
    s = ''
    st, sh = '#7a6a9a', '#5a4a7a'
    cx, base, k = 840, 300, 0.78
    parts = []
    for tx in (cx - 132 * k, cx + 132 * k):
        parts.append(P(rect_d(tx - 40 * k, base - 250 * k, tx + 40 * k, base), st, sh, off=(-8, 0),
                       over=fillp(arch_d(tx - 18 * k, tx + 18 * k, base - 226 * k, base - 170 * k), '#3a2e58')
                       + fillp(bell_d(tx, base - 214 * k, 22 * k, 22 * k), BRONZE)
                       + line('M%.1f %.1f L%.1f %.1f' % (tx + 40 * k, base - 250 * k, tx + 40 * k, base), '#ffe8b8', 3, op=0.8)))
        parts.append(P('M%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (tx - 46 * k, base - 250 * k, tx, base - 360 * k, tx + 46 * k, base - 250 * k), sh, '#40345e', off=(-6, -2)))
    parts.append(P(rect_d(cx - 92 * k, base - 190 * k, cx + 92 * k, base), st, sh, off=(-10, 0),
                   over='<circle cx="%.1f" cy="%.1f" r="%.1f" fill="#e8b84a" stroke="#3a2e58" stroke-width="4"/>' % (cx, base - 128 * k, 34 * k)
                   + ''.join(line('M%.1f %.1f L%.1f %.1f' % (cx, base - 128 * k, cx + 34 * k * math.cos(math.radians(a)), base - 128 * k + 34 * k * math.sin(math.radians(a))), '#3a2e58', 3)
                             for a in range(0, 360, 45))
                   + fillp(arch_d(cx - 22 * k, cx + 22 * k, base - 70 * k, base), '#3a2e58')))
    parts.append(P('M%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (cx - 102 * k, base - 190 * k, cx, base - 276 * k, cx + 102 * k, base - 190 * k), sh, '#40345e', off=(-6, -2)))
    parts.append(P('M%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (cx - 16 * k, base - 272 * k, cx, base - 380 * k, cx + 16 * k, base - 272 * k), sh, '#40345e', off=(-2, -2)))
    s += draw(ctx, parts, '#241a3a', MID_W)
    # the banner flying from the spire
    ty = base - 380 * k
    s += line('M%.1f %.1f L%.1f %.1f' % (cx, ty + 10, cx, ty - 34), '#241a3a', 3)
    s += '<path d="M%.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f Z" fill="%s" stroke="#241a3a" stroke-width="2"/>' % (
        cx, ty - 32, cx - 26, ty - 42, cx - 54, ty - 30, cx - 72, ty - 20, cx - 88, ty - 26, cx - 82, ty - 8,
        cx - 56, ty - 2, cx - 36, ty - 12, cx - 18, ty - 16, cx, ty - 10, PLUM)
    # the hill it rises from, cracking open; rubble and dust tumbling off its foot
    s += fillp('M0 300 Q300 280 560 292 Q700 280 760 290 L920 290 Q1000 282 1200 300 L1200 460 L0 460 Z', '#8a7a58')
    s += fillp('M700 300 L740 282 L790 304 L850 286 L900 306 L960 288 L990 302 L1000 318 L690 318 Z', '#5a4a38')
    for i in range(34):
        x, y = rng.u(690, 1000), rng.u(210, 320)
        r = rng.u(2.4, 8)
        s += '<path d="M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z" fill="%s" stroke="#241a3a" stroke-width="1.2"/>' % (
            x - r, y, x - r * 0.3, y - r, x + r, y - r * 0.4, x + r * 0.6, y + r * 0.6, rng.pick(['#7a6a9a', '#5a4a7a', '#8a7a58']))
    for i in range(9):
        x, y = rng.u(690, 1000), rng.u(280, 316)
        s += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="#f0e2cc" opacity="0.6"/>' % (x, y, rng.u(10, 22))
    p.layer('cathedral', 0.55, s, ctx=ctx)
    # ---------------------------------------------------------------- town (1.0): Lanternfold at dawn, every lamp, townsfolk cheering
    ctx = Ctx('drt')
    s = ''
    town, lamps = lanternfold_town(ctx, Rand(2203), tint=('#ffb080', 0.18))
    s += town
    s += fillp('M-10 372 L1210 372 L1210 470 L-10 470 Z', '#c8b8d8')
    s += fillp('M-10 366 Q200 358 400 368 Q600 376 800 366 Q1000 358 1210 368 L1210 384 Q900 378 600 388 Q300 380 -10 386 Z', '#f4eef8')
    for lx in LF_STREET:
        ls, tip = street_lamp(ctx, lx, 404, 190)
        s += ls
        lamps.append(tip)
    # townsfolk: little silhouettes with their arms up
    for i, x in enumerate((230, 300, 360, 470, 560, 640, 720, 830, 900, 980)):
        s += townsfolk(ctx, x, 404 + (i % 3) * 8, rng.pick(['#5a4a7a', '#6a3a4a', '#3a4a6a', '#4a5a3a']), 0.9 + (i % 2) * 0.2)
    p.layer('town', 1.0, s, ctx=ctx)
    lamps.sort(key=lambda t: t[0])
    for i, (x, y) in enumerate(lamps):
        street = i in (0, len(lamps) - 1)
        p.light('lamp%d' % (i + 1), x, y, 110 if street else 84, 1.0 if street else 0.9, 'flame', h=13 if street else 8)
    return p


def townsfolk(ctx, x, floor, col, k=1.0):
    t = 'translate(%.1f %.1f) scale(%.2f)' % (x, floor, k)
    parts = [P('M-12 0 L12 0 L9 -30 L-9 -30 Z', col, shade_of(col), off=(-2, 0)),
             LIMB('M-7 -26 L-16 -46 M7 -26 L16 -46', col, 4),
             E(0, -38, 10, 10, '#f0c8a8', '#d8a888', off=(-1.5, -1.5), over=dot(-3, -39, 1.2, INK) + dot(3.4, -39, 1.2, INK)
               + line('M-3 -34 Q0 -31 3 -34', INK, 1))]
    return '<g transform="%s">%s</g>' % (t, draw(ctx, parts, INK, FRONT_W))


# ================================================================ hush_eye (P1)

def hush_eye():
    # no darkness: the void is painted black and the eye figure draws on top
    # of it (a lit layer would draw over the figure)
    p = Panel('hush_eye', 1000, 460, None, None)
    ctx = Ctx('hev')
    s = fillp(rect_d(0, 0, 1000, 460), '#000000')
    for k in range(1, 14):
        rx, ry = 320 + k * 44, 118 + k * 22
        s += '<path d="%s" fill="none" stroke="#2a2440" stroke-width="%.1f" opacity="%.2f"/>' % (ell_d(500, 230, rx, ry), 3.0 - k * 0.12, 0.9 - k * 0.05)
    p.layer('void', 1.0, s, lit=False, ctx=ctx, note='black with ripples; the panel has no darkness')
    p.anchor('eye', 500, 230)
    return p


def panels():
    return [glass_legend(), lanternfold(), chapel(), callings(), crypt_row(), belfry(), tallow_vista(), undercandle(),
            bells_all(), dawn_rise(), hush_eye()]
