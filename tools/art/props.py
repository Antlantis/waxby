"""Props: the reliquary blocks (WICK's ? blocks), pickups, the wall sconce,
the checkpoint altar and the level-end bell.

Tile props use the 64 x 64 frame (one 32 px tile). The altar is 64 x 96
(bottom on 96), the bell and its beam 128 x 192 (the bell hangs from
(64, 20) and swings there). Flame points the engine draws on:
sconce wick tip (32, 14), altar wick tip (32, 22).
"""
import kit
from kit import Part, ell, pth, shp
from common import (Ctx, RIM, GOLD, GOLD_SH, GOLD_HI, GOLD_LINE, WAX, WAX_SH, WAX_LINE, FLAME, FLAME_CORE,
                    FLAME_MID, svg, svg64, paint, line, dot, flame, flame_d, glow, spec, sparkle, star4, mix, IN)

IRON, IRON_SH, IRON_LINE, IRON_HI = '#4a4658', '#302c3c', '#120e18', '#8a86a0'


def rrect(x0, y0, x1, y1, r):
    return pth('M%.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f L%.1f %.1f '
               'Q%.1f %.1f %.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f Z' % (
                   x0 + r, y0, x1 - r, y0, x1, y0, x1, y0 + r, x1, y1 - r, x1, y1, x1 - r, y1,
                   x0 + r, y1, x0, y1, x0, y1 - r, x0, y0 + r, x0, y0, x0 + r, y0))


def arch_d(x0, x1, top, bottom):
    """A pointed gothic arch window."""
    cx = (x0 + x1) / 2.0
    w = x1 - x0
    spring = top + w * 0.62
    return ('M%.1f %.1f L%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f L%.1f %.1f Z' % (
        x0, bottom, x0, spring, x0, spring - w * 0.36, cx - w * 0.2, top + w * 0.1, cx, top,
        cx + w * 0.2, top + w * 0.1, x1, spring - w * 0.36, x1, spring, x1, bottom))


def candle_parts(x0, x1, top, bottom, wick_top, lcol=WAX_LINE, drips=((0.22, 5), (0.62, 8.5), (0.86, 3.6))):
    """A cream candle from top to bottom between x0 and x1, a melted cap with
    drips (fractions across, lengths), and its wick up to wick_top."""
    w = x1 - x0
    body = Part('fill', pth('M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (x0, bottom, x0, top + 1.6, x1, top + 1.6, x1, bottom)),
                fill=WAX, shade=WAX_SH, off=(-w * 0.18, 0), line=lcol, hl=spec(x0 + w * 0.2, (top + bottom) / 2 + 2, w * 0.07, (bottom - top) * 0.18, rot=0, op=0.7))
    # the cap: a rounded top whose lower edge runs down into drips
    d = 'M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f' % (
        x0 - 0.5, top + 2, x0 - 0.5, top, x0 + w * 0.3, top - 0.8, x0 + w / 2, top - 0.8,
        x0 + w * 0.7, top - 0.8, x1 + 0.5, top, x1 + 0.5, top + 2)
    pts = sorted(drips, key=lambda t: -t[0])
    x_prev = x1 + 0.5
    base = top + 3
    for f, ln in pts:
        dx = x0 + w * f
        dw = max(1.6, w * 0.13)
        d += ' L%.1f %.1f Q%.1f %.1f %.1f %.1f L%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f' % (
            x_prev, base, (x_prev + dx + dw) / 2, base + 1, dx + dw, base + 0.4,
            dx + dw, base + ln, dx + dw, base + ln + dw * 1.1, dx - dw, base + ln + dw * 1.1, dx - dw, base + ln,
            dx - dw, base + 0.4, (dx - dw + x0) / 2, base + 1.2, dx - dw - 0.5, base + 0.8)
        x_prev = dx - dw - 0.5
    d += ' L%.1f %.1f Z' % (x0 - 0.5, base)
    well = ('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s"/>' % (x0 + w / 2, top + 1, w * 0.36, 0.9 + w * 0.04, WAX_SH))
    cap = Part('fill', pth(d), fill='#fffaec', shade='#eadfc0', off=(-0.8, -0.6), line='#b89c6c', lw=0.9, over=well)
    wick = line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (x0 + w / 2, top + 1, x0 + w / 2 - 0.6, (top + wick_top) / 2,
                                                   x0 + w / 2, wick_top), '#241a14', 1.5)
    return [body, cap], wick


# ================================================================ reliquaries

RELIQ = {
    'plain': dict(base='#c08a3e', shade='#8a5824', line='#241208', light='#f0c878', panel='#5e3416',
                  window='#1e0c06', rivet='#f0d08a'),
    'gold': dict(base='#f2c94c', shade='#c08a1e', line='#301c02', light='#fff0b0', panel='#8a4a10',
                 window='#2a1004', rivet='#ffffff'),
    'spent': dict(base='#5a4c4a', shade='#3c3232', line='#0e0808', light='#7a6a66', panel='#2a2222',
                  window='#140e0e', rivet='#6a5c58'),
}


def reliquary_svg(kind):
    ctx = Ctx('rq' + kind[:2])
    c = RELIQ[kind]
    pal = dict(line=c['line'], rim=RIM, base=c['base'], shade=c['shade'])
    P = []
    box = rrect(2.2, 2.2, 61.8, 61.8, 5)
    inner = rrect(10, 10, 54, 54, 3)
    win = arch_d(21.4, 42.6, 13.4, 51)
    art = ''
    # bevel: a bright top-left lip and a raised frame
    art += line('M6 50 L6 9 Q6 6 9 6 L50 6', c['light'], 2.2, op=0.9)
    art += shp(inner, fill=c['panel'], stroke=c['line'], stroke_width=1.4)
    art += line('M12 50 L12 12.6 Q12 12 12.6 12 L50 12', mix(c['panel'], '#000000', 0.35), 1.4, op=0.8)
    art += line('M53.6 13 L53.6 53.6 L13 53.6', c['light'], 1.2, op=0.45)
    # the gothic window with the sigil in it
    art += '<path d="%s" fill="%s" stroke="%s" stroke-width="1.4"/>' % (win, c['window'], c['line'])
    if kind == 'spent':
        art += line('M27 47 L30.6 40 L28.6 35 L33 28', '#2e2424', 1.2)
        art += flame_outline(32, 45.6, 11, 19, '#3a302e')
    else:
        halo = ctx.radgrad([(0, FLAME, 0.85), (0.6, FLAME, 0.25), (1, FLAME, 0)])
        art += '<g clip-path="%s"><ellipse cx="32" cy="38" rx="13" ry="16" fill="%s"/></g>' % (ctx.clip('<path d="%s"/>' % win), halo)
        art += flame(ctx, 32, 46.4, 11.6, 21, lean=0.8, halo=False, lcol=c['line'])
        art += sigil_cross(32, 47.6, c)
    # rivets (the golden one has jewels)
    for i, (x, y) in enumerate(((6.4, 6.4), (57.6, 6.4), (6.4, 57.6), (57.6, 57.6))):
        if kind == 'gold':
            gem = ('#e8384a', '#3a8aff', '#3a8aff', '#e8384a')[i]
            art += '<path d="M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z" fill="%s" stroke="%s" stroke-width="1"/>' % (
                x, y - 3.2, x + 3.2, y, x, y + 3.2, x - 3.2, y, gem, c['line'])
            art += dot(x - 0.8, y - 0.9, 0.9, '#ffffff', 0.95)
        else:
            art += dot(x, y, 2.1, c['line']) + dot(x, y, 1.4, c['base']) + dot(x - 0.5, y - 0.5, 0.6, c['rivet'])
    # mid-edge studs on the frame
    for x, y in ((32, 6.2), (6.2, 32), (57.8, 32), (32, 57.8)):
        art += dot(x, y, 1.2, c['line'], 0.8)
    P.append(Part('fill', box, off=(-2.6, -3), rim=False, over=art,
                  hl=spec(12, 8.6, 4, 1.4, rot=-8, op=0.5 if kind != 'spent' else 0.15)))
    over = ''
    if kind == 'gold':
        over = sparkle(52, 14, 4.2, c['line']) + star4(14, 49, 2, '#ffffff', 0.9)
    return svg64(ctx, paint(ctx, P, pal) + over)


def sigil_cross(x, y, c):
    """A little gold bar the flame stands on in the window."""
    return ('<path d="M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z" fill="%s" stroke="%s" stroke-width="1"/>' % (
        x - 6, y - 1, x + 6, y - 1, x + 4.6, y + 1.8, x - 4.6, y + 1.8, c['light'], c['line']))


def flame_outline(cx, by, w, h, col):
    return '<path d="%s" fill="none" stroke="%s" stroke-width="1.4" stroke-linejoin="round"/>' % (flame_d(cx, by, w, h, 0.6), col)


# ================================================================ pickups

def wax_svg():
    ctx = Ctx('wx')
    parts, wick = candle_parts(22.4, 41.6, 19.4, 47.6, 14.4, drips=((0.2, 6), (0.55, 11), (0.84, 4.6)))
    base = Part('fill', ell(32, 48.2, 12.6, 3.2), fill='#e2d6b4', shade='#c2b28c', off=(-1, -0.8), line=WAX_LINE)
    P = [base] + parts
    pal = dict(line=WAX_LINE, rim=RIM, base=WAX, shade=WAX_SH)
    return svg64(ctx, paint(ctx, P, pal) + wick + sparkle(47.6, 20, 3.4, WAX_LINE) + star4(15.6, 33, 1.8, '#ffffff', 0.9))


def sigil_svg():
    """A round gold saint's medallion with a flame emblem (3 hidden per level)."""
    ctx = Ctx('sg')
    L = GOLD_LINE
    pal = dict(line=L, rim=RIM, base='#f2c94c', shade='#c08a1e')
    beads = ''.join(dot(32 + 17.2 * __import__('math').cos(a * 0.3927), 33 + 17.2 * __import__('math').sin(a * 0.3927), 1.15, '#fff0b0')
                    for a in range(16))
    face = ('<circle cx="32" cy="33" r="13.4" fill="#e0a82e" stroke="%s" stroke-width="1.2"/>' % L
            + '<circle cx="32" cy="33" r="13.4" fill="none" stroke="#fff0b0" stroke-width="0.8" stroke-dasharray="0" opacity="0.5"/>')
    em = flame_d(32, 42.6, 11.4, 19, 1)
    face += '<path d="%s" fill="#fff4c8" stroke="%s" stroke-width="1.3" stroke-linejoin="round"/>' % (em, L)
    face += '<path d="%s" fill="#f2a62a"/>' % flame_d(32.2, 41.6, 5.6, 10, 0.5)
    # a halo arc over the flame, the saint's mark
    face += line('M23.4 27.6 Q32 21.4 40.6 27.6', '#fff4c8', 1.4)
    P = [Part('fill', ell(32, 11.6, 4, 3.4), fill='#f2c94c', shade='#c08a1e', off=(-0.8, -1), line=L,
              over='<ellipse cx="32" cy="11.4" rx="1.8" ry="1.3" fill="%s"/>' % '#3a2408'),
         Part('fill', ell(32, 33, 20.6, 20.6), off=(-2.4, -2.8), line=L, over=beads + face,
              hl=spec(21.4, 21.6, 4.2, 1.8, rot=-40, op=0.9))]
    return svg64(ctx, paint(ctx, P, pal) + sparkle(50.4, 16, 4, L) + star4(13, 46, 1.8, '#ffffff', 0.9))


# ================================================================ the wall sconce

def sconce_svg():
    ctx = Ctx('sc')
    pal = dict(line=IRON_LINE, rim=RIM, base=IRON, shade=IRON_SH)
    P = []
    # a scrolled iron bracket: a rosette on the wall, an S arm up to the drip
    # pan, a spike finial hanging below
    P.append(Part('fill', pth('M29.6 50 L34.4 50 L32 58.6 Z'), off=(-0.8, -0.8)))
    P.append(Part('limb', pth('M28.4 45.6 C20.4 44.6 19.4 37.6 24.4 36.2 C27.6 35.4 30.6 35.6 32 33.6'), width=2.6, fill=IRON))
    P.append(Part('limb', pth('M35.6 45.6 C41.4 45 43.2 40.4 40.2 38.6'), width=2, fill=IRON))
    P.append(Part('limb', pth('M32 41 L32 33.4'), width=2.4, fill=IRON))
    P.append(Part('fill', ell(32, 46, 5, 5), off=(-1.2, -1.4),
                  over=dot(32, 46, 1.6, IRON_LINE) + dot(31.5, 45.5, 0.6, IRON_HI),
                  hl=spec(29.8, 43.6, 1.4, 0.8, rot=-30, op=0.9, col=IRON_HI)))
    P.append(Part('fill', pth('M21.6 30.2 L42.4 30.2 Q41.6 34 37 34.4 L27 34.4 Q22.4 34 21.6 30.2 Z'), off=(-1, -1.2),
                  over=line('M23.4 31.2 L40.6 31.2', IRON_HI, 0.9, op=0.9)))
    parts, wick = candle_parts(28.2, 35.8, 17.4, 30.6, 14, drips=((0.25, 3.6), (0.7, 6)))
    P += parts
    return svg64(ctx, paint(ctx, P, pal) + wick)


# ================================================================ the checkpoint altar

def altar_svg(lit):
    ctx = Ctx('al' + ('l' if lit else 'u'))
    if lit:
        stone, stone_sh, stone_hi = '#6e5a74', '#4a3a54', '#9a82a0'
        trim, trim_sh = '#ffd65a', '#c8901e'
    else:
        stone, stone_sh, stone_hi = '#54496a', '#3a3148', '#6e6488'
        trim, trim_sh = '#9a8250', '#6a5634'
    L = '#120c1a'
    pal = dict(line=L, rim=RIM, base=stone, shade=stone_sh)
    P = []
    # the plinth, the altar block and its top slab
    blocks = ''
    P.append(Part('fill', rrect(5.4, 84.4, 58.6, 94.4, 1.6), off=(-2, -2),
                  over=line('M7.4 86.4 L56.6 86.4', stone_hi, 1, op=0.8)
                  + line('M18 84.6 L18 94 M34 84.6 L34 94 M48 84.6 L48 94', L, 0.9, op=0.5)))
    niche = arch_d(22.6, 41.4, 61.4, 83.6)
    body_over = ('<path d="%s" fill="%s" stroke="%s" stroke-width="1.3"/>' % (niche, '#1a1022', L)
                 + line('M12.4 66 L20 66 M44 66 L51.6 66 M12.4 76 L20 76 M44 76 L51.6 76', L, 0.9, op=0.45)
                 + line('M12 80.6 L12 60.6 L52 60.6', stone_hi, 1, op=0.8))
    if lit:
        glow_g = ctx.radgrad([(0, '#ffc85a', 0.9), (0.6, '#ffb040', 0.3), (1, '#ffb040', 0)])
        body_over += '<g clip-path="%s"><ellipse cx="32" cy="76" rx="12" ry="14" fill="%s"/></g>' % (
            ctx.clip('<path d="%s"/>' % niche), glow_g)
        body_over += flame(ctx, 32, 81, 8.4, 13.6, lean=0.6, halo=False, lcol=L)
    else:
        body_over += flame_outline(32, 81, 8.4, 13.6, '#3e3450')
    P.append(Part('fill', rrect(10, 58, 54, 84.6, 1.2), off=(-2.6, -2.2), over=body_over))
    # gold trim along the slab's edge and the mensa itself
    P.append(Part('fill', rrect(5, 51.6, 59, 58.6, 1.8), off=(-1.8, -1.6),
                  over=line('M7 55.6 L57 55.6', trim, 2, cap='butt') + line('M7 56.8 L57 56.8', trim_sh, 0.7)
                  + ''.join(dot(x, 55.6, 0.8, '#fff6d0' if lit else '#c8b484') for x in (10, 20, 32, 44, 54))
                  + line('M7 53 L57 53', stone_hi, 0.9, op=0.8)))
    # the gold candle dish
    P.append(Part('fill', pth('M23.4 48.4 L40.6 48.4 Q40 51.6 36.4 52 L27.6 52 Q24 51.6 23.4 48.4 Z'),
                  fill=trim, shade=trim_sh, off=(-1, -1), line=GOLD_LINE,
                  over=line('M25.4 49.4 L38.6 49.4', '#fff6d0' if lit else '#c8b484', 0.8)))
    parts, wick = candle_parts(27.4, 36.6, 25.4, 48.8, 22, drips=((0.2, 5), (0.58, 9), (0.85, 3.4)))
    P += parts
    under = ''
    if lit:
        warm = ctx.radgrad([(0, '#ffb44a', 0.45), (0.5, '#ff9a3a', 0.16), (1, '#ff9a3a', 0)])
        under = '<ellipse cx="32" cy="46" rx="31" ry="44" fill="%s"/>' % warm
    over = ''
    if lit:
        over = sparkle(52, 40, 3.2, L, '#fff2c8') + star4(10, 46, 1.8, '#fff2c8', 0.9)
    return svg(ctx, under + paint(ctx, P, pal) + wick + over, 64, 96)


# ================================================================ the great bell

BRONZE, BRONZE_SH, BRONZE_HI, BRONZE_LINE = '#c8903e', '#8a5a24', '#f6d48a', '#2a1406'
WOOD, WOOD_SH, WOOD_LINE = '#6e4628', '#4a2c16', '#1a0e06'
ROPE, ROPE_SH = '#c8a060', '#8a6630'


def bell_beam_svg():
    ctx = Ctx('bm')
    pal = dict(line=WOOD_LINE, rim=RIM, base=WOOD, shade=WOOD_SH)
    grain = line('M10 12.4 Q40 11 64 12.6 Q90 14 118 12.2 M14 16.4 Q46 17.6 70 16 Q96 15 116 16.8', '#8a5a36', 0.9, op=0.9)
    knots = '<ellipse cx="44" cy="14.4" rx="2.4" ry="1.1" fill="none" stroke="%s" stroke-width="0.8"/>' % WOOD_SH
    P = [Part('fill', rrect(6, 7.6, 122, 20.2, 2.4), off=(-2, -2.4), over=grain + knots,
              hl=line('M9 9.6 L119 9.6', '#9a6a40', 1.1, op=0.9))]
    # iron bands and the hanger the bell swings on
    for x in (22, 106):
        P.append(Part('fill', rrect(x - 3, 6.4, x + 3, 21.4, 1), fill=IRON, shade=IRON_SH, off=(-1, -1), line=IRON_LINE,
                      over=dot(x, 10, 0.9, IRON_HI) + dot(x, 17.6, 0.9, IRON_HI)))
    P.append(Part('fill', rrect(57, 14.6, 71, 22.6, 1.6), fill=IRON, shade=IRON_SH, off=(-1, -1), line=IRON_LINE,
                  over=dot(60.4, 18.4, 1, IRON_HI) + dot(67.6, 18.4, 1, IRON_HI)))
    return svg(ctx, paint(ctx, P, pal), 128, 192)


def bell_svg():
    ctx = Ctx('bl')
    pal = dict(line=BRONZE_LINE, rim=RIM, base=BRONZE, shade=BRONZE_SH)
    P = []
    # the rope, hanging from the clapper to the ground (it swings with the bell)
    rope_d = 'M64 108 C64.6 130 63.2 152 64 176'
    twist = ''.join('M%.1f %.1f l3.6 -2.4 ' % (62.2 + (0.3 if i % 2 else -0.2), y) for i, y in enumerate(range(114, 176, 5)))
    P.append(Part('limb', pth(rope_d), width=4.6, fill=ROPE, line='#2a1a08',
                  over=line(twist, ROPE_SH, 1.0)))
    # the tassel at its end, frayed
    P.append(Part('fill', pth('M60.8 176 L67.2 176 L68.4 180 L69.6 189.4 L66.8 187 L65.2 190 L63.4 187 L61.2 190 '
                              'L60.4 186.6 L58.4 189.4 L59.6 180 Z'), fill=ROPE, shade=ROPE_SH, off=(-1, -1), line='#2a1a08',
                  over=line('M60.4 178.6 L67.6 178.6', '#8a2a3a', 2.2, cap='butt')))
    # the clapper inside the mouth
    P.append(Part('fill', ell(64, 104.6, 6, 5.6), fill='#5a4a40', shade='#3a2e28', off=(-1.2, -1.4), line=BRONZE_LINE,
                  hl=dot(62, 102.6, 1.2, '#9a8a80')))
    # the canon (the loop it hangs by) and the bell itself
    P.append(Part('fill', pth('M58.4 29.6 L58.4 24.6 C58.4 17.6 69.6 17.6 69.6 24.6 L69.6 29.6 L66 29.6 L66 25 '
                              'C66 22.4 62 22.4 62 25 L62 29.6 Z'), off=(-1, -1.2)))
    body = pth('M50 30 C54 26.6 74 26.6 78 30 C84.4 35 85.4 46 86.6 60 C88 76 94 88 106 96.6 C109 98.8 108 102.4 104 102.4 '
               'L24 102.4 C20 102.4 19 98.8 22 96.6 C34 88 40 76 41.4 60 C42.6 46 43.6 35 50 30 Z')
    bands = (line('M44.2 42.6 Q64 47 83.8 42.6', BRONZE_HI, 1.8) + line('M43.6 46 Q64 50.4 84.4 46', BRONZE_LINE, 0.9, op=0.6)
             + line('M28.8 91.8 Q64 98.2 99.2 91.8', BRONZE_HI, 2) + line('M26 95.6 Q64 102 102 95.6', BRONZE_LINE, 0.9, op=0.6))
    em = flame_d(64, 80, 12, 20, 1)
    bands += '<path d="%s" fill="%s" stroke="%s" stroke-width="1.3" stroke-linejoin="round"/>' % (em, BRONZE_HI, BRONZE_LINE)
    bands += '<path d="%s" fill="%s"/>' % (flame_d(64.2, 79, 5.8, 10, 0.5), '#fff6d8')
    bands += ''.join(dot(x, y, 1.1, BRONZE_LINE, 0.8) for x, y in ((50, 52), (78, 52), (40, 84), (88, 84)))
    hl = (spec(52, 60, 2.6, 16, rot=12, op=0.75) + spec(54.4, 36, 3, 1.4, rot=-20, op=0.9)
          + line('M31 96.4 Q40 92 44 84', '#ffe6b0', 1.2, op=0.8))
    P.append(Part('fill', body, off=(-5, -3), over=bands, hl=hl))
    # the dark mouth
    P.append(Part('fill', ell(64, 102.2, 41.4, 4.2), fill='#2a1608', shade='#2a1608', no_shade=True, rim=False, sil=False,
                  lw=1.2))
    P.append(Part('fill', ell(64, 104.6, 6, 5.6), fill='#5a4a40', shade='#3a2e28', off=(-1.2, -1.4), line=BRONZE_LINE,
                  rim=False, sil=False, hl=dot(62, 102.6, 1.2, '#9a8a80')))
    return svg(ctx, paint(ctx, P, pal), 128, 192)


# ================================================================ World 2 props (W6b)
# Flame, drip and pour points (frame units) are in PROP_POINTS; the engine
# draws the live flames there, as it does for the sconce and the altar.

PROP_POINTS = {
    'brazier_lit': {'flame': (32, 33)},          # the coals' top: an open flame about 1.4 x a sconce's
    'brazier_out': {'flame': (32, 33), 'smoke': (33, 30)},
    'lantern_post_lit': {'flame': (32, 30)},     # inside the glass: the flame is painted; hang the light here
    'lantern_post_out': {'flame': (32, 30)},
    'drip_spout': {'drip': (32, 36)},            # where a drop swells and falls from
    'waxfall_head': {'pour': (32, 53), 'width': 18},   # the column's top centre and width
    'nest_sconce': {'flame': (32, 14), 'cocoon': (32, 53)},
}


def prop_points_json():
    """PROP_POINTS as JSON for the engine (frame units: brazier and lantern
    frames are 64 x 96 standing on y 96; the rest are one 64-unit tile)."""
    import json
    doc = {'_doc': 'W6b World 2 props. Frame units, 2 units = 1 world px. brazier_* and lantern_post_* are 64 x 96 '
                   '(bottom centre (32, 96) on the floor); the rest are 64 x 64 tiles (drip_spout and waxfall_head '
                   'hang from the tile top). flame = where the engine draws the live flame (brazier) or hangs the '
                   'light (lantern, painted flame); drip = where drops form; pour = the waxfall column top centre, '
                   'width its width in units.'}
    doc.update({k: {n: (list(p) if isinstance(p, tuple) else p) for n, p in v.items()} for k, v in PROP_POINTS.items()})
    return json.dumps(doc, indent=1, sort_keys=True) + '\n'


EMBER_HOT, EMBER_MID, COAL, COAL_SH = '#ffd06a', '#f07a2a', '#3a2226', '#22141a'


def brazier_svg(lit):
    """A standing iron brazier (64 x 96, feet on 95): a spiked bowl of coals
    on a knopped stem and three scrolled legs."""
    ctx = Ctx('bz' + ('l' if lit else 'o'))
    pal = dict(line=IRON_LINE, rim=RIM, base=IRON, shade=IRON_SH)
    warm = '#ffb45a'
    P = []
    # the legs: a back one, then two splayed forward, each ending in a scroll foot
    for d, back in (('M32 76 Q33 86 34 93', True), ('M31 76 Q22 82 14.6 92', False), ('M33 76 Q42 82 49.4 92', False)):
        P.append(Part('limb', pth(d), width=2.8, fill=IRON_SH if back else IRON))
    for x, k in ((12.6, -1), (51.4, 1)):
        P.append(Part('fill', ell(x, 93, 3.4, 2.2), off=(-0.6, -0.6),
                      over=line('M%.1f 93 q%.1f -2 %.1f 0' % (x - 1.6 * k, 1.6 * k, 3.2 * k), IRON_LINE, 0.7)))
    # the stem with its knop
    P.append(Part('limb', pth('M32 50 L32 78'), width=3.6, fill=IRON, over=line('M31 52 L31 76', IRON_HI, 0.7, op=0.8)))
    P.append(Part('fill', ell(32, 64, 4.6, 3.8), off=(-1, -1), hl=dot(30.4, 62.6, 1, IRON_HI)))
    P.append(Part('fill', ell(32, 77.6, 5.4, 2.2), off=(-0.8, -0.8)))
    # the coals (or cold ash) heaped in the bowl
    if lit:
        coals = ''
        for x, y, r in ((20.6, 36.4, 4.6), (27.4, 33.4, 5.2), (35, 32.8, 5.4), (42.4, 34.6, 4.8), (31.2, 36.8, 4.4), (46, 37.6, 3.4)):
            coals += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s" stroke="%s" stroke-width="1"/>' % (x, y, r, COAL, IRON_LINE)
            coals += line('M%.1f %.1f l%.1f %.1f l%.1f %.1f' % (x - r * 0.5, y - r * 0.1, r * 0.4, -r * 0.3, r * 0.4, r * 0.4), EMBER_MID, 1.1)
            coals += dot(x - r * 0.1, y - r * 0.35, r * 0.28, EMBER_HOT)
        # low tongues of flame licking up between the coals
        for x, h, lean in ((24, 7, -0.8), (39.6, 6.4, 0.8)):
            coals += '<path d="%s" fill="%s" stroke="%s" stroke-width="0.9" stroke-linejoin="round"/>' % (
                flame_d(x, 34.6, 4, h, lean), FLAME, '#5a1e0c')
            coals += '<path d="%s" fill="%s"/>' % (flame_d(x, 34.4, 2, h * 0.55, lean * 0.5), FLAME_CORE)
    else:
        coals = '<path d="M14.6 39 C17 33.4 24 31.4 32 31.4 C40 31.4 47 33.4 49.4 39 Z" fill="#6a6470" stroke="%s" stroke-width="1"/>' % IRON_LINE
        coals += ''.join('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s" stroke="%s" stroke-width="0.8"/>' % (x, y, r, c, IRON_LINE)
                         for x, y, r, c in ((22, 36, 3.2, '#3a3440'), (36, 33.6, 3.4, '#3a3440'), (43, 36.4, 2.6, '#4a4450')))
        coals += line('M18 37 Q26 34 34 35 M30 38 Q38 36 46 37.4', '#8a8494', 0.8, op=0.8)
        coals += dot(29, 35.4, 0.9, '#8a3a2a', 0.9)
    # the bowl: a deep iron dish, riveted band, spiked rim
    bowl = 'M10 38.4 L54 38.4 C53 46.4 45 51.4 32 51.4 C19 51.4 11 46.4 10 38.4 Z'
    b = line('M11.6 42.4 Q32 46.6 52.4 42.4', IRON_LINE, 1.1, op=0.7)
    b += ''.join(dot(x, y, 0.9, IRON_HI if not lit else warm) for x, y in ((16, 43.6), (24, 45), (32, 45.4), (40, 45), (48, 43.6)))
    rim_hi = line('M11 39.6 L53 39.6', warm if lit else IRON_HI, 1.3, op=0.95)
    spikes = []
    for x in (10.4, 18.6, 26.8, 35, 43.2, 51.4):
        spikes.append(Part('fill', pth('M%.1f 39 L%.1f 32.6 L%.1f 39 Z' % (x - 2.4, x + 0.2, x + 2.8)), off=(-0.6, 0), lw=1.0,
                           hl=line('M%.1f 38 L%.1f 34' % (x - 1, x - 0.1), warm if lit else IRON_HI, 0.6, op=0.9)))
    P += spikes
    P.append(Part('fill', pth(bowl), off=(-3, -2.4), over=b + rim_hi, under=coals,
                  hl=spec(17, 44, 2.6, 1.2, rot=10, op=0.6, col=warm if lit else IRON_HI)))
    under = ''
    over = ''
    if lit:
        halo = ctx.radgrad([(0, '#ffb44a', 0.5), (0.5, '#ff9a3a', 0.18), (1, '#ff9a3a', 0)])
        under = '<ellipse cx="32" cy="36" rx="31" ry="34" fill="%s"/>' % halo
        over = ''.join(dot(x, y, r, EMBER_HOT, 0.95) + dot(x, y, r * 0.45, '#ffffff') for x, y, r in (
            (22, 22, 1.1), (41, 17, 0.9), (30, 12, 0.8), (46, 26, 0.7)))
    else:
        over = line('M33 30 Q30 24 34 19 Q38 14 34 8', '#bdb6c8', 1.2, op=0.7) + line('M33 30 Q30 24 34 19 Q38 14 34 8', IRON_LINE, 2.6, op=0.18)
    return svg(ctx, under + paint(ctx, P, pal) + over, 64, 96)


def lantern_post_svg(lit):
    """A lantern on an iron post (64 x 96, base on 95): a glass cage under a
    pointed cap. Lit, its flame is painted inside the glass."""
    ctx = Ctx('lp' + ('l' if lit else 'o'))
    pal = dict(line=IRON_LINE, rim=RIM, base=IRON, shade=IRON_SH)
    P = []
    # the foot and the post, with two collars
    P.append(Part('fill', pth('M22.4 95 L41.6 95 L39.6 89.4 L24.4 89.4 Z'), off=(-1.2, -1),
                  over=line('M25 90.6 L39 90.6', IRON_HI, 0.8, op=0.8)))
    P.append(Part('limb', pth('M32 89.6 L32 42'), width=3.2, fill=IRON, over=line('M31.1 88 L31.1 44', IRON_HI, 0.7, op=0.8)))
    for y in (58, 76):
        P.append(Part('fill', ell(32, y, 3.6, 1.8), off=(-0.6, -0.6)))
    # the glass: warm when lit, dark and smoky when out
    glass = 'M23.4 37.6 L24.6 16.8 L39.4 16.8 L40.6 37.6 Z'
    if lit:
        gl = ctx.lingrad([(0, '#fff2c8'), (0.55, '#ffd98a'), (1, '#f2b84b')])
        inner = flame(ctx, 32, 32.6, 7.2, 12.4, lean=0.5, halo=False, lcol='#5a1e0c')
        inner += line('M32 33.4 L32 30.6', '#241a14', 1.1)
    else:
        gl = ctx.lingrad([(0, '#3a4452'), (1, '#1e2430')])
        inner = line('M32 34 Q31.6 32 32.2 30.6', '#241a14', 1.2)
        inner += '<path d="M26 20 L27 33 L28.4 33 L27.6 20 Z" fill="#8a9aae" opacity="0.5"/>'
        inner += line('M36 18.6 Q38.4 22 37.6 26', '#6a7888', 0.6, op=0.7)
    P.append(Part('fill', pth(glass), fill=gl, shade=gl, no_shade=True, lw=1.0, over=inner))
    # the cage: side posts, a middle bar, the base plate and the roof
    P.append(Part('limb', pth('M24.6 17 L23.4 37.6'), width=1.6, fill=IRON))
    P.append(Part('limb', pth('M39.4 17 L40.6 37.6'), width=1.6, fill=IRON))
    P.append(Part('limb', pth('M32 17 L32 26.6'), width=1.2, fill=IRON))
    P.append(Part('fill', pth('M21 37 L43 37 L41.6 41.6 L22.4 41.6 Z'), off=(-1, -1), over=line('M23 38.2 L41 38.2', IRON_HI, 0.7)))
    P.append(Part('fill', pth('M20.4 17.6 L43.6 17.6 L37 9.4 L27 9.4 Z'), off=(-1.4, -1.2),
                  over=line('M22.6 16.6 L41.4 16.6', IRON_HI if not lit else '#ffd98a', 0.8, op=0.9)))
    P.append(Part('fill', pth('M27.6 9.6 L36.4 9.6 L32 6.2 Z'), off=(-0.6, -0.4)))
    P.append(Part('fill', ell(32, 6.2, 1.9, 1.7), fill=IRON, shade=IRON_SH, off=(-0.4, -0.4),
                  over=dot(32, 6.2, 0.7, IRON_LINE)))
    under, over = '', ''
    if lit:
        halo = ctx.radgrad([(0, '#ffc85a', 0.55), (0.5, '#ffb040', 0.2), (1, '#ffb040', 0)])
        under = '<ellipse cx="32" cy="27" rx="28" ry="26" fill="%s"/>' % halo
        over = sparkle(46, 20, 2.6, IRON_LINE, '#fff2c8')
    else:
        over = line('M26 16 Q27 12 29.6 12.4', '#c8c0d4', 0.6, op=0.6) + line('M40 30 L44.6 34', '#c8c0d4', 0.5, op=0.5)
    return svg(ctx, under + paint(ctx, P, pal) + over, 64, 96)


LEAD, LEAD_SH, LEAD_HI, LEAD_LINE = '#5e6878', '#404856', '#9aa6b6', '#10141c'
VERDI = '#5aa892'


def _grow(d, k, cx=32.0):
    """Scales an absolute path's points by k about (cx, 0) (the ceiling)."""
    import re
    nums = re.split(r'(-?\d+(?:\.\d+)?)', d)
    out, i = '', 0
    for tok in nums:
        if re.fullmatch(r'-?\d+(?:\.\d+)?', tok):
            v = float(tok)
            out += '%.2f' % ((cx + (v - cx) * k) if i % 2 == 0 else v * k)
            i += 1
        else:
            out += tok
    return out


def drip_spout_svg(k=1.3):
    """A leaky lead gutter spout hanging from the ceiling (the frame's top),
    a drop of water swelling at its lip. Drawn at 1.3 x its sketch so it
    reads at 32 px."""
    ctx = Ctx('ds')
    pal = dict(line=LEAD_LINE, rim=RIM, base=LEAD, shade=LEAD_SH)
    G = lambda d: pth(_grow(d, k))
    Gl = lambda d, col, w, op=None: line(_grow(d, k), col, w, op=op)
    P = []
    # the bracket plate bolted to the ceiling
    P.append(Part('fill', G('M20 0.6 L44 0.6 L42.4 5 L21.6 5 Z'), off=(-1, -1),
                  over=dot(32 - 7.6 * k, 2.8 * k, 1, LEAD_LINE) + dot(32 + 7.6 * k, 2.8 * k, 1, LEAD_LINE)))
    # the pipe, a collar, and the flared lip it drips from
    P.append(Part('fill', G('M28.8 4.6 L35.2 4.6 L34.8 18 L29.2 18 Z'), off=(-1.6, 0),
                  over=Gl('M30 5.6 L30.2 17', LEAD_HI, 0.9, op=0.9)
                  + '<path d="%s" fill="%s" opacity="0.9"/>' % (_grow('M33.2 5.6 Q34.2 11 33 15.4 L34.3 15.4 Q35 11 34.5 5.6 Z', k), VERDI)))
    P.append(Part('fill', G('M27.6 9.8 L36.4 9.8 L36.4 12.6 L27.6 12.6 Z'), off=(-0.8, -0.8),
                  over=Gl('M28.4 10.5 L35.6 10.5', LEAD_HI, 0.7)))
    P.append(Part('fill', G('M29 17.6 L35 17.6 L37.2 22.4 Q32 24.2 26.8 22.4 Z'), off=(-1.2, -0.8),
                  over='<path d="%s" fill="%s"/>' % (_grow('M27.8 21.9 Q32 23.5 36.2 21.9 Q32 22.9 27.8 21.9 Z', k), LEAD_LINE)
                  + Gl('M28 21.2 L29.4 18.4', LEAD_HI, 0.8)))
    # the swelling drop, and a green-white stain of old drips
    dy = 26.2 * k + 1.6
    drop = ('<g transform="translate(32 %.1f) scale(0.7)"><path d="M0 -6 C2.4 -2.4 4.4 0 4.4 2.6 C4.4 5 2.4 6.4 0 6.4 '
            'C-2.4 6.4 -4.4 5 -4.4 2.6 C-4.4 0 -2.4 -2.4 0 -6 Z" fill="#bfe8ff" stroke="#3a6a9a" stroke-width="2"/>'
            '<ellipse cx="-1.4" cy="2.4" rx="1" ry="1.6" fill="#ffffff"/></g>') % dy
    stain = Gl('M39.6 5 Q40.2 8 39.6 10', VERDI, 1.1, op=0.8)
    return svg64(ctx, paint(ctx, P, pal) + drop + stain)


GARG, GARG_SH, GARG_HI, GARG_LINE = '#6e6480', '#4c4460', '#9a90ae', '#140e1c'


def waxfall_head_svg():
    """A little stone gargoyle hanging from the ceiling (the frame's top), its
    mouth gaping downward, crusted with the wax it pours (the column itself
    is drawn by the engine from PROP_POINTS['waxfall_head']['pour'])."""
    ctx = Ctx('wf')
    pal = dict(line=GARG_LINE, rim=RIM, base=GARG, shade=GARG_SH)
    P = []
    # the stone bracket it juts from
    P.append(Part('fill', pth('M10 0.6 L54 0.6 L50 8 L14 8 Z'), off=(-1.4, -1.2),
                  over=line('M14 3 L50 3', GARG_HI, 0.8, op=0.8) + line('M24 1 L23 7.6 M40 1 L41 7.6', GARG_LINE, 0.8, op=0.6)))
    # pointy ears
    for d in ('M16 18 L6.6 9.6 L17.4 11.6 Z', 'M48 18 L57.4 9.6 L46.6 11.6 Z'):
        P.append(Part('fill', pth(d), off=(-0.8, -0.8)))
    # the head: round, heavy-browed, cheeks puffed round a gaping mouth
    head = 'M14 20 C14 10 22 6.6 32 6.6 C42 6.6 50 10 50 20 C50 30 46 38 42 42 L22 42 C18 38 14 30 14 20 Z'
    f = ''
    for x, k in ((24.4, 1), (39.6, -1)):
        f += '<ellipse cx="%.1f" cy="21" rx="4.6" ry="4.2" fill="%s"/>' % (x, GARG_LINE)
        f += '<ellipse cx="%.1f" cy="21.6" rx="2.6" ry="2.4" fill="%s"/>' % (x + 0.6, '#f4ead6')
        f += dot(x + 1, 22, 1.2, GARG_LINE)
        f += line('M%.1f 15.6 Q%.1f 13 %.1f 15.4' % (x - 5.4 * k, x, x + 5 * k), GARG_LINE, 1.6)
    f += '<path d="M29.6 25.6 Q32 24.4 34.4 25.6 L33.4 28.4 L30.6 28.4 Z" fill="%s"/>' % GARG_SH
    f += dot(30.8, 27, 0.7, GARG_LINE) + dot(33.2, 27, 0.7, GARG_LINE)
    f += line('M17 30 Q18 35 22 38 M47 30 Q46 35 42 38', GARG_LINE, 0.9, op=0.6)
    P.append(Part('fill', pth(head), off=(-2.4, -2.6), over=f,
                  hl=spec(21, 12, 3.4, 1.4, rot=-20, op=0.35) + line('M17 22 Q17 13 25 10', GARG_HI, 1.1, op=0.8)))
    # the gaping mouth, a fang each side, wax crusting the lip and dribbling
    mouth = 'M20.6 38 Q32 33 43.4 38 Q43 50 32 53 Q21 50 20.6 38 Z'
    m = '<path d="M24 40.6 Q32 37.4 40 40.6 Q39 48.6 32 50.6 Q25 48.6 24 40.6 Z" fill="#2a0a12"/>'
    m += '<path d="M22.6 38.4 L25 43.6 L26.8 37.4 Z M41.4 38.4 L39 43.6 L37.2 37.4 Z" fill="#f4ead6" stroke="%s" stroke-width="0.7"/>' % GARG_LINE
    P.append(Part('fill', pth(mouth), fill=GARG_SH, shade=GARG_SH, off=(0, 0), over=m))
    # molten wax brimming in the mouth and spilling over the lip in drips
    P[-1].over += '<path d="M25.4 46.4 Q32 44.2 38.6 46.4 Q37 49.6 32 50.4 Q27 49.6 25.4 46.4 Z" fill="#fff2d6"/>'
    crust = ('M20.4 46.6 Q32 43.4 43.6 46.6 Q44.2 49 42 50.2 L41.2 50.4 L41.2 54 Q41.2 55.8 39.6 55.8 Q38 55.8 38 54 '
             'L38 51.4 Q35.6 52 34 52.2 L34 57.2 Q34 59 32 59 Q30 59 30 57.2 L30 52.2 Q28 52 26.4 51.4 L26.4 53 '
             'Q26.4 54.8 24.8 54.8 Q23.2 54.8 23.2 53 L23.2 50.4 Q20 49.6 20.4 46.6 Z')
    P.append(Part('fill', pth(crust), fill='#fff2d6', shade='#e6cc9a', off=(-1, -0.8), line='#5a3a1e', lw=1.0,
                  hl=spec(26, 48, 2.2, 0.8, rot=-8, op=0.95) + dot(31.3, 55.4, 0.6, '#ffffff', 0.9)))
    return svg64(ctx, paint(ctx, P, pal))


NEST_IRON, NEST_IRON_SH, NEST_HI = '#4e4468', '#342c4a', '#9a8ac0'
NEST_WAX, NEST_WAX_SH, NEST_LINE = '#e2d4f6', '#b8a4dc', '#3a2a5a'
SILK = '#efeaf8'


def nest_sconce_svg():
    """The sconce the Gutterwings nest in: the same bracket, tinged violet,
    a lilac candle, silk wound round the arm and a fuzzy cocoon hanging where
    the finial was. Its wick tip is the sconce's (32, 14)."""
    ctx = Ctx('ns')
    pal = dict(line=IRON_LINE, rim=RIM, base=NEST_IRON, shade=NEST_IRON_SH)
    P = []
    # the cocoon, hung on a thread from the rosette
    coc = 'M32 48.6 C36.4 48.6 38 52 37.8 55 C37.6 58 35.2 59.6 32 59.6 C28.8 59.6 26.4 58 26.2 55 C26 52 27.6 48.6 32 48.6 Z'
    fuzz = line('M27.8 52.2 Q32 53.6 36.2 52.2 M27 55.4 Q32 57 37 55.4 M28.4 58 Q32 59 35.6 58', '#b4c4a4', 0.9, op=0.9)
    sq = 'translate(32 48.6) scale(0.84) translate(-32 -48.6)'
    P.append(Part('fill', pth(coc).replace(' {a}/>', ' transform="%s" {a}/>' % sq), fill='#dfe8d2', shade='#b4c4a4',
                  off=(-1.2, -1.2), line='#1c2418', over='<g transform="%s">%s</g>' % (sq, fuzz),
                  hl=spec(29.8, 51, 1.2, 0.7, rot=-30, op=0.9)))
    P.append(Part('limb', pth('M28.4 45.6 C20.4 44.6 19.4 37.6 24.4 36.2 C27.6 35.4 30.6 35.6 32 33.6'), width=2.6, fill=NEST_IRON))
    P.append(Part('limb', pth('M35.6 45.6 C41.4 45 43.2 40.4 40.2 38.6'), width=2, fill=NEST_IRON))
    P.append(Part('limb', pth('M32 41 L32 33.4'), width=2.4, fill=NEST_IRON))
    P.append(Part('fill', ell(32, 46, 5, 5), off=(-1.2, -1.4),
                  over=dot(32, 46, 1.6, IRON_LINE) + dot(31.5, 45.5, 0.6, NEST_HI),
                  hl=spec(29.8, 43.6, 1.4, 0.8, rot=-30, op=0.9, col=NEST_HI)))
    P.append(Part('fill', pth('M21.6 30.2 L42.4 30.2 Q41.6 34 37 34.4 L27 34.4 Q22.4 34 21.6 30.2 Z'), off=(-1, -1.2),
                  over=line('M23.4 31.2 L40.6 31.2', NEST_HI, 0.9, op=0.9)
                  + ''.join(dot(x, 32.4, 0.8, '#f4f2e0') for x in (24.6, 26.4, 39.4))))
    # the lilac candle, melted down its front
    P.append(Part('fill', pth('M28.2 30.6 L28.2 19 L35.8 19 L35.8 30.6 Z'), fill=NEST_WAX, shade=NEST_WAX_SH, off=(-1.4, 0),
                  line=NEST_LINE, hl=spec(29.8, 25, 0.6, 2.2, rot=0, op=0.7)))
    P.append(Part('fill', pth('M27.7 19.8 C27.7 17.6 36.3 17.6 36.3 19.8 L36.3 22.6 C36.3 24 34.6 24 34.6 22.6 L34.6 21.4 '
                              'C33.8 21 33.2 21 32.8 21.6 L32.8 25.6 C32.8 27 31 27 31 25.6 L31 21.6 C30 21 29.4 21.2 29.4 22 '
                              'L29.4 22.6 C29.4 23.8 27.7 23.8 27.7 22.6 Z'), fill='#f2eafc', shade='#d4c4ee', off=(-0.6, -0.4),
                  line=NEST_LINE, lw=0.9))
    wick = line('M32 18.4 Q31.4 16.2 32 14', '#241a14', 1.5)
    # silk wound round the arm and strung to the cocoon
    silk = line('M22.6 36.4 L27.6 38.8 M21.8 39.6 L26.4 41.4 M24 43 L28.4 43.8 M38.8 40 L41.6 42.6', SILK, 0.9, op=0.95)
    silk += line('M29.6 49.4 Q30 47 31 45.4 M34.4 49.4 Q34 47 33 45.4', SILK, 0.7, op=0.9)
    silk += line('M21.6 30.4 Q19.6 36 22.6 40 M42.4 30.4 Q44 34 42 38', SILK, 0.6, op=0.7)
    glow_v = ctx.radgrad([(0, '#b89aff', 0.3), (1, '#b89aff', 0)])
    under = '<ellipse cx="32" cy="36" rx="22" ry="26" fill="%s"/>' % glow_v
    return svg64(ctx, under + paint(ctx, P, pal) + wick + silk)


def false_stone_crack_svg():
    """A hairline crack overlay for false stone (64 frame, transparent): light
    cream lines with a faint shadow, the engine shows it only in light."""
    ctx = Ctx('fc')
    main = 'M47.6 7.4 L44 14.6 L46.6 19.4 L40.4 26 L42 31.4 L35.4 36.6 L36.6 42.4 L29.4 47.4 L27.6 54.4 L21 57.6'
    br1 = 'M40.4 26 L33.4 24.4 L29.6 27.6 M35.4 36.6 L42.4 40.6 L46.4 46.4 M29.4 47.4 L22.4 45 L17.6 47.4'
    br2 = 'M44 14.6 L50.4 16.6 M42 31.4 L48.6 33.6'
    small = 'M12.6 12.4 L17 16 L15.6 20.4 L19.6 23.4'
    s = ''
    for d, w in ((main, 1.9), (br1, 1.2), (br2, 0.9), (small, 1.1)):
        s += '<path d="%s" fill="none" stroke="#1a1020" stroke-width="%.1f" stroke-linecap="round" stroke-linejoin="round" opacity="0.4" transform="translate(0.9 0.9)"/>' % (d, w + 0.6)
        s += '<path d="%s" fill="none" stroke="#f4ead6" stroke-width="%.1f" stroke-linecap="round" stroke-linejoin="round"/>' % (d, w)
    # a few chips knocked out along the crack
    for x, y, r in ((40.6, 29, 1.4), (30.8, 50.6, 1.2), (45, 17.4, 1)):
        s += '<path d="M%.1f %.1f l%.1f %.1f l%.1f %.1f Z" fill="#f4ead6" opacity="0.9"/>' % (x, y, r * 2, r * 0.6, -r * 1.2, r * 1.6)
    return svg64(ctx, s)


def files():
    return {
        'art/props/reliquary.svg': reliquary_svg('plain'),
        'art/props/reliquary_gold.svg': reliquary_svg('gold'),
        'art/props/reliquary_spent.svg': reliquary_svg('spent'),
        'art/props/wax.svg': wax_svg(),
        'art/props/sigil.svg': sigil_svg(),
        'art/props/sconce.svg': sconce_svg(),
        'art/props/altar.svg': altar_svg(False),
        'art/props/altar_lit.svg': altar_svg(True),
        'art/props/bell_beam.svg': bell_beam_svg(),
        'art/props/bell.svg': bell_svg(),
        # World 2 (W6b)
        'art/props/brazier_lit.svg': brazier_svg(True),
        'art/props/brazier_out.svg': brazier_svg(False),
        'art/props/lantern_post_lit.svg': lantern_post_svg(True),
        'art/props/lantern_post_out.svg': lantern_post_svg(False),
        'art/props/drip_spout.svg': drip_spout_svg(),
        'art/props/waxfall_head.svg': waxfall_head_svg(),
        'art/props/nest_sconce.svg': nest_sconce_svg(),
        'art/props/false_stone_crack.svg': false_stone_crack_svg(),
        'art/props/points_world2.json': prop_points_json(),
    }


def build(write):
    for rel, text in files().items():
        write(rel, text)
