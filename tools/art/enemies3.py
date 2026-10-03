"""WAXBY v3's World 3 and World 4 monsters, one SVG per frame on the 128 x 128
frame (2 units = 1 world px, sprite scale 0.25), facing right, in the chibi
cel kit of enemies.py and enemies2.py (the warm sticker rim, the ink line,
one hard shade band). Walkers, and the Creepbone, stand with their feet on
(64, 122) (contract §13); the Spurwheel and fliers are anchored on their
middle (64, 64).

World 3, the Bone Orchard (family: bone ivory, bark, moss, spore-yellow eyes)
  Rootling      rootling_mound, _swell, _pop, _dazed, _walk1, _walk2, _hit
  Weepcap       weepcap_idle, _inhale, _puff, _hit, _die
  Rattlehound   hound_prowl1, _prowl2, _howl, _run1, _run2, _crouch, _pounce, _land, _pant, _hit
                (the green lantern-glint burns in one socket; the other is dark)
  Creepbone     creep_crawl1, _crawl2, _coil, _lunge, _fall, _hit   (drawn head-up with its tail end
                on the feet line (64, 122) and its lane along x 64: code flips it to crawl down and turns
                it 90 deg on a flat lane or the floor; no stars in creep_fall, code draws them upright)
World 4, the Frozen Carillon (family: brass, ice, navy, clock-lamp cyan eyes, frost on the shoulders)
  Tickwind      tick_march1, _march2, _wind, _charge, _dizzy, _hit
  Spurwheel     spur_roll, _catch, _hit: the cog, which code turns about its hub (64, 64) as it rolls, so
                nothing in it points anywhere (no motion arc, trail or sparks: code draws the frost trail
                and the sparks at the contact point); spur_face, _face_catch, _face_hit: the hub face,
                drawn upright over the turning cog at the same anchor (it covers the cog's own hub face).
                The grinder rim e0602a is the Spurwheel's alone.
  Frostbuckle   buckle_idle, _walk1, _walk2, _raise, _stomp, _slam, _thawed, _hit, and buckle_shell,
                the rime overlay drawn over any frame while the rime holds (at the frame's `shell`
                offset)
  Hoarowl       owl_body (the owl on its bracket, headless), the heads owl_look_l, _look_c, _look_r,
                _screech, _hit (drawn where they sit on the body: draw owl_body, then the head, at the
                same anchor), and owl_broken (the whole owl, knocked off)

Tell accents (spec §11.5 rule 3): each world's accent (W3 c8d46a, W4 e8fcff, W5 f8f0ff, W6 e0e0ff) is
drawn only on TELL_FRAMES. W4's and W5's accents are near-white, so their other frames draw frost, ice
and glass off it (W4 frost c8e4f4, W5 lilac-grey prism and grey-blue cloud) and their shines, motion
lines and sparkles in the world's shine colour (W4 d0eaf6, W5 d4ecff) instead of white.

points_monsters3.json (frame units; world offset from the anchor = (p - anchor) / 2, mirrored
with the facing, as elites.frame_point does): per frame `eyes` (a list of the lit eyes' points,
[[x, y]] for one), `eye1` and `eye2` (each of two eyes) or `eye` (the one), `eye_mid` (the middle of
two), `eye_r` (the eye's radius), `hit` [x, y, w, h] (the body's box) and the tell anchors each kind
names. `_anchors` gives each prefix's anchor, `_tells` what each tell point is for, `_roles` which
frame shows which state, `_notes` how to hang the odd ones (the Creepbone's lane, the owl's head, the
Spurwheel's face).
Texture memory: a 256 x 256 frame is 0.33 MB with its mipmaps (the imports generate them, as v2's do);
a level loads only its own kinds' frames.
Run on its own: python3 tools/art/enemies3.py (writes under game/).
"""
import math
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import kit
from kit import Part, ell, pth, head_tpl
from enemies2 import ell_d
from common import (Ctx, RIM, svg128, paint, eye, blush, sweat, line, dot, squeeze, swirl_eye, spec, sparkle,
                    star4, mix, gx)
from enemies import glow_eye, BONE, BONE_SH, BONE_LINE, BONE_BACK, BONE_BACK_SH

# ================================================================ the kit shared by enemies3 and enemies4

POINTS = {}      # frame name -> {point: value}
FRAMES = {}      # frame name -> svg text


def fmt(p):
    return '%.2f %.2f' % (p[0], p[1])


def _corner(p):
    return len(p) > 2 and p[2] == 0


def smooth(pts, closed=True, k=1.0):
    """A Catmull-Rom curve through pts as cubic Beziers. A point given as
    (x, y, 0) is a corner (no tangent there)."""
    n = len(pts)

    def tan(i):
        if _corner(pts[i]) or (not closed and (i == 0 or i == n - 1)):
            return (0.0, 0.0)
        a, b = pts[(i - 1) % n], pts[(i + 1) % n]
        return ((b[0] - a[0]) / 6.0 * k, (b[1] - a[1]) / 6.0 * k)
    d = 'M%.2f %.2f' % (pts[0][0], pts[0][1])
    for i in range(n if closed else n - 1):
        j = (i + 1) % n
        t1, t2 = tan(i), tan(j)
        d += ' C%.2f %.2f %.2f %.2f %.2f %.2f' % (pts[i][0] + t1[0], pts[i][1] + t1[1],
                                                  pts[j][0] - t2[0], pts[j][1] - t2[1], pts[j][0], pts[j][1])
    return d + (' Z' if closed else '')


def poly(pts, closed=True):
    d = 'M' + ' L'.join(fmt(p) for p in pts)
    return d + (' Z' if closed else '')


def rot(p, deg, c=(64, 64)):
    a = math.radians(deg)
    cs, sn = math.cos(a), math.sin(a)
    x, y = p[0] - c[0], p[1] - c[1]
    q = (c[0] + x * cs - y * sn, c[1] + x * sn + y * cs)
    return q + tuple(p[2:])


def tf(pts, dx=0.0, dy=0.0, deg=0.0, c=(64, 64), sx=1.0, sy=1.0):
    """Scale about c, turn about c, then move: a list of points (corners kept)."""
    out = []
    for p in pts:
        q = (c[0] + (p[0] - c[0]) * sx, c[1] + (p[1] - c[1]) * sy) + tuple(p[2:])
        if deg:
            q = rot(q, deg, c)
        out.append((q[0] + dx, q[1] + dy) + tuple(q[2:]))
    return out


def pt(p, dx=0.0, dy=0.0, deg=0.0, c=(64, 64), sx=1.0, sy=1.0):
    return tf([p], dx, dy, deg, c, sx, sy)[0][:2]


def ring(cx, cy, rx, ry, n=16, start=-90.0, wob=None):
    """n points round an ellipse (wob(i) -> a radius factor)."""
    out = []
    for i in range(n):
        a = math.radians(start + 360.0 * i / n)
        k = wob(i) if wob else 1.0
        out.append((cx + rx * k * math.cos(a), cy + ry * k * math.sin(a)))
    return out


def blob(pts, fill, shade, off=(-2, -2), **kw):
    return Part('fill', pth(smooth(pts)), fill=fill, shade=shade, off=off, **kw)


def shard(pts, fill, shade, off=(-1, -1), **kw):
    return Part('fill', pth(poly(pts)), fill=fill, shade=shade, off=off, **kw)


def limb_part(pts, width, fill, closed=False, **kw):
    return Part('limb', pth(smooth(pts, closed=False) if len(pts) > 2 else poly(pts, closed=False)), width=width,
                fill=fill, **kw)


def ground_shadow(cx, rx, op=0.35):
    return '<ellipse cx="%.1f" cy="122.6" rx="%.1f" ry="2.2" fill="#07040a" opacity="%s"/>' % (cx, rx, op)


def motion(d, w=1.4, op=0.9):
    """White motion lines with a dark keyline, readable on any background."""
    return line(d, '#07040a', w + 1.4, op=0.6) + line(d, '#ffffff', w, op=op)


def glint(x, y, r, col='#ffffff', key='#07040a'):
    """A tell glint: a keyed four-point star with a hot centre."""
    return star4(x, y, r * 1.3, key, 0.7) + star4(x, y, r, col) + dot(x, y, r * 0.18, '#ffffff')


def dizzy_stars(cx, cy, rx=11, ry=3.4, n=3, col='#ffe28a', line_col='#2a1a10', phase=0.0):
    s = '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="none" stroke="%s" stroke-width="0.9" opacity="0.7" stroke-dasharray="2 2"/>' % (
        cx, cy, rx, ry, '#ffffff')
    for i in range(n):
        a = phase + i * 2 * math.pi / n
        s += sparkle(cx + rx * math.cos(a), cy + ry * math.sin(a), 2.6, line_col, col)
    return s


def specks(pts, col, key='#07040a', op=0.95):
    s = ''
    for x, y, r in pts:
        s += dot(x, y, r + 0.7, key, 0.55) + dot(x, y, r, col, op)
    return s


def puff(cx, cy, r, col, op=0.85, key=None):
    """A little fuzzy puff of dust or spores (raw SVG, no rim)."""
    d = smooth(ring(cx, cy, r, r * 0.86, 9, wob=lambda i: 1.0 + 0.14 * ((i * 7) % 3 - 1)))
    s = ''
    if key:
        s += '<path d="%s" fill="none" stroke="%s" stroke-width="1.6" opacity="%s"/>' % (d, key, op * 0.7)
    return s + '<path d="%s" fill="%s" opacity="%s"/>' % (d, col, op)


def hi_line(d, col='#ffffff', w=1.0, op=0.85):
    return line(d, col, w, op=op)


# The frames that show a tell: only these may use their world's tell accent (spec
# §11.5 rule 3), and only these keep pure white where their world's accent is a
# near-white (W4 e8fcff, W5 f8f0ff).
TELL_FRAMES = {'rootling_swell', 'weepcap_inhale', 'hound_crouch', 'hound_howl', 'creep_coil', 'tick_wind', 'spur_catch',
               'spur_face_catch', 'buckle_raise', 'owl_screech', 'mite_gnaw', 'gust_inhale', 'refractor_charge',
               'refractor_fire', 'pane_turn', 'pane_edge', 'hushling_crouch', 'maw_strain', 'maw_open', 'coil_head_open'}


class Fr:
    """One frame: its parts (the kit's cel renderer), raw SVG under and over
    them, and its engine points. rim: the sticker rim's colour and width.
    shift (dx, dy): the whole drawing and its points moved by that much (the
    Creepbone is drawn round its middle and moved down onto its feet).
    shine: in a world whose tell accent is a near-white, the colour the
    frame's decorative whites (shines, motion lines, sparkles) are drawn in
    instead of white, unless the frame is a tell."""

    def __init__(self, name, pal, rim_w=None, shift=None, shine=None):
        self.shine = shine
        self.name = name
        self.ctx = Ctx(re.sub('[^a-z0-9]', '', name)[:8] + 'x')
        self.P = []
        self.under = ''
        self.over = ''
        self.pal = pal
        self.rim_w = rim_w
        self.shift = shift

    def add(self, *parts):
        for p in parts:
            if isinstance(p, (list, tuple)):
                self.P.extend(p)
            else:
                self.P.append(p)
        return self

    def _mv(self, p):
        dx, dy = self.shift or (0.0, 0.0)
        return (round(p[0] + dx, 1), round(p[1] + dy, 1))

    def mark(self, eyes=None, eye_r=None, hit=None, **pts):
        """eyes: the frame's lit eyes. `eyes` in the file is always a list of
        points ([[x, y]] for one eye); eye1/eye2 (or eye) name them one by one
        and eye_mid is the middle of two."""
        d = POINTS.setdefault(self.name, {})
        if eyes:
            es = [self._mv(e) for e in eyes]
            d['eyes'] = [list(e) for e in es]
            if len(es) == 1:
                d['eye'] = es[0]
            else:
                d['eye1'], d['eye2'] = es[0], es[1]
                d['eye_mid'] = (round((es[0][0] + es[1][0]) / 2, 1), round((es[0][1] + es[1][1]) / 2, 1))
            if eye_r is not None:
                d['eye_r'] = round(eye_r, 1)
        if hit:
            dx, dy = self.shift or (0.0, 0.0)
            d['hit'] = [round(hit[0] + dx, 1), round(hit[1] + dy, 1), round(hit[2], 1), round(hit[3], 1)]
        for k, v in pts.items():
            if isinstance(v, (tuple, list)) and len(v) == 2 and not isinstance(v[0], (tuple, list)):
                d[k] = self._mv(v)
            else:
                d[k] = v
        return self

    def svg(self):
        old = kit.RIM_W
        if self.rim_w is not None:
            kit.RIM_W = self.rim_w
        try:
            body = self.under + paint(self.ctx, self.P, self.pal) + self.over
            if self.shift:
                body = '<g transform="translate(%.2f %.2f)">%s</g>' % (self.shift[0], self.shift[1], body)
            if self.shine and self.name not in TELL_FRAMES:
                body = body.replace('#ffffff', self.shine)
        finally:
            kit.RIM_W = old
        FRAMES[self.name] = svg128(self.ctx, body)
        return FRAMES[self.name]


def face_eyes(f, eyes, pal, look=(0.8, 0.3), lid=0.0, mood='open'):
    """Anime eyes (common.eye) for a list of (cx, cy, w, h); mood 'open',
    'squeeze' (> <), 'swirl', 'shut' (closed arcs), 'happy'."""
    s = ''
    for i, (cx, cy, w, h) in enumerate(eyes):
        if mood == 'squeeze':
            s += squeeze(cx, cy, min(w, h) * 0.85, pal['line'], flip=i == 1, w=1.7)
        elif mood == 'swirl':
            s += dot(cx, cy, w * 0.5, pal['line']) + swirl_eye(cx, cy, w * 0.42, '#ffffff', 1.0)
        elif mood == 'shut':
            s += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (cx - w / 2, cy, cx, cy + h * 0.34, cx + w / 2, cy), pal['line'], 1.6)
        elif mood == 'happy':
            s += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (cx - w / 2, cy + h * 0.1, cx, cy - h * 0.36, cx + w / 2, cy + h * 0.1),
                      pal['line'], 1.6)
        else:
            s += eye(f.ctx, cx, cy, w, h, pal, look=look, lid=lid)
    return s


def mouth_d(x, y, w, h):
    """A little open D mouth (dark), for over strings."""
    return 'M%.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f Z' % (x - w / 2, y, x, y - 0.6, x + w / 2, y,
                                                                        x, y + h * 1.25, x - w / 2, y)


def mouth(x, y, w, h, col, tongue='#ff7f8a'):
    s = '<path d="%s" fill="%s"/>' % (mouth_d(x, y, w, h), col)
    s += '<path d="%s" fill="%s"/>' % (mouth_d(x, y + h * 0.5, w * 0.55, h * 0.45), tongue)
    return s


def smile(x, y, w, col, lw=1.2, bend=1.4):
    return line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (x - w / 2, y, x, y + bend, x + w / 2, y), col, lw)


# ================================================================ World 3: the Rootling

ROOT, ROOT_SH, ROOT_HI, ROOT_LINE = '#c89a5a', '#8a6238', '#ecc48c', '#2a1a0e'
LEAF, LEAF_SH, LEAF_HI = '#7ab860', '#4e8a3c', '#b8e890'
SOIL, SOIL_SH, SOIL_HI = '#5e4432', '#3c2a1e', '#8a6a4a'
TELL3 = '#c8d46a'          # World 3's tell accent (decoration never uses it)
RPAL = dict(line=ROOT_LINE, rim=RIM, base=ROOT, shade=ROOT_SH)
RFACE = dict(line=ROOT_LINE, base=ROOT, iris0='#3a4608', iris1='#b8d42c', iris2='#f4ffa0', blush='#ff8f8a')
SPORE_EYE = '#e0f070'


def leaf(stem0, tip, width, col=LEAF, sh=LEAF_SH):
    """A pointed leaf from stem0 to tip."""
    sx, sy = stem0
    tx, ty = tip
    mx, my = (sx + tx) / 2, (sy + ty) / 2
    nx, ny = -(ty - sy), (tx - sx)
    ln = math.hypot(nx, ny) or 1
    nx, ny = nx / ln * width, ny / ln * width
    pts = [(sx, sy, 0), (mx + nx, my + ny), (tx, ty, 0), (mx - nx * 0.8, my - ny * 0.8)]
    vein = hi_line('M%.1f %.1f L%.1f %.1f' % (sx, sy, mx * 0.4 + tx * 0.6, my * 0.4 + ty * 0.6), LEAF_SH, 0.8, op=0.9)
    return Part('fill', pth(smooth(pts)), fill=col, shade=sh, off=(-0.8, -0.8), over=vein,
                hl=spec(mx - nx * 0.3, my - ny * 0.3, width * 0.35, width * 0.18, op=0.6))


def sprouts(x, y, spread=1.0, lean=0.0, droop=0.0):
    """The Rootling's two leaf sprouts from (x, y)."""
    P = [Part('limb', pth('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (x, y, x - 1 + lean * 0.4, y - 3, x - 1.6 + lean, y - 5.4)),
              width=1.4, fill=LEAF_SH)]
    a = (x - 1.6 + lean, y - 5.4)
    P.append(leaf(a, (a[0] - 8 * spread, a[1] - 6 + droop * 9), 3.0))
    P.append(leaf(a, (a[0] + 8.6 * spread, a[1] - 7.4 + droop * 10), 3.2, col=mix(LEAF, LEAF_HI, 0.25)))
    return P


def turnip(cx, cy, sx=1.0, sy=1.0, deg=0.0):
    """The root body's outline round (cx, cy)."""
    base = [(0, -15), (8, -13.6), (14.6, -7), (17.4, 2), (15, 10.6), (7.6, 15.2), (0, 16), (-7.6, 15.2),
            (-15, 10.6), (-17.4, 2), (-14.6, -7), (-8, -13.6)]
    return tf([(cx + x, cy + y) for x, y in base], deg=deg, c=(cx, cy + 16), sx=sx, sy=sy)


def baby_skull(cx, cy, deg=0.0, k=1.0):
    """The cap: a baby skull worn on the root's head; returns (part, socket svg)."""
    pts = [(-12, 4), (-12.6, -2.6), (-8.6, -8.6), (0, -10.4), (8.6, -8.4), (12.8, -2), (12.6, 4.4, 0),
           (9.6, 3.2), (7, 5.2), (4.2, 3.4), (1.4, 5.4), (-1.4, 3.4), (-4.2, 5.2), (-7, 3.4), (-9.8, 5.2, 0)]
    pts = tf([(cx + x * k, cy + y * k) + tuple(p[2:]) for (x, y, *_), p in zip(pts, pts)], deg=deg, c=(cx, cy))
    sock = ''
    for (sx, sy, w, h) in ((4.6, -1.6, 4.6, 3.8), (10.2, -1.8, 3.2, 3.4)):
        q = pt((cx + sx * k, cy + sy * k), deg=deg, c=(cx, cy))
        sock += '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s" transform="rotate(%.1f %.1f %.1f)"/>' % (
            q[0], q[1], w / 2 * k, h / 2 * k, BONE_LINE, deg, q[0], q[1])
    crack = pt((cx - 3 * k, cy - 9 * k), deg=deg, c=(cx, cy)), pt((cx - 1 * k, cy - 5 * k), deg=deg, c=(cx, cy)), \
        pt((cx - 4 * k, cy - 2.6 * k), deg=deg, c=(cx, cy))
    sock += line('M%s L%s L%s' % tuple(fmt(c) for c in crack), BONE_LINE, 0.9)
    hl = spec(*pt((cx - 6 * k, cy - 5.4 * k), deg=deg, c=(cx, cy)), 3.4 * k, 1.6 * k, rot=-30 + deg, op=0.9)
    return Part('fill', pth(smooth(pts)), fill=BONE, shade=BONE_SH, off=(-1.6, -1.8), over=sock, hl=hl)


def root_foot(x, y, fwd=0.0, col=ROOT, sh=ROOT_SH):
    pts = [(x - 4.4, y + 2.6, 0), (x - 4, y - 1.6), (x + 0.6, y - 3), (x + 4.6 + fwd, y - 0.6), (x + 5.8 + fwd, y + 2.6, 0)]
    return Part('fill', pth(smooth(pts)), fill=col, shade=sh, off=(-0.8, -0.8),
                over=hi_line('M%.1f %.1f q1.4 -1.6 3 -1.2' % (x - 1.4, y + 1.2), ROOT_LINE, 0.6, op=0.7))


def rootling_body(f, cx, cy, sx=1.0, sy=1.0, deg=0.0, mood='open', look=(0.8, 0.3), mouth_kind='smile',
                  cap=(0.0, 0.0, -6.0), leaves=(1.0, 0.0, 0.0)):
    """Turnip body, face, the skull cap and its sprouts. Returns the eye points."""
    body = turnip(cx, cy, sx, sy, deg)
    c0 = (cx, cy + 16)

    def P(x, y):
        return pt((cx + (x - cx) * sx, cy + 16 + (y - cy - 16) * sy), deg=deg, c=c0)
    e1, e2 = P(cx - 3.8, cy - 3.2), P(cx + 6.2, cy - 3.6)
    ew = (7.6 * sx, 9.2 * sy), (6.2 * sx, 8.6 * sy)
    fc = face_eyes(f, [(e1[0], e1[1], ew[0][0], ew[0][1]), (e2[0], e2[1], ew[1][0], ew[1][1])], RFACE, look=look, mood=mood)
    m = P(cx + 1.6, cy + 5.4)
    if mouth_kind == 'smile':
        fc += smile(m[0], m[1], 4.4, ROOT_LINE)
        fc += '<path d="M%.1f %.1f l1.3 0.3 l-0.5 1.7 Z" fill="#ffffff" stroke="%s" stroke-width="0.5"/>' % (m[0] + 0.6, m[1] + 0.5, ROOT_LINE)
    elif mouth_kind == 'open':
        fc += mouth(m[0], m[1] - 0.6, 5.6, 3.4, ROOT_LINE)
    elif mouth_kind == 'roar':
        fc += mouth(m[0], m[1] - 1.2, 7.4, 4.6, ROOT_LINE)
        fc += '<path d="M%.1f %.1f l1.6 0 l-0.8 1.8 Z M%.1f %.1f l1.6 0 l-0.8 1.8 Z" fill="#ffffff"/>' % (
            m[0] - 3, m[1] - 1.1, m[0] + 1.4, m[1] - 1.1)
    elif mouth_kind == 'wobble':
        fc += line('M%.1f %.1f q1 -1.2 2 0 q1 1.2 2 0 q1 -1.2 2 0' % (m[0] - 3, m[1] + 0.6), ROOT_LINE, 1.1)
    fc += blush(*P(cx - 10, cy + 3), RFACE, rx=2.6, ry=1.5, op=0.7) + blush(*P(cx + 11.6, cy + 2.6), RFACE, rx=1.8, ry=1.3, op=0.7)
    # turnip rings and root hairs
    rings = hi_line('M%s Q%s %s' % (fmt(P(cx - 14, cy + 9)), fmt(P(cx, cy + 13.6)), fmt(P(cx + 14, cy + 9))), ROOT_SH, 0.9, op=0.8)
    rings += hi_line('M%s q-2.4 1 -3.4 3.4' % fmt(P(cx - 15.4, cy + 4)), ROOT_LINE, 0.7, op=0.8)
    rings += hi_line('M%s q2.4 1 3.2 3.4' % fmt(P(cx + 15.6, cy + 3.6)), ROOT_LINE, 0.7, op=0.8)
    hl = spec(*P(cx - 10, cy - 7), 3.6, 2, rot=-35 + deg, op=0.7)
    parts = [Part('fill', pth(smooth(body)), fill=ROOT, shade=ROOT_SH, off=(-2.4, -2.6), over=rings + fc, hl=hl)]
    capc = P(cx + cap[0], cy - 13 + cap[1])
    top = pt((capc[0] - 1, capc[1] - 9.4), deg=cap[2] + deg, c=capc)
    parts += sprouts(top[0], top[1], leaves[0], leaves[1], leaves[2])
    parts.append(baby_skull(capc[0], capc[1], deg=cap[2] + deg))
    f.add(parts)
    return [e1, e2], ew[0][0] / 2


def rootling_svg(frame):
    name = 'rootling_' + frame
    f = Fr(name, RPAL)
    if frame in ('walk1', 'walk2'):
        a = 1 if frame == 'walk1' else -1
        bob = 0.0 if a > 0 else -1.2
        f.under = ground_shadow(64, 17)
        f.add(root_foot(58 - 3 * a, 119.4, col=mix(ROOT, ROOT_SH, 0.35)), root_foot(70 + 3 * a, 119.4))
        eyes, r = rootling_body(f, 64, 102.6 + bob, leaves=(1.0, -1.2 * a, 0.0), cap=(0, 0, -6 + 2 * a))
        f.mark(eyes, r, hit=(46, 78, 36, 44))
    elif frame == 'hit':
        f.under = ground_shadow(64, 16)
        f.add(root_foot(57, 119.4, col=mix(ROOT, ROOT_SH, 0.35)), root_foot(71, 119.4, fwd=1.4))
        eyes, r = rootling_body(f, 63, 102.6, deg=-9, mood='squeeze', mouth_kind='open', cap=(-3, -6, -26),
                                leaves=(1.1, -2.4, -0.2))
        f.over = sweat(84, 92, 0.5, 25) + motion('M38 84 L32 79 M36 96 L29 95 M88 78 L94 72', 1.3)
        f.mark(eyes, r, hit=(45, 78, 36, 44))
    elif frame == 'dazed':
        f.under = ground_shadow(64, 19)
        f.add(root_foot(55, 119.6, col=mix(ROOT, ROOT_SH, 0.35)), root_foot(73, 119.6, fwd=1))
        eyes, r = rootling_body(f, 64, 105, sx=1.1, sy=0.84, mood='swirl', mouth_kind='wobble', cap=(2, 1, 14),
                                leaves=(0.9, 1.6, 0.55))
        f.over = dizzy_stars(64, 78, 14, 3.6, 3, phase=0.4)
        f.mark(eyes, r, hit=(45, 84, 38, 38), stars=(64, 78))
    elif frame == 'pop':
        # bursting up out of the floor: a column of soil under it, the root flung high
        f.under = ground_shadow(64, 22, 0.4)
        col = [(64, 112, 11.4), (56, 106, 8.2), (72, 105, 8), (63, 98, 8), (56, 91, 6), (72, 92, 6.2), (64, 86, 5.6)]
        for i, (x, y, r) in enumerate(col):
            f.add(blob(ring(x, y, r, r * 0.8, 9, wob=lambda j: 1.0 + 0.16 * ((j * 5 + i) % 3 - 1)),
                       SOIL if i % 2 == 0 else mix(SOIL, SOIL_HI, 0.3), SOIL_SH, off=(-1.2, -1.2),
                       over=specks([(x - r * 0.3, y - r * 0.2, 0.9), (x + r * 0.35, y + r * 0.2, 0.7)], SOIL_HI)))
        # the burst ring on the floor
        for x, y, r, dx in ((45, 119, 5, -1), (83, 119, 5, 1), (38, 120.6, 3.4, -1), (90, 120.6, 3.4, 1)):
            f.add(blob(ring(x, y, r, r * 0.72, 8), SOIL, SOIL_SH, off=(-0.8, -0.8)))
        f.add(root_foot(57, 84.6, col=mix(ROOT, ROOT_SH, 0.35)), root_foot(71, 85.4, fwd=1.6))
        eyes, r = rootling_body(f, 64, 67, sx=0.94, sy=1.1, mouth_kind='roar', look=(0.4, -0.6), cap=(1, -3, -12),
                                leaves=(1.2, 0.0, -0.35))
        f.over = (specks([(40, 100, 1.4), (88, 96, 1.2), (34, 86, 1.0), (94, 82, 1.1), (44, 74, 0.9), (86, 66, 0.9)], SOIL_HI)
                  + motion('M36 70 L36 58 M92 72 L92 60 M30 90 L30 80 M98 92 L98 82', 1.3))
        f.mark(eyes, r, hit=(42, 42, 44, 80), column=(64, 82))
    elif frame == 'mound':
        f.under = ground_shadow(64, 22, 0.3)
        f.add(sprouts(64.6, 112, 0.8, 0.8, 0.1))
        mound = [(43, 122.2, 0), (47, 116.6), (55, 112.4), (64, 111), (73, 112.2), (81, 116.4), (85, 122.2, 0)]
        f.add(blob(mound, SOIL, SOIL_SH, off=(-2, -1.6),
                   over=specks([(52, 118, 1.1), (60, 115, 0.8), (70, 117.4, 1.2), (77, 119, 0.8), (65, 119.6, 0.7)], SOIL_HI),
                   hl=hi_line('M49 116 Q56 111.6 63 111.4', SOIL_HI, 1.2, op=0.7)))
        # a soil trail behind it
        f.over = specks([(38, 121, 1.3), (33, 121.4, 1.0), (29, 121.6, 0.7)], SOIL_HI)
        f.mark(hit=(44, 102, 40, 20), leaves=(64, 102))
    else:   # swell: the tell. The mound heaves, cracks, spits soil, the cap peeks through, a glint
        f.under = ground_shadow(64, 24, 0.35)
        f.add(sprouts(64, 101.6, 1.05, -0.6, -0.1))
        f.add(baby_skull(64, 106, deg=-4, k=0.8))
        mound = [(41, 122.2, 0), (44, 115), (50.6, 108.6), (57.6, 106, 0), (61, 109.2), (64.4, 104.4, 0), (67.6, 108.6),
                 (71, 105.4, 0), (78.4, 108.2), (84.4, 114.4), (87, 122.2, 0)]
        cracks = line('M57.6 106.4 L55 112 L57 116 M71 105.8 L73.6 111.6 L71.4 115.6 M64.4 105 L64 110', ROOT_LINE, 1.1)
        f.add(blob(mound, SOIL, SOIL_SH, off=(-2, -1.6),
                   over=cracks + specks([(50, 117, 1.1), (77, 118.4, 1.2), (60, 119.6, 0.8), (70, 114, 0.8)], SOIL_HI),
                   hl=hi_line('M46 114.4 Q50 109.6 56 107.4', SOIL_HI, 1.2, op=0.7)))
        f.over = (specks([(48, 99, 1.4), (80, 97, 1.3), (54, 91, 1.0), (75, 89, 1.0), (42, 104, 1.0), (86, 104, 1.1)], SOIL_HI)
                  + glint(64, 96, 6.4, TELL3) + motion('M40 110 L36 108 M88 110 L92 108', 1.0))
        f.mark(hit=(42, 98, 44, 24), glint=(64, 96))
    return f.svg()


# ================================================================ World 3: the Weepcap

CAP, CAP_SH, CAP_HI, CAP_DK = '#8a7a9c', '#665879', '#b4a6c6', '#4a3e5c'
GILL, GILL_HOT = '#c8a0e8', '#f4e2ff'
STALK, STALK_SH, STALK_HI = '#f2ead8', '#cdbfa6', '#ffffff'
WLINE = '#22182a'
WPAL = dict(line=WLINE, rim=RIM, base=STALK, shade=STALK_SH)
WFACE = dict(line=WLINE, base=STALK, iris0='#3a4608', iris1='#b4d02a', iris2='#f0ff98', blush='#e89ab8')
SPORE, SPORE_SH = '#d6c8e4', '#a898bc'


def weep_stalk(f, lean=0.0, sq=1.0, mood='sleepy', face_dy=0.0):
    """The pale stalk with its skirt and the sad face. Returns the eye points."""
    top = 86 + (1 - sq) * 20
    pts = [(49, 122.2, 0), (48.6, 117), (51.4, 111), (53.4, 104), (53.8, 95), (56 + lean * 0.3, top + 1),
           (64 + lean, top - 1.6), (72 + lean * 0.3, top + 1), (74.4, 95), (74.6, 104), (76.6, 111), (79.4, 117),
           (79, 122.2, 0)]
    fy = 97 + face_dy + (1 - sq) * 12
    e1, e2 = (59.6 + lean * 0.5, fy), (69.4 + lean * 0.5, fy - 0.4)
    if mood == 'sleepy':
        fc = face_eyes(f, [(e1[0], e1[1], 6.6, 8.2), (e2[0], e2[1], 5.4, 7.8)], WFACE, look=(0.5, 0.8), lid=0.46)
        fc += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (e1[0] - 4, e1[1] - 6.4, e1[0], e1[1] - 8.2, e1[0] + 3.4, e1[1] - 7.2), WLINE, 1.1)
        fc += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (e2[0] - 2.8, e2[1] - 7.2, e2[0], e2[1] - 8, e2[0] + 3, e2[1] - 6.4), WLINE, 1.1)
        fc += line('M%.1f %.1f q2 -1.6 4 0' % (e1[0] + 2.6, fy + 7.4), WLINE, 1.1)
        fc += kit.drop(0, 0, 1.0).replace('translate(0 0) scale(1.0)', 'translate(%.1f %.1f) scale(0.22)' % (e1[0] - 2.4, fy + 7))
    elif mood == 'wide':
        fc = face_eyes(f, [(e1[0], e1[1], 7.2, 9.0), (e2[0], e2[1], 6.0, 8.4)], WFACE, look=(0.8, -0.3))
        fc += '<ellipse cx="%.1f" cy="%.1f" rx="1.8" ry="1.6" fill="%s"/>' % (e1[0] + 5, fy + 7.4, WLINE)
    elif mood == 'shut':
        fc = face_eyes(f, [(e1[0], e1[1], 6.6, 8), (e2[0], e2[1], 5.4, 7.6)], WFACE, mood='shut')
        fc += line('M%.1f %.1f q2 -1.6 4 0' % (e1[0] + 2.6, fy + 6.6), WLINE, 1.1)
        fc += kit.drop(0, 0, 1.0).replace('translate(0 0) scale(1.0)', 'translate(%.1f %.1f) scale(0.22)' % (e1[0] - 1.6, fy + 5.4))
    else:
        fc = face_eyes(f, [(e1[0], e1[1], 6.6, 8.2), (e2[0], e2[1], 5.4, 7.8)], WFACE, mood=mood)
        fc += mouth(e1[0] + 5, fy + 6.6, 3.8, 2.4, WLINE)
    fc += blush(e1[0] - 4.2, fy + 5, WFACE, rx=2.2, ry=1.3, op=0.65) + blush(e2[0] + 4.6, fy + 4.6, WFACE, rx=1.6, ry=1.2, op=0.65)
    skirt = [(50.4, 110, 0), (57, 108.2), (64, 107.6), (71, 108.2), (77.6, 110, 0), (76.6, 113.4), (73, 112.2), (70, 114.4),
             (66.6, 112.4), (63, 114.6), (59.6, 112.4), (56, 114.4), (53.4, 112.4), (50.8, 113.8)]
    hl = hi_line('M51.6 118 Q52.6 108 56 96', STALK_HI, 1.4, op=0.7)
    f.add(Part('fill', pth(smooth(pts)), fill=STALK, shade=STALK_SH, off=(-2.2, -1), over=fc, hl=hl))
    f.add(Part('fill', pth(smooth(skirt)), fill=mix(STALK, STALK_SH, 0.45), shade=STALK_SH, off=(-0.6, -1.4)))
    return [e1, e2]


def weep_cap(f, cx, cy, s=1.0, deg=0.0, sy=1.0, glow=0.0, sad=True):
    """The drooping veil-cap, its underside of glowing gills. glow 0..1."""
    base = [(0, -32), (10, -30.4), (19, -24), (25, -14), (28.4, -3), (29.6, 6, 0), (27, 3), (24.6, 8.4, 0), (21.6, 3.6),
            (17.6, 6.2, 0), (13.6, 1.6), (8, 2.4), (2, 0.6), (-4, 2.4), (-10, 1.4), (-14, 6, 0), (-17.6, 2.4),
            (-21.6, 8, 0), (-24.4, 3), (-28, 7, 0), (-29, -3), (-25, -14), (-19, -24), (-10, -30.4)]
    pts = tf([(cx + x * s, cy + y * s * sy) + tuple(p[2:]) for (x, y, *_), p in zip(base, base)], deg=deg, c=(cx, cy))
    gill_pts = tf([(cx - 17 * s, cy + 0.6 * s * sy), (cx, cy - 4.6 * s * sy), (cx + 17 * s, cy + 0.6 * s * sy),
                   (cx + 12 * s, cy + 4.6 * s * sy), (cx, cy + 3.6 * s * sy), (cx - 12 * s, cy + 4.6 * s * sy)], deg=deg, c=(cx, cy))
    gcol = mix(GILL, GILL_HOT, glow)
    under = ''
    if glow > 0:
        g = f.ctx.radgrad([(0, GILL_HOT, 0.85 * glow), (0.5, GILL, 0.45 * glow), (1, GILL, 0)])
        gp = pt((cx, cy + 2 * s), deg=deg, c=(cx, cy))
        under = '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s"/>' % (gp[0], gp[1], 30 * s, 16 * s, g)
    gl = ''
    for i in range(-3, 4):
        a = pt((cx + i * 4.6 * s, cy - 2.6 * s * sy + abs(i) * 0.9), deg=deg, c=(cx, cy))
        b = pt((cx + i * 5.6 * s, cy + 3.4 * s * sy), deg=deg, c=(cx, cy))
        gl += line('M%s L%s' % (fmt(a), fmt(b)), mix(CAP_DK, gcol, 0.3), 0.9)
    gills = Part('fill', pth(smooth(gill_pts)), fill=gcol, shade=mix(gcol, CAP_DK, 0.4), off=(0, -1.2), over=gl, sil=False,
                 lw=0.8)
    ribs = ''
    for i in (-2, -1, 0, 1, 2):
        a = pt((cx + i * 4 * s, cy - 30 * s * sy + abs(i) * 1.4 * s), deg=deg, c=(cx, cy))
        b = pt((cx + i * 10.4 * s, cy - 1 * s * sy), deg=deg, c=(cx, cy))
        m = pt((cx + i * 8.6 * s, cy - 16 * s * sy), deg=deg, c=(cx, cy))
        ribs += line('M%s Q%s %s' % (fmt(a), fmt(m), fmt(b)), CAP_DK, 0.9, op=0.55)
    spots = ''.join(dot(*pt((cx + x * s, cy + y * s * sy), deg=deg, c=(cx, cy)), r * s, CAP_HI, 0.8)
                    for x, y, r in ((-13, -22, 1.8), (7, -25, 1.4), (18, -14, 1.6), (-20, -10, 1.2), (2, -15, 1.1)))
    hl = spec(*pt((cx - 14 * s, cy - 23 * s * sy), deg=deg, c=(cx, cy)), 7 * s, 2.6 * s, rot=-38 + deg, op=0.55)
    cap = Part('fill', pth(smooth(pts)), fill=CAP, shade=CAP_SH, off=(-3, -3.6), over=ribs + spots, hl=hl, under=under)
    return [cap, gills]


def weepcap_svg(frame):
    name = 'weepcap_' + frame
    f = Fr(name, WPAL)
    f.under = ground_shadow(64, 20)
    if frame == 'idle':
        eyes = weep_stalk(f, lean=0.6)
        f.add(weep_cap(f, 64.6, 85, deg=-4))
        f.mark(eyes, 3.3, hit=(36, 52, 56, 70), gills=(64.6, 86))
    elif frame == 'inhale':
        # the tell: the cap swells x1.2, the gills glow hot, air drawn in
        eyes = weep_stalk(f, lean=0.0, mood='wide')
        f.add(weep_cap(f, 64, 84, s=1.2, glow=1.0))
        f.over = (motion('M26 70 L33 74 M24 86 L32 86 M102 70 L95 74 M104 86 L96 86', 1.2)
                  + sparkle(40, 90, 2.2, WLINE, GILL_HOT) + sparkle(89, 91, 2.0, WLINE, GILL_HOT))
        f.mark(eyes, 3.6, hit=(30, 44, 68, 78), gills=(64, 85))
    elif frame == 'puff':
        eyes = weep_stalk(f, lean=0.0, mood='squeeze')
        for x, y, r in ((36, 70, 7), (92, 68, 7.4), (48, 56, 6), (80, 54, 6.4), (64, 50, 5.4), (28, 84, 5), (100, 84, 5.4)):
            f.under += puff(x, y, r, SPORE, 0.9, key=WLINE)
        f.add(weep_cap(f, 64, 88, s=1.06, sy=0.8, glow=0.4))
        f.over = (specks([(30, 60, 1.2), (98, 58, 1.1), (40, 44, 1.0), (88, 42, 1.1), (56, 40, 0.9), (72, 40, 0.8), (20, 74, 0.9),
                          (108, 74, 1.0)], SPORE)
                  + motion('M24 62 L18 58 M104 60 L110 56 M64 38 L64 32', 1.2))
        f.mark(eyes, 3.3, hit=(34, 58, 60, 64), burst=(64, 76))
    elif frame == 'hit':
        eyes = weep_stalk(f, lean=-1.6, mood='squeeze')
        f.add(weep_cap(f, 62, 86, deg=-13))
        f.over = (kit.drop(0, 0).replace('translate(0 0) scale(1.0)', 'translate(44 94) rotate(-30) scale(0.34)')
                  + kit.drop(0, 0).replace('translate(0 0) scale(1.0)', 'translate(86 90) rotate(30) scale(0.3)')
                  + motion('M100 66 L106 60 M102 78 L110 76 M26 64 L20 58', 1.3))
        f.mark(eyes, 3.3, hit=(34, 52, 58, 70))
    else:   # die: the cap wilts over, the stalk bends, it sobs itself shut
        eyes = weep_stalk(f, lean=-3.2, mood='shut', face_dy=1.6)
        f.add(weep_cap(f, 60, 94, s=0.96, deg=-32, sy=0.9))
        f.over = specks([(84, 70, 1.1), (90, 60, 0.9), (78, 56, 0.8)], SPORE, op=0.7)
        f.mark(eyes, 3.3, hit=(30, 64, 56, 58))
    return f.svg()


# ================================================================ World 3: the Rattlehound

HOUND_EYE = '#b8f070'


def bone_leg(hip, knee, foot, fill, sh, w=3.2, paw=1.0):
    """A bony leg: two limb bones, a knuckle, and an oversized round paw."""
    P = [Part('limb', pth('M%s L%s L%s' % (fmt(hip), fmt(knee), fmt(foot))), width=w, fill=fill),
         Part('fill', ell(knee[0], knee[1], 2.2, 2.2), fill=fill, shade=sh, off=(-0.6, -0.7))]
    fx, fy = foot
    k = paw
    pd = [(fx - 4.4 * k, fy + 2.8 * k, 0), (fx - 4.2 * k, fy - 1.2 * k), (fx + 0.4 * k, fy - 3 * k), (fx + 5.4 * k, fy - 1.4 * k),
          (fx + 7 * k, fy + 2.8 * k, 0)]
    toes = line('M%.1f %.1f l0 -1.8 M%.1f %.1f l0 -1.8' % (fx + 1.4 * k, fy + 2.8 * k, fx + 4 * k, fy + 2.8 * k), BONE_LINE, 0.7)
    P.append(Part('fill', pth(smooth(pd)), fill=fill, shade=sh, off=(-0.8, -0.9), over=toes))
    return P


def ribcage(x0, y0, x1, y1, drop=0.0, fill=BONE, sh=BONE_SH):
    """A rounded ribcage hung under the spine from (x0, y0) to (x1, y1)."""
    pts = [(x0, y0), (x0 + (x1 - x0) * 0.5, y0 - 1.2 + (y1 - y0) * 0.5), (x1, y1), (x1 + 2.4, y1 + 7), (x1 - 3, y1 + 13 + drop),
           (x0 + (x1 - x0) * 0.45, y0 + 16 + drop), (x0 + 1.4, y0 + 10 + drop * 0.6)]
    ribs = ''
    for i, t in enumerate((0.22, 0.44, 0.66)):
        x = x0 + (x1 - x0) * t
        y = y0 + (y1 - y0) * t
        ribs += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (x - 1, y + 1.4, x + 1.8, y + 7 + drop * 0.5, x - 0.6, y + 12.6 + drop * 0.7),
                     BONE_LINE, 1.2)
    return Part('fill', pth(smooth(pts)), fill=fill, shade=sh, off=(-1.4, -1.6), over=ribs,
                hl=hi_line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (x0 + 3, y0 + 2.4, x0 + (x1 - x0) * 0.5, y0 + 0.6, x1 - 3, y1 + 1.4),
                           '#ffffff', 0.9, op=0.8))


def hound_skull(f, cx, cy, deg=0.0, jaw=0.0, mood='idle', k=1.0):
    """The dog skull facing right: cranium round (cx, cy), snout forward, a
    lower jaw opened by jaw (0..1). The lantern-glint burns in the near socket
    only; the far one is dark. Returns (parts, [the lit eye], teeth point)."""
    c = (cx, cy)

    def P(x, y):
        return pt((cx + x * k, cy + y * k), deg=deg, c=c)

    def L(pts):
        return [P(*p[:2]) + tuple(p[2:]) for p in pts]
    ja = jaw * 22.0
    hinge = (4, 5)
    jaw_pts = [(3, 4.4), (10, 5.4), (19, 5.8), (21.4, 7.6), (19, 10.2), (10, 10.6), (4, 9)]
    jaw_pts = [rot(p, ja, hinge) for p in jaw_pts]
    teeth_low = ''.join('<path d="M%s L%s L%s Z" fill="#fffaf0" stroke="%s" stroke-width="0.5"/>' % (
        fmt(P(*rot((x, 5.4), ja, hinge))), fmt(P(*rot((x + 1.4, 3.2), ja, hinge))), fmt(P(*rot((x + 2.8, 5.4), ja, hinge))),
        BONE_LINE) for x in (10.4, 14, 17.4))
    parts = [Part('fill', pth(smooth(L(jaw_pts))), fill=BONE_BACK, shade=BONE_BACK_SH, off=(-0.8, -1), over=teeth_low)]
    if jaw > 0.35:
        parts[-1].under = '<path d="%s" fill="%s"/>' % (smooth(L([(4, 3), (18, 2), (22, 5.4), rot((20, 8), ja, hinge),
                                                                    rot((8, 8), ja, hinge)])), '#3a1a24')
    cran = [(-11, 1), (-10.4, -7), (-5, -12), (3, -12.4), (9.6, -8.6), (13, -3.4, 0), (21, -1.6), (24, 1.4), (23.6, 5, 0),
            (13, 5.6), (4, 7.6), (-4, 8.4), (-9.4, 6)]
    fc = ''
    e1, e2 = P(1.6, -3), P(9.8, -3.6)
    halo = f.ctx.radgrad([(0, HOUND_EYE, 0.55), (1, HOUND_EYE, 0)])
    hp = P(2.4, -3)
    fc += '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s"/>' % (hp[0], hp[1], 11 * k, 9 * k, halo)
    # the far socket is empty and dark (a faint ember at most): the lantern-glint burns in the near one only
    w2, h2 = 6.2 * k, 7.8 * k
    fc += '<ellipse cx="%.2f" cy="%.2f" rx="%.2f" ry="%.2f" fill="%s"/>' % (e2[0], e2[1], w2 / 2, h2 / 2, BONE_LINE)
    fc += dot(e2[0] + 0.6 * k, e2[1] + 1.2 * k, 0.9 * k, mix(HOUND_EYE, BONE_LINE, 0.62))
    if mood == 'hit':
        fc += glow_eye(f.ctx, e1[0], e1[1], 8.6 * k, 9.4 * k, look=(0, 0), iris=0.18, col=HOUND_EYE, pin=True)
    elif mood == 'tired':
        for (ex, ey), w, h, lit in ((e1, 8, 8.4, True), (e2, 5.6, 7, False)):
            if lit:
                fc += glow_eye(f.ctx, ex, ey + 0.6, w * k, h * k, look=(0.6, 1.2), iris=0.3, col=HOUND_EYE)
            fc += '<path d="M%.1f %.1f L%.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f Z" fill="%s"/>' % (
                ex - w * 0.62 * k, ey - h * 0.7 * k, ex + w * 0.62 * k, ey - h * 0.7 * k, ex + w * 0.62 * k, ey - 0.4,
                ex, ey + 0.8, ex - w * 0.62 * k, ey - 0.4, BONE)
            fc += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (ex - w * 0.6 * k, ey - 0.4, ex, ey + 0.9, ex + w * 0.6 * k, ey - 0.4),
                       BONE_LINE, 1.0)
    else:
        big = mood == 'flare'
        look = (1.4 * k, 0.3) if mood != 'squint' else (1.8 * k, 0.6)
        fc += glow_eye(f.ctx, e1[0], e1[1], (9.4 if big else 8.4) * k, (10.4 if big else 9.4) * k, look=look,
                       iris=0.4 if big else 0.34, col=HOUND_EYE)
        if mood == 'squint':
            for (ex, ey), w in ((e1, 8.6), (e2, 6.4)):
                fc += '<path d="M%.1f %.1f L%.1f %.1f L%.1f %.1f Z" fill="%s"/>' % (
                    ex - w * 0.7 * k, ey - 6 * k, ex + w * 0.7 * k, ey - 6 * k, ex + w * 0.7 * k, ey - 2.2 * k, BONE)
                fc += line('M%.1f %.1f L%.1f %.1f' % (ex - w * 0.6 * k, ey - 4.4 * k, ex + w * 0.62 * k, ey - 2.2 * k), BONE_LINE, 1.2)
    nose = P(22.2, 0.8)
    fc += '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s" transform="rotate(%.1f %.1f %.1f)"/>' % (
        nose[0], nose[1], 2.2 * k, 1.7 * k, BONE_LINE, deg, nose[0], nose[1])
    # the upper teeth under the snout
    fc += ''.join('<path d="M%s L%s L%s Z" fill="#fffaf0" stroke="%s" stroke-width="0.5"/>' % (
        fmt(P(x, 5.2)), fmt(P(x + 1.4, 7.6)), fmt(P(x + 2.8, 5.2)), BONE_LINE) for x in (11, 14.6, 18.2))
    fc += line('M%s L%s L%s' % (fmt(P(-6, -9.6)), fmt(P(-3.6, -6.4)), fmt(P(-5.6, -4))), BONE_LINE, 0.9)
    hl = spec(*P(-4.4, -8.4), 4.2 * k, 2 * k, rot=-36 + deg, op=0.9)
    parts.append(Part('fill', pth(smooth(L(cran))), fill=BONE, shade=BONE_SH, off=(-2 * k, -2.2 * k), over=fc, hl=hl))
    return parts, [e1], P(15.6, 6.8)


def bone_tail(base, pts_rel, fill=BONE, sh=BONE_SH):
    """A wagging bone tail: knuckles from base along pts_rel."""
    P = []
    prev = base
    for i, (dx, dy) in enumerate(pts_rel):
        q = (prev[0] + dx, prev[1] + dy)
        r = 2.4 - i * 0.3
        P.append(Part('fill', ell(q[0], q[1], r + 0.4, r), fill=fill, shade=sh, off=(-0.5, -0.6)))
        prev = q
    return P


def hound_body(f, hip, sh_, legs, head, tail, jaw=0.0, mood='idle', drop=0.0, spine_bend=-4.0):
    """The whole hound. legs: [(hip_or_shoulder, knee, foot, back?)...] in draw
    order; head: (cx, cy, deg); tail: list of knuckle offsets. Returns eyes, teeth."""
    back = [l for l in legs if l[3]]
    front = [l for l in legs if not l[3]]
    for h, kn, ft, _ in back:
        f.add(bone_leg(h, kn, ft, BONE_BACK, BONE_BACK_SH))
    f.add(bone_tail((hip[0] - 3, hip[1] - 1), tail))
    mid = ((hip[0] + sh_[0]) / 2, min(hip[1], sh_[1]) + spine_bend)
    f.add(Part('limb', pth('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (hip[0] - 3, hip[1], mid[0], mid[1], sh_[0] + 3, sh_[1] - 1)),
               width=3.4, fill=BONE))
    f.add(ribcage(hip[0] + 8, hip[1] - 2 + (sh_[1] - hip[1]) * 0.3, sh_[0] - 1, sh_[1] - 1, drop=drop))
    pel = [(hip[0] - 5, hip[1] - 2), (hip[0] + 1, hip[1] - 5), (hip[0] + 6, hip[1] - 2.4), (hip[0] + 4.6, hip[1] + 3.4),
           (hip[0] - 2, hip[1] + 4)]
    f.add(blob(pel, BONE, BONE_SH, off=(-0.8, -1)))
    for h, kn, ft, _ in front:
        f.add(bone_leg(h, kn, ft, BONE, BONE_SH))
    hx, hy, hd = head
    f.add(Part('limb', pth('M%.1f %.1f L%.1f %.1f' % (sh_[0] + 2, sh_[1] - 1, hx - 6, hy + 4)), width=3.2, fill=BONE))
    parts, eyes, teeth = hound_skull(f, hx, hy, hd, jaw, mood)
    f.add(parts)
    return eyes, teeth


def hound_svg(frame):
    name = 'hound_' + frame
    f = Fr(name, dict(line=BONE_LINE, rim=RIM, base=BONE, shade=BONE_SH))
    f.under = ground_shadow(64, 30)
    E = 4.2   # eye radius
    if frame in ('prowl1', 'prowl2'):
        a = 1 if frame == 'prowl1' else -1
        hip, sh = (44, 99 - 0.6 * a), (78, 98)
        legs = [(hip, (48 + 2 * a, 108), (44 + 6 * a, 118.6), True), (sh, (80 - 2 * a, 108), (80 - 5 * a, 118.6), True),
                (hip, (46 - 2 * a, 108.6), (40 - 5 * a, 118.6), False), (sh, (78 + 2 * a, 108.6), (84 + 5 * a, 118.6), False)]
        eyes, teeth = hound_body(f, hip, sh, legs, (90, 95 + a * 0.6, 14), [(-4, -2.6), (-3.4, -3.6 + a), (-2.4, -3.6 + a * 1.6),
                                                                           (-1.4, -3 + a * 2)])
        f.over = specks([(104, 120, 0.8), (108, 119, 0.6)], '#b0a58c')
        f.mark(eyes, E, hit=(30, 80, 78, 42), snout=(108, 100))
    elif frame == 'howl':
        # the tell to chase: sat back on its haunches, head thrown up, the lantern eye flaring
        hip, sh = (46, 110), (72, 92)
        legs = [(hip, (54, 112), (50, 118.6), True), (sh, (74, 106), (72, 118.6), True),
                (hip, (52, 114), (44, 118.6), False), (sh, (78, 106), (80, 118.6), False)]
        eyes, teeth = hound_body(f, hip, sh, legs, (82, 76, -38), [(-4, 1), (-3.6, -1), (-3, -2.6), (-1.6, -3.4)], jaw=0.9,
                                 mood='flare', drop=-1, spine_bend=-2)
        mouth_p = pt((82 + 22, 76 + 6), deg=-38, c=(82, 76))
        f.over = (motion('M%.1f %.1f q4 -3 3 -8 M%.1f %.1f q6 -3 5 -11' % (mouth_p[0] + 3, mouth_p[1] - 3, mouth_p[0] + 7, mouth_p[1] - 1), 1.2)
                  + glint(eyes[0][0], eyes[0][1] - 1, 5.4, '#e8ffc8'))
        f.mark(eyes, E + 0.6, hit=(36, 60, 60, 62), flare=eyes[0], mouth=mouth_p)
    elif frame == 'run1':
        # stretched: forelegs reaching, hind legs kicked back
        hip, sh = (40, 100), (76, 99)
        legs = [(hip, (34, 106), (26, 113), True), (sh, (86, 106), (98, 111), True),
                (hip, (36, 108), (28, 117.4), False), (sh, (84, 109), (100, 117.4), False)]
        eyes, teeth = hound_body(f, hip, sh, legs, (88, 90, 2), [(-4.4, -1), (-4, -1.4), (-3.4, -1.2), (-3, -0.6)], jaw=0.2,
                                 spine_bend=-1.4)
        f.over = motion('M18 94 L8 94 M20 102 L6 102 M24 110 L14 110', 1.3)
        f.mark(eyes, E, hit=(24, 80, 84, 42))
    elif frame == 'run2':
        # gathered: all four paws bunched under, the back arched
        hip, sh = (46, 97), (74, 97)
        legs = [(hip, (54, 106), (62, 117.4), True), (sh, (70, 107), (60, 116.6), True),
                (hip, (52, 108), (58, 118.6), False), (sh, (72, 108), (66, 118.6), False)]
        eyes, teeth = hound_body(f, hip, sh, legs, (87, 91, 0), [(-4, -3), (-3, -3.6), (-2, -3.4), (-1, -3)], jaw=0.15,
                                 spine_bend=-7)
        f.over = motion('M26 92 L16 92 M28 100 L14 100', 1.3)
        f.mark(eyes, E, hit=(30, 76, 76, 46))
    elif frame == 'crouch':
        # the tell: haunches down, head low and forward, a glint on the bared teeth
        hip, sh = (42, 106), (78, 104)
        legs = [(hip, (52, 110), (46, 118.6), True), (sh, (84, 110), (82, 118.6), True),
                (hip, (50, 113), (40, 118.6), False), (sh, (88, 110), (88, 118.6), False)]
        eyes, teeth = hound_body(f, hip, sh, legs, (92, 102, 8), [(-4, -1), (-4, -1.2), (-3.4, -0.4), (-3, 0.4)], jaw=0.3,
                                 mood='squint', drop=-2, spine_bend=-5)
        f.over = glint(teeth[0], teeth[1], 5.4, TELL3) + motion('M30 118 L24 116 M34 121 L27 121', 1.0)
        f.mark(eyes, E, hit=(30, 86, 80, 36), teeth=teeth)
    elif frame == 'pounce':
        # the leap: stretched long and tipped up, jaws wide, claws first
        hip, sh = (40, 104), (74, 92)
        legs = [(hip, (32, 108), (22, 110), True), (sh, (82, 100), (96, 104), True),
                (hip, (34, 112), (24, 116), False), (sh, (80, 104), (92, 112), False)]
        eyes, teeth = hound_body(f, hip, sh, legs, (88, 82, -8), [(-4.4, 1.4), (-4, 1.6), (-3.4, 1.8), (-2.6, 1.8)], jaw=0.95,
                                 mood='flare', spine_bend=-2)
        f.over = motion('M16 100 L6 106 M20 92 L8 96', 1.3)
        f.under = ground_shadow(62, 22, 0.25)
        f.mark(eyes, E + 0.6, hit=(20, 64, 92, 56), bite=teeth)
    elif frame == 'land':
        # skidding to a stop, forelegs braced, off balance: its open moment
        hip, sh = (46, 102), (80, 104)
        legs = [(hip, (52, 110), (48, 118.6), True), (sh, (90, 110), (98, 118.6), True),
                (hip, (48, 111), (40, 118.6), False), (sh, (88, 112), (102, 118.6), False)]
        eyes, teeth = hound_body(f, hip, sh, legs, (94, 100, 18), [(-4, -3), (-3, -3.8), (-2, -3.4), (-1, -2.8)], jaw=0.55,
                                 mood='hit', spine_bend=-6)
        f.over = (puff(104, 118, 4.6, '#b8b0a0', 0.8, key=BONE_LINE) + puff(110, 116, 3.4, '#b8b0a0', 0.7, key=BONE_LINE)
                  + puff(98, 120, 3.2, '#b8b0a0', 0.8, key=BONE_LINE) + sweat(80, 82, 0.45, -20))
        f.mark(eyes, E, hit=(32, 84, 80, 38))
    elif frame == 'pant':
        # worn out after its pounces: sat down, tongue lolling (+25% damage)
        hip, sh = (46, 110), (74, 96)
        legs = [(hip, (54, 112), (50, 118.6), True), (sh, (76, 108), (74, 118.6), True),
                (hip, (52, 114), (44, 118.6), False), (sh, (80, 108), (82, 118.6), False)]
        eyes, teeth = hound_body(f, hip, sh, legs, (86, 88, 6), [(-4, 1.4), (-4, 1.6), (-3, 1.4), (-2, 1)], jaw=0.5,
                                 mood='tired', drop=1, spine_bend=-2)
        tp = pt((86 + 13, 88 + 9), deg=6, c=(86, 88))
        f.over = ('<path d="M%.1f %.1f q3.4 0 3.6 4.4 q0 3.6 -2.6 3.6 q-2.6 0 -2.4 -3.8 Z" fill="#ff7f8a" stroke="%s" stroke-width="1"/>'
                  % (tp[0] - 1, tp[1] - 1, BONE_LINE)
                  + sweat(98, 72, 0.5, 20) + sweat(74, 74, 0.4, -20) + motion('M104 82 q3 -2 6 0 M104 88 q3 -2 6 0', 1.0))
        f.mark(eyes, E, hit=(34, 70, 66, 52), tongue=(tp[0] + 1, tp[1] + 3))
    else:   # hit: jolted, bones rattled loose, jaw dropped
        hip, sh = (45, 100), (77, 97)
        legs = [(hip, (50, 108), (46, 118.6), True), (sh, (80, 108), (78, 118.6), True),
                (hip, (44, 109), (38, 118.6), False), (sh, (76, 109), (84, 118.6), False)]
        eyes, teeth = hound_body(f, hip, sh, legs, (88, 90, -16), [(-4, -3.6), (-3, -4), (-2, -3.6), (-1, -3)], jaw=0.7,
                                 mood='hit', spine_bend=-3)
        f.over = sweat(102, 76, 0.5, 25) + motion('M104 66 L110 60 M108 80 L116 78 M30 80 L24 74', 1.3)
        f.mark(eyes, E, hit=(30, 74, 78, 48))
    return f.svg()


# ================================================================ World 3: the Creepbone

BARK, BARK_SH, BARK_HI = '#5a4030', '#3a281c', '#8a6a4a'


def knuckle(x, y, deg, k=1.0, fill=BONE, sh=BONE_SH):
    """One vertebra, seen from above: a rounded bone with side knobs and a spur."""
    base = [(-8, 0.4), (-7.2, -3.4), (-3.4, -4.4), (0, -6), (3.4, -4.4), (7.2, -3.4), (8, 0.4), (6.8, 4.2), (3, 4.8), (0, 4.2),
            (-3, 4.8), (-6.8, 4.2)]
    pts = tf([(x + px * k, y + py * k) for px, py in base], deg=deg, c=(x, y))
    groove = line('M%s L%s' % (fmt(pt((x - 3.6 * k, y - 0.4), deg=deg, c=(x, y))), fmt(pt((x + 3.6 * k, y - 0.4), deg=deg, c=(x, y)))),
                  BONE_LINE, 0.8, op=0.7)
    return Part('fill', pth(smooth(pts)), fill=fill, shade=sh, off=(-1, -1.2), over=groove,
                hl=spec(*pt((x - 3.4 * k, y - 2.4 * k), deg=deg, c=(x, y)), 1.8 * k, 0.9 * k, rot=deg - 20, op=0.8))


def root_legs(x, y, deg, phase, span=1.0, curl=0.0):
    """A pair of root-hair legs from a knuckle at (x, y): out to a knee, then
    down and back to a curled foot."""
    P = []
    for side in (-1, 1):
        sw = math.sin(phase + (0 if side < 0 else math.pi)) * 3.4
        a = pt((x + side * 5.4, y), deg=deg, c=(x, y))
        b = pt((x + side * (12.4 * span - curl * 6), y - 2.6 + sw * 0.5 + curl * 2), deg=deg, c=(x, y))
        c = pt((x + side * (16.4 * span - curl * 12), y + 3.4 + sw + curl * 1.4), deg=deg, c=(x, y))
        e = pt((x + side * (15.2 * span - curl * 12), y + 5.6 + sw + curl * 1.4), deg=deg, c=(x, y))
        P.append(Part('limb', pth(smooth([a, b, c, e], closed=False)), width=1.5, fill=BARK_HI, line=BONE_LINE, lw=0.8))
    return P


def creep_skull(f, cx, cy, deg=0.0, jaw=0.0, mood='idle', k=1.0):
    """The small grinning skull, facing the viewer. Returns (parts, eyes)."""
    c = (cx, cy)

    def P(x, y):
        return pt((cx + x * k, cy + y * k), deg=deg, c=c)
    jd = jaw * 5.0
    jawp = [P(-6.4, 4 + jd), P(-5, 8.6 + jd), P(0, 10 + jd), P(5, 8.6 + jd), P(6.4, 4 + jd)]
    teeth = ''.join('<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" rx="0.4" fill="#fffaf0" stroke="%s" stroke-width="0.5" transform="rotate(%.1f %.1f %.1f)"/>' % (
        P(x, 4.4 + jd)[0], P(x, 4.4 + jd)[1], 2.2 * k, 2.2 * k, BONE_LINE, deg, P(x, 4.4 + jd)[0], P(x, 4.4 + jd)[1])
        for x in (-4.6, -2.2, 0.2, 2.6))
    parts = [Part('fill', pth(smooth(jawp)), fill=BONE_BACK, shade=BONE_BACK_SH, off=(-0.6, -0.8), over=teeth)]
    cran = [P(-10, 0), P(-9, -7), P(-4.4, -10.6), P(0, -11.2), P(4.4, -10.6), P(9, -7), P(10, 0), P(8.4, 4.8), P(3, 6.6),
            P(-3, 6.6), P(-8.4, 4.8)]
    e1, e2 = P(-4.2, -1.6), P(4.4, -1.8)
    fc = ''
    halo = f.ctx.radgrad([(0, SPORE_EYE, 0.5), (1, SPORE_EYE, 0)])
    fc += '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s"/>' % (cx, cy - 1.6, 12 * k, 7 * k, halo)
    if mood == 'swirl':
        for e in (e1, e2):
            fc += dot(e[0], e[1], 3.2 * k, BONE_LINE) + swirl_eye(e[0], e[1], 2.6 * k, SPORE_EYE, 0.9)
    elif mood == 'hit':
        for i, e in enumerate((e1, e2)):
            fc += dot(e[0], e[1], 3.3 * k, BONE_LINE) + squeeze(e[0], e[1], 4.4 * k, SPORE_EYE, flip=i == 1, w=1.3)
    else:
        big = mood == 'glint'
        for e in (e1, e2):
            fc += glow_eye(f.ctx, e[0], e[1], (7.2 if big else 6.4) * k, (7.8 if big else 7.2) * k, look=(0, 0.3),
                           iris=0.38 if big else 0.34, col=SPORE_EYE)
    nose = P(0, 2.4)
    fc += '<path d="M%.1f %.1f l-1.3 1.8 l2.6 0 Z" fill="%s"/>' % (nose[0], nose[1] - 0.8, BONE_LINE)
    # the grin across the upper teeth
    g = [P(-6, 4.2), P(0, 5.6), P(6, 4.2)]
    fc += line('M%s Q%s %s' % (fmt(g[0]), fmt(g[1]), fmt(g[2])), BONE_LINE, 1.1)
    parts.append(Part('fill', pth(smooth(cran)), fill=BONE, shade=BONE_SH, off=(-1.4, -1.6), over=fc,
                      hl=spec(*P(-5, -7), 2.8 * k, 1.4 * k, rot=-35 + deg, op=0.9)))
    return parts, [e1, e2]


def creep_chain(f, spine, phase=0.0, span=1.0, curl=0.0, legs_front=False):
    """Knuckles along spine (a list of (x, y) from the neck down), legs on each
    (legs_front: on its back, the legs kick in front of the bones)."""
    back = []
    for i, (x, y) in enumerate(spine):
        nx, ny = spine[min(i + 1, len(spine) - 1)]
        px, py = spine[max(i - 1, 0)]
        deg = math.degrees(math.atan2(ny - py, nx - px)) - 90
        k = 1.0 - i * 0.07
        back.append((x, y, deg, k, i))
    if not legs_front:
        for x, y, deg, k, i in back:
            f.add(root_legs(x, y, deg, phase + i * 1.3, span * k, curl))
    for x, y, deg, k, i in reversed(back):
        f.add(knuckle(x, y, deg, k))
    if legs_front:
        for x, y, deg, k, i in back:
            f.add(root_legs(x, y, deg + (180 if i % 2 else 0), phase + i * 1.3, span * k, curl))
    tx, ty = spine[-1]
    px, py = spine[-2]
    dx, dy = tx - px, ty - py
    ln = math.hypot(dx, dy) or 1
    tip = (tx + dx / ln * 9, ty + dy / ln * 9)
    f.P.insert(0, Part('limb', pth('M%.1f %.1f L%.1f %.1f' % (tx, ty, tip[0], tip[1])), width=2.2, fill=BONE))


def spine_path(y0, y1, n, amp, phase, xc=64.0, waves=1.0):
    return [(xc + amp * math.sin(phase + waves * math.pi * i / (n - 1)), y0 + (y1 - y0) * i / (n - 1)) for i in range(n)]


# Each Creepbone frame is drawn round the frame's middle, then moved down so its
# tail end stands on the feet line (64, 122) like every walker (contract §13): its
# lane runs along frame x 64, the tail at the anchor and the skull 40 px up.
CREEP_SHIFT = {'crawl1': (0, 9.5), 'crawl2': (0, 8.5), 'coil': (0, 17.5), 'lunge': (0, 0.5), 'fall': (0, 10.5),
               'hit': (0, 14.5)}


def creep_svg(frame):
    name = 'creep_' + frame
    f = Fr(name, dict(line=BONE_LINE, rim=RIM, base=BONE, shade=BONE_SH), shift=CREEP_SHIFT[frame])
    if frame in ('crawl1', 'crawl2'):
        ph = 0.0 if frame == 'crawl1' else 1.6
        sp = spine_path(52, 100, 6, 2.6, ph, waves=1.4)
        creep_chain(f, sp, phase=ph)
        hy = 39 if frame == 'crawl1' else 39.6
        parts, eyes = creep_skull(f, 64 + 2.6 * math.sin(ph - 0.5), hy, deg=-4 if ph else 4)
        f.add(parts)
        f.mark(eyes, 3.2, hit=(48, 26, 32, 84), head=(64, hy))
    elif frame == 'coil':
        # the tell: curled into an S, rattling, the eyes lit
        sp = [(62, 50), (70, 55), (72, 63), (66, 70), (58, 76), (56, 84), (62, 91)]
        creep_chain(f, sp, phase=0.8, span=0.9, curl=0.3)
        parts, eyes = creep_skull(f, 60, 40, deg=-10, mood='glint')
        f.add(parts)
        f.over = glint(eyes[1][0] + 1, eyes[1][1] - 1, 5.0, TELL3) + motion('M42 60 L38 58 M86 66 L90 64 M40 84 L36 86', 1.0)
        f.mark(eyes, 3.6, hit=(44, 28, 40, 72), glint=eyes[1])
    elif frame == 'lunge':
        sp = spine_path(30, 108, 7, 0.8, 0.3)
        creep_chain(f, sp, phase=0.4, span=0.8, curl=-0.4)
        parts, eyes = creep_skull(f, 64, 19, jaw=1.0)
        f.add(parts)
        f.over = motion('M46 100 L46 112 M82 100 L82 112 M44 76 L44 86 M84 76 L84 86', 1.2)
        f.mark(eyes, 3.2, hit=(48, 8, 32, 112), bite=(64, 29))
    elif frame == 'fall':
        # knocked off, on its back: legs curled and kicking, dizzy
        sp = spine_path(46, 98, 6, 1.4, 0.0)
        creep_chain(f, sp, phase=2.2, span=0.9, curl=0.5, legs_front=True)
        parts, eyes = creep_skull(f, 64, 33, deg=12, mood='swirl')
        f.add(parts)
        # no dizzy stars in the frame: it is turned 90 deg on the floor, so code draws them upright over it
        f.mark(eyes, 3.2, hit=(46, 20, 36, 86), belly=(64, 72))
    else:   # hit: the skull knocked aside, the chain jolted apart
        sp = [(66, 46), (61, 55), (65, 65), (61, 75), (66, 85), (63, 95)]
        creep_chain(f, sp, phase=1.0, span=1.1)
        parts, eyes = creep_skull(f, 70, 31, deg=24, mood='hit')
        f.add(parts)
        f.over = sweat(84, 22, 0.45, 25) + motion('M86 36 L94 32 M44 26 L38 20 M90 48 L96 48', 1.2)
        f.mark(eyes, 3.2, hit=(48, 18, 36, 88))
    return f.svg()


# ================================================================ World 4: the Tickwind

NAVY, NAVY_SH, NAVY_HI, NAVY_LINE = '#34508e', '#22376a', '#5a78b8', '#121a30'
BRASS, BRASS_SH, BRASS_HI = '#d8b24a', '#a8842a', '#ffe28a'
FROST, FROST_SH = '#c8e4f4', '#98c6e0'     # frost for decoration: bluer than the tell accent e8fcff
ICE, ICE_SH, ICE_HI = '#bfe4f4', '#8ab8d8', '#d0eaf6'   # ICE_HI: the ice's shine (not white)
PORC, PORC_SH = '#f6e8d2', '#d8c2a2'
TELL4 = '#e8fcff'         # World 4's tell accent
SHINE4 = ICE_HI            # W4's shines, motion lines and sparkles (white is for tells)
TPAL = dict(line=NAVY_LINE, rim=RIM, base=NAVY, shade=NAVY_SH)
CYAN = dict(line=NAVY_LINE, base=PORC, iris0='#06283e', iris1='#3aa8e0', iris2='#b4f4ff', blush='#ff7a8a')


def rrect_pts(x0, y0, x1, y1, r):
    """A rounded rectangle as smooth points (corners rounded by r)."""
    return [(x0 + r, y0, 0), (x1 - r, y0, 0), (x1, y0 + r, 0), (x1, y1 - r, 0), (x1 - r, y1, 0), (x0 + r, y1, 0),
            (x0, y1 - r, 0), (x0, y0 + r, 0)]


def rrect_d(x0, y0, x1, y1, r):
    return ('M%.2f %.2f L%.2f %.2f Q%.2f %.2f %.2f %.2f L%.2f %.2f Q%.2f %.2f %.2f %.2f L%.2f %.2f Q%.2f %.2f %.2f %.2f '
            'L%.2f %.2f Q%.2f %.2f %.2f %.2f Z') % (x0 + r, y0, x1 - r, y0, x1, y0, x1, y0 + r, x1, y1 - r, x1, y1, x1 - r, y1,
                                                    x0 + r, y1, x0, y1, x0, y1 - r, x0, y0 + r, x0, y0, x0 + r, y0)


def xpath(d, t):
    return '<path d="%s" transform="%s" {a}/>' % (d, t)


def wind_key(cx, cy, turn=1.0, t='translate(0 0)'):
    """The big brass wind-up key in its back: a shaft and a two-lobed bow.
    turn 1 = the bow flat to us, 0 = edge-on."""
    P = [Part('limb', xpath('M%.1f %.1f L%.1f %.1f' % (cx + 10, cy, cx + 3, cy), t), width=2.6, fill=BRASS_SH)]
    w = 5.2 * max(turn, 0.18)
    for sy in (-1, 1):
        lobe = smooth([(cx + 3, cy + sy * 1.2), (cx - 0.4, cy + sy * (2 + w * 0.3)), (cx - 2.4, cy + sy * (2.6 + w)),
                       (cx + 1.6, cy + sy * (3.4 + w * 1.4)), (cx + 5.4, cy + sy * (2.8 + w * 0.9)), (cx + 4.6, cy + sy * 1.4)])
        hole = ''
        if turn > 0.5:
            hole = '<ellipse cx="%.1f" cy="%.1f" rx="1.1" ry="%.1f" fill="%s" transform="%s"/>' % (
                cx + 1.8, cy + sy * (2.6 + w * 0.8), w * 0.22, NAVY_LINE, t)
        P.append(Part('fill', xpath(lobe, t), fill=BRASS, shade=BRASS_SH, off=(-0.8, -0.8), over=hole))
    return P


def tick_body(f, dx=0.0, dy=0.0, deg=0.0, legs=(0.0, 0.0), arms=(0.0, 0.0), mood='open', key_turn=1.0, hat=(0, 0, 0),
              brow=False):
    """The toy soldier round (64 + dx, 100 + dy), tipped deg about its feet.
    Returns the eye points."""
    c = (64 + dx, 121)
    T = 'rotate(%.1f %.1f %.1f) translate(%.1f %.1f)' % (deg, c[0], c[1], dx, dy)

    def P(x, y):
        return pt((x + dx, y + dy), deg=deg, c=c)
    parts = []
    # the key behind the drum
    parts += wind_key(40, 100, key_turn, T)
    # legs: white trousers, black boots
    for i, (hx, sw) in enumerate(((59, legs[0]), (69, legs[1]))):
        col = '#e8e4ec' if i else '#c8c4d4'
        foot = (hx + sw, 119.4)
        parts.append(Part('limb', xpath('M%.1f 108 L%.1f 116' % (hx, hx + sw * 0.8), 'rotate(%.1f %.1f %.1f)' % (deg, c[0], c[1]) + ' translate(%.1f 0)' % dx),
                          width=4.6, fill=col))
        boot = pth(smooth([(foot[0] - 3.6 + dx, 121.8, 0), (foot[0] - 3.4 + dx, 117.8), (foot[0] + 1 + dx, 116.4),
                           (foot[0] + 4.6 + dx, 118.6), (foot[0] + 5 + dx, 121.8, 0)]))
        parts.append(Part('fill', boot, fill='#2a2a3a', shade='#15151f', off=(-0.6, -0.8),
                          hl=spec(foot[0] + dx, 118, 1.4, 0.7, op=0.8)))
    # the back arm
    parts.append(Part('limb', xpath('M52 96 Q%.1f 102 %.1f 106' % (48 - arms[0] * 0.5, 50 - arms[0]), T), width=3.4, fill=NAVY_SH))
    parts.append(Part('fill', xpath(ell_path(50 - arms[0], 106.6, 2.8, 2.6), T), fill='#f4f4fa', shade='#c8c8d8', off=(-0.6, -0.6)))
    # the drum body with brass hoops and a white cord
    drum = rrect_d(49, 91, 79, 111, 5)
    cords = ''.join('M%.1f 94.4 L%.1f 107.6 L%.1f 94.4 ' % (x, x + 4, x + 8) for x in (51, 59, 67))
    over = (line(cords, '#f4f0e0', 1.3) + line('M49.4 93.4 L78.6 93.4', BRASS, 2.8, cap='butt')
            + line('M49.6 109 L78.4 109', BRASS, 2.8, cap='butt')
            + line('M49.4 93.4 L78.6 93.4 M49.6 109 L78.4 109', BRASS_SH, 0.6, cap='butt', op=0.8)
            + dot(53, 93.4, 0.9, BRASS_HI) + dot(75, 109, 0.9, BRASS_HI))
    # frost crust on its shoulders
    over += line('M51 91.8 Q64 90 77 91.8', FROST, 2.0, op=0.95)
    parts.append(Part('fill', xpath(drum, T), fill=NAVY, shade=NAVY_SH, off=(-2.4, -2), over=gx(over, T),
                      hl=gx(line('M52 97 L52 106', NAVY_HI, 1.6, op=0.9), T)))
    # the head: painted porcelain
    e1, e2 = P(60.8, 83.8), P(69.4, 83.4)
    fc = face_eyes(f, [(e1[0], e1[1], 6.4, 7.6), (e2[0], e2[1], 5.4, 7.2)], CYAN, look=(0.9, 0.2), mood=mood,
                   lid=0.3 if brow else 0.0)
    if brow:
        fc += line('M%.1f %.1f L%.1f %.1f M%.1f %.1f L%.1f %.1f' % (e1[0] - 3.4, e1[1] - 5.4, e1[0] + 2.8, e1[1] - 4,
                                                                   e2[0] - 2.4, e2[1] - 4, e2[0] + 3, e2[1] - 5.4), NAVY_LINE, 1.3)
    m = P(66, 88.6)
    if mood in ('squeeze', 'swirl'):
        fc += mouth(m[0], m[1] - 0.4, 3.4, 2, NAVY_LINE)
    else:
        fc += smile(m[0], m[1], 3.2, NAVY_LINE, 1.0, 1.0)
    fc += dot(*P(56.4, 87.4), 2.2, '#ff7a8a', 0.75) + dot(*P(73, 86.8), 1.7, '#ff7a8a', 0.75)
    head = xpath(ell_path(64, 84.6, 10.6, 8.4), T)
    parts.append(Part('fill', head, fill=PORC, shade=PORC_SH, off=(-1.4, -1.4), over=fc,
                      hl=gx(spec(58, 80, 2.4, 1.2, op=0.9), T)))
    # the shako: brim, body, brass plate, the icicle plume
    hx, hy, hd = hat
    HT = T + ' rotate(%.1f 64 78) translate(%.1f %.1f)' % (hd, hx, hy)
    plume = smooth([(62.4, 66, 0), (63.2, 60), (64, 53.6, 0), (65.4, 60), (66, 66, 0)])
    parts.append(Part('fill', xpath(plume, HT), fill=FROST, shade=FROST_SH, off=(-0.6, 0),
                      hl=gx(hi_line('M63.6 64 L64 57', ICE_HI, 0.7), HT)))
    shako = smooth([(55.6, 78.4, 0), (56, 67.4, 0), (72.4, 66.2, 0), (73.2, 78.4, 0)])
    plate = ('<path d="M64.4 69.4 L66.8 71.6 L66.2 74.8 L62.8 74.8 L62.2 71.6 Z" fill="%s" stroke="%s" stroke-width="0.6"/>'
             % (BRASS, BRASS_SH)) + dot(64.5, 72.4, 0.8, BRASS_HI)
    parts.append(Part('fill', xpath(shako, HT), fill=NAVY, shade=NAVY_SH, off=(-1.2, -1), over=gx(plate + line('M56.4 68.6 L72.6 67.4', FROST, 1.4, op=0.9), HT)))
    brim = smooth([(55, 77.4, 0), (74.4, 77.4, 0), (76.6, 79.6, 0), (55, 79.6, 0)])
    parts.append(Part('fill', xpath(brim, HT), fill='#2a2a3a', shade='#15151f', off=(0, -0.6)))
    # the front arm with its white glove
    parts.append(Part('limb', xpath('M76 96 Q%.1f 102 %.1f 105' % (79 + arms[1] * 0.5, 78 + arms[1]), T), width=3.4, fill=NAVY))
    parts.append(Part('fill', xpath(ell_path(78.4 + arms[1], 105.8, 2.8, 2.6), T), fill='#ffffff', shade='#d0d0dc', off=(-0.6, -0.6)))
    f.add(parts)
    return [e1, e2]


def ell_path(cx, cy, rx, ry):
    k = 0.5523
    return ('M%.2f %.2f C%.2f %.2f %.2f %.2f %.2f %.2f C%.2f %.2f %.2f %.2f %.2f %.2f C%.2f %.2f %.2f %.2f %.2f %.2f '
            'C%.2f %.2f %.2f %.2f %.2f %.2f Z') % (cx + rx, cy, cx + rx, cy + ry * k, cx + rx * k, cy + ry, cx, cy + ry,
                                                  cx - rx * k, cy + ry, cx - rx, cy + ry * k, cx - rx, cy, cx - rx, cy - ry * k,
                                                  cx - rx * k, cy - ry, cx, cy - ry, cx + rx * k, cy - ry, cx + rx, cy - ry * k,
                                                  cx + rx, cy)


def steam(x, y, k=1.0):
    return puff(x, y, 3.2 * k, '#f4f8ff', 0.85, key=NAVY_LINE) + puff(x - 3 * k, y - 3.4 * k, 2.2 * k, '#f4f8ff', 0.75, key=NAVY_LINE)


def tick_svg(frame):
    name = 'tick_' + frame
    f = Fr(name, TPAL, shine=SHINE4)
    f.under = ground_shadow(62, 16)
    hit = (44, 56, 40, 66)
    if frame in ('march1', 'march2'):
        a = 1 if frame == 'march1' else -1
        eyes = tick_body(f, dy=-0.8 if a < 0 else 0, legs=(-3.4 * a, 3.4 * a), arms=(3 * a, -3 * a), key_turn=1.0 if a > 0 else 0.45)
        f.mark(eyes, 3.2, hit=hit, key=(38, 100))
    elif frame == 'wind':
        # the tell: stopped, the key a spinning blur, a ratchet clicking up, steam, a glint on the key
        eyes = tick_body(f, dy=1.0, legs=(-1, 1), arms=(-2, 2), key_turn=0.2, brow=True)
        f.under += ('<ellipse cx="39" cy="100" rx="5" ry="10.4" fill="none" stroke="%s" stroke-width="3" opacity="0.5"/>' % BRASS_HI)
        f.over = (motion('M33 88 Q28 100 33 112 M45 86 Q49 92 47 96', 1.1) + steam(52, 64) + steam(78, 66, 0.9)
                  + glint(37, 94, 6.2, TELL4))
        f.mark(eyes, 3.4, hit=hit, key=(37, 96))
    elif frame == 'charge':
        eyes = tick_body(f, dx=4, deg=12, legs=(-5, 5), arms=(-5, -3), key_turn=0.3, brow=True, hat=(0, 0, -6))
        f.over = (motion('M20 96 L8 96 M22 104 L6 104 M26 112 L12 112 M44 120 L32 120', 1.3) + steam(26, 84, 0.9) + steam(18, 90, 0.7))
        f.mark(eyes, 3.4, hit=(46, 56, 44, 66), front=(94, 100))
    elif frame == 'dizzy':
        eyes = tick_body(f, deg=-10, legs=(-2, 3), arms=(3, 3), mood='swirl', key_turn=0.6, hat=(1, -1, 18))
        coil = 'M36 96 q-4 -1 -3 -4 q4 -1 3 -4 q-4 -1 -3 -4 q4 -1 3 -4'
        f.over = line(coil, NAVY_LINE, 2.6) + line(coil, BRASS_HI, 1.2) + dizzy_stars(62, 52, 12, 3.4, 3)
        f.mark(eyes, 3.2, hit=hit, stars=(62, 52))
    else:   # hit
        eyes = tick_body(f, deg=-8, legs=(2, -2), arms=(6, 5), mood='squeeze', key_turn=0.8, hat=(-3, -7, -22))
        f.over = sweat(82, 76, 0.45, 25) + motion('M86 66 L92 60 M88 80 L96 78 M36 70 L30 64', 1.3)
        f.mark(eyes, 3.2, hit=hit)
    return f.svg()


# ================================================================ World 4: the Spurwheel

GRIND = '#e0602a'         # the grinder rim: the Spurwheel's alone (no platform cog has it)


def cog_pts(cx, cy, r_tip, r_root, n, turn=0.0, tip_w=0.34, root_w=0.5):
    """A gear outline: n teeth; tip_w and root_w are the tooth's share of its pitch."""
    pts = []
    pitch = 2 * math.pi / n
    for i in range(n):
        a = turn + i * pitch
        for da, r in ((-root_w / 2, r_root), (-tip_w / 2, r_tip), (tip_w / 2, r_tip), (root_w / 2, r_root)):
            pts.append((cx + r * math.cos(a + da * pitch), cy + r * math.sin(a + da * pitch), 0))
    return pts


SPUR_EYES = ((59.2, 62), (69, 61.6))


def spur_hub(f, mood, rim=True):
    """The hub disc with its stern little face (r 11.6 round (64, 64)). The same
    disc is drawn into the turning cog frames and, upright, as the spur_face
    overlays, which cover it exactly."""
    e1, e2 = SPUR_EYES
    fc = ''
    if mood == 'open':
        fc += face_eyes(f, [(e1[0], e1[1], 5.4, 6.4), (e2[0], e2[1], 4.6, 6)], CYAN, look=(1.0, 0.2), lid=0.36)
        fc += line('M55.6 56 L62 57.6 M66.4 57.4 L72.6 55.6', NAVY_LINE, 1.5)
        fc += line('M61 69.6 L68 69.2', NAVY_LINE, 1.3)
    elif mood == 'grit':
        fc += face_eyes(f, [(e1[0], e1[1], 5.4, 6.4), (e2[0], e2[1], 4.6, 6)], CYAN, look=(0, 0.4), lid=0.5)
        fc += line('M55.6 55 L62 57.8 M66.4 57.6 L72.6 54.8', NAVY_LINE, 1.6)
        fc += ('<rect x="58.4" y="67.4" width="11.6" height="4" rx="1" fill="#ffffff" stroke="%s" stroke-width="1"/>' % NAVY_LINE
               + line('M61.3 67.6 L61.3 71.2 M64.2 67.6 L64.2 71.2 M67.1 67.6 L67.1 71.2', NAVY_LINE, 0.6))
    else:
        fc += face_eyes(f, [(e1[0], e1[1], 5.4, 6.4), (e2[0], e2[1], 4.6, 6)], CYAN, mood='squeeze')
        fc += mouth(64.4, 68.4, 4, 2.4, NAVY_LINE)
    return Part('fill', ell(64, 64, 11.6, 11.6), fill=mix(BRASS, BRASS_HI, 0.35), shade=BRASS_SH, off=(-1.4, -1.6),
                over=fc, hl=spec(57, 56, 2.6, 1.2, op=0.8), rim=rim)


SPUR_MOOD = {'roll': 'open', 'catch': 'grit', 'hit': 'squeeze'}


def spur_svg(frame):
    """The turning cog (code turns the sprite about its hub as it rolls), so
    nothing in it has a direction: no motion arc, no trail, no sparks (code
    draws the frost trail and puts the sparks at the contact point). The hub
    face is drawn in too, and the upright spur_face overlays cover it."""
    if frame.startswith('face'):
        return spur_face_svg(frame)
    name = 'spur_' + frame
    f = Fr(name, dict(line=NAVY_LINE, rim=RIM, base=BRASS, shade=BRASS_SH), shine=SHINE4)
    cx, cy = 64, 64
    turn = math.radians(8 if frame == 'roll' else 0)
    sq = (1.06, 0.94) if frame == 'hit' else (1.0, 1.0)
    jam = frame == 'catch'
    # jammed, its spurs bristle: longer, narrower teeth and a hot, thick grinder rim
    r_tip, tip_w = (31.0, 0.24) if jam else (28.0, 0.34)
    teeth = tf(cog_pts(cx, cy, r_tip, 21.4, 12, turn, tip_w), sx=sq[0], sy=sq[1], c=(cx, cy))
    rim_in = tf(cog_pts(cx, cy, r_tip - 1.6, 20.2, 12, turn, tip_w * 0.88, 0.46), sx=sq[0], sy=sq[1], c=(cx, cy))
    over = '<path d="%s" fill="none" stroke="%s" stroke-width="%.1f" stroke-linejoin="round"/>' % (
        poly(rim_in), GRIND, 3.4 if jam else 2.2)
    # frost caps on the teeth
    for i in range(0, 12, 2):
        a = turn + i * 2 * math.pi / 12
        x, y = cx + (r_tip - 1.4) * math.cos(a) * sq[0], cy + (r_tip - 1.4) * math.sin(a) * sq[1]
        over += '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="1.3" fill="%s" transform="rotate(%.1f %.1f %.1f)"/>' % (
            x, y, 1.6 if jam else 2.2, FROST, math.degrees(a) + 90, x, y)
    # the disc: a darker groove ring and four spoke slots
    over += '<circle cx="%.1f" cy="%.1f" r="16.4" fill="none" stroke="%s" stroke-width="1.2" opacity="0.8"/>' % (cx, cy, BRASS_SH)
    for i in range(4):
        a = turn + math.pi / 4 + i * math.pi / 2
        x, y = cx + 17.6 * math.cos(a), cy + 17.6 * math.sin(a)
        over += '<ellipse cx="%.1f" cy="%.1f" rx="2.4" ry="1.4" fill="%s" transform="rotate(%.1f %.1f %.1f)"/>' % (
            x, y, '#5a3a10', math.degrees(a), x, y)
    f.add(Part('fill', pth(poly(teeth)), fill=BRASS, shade=BRASS_SH, off=(-3, -3.4), over=over,
               hl=hi_line('M44 50 Q52 40 64 38.4', BRASS_HI, 1.8, op=0.9)))
    f.add(spur_hub(f, SPUR_MOOD[frame]))
    e1, e2 = SPUR_EYES
    if frame == 'roll':
        f.mark([e1, e2], 2.7, hit=(36, 36, 56, 56), hub=(64, 64))
    elif frame == 'catch':
        f.mark([e1, e2], 2.7, hit=(34, 34, 60, 60), hub=(64, 64))
    else:
        f.mark([e1, e2], 2.7, hit=(34, 38, 60, 52), hub=(64, 64))
    return f.svg()


def spur_face_svg(frame):
    """spur_face, spur_face_catch, spur_face_hit: the hub face alone, drawn
    upright (not turned) over the turning cog at the same anchor, so the stern
    face, its sweat and the hit's stars stay the right way up."""
    name = 'spur_' + frame
    f = Fr(name, dict(line=NAVY_LINE, rim=RIM, base=BRASS, shade=BRASS_SH), shine=SHINE4)
    mood = {'face': 'open', 'face_catch': 'grit', 'face_hit': 'squeeze'}[frame]
    f.add(spur_hub(f, mood, rim=False))
    e1, e2 = SPUR_EYES
    if mood == 'grit':
        f.over = sweat(74, 54, 0.3, 20)
    elif mood == 'squeeze':
        f.over = (sparkle(96, 40, 3, NAVY_LINE, '#fff2a8') + sparkle(30, 44, 2.4, NAVY_LINE, '#fff2a8')
                  + motion('M98 58 L106 56 M96 74 L104 78 M30 76 L22 80', 1.2))
    f.mark([e1, e2], 2.7, hit=(52, 52, 24, 24), hub=(64, 64))
    return f.svg()


# ================================================================ World 4: the Frostbuckle

STEEL, STEEL_SH, STEEL_HI, STEEL_BK = '#8494b4', '#5c6a8a', '#c4d2ec', '#6c7a9a'
LANTERN = '#8ae0ff'
BPAL = dict(line=NAVY_LINE, rim=RIM, base=STEEL, shade=STEEL_SH)
SHELL_OFF = {'idle': (0, 0), 'walk1': (0, -1.2), 'walk2': (0, 0.6), 'raise': (-2, -4), 'stomp': (1, 2), 'slam': (5, 1),
             'hit': (-2, 0), 'thawed': (0, 4)}


def helm_eye(f, x, y, mood='open', k=1.0):
    """The one lantern-blue eye glowing through the visor slit."""
    s = ''
    halo = f.ctx.radgrad([(0, LANTERN, 0.7), (0.5, LANTERN, 0.3), (1, LANTERN, 0)])
    s += '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s"/>' % (x, y, 9 * k, 6 * k, halo)
    if mood == 'squeeze':
        s += squeeze(x, y, 5.4 * k, LANTERN, w=1.6)
    elif mood == 'swirl':
        s += swirl_eye(x, y, 3 * k, LANTERN, 1.1)
    else:
        big = mood == 'flare'
        s += '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s"/>' % (x, y, (3.6 if big else 3.0) * k, (3.0 if big else 2.4) * k, LANTERN)
        s += '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="#f4feff"/>' % (x + 0.3, y - 0.2, 1.6 * k, 1.2 * k)
        s += dot(x - 1.2 * k, y - 0.8 * k, 0.7 * k, '#ffffff')
    return s


def ice_shield(t, flash=False, cracked=False):
    """The tower shield of ice, local to its middle (0, 0): 26 x 52 units."""
    d = smooth([(-11, -24), (0, -27), (11, -24), (13, -8), (12.4, 12), (8, 24), (0, 27.4), (-8, 24), (-12.4, 12), (-13, -8)])
    facets = line('M-6 -20 L2 -6 L-4 8 L3 20 M8 -16 L2 -6 M-9 0 L-4 8', ICE_SH, 0.9, op=0.9)
    facets += line('M-8 -18 L-7 -2', ICE_HI, 1.4, op=0.9) + line('M-5.4 12 L-4.4 20', ICE_HI, 1.0, op=0.8)
    if cracked:
        facets += line('M4 -24 L1 -12 L6 -4 L2 6', NAVY_LINE, 1.1)
    rim = '<path d="%s" fill="none" stroke="%s" stroke-width="%.1f" opacity="%s" transform="scale(0.88)"/>' % (
        d, '#ffffff' if flash else FROST, 2.4 if flash else 1.4, 1.0 if flash else 0.85)
    return Part('fill', xpath(d, t), fill=ICE, shade=ICE_SH, off=(-2.4, -2), over=gx(facets + rim, t),
                hl=gx(spec(-6, -14, 3, 7, rot=-10, op=0.6), t))


def icicle_beard(x, y, k=1.0):
    pts = [(x - 8, y), (x - 6.4, y + 7 * k), (x - 4.4, y + 1), (x - 2, y + 10 * k), (x + 0.4, y + 1), (x + 3, y + 8.4 * k),
           (x + 5, y + 1), (x + 7, y + 5.4 * k), (x + 8.6, y)]
    return Part('fill', pth(poly(pts)), fill=FROST, shade=FROST_SH, off=(-0.8, 0),
                hl=hi_line('M%.1f %.1f L%.1f %.1f' % (x - 2.6, y + 1.4, x - 2.1, y + 7 * k), ICE_HI, 0.6))


def buckle_body(f, frame, dx=0.0, dy=0.0, lean=0.0, foot=None, shield=(0.0, 0.0, 0.0), mood='open', flash=False,
                back_arm=0.0):
    """The knight: legs (foot = the front foot's lift and reach), torso, pauldrons,
    helm, beard and the shield in front. Returns the eye point."""
    T = 'rotate(%.1f 64 104) translate(%.1f %.1f)' % (lean, dx, dy)

    def P(x, y):
        return pt((x + dx, y + dy), deg=lean, c=(64, 104))
    parts = []
    lift, reach = foot or (0.0, 0.0)
    # the back leg
    parts.append(Part('limb', pth('M56 %.1f L54 116' % (102 + dy)), width=8, fill=STEEL_BK))
    parts.append(Part('fill', pth(rrect_d(46, 114.6, 60, 122, 2.6)), fill=STEEL_BK, shade=STEEL_SH, off=(-1, -1)))
    # the back arm (a gauntlet behind the body)
    parts.append(Part('limb', xpath('M47 80 Q42 %.1f %.1f %.1f' % (90 + back_arm, 44 - back_arm * 0.4, 97 + back_arm * 0.3), T),
                      width=6, fill=STEEL_BK))
    # the front leg
    fx, fy = 72 + reach, 116 - lift
    parts.append(Part('limb', pth('M70 %.1f Q%.1f %.1f %.1f %.1f' % (102 + dy, 71 + reach * 0.5, 110 - lift * 0.6, fx, fy)), width=8.4,
                      fill=STEEL))
    parts.append(Part('fill', pth(rrect_d(fx - 6, fy - 1.4, fx + 9, fy + 6, 2.6)), fill=STEEL, shade=STEEL_SH, off=(-1, -1),
                      over=line('M%.1f %.1f L%.1f %.1f' % (fx - 4, fy + 1, fx + 6, fy + 1), STEEL_HI, 1.0, op=0.8)))
    # the torso: a round breastplate, a belt with its big brass buckle
    torso = rrect_d(44, 72, 84, 104, 10)
    tover = (line('M46 99 L82 99', '#3a3a4e', 4.2, cap='butt') + '<rect x="59.6" y="96" width="9" height="6.4" rx="1.2" fill="%s" stroke="%s" stroke-width="1"/>' % (BRASS, NAVY_LINE)
             + '<rect x="62" y="97.8" width="4.2" height="2.8" fill="#3a3a4e"/>' + line('M64 78 Q63 88 64 96', STEEL_SH, 1.0, op=0.8))
    parts.append(Part('fill', xpath(torso, T), fill=STEEL, shade=STEEL_SH, off=(-3, -3), over=gx(tover, T),
                      hl=gx(spec(52, 80, 3, 5, rot=-15, op=0.6), T)))
    # pauldrons with frost crust
    for x in (46, 81):
        pd = ell_path(x, 76, 9.6, 7.4)
        parts.append(Part('fill', xpath(pd, T), fill=STEEL if x > 60 else STEEL_BK, shade=STEEL_SH, off=(-1.4, -1.6),
                          over=gx(line('M%.1f 71.4 Q%.1f 68 %.1f 71.4' % (x - 7.4, x, x + 7.4), FROST, 2.4) + dot(x + 3, 70.6, 0.9, ICE_HI), T)))
    # the helm: a great bucket helm, the visor slit, the one eye
    helm = rrect_d(49, 44, 79, 72, 8)
    e = P(71, 59)
    hover = ('<path d="M53 57 L78 57 L78 61.6 L53 61.6 Z" fill="#0a0e1c"/>' + line('M64 47 L64 56', STEEL_SH, 1.2)
             + ''.join(dot(x, 66.6, 0.9, '#0a0e1c') for x in (56, 60, 64, 68, 72))
             + line('M50.6 47 Q64 42.4 77.4 47', FROST, 2.6) + dot(55, 45.8, 1.0, ICE_HI))
    heye = helm_eye(f, 71, 59.4, mood)
    parts.append(Part('fill', xpath(helm, T), fill=STEEL, shade=STEEL_SH, off=(-2.4, -2.4), over=gx(hover + heye, T),
                      hl=gx(spec(54, 50, 2.6, 1.4, op=0.8), T)))
    beard = icicle_beard(64, 72)
    beard.tpl = beard.tpl.replace(' {a}/>', ' transform="%s" {a}/>' % T)
    beard.hl = gx(beard.hl, T)
    parts.append(beard)
    # the shield in its front hand
    sx, sy, sd = shield
    parts.append(ice_shield('translate(%.1f %.1f) rotate(%.1f)' % (P(90 + sx, 92 + sy)[0], P(90 + sx, 92 + sy)[1], sd + lean),
                            flash=flash, cracked=frame in ('hit', 'thawed')))
    f.add(parts)
    return e


def buckle_shell_svg():
    """The rime: a block of glassy ice round the torso and helm (see-through),
    drawn over any buckle frame at its `shell` offset."""
    name = 'buckle_shell'
    f = Fr(name, BPAL, shine=SHINE4)
    d = smooth([(46, 38, 0), (64, 34), (82, 38, 0), (90, 52), (92, 74, 0), (90, 96), (84, 108, 0), (64, 110), (44, 108, 0),
                (38, 94), (36, 72, 0), (38, 52)])
    g = f.ctx.lingrad([(0, ICE_HI, 0.62), (0.5, ICE, 0.42), (1, ICE_SH, 0.5)], x2=1, y2=1)
    s = '<path d="%s" fill="%s" stroke="%s" stroke-width="4.4" stroke-linejoin="round" opacity="0.9"/>' % (d, g, '#1a3a5a')
    s += '<path d="%s" fill="none" stroke="%s" stroke-width="2" stroke-linejoin="round"/>' % (d, '#a6d0ea')
    s += line('M46 40 L54 60 L44 76 M82 40 L74 58 L88 72 M54 60 L74 58 M44 76 L58 92 L82 96 M58 92 L56 108', ICE_HI, 1.2, op=0.75)
    s += line('M42 52 L40 72', ICE_HI, 2.4, op=0.9) + line('M48 44 L54 42', ICE_HI, 2.2, op=0.9)
    s += star4(84, 50, 3.4, ICE_HI) + star4(42, 90, 2.4, ICE_HI, 0.9)
    f.over = s
    f.mark(hit=(36, 34, 56, 76))
    return f.svg()


def buckle_svg(frame):
    if frame == 'shell':
        return buckle_shell_svg()
    name = 'buckle_' + frame
    f = Fr(name, BPAL, shine=SHINE4)
    f.under = ground_shadow(64, 26)
    so = SHELL_OFF[frame]
    hit = (38, 42, 60, 80)
    if frame in ('idle', 'walk1', 'walk2'):
        a = {'idle': 0, 'walk1': 1, 'walk2': -1}[frame]
        e = buckle_body(f, frame, dy=so[1], foot=(2.4 if a > 0 else 0, 4 * a), shield=(0, so[1], 0), back_arm=-a * 2)
        f.mark([e], 3.0, hit=hit, shell_dx=so[0], shell_dy=so[1], shield=(90, 92 + so[1]))
    elif frame == 'raise':
        # the tell: rearing up, the front foot lifted, the shield hoisted, the eye flaring
        e = buckle_body(f, frame, dx=so[0], dy=so[1], lean=-5, foot=(14, 6), shield=(-4, -22, -20), mood='flare', flash=True,
                        back_arm=-6)
        f.over = glint(e[0] + 1, e[1] - 1, 5, TELL4) + motion('M100 44 L106 38 M104 58 L112 56', 1.1)
        f.mark([e], 3.4, hit=(34, 30, 64, 92), shell_dx=so[0], shell_dy=so[1], foot=(80, 108), shield=(86, 66))
    elif frame == 'stomp':
        e = buckle_body(f, frame, dx=so[0], dy=so[1], lean=3, foot=(0, 8), shield=(2, -1, 8), mood='open', back_arm=4)
        sh = ''
        for x, h, w in ((80, 12, 4), (88, 8, 3.4), (72, 7, 3), (96, 5, 2.6)):
            sh += '<path d="M%.1f 122 L%.1f %.1f L%.1f 122 Z" fill="%s" stroke="%s" stroke-width="1.2" stroke-linejoin="round"/>' % (
                x - w, x, 122 - h, x + w, FROST, NAVY_LINE)
        f.over = sh + motion('M60 121 L50 121 M104 121 L112 121', 1.2) + specks([(100, 112, 1.2), (70, 110, 1.0), (92, 104, 0.9)], FROST)
        f.mark([e], 3.0, hit=hit, shell_dx=so[0], shell_dy=so[1], stomp=(82, 120))
    elif frame == 'slam':
        e = buckle_body(f, frame, dx=so[0], dy=so[1], lean=10, foot=(0, 10), shield=(1, -8, 22), back_arm=10, mood='flare')
        f.over = (motion('M30 64 L20 66 M28 78 L16 80 M30 92 L20 94', 1.3) + star4(110, 70, 4, ICE_HI)
                  + specks([(116, 64, 1.2), (118, 92, 1.0)], FROST))
        f.mark([e], 3.0, hit=(38, 42, 76, 80), shell_dx=so[0], shell_dy=so[1], shield=(104, 90))
    elif frame == 'thawed':
        # the rime shattered: stunned, the shield sagging, ice falling off
        e = buckle_body(f, frame, dy=so[1], lean=-3, shield=(4, 1, 20), mood='swirl', back_arm=8)
        chips = ''
        for x, y, r, a in ((30, 60, 5, 20), (100, 48, 4.4, -30), (26, 90, 3.6, 50), (104, 80, 3.4, 10), (40, 36, 3, -20), (92, 30, 3, 40)):
            chips += '<path d="M%.1f %.1f l%.1f %.1f l%.1f %.1f Z" fill="%s" stroke="%s" stroke-width="1" transform="rotate(%d %.1f %.1f)"/>' % (
                x, y - r, r, r * 1.4, -r * 1.8, 0, ICE, NAVY_LINE, a, x, y)
        f.over = chips + dizzy_stars(64, 36, 13, 3.6, 3)
        f.mark([e], 3.0, hit=(38, 44, 64, 78), shell_dx=so[0], shell_dy=so[1], stars=(64, 36))
    else:   # hit (only without the rime)
        e = buckle_body(f, frame, dx=so[0], lean=-6, shield=(-3, 2, -8), mood='squeeze', back_arm=-4)
        f.over = sweat(84, 44, 0.5, 25) + motion('M92 36 L98 30 M96 50 L104 48 M30 50 L24 44', 1.3)
        f.mark([e], 3.0, hit=hit, shell_dx=so[0], shell_dy=so[1])
    return f.svg()


# ================================================================ World 4: the Hoarowl

SILV, SILV_SH, SILV_HI, SILV_BK = '#aeb2c0', '#7c8094', '#d4d8e6', '#8e92a4'
IRON, IRON_SH, IRON_HI = '#4a4658', '#302c3c', '#8a86a0'
OPAL = dict(line=NAVY_LINE, rim=RIM, base=SILV, shade=SILV_SH)
OWL_HEAD = (64, 77)       # the head's middle, on the body


def owl_bracket():
    base = rrect_d(52, 118, 76, 122, 1.6)
    P = [Part('fill', pth(base), fill=IRON, shade=IRON_SH, off=(-0.8, -0.8)),
         Part('limb', pth('M64 118 L64 110'), width=3.4, fill=IRON),
         Part('limb', pth('M44 108.6 L84 108.6'), width=3.2, fill=IRON,
              over=dot(64, 108.6, 1.2, BRASS) + line('M46 108 L82 108', IRON_HI, 0.8, op=0.8))]
    for x, s in ((44, -1), (84, 1)):
        P.append(Part('limb', pth('M%.1f 108.6 q%.1f 0 %.1f -3.4 q0 -2.6 %.1f -2.4' % (x, s * 3, s * 3, -s * 2)), width=2, fill=IRON))
    return P


def owl_body_parts(deg=0.0, cracked=False):
    T = 'rotate(%.1f 64 108)' % deg
    P = []
    for x, s in ((50, -1), (78, 1)):
        wing = smooth([(x - s * 1, 86), (x + s * 3, 90), (x + s * 4, 100), (x + s * 1, 106), (x - s * 4, 102), (x - s * 4, 92)])
        P.append(Part('fill', xpath(wing, T), fill=SILV_BK, shade=SILV_SH, off=(-1, -1),
                      over=gx(line('M%.1f 92 L%.1f 101 M%.1f 94 L%.1f 103' % (x, x, x + s * 2, x + s * 2), SILV_SH, 0.8), T)))
    body = ell_path(64, 96.4, 14.6, 13.4)
    sc = ''
    for row, y in enumerate((91, 96, 101)):
        for i in range(-2, 3):
            x = 64 + i * 5 + (2.5 if row % 2 else 0)
            if abs(x - 64) > 10.6 - row:
                continue
            sc += line('M%.1f %.1f q2.4 2.6 4.8 0' % (x - 2.4, y), SILV_SH, 0.9, op=0.9)
            sc += dot(x, y + 1.4, 0.7, ICE_HI, 0.9)
    key = ('<path d="M64 99.6 m-2 0 a2 2 0 1 1 4 0 a2 2 0 0 1 -1 1.7 l0.8 3.6 l-3.6 0 l0.8 -3.6 a2 2 0 0 1 -1 -1.7 Z" fill="#0a0e1c"/>')
    key += '<circle cx="64" cy="100.2" r="4.4" fill="none" stroke="%s" stroke-width="1.4"/>' % BRASS
    if cracked:
        key += line('M56 88 L60 94 L57 99 L61 104', NAVY_LINE, 1.1)
    P.append(Part('fill', xpath(body, T), fill=SILV, shade=SILV_SH, off=(-2.4, -2.4), over=gx(sc + key + line('M53 86 Q64 82 75 86', FROST, 2.2), T),
                  hl=gx(spec(56, 88, 3, 1.6, op=0.8), T)))
    for x in (59, 69):
        P.append(Part('fill', xpath(smooth([(x - 3, 109.6, 0), (x - 2.6, 106), (x + 0.4, 105), (x + 3, 106.4), (x + 3.4, 109.6, 0)]), T),
                      fill=BRASS, shade=BRASS_SH, off=(-0.5, -0.6)))
    return P


def owl_head_parts(f, look=0.0, deg=0.0, mood='open', beak=0.0, k=1.0, c=OWL_HEAD):
    """The head round c; look -1 (left) .. 1 (right) swings the face; mood
    'open', 'flare', 'squeeze', 'broken'. Returns (parts, eyes, cone point)."""
    cx, cy = c
    T = 'rotate(%.1f %.1f %.1f)' % (deg, cx, cy)

    def P(x, y):
        return pt((cx + x * k, cy + y * k), deg=deg, c=c)
    parts = []
    # ear tufts like clock hands
    for s in (-1, 1):
        tuft = poly([P(s * 5 + look * 2, -9), P(s * 11 + look * 1.4, -17.4), P(s * 9.6 + look * 2, -7.4)])
        parts.append(Part('fill', pth(tuft), fill=SILV_BK, shade=SILV_SH, off=(0, -0.6),
                          over=dot(*P(s * 10.6 + look * 1.4, -16), 0.9, FROST)))
    head = smooth([P(0, -12.6), P(10, -10.6), P(15, -3), P(14.4, 5), P(9, 10.4), P(0, 12), P(-9, 10.4), P(-14.4, 5),
                   P(-15, -3), P(-10, -10.6)])
    fc = ''
    # the facial disc, swung by look
    fx = look * 4.6
    fc += '<path d="%s" fill="%s" opacity="0.9"/>' % (smooth([P(fx - 12, -2), P(fx - 6, -8), P(fx, -5), P(fx + 6, -8), P(fx + 12, -2),
                                                              P(fx + 8, 7), P(fx, 9), P(fx - 8, 7)]), SILV_HI)
    eyes = [P(fx - 5.8, -1), P(fx + 5.8, -1)]
    for i, (ex, ey) in enumerate(eyes):
        r = 5.2 * k
        fc += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s" stroke="%s" stroke-width="1.2"/>' % (ex, ey, r + 1.2, BRASS, NAVY_LINE)
        if mood == 'squeeze':
            fc += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="#0a0e1c"/>' % (ex, ey, r)
            fc += squeeze(ex, ey, r * 1.3, LANTERN, flip=i == 1, w=1.4)
        elif mood == 'broken' and i == 1:
            fc += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="#1a2030"/>' % (ex, ey, r)
            fc += line('M%.1f %.1f L%.1f %.1f L%.1f %.1f' % (ex - 3, ey - 3, ex, ey, ex + 1, ey + 4), '#8a9ab0', 0.9)
        else:
            g = f.ctx.radgrad([(0, '#ffffff'), (0.35, '#d4faff'), (0.7, LANTERN), (1, '#2a7aa8')])
            fc += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s"/>' % (ex, ey, r, g)
            pr = 1.8 if mood != 'flare' else 1.2
            fc += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="#0a3a5a"/>' % (ex + look * 1.6, ey + 0.4, pr * k)
            fc += dot(ex - 1.8 * k, ey - 1.8 * k, 1.3 * k, '#ffffff')
    bk = P(fx, 4.4)
    if beak > 0:
        fc += '<path d="M%s L%s L%s Z" fill="%s" stroke="%s" stroke-width="0.8"/>' % (
            fmt(P(fx - 2.6, 2.6)), fmt(P(fx + 2.6, 2.6)), fmt(P(fx, 6.2 - beak * 2)), BRASS, NAVY_LINE)
        fc += '<path d="M%s L%s L%s Z" fill="#3a1a24"/>' % (fmt(P(fx - 2, 5)), fmt(P(fx + 2, 5)), fmt(P(fx, 5 + beak * 5)))
        fc += '<path d="M%s L%s L%s Z" fill="%s" stroke="%s" stroke-width="0.8"/>' % (
            fmt(P(fx - 2.2, 5 + beak * 3)), fmt(P(fx + 2.2, 5 + beak * 3)), fmt(P(fx, 8 + beak * 4)), BRASS_SH, NAVY_LINE)
    else:
        fc += '<path d="M%s L%s L%s Z" fill="%s" stroke="%s" stroke-width="0.8"/>' % (
            fmt(P(fx - 2.4, 2.2)), fmt(P(fx + 2.4, 2.2)), fmt(P(fx, 7.4)), BRASS, NAVY_LINE)
    fc += line('M%s Q%s %s' % (fmt(P(-11, -8)), fmt(P(0, -12.4)), fmt(P(11, -8))), FROST, 2.0)
    parts.append(Part('fill', pth(head), fill=SILV, shade=SILV_SH, off=(-2, -2), over=fc, hl=spec(*P(-8, -7), 2.4 * k, 1.2 * k, op=0.8)))
    cone = P(fx, -1)
    return parts, eyes, cone


def owl_svg(frame):
    name = 'owl_' + frame
    f = Fr(name, OPAL, shine=SHINE4)
    if frame == 'body':
        f.under = ground_shadow(64, 14)
        f.add(owl_bracket())
        f.add(owl_body_parts())
        f.mark(hit=(40, 62, 48, 60), head=OWL_HEAD, neck=(64, 86))
    elif frame == 'broken':
        f.under = ground_shadow(64, 16)
        f.add(owl_bracket())
        f.add(owl_body_parts(deg=14, cracked=True))
        parts, eyes, cone = owl_head_parts(f, look=0.4, deg=38, mood='broken', c=(70, 82))
        f.add(parts)
        spring = 'M60 86 q-3 -1 -2 -4 q4 -1 3 -4 q-4 -1 -3 -4'
        f.under += line(spring, NAVY_LINE, 2.6) + line(spring, BRASS_HI, 1.2)
        f.over = (specks([(86, 116, 1.2), (92, 118, 0.9)], BRASS) + star4(52, 80, 2.4, '#fff2a8') + star4(46, 86, 1.8, '#ffffff')
                  + '<circle cx="90" cy="112" r="3.2" fill="%s" stroke="%s" stroke-width="1"/>' % (BRASS, NAVY_LINE))
        f.mark(eyes, 5.2, hit=(40, 64, 50, 58))
    else:
        look, deg, mood, beak = {'look_l': (-1, -8, 'open', 0), 'look_c': (0, 0, 'open', 0), 'look_r': (1, 8, 'open', 0),
                                 'screech': (0, -10, 'flare', 1.0), 'hit': (0.3, 14, 'squeeze', 0.4)}[frame]
        parts, eyes, cone = owl_head_parts(f, look, deg, mood, beak)
        f.add(parts)
        if frame == 'screech':
            f.over = (motion('M40 60 q-4 4 -4 10 M88 60 q4 4 4 10 M34 56 q-6 6 -6 14 M94 56 q6 6 6 14', 1.2)
                      + glint(eyes[0][0], eyes[0][1], 4.4, TELL4) + glint(eyes[1][0], eyes[1][1], 4.4, TELL4))
        elif frame == 'hit':
            f.over = (sweat(84, 64, 0.4, 25) + ''.join('<ellipse cx="%.1f" cy="%.1f" rx="2.6" ry="1.2" fill="%s" stroke="%s" stroke-width="0.7" transform="rotate(%d %.1f %.1f)"/>' % (
                x, y, SILV_HI, NAVY_LINE, a, x, y) for x, y, a in ((40, 70, 30), (90, 72, -20), (46, 60, -40))))
        f.mark(eyes, 5.2, hit=(48, 62, 32, 28), cone=cone, look=look)
    return f.svg()


# ================================================================ the points file and all files

W3 = {
    'rootling': ['mound', 'swell', 'pop', 'dazed', 'walk1', 'walk2', 'hit'],
    'weepcap': ['idle', 'inhale', 'puff', 'hit', 'die'],
    'hound': ['prowl1', 'prowl2', 'howl', 'run1', 'run2', 'crouch', 'pounce', 'land', 'pant', 'hit'],
    'creep': ['crawl1', 'crawl2', 'coil', 'lunge', 'fall', 'hit'],
}
W4 = {
    'tick': ['march1', 'march2', 'wind', 'charge', 'dizzy', 'hit'],
    'spur': ['roll', 'catch', 'hit', 'face', 'face_catch', 'face_hit'],
    'buckle': ['idle', 'walk1', 'walk2', 'raise', 'stomp', 'slam', 'thawed', 'hit', 'shell'],
    'owl': ['body', 'look_l', 'look_c', 'look_r', 'screech', 'hit', 'broken'],
}
MAKERS = {'rootling': rootling_svg, 'weepcap': weepcap_svg, 'hound': hound_svg, 'creep': creep_svg,
          'tick': tick_svg, 'spur': spur_svg, 'buckle': buckle_svg, 'owl': owl_svg}
ANCHORS = {'rootling': (64, 122), 'weepcap': (64, 122), 'hound': (64, 122), 'creep': (64, 122),
           'tick': (64, 122), 'spur': (64, 64), 'buckle': (64, 122), 'owl': (64, 122)}
TELLS = {
    'rootling_swell.glint': 'the swell tell: the green glint (a light r 22) over the mound',
    'rootling_mound.leaves': 'the two leaves poking out of the mound',
    'rootling_pop.column': 'the middle of the pop column (22 x 40 px from the floor)',
    'weepcap_*.gills': 'the gills under the cap: the inhale glow (a violet light r 26)',
    'weepcap_puff.burst': 'the middle of the puff burst (r 36 px)',
    'hound_howl.flare': 'the lantern eye flaring (a green light r 30): the one lit socket',
    'hound_crouch.teeth': 'the crouch tell: the glint on the bared teeth',
    'hound_pounce.bite': 'the jaws, leading the pounce',
    'creep_coil.glint': 'the coil tell: the eye glint (a light r 18)',
    'creep_lunge.bite': 'the jaws at the front of the lunge',
    'creep_fall.belly': 'the middle of its body, lying on its back: draw the dizzy stars upright over it',
    'spur_*.hub': 'the hub (the middle of the turning and of the face overlay)',
}
NOTES = {
    'owl': 'Draw owl_body, then one head frame over it at the same anchor (the head sits on the body at `head`); the '
           'head frames swap to sweep (look_l, look_c, look_r), and `cone` is where the eye cone starts on each. '
           'owl_broken is the whole owl.',
    'buckle': 'buckle_shell (see-through ice) goes over any frame while the rime holds, shifted by that frame\'s '
              'shell_dx, shell_dy (frame units).',
    'spur': 'Centred on its hub (64, 64): it rolls along edges, so turn spur_roll / _catch / _hit about its middle '
            '(sprite.rotation = spin); its teeth reach 28 units (14 px) from the hub, 31 (15.5 px) bristling in the '
            'catch. Then draw the matching face overlay upright (rotation 0) at the same anchor: spur_face over roll, '
            'spur_face_catch over catch (the jam and the caught window), spur_face_hit over hit. It covers the cog\'s '
            'own hub face exactly, so the stern face stays the right way up; its eye1 / eye2 are the glow eyes, '
            'unturned. The frames draw no sparks or trail: code puts the sparks at the contact point.',
    'creep': 'Drawn head-up with its tail end on the feet anchor (64, 122) and its lane along frame x 64, the skull '
             'about 40 px up (it fills its 16 x 40 box). Crawling down its lane, flip it vertically about the top '
             'of its box. Off the lane (a flat lane or knocked onto the floor) turn it 90 deg with the head toward '
             'its heading; its tail is at the anchor, so shift the sprite back by half its length (20 px) to centre '
             'it, and 8 px up (its body is 16 px thick). creep_fall is the knocked-off Creepbone on its back; it has '
             'no dizzy stars (they would lie sideways once it is turned): draw them upright over its `belly`.',
}


ROLES = {
    'rootling': 'buried: mound; the tell: swell; pop; dazed; walking: walk1/walk2; hit; digging back in: swell then mound',
    'weepcap': 'idle (sway it); the tell: inhale; puff; hit; die',
    'hound': 'prowl: prowl1/prowl2; the chase tell: howl; chase: run1/run2; the tell: crouch; pounce; land (open); pant '
             '(tired); hit',
    'creep': 'crawl1/crawl2; the tell: coil; lunge; stretched: lunge; knocked off and dazed: fall; hit',
    'tick': 'march1/march2 on the tick; the tell: wind; charge; dizzy (after a wall) and rundown; hit',
    'spur': 'roll (turn the sprite as it rolls) under spur_face; the jam tell and the caught window: catch (with the '
            're-spin) under spur_face_catch; hit under spur_face_hit',
    'buckle': 'idle; walk1/walk2; both tells (Frost Stomp and Shield Slam): raise; stomp; slam; thawed (the rime '
              'shattered); hit (no rime); and buckle_shell over any frame while the rime holds',
    'owl': 'owl_body with a head over it (same anchor): the sweep look_l / look_c / look_r, the alarm screech, hit; '
           'broken is the whole owl (its death)',
}


def points_json(kinds, anchors, tells, notes, title, roles=None):
    import json
    doc = {'_doc': title + ': 128-unit frames, 2 units = 1 world px, facing right. Each kind has one anchor '
                   '(its feet, or its middle). Offsets from the anchor in world px = (point - anchor) / 2 '
                   '(elites.frame_point). eyes = the list of the lit eyes\' points ([[x, y]] for one); eye1 and eye2 '
                   '(or eye) name them; eye_mid = the middle of two; eye_r = an eye\'s radius; '
                   'hit = [x, y, w, h], the body\'s box on that frame.',
           '_anchors': {k: list(v) for k, v in anchors.items()},
           '_frames': {k: ['%s_%s' % (k, fr) for fr in v] for k, v in kinds.items()},
           '_tells': tells, '_notes': notes, '_roles': {k: v for k, v in (roles or ROLES).items() if k in kinds}}
    for k, v in sorted(POINTS.items()):
        if any(k.startswith(p + '_') for p in kinds):
            doc[k] = {n: list(p) if isinstance(p, tuple) else p for n, p in v.items()}
    return json.dumps(doc, indent=1, sort_keys=True) + '\n'


def files():
    out = {}
    for kinds in (W3, W4):
        for kind, frames in kinds.items():
            for fr in frames:
                out['art/enemies/%s_%s.svg' % (kind, fr)] = MAKERS[kind](fr)
    out['art/enemies/points_monsters3.json'] = points_json(dict(W3, **W4), ANCHORS, TELLS, NOTES,
                                                           'World 3 and World 4 monster frames (enemies3.py)')
    return out


def build(write):
    for rel, text in files().items():
        write(rel, text)


if __name__ == '__main__':
    import build as _b
    build(_b.write)
    print('wrote %d files under game/' % len(files()))
