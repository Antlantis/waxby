"""The story art's shared kit: the Panel builder that writes a panel's layer
SVGs and its panels.json entry, the line-weight switch, cel-shaded set
pieces in panel units, stained glass, and the figure/portrait frames.

Units. A panel is W x H panel units (1000 x 460 is about the phone's view at
zoom 1). A layer's SVG covers `rect` (panel units; the whole panel unless it
is a near layer or a tile) at `px` pixels per unit: 2 for depth <= 0.7, 3
otherwise, never wider than 4096 px (a wide near layer drops to 2.9).

Figures and portraits are drawn in "native" units, twice WICK's 128-frame
coordinates (so the kit's face pieces go in unhalved, and a Wick-sized
character is about 180 units tall), then fitted into their frame:
  figure    256 frame, feet at (128, 244); native (128, 244) is the feet.
            fit scale s: the figure's panel height h = 120 / s (the actor,
            Wick's 128 frame, is h 120, so s = 1 is Wick-sized).
  portrait  128 frame, face near (64, 62); native drawing scaled by 8/9
            (the same on-screen size and line weight as the calling
            portraits, which crop 72 units of Wick's frame).
The kit's default weights (8 / 5 / 2.6 / 2) are native weights; the warm
RIM goes on figures and portraits only, never on set pieces.
"""
import math
from contextlib import contextmanager

import kit
from kit import Part, ell, pth, shp
from common import (Ctx, RIM, GOLD, GOLD_SH, GOLD_HI, GOLD_LINE, WAX, WAX_SH, WAX_LINE, FLAME, FLAME_MID,
                    FLAME_CORE, line, dot, flame_d, spec, star4, mix, gx)

# ---------------------------------------------------------------- weights

NATIVE_W = (8.0, 5.6, 2.6, 2.0)     # figures and portraits (native units)
# set pieces: (silhouette, rim 0, inner, detail). The visible outline is
# silhouette/2 + inner/2: 3.0 on the front layers, 2.0 middle, 1.4 back.
FRONT_W = (4.4, 0.0, 1.6, 1.1)
MID_W = (3.0, 0.0, 1.0, 0.8)
BACK_W = (2.0, 0.0, 0.8, 0.6)


@contextmanager
def weights(w):
    """Sets the kit's line weights for the drawing inside, then restores them
    (the other art modules draw with WICK's own weights)."""
    old = (kit.OUT_W, kit.RIM_W, kit.IN_W, kit.DETAIL_W)
    kit.OUT_W, kit.RIM_W, kit.IN_W, kit.DETAIL_W = w
    try:
        yield
    finally:
        kit.OUT_W, kit.RIM_W, kit.IN_W, kit.DETAIL_W = old


def weights_for(depth):
    if depth >= 0.95:
        return FRONT_W
    if depth >= 0.55:
        return MID_W
    return BACK_W


# ---------------------------------------------------------------- colour

def rgb(h):
    h = h.lstrip('#')
    return [int(h[i:i + 2], 16) for i in (0, 2, 4)]


def hexc(c):
    return '#%02x%02x%02x' % tuple(max(0, min(255, int(round(v)))) for v in c)


def shade_of(col, k=0.72, hue_to='#2a1a4a', t=0.18):
    """A cel shade: darker and pulled a little toward violet (the cathedral's shadows)."""
    c = rgb(col)
    return mix(hexc([v * k for v in c]), hue_to, t)


def light_of(col, k=0.35, to='#fff6e0'):
    return mix(col, to, k)


def fade(col, dark, t):
    """Pushes a back-layer colour toward the panel's dark hue (desaturated, dimmed)."""
    if dark is None:
        return col
    c = rgb(col)
    lum = (0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2])
    d = [v * 255 for v in dark]
    dl = max(1.0, 0.3 * d[0] + 0.59 * d[1] + 0.11 * d[2])
    tint = [v * lum / dl for v in d]
    return mix(col, hexc(tint), t)


# ---------------------------------------------------------------- panels

ROOT = 'res://art/story/'


def rnd(v):
    return round(v, 2)


# The cutscene player draws a pair of eyes from one point and a size h: the
# eyes EYE_GAP * h apart, dots of 0.5 h (scripts/cutscene.gd). Eye lights set
# h from their two points, so the eyes land in their sockets even where the
# exact points (pts, dot) aren't read.
EYE_GAP = 5.2


class Panel:
    """One story panel: its layers (each an SVG under art/story/sets/), its
    lights and its anchors, as panels.json lists them. Place lights first,
    then paint toward them."""

    def __init__(self, pid, w, h, dark, motes=None, **extra):
        self.id, self.w, self.h = pid, w, h
        self.dark = dark
        self.motes = motes
        self.extra = extra
        self.layers = []
        self.lights = {}
        self.anchors = {}
        self.files = {}

    # ---- lights and anchors (panel units; depth = the layer they ride on)
    def light(self, lid, x, y, r, s=1.0, kind='flame', h=None, depth=1.0, **kw):
        """A light. Eyes give pts (the two eyes) and dot, and take their h
        (the eye size) from pts. A tint is written as color too, the key the
        cutscene player reads."""
        if kind == 'eyes' and h is None and 'pts' in kw:
            (ax, ay), (bx, by) = kw['pts']
            h = math.hypot(bx - ax, by - ay) / EYE_GAP
        d = {'p': [rnd(x), rnd(y)], 'r': rnd(r), 's': rnd(s), 'kind': kind, 'depth': depth}
        if h is not None:
            d['h'] = rnd(h)
        d.update(kw)
        if 'tint' in d and 'color' not in d:
            d['color'] = d['tint']
        self.lights[lid] = d
        return (x, y)

    def anchor(self, aid, x, y, depth=1.0, h=None, flip=False, **kw):
        d = {'p': [rnd(x), rnd(y)], 'depth': depth}
        if h is not None:
            d['h'] = rnd(h)
        if flip:
            d['flip'] = True
        d.update(kw)
        self.anchors[aid] = d

    def L(self, lid):
        return tuple(self.lights[lid]['p'])

    # ---- layers
    def px_for(self, depth, width):
        px = 2.0 if depth <= 0.7 else 3.0
        while width * px > 4096:
            px = round(px - 0.1, 1)
        return px

    def layer(self, name, depth, body, lit=False, px=None, rect=None, ctx=None, note=None):
        """Adds a layer. body is SVG in panel coordinates; rect (x, y, w, h)
        is the part of the panel it covers (default: the panel, or 10% more
        on every side for a near layer, depth > 1)."""
        if rect is None:
            if depth > 1.0:
                mx, my = self.w * 0.1, self.h * 0.1
                rect = (-mx, -my, self.w + 2 * mx, self.h + 2 * my)
            else:
                rect = (0, 0, self.w, self.h)
        x, y, w, h = rect
        if px is None:
            px = self.px_for(depth, w)
        tw, th = w * px, h * px
        assert tw <= 4096.5, '%s_%s is %d px wide' % (self.id, name, tw)
        defs = ''.join(ctx.defs) if ctx else ''
        doc = ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="%s %s %s %s">\n'
               '<defs>%s</defs>\n%s\n</svg>\n') % (round(tw), round(th), rnd(x), rnd(y), rnd(w), rnd(h), defs, body)
        rel = 'art/story/sets/%s_%s.svg' % (self.id, name)
        self.files[rel] = doc
        entry = {'tex': ROOT + 'sets/%s_%s.svg' % (self.id, name), 'depth': depth, 'lit': lit, 'px': px,
                 'rect': [rnd(x), rnd(y), rnd(w), rnd(h)]}
        if note:
            entry['note'] = note
        self.layers.append(entry)

    def manifest(self):
        m = {'size': [self.w, self.h], 'dark': self.dark, 'motes': self.motes, 'layers': self.layers,
             'lights': self.lights, 'anchors': self.anchors}
        m.update(self.extra)
        return m


# ---------------------------------------------------------------- painting helpers (panel units)

def P(d, fill, shade=None, off=(-3, -3), **kw):
    """A cel-shaded fill part (shade defaults to a violet-leaning darker fill)."""
    return Part('fill', pth(d), fill=fill, shade=shade or shade_of(fill), off=off, **kw)


def E(cx, cy, rx, ry, fill, shade=None, off=(-2, -2), rot=0, **kw):
    return Part('fill', ell(cx, cy, rx, ry, rot), fill=fill, shade=shade or shade_of(fill), off=off, **kw)


def LIMB(d, fill, width, **kw):
    return Part('limb', pth(d), fill=fill, width=width, **kw)


def draw(ctx, parts, line_col, w=FRONT_W):
    """Renders parts as one outlined object at weights w."""
    with weights(w):
        return kit.render_parts(ctx, parts, dict(line=line_col, rim=RIM, base='#808080', shade='#606060'))


def fillp(d, col, op=None):
    o = ' opacity="%s"' % op if op is not None else ''
    return '<path d="%s" fill="%s"%s/>' % (d, col, o)


def rect_d(x0, y0, x1, y1):
    return 'M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (x0, y0, x1, y0, x1, y1, x0, y1)


def rrect_d(x0, y0, x1, y1, r):
    return ('M%.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f L%.1f %.1f '
            'Q%.1f %.1f %.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f Z') % (
        x0 + r, y0, x1 - r, y0, x1, y0, x1, y0 + r, x1, y1 - r, x1, y1, x1 - r, y1,
        x0 + r, y1, x0, y1, x0, y1 - r, x0, y0 + r, x0, y0, x0 + r, y0)


def ell_d(cx, cy, rx, ry, rot=0.0):
    k = 0.5523
    pts = [(rx, 0), (rx, ry * k), (rx * k, ry), (0, ry), (-rx * k, ry), (-rx, ry * k), (-rx, 0), (-rx, -ry * k),
           (-rx * k, -ry), (0, -ry), (rx * k, -ry), (rx, -ry * k), (rx, 0)]
    c, s = math.cos(math.radians(rot)), math.sin(math.radians(rot))
    Q = ['%.2f %.2f' % (cx + x * c - y * s, cy + x * s + y * c) for x, y in pts]
    return 'M%s C%s %s %s C%s %s %s C%s %s %s C%s %s %s Z' % tuple(Q)


def poly_d(pts, close=True):
    s = 'M' + ' L'.join('%.1f %.1f' % p for p in pts)
    return s + (' Z' if close else '')


def arch_d(x0, x1, top, bottom, point=0.62):
    """A pointed gothic arch from x0 to x1, apex at top, sides down to bottom."""
    cx = (x0 + x1) / 2.0
    w = x1 - x0
    spring = top + w * point
    return ('M%.1f %.1f L%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f L%.1f %.1f Z' % (
        x0, bottom, x0, spring, x0, spring - w * 0.36, cx - w * 0.2, top + w * 0.1, cx, top,
        cx + w * 0.2, top + w * 0.1, x1, spring - w * 0.36, x1, spring, x1, bottom))


def round_arch_d(x0, x1, top, bottom):
    cx, r = (x0 + x1) / 2.0, (x1 - x0) / 2.0
    k = 0.5523 * r
    return ('M%.1f %.1f L%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f L%.1f %.1f Z' % (
        x0, bottom, x0, top + r, x0, top + r - k, cx - k, top, cx, top, cx + k, top, x1, top + r - k, x1, top + r,
        x1, bottom))


def radial(ctx, cx, cy, r, col, op=0.6, mid=0.45):
    g = ctx.radgrad([(0, col, op), (mid, col, op * 0.45), (1, col, 0)])
    return '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s"/>' % (cx, cy, r, g)


def vgrad(ctx, stops):
    return ctx.lingrad(stops, x1=0, y1=0, x2=0, y2=1)


class Rand:
    """A tiny seeded LCG so every build draws the same snow, stars and cobbles."""

    def __init__(self, seed):
        self.s = seed & 0x7fffffff or 1

    def f(self):
        self.s = (1103515245 * self.s + 12345) & 0x7fffffff
        return self.s / float(0x7fffffff)

    def u(self, a, b):
        return a + (b - a) * self.f()

    def i(self, a, b):
        return int(math.floor(self.u(a, b + 0.999)))

    def pick(self, seq):
        return seq[min(len(seq) - 1, int(self.f() * len(seq)))]


# ---------------------------------------------------------------- set pieces

def unlit_wick(x, y, h=6.0, col='#241a14', w=1.6):
    """A burnt wick stub standing up from (x, y)."""
    return line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (x, y, x - h * 0.12, y - h * 0.5, x + h * 0.05, y - h), col, w)


def candle(ctx, x, base, w, h, line_col, lit_tip=True, drips=((0.22, 0.28), (0.62, 0.45), (0.86, 0.18)),
           wax=WAX, wax_sh=WAX_SH, cap='#fffaec'):
    """A cream candle standing on (x, base), w wide and h tall, its melted cap
    running down in drips (fraction across, length as a fraction of w * 2).
    Returns (parts, overlay, wick_tip): draw the wick overlay after the parts;
    wick_tip is where the engine's flame sits."""
    x0, x1 = x - w / 2.0, x + w / 2.0
    top = base - h
    body = P(rect_d(x0, top + w * 0.12, x1, base), wax, wax_sh, off=(-w * 0.2, 0),
             hl=spec(x0 + w * 0.22, (top + base) / 2 + 1, w * 0.07, h * 0.2, rot=0, op=0.6))
    d = 'M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f' % (
        x0 - w * 0.04, top + w * 0.16, x0 - w * 0.04, top, x0 + w * 0.3, top - w * 0.06, x, top - w * 0.06,
        x0 + w * 0.7, top - w * 0.06, x1 + w * 0.04, top, x1 + w * 0.04, top + w * 0.16)
    xp = x1 + w * 0.04
    b = top + w * 0.24
    for f, ln in sorted(drips, key=lambda t: -t[0]):
        dx = x0 + w * f
        dw = max(0.8, w * 0.12)
        L = ln * w * 2
        d += (' L%.1f %.1f Q%.1f %.1f %.1f %.1f L%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f L%.1f %.1f '
              'Q%.1f %.1f %.1f %.1f') % (
            xp, b, (xp + dx + dw) / 2, b + w * 0.06, dx + dw, b + w * 0.03, dx + dw, b + L, dx + dw, b + L + dw * 1.2,
            dx - dw, b + L + dw * 1.2, dx - dw, b + L, dx - dw, b + w * 0.03, (dx - dw + x0) / 2, b + w * 0.08,
            dx - dw - w * 0.04, b + w * 0.05)
        xp = dx - dw - w * 0.04
    d += ' L%.1f %.1f Z' % (x0 - w * 0.04, b)
    capp = Part('fill', pth(d), fill=cap, shade=mix(cap, wax_sh, 0.55), off=(-w * 0.08, -w * 0.05), line=None,
                over='<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s"/>' % (x, top + w * 0.05, w * 0.34, w * 0.09 + 0.3, wax_sh))
    tip = (x, top - w * 0.05 - max(2.5, w * 0.5))
    wick = unlit_wick(x, top + w * 0.02, max(2.5, w * 0.5), w=max(1.0, w * 0.13))
    return [body, capp], wick, tip


def candle_stand(ctx, x, floor, height, w, line_col, iron='#3a3446', iron_sh='#221e2c', iron_hi='#6a6480',
                 candle_h=None):
    """A wrought-iron candle stand: a tripod foot, a shaft, a drip pan, and a
    candle on top. Returns (svg, wick_tip)."""
    ch = candle_h if candle_h is not None else height * 0.28
    pan_y = floor - height + ch
    parts = []
    sw = max(1.2, w * 0.16)
    parts.append(LIMB('M%.1f %.1f L%.1f %.1f' % (x, floor - w * 0.3, x, pan_y + w * 0.1), iron, sw))
    for k in (-1, 1):
        parts.append(LIMB('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (x, floor - w * 0.5, x + k * w * 0.4, floor - w * 0.3,
                                                              x + k * w * 0.75, floor), iron, sw * 0.9))
    parts.append(P('M%.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f Z' % (
        x - w * 0.62, pan_y, x + w * 0.62, pan_y, x + w * 0.5, pan_y + w * 0.3, x + w * 0.2, pan_y + w * 0.3,
        x - w * 0.2, pan_y + w * 0.3, x - w * 0.5, pan_y + w * 0.3, x - w * 0.62, pan_y), iron, iron_sh,
        off=(-w * 0.08, -w * 0.08), over=line('M%.1f %.1f L%.1f %.1f' % (x - w * 0.5, pan_y + w * 0.06, x + w * 0.1, pan_y + w * 0.06), iron_hi, max(0.6, w * 0.06))))
    cparts, wick, tip = candle(ctx, x, pan_y + w * 0.02, w * 0.46, ch, line_col)
    parts += cparts
    return parts, wick, tip


def bell_d(cx, top, w, h):
    """A church bell's outline: shoulder at top, flared lip at top + h."""
    a = w / 2.0
    R = [(cx - a * 0.42, top),
         ((cx - a * 0.2, top - h * 0.05), (cx + a * 0.2, top - h * 0.05), (cx + a * 0.42, top)),
         ((cx + a * 0.62, top + h * 0.1), (cx + a * 0.6, top + h * 0.45), (cx + a * 0.68, top + h * 0.7)),
         ((cx + a * 0.76, top + h * 0.86), (cx + a * 0.98, top + h * 0.9), (cx + a, top + h))]
    d = 'M%.1f %.1f' % R[0]
    for c in R[1:]:
        d += ' C%.1f %.1f %.1f %.1f %.1f %.1f' % (c[0] + c[1] + c[2])
    d += ' L%.1f %.1f' % (cx - a, top + h)
    d += ' C%.1f %.1f %.1f %.1f %.1f %.1f' % (cx - a * 0.98, top + h * 0.9, cx - a * 0.76, top + h * 0.86, cx - a * 0.68, top + h * 0.7)
    d += ' C%.1f %.1f %.1f %.1f %.1f %.1f Z' % (cx - a * 0.6, top + h * 0.45, cx - a * 0.62, top + h * 0.1, cx - a * 0.42, top)
    return d


BRONZE, BRONZE_SH, BRONZE_HI, BRONZE_LINE = '#c8903e', '#8a5a24', '#f6d48a', '#2a1406'


def bell_parts(cx, top, w, h, rot=0.0, bronze=BRONZE, bronze_sh=BRONZE_SH, hi=BRONZE_HI, crest=True, crack=False,
               line_col=BRONZE_LINE):
    """A bronze bell (with the Vigil's flame on its waist) turned rot degrees
    around its crown. Returns parts."""
    t = 'rotate(%.1f %.1f %.1f)' % (rot, cx, top)
    a = w / 2.0
    over = line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (cx - a * 0.6, top + h * 0.18, cx, top + h * 0.24, cx + a * 0.6, top + h * 0.18), hi, max(0.8, w * 0.03))
    over += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (cx - a * 0.9, top + h * 0.9, cx, top + h * 0.98, cx + a * 0.9, top + h * 0.9), hi, max(0.8, w * 0.035))
    if crest:
        over += '<path d="%s" fill="%s" stroke="%s" stroke-width="%.2f" stroke-linejoin="round"/>' % (
            flame_d(cx, top + h * 0.72, w * 0.16, h * 0.3, w * 0.01), hi, line_col, max(0.6, w * 0.018))
    if crack:
        over += line('M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f' % (
            cx + a * 0.3, top + h * 0.05, cx + a * 0.15, top + h * 0.3, cx + a * 0.34, top + h * 0.48, cx + a * 0.2, top + h * 0.75),
            line_col, max(1.0, w * 0.035))
    hl = spec(cx - a * 0.38, top + h * 0.45, w * 0.05, h * 0.22, rot=12, op=0.7)
    body = Part('fill', pth(bell_d(cx, top, w, h)).replace(' {a}', ' transform="%s" {a}' % t), fill=bronze, shade=bronze_sh,
                off=(-w * 0.07, -h * 0.03), line=line_col, over=gx(over, t), hl=gx(hl, t))
    mouth = Part('fill', ell(cx, top + h, a * 0.98, h * 0.07).replace(' {a}', ' transform="%s" {a}' % t), fill='#2a1608', no_shade=True,
                 sil=False, line=line_col)
    cx2, cy2 = cx, top + h * 1.02
    clap = Part('fill', ell(cx2, cy2, w * 0.08, w * 0.075).replace(' {a}', ' transform="%s" {a}' % t), fill='#5a4a40', shade='#3a2e28',
                off=(-w * 0.015, -w * 0.02), line=line_col, sil=False)
    canon = Part('fill', pth('M%.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f L%.1f %.1f Z' % (
        cx - w * 0.09, top + 0.5, cx - w * 0.09, top - h * 0.1, cx, top - h * 0.2, cx + w * 0.09, top - h * 0.1, cx + w * 0.09, top + 0.5))
        .replace(' {a}', ' transform="%s" {a}' % t), fill=bronze, shade=bronze_sh, off=(-1, -1), line=line_col)
    return [canon, body, mouth, clap]


def crest_svg(cx, cy, s, fill, line_col, flame_col='#fff2c8', lw=1.6):
    """The Vigil's crest: a bell whose clapper is a teardrop flame."""
    body = bell_d(cx, cy - s * 0.55, s * 0.95, s * 0.9)
    out = '<path d="%s" fill="%s" stroke="%s" stroke-width="%.2f" stroke-linejoin="round"/>' % (body, fill, line_col, lw)
    out += '<path d="%s" fill="%s" stroke="%s" stroke-width="%.2f" stroke-linejoin="round"/>' % (
        flame_d(cx, cy + s * 0.5, s * 0.3, s * 0.52, s * 0.03), flame_col, line_col, lw * 0.8)
    out += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (cx - s * 0.36, cy + s * 0.2, cx, cy + s * 0.27, cx + s * 0.36, cy + s * 0.2), line_col, lw * 0.7, op=0.6)
    return out


def snowcap(d_top, col='#eef2ff', sh='#b8c0e0', line_col=None, lw=1.2):
    return '<path d="%s" fill="%s" stroke="%s" stroke-width="%.1f" stroke-linejoin="round"/>' % (d_top, col, line_col or sh, lw)


def moon_svg(ctx, cx, cy, r, col='#e8e4ff', halo=True):
    s = ''
    if halo:
        s += radial(ctx, cx, cy, r * 3.2, '#b8b0ff', 0.28, 0.35)
        s += radial(ctx, cx, cy, r * 1.7, '#e8e4ff', 0.35, 0.6)
    g = ctx.radgrad([(0, '#ffffff'), (0.6, col), (1, mix(col, '#9a90c8', 0.35))], cx=0.4, cy=0.38, r=0.65)
    s += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s"/>' % (cx, cy, r, g)
    for dx, dy, rr in ((0.3, -0.2, 0.18), (-0.25, 0.3, 0.13), (0.1, 0.42, 0.09), (-0.4, -0.25, 0.08)):
        s += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s" opacity="0.55"/>' % (cx + dx * r, cy + dy * r, rr * r, mix(col, '#9a90c8', 0.45))
    return s


def cloud_d(x, y, w, h):
    """A puffy flat-bottomed cloud."""
    return ('M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f '
            'C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z') % (
        x, y,
        x - w * 0.06, y - h * 0.5, x + w * 0.14, y - h * 0.7, x + w * 0.26, y - h * 0.5,
        x + w * 0.3, y - h * 1.05, x + w * 0.58, y - h * 1.1, x + w * 0.62, y - h * 0.6,
        x + w * 0.74, y - h * 0.9, x + w * 0.96, y - h * 0.7, x + w * 0.92, y - h * 0.3,
        x + w * 1.04, y - h * 0.2, x + w * 1.02, y, x + w * 0.96, y,
        x + w * 0.6, y + h * 0.04, x + w * 0.3, y + h * 0.04, x, y)


def smoke_curl(x, y, h, col, w=2.0, op=0.6, lean=1.0):
    """A thin S-curl of smoke rising from (x, y)."""
    d = 'M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f' % (
        x, y, x - h * 0.2 * lean, y - h * 0.25, x + h * 0.25 * lean, y - h * 0.45, x + h * 0.05 * lean, y - h * 0.65,
        x - h * 0.12 * lean, y - h * 0.8, x + h * 0.1 * lean, y - h * 0.95, x + h * 0.22 * lean, y - h)
    return line(d, col, w, op=op)


# ---------------------------------------------------------------- stained glass

CAME = '#140e1c'
GLASS = {'ruby': '#b8324e', 'cobalt': '#3a6ab8', 'gold': '#d8a830', 'green': '#5aa860', 'flame': '#fff2c8',
         'hush': '#4a3a7a', 'hush_dk': '#2a2040', 'bronze': '#c8903e', 'ivory': '#efe6cc', 'sky': '#6a9ad8',
         'lav': '#8a7ac8', 'earth': '#6a7a3a', 'earth_dk': '#4a5228', 'white': '#fff8e8'}


class Glass:
    """Stained glass: flat panes, each a touch lighter toward its top, with a
    thin white sliver; lead cames over the joins. One gradient per colour."""

    def __init__(self, ctx):
        self.ctx = ctx
        self.grads = {}

    def grad(self, col):
        if col not in self.grads:
            self.grads[col] = self.ctx.lingrad([(0, light_of(col, 0.32)), (0.55, col), (1, shade_of(col, 0.8, '#1a1030', 0.1))])
        return self.grads[col]

    def pane(self, d, col, came=4.0, sliver=True, box=None):
        s = '<path d="%s" fill="%s"/>' % (d, self.grad(col))
        if sliver and box:
            x0, y0, x1, y1 = box
            w, h = x1 - x0, y1 - y0
            if w > 14 and h > 14:
                s += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (x0 + w * 0.18, y0 + h * 0.5, x0 + w * 0.2, y0 + h * 0.22,
                                                             x0 + w * 0.45, y0 + h * 0.16), '#ffffff', max(1.2, min(w, h) * 0.05), op=0.45)
        if came:
            s += '<path d="%s" fill="none" stroke="%s" stroke-width="%.1f" stroke-linejoin="round"/>' % (d, CAME, came)
        return s

    def quad(self, pts, col, came=4.0):
        xs, ys = [p[0] for p in pts], [p[1] for p in pts]
        return self.pane(poly_d(pts), col, came, box=(min(xs), min(ys), max(xs), max(ys)))


# ---------------------------------------------------------------- figure frames

FIG = 256
FEET = (128.0, 244.0)


def fit(body, s):
    """Fits native drawing (feet at (128, 244)) into the figure frame at scale s."""
    if abs(s - 1.0) < 1e-6:
        return body
    return '<g transform="translate(128 244) scale(%.4f) translate(-128 -244)">%s</g>' % (s, body)


def to_frame(x, y, s):
    return (rnd(128 + (x - 128) * s), rnd(244 + (y - 244) * s))


def fig_doc(ctx, body, px=4, frame=256):
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">\n'
            '<defs>%s</defs>\n%s\n</svg>\n') % (frame * px, frame * px, frame, frame, ''.join(ctx.defs), body)


PORTRAIT_S = 8.0 / 9.0


def portrait_fit(body):
    """Native portrait drawing (face near (72, 70)) into the 128 frame, face near (64, 62)."""
    return '<g transform="scale(%.4f)">%s</g>' % (PORTRAIT_S, body)


def portrait_pt(x, y):
    return (rnd(x * PORTRAIT_S), rnd(y * PORTRAIT_S))
