"""What every WICK drawing shares: the palette, the frame documents, the line
weights and the kit's face pieces at WICK's scale, plus the candle flame.

Frames (see the art contract in the README of this folder):
  characters  viewBox 0 0 128 128 at 256 px, ground y 122, facing right
  props/icons viewBox 0 0 64 64 at 128 px (one 32 px tile)
2 frame units are 1 world pixel, so every frame uses the same line weights.
The kit's face pieces (eyes, blush, mouths) are sized for HAUL's 150 box, so
they are drawn at twice WICK's coordinates and halved (H and the wrappers).
"""
import kit
from kit import Ctx, Part, render_parts, ell, pth, shp, spec, star4

# ---------------------------------------------------------------- palette
BG = '#1d1526'
STONE, STONE_HI, STONE_LINE = '#3a3148', '#54496a', '#140e1c'
GOLD, GOLD_HI, GOLD_SH, GOLD_LINE = '#d8b24a', '#ffe28a', '#a8842a', '#3a2408'
WAX, WAX_SH, WAX_LINE = '#efe6cc', '#cdbf9c', '#4a3420'
FLAME, FLAME_MID, FLAME_CORE, FLAME_EDGE, FLAME_LINE = '#f2b84b', '#ffd98a', '#fff2c8', '#e8742a', '#5a1e0c'
DEEP_RED, DEEP_RED_SH = '#a63a5a', '#6e2442'
LAVA = '#c8352a'
RIM = '#ffeccc'      # the warm candlelit sticker rim that makes silhouettes pop in the dark

# ---------------------------------------------------------------- weights
# (silhouette, rim, inner line, detail) in frame units. 2 units = 1 world px.
CHAR_WEIGHTS = (4.0, 3.2, 1.4, 1.0)


def weights(out=4.0, rim=3.2, inner=1.4, detail=1.0):
    kit.OUT_W, kit.RIM_W, kit.IN_W, kit.DETAIL_W = out, rim, inner, detail


weights(*CHAR_WEIGHTS)


def IN():
    return kit.IN_W


# ---------------------------------------------------------------- documents

def svg(ctx, body, w, h, px=2):
    """A document with viewBox 0 0 w h rendered at px pixels per unit."""
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">\n'
            '<defs>%s</defs>\n%s\n</svg>\n') % (w * px, h * px, w, h, ''.join(ctx.defs), body)


def svg128(ctx, body):
    return svg(ctx, body, 128, 128)


def svg64(ctx, body):
    return svg(ctx, body, 64, 64)


def paint(ctx, parts, pal):
    return render_parts(ctx, parts, pal)


def g(body, t):
    return '<g transform="%s">%s</g>' % (t, body)


# ---------------------------------------------------------------- the kit's face pieces at half size

def H(s):
    """Halve art drawn at twice WICK's coordinates."""
    return '<g transform="scale(0.5)">%s</g>' % s


def eye(ctx, cx, cy, w, h, pal, look=(0, 0), **kw):
    return H(kit.eye(ctx, cx * 2, cy * 2, w * 2, h * 2, pal, look=(look[0] * 2, look[1] * 2), **kw))


def blush(cx, cy, pal, rx=3.8, ry=2.1, lines=True, op=0.62):
    return H(kit.blush(cx * 2, cy * 2, pal, rx * 2, ry * 2, lines, op))


def mouth_open(x, y, w, h, pal, teeth=False):
    return H(kit.mouth_open(x * 2, y * 2, w * 2, h * 2, pal, teeth))


def mouth_frown(x, y, w, pal):
    return H(kit.mouth_frown(x * 2, y * 2, w * 2, pal))


def sweat(x, y, s=1.0, rot=0):
    return H(kit.sweat(x * 2, y * 2, s, rot))


def sparkle(x, y, r, line, fill='#ffffff'):
    return kit.sparkle(x, y, r, line, fill)


def line(d, col, w, op=None, cap='round'):
    o = ' opacity="%s"' % op if op is not None else ''
    return '<path d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linecap="%s" stroke-linejoin="round"%s/>' % (
        d, col, w, cap, o)


def dot(x, y, r, col, op=None):
    o = ' opacity="%s"' % op if op is not None else ''
    return '<circle cx="%.2f" cy="%.2f" r="%.2f" fill="%s"%s/>' % (x, y, r, col, o)


def squeeze(cx, cy, s, col, flip=False, w=2.2):
    """A > (or < with flip) eye squeezed shut."""
    k = -1 if flip else 1
    return line('M%.1f %.1f L%.1f %.1f L%.1f %.1f' % (cx - k * s * 0.5, cy - s * 0.55, cx + k * s * 0.45, cy,
                                                     cx - k * s * 0.5, cy + s * 0.55), col, w)


def swirl_eye(cx, cy, r, col, w=1.3):
    """A dizzy spiral eye."""
    d = 'M%.1f %.1f' % (cx, cy)
    import math
    n = 22
    for i in range(1, n + 1):
        t = i / float(n)
        a = t * 4.2 * math.pi
        rr = r * t
        d += ' L%.2f %.2f' % (cx + rr * math.cos(a), cy + rr * math.sin(a))
    return line(d, col, w)


# ---------------------------------------------------------------- flame

def flame_d(cx, by, w, h, lean=0.0):
    """A teardrop flame: its round bottom on by, its tip h above, leaning by lean."""
    a = w / 2.0
    tx, ty = cx + lean, by - h
    return ('M%.2f %.2f C%.2f %.2f %.2f %.2f %.2f %.2f C%.2f %.2f %.2f %.2f %.2f %.2f '
            'C%.2f %.2f %.2f %.2f %.2f %.2f C%.2f %.2f %.2f %.2f %.2f %.2f Z') % (
        tx, ty,
        tx + a * 0.25, ty + h * 0.28, cx + a, by - h * 0.46, cx + a, by - a * 0.9,
        cx + a, by - a * 0.3, cx + a * 0.55, by, cx, by,
        cx - a * 0.55, by, cx - a, by - a * 0.3, cx - a, by - a * 0.9,
        cx - a, by - h * 0.46, tx - a * 0.2, ty + h * 0.34, tx, ty)


def glow(ctx, cx, cy, r, col=FLAME, op=0.55):
    grad = ctx.radgrad([(0, col, op), (0.45, col, op * 0.45), (1, col, 0)])
    return '<circle cx="%.2f" cy="%.2f" r="%.2f" fill="%s"/>' % (cx, cy, r, grad)


def flame(ctx, cx, by, w, h, lean=0.0, line_w=None, halo=True, lcol=FLAME_LINE):
    """A lit flame, outlined, with a hot core (and a soft halo)."""
    lw = kit.IN_W * 1.2 if line_w is None else line_w
    s = glow(ctx, cx + lean * 0.4, by - h * 0.45, h * 1.1) if halo else ''
    outer = flame_d(cx, by, w, h, lean)
    s += '<path d="%s" fill="%s" stroke="%s" stroke-width="%.2f" stroke-linejoin="round"/>' % (outer, FLAME, lcol, lw)
    s += '<path d="%s" fill="%s"/>' % (flame_d(cx + w * 0.02, by - h * 0.05, w * 0.7, h * 0.72, lean * 0.6), FLAME_MID)
    s += '<path d="%s" fill="%s"/>' % (flame_d(cx - w * 0.02, by - h * 0.1, w * 0.42, h * 0.44, lean * 0.3), FLAME_CORE)
    return s


def mix(a, b, t):
    """Color a blended toward b by t (0..1)."""
    ca = [int(a[i:i + 2], 16) for i in (1, 3, 5)]
    cb = [int(b[i:i + 2], 16) for i in (1, 3, 5)]
    return '#%02x%02x%02x' % tuple(round(x + (y - x) * t) for x, y in zip(ca, cb))


def xf(d, t):
    """A path shape carrying its own transform (ThorVG keeps it inside clip paths)."""
    return '<path d="%s" transform="%s" {a}/>' % (d, t)


def xell(cx, cy, rx, ry, t):
    return '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" transform="%s" {a}/>' % (cx, cy, rx, ry, t)


def gx(body, t):
    return '<g transform="%s">%s</g>' % (t, body) if body else ''
