"""The story figures: the cast as they stand on the panels. Each is a 256 x
256 frame (feet at (128, 244), facing right, px 4) drawn in native units
(twice WICK's coordinates: a Wick-sized character is about 180 units tall)
and fitted into the frame at scale s, so every figure's lines come out the
same weight on screen. A figure's h (the panel height its frame covers) is
120 / s: the actor rig (Wick's 128 frame) stands h 120.

Flames are the engine's to draw: each figure lists its flame points (the
flame's base and height, frame units) and how each lights the panel.
"""
import math
import re

import kit
from kit import Part, ell, pth, shp
import story_snuffer as SN
from common import (Ctx, RIM, GOLD, GOLD_SH, GOLD_HI, GOLD_LINE, WAX, WAX_SH, WAX_LINE, line, dot, flame_d, spec,
                    star4, mix, gx, sparkle)
from story_kit import (NATIVE_W, weights, P, E, LIMB, fillp, rect_d, rrect_d, ell_d, poly_d, radial, candle,
                       bell_parts, crest_svg, smoke_curl, unlit_wick, fit, to_frame, fig_doc, shade_of, light_of,
                       Rand, BRONZE, BRONZE_SH, BRONZE_HI, BRONZE_LINE, EYE_GAP, rnd)

ROOT = 'res://art/story/figures/'


def render(ctx, parts, line_col, base='#808080'):
    """All of a character's parts in one pass, so the warm sticker rim and the
    silhouette line wrap the whole figure."""
    with weights(NATIVE_W):
        return kit.render_parts(ctx, parts, dict(line=line_col, rim=RIM, base=base, shade=shade_of(base)))


def clipped(ctx, d, body):
    return '<g clip-path="%s">%s</g>' % (ctx.clip('<path d="%s"/>' % d), body)


def shadow(cx, rx, y=244.5, op=0.3):
    return '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="#07040a" opacity="%s"/>' % (cx, y, rx, rx * 0.12, op)


class Fig:
    """Collects one figure: its SVG and its panels.json entry."""

    def __init__(self, fid, s, px=4, feet=(128.0, 244.0), h=None):
        self.id, self.s, self.px, self.feet = fid, s, px, feet
        self.h = h if h is not None else 120.0 / s
        self.flames = {}
        self.light = {}

    def flame(self, name, x, y, h, **style):
        """A flame point in native units: its base (x, y) and height h, with
        how it lights the panel (kind, r, s; eyes add color, pts and dot)."""
        fx, fy = to_frame(x, y, self.s)
        st = dict(style)
        if 'r' in st:
            st['r'] = round(st['r'] * self.s, 1)
        if 'pts' in st:
            st['pts'] = [list(to_frame(px, py, self.s)) for px, py in st['pts']]
        if 'dot' in st:
            st['dot'] = round(st['dot'] * self.s, 2)
        self.set_flame(name, fx, fy, round(h * self.s, 2), st)

    def set_flame(self, name, fx, fy, h, st):
        """A flame point in frame units. The entry is [x, y, h, kind] (and the
        eyes' colour), so a reader of the array alone gets the kind and colour;
        eyes' h is their size (EYE_GAP h apart), taken from their two points."""
        kind = st.get('kind', 'flame')
        st = dict(st, kind=kind)
        if kind == 'eyes' and 'pts' in st:
            (ax, ay), (bx, by) = st['pts']
            h = round(math.hypot(bx - ax, by - ay) / EYE_GAP, 2)
        q = [rnd(fx), rnd(fy), h, kind]
        if st.get('color'):
            q.append(st['color'])
        self.flames[name] = q
        self.light[name] = st

    def entry(self):
        e = {'tex': ROOT + '%s.svg' % self.id, 'frame': [256, 256], 'feet': list(self.feet), 'px': self.px,
             'h': round(self.h, 1), 'flames': self.flames}
        if self.light:
            e['light'] = self.light
        return e


# ================================================================ Mother Taper

TAPER = dict(plum='#5a2e5a', plum_sh='#3e1e40', plum_hi='#7e4a7a', plum_in='#24102a', trim='#d8b24a', trim_sh='#a8842a',
             skin='#f6cfae', skin_sh='#e2aa8a', hair='#eee8f2', hair_sh='#b8b0c8', line='#1e1224', blush='#ff8a9a',
             shoe='#6a4430', wood='#8a5a36', wood_sh='#5e3a22', leather='#5a3a2a')
TFACE = dict(line=TAPER['line'], base=TAPER['skin'], iris0='#2a1406', iris1='#6a4a8a', iris2='#b8a0e0', blush=TAPER['blush'])


def taper_face(ctx, cx, cy, k=1.0, mood='warm'):
    """Taper's little face for the figures: round spectacles, apple cheeks,
    a gentle smile. (cx, cy) is the face's centre."""
    T = TAPER
    s = ''
    ex1, ex2, ey = cx - 6.5 * k, cx + 10.5 * k, cy + 1 * k
    # apple cheeks under the spectacles
    s += kit.blush(ex1 - 3 * k, cy + 9 * k, TFACE, 6.2 * k, 3.6 * k, lines=False, op=0.7)
    s += kit.blush(ex2 + 3.5 * k, cy + 8.5 * k, TFACE, 4.6 * k, 3.2 * k, lines=False, op=0.7)
    # eyes: kind closed arcs behind the glass (warm), little crow's feet
    if mood in ('warm', 'proud'):
        for x, w in ((ex1, 7.2), (ex2, 6.2)):
            s += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (x - w / 2 * k, ey + 1 * k, x, ey - 3.2 * k, x + w / 2 * k, ey + 1 * k), T['line'], 1.9 * k)
    else:
        for x, w in ((ex1, 4.6), (ex2, 4.0)):
            s += '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s"/>' % (x + 0.6 * k, ey, w / 2 * k, w * 0.6 * k, T['line'])
            s += dot(x - 0.2 * k, ey - 1 * k, 0.9 * k, '#ffffff')
    s += line('M%.1f %.1f l%.1f %.1f M%.1f %.1f l%.1f %.1f' % (ex1 - 7.4 * k, ey - 0.5 * k, -2.4 * k, -1.8 * k, ex1 - 7.6 * k, ey + 1.8 * k, -2.6 * k, 0.6 * k),
              T['line'], 0.9 * k, op=0.7)
    # the spectacles: gold rims, a pale lens, a glint
    for x, r in ((ex1, 6.4), (ex2, 5.6)):
        s += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="#ffffff" fill-opacity="0.16" stroke="%s" stroke-width="%.2f"/>' % (
            x, ey, r * k, T['trim_sh'], 2.4 * k)
        s += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="none" stroke="%s" stroke-width="%.2f"/>' % (x, ey, r * k, T['trim'], 1.3 * k)
        s += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (x - r * 0.55 * k, ey - r * 0.2 * k, x - r * 0.45 * k, ey - r * 0.6 * k, x - r * 0.05 * k, ey - r * 0.7 * k),
                  '#ffffff', 1.1 * k, op=0.85)
    s += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (ex1 + 6.4 * k, ey - 0.6 * k, (ex1 + ex2) / 2, ey - 2.6 * k, ex2 - 5.6 * k, ey - 0.6 * k), T['trim_sh'], 1.6 * k)
    s += line('M%.1f %.1f L%.1f %.1f' % (ex1 - 6.4 * k, ey - 0.8 * k, ex1 - 12 * k, ey - 2.6 * k), T['trim_sh'], 1.5 * k)
    # a button nose and the smile
    s += '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s"/>' % (cx + 3.6 * k, cy + 6.4 * k, 2.8 * k, 2.3 * k, T['skin_sh'])
    s += dot(cx + 2.8 * k, cy + 5.6 * k, 0.8 * k, '#ffffff', 0.8)
    if mood == 'proud':
        s += kit.mouth_open(cx + 3 * k, cy + 10.6 * k, 7 * k, 4.6 * k, TFACE)
    else:
        s += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (cx - 1 * k, cy + 11 * k, cx + 3.4 * k, cy + 14.2 * k, cx + 7.8 * k, cy + 10.6 * k), T['line'], 1.6 * k)
    return s


def taper_hood(ctx, P_, cx, cy, face_dx=12, k=1.0, nub=True, mood='warm'):
    """Taper's plum hood around her face, gold-trimmed, the nub candle
    buckled on top. Appends parts to P_; returns the wick tip (or None)."""
    T = TAPER
    hr = 36 * k
    hood = ('M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f L%.1f %.1f '
            'C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z') % (
        cx, cy - hr,
        cx + hr * 0.62, cy - hr, cx + hr * 1.02, cy - hr * 0.5, cx + hr * 1.02, cy + hr * 0.08,
        cx + hr * 1.02, cy + hr * 0.6, cx + hr * 0.72, cy + hr * 0.95, cx + hr * 0.4, cy + hr * 1.02,
        cx - hr * 0.62, cy + hr * 1.02,
        cx - hr * 0.95, cy + hr * 0.7, cx - hr * 1.0, cy + hr * 0.3, cx - hr * 1.0, cy - hr * 0.05,
        cx - hr * 1.0, cy - hr * 0.62, cx - hr * 0.6, cy - hr, cx, cy - hr)
    # the drooping tail of the hood at the back
    tail = 'M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z' % (
        cx - hr * 0.6, cy - hr * 0.78, cx - hr * 1.2, cy - hr * 0.8, cx - hr * 1.5, cy - hr * 0.2, cx - hr * 1.42, cy + hr * 0.42,
        cx - hr * 1.2, cy + hr * 0.08, cx - hr * 1.0, cy - hr * 0.1, cx - hr * 0.86, cy - hr * 0.06)
    P_.append(P(tail, T['plum'], T['plum_sh'], off=(-3, -3)))
    fx, fy = cx + face_dx * k, cy + 4 * k
    opening = ell_d(fx, fy, 23 * k, 21 * k)
    face = ell_d(fx + 0.6 * k, fy + 1.4 * k, 19.5 * k, 18 * k)
    inner = '<path d="%s" fill="%s"/>' % (opening, T['plum_in'])
    # the face, the white fringe peeking from the hood
    fringe = ('M%.1f %.1f L%.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f '
              'Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f Z') % (
        fx - 24 * k, fy - 24 * k, fx + 24 * k, fy - 24 * k, fx + 22 * k, fy - 9 * k,
        fx + 16 * k, fy - 13 * k, fx + 11 * k, fy - 8 * k, fx + 6 * k, fy - 14 * k, fx, fy - 9 * k,
        fx - 5 * k, fy - 15 * k, fx - 10 * k, fy - 8 * k, fx - 16 * k, fy - 14 * k, fx - 20 * k, fy - 6 * k,
        fx - 24 * k, fy - 12 * k, fx - 24 * k, fy - 24 * k)
    face_art = clipped(ctx, face, '<path d="%s" fill="%s"/><path d="%s" fill="none" stroke="%s" stroke-width="%.1f"/>' % (
        fringe, T['hair'], fringe, T['hair_sh'], 1.1 * k))
    face_art += taper_face(ctx, fx + 0.6 * k, fy + 1.4 * k, k, mood)
    trim = ('<path d="%s" fill="none" stroke="%s" stroke-width="%.1f"/>' % (ell_d(fx, fy, 24.2 * k, 22.2 * k), T['trim_sh'], 4.6 * k)
            + '<path d="%s" fill="none" stroke="%s" stroke-width="%.1f"/>' % (ell_d(fx, fy, 24.2 * k, 22.2 * k), T['trim'], 2.6 * k))
    hood_over = line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (cx - hr * 0.7, cy - hr * 0.4, cx - hr * 0.5, cy + hr * 0.3, cx - hr * 0.2, cy + hr * 0.9),
                     T['plum_sh'], 1.6 * k, op=0.8)
    P_.append(Part('fill', pth(hood), fill=T['plum'], shade=T['plum_sh'], off=(-6 * k, -5 * k),
                   over=hood_over + inner + trim,
                   hl=spec(cx - hr * 0.45, cy - hr * 0.62, 9 * k, 3.4 * k, rot=-38, op=0.4)))
    P_.append(Part('fill', pth(face), fill=T['skin'], shade=T['skin_sh'], off=(-2.4 * k, -2 * k), over=face_art))
    tip = None
    if nub:
        # the battered brass holder buckled to the hood, and the nub of candle
        bx, by = cx + 4 * k, cy - hr + 3 * k
        P_.append(LIMB('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (bx - 18 * k, by + 8 * k, bx, by - 3 * k, bx + 18 * k, by + 8 * k),
                       T['leather'], 3.6 * k))
        P_.append(P(rrect_d(bx + 10 * k, by + 1.6 * k, bx + 16 * k, by + 7.6 * k, 1.2 * k), T['trim'], T['trim_sh'], off=(-0.6, -0.6),
                    over='<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="%s"/>' % (bx + 12 * k, by + 3.4 * k, 2 * k, 2.4 * k, T['leather'])))
        cup = 'M%.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f Z' % (
            bx - 9 * k, by - 2 * k, bx + 9 * k, by - 2 * k, bx + 8 * k, by + 4 * k, bx, by + 4.6 * k, bx - 8 * k, by + 4 * k, bx - 9 * k, by - 2 * k)
        dent = line('M%.1f %.1f l%.1f %.1f' % (bx + 3 * k, by - 1 * k, 2 * k, 3 * k), T['trim_sh'], 1.1 * k)
        P_.append(P(cup, T['trim'], T['trim_sh'], off=(-1.4 * k, -1.2 * k), over=dent,
                    hl=line('M%.1f %.1f L%.1f %.1f' % (bx - 6 * k, by - 0.6 * k, bx + 1 * k, by - 0.6 * k), GOLD_HI, 1.1 * k, op=0.9)))
        cp, wk, tip = candle(ctx, bx, by - 1.6 * k, 9 * k, 8 * k, TAPER['line'], drips=((0.2, 0.34), (0.7, 0.5)))
        P_ += cp
        P_[-1].over += wk
    return tip


def taper_stand():
    f = Fig('taper_stand', 1.0)
    ctx = Ctx('fts')
    T = TAPER
    parts = []
    # little shoes under the hem
    parts.append(E(114, 243, 9, 4.8, T['shoe'], off=(-1, -1)))
    parts.append(E(146, 244, 9.4, 5, T['shoe'], off=(-1, -1)))
    # the robe, a little bell of plum with a gold hem and front edge
    robe = 'M106 186 C98 204 91 224 88 241 Q100 246 112 243 Q128 247 144 243 Q158 246 170 241 C166 222 160 204 152 186 Z'
    trim = clipped(ctx, robe, line('M86 236 Q128 244 172 236', T['trim'], 5.4, cap='butt') + line('M86 232.6 Q128 240.6 172 232.6', T['trim_sh'], 1.1)
                   + line('M146 188 Q150 214 157 246', T['trim'], 3.4) + line('M120 196 Q114 220 110 240', T['plum_sh'], 1.6, op=0.8))
    parts.append(P(robe, T['plum'], T['plum_sh'], off=(-7, -3), over=trim))
    # the hood and her face; the nub candle buckled on top
    tip = taper_hood(ctx, parts, 128, 170, face_dx=12)
    # the front sleeve reaching to the staff, a little hand on it
    parts.append(P('M144 192 C156 190 168 194 176 200 L172 210 C164 208 154 206 146 206 Z', T['plum'], T['plum_sh'], off=(-2, -3),
                   over=line('M170 198 L167 209', T['trim'], 3)))
    # the crooked staff and its lantern
    staff = 'M182 244 C179 224 186 208 181 188 C176 170 185 152 182 134 C180 122 186 114 195 114 C204 114 207 122 203 128'
    parts.append(LIMB(staff, T['wood'], 4.6, over=line('M180.5 200 l3 -2 M182.5 160 l-3 -2', T['wood_sh'], 1.2)))
    parts.append(E(180, 204, 5.6, 5.2, T['skin'], T['skin_sh'], off=(-1, -1),
                   over=line('M177 202.4 L184 202.4 M177.4 205.6 L183.6 205.6', T['line'], 0.8, op=0.7)))
    lx, ly = 203, 130
    parts += lantern(ctx, lx, ly)
    body = shadow(130, 44) + render(ctx, parts, T['line'], T['plum'])
    f.flame('head', tip[0], tip[1], 26, kind='flame', r=150, s=0.95)
    f.flame('lantern', lx, ly + 25, 15, kind='flame', r=170, s=0.9)
    return f, fig_doc(ctx, fit(body, f.s))


def lantern(ctx, lx, ly):
    """A little iron lantern hanging from (lx, ly); its flame sits at (lx, ly + 25)."""
    parts = [LIMB('M%.1f %.1f L%.1f %.1f' % (lx, ly - 2, lx, ly + 3), '#3a3446', 1.4),
             P('M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (lx - 10, ly + 9, lx + 10, ly + 9, lx + 5, ly + 3, lx - 5, ly + 3),
               '#4a4458', '#2e2a3a', off=(-1, -1))]
    glass = ctx.radgrad([(0, '#fff6d0'), (0.6, '#ffd878'), (1, '#e8a040')], cx=0.5, cy=0.65, r=0.6)
    parts.append(Part('fill', pth(rect_d(lx - 8, ly + 9, lx + 8, ly + 29)), fill=glass, no_shade=True,
                      over=line('M%.1f %.1f L%.1f %.1f M%.1f %.1f L%.1f %.1f' % (lx - 8, ly + 9, lx - 8, ly + 29, lx + 8, ly + 9, lx + 8, ly + 29), '#3a3446', 2.2)
                      + line('M%.1f %.1f L%.1f %.1f' % (lx, ly + 9, lx, ly + 29), '#3a3446', 1.2, op=0.8)))
    parts.append(P('M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (lx - 11, ly + 29, lx + 11, ly + 29, lx + 8, ly + 33, lx - 8, ly + 33),
                   '#4a4458', '#2e2a3a', off=(-1, -1)))
    return parts


# ================================================================ the novice (from behind)

NOV = dict(robe='#c8b89a', robe_sh='#a0907a', robe_hi='#e2d6ba', line='#2a1e18', rope='#8a6a3a', rope_sh='#5e4424',
           skin='#ffd9c0', skin_sh='#f4b89e', hair='#9a5a2a', boot='#5a4030', tin='#b8bcc8', tin_sh='#80849a')


def novice_back():
    """Wick-sized, seen from behind at three-quarters, turned toward Taper:
    the hood up, the edge of a cheek and a tuft of hair showing at its
    opening, a capelet with the crest clasp, a rope belt, one hand
    clutching the robe, the unlit candle in its tin holder on top."""
    f = Fig('novice_back', 1.0)
    ctx = Ctx('fnb')
    N = NOV
    parts = []
    parts.append(E(108, 244, 11, 5, N['boot'], off=(-1, -1)))
    parts.append(E(146, 245, 11, 5, N['boot'], off=(-1, -1)))
    robe = 'M96 158 C86 188 82 220 80 241 Q98 247 114 242 Q130 247 146 242 Q162 247 178 241 C174 218 168 188 158 158 Z'
    folds = (line('M112 176 Q106 212 104 240 M136 190 Q138 220 140 242 M156 184 Q162 212 164 238', N['robe_sh'], 1.8, op=0.9)
             + line('M100 176 Q94 198 91 218', N['robe_hi'], 2.4, op=0.8))
    parts.append(P(robe, N['robe'], N['robe_sh'], off=(-8, -3), over=folds))
    belt = 'M85 206 Q124 216 172 205'
    parts.append(LIMB(belt, N['rope'], 5.2, over=line('M94 208 l2 -3 M106 210.6 l2 -3 M118 212.4 l2 -3 M130 212.6 l2 -3 M142 211.6 l2 -3 M154 209.6 l2 -3', N['rope_sh'], 1.0)))
    parts.append(LIMB('M154 211 Q152 224 148 234 M158 211 Q162 222 162 230', N['rope'], 3.6))
    parts.append(E(156, 211, 5, 4.4, N['rope'], N['rope_sh'], off=(-1, -1)))
    # the near hand clutching a fold of the robe (nervous)
    parts.append(P('M160 164 C170 176 174 192 173 204 L163 206 C163 194 159 182 153 172 Z', N['robe'], N['robe_sh'], off=(-2, -2)))
    parts.append(P('M167 204 Q171 214 169 224 Q164 216 162 206 Z', N['robe_sh'], N['robe_sh'], off=(0, 0)))
    parts.append(E(168, 208, 6.4, 6, N['skin'], N['skin_sh'], off=(-1.4, -1.4),
                   over=line('M164 206 L171 206 M164.6 209.8 L171 209.8', N['line'], 0.9, op=0.7)))
    # a capelet over the shoulders
    parts.append(P('M88 150 C96 140 158 140 168 152 C170 164 164 172 156 174 L100 174 C92 170 86 162 88 150 Z', N['robe'], N['robe_sh'], off=(-4, -4),
                   over=line('M96 168 Q126 176 158 168', N['robe_sh'], 1.6, op=0.8)))
    # the hood from behind: rounded, a little peak at the back, its seam
    hood = 'M124 66 C150 66 172 84 174 112 C176 132 168 150 156 160 L98 160 C86 150 78 134 78 114 C78 86 98 66 124 66 Z'
    seam = line('M112 70 Q102 112 108 158', N['robe_sh'], 2, op=0.9)
    parts.append(P(hood, N['robe'], N['robe_sh'], off=(-9, -7), over=seam + line('M88 140 Q104 154 132 156', N['robe_sh'], 1.6, op=0.8),
                   hl=spec(98, 86, 11, 4, rot=-40, op=0.35)))
    parts.append(P('M96 72 C86 66 76 70 72 80 C80 76 88 78 94 84 Z', N['robe'], N['robe_sh'], off=(-2, -2)))
    # the hood's opening at the side: its lining, a cheek, a tuft of hair
    rim = 'M156 76 C170 86 180 106 180 124 C180 140 174 152 164 160 C168 146 170 130 168 114 C166 98 162 86 156 76 Z'
    parts.append(P(rim, '#e8dcc2', N['robe_sh'], off=(-1, -1)))
    cheek = 'M167 102 C176 110 179 124 176 140 C173 148 168 152 164 154 C168 138 169 118 167 102 Z'
    parts.append(P(cheek, N['skin'], N['skin_sh'], off=(-1, -1),
                   over=kit.blush(174, 136, dict(blush='#ff9aa0'), 2.4, 3.6, lines=False, op=0.65)))
    parts.append(P('M164 96 C172 98 178 104 181 112 C176 110 172 108 170 112 C168 106 166 102 164 96 Z', N['hair'], shade_of(N['hair']), off=(-1, -1)))
    # the crest clasp glinting at the throat
    parts.append(E(168, 168, 5, 4.6, GOLD, GOLD_SH, off=(-1, -1), over=dot(166.6, 166.6, 1.2, GOLD_HI)))
    # the unlit candle in its tin holder on the hood
    bx, by = 130, 70
    parts.append(P('M%.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f Z' % (bx - 11, by - 4, bx + 11, by - 4, bx + 10, by + 3, bx, by + 4,
                                                                                    bx - 10, by + 3, bx - 11, by - 4),
                   N['tin'], N['tin_sh'], off=(-1.4, -1.2), hl=line('M%.1f %.1f L%.1f %.1f' % (bx - 8, by - 2.4, bx, by - 2.4), '#ffffff', 1.1, op=0.8)))
    parts.append(LIMB('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (bx + 10, by - 1, bx + 18, by - 4, bx + 17, by + 5), N['tin_sh'], 2.2))
    cp, wk, tip = candle(ctx, bx, by - 3.4, 11, 18, N['line'])
    parts += cp
    parts[-1].over += wk
    body = shadow(128, 52) + render(ctx, parts, N['line'], N['robe'])
    return f, fig_doc(ctx, fit(body, f.s))


# ================================================================ Old Tollgrave (boss.py, sockets empty)

def tollgrave_boss():
    """boss.py's idle frame at px 4, the eye sockets left dark and empty so the
    engine lights them (light boss.eyes)."""
    import boss
    # boss.py draws in WICK's units, so the fight's scale is h 240; in his
    # intro he looms larger (h 340), and the belfry's boss anchor leaves the
    # size to the figure, so the Snuffer can take the same spot at his own
    f = Fig('tollgrave_boss', 0.5, h=340.0)

    def socket(ctx, cx, cy, w, h, look=(0.8, 0), iris=0.34, col=None, socket=None, pin=False):
        return '<ellipse cx="%.2f" cy="%.2f" rx="%.2f" ry="%.2f" fill="%s"/>' % (cx, cy, w / 2, h / 2, '#0a0610')
    old = (boss.glow_eye, boss.TEAL)
    boss.glow_eye, boss.TEAL = socket, '#06030a'
    try:
        svg = boss.frame('idle')
    finally:
        boss.glow_eye, boss.TEAL = old
    svg = re.sub(r'width="512" height="512"', 'width="1024" height="1024"', svg, count=1)
    # boss.py's frame is the figure frame already (feet on 244): points as they are
    f.set_flame('eyes', 153.4, 125.1, 0, {'kind': 'eyes', 'color': '7ef0c8', 'pts': [[145.6, 125.4], [161.2, 124.8]],
                                          'dot': 3.4, 'r': 120, 's': 0.8})
    return f, svg


# ================================================================ Taper in her chair (P1)

def taper_chair():
    f = Fig('taper_chair', 1.0)
    ctx = Ctx('ftc')
    T = TAPER
    parts = []
    W_, WS = '#7a4a2c', '#4e2c16'
    # the high-backed chair: back legs, the tall carved back, the seat, front legs
    parts.append(LIMB('M86 244 L90 130', W_, 7))
    parts.append(P('M80 96 C80 84 92 78 100 86 C106 78 118 84 118 96 L118 196 L80 196 Z', W_, WS, off=(-4, -3),
                   over=line('M88 104 L88 188 M110 104 L110 188', WS, 2.2, op=0.8) + '<circle cx="99" cy="92" r="4" fill="%s"/>' % GOLD))
    parts.append(E(99, 80, 5.4, 5.4, W_, WS, off=(-1, -1)))
    parts.append(P('M76 194 L176 194 L172 206 L80 206 Z', W_, WS, off=(-2, -3)))
    parts.append(LIMB('M166 206 L170 244', W_, 7))
    parts.append(LIMB('M88 206 L84 244', W_, 6))
    # her little shoes on a footstool
    parts.append(P(rrect_d(140, 228, 196, 240, 3), '#6a2a40', '#4a1a2c', off=(-2, -2)))
    parts.append(LIMB('M146 240 L144 245 M190 240 L192 245', W_, 4))
    parts.append(E(156, 224, 8.4, 4.6, T['shoe'], off=(-1, -1)))
    parts.append(E(178, 225, 8.4, 4.6, T['shoe'], off=(-1, -1)))
    # the patchwork blanket over her lap, down to the stool
    blanket = 'M102 160 C130 156 158 166 170 186 C182 204 186 220 184 230 L118 232 C108 222 102 206 100 190 Z'
    patches = ''
    rng = Rand(31)
    cols = ['#c8506a', '#e8c878', '#7a9ac8', '#e89a70', '#a8c888', '#f4e4c8']
    for yy in range(150, 236, 16):
        for xx in range(92, 190, 16):
            patches += '<rect x="%d" y="%d" width="16" height="16" fill="%s"/>' % (xx, yy, rng.pick(cols))
    patches += ''.join(line('M%d 150 L%d 236' % (x, x), '#ffffff', 0.8, op=0.5) for x in range(92, 192, 16))
    patches += ''.join(line('M92 %d L190 %d' % (y, y), '#ffffff', 0.8, op=0.5) for y in range(150, 238, 16))
    parts.append(Part('fill', pth(blanket), fill='#e8c878', shade='#b8905a', off=(-6, -4),
                      under='', over=clipped(ctx, blanket, patches + '<path d="M150 160 C166 176 176 196 180 230 L190 230 L190 150 Z" fill="#3a1a30" opacity="0.28"/>')
                      + line('M104 196 Q140 202 178 212', '#8a5a3a', 1.4, op=0.6)))
    # the robe above the blanket, the hood and face (a smile), the nub candle
    parts.append(P('M104 146 C100 158 100 172 104 184 L150 184 C154 170 152 156 148 146 Z', T['plum'], T['plum_sh'], off=(-4, -3),
                   over=line('M136 148 Q140 164 142 184', T['trim'], 3)))
    tip = taper_hood(ctx, parts, 128, 120, face_dx=12, mood='warm')
    # both hands round a steaming cup
    parts.append(P('M144 158 C154 156 160 162 162 170 L150 176 C146 170 142 166 140 162 Z', T['plum'], T['plum_sh'], off=(-2, -2)))
    cup = 'M156 156 L174 156 L172 176 Q165 180 158 176 Z'
    parts.append(P(cup, '#e8e4f0', '#b8b0c8', off=(-2, -1), over=line('M157 162 L173 162', '#7a9ac8', 2.4)))
    parts.append(LIMB('M173 160 Q182 162 181 168 Q180 173 172.5 172', '#e8e4f0', 2.6))
    parts.append(E(156, 168, 5.4, 5, T['skin'], T['skin_sh'], off=(-1, -1)))
    parts.append(E(170, 170, 5, 4.6, T['skin'], T['skin_sh'], off=(-1, -1)))
    steam = smoke_curl(162, 150, 26, '#ffffff', 2.2, 0.55, 0.6) + smoke_curl(168, 148, 20, '#ffffff', 1.8, 0.45, -0.7)
    body = shadow(134, 60) + render(ctx, parts, T['line'], T['plum']) + steam
    f.flame('head', tip[0], tip[1], 26, kind='flame', r=150, s=0.95)
    return f, fig_doc(ctx, fit(body, f.s))


# ================================================================ Taper in the smoke (P1)

def taper_smoke():
    """A grey wisp rising in S-curves; its top curls draw Taper's hood, her
    spectacles and her smile in single lines."""
    f = Fig('taper_smoke', 1.0)
    ctx = Ctx('ftk')
    C = '#d8d0e0'
    HI = '#f6f2fc'
    s = ''

    def wisp(d, w=5.0, op=0.55):
        return line(d, C, w * 2.6, op=op * 0.35) + line(d, C, w, op=op) + line(d, HI, max(1.4, w * 0.36), op=min(1.0, op + 0.2))
    # the stem, curling up from the base
    s += wisp('M128 244 C112 224 146 208 130 190 C118 176 138 164 136 150', 6, 0.5)
    s += wisp('M130 214 C150 208 156 196 148 188', 2.6, 0.4) + wisp('M126 194 C108 188 106 178 114 170', 2.6, 0.4)
    # the hood: a smoke line over her head, down her back into the stem, a curl for its tail
    s += wisp('M136 150 C112 150 94 136 92 112 C90 86 108 68 132 66 C154 64 172 78 176 98', 4.6, 0.6)
    s += wisp('M92 112 C80 106 72 112 74 124 C76 132 86 132 88 124', 3, 0.5)
    # the face opening, in a thinner line
    s += line('M166 94 C170 110 164 128 148 134 C132 138 116 128 116 110 C116 96 128 86 142 86', C, 2.4, op=0.55)
    # spectacles, a smile, kind closed eyes, the nub of smoke-flame on top
    for x, r in ((130, 7.2), (150, 6.4)):
        s += '<circle cx="%d" cy="110" r="%.1f" fill="none" stroke="%s" stroke-width="2.4" opacity="0.85"/>' % (x, r, HI)
    s += line('M137.2 109 Q140 106.4 143.6 109', HI, 1.8, op=0.85)
    s += line('M126.6 111 Q130 108 133.4 111 M146.8 111 Q150 108.4 153.2 111', HI, 1.5, op=0.7)
    s += line('M132 124 Q140 130 148 123', HI, 2.4, op=0.9)
    s += wisp('M132 66 C128 56 138 52 134 42 C132 36 136 32 138 30', 2.6, 0.5)
    return f, fig_doc(ctx, fit(s, f.s))


# ================================================================ Waxley the chandler

WAXLEY = dict(skin='#e8b890', skin_sh='#c8906a', line='#2a1810', hat='#6a4a2a', hat_sh='#4a3018', shirt='#c8a040',
              shirt_sh='#9a7828', apron='#e2d2b2', apron_sh='#b8a684', trousers='#6a4a3a', boot='#4a3020',
              brow='#8a6a4a', nose='#e8907a', blush='#ff8a7a', brass='#d8a84a', brass_sh='#9a7028')
WFACE = dict(line=WAXLEY['line'], base=WAXLEY['skin'], iris0='#2a1406', iris1='#7a4a1a', iris2='#e8a84a', blush=WAXLEY['blush'])


def mustache(cx, cy, span, thick, up=0.0):
    """A huge cream wax mustache from under the nose at (cx, cy): two lobes
    sweeping out span units each side and curling up (more with up)."""
    def lobe(k):
        x0 = cx
        tip = (cx + k * span, cy - span * (0.28 + up * 0.4))
        return ('M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f '
                'C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z') % (
            x0, cy - thick * 0.45,
            x0 + k * span * 0.35, cy - thick * 0.9, x0 + k * span * 0.7, cy - thick * 0.1, x0 + k * span * 0.88, cy - span * (0.1 + up * 0.2),
            x0 + k * span * 0.95, cy - span * (0.2 + up * 0.3), tip[0] - k * span * 0.02, tip[1] + span * 0.02, tip[0], tip[1],
            tip[0] + k * span * 0.14, tip[1] + span * 0.12, x0 + k * span * 1.02, cy + thick * 0.1, x0 + k * span * 0.7, cy + thick * 0.7,
            x0 + k * span * 0.45, cy + thick * 1.0, x0 + k * span * 0.15, cy + thick * 0.8, x0, cy + thick * 0.4)
    return lobe(-1), lobe(1)


def waxley_pack():
    f = Fig('waxley_pack', 0.75)
    ctx = Ctx('fwx')
    X = WAXLEY
    parts = []
    # ---- the towering pack behind him
    parts.append(LIMB('M54 214 L64 -30', '#8a5a36', 6))
    parts.append(LIMB('M104 206 L112 -34', '#8a5a36', 6))
    parts.append(P('M36 140 C30 170 36 200 50 214 L108 212 C118 196 118 164 110 136 Z', '#a88a5a', '#7a6038', off=(-5, -3),
                   over=line('M48 150 Q60 146 70 152 M62 186 Q78 180 92 188', '#6a5030', 1.6)))
    # a bundle of candles tied with red string
    for i, x in enumerate(range(40, 118, 9)):
        top = 66 - (i % 3) * 5
        parts.append(P(rect_d(x, top, x + 8, 138), WAX, WAX_SH, off=(-2, 0), over=unlit_wick(x + 4, top, 5)))
    parts.append(LIMB('M36 102 Q76 110 120 100', '#c83a4a', 3.4))
    # a rolled rug across the top of the bundle
    parts.append(P('M22 48 L126 44 L128 68 L24 72 Z', '#b8404a', '#842a36', off=(-2, -3),
                   over=line('M40 47 L42 71 M66 46 L68 70 M92 45 L94 69', '#e8b84a', 3)))
    parts.append(E(24, 60, 8, 12, '#b8404a', '#842a36', off=(-1, -1), over='<ellipse cx="24" cy="60" rx="4" ry="7" fill="none" stroke="#e8b84a" stroke-width="1.6"/>'))
    # the birdcage on top and Duchess the moth inside
    cx0, cy0 = 84, -2
    parts.append(P('M%d %d L%d %d L%d %d L%d %d Z' % (cx0 - 32, cy0 + 40, cx0 + 32, cy0 + 40, cx0 + 28, cy0 + 48, cx0 - 28, cy0 + 48),
                   X['brass'], X['brass_sh'], off=(-2, -2)))
    duchess = moth_svg(ctx, cx0, cy0 + 12, 1.25, face=True)
    bars = ''
    for bx in range(-26, 30, 9):
        bars += line('M%d %d Q%d %d %d %d' % (cx0 + bx, cy0 + 40, cx0 + bx * 1.05, cy0 - 14, cx0 + bx * 0.2, cy0 - 36), X['brass_sh'], 3.2)
        bars += line('M%d %d Q%d %d %d %d' % (cx0 + bx, cy0 + 40, cx0 + bx * 1.05, cy0 - 14, cx0 + bx * 0.2, cy0 - 36), X['brass'], 1.6)
    ring = line('M%d %d Q%d %d %d %d' % (cx0 - 6, cy0 - 36, cx0, cy0 - 52, cx0 + 6, cy0 - 36), X['brass_sh'], 3.4)
    parts.append(Part('fill', pth('M%d %d Q%d %d %d %d Q%d %d %d %d Z' % (cx0 - 32, cy0 + 40, cx0 - 30, cy0 - 30, cx0, cy0 - 38,
                                                                          cx0 + 30, cy0 - 30, cx0 + 32, cy0 + 40)),
                      fill='#2a2030', no_shade=True, over=duchess + bars + ring, lw=0))
    # a pan and a lantern hanging off the frame
    parts.append(LIMB('M110 150 L124 172', '#3a3446', 2))
    parts.append(E(128, 178, 10, 10, '#4a4458', '#2e2a3a', off=(-2, -2)))
    parts.append(LIMB('M52 112 L40 124', '#3a3446', 2))
    parts += lantern(ctx, 38, 122)
    # ---- the man: boots, trousers, the back arm on the strap
    parts.append(E(104, 238, 15, 7.4, X['boot'], off=(-2, -2)))
    parts.append(E(156, 239, 15, 7.4, X['boot'], off=(-2, -2)))
    parts.append(P('M92 196 L124 196 L118 234 L94 234 Z', X['trousers'], shade_of(X['trousers']), off=(-2, -2)))
    parts.append(P('M134 196 L168 196 L164 234 L140 234 Z', X['trousers'], shade_of(X['trousers']), off=(-2, -2)))
    parts.append(P('M104 128 C94 140 90 156 92 170 L104 172 C104 158 108 146 114 136 Z', X['shirt'], X['shirt_sh'], off=(-2, -2)))
    parts.append(E(98, 176, 7, 6.4, X['skin'], X['skin_sh'], off=(-1, -1)))
    # the round belly in its mustard shirt, the wax-spotted apron
    parts.append(E(134, 168, 50, 46, X['shirt'], X['shirt_sh'], off=(-9, -7), over=line('M108 132 Q104 150 106 170', '#e8c870', 2.4, op=0.8)))
    apron = 'M104 136 L164 136 C172 160 176 196 172 230 L100 230 C96 196 98 160 104 136 Z'
    spots = ''.join('<path d="%s" fill="#fff8e8" stroke="%s" stroke-width="0.9"/>' % (flame_d(x, y, 5, 7, 0)[:], X['apron_sh'])
                    for x, y in ((118, 170), (152, 158), (140, 200), (116, 212), (160, 214), (128, 148)))
    pocket = rrect_d(120, 184, 152, 206, 3)
    parts.append(P(apron, X['apron'], X['apron_sh'], off=(-6, -3),
                   over=spots + '<path d="%s" fill="%s" stroke="%s" stroke-width="1.6"/>' % (pocket, X['apron_sh'], X['line'])
                   + ''.join(line('M%d 184 L%d 172' % (x, x + 1), WAX, 4) for x in (128, 136, 144))))
    parts.append(LIMB('M112 136 Q134 118 156 136', X['apron_sh'], 3))
    # pack straps over the shoulders
    parts.append(LIMB('M100 126 Q112 140 108 166', '#6a4028', 5))
    # ---- the head: tan and rosy, happy squint, the great mustache, the hat
    head = kit.head_tpl(140, 98, 70, 64)
    face = ''
    face += kit.blush(118, 108, WFACE, 8, 4.4, lines=True, op=0.6) + kit.blush(166, 106, WFACE, 6.4, 4, lines=True, op=0.6)
    for x, w in ((126, 13), (154, 11)):
        face += line('M%.1f 94 Q%.1f 86 %.1f 94' % (x - w / 2, x, x + w / 2), X['line'], 3.2)
    face += kit.brow_fill(118, 80, 134, 78, dict(line=X['brow']), 4.2, bend=-3) + kit.brow_fill(147, 78, 162, 80, dict(line=X['brow']), 3.8, bend=-3)
    face += kit.mouth_open(141, 117, 18, 8, WFACE)
    lm, rm = mustache(141, 108, 46, 14, up=0.3)
    wax_line = '#8a7050'
    mst = ''
    for d in (lm, rm):
        mst += '<path d="%s" fill="%s" stroke="%s" stroke-width="2.6" stroke-linejoin="round"/>' % (d, WAX, wax_line)
    mst += line('M118 104 Q128 100 138 104 M144 104 Q154 100 166 104', '#ffffff', 2, op=0.8)
    mst += wax_drips(141, 112, 46, 0.8)
    nose = '<ellipse cx="146" cy="100" rx="9" ry="8" fill="%s" stroke="%s" stroke-width="2"/>' % (X['nose'], X['line'])
    nose += dot(143, 97, 2.2, '#ffffff', 0.8)
    parts.append(Part('fill', head, fill=X['skin'], shade=X['skin_sh'], off=(-4, -4), over=face + mst + nose))
    parts.append(E(104, 102, 6, 8, X['skin'], X['skin_sh'], off=(-1, -1)))
    # the wide leather hat, five candles on its brim
    parts.append(P('M104 70 C102 44 116 30 140 30 C164 30 178 44 176 70 Z', X['hat'], X['hat_sh'], off=(-6, -4),
                   over='<path d="M104 58 Q140 66 176 58 L176 66 Q140 74 104 66 Z" fill="#3a2410"/>'
                   + '<rect x="146" y="59" width="10" height="9" rx="1.5" fill="%s" stroke="%s" stroke-width="1.4"/>' % (X['brass'], X['line'])))
    parts.append(Part('fill', ell(140, 70, 66, 13), fill=X['hat'], shade=X['hat_sh'], off=(-3, -4),
                      over=line('M78 68 Q140 58 202 68', '#8a6440', 2, op=0.9)))
    tips = []
    for i, x in enumerate((88, 112, 140, 168, 192)):
        yb = 70 + 13 * math.sqrt(max(0.0, 1 - ((x - 140) / 66.0) ** 2)) * 0.55
        cp, wk, tip = candle(ctx, x, yb, 8.4, 13 + (i % 2) * 3, X['line'], drips=((0.25, 0.6), (0.75, 0.9)))
        parts += cp
        parts[-1].over += wk
        tips.append(tip)
    # the waving arm, up and friendly
    parts.append(P('M162 132 C176 124 186 112 192 100 L204 106 C198 122 186 138 170 148 Z', X['shirt'], X['shirt_sh'], off=(-2, -2),
                   over=line('M188 104 L200 111', '#e8c870', 4)))
    hand = ('M196 100 C192 92 192 84 196 80 L198 70 C198 66 203 66 203 70 L204 78 L206 66 C206 62 211 62 211 66 L211 79 '
            'L214 70 C215 66 220 67 219 71 L216 86 L222 80 C225 77 229 80 226 84 L216 98 C212 104 202 106 196 100 Z')
    parts.append(P(hand, X['skin'], X['skin_sh'], off=(-2, -2)))
    body = shadow(128, 66) + render(ctx, parts, X['line'], X['shirt'])
    body += line('M214 60 Q222 56 226 48 M224 70 Q234 68 238 62', X['line'], 2.4)
    for i, tp in enumerate(tips):
        f.flame('brim%d' % (i + 1), tp[0], tp[1], 22, kind='flame', r=110, s=0.8)
    return f, fig_doc(ctx, fit(body, f.s))


def wax_drips(cx, y, span, k=1.0, col=WAX, line_col='#8a7050'):
    """Little wax teardrops hanging from under a mustache's two lobes, near their tips."""
    s = ''
    for f_, ln in ((-0.78, 10), (-0.56, 14), (0.56, 12), (0.8, 8)):
        x = cx + f_ * span
        yy = y - abs(f_) * span * 0.12
        L = ln * k
        s += '<path d="M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z" fill="%s" stroke="%s" stroke-width="%.1f"/>' % (
            x - 2.4 * k, yy, x - 2.6 * k, yy + L * 0.6, x - 3.2 * k, yy + L, x, yy + L + 2 * k,
            x + 3.2 * k, yy + L, x + 2.6 * k, yy + L * 0.6, x + 2.4 * k, yy, col, line_col, 1.6 * k)
        s += dot(x - 0.8 * k, yy + L * 0.7, 0.9 * k, '#ffffff', 0.9)
    return s


def soft_hair(sx, sy, k=1.0):
    """A few soft white wisps and curls on an old bald crown."""
    s = ''
    for d in ('M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f' % (sx - 12 * k, sy, sx - 18 * k, sy - 8 * k, sx - 10 * k, sy - 14 * k, sx - 4 * k, sy - 9 * k),
              'M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f' % (sx - 2 * k, sy - 3 * k, sx - 4 * k, sy - 14 * k, sx + 8 * k, sy - 16 * k, sx + 8 * k, sy - 8 * k),
              'M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f' % (sx + 10 * k, sy - 1 * k, sx + 14 * k, sy - 10 * k, sx + 24 * k, sy - 8 * k, sx + 22 * k, sy - 1 * k)):
        s += line(d, '#6a6070', 4.4 * k) + line(d, '#f8f4ff', 2.4 * k)
    return s


def moth_svg(ctx, cx, cy, k=1.0, face=False, rot=0.0, col='#d8e8c8', line_col='#2a3a2a', spots=True):
    """A plump little moth (four round wings with eye-spots, a fuzzy body,
    feathery feelers), centred on (cx, cy), k times 10 units across."""
    t = 'translate(%.1f %.1f) rotate(%.1f) scale(%.3f)' % (cx, cy, rot, k)
    wing_sh = mix(col, '#6a8a6a', 0.35)
    s = ''
    for sx in (-1, 1):
        s += '<path d="M0 -2 C%d -16 %d -18 %d -8 C%d -2 %d 2 0 2 Z" fill="%s" stroke="%s" stroke-width="1.4"/>' % (
            sx * 8, sx * 22, sx * 20, sx * 18, sx * 8, col, line_col)
        s += '<path d="M0 1 C%d 4 %d 14 %d 12 C%d 10 %d 6 0 3 Z" fill="%s" stroke="%s" stroke-width="1.4"/>' % (
            sx * 6, sx * 16, sx * 10, sx * 6, sx * 3, wing_sh, line_col)
        if spots:
            s += '<circle cx="%d" cy="-8" r="3" fill="%s"/><circle cx="%d" cy="-8" r="1.3" fill="#e8f4d8"/>' % (sx * 12, '#4a5a3a', sx * 12)
        s += '<path d="M%d -9 Q%d -18 %d -20" fill="none" stroke="%s" stroke-width="1.1"/>' % (sx * 1, sx * 4, sx * 8, line_col)
    s += '<ellipse cx="0" cy="1" rx="3.6" ry="7" fill="#f4f8e8" stroke="%s" stroke-width="1.4"/>' % line_col
    s += '<circle cx="0" cy="-5" r="3.4" fill="#fffcf0" stroke="%s" stroke-width="1.2"/>' % line_col
    if face:
        s += dot(-1.4, -5.4, 1.1, line_col) + dot(1.6, -5.4, 1.0, line_col) + dot(-1.7, -5.8, 0.4, '#ffffff') + dot(1.3, -5.8, 0.4, '#ffffff')
        s += '<ellipse cx="-2.6" cy="-3.6" rx="1" ry="0.6" fill="#ff9aa0" opacity="0.7"/><ellipse cx="2.8" cy="-3.6" rx="1" ry="0.6" fill="#ff9aa0" opacity="0.7"/>'
    return '<g transform="%s">%s</g>' % (t, s)


# ================================================================ Old Tollgrave, freed (sitting)

def tollgrave_sit():
    """Sitting on the belfry floor, legs out, hood fallen back: white wisps of
    hair, a beard tuft, a gentle jaw smile, the whole bell beside him. Drawn in
    boss.py's units (WICK's), like tollgrave_boss; the sockets are left for the
    engine's amber eye-lights."""
    import boss
    from enemies import BONE, BONE_SH, BONE_LINE
    f = Fig('tollgrave_sit', 0.5)
    ctx = Ctx('ftg')
    L = boss.L
    parts = []
    # the bell beside him, whole again, mouth down on the boards
    parts += boss.bell(ctx, 212, 170, 0.72, 0)
    # bony feet sticking out from under the robe
    for fx, fy in ((176, 238), (160, 241)):
        parts.append(Part('fill', pth(ell_d(fx, fy, 9, 4.4, -8)), fill=BONE, shade=BONE_SH, off=(-1, -1), line=BONE_LINE))
        parts.append(Part('limb', pth('M%.1f %.1f L%.1f %.1f' % (fx - 16, fy - 3, fx - 6, fy - 1)), width=3, fill=BONE, line=BONE_LINE))
    # the robe as a sitting mound, the cord belt
    robe = ('M86 150 C72 160 62 190 60 214 C58 230 62 242 74 244 L150 244 C162 242 170 236 166 226 C160 214 150 206 150 190 '
            'C150 172 146 158 140 150 Z')
    folds = line('M84 176 Q78 206 80 238 M112 188 Q114 214 120 240', L, 1.2, op=0.5) + line('M76 178 Q70 200 70 222', boss.ROBE_HI, 2.2, op=0.7)
    cord = line('M68 204 Q104 214 146 204', L, 6) + line('M68 204 Q104 214 146 204', boss.CORD, 3.2)
    parts.append(Part('fill', pth(robe), fill=boss.ROBE, shade=boss.ROBE_SH, off=(-4, -3), over=folds + cord))
    # an arm resting on the bell, the other hand in his lap
    parts.append(boss.sleeve((140, 160), (184, 172), 12, 18))
    parts += boss.bone_hand(192, 172, 10, fist=False)
    parts.append(boss.sleeve((100, 162), (122, 196), 12, 17, boss.ROBE_SH, '#261e33'))
    parts += boss.bone_hand(128, 200, 60)
    # the hood fallen back behind the skull
    hx, hy = 112, 124
    parts.append(Part('fill', pth(ell_d(hx - 14, hy + 6, 30, 28)), fill=boss.ROBE, shade=boss.ROBE_SH, off=(-3, -3),
                      over=line('M%d %d Q%d %d %d %d' % (hx - 34, hy - 4, hx - 36, hy + 14, hx - 24, hy + 28), boss.ROBE_HI, 1.8, op=0.8)))
    parts.append(Part('fill', pth('M86 146 C96 136 136 134 146 146 C140 154 96 156 86 146 Z'), fill=boss.ROBE, shade=boss.ROBE_SH, off=(-2, -2)))
    # the skull: a gentle jaw smile, empty sockets (the engine lights them amber)
    sx, sy = 118, 118
    jaw = 'M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z' % (
        sx - 12, sy + 13, sx - 11, sy + 22, sx - 2, sy + 25, sx + 6, sy + 25, sx + 14, sy + 25, sx + 21, sy + 21, sx + 20, sy + 12)
    parts.append(Part('fill', pth(jaw), fill=BONE, shade=BONE_SH, off=(-1, -1), line=BONE_LINE))
    face = ''
    for ex, ey, w, h in ((sx - 8, sy - 1, 13, 14), (sx + 11, sy - 2, 11, 13)):
        face += '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="#1a0e08"/>' % (ex, ey, w / 2, h / 2)
    face += '<path d="M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z" fill="%s"/>' % (
        sx + 2.4, sy + 5, sx + 0.4, sy + 3.6, sx - 0.8, sy + 6.4, sx + 2.2, sy + 8.6, sx + 5.2, sy + 6.4, sx + 4.2, sy + 3.6, sx + 2.4, sy + 5, BONE_LINE)
    # the smile: a curved row of teeth turned up at the corners
    face += '<path d="M%.1f %.1f Q%.1f %.1f %.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f Z" fill="%s"/>' % (
        sx - 9, sy + 10.4, sx + 4, sy + 18, sx + 18, sy + 9.6, sx + 18, sy + 12.4, sx + 4, sy + 21.4, sx - 9, sy + 13.4, BONE_LINE)
    for i in range(6):
        t = (i + 0.5) / 6.0
        x = sx - 8 + t * 25
        y = sy + 11 + 6.2 * math.sin(t * math.pi) + 0.4
        face += '<rect x="%.1f" y="%.1f" width="2.8" height="2.6" rx="0.6" fill="#fffaf0"/>' % (x - 1.4, y)
    face += kit.blush(sx - 14, sy + 8, dict(blush='#ff9a8a'), 3, 1.8, lines=False, op=0.45)
    hl = spec(sx - 12, sy - 14, 6, 3, rot=-38, op=0.95) + dot(sx - 4, sy - 19, 1.4, '#ffffff', 0.9)
    parts.append(Part('fill', kit.head_tpl(sx, sy, 46, 42, squish=-0.08), fill=BONE, shade=BONE_SH, off=(-3.4, -3.4), line=BONE_LINE,
                      over=face, hl=hl))
    # a few soft curls of white hair, and a little beard tuft
    hair = soft_hair(sx, sy - 19, 0.8)
    beard = 'M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z' % (
        sx - 4, sy + 23, sx - 8, sy + 32, sx - 4, sy + 42, sx + 2, sy + 48, sx + 4, sy + 40, sx + 12, sy + 36, sx + 14, sy + 23,
        sx + 8, sy + 26, sx + 1, sy + 26, sx - 4, sy + 23)
    parts.append(Part('fill', pth(beard), fill='#f8f4ff', shade='#c8c0d8', off=(-1, -1), line=BONE_LINE,
                      over=line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (sx + 2, sy + 27, sx + 3, sy + 33, sx + 5, sy + 38), '#c8c0d8', 1)))
    body = '<ellipse cx="140" cy="245" rx="92" ry="8" fill="#07040a" opacity="0.3"/>'
    body += kit.render_parts(ctx, parts, dict(line=L, rim=RIM, base=boss.ROBE, shade=boss.ROBE_SH)) + hair
    f.set_flame('eyes', sx + 1.5, sy - 1.5, 0, {'kind': 'eyes', 'color': 'f7b64a', 'pts': [[sx - 8, sy - 1], [sx + 11, sy - 2]],
                                              'dot': 3.0, 'r': 110, 's': 0.75})
    return f, fig_doc(ctx, body)


# ================================================================ the Snuffer

# story_snuffer.py draws him with the fight's own parts (boss2.py), in its
# 384 frame, and places that in the figure frame.
SNUFFER_EYES = dict(kind='eyes', color='eeeaf8', dot=round(SN.EYE_R * SN.FIG_K, 2), r=60.0, s=0.55)


def snuffer(pose):
    """The Snuffer, 2.2x Waxby's height, the cone 40% of him: standing with his
    pole upright (the taunt), or reaching it up and forward to snuff a candle
    (the crypt, the Undercandle)."""
    fid = 'snuffer_stand' if pose == 'stand' else 'snuffer_reach'
    f = Fig(fid, 1.0, h=SN.FIG_H)
    ctx = Ctx('fsn' + pose[:2])
    if pose == 'stand':
        art, eyes = SN.stand(ctx)
    else:
        art, eyes, _ = SN.reach(ctx)
    pts = [list(SN.to_fig(e)) for e in eyes]
    mid = ((pts[0][0] + pts[1][0]) / 2, (pts[0][1] + pts[1][1]) / 2)
    f.set_flame('eyes', mid[0], mid[1], 0, dict(SNUFFER_EYES, pts=pts))
    return f, fig_doc(ctx, SN.fig_body(art))


def cone_broken():
    """The iron cone split in two on the floor, the bell toppled beside it,
    a curl of smoke rising from where the Snuffer fell."""
    f = Fig('cone_broken', 1.0, h=SN.FIG_H)
    ctx = Ctx('fcb')
    return f, fig_doc(ctx, SN.fig_body(SN.broken(ctx)))


# ================================================================ Hollin

HOL = dict(ash='#c8c4cc', ash_sh='#a09ca8', warm='#ffd9c0', warm_sh='#f4b89e', hair='#3a3844', hair_hi='#5a5866',
           tabard='#6a7488', tabard_sh='#4e566a', tunic='#8a8a96', tunic_sh='#6a6a78', boot='#4a4a56', line='#1c1a24',
           trim='#a89a70', steel='#a8acbc', steel_sh='#7a7e94', steel_hi='#e2e4ee')
HCOLD = dict(line=HOL['line'], base=HOL['ash'], iris0='#1e2430', iris1='#6a8098', iris2='#d0dcea', blush='#b8a8c8')
HWARM = dict(line=HOL['line'], base=HOL['warm'], iris0='#1e2430', iris1='#4a78a8', iris2='#bfe0ff', blush='#ff9aa0')


def hollin_face(ctx, cx, cy, mood, k=1.0):
    """Hollin's face centred on (cx, cy), native units (Wick's face, doubled)."""
    F = HCOLD if mood == 'cold' else HWARM
    E1 = (cx - 15 * k, cy + 1 * k, 25 * k, 32 * k)
    E2 = (cx + 20 * k, cy, 20.5 * k, 30 * k)
    s = ''
    if mood == 'cold':
        s += kit.eye(ctx, *E1, F, look=(0.6, 3.0)) + kit.eye(ctx, *E2, F, look=(0.6, 3.0))
        s += kit.worried_brows([E1, E2], F, lift=6, thick=3.6)
        s += kit.tears([E1, E2], streams=False)
        s += kit.mouth_frown(cx + 4 * k, cy + 26 * k, 11 * k, F)
    else:
        for ex, ey, w, h in (E1, E2):
            s += kit.eye(ctx, ex, ey + 2 * k, w + 1, h * 0.78, F, mood='happy')
        s += kit.tears([E1, E2], streams=True)
        s += kit.blush(cx - 26 * k, cy + 18 * k, F, 9 * k, 5 * k) + kit.blush(cx + 32 * k, cy + 16 * k, F, 6.4 * k, 4 * k)
        s += kit.mouth_open(cx + 4 * k, cy + 21 * k, 14 * k, 9 * k, F)
    return s


def messy_hair(cx, cy, w, h, col, hi, line_col):
    """A mop of messy hair over the top of a head centred on (cx, cy)."""
    a, b = w / 2.0, h / 2.0
    pts = []
    n = 11
    for i in range(n + 1):
        t = math.pi + math.pi * i / n
        r = 1.08 if i % 2 == 0 else 0.9
        pts.append((cx + a * r * math.cos(t), cy - b * 0.1 + b * r * math.sin(t)))
    d = 'M%.1f %.1f' % (cx - a * 1.02, cy + b * 0.25)
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        d += ' Q%.1f %.1f %.1f %.1f' % (x0 + (x1 - x0) * 0.2, y0 - 6, x1, y1)
    # the fringe falling over the brow in tufts
    d += ' L%.1f %.1f' % (cx + a * 1.02, cy + b * 0.2)
    fr = [(cx + a * 0.8, cy - b * 0.1), (cx + a * 0.55, cy - b * 0.35), (cx + a * 0.3, cy - b * 0.02), (cx, cy - b * 0.38),
          (cx - a * 0.3, cy - b * 0.05), (cx - a * 0.6, cy - b * 0.4), (cx - a * 0.86, cy + b * 0.05)]
    for x, y in fr:
        d += ' L%.1f %.1f' % (x, y)
    d += ' Z'
    return Part('fill', pth(d), fill=col, shade=mix(col, '#000000', 0.3), off=(-3, -3),
                over=line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (cx - a * 0.5, cy - b * 0.8, cx - a * 0.1, cy - b * 1.0, cx + a * 0.3, cy - b * 0.86), hi, 2.4, op=0.9))


def hollin_cold():
    """Wick-sized, ash-grey, bare-headed, sitting and hugging his knees."""
    f = Fig('hollin_cold', 1.0)
    ctx = Ctx('fhc')
    H = HOL
    parts = []
    # the body curled up: back and seat, the faded tabard
    parts.append(P('M92 176 C80 196 78 222 84 240 L138 244 C146 226 140 196 128 176 Z', H['tabard'], H['tabard_sh'], off=(-5, -3),
                   over=line('M96 196 Q92 216 94 236', H['trim'], 2.4, op=0.7)))
    # shins drawn up, boots on the floor
    parts.append(LIMB('M132 232 L150 188 L178 226', H['tunic'], 22))
    parts.append(E(186, 236, 14, 8.6, H['boot'], off=(-2, -2)))
    parts.append(E(170, 240, 13, 8, H['boot'], off=(-2, -2)))
    parts.append(LIMB('M150 190 L170 230', mix(H['tunic'], '#000000', 0.12), 18))
    # arms wrapped round his knees, hands clasped
    parts.append(P('M104 180 C120 184 148 196 172 204 L168 218 C142 212 118 204 100 196 Z', H['tabard'], H['tabard_sh'], off=(-2, -3)))
    parts.append(E(172, 210, 8, 7.4, H['ash'], H['ash_sh'], off=(-1.4, -1.4),
                   over=line('M168 207 L177 207 M168.6 211 L177 211', H['line'], 1, op=0.7)))
    # the head resting on his knees
    hx, hy = 146, 142
    head = kit.head_tpl(hx, hy, 104, 92)
    parts.append(Part('fill', head, fill=H['ash'], shade=H['ash_sh'], off=(-4, -4), over=hollin_face(ctx, hx + 4, hy + 6, 'cold')))
    parts.append(E(92, 146, 7, 10, H['ash'], H['ash_sh'], off=(-1, -1)))
    parts.append(messy_hair(hx, hy - 10, 110, 82, H['hair'], H['hair_hi'], H['line']))
    body = shadow(134, 60) + render(ctx, parts, H['line'], H['tabard'])
    return f, fig_doc(ctx, fit(body, f.s))


def dented_helm(ctx, cx, top, w, lit=True, stub=11):
    """Hollin's candle-helm: an older, smaller kettle hat, dented, an H
    scratched on the brow, a burnt stub (stub tall) on the crown. Returns
    (parts, wick tip)."""
    H = HOL
    a = w / 2.0
    brim_y = top + w * 0.44
    parts = []
    dome = ('M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f '
            'L%.1f %.1f L%.1f %.1f Z') % (
        cx - a * 0.86, brim_y, cx - a * 0.9, top + w * 0.06, cx - a * 0.1, top - w * 0.02, cx + a * 0.1, top + w * 0.02,
        cx + a * 0.62, top, cx + a * 0.92, top + w * 0.12, cx + a * 0.86, brim_y, cx + a * 0.86, brim_y, cx - a * 0.86, brim_y)
    dent = line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (cx + a * 0.2, top + w * 0.05, cx + a * 0.34, top + w * 0.2, cx + a * 0.3, top + w * 0.34),
                H['steel_sh'], 2.4) + line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (cx + a * 0.24, top + w * 0.04, cx + a * 0.38, top + w * 0.19, cx + a * 0.34, top + w * 0.33),
                                          H['steel_hi'], 1.2, op=0.9)
    hmark = line('M%.1f %.1f L%.1f %.1f M%.1f %.1f L%.1f %.1f M%.1f %.1f L%.1f %.1f' % (
        cx - 7, brim_y - 16, cx - 6, brim_y - 5, cx + 5, brim_y - 16, cx + 6, brim_y - 5, cx - 6.5, brim_y - 10.5, cx + 5.5, brim_y - 10.5), '#4a4a5e', 1.8)
    rust = '<ellipse cx="%.1f" cy="%.1f" rx="4" ry="2.6" fill="#a8683a" opacity="0.7"/>' % (cx - a * 0.5, top + w * 0.3)
    parts.append(Part('fill', pth(dome), fill=H['steel'], shade=H['steel_sh'], off=(-6, -6), over=dent + hmark + rust,
                      hl=spec(cx - a * 0.5, top + w * 0.14, 8, 3.4, rot=-40, op=0.9)))
    parts.append(Part('fill', ell(cx, brim_y, a * 1.14, w * 0.085), fill=H['steel'], shade=H['steel_sh'], off=(-2, -3),
                      over=line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (cx - a * 1.1, brim_y - 1, cx, brim_y - w * 0.07, cx + a * 1.1, brim_y - 1), H['steel_hi'], 2, op=0.9)
                      + line('M%.1f %.1f l6 5' % (cx + a * 0.6, brim_y + 2), H['steel_sh'], 2)))
    # the cup and the burnt stub on the crown
    ux, uy = cx - a * 0.05, top + w * 0.02
    parts.append(P('M%.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f Z' % (ux - 12, uy - 3, ux + 12, uy - 3, ux + 11, uy + 5, ux, uy + 6,
                                                                                    ux - 11, uy + 5, ux - 12, uy - 3),
                   '#a88a4a', '#7a6030', off=(-1.4, -1.4)))
    cp, wk, tip = candle(ctx, ux, uy - 2, 13, stub, H['line'], drips=((0.2, 0.3), (0.72, 0.42)), wax='#e8dcc0', wax_sh='#c0b090')
    parts += cp
    parts[-1].over += wk
    return parts, tip


def hollin_warm():
    """Standing, warmed through, a teary smile, the dented helm on and lit."""
    f = Fig('hollin_warm', 1.0)
    ctx = Ctx('fhw')
    H = HOL
    parts = []
    parts.append(E(112, 239, 13, 7, H['boot'], off=(-2, -2)))
    parts.append(E(150, 240, 13, 7, H['boot'], off=(-2, -2)))
    parts.append(LIMB('M116 208 L114 232', H['tunic'], 14))
    parts.append(LIMB('M144 208 L148 232', H['tunic'], 14))
    # the faded tabard over the tunic, frayed hem, a faded flame on the chest
    tab = 'M106 166 L152 166 C158 184 160 200 162 214 L150 218 L140 212 L130 219 L118 212 L108 218 L96 214 C98 200 100 184 106 166 Z'
    em = '<path d="%s" fill="%s" stroke="%s" stroke-width="1.6" opacity="0.8"/>' % (flame_d(130, 200, 13, 21, 1), H['trim'], H['line'])
    parts.append(P(tab, H['tabard'], H['tabard_sh'], off=(-5, -3), over=em + line('M100 206 L160 206', H['trim'], 2, op=0.6)))
    # one arm wiping a happy tear, the other hanging
    parts.append(P('M104 172 C96 180 92 194 94 206 L104 208 C104 196 106 186 110 178 Z', H['tunic'], H['tunic_sh'], off=(-2, -2)))
    parts.append(E(98, 212, 7, 6.6, H['warm'], H['warm_sh'], off=(-1, -1)))
    parts.append(P('M150 170 C160 170 170 164 176 154 L186 160 C180 174 166 182 154 184 Z', H['tunic'], H['tunic_sh'], off=(-2, -2)))
    parts.append(E(184, 152, 7.4, 7, H['warm'], H['warm_sh'], off=(-1, -1)))
    hx, hy = 136, 126
    parts.append(Part('fill', kit.head_tpl(hx, hy, 102, 86), fill=H['warm'], shade=H['warm_sh'], off=(-4, -4),
                      over=hollin_face(ctx, hx + 4, hy + 8, 'warm')))
    parts.append(E(86, 132, 7, 10, H['warm'], H['warm_sh'], off=(-1, -1)))
    parts.append(messy_hair(hx, hy - 6, 104, 70, H['hair'], H['hair_hi'], H['line']))
    helm, tip = dented_helm(ctx, hx - 2, 70, 94)
    parts += helm
    # the torn chin strap
    parts.append(LIMB('M86 110 Q84 132 92 150', '#6a4a30', 3.4))
    body = shadow(130, 50) + render(ctx, parts, H['line'], H['tabard'])
    f.flame('head', tip[0], tip[1], 30, kind='flame', r=260, s=1.0)
    return f, fig_doc(ctx, fit(body, f.s))


# ================================================================ the moth swarm (P1)

def moth_swarm():
    """Seventy-odd ivory-green moths whirling round a hollow in the shape of
    the Snuffer (a flared cone head over a hooded robe), his two pale eyes
    in the dark of the cone."""
    f = Fig('moth_swarm', 0.5)
    ctx = Ctx('fms')
    sil = [(128, -170), (140, -110), (152, -50), (176, -4), (214, 16), (166, 22), (178, 80), (198, 160), (212, 244), (44, 244), (58, 160),
           (78, 80), (90, 22), (42, 16), (80, -4), (104, -50), (116, -110)]

    def inside(x, y):
        c = False
        n = len(sil)
        for i in range(n):
            x0, y0 = sil[i]
            x1, y1 = sil[(i + 1) % n]
            if (y0 > y) != (y1 > y) and x < x0 + (y - y0) * (x1 - x0) / (y1 - y0):
                c = not c
        return c

    def dist(x, y):
        best = 1e9
        n = len(sil)
        for i in range(n):
            x0, y0 = sil[i]
            x1, y1 = sil[(i + 1) % n]
            dx, dy = x1 - x0, y1 - y0
            t = max(0.0, min(1.0, ((x - x0) * dx + (y - y0) * dy) / float(dx * dx + dy * dy)))
            best = min(best, math.hypot(x - (x0 + t * dx), y - (y0 + t * dy)))
        return best
    rng = Rand(909)
    moths = []
    tries = 0
    while len(moths) < 78 and tries < 40000:
        tries += 1
        x, y = rng.u(-60, 316), rng.u(-230, 250)
        if inside(x, y):
            continue
        d = dist(x, y)
        near = d < 34
        if d > 86 or d < 4 or (not near and rng.f() < 0.55):
            continue
        if any(math.hypot(x - mx, y - my) < (20 if near else 28) for mx, my, _, _ in moths):
            continue
        a = math.degrees(math.atan2(y - 40, x - 128)) + 90 + rng.u(-20, 20)
        k = (1.7 if near else 1.35) + rng.u(-0.2, 0.2)
        moths.append((x, y, a, k))
    # the hollow itself: a faint shadow of him, so the negative space reads
    s = '<path d="%s" fill="#140e22" opacity="0.6" stroke="#6a8a6a" stroke-width="2" stroke-opacity="0.35"/>' % poly_d(sil)
    for r0 in (170, 210, 250):
        s += '<path d="%s" fill="none" stroke="#d8e8c8" stroke-width="3" opacity="0.14" stroke-dasharray="30 22"/>' % ell_d(128, 30, r0 * 0.66, r0, 0)
    for x, y, a, k in sorted(moths, key=lambda m: m[3]):
        s += moth_svg(ctx, x, y, k, rot=a)
    e1, e2 = (112, 4), (144, 3)
    for ex, ey in (e1, e2):
        s += '<circle cx="%.1f" cy="%.1f" r="8" fill="#e8e4ff" opacity="0.2"/>' % (ex, ey) + dot(ex, ey, 3.2, '#e8e4ff')
    f.flame('eyes', 128, 3.5, 6, kind='eyes', color='e8e4ff', pts=[e1, e2], dot=3.4, r=160, s=0.6)
    return f, fig_doc(ctx, fit(s, f.s))


# ================================================================ the Hush's eye (P1)

def hush_eye():
    """An almond eye 600 x 220 panel units: a pale violet white darkening at the
    corners, a thin dim iris ring, a tiny black pupil with one glint, black lids
    (scaling it on y opens it). Its pivot, feet, is the eye's centre."""
    f = Fig('hush_eye', 1.0, px=8, feet=(128.0, 128.0), h=640.0)
    ctx = Ctx('fhe')
    cx, cy, a, b = 128, 128, 120, 44
    almond = 'M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z' % (
        cx - a, cy, cx - a * 0.5, cy - b * 1.34, cx + a * 0.5, cy - b * 1.34, cx + a, cy,
        cx + a * 0.5, cy + b * 1.34, cx - a * 0.5, cy + b * 1.34, cx - a, cy)
    white = ctx.radgrad([(0, '#e4e0f8'), (0.55, '#d8d4f0'), (0.85, '#8a82b0'), (1, '#3a3260')], cx=0.5, cy=0.5, r=0.55)
    s = '<path d="%s" fill="#000000"/>' % ell_d(cx, cy, a * 1.12, b * 1.9)
    clip = ctx.clip('<path d="%s"/>' % almond)
    inner = '<rect x="0" y="0" width="256" height="256" fill="%s"/>' % white
    iris = ctx.radgrad([(0, '#3a3060'), (0.7, '#4a3e78'), (0.86, '#6a5a9a'), (1, '#6a5a9a', 0)])
    inner += '<circle cx="%d" cy="%d" r="38" fill="%s"/>' % (cx, cy, iris)
    inner += '<circle cx="%d" cy="%d" r="34" fill="none" stroke="#6a5a9a" stroke-width="2"/>' % (cx, cy)
    inner += '<circle cx="%d" cy="%d" r="6" fill="#000000"/>' % (cx, cy)
    inner += dot(cx - 2.2, cy - 2.4, 1.6, '#ffffff')
    inner += '<path d="%s" fill="none" stroke="#1a1430" stroke-width="10" opacity="0.6"/>' % almond
    s += '<g clip-path="%s">%s</g>' % (clip, inner)
    # the lids' rims catching a thread of violet
    s += line('M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f' % (cx - a, cy, cx - a * 0.5, cy - b * 1.34, cx + a * 0.5, cy - b * 1.34, cx + a, cy), '#4a3a7a', 1.6, op=0.9)
    s += line('M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f' % (cx - a, cy, cx - a * 0.5, cy + b * 1.34, cx + a * 0.5, cy + b * 1.34, cx + a, cy), '#2a2440', 1.2, op=0.9)
    return f, fig_doc(ctx, s, px=8)


# ================================================================ all

FIGURES = [taper_stand, taper_chair, taper_smoke, novice_back, waxley_pack, tollgrave_boss, tollgrave_sit,
           lambda: snuffer('stand'), lambda: snuffer('reach'), cone_broken, hollin_cold, hollin_warm, moth_swarm, hush_eye]


def figures():
    out = {}
    files = {}
    for fn in FIGURES:
        fig, svg = fn()
        out[fig.id] = fig.entry()
        files['art/story/figures/%s.svg' % fig.id] = svg
    return out, files
