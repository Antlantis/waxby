"""HUD pieces (64 x 64 frame) and touch-control glyphs (128 x 128 frame).

  ember            the currency: a glowing coal with a tiny flame
  flame_full/empty a health pip: a candle flame / a grey smoking wick
  sigil_empty      the slot for an uncollected sigil
  btn_*            light glyphs on transparent (the engine draws the circle):
                   move, jump, attack; each Calling's Special (knight Aegis
                   shield, witch Flare, runner Smoke Step, founder Peal,
                   sexton Knell wisp; btn_special_toll the Sexton's bell at
                   max wisps) and the flask
v3 (A8): the world tabs world_1..world_6, the Candlemark, the Trials'
medals, the Waxworks' seals and the mode pill's drip, spare_wick and hushing
(see v3_files()). The logo is logo.py.
"""
import math

import kit
from kit import Part, ell, pth, shp
from common import (Ctx, RIM, GOLD, GOLD_SH, GOLD_LINE, FLAME, FLAME_MID, FLAME_CORE, FLAME_EDGE, FLAME_LINE, svg64,
                    svg128, paint, line, dot, flame, flame_d, glow, spec, sparkle, star4, mix, weights, CHAR_WEIGHTS)


def ember_svg():
    """A faceted chunk of coal glowing through its cracks, a tiny flame on top."""
    ctx = Ctx('em')
    L = '#1c0806'
    s = glow(ctx, 32, 36, 27, '#ff7a3a', 0.6)
    lump = [(13.4, 40.6), (18.4, 30.2), (28.4, 25.6), (40.6, 27), (50.2, 34.4), (51, 44.6), (43.4, 52.4), (29.6, 53.6), (18, 49.4)]
    d = 'M' + ' L'.join('%.1f %.1f' % p for p in lump) + ' Z'
    hot = ctx.radgrad([(0, '#ffe8a0'), (0.35, '#ffa040'), (0.75, '#d8402a'), (1, '#7a1a16')], cx=0.45, cy=0.42, r=0.62)
    # dark charcoal facets over the hot core; the gaps between them are the glowing cracks
    facets = [
        ([(18.4, 30.8), (28.4, 26.6), (39.8, 27.8), (35.4, 34.6), (22.6, 36.4)], '#5a4448'),
        ([(41.6, 28.8), (49.2, 35), (49.8, 43), (41.2, 40.4), (37.4, 35.4)], '#3e2c30'),
        ([(14.6, 40.4), (21.4, 38.6), (27.2, 45.2), (24.8, 51.6), (18.6, 48.6)], '#46343a'),
        ([(29.6, 46.2), (39.6, 42.6), (48.8, 45.6), (42.8, 51.4), (30.4, 52.4)], '#34262a'),
    ]
    art = ''.join('<path d="M%s Z" fill="%s" stroke="%s" stroke-width="0.8" stroke-linejoin="round"/>' % (
        ' L'.join('%.1f %.1f' % p for p in pts), col, L) for pts, col in facets)
    art += spec(24, 30.6, 3.4, 1, rot=-22, op=0.55)
    P = [Part('fill', pth(d), fill=hot, no_shade=True, line=L, over=art)]
    body = paint(ctx, P, dict(line=L, rim=RIM, base='#c8352a', shade='#8a1e1a'))
    return svg64(ctx, s + body + flame(ctx, 31.2, 31.6, 9.2, 17.6, lean=1, halo=False)
                 + star4(51, 18, 2.4, FLAME_CORE, 0.95) + dot(14.6, 24, 1.1, FLAME, 0.9))


def flame_full_svg():
    ctx = Ctx('ff')
    s = glow(ctx, 32, 36, 30, FLAME, 0.6)
    # a big stickered flame, rim and all
    d = flame_d(32, 57, 30, 50, 2.6)
    s += '<path d="%s" fill="%s" stroke="%s" stroke-width="%.1f" stroke-linejoin="round"/>' % (d, RIM, RIM, kit.OUT_W + kit.RIM_W)
    s += '<path d="%s" fill="%s" stroke="%s" stroke-width="%.1f" stroke-linejoin="round"/>' % (d, FLAME_LINE, FLAME_LINE, kit.OUT_W)
    s += '<path d="%s" fill="%s"/>' % (d, FLAME_EDGE)
    s += '<path d="%s" fill="%s"/>' % (flame_d(31.4, 56, 25, 42, 2.4), FLAME)
    s += '<path d="%s" fill="%s"/>' % (flame_d(31.8, 55, 17, 28, 1.4), FLAME_MID)
    s += '<path d="%s" fill="%s"/>' % (flame_d(31.8, 54, 10, 16, 0.6), FLAME_CORE)
    s += spec(24, 34, 2, 5, rot=18, op=0.8, col='#fff8e0')
    return svg64(ctx, s)


def flame_empty_svg():
    ctx = Ctx('fe')
    # the burnt-out pip: the same footprint, a grey ghost of the flame, a
    # curled black wick and a wisp of smoke
    d = flame_d(32, 57, 30, 50, 2.6)
    s = '<path d="%s" fill="#000000" fill-opacity="0.3" stroke="#a89eb8" stroke-opacity="0.7" stroke-width="2.2" stroke-linejoin="round"/>' % d
    s += line('M32 57 Q31 51 33.4 47.6', '#0e0a12', 4.4) + line('M32 57 Q31 51 33.4 47.6', '#4a4254', 2)
    s += dot(33.6, 47.4, 1.6, '#ff7a3a', 0.8)
    smoke = 'M33.6 44 C29 39.4 37.6 35 33 29.6 C29.4 25.4 35.6 21.4 32.4 16'
    s += line(smoke, '#0e0a12', 4, op=0.6) + line(smoke, '#b8b0c4', 2.2)
    s += '<circle cx="36.6" cy="12.4" r="2.4" fill="#b8b0c4" stroke="#0e0a12" stroke-width="1.2" stroke-opacity="0.6"/>'
    return svg64(ctx, s)


def sigil_empty_svg():
    ctx = Ctx('se')
    s = '<circle cx="32" cy="33" r="20.6" fill="#000000" fill-opacity="0.35"/>'
    s += '<circle cx="32" cy="33" r="20.6" fill="none" stroke="#c9a227" stroke-opacity="0.75" stroke-width="2.4" stroke-dasharray="4.2 3"/>'
    s += '<circle cx="32" cy="33" r="14" fill="none" stroke="#c9a227" stroke-opacity="0.4" stroke-width="1.2"/>'
    s += '<path d="%s" fill="none" stroke="#c9a227" stroke-opacity="0.6" stroke-width="1.6" stroke-linejoin="round"/>' % flame_d(32, 42.6, 11.4, 19, 1)
    s += '<ellipse cx="32" cy="11.6" rx="3.6" ry="3" fill="none" stroke="#c9a227" stroke-opacity="0.5" stroke-width="1.4"/>'
    return svg64(ctx, s)


# ---------------------------------------------------------------- touch glyphs

GLYPH, GLYPH_SH, GLYPH_LINE = '#fff3dc', '#e2cfae', '#1d1526'


def glyph(ctx, parts):
    """Light glyph parts with a soft dark outline so they hold over any backdrop."""
    weights(5.0, 0, 0, 1)
    body = paint(ctx, parts, dict(line=GLYPH_LINE, rim=RIM, base=GLYPH, shade=GLYPH_SH))
    weights(*CHAR_WEIGHTS)
    return '<g opacity="0.95">%s</g>' % body


def arrow_d(k):
    """A fat rounded arrowhead pointing right (k=1) or left (k=-1)."""
    def X(x):
        return 64 + k * (x - 64)
    return ('M%.1f 40 C%.1f 36.4 %.1f 36.4 %.1f 38.6 L%.1f 58.6 C%.1f 61.8 %.1f 66.2 %.1f 69.4 L%.1f 89.4 '
            'C%.1f 91.6 %.1f 91.6 %.1f 88 Z') % (
        X(46.6), X(47.2), X(50.6), X(53.2), X(84.2), X(88.4), X(88.4), X(84.2), X(53.2), X(50.6), X(47.2), X(46.6))


def btn_arrow_svg(k):
    ctx = Ctx('ba' + ('r' if k > 0 else 'l'))
    P = [Part('fill', pth(arrow_d(k)), off=(-2 * k, -3), hl=spec(64 - 10 * k, 48, 2, 5, rot=-30 * k, op=0.9))]
    return svg128(ctx, glyph(ctx, P))


def btn_jump_svg():
    ctx = Ctx('bj')
    # a double up-chevron: a big one leaping, a smaller one under it
    def chev(y, w, h, t):
        a = w / 2.0
        return ('M64 %.1f C66.6 %.1f 68.4 %.1f 70 %.1f L%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f L64 %.1f '
                'L%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f L58 %.1f C59.6 %.1f 61.4 %.1f 64 %.1f Z') % (
            y, y, y + 0.8, y + 2.4, 64 + a, y + h - 4,
            64 + a + 3.4, y + h, 64 + a - 2, y + h + 5.6, 64 + a - 6, y + h + 3.2, y + t,
            64 - a + 6, y + h + 3.2, 64 - a + 2, y + h + 5.6, 64 - a - 3.4, y + h, 64 - a, y + h - 4,
            y + 2.4, y + 0.8, y, y)
    P = [Part('fill', pth(chev(66, 50, 22, 18)), off=(-1, -2.4)),
         Part('fill', pth(chev(34, 64, 28, 22)), off=(-1.5, -3), hl=spec(50, 48, 6, 1.8, rot=-40, op=0.9))]
    return svg128(ctx, glyph(ctx, P))


def btn_attack_svg():
    ctx = Ctx('bk')
    t = 'translate(64 66) rotate(-45)'
    blade = 'M-8 -5.6 L30 -5.6 L41 0 L30 5.6 L-8 5.6 Z'
    guard = 'M-12.6 -15.6 Q-9 -17.6 -7.2 -14.6 L-7.2 14.6 Q-9 17.6 -12.6 15.6 Q-10.8 0 -12.6 -15.6 Z'
    P = [Part('limb', '<path d="M-30 0 L-14 0" transform="%s" {a}/>' % t, width=7),
         Part('fill', '<ellipse cx="-32" cy="0" rx="5.4" ry="5.4" transform="%s" {a}/>' % t, off=(-1, -1)),
         Part('fill', '<path d="%s" transform="%s" {a}/>' % (blade, t), off=(0, -3),
              over='<path d="M-4 -1 L30 -1" transform="%s" stroke="%s" stroke-width="1.6" opacity="0.5"/>' % (t, GLYPH_LINE)),
         Part('fill', '<path d="%s" transform="%s" {a}/>' % (guard, t), off=(-1, -1))]
    slash = ('<path d="M82 30 Q98 44 96 64" fill="none" stroke="%s" stroke-width="6.4" stroke-linecap="round" opacity="0.9"/>'
             '<path d="M82 30 Q98 44 96 64" fill="none" stroke="%s" stroke-width="3" stroke-linecap="round"/>') % (GLYPH_LINE, GLYPH)
    return svg128(ctx, glyph(ctx, P) + '<g opacity="0.95">%s</g>' % slash)


def gline(d, w=3.2, op=0.9):
    """A dark detail line inside a glyph."""
    return line(d, GLYPH_LINE, w, op=op)


def btn_special_knight_svg():
    """Aegis: a shield with the lantern shield's rose window in its heart."""
    ctx = Ctx('bsk')
    shield = 'M64 22 C76 28 88 30 98 29 C99 58 90 88 64 106 C38 88 29 58 30 29 C40 30 52 28 64 22 Z'
    petals = ''.join(
        '<ellipse cx="%.1f" cy="%.1f" rx="5.4" ry="2.8" transform="rotate(%d %.1f %.1f)" fill="%s" opacity="0.85"/>' % (
            64 + 10.4 * math.cos(math.radians(a)), 60 + 10.4 * math.sin(math.radians(a)), a,
            64 + 10.4 * math.cos(math.radians(a)), 60 + 10.4 * math.sin(math.radians(a)), GLYPH_LINE) for a in range(0, 360, 45))
    rim = ('<path d="M64 30 C74 35 84 37 91 36.6 C91 60 83 83 64 97 C45 83 37 60 37 36.6 C44 37 54 35 64 30 Z" fill="none" '
           'stroke="%s" stroke-width="3" opacity="0.8"/>') % GLYPH_LINE
    P = [Part('fill', pth(shield), off=(-3.4, -3.6),
              over=rim + petals + '<circle cx="64" cy="60" r="4" fill="%s" opacity="0.85"/>' % GLYPH_LINE,
              hl=spec(44, 44, 2.6, 8, rot=16, op=0.9))]
    return svg128(ctx, glyph(ctx, P))


def btn_special_witch_svg():
    """Flare: a lobbed fireball on its arc, sparks round it."""
    ctx = Ctx('bsw')
    trail = ''.join('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s" stroke="%s" stroke-width="2.6"/>' % (x, y, r, GLYPH, GLYPH_LINE)
                    for x, y, r in ((24, 102, 3.4), (32, 90, 4.6), (41.6, 79.6, 5.8)))
    ball = flame_d(70, 100, 52, 76, 14)
    P = [Part('fill', pth(ball), off=(-3.4, -4),
              over='<path d="%s" fill="%s" opacity="0.8"/>' % (flame_d(71.6, 95, 24, 36, 7), GLYPH_LINE)
              + '<path d="%s" fill="%s"/>' % (flame_d(71.8, 92, 12, 18, 3.4), GLYPH),
              hl=spec(54, 66, 2.6, 8, rot=20, op=0.9))]
    sparks = star4(102, 36, 9, GLYPH_LINE) + star4(102, 36, 6.2, GLYPH) + star4(36, 48, 6.8, GLYPH_LINE) + star4(36, 48, 4.4, GLYPH)
    return svg128(ctx, '<g opacity="0.95">%s</g>' % trail + glyph(ctx, P) + '<g opacity="0.95">%s</g>' % sparks)


def btn_special_runner_svg():
    """Smoke Step: a dashing puff of soot, streaks trailing behind."""
    ctx = Ctx('bsr')
    puff = ('M56 90 C44 92 38 82 43 74 C38 64 48 54 58 58 C60 46 76 42 82 52 C92 48 102 58 97 68 '
            'C106 74 100 90 88 88 C84 96 68 96 64 90 C61 92 58 92 56 90 Z')
    P = [Part('fill', pth(puff), off=(-3.4, -3.6),
              over=gline('M56 76 Q62 70 70 74 M74 66 Q82 60 88 66', 3, 0.7),
              hl=spec(60, 62, 5, 2, rot=-30, op=0.9))]
    streaks = ''
    for y, x0, x1 in ((58, 26, 44), (73, 18, 40), (88, 28, 46)):
        streaks += ('<path d="M%d %d L%d %d" stroke="%s" stroke-width="8" stroke-linecap="round"/>' % (x0, y, x1, y, GLYPH_LINE)
                    + '<path d="M%d %d L%d %d" stroke="%s" stroke-width="3.4" stroke-linecap="round"/>' % (x0, y, x1, y, GLYPH))
    return svg128(ctx, '<g transform="translate(5 -6)"><g opacity="0.95">%s</g>%s</g>' % (streaks, glyph(ctx, P)))


def btn_special_founder_svg():
    """Peal: the great bell struck down, its waves running out along the floor."""
    ctx = Ctx('bsf')
    bell = ('M64 26 C71 26 74 30 74 36 C82 38 86 46 86 58 C86 70 88 76 94 82 L34 82 C40 76 42 70 42 58 '
            'C42 46 46 38 54 36 C54 30 57 26 64 26 Z')
    P = [Part('fill', pth(bell), off=(-3.4, -3.6), over=gline('M44 70 L84 70', 3, 0.7),
              hl=spec(52, 50, 2.4, 8, rot=8, op=0.9)),
         Part('fill', ell(64, 88, 7, 6), off=(-1, -1))]
    waves = ''
    for k in (-1, 1):
        for r, op in ((14, 1.0), (24, 0.8)):
            d = 'M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (64 + k * (30 + r * 0.3), 92, 64 + k * (34 + r), 86 - r * 0.2,
                                                     64 + k * (34 + r * 0.8), 70 - r * 0.2)
            waves += ('<path d="%s" fill="none" stroke="%s" stroke-width="8" stroke-linecap="round" opacity="%s"/>' % (d, GLYPH_LINE, op)
                      + '<path d="%s" fill="none" stroke="%s" stroke-width="3.6" stroke-linecap="round" opacity="%s"/>' % (d, GLYPH, op))
    ground = ('<path d="M24 98 L104 98" stroke="%s" stroke-width="8" stroke-linecap="round"/>'
              '<path d="M24 98 L104 98" stroke="%s" stroke-width="3.6" stroke-linecap="round"/>') % (GLYPH_LINE, GLYPH)
    return svg128(ctx, glyph(ctx, P) + '<g opacity="0.95">%s%s</g>' % (waves, ground))


def btn_special_sexton_svg():
    """Knell: a mourning wisp, two dot eyes, its tail curling."""
    ctx = Ctx('bsx')
    body = ('M64 22 C72 34 88 44 88 64 C88 80 78 90 66 90 C60 90 56 94 58 100 C50 98 48 90 50 86 '
            'C42 80 40 72 40 64 C40 44 56 36 64 22 Z')
    eyes = ('<ellipse cx="56" cy="64" rx="4.4" ry="6" fill="%s"/><ellipse cx="74" cy="64" rx="4.4" ry="6" fill="%s"/>' % (GLYPH_LINE, GLYPH_LINE)
            + '<circle cx="54.6" cy="61.6" r="1.6" fill="%s"/><circle cx="72.6" cy="61.6" r="1.6" fill="%s"/>' % (GLYPH, GLYPH))
    P = [Part('fill', pth(body), off=(-3.4, -3.6), over=eyes + gline('M60 76 Q65 79 70 76', 2.6, 0.8),
              hl=spec(50, 48, 2.2, 6, rot=20, op=0.9))]
    motes = star4(96, 36, 6.4, GLYPH_LINE) + star4(96, 36, 4.2, GLYPH) + star4(32, 42, 5, GLYPH_LINE) + star4(32, 42, 3.2, GLYPH)
    return svg128(ctx, glyph(ctx, P) + '<g opacity="0.95">%s</g>' % motes)


def btn_special_toll_svg():
    """Toll the Dead (the Sexton at max wisps): his handbell swung, ringing."""
    ctx = Ctx('bst')
    t = 'translate(-2 6) rotate(-18 64 64)'
    bell = ('M64 44 C72 44 76 50 77 58 C78 68 80 76 88 82 L40 82 C48 76 50 68 51 58 C52 50 56 44 64 44 Z')
    P = [Part('limb', '<path d="M64 22 L64 42" transform="%s" {a}/>' % t, width=8),
         Part('fill', '<ellipse cx="64" cy="20" rx="6" ry="6" transform="%s" {a}/>' % t, off=(-1, -1)),
         Part('fill', '<path d="%s" transform="%s" {a}/>' % (bell, t), off=(-3.4, -3.6),
              over='<path d="M50 72 L78 72" transform="%s" stroke="%s" stroke-width="3" opacity="0.7"/>' % (t, GLYPH_LINE),
              hl='<g transform="%s">%s</g>' % (t, spec(56, 56, 2.2, 7, rot=8, op=0.9))),
         Part('fill', '<ellipse cx="64" cy="88" rx="6" ry="5.4" transform="%s" {a}/>' % t, off=(-1, -1))]
    rings = ''
    for d in ('M90 46 Q98 56 96 68', 'M98 36 Q110 52 106 72', 'M26 76 Q20 86 24 98'):
        rings += ('<path d="%s" fill="none" stroke="%s" stroke-width="7.4" stroke-linecap="round"/>' % (d, GLYPH_LINE)
                  + '<path d="%s" fill="none" stroke="%s" stroke-width="3.2" stroke-linecap="round"/>' % (d, GLYPH))
    return svg128(ctx, glyph(ctx, P) + '<g opacity="0.95">%s</g>' % rings)


def btn_flask_svg():
    """The flask: a round-bellied bottle, corked, half full, a glint."""
    ctx = Ctx('bfl')
    bottle = ('M56 26 L72 26 L72 44 C88 50 96 62 96 76 C96 94 82 104 64 104 C46 104 32 94 32 76 '
              'C32 62 40 50 56 44 Z')
    liquid = ('<g clip-path="%s"><path d="M28 72 Q40 66 52 72 Q64 78 76 72 Q88 66 100 72 L100 110 L28 110 Z" fill="%s"/></g>' % (
        ctx.clip(shp(pth(bottle))), GLYPH_SH)
              + gline('M34 72 Q42 67 52 72 Q64 78 76 72 Q86 67 94 72', 2.8, 0.75))
    P = [Part('fill', pth(bottle), off=(-3.4, -3.6), over=liquid, hl=spec(46, 64, 3, 9, rot=24, op=0.9)),
         Part('fill', pth('M53 18 L75 18 Q77 18 77 21 L77 27 Q77 30 74 30 L54 30 Q51 30 51 27 L51 21 Q51 18 53 18 Z'), off=(-1.2, -1.4),
              over=gline('M56 24 L72 24', 2.2, 0.6))]
    heart = kit.heart(64, 86, 1.25, GLYPH_LINE, GLYPH_LINE)
    return svg128(ctx, glyph(ctx, P) + '<g opacity="0.8">%s</g>' % heart)


# ================================================================ v3 (A8): world tabs, the Candlemark, medals, seals, pills
# All on the 64 frame at 128 px, stickered and cel-shaded like the rest:
#   world_1 .. world_6   the map's world tabs, each in its accent (spec 10):
#                        a bell, a dripping candle, a skull-fruit tree, a gear
#                        with icicles, a glass shard, the pale eye
#   candlemark           the gold four-point star beside the level at 40
#   medal_bronze/_silver/_gold/_dawn   the Vigil Trials' medals: a disc on a
#                        ribbon, a candle stamp (a sunrise on Dawn); each one's
#                        edge differs too (plain, beaded, scalloped, rayed), so
#                        they part by shape as well as metal. medal_none: the
#                        empty place, a dashed ghost
#   seal_bronze/_silver/_gold   the Waxworks' wax seals: a lumpy disc with a
#                        bell stamp, one, two or three drips running off it
#   drip, spare_wick, hushing   the mode pill's 16 px icons: a wax drop, a
#                        spare candle, a Hushing (a black flame with a pale eye)

BRZ, BRZ_SH, BRZ_HI, BRZ_LINE = '#c8893a', '#8e5a24', '#f2c07a', '#3a2008'
SLV, SLV_SH, SLV_HI, SLV_LINE = '#dfe3ee', '#9ea4bc', '#ffffff', '#1e2236'
GLD, GLD_SH, GLD_HI, GLD_LINE = '#f2c448', '#b8862a', '#ffe890', GOLD_LINE
DWN, DWN_SH, DWN_HI, DWN_LINE = '#fff4dc', '#ecc88c', '#ffffff', '#5a3414'
WAXC, WAXC_SH, WAXC_LINE = '#efe6cc', '#cdbf9c', '#4a3420'
HUSH_RIM, HUSH_INK, HUSH_PALE = '#c8c8f0', '#0e0c18', '#d8d4f0'
ICE_L, ICE_M, ICE_D, ICE_LINE = '#e8f8ff', '#bfe4f4', '#7eaecc', '#16283a'


def stk(ctx, parts, line_col):
    """Parts painted as a sticker with the given ink line."""
    return paint(ctx, parts, dict(line=line_col, rim=RIM, base='#ffffff', shade='#cccccc'))


def poly(pts):
    return 'M' + ' L'.join('%.2f %.2f' % p for p in pts) + ' Z'


def bell_d(cx, top, w, h):
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


# ---------------------------------------------------------------- world tabs

def world_1_svg():
    """The Sunken Cathedral: a gold bell, ringing."""
    ctx = Ctx('w1')
    L = GOLD_LINE
    s = glow(ctx, 32, 34, 28, GOLD, 0.35)
    P = [Part('fill', ell(32, 11.6, 4.4, 4.4), fill=GOLD, shade=GOLD_SH, off=(-0.6, -0.8), line=L,
              over=dot(32, 11.6, 1.8, L)),
         Part('fill', ell(32, 51.4, 5, 4.4), fill=GOLD, shade=GOLD_SH, off=(-0.8, -0.8), line=L),
         Part('fill', pth(bell_d(32, 14.6, 36, 35)), fill=GOLD, shade=GOLD_SH, off=(-2.6, -2.4), line=L,
              over=line('M17.4 43 Q32 45.6 46.6 43', GOLD_SH, 1.6) + line('M20.4 38 Q32 40.4 43.6 38', GLD_HI, 1.1),
              hl=spec(25, 26, 1.8, 5.6, rot=10, op=0.9))]
    waves = ''
    for d in ('M52 24 Q56.4 30 54.6 36', 'M12 24 Q7.6 30 9.4 36'):
        waves += line(d, L, 4.4) + line(d, '#fff2c8', 1.9)
    return svg64(ctx, s + stk(ctx, P, L) + waves + sparkle(52, 12, 3, L))


def world_2_svg():
    """The Tallow Deep: a stub of pale candle, lit, a fat drip running down it
    and a drop falling."""
    ctx = Ctx('w2')
    L = '#4a3420'
    wax, wax_sh = '#f2dc8a', '#d0b060'
    s = glow(ctx, 30, 22, 24, '#f7b64a', 0.4)
    drip = ('M17.6 32 C17.6 27.4 24 26.6 30 26.6 C36 26.6 42.4 27.4 42.4 32 L42.4 34 C42.4 36 40 36 40 34 L40 33 '
            'C38.6 32.4 37.4 32.6 36.6 33.4 L36.6 45 C36.6 49 31.6 49 31.6 45 L31.6 33.6 C29 32.8 26.4 33 24.6 34 '
            'L24.6 37 C24.6 39 21.6 39 21.6 37 L21.6 34 C19.8 33.8 17.6 34.4 17.6 32 Z')
    P = [Part('fill', pth('M17.6 56 L17.6 31 L42.4 31 L42.4 56 Z'), fill=wax, shade=wax_sh, off=(-3.4, 0), line=L,
              hl=spec(21, 46, 1, 4.4, rot=0, op=0.8)),
         Part('fill', pth(drip), fill='#fff4c0', shade=wax, off=(-0.8, -0.6), line=L, lw=1.2),
         Part('fill', pth('M48 44 C50.6 48 52.4 50.6 52.4 53 C52.4 55.6 50.4 57.4 48 57.4 C45.6 57.4 43.6 55.6 43.6 53 '
                          'C43.6 50.6 45.4 48 48 44 Z'), fill='#fff4c0', shade=wax, off=(-0.6, -0.8), line=L,
              hl=dot(46.4, 52.4, 0.9, '#ffffff'))]
    wick = line('M30 27.4 Q29.4 25 30.4 22.6', '#241a14', 1.6)
    return svg64(ctx, s + stk(ctx, P, L) + wick + flame(ctx, 30.4, 24, 9.6, 17, lean=0.8, halo=False))


def world_3_svg():
    """The Bone Orchard: a crooked little tree hung with skull-fruit."""
    ctx = Ctx('w3')
    L = '#1e2410'
    ch, ch_sh, ch_hi = '#c8d46a', '#8e9a3a', '#f0f8b0'
    s = glow(ctx, 32, 34, 28, ch, 0.35)
    trunk = ('M27.6 58 C28.6 50 29.4 44 28 38 C26 32 20 30 14.6 26.4 L16.8 23.4 C22 26.6 26 28 29.2 31.6 '
             'C29.6 26 28.4 20 25.6 14 L29 12.6 C32 18.6 33.4 24.6 33.2 30.4 C36.4 25.6 41 22.4 47.4 20.8 L48.2 24.4 '
             'C42.4 26 38.2 29.4 35.6 34.4 C34.4 42 35 50 36.6 58 Z')
    P = [Part('fill', pth(trunk), fill='#626a3a', shade='#40462a', off=(-1.6, 0), line=L,
              over=line('M31 54 C31.4 48 31.8 44 31 40', '#40462a', 1.1))]
    fruit = []
    for x, y, k in ((15.4, 31, 1.0), (47.6, 26.4, 1.06), (27, 19.6, 0.9)):
        fruit.append((x, y, k))
        P.append(Part('limb', pth('M%.1f %.1f L%.1f %.1f' % (x, y - 6.6 * k, x, y - 4.4 * k)), width=1.4, fill='#626a3a', line=L))
        skull = ('M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f L%.1f %.1f '
                 'C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z') % (
            x, y - 5 * k,
            x + 5.4 * k, y - 5 * k, x + 6 * k, y, x + 4.4 * k, y + 2.6 * k,
            x + 3.6 * k, y + 4 * k, x + 3 * k, y + 5.6 * k, x + 1.8 * k, y + 5.6 * k,
            x - 1.8 * k, y + 5.6 * k,
            x - 3 * k, y + 5.6 * k, x - 3.6 * k, y + 4 * k, x - 4.4 * k, y + 2.6 * k,
            x - 6 * k, y, x - 5.4 * k, y - 5 * k, x, y - 5 * k)
        P.append(Part('fill', pth(skull), fill=ch, shade=ch_sh, off=(-1, -1), line=L,
                      over=dot(x - 2 * k, y + 0.4 * k, 1.5 * k, L) + dot(x + 2 * k, y + 0.4 * k, 1.5 * k, L)
                      + line('M%.1f %.1f L%.1f %.1f' % (x, y + 3 * k, x, y + 4.8 * k), L, 0.8),
                      hl=spec(x - 2.4 * k, y - 2.6 * k, 1.4 * k, 0.8 * k, rot=-20, op=0.9, col=ch_hi)))
    roots = line('M20 58.6 Q26 55.6 32 57 Q38 55.4 44 58.6', L, 3.4) + line('M20 58.6 Q26 55.6 32 57 Q38 55.4 44 58.6', '#626a3a', 1.4)
    return svg64(ctx, s + stk(ctx, P, L) + roots + star4(52, 44, 2.2, ch_hi, 0.95) + star4(10, 14, 1.8, ch_hi, 0.9))


def gear_d(cx, cy, r_in, r_out, teeth):
    """A gear with square-shouldered teeth (each half its pitch wide)."""
    pts = []
    pitch = math.pi * 2 / teeth
    for k in range(teeth):
        a0 = k * pitch - math.pi / 2
        for t, r in ((0.0, r_in), (0.06, r_out), (0.44, r_out), (0.5, r_in)):
            a = a0 + t * pitch
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return poly(pts)


def world_4_svg():
    """The Frozen Carillon: a frosted gear, icicles hanging from its teeth."""
    ctx = Ctx('w4')
    L = ICE_LINE
    s = glow(ctx, 32, 30, 28, ICE_M, 0.4)
    gear = gear_d(32, 28, 16.4, 21.8, 9)
    P = [Part('fill', pth(gear), fill=ICE_M, shade=ICE_D, off=(-2.2, -2.4), line=L,
              over='<circle cx="32" cy="28" r="10" fill="none" stroke="%s" stroke-width="1.4" opacity="0.7"/>' % ICE_D
              + ''.join(dot(32 + 7 * math.cos(a), 28 + 7 * math.sin(a), 1.1, ICE_D) for a in (math.pi * 2 * i / 6 for i in range(6))),
              hl=spec(24, 18, 2.4, 1.2, rot=-40, op=0.9)),
         Part('fill', ell(32, 28, 4.6, 4.6), fill='#e8f8ff', shade=ICE_D, off=(-0.8, -0.8), line=L, over=dot(32, 28, 1.8, L))]
    icicles = ''
    for x, y, h in ((22.4, 45.4, 11), (32, 49.4, 9), (41.6, 45.4, 12.4), (15.4, 38.6, 7)):
        icicles += ('<path d="M%.1f %.1f L%.1f %.1f L%.1f %.1f Z" fill="%s" stroke="%s" stroke-width="1.6" stroke-linejoin="round"/>' % (
            x - 2.4, y, x + 2.4, y, x + 0.3, y + h, ICE_L, L)
                    + line('M%.1f %.1f L%.1f %.1f' % (x - 0.6, y + 1, x - 0.1, y + h * 0.6), '#ffffff', 0.9))
    snow = ''.join('<path d="M%.1f %.1f L%.1f %.1f M%.1f %.1f L%.1f %.1f M%.1f %.1f L%.1f %.1f" stroke="%s" stroke-width="1.2" stroke-linecap="round"/>' % (
        x, y - r, x, y + r, x - r * 0.87, y - r * 0.5, x + r * 0.87, y + r * 0.5, x - r * 0.87, y + r * 0.5, x + r * 0.87, y - r * 0.5, '#ffffff')
        for x, y, r in ((53, 12, 3.4), (10, 54, 2.6)))
    return svg64(ctx, s + stk(ctx, P, L) + icicles + snow)


def world_5_svg():
    """The Shattered Sanctum: a shard of crimson window glass, leaded, catching
    the light."""
    ctx = Ctx('w5')
    L = '#2a0c16'
    shard = [(30, 5.6), (41.6, 18), (38.4, 22.6), (46.6, 34.4), (40.6, 58.4), (27.6, 50.6), (19.4, 36), (24.4, 30.6), (18.4, 20.4)]
    s = glow(ctx, 32, 32, 28, '#c83a5a', 0.35)
    clip = ctx.clip('<path d="%s"/>' % poly(shard))
    facets = ('<g clip-path="%s">' % clip
              + '<path d="%s" fill="#e05a76"/>' % poly([(18, 4), (46, 4), (46, 26), (30, 32), (16, 22)])
              + '<path d="%s" fill="#a82a48"/>' % poly([(30, 32), (48, 26), (48, 60), (34, 60)])
              + '<path d="%s" fill="#f2a0b0" opacity="0.9"/>' % poly([(22, 18), (30, 8), (34, 16), (26, 26)])
              + line('M30 32 L46 26 M30 32 L34 60 M30 32 L16 22 M30 32 L21 37', L, 1.8)
              + '</g>')
    P = [Part('fill', pth(poly(shard)), fill='#c83a5a', shade='#8a1e36', no_shade=True, line=L, over=facets,
              hl=spec(27, 16, 1.2, 4.4, rot=30, op=0.9))]
    return svg64(ctx, s + stk(ctx, P, L) + star4(40, 20, 5.2, L) + star4(40, 20, 3.6, '#ffffff')
                 + sparkle(12, 48, 2.6, L) + sparkle(53, 50, 2.2, L))


def world_6_svg():
    """The Hushdeep: the Hush's eye as the story shows it (the Undercandle's
    art/story/figures/hush_eye.svg): a pale violet almond darkening to its
    corners, a dim violet iris ring, a pinprick black pupil with one glint,
    set in black lids. No lashes, no slit: it is not a beast's eye."""
    ctx = Ctx('w6')
    cx, cy, a, b = 32.0, 32.0, 24.0, 9.6
    almond = 'M%.2f %.2f C%.2f %.2f %.2f %.2f %.2f %.2f C%.2f %.2f %.2f %.2f %.2f %.2f Z' % (
        cx - a, cy, cx - a * 0.5, cy - b * 1.34, cx + a * 0.5, cy - b * 1.34, cx + a, cy,
        cx + a * 0.5, cy + b * 1.34, cx - a * 0.5, cy + b * 1.34, cx - a, cy)
    # the black lids round it: an ellipse a little wider than the almond
    rx, ry, k = a * 1.08, b * 1.72, 0.5523
    lids = ('M%.2f %.2f C%.2f %.2f %.2f %.2f %.2f %.2f C%.2f %.2f %.2f %.2f %.2f %.2f '
            'C%.2f %.2f %.2f %.2f %.2f %.2f C%.2f %.2f %.2f %.2f %.2f %.2f Z') % (
        cx - rx, cy, cx - rx, cy - ry * k, cx - rx * k, cy - ry, cx, cy - ry,
        cx + rx * k, cy - ry, cx + rx, cy - ry * k, cx + rx, cy,
        cx + rx, cy + ry * k, cx + rx * k, cy + ry, cx, cy + ry,
        cx - rx * k, cy + ry, cx - rx, cy + ry * k, cx - rx, cy)
    white = ctx.radgrad([(0, '#e4e0f8'), (0.55, HUSH_PALE), (0.85, '#8a82b0'), (1, '#3a3260')], cx=0.5, cy=0.5, r=0.55)
    iris = ctx.radgrad([(0, '#3a3060'), (0.7, '#4a3e78'), (1, '#6a5a9a')], cx=0.5, cy=0.5, r=0.5)
    clip = ctx.clip('<path d="%s"/>' % almond)
    eye = ('<g clip-path="%s">' % clip
           + '<rect x="0" y="0" width="64" height="64" fill="%s"/>' % white
           + '<circle cx="%.1f" cy="%.1f" r="9.4" fill="%s"/>' % (cx, cy, iris)
           + '<circle cx="%.1f" cy="%.1f" r="8.5" fill="none" stroke="#6a5a9a" stroke-width="1.1"/>' % (cx, cy)
           + '<circle cx="%.1f" cy="%.1f" r="2.3" fill="#000000"/>' % (cx, cy)
           + dot(cx - 0.9, cy - 1.0, 0.75, '#ffffff')
           + '<path d="%s" fill="none" stroke="#1a1430" stroke-width="2.6" opacity="0.6"/>' % almond
           + '</g>'
           # the lids' rims catching a thread of violet
           + line('M%.2f %.2f C%.2f %.2f %.2f %.2f %.2f %.2f' % (cx - a, cy, cx - a * 0.5, cy - b * 1.34, cx + a * 0.5, cy - b * 1.34, cx + a, cy),
                  '#4a3a7a', 1.0, op=0.9)
           + line('M%.2f %.2f C%.2f %.2f %.2f %.2f %.2f %.2f' % (cx - a, cy, cx - a * 0.5, cy + b * 1.34, cx + a * 0.5, cy + b * 1.34, cx + a, cy),
                  '#2a2440', 0.8, op=0.9))
    P = [Part('fill', pth(lids), fill='#000000', shade='#000000', no_shade=True, line=HUSH_RIM, over=eye)]
    return svg64(ctx, glow(ctx, 32, 32, 28, HUSH_PALE, 0.3) + stk(ctx, P, HUSH_RIM)
                 + star4(54, 52, 2.2, HUSH_PALE, 0.9) + star4(10, 12, 1.8, HUSH_PALE, 0.8))


# ---------------------------------------------------------------- the Candlemark

def candlemark_svg():
    """The Candlemark: a fat gold four-point star, a warm glint at its heart."""
    ctx = Ctx('cm')
    L = GOLD_LINE
    r, k = 25.0, 0.34
    x, y = 32, 32
    d = 'M%.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f Z' % (
        x, y - r, x + r * k, y - r * k, x + r, y, x + r * k, y + r * k, x, y + r, x - r * k, y + r * k, x - r, y,
        x - r * k, y - r * k, x, y - r)
    grad = ctx.radgrad([(0, '#fff6d0'), (0.35, '#ffe28a'), (1, GOLD)], cx=0.5, cy=0.5, r=0.5)
    P = [Part('fill', pth(d), fill=grad, shade=GOLD_SH, off=(-1.6, -1.6), line=L,
              over=line('M%.1f %.1f L%.1f %.1f' % (x, y - r + 6, x, y - 4), '#ffffff', 1.4, op=0.8),
              hl=spec(x - 3.4, y - 3.4, 1.6, 3.2, rot=-45, op=0.9))]
    return svg64(ctx, glow(ctx, 32, 32, 26, '#ffd070', 0.45) + stk(ctx, P, L)
                 + '<path d="%s" fill="#ff9a3a" stroke="%s" stroke-width="0.8"/>' % (flame_d(32, 36.4, 5.6, 9.6, 0.3), L)
                 + '<path d="%s" fill="#fff4cf"/>' % flame_d(32.1, 35.6, 2.8, 5, 0.2))


# ---------------------------------------------------------------- medals

MEDALS = {
    'bronze': dict(m=(BRZ, BRZ_SH, BRZ_HI, BRZ_LINE), ribbon=('#a8402a', '#e8a060'), edge='plain'),
    'silver': dict(m=(SLV, SLV_SH, SLV_HI, SLV_LINE), ribbon=('#4a64a8', '#f0f4ff'), edge='beads'),
    'gold': dict(m=(GLD, GLD_SH, GLD_HI, GLD_LINE), ribbon=('#a63a5a', '#ffd84a'), edge='scallop'),
    'dawn': dict(m=(DWN, DWN_SH, DWN_HI, DWN_LINE), ribbon=('#f2a57a', '#fffaf0'), edge='rays'),
}
MC = (32, 39.6)
MR = 15.0


def ribbon_parts(col, stripe, ln):
    P = []
    for pts in ([(47, 6.8), (37, 6.8), (27, 29), (37.2, 31.4)], [(17, 6.8), (27, 6.8), (37, 29), (26.8, 31.4)]):
        mid_a = ((pts[0][0] + pts[1][0]) / 2, pts[0][1])
        mid_b = ((pts[2][0] + pts[3][0]) / 2, (pts[2][1] + pts[3][1]) / 2)
        P.append(Part('fill', pth(poly(pts)), fill=col, shade=mix(col, '#000000', 0.3), off=(-1.2, 0), line=ln,
                      over=line('M%.1f %.1f L%.1f %.1f' % (mid_a[0], mid_a[1] + 0.8, mid_b[0], mid_b[1] - 1), stripe, 1.8)))
    return P


def medal_edge(kind, cx, cy, r):
    if kind == 'scallop':
        pts = []
        for i in range(48):
            a = math.pi * 2 * i / 48
            rr = r + 2.2 * abs(math.cos(a * 6))
            pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
        return poly(pts)
    if kind == 'rays':
        pts = []
        for i in range(32):
            a = math.pi * 2 * i / 32 - math.pi / 2
            rr = r + 3.2 if i % 2 == 0 else r + 0.4
            pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
        return poly(pts)
    return 'M%.2f %.2f a%.2f %.2f 0 1 0 %.2f 0 a%.2f %.2f 0 1 0 %.2f 0 Z' % (cx - r, cy, r, r, 2 * r, r, r, -2 * r)


def candle_stamp(cx, cy, col, hi, ln):
    """An embossed candle: its body, a drip, a flame."""
    body = 'M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (cx - 3.4, cy + 7.6, cx - 3.4, cy - 2.4, cx + 3.4, cy - 2.4, cx + 3.4, cy + 7.6)
    s = '<path d="%s" fill="%s" stroke="%s" stroke-width="1.1" stroke-linejoin="round"/>' % (body, col, ln)
    s += line('M%.1f %.1f L%.1f %.1f' % (cx - 2.2, cy - 1.2, cx - 2.2, cy + 6.4), hi, 1.0, op=0.9)
    s += line('M%.1f %.1f L%.1f %.1f' % (cx - 5.6, cy + 8.2, cx + 5.6, cy + 8.2), ln, 1.8)
    s += '<path d="%s" fill="%s" stroke="%s" stroke-width="1.1" stroke-linejoin="round"/>' % (flame_d(cx, cy - 3.2, 5.2, 9.2, 0.4), col, ln)
    s += '<path d="%s" fill="%s"/>' % (flame_d(cx, cy - 4, 2.4, 4.4, 0.2), hi)
    return s


def sunrise_stamp(ctx, cx, cy, ln):
    """Dawn's stamp: a sun half risen over a line of still water, its rays up."""
    sun = 'M%.1f %.1f a7 7 0 0 1 14 0 Z' % (cx - 7, cy + 2)
    s = '<path d="%s" fill="#ffc870" stroke="%s" stroke-width="1.2"/>' % (sun, ln)
    s += '<path d="M%.1f %.1f a3.6 3.6 0 0 1 7.2 0 Z" fill="#fff4cf"/>' % (cx - 3.6, cy + 2)
    for a in (-150, -120, -90, -60, -30):
        t = math.radians(a)
        s += line('M%.1f %.1f L%.1f %.1f' % (cx + 9 * math.cos(t), cy + 2 + 9 * math.sin(t), cx + 12 * math.cos(t),
                                             cy + 2 + 12 * math.sin(t)), '#f2a57a', 1.8)
    s += line('M%.1f %.1f L%.1f %.1f' % (cx - 11, cy + 2.4, cx + 11, cy + 2.4), ln, 1.4)
    s += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (
        cx - 7, cy + 5.6, cx - 3.5, cy + 4.4, cx, cy + 5.6, cx + 1, cy + 8, cx + 4, cy + 6.8, cx + 7, cy + 8), '#f2a57a', 1.3)
    return s


def medal_svg(kind):
    M = MEDALS[kind]
    ctx = Ctx('md' + kind[:2])
    col, sh, hi, ln = M['m']
    cx, cy = MC
    s = glow(ctx, cx, cy, 24, '#ffe6b0', 0.45) if kind == 'dawn' else ''
    P = ribbon_parts(M['ribbon'][0], M['ribbon'][1], ln)
    edge = medal_edge(M['edge'], cx, cy, MR + (0.6 if M['edge'] == 'plain' else 0))
    face = 'M%.2f %.2f a%.2f %.2f 0 1 0 %.2f 0 a%.2f %.2f 0 1 0 %.2f 0 Z' % (cx - MR + 3, cy, MR - 3, MR - 3, 2 * (MR - 3), MR - 3, MR - 3, -2 * (MR - 3))
    over = '<path d="%s" fill="%s" stroke="%s" stroke-width="1.1" opacity="0.95"/>' % (face, mix(col, sh, 0.25), sh)
    if M['edge'] == 'beads':
        over += ''.join(dot(cx + (MR - 1.4) * math.cos(a), cy + (MR - 1.4) * math.sin(a), 0.95, hi)
                        for a in (math.pi * 2 * i / 20 for i in range(20)))
    stamp = sunrise_stamp(ctx, cx, cy, ln) if kind == 'dawn' else candle_stamp(cx, cy + 0.6, sh, hi, ln)
    P.append(Part('fill', pth(edge), fill=col, shade=sh, off=(-2.2, -2.4), line=ln, over=over + stamp,
                  hl=spec(cx - 8.6, cy - 7.6, 1.6, 3.6, rot=40, op=0.9)))
    glint = sparkle(52, 30, 3.2, ln) if kind in ('gold', 'dawn') else ''
    if kind == 'dawn':
        glint += sparkle(11, 50, 2.6, ln) + star4(53, 52, 1.8, '#fff4cf', 0.95)
    return svg64(ctx, s + stk(ctx, P, ln) + glint)


def medal_none_svg():
    """No medal yet: the ribbon and disc as a dashed ghost."""
    ctx = Ctx('mdno')
    cx, cy = MC
    c = '#b8aacb'
    s = '<path d="%s" fill="#000000" fill-opacity="0.3" stroke="%s" stroke-opacity="0.55" stroke-width="2" stroke-dasharray="3.4 2.6"/>' % (
        poly([(47, 6.8), (37, 6.8), (27, 29), (37.2, 31.4)]), c)
    s += '<path d="%s" fill="#000000" fill-opacity="0.3" stroke="%s" stroke-opacity="0.55" stroke-width="2" stroke-dasharray="3.4 2.6"/>' % (
        poly([(17, 6.8), (27, 6.8), (37, 29), (26.8, 31.4)]), c)
    s += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="#000000" fill-opacity="0.4"/>' % (cx, cy, MR + 0.6)
    s += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="none" stroke="%s" stroke-opacity="0.75" stroke-width="2.4" stroke-dasharray="4.2 3"/>' % (
        cx, cy, MR + 0.6, c)
    s += '<path d="%s" fill="none" stroke="%s" stroke-opacity="0.5" stroke-width="1.6" stroke-linejoin="round"/>' % (
        flame_d(cx, cy + 6, 9, 15, 0.8), c)
    return svg64(ctx, s)


# ---------------------------------------------------------------- the Waxworks' seals

SEALS = {
    'bronze': (('#c47c3c', '#8a4e22', '#f0b878'), 1),
    'silver': (('#cdd1e0', '#8e94ac', '#ffffff'), 2),
    'gold': (('#ecbc4c', '#b08428', '#fff0a8'), 3),
}


def seal_svg(kind):
    (col, sh, hi), drips = SEALS[kind]
    ctx = Ctx('sl' + kind[:2])
    ln = '#2a1608'
    cx, cy, r = 32, 27, 19.6
    pts = []
    for i in range(60):
        a = math.pi * 2 * i / 60
        rr = r + 1.4 * math.sin(a * 7 + 0.6) + 0.8 * math.sin(a * 3 + 1.9)
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    blob = poly(pts)
    P = []
    runs = {1: [(33, 11.4)], 2: [(25.4, 10), (38.6, 12)], 3: [(19.6, 13), (32.2, 12.4), (44.6, 12)]}[drips]
    for x, ln_ in runs:
        y0 = cy + math.sqrt(max(0.0, r * r - (x - cx) ** 2)) - 3
        d = ('M%.1f %.1f L%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f L%.1f %.1f Z') % (
            x - 2.8, y0, x - 2.6, y0 + ln_ * 0.55, x - 3.8, y0 + ln_ * 0.8, x - 3, y0 + ln_ + 1.6, x, y0 + ln_ + 2.2,
            x + 3, y0 + ln_ + 1.6, x + 3.8, y0 + ln_ * 0.8, x + 2.6, y0 + ln_ * 0.55, x + 2.8, y0)
        P.append(Part('fill', pth(d), fill=col, shade=sh, off=(-1, -0.6), line=ln,
                      hl=dot(x - 1.2, y0 + ln_ * 0.7, 0.8, hi)))
    ring = '<circle cx="%.1f" cy="%.1f" r="13.6" fill="%s" stroke="%s" stroke-width="1.2" opacity="0.9"/>' % (cx, cy, mix(col, sh, 0.35), sh)
    ring += '<circle cx="%.1f" cy="%.1f" r="12" fill="none" stroke="%s" stroke-width="0.9" opacity="0.8"/>' % (cx, cy + 0.6, hi)
    bell = bell_d(cx, cy - 9, 15, 15.6)
    stamp = ('<path d="%s" fill="%s" stroke="%s" stroke-width="1.2" stroke-linejoin="round"/>' % (bell, sh, ln)
             + '<path d="M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f" fill="none" stroke="%s" stroke-width="1.1"/>' % (
                 cx - 3.2, cy - 5, cx - 4, cy - 1, cx - 4.6, cy + 2, cx - 6, cy + 4, hi)
             + dot(cx, cy + 8.6, 1.8, sh) + '<circle cx="%.1f" cy="%.1f" r="1.8" fill="none" stroke="%s" stroke-width="1"/>' % (cx, cy + 8.6, ln)
             + line('M%.1f %.1f L%.1f %.1f' % (cx - 6.6, cy + 5.2, cx + 6.6, cy + 5.2), ln, 0.9, op=0.7))
    P.append(Part('fill', pth(blob), fill=col, shade=sh, off=(-2.4, -2.4), line=ln, over=ring + stamp,
                  hl=spec(cx - 11, cy - 9, 1.8, 3.4, rot=40, op=0.85)))
    glint = sparkle(53, 12, 3.2, ln) if kind == 'gold' else ''
    return svg64(ctx, stk(ctx, P, ln) + glint)


# ---------------------------------------------------------------- the mode pill's icons (read at 16 px)

def drip_svg():
    """A drip: one fat drop of cream wax, warm, never water's blue."""
    ctx = Ctx('dp')
    ln = WAXC_LINE
    d = 'M32 6 C39 17 48.6 27 48.6 39.6 C48.6 50.6 41 58 32 58 C23 58 15.4 50.6 15.4 39.6 C15.4 27 25 17 32 6 Z'
    P = [Part('fill', pth(d), fill='#f6ecd0', shade='#e0b878', off=(-3.4, -3.6), line=ln,
              hl=spec(24.6, 40, 3, 6.4, rot=10, op=0.95) + dot(26, 30, 1.8, '#ffffff'))]
    return svg64(ctx, stk(ctx, P, ln))


def spare_wick_svg():
    """A Spare Wick: a fat little candle, lit."""
    ctx = Ctx('sw')
    ln = '#3a2410'
    s = glow(ctx, 32, 22, 22, FLAME, 0.45)
    top = ('M19.4 33.4 C19.4 30.4 25 29.6 32 29.6 C39 29.6 44.6 30.4 44.6 33.4 L44.6 37 C44.6 39 42 39 42 37 L42 35.6 '
           'C40 34.8 37.8 35 36.8 36 L36.8 42 C36.8 44.4 33.4 44.4 33.4 42 L33.4 36 C30 35.2 27 35.4 24.6 36.4 L24.6 38.6 '
           'C24.6 40.6 21.8 40.6 21.8 38.6 L21.8 36.4 C20.2 36 19.4 35.4 19.4 33.4 Z')
    P = [Part('fill', pth('M19.4 58 L19.4 32.6 L44.6 32.6 L44.6 58 Z'), fill=WAXC, shade=WAXC_SH, off=(-4, 0), line=ln,
              hl=spec(23.4, 48, 1.4, 5, rot=0, op=0.85)),
         Part('fill', pth(top), fill='#fffaec', shade='#e8dcbc', off=(-0.8, -0.6), line=ln, lw=1.2, rim=False)]
    wick = line('M32 30.4 Q31.2 27.4 32.4 25', '#241a14', 2.0)
    return svg64(ctx, s + stk(ctx, P, ln) + wick + flame(ctx, 32.4, 27, 14, 22, lean=1.0, line_w=1.8, halo=False))


def hushing_svg():
    """A Hushing: a black flame that eats light, rimmed in the Hush's silver,
    one pale eye half open in it."""
    ctx = Ctx('hs')
    d = ('M32 58.4 C45 58.4 50 49 48.4 39 C47 30 41 24.6 40.6 15 C40.4 10 42.6 6.4 46 4.4 C37.6 5.4 31.6 12 30.6 21.4 '
         'C30.2 24.4 29.4 26.4 27.6 27.6 C25.4 24.6 24.4 20.4 24.8 15.6 C18.4 21.6 14.4 30 15.4 40.6 C16.4 51 22.6 58.4 32 58.4 Z')
    eye = 'M21.6 40.6 C25 35.4 28.4 34 32 34 C35.6 34 39 35.4 42.4 40.6 C39 44.4 35.6 45.6 32 45.6 C28.4 45.6 25 44.4 21.6 40.6 Z'
    clip = ctx.clip('<path d="%s"/>' % eye)
    inner = ('<path d="%s" fill="%s"/>' % (eye, HUSH_PALE)
             + '<g clip-path="%s"><circle cx="32" cy="40.8" r="2.7" fill="%s"/>' % (clip, HUSH_INK)
             + dot(31.1, 40, 0.7, '#ffffff')
             + '<path d="M18 33 L46 33 L46 38.8 C38 36.4 26 36.4 18 38.8 Z" fill="#1a1830"/></g>'
             + line('M21.6 40.6 C25 37.8 28.4 37 32 37 C35.6 37 39 37.8 42.4 40.6', HUSH_RIM, 1.4))
    P = [Part('fill', pth(d), fill='#1a1830', shade='#0a0812', off=(-3, -2), line=HUSH_INK, over=inner,
                        hl=line('M20.4 38 C20 32 22 26 24.6 22', '#5a5488', 1.6, op=0.9) + line('M36 18 C37 13 39.4 9.6 42 7.6', '#5a5488', 1.4, op=0.9))]
    return svg64(ctx, paint(ctx, P, dict(line=HUSH_INK, rim=HUSH_RIM, base='#1a1830', shade='#0a0812')))


def v3_files():
    out = {'art/ui/world_%d.svg' % n: fn() for n, fn in (
        (1, world_1_svg), (2, world_2_svg), (3, world_3_svg), (4, world_4_svg), (5, world_5_svg), (6, world_6_svg))}
    out['art/ui/candlemark.svg'] = candlemark_svg()
    for k in MEDALS:
        out['art/ui/medal_%s.svg' % k] = medal_svg(k)
    out['art/ui/medal_none.svg'] = medal_none_svg()
    for k in SEALS:
        out['art/ui/seal_%s.svg' % k] = seal_svg(k)
    out['art/ui/drip.svg'] = drip_svg()
    out['art/ui/spare_wick.svg'] = spare_wick_svg()
    out['art/ui/hushing.svg'] = hushing_svg()
    return out


def files():
    return {
        'art/ui/btn_special_knight.svg': btn_special_knight_svg(),
        'art/ui/btn_special_witch.svg': btn_special_witch_svg(),
        'art/ui/btn_special_runner.svg': btn_special_runner_svg(),
        'art/ui/btn_special_founder.svg': btn_special_founder_svg(),
        'art/ui/btn_special_sexton.svg': btn_special_sexton_svg(),
        'art/ui/btn_special_toll.svg': btn_special_toll_svg(),
        'art/ui/btn_flask.svg': btn_flask_svg(),
        'art/ui/ember.svg': ember_svg(),
        'art/ui/flame_full.svg': flame_full_svg(),
        'art/ui/flame_empty.svg': flame_empty_svg(),
        'art/ui/sigil_empty.svg': sigil_empty_svg(),
        'art/ui/btn_left.svg': btn_arrow_svg(-1),
        'art/ui/btn_right.svg': btn_arrow_svg(1),
        'art/ui/btn_jump.svg': btn_jump_svg(),
        'art/ui/btn_attack.svg': btn_attack_svg(),
        **v3_files(),
    }
