"""Drawing kit (from HAUL's Chibi Critters): SVG defs, shapes, the cel-shaded
Part renderer and the face pieces (eyes, brows, mouths, blush, tears, sparkles).

The face pieces are sized for HAUL's 150 x 140 box; WICK draws them at twice
its frame size and halves them (see common.py). Line weights are module
globals so each WICK frame can set its own (common.weights). Godot imports
SVG with ThorVG: gradients and clip paths work, <text> and filters do not, so
nothing here uses them. A <g> inside a <clipPath> is dropped by ThorVG: put
transforms on the clip shapes themselves.
"""
import math

OUT_W = 8.0     # silhouette stroke (the outer line is OUT_W / 2 outside the shape)
RIM_W = 5.0     # sticker rim (RIM_W / 2 outside the outer line); 0 turns it off
IN_W = 2.6      # inner line weight
DETAIL_W = 2.0  # fine detail lines (stripes, veins)

TEAR, TEAR_LINE = '#bfe8ff', '#3a6a9a'
TONGUE = '#ff7f7f'


class Ctx:
    """Collects the <defs> of one SVG document and hands out unique ids."""

    def __init__(self, prefix='a'):
        self.defs = []
        self.n = 0
        self.prefix = prefix

    def uid(self, tag='i'):
        self.n += 1
        return '%s%s%d' % (self.prefix, tag, self.n)

    def _stops(self, stops):
        out = []
        for t in stops:
            o, c = t[0], t[1]
            op = ' stop-opacity="%s"' % t[2] if len(t) > 2 else ''
            out.append('<stop offset="%s" stop-color="%s"%s/>' % (o, c, op))
        return ''.join(out)

    def lingrad(self, stops, x1=0, y1=0, x2=0, y2=1, units='objectBoundingBox'):
        gid = self.uid('g')
        self.defs.append('<linearGradient id="%s" x1="%s" y1="%s" x2="%s" y2="%s" gradientUnits="%s">%s</linearGradient>'
                         % (gid, x1, y1, x2, y2, units, self._stops(stops)))
        return 'url(#%s)' % gid

    def radgrad(self, stops, cx=0.5, cy=0.5, r=0.5, units='objectBoundingBox'):
        gid = self.uid('r')
        self.defs.append('<radialGradient id="%s" cx="%s" cy="%s" r="%s" gradientUnits="%s">%s</radialGradient>'
                         % (gid, cx, cy, r, units, self._stops(stops)))
        return 'url(#%s)' % gid

    def clip(self, inner):
        cid = self.uid('c')
        self.defs.append('<clipPath id="%s">%s</clipPath>' % (cid, inner))
        return 'url(#%s)' % cid


def doc(ctx, body, size=512):
    """A square SVG document around body (already placed in 0..size)."""
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d">\n'
            '<defs>%s</defs>\n%s\n</svg>\n') % (size, size, size, size, ''.join(ctx.defs), body)


# ---------------------------------------------------------------- shapes
# A shape is a template with an {a} slot for its attributes, so one outline
# can be painted several times (rim, silhouette, fill, clip).

def ell(cx, cy, rx, ry, rot=0):
    t = (' transform="rotate(%s %s %s)"' % (rot, cx, cy)) if rot else ''
    return '<ellipse cx="%s" cy="%s" rx="%s" ry="%s"%s {a}/>' % (cx, cy, rx, ry, t)


def pth(d, move=None):
    """A path shape; move (dx, dy) shifts it without touching the path data."""
    t = ' transform="translate(%s %s)"' % move if move else ''
    return '<path d="%s"%s {a}/>' % (d, t)


def shp(tpl, **attrs):
    a = ' '.join('%s="%s"' % (k.replace('_', '-'), v) for k, v in attrs.items())
    return tpl.replace('{a}', a)


class Part:
    """kind 'fill': a closed shape, cel-shaded: its base color offset by off
    over the shade color, clipped to the shape, so the shadow is one hard band
    on the lower right. kind 'limb': an open path drawn as an outlined stroke.
    over and under are raw SVG drawn right after and right before the part.
    rim False leaves the part out of the sticker rim (it still gets the
    silhouette line)."""

    def __init__(self, kind, tpl, fill=None, shade=None, off=(-4, -6), width=5.0,
                 sil=True, over='', under='', hl='', line=None, lw=None, no_shade=False, rim=True):
        self.kind, self.tpl = kind, tpl
        self.fill, self.shade = fill, shade
        self.off, self.width, self.sil = off, width, sil
        self.over, self.under, self.hl = over, under, hl
        self.line, self.lw, self.no_shade = line, lw, no_shade
        self.rim = rim


def render_parts(ctx, parts, pal):
    rim, sil, paint = [], [], []
    for p in parts:
        if not p.sil:
            continue
        col = p.line or pal['line']
        do_rim = RIM_W > 0 and p.rim
        if p.kind == 'fill':
            if do_rim:
                rim.append(shp(p.tpl, fill=pal['rim'], stroke=pal['rim'], stroke_width=OUT_W + RIM_W,
                               stroke_linejoin='round'))
            sil.append(shp(p.tpl, fill=col, stroke=col, stroke_width=OUT_W, stroke_linejoin='round'))
        else:
            if do_rim:
                rim.append(shp(p.tpl, fill='none', stroke=pal['rim'], stroke_width=p.width + OUT_W + RIM_W,
                               stroke_linecap='round', stroke_linejoin='round'))
            sil.append(shp(p.tpl, fill='none', stroke=col, stroke_width=p.width + OUT_W,
                           stroke_linecap='round', stroke_linejoin='round'))
    for p in parts:
        paint.append(p.under)
        col = p.line or pal['line']
        lw = p.lw if p.lw is not None else IN_W
        fill = p.fill or pal['base']
        if p.kind == 'fill':
            if p.no_shade:
                paint.append(shp(p.tpl, fill=fill) + p.hl)
            else:
                cid = ctx.clip(shp(p.tpl))
                dx, dy = p.off
                paint.append('<g clip-path="%s">%s<g transform="translate(%s %s)">%s</g>%s</g>' % (
                    cid, shp(p.tpl, fill=p.shade or pal['shade']), dx, dy, shp(p.tpl, fill=fill), p.hl))
            if lw > 0:
                paint.append(shp(p.tpl, fill='none', stroke=col, stroke_width=lw, stroke_linejoin='round'))
        else:
            paint.append(shp(p.tpl, fill='none', stroke=col, stroke_width=p.width + 2 * lw,
                             stroke_linecap='round', stroke_linejoin='round'))
            paint.append(shp(p.tpl, fill='none', stroke=fill, stroke_width=p.width,
                             stroke_linecap='round', stroke_linejoin='round'))
        paint.append(p.over)
    return '<g>%s</g><g>%s</g><g>%s</g>' % (''.join(rim), ''.join(sil), ''.join(paint))


# ---------------------------------------------------------------- body pieces

def head_tpl(cx, cy, w, h, squish=0.0):
    """The mochi head: a flatter bottom and full cheeks."""
    a, b = w / 2.0, h / 2.0
    d = ('M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f '
         'C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z') % (
        cx, cy - b,
        cx + a * 0.62, cy - b, cx + a, cy - b * 0.55, cx + a, cy + b * 0.05,
        cx + a, cy + b * (0.62 + squish), cx + a * 0.6, cy + b, cx, cy + b,
        cx - a * 0.6, cy + b, cx - a, cy + b * (0.62 + squish), cx - a, cy + b * 0.05,
        cx - a, cy - b * 0.55, cx - a * 0.62, cy - b, cx, cy - b)
    return pth(d)


def gaster_over(pal, cx, cy, rx, ry, rot):
    """Segment stripes and a gloss on the abdomen."""
    s = '<g transform="rotate(%s %s %s)">' % (rot, cx, cy)
    for k in (0.1, 0.48):
        x = cx + rx * (k - 0.1) - rx * 0.05
        s += '<path d="M%.1f %.1f Q%.1f %.1f %.1f %.1f" fill="none" stroke="%s" stroke-width="%.1f" stroke-linecap="round" opacity="0.9"/>' % (
            x + 4, cy - ry * 0.86, x - rx * 0.16, cy, x + 4, cy + ry * 0.86, pal['line'], DETAIL_W)
    s += '</g>'
    return s + spec(cx - rx * 0.35, cy - ry * 0.45, rx * 0.26, ry * 0.16, rot=-20, op=0.8)


def shadow_blob(cx, cy, rx, ry=4.5, op=0.22):
    return '<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="#2a1a10" opacity="%s"/>' % (cx, cy, rx, ry, op)


def limb(d, width=5.2, fill=None, sil=True):
    return Part('limb', pth(d), width=width, fill=fill, sil=sil)


def foot(x, y, r=4.6, fill=None):
    return Part('fill', ell(x, y, r * 1.25, r * 0.9), fill=fill, off=(-1.5, -2))


def antenna(x0, y0, kx, ky, tx, ty):
    """An elbowed antenna from (x0, y0) through the knee to a bulb tip."""
    return [limb('M%s %s Q%s %s %s %s' % (x0, y0, (x0 + kx) / 2 - 3, (y0 + ky) / 2, kx, ky) +
                 ' Q%s %s %s %s' % ((kx + tx) / 2, (ky + ty) / 2 - 3, tx, ty), width=3.6),
            Part('fill', ell(tx, ty, 5.4, 5.0), off=(-1.5, -2.2), hl=spec(tx - 1.8, ty - 1.8, 1.8, 1.2, op=0.9))]


def spec(cx, cy, rx, ry, rot=-30, op=0.85, col='#ffffff'):
    """A specular pop."""
    return '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s" opacity="%s" transform="rotate(%s %.1f %.1f)"/>' % (
        cx, cy, rx, ry, col, op, rot, cx, cy)


def star4(x, y, r, col, op=1.0):
    k = r * 0.28
    d = 'M%.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f Z' % (
        x, y - r, x + k, y - k, x + r, y, x + k, y + k, x, y + r, x - k, y + k, x - r, y, x - k, y - k, x, y - r)
    return '<path d="%s" fill="%s" opacity="%s"/>' % (d, col, op)


def sparkle(x, y, r, line, fill='#ffffff'):
    """A four-point sparkle with an outline, readable on light and dark."""
    return star4(x, y, r, line) + star4(x, y, r * 0.72, fill)


def star5(x, y, r, fill, line, lw=1.6):
    pts = []
    for k in range(10):
        a = -math.pi / 2 + k * math.pi / 5
        rr = r if k % 2 == 0 else r * 0.45
        pts.append('%.1f %.1f' % (x + rr * math.cos(a), y + rr * math.sin(a)))
    return '<path d="M%sZ" fill="%s" stroke="%s" stroke-width="%s" stroke-linejoin="round"/>' % (' L'.join(pts), fill, line, lw)


def heart(x, y, s, fill, line, rot=0):
    return ('<g transform="translate(%s %s) rotate(%s) scale(%s)"><path d="M0 -3 C-2 -8 -9 -7 -9 -2 C-9 3 -3 6 0 9 '
            'C3 6 9 3 9 -2 C9 -7 2 -8 0 -3 Z" fill="%s" stroke="%s" stroke-width="1.8"/>'
            '<ellipse cx="-4" cy="-2.5" rx="1.8" ry="1.2" fill="#ffffff"/></g>') % (x, y, rot, s, fill, line)


# ---------------------------------------------------------------- face pieces

def _oval(x, y, a, b):
    """The anime eye shape: a tall rounded oval, a touch squarer at the bottom."""
    return ('M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f '
            'L%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z') % (
        x - a, y - b * 0.15,
        x - a, y - b * 0.85, x - a * 0.55, y - b, x, y - b,
        x + a * 0.55, y - b, x + a, y - b * 0.85, x + a, y - b * 0.15,
        x + a, y + b * 0.3,
        x + a, y + b * 0.85, x + a * 0.55, y + b, x, y + b,
        x - a * 0.55, y + b, x - a, y + b * 0.85, x - a, y + b * 0.3)


def eye(ctx, cx, cy, w, h, pal, look=(0, 0), mood='open', lid=0.0, star=False):
    """An anime eye: a dark oval, gradient iris, pupil, two highlights and a
    heavy upper lash line. mood 'happy' is a closed ^ arc; star (sparkle
    eyes) makes the big highlight bigger and adds a four-point star; lid cuts
    the top flat (determined)."""
    line = pal['line']
    if mood == 'happy':
        d = 'M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (cx - w / 2, cy + h * 0.12, cx, cy - h * 0.42, cx + w / 2, cy + h * 0.12)
        s = '<path d="%s" fill="none" stroke="%s" stroke-width="4.4" stroke-linecap="round"/>' % (d, line)
        return s + '<path d="M%.1f %.1f l%.1f %.1f" stroke="%s" stroke-width="2.4" stroke-linecap="round"/>' % (
            cx + w / 2 - 0.5, cy + h * 0.08, w * 0.22, -h * 0.02, line)
    hw, hh = w / 2.0, h / 2.0
    lx, ly = look
    outer = _oval(cx, cy, hw, hh)
    iris = _oval(cx + lx * 0.4, cy + ly * 0.4 + 0.6, hw - 1.6, hh - 1.8)
    grad = ctx.lingrad([(0, pal['iris0']), (0.38, pal['iris1']), (1, pal['iris2'])])
    cid = ctx.clip('<path d="%s"/>' % outer)
    s = '<path d="%s" fill="%s"/>' % (outer, line)
    s += '<g clip-path="%s">' % cid
    s += '<path d="%s" fill="%s"/>' % (iris, grad)
    s += '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s" opacity="0.85"/>' % (
        cx + lx * 0.7, cy + ly * 0.7 - hh * 0.05, hw * 0.42, hh * 0.44, pal['iris0'])
    s += '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s" opacity="0.55"/>' % (
        cx + lx * 0.4, cy + hh * 0.72, hw * 0.7, hh * 0.25, pal['iris2'])
    s += '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s" opacity="0.6"/>' % (
        cx, cy - hh * 1.05, hw * 1.3, hh * 0.45, line)
    s += '</g>'
    hx, hy = cx - hw * 0.28 + lx * 0.3, cy - hh * 0.32 + ly * 0.3
    if star:
        # sparkle eyes: a bigger shine than an idle eye's, and a star in it
        s += '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="#ffffff" transform="rotate(-25 %.1f %.1f)"/>' % (
            hx, hy, hw * 0.5, hh * 0.38, hx, hy)
        s += star4(cx + hw * 0.28 + lx * 0.3, cy + hh * 0.08 + ly * 0.3, hw * 0.62, '#ffffff')
    else:
        s += '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="#ffffff" transform="rotate(-25 %.1f %.1f)"/>' % (
            hx - hw * 0.02, hy - hh * 0.04, hw * 0.4, hh * 0.3, hx - hw * 0.02, hy - hh * 0.04)
    s += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="#ffffff"/>' % (cx + hw * 0.34 + lx * 0.3, cy + hh * 0.42 + ly * 0.3, hw * 0.19)
    s += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="#ffffff" opacity="0.8"/>' % (cx - hw * 0.02 + lx * 0.3, cy + hh * 0.5 + ly * 0.3, hw * 0.1)
    if lid > 0:
        top, cut = cy - hh - 3, cy - hh + h * lid
        s += '<path d="M%.1f %.1f L%.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f Z" fill="%s"/>' % (
            cx - hw - 2, top, cx + hw + 2, top, cx + hw + 2, cut - 1.5, cx, cut + 2.5, cx - hw - 2, cut - 1.5, pal['base'])
        s += '<path d="M%.1f %.1f Q%.1f %.1f %.1f %.1f" fill="none" stroke="%s" stroke-width="3.2" stroke-linecap="round"/>' % (
            cx - hw - 1, cut - 1.2, cx, cut + 2.8, cx + hw + 1.5, cut - 1.8, line)
    else:
        d = 'M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f L%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z' % (
            cx - hw - 0.8, cy - hh * 0.35,
            cx - hw - 0.5, cy - hh * 1.22, cx + hw * 0.6, cy - hh * 1.25, cx + hw + 3.2, cy - hh * 0.72,
            cx + hw + 0.4, cy - hh * 0.5,
            cx + hw * 0.4, cy - hh * 0.98, cx - hw * 0.4, cy - hh * 0.98, cx - hw + 0.8, cy - hh * 0.35)
        s += '<path d="%s" fill="%s"/>' % (d, line)
    return s


def blush(cx, cy, pal, rx=7.5, ry=4.2, lines=True, op=0.62):
    s = '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s" opacity="%s"/>' % (cx, cy, rx, ry, pal['blush'], op)
    if lines:
        for i in (-1, 0, 1):
            x = cx + i * rx * 0.48
            s += '<path d="M%.1f %.1f l%.1f %.1f" stroke="#ffffff" stroke-width="1.3" stroke-linecap="round" opacity="0.85"/>' % (
                x + 1.2, cy - ry * 0.55, -2.4, ry * 1.1)
    return s


def brow(x1, y1, x2, y2, pal, w=3.4, bend=0):
    mx, my = (x1 + x2) / 2, (y1 + y2) / 2 + bend
    return '<path d="M%.1f %.1f Q%.1f %.1f %.1f %.1f" fill="none" stroke="%s" stroke-width="%.1f" stroke-linecap="round"/>' % (
        x1, y1, mx, my, x2, y2, pal['line'], w)


def brow_fill(x1, y1, x2, y2, pal, thick=3.6, bend=-2):
    """A tapered, filled brow from (x1, y1) to (x2, y2), bowed by bend."""
    mx, my = (x1 + x2) / 2, (y1 + y2) / 2 + bend
    return '<path d="M%.1f %.1f Q%.1f %.1f %.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f Z" fill="%s"/>' % (
        x1, y1, mx, my, x2, y2, x2 + 0.6, y2 + thick * 0.9, mx, my + thick, x1 + 0.4, y1 + thick * 0.8, pal['line'])


def eager_brows(eyes, pal, lift=6, w=3.2):
    """Arched brows lifted over both eyes (picked, scored)."""
    s = ''
    for cx, cy, ew, eh in eyes:
        y = cy - eh / 2 - lift
        s += brow(cx - ew / 2 - 1, y + 1, cx + ew / 2 + 1, y, pal, w=w, bend=-4.5)
    return s


def worried_brows(eyes, pal, lift=5, thick=3.6):
    """Brows with their inner ends raised (sad). The first eye is on the left."""
    (ax, ay, aw, ah), (bx, by, bw, bh) = eyes
    ya, yb = ay - ah / 2 - lift, by - bh / 2 - lift
    return (brow_fill(ax - aw / 2 - 2, ya + 3, ax + aw / 2 + 1.5, ya - 4.5, pal, thick, bend=0.5)
            + brow_fill(bx - bw / 2 - 1, yb - 4.5, bx + bw / 2 + 2, yb + 3, pal, thick, bend=0.5))


def mouth_open(x, y, w, h, pal, teeth=False):
    """A D-shaped open mouth, flat top at y, with a tongue (and a row of teeth)."""
    L = pal['line']
    a = w / 2.0
    s = '<path d="M%.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f Z" fill="%s"/>' % (
        x - a, y, x, y - 1.6, x + a, y, x + a - 0.6, y + h, x, y + h, x - a + 0.6, y + h, x - a, y, L)
    s += '<path d="M%.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f Z" fill="%s"/>' % (
        x - a * 0.66, y + h * 0.68, x, y + h * 0.3, x + a * 0.66, y + h * 0.68,
        x + a * 0.42, y + h - 1.2, x, y + h - 1.2, x - a * 0.42, y + h - 1.2, x - a * 0.66, y + h * 0.68, TONGUE)
    if teeth:
        s += '<path d="M%.1f %.1f Q%.1f %.1f %.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f Z" fill="#ffffff"/>' % (
            x - a + 2, y + 0.7, x, y - 0.9, x + a - 2, y + 0.7, x + a - 2.6, y + 3.2, x, y + 1.9, x - a + 2.6, y + 3.2)
    return s


def mouth_frown(x, y, w, pal):
    """A small wobbly frown (sad)."""
    a = w / 2.0
    return ('<path d="M%.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f" fill="none" stroke="%s" stroke-width="2.8" '
            'stroke-linecap="round" stroke-linejoin="round"/>') % (
        x - a, y + 2.2, x - a * 0.5, y - 2.6, x, y - 0.4, x + a * 0.5, y - 2.6, x + a, y + 2.2, pal['line'])


def sweat(x, y, s=1.0, rot=0):
    d = 'M0 -7 C2.5 -3 5 0 5 3 C5 6 2.5 8 0 8 C-2.5 8 -5 6 -5 3 C-5 0 -2.5 -3 0 -7 Z'
    return ('<g transform="translate(%s %s) rotate(%s) scale(%s)"><path d="%s" fill="#dff4ff" stroke="%s" stroke-width="1.6"/>'
            '<ellipse cx="-1.8" cy="2.5" rx="1.2" ry="2" fill="#ffffff"/></g>') % (x, y, rot, s, d, TEAR_LINE)


def tears(eyes, streams=True):
    """Welling tears along the bottom of each eye and, with streams, a
    tear running down each cheek from the eye's outer-lower corner."""
    s = ''
    for i, (cx, cy, w, h) in enumerate(eyes):
        a, y = w / 2.0 - 0.5, cy + h * 0.3
        s += '<path d="M%.1f %.1f Q%.1f %.1f %.1f %.1f" fill="none" stroke="%s" stroke-width="5.2" stroke-linecap="round"/>' % (
            cx - a, y - 1.6, cx, y + 3.4, cx + a, y - 1.6, TEAR_LINE)
        s += '<path d="M%.1f %.1f Q%.1f %.1f %.1f %.1f" fill="none" stroke="%s" stroke-width="3" stroke-linecap="round"/>' % (
            cx - a, y - 1.6, cx, y + 3.4, cx + a, y - 1.6, TEAR)
        if streams:
            sx = cx - a * 0.55 if i == 0 else cx + a * 0.45
            sy = y + 2
            d = 'M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f' % (sx, sy, sx - 1.6, sy + 4, sx + 1.2, sy + 8, sx - 0.4, sy + 12)
            s += '<path d="%s" fill="none" stroke="%s" stroke-width="5.2" stroke-linecap="round"/>' % (d, TEAR_LINE)
            s += '<path d="%s" fill="none" stroke="%s" stroke-width="3" stroke-linecap="round"/>' % (d, TEAR)
            s += drop(sx - 0.4, sy + 15.5, 0.62)
    return s


def drop(x, y, k=1.0):
    """A falling teardrop centered at (x, y)."""
    return ('<g transform="translate(%s %s) scale(%s)"><path d="M0 -8 C3 -3.5 5.6 -0.5 5.6 2.8 C5.6 6 3.2 8 0 8 '
            'C-3.2 8 -5.6 6 -5.6 2.8 C-5.6 -0.5 -3 -3.5 0 -8 Z" fill="%s" stroke="%s" stroke-width="2.6"/>'
            '<ellipse cx="-1.8" cy="3" rx="1.4" ry="2.2" fill="#ffffff"/></g>') % (x, y, k, TEAR, TEAR_LINE)


def pop(x, y, r_in, r_out, fill, line, a0=-200, a1=40, step=13):
    """A manga starburst fanning out from (x, y) over the arc a0..a1 degrees,
    a spike every step degrees, closed through its center (which the head
    hides), outlined."""
    pts = ['%.1f %.1f' % (x, y)]
    k = 0
    a = a0
    while a <= a1 + 0.01:
        r = r_in if k % 2 else (r_out if k % 4 == 0 else r_out * 0.84)
        t = math.radians(a)
        pts.append('%.1f %.1f' % (x + r * math.cos(t), y + r * math.sin(t)))
        a += step / 2.0
        k += 1
    return '<path d="M%sZ" fill="%s" stroke="%s" stroke-width="2.6" stroke-linejoin="round"/>' % (' L'.join(pts), fill, line)
