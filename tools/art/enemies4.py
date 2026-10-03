"""WAXBY v3's World 5 and World 6 monsters, one SVG per frame on the 128 x 128
frame (2 units = 1 world px, sprite scale 0.25), facing right, in the kit of
enemies3.py. Walkers stand with their feet on (64, 122); fliers and the
Lurecoil's pieces are anchored on their middle (64, 64).

World 5, the Shattered Sanctum (family: jewel glass in lead 1a1420, white-core eyes with a ring, a glass
highlight streak on every body, the warm rim)
  Glassmite   mite_walk1, _walk2, _gnaw, _hit
  Gustling    gust_idle1, _idle2, _inhale, _blow, _hit
  Refractor   refractor_idle1, _idle2, _charge, _fire, _hit (it aims at any angle and the sprite is
              not turned, so the lock and fire frames draw only a star round the lens: code draws the
              aim line and the beam from `lens`)
  Paneguard   pane_face1, _face2, _turn, _edge, _cut, _hit, _shatter
  The Glassmite and the Paneguard are drawn in neutral glass: enemy.gd's `tint` (the sprite's
  modulate) gives them their colour (points_monsters4.json `_tints`: red, blue, gold, by hash(cell)).
  The Glassmite's `hit` box is 40 units (20 px) tall, over its 14 px body (spec §4.5).
  W5's tell accent is a prism white, so the glass, the cloud and the prism are drawn off it (neutral
  panes up to e2e3ec, cloud dfe3ef, prism d8d4ea) and their shines in cyan-white d4ecff (enemies3.Fr).
World 6, the Hushdeep (family: ink bodies 2a2838, the silver rim c8c8f0 at 4 units (2 px), pale eyes
d8d4f0 of at least 3 px, Hush-violet 6a5a9a)
  Hushling    hushling_idle1, _idle2, _crouch, _lunge, _blink, _pop
  Stillmaw    maw_idle, _strain, _open, _choke, _hit
  Lurecoil    coil_head_closed, _head_open, _head_rest, coil_seg, coil_tail, coil_hit (the head faces
              right; the segments and the tail trail behind it, each centred on (64, 64)), and
              coil_head_closed_bare, _head_open_bare, _head_rest_bare, coil_hit_bare: the head once a
              hit on the lure has knocked its stolen candle loose (no candle, no flame)
  The Unwick has no frames: it is the player's own rig in black with a silver rim.

The Omen looks (P1): omen_glassed (a faceted glass shell) and omen_echo_dial (a flat clock dial for the
feet), 128-unit overlays on their middle; omen_spore_mote and omen_hush_mote, 32-unit motes. How elites.gd
draws each is points_monsters4.json `_omens`.

points_monsters4.json: as points_monsters3.json (enemies3.py's docstring), plus `_tints` (the glass kinds'
modulate colours), `_rim` and `_omens`. `_roles` in both says which frame shows which state.
Run on its own: python3 tools/art/enemies4.py (writes under game/).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import kit
from kit import Part, ell, pth
from common import RIM, eye, blush, sweat, line, dot, squeeze, swirl_eye, spec, sparkle, star4, mix, gx, flame
import enemies3 as e3
from enemies3 import (Fr, POINTS, FRAMES, smooth, poly, rot, tf, pt, ring, blob, shard, ground_shadow, motion, glint,
                      dizzy_stars, specks, puff, hi_line, face_eyes, mouth, smile, fmt, xpath, ell_path, rrect_d)

# ================================================================ World 5: glass

LEAD = '#1a1420'
GLASS_N = ['#dcdee9', '#c8cbdc', '#b4b8cc', '#d2d5e4', '#bfc3d6', '#e2e3ec']   # neutral panes (tinted by modulate),
# kept off the prism-white tell accent
GL, GL_SH, GL_HI = '#dfe2ee', '#aeb2c8', '#ffffff'
TELL5 = '#f8f0ff'          # World 5's tell accent: prism white
SHINE5 = '#d4ecff'         # W5's glass shines, motion lines and sparkles: cyan-white (white is for tells)
GPAL = dict(line=LEAD, rim=RIM, base=GL, shade=GL_SH)
TINTS = {'red': '#ff8878', 'blue': '#8cb4ff', 'gold': '#ffd870'}
RING_N = '#6a6e86'         # the eye ring on the tinted kinds (neutral: modulate colours it)


def stained(f, outline_d, box, cell=(9.0, 9.0), lead_w=1.3, jitter=0.28, seed=1, light=(-0.6, -0.8), streak=None,
            diamond=False):
    """Panes of neutral glass in lead, clipped to outline_d: a jittered grid over
    box (x0, y0, x1, y1) (diamond: turned 45 deg, the leaded quarries of a
    window). Lighter toward light (a unit direction), plus a white highlight
    streak (a path) on top. Raw SVG for a Part's over."""
    x0, y0, x1, y1 = box
    if diamond:
        mx, my = (x0 + x1) / 2, (y0 + y1) / 2
        half = max(x1 - x0, y1 - y0) * 0.75
        x0, y0, x1, y1 = mx - half, my - half, mx + half, my + half
    cw, ch = cell
    nx, ny = max(1, int(math.ceil((x1 - x0) / cw))), max(1, int(math.ceil((y1 - y0) / ch)))
    grid = {}
    for j in range(ny + 1):
        for i in range(nx + 1):
            h = math.sin((i + 1) * 12.9898 + (j + 1) * 78.233 + seed * 37.719) * 43758.5453
            h2 = math.sin((i + 1) * 39.346 + (j + 1) * 11.135 + seed * 7.1) * 24634.6345
            jx = (h - math.floor(h) - 0.5) * cw * jitter * (0 < i < nx)
            jy = (h2 - math.floor(h2) - 0.5) * ch * jitter * (0 < j < ny)
            grid[(i, j)] = (x0 + i * cw + jx, y0 + j * ch + jy)
    cid = f.ctx.clip('<path d="%s"/>' % outline_d)
    s = '<g clip-path="%s">' % cid
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    for j in range(ny):
        for i in range(nx):
            q = [grid[(i, j)], grid[(i + 1, j)], grid[(i + 1, j + 1)], grid[(i, j + 1)]]
            if diamond:
                q = tf(q, deg=45, c=(cx, cy), sy=1.5)
            mx = sum(p[0] for p in q) / 4
            my = sum(p[1] for p in q) / 4
            lit = ((mx - cx) * light[0] + (my - cy) * light[1]) / max(x1 - x0, y1 - y0)
            k = (i * 3 + j * 5 + seed) % len(GLASS_N)
            col = mix(GLASS_N[k], '#9a9eb6', max(0.0, min(0.6, 0.3 - lit * 1.2)))
            s += '<path d="%s" fill="%s" stroke="%s" stroke-width="%.1f" stroke-linejoin="round"/>' % (poly(q), col, LEAD, lead_w)
    if streak:
        s += line(streak, '#ffffff', 2.0, op=0.75)
    return s + '</g>'


def fan_panes(f, outline_d, c, r_in, r_out, n, a0=180.0, a1=360.0, seed=1, lead_w=1.3, streak=None):
    """A Tiffany-lamp dome of panes: n sectors fanning from c, split at r_in."""
    cid = f.ctx.clip('<path d="%s"/>' % outline_d)
    s = '<g clip-path="%s">' % cid
    cx, cy = c
    for i in range(n):
        t0 = math.radians(a0 + (a1 - a0) * i / n)
        t1 = math.radians(a0 + (a1 - a0) * (i + 1) / n)
        for k, (ra, rb) in enumerate(((0, r_in), (r_in, r_out))):
            q = [(cx + ra * math.cos(t0), cy + ra * math.sin(t0)), (cx + rb * math.cos(t0), cy + rb * math.sin(t0)),
                 (cx + rb * math.cos(t1), cy + rb * math.sin(t1)), (cx + ra * math.cos(t1), cy + ra * math.sin(t1))]
            col = GLASS_N[(i * 2 + k * 3 + seed) % len(GLASS_N)]
            lit = math.cos((t0 + t1) / 2 - math.radians(225))
            col = mix(col, '#9a9eb6', max(0.0, 0.25 - lit * 0.3))
            s += '<path d="%s" fill="%s" stroke="%s" stroke-width="%.1f" stroke-linejoin="round"/>' % (poly(q), col, LEAD, lead_w)
    if streak:
        s += line(streak, '#ffffff', 2.0, op=0.75)
    return s + '</g>'


def ring_eye(cx, cy, r, ring_col, core='#fff2f8', look=(0.6, 0.0), mood='open', line_col=LEAD):
    """W5's eye: a dark socket, a coloured ring, a white core and a shine."""
    if mood == 'squeeze':
        return dot(cx, cy, r * 0.9, line_col, 0.0) + squeeze(cx, cy, r * 1.5, line_col, w=1.3)
    if mood == 'swirl':
        return dot(cx, cy, r, line_col) + swirl_eye(cx, cy, r * 0.8, '#ffffff', 0.9)
    lx, ly = look
    s = dot(cx, cy, r + 0.9, line_col)
    s += dot(cx + lx * 0.4, cy + ly * 0.4, r, ring_col)
    s += dot(cx + lx * 0.6, cy + ly * 0.6, r * 0.62, core)
    s += dot(cx + lx * 0.6 - r * 0.3, cy + ly * 0.6 - r * 0.3, r * 0.26, '#ffffff')
    return s


# ---------------------------------------------------------------- the Glassmite

def mite_leg(x, knee, foot, back=False):
    return Part('limb', pth('M%.1f 111 L%.1f %.1f L%.1f %.1f' % (x, knee[0], knee[1], foot[0], foot[1])), width=1.1,
                fill='#6a6480' if back else '#9a94b0', line=LEAD, lw=0.7, rim=not back)


def mite_svg(frame):
    name = 'mite_' + frame
    f = Fr(name, GPAL, shine=SHINE5)
    f.under = ground_shadow(64, 18)
    walk = frame in ('walk1', 'walk2')
    a = 1 if frame == 'walk1' else -1
    tilt = {'walk1': 0, 'walk2': 0, 'gnaw': 9, 'hit': -14}[frame]
    c = (66, 110)
    lift = -0.8 if frame == 'walk2' else 0.0
    # six needle legs: three a side (the far three darker, drawn first)
    for back in (True, False):
        for i, x in enumerate((52, 62, 72)):
            ph = (a if walk else 0.4) * (1 if (i % 2 == 0) != back else -1)
            ox = -2.4 if back else 0
            sd = -1 if i == 0 else (1 if i == 2 else 0.2)
            knee = (x + ox + sd * 4 + ph * 1.6, 112.6 - (1.2 if back else 0))
            foot = (x + ox + sd * 7 + ph * 3, 121.2)
            if frame == 'hit':
                knee, foot = (x + ox - 3, 104), (x + ox - 6 - i, 114 + i * 2)
            f.add(mite_leg(x + ox, knee, foot, back))
    dome = tf([(46, 112), (48, 104), (55, 98), (64, 96), (73, 97.6), (80, 102), (84, 109), (83, 113, 0), (47, 113, 0)],
              deg=tilt, c=c, dy=lift)
    dd = smooth(dome)
    over = fan_panes(f, dd, pt((65, 114), deg=tilt, c=c, dy=lift), 9, 30, 5, 180 + tilt, 360 + tilt, seed=3,
                   streak='M%s Q%s %s' % (fmt(pt((52, 104), deg=tilt, c=c, dy=lift)), fmt(pt((58, 98.6), deg=tilt, c=c, dy=lift)),
                                         fmt(pt((66, 98), deg=tilt, c=c, dy=lift))))
    seam = pt((64, 96.4), deg=tilt, c=c, dy=lift), pt((65, 112.6), deg=tilt, c=c, dy=lift)
    over += line('M%s L%s' % (fmt(seam[0]), fmt(seam[1])), LEAD, 1.8)
    f.add(Part('fill', pth(dd), fill=GL, shade=GL_SH, off=(-2, -1.6), over=over))
    # the head with its two tiny prism eyes and mandibles
    hc = pt((85, 109), deg=tilt * 1.6, c=c, dy=lift)
    head = ell_path(hc[0], hc[1], 6.6, 5.6)
    e1, e2 = (hc[0] - 1.4, hc[1] - 1.6), (hc[0] + 3.2, hc[1] - 1.8)
    mood = 'squeeze' if frame == 'hit' else 'open'
    fc = ring_eye(e1[0], e1[1], 2.7, RING_N, mood=mood) + ring_eye(e2[0], e2[1], 2.3, RING_N, mood=mood)
    f.add(Part('fill', pth(head), fill='#8a869e', shade='#6a6680', off=(-1, -1), over=fc,
               hl=spec(hc[0] - 3, hc[1] - 3, 1.4, 0.8, op=0.9)))
    jaw = 3.0 if frame == 'gnaw' else 0.0
    for s in (-1, 1):
        m0 = (hc[0] + 5.4, hc[1] + 2 + s * 1.2)
        m1 = (hc[0] + 9.2, hc[1] + 3.6 + s * 2.2 + jaw)
        f.add(Part('limb', pth('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (m0[0], m0[1], m1[0] + 1, m0[1] + s * 0.4, m1[0], m1[1])),
                   width=1.4, fill='#d0cee0', line=LEAD, lw=0.8))
    if frame == 'gnaw':
        tip = (hc[0] + 9.2, 120.4)
        f.over = (glint(tip[0], tip[1] - 1, 4.6, TELL5) + line('M%.1f 121.6 L%.1f 120.4 L%.1f 121.4 L%.1f 120.6' % (
            tip[0] + 1, tip[0] + 6, tip[0] + 10, tip[0] + 16), '#ffffff', 1.1)
            + motion('M%.1f %.1f l3 -2 M%.1f %.1f l4 0' % (tip[0] + 2, tip[1] - 6, tip[0] + 3, tip[1] - 2), 0.9))
        f.mark([e1, e2], 2.7, hit=(44, 82, 54, 40), jaws=(tip[0], tip[1] - 1))
    elif frame == 'hit':
        chips = ''.join('<path d="M%.1f %.1f l2.4 -2.6 l1.2 3.6 Z" fill="%s" stroke="%s" stroke-width="0.7" transform="rotate(%d %.1f %.1f)"/>' % (
            x, y, GLASS_N[i % 6], LEAD, a2, x, y) for i, (x, y, a2) in enumerate(((40, 96, 20), (94, 92, -30), (46, 86, 60), (100, 102, 10))))
        f.over = chips + motion('M36 104 L30 100 M98 86 L104 80', 1.2)
        f.mark([e1, e2], 2.7, hit=(42, 82, 54, 40))
    else:
        # the gameplay box is at least 20 px tall (spec §4.5), taller than the 14 px beetle: it reaches up over the dome
        f.mark([e1, e2], 2.7, hit=(44, 82, 50, 40), jaws=(hc[0] + 9, hc[1] + 3.6))
    return f.svg()


# ---------------------------------------------------------------- the Gustling

CLOUD, CLOUD_SH, CLOUD_HI = '#dfe3ef', '#b4b9d2', '#ffffff'   # a grey-blue cloud: the prism white is for tells
BELLOWS, BELLOWS_SH, LEATHER = '#8a5a3a', '#5e3a22', '#c08a5a'
BLUE_RING = '#5a7ad8'
UPAL = dict(line=LEAD, rim=RIM, base=CLOUD, shade=CLOUD_SH)
UFACE = dict(line=LEAD, base=CLOUD)


def fuzzy(cx, cy, r, bumps=11, depth=2.4, ry=None, phase=0.0):
    ry = ry or r
    pts = []
    for i in range(bumps):
        a = phase + 2 * math.pi * i / bumps
        pts.append((cx + r * math.cos(a), cy + ry * math.sin(a), 0))
        a2 = a + math.pi / bumps
        pts.append((cx + (r + depth) * math.cos(a2), cy + (ry + depth) * math.sin(a2)))
    return pts


def bellows(cx, cy, deg, open_=1.0, k=1.0):
    """A bellows wing: two wooden boards hinged at (cx, cy), pleated leather between."""
    spread = 14 + 26 * open_
    P = []
    a0, a1 = deg - spread / 2, deg + spread / 2
    ln = 22 * k

    def at(a, r):
        return (cx + r * math.cos(math.radians(a)), cy + r * math.sin(math.radians(a)))
    pleat = [at(a0, 3), at(a0, ln)]
    for i in range(1, 4):
        t = i / 4.0
        a = a0 + (a1 - a0) * t
        pleat.append(at(a, ln * (0.9 if i % 2 else 1.0)))
    pleat += [at(a1, ln), at(a1, 3)]
    folds = ''.join(line('M%s L%s' % (fmt(at(a0 + (a1 - a0) * t, 4)), fmt(at(a0 + (a1 - a0) * t, ln * 0.94))), BELLOWS_SH, 0.8, op=0.8)
                    for t in (0.25, 0.5, 0.75))
    P.append(Part('fill', pth(poly(pleat)), fill=LEATHER, shade=BELLOWS_SH, off=(-0.8, -0.8), over=folds))
    for a in (a0, a1):
        b = [at(a - 3.4, 2), at(a - 2.2, ln + 1.4), at(a + 2.2, ln + 1.4), at(a + 3.4, 2)]
        P.append(Part('fill', pth(poly(b)), fill=BELLOWS, shade=BELLOWS_SH, off=(-0.6, -0.6),
                      over=dot(*at(a, ln * 0.6), 0.9, e3.BRASS)))
    P.append(Part('fill', ell(cx, cy, 2.6 * k, 2.6 * k), fill=e3.BRASS, shade=e3.BRASS_SH, off=(-0.5, -0.5)))
    return P


def glass_halo(cx, cy, deg=0.0, k=1.0, broken=False):
    """A small ring of glass panes, tilted into an ellipse."""
    cols = ['#f4d8e0', '#f4ecc8', '#d4ecf4', '#e0d8f4']
    s = ''
    n = 8
    for i in range(n):
        if broken and i in (2, 3):
            continue
        a0 = 2 * math.pi * i / n
        a1 = 2 * math.pi * (i + 0.86) / n
        q = [(cx + 11 * k * math.cos(a0), cy + 3.6 * k * math.sin(a0)), (cx + 11 * k * math.cos(a1), cy + 3.6 * k * math.sin(a1)),
             (cx + 7.4 * k * math.cos(a1), cy + 2.2 * k * math.sin(a1)), (cx + 7.4 * k * math.cos(a0), cy + 2.2 * k * math.sin(a0))]
        q = tf(q, deg=deg, c=(cx, cy))
        s += '<path d="%s" fill="%s" stroke="%s" stroke-width="0.9" stroke-linejoin="round"/>' % (poly(q), cols[i % 4], LEAD)
    rim_d = smooth(tf(ring(cx, cy, 12.4 * k, 4.6 * k, 14), deg=deg, c=(cx, cy)))
    return ('<path d="%s" fill="none" stroke="%s" stroke-width="3.6" opacity="0.9"/>' % (rim_d, RIM)
            + '<path d="%s" fill="none" stroke="%s" stroke-width="1.6"/>' % (rim_d, LEAD) + s)


def gust_face(f, cx, cy, mood, puffk=1.0):
    e1, e2 = (cx - 3.6, cy - 3), (cx + 5.6, cy - 3.4)
    s = ''
    if mood in ('open', 'wide'):
        r = 3.2 if mood == 'open' else 3.6
        s += ring_eye(e1[0], e1[1], r, BLUE_RING, look=(0.8, 0.2)) + ring_eye(e2[0], e2[1], r * 0.85, BLUE_RING, look=(0.8, 0.2))
    elif mood == 'shut':
        for i, e in enumerate((e1, e2)):
            s += squeeze(e[0], e[1], 5, LEAD, flip=i == 1, w=1.4)
    else:
        s += ring_eye(e1[0], e1[1], 3.2, BLUE_RING, mood='swirl') + ring_eye(e2[0], e2[1], 2.8, BLUE_RING, mood='swirl')
    # cheeks
    for x, y, r in ((cx - 7.6, cy + 3.4, 3.6), (cx + 9.4, cy + 2.8, 3.0)):
        s += '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="#ffb0c8" opacity="0.75"/>' % (x, y, r * puffk, r * 0.72 * puffk)
    return s, [e1, e2]


def gust_svg(frame):
    name = 'gust_' + frame
    f = Fr(name, UPAL, shine=SHINE5)
    cx, cy = 62, 66
    bob = {'idle1': 0, 'idle2': 1.6, 'inhale': -1, 'blow': 0, 'hit': 2}[frame]
    cy += bob
    size = {'idle1': 1.0, 'idle2': 0.97, 'inhale': 1.14, 'blow': 0.94, 'hit': 1.0}[frame]
    open_ = {'idle1': 1.0, 'idle2': 0.3, 'inhale': 1.0, 'blow': 0.1, 'hit': 0.6}[frame]
    # the bellows wings, a pair either side of its shoulders, spread up and out like a cherub's
    f.add(bellows(cx + 13, cy - 8, 326, open_ * 0.9, 1.02))
    f.add(bellows(cx - 11, cy - 8, 214, open_, 1.12))
    sq = (1.08, 0.9) if frame == 'hit' else (1.0, 1.0)
    k = size
    puffs = [(-12, 4, 9.6), (-4, -9, 10.4), (8, -8, 9.4), (13, 4, 9.6), (-2, 8, 11), (4, 2, 13)]
    mood = {'idle1': 'open', 'idle2': 'open', 'inhale': 'wide', 'blow': 'shut', 'hit': 'swirl'}[frame]
    fc, eyes = gust_face(f, cx + 6, cy + 1, mood, 1.5 if frame == 'inhale' else 1.0)
    mp = (cx + 13 * size + (3 if frame == 'blow' else 0), cy + 6)
    if frame == 'blow':
        fc += '<ellipse cx="%.1f" cy="%.1f" rx="2.6" ry="3" fill="%s"/>' % (mp[0], mp[1], LEAD)
    elif frame == 'inhale':
        fc += '<ellipse cx="%.1f" cy="%.1f" rx="1.2" ry="1.4" fill="%s"/>' % (mp[0] - 2, mp[1], LEAD)
    elif frame == 'hit':
        fc += mouth(mp[0] - 3, mp[1] - 1, 4, 2.4, LEAD)
    else:
        fc += smile(mp[0] - 3, mp[1] - 1, 3.4, LEAD, 1.1)
    for i, (dx, dy, r) in enumerate(puffs):
        q = tf(ring(cx + dx * k, cy + dy * k, r * k, r * k * 0.92, 14), sx=sq[0], sy=sq[1], c=(cx, cy + 18))
        last = i == len(puffs) - 1
        f.add(Part('fill', pth(smooth(q)), fill=CLOUD, shade=CLOUD_SH, off=(-1.6, -1.8), over=fc if last else '',
                   hl=hi_line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (cx + dx * k - r * 0.6, cy + dy * k - r * 0.1, cx + dx * k - r * 0.5,
                                                               cy + dy * k - r * 0.6, cx + dx * k, cy + dy * k - r * 0.8), '#ffffff', 1.6, op=0.9)
                   if i in (1, 2) else ''))
    f.over = glass_halo(cx + 3, cy - 24 * size, deg=-8 if frame != 'hit' else 22, broken=frame == 'hit')
    if frame == 'inhale':
        f.over += motion('M%.1f %.1f L%.1f %.1f M%.1f %.1f L%.1f %.1f M%.1f %.1f L%.1f %.1f' % (
            mp[0] + 20, mp[1] - 8, mp[0] + 8, mp[1] - 2, mp[0] + 22, mp[1] + 2, mp[0] + 9, mp[1] + 1, mp[0] + 19, mp[1] + 11,
            mp[0] + 8, mp[1] + 4), 1.2)
        f.mark(eyes, 3.6, hit=(36, 36, 58, 56), mouth=mp)
    elif frame == 'blow':
        f.over += motion('M%.1f %.1f L%.1f %.1f M%.1f %.1f Q%.1f %.1f %.1f %.1f M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (
            mp[0] + 5, mp[1], 122, mp[1], mp[0] + 5, mp[1] - 4, 104, mp[1] - 12, 120, mp[1] - 12, mp[0] + 5, mp[1] + 4,
            104, mp[1] + 12, 120, mp[1] + 12), 1.4)
        f.over += puff(mp[0] + 10, mp[1], 3.4, CLOUD, 0.8, key=LEAD)
        f.mark(eyes, 3.2, hit=(40, 42, 50, 50), mouth=mp, gust=(120, mp[1]))
    elif frame == 'hit':
        f.over += sweat(86, 48, 0.45, 25) + motion('M88 40 L94 34 M30 50 L24 44', 1.2)
        f.mark(eyes, 3.2, hit=(38, 44, 54, 48))
    else:
        f.mark(eyes, 3.2, hit=(40, 42, 50, 50), mouth=mp)
    return f.svg()


# ---------------------------------------------------------------- the Refractor

PRISM, PRISM_SH, PRISM_HI = '#d8d4ea', '#a8a0c8', '#ffffff'   # a lilac-grey crystal: the prism white is for tells
VIOLET_RING = '#8a6ae0'
SPECTRUM = ['#ff8a9a', '#ffd070', '#8ae0a0', '#80b0ff', '#c090ff']
PETALS = ['#f4a0b4', '#f4d480', '#90b4f4']
YPAL = dict(line=LEAD, rim=RIM, base=PRISM, shade=PRISM_SH)


def petal(cx, cy, deg, col, k=1.0):
    pts = tf([(cx, cy - 8 * k, 0), (cx + 4.4 * k, cy - 1), (cx, cy + 7 * k, 0), (cx - 4.4 * k, cy - 1)], deg=deg, c=(cx, cy))
    return Part('fill', pth(poly(pts)), fill=col, shade=mix(col, '#6a5a8a', 0.4), off=(-0.8, -0.6),
                hl=hi_line('M%s L%s' % (fmt(pt((cx - 1.2, cy - 5), deg=deg, c=(cx, cy))), fmt(pt((cx - 1.6, cy), deg=deg, c=(cx, cy)))),
                           '#ffffff', 0.9, op=0.9))


def refractor_svg(frame):
    name = 'refractor_' + frame
    f = Fr(name, YPAL, shine=SHINE5)
    cx, cy = 64, 64
    bob = {'idle1': 0, 'idle2': -1.6, 'charge': 0, 'fire': 0, 'hit': 2}[frame]
    cy += bob
    tilt = {'idle1': 0, 'idle2': 0, 'charge': 0, 'fire': -4, 'hit': 12}[frame]
    # petals behind (the ones on the far side of the orbit)
    if frame == 'charge':
        orbit = [(90, cy - 11, 90), (95, cy, 90), (90, cy + 11, 90)]
    elif frame == 'fire':
        orbit = [(90, cy - 22, 60), (99, cy + 2, 100), (86, cy + 24, 130)]
    else:
        base = {'idle1': 30, 'idle2': 75, 'hit': 110}[frame]
        orbit = []
        for i in range(3):
            a = math.radians(base + i * 120)
            orbit.append((cx + 27 * math.cos(a), cy + 11 * math.sin(a) - 2, math.degrees(a) + 90))
    behind = [(i, o) for i, o in enumerate(orbit) if frame not in ('charge', 'fire') and o[1] < cy - 2]
    front = [(i, o) for i, o in enumerate(orbit) if (i, o) not in behind]
    for i, (x, y, a) in behind:
        f.add(petal(x, y, a, mix(PETALS[i], '#8a86a8', 0.3), 0.85))
    body = tf([(cx, cy - 30, 0), (cx + 12, cy - 18, 0), (cx + 13.4, cy + 12, 0), (cx, cy + 30, 0), (cx - 13.4, cy + 12, 0),
               (cx - 12, cy - 18, 0)], deg=tilt, c=(cx, cy))
    facets = ''
    P = lambda x, y: pt((x, y), deg=tilt, c=(cx, cy))
    facets += line('M%s L%s L%s L%s' % (fmt(P(cx, cy - 30)), fmt(P(cx + 3.4, cy - 18)), fmt(P(cx + 4, cy + 12)), fmt(P(cx, cy + 30))),
                   PRISM_SH, 1.0, op=0.9)
    facets += line('M%s L%s L%s' % (fmt(P(cx - 12, cy - 18)), fmt(P(cx + 3.4, cy - 18)), fmt(P(cx + 12, cy - 18))), PRISM_SH, 0.9, op=0.8)
    facets += line('M%s L%s L%s' % (fmt(P(cx - 13.4, cy + 12)), fmt(P(cx + 4, cy + 12)), fmt(P(cx + 13.4, cy + 12))), PRISM_SH, 0.9, op=0.8)
    # a spectral fringe down the right edge
    for i, col in enumerate(SPECTRUM):
        a = P(cx + 11.4 - i * 0.9, cy - 16 + i * 0.4)
        b = P(cx + 12.6 - i * 0.9, cy + 10 - i * 0.4)
        facets += line('M%s L%s' % (fmt(a), fmt(b)), col, 1.0, op=0.8)
    glow = {'idle1': 0.25, 'idle2': 0.25, 'charge': 0.7, 'fire': 1.0, 'hit': 0.1}[frame]
    g = f.ctx.radgrad([(0, '#ffffff', 0.9 * glow), (0.5, '#e8d8ff', 0.5 * glow), (1, '#e8d8ff', 0)])
    facets += '<ellipse cx="%.1f" cy="%.1f" rx="14" ry="16" fill="%s"/>' % (cx, cy, g)
    # the one calm eye in the core
    ex, ey = P(cx + 1, cy - 2)
    if frame == 'hit':
        facets += squeeze(ex, ey, 7, LEAD, w=1.6) + line('M%s L%s L%s L%s' % (fmt(P(cx - 6, cy - 26)), fmt(P(cx - 2, cy - 14)),
                                                                             fmt(P(cx - 7, cy - 6)), fmt(P(cx - 3, cy + 4))), LEAD, 1.1)
    else:
        r = {'idle1': 5.6, 'idle2': 5.6, 'charge': 5.2, 'fire': 6.2}[frame]
        # the lock and the fire glint: a star round the lens, behind the eye. It points nowhere, since the
        # Refractor aims at any angle and code draws the aim line and the beam from `lens`.
        if frame == 'charge':
            facets += glint(ex, ey, 10.4, TELL5)
        elif frame == 'fire':
            facets += glint(ex, ey, 15, TELL5) + star4(ex, ey, 9, '#ffffff')
        facets += ring_eye(ex, ey, r, VIOLET_RING, look=(1.4, 0) if frame != 'idle2' else (0.6, 0.4))
        if frame in ('idle1', 'idle2'):
            # calm: a heavy lid
            lid = ey - r * 0.62
            facets += '<path d="M%.1f %.1f L%.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f Z" fill="%s"/>' % (
                ex - r - 1.4, ey - r - 1.4, ex + r + 1.4, ey - r - 1.4, ex + r + 1.4, lid, ex, lid + 1.6, ex - r - 1.4, lid, PRISM)
            facets += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (ex - r - 1, lid, ex, lid + 1.8, ex + r + 1, lid), LEAD, 1.3)
        elif frame == 'charge':
            facets += line('M%.1f %.1f L%.1f %.1f M%.1f %.1f L%.1f %.1f' % (ex - r - 2, ey - r - 1, ex + r, ey - r + 1.4,
                                                                           ex - r - 2, ey + r + 1, ex + r, ey + r - 1.4), LEAD, 1.4)
    f.add(Part('fill', pth(poly(body)), fill=PRISM, shade=PRISM_SH, off=(-2.4, -2), over=facets,
               hl=hi_line('M%s L%s' % (fmt(P(cx - 7, cy - 20)), fmt(P(cx - 8.6, cy + 6))), '#ffffff', 2.0, op=0.9)))
    for i, (x, y, a) in front:
        f.add(petal(x, y, a, PETALS[i]))
    eyes = [(ex, ey)]
    if frame == 'charge':
        f.mark(eyes, 5.2, hit=(48, 32, 32, 64), lens=(ex, ey), beam=(ex, ey))
    elif frame == 'fire':
        f.mark(eyes, 6.2, hit=(48, 32, 32, 64), lens=(ex, ey), beam=(ex, ey))
    elif frame == 'hit':
        f.over = motion('M88 40 L94 34 M36 44 L30 40 M92 88 L98 92', 1.2) + sweat(84, 36, 0.4, 25)
        f.mark(eyes, 4.6, hit=(46, 34, 36, 64))
    else:
        f.mark(eyes, 5.6, hit=(48, 32, 32, 64), lens=(ex, ey))
    return f.svg()


# ---------------------------------------------------------------- the Paneguard

def lancet(x0, x1, y_top, y_bot, point=1.0):
    """A pointed-arch window shape from y_top (its point) to a flat foot at y_bot."""
    cx = (x0 + x1) / 2
    w = x1 - x0
    return [(cx, y_top, 0), (x1 - w * 0.08, y_top + w * 0.5 * point), (x1, y_top + w * 0.95 * point), (x1, y_bot, 0),
            (x0, y_bot, 0), (x0, y_top + w * 0.95 * point), (x0 + w * 0.08, y_top + w * 0.5 * point)]


def pane_parts(f, sx=1.0, step=0.0, sword=(0.0, 0.0), cut=False, crack=False, mood='open', lean=0.0, glint_run=False, blade_len=46.0):
    """The glass knight face-on (sx < 1 squeezes it toward edge-on round x 64).
    Returns the eye points."""
    c = (64, 122)

    def S(pts):
        return tf(pts, sx=sx, c=c, deg=lean)
    parts = []
    # the rose-window halo behind the head
    hc = pt((64, 44), sx=sx, c=c, deg=lean)
    halo = S(ring(64, 44, 14, 14, 18))
    spokes = ''.join(line('M%s L%s' % (fmt(hc), fmt(pt((64 + 13 * math.cos(a), 44 + 13 * math.sin(a)), sx=sx, c=c, deg=lean))), LEAD, 1.1)
                     for a in [i * math.pi / 4 for i in range(8)])
    parts.append(Part('fill', pth(smooth(halo)), fill=GL, shade=GL_SH, off=(-1.2, -1.2),
                      over=stained(f, smooth(halo), (48, 28, 80, 60), cell=(40, 40), seed=5, jitter=0) + spokes
                      + '<path d="%s" fill="none" stroke="%s" stroke-width="1.4"/>' % (smooth(S(ring(64, 44, 6, 6, 12))), LEAD)))
    # legs (lancets), the back one first
    for i, (x, d) in enumerate(((56, -step), (72, step))):
        leg = S(lancet(x - 5 + d, x + 5 + d, 100, 122, 0.3))
        parts.append(Part('fill', pth(smooth(leg)), fill=GL, shade=GL_SH, off=(-1, -1),
                          over=stained(f, smooth(leg), (x - 8 + d, 98, x + 8 + d, 122), cell=(8, 8), seed=7 + i, diamond=True, jitter=0, lead_w=1.1)))
    # the tabard: a tall lancet of panes with a lead cross
    body = S(lancet(47, 81, 60, 106, 0.55))
    bd = smooth(body)
    over = stained(f, bd, (44, 58, 84, 108), cell=(10.6, 10.6), seed=11, diamond=True, jitter=0, lead_w=1.1,
                   streak='M%s L%s' % (fmt(pt((52, 76), sx=sx, c=c, deg=lean)), fmt(pt((54, 100), sx=sx, c=c, deg=lean))))
    over += line('M%s L%s M%s L%s' % (fmt(pt((64, 66), sx=sx, c=c, deg=lean)), fmt(pt((64, 106), sx=sx, c=c, deg=lean)),
                                      fmt(pt((49, 80), sx=sx, c=c, deg=lean)), fmt(pt((79, 80), sx=sx, c=c, deg=lean))), LEAD, 2.4)
    if crack:
        over += line('M%s L%s L%s L%s' % (fmt(pt((70, 64), sx=sx, c=c)), fmt(pt((64, 76), sx=sx, c=c)), fmt(pt((72, 86), sx=sx, c=c)),
                                          fmt(pt((66, 98), sx=sx, c=c))), '#ffffff', 1.4)
    if glint_run:
        over += line('M%s L%s' % (fmt(pt((64, 62), sx=sx, c=c, deg=lean)), fmt(pt((64, 104), sx=sx, c=c, deg=lean))), '#ffffff', 1.6)
    parts.append(Part('fill', pth(bd), fill=GL, shade=GL_SH, off=(-2, -2), over=over))
    # the helm: a small lancet with a visor band and two eyes
    helm = S(lancet(55.4, 72.6, 36, 66, 0.7))
    hd = smooth(helm)
    e1, e2 = pt((60.4, 54.6), sx=sx, c=c, deg=lean), pt((68.2, 54.4), sx=sx, c=c, deg=lean)
    hov = stained(f, hd, (54, 34, 74, 68), cell=(8, 8), seed=13, diamond=True, jitter=0, lead_w=1.1)
    band = S([(55.6, 51, 0), (72.4, 51, 0), (72.4, 58.4, 0), (55.6, 58.4, 0)])
    hov += '<path d="%s" fill="%s"/>' % (poly(band), '#2a2438')
    hov += ring_eye(e1[0], e1[1], 2.9 * max(sx, 0.5), RING_N, look=(0.5, 0), mood=mood) + ring_eye(e2[0], e2[1], 2.6 * max(sx, 0.5), RING_N, look=(0.5, 0), mood=mood)
    parts.append(Part('fill', pth(hd), fill=GL, shade=GL_SH, off=(-1.4, -1.4), over=hov))
    # the glass sword in the front hand
    ang, reach = sword
    hand = pt((84 + reach, 86), sx=sx, c=c, deg=lean)
    L = blade_len
    bl = tf([(0, -4), (L - 6, -2.4), (L, 0, 0), (L - 6, 2.4), (0, 4)], dx=hand[0], dy=hand[1], deg=ang, c=(0, 0))
    blade = Part('fill', pth(smooth(bl)), fill='#d8e0f0', shade=GL_SH, off=(-0.6, -1),
                 over=line('M%s L%s' % (fmt(pt((hand[0] + 4, hand[1]), deg=ang, c=hand)), fmt(pt((hand[0] + L - 8, hand[1]), deg=ang, c=hand))),
                           '#ffffff', 1.2, op=0.9))
    guard = tf([(hand[0] - 1.4, hand[1] - 7), (hand[0] + 1.4, hand[1] - 7), (hand[0] + 1.4, hand[1] + 7), (hand[0] - 1.4, hand[1] + 7)],
               deg=ang, c=hand)
    parts.append(blade)
    parts.append(Part('fill', pth(poly(guard)), fill='#5a5470', shade='#3a3450', off=(0, -0.6)))
    parts.append(Part('fill', pth(ell_path(hand[0], hand[1], 3.4, 3.2)), fill=GL, shade=GL_SH, off=(-0.6, -0.6)))
    f.add(parts)
    return [e1, e2]


def pane_svg(frame):
    name = 'pane_' + frame
    f = Fr(name, GPAL, shine=SHINE5)
    f.under = ground_shadow(64, 22)
    if frame in ('face1', 'face2'):
        a = 1 if frame == 'face1' else -1
        eyes = pane_parts(f, step=1.6 * a, sword=(-70, 0))
        f.mark(eyes, 2.9, hit=(38, 30, 52, 92), halo=(64, 44))
    elif frame == 'turn':
        # the tell: turning edge-on, a glint running along the lead, the halo flaring
        eyes = pane_parts(f, sx=0.5, sword=(-80, -4), glint_run=True)
        f.over = glint(64, 40, 6.4, TELL5) + glint(64, 84, 4.4, TELL5)
        f.mark(eyes, 2.6, hit=(48, 30, 32, 92), glint=(64, 84), halo=(64, 44))
    elif frame == 'edge':
        # edge-on: a thin line of lead, a glint running up it (full damage here)
        f.under = ground_shadow(64, 8)
        strip = [(64, 28, 0), (66.4, 36), (67.4, 50), (67, 60), (68.4, 66), (68.4, 104), (67.4, 122, 0), (60.6, 122, 0),
                 (59.6, 104), (59.6, 66), (61, 60), (60.6, 50), (61.6, 36)]
        f.add(Part('limb', pth('M66 56 L69.4 104'), width=2.4, fill='#d8e0f0'))
        f.add(Part('fill', pth(smooth(strip)), fill='#4a4460', shade='#2a2438', off=(-1, 0),
                   over=line('M64 34 L64 118', GL, 1.6, op=0.9) + line('M62.4 60 L62.4 70', '#ffffff', 1.6)
                   + dot(64, 54, 1.6, '#fff2f8') + dot(64, 54, 0.8, '#ffffff')))
        f.over = glint(64, 64, 4.2, TELL5)
        f.mark([(64, 54)], 2.6, hit=(56, 26, 16, 96), glint=(64, 64))
    elif frame == 'cut':
        # the Glass Cut: a swing, not a thrust. The sword has come down through an arc from over the head
        # (the glass smear of its path) and ends low in front.
        smear = [(78, 30, 0), (100, 36), (114, 54), (119, 76), (114, 100, 0), (111, 78), (106, 58), (94, 42)]
        f.under += ('<path d="%s" fill="%s" opacity="0.5" stroke="%s" stroke-width="1.2" stroke-opacity="0.5"/>' % (
            smooth(smear), '#d0d8ea', LEAD) + line(smooth([(80, 31), (101, 37.6), (115, 56), (119.4, 78)], closed=False),
                                                   '#ffffff', 1.4, op=0.85)
            + line(smooth([(86, 36), (104, 46), (112, 64), (113, 88)], closed=False), '#ffffff', 0.8, op=0.6))
        eyes = pane_parts(f, sword=(38, 3), lean=4, step=2, blade_len=32)
        hand = pt((87, 86), deg=4, c=(64, 122))
        tip = (hand[0] + 32 * math.cos(math.radians(38)), hand[1] + 32 * math.sin(math.radians(38)))
        f.over = motion('M%.1f %.1f l5 3 M%.1f %.1f l3 5' % (tip[0] - 2, tip[1] + 4, tip[0] - 7, tip[1] + 6), 1.1)
        f.mark(eyes, 2.9, hit=(38, 28, 80, 94), blade=tip, arc=(114, 62))
    elif frame == 'hit':
        eyes = pane_parts(f, sword=(-100, -3), crack=True, mood='squeeze', lean=-4)
        f.over = (sparkle(92, 50, 3, LEAD, '#ffffff') + sparkle(36, 60, 2.4, LEAD, '#ffffff')
                  + motion('M96 64 L104 62 M30 76 L22 74', 1.2))
        f.mark(eyes, 2.9, hit=(38, 30, 52, 92))
    else:   # shatter: the window falls to pieces
        pieces = [(40, 112, 20, 5), (54, 115, -10, 5.4), (76, 114, 30, 5), (88, 116, -30, 4), (64, 104, 60, 5), (46, 96, -40, 4),
                  (82, 98, 15, 4.6), (58, 86, 70, 4), (72, 80, -20, 3.6), (36, 116, 50, 3.2), (96, 112, 5, 3.4)]
        for i, (x, y, a, r) in enumerate(pieces):
            q = tf([(x - r, y + r * 0.6), (x, y - r), (x + r * 0.8, y + r * 0.7)], deg=a, c=(x, y))
            f.add(Part('fill', pth(poly(q)), fill=GLASS_N[i % 6], shade=GL_SH, off=(-0.6, -0.6)))
        helm = tf(lancet(55.4, 72.6, 90, 114, 0.7), deg=-70, c=(64, 108))
        f.add(Part('fill', pth(smooth(helm)), fill=GL, shade=GL_SH, off=(-1, -1),
                   over=ring_eye(62, 107, 2.6, RING_N, mood='squeeze')))
        f.over = specks([(50, 70, 1.2), (78, 64, 1.0), (60, 56, 0.9), (70, 90, 0.9)], '#ffffff')
        f.mark([(62, 107)], 2.6, hit=(34, 76, 64, 46))
    return f.svg()


# ================================================================ World 6: the Hushdeep

INK, INK_SH, INK_LINE = '#2a2838', '#1c1a28', '#0a0810'
SILVER = '#c8c8f0'         # the W6 rim
PALE = '#d8d4f0'           # W6 eyes
HVIOLET = '#6a5a9a'
TELL6 = '#e0e0ff'          # World 6's tell accent: silver ripple
RIM6 = 8.0                 # the sticker rim's stroke: its visible band is 4 units (2 px)
HPAL = dict(line=INK_LINE, rim=SILVER, base=INK, shade=INK_SH)


def pale_eye(cx, cy, r, look=(0.8, 0.2), pupil=1.0, mood='open'):
    """W6's round pale eye with a small dark pupil and a shine."""
    if mood == 'shut':
        return line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (cx - r, cy, cx, cy + r * 0.7, cx + r, cy), PALE, 1.8)
    if mood == 'x':
        return line('M%.1f %.1f L%.1f %.1f M%.1f %.1f L%.1f %.1f' % (cx - r * 0.7, cy - r * 0.7, cx + r * 0.7, cy + r * 0.7,
                                                                   cx - r * 0.7, cy + r * 0.7, cx + r * 0.7, cy - r * 0.7), PALE, 1.6)
    s = dot(cx, cy, r + 0.8, INK_LINE) + dot(cx, cy, r, PALE)
    if pupil > 0:
        s += dot(cx + look[0], cy + look[1], r * 0.34 * pupil, INK_LINE)
    s += dot(cx - r * 0.36, cy - r * 0.38, r * 0.28, '#ffffff')
    return s


# ---------------------------------------------------------------- the Hushling

def hushling_body(cx, bottom, w, h, lean=0.0, wisp=0.0):
    """The blob of living dark, round at the bottom, dripping upward into
    three smoky wisps. Points, bottom-centre (cx, bottom)."""
    b = bottom
    pts = [(cx, b), (cx + w * 0.42, b - 0.6), (cx + w * 0.52, b - h * 0.28), (cx + w * 0.44, b - h * 0.6),
           (cx + w * 0.26, b - h * 0.8), (cx + w * 0.32 + wisp, b - h * 1.0, 0), (cx + w * 0.1, b - h * 0.84),
           (cx + wisp * 0.6, b - h * 1.14, 0), (cx - w * 0.14, b - h * 0.86), (cx - w * 0.34 + wisp * 0.4, b - h * 1.02, 0),
           (cx - w * 0.3, b - h * 0.78), (cx - w * 0.46, b - h * 0.58), (cx - w * 0.52, b - h * 0.28), (cx - w * 0.42, b - 0.6)]
    return tf(pts, deg=lean, c=(cx, b))


def hushling_svg(frame):
    name = 'hushling_' + frame
    f = Fr(name, HPAL, rim_w=RIM6)
    f.under = ground_shadow(64, 15)
    B = 120.0      # the ink's bottom: the silver rim reaches the floor line below it
    if frame in ('idle1', 'idle2', 'crouch', 'blink'):
        w, h, wisp = {'idle1': (34, 30, 1.6), 'idle2': (35.6, 28.6, -1.6), 'crouch': (26, 42, 0.6), 'blink': (38, 25, 2.6)}[frame]
        body = hushling_body(64, B, w, h, wisp=wisp)
        ey = B - h * 0.5
        r = {'crouch': 6.4, 'blink': 6.0}.get(frame, 6.0)
        e1, e2 = (57.4, ey), (70.4, ey - 0.4)
        if frame == 'crouch':
            fc = pale_eye(e1[0], e1[1], r, look=(1.2, 0), pupil=0.45) + pale_eye(e2[0], e2[1], r * 0.94, look=(1.2, 0), pupil=0.45)
            fc += line('M%.1f %.1f q2.6 1.6 5.2 0' % (61.4, ey + 9), '#8a80c0', 1.3)
        elif frame == 'blink':
            fc = pale_eye(e1[0], e1[1], r, mood='shut') + pale_eye(e2[0], e2[1], r * 0.94, mood='shut')
            fc += line('M%.1f %.1f q2.6 2.2 5.2 0' % (61.4, ey + 7), '#8a80c0', 1.3)
        else:
            fc = pale_eye(e1[0], e1[1], r) + pale_eye(e2[0], e2[1], r * 0.94)
            fc += line('M%.1f %.1f q2.6 1.8 5.2 0' % (61.4, ey + 8.6), '#8a80c0', 1.3)
        fc += '<path d="%s" fill="none" stroke="%s" stroke-width="1.6" opacity="0.7"/>' % (
            smooth([(64 - w * 0.36, B - 4), (64, B - 1.4), (64 + w * 0.36, B - 4)], closed=False), HVIOLET)
        f.add(Part('fill', pth(smooth(body)), fill=INK, shade=INK_SH, off=(-2, -2), over=fc,
                   hl=hi_line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (64 - w * 0.36, B - h * 0.3, 64 - w * 0.34, B - h * 0.6, 64 - w * 0.18, B - h * 0.78),
                              HVIOLET, 1.8, op=0.9)))
        f.mark([e1, e2], r, hit=(64 - w * 0.55, B - h * 1.1, w * 1.1, h * 1.1 + 2))
    elif frame == 'lunge':
        body = hushling_body(66, 108, 30, 34, lean=58, wisp=-2)
        e1, e2 = pt((62, 91), deg=58, c=(66, 108)), pt((74, 90.4), deg=58, c=(66, 108))
        e1, e2 = (e1[0], e1[1]), (e2[0], e2[1])
        fc = pale_eye(e1[0], e1[1], 5.8, look=(1.4, 0.4), pupil=0.8) + pale_eye(e2[0], e2[1], 5.4, look=(1.4, 0.4), pupil=0.8)
        mp = pt((69, 100.6), deg=58, c=(66, 108))
        fc += '<ellipse cx="%.1f" cy="%.1f" rx="3.4" ry="2.4" fill="%s" transform="rotate(58 %.1f %.1f)"/>' % (mp[0], mp[1], '#0a0812', mp[0], mp[1])
        fc += '<ellipse cx="%.1f" cy="%.1f" rx="2" ry="1.2" fill="%s" transform="rotate(58 %.1f %.1f)"/>' % (mp[0], mp[1] + 0.6, HVIOLET, mp[0], mp[1])
        f.add(Part('fill', pth(smooth(body)), fill=INK, shade=INK_SH, off=(-2, -2), over=fc))
        f.over = motion('M28 98 L18 104 M32 110 L22 116', 1.2)
        f.mark([e1, e2], 5.8, hit=(40, 78, 62, 42), mouth=mp)
    else:   # pop: burst into wisps and drops of dark
        f.add(Part('fill', pth(smooth([(46, 120.2, 0), (54, 116), (64, 115), (74, 116), (82, 120.2, 0)])), fill=INK, shade=INK_SH,
                   off=(-1, -1)))
        for x, y, r, a in ((42, 98, 3.4, -30), (86, 96, 3.2, 30), (56, 86, 2.8, -10), (74, 84, 3.2, 15), (34, 110, 2.4, -50),
                           (94, 108, 2.6, 50)):
            q = tf([(x, y - r * 1.6, 0), (x + r, y), (x, y + r), (x - r, y)], deg=a, c=(x, y))
            f.add(Part('fill', pth(smooth(q)), fill=INK, shade=INK_SH, off=(-0.6, -0.6), rim=False, over=dot(x - r * 0.3, y - r * 0.2, r * 0.3, SILVER, 0.8)))
        f.over = pale_eye(58, 104, 3.2, mood='x') + pale_eye(70, 104, 3.0, mood='x')
        f.mark([(58, 104), (70, 104)], 5.5, hit=(40, 90, 48, 32))
    return f.svg()


# ---------------------------------------------------------------- the Stillmaw

PORC6, PORC6_SH, PORC6_HI = '#a8a6be', '#747290', '#e6e4f4'


def maw_svg(frame):
    name = 'maw_' + frame
    f = Fr(name, dict(line=INK_LINE, rim=SILVER, base=PORC6, shade=PORC6_SH), rim_w=RIM6)
    cx, cy = 64, 62
    # the tells change its outline too: straining, the mask tips back (chin thrust forward), its jaw stretches
    # long and wide against the stitches and the ties flare; torn open, the jaw hangs lower still
    tilt = {'idle': 0, 'strain': -12, 'open': -16, 'choke': 6, 'hit': -12}[frame]
    sw = {'strain': 1.06, 'open': 1.04, 'choke': 1.06}.get(frame, 1.0)
    jx, jy = {'strain': (1.2, 1.3), 'open': (1.26, 1.5)}.get(frame, (1.0, 1.0))
    flare = {'strain': 1.0, 'open': 1.3}.get(frame, 0.0)
    c = (cx, cy)

    def J(x, y):
        """The jaw's stretch (below the eyes), then the tilt."""
        t = max(0.0, min(1.0, (y - cy) / 30.0))
        if y > cy:
            x = cx + (x - cx) * (1.0 + (jx - 1.0) * t)
            y = cy + (y - cy) * jy
        return pt((x, y), deg=tilt, c=c)
    # the mask's ties trailing behind, wavy black ribbons (flared up and out in the tells)
    for dy, ph, up in ((-9, 0.0, -1), (5, 1.3, 1)):
        lift = up * flare * 9
        rb = [(42, cy + dy), (33.6, cy + dy - 2.6 + ph + lift * 0.4), (26, cy + dy + 1 - ph + lift * 0.9),
              (18 + flare * 4, cy + dy - 1.6 + ph * 0.6 + lift * 1.6)]
        f.add(Part('limb', pth(smooth(tf(rb, deg=tilt, c=c), closed=False)), width=3.2 + flare * 0.6, fill=INK,
                   over=line(smooth(tf([(40, cy + dy - 0.8), (33, cy + dy - 3 + ph)], deg=tilt, c=c), closed=False), HVIOLET, 0.8, op=0.8)))
    face = [(cx, cy - 30), (cx + 16, cy - 27), (cx + 24, cy - 14), (cx + 25, cy + 2), (cx + 20, cy + 18), (cx + 10, cy + 28),
            (cx, cy + 31), (cx - 10, cy + 28), (cx - 20, cy + 18), (cx - 25, cy + 2), (cx - 24, cy - 14), (cx - 16, cy - 27)]
    face = [J(cx + (x - cx) * sw, y) for x, y in face]
    P = lambda x, y: pt((x, y), deg=tilt, c=c)
    fc = ''
    # brow ridge and cheek shading
    fc += line('M%s Q%s %s' % (fmt(P(cx - 18, cy - 12)), fmt(P(cx, cy - 18)), fmt(P(cx + 18, cy - 12))), PORC6_SH, 1.2, op=0.8)
    for s in (-1, 1):
        fc += '<ellipse cx="%.1f" cy="%.1f" rx="5" ry="3" fill="%s" opacity="0.5" transform="rotate(%.1f %.1f %.1f)"/>' % (
            P(cx + s * 15, cy + 8)[0], P(cx + s * 15, cy + 8)[1], PORC6_SH, tilt, P(cx + s * 15, cy + 8)[0], P(cx + s * 15, cy + 8)[1])
    # the eye holes with the pale eyes inside
    eyes = []
    for s, w in ((-1, 1.0), (1, 0.94)):
        ex, ey = P(cx + s * 9.6, cy - 4)
        hole = tf([(ex - 7.4 * w, ey), (ex - 2, ey - 5.6 * w), (ex + 5, ey - 4.8 * w), (ex + 7.4 * w, ey + 0.6), (ex + 2, ey + 4.4 * w),
                   (ex - 4, ey + 4.2 * w)], deg=tilt, c=(ex, ey))
        fc += '<path d="%s" fill="%s"/>' % (smooth(hole), '#0a0812')
        if frame in ('choke', 'hit'):
            fc += squeeze(ex, ey, 6, PALE, flip=s > 0, w=1.5)
        else:
            r = 3.6 if frame != 'strain' else 4.2
            fc += dot(ex + 1, ey, r, PALE) + dot(ex + 1.6, ey + 0.2, r * 0.36, INK_LINE) + dot(ex - 0.2, ey - 1.2, r * 0.3, '#ffffff')
        eyes.append((ex + 1, ey))
    # the mouth: stitched shut, straining, torn open, spitting
    m0, m1 = J(cx - 11 * sw, cy + 16), J(cx + 11 * sw, cy + 16)
    mc = J(cx, cy + 16)
    if frame == 'idle':
        fc += line('M%s Q%s %s' % (fmt(m0), fmt(J(cx, cy + 17.4)), fmt(m1)), INK_LINE, 1.6)
        for i in range(5):
            x = cx - 8 + i * 4
            fc += line('M%s L%s' % (fmt(J(x - 1.2, cy + 13.4)), fmt(J(x + 1.2, cy + 19.4))), INK_LINE, 1.2)
            fc += line('M%s L%s' % (fmt(J(x - 1.2, cy + 13.4)), fmt(J(x + 1.2, cy + 19.4))), SILVER, 0.5)
    elif frame == 'strain':
        fc += '<path d="%s" fill="%s"/>' % (smooth([m0, J(cx, cy + 12.6), m1, J(cx, cy + 20)]), PORC6_SH)
        fc += line('M%s Q%s %s' % (fmt(m0), fmt(J(cx, cy + 17.8)), fmt(m1)), INK_LINE, 1.6)
        for i in range(5):
            x = cx - 8 + i * 4
            if i in (1, 3):
                fc += line('M%s l-1.6 -4 M%s l1.8 4' % (fmt(J(x - 1, cy + 12.6)), fmt(J(x + 1, cy + 20.6))), INK_LINE, 1.0)
            else:
                fc += line('M%s L%s' % (fmt(J(x - 1.2, cy + 12.8)), fmt(J(x + 1.2, cy + 20))), INK_LINE, 1.2)
    elif frame == 'open':
        void = [m0, J(cx - 8, cy + 9), J(cx, cy + 8), J(cx + 8, cy + 9), m1, J(cx + 8, cy + 27), J(cx, cy + 29), J(cx - 8, cy + 27)]
        g = f.ctx.radgrad([(0, HVIOLET, 0.7), (0.5, '#2a2040', 0.9), (1, '#06040a', 1)])
        fc += '<path d="%s" fill="%s" stroke="%s" stroke-width="1.4"/>' % (smooth(void), g, INK_LINE)
        for i, x in enumerate((cx - 8, cx - 3, cx + 3, cx + 8)):
            fc += line('M%s l%.1f -3' % (fmt(J(x, cy + 9 + abs(x - cx) * 0.1)), -1 + i * 0.6), INK_LINE, 1.0)
    elif frame == 'choke':
        void = [m0, J(cx - 6, cy + 12), J(cx + 6, cy + 12), m1, J(cx + 6, cy + 22), J(cx - 6, cy + 22)]
        fc += '<path d="%s" fill="%s" stroke="%s" stroke-width="1.2"/>' % (smooth(void), '#0a0812', INK_LINE)
    else:
        fc += line('M%s Q%s %s' % (fmt(m0), fmt(J(cx, cy + 18.6)), fmt(m1)), INK_LINE, 1.6)
        fc += line('M%s L%s L%s L%s' % (fmt(J(cx + 4, cy - 30)), fmt(J(cx + 1, cy - 20)), fmt(J(cx + 7, cy - 12)), fmt(J(cx + 3, cy - 4))), INK_LINE, 1.3)
    if frame != 'hit':
        fc += line('M%s L%s L%s' % (fmt(P(cx - 6, cy - 29)), fmt(P(cx - 4, cy - 23)), fmt(P(cx - 7, cy - 19))), INK_LINE, 1.0)
    f.add(Part('fill', pth(smooth(face)), fill=PORC6, shade=PORC6_SH, off=(-3, -3), over=fc,
               hl=spec(*P(cx - 13, cy - 18), 5, 2.4, rot=-35 + tilt, op=0.7)))
    if frame == 'hit':
        chip = tf([(cx + 20, cy - 16), (cx + 28, cy - 22), (cx + 26, cy - 12)], deg=0, c=c)
        f.add(Part('fill', pth(poly(chip)), fill=PORC6, shade=PORC6_SH, off=(-0.6, -0.6)))
        f.over = motion('M96 44 L104 40 M30 76 L22 80', 1.2)
    elif frame == 'strain':
        f.over = (glint(mc[0], mc[1] + 2, 5, TELL6) + line('M%.1f %.1f l-4 -5 M%.1f %.1f l5 -4' % (mc[0] - 6, mc[1] - 4, mc[0] + 6, mc[1] - 4),
                                                           SILVER, 0.9))
    elif frame == 'choke':
        f.over = flame(f.ctx, mc[0] + 22, mc[1] + 6, 8, 12, lean=6, line_w=1.1) + motion('M%.1f %.1f l6 0 M%.1f %.1f l6 3' % (
            mc[0] + 8, mc[1] + 2, mc[0] + 8, mc[1] + 6), 1.0)
    hit = {'strain': (34, 26, 62, 80), 'open': (34, 26, 64, 86)}.get(frame, (36, 30, 56, 64))
    f.mark(eyes, 5.6, hit=hit, mouth=mc)
    return f.svg()


# ---------------------------------------------------------------- the Lurecoil

BONE6, BONE6_SH, BONE6_HI = '#dcd8e8', '#a8a2c0', '#ffffff'
WAX6, WAX6_SH = '#f0e6cc', '#cdbf9c'


def coil_head(f, frame, jaw=0.0, deg=0.0, lid=0.0, mood='open', droop=0.0, candle=True):
    """The eel's head facing right: an ink collar, the pale bone face, the jaws
    and the stolen candle it bites (candle=False: knocked loose, the jaws bare).
    Returns (eyes, lure point or None, bite point)."""
    cx, cy = 64, 64
    c = (52, 66)
    P = lambda x, y: pt((x, y), deg=deg, c=c)
    L = lambda pts: tf(pts, deg=deg, c=c)
    # the dorsal frill
    fr = L([(40, 50, 0), (46, 38), (54, 36), (62, 40, 0), (58, 44), (50, 48, 0)])
    f.add(Part('fill', pth(smooth(fr)), fill=HVIOLET, shade=INK_SH, off=(-0.8, -0.8),
               over=line('M%s L%s M%s L%s' % (fmt(P(46, 46)), fmt(P(48, 39)), fmt(P(52, 46)), fmt(P(55, 38))), SILVER, 0.8, op=0.8)))
    # the lower jaw, opened by jaw about its hinge
    hinge = (52, 72)
    lj = [(50, 70), (70, 74), (88, 76), (96, 78), (94, 83), (80, 84), (62, 82), (50, 78)]
    lj = [rot(p, jaw * 26, hinge) for p in lj]
    teeth = ''
    for x in (66, 74, 82, 90):
        a = rot((x, 74.6), jaw * 26, hinge)
        b = rot((x + 1.6, 70.8), jaw * 26, hinge)
        cc = rot((x + 3.2, 74.8), jaw * 26, hinge)
        teeth += '<path d="M%s L%s L%s Z" fill="#fffaf0" stroke="%s" stroke-width="0.5"/>' % (fmt(P(*a)), fmt(P(*b)), fmt(P(*cc)), INK_LINE)
    under = ''
    if jaw > 0.3:
        under = '<path d="%s" fill="%s"/>' % (smooth(L([(54, 70), (94, 72), rot((94, 80), jaw * 26, hinge), rot((56, 78), jaw * 26, hinge)])), '#0a0812')
    f.add(Part('fill', pth(smooth(L(lj))), fill=BONE6_SH, shade=mix(BONE6_SH, INK, 0.3), off=(-0.8, -1), over=teeth, under=under))
    # the collar ring where the body joins
    col = L([(30, 50), (40, 46), (44, 60), (42, 80), (32, 84), (26, 68)])
    f.add(Part('fill', pth(smooth(col)), fill=INK, shade=INK_SH, off=(-1.4, -1.4),
               over=line('M%s Q%s %s' % (fmt(P(34, 52)), fmt(P(30, 66)), fmt(P(34, 80))), HVIOLET, 1.4, op=0.8)))
    # the cranium and upper jaw: a long pale bone face
    head = L([(38, 60), (42, 48), (54, 42), (70, 44), (86, 52), (98, 62), (100, 70, 0), (90, 72), (72, 72), (56, 74), (42, 74)])
    fc = ''
    eyes = []
    for (ex, ey), w in (((60, 56), 1.0), ((72.4, 55.2), 0.86)):
        q = P(ex, ey)
        fc += '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="#0a0812" transform="rotate(%.1f %.1f %.1f)"/>' % (
            q[0], q[1], 6.2 * w, 5.6 * w, deg, q[0], q[1])
        if mood == 'squeeze':
            fc += squeeze(q[0], q[1], 6.2 * w, PALE, flip=w < 1, w=1.4)
        else:
            fc += pale_eye(q[0] + 0.8, q[1], 3.6 * w, look=(1.0, 0.3))
            if lid > 0:
                fc += '<path d="M%.1f %.1f L%.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f Z" fill="%s"/>' % (
                    q[0] - 6.4 * w, q[1] - 6 * w, q[0] + 6.4 * w, q[1] - 6 * w, q[0] + 6.4 * w, q[1] - 6 * w + 11 * w * lid,
                    q[0], q[1] - 4.6 * w + 11 * w * lid, q[0] - 6.4 * w, q[1] - 6 * w + 11 * w * lid, BONE6)
                fc += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (q[0] - 6 * w, q[1] - 6 * w + 11 * w * lid, q[0], q[1] - 4.2 * w + 11 * w * lid,
                                                              q[0] + 6 * w, q[1] - 6 * w + 11 * w * lid), INK_LINE, 1.1)
        eyes.append((q[0] + 0.8, q[1]))
    for x in (74, 80, 86, 92):
        fc += '<path d="M%s L%s L%s Z" fill="#fffaf0" stroke="%s" stroke-width="0.5"/>' % (fmt(P(x, 71.6)), fmt(P(x + 1.6, 75.4)),
                                                                                       fmt(P(x + 3.2, 71.6)), INK_LINE)
    fc += '<ellipse cx="%.1f" cy="%.1f" rx="1.6" ry="1.1" fill="%s"/>' % (P(95, 63)[0], P(95, 63)[1], INK_LINE)
    fc += line('M%s Q%s %s' % (fmt(P(46, 50)), fmt(P(50, 58)), fmt(P(46, 68))), BONE6_SH, 1.0, op=0.9)
    f.add(Part('fill', pth(smooth(head)), fill=BONE6, shade=BONE6_SH, off=(-2, -2.4), over=fc,
               hl=hi_line('M%s Q%s %s' % (fmt(P(48, 48)), fmt(P(62, 44)), fmt(P(78, 47))), '#ffffff', 1.8, op=0.9)))
    if not candle:
        # knocked loose: only a smear of wax left on a front tooth
        wx, wy = P(93.4, 72.4)
        f.over += '<ellipse cx="%.1f" cy="%.1f" rx="1.6" ry="1.1" fill="%s" stroke="%s" stroke-width="0.5"/>' % (wx, wy, WAX6_SH, INK_LINE)
        return eyes, None, P(98, 74)
    # the stolen candle in its front teeth, its flame the lure
    base = P(96, 70) if jaw < 0.3 else P(97, 68)
    ang = deg - 58 + droop
    cand = tf([(base[0] - 2.4, base[1]), (base[0] - 2.4, base[1] - 11), (base[0] + 2.4, base[1] - 11), (base[0] + 2.4, base[1])], deg=ang + 90,
              c=base)
    f.add(Part('fill', pth(poly(cand)), fill=WAX6, shade=WAX6_SH, off=(-0.6, 0),
               over=line('M%s L%s' % (fmt(pt((base[0] - 1, base[1] - 2), deg=ang + 90, c=base)), fmt(pt((base[0] - 1, base[1] - 9), deg=ang + 90, c=base))),
                         '#ffffff', 0.8, op=0.8)))
    tip = pt((base[0], base[1] - 12), deg=ang + 90, c=base)
    k = 1.0 - droop / 90.0
    f.over += flame(f.ctx, tip[0], tip[1] + 1, 6 * k, 10 * k, lean=4, line_w=1.0)
    lure = (tip[0] + 1, tip[1] - 4 * k)
    return eyes, lure, P(98, 74)


def coil_svg(frame):
    name = 'coil_' + frame
    f = Fr(name, HPAL, rim_w=RIM6)
    if frame == 'seg':
        ringd = ell_path(64, 64, 22, 22)
        over = ('<circle cx="64" cy="64" r="14" fill="none" stroke="%s" stroke-width="3" opacity="0.6"/>' % INK_SH
                + '<path d="M50 50 Q64 42 78 50" fill="none" stroke="%s" stroke-width="1.6" opacity="0.8"/>' % HVIOLET
                + line('M46 72 Q64 82 82 72', HVIOLET, 1.2, op=0.6))
        fin = [(58, 43, 0), (62, 34), (68, 35), (70, 43, 0)]
        f.add(Part('fill', pth(smooth(fin)), fill=HVIOLET, shade=INK_SH, off=(-0.6, -0.6)))
        f.add(Part('fill', pth(ringd), fill=INK, shade=INK_SH, off=(-3, -3), over=over,
                   hl=hi_line('M48 56 Q52 46 62 44', SILVER, 1.6, op=0.7)))
        f.mark(hit=(42, 42, 44, 44), top=(64, 40))
    elif frame == 'tail':
        body = [(78, 50), (88, 58), (86, 72), (74, 78), (58, 72), (44, 66), (32, 62, 0), (46, 58), (60, 54)]
        fin = [(40, 62), (24, 48), (18, 50), (22, 62, 0), (18, 76), (24, 78), (40, 66)]
        f.add(Part('fill', pth(smooth(fin)), fill=HVIOLET, shade=INK_SH, off=(-0.8, -0.8),
                   over=line('M38 62 L24 52 M38 64 L22 64 M38 66 L24 74', SILVER, 0.8, op=0.8)))
        f.add(Part('fill', pth(smooth(body)), fill=INK, shade=INK_SH, off=(-2, -2),
                   over=line('M62 58 Q70 60 76 68', HVIOLET, 1.2, op=0.7), hl=hi_line('M50 60 Q64 54 78 54', SILVER, 1.2, op=0.6)))
        f.mark(hit=(20, 48, 70, 32), tip=(20, 62))
    else:
        # the head frames, and their _bare twins once a hit on the lure has knocked the candle loose
        bare = frame.endswith('_bare')
        base = frame[:-5] if bare else frame
        jaw, deg, lid, mood, droop = {'head_closed': (0.0, 0, 0.0, 'open', 0), 'head_open': (1.0, -6, 0.0, 'open', 8),
                                      'head_rest': (0.0, 8, 0.45, 'open', 40), 'hit': (0.45, -16, 0.0, 'squeeze', -20)}[base]
        eyes, lure, bite = coil_head(f, frame, jaw, deg, lid, mood, droop, candle=not bare)
        if base == 'hit':
            f.over += sweat(96, 40, 0.45, 25) + motion('M100 48 L108 44 M28 40 L22 34', 1.2)
        elif base == 'head_open':
            f.over += motion('M20 58 L10 58 M20 70 L8 70', 1.2)
        elif base == 'head_rest':
            f.over += specks([(102, 84, 1.0), (96, 90, 0.8)], PALE, op=0.7)
        if lure:
            f.mark(eyes, 5.6, hit=(26, 36, 76, 50), lure=lure, bite=bite, neck=(34, 66))
        else:
            f.mark(eyes, 5.6, hit=(26, 36, 76, 50), bite=bite, neck=(34, 66))
    return f.svg()



# ================================================================ the Omen looks (P1)
# Overlays for elites.gd's four new Omens, drawn on the glow layer by the kind
# (textures loaded in _ready). The 128 overlays are anchored on their middle
# (64, 64); the motes are 32-unit frames (64 px). See points_monsters4.json _omens.

def omen_svg(name):
    import common
    ctx = e3.Ctx('om' + name[:5])
    if name == 'omen_glassed':
        # the Glassed Omen: a faceted glass shell round the monster
        d = poly(ring(64, 64, 46, 50, 10, start=-72))
        g = ctx.lingrad([(0, '#ffffff', 0.38), (0.5, '#f8f0ff', 0.16), (1, '#c8c0ec', 0.3)], x2=1, y2=1)
        body = '<path d="%s" fill="none" stroke="#07040a" stroke-width="4.4" opacity="0.4"/>' % d
        body += '<path d="%s" fill="%s" stroke="#f8f0ff" stroke-width="2" opacity="0.95"/>' % (d, g)
        cid = ctx.clip('<path d="%s"/>' % d)
        facets = ''
        pts = [(40, 24), (64, 16), (88, 24), (104, 50), (104, 80), (86, 104), (64, 112), (42, 104), (24, 80), (24, 48)]
        inner = [(52, 44), (76, 42), (86, 66), (70, 88), (48, 84), (40, 62)]
        for i, q in enumerate(inner):
            facets += line('M%s L%s' % (fmt(q), fmt(inner[(i + 1) % len(inner)])), '#ffffff', 1.1, op=0.55)
            facets += line('M%s L%s' % (fmt(q), fmt(pts[(i * 10) // len(inner)])), '#ffffff', 0.9, op=0.4)
        body += '<g clip-path="%s">%s</g>' % (cid, facets)
        body += line('M30 50 Q34 32 50 24', '#ffffff', 3.0, op=0.85) + star4(40, 30, 5.4, '#ffffff') + star4(94, 92, 3.4, '#ffffff', 0.9)
        return common.svg(ctx, body, 128, 128)
    if name == 'omen_echo_dial':
        # the Echoing Omen: a flat clock dial round its feet (the hand is code, one tick a beat)
        d = smooth(ring(64, 64, 48, 11, 24))
        body = '<path d="%s" fill="none" stroke="#07040a" stroke-width="5" opacity="0.5"/>' % d
        body += '<path d="%s" fill="none" stroke="#e8fcff" stroke-width="2.2" opacity="0.95"/>' % d
        for i in range(12):
            a = -math.pi / 2 + i * math.pi / 6
            x, y = 64 + 48 * math.cos(a), 64 + 11 * math.sin(a)
            x2, y2 = 64 + 42 * math.cos(a), 64 + 8.6 * math.sin(a)
            w = 2.6 if i % 3 == 0 else 1.4
            body += line('M%.1f %.1f L%.1f %.1f' % (x, y, x2, y2), '#07040a', w + 1.4, op=0.5) + line('M%.1f %.1f L%.1f %.1f' % (x, y, x2, y2), '#e8fcff', w)
        body += star4(64, 53, 3.6, '#ffffff')
        return common.svg(ctx, body, 128, 128)
    if name == 'omen_spore_mote':
        # the Sporebound Omen: a spore mote drifting up from it
        g = ctx.radgrad([(0, '#f4ffc0', 0.95), (0.4, '#b8e070', 0.7), (1, '#b8e070', 0)])
        body = '<circle cx="16" cy="16" r="14" fill="%s"/>' % g
        body += '<circle cx="16" cy="16" r="5.2" fill="#b8e070" stroke="#1c2408" stroke-width="1.2"/>'
        body += dot(14.4, 14.4, 1.6, '#ffffff', 0.9)
        return common.svg(ctx, body, 32, 32)
    # omen_hush_mote: the Hushed Omen's violet-black wisp (with the violet rim drawn in code)
    d = smooth([(16, 4, 0), (21, 13), (22, 20), (16, 26), (10, 20), (11, 13)])
    body = '<path d="%s" fill="none" stroke="#6a5a9a" stroke-width="4" opacity="0.8"/>' % d
    body += '<path d="%s" fill="#16121e"/>' % d + dot(14, 18, 1.4, '#d8d4f0', 0.8)
    return common.svg(ctx, body, 32, 32)


OMENS = ['omen_glassed', 'omen_echo_dial', 'omen_spore_mote', 'omen_hush_mote']
OMEN_DOC = {
    'how': 'Glow-layer overlays for the four new Omens (P1), loaded in _ready. omen_glassed and omen_echo_dial are '
           '128-unit frames anchored on their middle (64, 64); the motes are 32-unit frames (64 px) anchored on their '
           'middle. Colours: Sporebound green b8e070, Echoing frost e8fcff (W4 tell accent), Glassed prism white '
           'f8f0ff, Hushed violet 6a5a9a.',
    'Sporebound': 'Up to 6 omen_spore_mote drifting up from the body (rise 14 px/s, sway 3 px, 1.6 s life, scale 0.12-0.2), '
                  'and its eyes glow green (eye points drawn in b8e070).',
    'Echoing': 'omen_echo_dial at its feet, scaled so its half-width (48 units) is size.x * 0.75 + 4 px (the elite '
               'ring\'s width), flattened as drawn; the hand is a line from the middle to the dial, one tick every '
               'W4 beat (0.536 s). The echo itself: the monster\'s frame redrawn at the strike place in e8fcff at '
               'alpha 0.45, its box outlined from the first strike.',
    'Glassed': 'omen_glassed centred on center(), scaled so its 96-unit width is max(size) * 1.35 px, alpha 0.5 + '
               '0.2 * sin(ftime * 3); gone when the shell breaks (spark burst, omen_glass_break).',
    'Hushed': 'A violet rim: the frame redrawn 4 times offset by 1 px (up, down, left, right) in 6a5a9a at alpha 0.35 '
              'under the eye glints, plus 3 omen_hush_mote orbiting slowly (r = size.x * 0.7); its eyes go dark.',
}


# ================================================================ the points file and all files

W5 = {
    'mite': ['walk1', 'walk2', 'gnaw', 'hit'],
    'gust': ['idle1', 'idle2', 'inhale', 'blow', 'hit'],
    'refractor': ['idle1', 'idle2', 'charge', 'fire', 'hit'],
    'pane': ['face1', 'face2', 'turn', 'edge', 'cut', 'hit', 'shatter'],
}
W6 = {
    'hushling': ['idle1', 'idle2', 'crouch', 'lunge', 'blink', 'pop'],
    'maw': ['idle', 'strain', 'open', 'choke', 'hit'],
    'coil': ['head_closed', 'head_open', 'head_rest', 'seg', 'tail', 'hit', 'head_closed_bare', 'head_open_bare',
             'head_rest_bare', 'hit_bare'],
}
MAKERS = {'mite': mite_svg, 'gust': gust_svg, 'refractor': refractor_svg, 'pane': pane_svg, 'hushling': hushling_svg,
          'maw': maw_svg, 'coil': coil_svg}
ANCHORS = {'mite': (64, 122), 'gust': (64, 64), 'refractor': (64, 64), 'pane': (64, 122), 'hushling': (64, 122),
           'maw': (64, 64), 'coil': (64, 64)}
TELLS = {
    'mite_gnaw.jaws': 'the gnaw tell: the mandibles tapping the glass (the crack runs from here)',
    'gust_*.mouth': 'the mouth the gust blows from (the band runs forward from it)',
    'gust_blow.gust': 'the far end of the drawn gust lines (off the art)',
    'refractor_*.lens': 'the eye in its core: the beam starts here',
    'refractor_*.beam': 'the lock and fire glint round the lens, where code starts the aim line and the beam (the frames '
                        'draw no line: it aims at any angle)',
    'pane_turn.glint': 'the turn tell: the glint running along the lead',
    'pane_edge.glint': 'edge-on, the glint running up the lead',
    'pane_cut.blade': 'the sword tip at the end of the Glass Cut\'s swing (low in front)',
    'pane_cut.arc': 'the middle of the swing\'s glass smear (the 60 x 40 arc runs from over the head down to the tip)',
    'hushling_lunge.mouth': 'the mouth at the front of the lunge',
    'maw_*.mouth': 'the stitched mouth: Swallow and Gulp pull toward it; choke spits the light from it',
    'coil_*.lure': 'the stolen candle\'s flame (the lure light, r 30); the _bare frames have none',
    'coil_*.bite': 'the jaws\' front (the bite)',
    'coil_*.neck': 'where the first segment joins the head',
    'coil_seg.top': 'the segment\'s fin',
    'coil_tail.tip': 'the tail fin\'s tip',
}
NOTES = {
    'mite': 'Neutral glass: tint it by the sprite modulate (enemy.gd tint) with one of _tints, picked by hash(cell). '
            'Its hit box is 40 units (20 px) tall (spec: at least 20), reaching up over its 14 px dome.',
    'pane': 'Neutral glass: tint it as the Glassmite. pane_turn is the turn tell (halfway), pane_edge the 8 px '
            'edge-on window (full damage).',
    'hushling': 'W6: ink with the silver rim (4 units). The ink ends at y 120; its silver rim reaches the floor line.',
    'maw': 'W6: a porcelain mask with the silver rim. It floats: anchored on its middle.',
    'coil': 'W6: the head faces right; chain coil_seg frames behind it from the neck (about 20 px apart) and end '
            'with coil_tail (its fin trails behind, to the left when the head faces right). coil_hit is the head '
            'recoiling; coil_head_rest the head resting on an islet edge (its jaw\'s underside flat on the ground). '
            'Once the candle is knocked loose (flames 0), show the _bare twin of each head frame instead.',
    'unwick': 'No frames: the Unwick is the player\'s own rig (wick_rig.gd) in black with a silver rim.',
}


ROLES = {
    'mite': 'walk1/walk2; the tell: gnaw; hit',
    'gust': 'idle1/idle2 (the bob); the tell: inhale; blow; hit',
    'refractor': 'track: idle1/idle2; lock: charge; fire; hit (code draws the aim line and the beam from lens)',
    'pane': 'advance: face1/face2; the tell: turn; edge-on (the lunge and the recover window): edge; Glass Cut: cut; '
            'face-on hit: hit; death: shatter',
    'hushling': 'idle1/idle2; the tell: crouch; lunge; open after it: blink; death: pop',
    'maw': 'idle; the Swallow and Gulp tells: strain (tipped back, the jaw stretched, the ties flared), then open; the '
           'gulp: open; a hit in a tell: choke (it spits the light); hit',
    'coil': 'swimming: coil_head_closed; the leap bite: coil_head_open; the rest window: coil_head_rest; hit: coil_hit; '
            'the same four as coil_head_closed_bare, _head_open_bare, _head_rest_bare, coil_hit_bare once its candle is '
            'knocked loose; the body: coil_seg links and coil_tail',
}


def files():
    out = {}
    for kinds in (W5, W6):
        for kind, frames in kinds.items():
            for fr in frames:
                out['art/enemies/%s_%s.svg' % (kind, fr)] = MAKERS[kind](fr)
    doc = e3.points_json(dict(W5, **W6), ANCHORS, TELLS, NOTES, 'World 5 and World 6 monster frames (enemies4.py)', ROLES)
    import json
    d = json.loads(doc)
    d['_tints'] = TINTS
    d['_omens'] = dict(OMEN_DOC, frames=OMENS)
    for name in OMENS:
        out['art/enemies/%s.svg' % name] = omen_svg(name)
    d['_rim'] = {'w5': RIM, 'w6': SILVER, 'w6_width_units': RIM6 / 2}
    out['art/enemies/points_monsters4.json'] = json.dumps(d, indent=1, sort_keys=True) + '\n'
    return out


def build(write):
    for rel, text in files().items():
        write(rel, text)


if __name__ == '__main__':
    import build as _b
    build(_b.write)
    print('wrote %d files under game/' % len(files()))
