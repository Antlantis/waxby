"""World 6 props (A2): the Hushdeep, in ink and silver.

  bell_buoy, bell_buoy_rung       the bell-buoy J (64 x 96, drawn at 0.25): a cork float at the lake line
                                  ("water" (32, 70)), a caged bell above it and a small lantern on top;
                                  rung, the bell swings and the lantern is lit
  vigil_candle_out, vigil_candle_lit   a Lost Wick's candle stub on a shore stone (64 x 64, foot (32, 64),
                                  wick tip (32, 8): the live flame and its light go there); out, cold grey
                                  wax with a silver edge; lit, warm wax
  grasp_hand                      a Hushgrasp (64 x 160: 32 x 80 px): two pale-tipped ink hands rising
                                  side by side, filling its 28 x 80 px hurt rect ("hurt" [4, 0, 56, 160]
                                  units), "tips" the highest fingertip, the arms fading to the lake at the
                                  bottom (the feature shows only what is above the water line)
  buoy_lantern_lit, buoy_lantern_out   the W6 lantern post L (64 x 96, v2's lantern_post frame: foot (32,
                                  96), flame (32, 30)): a drowned glass lantern on a cork float, chained
                                  down to its stone
  altar_hush, altar_hush_lit      the altar (64 x 96, v2's frame, wick tip (32, 22)): black stone, a silver
                                  candle cup; lit, the warmest light in the game
  bell_hush, bell_hush_beam       the bell (128 x 192, v2's: hangs from (64, 20)): a black bell dripping
                                  silver water; a beam of black wood with silver nails
  sconce_dead                     W6's `c` (64 frame): a snuffed iron sconce with a silver edge and a curl
                                  of old smoke (it gives no light)
  eye_seal_open, eye_seal_closed  the arena door (128 x 192, the two-by-three doorway): black lids open
                                  on the dark, and closed
and points_w6.json (frame units; 2 units = 1 world px).
"""
import math
import kit
from kit import Part, ell, pth
from common import (Ctx, RIM, GOLD, GOLD_SH, GOLD_HI, GOLD_LINE, WAX, WAX_SH, WAX_LINE, FLAME, FLAME_CORE, FLAME_MID,
                    svg, svg64, paint, line, dot, flame, flame_d, glow, spec, sparkle, star4, mix, IN)
from props import rrect, arch_d, candle_parts, flame_outline

INK, INK_SH, INK_LINE, INK_HI = '#2a2838', '#1a1824', '#08070c', '#4a4860'
SILVER, SILVER_HI, SILVER_SH = '#c8c8f0', '#eeeeff', '#8a88b0'
RIM6 = '#c8c8f0'          # W6's rim: silver, not the warm candle rim
CORK, CORK_SH = '#6a5a4a', '#46382c'
STONE6, STONE6_SH, STONE6_HI = '#3e3c52', '#2a2838', '#7a789e'
COLD_WAX, COLD_WAX_SH = '#8a8698', '#5e5a6c'
EYE = '#d8d4f0'


def _pal(base=INK, shade=INK_SH, rim=RIM6):
    return dict(line=INK_LINE, rim=rim, base=base, shade=shade)


# ================================================================ the bell-buoy

def bell_buoy_svg(rung):
    """A bell-buoy (64 x 96): a cork float riding the lake line at y 70, an
    iron cage on it holding a small bell, a lantern on the cage's top. Rung,
    the bell is swung and the lantern is lit (its light is the toll's)."""
    ctx = Ctx('bb' + ('r' if rung else 'q'))
    pal = _pal()
    P = []
    # the float: a fat cork ring, its lower half under the line (drawn darker)
    P.append(Part('fill', ell(32, 72, 22, 8.4), fill=CORK, shade=CORK_SH, off=(-1.4, -2.2),
                  over=line('M13 71 Q32 66 51 71', '#8a7862', 1.2, op=0.9)
                  + line('M17 75 L19 70 M25 77 L26 71 M38 77 L37.4 71 M46 75 L44.6 70', CORK_SH, 0.9)))
    # the cage: four iron bars bowed round the bell, a ring at the top
    for x0, x1 in ((16, 20), (48, 44)):
        P.append(Part('limb', pth('M%d 66 C%d 52 %d 36 32 26' % (x0, x0 - 1, x1, )), width=2.0, fill=INK))
    P.append(Part('limb', pth('M16 66 L48 66'), width=2.2, fill=INK))
    # the bell (swung when rung)
    rot = -16 if rung else 0
    bell = ('M26 40 C26 36 38 36 38 40 C39.4 46 40 52 44 56 C45 57 44.6 58.6 43 58.6 L21 58.6 C19.4 58.6 19 57 20 56 '
            'C24 52 24.6 46 26 40 Z')
    bell_g = ('<g transform="rotate(%d 32 37)">' % rot)
    bell_p = [Part('fill', pth(bell), fill='#3a3648', shade='#24222e', off=(-1.2, -1.2), line=INK_LINE,
                   over=line('M22.4 55 Q32 57.8 41.6 55', SILVER, 1.2) + line('M27.4 44 Q32 45.4 36.6 44', SILVER_SH, 0.8),
                   hl=spec(28, 46, 1.2, 4, rot=10, op=0.5, col=SILVER_HI)),
              Part('fill', ell(32, 60, 2.4, 2.2), fill=SILVER_SH, shade=INK_SH, off=(-0.5, -0.5), line=INK_LINE)]
    bell_svg = bell_g + paint(ctx, bell_p, pal) + '</g>'
    # the lantern on top
    lamp = []
    glass = 'M26 12 L38 12 L37 24 L27 24 Z'
    if rung:
        gl = ctx.lingrad([(0, '#fff2c8'), (0.6, '#ffd98a'), (1, '#f2b84b')])
        inner = flame(ctx, 32, 22.4, 5.4, 9.4, lean=0.4, halo=False, lcol='#5a1e0c')
    else:
        gl = ctx.lingrad([(0, '#3a4452'), (1, '#1e2430')])
        inner = line('M32 23 Q31.6 21.4 32.2 20', '#241a14', 1.0)
    lamp.append(Part('fill', pth(glass), fill=gl, shade=gl, no_shade=True, lw=1.0, over=inner))
    lamp.append(Part('fill', pth('M24.4 12.6 L39.6 12.6 L35.6 6.6 L28.4 6.6 Z'), off=(-0.8, -0.8)))
    lamp.append(Part('fill', pth('M24.8 24 L39.2 24 L38 27 L26 27 Z'), off=(-0.6, -0.6)))
    lamp.append(Part('fill', ell(32, 5.4, 1.8, 1.6), off=(-0.4, -0.4), over=dot(32, 5.4, 0.6, SILVER)))
    lamp_svg = paint(ctx, lamp, pal)
    under = ''
    over = ''
    if rung:
        halo = ctx.radgrad([(0, '#ffc85a', 0.55), (0.5, '#ffb040', 0.18), (1, '#ffb040', 0)])
        under = '<ellipse cx="32" cy="20" rx="24" ry="20" fill="%s"/>' % halo
        over = ('<path d="M10 40 Q6 48 10 56" fill="none" stroke="%s" stroke-width="1.4" stroke-linecap="round"/>' % SILVER_HI
                + '<path d="M54 40 Q58 48 54 56" fill="none" stroke="%s" stroke-width="1.4" stroke-linecap="round"/>' % SILVER_HI
                + sparkle(50, 16, 2.6, INK_LINE, '#ffffff'))
    # the silver edge on the float's crest (the W6 phone alpha is drawn live; this is its lit look)
    crest = line('M11.4 70.4 Q32 64.2 52.6 70.4', SILVER, 1.1, op=0.8)
    # what hangs under the line: the float's belly, dim (it shows through the ink)
    belly = '<ellipse cx="32" cy="80" rx="18" ry="5" fill="%s" opacity="0.35"/>' % CORK_SH
    return svg(ctx, under + belly + paint(ctx, P, pal) + bell_svg + lamp_svg + crest + over, 64, 96)


# ================================================================ the Vigil candle

def vigil_candle_svg(lit):
    """A Lost Wick's candle stub on a shore stone (64 x 64, foot (32, 64),
    wick (32, 8)). Out: cold grey wax, a silver edge, a charred wick; lit:
    warm cream wax (the flame itself is drawn live)."""
    ctx = Ctx('vc' + ('l' if lit else 'o'))
    pal = _pal(base=STONE6, shade=STONE6_SH)
    P = []
    P.append(Part('fill', pth('M10 64 L12 56 Q18 49.6 32 49.4 Q46 49.6 52 56 L54 64 Z'), off=(-1.6, -1.4),
                  over=line('M13 56 Q20 51 32 50.8 Q44 51 51 56', STONE6_HI, 1.1, op=0.9)))
    wax, wax_sh, lcol = (WAX, WAX_SH, WAX_LINE) if lit else (COLD_WAX, COLD_WAX_SH, INK_LINE)
    # the stub, melted over the stone, and its drips
    P.append(Part('fill', pth('M24 51.6 L24.4 14 L39.6 14 L40 51.6 Q44 53.4 46 55 Q32 57.4 18 55 Q20 53.4 24 51.6 Z'),
                  fill=wax, shade=wax_sh, off=(-2.4, -1), line=lcol,
                  over=line('M36.6 14.4 L36.6 28 M28 14.6 L28 21', wax_sh, 1.3, op=0.8),
                  hl=spec(27.4, 32, 1.2, 8, rot=0, op=0.6)))
    P.append(Part('fill', pth('M23.6 15.6 Q24 12 32 11.4 Q40 12 40.4 15.6 L38 18 L37 23 L35.4 18 L29 18.6 L27.6 22 L26.6 18 Z'),
                  fill='#fffaec' if lit else '#a8a4b4', shade='#eadfc0' if lit else '#8a8698', off=(-0.6, -0.6), line=lcol, lw=0.9))
    wick = line('M32 12.6 Q31.2 10.6 32.2 8', '#241a14', 1.6)
    if lit:
        wick += dot(32.2, 8.2, 0.9, '#ff9a3a')
    over = ''
    if not lit:
        over = (line('M24.6 15 L24.4 50.6', SILVER, 1.0, op=0.75) + line('M32.6 7.4 Q35 4 33.6 1.6', '#6a6680', 0.9, op=0.7))
    else:
        warm = ctx.radgrad([(0, '#ffb44a', 0.4), (1, '#ffb44a', 0)])
        over = '<ellipse cx="32" cy="20" rx="20" ry="18" fill="%s"/>' % warm
    return svg64(ctx, paint(ctx, P, pal) + wick + over)


# ================================================================ the Hushgrasp

def _hand(P, tips_svg, mirror, dy, fade):
    """One of a Hushgrasp's two hands (the left one; mirror: the right, its
    tips dy lower), in frame units: a forearm rising from the lake, a palm,
    four long fingers and a thumb splayed up and out, pale tips."""
    X = (lambda x: 64.0 - x) if mirror else (lambda x: x)
    def pts(*xy):
        return ' '.join('%.1f %.1f' % (X(x), y + (dy if y < 100 else 0.0)) for x, y in xy)
    # the forearm, fading into the lake at the bottom (the base overlaps its twin's: one tangle)
    P.append(Part('fill', pth('M%s L%s L%s L%s Z' % (pts((5.5, 160)), pts((34.5, 160)), pts((29.4, 80)), pts((9.6, 80)))),
                  fill=fade, shade=fade, no_shade=True, rim=False, sil=False, lw=0))
    P.append(Part('limb', pth('M%s L%s' % (pts((9.0, 82)), pts((7.0, 124)))), width=0.1, fill='#1e1c2a', sil=False, rim=False,
                  over=line('M%s L%s' % (pts((9.2, 82)), pts((6.4, 128))), SILVER, 1.5, op=0.6)))
    # the palm
    P.append(Part('fill', pth('M%s Q%s %s L%s Q%s %s Q%s %s Z' % (pts((9.6, 82)), pts((4.0, 68)), pts((5.6, 53)), pts((30.6, 51)),
                                                                 pts((32.6, 66)), pts((29.4, 82)), pts((19.5, 85.5)), pts((9.6, 82)))),
                  off=(-1.2, -1.2)))
    # a thumb out to the side, four fingers splayed up and out, their tips
    # hooked back in like claws closing (a grasp, not a wave)
    fingers = [((8.0, 67), (1.0, 60), (0.4, 50), (3.6, 44)), ((9.4, 53), (4.2, 42), (3.2, 28), (7.0, 21)),
               ((15.0, 52), (13.0, 36), (11.4, 18), (15.2, 11)), ((21.0, 52), (22.6, 36), (24.8, 21), (22.0, 14.5)),
               ((27.0, 53), (30.6, 45), (32.2, 35), (29.2, 28.5))]
    for (a, b, c, d) in fingers:
        P.append(Part('limb', pth('M%s C%s %s %s' % (pts(a), pts(b), pts(c), pts(d))), width=4.4))
        tx, ty = X(d[0]), d[1] + dy
        tips_svg.append(dot(tx, ty, 2.3, EYE) + dot(tx - 0.5, ty - 0.6, 0.9, '#ffffff'))
    tips_svg.append(line('M%s Q%s %s' % (pts((8.0, 54)), pts((18.0, 56.5)), pts((29.0, 53))), '#3a3850', 1.0, op=0.8))


def grasp_hand_svg():
    """A Hushgrasp (64 x 160 = 32 x 80 px): two ink hands rising from the
    lake side by side ("hands rise", spec §3.7), filling the grasp's hurt rect
    (28 x 80 px = units 4..60: points_w6.json "hurt"), their fingers splayed
    up and out with pale tips, silver rims; the forearms fade into the lake."""
    ctx = Ctx('gh')
    pal = _pal(base='#1e1c2a', shade='#121018')
    P = []
    tips = []
    fade = ctx.lingrad([(0, '#1e1c2a', 1), (0.5, '#1e1c2a', 1), (1, '#1e1c2a', 0)])
    _hand(P, tips, True, 5.0, fade)
    _hand(P, tips, False, 0.0, fade)
    return svg(ctx, paint(ctx, P, pal) + ''.join(tips), 64, 160)


# ================================================================ the buoy lantern (W6's lantern post)

def buoy_lantern_svg(lit):
    """The W6 lantern post (64 x 96, foot (32, 96), flame (32, 30)): a
    drowned glass lantern riding a cork float, chained down to its stone."""
    ctx = Ctx('bl' + ('l' if lit else 'o'))
    pal = _pal()
    P = []
    # the anchor stone and the chain up to the float
    P.append(Part('fill', pth('M22 96 L24 89 L40 89 L42 96 Z'), fill=STONE6, shade=STONE6_SH, off=(-1, -1)))
    y = 88
    chain = ''
    while y > 56:
        chain += '<ellipse cx="32" cy="%.1f" rx="1.6" ry="2.6" fill="none" stroke="%s" stroke-width="1.2"/>' % (y, INK_HI)
        y -= 4.4
    P.append(Part('fill', ell(32, 53.4, 17, 6), fill=CORK, shade=CORK_SH, off=(-1.2, -1.8),
                  over=line('M16.4 52.6 Q32 48 47.6 52.6', '#8a7862', 1.1, op=0.9) + line('M16 53.6 Q32 49.4 48 53.6', SILVER, 0.8, op=0.7)))
    # the lantern: a glass cage on the float
    glass = 'M23.4 44 L24.6 22 L39.4 22 L40.6 44 Z'
    if lit:
        gl = ctx.lingrad([(0, '#fff2c8'), (0.55, '#ffd98a'), (1, '#f2b84b')])
        inner = flame(ctx, 32, 38.6, 7.2, 12.4, lean=0.5, halo=False, lcol='#5a1e0c') + line('M32 39.4 L32 36.6', '#241a14', 1.1)
    else:
        gl = ctx.lingrad([(0, '#2e3440'), (1, '#161a22')])
        inner = line('M32 40 Q31.6 38 32.2 36.6', '#241a14', 1.2) + '<path d="M26 25 L27 39 L28.4 39 L27.6 25 Z" fill="#8a9aae" opacity="0.4"/>'
    P.append(Part('fill', pth(glass), fill=gl, shade=gl, no_shade=True, lw=1.0, over=inner))
    P.append(Part('limb', pth('M24.6 22 L23.4 44'), width=1.6, fill=INK))
    P.append(Part('limb', pth('M39.4 22 L40.6 44'), width=1.6, fill=INK))
    P.append(Part('fill', pth('M21 44 L43 44 L41.6 48 L22.4 48 Z'), off=(-1, -1)))
    P.append(Part('fill', pth('M20.4 22.6 L43.6 22.6 L37 14.4 L27 14.4 Z'), off=(-1.4, -1.2),
                  over=line('M22.6 21.6 L41.4 21.6', SILVER if not lit else '#ffd98a', 0.8, op=0.9)))
    P.append(Part('fill', ell(32, 12.2, 1.9, 1.7), off=(-0.4, -0.4), over=dot(32, 12.2, 0.7, SILVER)))
    under, over = '', ''
    if lit:
        halo = ctx.radgrad([(0, '#ffc85a', 0.55), (0.5, '#ffb040', 0.2), (1, '#ffb040', 0)])
        under = '<ellipse cx="32" cy="32" rx="26" ry="24" fill="%s"/>' % halo
        over = sparkle(46, 24, 2.4, INK_LINE, '#fff2c8')
    else:
        # drowned: a drip of silver water off its roof
        over = line('M40.6 24 L41 30', SILVER, 1.0, op=0.8) + dot(41, 31.4, 1.0, SILVER)
    return svg(ctx, under + chain + paint(ctx, P, pal) + over, 64, 96)


# ================================================================ the altar

def altar_hush_svg(lit):
    """The W6 altar (64 x 96, v2's frame, wick tip (32, 22)): a black stone
    altar with a silver candle cup; lit, warm (the most welcome light)."""
    ctx = Ctx('ah' + ('l' if lit else 'u'))
    if lit:
        stone, stone_sh, stone_hi = '#4a4660', '#302c40', '#8a86b0'
        trim, trim_sh = '#ffd65a', '#c8901e'
    else:
        stone, stone_sh, stone_hi = STONE6, STONE6_SH, STONE6_HI
        trim, trim_sh = SILVER_SH, '#5a5878'
    L = INK_LINE
    pal = dict(line=L, rim=RIM6 if not lit else RIM, base=stone, shade=stone_sh)
    P = []
    P.append(Part('fill', rrect(5.4, 84.4, 58.6, 94.4, 1.6), off=(-2, -2), over=line('M7.4 86.4 L56.6 86.4', stone_hi, 1, op=0.8)))
    niche = arch_d(22.6, 41.4, 61.4, 83.6)
    body_over = ('<path d="%s" fill="#06050a" stroke="%s" stroke-width="1.3"/>' % (niche, L)
                 + line('M12 80.6 L12 60.6 L52 60.6', stone_hi, 1, op=0.8))
    if lit:
        glow_g = ctx.radgrad([(0, '#ffc85a', 0.9), (0.6, '#ffb040', 0.3), (1, '#ffb040', 0)])
        body_over += '<g clip-path="%s"><ellipse cx="32" cy="76" rx="12" ry="14" fill="%s"/></g>' % (
            ctx.clip('<path d="%s"/>' % niche), glow_g)
        body_over += flame(ctx, 32, 81, 8.4, 13.6, lean=0.6, halo=False, lcol=L)
    else:
        body_over += flame_outline(32, 81, 8.4, 13.6, '#4a4660')
    # silver water running down its face
    body_over += line('M47 60.6 L47 74', SILVER, 1.1, op=0.7) + dot(47, 75.4, 1.2, SILVER, 0.8)
    P.append(Part('fill', rrect(10, 58, 54, 84.6, 1.2), off=(-2.6, -2.2), over=body_over))
    P.append(Part('fill', rrect(5, 51.6, 59, 58.6, 1.8), off=(-1.8, -1.6),
                  over=line('M7 55.6 L57 55.6', trim, 2, cap='butt') + line('M7 56.8 L57 56.8', trim_sh, 0.7)
                  + line('M7 53 L57 53', stone_hi, 0.9, op=0.8)))
    P.append(Part('fill', pth('M23.4 48.4 L40.6 48.4 Q40 51.6 36.4 52 L27.6 52 Q24 51.6 23.4 48.4 Z'),
                  fill=SILVER, shade=SILVER_SH, off=(-1, -1), line=L, over=line('M25.4 49.4 L38.6 49.4', SILVER_HI, 0.8)))
    parts, wick = candle_parts(27.4, 36.6, 25.4, 48.8, 22, drips=((0.2, 5), (0.58, 9), (0.85, 3.4)))
    P += parts
    under = ''
    if lit:
        warm = ctx.radgrad([(0, '#ffb44a', 0.5), (0.5, '#ff9a3a', 0.18), (1, '#ff9a3a', 0)])
        under = '<ellipse cx="32" cy="46" rx="31" ry="44" fill="%s"/>' % warm
    over = sparkle(52, 40, 3.2, L, '#fff2c8') if lit else ''
    return svg(ctx, under + paint(ctx, P, pal) + wick + over, 64, 96)


# ================================================================ the bell and its beam

def bell_hush_beam_svg():
    ctx = Ctx('hbm')
    pal = _pal(base='#2a2634', shade='#1a1822')
    P = [Part('fill', rrect(6, 7.6, 122, 20.2, 2.4), off=(-2, -2.4),
              over=line('M10 13.4 Q40 12 64 13.6 Q90 15 118 13.2', '#3a3448', 0.9, op=0.9)
              + ''.join(dot(x, 14, 1.2, SILVER) for x in (14, 40, 88, 114)),
              hl=line('M9 9.6 L119 9.6', '#5a5470', 1.1, op=0.9))]
    P.append(Part('fill', rrect(57, 14.6, 71, 22.6, 1.6), fill='#1e1c28', shade='#121018', off=(-1, -1),
                  over=dot(60.4, 18.4, 1, SILVER) + dot(67.6, 18.4, 1, SILVER)))
    return svg(ctx, paint(ctx, P, pal), 128, 192)


def bell_hush_svg():
    """The W6 bell (128 x 192, v2's frame): black, a silver band at its
    mouth, silver water dripping from it, its rope grey."""
    ctx = Ctx('hbl')
    pal = _pal(base='#2a2838', shade='#16141e')
    P = []
    ROPE, ROPE_SH = '#8a8698', '#5a5668'
    rope_d = 'M64 108 C64.6 130 63.2 152 64 176'
    twist = ''.join('M%.1f %.1f l3.6 -2.4 ' % (62.2 + (0.3 if i % 2 else -0.2), y) for i, y in enumerate(range(114, 176, 5)))
    P.append(Part('limb', pth(rope_d), width=4.6, fill=ROPE, over=line(twist, ROPE_SH, 1.0)))
    P.append(Part('fill', pth('M60.8 176 L67.2 176 L68.4 180 L69.6 189.4 L66.8 187 L65.2 190 L63.4 187 L61.2 190 '
                              'L60.4 186.6 L58.4 189.4 L59.6 180 Z'), fill=ROPE, shade=ROPE_SH, off=(-1, -1),
                  over=line('M60.4 178.6 L67.6 178.6', SILVER, 2.2, cap='butt')))
    P.append(Part('fill', ell(64, 104.6, 6, 5.6), fill='#3a3848', shade='#22202c', off=(-1.2, -1.4)))
    P.append(Part('fill', pth('M58.4 29.6 L58.4 24.6 C58.4 17.6 69.6 17.6 69.6 24.6 L69.6 29.6 L66 29.6 L66 25 '
                              'C66 22.4 62 22.4 62 25 L62 29.6 Z'), off=(-1, -1.2)))
    body = ('M50 30 C54 26.6 74 26.6 78 30 C84.4 35 85.4 46 86.6 60 C88 76 94 88 106 96.6 C109 98.8 108 102.4 104 102.4 '
            'L24 102.4 C20 102.4 19 98.8 22 96.6 C34 88 40 76 41.4 60 C42.6 46 43.6 35 50 30 Z')
    bands = (line('M44.2 42.6 Q64 47 83.8 42.6', '#4a4860', 1.8) + line('M28.8 91.8 Q64 98.2 99.2 91.8', SILVER, 2)
             + line('M26 95.6 Q64 102 102 95.6', SILVER_SH, 0.9, op=0.8))
    # an eye closed on its face, the Hush's mark
    bands += line('M54 70 Q64 76 74 70', SILVER_SH, 1.6) + line('M57 71.6 L55 75 M64 73.4 L64 77.4 M71 71.6 L73 75', SILVER_SH, 1.0)
    drips = ''
    for x, l in ((34, 10), (58, 16), (92, 8)):
        drips += line('M%d 100 L%d %d' % (x, x, 100 + l), SILVER, 1.4, op=0.8) + dot(x, 101.6 + l, 1.5, SILVER, 0.85)
    hl = spec(52, 60, 2.6, 16, rot=12, op=0.35, col=SILVER_HI) + line('M31 96.4 Q40 92 44 84', SILVER_HI, 1.0, op=0.5)
    P.append(Part('fill', pth(body), off=(-5, -3), over=bands, hl=hl))
    P.append(Part('fill', ell(64, 102.2, 41.4, 4.2), fill='#06050a', shade='#06050a', no_shade=True, rim=False, sil=False, lw=1.2))
    P.append(Part('fill', ell(64, 104.6, 6, 5.6), fill='#3a3848', shade='#22202c', off=(-1.2, -1.4), rim=False, sil=False))
    return svg(ctx, paint(ctx, P, pal) + drips, 128, 192)


# ================================================================ the dead sconce

def sconce_dead_svg():
    """W6's `c` (64 frame): a snuffed iron sconce, a silver edge on its arm,
    a stub of cold wax and a curl of old smoke. It gives no light."""
    ctx = Ctx('sd')
    pal = _pal(base='#2a2836', shade='#1a1822')
    P = []
    P.append(Part('fill', pth('M29.6 50 L34.4 50 L32 58.6 Z'), off=(-0.8, -0.8)))
    P.append(Part('limb', pth('M28.4 45.6 C20.4 44.6 19.4 37.6 24.4 36.2 C27.6 35.4 30.6 35.6 32 33.6'), width=2.6, fill='#2a2836',
                  over=line('M27.4 44.6 C21.6 43.4 21 38.4 24.6 37.4', SILVER, 0.9, op=0.8)))
    P.append(Part('limb', pth('M35.6 45.6 C41.4 45 43.2 40.4 40.2 38.6'), width=2, fill='#2a2836'))
    P.append(Part('limb', pth('M32 41 L32 33.4'), width=2.4, fill='#2a2836'))
    P.append(Part('fill', ell(32, 46, 5, 5), off=(-1.2, -1.4), over=dot(32, 46, 1.6, INK_LINE)))
    P.append(Part('fill', pth('M21.6 30.2 L42.4 30.2 Q41.6 34 37 34.4 L27 34.4 Q22.4 34 21.6 30.2 Z'), off=(-1, -1.2),
                  over=line('M23.4 31.2 L40.6 31.2', SILVER, 0.9, op=0.8)))
    parts, wick = candle_parts(28.6, 35.4, 23.4, 30.6, 20.6, lcol=INK_LINE, drips=((0.3, 2.4), (0.72, 3.4)))
    for p in parts:
        p.fill = COLD_WAX if p.fill == WAX else ('#a8a4b4' if p.fill == '#fffaec' else p.fill)
        p.shade = COLD_WAX_SH if p.shade == WAX_SH else ('#8a8698' if p.shade == '#eadfc0' else p.shade)
    P += parts
    smoke = line('M32.4 20 Q29.6 15 33 11.4 Q36.4 7.6 33.4 3.6', '#8a86a0', 1.1, op=0.55)
    return svg64(ctx, paint(ctx, P, pal) + wick + smoke)


# ================================================================ the eye seal (the arena door)

def eye_seal_svg(closed):
    """The Hush's door (128 x 192, the two-by-three doorway): a frame of
    black stone round an eye-shaped opening; closed, black lids meet across
    it with a silver lash line."""
    ctx = Ctx('es' + ('c' if closed else 'o'))
    pal = _pal(base=STONE6, shade=STONE6_SH)
    P = []
    frame = ('M8 192 L8 20 Q64 -6 120 20 L120 192 L100 192 L100 40 Q64 22 28 40 L28 192 Z')
    P.append(Part('fill', pth(frame), off=(-2.4, -2.2), over=line('M12 188 L12 22 Q64 -2 116 22', STONE6_HI, 1.2, op=0.7)))
    eye_d = 'M28 112 Q64 40 100 112 Q64 184 28 112 Z'
    if closed:
        over = ('<path d="%s" fill="#08070c" stroke="%s" stroke-width="3"/>' % (eye_d, INK_LINE)
                + '<path d="M28 112 Q64 70 100 112 Q64 124 28 112 Z" fill="#1e1c28"/>'
                + '<path d="M28 112 Q64 154 100 112 Q64 124 28 112 Z" fill="#16141e"/>'
                + line('M30 112 Q64 124 98 112', SILVER, 2.0)
                + ''.join(line('M%.1f %.1f L%.1f %.1f' % (x, 112 + 12 * (1 - ((x - 64) / 36.0) ** 2) - 0.5, x + (x - 64) * 0.08,
                                                        112 + 12 * (1 - ((x - 64) / 36.0) ** 2) + 5), SILVER_SH, 1.2)
                          for x in (40, 48, 56, 64, 72, 80, 88)))
    else:
        over = ('<path d="%s" fill="#040306" stroke="%s" stroke-width="3" opacity="0.8"/>' % (eye_d, INK_LINE)
                + line('M30 112 Q64 46 98 112', SILVER_SH, 1.4, op=0.7) + line('M30 112 Q64 178 98 112', SILVER_SH, 1.0, op=0.5))
    return svg(ctx, paint(ctx, P, pal) + over, 128, 192)


# ================================================================ points

POINTS = {
    'bell_buoy': {'water': (32, 70), 'bell': (32, 48), 'light': (32, 18)},
    'bell_buoy_rung': {'water': (32, 70), 'bell': (32, 48), 'light': (32, 18)},
    'vigil_candle_out': {'foot': (32, 64), 'flame': (32, 8)},
    'vigil_candle_lit': {'foot': (32, 64), 'flame': (32, 8)},
    'grasp_hand': {'tips': (14, 11), 'base': (32, 160), 'hurt': [4, 0, 56, 160]},
    'buoy_lantern_lit': {'foot': (32, 96), 'flame': (32, 30), 'water': (32, 54)},
    'buoy_lantern_out': {'foot': (32, 96), 'flame': (32, 30), 'water': (32, 54)},
    'altar_hush': {'foot': (32, 96), 'flame': (32, 22)}, 'altar_hush_lit': {'foot': (32, 96), 'flame': (32, 22)},
    'bell_hush': {'hang': (64, 20), 'rope': [58, 108, 12, 82]}, 'bell_hush_beam': {'hang': (64, 20)},
    'sconce_dead': {'flame': (32, 14)},
    'eye_seal_open': {'cells': [2, 3]}, 'eye_seal_closed': {'cells': [2, 3]},
}


def points_json():
    import json
    doc = {'_doc': 'A2 World 6 props. Frame units, 2 units = 1 world px (sprites drawn at scale 0.25). bell_buoy*: 64 x 96, '
                   'its float\'s crest ("water") on the lake line; "bell" the bell (the toll ring), "light" the lantern. '
                   'vigil_candle_*: 64 x 64, "foot" on the floor, "flame" the wick tip (a live flame and the light go '
                   'there). grasp_hand: 64 x 160 (32 x 80 px), two hands filling the grasp\'s 28 x 80 px hurt rect ("hurt", units), the highest fingertip at "tips", its bottom '
                   '"base" on the water line when fully risen (show only what is above the line). buoy_lantern_*: v2\'s '
                   'lantern_post frame (64 x 96, "foot" on the floor, "flame" the light), its cork float at "water". '
                   'altar_hush*, bell_hush*: v2\'s altar and bell frames. sconce_dead: v2\'s sconce frame (no flame, no '
                   'light). eye_seal_*: 128 x 192 over the two-by-three doorway boss_arena.gd seals.'}
    doc.update({k: {n: (list(p) if isinstance(p, tuple) else p) for n, p in v.items()} for k, v in POINTS.items()})
    return json.dumps(doc, indent=1, sort_keys=True) + '\n'


def files():
    return {
        'art/props/bell_buoy.svg': bell_buoy_svg(False),
        'art/props/bell_buoy_rung.svg': bell_buoy_svg(True),
        'art/props/vigil_candle_out.svg': vigil_candle_svg(False),
        'art/props/vigil_candle_lit.svg': vigil_candle_svg(True),
        'art/props/grasp_hand.svg': grasp_hand_svg(),
        'art/props/buoy_lantern_lit.svg': buoy_lantern_svg(True),
        'art/props/buoy_lantern_out.svg': buoy_lantern_svg(False),
        'art/props/altar_hush.svg': altar_hush_svg(False),
        'art/props/altar_hush_lit.svg': altar_hush_svg(True),
        'art/props/bell_hush.svg': bell_hush_svg(),
        'art/props/bell_hush_beam.svg': bell_hush_beam_svg(),
        'art/props/sconce_dead.svg': sconce_dead_svg(),
        'art/props/eye_seal_open.svg': eye_seal_svg(False),
        'art/props/eye_seal_closed.svg': eye_seal_svg(True),
        'art/props/points_w6.json': points_json(),
    }


def build(write):
    for rel, text in files().items():
        write(rel, text)
