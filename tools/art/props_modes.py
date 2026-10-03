"""The secrets' and the modes' props (A2).

  secret_door          the arch the silver bell hangs in (128 x 192 = 64 x 96 px, foot (64, 192)): old stone round
                       a bell-shaped window; the silver bell hangs at "bell" (64, 72), where world.add_bell puts it
  secret_door_glint    its window's silver glow alone (same frame): drawn over the door, strong inside Waxby's
                       light and as a faint glint in any light (spec §3.9: the visual twin of the hum)
  silver_bell          the silver bell (bell.svg's frame, 128 x 192, hung from (64, 20)): drawn at 0.14 (half
                       size), so its lines are heavier
  legend_shrine_out, legend_shrine_lit   the shrine (64 x 96, foot (32, 96)): a gold mensa under a lancet; the prize
                       appears at "prize"; lit, gold light stands in the lancet
  grave_candle_out, grave_candle_lit     a Lost Wick's grave candle (64 x 64, foot (32, 64)): a candle stub before a
                       small headstone; the live flame goes at "flame"
  waxley_cart          Waxley's cart (128 x 112 = 64 x 56 px, drawn at 0.25, bottom centre (64, 112) on the floor):
                       two wheels, a striped awning, candles for sale, a lantern on a pole ("lantern")
  trial_candle_out, trial_candle_lit     a Vigil Trial's candle (32 x 56 = 16 x 28 px): a violet taper in a little
                       iron cup; lit, only its wick is scorched (glow draws the flame at "flame")
and points_modes.json (frame units; 2 units = 1 world px).
"""
import kit
from kit import Part, ell, pth
import common
from common import (Ctx, RIM, GOLD, GOLD_SH, GOLD_HI, GOLD_LINE, WAX, WAX_SH, WAX_LINE, FLAME, FLAME_CORE, FLAME_MID,
                    svg, svg64, paint, line, dot, flame, flame_d, glow, spec, sparkle, star4, mix)
from props import rrect, arch_d, candle_parts, flame_outline

STONE, STONE_SH, STONE_HI, STONE_LINE = '#54496a', '#3a3148', '#7a6c96', '#140e1c'
SILVER, SILVER_HI, SILVER_SH, SILVER_LINE = '#d8dcf0', '#ffffff', '#9a9cc0', '#1a1830'
IRON, IRON_SH, IRON_LINE, IRON_HI = '#4a4658', '#302c3c', '#120e18', '#8a86a0'
TAPER, TAPER_SH, TAPER_HI = '#7a5a9a', '#54406e', '#a68ac4'

# The bell-shaped window: a crown at the top, flaring to the sill.
WINDOW = ('M64 30 C54 30 50 36 49 46 C47.6 62 46 80 40 100 C35 118 26 132 24 150 L24 184 L104 184 L104 150 '
          'C102 132 93 118 88 100 C82 80 80.4 62 79 46 C78 36 74 30 64 30 Z')


SILVER_BELL_BODY = ('M49 30 C54 26 74 26 79 30 C86 36 86 48 87.4 62 C89 78 95 88 107 97 C110 99.4 109 103.4 104.6 103.4 '
                    'L23.4 103.4 C19 103.4 18 99.4 21 97 C33 88 39 78 40.6 62 C42 48 42 36 49 30 Z')


# ================================================================ the secret door

def secret_door_svg():
    ctx = Ctx('sdr')
    pal = dict(line=STONE_LINE, rim=RIM, base=STONE, shade=STONE_SH)
    P = []
    # the arch: a thick stone frame, its courses, a keystone with a small bell
    outer = ('M8 192 L8 60 C8 26 34 6 64 4 C94 6 120 26 120 60 L120 192 Z')
    clip_win = ctx.clip('<path d="%s"/>' % WINDOW)
    courses = (line('M8 150 L28 150 M100 150 L120 150 M8 112 L34 112 M94 112 L120 112 M8 76 L40 76 M88 76 L120 76', STONE_LINE, 1.4, op=0.55)
               + line('M20 150 L20 112 M110 150 L110 112 M26 112 L26 76 M104 112 L104 76', STONE_LINE, 1.2, op=0.45)
               + line('M14 186 L14 62 C14 32 38 12 64 10', STONE_HI, 1.4, op=0.8))
    P.append(Part('fill', pth(outer), off=(-3, -2.6), over=courses))
    P.append(Part('fill', pth('M55 2.4 L73 2.4 L70 20 L58 20 Z'), fill=STONE_HI, shade=STONE, off=(-1, -1),
                  over='<path d="M61.4 14 Q61.4 8.4 64 8 Q66.6 8.4 66.6 14 Z" fill="%s" stroke="%s" stroke-width="0.8"/>' % (SILVER_SH, STONE_LINE)))
    P.append(Part('fill', rrect(4, 184, 124, 192, 1.4), off=(-1.6, -1.2), over=line('M6 185.6 L122 185.6', STONE_HI, 1.1, op=0.8)))
    # the window: dark, a hint of the bell shape's rim in old silver leaf
    win = ('<path d="%s" fill="#0a0812"/>' % WINDOW
           + '<g clip-path="%s"><path d="%s" fill="none" stroke="#1a1628" stroke-width="10"/></g>' % (clip_win, WINDOW)
           + '<path d="%s" fill="none" stroke="%s" stroke-width="2.4"/>' % (WINDOW, STONE_LINE)
           + '<path d="%s" fill="none" stroke="%s" stroke-width="1.0" opacity="0.6"/>' % (WINDOW, SILVER_SH))
    return svg(ctx, paint(ctx, P, pal) + win, 128, 192)


def secret_door_glint_svg():
    """The window's silver glow alone: a bright rim with a soft inner glow
    hugging it (the middle stays clear, so the silver bell in it shows), a
    few glints. The feature draws it at the alpha the light says."""
    ctx = Ctx('sdg')
    clip = ctx.clip('<path d="%s"/>' % WINDOW)
    s = '<g clip-path="%s">' % clip
    s += '<path d="%s" fill="none" stroke="#c8d0ff" stroke-width="16" opacity="0.14"/>' % WINDOW
    s += '<path d="%s" fill="none" stroke="#dce2ff" stroke-width="7" opacity="0.28"/>' % WINDOW
    s += '</g>'
    s += '<path d="%s" fill="none" stroke="%s" stroke-width="2.8"/>' % (WINDOW, SILVER)
    s += '<path d="%s" fill="none" stroke="#ffffff" stroke-width="1.0" opacity="0.9"/>' % WINDOW
    # The silver bell hanging in it catches the light too: its rim, where
    # world.add_bell hangs it (bell.svg's frame at 0.14: 0.56 door units a
    # bell unit, its hang point (64, 20) on the door's (64, 72)).
    s += ('<path d="%s" fill="#dce2ff" fill-opacity="0.16" stroke="#eef0ff" stroke-width="3.4" opacity="0.9" '
          'transform="translate(64 72) scale(0.56) translate(-64 -20)"/>' % SILVER_BELL_BODY)
    s += sparkle(56, 86, 3.2, SILVER_LINE, '#ffffff')
    s += sparkle(84, 96, 4.4, SILVER_LINE, '#ffffff') + sparkle(40, 150, 3.2, SILVER_LINE, '#ffffff') + star4(64, 34, 2.4, '#ffffff', 0.9)
    return svg(ctx, s, 128, 192)


# ================================================================ the silver bell

def silver_bell_svg():
    """The silver bell in bell.svg's frame (hung from (64, 20), rope to
    ~190), drawn at 0.14: heavy lines so it reads at 36 px."""
    ctx = Ctx('svb')
    common.weights(out=7.0, rim=5.0, inner=2.6, detail=1.8)
    try:
        pal = dict(line=SILVER_LINE, rim=RIM, base=SILVER, shade=SILVER_SH)
        P = []
        P.append(Part('limb', pth('M64 108 C64.8 130 63.2 152 64 176'), width=7.0, fill='#e8e4f0', line=SILVER_LINE,
                      over=line(''.join('M%.1f %.1f l5 -3.4 ' % (61.6, y) for y in range(116, 176, 8)), SILVER_SH, 1.6)))
        P.append(Part('fill', pth('M58 176 L70 176 L72 186 L66.6 184 L64 190 L61.4 184 L56 186 Z'), fill='#e8e4f0', shade=SILVER_SH,
                      off=(-1.4, -1.4), line=SILVER_LINE))
        P.append(Part('fill', pth('M57 30 L57 24 C57 14 71 14 71 24 L71 30 L66.4 30 L66.4 25 C66.4 21.6 61.6 21.6 61.6 25 L61.6 30 Z'),
                      off=(-1.4, -1.4)))
        body = SILVER_BELL_BODY
        star = star4(64, 70, 11, SILVER_LINE) + star4(64, 70, 7.6, '#ffffff')
        bands = line('M29 92.6 Q64 99.4 99 92.6', SILVER_HI, 3.2) + line('M44 43 Q64 47.6 84 43', SILVER_HI, 2.6)
        P.append(Part('fill', pth(body), off=(-7, -4), over=bands + star,
                      hl=spec(51, 58, 3.6, 17, rot=12, op=0.9) + spec(54, 36, 4, 1.8, rot=-20, op=0.95)))
        P.append(Part('fill', ell(64, 103, 42, 5), fill='#3a3a58', shade='#3a3a58', no_shade=True, rim=False, sil=False, lw=2.0))
        P.append(Part('fill', ell(64, 106, 7.4, 7), fill='#9a9cc0', shade='#6a6c90', off=(-1.6, -1.6), rim=False, sil=False,
                      hl=dot(61.6, 103.4, 1.8, '#ffffff')))
        return svg(ctx, paint(ctx, P, pal), 128, 192)
    finally:
        common.weights(*common.CHAR_WEIGHTS)


# ================================================================ the shrine and the grave candle

def legend_shrine_svg(lit):
    """The Legendary's shrine (64 x 96, foot (32, 96)): a gold mensa on a
    stone base under a lancet; "prize" is where the prize appears. Lit, gold
    light stands in the lancet."""
    ctx = Ctx('ls' + ('l' if lit else 'o'))
    pal = dict(line=STONE_LINE, rim=RIM, base=STONE, shade=STONE_SH)
    P = []
    lancet = arch_d(14, 50, 4, 60)
    if lit:
        lg = ctx.lingrad([(0, '#fff2c8'), (0.6, '#ffd84a'), (1, '#e8a830')])
    else:
        lg = ctx.lingrad([(0, '#2a2238'), (1, '#161020')])
    P.append(Part('fill', pth(arch_d(9, 55, -1, 64)), off=(-2, -2),
                  over=line('M12 62 L12 22', STONE_HI, 1.1, op=0.8)))
    P.append(Part('fill', pth(lancet), fill=lg, shade=lg, no_shade=True, lw=1.4,
                  over=line('M32 10 L32 60', STONE_LINE, 1.4, op=0.8) + line('M16 40 L48 40', STONE_LINE, 1.2, op=0.7)))
    # the mensa: gold, on a stone base
    P.append(Part('fill', rrect(12, 66, 52, 94.6, 1.2), off=(-2.2, -2), over=line('M15 70 L15 92', STONE_HI, 1, op=0.7)
                  + '<path d="M26 78 Q32 72 38 78 L38 90 L26 90 Z" fill="#140e1c" stroke="%s" stroke-width="1"/>' % STONE_LINE))
    P.append(Part('fill', rrect(6, 58, 58, 66, 1.8), fill=GOLD, shade=GOLD_SH, off=(-1.4, -1.4), line=GOLD_LINE,
                  over=line('M8 60.4 L56 60.4', GOLD_HI, 1.2) + ''.join(dot(x, 63, 0.9, GOLD_HI) for x in (12, 22, 32, 42, 52))))
    under, over = '', ''
    if lit:
        warm = ctx.radgrad([(0, '#ffd84a', 0.5), (0.5, '#ffb040', 0.18), (1, '#ffb040', 0)])
        under = '<ellipse cx="32" cy="40" rx="31" ry="44" fill="%s"/>' % warm
        over = sparkle(50, 16, 3.2, STONE_LINE, '#fff2c8') + star4(14, 30, 1.8, '#fff2c8', 0.9)
    return svg(ctx, under + paint(ctx, P, pal) + over, 64, 96)


def grave_candle_svg(lit):
    """A Lost Wick's grave candle (64 x 64, foot (32, 64)): a small rounded
    headstone with a candle carved on it, a real stub before it (wick
    "flame")."""
    ctx = Ctx('gv' + ('l' if lit else 'o'))
    pal = dict(line=STONE_LINE, rim=RIM, base=STONE, shade=STONE_SH)
    P = []
    P.append(Part('fill', pth('M12 64 L12 26 C12 14 20 8 30 8 C40 8 48 14 48 26 L48 64 Z'), off=(-2.4, -2),
                  over=flame_outline(30, 40, 7, 12, STONE_SH) + line('M26 40 L26 52 L34 52 L34 40', STONE_SH, 1.2)
                  + line('M16 60 L16 26 C16 17 22 12 30 12', STONE_HI, 1.1, op=0.8)))
    wax, wax_sh = (WAX, WAX_SH) if lit else ('#9a94a8', '#6e6a7c')
    P.append(Part('fill', pth('M38 64 L38.4 38 L48.6 38 L49 64 Z'), fill=wax, shade=wax_sh, off=(-1.8, -0.6), line=WAX_LINE,
                  hl=spec(40.6, 50, 0.9, 6, rot=0, op=0.6)))
    P.append(Part('fill', pth('M37.6 39.4 Q38 36.4 43.6 36 Q49 36.4 49.4 39.4 L47.6 41 L46.8 45 L45.6 41 L41 41.6 L40 44 L39.4 41 Z'),
                  fill='#fffaec' if lit else '#b0aabc', shade='#eadfc0' if lit else '#8a8698', off=(-0.6, -0.6), line=WAX_LINE, lw=0.9))
    wick = line('M43.6 36.4 Q43 34.4 43.8 32', '#241a14', 1.5)
    over = ''
    if lit:
        warm = ctx.radgrad([(0, '#ffb44a', 0.45), (1, '#ffb44a', 0)])
        over = '<ellipse cx="42" cy="34" rx="18" ry="16" fill="%s"/>' % warm + dot(43.8, 32.2, 0.9, '#ff9a3a')
    return svg64(ctx, paint(ctx, P, pal) + wick + over)


# ================================================================ Waxley's cart

def waxley_cart_svg():
    """Waxley's cart (128 x 112, bottom centre (64, 112) on the floor): a
    two-wheeled chandler's cart, a striped awning, candles hanging and
    stacked, a lantern on a pole (its light r 90 at "lantern")."""
    ctx = Ctx('wc')
    WOOD, WOOD_SH, WOOD_LINE = '#8a5a34', '#5a3a20', '#1e1008'
    pal = dict(line=WOOD_LINE, rim=RIM, base=WOOD, shade=WOOD_SH)
    P = []
    # the lantern pole and lantern (behind)
    P.append(Part('limb', pth('M104 88 L104 14'), width=2.6, fill=IRON, line=IRON_LINE))
    P.append(Part('limb', pth('M104 14 L114 14'), width=2.0, fill=IRON, line=IRON_LINE))
    gl = ctx.lingrad([(0, '#fff2c8'), (0.55, '#ffd98a'), (1, '#f2b84b')])
    P.append(Part('fill', pth('M109 18 L119 18 L118 32 L110 32 Z'), fill=gl, shade=gl, no_shade=True, line=IRON_LINE, lw=1.0,
                  over=flame(ctx, 114, 30, 4.6, 8.4, lean=0.3, halo=False, lcol='#5a1e0c')))
    P.append(Part('fill', pth('M108 18.4 L120 18.4 L116.6 13.4 L111.4 13.4 Z'), fill=IRON, shade=IRON_SH, off=(-0.6, -0.6), line=IRON_LINE))
    # the body: a box with planks, the shafts reaching left
    P.append(Part('limb', pth('M30 80 L4 90'), width=3.2, fill=WOOD))
    P.append(Part('fill', rrect(26, 56, 102, 88, 2), off=(-2.6, -2.4),
                  over=line('M28 66 L100 66 M28 76 L100 76', WOOD_LINE, 1.1, op=0.55)
                  + line('M40 58 L40 86 M64 58 L64 86 M88 58 L88 86', WOOD_LINE, 1.0, op=0.4)
                  + line('M28 58.4 L100 58.4', '#b88a5a', 1.2, op=0.9)))
    # stacked candles for sale on the counter
    for i, (x, h) in enumerate(((36, 14), (42, 18), (48, 12), (84, 16), (90, 12))):
        P.append(Part('fill', rrect(x - 2.4, 56 - h, x + 2.4, 56, 0.8), fill=WAX, shade=WAX_SH, off=(-0.8, 0), line=WAX_LINE, lw=0.9,
                      over=line('M%.1f %.1f L%.1f %.1f' % (x, 56 - h, x, 53 - h), '#241a14', 1.0)))
    # the awning: striped cloth on two posts
    P.append(Part('limb', pth('M30 56 L30 22'), width=2.2, fill=WOOD))
    P.append(Part('limb', pth('M98 56 L98 22'), width=2.2, fill=WOOD))
    awning = 'M22 22 L106 22 L102 34 Q97 38 92 34 Q87 38 82 34 Q77 38 72 34 Q67 38 62 34 Q57 38 52 34 Q47 38 42 34 Q37 38 32 34 Q27 38 24 34 Z'
    stripes = ''.join('<path d="M%d 22 L%d 22 L%d 35 L%d 35 Z" fill="#f0e6cc"/>' % (x, x + 10, x + 9, x - 1) for x in range(24, 104, 20))
    clip = ctx.clip('<path d="%s"/>' % awning)
    P.append(Part('fill', pth(awning), fill='#b83a4a', shade='#8a2a38', off=(-1.2, -1.6), line='#2a0a10',
                  over='<g clip-path="%s">%s</g>' % (clip, stripes)))
    # hanging candles under the awning
    for x in (44, 56, 68):
        P.append(Part('fill', rrect(x - 1.6, 38, x + 1.6, 48, 0.6), fill=WAX, shade=WAX_SH, off=(-0.6, 0), line=WAX_LINE, lw=0.8))
    # the wheel
    P.append(Part('fill', ell(64, 94, 17, 17), fill='#6a4428', shade='#46301c', off=(-2, -2),
                  over=''.join(line('M64 94 L%.1f %.1f' % (64 + 15 * c, 94 + 15 * s), WOOD_LINE, 1.6)
                               for c, s in ((1, 0), (0.5, 0.866), (-0.5, 0.866), (-1, 0), (-0.5, -0.866), (0.5, -0.866)))
                  + '<circle cx="64" cy="94" r="12.6" fill="none" stroke="%s" stroke-width="1.2"/>' % WOOD_LINE
                  + dot(64, 94, 3, IRON) + dot(63.4, 93.4, 1, IRON_HI)))
    P.append(Part('fill', rrect(96, 104, 104, 112, 1), fill=WOOD_SH, shade=WOOD_LINE, off=(-0.6, -0.6)))
    under = '<ellipse cx="114" cy="26" rx="20" ry="18" fill="%s"/>' % ctx.radgrad([(0, '#ffc85a', 0.5), (1, '#ffb040', 0)])
    return svg(ctx, under + paint(ctx, P, pal), 128, 112)


# ================================================================ the trial candle

def trial_candle_svg(lit):
    """A Vigil Trial's candle (32 x 56 = 16 x 28 px): a violet taper in a
    little iron cup. Lit, its wick is scorched (glow draws the flame at
    "flame"); out, a clean white wick."""
    ctx = Ctx('tc' + ('l' if lit else 'o'))
    pal = dict(line=IRON_LINE, rim=RIM, base=IRON, shade=IRON_SH)
    P = []
    P.append(Part('fill', pth('M6 46 L26 46 L23 54 L9 54 Z'), off=(-1, -1), over=line('M8 47.4 L24 47.4', IRON_HI, 0.9, op=0.9)))
    P.append(Part('fill', pth('M11.4 46.6 L11.8 12 L20.2 12 L20.6 46.6 Z'), fill=TAPER if not lit else '#8a68ac', shade=TAPER_SH,
                  off=(-1.6, -0.4), line='#1c1026', hl=spec(13.8, 28, 0.9, 8, rot=0, op=0.6, col=TAPER_HI)))
    P.append(Part('fill', pth('M11.4 13.6 Q12 10.6 16 10.4 Q20 10.6 20.6 13.6 L19 15 L18.2 19 L17.2 15 L13.6 15.4 Z'),
                  fill=TAPER_HI, shade=TAPER, off=(-0.4, -0.4), line='#1c1026', lw=0.8))
    wick_col = '#241a14' if lit else '#e8e0d0'
    wick = line('M16 10.8 Q15.4 8.6 16.2 6', wick_col, 1.6)
    if lit:
        wick += dot(16.2, 6.2, 1.0, '#ff9a3a')
    return svg(ctx, paint(ctx, P, pal) + wick, 32, 56)


# ================================================================ points

POINTS = {
    'secret_door': {'foot': (64, 192), 'bell': (64, 72), 'window': [24, 30, 80, 154]},
    'secret_door_glint': {'foot': (64, 192)},
    'silver_bell': {'hang': (64, 20), 'scale': 0.14},
    'legend_shrine_out': {'foot': (32, 96), 'prize': (32, 50)}, 'legend_shrine_lit': {'foot': (32, 96), 'prize': (32, 50)},
    'grave_candle_out': {'foot': (32, 64), 'flame': (43.8, 32)}, 'grave_candle_lit': {'foot': (32, 64), 'flame': (43.8, 32)},
    'waxley_cart': {'foot': (64, 112), 'lantern': (114, 26)},
    'trial_candle_out': {'foot': (16, 54), 'flame': (16, 6)}, 'trial_candle_lit': {'foot': (16, 54), 'flame': (16, 6)},
}


def points_json():
    import json
    doc = {'_doc': 'A2 secrets and modes props. Frame units, 2 units = 1 world px (sprites drawn at scale 0.25, the silver '
                   'bell at 0.14). secret_door (+ _glint): 128 x 192, "foot" on the floor under the S cell; the silver bell '
                   'hangs at "bell" (60 px over the floor, as world.add_bell hangs it); "window" = [x, y, w, h]. '
                   'legend_shrine_*: 64 x 96, the prize at "prize". grave_candle_*: 64 x 64, the live flame at "flame". '
                   'waxley_cart: 128 x 112, bottom centre on the floor, its light at "lantern". trial_candle_*: 32 x 56 '
                   '(16 x 28 px), the live flame at "flame".'}
    doc.update({k: {n: (list(p) if isinstance(p, tuple) else p) for n, p in v.items()} for k, v in POINTS.items()})
    return json.dumps(doc, indent=1, sort_keys=True) + '\n'


def files():
    return {
        'art/props/secret_door.svg': secret_door_svg(),
        'art/props/secret_door_glint.svg': secret_door_glint_svg(),
        'art/props/silver_bell.svg': silver_bell_svg(),
        'art/props/legend_shrine_out.svg': legend_shrine_svg(False),
        'art/props/legend_shrine_lit.svg': legend_shrine_svg(True),
        'art/props/grave_candle_out.svg': grave_candle_svg(False),
        'art/props/grave_candle_lit.svg': grave_candle_svg(True),
        'art/props/waxley_cart.svg': waxley_cart_svg(),
        'art/props/trial_candle_out.svg': trial_candle_svg(False),
        'art/props/trial_candle_lit.svg': trial_candle_svg(True),
        'art/props/points_modes.json': points_json(),
    }


def build(write):
    for rel, text in files().items():
        write(rel, text)
