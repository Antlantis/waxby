"""The WAXBY wordmark, 1024 x 400, every letter a path (ThorVG draws no <text>).

The letters are blackletter-flavored: each is a union of broad-nib strokes,
parallelograms whose ends are cut along one pen angle, with diamond serifs,
a spike and wax drips, unioned into one path per letter (nonzero winding)
so it takes one silhouette, one cel band and one sticker rim. The A wears a
lit candle on its apex, the way Waxby does (static art here, unlike the
game's flame). Letters are designed 240 units tall and set at SCALE.
"""
import math

import kit
from kit import Part, ell, pth, shp
from common import (Ctx, RIM, GOLD, GOLD_SH, GOLD_LINE, WAX, WAX_SH, WAX_LINE, FLAME, FLAME_MID, FLAME_CORE,
                    FLAME_EDGE, FLAME_LINE, svg, paint, line, dot, flame_d, glow, spec, star4, weights, CHAR_WEIGHTS)

NIB = math.radians(35)
INK = '#1a0e1c'
H = 240          # letter height
TOP = 88         # letters' top in the frame


def poly_d(pts):
    area = sum(x0 * y1 - x1 * y0 for (x0, y0), (x1, y1) in zip(pts, pts[1:] + pts[:1]))
    if area < 0:
        pts = list(reversed(pts))
    return 'M' + ' L'.join('%.1f %.1f' % p for p in pts) + ' Z'


def stroke(p0, p1, t):
    """A broad-nib stroke from p0 to p1, t thick, its ends cut along the pen angle."""
    (x0, y0), (x1, y1) = p0, p1
    dx, dy = x1 - x0, y1 - y0
    ln = math.hypot(dx, dy)
    dx, dy = dx / ln, dy / ln
    nx, ny = -dy, dx
    cx, cy = math.cos(NIB), -math.sin(NIB)
    dot_cn = cx * nx + cy * ny
    if abs(dot_cn) < 0.4:
        cx, cy, dot_cn = nx, ny, 1.0
    s = t / (2 * dot_cn)
    return poly_d([(x0 + s * cx, y0 + s * cy), (x1 + s * cx, y1 + s * cy), (x1 - s * cx, y1 - s * cy), (x0 - s * cx, y0 - s * cy)])


def diamond(x, y, w, h):
    return poly_d([(x, y - h / 2), (x + w / 2, y), (x, y + h / 2), (x - w / 2, y)])


def drip(x, y0, w, ln):
    """A wax drip hanging from y0, w wide, ln long, with a round bulb."""
    a = w / 2.0
    return ('M%.1f %.1f L%.1f %.1f L%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z' % (
        x - a, y0 - 6, x + a, y0 - 6, x + a, y0 + ln,
        x + a, y0 + ln + a * 1.5, x - a, y0 + ln + a * 1.5, x - a, y0 + ln,
        x - a, y0 + ln, x - a, y0 + ln, x - a, y0 + ln))


LETTERS = {
    'W': dict(w=300, parts=[
        ('s', (22, 10), (90, 232), 64), ('s', (90, 232), (150, 56), 32), ('s', (150, 56), (214, 232), 64),
        ('s', (214, 232), (284, 10), 32),
        ('d', 18, 8, 34, 26), ('d', 286, 6, 26, 22), ('p', [(141, 66), (150, 20), (159, 66)]),
        ('r', 86, 238, 18, 15), ('r', 222, 238, 14, 10)]),
    'A': dict(w=232, parts=[
        ('s', (24, 234), (100, 30), 34), ('s', (106, 26), (206, 234), 66), ('s', (56, 152), (172, 152), 30),
        ('p', [(80, 40), (86, 14), (128, 14), (134, 40)]),
        ('d', 22, 236, 34, 22), ('d', 212, 236, 36, 24), ('r', 204, 240, 16, 15), ('r', 128, 164, 12, 12)]),
    'X': dict(w=222, parts=[
        ('s', (26, 12), (196, 234), 64), ('s', (194, 14), (28, 232), 32),
        ('d', 22, 8, 32, 24), ('d', 198, 10, 26, 20), ('d', 24, 236, 30, 22), ('d', 202, 238, 34, 24),
        ('r', 190, 242, 16, 14), ('r', 36, 240, 12, 10), ('r', 108, 138, 12, 16)]),
    'B': dict(w=204, parts=[
        ('s', (40, 6), (40, 234), 66), ('s', (60, 16), (138, 18), 36), ('s', (138, 18), (168, 60), 42),
        ('s', (168, 60), (134, 110), 40), ('s', (134, 110), (66, 116), 32), ('s', (72, 118), (154, 120), 36),
        ('s', (154, 120), (188, 174), 48), ('s', (188, 174), (152, 228), 46), ('s', (152, 228), (62, 232), 38),
        ('d', 40, 2, 36, 26), ('r', 40, 240, 18, 14), ('r', 150, 238, 14, 14)]),
    'Y': dict(w=222, parts=[
        ('s', (20, 12), (112, 134), 64), ('s', (204, 12), (112, 134), 32), ('s', (112, 120), (112, 234), 62),
        ('d', 18, 8, 32, 24), ('d', 206, 8, 26, 20), ('r', 112, 240, 20, 15), ('r', 66, 92, 12, 14)]),
}
SCALE = 0.78
LAYOUT = [('W', 50), ('A', 274), ('X', 454), ('B', 636), ('Y', 800)]
TOP = 158        # the letters' top in the frame (design y 0)


def letter_d(ch, ox, oy, k=SCALE):
    subs = []
    for p in LETTERS[ch]['parts']:
        kind = p[0]
        if kind == 's':
            (x0, y0), (x1, y1), t = p[1], p[2], p[3]
            subs.append(stroke((ox + x0 * k, oy + y0 * k), (ox + x1 * k, oy + y1 * k), t * k))
        elif kind == 'd':
            subs.append(diamond(ox + p[1] * k, oy + p[2] * k, p[3] * k, p[4] * k))
        elif kind == 'p':
            subs.append(poly_d([(ox + x * k, oy + y * k) for x, y in p[1]]))
        elif kind == 'r':
            subs.append(drip(ox + p[1] * k, oy + p[2] * k, p[3] * k, p[4] * k))
    return ' '.join(subs)


def candle_parts(ctx, cx, top, bottom, w):
    """The candle on the A: a wax stub with drips down its front, in a gold
    dish that sits on the letter's flat apex."""
    x0, x1 = cx - w / 2.0, cx + w / 2.0
    P = []
    P.append(Part('fill', pth('M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (x0, bottom, x0, top + 8, x1, top + 8, x1, bottom)),
                  fill=WAX, shade=WAX_SH, off=(-8, 0), line=INK,
                  hl=spec(x0 + 9, (top + bottom) / 2 + 6, 3.4, 12, rot=0, op=0.75)))
    cap = ('M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f L%.1f %.1f '
           'C%.1f %.1f %.1f %.1f %.1f %.1f L%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f L%.1f %.1f '
           'C%.1f %.1f %.1f %.1f %.1f %.1f L%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z') % (
        x0 - 3, top + 10, x0 - 3, top - 2, cx - 14, top - 5, cx, top - 5,
        cx + 14, top - 5, x1 + 3, top - 2, x1 + 3, top + 10,
        x1 + 3, top + 26,
        x1 + 3, top + 34, x1 - 8, top + 34, x1 - 8, top + 26,
        x1 - 8, top + 18,
        x1 - 12, top + 14, x1 - 18, top + 14, x1 - 20, top + 20,
        x1 - 20, top + 40,
        x1 - 20, top + 50, x1 - 32, top + 50, x1 - 32, top + 40,
        x1 - 32, top + 20,
        x1 - 36, top + 15, x0 + 8, top + 15, x0 + 6, top + 22)
    well = '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="4.4" fill="%s"/>' % (cx, top + 3, w * 0.36, WAX_SH)
    P.append(Part('fill', pth(cap), fill='#fffaec', shade='#eadfc0', off=(-3, -2), line='#b89c6c', lw=2.4, over=well,
                  hl=spec(x1 - 26, top + 34, 1.8, 6, rot=0, op=0.9)))
    P.append(Part('fill', pth('M%.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f Z' % (
        cx - 38, bottom - 12, cx + 38, bottom - 12, cx + 36, bottom + 5, cx + 24, bottom + 6,
        cx - 24, bottom + 6, cx - 36, bottom + 5, cx - 38, bottom - 12)),
        fill=GOLD, shade=GOLD_SH, off=(-5, -5), line=INK,
        over=line('M%.1f %.1f L%.1f %.1f' % (cx - 32, bottom - 6, cx + 32, bottom - 6), '#ffe48a', 4, op=0.9)))
    return P


def logo_svg():
    ctx = Ctx('lg')
    weights(18, 14, 5, 3)
    fill = ctx.lingrad([(0, '#fff8e2'), (0.45, '#ffe6a0'), (0.75, '#f2c054'), (1, '#dc9a30')],
                       x1=0, y1=TOP, x2=0, y2=TOP + H * SCALE + 24, units='userSpaceOnUse')
    P = []
    for ch, ox in LAYOUT:
        P.append(Part('fill', pth(letter_d(ch, ox, TOP)), fill=fill, shade='#b8741e', off=(-8, -9), lw=0))
    # the candle stands in its dish on the A's flat apex
    a_x = dict(LAYOUT)['A']
    cx = a_x + 107 * SCALE
    bottom = TOP + 14 * SCALE + 2
    top, w = bottom - 64, 48
    P += candle_parts(ctx, cx, top, bottom, w)
    pal = dict(line=INK, rim=RIM, base='#fff0c0', shade='#b8741e')
    body = paint(ctx, P, pal)
    # a soft dark drop shadow: the rim layer again, dark and offset
    shadow_pal = dict(pal, rim='#050208')
    shadow = paint(ctx, P, shadow_pal).split('</g>')[0] + '</g>'
    shadow = '<g transform="translate(8 12)" opacity="0.7">%s</g>' % shadow
    # the lit wick, the flame and its glow
    wick = line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (cx, top + 2, cx - 3, top - 8, cx + 1, top - 16), '#241a14', 6)
    fl_by, fl_h, fl_w = top - 7, 76, 50
    hg = ctx.radgrad([(0, FLAME, 0.5), (0.45, FLAME, 0.2), (1, FLAME, 0)])
    hy = fl_by - fl_h * 0.45
    halo = '<ellipse cx="%.1f" cy="%.1f" rx="190" ry="%.1f" fill="%s"/>' % (cx + 2, hy + 20, hy + 18, hg)
    fd = flame_d(cx, fl_by, fl_w, fl_h, 6)
    flame_art = ('<path d="%s" fill="%s" stroke="%s" stroke-width="%s" stroke-linejoin="round"/>' % (fd, RIM, RIM, 18 + 14)
                 + '<path d="%s" fill="%s" stroke="%s" stroke-width="18" stroke-linejoin="round"/>' % (fd, INK, INK)
                 + '<path d="%s" fill="%s"/>' % (fd, FLAME_EDGE)
                 + '<path d="%s" fill="%s"/>' % (flame_d(cx - 1, fl_by - 2, fl_w * 0.84, fl_h * 0.86, 5), FLAME)
                 + '<path d="%s" fill="%s"/>' % (flame_d(cx - 1, fl_by - 4, fl_w * 0.58, fl_h * 0.6, 3), FLAME_MID)
                 + '<path d="%s" fill="%s"/>' % (flame_d(cx - 1, fl_by - 6, fl_w * 0.32, fl_h * 0.34, 1.4), FLAME_CORE)
                 + spec(cx - 14, fl_by - 50, 3.6, 12, rot=16, op=0.7, col='#fff8e0'))
    # sparkles in the candlelight
    sparks = (star4(cx + 80, 52, 12, FLAME_CORE, 0.95) + star4(cx - 96, 84, 8, FLAME_CORE, 0.85)
              + star4(968, 118, 9, '#fff2c8', 0.8) + star4(40, 130, 7, '#fff2c8', 0.75))
    weights(*CHAR_WEIGHTS)
    return svg(ctx, halo + shadow + body + wick + flame_art + sparks, 1024, 400, px=1)


def files():
    return {'art/ui/logo.svg': logo_svg()}
