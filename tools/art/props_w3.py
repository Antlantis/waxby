"""World 3 props, the Bone Orchard (A1): the vine's knot, spore pods,
glowfruit, the skull lantern (W3's `L`), the arena's root seal, the orchard
altar, bell and bone sconce, and points_w3.json (where the engine draws on
them).

Frames (2 units = 1 world px, width = 2 x viewBox, sprite scale 0.25):
  64 x 64   vine_top (hangs from the tile top, the stem leaves at (32, 64)),
            spore_pod_closed/_swell/_burst (stand on y 64),
            spore_pod_hang_closed/_swell/_burst (hang from y 0),
            glowfruit_hang (hangs from y 0), glowfruit_lit / glowfruit_dim
            (lie on y 64), sconce_bone (wick tip (32, 14), as v2's sconce)
  64 x 96   skull_lantern_lit/_out (stand on y 96; the flame and light at
            (32, 30), as v2's lantern post), altar_orchard/_lit (stand on
            y 96; wick tip (32, 22), as v2's altar)
  128 x 192 bell_orchard (hangs from (64, 20), as v2's bell), bell_orchard_beam,
            root_seal_open/_closed (the arena door: 2 tiles x 3 tiles, its
            top-left on the door's top-left cell)
The tell accent (spore chartreuse c8d46a) is used only on the pods' swell
and burst (spec 11.1: decoration never uses it).
"""
import json
import math

import kit
from kit import Part, ell, pth, shp
from common import (Ctx, RIM, FLAME, FLAME_MID, FLAME_CORE, svg, svg64, paint, line, dot, flame, flame_d, glow, spec,
                    sparkle, star4, mix)
from props import candle_parts, rrect, arch_d, flame_outline

# ---------------------------------------------------------------- the orchard's colours (p_artaudio 4.1)
BONE, BONE_SH, BONE_HI, BONE_LINE = '#e6dcc0', '#b8ab8a', '#fff8e4', '#3a2c1e'
ROOT, ROOT_SH, ROOT_HI, ROOT_LINE = '#4a3526', '#34241a', '#6e4e36', '#140c06'
LEAF, LEAF_SH, LEAF_HI = '#6e8a44', '#4e6630', '#9ab86a'
THORN = '#5a3a2a'
SPORE, SPORE_HI = '#c8d46a', '#e8f08a'          # the tell accent: the pods' swell and burst only
PUFF, PUFF_SH, PUFF_HI, PUFF_LINE = '#e2d8b8', '#b8ac88', '#fbf4dc', '#3a3020'
GILL = '#5a4a36'
BLOSSOM, BLOSSOM_HI = '#e8a0b0', '#f8dce4'
GRAVE, GRAVE_SH, GRAVE_HI, GRAVE_LINE = '#7a7664', '#56534a', '#a09c86', '#16140e'
MOSS, MOSS_HI = '#6e8a44', '#9ab86a'
BRONZE, BRONZE_SH, BRONZE_HI, BRONZE_LINE = '#c8903e', '#8a5a24', '#f6d48a', '#2a1406'
GOURD, GOURD_SH, GOURD_HI, GOURD_LINE = '#ffe6a8', '#f0b860', '#fff8e0', '#5a3410'


def _pal(line_c, base, shade):
    return dict(line=line_c, rim=RIM, base=base, shade=shade)


def leaf_d(x, y, ang, ln=7.0, w=3.2):
    """A pointed leaf from (x, y), pointing at ang degrees."""
    a = math.radians(ang)
    dx, dy = math.cos(a), math.sin(a)
    nx, ny = -dy, dx
    tx, ty = x + dx * ln, y + dy * ln
    mx, my = x + dx * ln * 0.45, y + dy * ln * 0.45
    return 'M%.2f %.2f Q%.2f %.2f %.2f %.2f Q%.2f %.2f %.2f %.2f Z' % (
        x, y, mx + nx * w, my + ny * w, tx, ty, mx - nx * w, my - ny * w, x, y)


def leaf_part(x, y, ang, ln=7.0, w=3.2, fill=LEAF):
    return Part('fill', pth(leaf_d(x, y, ang, ln, w)), fill=fill, shade=LEAF_SH, off=(-0.6, -0.8), line=ROOT_LINE, lw=0.9,
                over=line('M%.2f %.2f L%.2f %.2f' % (x, y, x + math.cos(math.radians(ang)) * ln * 0.8,
                                                   y + math.sin(math.radians(ang)) * ln * 0.8), LEAF_HI, 0.7, op=0.9))


def blossom(x, y, r=2.6, col=BLOSSOM):
    """A five-petal blossom, flat (no outline pass: small)."""
    s = ''
    for k in range(5):
        a = math.radians(-90 + k * 72)
        s += '<ellipse cx="%.2f" cy="%.2f" rx="%.2f" ry="%.2f" fill="%s" stroke="%s" stroke-width="0.6" transform="rotate(%.1f %.2f %.2f)"/>' % (
            x + math.cos(a) * r * 0.7, y + math.sin(a) * r * 0.7, r * 0.62, r * 0.42, col, ROOT_LINE, k * 72, x + math.cos(a) * r * 0.7,
            y + math.sin(a) * r * 0.7)
    return s + dot(x, y, r * 0.35, '#fff2c8')


# ================================================================ the vine's knot

def vine_top_svg():
    """The root knot a vine hangs from (the tile top is the frame's top); its
    stem leaves at (32, 64)."""
    ctx = Ctx('vt')
    pal = _pal(ROOT_LINE, ROOT, ROOT_SH)
    P = []
    # roots splayed along the ceiling
    P.append(Part('fill', pth('M1 0 L63 0 L62 3.4 Q54 7.4 46 6 Q40 9.6 37.4 14 L26.6 14 Q24 9.6 18 6 Q10 7.4 2 3.4 Z'),
                  off=(-1, -1.4), over=line('M6 2.6 Q14 5 20 4.4 M44 4.4 Q50 5 58 2.6', ROOT_HI, 1, op=0.9)))
    for d in ('M10 4 Q8 10 11 15', 'M53 4 Q56 9 53 14'):
        P.append(Part('limb', pth(d), width=1.6, fill=ROOT))
    # the stem, down to the frame's foot
    P.append(Part('limb', pth('M32 16 Q30.6 30 32.4 42 Q33.6 52 32 64'), width=5.4, fill=ROOT,
                  over=line('M30.6 20 Q29.4 32 31 44', ROOT_HI, 1.1, op=0.9)))
    # the knot
    P.append(Part('fill', ell(32, 15, 9.6, 7), off=(-1.4, -1.4),
                  over=line('M25 14 Q32 10.6 39 14 M26.6 17.4 Q32 20 37.6 17', ROOT_LINE, 0.9, op=0.7),
                  hl=spec(27.6, 11.8, 2.4, 1.1, rot=-15, op=0.35)))
    P += [leaf_part(32.4, 30, -30, 9, 3.6), leaf_part(31.6, 40, 205, 8.4, 3.4), leaf_part(32.6, 52, -25, 8, 3.2)]
    return svg64(ctx, paint(ctx, P, pal))


# ================================================================ spore pods

def _pod_parts(ctx, state, hang):
    """A pale puffball with dark gills under its cap and a moss collar where it
    grows from. The body's centre is (32, cy); hang puts the collar on top."""
    P = []
    over = ''
    if state == 'burst':
        # the torn, flattened skin
        if hang:
            skin = 'M17 8 Q20 3 32 3 Q44 3 47 8 Q44 16 40 13 Q37 20 33 15 Q29 21 26 14 Q21 17 17 8 Z'
        else:
            skin = 'M17 58 Q20 63 32 63 Q44 63 47 58 Q44 50 40 53 Q37 46 33 51 Q29 45 26 52 Q21 49 17 58 Z'
        P.append(Part('fill', pth(skin), fill=PUFF_SH, shade=mix(PUFF_SH, '#000000', 0.25), off=(-1, -1), line=PUFF_LINE, lw=1.1))
        return P, over
    big = state == 'swell'
    rx, ry = (21.5, 18.5) if big else (18.6, 15.4)
    cy = (8 + ry + 3.6) if hang else (60 - ry - 1.6)
    # the collar of moss it grows from
    if hang:
        P.append(Part('fill', pth('M20 0 L44 0 L43 5 Q38 9.4 32 8.6 Q26 9.4 21 5 Z'), fill=MOSS, shade=LEAF_SH, off=(-0.8, -1),
                      line=ROOT_LINE, lw=1, over=line('M23 3 L25 6.6 M29 3.6 L30 8 M35 3.6 L34.4 8 M41 3 L39.4 6.4', LEAF_HI, 0.8)))
        P.append(Part('limb', pth('M32 7 L32 %.1f' % (cy - ry + 2)), width=3.6, fill=PUFF_SH))
    else:
        P.append(Part('fill', pth('M14 64 L50 64 Q49 58 44 56.6 Q38 54 32 54.6 Q26 54 20 56.6 Q15 58 14 64 Z'), fill=MOSS, shade=LEAF_SH,
                      off=(-0.8, -1), line=ROOT_LINE, lw=1,
                      over=line('M18 62 L20 58 M24 62.4 L25 57 M31 62.6 L31.6 56 M38 62.4 L38 57 M44 62 L43 58', LEAF_HI, 0.8)))
    body = ell(32, cy, rx, ry)
    # the gills: the ball's underside in a soft dark band that fades in from
    # its waist (a gradient clipped to the ball; no line and no ticks, which
    # read as a sewn mouth at game scale)
    gy = cy + ry * 0.30 if not hang else cy + ry * 0.34
    band = SPORE if big else GILL      # the swell's vents glow through it: the tell
    fade = ctx.lingrad([(0, band, 0), (0.45, band, 0.55 if big else 0.5), (1, band, 0.4 if big else 0.34)], x1=0, y1=gy - 3.0, x2=0,
                       y2=cy + ry, units='userSpaceOnUse')
    g = '<g clip-path="%s"><rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="%s"/></g>' % (
        ctx.clip(shp(body)), 32 - rx - 1, gy - 3.0, rx * 2 + 2, cy + ry - gy + 4.0, fade)
    # pale warts on the cap
    warts = ''
    for dx, dy, r in ((-7, -7, 2.2), (4, -9.4, 1.8), (10, -3.6, 1.6), (-12, 0, 1.4), (1, -2, 1.3)):
        warts += dot(32 + dx * rx / 18.6, cy + dy * ry / 15.4 * (-1 if hang else 1), r, PUFF_HI, 0.95)
    col_line = PUFF_LINE
    if big:
        # the tell: it swells, its vents glow chartreuse and it quivers
        vent = ctx.radgrad([(0, SPORE_HI, 0.95), (0.55, SPORE, 0.55), (1, SPORE, 0)])
        g = '<ellipse cx="32" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s"/>' % (gy, rx * 0.8, ry * 0.45, vent) + g.replace(GILL, SPORE)
        top = cy - ry if not hang else cy + ry
        warts += '<ellipse cx="32" cy="%.1f" rx="4.4" ry="2.4" fill="%s" stroke="%s" stroke-width="1"/>' % (top + (1.6 if not hang else -1.6), SPORE_HI, col_line)
    P.append(Part('fill', body, fill=PUFF, shade=PUFF_SH, off=(-3, -2.6), line=col_line, over=g + warts,
                  hl=spec(32 - rx * 0.42, cy - ry * 0.5 if not hang else cy - ry * 0.2, rx * 0.2, ry * 0.14, rot=-25, op=0.85)))
    if big:
        # quiver lines either side, and a sparkle
        for s in (-1, 1):
            over += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (32 + s * (rx + 4), cy - 6, 32 + s * (rx + 6.6), cy, 32 + s * (rx + 4), cy + 6),
                         SPORE_HI, 1.4)
            over += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (32 + s * (rx + 8), cy - 4, 32 + s * (rx + 9.6), cy, 32 + s * (rx + 8), cy + 4),
                         SPORE, 1.1, op=0.8)
    return P, over


def spore_pod_svg(state, hang=False):
    ctx = Ctx('sp' + state[:2] + ('h' if hang else 'f'))
    P, over = _pod_parts(ctx, state, hang)
    under = ''
    if state == 'swell':
        halo = ctx.radgrad([(0, SPORE, 0.42), (0.6, SPORE, 0.12), (1, SPORE, 0)])
        cy = 30 if hang else 36
        under = '<ellipse cx="32" cy="%d" rx="31" ry="28" fill="%s"/>' % (cy, halo)
    if state == 'burst':
        # the puff going up (or down from a ceiling pod): a chartreuse cloud with motes
        puff = ctx.radgrad([(0, SPORE_HI, 0.7), (0.6, SPORE, 0.4), (1, SPORE, 0)])
        base = 22 if not hang else 42
        over += '<ellipse cx="32" cy="%d" rx="26" ry="20" fill="%s"/>' % (base, puff)
        for dx, dy, r in ((-14, -8, 5.4), (0, -12, 7), (13, -6, 5.8), (-6, 2, 4.6), (9, 4, 4)):
            yy = base + (dy if not hang else -dy)
            over += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s" stroke="%s" stroke-width="1" opacity="0.9"/>' % (
                32 + dx, yy, r, mix(SPORE, '#ffffff', 0.25), mix(SPORE, '#3a3020', 0.5))
        for dx, dy in ((-20, -16), (18, -18), (-4, -22), (22, 0), (-24, 2)):
            over += dot(32 + dx, base + (dy if not hang else -dy), 1.3, SPORE_HI, 0.95)
    pal = _pal(PUFF_LINE, PUFF, PUFF_SH)
    return svg64(ctx, under + paint(ctx, P, pal) + over)


# ================================================================ glowfruit

def _gourd(ctx, cx, cy, rx, ry, lit=True, lying=False):
    """A pale gourd with ribs, lit from inside."""
    if lying:
        d = ('M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z' % (
            cx - rx, cy + 1, cx - rx, cy - ry * 1.1, cx + rx * 0.2, cy - ry * 1.05, cx + rx * 0.62, cy - ry * 0.62,
            cx + rx * 1.05, cy - ry * 0.3, cx + rx * 1.02, cy + ry, cx + rx * 0.4, cy + ry,
            cx - rx * 0.2, cy + ry * 1.02, cx - rx, cy + ry * 0.9, cx - rx, cy + 1))
    else:
        d = ('M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f '
             'C%.1f %.1f %.1f %.1f %.1f %.1f Z' % (
                 cx, cy - ry,
                 cx + rx * 0.5, cy - ry, cx + rx * 0.42, cy - ry * 0.35, cx + rx * 0.92, cy + ry * 0.1,
                 cx + rx * 1.2, cy + ry * 0.45, cx + rx * 0.8, cy + ry, cx, cy + ry,
                 cx - rx * 0.8, cy + ry, cx - rx * 1.2, cy + ry * 0.45, cx - rx * 0.92, cy + ry * 0.1,
                 cx - rx * 0.42, cy - ry * 0.35, cx - rx * 0.5, cy - ry, cx, cy - ry))
    if lit:
        fill = ctx.radgrad([(0, '#fffbe8'), (0.5, GOURD), (1, GOURD_SH)], cx=0.45, cy=0.62, r=0.62)
    else:
        fill = ctx.radgrad([(0, '#c8b890'), (1, '#8a7c5c')], cx=0.45, cy=0.62, r=0.62)
    ribs = ''
    for k in (-0.5, 0, 0.5):
        if lying:
            ribs += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (cx - rx * 0.8, cy + k * ry * 0.9, cx, cy + k * ry * 1.3,
                                                            cx + rx * 0.8, cy + k * ry * 0.7), GOURD_SH if lit else '#6a5c40', 0.9, op=0.8)
        else:
            ribs += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (cx + k * rx * 0.3, cy - ry * 0.8, cx + k * rx * 1.25, cy + ry * 0.2,
                                                            cx + k * rx * 0.6, cy + ry * 0.92), GOURD_SH if lit else '#6a5c40', 0.9, op=0.8)
    return Part('fill', pth(d), fill=fill, shade=fill, no_shade=True, line=GOURD_LINE, lw=1.3, over=ribs,
                hl=spec(cx - rx * 0.4, cy - ry * 0.2, rx * 0.16, ry * 0.3, rot=15, op=0.8 if lit else 0.3))


def glowfruit_hang_svg():
    """Hanging (from the tile top: a root or a vine): the stalk, a leaf, the
    gourd lit from inside. Its light is the feature's (r 90, at (32, 38))."""
    ctx = Ctx('gh')
    pal = _pal(ROOT_LINE, ROOT, ROOT_SH)
    P = [Part('fill', pth('M24 0 L40 0 L38 3.4 Q32 5.6 26 3.4 Z'), off=(-0.6, -0.8)),
         Part('limb', pth('M32 3 Q34.4 9 32 16.6'), width=2.4, fill=ROOT_HI),
         leaf_part(33, 8, -20, 10, 3.8), leaf_part(31, 10, 200, 8, 3.2),
         _gourd(ctx, 32, 36.6, 12.4, 19.4)]
    halo = ctx.radgrad([(0, '#ffd88a', 0.55), (0.5, '#ffb44a', 0.18), (1, '#ffb44a', 0)])
    under = '<ellipse cx="32" cy="38" rx="31" ry="28" fill="%s"/>' % halo
    return svg64(ctx, under + paint(ctx, P, pal) + star4(47, 26, 2.2, '#fff6d8', 0.9))


def glowfruit_ground_svg(lit=True):
    """Fallen, lying on its side (bottom on y 64): lit (r 120, 30 s) or dim
    (the faint r 40 glow it keeps). Its light is the feature's, at (32, 50)."""
    ctx = Ctx('gl' + ('l' if lit else 'd'))
    pal = _pal(ROOT_LINE, ROOT, ROOT_SH)
    P = [Part('limb', pth('M45.4 44 Q50 40.6 52.4 42.6'), width=2.2, fill=ROOT_HI),
         leaf_part(50, 42, -60, 7, 2.8),
         _gourd(ctx, 31.4, 51.4, 16.6, 11.4, lit=lit, lying=True)]
    under = ''
    over = ''
    if lit:
        halo = ctx.radgrad([(0, '#ffd88a', 0.7), (0.5, '#ffb44a', 0.24), (1, '#ffb44a', 0)])
        under = '<ellipse cx="32" cy="48" rx="32" ry="24" fill="%s"/>' % halo
        # the split in its skin, bright
        over = line('M21 48.6 Q25 50.4 24.6 53.6', '#fffbe8', 1.2, op=0.9)
        over += sparkle(12, 40, 2.8, GOURD_LINE, '#fff6d8') + star4(54, 52, 1.6, '#fff6d8', 0.9)
    else:
        halo = ctx.radgrad([(0, '#ffc870', 0.25), (1, '#ffc870', 0)])
        under = '<ellipse cx="32" cy="51" rx="20" ry="12" fill="%s"/>' % halo
    return svg64(ctx, under + paint(ctx, P, pal) + over)


# ================================================================ the skull lantern (W3's L)

def skull_lantern_svg(lit):
    """A skull on a bone post (64 x 96, base on y 96): the candle burns in its
    cranium and the light comes out through its eyes. The flame (and the
    lantern's light) at (32, 30), as v2's lantern post."""
    ctx = Ctx('sl' + ('l' if lit else 'o'))
    pal = _pal(BONE_LINE, BONE, BONE_SH)
    P = []
    # the root foot it stands in
    P.append(Part('fill', pth('M16 96 L48 96 Q47 90 42 88.6 Q36 86 32 86.6 Q27 86 22 88.6 Q17 90 16 96 Z'), fill=ROOT, shade=ROOT_SH,
                  off=(-1, -1), line=ROOT_LINE, over=line('M20 94 Q24 90 30 89 M36 89.4 Q41 90 45 94', ROOT_HI, 0.9, op=0.9)))
    for d in ('M18 95 Q10 93 8.6 88', 'M46 95 Q54 93.4 55 89'):
        P.append(Part('limb', pth(d), width=1.8, fill=ROOT))
    # the femur post, knobbed at both ends
    P.append(Part('fill', pth('M29.4 86 L29.8 52 L34.2 52 L34.6 86 Z'), off=(-1.4, 0),
                  over=line('M30.8 54 L30.8 84', BONE_HI, 0.9, op=0.8)))
    for y in (86.4, 51.6):
        P.append(Part('fill', pth('M25.6 %.1f Q25 %.1f 28.4 %.1f L35.6 %.1f Q39 %.1f 38.4 %.1f Q39 %.1f 35.6 %.1f L28.4 %.1f Q25 %.1f 25.6 %.1f Z' % (
            y, y - 3.4, y - 3.6, y - 3.6, y - 3.4, y, y + 3.4, y + 3.6, y + 3.6, y + 3.4, y)), off=(-0.8, -0.8)))
    # a twist of root round the post, a leaf
    P.append(Part('limb', pth('M29 80 Q37 76 30.4 70 Q24 64 34 60'), width=1.6, fill=ROOT))
    P.append(leaf_part(34, 60, -30, 7, 2.8))
    # the jaw and the cranium
    jaw = 'M22.6 38 Q23 46.6 32 47.4 Q41 46.6 41.4 38 Z'
    teeth = ''.join(line('M%.1f 38.6 L%.1f 42' % (x, x), BONE_LINE, 0.9) for x in (26.4, 29.6, 32.8, 36))
    P.append(Part('fill', pth(jaw), off=(-1, -1), over=teeth))
    crown = ('M32 14.6 C42 14.6 47.4 21.4 47.4 29 C47.4 34.4 44.6 37.4 41.4 38.6 L22.6 38.6 C19.4 37.4 16.6 34.4 16.6 29 '
             'C16.6 21.4 22 14.6 32 14.6 Z')
    sock = ''
    for x in (25.4, 38.6):
        if lit:
            g = ctx.radgrad([(0, '#fff2c8'), (0.55, '#ffd06a'), (1, '#e88a2a')])
            sock += '<ellipse cx="%.1f" cy="30.4" rx="4.6" ry="4.2" fill="%s" stroke="%s" stroke-width="1.2"/>' % (x, g, BONE_LINE)
        else:
            sock += '<ellipse cx="%.1f" cy="30.4" rx="4.6" ry="4.2" fill="#1a1210" stroke="%s" stroke-width="1.2"/>' % (x, BONE_LINE)
    sock += '<path d="M30.4 35.6 L32 33 L33.6 35.6 Z" fill="#1a1210"/>'
    # a crack in the crown, a cute little chip
    sock += line('M36 16.4 L34.6 20.4 L37 23', BONE_LINE, 0.8, op=0.7)
    if lit:
        # the flame seen between the eyes, through the crown's open top
        sock += '<path d="%s" fill="%s" opacity="0.95"/>' % (flame_d(32, 31.6, 4.2, 8.6, 0.4), FLAME_MID)
    P.append(Part('fill', pth(crown), off=(-2.6, -2.4), over=sock,
                  hl=spec(24, 20, 3.2, 1.6, rot=-30, op=0.9) + line('M19.4 27 Q20.4 20 26 17', BONE_HI, 1.1, op=0.8)))
    # moss on the crown
    P.append(Part('fill', pth('M22 17.6 Q26 13.4 32 13.6 Q37 13.6 40 16 Q36 16.4 33.4 18.4 Q29 16 25.6 18.6 Q23 18.6 22 17.6 Z'),
                  fill=MOSS, shade=LEAF_SH, off=(-0.6, -0.8), line=ROOT_LINE, lw=0.9))
    under = ''
    over = ''
    if lit:
        halo = ctx.radgrad([(0, '#ffc85a', 0.55), (0.5, '#ffb040', 0.2), (1, '#ffb040', 0)])
        under = '<ellipse cx="32" cy="30" rx="30" ry="26" fill="%s"/>' % halo
        over = sparkle(49, 18, 2.6, BONE_LINE, '#fff2c8') + star4(13, 36, 1.5, '#fff2c8', 0.9)
    else:
        over = line('M32 14 Q29.6 9 32.6 5.6 Q35.4 2.6 33 0.6', '#c8c0b4', 1.1, op=0.7)
    return svg(ctx, under + paint(ctx, P, pal) + over, 64, 96)


# ================================================================ the root seal (the arena door)

def root_seal_svg(closed):
    """Mother Gravebough's door: a curtain of roots that grows shut (2 x 3
    tiles: 128 x 192, its top-left on the door's top-left cell). Open, the
    roots hang drawn back to the jambs."""
    ctx = Ctx('rs' + ('c' if closed else 'o'))
    pal = _pal(ROOT_LINE, ROOT, ROOT_SH)
    P = []
    if closed:
        strands = [
            'M8 0 Q20 40 12 80 Q4 124 18 160 Q26 180 20 192', 'M30 0 Q24 36 36 70 Q48 104 32 140 Q20 170 32 192',
            'M54 0 Q64 30 56 64 Q46 100 60 130 Q72 160 60 192', 'M78 0 Q70 34 80 66 Q92 98 76 132 Q66 164 80 192',
            'M100 0 Q110 42 98 78 Q88 112 104 146 Q114 172 104 192', 'M122 0 Q112 44 120 84 Q128 122 114 158 Q108 178 120 192',
            'M0 40 Q40 52 64 44 Q90 36 128 50', 'M0 104 Q30 92 60 104 Q92 118 128 100', 'M0 158 Q38 150 66 162 Q96 172 128 156']
        widths = [9, 11, 8, 10, 9, 11, 6, 6.6, 6]
        for d, w in zip(strands, widths):
            P.append(Part('limb', pth(d), width=w, fill=ROOT, over=''))
        # highlights along the strands
        hi = ''.join(line(d, ROOT_HI, 1.4, op=0.75) for d in strands[:6])
        # thorns and bone knuckles caught in the weave
        thorns = ''
        for x, y, a in ((18, 30, -30), (40, 58, 200), (62, 90, -20), (84, 120, 210), (104, 60, -40), (26, 130, 190), (96, 170, -25),
                        (50, 150, 20), (112, 110, 200)):
            r = math.radians(a)
            tx, ty = x + math.cos(r) * 8, y + math.sin(r) * 8
            nx, ny = -math.sin(r) * 2.2, math.cos(r) * 2.2
            thorns += '<path d="M%.1f %.1f L%.1f %.1f L%.1f %.1f Z" fill="%s" stroke="%s" stroke-width="1"/>' % (
                x + nx, y + ny, tx, ty, x - nx, y - ny, BONE, ROOT_LINE)
        knuck = ''
        for x, y in ((44, 46), (86, 96), (30, 166), (72, 20)):
            knuck += '<ellipse cx="%d" cy="%d" rx="6" ry="4.4" fill="%s" stroke="%s" stroke-width="1.4"/>' % (x, y, BONE, BONE_LINE)
            knuck += dot(x - 1.6, y - 1.2, 1.1, BONE_HI)
        P.append(Part('fill', pth('M0 0 L128 0 L128 192 L0 192 Z'), fill='#1a120c', shade='#1a120c', no_shade=True, rim=False, sil=False,
                      lw=0))
        P.insert(0, P.pop())   # the dark gap behind, first
        over = hi + thorns + knuck
        over += ''.join(leaf for leaf in [])
        doc = paint(ctx, P, pal) + over
        # a few leaves and a blossom so it reads as living roots
        L = [leaf_part(22, 76, -40, 9, 3.4), leaf_part(70, 136, 220, 9, 3.4), leaf_part(108, 30, -60, 8, 3)]
        doc += paint(ctx, L, pal) + blossom(58, 70, 3.4) + blossom(20, 120, 2.8)
        return svg(ctx, doc, 128, 192)
    # open: the roots drawn back to the jambs, hanging from the lintel
    for d, w in (('M4 0 Q10 60 4 120 Q0 160 6 192', 10), ('M16 0 Q14 30 22 60 Q28 84 18 100', 6),
                 ('M124 0 Q118 60 124 120 Q128 160 122 192', 10), ('M112 0 Q114 34 106 64 Q100 88 110 104', 6),
                 ('M34 0 Q36 14 30 26', 4), ('M60 0 Q58 12 64 22 Q68 30 62 36', 4.4), ('M92 0 Q94 16 88 28', 4)):
        P.append(Part('limb', pth(d), width=w, fill=ROOT))
    P += [leaf_part(22, 60, -30, 8, 3), leaf_part(106, 64, 210, 8, 3), leaf_part(62, 36, 80, 7, 2.6)]
    over = blossom(10, 100, 2.8) + blossom(118, 130, 2.6)
    return svg(ctx, paint(ctx, P, pal) + over, 128, 192)


# ================================================================ the orchard altar

def altar_orchard_svg(lit):
    """A mossy grave-stone altar (64 x 96, standing on y 96), its candle in a
    bone dish on the tomb's slab: the wick tip at (32, 22) as v2's altar.
    Lit, the carved flame in its niche burns and the moss blossoms."""
    ctx = Ctx('ao' + ('l' if lit else 'u'))
    stone, stone_sh, stone_hi = (('#8a846c', '#625e4e', '#b0aa90') if lit else (GRAVE, GRAVE_SH, GRAVE_HI))
    L = GRAVE_LINE
    pal = _pal(L, stone, stone_sh)
    P = []
    # the root plinth
    P.append(Part('fill', pth('M4 95.4 L60 95.4 Q59 88 54 85.6 L10 85.6 Q5 88 4 95.4 Z'), fill=ROOT, shade=ROOT_SH, off=(-1.6, -1.4),
                  line=ROOT_LINE, over=line('M9 88.6 Q20 86.6 30 88 M36 87.6 Q46 86.4 55 88.6', ROOT_HI, 0.9, op=0.9)))
    for d in ('M6 94 Q1 91 2 84', 'M58 94 Q63 90 61.6 84'):
        P.append(Part('limb', pth(d), width=2, fill=ROOT))
    # the tomb's body with its niche
    niche = arch_d(22.6, 41.4, 61.4, 83.6)
    body_over = '<path d="%s" fill="#161410" stroke="%s" stroke-width="1.3"/>' % (niche, L)
    body_over += line('M12.4 66 L19 66 M45 66 L51.6 66 M12.4 77 L19 77 M45 77 L51.6 77', L, 0.9, op=0.4)
    body_over += line('M12 81 L12 61 L52 61', stone_hi, 1, op=0.8)
    if lit:
        gl = ctx.radgrad([(0, '#ffd88a', 0.95), (0.6, '#ffb44a', 0.35), (1, '#ffb44a', 0)])
        body_over += '<g clip-path="%s"><ellipse cx="32" cy="76" rx="12" ry="14" fill="%s"/></g>' % (ctx.clip('<path d="%s"/>' % niche), gl)
        body_over += flame(ctx, 32, 81, 8.4, 13.6, lean=0.6, halo=False, lcol=L)
    else:
        body_over += flame_outline(32, 81, 8.4, 13.6, '#3c3a30')
    # a little skull carved over the niche
    P.append(Part('fill', rrect(10, 58, 54, 85, 1.4), off=(-2.6, -2.2), over=body_over))
    # moss over the body's shoulders, and a root climbing its corner
    P.append(Part('fill', pth('M9.6 60 Q9 66 11.6 70 Q13.6 66 16 67.6 Q17 63 21 63.4 Q22 60.6 26 60 Z'), fill=MOSS, shade=LEAF_SH,
                  off=(-0.6, -0.8), line=ROOT_LINE, lw=0.9))
    P.append(Part('limb', pth('M53 84 Q57 76 51.6 70 Q47 64 54 58'), width=2, fill=ROOT))
    # the mensa slab, moss dripping off its lip
    slab_over = line('M7 53.4 L57 53.4', stone_hi, 1, op=0.8)
    P.append(Part('fill', rrect(5, 51.4, 59, 58.6, 1.8), off=(-1.8, -1.6), over=slab_over))
    moss = ('M5.4 52 Q14 49 22 51 Q30 49.4 36 51 Q44 49.4 58.6 52 L58.6 54.6 Q55 54.6 54.4 58 Q52.6 55 50 55.4 Q47 55.4 46.4 59.6 '
            'Q45 55.6 42 55.2 L24 55.2 Q20 55.4 19.4 60 Q18 55.8 14 55.6 Q10 55.4 9.4 58.6 Q8.4 55 5.4 54.6 Z')
    P.append(Part('fill', pth(moss), fill=MOSS_HI if lit else MOSS, shade=LEAF_SH, off=(-0.8, -1), line=ROOT_LINE, lw=1,
                  over=line('M8 52.4 Q20 50.6 30 52 Q42 50.6 56 52.4', LEAF_HI if not lit else '#c8e08a', 0.9, op=0.9)))
    # the bone dish the candle stands in
    P.append(Part('fill', pth('M22.6 48.2 L41.4 48.2 Q40.8 51.8 36.6 52.4 L27.4 52.4 Q23.2 51.8 22.6 48.2 Z'), fill=BONE, shade=BONE_SH,
                  off=(-1, -1), line=BONE_LINE, over=line('M24.6 49.2 L39.4 49.2', BONE_HI, 0.8)))
    for x in (22.4, 41.6):
        P.append(Part('fill', ell(x, 49.4, 2.2, 1.8), fill=BONE, shade=BONE_SH, off=(-0.4, -0.4), line=BONE_LINE, lw=0.8))
    parts, wick = candle_parts(27.4, 36.6, 25.4, 48.8, 22, drips=((0.2, 5), (0.58, 9), (0.85, 3.4)))
    P += parts
    under = ''
    over = ''
    if lit:
        warm = ctx.radgrad([(0, '#ffb44a', 0.45), (0.5, '#ff9a3a', 0.16), (1, '#ff9a3a', 0)])
        under = '<ellipse cx="32" cy="46" rx="31" ry="44" fill="%s"/>' % warm
        over = blossom(12, 54.4, 2.8) + blossom(49.6, 53.2, 2.4) + blossom(56, 60, 2)
        over += sparkle(52, 40, 3.2, L, '#fff2c8') + star4(10, 44, 1.8, '#fff2c8', 0.9)
    return svg(ctx, under + paint(ctx, P, pal) + wick + over, 64, 96)


# ================================================================ the orchard bell

def _bell_parts(pal_c, rope_c, rope_sh, rope_line):
    """v2's bell shape (it keeps the gold rim and the swing, so it reads as the
    goal), hung from (64, 20)."""
    P = []
    rope_d = 'M64 108 C64.6 130 63.2 152 64 176'
    twist = ''.join('M%.1f %.1f l3.6 -2.4 ' % (62.2 + (0.3 if i % 2 else -0.2), y) for i, y in enumerate(range(114, 176, 5)))
    P.append(Part('limb', pth(rope_d), width=4.6, fill=rope_c, line=rope_line, over=line(twist, rope_sh, 1.0)))
    P.append(Part('fill', ell(64, 104.6, 6, 5.6), fill='#5a4a40', shade='#3a2e28', off=(-1.2, -1.4), line=BRONZE_LINE,
                  hl=dot(62, 102.6, 1.2, '#9a8a80')))
    P.append(Part('fill', pth('M58.4 29.6 L58.4 24.6 C58.4 17.6 69.6 17.6 69.6 24.6 L69.6 29.6 L66 29.6 L66 25 '
                              'C66 22.4 62 22.4 62 25 L62 29.6 Z'), off=(-1, -1.2)))
    body = pth('M50 30 C54 26.6 74 26.6 78 30 C84.4 35 85.4 46 86.6 60 C88 76 94 88 106 96.6 C109 98.8 108 102.4 104 102.4 '
               'L24 102.4 C20 102.4 19 98.8 22 96.6 C34 88 40 76 41.4 60 C42.6 46 43.6 35 50 30 Z')
    return P, body


def bell_orchard_svg():
    """The goal: a bronze bell wound with a root and blossom, its rope a
    twisted green vine with a leaf tassel."""
    ctx = Ctx('bo')
    pal = _pal(BRONZE_LINE, BRONZE, BRONZE_SH)
    P, body = _bell_parts(pal, '#7a9a4a', '#4e6630', '#1a2408')
    # the tassel: a bunch of leaves
    tassel = [leaf_part(64, 176, 100, 12, 4), leaf_part(63, 176, 60, 11, 3.6), leaf_part(65, 176, 130, 11, 3.6)]
    P = P[:1] + tassel + P[1:]
    bands = (line('M44.2 42.6 Q64 47 83.8 42.6', BRONZE_HI, 1.8) + line('M43.6 46 Q64 50.4 84.4 46', BRONZE_LINE, 0.9, op=0.6)
             + line('M28.8 91.8 Q64 98.2 99.2 91.8', BRONZE_HI, 2) + line('M26 95.6 Q64 102 102 95.6', BRONZE_LINE, 0.9, op=0.6))
    em = flame_d(64, 80, 12, 20, 1)
    bands += '<path d="%s" fill="%s" stroke="%s" stroke-width="1.3" stroke-linejoin="round"/>' % (em, BRONZE_HI, BRONZE_LINE)
    bands += '<path d="%s" fill="%s"/>' % (flame_d(64.2, 79, 5.8, 10, 0.5), '#fff6d8')
    hl = (spec(52, 60, 2.6, 16, rot=12, op=0.75) + spec(54.4, 36, 3, 1.4, rot=-20, op=0.9)
          + line('M31 96.4 Q40 92 44 84', '#ffe6b0', 1.2, op=0.8))
    P.append(Part('fill', body, off=(-5, -3), over=bands, hl=hl))
    P.append(Part('fill', ell(64, 102.2, 41.4, 4.2), fill='#2a1608', shade='#2a1608', no_shade=True, rim=False, sil=False, lw=1.2))
    P.append(Part('fill', ell(64, 104.6, 6, 5.6), fill='#5a4a40', shade='#3a2e28', off=(-1.2, -1.4), line=BRONZE_LINE,
                  rim=False, sil=False, hl=dot(62, 102.6, 1.2, '#9a8a80')))
    # the root wound round its shoulder and down one side
    root = 'M46 36 Q64 44 82 34 M82 34 Q88 50 84 64 Q80 76 90 86'
    P.append(Part('limb', pth(root), width=3.2, fill=ROOT, line=ROOT_LINE))
    P += [leaf_part(46, 36, 200, 10, 3.6), leaf_part(84, 64, -20, 9, 3.4), leaf_part(90, 86, 30, 8, 3)]
    over = blossom(70, 40, 3.6) + blossom(58, 41, 3) + blossom(86, 50, 2.6) + blossom(88, 78, 2.4)
    return svg(ctx, paint(ctx, P, pal) + over, 128, 192)


def bell_orchard_beam_svg():
    """The beam the orchard bell hangs from: a bough wrapped in roots, the
    iron hanger at (64, 20)."""
    ctx = Ctx('ob')
    pal = _pal(ROOT_LINE, '#6a4a30', '#4a3020')
    grain = line('M10 12.4 Q40 10.4 64 12.8 Q90 14.4 118 12 M14 16.6 Q46 18 70 16 Q96 14.6 116 17', '#8a6440', 0.9, op=0.9)
    P = [Part('fill', pth('M4 9 Q30 5.6 64 7.4 Q98 5.4 124 9.4 Q126 15 123 20.4 Q98 22.6 64 21 Q30 23 5 20.4 Q2 15 4 9 Z'),
              off=(-2, -2.4), over=grain, hl=line('M9 9.6 Q60 6.6 119 10', '#9a7048', 1.1, op=0.9))]
    for d in ('M16 6.6 Q22 14 18 22', 'M40 6 Q36 14 42 22', 'M88 6.2 Q94 14 88 22', 'M110 7 Q106 15 112 21.4'):
        P.append(Part('limb', pth(d), width=2.6, fill=ROOT))
    IRON, IRON_SH, IRON_LINE = '#4a4658', '#302c3c', '#120e18'
    P.append(Part('fill', rrect(57, 14.6, 71, 22.6, 1.6), fill=IRON, shade=IRON_SH, off=(-1, -1), line=IRON_LINE,
                  over=dot(60.4, 18.4, 1, '#8a86a0') + dot(67.6, 18.4, 1, '#8a86a0')))
    P += [leaf_part(18, 8, -120, 9, 3.4), leaf_part(110, 8, -60, 9, 3.4), leaf_part(40, 21, 110, 8, 3)]
    return svg(ctx, paint(ctx, P, pal) + blossom(96, 8, 2.8) + blossom(28, 19, 2.4), 128, 192)


# ================================================================ the bone sconce (P1)

def sconce_bone_svg():
    """W3's wall sconce `c`: a little skull on the wall, a femur arm and a
    rib-cage drip pan; the wick tip at (32, 14) as v2's sconce."""
    ctx = Ctx('sb')
    pal = _pal(BONE_LINE, BONE, BONE_SH)
    P = []
    # the femur arm, from the skull up to the pan
    P.append(Part('fill', pth('M30.2 44 L30.6 35 L33.4 35 L33.8 44 Z'), off=(-0.8, 0)))
    P.append(Part('fill', ell(32, 35, 4.4, 2.2), off=(-0.6, -0.6)))
    # the skull rosette on the wall
    P.append(Part('fill', pth('M32 38.6 C38.4 38.6 41.6 42.6 41.6 47 C41.6 50 40 51.6 38 52.4 L37.4 55.4 L26.6 55.4 L26 52.4 '
                              'C24 51.6 22.4 50 22.4 47 C22.4 42.6 25.6 38.6 32 38.6 Z'), off=(-1.6, -1.4),
                  over=('<ellipse cx="28.2" cy="47.4" rx="2.8" ry="2.6" fill="#1a1210"/><ellipse cx="35.8" cy="47.4" rx="2.8" ry="2.6" fill="#1a1210"/>'
                        '<path d="M31 51.6 L32 50 L33 51.6 Z" fill="#1a1210"/>'
                        + line('M28.6 53.4 L28.6 55 M31 53.6 L31 55.2 M33.4 53.6 L33.4 55.2 M35.6 53.4 L35.6 55', BONE_LINE, 0.7)),
                  hl=spec(27, 42, 2, 1, rot=-30, op=0.9)))
    # the rib pan
    P.append(Part('fill', pth('M21.6 30.2 L42.4 30.2 Q41.6 34 37 34.6 L27 34.6 Q22.4 34 21.6 30.2 Z'), off=(-1, -1.2),
                  over=line('M24.6 31.2 L24.6 33.6 M28.6 31.2 L28.6 34.2 M32 31.2 L32 34.4 M35.4 31.2 L35.4 34.2 M39.4 31.2 L39.4 33.6',
                            BONE_LINE, 0.8, op=0.8) + line('M23.4 31 L40.6 31', BONE_HI, 0.8, op=0.9)))
    P.append(Part('fill', pth('M42 31 Q46 28 45 25 Q48 29 43.6 33 Z'), fill=MOSS, shade=LEAF_SH, off=(-0.4, -0.4), line=ROOT_LINE, lw=0.8))
    parts, wick = candle_parts(28.2, 35.8, 17.4, 30.6, 14, drips=((0.25, 3.6), (0.7, 6)))
    P += parts
    return svg64(ctx, paint(ctx, P, pal) + wick)


# ================================================================ where the engine draws

POINTS = {
    'vine_top': {'hang': (32, 0), 'stem': (32, 64)},
    'spore_pod_closed': {'center': (32, 44), 'base': (32, 64), 'glow': (32, 44)},
    'spore_pod_swell': {'center': (32, 40), 'base': (32, 64), 'glow': (32, 40)},
    'spore_pod_burst': {'center': (32, 56), 'base': (32, 64), 'puff': (32, 22)},
    'spore_pod_hang_closed': {'center': (32, 27), 'top': (32, 0), 'glow': (32, 27)},
    'spore_pod_hang_swell': {'center': (32, 30), 'top': (32, 0), 'glow': (32, 30)},
    'spore_pod_hang_burst': {'center': (32, 9), 'top': (32, 0), 'puff': (32, 42)},
    'glowfruit_hang': {'top': (32, 0), 'light': (32, 38), 'fruit': (32, 37)},
    'glowfruit_lit': {'base': (32, 64), 'light': (32, 50)},
    'glowfruit_dim': {'base': (32, 64), 'light': (32, 50)},
    'skull_lantern_lit': {'flame': (32, 30), 'base': (32, 96)},
    'skull_lantern_out': {'flame': (32, 30), 'base': (32, 96)},
    'altar_orchard': {'flame': (32, 22), 'base': (32, 96)},
    'altar_orchard_lit': {'flame': (32, 22), 'base': (32, 96)},
    'bell_orchard': {'hang': (64, 20)},
    'bell_orchard_beam': {'hang': (64, 20)},
    'sconce_bone': {'flame': (32, 14)},
    'root_seal_open': {'size': (128, 192)},
    'root_seal_closed': {'size': (128, 192)},
}


def points_json():
    doc = {'_doc': 'A1 World 3 props (tools/art/props_w3.py). Frame units, 2 units = 1 world px (sprite scale 0.25). '
                   '64 x 64: vine_top, spore_pod_* and glowfruit_* (floor ones stand on y 64, _hang ones and glowfruit_hang '
                   'hang from y 0), sconce_bone. 64 x 96 (standing on y 96): skull_lantern_*, altar_orchard*. 128 x 192: '
                   'bell_orchard (hangs from (64, 20)), bell_orchard_beam, root_seal_* (2 x 3 tiles, top-left on the door\'s '
                   'top-left cell). flame = where the engine draws a live flame or hangs a light; light = a glowfruit\'s light; '
                   'glow = a pod\'s dim glow (r 24); puff = where a burst\'s cloud starts; center = the body\'s centre.'}
    doc.update({k: {n: list(p) for n, p in v.items()} for k, v in POINTS.items()})
    return json.dumps(doc, indent=1, sort_keys=True) + '\n'


def files():
    out = {
        'art/props/vine_top.svg': vine_top_svg(),
        'art/props/glowfruit_hang.svg': glowfruit_hang_svg(),
        'art/props/glowfruit_lit.svg': glowfruit_ground_svg(True),
        'art/props/glowfruit_dim.svg': glowfruit_ground_svg(False),
        'art/props/skull_lantern_lit.svg': skull_lantern_svg(True),
        'art/props/skull_lantern_out.svg': skull_lantern_svg(False),
        'art/props/root_seal_open.svg': root_seal_svg(False),
        'art/props/root_seal_closed.svg': root_seal_svg(True),
        'art/props/altar_orchard.svg': altar_orchard_svg(False),
        'art/props/altar_orchard_lit.svg': altar_orchard_svg(True),
        'art/props/bell_orchard.svg': bell_orchard_svg(),
        'art/props/bell_orchard_beam.svg': bell_orchard_beam_svg(),
        'art/props/sconce_bone.svg': sconce_bone_svg(),
        'art/props/points_w3.json': points_json(),
    }
    for st in ('closed', 'swell', 'burst'):
        out['art/props/spore_pod_%s.svg' % st] = spore_pod_svg(st)
        out['art/props/spore_pod_hang_%s.svg' % st] = spore_pod_svg(st, hang=True)
    return out


def build(write):
    for rel, text in files().items():
        write(rel, text)
