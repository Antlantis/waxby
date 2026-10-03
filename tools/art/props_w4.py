"""World 4 props, the Frozen Carillon (A1): the gears (and their still
shines), the cog's tooth ledge, the swing ledges, the belt's teeth strip, the
pendulum weight and its pivot, icicles, the brass lamp (W4's `L`), the
clock-face door, the frost altar, bell and brass sconce, and points_w4.json.

Frames (2 units = 1 world px, width = 2 x viewBox, sprite scale 0.25):
  gear_s 64, gear_m 128, gear_l 192 (square, centred; they turn), and
            gear_*_shine the same size (a highlight drawn over the turning
            gear that doesn't turn, so the light stays put)
  cog_tooth 128 x 32: a cog's 2-tile tooth ledge (movers.gd: 64 x 12 px); the
            ledge's top is the frame's top, its rect 128 x 24 units; the arm
            meets it at (64, 28)
  swing_ledge (1 tile), swing_ledge_2, swing_ledge_3: 64 x 32 a tile, the
            ledge's top the frame's top (12 px tall, as movers.gd), the rod
            meets its top at the middle; brass, no bob
  belt_teeth 96 x 16: the belt's cleats, periodic every 32 units (16 px):
            draw a 64-unit window from an offset in [0, 32) along a belt
            tile's top (8 px), scrolled at the belt's speed; the chevrons
            point right (mirror it for a left belt)
  pendulum_bob 80 x 80: a round iron bell-weight with a frost lamp,
            centred on (40, 40): its body (r 34.5 units, 36.5 with its line)
            covers the whole hurt circle (r 18 px = 36 units); its ring is
            its top, the rod meets it at (40, 3): turn it with the rod
  pendulum_pivot 64 x 64: the iron bracket under the ceiling (the frame's
            top); the rod hangs from the pin at (32, 20)
  icicle_hang / _crack / _fall 64 x 64: hanging from the tile top (y 0),
            tip at (32, 60); _fall is the icicle alone
  brass_lamp_lit / _out 64 x 96: standing on y 96, the flame and light at
            (32, 30) (as v2's lantern post)
  clock_door_open / _closed 128 x 192: the arena door, 2 x 3 tiles, top-left
            on the door's top-left cell
  altar_frost / _lit 64 x 96: standing on y 96, wick tip (32, 22)
  bell_frost 128 x 192 (hangs from (64, 20)), bell_frost_beam
  sconce_brass 64 x 64: wick tip (32, 14)
Brass is what you ride; iron with a frost lamp is what hurts. No platform
has the grinder rim (e0602a: the Spurwheel's alone). The tell accent (frost
e8fcff) is used only on the icicle's crack.
"""
import json
import math

import kit
from kit import Part, ell, pth, shp
from common import (Ctx, RIM, FLAME, FLAME_MID, FLAME_CORE, svg, svg64, paint, line, dot, flame, flame_d, glow, spec,
                    sparkle, star4, mix)
from props import candle_parts, rrect, arch_d, flame_outline

# ---------------------------------------------------------------- the carillon's colours (p_artaudio 4.2)
BRASS, BRASS_SH, BRASS_HI, BRASS_LINE = '#c8983a', '#8a6424', '#f0d080', '#3a2408'
ICE, ICE_SH, ICE_HI, ICE_LINE = '#bfe4f4', '#7ab0d0', '#d4ecf8', '#1c3a52'   # ICE_HI 0.10 off the tell
IRON, IRON_SH, IRON_HI, IRON_LINE = '#3a3a48', '#26262f', '#6a6a80', '#0c0c14'
NAVY = '#1a2440'
FROST_TELL = '#e8fcff'      # the tell accent: the icicle's crack only
SLATE, SLATE_SH, SLATE_HI, SLATE_LINE = '#5a6a88', '#3e4c66', '#8aa0c0', '#0e1424'
BRONZE, BRONZE_SH, BRONZE_HI, BRONZE_LINE = '#c8903e', '#8a5a24', '#f6d48a', '#2a1406'
FACE, FACE_SH = '#f4f0e0', '#c8c0a8'


def _pal(line_c, base, shade):
    return dict(line=line_c, rim=RIM, base=base, shade=shade)


def frost_specks(pts, r=1.2):
    return ''.join(dot(x, y, r * k, ICE_HI, 0.95) for x, y, k in pts)


# ================================================================ gears

GEAR = {'s': (64, 10), 'm': (128, 12), 'l': (192, 16)}


def gear_d(cx, cy, r_out, r_in, n):
    """A gear's outline: n trapezoid teeth between r_in and r_out."""
    pts = []
    for k in range(n):
        a0 = 2 * math.pi * k / n
        step = 2 * math.pi / n
        for f, r in ((0.0, r_in), (0.18, r_in), (0.3, r_out), (0.62, r_out), (0.74, r_in)):
            a = a0 + step * f
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return 'M' + ' L'.join('%.2f %.2f' % p for p in pts) + ' Z'


def gear_svg(size):
    N, n = GEAR[size]
    ctx = Ctx('g' + size)
    c = N / 2.0
    k = N / 64.0
    r_out = c - 2.6 * k
    r_in = r_out - (4.6 if size == 's' else 5.4) * k
    pal = _pal(BRASS_LINE, BRASS, BRASS_SH)
    P = []
    body_over = ''
    # the inner rim, the four windows between the spokes, the hub
    rim_r = r_in - 4.2 * k
    body_over += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="none" stroke="%s" stroke-width="%.1f" opacity="0.7"/>' % (c, c, rim_r, BRASS_SH, 1.4 * k)
    win_r0, win_r1 = rim_r - 2.2 * k, 7.6 * k
    for q in range(4):
        a0 = math.radians(q * 90 + 14)
        a1 = math.radians(q * 90 + 76)
        d = 'M%.2f %.2f A%.2f %.2f 0 0 1 %.2f %.2f L%.2f %.2f A%.2f %.2f 0 0 0 %.2f %.2f Z' % (
            c + win_r0 * math.cos(a0), c + win_r0 * math.sin(a0), win_r0, win_r0, c + win_r0 * math.cos(a1), c + win_r0 * math.sin(a1),
            c + win_r1 * math.cos(a1), c + win_r1 * math.sin(a1), win_r1, win_r1, c + win_r1 * math.cos(a0), c + win_r1 * math.sin(a0))
        body_over += '<path d="%s" fill="%s" stroke="%s" stroke-width="%.1f"/>' % (d, '#140e08', BRASS_LINE, 1.1 * k)
    # the marked spoke (so the turning reads), rivets on the rim
    a = math.radians(-45)
    body_over += line('M%.2f %.2f L%.2f %.2f' % (c + 5 * k * math.cos(a), c + 5 * k * math.sin(a), c + rim_r * math.cos(a), c + rim_r * math.sin(a)),
                      BRASS_HI, 3.0 * k)
    for q in range(8):
        aa = math.radians(q * 45 + 22.5)
        body_over += dot(c + (rim_r + 1.8 * k) * math.cos(aa), c + (rim_r + 1.8 * k) * math.sin(aa), 0.9 * k, BRASS_LINE, 0.8)
    # rime in the teeth's roots (even all round: it turns)
    for q in range(n):
        aa = 2 * math.pi * (q + 0.87) / n
        body_over += dot(c + (r_in + 0.6 * k) * math.cos(aa), c + (r_in + 0.6 * k) * math.sin(aa), 1.3 * k, ICE_HI, 0.9)
    P.append(Part('fill', pth(gear_d(c, c, r_out, r_in, n)), off=(-2 * k, -2 * k), over=body_over))
    P.append(Part('fill', ell(c, c, 6.4 * k, 6.4 * k), fill=BRASS, shade=BRASS_SH, off=(-1.2 * k, -1.2 * k),
                  over=dot(c, c, 2.6 * k, IRON) + dot(c - 0.8 * k, c - 0.8 * k, 0.9 * k, IRON_HI)))
    return svg(ctx, paint(ctx, P, pal), N, N)


def gear_shine_svg(size):
    """The light on a gear, drawn over it and never turned."""
    N, n = GEAR[size]
    ctx = Ctx('gs' + size)
    c = N / 2.0
    k = N / 64.0
    r = c - 7.6 * k
    s = '<path d="M%.2f %.2f A%.2f %.2f 0 0 1 %.2f %.2f" fill="none" stroke="#fff4d0" stroke-width="%.1f" stroke-linecap="round" opacity="0.55"/>' % (
        c + r * math.cos(math.radians(200)), c + r * math.sin(math.radians(200)), r, r,
        c + r * math.cos(math.radians(250)), c + r * math.sin(math.radians(250)), 2.2 * k)
    s += spec(c - r * 0.5, c - r * 0.62, 2.6 * k, 1.2 * k, rot=-35, op=0.7)
    s += star4(c - r * 0.78, c - r * 0.2, 1.8 * k, '#ffffff', 0.8)
    return svg(ctx, s, N, N)


# ================================================================ the cog's tooth

def cog_tooth_svg():
    """A 2-tile brass tooth ledge (128 x 24 units of ledge, its top the frame's
    top), riveted, a lug under its middle where the cog's arm meets it."""
    ctx = Ctx('ct')
    pal = _pal(BRASS_LINE, BRASS, BRASS_SH)
    P = []
    P.append(Part('fill', pth('M54 20 L74 20 L70 30.6 L58 30.6 Z'), fill=BRASS_SH, shade=mix(BRASS_SH, '#000000', 0.3), off=(-1, -1),
                  over=dot(64, 25.4, 1.8, IRON) + dot(63.4, 24.8, 0.6, IRON_HI)))
    over = line('M5 3.6 L123 3.6', BRASS_HI, 3.2, cap='butt') + line('M4 20.6 L124 20.6', BRASS_SH, 3.4, cap='butt')
    over += ''.join(dot(x, 12, 1.5, BRASS_LINE) + dot(x - 0.4, 11.6, 0.6, BRASS_HI) for x in (12, 36, 64, 92, 116))
    over += line('M48 7 L48 18 M80 7 L80 18', BRASS_SH, 1.1, op=0.8)
    over += frost_specks(((6, 1.6, 1), (10, 1.2, 0.8), (120, 1.6, 1), (116, 1.4, 0.7)))
    P.append(Part('fill', rrect(1.6, 1.6, 126.4, 22.6, 3), off=(-2, -1.6), over=over))
    return svg(ctx, paint(ctx, P, pal), 128, 32)


# ================================================================ swing ledges

def swing_ledge_svg(n):
    """A brass swing ledge n tiles long (its top the frame's top, 12 px tall),
    a collar at its top middle where the rod meets it. No bob: that's a
    weight's."""
    W = 64 * n
    ctx = Ctx('sw%d' % n)
    pal = _pal(BRASS_LINE, BRASS, BRASS_SH)
    P = []
    # a truss under it (it hangs level)
    tr = ''
    for i in range(n * 2):
        x0 = 8 + i * (W - 16) / (n * 2.0)
        x1 = 8 + (i + 1) * (W - 16) / (n * 2.0)
        tr += 'M%.1f 22 L%.1f 29 L%.1f 22 ' % (x0, (x0 + x1) / 2, x1)
    P.append(Part('limb', pth(tr), width=1.6, fill=BRASS_SH))
    over = line('M5 3.6 L%.1f 3.6' % (W - 5), BRASS_HI, 3.2, cap='butt') + line('M4 20.6 L%.1f 20.6' % (W - 4), BRASS_SH, 3.4, cap='butt')
    over += ''.join(dot(x, 12, 1.4, BRASS_LINE) + dot(x - 0.4, 11.6, 0.6, BRASS_HI) for x in [10 + i * 32 for i in range(W // 32)] + [W - 10])
    # the collar the rod ends in
    over += '<ellipse cx="%.1f" cy="3.2" rx="5.2" ry="3.2" fill="%s" stroke="%s" stroke-width="1.2"/>' % (W / 2, IRON, IRON_LINE)
    over += dot(W / 2, 3.2, 1.3, IRON_HI)
    over += frost_specks(((6, 1.6, 1), (W - 6, 1.6, 1), (W / 2 + 14, 1.4, 0.7)))
    P.append(Part('fill', rrect(1.6, 1.6, W - 1.6, 22.6, 3), off=(-2, -1.6), over=over))
    return svg(ctx, paint(ctx, P, pal), W, 32)


# ================================================================ the belt's teeth

def belt_teeth_svg():
    """The belt's cleats (96 x 16), one every 32 units (16 px), chevrons
    pointing right, under a lit brass top band (the belt's walkable top reads
    against the wall: test_world_art.gd). The feature scrolls a 64-unit
    window of it."""
    ctx = Ctx('bt')
    s = '<rect x="0" y="0" width="96" height="16" fill="%s"/>' % '#1e1a22'
    s += '<rect x="0" y="0" width="96" height="3.2" fill="%s"/>' % BRASS_HI
    s += '<rect x="0" y="3.2" width="96" height="0.8" fill="%s"/>' % BRASS_LINE
    for i in range(3):
        x = 4 + i * 32
        s += '<path d="M%.1f 4.6 L%.1f 4.6 L%.1f 9.2 L%.1f 13.8 L%.1f 13.8 L%.1f 9.2 Z" fill="%s" stroke="%s" stroke-width="1.2" stroke-linejoin="round"/>' % (
            x, x + 12, x + 19, x + 12, x, x + 7, BRASS, BRASS_LINE)
        s += line('M%.1f 5.8 L%.1f 5.8 L%.1f 9.2' % (x + 1.4, x + 11.4, x + 17), BRASS_HI, 1.1)
        s += line('M%.1f 12.4 L%.1f 12.4' % (x + 1.6, x + 11.2), BRASS_SH, 1.0)
    return svg(ctx, s, 96, 16)


# ================================================================ the pendulum weight

def pendulum_bob_svg():
    """A round iron bell-weight (80 x 80, centred on (40, 40)): its body is a
    disc of r 34.5 units, so with its outline it covers the whole hurt circle
    (r 36 units = 18 px) and nothing past it but the outline and the rod's
    ring; a bell's rim ridge across its lower face, rivets round it, a frost
    lamp in its face and rime on its crown. The ring (the rod meets it at
    (40, 3)) is its top: turn the frame with the rod."""
    ctx = Ctx('pb')
    pal = _pal(IRON_LINE, IRON, IRON_SH)
    P = []
    P.append(Part('fill', pth('M40 0.8 C43.6 0.8 45.4 3 45.4 5.6 L45.4 9 L34.6 9 L34.6 5.6 C34.6 3 36.4 0.8 40 0.8 Z '
                              'M37.8 4 L42.2 4 L42.2 6.4 L37.8 6.4 Z'), off=(-0.8, -0.8)))
    lamp = ctx.radgrad([(0, '#ffffff'), (0.5, '#c4e4f4'), (1, '#6aa0c4')])
    over = ''
    # the bell's rim ridge: a dark band with a lit upper edge, across the lower face
    ridge = ctx.clip('<circle cx="40" cy="40" r="34.5"/>')
    over += '<g clip-path="%s"><rect x="0" y="56" width="80" height="7.4" fill="%s"/>' % (ridge, IRON_SH)
    over += '<rect x="0" y="55" width="80" height="1.6" fill="%s" opacity="0.8"/></g>' % IRON_HI
    over += line('M9.6 63.4 Q40 70.6 70.4 63.4', IRON_LINE, 1.2, op=0.7)
    # the shoulder: where the bell's crown turns down
    over += line('M10.4 29 Q40 17.4 69.6 29', IRON_LINE, 1.6, op=0.8) + line('M11 30.6 Q40 19 69 30.6', IRON_HI, 1.0, op=0.5)
    # rivets round the face
    for k in range(10):
        ang = math.radians(18 + k * 36)
        x, y = 40 + 29.4 * math.cos(ang), 40 + 29.4 * math.sin(ang)
        if 52 < y < 66:
            continue
        over += dot(x, y, 1.5, IRON_LINE) + dot(x - 0.45, y - 0.45, 0.6, IRON_HI)
    # the frost lamp in its brass bezel
    over += '<circle cx="40" cy="40" r="12.6" fill="%s" stroke="%s" stroke-width="2"/>' % (BRASS_SH, IRON_LINE)
    over += '<circle cx="40" cy="40" r="10.2" fill="%s" stroke="%s" stroke-width="1.2"/>' % (BRASS, BRASS_LINE)
    over += '<circle cx="40" cy="40" r="7.8" fill="%s" stroke="%s" stroke-width="1.2"/>' % (lamp, ICE_LINE)
    over += spec(37.4, 37.2, 2.2, 1.3, rot=-30, op=0.95)
    # rime on the crown
    rime = ('M18 17.6 Q27 7.6 40 7 Q53 7.6 62 17.6 Q57 17.4 54.6 20.6 Q51.4 17 47.4 19.4 Q44 16 40 18.6 '
            'Q36 16 32.6 19.4 Q28.6 17 25.4 20.6 Q23 17.4 18 17.6 Z')
    P.append(Part('fill', '<circle cx="40" cy="40" r="34.5" {a}/>', off=(-3.6, -3), over=over,
                  hl=spec(24, 28, 2.4, 7, rot=28, op=0.32)))
    P.append(Part('fill', pth(rime), fill=ICE, shade=ICE_SH, off=(-0.6, -0.8), line=ICE_LINE, lw=1,
                  over=frost_specks(((29, 11.6, 1), (44, 9.6, 0.8), (53, 13, 0.7)))))
    return svg(ctx, paint(ctx, P, pal), 80, 80)


def pendulum_pivot_svg():
    """The weight's iron bracket under the ceiling; the pin at (32, 20)."""
    ctx = Ctx('pp')
    pal = _pal(IRON_LINE, IRON, IRON_SH)
    P = [Part('fill', rrect(12, 0.4, 52, 6.4, 1.4), off=(-1, -1),
              over=dot(17, 3.4, 1.2, IRON_LINE) + dot(47, 3.4, 1.2, IRON_LINE) + line('M14 1.6 L50 1.6', IRON_HI, 0.8, op=0.8)),
         Part('fill', pth('M24 5 L40 5 L37 17 Q32 26 27 17 Z'), off=(-1.4, -1)),
         Part('fill', ell(32, 20, 4.4, 4.4), fill=BRASS, shade=BRASS_SH, off=(-0.8, -0.8), line=BRASS_LINE,
              over=dot(32, 20, 1.4, IRON_LINE))]
    over = frost_specks(((14, 6.4, 1), (20, 6.8, 0.8), (46, 6.6, 0.9), (26, 9, 0.7)))
    over += '<path d="M20 6.4 L21.6 11.4 L23 6.4 Z M43 6.4 L44 10 L45.2 6.4 Z" fill="%s" stroke="%s" stroke-width="0.6"/>' % (ICE, ICE_LINE)
    return svg64(ctx, paint(ctx, P, pal) + over)


# ================================================================ icicles

def _icicle_parts(base=True):
    P = []
    if base:
        P.append(Part('fill', pth('M12 0 L52 0 L50 4.4 Q44 8.6 38 7 Q32 9.6 26 7 Q20 8.6 14 4.4 Z'), fill=ICE, shade=ICE_SH, off=(-0.8, -1),
                      line=ICE_LINE, lw=1.1))
        for x, ln in ((19, 14), (45, 11)):
            P.append(Part('fill', pth('M%.1f 4 L%.1f 4 L%.1f %.1f Z' % (x - 3, x + 3, x + 0.4, 4 + ln)), fill=ICE, shade=ICE_SH, off=(-0.6, 0),
                          line=ICE_LINE, lw=1))
    body = 'M22 3 L42 3 Q40 18 36.4 34 Q34 48 32.4 60 L31.6 60 Q30 48 27.6 34 Q24 18 22 3 Z'
    over = line('M28 8 Q29.6 30 31.8 54', ICE_HI, 2.2, op=0.9) + line('M37 10 Q36 26 34 40', ICE_HI, 0.9, op=0.6)
    P.append(Part('fill', pth(body), fill=ICE, shade=ICE_SH, off=(-2.4, -1), line=ICE_LINE, over=over))
    return P


def icicle_svg(state):
    ctx = Ctx('ic' + state[:2])
    pal = _pal(ICE_LINE, ICE, ICE_SH)
    P = _icicle_parts(base=state != 'fall')
    over = ''
    if state == 'crack':
        # the tell: a crack across its root and a frost glint
        over += line('M23.4 11 L28 13.4 L30.6 10.6 L35 14.6 L40.4 11.6', ICE_LINE, 2.6)
        over += line('M23.4 11 L28 13.4 L30.6 10.6 L35 14.6 L40.4 11.6', FROST_TELL, 1.3)
        over += sparkle(46, 18, 4.6, ICE_LINE, FROST_TELL) + star4(18, 24, 2.2, FROST_TELL, 0.95)
    if state == 'fall':
        over += line('M26 -2 L26 -10 M38 -2 L38 -9 M32 -4 L32 -14', ICE_HI, 1, op=0.6)
    body = paint(ctx, P, pal) + over
    if state == 'fall':
        body = '<g transform="translate(0 2)">%s</g>' % body
    return svg64(ctx, body)


# ================================================================ the brass lamp (W4's L)

def brass_lamp_svg(lit):
    """A clockmaker's lamp on a brass post (64 x 96, base on y 96): a glass
    chimney in a brass cage under a frosted cap. The flame (painted when lit)
    and the lamp's light at (32, 30)."""
    ctx = Ctx('bl' + ('l' if lit else 'o'))
    pal = _pal(BRASS_LINE, BRASS, BRASS_SH)
    P = []
    P.append(Part('fill', pth('M20.4 95.4 L43.6 95.4 L41 89 L23 89 Z'), off=(-1.2, -1), over=line('M24 90.4 L40 90.4', BRASS_HI, 0.8)))
    P.append(Part('limb', pth('M32 89.4 L32 44'), width=3.2, fill=BRASS, over=line('M31.1 88 L31.1 46', BRASS_HI, 0.7, op=0.8)))
    # a little gear on the post
    P.append(Part('fill', pth(gear_d(32, 68, 7.4, 5.6, 8)), off=(-0.8, -0.8), over=dot(32, 68, 1.8, IRON)))
    P.append(Part('fill', ell(32, 80, 3.6, 1.8), off=(-0.6, -0.6)))
    # the chimney
    glass = 'M24.6 41 Q23.4 30 25.8 17.6 L38.2 17.6 Q40.6 30 39.4 41 Z'
    if lit:
        gl = ctx.lingrad([(0, '#fff6d8'), (0.5, '#ffe09a'), (1, '#f2b84b')])
        inner = flame(ctx, 32, 35.6, 7.2, 12.4, lean=0.5, halo=False, lcol='#5a1e0c') + line('M32 36.4 L32 33.4', '#241a14', 1.1)
    else:
        gl = ctx.lingrad([(0, '#3a4a5c'), (1, '#1e2836')])
        inner = line('M32 37 Q31.6 35 32.2 33.4', '#241a14', 1.2)
        inner += '<path d="M27 21 L27.6 36 L29 36 L28.6 21 Z" fill="%s" opacity="0.5"/>' % '#a8c8e0'
        inner += frost_specks(((27, 38, 1), (36.6, 22, 0.9), (29, 26, 0.7)))
    P.append(Part('fill', pth(glass), fill=gl, shade=gl, no_shade=True, lw=1.0, line=BRASS_LINE, over=inner))
    # the cage: side bars, the base cup, the cap
    for d in ('M25.8 18 Q23.6 30 24.8 40.6', 'M38.2 18 Q40.4 30 39.2 40.6'):
        P.append(Part('limb', pth(d), width=1.6, fill=BRASS))
    P.append(Part('fill', pth('M21.6 40.4 L42.4 40.4 L40 45.6 L24 45.6 Z'), off=(-1, -1), over=line('M23.6 41.6 L40.4 41.6', BRASS_HI, 0.7)))
    P.append(Part('fill', pth('M21 18.4 L43 18.4 L38 10.6 L26 10.6 Z'), off=(-1.4, -1.2), over=line('M23 17.4 L41 17.4', BRASS_HI, 0.8)))
    P.append(Part('fill', pth('M24.6 11.6 Q26 6.6 32 6.4 Q38 6.6 39.4 11.6 Q36 10.4 34.4 12.4 Q32 10 29.6 12.4 Q28 10.4 24.6 11.6 Z'),
                  fill=ICE, shade=ICE_SH, off=(-0.6, -0.6), line=ICE_LINE, lw=0.9, over=frost_specks(((28, 8.4, 0.8), (35, 8.2, 0.7)))))
    P.append(Part('fill', ell(32, 5.4, 1.9, 1.7), fill=BRASS, shade=BRASS_SH, off=(-0.4, -0.4)))
    under, over = '', ''
    if lit:
        halo = ctx.radgrad([(0, '#ffc85a', 0.55), (0.5, '#ffb040', 0.2), (1, '#ffb040', 0)])
        under = '<ellipse cx="32" cy="30" rx="28" ry="26" fill="%s"/>' % halo
        over = sparkle(47, 22, 2.6, BRASS_LINE, '#fff2c8')
    else:
        over = line('M36 42 L38 46.6', ICE_HI, 0.7, op=0.8)
    return svg(ctx, under + paint(ctx, P, pal) + over, 64, 96)


# ================================================================ the clock-face door

def _clock_face(cx, cy, r, h_ang, m_ang, lit=False):
    s = '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s" stroke="%s" stroke-width="2.4"/>' % (cx, cy, r, FACE if not lit else '#fff8e8', BRASS_LINE)
    s += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="none" stroke="%s" stroke-width="1.6"/>' % (cx, cy, r - 3, BRASS)
    for k in range(12):
        a = math.radians(k * 30 - 90)
        r0 = r - (9 if k % 3 == 0 else 7)
        s += line('M%.2f %.2f L%.2f %.2f' % (cx + r0 * math.cos(a), cy + r0 * math.sin(a), cx + (r - 4.6) * math.cos(a), cy + (r - 4.6) * math.sin(a)),
                  NAVY, 2.2 if k % 3 == 0 else 1.2, cap='butt')
    for ang, ln, w in ((h_ang, r * 0.5, 3.2), (m_ang, r * 0.74, 2.2)):
        a = math.radians(ang - 90)
        s += line('M%.2f %.2f L%.2f %.2f' % (cx, cy, cx + ln * math.cos(a), cy + ln * math.sin(a)), NAVY, w)
    s += dot(cx, cy, 2.6, BRASS) + dot(cx, cy, 1.1, NAVY)
    s += '<path d="M%.1f %.1f Q%.1f %.1f %.1f %.1f" fill="none" stroke="#ffffff" stroke-width="1.4" opacity="0.6"/>' % (
        cx - r * 0.7, cy - r * 0.2, cx - r * 0.55, cy - r * 0.62, cx - r * 0.1, cy - r * 0.76)
    return s


def clock_door_svg(closed):
    """The Tinker's door (2 x 3 tiles, 128 x 192): closed, a frosted iron door
    with a clock face; open, only the brass jambs and the lintel's face. Both
    faces show ten past ten, no hand on XII, III, VI or IX: his fight is
    ringing the hour a clock shows, and a door must never suggest one."""
    ctx = Ctx('cd' + ('c' if closed else 'o'))
    pal = _pal(IRON_LINE, IRON, IRON_SH)
    P = []
    if closed:
        plates = ''
        for y in (48, 96, 144):
            plates += line('M6 %d L122 %d' % (y, y), IRON_SH, 2.4) + line('M6 %d L122 %d' % (y + 2, y + 2), IRON_HI, 0.9, op=0.6)
        for y in (8, 56, 104, 152, 184):
            plates += ''.join(dot(x, y, 1.8, IRON_LINE) + dot(x - 0.5, y - 0.5, 0.7, IRON_HI) for x in (12, 40, 88, 116))
        plates += line('M64 100 L64 186', IRON_LINE, 1.6, op=0.8)
        plates += '<rect x="4" y="106" width="120" height="8" fill="%s" stroke="%s" stroke-width="1.2"/>' % (BRASS, BRASS_LINE)
        plates += line('M5 107.6 L123 107.6', BRASS_HI, 1.2)
        plates += frost_specks(((10, 4, 1.2), (30, 3.4, 1), (70, 4, 1.1), (110, 3.6, 1.2), (8, 60, 1), (118, 150, 1), (22, 186, 1.1), (100, 188, 1)))
        P.append(Part('fill', rrect(2, 1, 126, 191, 3), off=(-3, -2.4), over=plates,
                      hl=line('M8 186 L8 8 L120 8', IRON_HI, 1.2, op=0.6)))
        over = _clock_face(64, 58, 34, 305, 60)
        # icicles off its top plate
        for x, ln in ((22, 10), (54, 8), (84, 12), (108, 7)):
            over += '<path d="M%.1f 1 L%.1f 1 L%.1f %.1f Z" fill="%s" stroke="%s" stroke-width="1"/>' % (x - 3, x + 3, x, 1 + ln, ICE, ICE_LINE)
        return svg(ctx, paint(ctx, P, pal) + over, 128, 192)
    for x0, x1 in ((0, 12), (116, 128)):
        P.append(Part('fill', rrect(x0 + 1, 10, x1 - 1, 191, 2), fill=BRASS, shade=BRASS_SH, off=(-1.2, -1), line=BRASS_LINE,
                      over=''.join(dot((x0 + x1) / 2.0, y, 1.3, BRASS_LINE) for y in (30, 80, 130, 180))))
    P.append(Part('fill', rrect(1, 1, 127, 14, 2), fill=IRON, shade=IRON_SH, off=(-1.4, -1.2),
                  over=frost_specks(((10, 3, 1), (40, 2.6, 0.9), (90, 3, 1), (118, 2.6, 0.9)))))
    over = _clock_face(64, 20, 17, 305, 60, lit=True)
    return svg(ctx, paint(ctx, P, pal) + over, 128, 192)


# ================================================================ the frost altar

def altar_frost_svg(lit):
    """An iced slate altar (64 x 96, standing on y 96) with a brass cage round
    its candle; the wick tip at (32, 22) as v2's altar. Lit, its niche burns
    and the ice drips."""
    ctx = Ctx('af' + ('l' if lit else 'u'))
    stone, stone_sh, stone_hi = (('#6a7a98', '#4a5a78', '#9ab0d0') if lit else (SLATE, SLATE_SH, SLATE_HI))
    L = SLATE_LINE
    pal = _pal(L, stone, stone_sh)
    P = []
    P.append(Part('fill', rrect(5.4, 84.4, 58.6, 94.4, 1.6), off=(-2, -2),
                  over=line('M7.4 86.4 L56.6 86.4', stone_hi, 1, op=0.8) + line('M18 84.6 L18 94 M34 84.6 L34 94 M48 84.6 L48 94', L, 0.9, op=0.5)))
    niche = arch_d(22.6, 41.4, 61.4, 83.6)
    body_over = '<path d="%s" fill="#0e1424" stroke="%s" stroke-width="1.3"/>' % (niche, L)
    body_over += line('M12.4 66 L20 66 M44 66 L51.6 66 M12.4 76 L20 76 M44 76 L51.6 76', L, 0.9, op=0.45)
    body_over += line('M12 80.6 L12 60.6 L52 60.6', stone_hi, 1, op=0.8)
    if lit:
        gl = ctx.radgrad([(0, '#ffd88a', 0.9), (0.6, '#ffb040', 0.3), (1, '#ffb040', 0)])
        body_over += '<g clip-path="%s"><ellipse cx="32" cy="76" rx="12" ry="14" fill="%s"/></g>' % (ctx.clip('<path d="%s"/>' % niche), gl)
        body_over += flame(ctx, 32, 81, 8.4, 13.6, lean=0.6, halo=False, lcol=L)
    else:
        body_over += flame_outline(32, 81, 8.4, 13.6, '#2a3450')
    P.append(Part('fill', rrect(10, 58, 54, 84.6, 1.2), off=(-2.6, -2.2), over=body_over))
    # the slab, iced over, icicles (or drips, lit) off its lip
    ice_top = 'M4.6 51 Q14 48.6 24 50.4 Q34 48.6 44 50.4 Q52 48.8 59.4 51 L59.4 54 L4.6 54 Z'
    P.append(Part('fill', rrect(5, 51.6, 59, 58.6, 1.8), off=(-1.8, -1.6), over=line('M7 55.6 L57 55.6', BRASS, 2, cap='butt')
                  + line('M7 56.8 L57 56.8', BRASS_SH, 0.7)))
    P.append(Part('fill', pth(ice_top), fill=ICE, shade=ICE_SH, off=(-0.6, -0.8), line=ICE_LINE, lw=1,
                  over=frost_specks(((10, 50.4, 1), (30, 50, 0.8), (50, 50.4, 0.9)))))
    tips = ''
    for x, ln in ((9, 7), (17, 4.6), (47, 5.6), (55, 8)):
        if lit:
            tips += '<path d="M%.1f 58.4 L%.1f 58.4 L%.1f %.1f Z" fill="%s" stroke="%s" stroke-width="0.8"/>' % (x - 1.6, x + 1.6, x, 58.4 + ln * 0.5, ICE, ICE_LINE)
            tips += dot(x, 58.4 + ln * 0.5 + 3.4, 1.2, ICE_HI, 0.95)
        else:
            tips += '<path d="M%.1f 58.4 L%.1f 58.4 L%.1f %.1f Z" fill="%s" stroke="%s" stroke-width="0.8"/>' % (x - 2.2, x + 2.2, x, 58.4 + ln, ICE, ICE_LINE)
    # the brass dish and the cage round the candle
    P.append(Part('fill', pth('M23.4 48.4 L40.6 48.4 Q40 51.6 36.4 52 L27.6 52 Q24 51.6 23.4 48.4 Z'),
                  fill=BRASS, shade=BRASS_SH, off=(-1, -1), line=BRASS_LINE, over=line('M25.4 49.4 L38.6 49.4', BRASS_HI, 0.8)))
    parts, wick = candle_parts(27.4, 36.6, 25.4, 48.8, 22, drips=((0.2, 5), (0.58, 9), (0.85, 3.4)))
    P += parts
    cage = ''
    for d in ('M24.4 48.6 Q22 34 25.6 16.6', 'M39.6 48.6 Q42 34 38.4 16.6'):
        cage += line(d, BRASS_LINE, 2.8) + line(d, BRASS, 1.5)
    cage += line('M25 16.6 Q32 10.4 39 16.6', BRASS_LINE, 2.8) + line('M25 16.6 Q32 10.4 39 16.6', BRASS, 1.5)
    cage += dot(32, 12.2, 1.8, BRASS) + dot(32, 12.2, 0.7, BRASS_LINE)
    under, over = '', ''
    if lit:
        warm = ctx.radgrad([(0, '#ffb44a', 0.45), (0.5, '#ff9a3a', 0.16), (1, '#ff9a3a', 0)])
        under = '<ellipse cx="32" cy="46" rx="31" ry="44" fill="%s"/>' % warm
        over = sparkle(52, 40, 3.2, L, '#fff2c8') + star4(10, 46, 1.8, '#fff2c8', 0.9)
    return svg(ctx, under + paint(ctx, P, pal) + tips + wick + cage + over, 64, 96)


# ================================================================ the frost bell

def bell_frost_svg():
    """The goal, ice-crusted: v2's bronze bell (the gold rim and the swing kept),
    frost on its shoulder, icicles off its lip, a frosted rope."""
    ctx = Ctx('bf')
    pal = _pal(BRONZE_LINE, BRONZE, BRONZE_SH)
    P = []
    rope_d = 'M64 108 C64.6 130 63.2 152 64 176'
    twist = ''.join('M%.1f %.1f l3.6 -2.4 ' % (62.2 + (0.3 if i % 2 else -0.2), y) for i, y in enumerate(range(114, 176, 5)))
    P.append(Part('limb', pth(rope_d), width=4.6, fill='#d8d0c0', line='#2a2a36', over=line(twist, '#9aa8b8', 1.0)))
    P.append(Part('fill', pth('M60.8 176 L67.2 176 L68.4 180 L69.6 189.4 L66.8 187 L65.2 190 L63.4 187 L61.2 190 '
                              'L60.4 186.6 L58.4 189.4 L59.6 180 Z'), fill='#d8d0c0', shade='#9aa8b8', off=(-1, -1), line='#2a2a36',
                  over=line('M60.4 178.6 L67.6 178.6', '#3a5a9a', 2.2, cap='butt')))
    P.append(Part('fill', ell(64, 104.6, 6, 5.6), fill='#5a4a40', shade='#3a2e28', off=(-1.2, -1.4), line=BRONZE_LINE))
    P.append(Part('fill', pth('M58.4 29.6 L58.4 24.6 C58.4 17.6 69.6 17.6 69.6 24.6 L69.6 29.6 L66 29.6 L66 25 '
                              'C66 22.4 62 22.4 62 25 L62 29.6 Z'), off=(-1, -1.2)))
    body = pth('M50 30 C54 26.6 74 26.6 78 30 C84.4 35 85.4 46 86.6 60 C88 76 94 88 106 96.6 C109 98.8 108 102.4 104 102.4 '
               'L24 102.4 C20 102.4 19 98.8 22 96.6 C34 88 40 76 41.4 60 C42.6 46 43.6 35 50 30 Z')
    bands = (line('M44.2 42.6 Q64 47 83.8 42.6', BRONZE_HI, 1.8) + line('M43.6 46 Q64 50.4 84.4 46', BRONZE_LINE, 0.9, op=0.6)
             + line('M28.8 91.8 Q64 98.2 99.2 91.8', BRONZE_HI, 2) + line('M26 95.6 Q64 102 102 95.6', BRONZE_LINE, 0.9, op=0.6))
    em = flame_d(64, 80, 12, 20, 1)
    bands += '<path d="%s" fill="%s" stroke="%s" stroke-width="1.3" stroke-linejoin="round"/>' % (em, BRONZE_HI, BRONZE_LINE)
    bands += '<path d="%s" fill="%s"/>' % (flame_d(64.2, 79, 5.8, 10, 0.5), '#fff6d8')
    hl = spec(52, 60, 2.6, 16, rot=12, op=0.75) + spec(54.4, 36, 3, 1.4, rot=-20, op=0.9)
    P.append(Part('fill', body, off=(-5, -3), over=bands, hl=hl))
    P.append(Part('fill', ell(64, 102.2, 41.4, 4.2), fill='#2a1608', shade='#2a1608', no_shade=True, rim=False, sil=False, lw=1.2))
    P.append(Part('fill', ell(64, 104.6, 6, 5.6), fill='#5a4a40', shade='#3a2e28', off=(-1.2, -1.4), line=BRONZE_LINE,
                  rim=False, sil=False, hl=dot(62, 102.6, 1.2, '#9a8a80')))
    # frost on the shoulder and crown
    crust = ('M47.6 32 Q56 26.4 64 26.6 Q72 26.4 80.4 32 Q83 38 84.4 44 Q80 41 77.4 44.6 Q74.6 38.6 70.6 41.4 Q66.6 36.6 63 40.6 '
             'Q58.6 36.4 55.6 41.6 Q52 38.4 49 43.6 Q46.6 40 43.8 43 Q45 36 47.6 32 Z')
    P.append(Part('fill', pth(crust), fill=ICE, shade=ICE_SH, off=(-0.8, -1), line=ICE_LINE, lw=1.1,
                  over=frost_specks(((56, 30, 1.2), (66, 29, 1), (74, 31, 1.1), (50, 36, 0.8)))))
    over = ''
    for x, ln in ((30, 9), (44, 6), (84, 7), (98, 10)):
        over += '<path d="M%.1f 101.6 L%.1f 101.6 L%.1f %.1f Z" fill="%s" stroke="%s" stroke-width="1"/>' % (x - 2.4, x + 2.4, x, 101.6 + ln, ICE, ICE_LINE)
    return svg(ctx, paint(ctx, P, pal) + over, 128, 192)


def bell_frost_beam_svg():
    """The frost bell's beam: a brass-banded iron girder, rimed, the hanger at (64, 20)."""
    ctx = Ctx('fb')
    pal = _pal(IRON_LINE, '#4a4c5e', '#34364a')
    over = line('M8 11 L120 11', '#6a6c84', 1, op=0.8)
    over += ''.join(dot(x, 14.2, 1.2, IRON_LINE) + dot(x - 0.4, 13.8, 0.5, '#8a8ca4') for x in range(12, 120, 12))
    P = [Part('fill', rrect(4, 7.6, 124, 20.4, 2.2), off=(-2, -2.4), over=over)]
    for x in (22, 106):
        P.append(Part('fill', rrect(x - 3.4, 6.4, x + 3.4, 21.6, 1), fill=BRASS, shade=BRASS_SH, off=(-1, -1), line=BRASS_LINE))
    P.append(Part('fill', rrect(57, 14.6, 71, 22.6, 1.6), fill=IRON, shade=IRON_SH, off=(-1, -1), line=IRON_LINE,
                  over=dot(60.4, 18.4, 1, IRON_HI) + dot(67.6, 18.4, 1, IRON_HI)))
    rime = 'M5 8 Q30 4.6 64 6.4 Q98 4.6 123 8 L123 10.4 Q100 8.4 64 9.6 Q28 8.4 5 10.4 Z'
    P.append(Part('fill', pth(rime), fill=ICE, shade=ICE_SH, off=(-0.4, -0.6), line=ICE_LINE, lw=0.9))
    tips = ''.join('<path d="M%.1f 20.4 L%.1f 20.4 L%.1f %.1f Z" fill="%s" stroke="%s" stroke-width="0.8"/>' % (
        x - 2, x + 2, x, 20.4 + ln, ICE, ICE_LINE) for x, ln in ((14, 7), (38, 5), (88, 6), (116, 8)))
    return svg(ctx, paint(ctx, P, pal) + tips, 128, 192)


# ================================================================ the brass sconce (P1)

def sconce_brass_svg():
    """W4's wall sconce `c`: a little gear on the wall, a brass arm up to the
    drip pan; the wick tip at (32, 14) as v2's sconce."""
    ctx = Ctx('sq')
    pal = _pal(BRASS_LINE, BRASS, BRASS_SH)
    P = [Part('fill', pth('M29.6 50 L34.4 50 L32 57.6 Z'), off=(-0.8, -0.8)),
         Part('limb', pth('M32 41 L32 33.4'), width=2.4, fill=BRASS),
         Part('limb', pth('M28.4 45.6 C21.6 44.6 20.6 38.4 24.8 36.6 C27.6 35.6 30.6 35.8 32 33.6'), width=2.2, fill=BRASS),
         Part('fill', pth(gear_d(32, 46, 6.6, 5, 8)), off=(-1, -1.2), over=dot(32, 46, 1.8, IRON) + dot(31.5, 45.5, 0.6, IRON_HI)),
         Part('fill', pth('M21.6 30.2 L42.4 30.2 Q41.6 34 37 34.4 L27 34.4 Q22.4 34 21.6 30.2 Z'), off=(-1, -1.2),
              over=line('M23.4 31.2 L40.6 31.2', BRASS_HI, 0.9, op=0.9))]
    parts, wick = candle_parts(28.2, 35.8, 17.4, 30.6, 14, drips=((0.25, 3.6), (0.7, 6)))
    P += parts
    over = frost_specks(((24, 34.6, 0.9), (40, 34.2, 0.8)))
    over += '<path d="M25.6 34.4 L26.6 38 L27.6 34.4 Z M37.6 34.4 L38.4 37 L39.2 34.4 Z" fill="%s" stroke="%s" stroke-width="0.6"/>' % (ICE, ICE_LINE)
    return svg64(ctx, paint(ctx, P, pal) + wick + over)


# ================================================================ where the engine draws

POINTS = {
    'gear_s': {'size': (64, 64), 'center': (32, 32)},
    'gear_m': {'size': (128, 128), 'center': (64, 64)},
    'gear_l': {'size': (192, 192), 'center': (96, 96)},
    'cog_tooth': {'size': (128, 32), 'ledge': (0, 0, 128, 24), 'arm': (64, 28)},
    'swing_ledge': {'size': (64, 32), 'ledge': (0, 0, 64, 24), 'rod': (32, 0)},
    'swing_ledge_2': {'size': (128, 32), 'ledge': (0, 0, 128, 24), 'rod': (64, 0)},
    'swing_ledge_3': {'size': (192, 32), 'ledge': (0, 0, 192, 24), 'rod': (96, 0)},
    'belt_teeth': {'size': (96, 16), 'period': 32, 'window': 64, 'points': 'right'},
    'pendulum_bob': {'size': (80, 80), 'center': (40, 40), 'rod': (40, 3), 'lamp': (40, 40), 'hurt_r': 36, 'body_r': 34.5},
    'pendulum_pivot': {'size': (64, 64), 'pin': (32, 20)},
    'icicle_hang': {'top': (32, 0), 'tip': (32, 60), 'body': (22, 0, 42, 60)},
    'icicle_crack': {'top': (32, 0), 'tip': (32, 60), 'glint': (46, 18)},
    'icicle_fall': {'tip': (32, 62), 'body': (22, 2, 42, 62)},
    'brass_lamp_lit': {'flame': (32, 30), 'base': (32, 96)},
    'brass_lamp_out': {'flame': (32, 30), 'base': (32, 96)},
    'clock_door_open': {'size': (128, 192), 'face': (64, 20)},
    'clock_door_closed': {'size': (128, 192), 'face': (64, 58)},
    'altar_frost': {'flame': (32, 22), 'base': (32, 96)},
    'altar_frost_lit': {'flame': (32, 22), 'base': (32, 96)},
    'bell_frost': {'hang': (64, 20)},
    'bell_frost_beam': {'hang': (64, 20)},
    'sconce_brass': {'flame': (32, 14)},
}


def points_json():
    doc = {'_doc': 'A1 World 4 props (tools/art/props_w4.py). Frame units, 2 units = 1 world px (sprite scale 0.25). '
                   'gear_*: square, centred, turning; gear_*_shine: the same size, drawn over and never turned. cog_tooth and '
                   'swing_ledge*: the ledge rect (x, y, w, h) from the frame top-left, top = the mover rect\'s top; arm / rod = where '
                   'the cog\'s arm or the swing\'s rod meets it. belt_teeth: a strip periodic every `period` units; draw a `window`-unit '
                   'slice from an offset in [0, period) on a belt tile\'s top 8 px, chevrons pointing `points` (mirror for a left belt). '
                   'pendulum_bob: centred on its hurt circle (hurt_r units); the rod meets it at rod; lamp = the frost lamp. '
                   'pendulum_pivot: the rod hangs from pin. icicle_*: top on the ceiling, tip = its point; glint = the tell\'s star. '
                   'flame = where the engine draws a live flame or hangs a light. Standing props stand on y 96 (base).'}
    doc.update({k: {n: (list(p) if isinstance(p, tuple) else p) for n, p in v.items()} for k, v in POINTS.items()})
    return json.dumps(doc, indent=1, sort_keys=True) + '\n'


def files():
    out = {
        'art/props/cog_tooth.svg': cog_tooth_svg(),
        'art/props/swing_ledge.svg': swing_ledge_svg(1),
        'art/props/swing_ledge_2.svg': swing_ledge_svg(2),
        'art/props/swing_ledge_3.svg': swing_ledge_svg(3),
        'art/props/belt_teeth.svg': belt_teeth_svg(),
        'art/props/pendulum_bob.svg': pendulum_bob_svg(),
        'art/props/pendulum_pivot.svg': pendulum_pivot_svg(),
        'art/props/icicle_hang.svg': icicle_svg('hang'),
        'art/props/icicle_crack.svg': icicle_svg('crack'),
        'art/props/icicle_fall.svg': icicle_svg('fall'),
        'art/props/brass_lamp_lit.svg': brass_lamp_svg(True),
        'art/props/brass_lamp_out.svg': brass_lamp_svg(False),
        'art/props/clock_door_open.svg': clock_door_svg(False),
        'art/props/clock_door_closed.svg': clock_door_svg(True),
        'art/props/altar_frost.svg': altar_frost_svg(False),
        'art/props/altar_frost_lit.svg': altar_frost_svg(True),
        'art/props/bell_frost.svg': bell_frost_svg(),
        'art/props/bell_frost_beam.svg': bell_frost_beam_svg(),
        'art/props/sconce_brass.svg': sconce_brass_svg(),
        'art/props/points_w4.json': points_json(),
    }
    for s in GEAR:
        out['art/props/gear_%s.svg' % s] = gear_svg(s)
        out['art/props/gear_%s_shine.svg' % s] = gear_shine_svg(s)
    return out


def build(write):
    for rel, text in files().items():
        write(rel, text)
