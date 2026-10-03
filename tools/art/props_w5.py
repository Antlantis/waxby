"""World 5 props (A2): the Shattered Sanctum.

  pennant_slack, pennant_lift, pennant_full   the gust's pennants (64 frame): slack at rest, lifting at
                                              the tell, flying in the gust; hung from (8, 2) (a pole's
                                              top), blowing right (the engine mirrors them)
  glass_crack1, glass_crack2, glass_crack3    crack overlays for a pane (64 frame, transparent): a white
                                              core >= 3 units (1.5 px) on a dark edge
  prism_lamp_lit, prism_lamp_out              the W5 lantern post (64 x 96, v2's lantern_post frame and
                                              points: foot (32, 96), flame (32, 30)): a crystal lantern
                                              on a slim gold post; its crystal is white so a modulate
                                              tints it (4 colours by hash, p_artaudio 4.3)
  window_seal_open, window_seal_closed        the arena door (128 x 192: two tiles by three, the doorway
                                              boss_arena.gd seals): an empty lancet, and the lancet
                                              assembled from shards
  altar_glass, altar_glass_lit                the altar (64 x 96, v2's altar frame: wick tip (32, 22)): a
                                              marble altar floating a little off the floor, a glass cup
  bell_glass, bell_glass_beam                 the bell (128 x 192, v2's: hangs from (64, 20), rope to
                                              176): a bell of leaded panes with its gold rim; a marble beam
  sconce_glass                                the W5 sconce (64 frame, v2's wick tip (32, 14))
and points_w5.json (frame units; 2 units = 1 world px).
Every piece keeps its v2 counterpart's frame and anchor points, so the World
can swap it in by the theme's "props" table (scripts/themes/w5.gd).
"""
import math
import kit
from kit import Part, ell, pth
from common import (Ctx, RIM, GOLD, GOLD_SH, GOLD_HI, GOLD_LINE, WAX, WAX_SH, WAX_LINE, FLAME, FLAME_CORE, FLAME_MID,
                    svg, svg64, paint, line, dot, flame, flame_d, glow, spec, sparkle, star4, mix, IN)
from props import rrect, arch_d, candle_parts, flame_outline

LEAD, LEAD_SH, LEAD_LINE, LEAD_HI = '#2a2434', '#1a1420', '#0c0810', '#5a5270'
MARBLE, MARBLE_SH, MARBLE_HI, MARBLE_LINE = '#8c84a4', '#5e5876', '#c8c0e0', '#16121e'
PANES = ['#c83a5a', '#3a6ac8', '#e0a830', '#4aa86a']
PRISM = '#f8f0ff'
CLOTH, CLOTH_SH, CLOTH_LINE = '#8a3a6a', '#5a2448', '#1c0a16'


def _pts(pts):
    return 'M' + ' L'.join('%.2f %.2f' % p for p in pts) + ' Z'


# ================================================================ pennants

def _pennant_shape(state):
    """The cloth's outline for a state: its hoist on the pole at x 8 from y 6
    to 20, its fly to the right (full), angled down (lift), hanging (slack)."""
    if state == 'full':
        return ('M8.6 6 C20 3.6 34 7.4 46 5 C51 4 56 5.4 60 6.2 L52.4 12.6 L60 19.2 C54 19.6 48 18 42 19.6 '
                'C30 22.4 18 18.6 8.6 20 Z')
    if state == 'lift':
        return ('M8.6 6 C17 7.4 26 12 34 18.4 C38 21.6 42 26 44.6 30.4 L36.8 31 L38.8 40.4 C33.6 37.4 28.6 33.4 23.8 30 '
                'C18.4 26.6 13 24 8.6 20 Z')
    return ('M8.6 6 C12.4 11 14.6 20 14.4 30 C14.2 38 15.6 46 17.8 54 L12.4 50.2 L9.6 57.8 C9 50 8.4 40 8.6 30 Z')


def pennant_svg(state):
    ctx = Ctx('pn' + state[0])
    pal = dict(line=CLOTH_LINE, rim=RIM, base=CLOTH, shade=CLOTH_SH)
    P = []
    # the pole (a slim gold rod with a finial), hung from its top at (8, 2)
    P.append(Part('limb', pth('M8 2.4 L8 44'), width=2.2, fill=GOLD, line=GOLD_LINE,
                  over=line('M7.4 4 L7.4 42', GOLD_HI, 0.7, op=0.9)))
    P.append(Part('fill', ell(8, 2.6, 2.6, 2.4), fill=GOLD, shade=GOLD_SH, off=(-0.6, -0.6), line=GOLD_LINE,
                  hl=dot(7.2, 1.8, 0.7, GOLD_HI)))
    d = _pennant_shape(state)
    # the hem stripe and a little gold bell on the cloth
    if state == 'full':
        hem = line('M10 16.6 C22 15 34 18.6 44 16.6 C49 15.8 53 16.6 57 17.4', GOLD, 1.6)
        bell_at = (24, 12.4)
    elif state == 'lift':
        hem = line('M10.4 17.6 C16 21 24 26.8 31 33 C33 35 35 37 36.4 38.4', GOLD, 1.6)
        bell_at = (20, 18)
    else:
        hem = line('M10.2 16 C11.6 26 11.2 38 12.4 48', GOLD, 1.4)
        bell_at = (11.4, 22)
    bx, by = bell_at
    emblem = ('<path d="M%.1f %.1f Q%.1f %.1f %.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f Z" fill="%s" '
              'stroke="%s" stroke-width="0.7"/>' % (bx - 2, by + 2, bx - 2, by - 3, bx, by - 3.4, bx + 0.1, by - 3.4,
                                                     bx + 2.6, by + 2, bx - 2, by + 2, bx, by - 3.4, bx, by - 3.4,
                                                     GOLD, GOLD_LINE))
    emblem += dot(bx + 0.3, by + 3, 0.8, GOLD)
    P.append(Part('fill', pth(d), off=(-1.2, -1.8), over=hem + emblem,
                  hl=spec(bx + 6, by - 2, 3, 1.2, rot=-10, op=0.35)))
    return svg64(ctx, paint(ctx, P, pal))


# ================================================================ glass cracks

CRACK_ARMS = {
    1: [[(30, 8), (24, 20), (20, 34)], [(30, 8), (38, 22), (42, 30)], [(30, 8), (31, 18)]],
    2: [[(30, 8), (24, 20), (20, 34), (14, 42)], [(30, 8), (38, 22), (42, 30), (50, 40)], [(30, 8), (31, 18), (28, 30)],
        [(30, 8), (16, 12), (8, 14)], [(30, 8), (46, 12), (56, 20)], [(24, 20), (16, 24)], [(38, 22), (48, 22)]],
    3: [[(30, 8), (24, 20), (20, 34), (14, 42), (10, 56)], [(30, 8), (38, 22), (42, 30), (50, 40), (54, 56)],
        [(30, 8), (31, 18), (28, 30), (30, 46), (26, 58)], [(30, 8), (16, 12), (8, 14)], [(30, 8), (46, 12), (56, 20)],
        [(24, 20), (16, 24), (6, 30)], [(38, 22), (48, 22), (58, 30)], [(20, 34), (30, 36), (42, 30)],
        [(14, 42), (26, 46), (40, 44), (50, 40)]],
}


def glass_crack_svg(stage):
    """The crack web for a strain stage: a white core (3 units = 1.5 px) on
    a dark edge, from the impact near the top."""
    ctx = Ctx('gc%d' % stage)
    s = ''
    arms = CRACK_ARMS[stage]
    for a in arms:
        d = 'M' + ' L'.join('%.1f %.1f' % p for p in a)
        s += line(d, '#140c1c', 6.4, op=0.7)
    for a in arms:
        d = 'M' + ' L'.join('%.1f %.1f' % p for p in a)
        s += line(d, '#ffffff', 3.0)
    s += dot(30, 8, 3.6, '#ffffff') + dot(30, 8, 1.6, PRISM)
    if stage >= 2:
        s += sparkle(46, 12, 3.4, '#140c1c', '#ffffff')
    if stage >= 3:
        # chips already knocked out of the web
        for x, y in ((22, 28), (40, 36), (32, 50)):
            s += '<path d="M%.1f %.1f l3.4 1.2 l-1.4 3 Z" fill="#ffffff" opacity="0.9"/>' % (x, y)
    return svg64(ctx, s)


# ================================================================ the prism lamp (W5's lantern post)

def prism_lamp_svg(lit):
    """A crystal lantern on a slim gold post (64 x 96, foot on 96): the post,
    a gilded cap, a six-sided white crystal (a modulate colours it). Lit, the
    crystal glows and a flame stands in it; out, it is dark glass."""
    ctx = Ctx('pl' + ('l' if lit else 'o'))
    pal = dict(line=GOLD_LINE, rim=RIM, base=GOLD, shade=GOLD_SH)
    P = []
    P.append(Part('fill', pth('M22.4 95.4 L41.6 95.4 L38.4 89.6 L25.6 89.6 Z'), fill=MARBLE, shade=MARBLE_SH, off=(-1.2, -1),
                  line=MARBLE_LINE, over=line('M25.4 90.8 L38.6 90.8', MARBLE_HI, 0.8, op=0.9)))
    P.append(Part('limb', pth('M32 90 L32 44'), width=2.8, fill=GOLD, line=GOLD_LINE,
                  over=line('M31.2 88 L31.2 46', GOLD_HI, 0.7, op=0.9)))
    for y in (60, 76):
        P.append(Part('fill', ell(32, y, 3.4, 1.6), off=(-0.6, -0.6)))
    # the crystal: a tall hexagon, faceted
    crystal = _pts([(32, 13.4), (40.4, 19.6), (40.4, 36.2), (32, 42.4), (23.6, 36.2), (23.6, 19.6)])
    if lit:
        cg = ctx.lingrad([(0, '#ffffff'), (0.5, '#fff6e0'), (1, '#f0e0ff')])
        inner = flame(ctx, 32, 35.6, 6.8, 12.6, lean=0.4, halo=False, lcol='#5a1e0c')
        inner += line('M32 36.4 L32 33.6', '#241a14', 1.0)
    else:
        cg = ctx.lingrad([(0, '#5a5670'), (1, '#2a2638')])
        inner = line('M32 37 Q31.6 35 32.2 33.6', '#241a14', 1.1)
    facets = (line('M32 13.4 L32 42.4', '#ffffff' if lit else '#8a86a0', 0.7, op=0.6)
              + line('M23.6 19.6 L32 24.6 L40.4 19.6', '#ffffff' if lit else '#8a86a0', 0.7, op=0.5)
              + line('M23.6 36.2 L32 31 L40.4 36.2', '#ffffff' if lit else '#8a86a0', 0.6, op=0.35))
    P.append(Part('fill', pth(crystal), fill=cg, shade=cg, no_shade=True, line=LEAD_LINE, lw=1.1, over=inner + facets))
    # the gold cap and the cup it sits in
    P.append(Part('fill', pth('M22.4 40.6 L41.6 40.6 L38.6 45 L25.4 45 Z'), off=(-1, -1), over=line('M24.4 41.6 L39.6 41.6', GOLD_HI, 0.8)))
    P.append(Part('fill', pth('M24 15.4 L40 15.4 L35 8.6 L29 8.6 Z'), off=(-1, -1), over=line('M26 14.4 L38 14.4', GOLD_HI, 0.8)))
    P.append(Part('fill', ell(32, 6.8, 2.2, 2.2), off=(-0.5, -0.5), hl=dot(31.3, 6.1, 0.7, GOLD_HI)))
    under, over = '', ''
    if lit:
        halo = ctx.radgrad([(0, '#ffffff', 0.55), (0.5, '#fff0d8', 0.2), (1, '#fff0d8', 0)])
        under = '<ellipse cx="32" cy="28" rx="28" ry="27" fill="%s"/>' % halo
        over = sparkle(46, 18, 2.6, LEAD_LINE, '#ffffff') + star4(18, 32, 1.4, '#ffffff', 0.9)
    return svg(ctx, under + paint(ctx, P, pal) + over, 64, 96)


# ================================================================ the window seal (the arena door)

def window_seal_svg(closed):
    """The Saint's arena door (128 x 192, the two-by-three doorway): a lead
    lancet in a marble frame. Open, it is an empty window; closed, it is
    filled with shards (the door sealed behind you)."""
    ctx = Ctx('ws' + ('c' if closed else 'o'))
    pal = dict(line=MARBLE_LINE, rim=RIM, base=MARBLE, shade=MARBLE_SH)
    P = []
    frame = ('M10 192 L10 58 C10 28 38 8 64 4 C90 8 118 28 118 58 L118 192 L100 192 L100 62 C100 40 84 24 64 20 '
             'C44 24 28 40 28 62 L28 192 Z')
    P.append(Part('fill', pth(frame), off=(-2.4, -2.2), over=line('M14 188 L14 60 C14 34 40 13 64 9', MARBLE_HI, 1.4, op=0.8)
                  + line('M10 150 L28 150 M100 150 L118 150 M10 110 L28 110 M100 110 L118 110', MARBLE_LINE, 1.2, op=0.6)))
    # gold on the keystone and the springers
    P.append(Part('fill', pth('M56 3.6 L72 3.6 L69 16 L59 16 Z'), fill=GOLD, shade=GOLD_SH, off=(-1, -1), line=GOLD_LINE))
    for x in (19, 109):
        P.append(Part('fill', rrect(x - 9, 58, x + 9, 64, 1.2), fill=GOLD, shade=GOLD_SH, off=(-0.8, -0.8), line=GOLD_LINE))
    inner = 'M28 192 L28 62 C28 40 44 24 64 20 C84 24 100 40 100 62 L100 192 Z'
    if closed:
        s = ''
        # the shards, set in lead: a mosaic, a colour per shard
        cells = []
        rows = [62, 88, 114, 140, 166, 192]
        for r in range(len(rows) - 1):
            y0, y1 = rows[r], rows[r + 1]
            xs = [28, 46, 64, 82, 100] if r % 2 == 0 else [28, 40, 58, 76, 88, 100]
            for c in range(len(xs) - 1):
                cells.append((xs[c], y0, xs[c + 1], y1, (r * 3 + c) % 4))
        clip = ctx.clip('<path d="%s"/>' % inner)
        s += '<g clip-path="%s">' % clip
        s += '<path d="%s" fill="%s"/>' % (inner, LEAD_SH)
        for x0, y0, x1, y1, k in cells:
            col = PANES[k]
            s += '<path d="M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z" fill="%s" stroke="%s" stroke-width="3"/>' % (
                x0 + 1, y0 + 2, x1 - 1, y0 + 1, x1 - 2, y1 - 1, x0 + 2, y1 - 2, col, LEAD_LINE)
            s += '<path d="M%.1f %.1f L%.1f %.1f L%.1f %.1f Z" fill="#ffffff" opacity="0.25"/>' % (x0 + 4, y1 - 5, x0 + 8, y1 - 5, x1 - 4, y0 + 5)
        # the top: a rosette of shards
        for k in range(6):
            a = math.pi + k * math.pi / 5
            cx, cy = 64 + math.cos(a) * 20, 52 + math.sin(a) * 18
            s += '<ellipse cx="%.1f" cy="%.1f" rx="7" ry="6" fill="%s" stroke="%s" stroke-width="2.4"/>' % (cx, cy, PANES[k % 4], LEAD_LINE)
        s += '</g>'
        s += '<path d="%s" fill="none" stroke="%s" stroke-width="3.4"/>' % (inner, LEAD_LINE)
        s += sparkle(84, 96, 4, LEAD_LINE, '#ffffff')
        over = s
    else:
        # an empty window: the dark beyond, a few lead stubs where glass was
        over = ('<path d="%s" fill="#0a0812" opacity="0.35"/>' % inner
                + line('M28 120 L36 118 M100 100 L92 104 M28 70 L34 74', LEAD, 3.0)
                + '<path d="M36 118 L42 113 L40 121 Z" fill="%s" opacity="0.8"/>' % PANES[1])
    return svg(ctx, paint(ctx, P, pal) + over, 128, 192)


# ================================================================ the altar

def altar_glass_svg(lit):
    """The W5 altar (64 x 96, v2's frame, wick tip (32, 22)): a marble altar
    floating a little over the floor, gold at its edges, the candle in a
    cup of cobalt glass; a faint light under it holds it up."""
    ctx = Ctx('ag' + ('l' if lit else 'u'))
    if lit:
        stone, stone_sh, stone_hi = '#a49cc0', '#6e6890', '#d8d0f0'
        trim, trim_sh = '#ffd65a', '#c8901e'
    else:
        stone, stone_sh, stone_hi = MARBLE, MARBLE_SH, '#b0a8cc'
        trim, trim_sh = '#b89a50', '#7a6434'
    L = MARBLE_LINE
    pal = dict(line=L, rim=RIM, base=stone, shade=stone_sh)
    P = []
    # it floats: its foot is a broken point, 5 units off the floor
    P.append(Part('fill', pth('M16 84 L48 84 L40 90.4 L32 91.4 L24 90.2 Z'), off=(-1.6, -1.4),
                  over=line('M22 86 L28 88.4 M36 86 L40 88', L, 0.8, op=0.5)))
    niche = arch_d(22.6, 41.4, 61.4, 81.6)
    body_over = ('<path d="%s" fill="%s" stroke="%s" stroke-width="1.3"/>' % (niche, '#140e20', L)
                 + line('M12 80.6 L12 60.6 L52 60.6', stone_hi, 1, op=0.8))
    # a quatrefoil in the niche, glass in it
    for dx, dy in ((0, -4), (4, 0), (0, 4), (-4, 0)):
        body_over += '<circle cx="%.1f" cy="%.1f" r="3.2" fill="%s" stroke="%s" stroke-width="0.9"/>' % (
            32 + dx, 71 + dy, PANES[1] if lit else '#2a3a60', L)
    if lit:
        glow_g = ctx.radgrad([(0, '#ffc85a', 0.8), (0.6, '#ffb040', 0.25), (1, '#ffb040', 0)])
        body_over += '<g clip-path="%s"><ellipse cx="32" cy="72" rx="12" ry="12" fill="%s"/></g>' % (
            ctx.clip('<path d="%s"/>' % niche), glow_g)
    P.append(Part('fill', rrect(10, 58, 54, 84.6, 1.2), off=(-2.6, -2.2), over=body_over))
    P.append(Part('fill', rrect(5, 51.6, 59, 58.6, 1.8), off=(-1.8, -1.6),
                  over=line('M7 55.6 L57 55.6', trim, 2, cap='butt') + line('M7 56.8 L57 56.8', trim_sh, 0.7)
                  + ''.join(dot(x, 55.6, 0.8, '#fff6d0' if lit else '#c8b484') for x in (10, 20, 32, 44, 54))
                  + line('M7 53 L57 53', stone_hi, 0.9, op=0.8)))
    # the glass cup: cobalt panes in gold
    cup = 'M23.4 44.6 L40.6 44.6 L38.6 51.8 L25.4 51.8 Z'
    cupg = ctx.lingrad([(0, '#6a9ae8' if lit else '#3a4a78'), (1, '#2a4aa0' if lit else '#1e2848')])
    P.append(Part('fill', pth(cup), fill=cupg, shade=cupg, no_shade=True, line=GOLD_LINE, lw=1.2,
                  over=line('M28 45 L27.4 51.4 M32 45 L32 51.4 M36 45 L36.6 51.4', trim, 0.9)
                  + line('M23.4 44.8 L40.6 44.8', trim, 1.3)))
    parts, wick = candle_parts(27.4, 36.6, 25.4, 45, 22, drips=((0.2, 5), (0.58, 8), (0.85, 3.4)))
    P += parts
    under = ''
    lift = ctx.radgrad([(0, '#e8e0ff', 0.35 if lit else 0.2), (1, '#e8e0ff', 0)])
    under += '<ellipse cx="32" cy="93" rx="20" ry="4" fill="%s"/>' % lift
    if lit:
        warm = ctx.radgrad([(0, '#ffb44a', 0.45), (0.5, '#ff9a3a', 0.16), (1, '#ff9a3a', 0)])
        under += '<ellipse cx="32" cy="44" rx="31" ry="42" fill="%s"/>' % warm
    over = ''
    if lit:
        over = sparkle(52, 38, 3.2, L, '#fff2c8') + star4(11, 44, 1.8, '#fff2c8', 0.9)
    return svg(ctx, under + paint(ctx, P, pal) + wick + over, 64, 96)


# ================================================================ the bell and its beam

def bell_glass_beam_svg():
    ctx = Ctx('gbm')
    pal = dict(line=MARBLE_LINE, rim=RIM, base=MARBLE, shade=MARBLE_SH)
    P = [Part('fill', rrect(6, 7.6, 122, 20.2, 2.4), off=(-2, -2.4),
              over=line('M9 16.6 L119 16.6', GOLD, 1.4) + line('M20 11 L24 14 M88 10.4 L92 13', MARBLE_SH, 0.9, op=0.8),
              hl=line('M9 9.6 L119 9.6', MARBLE_HI, 1.1, op=0.9))]
    for x in (22, 106):
        P.append(Part('fill', rrect(x - 3, 6.4, x + 3, 21.4, 1), fill=GOLD, shade=GOLD_SH, off=(-1, -1), line=GOLD_LINE,
                      over=dot(x, 10, 0.9, GOLD_HI) + dot(x, 17.6, 0.9, GOLD_HI)))
    P.append(Part('fill', rrect(57, 14.6, 71, 22.6, 1.6), fill=GOLD, shade=GOLD_SH, off=(-1, -1), line=GOLD_LINE,
                  over=dot(60.4, 18.4, 1, GOLD_HI) + dot(67.6, 18.4, 1, GOLD_HI)))
    return svg(ctx, paint(ctx, P, pal), 128, 192)


BELL_BODY = ('M50 30 C54 26.6 74 26.6 78 30 C84.4 35 85.4 46 86.6 60 C88 76 94 88 106 96.6 C109 98.8 108 102.4 104 102.4 '
             'L24 102.4 C20 102.4 19 98.8 22 96.6 C34 88 40 76 41.4 60 C42.6 46 43.6 35 50 30 Z')


def bell_glass_svg():
    """The W5 bell (128 x 192, v2's frame): a bell of leaded panes, jewel
    colours in black lead, its gold rim and crown kept."""
    ctx = Ctx('gbl')
    pal = dict(line=LEAD_LINE, rim=RIM, base=GOLD, shade=GOLD_SH)
    P = []
    ROPE, ROPE_SH = '#c8a060', '#8a6630'
    rope_d = 'M64 108 C64.6 130 63.2 152 64 176'
    twist = ''.join('M%.1f %.1f l3.6 -2.4 ' % (62.2 + (0.3 if i % 2 else -0.2), y) for i, y in enumerate(range(114, 176, 5)))
    P.append(Part('limb', pth(rope_d), width=4.6, fill=ROPE, line='#2a1a08', over=line(twist, ROPE_SH, 1.0)))
    P.append(Part('fill', pth('M60.8 176 L67.2 176 L68.4 180 L69.6 189.4 L66.8 187 L65.2 190 L63.4 187 L61.2 190 '
                              'L60.4 186.6 L58.4 189.4 L59.6 180 Z'), fill=ROPE, shade=ROPE_SH, off=(-1, -1), line='#2a1a08',
                  over=line('M60.4 178.6 L67.6 178.6', '#3a6ac8', 2.2, cap='butt')))
    P.append(Part('fill', ell(64, 104.6, 6, 5.6), fill='#5a4a40', shade='#3a2e28', off=(-1.2, -1.4), line=LEAD_LINE))
    P.append(Part('fill', pth('M58.4 29.6 L58.4 24.6 C58.4 17.6 69.6 17.6 69.6 24.6 L69.6 29.6 L66 29.6 L66 25 '
                              'C66 22.4 62 22.4 62 25 L62 29.6 Z'), off=(-1, -1.2), line=GOLD_LINE))
    # the panes: clipped to the bell, a mosaic of four colours in lead
    clip = ctx.clip('<path d="%s"/>' % BELL_BODY)
    panes = '<g clip-path="%s">' % clip
    panes += '<path d="%s" fill="%s"/>' % (BELL_BODY, LEAD_SH)
    rows = [26, 42, 58, 74, 90, 104]
    for r in range(len(rows) - 1):
        y0, y1 = rows[r], rows[r + 1]
        n = 3 + r
        for c in range(n + 1):
            x0 = 16 + (c - (0.5 if r % 2 else 0)) * 96.0 / n
            x1 = x0 + 96.0 / n
            col = PANES[(r + c * 2) % 4]
            panes += '<path d="M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z" fill="%s" stroke="%s" stroke-width="2.6"/>' % (
                x0, y0, x1, y0, x1, y1, x0, y1, col, LEAD_LINE)
            panes += '<path d="M%.1f %.1f L%.1f %.1f L%.1f %.1f Z" fill="#ffffff" opacity="0.22"/>' % (
                x0 + 2.5, y1 - 3, x0 + 6, y1 - 3, x1 - 3, y0 + 3)
    panes += '</g>'
    # the gold rim along the mouth and a gold band at the shoulder
    bands = (line('M44.2 42.6 Q64 47 83.8 42.6', GOLD, 2.4) + line('M28.8 93.4 Q64 100 99.2 93.4', GOLD, 3.2)
             + line('M26 97 Q64 103.4 102 97', GOLD_HI, 1.2))
    hl = (spec(52, 60, 2.6, 16, rot=12, op=0.55) + line('M31 96.4 Q40 92 44 84', '#ffffff', 1.2, op=0.6))
    P.append(Part('fill', pth(BELL_BODY), fill=GOLD, shade=GOLD, no_shade=True, line=LEAD_LINE, over=panes + bands, hl=hl))
    P.append(Part('fill', ell(64, 102.2, 41.4, 4.2), fill='#1a1420', shade='#1a1420', no_shade=True, rim=False, sil=False, lw=1.2))
    P.append(Part('fill', ell(64, 104.6, 6, 5.6), fill='#5a4a40', shade='#3a2e28', off=(-1.2, -1.4), line=LEAD_LINE,
                  rim=False, sil=False, hl=dot(62, 102.6, 1.2, '#9a8a80')))
    return svg(ctx, paint(ctx, P, pal), 128, 192)


# ================================================================ the sconce

def sconce_glass_svg():
    """The W5 wall sconce (64 frame, wick tip (32, 14)): a gold bracket with a
    crystal drip pan."""
    ctx = Ctx('sg')
    pal = dict(line=GOLD_LINE, rim=RIM, base=GOLD, shade=GOLD_SH)
    P = []
    P.append(Part('fill', pth('M29.6 50 L34.4 50 L32 58.6 Z'), off=(-0.8, -0.8)))
    P.append(Part('limb', pth('M28.4 45.6 C20.4 44.6 19.4 37.6 24.4 36.2 C27.6 35.4 30.6 35.6 32 33.6'), width=2.4, fill=GOLD))
    P.append(Part('limb', pth('M35.6 45.6 C41.4 45 43.2 40.4 40.2 38.6'), width=1.8, fill=GOLD))
    P.append(Part('limb', pth('M32 41 L32 33.4'), width=2.2, fill=GOLD))
    P.append(Part('fill', ell(32, 46, 5, 5), fill=GOLD, shade=GOLD_SH, off=(-1.2, -1.4),
                  over=dot(32, 46, 2.2, PANES[1]) + dot(31.3, 45.3, 0.8, '#ffffff')))
    pan = ctx.lingrad([(0, '#ffffff'), (1, '#c8c0f0')])
    P.append(Part('fill', pth('M21.6 30.2 L42.4 30.2 Q41.6 34 37 34.4 L27 34.4 Q22.4 34 21.6 30.2 Z'), fill=pan, shade=pan,
                  no_shade=True, line=LEAD_LINE, lw=1.1, over=line('M23.4 31.2 L40.6 31.2', '#ffffff', 0.9, op=0.9)))
    parts, wick = candle_parts(28.2, 35.8, 17.4, 30.6, 14, drips=((0.25, 3.6), (0.7, 6)))
    P += parts
    return svg64(ctx, paint(ctx, P, pal) + wick)


# ================================================================ points

POINTS = {
    'pennant_slack': {'hang': (8, 2)}, 'pennant_lift': {'hang': (8, 2)}, 'pennant_full': {'hang': (8, 2)},
    'prism_lamp_lit': {'foot': (32, 96), 'flame': (32, 30)}, 'prism_lamp_out': {'foot': (32, 96), 'flame': (32, 30)},
    'altar_glass': {'foot': (32, 96), 'flame': (32, 22)}, 'altar_glass_lit': {'foot': (32, 96), 'flame': (32, 22)},
    'bell_glass': {'hang': (64, 20), 'rope': [58, 108, 12, 82]}, 'bell_glass_beam': {'hang': (64, 20)},
    'sconce_glass': {'flame': (32, 14)},
    'window_seal_open': {'cells': [2, 3]}, 'window_seal_closed': {'cells': [2, 3]},
    'glass_crack1': {'impact': (30, 8)}, 'glass_crack2': {'impact': (30, 8)}, 'glass_crack3': {'impact': (30, 8)},
}


def points_json():
    import json
    doc = {'_doc': 'A2 World 5 props. Frame units, 2 units = 1 world px (sprites drawn at scale 0.25). pennant_*: 64 x 64, '
                   'hung from "hang" (a pole top), blowing right (mirror for left). prism_lamp_* and altar_glass*: 64 x 96, '
                   '"foot" on the floor, "flame" where the light (and a live flame) goes, as v2\'s lantern_post and altar. '
                   'bell_glass*: 128 x 192 hung from (64, 20), v2\'s bell; rope = [x, y, w, h]. sconce_glass: 64 x 64, '
                   'wick tip "flame". window_seal_*: 128 x 192 over the two-by-three doorway boss_arena.gd seals. '
                   'glass_crack*: 64 x 64 overlays for a pane cell (stage 1 at strain 0.4, 2 at 0.8, 3 as it flashes).'}
    doc.update({k: {n: (list(p) if isinstance(p, tuple) else p) for n, p in v.items()} for k, v in POINTS.items()})
    return json.dumps(doc, indent=1, sort_keys=True) + '\n'


def files():
    out = {}
    for st in ('slack', 'lift', 'full'):
        out['art/props/pennant_%s.svg' % st] = pennant_svg(st)
    for k in (1, 2, 3):
        out['art/props/glass_crack%d.svg' % k] = glass_crack_svg(k)
    out['art/props/prism_lamp_lit.svg'] = prism_lamp_svg(True)
    out['art/props/prism_lamp_out.svg'] = prism_lamp_svg(False)
    out['art/props/window_seal_open.svg'] = window_seal_svg(False)
    out['art/props/window_seal_closed.svg'] = window_seal_svg(True)
    out['art/props/altar_glass.svg'] = altar_glass_svg(False)
    out['art/props/altar_glass_lit.svg'] = altar_glass_svg(True)
    out['art/props/bell_glass.svg'] = bell_glass_svg()
    out['art/props/bell_glass_beam.svg'] = bell_glass_beam_svg()
    out['art/props/sconce_glass.svg'] = sconce_glass_svg()
    out['art/props/points_w5.json'] = points_json()
    return out


def build(write):
    for rel, text in files().items():
        write(rel, text)
