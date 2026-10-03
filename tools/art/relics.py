"""Relics: the loot icons, one per relic id, on the 64 x 64 frame, centered,
about 48 units across, no background (the engine draws the rarity frame and
beam). Same stickered, cel-shaded recipe as everything else.
"""
import math

import kit

from kit import Part, ell, pth, shp
from common import (Ctx, RIM, GOLD, GOLD_SH, GOLD_HI, GOLD_LINE, WAX, WAX_SH, WAX_LINE, FLAME, FLAME_MID,
                    FLAME_CORE, FLAME_EDGE, FLAME_LINE, svg64, paint, line, dot, flame, flame_d, glow, spec, sparkle,
                    star4, mix, xf, xell, gx)

RELICS = ['tallow_heart', 'rook_feather', 'longsword', 'iron_boots', 'moth_charm', 'bellows', 'saints_knuckle',
          'phoenix_wick', 'owls_eye', 'wind_wick', 'bell_shard', 'choir_bone',
          # v3 (spec 8.3): two a world, W3 to W6
          'sporeward', 'bone_flute', 'hoarfrost_bell', 'clockheart', 'leaded_pane', 'sanctum_glass', 'hush_pearl',
          'taper_match']


def pal(line, base='#ffffff', shade='#cccccc'):
    return dict(line=line, rim=RIM, base=base, shade=shade)


def tallow_heart(ctx):
    L = '#3a0c1a'
    heart = 'M32 29 C28.4 21.6 12.4 20.6 12.4 34 C12.4 45 24 50.6 32 57 C40 50.6 51.6 45 51.6 34 C51.6 20.6 35.6 21.6 32 29 Z'
    cap = ('M13.2 30 C15 23 27 22 31.2 28.4 L32.8 28.4 C37 22 49 23 50.8 30 L50.8 33.4 C50.8 35 48.8 35 48.8 33.4 L48.8 32.4 '
           'C47.4 31.6 46 31.6 45 32.6 L45 38.4 C45 40.4 42.4 40.4 42.4 38.4 L42.4 32.8 C39 31.4 36 31.6 34 33 L34 35 C34 36.4 32 36.4 32 35 '
           'L32 33.2 C29 31.4 25 31.2 22.4 33 L22.4 36.8 C22.4 38.6 19.8 38.6 19.8 36.8 L19.8 32.8 C18 32.2 16 32.6 13.2 33.6 Z')
    P = [Part('fill', pth(heart), fill='#f07a8a', shade='#c24a62', off=(-3, -3.4), line=L,
              hl=spec(19.6, 38.4, 2.2, 4, rot=20, op=0.9) + dot(22, 45, 1, '#ffffff', 0.8)),
         Part('fill', pth(cap), fill='#ffc4c8', shade='#f2a0aa', off=(-0.8, -0.8), line='#b04a60', lw=0.9, rim=False)]
    wick = line('M32 29.4 Q31.4 26.4 32.2 23.6', '#241a14', 1.5)
    return paint(ctx, P, pal(L)) + wick + flame(ctx, 32.2, 24.4, 8.4, 15.6, lean=0.8) + sparkle(51, 16, 3.2, L)


def rook_feather(ctx):
    L = '#07060e'
    t = 'translate(31 33) rotate(-52)'
    vane = ('M-15 0 C-12 -5 -8 -8 -4 -8.8 L-2.4 -6.8 L-0.8 -9.6 C4 -10.2 8 -9.4 10.6 -8.6 L11.4 -6.4 L13.4 -8 '
            'C19 -6 23 -3.4 26.6 -0.4 C23 3.2 19 6 14.6 7.4 L13 5.6 L11.8 7.8 C8 8.8 5 9 1.6 8.8 L0.4 6.6 L-1.8 8.6 '
            'C-7.4 8 -12 5.6 -15 0 Z')
    sheen = gx(line('M-10 -3.4 C-4 -6.6 6 -7.6 16 -4.6', '#6a78e0', 2.2, op=0.9)
               + line('M-8 -2.2 C-2 -4.6 8 -5.4 18 -3', '#c4b2ff', 0.9, op=0.95)
               + line('M-6 4.6 C2 6.6 10 6.2 17 3.4', '#4a56b0', 1.6, op=0.8)
               + line(''.join('M%.1f -0.2 l%.1f -6.4 M%.1f 0.2 l%.1f 6.4 ' % (x, 3.2, x, 3.2) for x in (-8, -2, 4, 10, 16)),
                      '#0c0a18', 0.7, op=0.8)
               + line('M-17.6 0.4 L23 -0.2', '#d8d4ec', 1.1), t)
    P = [Part('limb', xf('M-27 0.8 L-15 0.3', t), width=2.2, fill='#d8d4ec', line=L),
         Part('fill', xf(vane, t), fill='#2a2846', shade='#16142a', off=(0, 2.6), line=L, over=sheen,
              hl=gx(spec(4, -5.4, 3.6, 1, rot=-6, op=0.85), t))]
    fluff = gx(line('M-15 0 C-17 -3 -19 -3.4 -20 -2 M-15 0.6 C-17 3.6 -19.4 4 -20.4 2.6', '#3a3860', 1.6), t)
    return fluff + paint(ctx, P, pal(L)) + sparkle(47.6, 43, 3, L) + star4(18, 17, 1.8, '#c4b2ff', 0.95)


def longsword(ctx):
    L = '#140e1c'
    t = 'translate(32 32) rotate(-45)'
    blade = 'M-12.6 -3 L24 -3 L31.4 0 L24 3 L-12.6 3 Z'
    guard = 'M-15.6 -10.4 Q-13.2 -11.4 -12 -9.6 L-12.2 9.6 Q-13.2 11.4 -15.6 10.4 Q-14 0 -15.6 -10.4 Z'
    P = [Part('limb', xf('M-27.4 0 L-16 0', t), width=3.8, fill='#6a3a5a', line=L,
              over=gx(line('M-25.4 -1.8 L-24 1.8 M-22.4 -1.8 L-21 1.8 M-19.4 -1.8 L-18 1.8', '#3a1a30', 0.8), t)),
         Part('fill', xf(blade, t), fill='#e4e8f2', shade='#9ea4bc', off=(0, -1.6), line=L,
              over=gx(line('M-10 0 L22 0', '#8a90a8', 1.1) + line('M-10 -1.9 L24 -1.9', '#ffffff', 0.9), t)),
         Part('fill', xf(guard, t), fill=GOLD, shade=GOLD_SH, off=(-1, 0), line=GOLD_LINE),
         Part('fill', xell(-13.8, 0, 2.8, 2.8, t), fill='#3a8aff', shade='#1a4ab0', off=(-0.6, -0.6), line=GOLD_LINE,
              hl=gx(dot(-14.6, -0.8, 0.8, '#ffffff'), t)),
         Part('fill', xell(-29, 0, 3, 3, t), fill=GOLD, shade=GOLD_SH, off=(-0.6, -0.8), line=GOLD_LINE,
              hl=gx(dot(-29.8, -0.8, 0.8, GOLD_HI), t))]
    # flourishes: the guard's curled tips
    curls = gx(line('M-13.8 -10.4 Q-10 -13 -8.6 -9.6 M-13.8 10.4 Q-10 13 -8.6 9.6', GOLD_LINE, 3.2)
               + line('M-13.8 -10.4 Q-10 -13 -8.6 -9.6 M-13.8 10.4 Q-10 13 -8.6 9.6', GOLD, 1.4), t)
    return paint(ctx, P, pal(L)) + curls + sparkle(50.6, 10.6, 3.4, L) + star4(16, 44, 1.8, '#ffffff', 0.9)


def boot_shape(x, y, k=1.0):
    """A heavy iron boot, its heel's bottom-left corner at (x, y)."""
    def p(px, py):
        return '%.1f %.1f' % (x + px * k, y + py * k)
    return ('M%s L%s Q%s %s L%s Q%s %s L%s C%s %s %s L%s Z' % (
        p(0, 0), p(0, -24), p(0, -28), p(4, -28), p(13, -28), p(16, -28), p(16, -25), p(16, -12),
        p(22, -12.6), p(29, -9), p(29, -3.6), p(29, 0)))


def iron_boots(ctx):
    L = '#14121e'
    P = []
    for (x, y, base, shade) in ((13.4, 44.6, '#6e7290', '#4e526a'), (22, 53.4, '#9296ae', '#62667e')):
        plates = (line('M%.1f %.1f L%.1f %.1f M%.1f %.1f L%.1f %.1f' % (x + 0.6, y - 20.4, x + 15.4, y - 20.4,
                                                                     x + 0.6, y - 15.4, x + 15.4, y - 15.4), L, 1, op=0.75)
                  + line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (x + 16, y - 11.6, x + 18.4, y - 6.4, x + 17.4, y - 2.2), L, 0.9, op=0.7)
                  + line('M%.1f %.1f L%.1f %.1f' % (x + 0.6, y - 1.6, x + 28.4, y - 1.6), '#26243a', 2.2, cap='butt')
                  + dot(x + 8, y - 8, 1.3, L) + dot(x + 7.6, y - 8.4, 0.5, '#e8ecf8')
                  + dot(x + 4, y - 24.4, 1, L, 0.8) + dot(x + 12, y - 24.4, 1, L, 0.8))
        P.append(Part('fill', pth(boot_shape(x, y)), fill=base, shade=shade, off=(-2, -2), line=L, over=plates,
                      hl=spec(x + 4.4, y - 22.6, 1.4, 0.9, op=0.9) + spec(x + 23.6, y - 8.2, 2, 0.9, rot=-12, op=0.9)))
        # the rolled cuff at the top
        P.append(Part('fill', pth('M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (x - 1, y - 26, x + 17, y - 26, x + 16.4, y - 29.4,
                                                                                   x - 0.4, y - 29.4)),
                      fill=mix(base, '#ffffff', 0.25), shade=base, off=(-0.8, -0.8), line=L))
    quake = line('M8 57.6 Q11 55 14 57.6 M52 57.6 Q55 55 58 57.6', '#fff2c8', 1.6)
    return paint(ctx, P, pal(L)) + quake + sparkle(50, 16, 3.2, L)


def moth_charm(ctx):
    L = '#2a1a04'
    P = []
    enamel = '#d8c4f4'
    for k in (-1, 1):
        def X(x):
            return 32 + k * (x - 32)
        fore = 'M%.1f 31 C%.1f 20 %.1f 13.4 %.1f 16.6 C%.1f 19 %.1f 30 %.1f 36.4 Z' % (
            X(31), X(24), X(10.4), X(7.4), X(4.8), X(14), X(30.6))
        hind = 'M%.1f 37 C%.1f 38 %.1f 44 %.1f 50 C%.1f 55 %.1f 51 %.1f 40.6 Z' % (
            X(31), X(22), X(12), X(15.4), X(18.6), X(27), X(31))
        spots = (dot(X(17.6), 24.4, 3.6, '#6a4aa8') + dot(X(17.6), 24.4, 1.8, '#ffc04a') + dot(X(17), 23.8, 0.7, '#ffffff')
                 + dot(X(20.8), 45, 2.2, '#6a4aa8') + dot(X(20.6), 44.6, 0.7, '#ffffff'))
        inner = ('M%.1f 31.6 C%.1f 22.6 %.1f 17.8 %.1f 19.8 C%.1f 21.6 %.1f 29.4 %.1f 34.6 Z' % (
            X(29.4), X(23.4), X(12.4), X(10.2), X(8.4), X(15.4), X(29)))
        P.append(Part('fill', pth(hind), fill=GOLD, shade=GOLD_SH, off=(-1, -1), line=L,
                      over='<path d="M%.1f 38.6 C%.1f 40.6 %.1f 45 %.1f 48 C%.1f 50.4 %.1f 47.6 %.1f 40.6 Z" fill="%s"/>' % (
                          X(29.4), X(23), X(15.6), X(17), X(19.6), X(25.6), X(29.4), enamel) + dot(X(20.8), 45, 2.2, '#6a4aa8')
                      + dot(X(20.6), 44.6, 0.7, '#ffffff')))
        P.append(Part('fill', pth(fore), fill=GOLD, shade=GOLD_SH, off=(-1, -1.2), line=L,
                      over='<path d="%s" fill="%s"/>' % (inner, enamel) + dot(X(17.6), 24.4, 3.6, '#6a4aa8')
                      + dot(X(17.6), 24.4, 1.8, '#ffc04a') + dot(X(17), 23.8, 0.7, '#ffffff')))
    # antennae, feathery, and the jump ring between them
    for k in (-1, 1):
        P.append(Part('limb', pth('M%.1f 25 Q%.1f 17 %.1f 13.6' % (32 + k * 1.2, 32 + k * 4, 32 + k * 9)), width=1.2, fill=GOLD, line=L))
    P.append(Part('fill', ell(32, 18.6, 2.6, 2.6), fill=GOLD, shade=GOLD_SH, off=(-0.6, -0.6), line=L,
                  over=dot(32, 18.6, 1.1, L)))
    # the body: an amber cabochon
    body = ctx.radgrad([(0, '#fff0b0'), (0.5, '#ffa23a'), (1, '#c8501a')], cx=0.4, cy=0.3, r=0.7)
    P.append(Part('fill', ell(32, 37, 3.8, 11), fill=body, no_shade=True, line=L,
                  hl=spec(30.8, 31.4, 1, 2.6, rot=0, op=0.95)))
    P.append(Part('fill', ell(32, 25.6, 3.2, 2.8), fill=GOLD, shade=GOLD_SH, off=(-0.6, -0.8), line=L))
    return paint(ctx, P, pal(L)) + sparkle(52, 51, 3, L) + star4(12, 50, 1.8, '#ffffff', 0.9)


def bellows(ctx):
    """Leather bellows seen from above: a pear-shaped board over pleated
    leather, a brass nozzle up and to the right, the handle down to the left."""
    L = '#1e1006'
    t = 'translate(31 34) rotate(-40)'
    board = 'M-14 0 C-14 -11 -5 -15 4 -12 C10 -10 15 -5 18 -3.2 L18 3.2 C15 5 10 10 4 12 C-5 15 -14 11 -14 0 Z'
    leather = 'M-17.4 0 C-17.4 -13.6 -6 -18.6 4.6 -15 C11.6 -12.6 16.6 -7 20 -4.6 L20 4.6 C16.6 7 11.6 12.6 4.6 15 C-6 18.6 -17.4 13.6 -17.4 0 Z'
    pleats = ''.join('M%.1f %.1f L%.1f %.1f ' % (x0, y0, x1, y1) for x0, y0, x1, y1 in (
        (-16.4, -6, -13.2, -4.4), (-12.6, -12.6, -10.4, -9.8), (-5, -16.4, -4.2, -13), (3.4, -15.4, 3.4, -12),
        (11, -11.6, 9.6, -9), (-16.4, 6, -13.2, 4.4), (-12.6, 12.6, -10.4, 9.8), (-5, 16.4, -4.2, 13), (3.4, 15.4, 3.4, 12),
        (11, 11.6, 9.6, 9)))
    P = [Part('limb', xf('M-18 0 L-27 0', t), width=4.4, fill='#c08a4e', line=L),
         Part('fill', xell(-28.6, 0, 3.4, 3.4, t), fill='#c08a4e', shade='#8a5a2a', off=(-0.6, -0.6), line=L),
         Part('fill', xf(leather, t), fill='#8a4e2a', shade='#5e3016', off=(0, 1.4), line=L,
              over=gx(line(pleats, '#3a1a0a', 1.1), t)),
         Part('fill', xf(board, t), fill='#c89056', shade='#8e5c2c', off=(0, 2.2), line=L,
              over=gx(line('M-8 -6.4 Q2 -8.4 10 -4.6 M-9 5 Q0 8 8 5.4', '#a06a36', 0.9)
                      + '<circle cx="-1" cy="0" r="4.4" fill="%s" stroke="%s" stroke-width="1.1"/>' % (GOLD, GOLD_LINE)
                      + dot(-1, 0, 1.6, GOLD_SH) + dot(-2.2, -1.4, 0.8, GOLD_HI)
                      + ''.join(dot(x, y, 0.8, '#f0d08a') for x, y in ((-10.4, -5), (-10.4, 5), (8, -7.4), (8, 7.4))), t),
              hl=gx(spec(-7, -7, 3, 1, rot=-20, op=0.6), t)),
         Part('fill', xf('M17 -3.6 L29 -2 Q31 0 29 2 L17 3.6 Z', t), fill=GOLD, shade=GOLD_SH, off=(0, 1), line=GOLD_LINE,
              over=gx(line('M20.6 -3.2 L20.6 3.2 M24 -2.7 L24 2.7', GOLD_LINE, 0.8, op=0.7), t))]
    puff = ''.join('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="#fff4dc" stroke="%s" stroke-width="1.2"/>' % (x, y, r, L)
                   for x, y, r in ((55.4, 11.6, 3), (51, 7.4, 2.2), (57.6, 5.2, 1.7)))
    embers = dot(47.6, 4, 1.4, FLAME) + dot(58.6, 16.6, 1.1, FLAME_EDGE)
    return paint(ctx, P, pal(L)) + puff + embers + sparkle(12, 18, 2.8, L)


def saints_knuckle(ctx):
    L = '#1a0c08'
    s = glow(ctx, 32, 30, 28, FLAME, 0.5)
    # the holy fire behind, licking up round the fist
    for cx, by, w, h, lean in ((18, 44, 12, 24, -4), (46, 40, 12, 24, 4), (31, 32, 16, 26, 1), (24, 35, 10, 20, -2),
                               (40, 33, 10, 20, 3)):
        s += ('<path d="%s" fill="%s" stroke="%s" stroke-width="1.4" stroke-linejoin="round"/>' % (
            flame_d(cx, by, w, h, lean), FLAME_EDGE, FLAME_LINE))
        s += '<path d="%s" fill="%s"/>' % (flame_d(cx, by - 1, w * 0.62, h * 0.66, lean * 0.6), FLAME)
    P = []
    steel, steel_sh = '#c9cdda', '#8b90a8'
    # the cuff, flared, trimmed in gold
    P.append(Part('fill', pth('M12 34.4 L24 36 L24 52 L10.6 54.6 Q8.6 44 12 34.4 Z'), fill=steel, shade=steel_sh, off=(-1.6, -1.4),
                  line=L, over=line('M11.4 37.6 L24 38.8', GOLD, 1.8) + line('M10.6 51.8 L24 49.8', GOLD, 1.8)))
    # the fist from the side, punching right: the back of the hand on top,
    # four curled fingers stacked down its front, the thumb folded across
    fist = ('M22 32 C22 27.4 25.6 25.4 30 25.4 L43 25.4 C47.4 25.4 50.4 26.6 51.4 29.6 C54.6 30.4 54.6 35.6 51.8 36.4 '
            'C54.6 37.4 54.6 42.4 51.6 43.2 C54.2 44.4 53.8 49.6 50.4 50 C49.4 52.4 46.6 53.4 43 53.4 L28 53.4 '
            'C24 53.4 22 50.4 22 46.4 Z')
    fingers = (line('M42.6 36.4 L51.8 36.4 M42.6 43.2 L51.6 43.2 M43 49.8 L50.4 50', L, 1.1, op=0.85)
               + line('M42.6 29.4 L42.6 50.8', L, 1.1, op=0.6)
               + ''.join(spec(47.6, y, 1.8, 0.7, rot=0, op=0.9) for y in (30.6, 38, 45.2)))
    thumb = ('<path d="M26 42.2 C30.4 39.8 37.4 40 41.6 42.2 C43.6 43.4 43.2 46.8 40.6 47 L27.4 47 C25 47 24.2 43.4 26 42.2 Z" '
             'fill="%s" stroke="%s" stroke-width="1.2" stroke-linejoin="round"/>') % (mix(steel, '#ffffff', 0.35), L)
    plate = line('M24.4 33 Q32 30.4 41 31.6', L, 1, op=0.55)
    P.append(Part('fill', pth(fist), fill=steel, shade=steel_sh, off=(-2, -2.2), line=L, over=fingers + thumb + plate,
                  hl=spec(28.4, 28.6, 3, 1.1, rot=-8, op=0.95)))
    return s + paint(ctx, P, pal(L)) + star4(54, 14, 2.2, FLAME_CORE, 0.95) + star4(8, 22, 1.6, FLAME_CORE, 0.9)


def feather_d(w, ln):
    """A fire feather along -y from the origin: narrow at the quill, a round tip."""
    a = w / 2.0
    return ('M0 0 C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f 0 %.1f C%.1f %.1f %.1f %.1f %.1f %.1f '
            'C%.1f %.1f %.1f %.1f 0 0 Z') % (
        a * 0.6, -ln * 0.1, a, -ln * 0.4, a, -ln * 0.7,
        a, -ln * 0.92, a * 0.4, -ln, -ln,
        -a * 0.5, -ln, -a * 0.9, -ln * 0.86, -a * 0.8, -ln * 0.66,
        -a * 0.7, -ln * 0.4, -a * 0.4, -ln * 0.1)


def phoenix_wick(ctx):
    L = '#2a0e06'
    parts = []
    # a little candle stub
    P = [Part('fill', pth('M22.6 58 L22.6 44.6 L37.4 44.6 L37.4 58 Z'), fill=WAX, shade=WAX_SH, off=(-2.4, 0), line=WAX_LINE,
              hl=spec(25, 53, 0.8, 2.6, rot=0, op=0.8)),
         Part('fill', pth('M22 44.8 C22 42.6 26 42 30 42 C34 42 38 42.6 38 44.8 L38 48.4 C38 49.8 36 49.8 36 48.4 L36 47 '
                          'C34.6 46.4 33 46.4 32 47.4 L32 51.4 C32 53 29.6 53 29.6 51.4 L29.6 47.4 C27.6 46.6 25.6 46.8 24.4 47.6 '
                          'L24.4 48.8 C24.4 50 22 50 22 48.8 Z'), fill='#fffaec', shade='#eadfc0', off=(-0.8, -0.6),
              line='#b89c6c', lw=0.9, rim=False)]
    s = glow(ctx, 38, 26, 26, '#ff8a3a', 0.55)
    # the flame: one raised wing of fire, a smooth leading edge on the right
    # and feather lobes down its trailing edge, rising from the wick
    notches = [(43.4, 4.6), (35, 9.8), (28.4, 15.8), (24.4, 23.6), (23.8, 31.4), (26.4, 38), (30.4, 41.6)]
    cx0, cy0 = 40, 25
    d = 'M30.4 41.6 C38 39.4 47.6 31.6 49.8 21.4 C51.2 14.4 48.6 8 43.4 4.6'
    for (x0, y0), (x1, y1) in zip(notches, notches[1:]):
        mx, my = (x0 + x1) / 2.0, (y0 + y1) / 2.0
        nx, ny = mx - cx0, my - cy0
        k = 4.6 / math.hypot(nx, ny)
        d += ' Q%.1f %.1f %.1f %.1f' % (mx + nx * k, my + ny * k, x1, y1)
    d += ' Z'
    fire = ctx.radgrad([(0, '#fff6d0'), (0.3, '#ffd05a'), (0.62, '#f58a2e'), (1, '#d8362a')], cx=0.3, cy=0.95, r=1.0)
    quills = ''.join('M%.1f %.1f L%.1f %.1f ' % (cx0 + (x - cx0) * 0.25 + 2, cy0 + (y - cy0) * 0.25 + 4, x + (cx0 - x) * 0.2,
                                                y + (cy0 - y) * 0.2) for x, y in notches[1:-1])
    wing = '<path d="%s" fill="%s" stroke="%s" stroke-width="1.5" stroke-linejoin="round"/>' % (d, fire, FLAME_LINE)
    wing += line(quills, '#c8402a', 1.1, op=0.8)
    wing += line('M33.4 38 C40 34 45 28 46.6 19.4', '#fff2c8', 1.3, op=0.9)
    wing += '<path d="%s" fill="%s" stroke="%s" stroke-width="1.2"/>' % (flame_d(30.4, 43.4, 7, 10, 0.4), FLAME_CORE, FLAME_LINE)
    wick = line('M30.2 43 Q29.8 41.4 30.2 39.8', '#241a14', 1.4)
    return s + paint(ctx, P, pal(L)) + wick + wing + sparkle(52, 44, 3, L, FLAME_CORE) + star4(12, 20, 1.8, FLAME_CORE, 0.9)


def owls_eye(ctx):
    """A great amber owl's eye set in a ring of tawny feathers, ear tufts up:
    it sees what the dark hides."""
    L = '#2a1606'
    P = []
    # the ear tufts and the feathered facial disc
    for k in (-1, 1):
        P.append(Part('fill', pth('M%.1f 22 C%.1f 14 %.1f 8 %.1f 6.4 C%.1f 10 %.1f 16 %.1f 24 Z' % (
            32 + k * 8, 32 + k * 10, 32 + k * 15, 32 + k * 19, 32 + k * 19.6, 32 + k * 18.4, 32 + k * 16)),
            fill='#a8743a', shade='#7a4e22', off=(-0.8, -0.8), line=L))
    disc = ''
    n = 16
    pts = []
    for i in range(n * 2):
        a = math.pi * 2 * i / (n * 2)
        r = 22.6 if i % 2 == 0 else 19.6
        pts.append((32 + r * math.cos(a), 36 + r * 0.94 * math.sin(a)))
    disc = 'M' + ' L'.join('%.1f %.1f' % p for p in pts) + ' Z'
    rays = line(''.join('M%.1f %.1f L%.1f %.1f ' % (32 + 12.6 * math.cos(a), 36 + 12 * math.sin(a), 32 + 18.6 * math.cos(a),
                                                   36 + 17.6 * math.sin(a)) for a in (math.pi * 2 * i / 16 for i in range(16))),
                '#8a5a2a', 1.0, op=0.9)
    P.append(Part('fill', pth(disc), fill='#d8a868', shade='#a8743a', off=(-2.4, -2.6), line=L, over=rays))
    # the eye: a gold rim, the amber iris, a slit of pupil, two highlights
    iris = ctx.radgrad([(0, '#fff2a0'), (0.45, '#ffb82a'), (1, '#c8601a')], cx=0.45, cy=0.4, r=0.6)
    P.append(Part('fill', ell(32, 36, 12.4, 12.4), fill=GOLD, shade=GOLD_SH, off=(-1, -1), line=GOLD_LINE))
    P.append(Part('fill', ell(32, 36, 9.6, 9.6), fill=iris, no_shade=True, line=L,
                  over='<ellipse cx="32.4" cy="36" rx="3.4" ry="6" fill="#1a0c04"/>'
                  + dot(28.6, 32.4, 2.2, '#ffffff') + dot(35.4, 39.4, 1.1, '#ffffff', 0.85)))
    return paint(ctx, P, pal(L)) + sparkle(52, 12, 3.4, L, '#fff6d0') + star4(11, 50, 2, '#fff6d0', 0.95)


def wind_wick(ctx):
    """A candle whose flame the wind bends but cannot put out: pale gusts
    curl round it."""
    L = '#1a1024'
    s = glow(ctx, 30, 26, 24, FLAME, 0.5)
    P = [Part('fill', pth('M22.6 58 L22.6 38 L37.4 38 L37.4 58 Z'), fill=WAX, shade=WAX_SH, off=(-2.4, 0), line=WAX_LINE,
              hl=spec(25, 48, 0.9, 4, rot=0, op=0.8)),
         Part('fill', pth('M22 38.4 C22 36.2 26 35.6 30 35.6 C34 35.6 38 36.2 38 38.4 L38 42 C38 43.4 36 43.4 36 42 L36 40.6 '
                          'C34.6 40 33 40 32 41 L32 45 C32 46.6 29.6 46.6 29.6 45 L29.6 41 C27.6 40.2 25.6 40.4 24.4 41.2 '
                          'L24.4 42.4 C24.4 43.6 22 43.6 22 42.4 Z'), fill='#fffaec', shade='#eadfc0', off=(-0.8, -0.6),
              line='#b89c6c', lw=0.9, rim=False)]
    wick = line('M30 36.4 Q29.8 34.4 30.8 33', '#241a14', 1.5)
    fl = flame(ctx, 31.4, 34.8, 10.4, 20, lean=7, halo=False)
    gusts = ''
    for d, w in (('M8 22 C16 16 26 20 22 26 C19 30 13 26 17 23', 2.4), ('M44 44 C52 40 58 44 55 50 C52 55 46 51 50 48', 2.2),
                 ('M40 14 C48 10 56 14 58 20', 2.0)):
        gusts += line(d, L, w + 2.6) + line(d, '#d8f0ff', w)
    return s + paint(ctx, P, pal(L)) + wick + fl + gusts + sparkle(12, 50, 2.8, L)


def bell_shard(ctx):
    """A broken piece of a bronze bell: its crown, waist and flared lip, the
    jagged break showing the metal's thickness, still humming."""
    L = '#2a1606'
    jag = [(35.4, 11.4), (33, 17), (38, 22.4), (34.6, 27.6), (40.4, 33.4), (37, 38.4), (43.4, 44), (41, 48.6), (46, 53.4)]
    shard = ('M22 12.4 C26 9.4 31.6 9.2 35.4 11.4 L' + ' L'.join('%.1f %.1f' % p for p in jag[1:])
             + ' C32 57 17 56 7.4 51.6 C7.2 48.6 10 46.4 12.6 44.4 C16 36 16.6 26 17.8 20 C18.4 15.6 19.8 13.6 22 12.4 Z')
    inside = 'M' + ' L'.join('%.1f %.1f' % p for p in jag) + ' L' + ' L'.join(
        '%.1f %.1f' % (x - 3.6, y + 0.6) for x, y in reversed(jag)) + ' Z'
    clip = ctx.clip('<path d="%s"/>' % shard)
    art = ('<g clip-path="%s"><path d="%s" fill="#6a3a14"/>%s%s</g>' % (
        clip, inside,
        line('M4 47.6 C16 53 32 54.6 50 50.6', '#f2c07a', 2.2, op=0.95) + line('M4 44.6 C16 50 32 51.6 50 47.6', '#8e5a24', 1.2),
        line('M12 25 C20 27.6 30 28.4 40 27.6', '#8e5a24', 2.2) + line('M12 22.6 C20 25.2 30 26 40 25.2', '#f2c07a', 0.9)))
    P = [Part('fill', pth(shard), fill='#c8893a', shade='#8e5a24', off=(-2.6, -2.4), line=L, over=art,
              hl=spec(22, 20, 1.6, 4.4, rot=18, op=0.9) + spec(15, 46, 3, 1.1, rot=20, op=0.7))]
    # the stub of its hanging loop
    P.insert(0, Part('fill', pth('M23.6 12 C23.6 6 30.4 5 32 9.6 L29 11 C28.4 9 26.4 9.4 26.6 12 Z'), fill='#a8742a', shade='#7a4e1a',
                     off=(-0.5, -0.5), line=L))
    hum = ''
    for d in ('M50 22 Q55 28 53.4 35', 'M55.6 15 Q62.6 24 60.4 37', 'M5 20 Q2.6 27 4.6 34'):
        hum += line(d, L, 4.2) + line(d, '#fff2c8', 1.8)
    return paint(ctx, P, pal(L)) + hum + star4(47, 8, 2.2, '#fff2c8', 0.95)


def choir_bone(ctx):
    """A little bone flute of the choir, a gold halo over it, notes rising:
    every kill mends the flame."""
    L = '#2a1e14'
    t = 'translate(31 36) rotate(-38)'
    bone = ('M-18 -3.4 L18 -3.4 C19 -7.8 25.4 -8 25.6 -3.4 C28.6 -3.6 29 3.6 25.6 3.4 C25.4 8 19 7.8 18 3.4 '
            'L-18 3.4 C-19 7.8 -25.4 8 -25.6 3.4 C-28.6 3.6 -29 -3.6 -25.6 -3.4 C-25.4 -8 -19 -7.8 -18 -3.4 Z')
    holes = gx(''.join(dot(x, 0, 1.4, L) for x in (-9, -2, 5, 12)), t)
    P = [Part('fill', xf(bone, t), fill='#f0e8d8', shade='#c8bca4', off=(0, 1.8), line=L, over=holes,
              hl=gx(line('M-16 -2 L16 -2', '#ffffff', 1.0, op=0.9), t))]
    halo = ('<ellipse cx="44" cy="15" rx="9.4" ry="3.4" fill="none" stroke="%s" stroke-width="4.6" transform="rotate(-20 44 15)"/>'
            '<ellipse cx="44" cy="15" rx="9.4" ry="3.4" fill="none" stroke="%s" stroke-width="2" transform="rotate(-20 44 15)"/>') % (
        GOLD_LINE, GOLD_HI)
    notes = ''
    for x, y, k in ((14, 18, 1.0), (22, 9, 0.8)):
        notes += ('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" transform="rotate(-20 %.1f %.1f)" fill="#8ae0a0" stroke="%s" stroke-width="1.2"/>' % (
            x, y, 2.8 * k, 2.1 * k, x, y, L)
                  + line('M%.1f %.1f L%.1f %.1f L%.1f %.1f' % (x + 2.4 * k, y - 0.6, x + 2.4 * k, y - 9 * k, x + 5.6 * k, y - 7.4 * k), L, 1.3))
    heal = kit.heart(50, 46, 0.62, '#ff8aa0', L)
    return paint(ctx, P, pal(L)) + halo + notes + heal + star4(8, 44, 1.8, '#fff2c8', 0.9)


# ================================================================ v3's eight (spec 8.3)

def poly(pts):
    return 'M' + ' L'.join('%.2f %.2f' % p for p in pts) + ' Z'


def sporeward(ctx):
    """A sage pomander tied with red cord, a sprig of herb in its neck, the
    spores bouncing off the ward it throws."""
    L = '#1a2410'
    P = []
    for x0, y0, x1, y1, lr in ((31, 22, 25.4, 11.6, -1), (32.6, 22, 36.4, 10.4, 1), (32, 22, 30.8, 9, 0)):
        P.append(Part('limb', pth('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (x0, y0, (x0 + x1) / 2 + lr * 2, (y0 + y1) / 2, x1, y1)),
                      width=1.4, fill='#5e8a3a', line=L))
    for x, y, rot in ((24.4, 12.6, -40), (37.6, 11.6, 36), (30.6, 10, -6), (27, 17, -60), (36, 16.4, 56)):
        P.append(Part('fill', ell(x, y, 2, 4, rot=rot), fill='#8ac05a', shade='#5e8a3a', off=(-0.5, -0.5), line=L,
                      over=line('M%.1f %.1f L%.1f %.1f' % (x, y + 2.4, x, y - 2.4), '#5e8a3a', 0.6)))
    bag = 'M32 24 C44 24 49.6 32 49.6 41 C49.6 51 42 57.4 32 57.4 C22 57.4 14.4 51 14.4 41 C14.4 32 20 24 32 24 Z'
    weave = ('<g clip-path="%s">%s</g>' % (ctx.clip(shp(pth(bag))), line(
        ''.join('M%d 20 Q%d 40 %d 60 ' % (x, x + 3, x) for x in range(16, 50, 6)), '#5e7a3a', 0.9, op=0.8)))
    P.append(Part('fill', pth(bag), fill='#9ab870', shade='#6a8a44', off=(-3, -3), line=L, over=weave,
                  hl=spec(22, 36, 2, 4.4, rot=24, op=0.7)))
    P.append(Part('fill', pth('M23 27.6 C21.6 22.4 26 20.6 28 23 C29.4 19.6 34.6 19.6 36 23 C38 20.6 42.4 22.4 41 27.6 Z'),
                  fill='#aac880', shade='#7a9a54', off=(-0.8, -0.8), line=L))
    P.append(Part('limb', pth('M22.4 28 Q32 31 41.6 28'), width=2.4, fill='#c8352a', line=L))
    P.append(Part('fill', ell(32, 29.8, 2.6, 2.2), fill='#c8352a', shade='#8a1e1a', off=(-0.5, -0.5), line=L))
    P.append(Part('limb', pth('M31 31 L28.6 37.6 M33 31 L35.6 37.6'), width=1.6, fill='#c8352a', line=L))
    ward = line('M52.6 24 C58.4 33 58.4 46 52.6 55', '#fff2c8', 2.0, op=0.95) + line('M52.6 24 C58.4 33 58.4 46 52.6 55', L, 0.8, op=0.6)
    spores = ''.join('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="#b8c080" stroke="%s" stroke-width="1"/>' % (x, y, r, L)
                     for x, y, r in ((58.6, 29, 1.8), (59.6, 40, 1.5), (57.6, 50.6, 1.7)))
    return paint(ctx, P, pal(L)) + ward + spores + sparkle(11, 20, 2.8, L)


def bone_flute(ctx):
    """Pan pipes of five bones, bound with cord, a bone moth fluttering up out
    of them."""
    L = '#2a1e14'
    P = []
    tubes = [(18, 14, 56), (24.4, 18, 54), (30.8, 22, 52), (37.2, 26, 50.4), (43.6, 30, 49)]
    for x, top, bot in tubes:
        d = 'M%.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f Z' % (
            x - 2.8, top, x - 2.8, bot, x, bot + 2.2, x + 2.8, bot, x + 2.8, top, x, top - 2.2, x - 2.8, top)
        P.append(Part('fill', pth(d), fill=BONE, shade=BONE_SH, off=(-1.2, 0), line=L,
                      over='<ellipse cx="%.1f" cy="%.1f" rx="1.6" ry="0.9" fill="%s"/>' % (x, top - 0.2, L)
                      + line('M%.1f %.1f L%.1f %.1f' % (x - 1.6, top + 3, x - 1.6, bot - 2), '#ffffff', 0.8, op=0.9)))
    P.append(Part('limb', pth('M13.6 38 L48.4 31'), width=2.6, fill='#a8743a', line=L,
                  over=line('M17 37.4 L17.6 35.6 M23.4 36 L24 34.2 M29.8 34.8 L30.4 33 M36.2 33.4 L36.8 31.6 M42.6 32.2 L43.2 30.4',
                            '#6a4420', 0.8)))
    P.append(Part('limb', pth('M14 38 Q10.6 43 12.4 48'), width=1.6, fill='#a8743a', line=L))
    # the bone moth
    mx, my = 49, 14
    for k in (-1, 1):
        P.append(Part('fill', pth('M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z' % (
            mx, my, mx + k * 4, my - 8, mx + k * 11, my - 7, mx + k * 10.4, my - 1.6, mx + k * 9.4, my + 2.6, mx + k * 4,
            my + 2.4, mx, my)), fill='#fff8ec', shade='#d8ccb4', off=(-0.5, -0.5), line=L,
            over=dot(mx + k * 6.6, my - 3.4, 1.3, '#6a5a86')))
        P.append(Part('fill', pth('M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z' % (
            mx, my + 1, mx + k * 6, my + 3, mx + k * 5.4, my + 8.4, mx, my + 3.4)), fill='#fff8ec', shade='#d8ccb4',
            off=(-0.4, -0.4), line=L))
    P.append(Part('fill', ell(mx, my + 1, 1.6, 4), fill=BONE_SH, shade='#a89c84', off=(-0.4, -0.4), line=L))
    P.append(Part('limb', pth('M%.1f %.1f Q%.1f %.1f %.1f %.1f M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (
        mx - 0.6, my - 2.6, mx - 1.6, my - 6, mx - 4, my - 7.4, mx + 0.6, my - 2.6, mx + 1.6, my - 6, mx + 4, my - 7.4)),
        width=0.8, fill=BONE_SH, line=L))
    notes = line('M40 22 Q43 19 45 20', '#fff2c8', 1.4, op=0.9)
    return paint(ctx, P, pal(L)) + notes + sparkle(8, 22, 2.6, L) + star4(56, 44, 1.8, '#fff2c8', 0.9)


def bell_up(cx, top, w, h):
    """An upright bell: its crown's top at top, mouth h below, w wide at the lip."""
    a = w / 2.0
    return ('M%.2f %.2f C%.2f %.2f %.2f %.2f %.2f %.2f C%.2f %.2f %.2f %.2f %.2f %.2f Q%.2f %.2f %.2f %.2f '
            'L%.2f %.2f Q%.2f %.2f %.2f %.2f C%.2f %.2f %.2f %.2f %.2f %.2f C%.2f %.2f %.2f %.2f %.2f %.2f Z') % (
        cx, top,
        cx + a * 0.5, top, cx + a * 0.62, top + h * 0.14, cx + a * 0.62, top + h * 0.36,
        cx + a * 0.62, top + h * 0.62, cx + a * 0.76, top + h * 0.8, cx + a, top + h * 0.9,
        cx + a * 1.04, top + h, cx + a * 0.8, top + h,
        cx - a * 0.8, top + h,
        cx - a * 1.04, top + h, cx - a, top + h * 0.9,
        cx - a * 0.76, top + h * 0.8, cx - a * 0.62, top + h * 0.62, cx - a * 0.62, top + h * 0.36,
        cx - a * 0.62, top + h * 0.14, cx - a * 0.5, top, cx, top)


def ice_star(x, y, r, col='#ffffff', w=1.3):
    return ('<path d="M%.1f %.1f L%.1f %.1f M%.1f %.1f L%.1f %.1f M%.1f %.1f L%.1f %.1f" stroke="%s" stroke-width="%.1f" '
            'stroke-linecap="round"/>') % (x, y - r, x, y + r, x - r * 0.87, y - r * 0.5, x + r * 0.87, y + r * 0.5,
                                          x - r * 0.87, y + r * 0.5, x + r * 0.87, y - r * 0.5, col, w)


def hoarfrost_bell(ctx):
    """A little handbell gone to ice: rime crusting its crown, icicles on its
    lip, frost glinting."""
    L = '#16283a'
    ice, ice_sh = '#cce8f6', '#86b2cc'
    P = [Part('limb', pth('M32 13 L32 5'), width=4.4, fill='#8a6a44', line=L),
         Part('fill', ell(32, 4.6, 3.2, 2.6), fill='#a8804e', shade='#6a4a2a', off=(-0.5, -0.5), line=L),
         Part('fill', ell(32, 50.6, 4.4, 4), fill=ice, shade=ice_sh, off=(-0.8, -0.8), line=L)]
    body = bell_up(32, 12, 40, 36.4)
    crust = ('<g clip-path="%s"><path d="M8 8 L56 8 L56 22 Q51 26 47 22.6 Q43 27.4 38.6 23 Q34 28 30 23.6 Q25.4 27.6 21.4 23 '
             'Q17 26.6 12 22 L8 24 Z" fill="#f4fbff"/></g>') % ctx.clip(shp(pth(body)))
    P.append(Part('fill', pth(body), fill=ice, shade=ice_sh, off=(-2.6, -2.4), line=L,
                  over=crust + line('M14.6 42.6 Q32 45.4 49.4 42.6', ice_sh, 1.6) + line('M17 38 Q32 40.6 47 38', '#ffffff', 1.1),
                  hl=spec(24.6, 30, 1.8, 5.6, rot=10, op=0.9)))
    icicles = ''
    for x, h in ((17, 7.6), (25.4, 10.4), (38.6, 9), (46.6, 6.4)):
        icicles += ('<path d="M%.1f 47.6 L%.1f 47.6 L%.1f %.1f Z" fill="#f4fbff" stroke="%s" stroke-width="1.3" stroke-linejoin="round"/>' % (
            x - 2.2, x + 2.2, x + 0.2, 47.6 + h, L))
    return gx(glow(ctx, 32, 32, 26, '#bfe4f4', 0.4) + paint(ctx, P, pal(L)) + icicles
              + ice_star(53, 12, 3.6, L, 3.4) + ice_star(53, 12, 3.6) + ice_star(10, 36, 2.8, L, 3) + ice_star(10, 36, 2.8),
              'translate(0 3)')


def clockheart(ctx):
    """A brass heart with a clock face set in it, a winding key in its top and
    gear teeth along one side."""
    L = '#2a1a06'
    heart = 'M32 21 C28 12 10 11 10 27 C10 40 22 48 32 57 C42 48 54 40 54 27 C54 11 36 12 32 21 Z'
    teeth = []
    for i in range(7):
        a = math.radians(-60 + i * 20)
        for t, r in ((-0.18, 22.6), (-0.12, 25.4), (0.12, 25.4), (0.18, 22.6)):
            teeth.append((32 + r * math.cos(a + t), 32 + r * math.sin(a + t)))
    gear = poly(teeth)
    face = ('<circle cx="32" cy="32" r="11" fill="#fff8e4" stroke="%s" stroke-width="1.4"/>' % L
            + ''.join('<path d="M%.2f %.2f L%.2f %.2f" stroke="%s" stroke-width="%.1f" stroke-linecap="round"/>' % (
                32 + 8.4 * math.cos(a), 32 + 8.4 * math.sin(a), 32 + 10 * math.cos(a), 32 + 10 * math.sin(a), L,
                1.4 if i % 3 == 0 else 0.8) for i, a in enumerate(math.pi * 2 * k / 12 for k in range(12)))
            + line('M32 32 L26.6 28.4', L, 1.8) + line('M32 32 L38.4 25.6', L, 1.3)
            + dot(32, 32, 1.6, '#c8352a'))
    P = [Part('fill', pth(gear), fill=BRASS2, shade=BRASS2_SH, off=(-0.6, -0.6), line=L),
         Part('fill', pth(heart), fill=BRASS2, shade=BRASS2_SH, off=(-3, -3), line=L, over=face
              + '<circle cx="32" cy="32" r="12.8" fill="none" stroke="%s" stroke-width="1.6"/>' % GOLD_HI,
              hl=spec(17.6, 24, 2, 4, rot=30, op=0.9)),
         Part('limb', pth('M32 17 L32 11'), width=2.6, fill=BRASS2, line=L),
         Part('fill', pth('M32 11.4 C27.6 11.4 25.6 8.6 26.8 6.6 C28 4.6 30.6 5.6 32 8 C33.4 5.6 36 4.6 37.2 6.6 C38.4 8.6 36.4 11.4 32 11.4 Z'),
              fill=BRASS2, shade=BRASS2_SH, off=(-0.6, -0.6), line=L)]
    return paint(ctx, P, pal(L)) + sparkle(52, 50, 3, L) + star4(11, 48, 1.8, '#fff2c8', 0.9)


BRASS2, BRASS2_SH = '#d8a84a', '#9a6e26'


def leaded_pane(ctx):
    """A small pane of old window glass, round-topped in a lead frame, a
    lattice of diamond quarrels; a spent arrowhead lies broken below it."""
    L = '#14121e'
    pane = 'M15 58 L15 22 C15 12 22.6 6 32 6 C41.4 6 49 12 49 22 L49 58 Z'
    clip = ctx.clip(shp(pth(pane)))
    cols = ['#f2d890', '#f0a8a0', '#bcdcf0', '#f6e8c0']
    cells = ''
    step = 7.0
    for i in range(-6, 8):
        for j in range(-2, 12):
            cx, cy = 32 + (i + (0.5 if j % 2 else 0)) * step, 2 + j * step * 0.75
            cells += '<path d="%s" fill="%s"/>' % (poly([(cx, cy - step * 0.75), (cx + step / 2, cy), (cx, cy + step * 0.75),
                                                          (cx - step / 2, cy)]), cols[(i + j * 3) % 4])
    lattice = ''.join('M%.1f -4 L%.1f 70 M%.1f -4 L%.1f 70 ' % (x, x + 49.3, x, x - 49.3) for x in range(-40, 110, 7))
    glass = ('<g clip-path="%s">%s%s</g>' % (clip, cells, line(lattice, '#3a3848', 1.4))
             + line('M20 26 C21 18 25 13 30 11', '#ffffff', 1.6, op=0.9))
    P = [Part('fill', pth(pane), fill='#f6e8c0', shade='#c8b890', no_shade=True, line=L, over=glass
              + '<path d="%s" fill="none" stroke="#5a5868" stroke-width="3"/>' % pane
              + '<path d="%s" fill="none" stroke="#9a98ac" stroke-width="1"/>' % pane)]
    arrow = ('<path d="M49.6 47.6 L58.6 49.4 L52 55.6 Z" fill="#9a9eb6" stroke="%s" stroke-width="1.3" stroke-linejoin="round"/>' % L
             + line('M41.6 59.4 L52.4 51.6', L, 3.6) + line('M41.6 59.4 L52.4 51.6', '#b8844a', 1.6)
             + line('M42.6 58.6 L39 56.6 M42.6 58.6 L41.6 62', L, 2.8) + line('M42.6 58.6 L39 56.6 M42.6 58.6 L41.6 62', '#e8e0ff', 1.2))
    return paint(ctx, P, pal(L)) + arrow + star4(47.4, 45.4, 4.6, L) + star4(47.4, 45.4, 3.2, '#ffffff') + sparkle(9, 14, 2.6, L)


def sanctum_glass(ctx):
    """A lancet of the Sanctum's window, crimson, gold and blue in a gold
    frame, hung as an amulet, throwing its colours."""
    L = '#2a0c16'
    lancet = 'M19.6 57 L19.6 29 C19.6 19.4 25 12.6 32 9 C39 12.6 44.4 19.4 44.4 29 L44.4 57 Z'
    clip = ctx.clip(shp(pth(lancet)))
    glass = ('<g clip-path="%s">' % clip
             + '<path d="M0 0 L64 0 L64 64 L0 64 Z" fill="#c83a5a"/>'
             + '<path d="M32 30 L50 30 L50 64 L32 64 Z" fill="#3a6ad8"/>'
             + '<path d="M14 36 L32 36 L32 64 L14 64 Z" fill="#e8b84a"/>'
             + '<circle cx="32" cy="23.6" r="6" fill="#f2a0b0"/>'
             + ''.join('<circle cx="%.1f" cy="%.1f" r="2.6" fill="%s" stroke="%s" stroke-width="1"/>' % (
                 32 + 3.4 * math.cos(a), 23.6 + 3.4 * math.sin(a), '#ffd84a', L) for a in (math.pi / 2 * k for k in range(4)))
             + dot(32, 23.6, 1.4, '#fff4d0')
             + line('M32 30 L32 60 M14 36 L50 36 M14 47 L32 47 M32 43 L50 43', L, 1.6)
             + line('M23 52 L26 40 M36 55 L39 46', '#ffffff', 1.2, op=0.7)
             + '</g>')
    P = [Part('fill', pth(lancet), fill='#c83a5a', shade='#8a1e36', no_shade=True, line=L, over=glass
              + '<path d="%s" fill="none" stroke="%s" stroke-width="2.4"/>' % (lancet, GOLD)
              + '<path d="%s" fill="none" stroke="%s" stroke-width="0.8" opacity="0.8"/>' % (lancet, GOLD_LINE)),
         Part('fill', ell(32, 7.4, 2.8, 2.8), fill=GOLD, shade=GOLD_SH, off=(-0.6, -0.6), line=GOLD_LINE, over=dot(32, 7.4, 1.2, GOLD_LINE))]
    beams = ''
    for col, y in (('#ff6a8a', 40), ('#ffd84a', 46), ('#6a9aff', 52)):
        beams += line('M48 %.1f L60 %.1f' % (y - 2, y + 2), col, 2.2, op=0.85)
    return paint(ctx, P, pal(L)) + beams + star4(38, 17, 4.4, L) + star4(38, 17, 3, '#ffffff') + sparkle(10, 18, 2.8, L)


def hush_pearl(ctx):
    """A great pale pearl on a black scallop shell rimmed with the Hush's
    silver, a warm flame caught in its shine."""
    L = '#0e0c18'
    hx, hy, R = 32, 45, 25.0
    pts = []
    n = 7
    for i in range(n * 6 + 1):
        t = i / float(n * 6)
        a = math.radians(198 + 144 * t)
        rr = R - 2.2 * abs(math.sin(t * n * math.pi))
        pts.append((hx + rr * math.cos(a), hy + rr * 1.22 * math.sin(a)))
    fan = 'M%.2f %.2f L' % (hx, hy) + ' L'.join('%.2f %.2f' % p for p in pts) + ' Z'
    ridges = line(''.join('M%.1f %.1f L%.1f %.1f ' % (hx, hy - 4, hx + (R - 4) * math.cos(a), hy + (R - 4) * 1.22 * math.sin(a))
                          for a in (math.radians(198 + 144 * (k + 0.5) / n) for k in range(n))), '#6a64a0', 1.4, op=0.9)
    lower = 'M11 45 C13 54 21.4 58.4 32 58.4 C42.6 58.4 51 54 53 45 C45 49 40 50 32 50 C24 50 19 49 11 45 Z'
    pearl = ctx.radgrad([(0, '#ffffff'), (0.45, '#ece8fa'), (0.85, '#b8b2e0'), (1, '#8a84b8')], cx=0.38, cy=0.34, r=0.66)
    P = [Part('fill', pth(fan), fill='#262440', shade='#15132a', off=(-2, -2), line=L, over=ridges),
         Part('fill', pth(lower), fill='#262440', shade='#15132a', off=(-1.4, -1.4), line=L,
              hl=line('M17 50 C22 53.4 26.6 54.8 32 55', '#6a64a0', 1.4, op=0.8)),
         Part('fill', ell(32, 40.6, 11, 11), fill=pearl, no_shade=True, line='#3a3660')]
    body = paint(ctx, P, dict(line=L, rim='#c8c8f0', base='#262440', shade='#15132a'))
    shine = ('<ellipse cx="27.6" cy="36" rx="3.4" ry="2.4" fill="#ffffff" opacity="0.9" transform="rotate(-30 27.6 36)"/>'
             + '<path d="%s" fill="%s" stroke="%s" stroke-width="0.7"/>' % (flame_d(36.2, 46, 3.4, 6, 0.3), FLAME, FLAME_LINE)
             + '<path d="%s" fill="%s"/>' % (flame_d(36.2, 45.4, 1.6, 3, 0.2), FLAME_CORE))
    return (glow(ctx, 32, 38, 26, '#d8d4f0', 0.35) + body + shine + star4(55, 8, 2.6, '#d8d4f0', 0.95)
            + star4(8, 54, 2, '#d8d4f0', 0.85))


def taper_match(ctx):
    """Mother Taper's match: a long match, lit, her plum ribbon tied round it
    in a bow."""
    L = '#1e1224'
    ang = -50
    t = 'translate(30 38) rotate(%d)' % ang
    plum, plum_sh, trim = '#8a4e86', '#5a2e5a', '#d8b24a'
    P = [Part('fill', xf('M-26 -2.2 L14 -2.2 L14 2.2 L-26 2.2 Z', t), fill='#e8c48a', shade='#b8905a', off=(0, 1.2), line=L,
              over=gx(line('M-24 -1 L12 -1', '#fff0cc', 0.8, op=0.9), t)),
         Part('fill', xell(17.4, 0, 4.8, 3.8, t), fill='#c8352a', shade='#8a1e1a', off=(-0.8, -0.8), line=L,
              hl=gx(dot(16, -1.4, 0.9, '#ffb0a0'), t))]
    # the bow: two round loops across the stick, two short tails along it
    for k in (-1, 1):
        P.append(Part('fill', xf('M-9 %.1f C-3 %.1f -4 %.1f -10 %.1f C-15 %.1f -16 %.1f -9 %.1f Z' % (
            k * 1.4, k * 4, k * 12.6, k * 12.4, k * 12, k * 5, k * 1.4), t), fill=plum, shade=plum_sh, off=(-0.6, -0.6), line=L,
            over=gx(line('M-9.6 %.1f C-7.6 %.1f -8 %.1f -10.4 %.1f' % (k * 3, k * 5, k * 8.6, k * 10), trim, 0.9), t)))
        P.append(Part('fill', xf('M-9 %.1f L-19 %.1f L-17 %.1f L-20.4 %.1f L-9 %.1f Z' % (
            k * 0.6, k * 3.4, k * 5, k * 7.4, k * 2.4), t), fill=plum, shade=plum_sh, off=(-0.4, -0.4), line=L))
    P.append(Part('fill', xell(-9, 0, 2.8, 3.2, t), fill=plum, shade=plum_sh, off=(-0.4, -0.4), line=L,
                  over=gx(dot(-9, 0, 1, trim), t)))
    c = math.cos(math.radians(ang))
    s_ = math.sin(math.radians(ang))
    fx, fy = 30 + 19 * c, 38 + 19 * s_
    s = glow(ctx, fx, fy - 5, 16, '#ffb24a', 0.6)
    fl = flame(ctx, fx + 0.4, fy - 0.2, 10, 16.6, lean=1.4, halo=False)
    return s + paint(ctx, P, pal(L)) + fl + sparkle(13, 14, 3.2, L, FLAME_CORE) + sparkle(54, 50, 2.8, L, FLAME_CORE) + star4(
        18, 55, 1.8, FLAME_CORE, 0.9)


BONE, BONE_SH = '#f0e8d8', '#c8bca4'


DRAW = {'owls_eye': owls_eye, 'wind_wick': wind_wick, 'bell_shard': bell_shard, 'choir_bone': choir_bone,
        'tallow_heart': tallow_heart, 'rook_feather': rook_feather, 'longsword': longsword, 'iron_boots': iron_boots,
        'moth_charm': moth_charm, 'bellows': bellows, 'saints_knuckle': saints_knuckle, 'phoenix_wick': phoenix_wick,
        'sporeward': sporeward, 'bone_flute': bone_flute, 'hoarfrost_bell': hoarfrost_bell, 'clockheart': clockheart,
        'leaded_pane': leaded_pane, 'sanctum_glass': sanctum_glass, 'hush_pearl': hush_pearl, 'taper_match': taper_match}


def files():
    out = {}
    for name in RELICS:
        ctx = Ctx('rl' + name[:3])
        out['art/relics/%s.svg' % name] = svg64(ctx, DRAW[name](ctx))
    return out
