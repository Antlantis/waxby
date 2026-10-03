"""The cathedral's cute monsters, one SVG per frame on the 128 x 128 frame,
facing right, feet on y 122 (the bat flies, centered on (64, 64)).

  Rattle the skeleton   skel_walk1/2, skel_hit, skel_bones (the collapsed pile)
  Flit the bat          bat_up, bat_down, bat_hit
  Thornback the ghoul   thorn_walk1/2, thorn_hit, thorn_brace (spikes up: don't stomp it;
                        the brace is its tell before a charge)
"""
import math

import kit
from kit import Part, ell, pth, shp, head_tpl
from common import (Ctx, RIM, svg128, paint, eye, blush, mouth_open, sweat, line, dot, squeeze, swirl_eye, spec,
                    sparkle, H, IN, mix, xf, xell, gx)


def shadow(cx, rx, y=122.5, op=0.35):
    return '<ellipse cx="%s" cy="%s" rx="%s" ry="2.2" fill="#07040a" opacity="%s"/>' % (cx, y, rx, op)


# ================================================================ Rattle, the skeleton

BONE, BONE_SH, BONE_LINE = '#efe6d2', '#c9bfa6', '#2a2030'
BONE_BACK, BONE_BACK_SH = '#d6ccb4', '#b0a58c'
TEAL = '#7ef0c8'
RUST, RUST_SH, RUST_HI = '#b8683a', '#80401f', '#e8a070'
SPAL = dict(line=BONE_LINE, rim=RIM, base=BONE, shade=BONE_SH)


def glow_eye(ctx, cx, cy, w, h, look=(0.8, 0), iris=0.34, col=TEAL, socket=BONE_LINE, pin=False):
    """A skull socket: a dark oval with a glowing iris and a shine."""
    hw, hh = w / 2.0, h / 2.0
    s = '<ellipse cx="%.2f" cy="%.2f" rx="%.2f" ry="%.2f" fill="%s"/>' % (cx, cy, hw, hh, socket)
    r = w * iris
    ix, iy = cx + look[0], cy + look[1] + hh * 0.08
    halo = ctx.radgrad([(0, col, 0.9), (0.5, col, 0.35), (1, col, 0)])
    s += '<circle cx="%.2f" cy="%.2f" r="%.2f" fill="%s"/>' % (ix, iy, r * 2.0, halo)
    core = ctx.radgrad([(0, '#f4fffb'), (0.45, col), (1, mix(col, '#0a3a34', 0.5))], cx=0.42, cy=0.4, r=0.6)
    s += '<circle cx="%.2f" cy="%.2f" r="%.2f" fill="%s"/>' % (ix, iy, r, core)
    if not pin:
        s += dot(ix - r * 0.35, iy - r * 0.4, r * 0.36, '#ffffff')
        s += dot(ix + r * 0.4, iy + r * 0.45, r * 0.16, '#ffffff', 0.85)
    return s


def skel_leg(hip, foot, fill, shade):
    hx, hy = hip
    fx, fy = foot
    kx, ky = (hx + fx) / 2 + 1.6, (hy + fy) / 2
    return [Part('limb', pth('M%.1f %.1f L%.1f %.1f L%.1f %.1f' % (hx, hy, kx, ky, fx, fy)), width=2.8, fill=fill),
            Part('fill', ell(kx, ky, 2.1, 2.1), fill=fill, shade=shade, off=(-0.6, -0.7)),
            Part('fill', pth('M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z' % (
                fx - 2.6, fy + 2.4, fx - 3, fy - 1.6, fx + 3.4, fy - 2.2, fx + 5.6, fy + 0.6,
                fx + 6.2, fy + 2.4, fx + 2, fy + 2.8, fx - 2.6, fy + 2.4)), fill=fill, shade=shade, off=(-0.6, -0.8))]


def skel_arm(sh, hand, fill, shade, elbow_out=1.6):
    sx, sy = sh
    hx, hy = hand
    ex, ey = (sx + hx) / 2 - elbow_out * 0.3, (sy + hy) / 2 + elbow_out
    return [Part('limb', pth('M%.1f %.1f L%.1f %.1f L%.1f %.1f' % (sx, sy, ex, ey, hx, hy)), width=2.6, fill=fill),
            Part('fill', ell(ex, ey, 1.8, 1.8), fill=fill, shade=shade, off=(-0.5, -0.6)),
            Part('fill', ell(hx, hy, 2.6, 2.4), fill=fill, shade=shade, off=(-0.7, -0.8))]


def rusty_sword(hx, hy, ang):
    """A notched rusty shortsword in the hand at (hx, hy), pointing ang degrees (0 = right)."""
    t = 'translate(%.1f %.1f) rotate(%.1f)' % (hx, hy, ang)
    blade = 'M3.4 -2 L17.4 -2.2 L19.6 -0.4 L20.8 0.2 L17.4 2.4 L12.6 2.2 L11.6 0.9 L10.4 2.2 L3.4 2.2 Z'
    guard = 'M2.2 -4.6 L4.4 -4.6 L4.4 4.6 L2.2 4.6 Z'
    grip = 'M-3.4 -1.2 L2.4 -1.2 L2.4 1.2 L-3.4 1.2 Z'
    return [Part('fill', xf(grip, t), fill='#5a3a2a', shade='#3a2418', off=(0, -0.6)),
            Part('fill', xf(blade, t), fill=RUST, shade=RUST_SH, off=(0, -1.2),
                 over=gx(line('M4.6 -0.9 L16.4 -1', RUST_HI, 0.8, op=0.9)
                         + dot(8, 0.8, 0.7, RUST_SH) + dot(14.6, -0.2, 0.6, RUST_SH), t)),
            Part('fill', xf(guard, t), fill='#8a6a4a', shade='#5a4028', off=(-0.4, -0.6))]


def skull(ctx, cx, cy, w, h, mood, t=''):
    """The big round skull (cranium + jaw) centered on (cx, cy), in mood
    'idle', 'hit' or 'dizzy'. t is an extra transform for the whole skull."""
    k = w / 38.0
    P = []

    def X(x):
        return cx + (x - 66) * k

    def Y(y):
        return cy + (y - 79) * k
    jaw_drop = 4.4 * k if mood == 'hit' else (1.2 * k if mood == 'dizzy' else 0)
    jaw_d = 'M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z' % (
        X(57.6), Y(90) + jaw_drop, X(57.6), Y(98.4) + jaw_drop, X(64), Y(100.6) + jaw_drop, X(71.4), Y(100.4) + jaw_drop,
        X(79), Y(100) + jaw_drop, X(83.2), Y(96.4) + jaw_drop, X(83.4), Y(89.6) + jaw_drop)
    teeth_low = ''.join(
        '<rect x="%.2f" y="%.2f" width="%.2f" height="%.2f" rx="%.2f" fill="#fffaf0" stroke="%s" stroke-width="0.6"/>' % (
            X(x), Y(90.6) + jaw_drop, 2.9 * k, 3 * k, 0.6 * k, BONE_LINE) for x in (62.4, 65.6, 68.8, 72, 75.2))
    P.append(Part('fill', xf(jaw_d, t or 'translate(0 0)'), fill=BONE, shade=BONE_SH, off=(-1, -1.4),
                  over=gx(teeth_low, t or 'translate(0 0)')))
    cran = head_tpl(cx, cy, w, h, squish=-0.08)
    cran = cran.replace(' {a}/>', ' transform="%s" {a}/>' % (t or 'translate(0 0)'))
    f = ''
    # the eye glow warms the bone round the sockets
    halo = ctx.radgrad([(0, TEAL, 0.5), (1, TEAL, 0)])
    f += '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s"/>' % (X(69), Y(81), 20 * k, 11 * k, halo)
    if mood == 'idle':
        f += glow_eye(ctx, X(60.4), Y(80.6), 12.4 * k, 13.8 * k, look=(0.9 * k, 0.2))
        f += glow_eye(ctx, X(77.6), Y(80.2), 9.8 * k, 12.6 * k, look=(0.8 * k, 0.2))
    elif mood == 'hit':
        f += glow_eye(ctx, X(60.2), Y(80), 13.6 * k, 15 * k, look=(0, 0), iris=0.16, pin=True)
        f += glow_eye(ctx, X(77.6), Y(79.6), 10.8 * k, 13.6 * k, look=(0, 0), iris=0.16, pin=True)
    else:
        f += '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s"/>' % (X(60.4), Y(80.6), 6.2 * k, 6.9 * k, BONE_LINE)
        f += '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s"/>' % (X(77.6), Y(80.2), 4.9 * k, 6.3 * k, BONE_LINE)
        f += swirl_eye(X(60.4), Y(80.6), 4.6 * k, TEAL, 1.1) + swirl_eye(X(77.6), Y(80.2), 3.6 * k, TEAL, 1.0)
    # nose, the upper teeth and a crack
    f += '<path d="M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z" fill="%s"/>' % (
        X(70.4), Y(86.6), X(68.2), Y(85), X(66.8), Y(87.6), X(70.2), Y(90.2),
        X(73.2), Y(87.4), X(72.2), Y(85), X(70.4), Y(86.6), BONE_LINE)
    f += '<path d="M%.1f %.1f Q%.1f %.1f %.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f Z" fill="%s"/>' % (
        X(60.4), Y(91.6), X(71), Y(94.6), X(82.4), Y(90.6), X(82.4), Y(92.8), X(71), Y(97.4), X(60.4), Y(93.8), BONE_LINE)
    f += ''.join('<rect x="%.2f" y="%.2f" width="%.2f" height="%.2f" rx="%.2f" fill="#fffaf0"/>' % (
        X(x), Y(y), 2.7 * k, 2.6 * k, 0.5 * k) for x, y in ((62.6, 92.1), (65.8, 92.9), (69, 93.3), (72.2, 93.2), (75.4, 92.7), (78.6, 91.8)))
    f += line('M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f' % (X(53.4), Y(66.4), X(56.4), Y(69.4), X(54.8), Y(71.6),
                                                               X(58.2), Y(74.6)), BONE_LINE, 1.0)
    hl = spec(X(55), Y(68.4), 5.6 * k, 2.8 * k, rot=-38, op=0.95) + dot(X(61.6), Y(65.6), 1.2 * k, '#ffffff', 0.9)
    P.append(Part('fill', cran, fill=BONE, shade=BONE_SH, off=(-3.4 * k, -3.6 * k), over=gx(f, t or 'translate(0 0)'),
                  hl=gx(hl, t or 'translate(0 0)')))
    return P


def skeleton_svg(frame):
    ctx = Ctx('sk' + frame[:2] + frame[-1])
    P = []
    under = shadow(66, 16)
    over = ''
    if frame in ('walk1', 'walk2'):
        a = 1 if frame == 'walk1' else -1
        bob = 0 if frame == 'walk1' else 0.8
        # back leg and back arm (a shade darker)
        P += skel_leg((61, 108.6 + bob), (60 - 5.4 * a, 118.4), BONE_BACK, BONE_BACK_SH)
        P += skel_arm((58.4, 98.6 + bob), (55.4 - 3.4 * a, 106.4 + bob), BONE_BACK, BONE_BACK_SH)
        # spine, ribs and pelvis
        P.append(Part('limb', pth('M64 96 L63.6 108'), width=2.8, fill=BONE))
        P.append(Part('fill', pth('M57.2 97.8 C57.2 95.8 70.8 95.8 70.8 97.8 L70 104 C68 106.2 60 106.2 58 104 Z'),
                      fill=BONE, shade=BONE_SH, off=(-1, -1),
                      over=line('M58.6 100.4 Q64 102.2 69.6 100.4 M59.2 103 Q64 104.6 69 103', BONE_LINE, 1.1)))
        P.append(Part('fill', pth('M57.8 108.2 C58 105.8 69.4 105.8 69.8 108.2 C69.6 111 66 111.4 63.8 109.8 C61.4 111.4 58 111 57.8 108.2 Z'),
                      fill=BONE, shade=BONE_SH, off=(-0.8, -0.8)))
        P += skull(ctx, 66, 79 + bob, 38, 33, 'idle')
        # front leg, then the arm with its rusty sword held forward
        P += skel_leg((66.4, 108.6 + bob), (68 + 5.4 * a, 118.4), BONE, BONE_SH)
        hx, hy = 75.4 + 2 * a, 104.6 + bob
        P += rusty_sword(hx, hy, -28 - 6 * a)
        P += skel_arm((69.6, 98.6 + bob), (hx, hy), BONE, BONE_SH)
    elif frame == 'hit':
        # jolted: skull knocked back, jaw dropped, arms flung up, the sword flying loose
        P += skel_leg((61, 108.6), (56.6, 118.4), BONE_BACK, BONE_BACK_SH)
        P += skel_arm((58.4, 98.6), (50, 92), BONE_BACK, BONE_BACK_SH, elbow_out=-2)
        P.append(Part('limb', pth('M64 96 L63.6 108'), width=2.8, fill=BONE))
        P.append(Part('fill', pth('M57.2 97.8 C57.2 95.8 70.8 95.8 70.8 97.8 L70 104 C68 106.2 60 106.2 58 104 Z'),
                      fill=BONE, shade=BONE_SH, off=(-1, -1),
                      over=line('M58.6 100.4 Q64 102.2 69.6 100.4 M59.2 103 Q64 104.6 69 103', BONE_LINE, 1.1)))
        P.append(Part('fill', pth('M57.8 108.2 C58 105.8 69.4 105.8 69.8 108.2 C69.6 111 66 111.4 63.8 109.8 C61.4 111.4 58 111 57.8 108.2 Z'),
                      fill=BONE, shade=BONE_SH, off=(-0.8, -0.8)))
        P += skull(ctx, 64, 78, 38, 33, 'hit', t='rotate(-12 64 95)')
        P += skel_leg((66.4, 108.6), (72, 118.4), BONE, BONE_SH)
        P += rusty_sword(88, 84, -70)
        P += skel_arm((69.6, 98.6), (80, 90), BONE, BONE_SH, elbow_out=-2)
        over = (line('M86 66 L92 60 M90 72 L98 70 M44 70 L38 64', BONE_LINE, 1.6) + sweat(90, 80, 0.55, 25)
                + line('M86 66 L92 60 M90 72 L98 70 M44 70 L38 64', '#ffffff', 0.7, op=0.8))
    else:   # bones: the collapsed pile
        P += [Part('limb', pth('M47 118.4 L79 112.6'), width=3, fill=BONE_BACK)]
        P += [Part('fill', ell(x, y, 2.3, 2.1), fill=BONE_BACK, shade=BONE_BACK_SH, off=(-0.6, -0.7))
              for x, y in ((46.2, 117.2), (46.8, 120.2), (79.6, 111.2), (80.8, 114))]
        P.append(Part('fill', pth('M52.2 116 C52.2 113.8 66 113.8 66 116 L65.2 120.4 C63.4 122.2 55.4 122.2 53.4 120.4 Z'),
                      fill=BONE, shade=BONE_SH, off=(-1, -1),
                      over=line('M53.6 117.4 Q59 119 64.6 117.4', BONE_LINE, 1.0)))
        P += [Part('limb', pth('M54 112 L86 119.4'), width=3, fill=BONE)]
        P += [Part('fill', ell(x, y, 2.3, 2.1), fill=BONE, shade=BONE_SH, off=(-0.6, -0.7))
              for x, y in ((53.2, 110.6), (52.6, 113.4), (86.8, 118), (86.2, 121))]
        P += skull(ctx, 66, 108.4, 22, 19, 'dizzy', t='rotate(14 66 116)')
        P += [Part('fill', pth('M82 121 L94 121 L93 118.4 L83 118.4 Z'), fill=RUST, shade=RUST_SH, off=(0, -0.8))]
        over = (sparkle(52, 98, 2.6, BONE_LINE, '#bff8e6') + sparkle(82, 96, 2.2, BONE_LINE, '#bff8e6')
                + sparkle(66, 92, 1.8, BONE_LINE, '#bff8e6'))
        under = shadow(68, 22)
    return svg128(ctx, under + paint(ctx, P, SPAL) + over)


# ================================================================ Flit, the bat

BAT, BAT_SH, BAT_LINE = '#6a4a8a', '#4a3068', '#1a0e26'
BAT_HI = '#9a7abc'
MEMBRANE, MEMBRANE_SH = '#8a5a9a', '#6a3c7c'
BPAL = dict(line=BAT_LINE, rim=RIM, base=BAT, shade=BAT_SH)
BFACE = dict(line=BAT_LINE, base=BAT, iris0='#3a0612', iris1='#c0202e', iris2='#ff6a5a', blush='#ff7ab0')


def wing(side, mode):
    """One wing: side -1 (left) or 1 (right); mode 'up', 'down' or 'crumpled'."""
    def X(x):
        return 64 + side * (64 - x)
    if mode == 'up':
        root_t, root_b = (57, 58), (58, 69)
        pts = [(29, 36), (33, 50), (42, 53), (51, 63)]
        lead = (44, 42)
    elif mode == 'down':
        root_t, root_b = (56, 60), (58, 70)
        pts = [(30, 86), (40, 90), (48, 84), (54, 77)]
        lead = (40, 62)
    else:
        root_t, root_b = (56, 59), (58, 69)
        pts = [(38, 48), (39, 60), (46, 64), (52, 68)]
        lead = (46, 48)
    tip = pts[0]
    d = 'M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (X(root_t[0]), root_t[1], X(lead[0]), lead[1], X(tip[0]), tip[1])
    chain = pts + [root_b]
    for (x0, y0), (x1, y1) in zip(chain, chain[1:]):
        # a scallop bowing in toward the body
        mx, my = (x0 + x1) / 2.0, (y0 + y1) / 2.0
        cx, cy = mx + (root_t[0] - mx) * 0.22, my + (root_t[1] - my) * 0.22
        d += ' Q%.1f %.1f %.1f %.1f' % (X(cx), cy, X(x1), y1)
    d += ' Z'
    bones = ''.join('M%.1f %.1f L%.1f %.1f ' % (X(root_t[0] + 1), root_t[1] + 2, X(x), y) for x, y in pts[:3])
    bones_s = line(bones, BAT_SH, 1.3) + dot(X(tip[0]), tip[1], 1.2, BAT_SH)
    near = side < 0
    return Part('fill', pth(d), fill=MEMBRANE if near else mix(MEMBRANE, BAT_SH, 0.35), shade=MEMBRANE_SH,
                off=(-1.6 * -side if False else -1.6, -2), over=bones_s)


def bat_svg(frame):
    ctx = Ctx('bt' + frame[-2:])
    mode = {'up': 'up', 'down': 'down', 'hit': 'crumpled'}[frame]
    P = [wing(1, mode), wing(-1, mode)]
    tilt = 'rotate(-10 64 64)' if frame == 'hit' else 'translate(0 0)'
    # ears
    for d, inner in (('M53.6 58 L52.4 43.6 L61 53 Z', 'M54.6 55 L54 47.6 L58.6 52.6 Z'),
                     ('M66.4 53 L74.6 43 L74.4 57.6 Z', 'M68.6 53 L73.2 47.6 L73 54.8 Z')):
        P.append(Part('fill', xf(d, tilt), fill=BAT, shade=BAT_SH, off=(-0.8, -1),
                      over=gx('<path d="%s" fill="#e88ab8"/>' % inner, tilt)))
    # the round fuzzy body with a pale tuft on the chest
    body = '<path d="M64 52 C74.6 52 77.4 59 77.4 65.4 C77.4 73.4 71.6 77 64 77 C56.4 77 50.6 73.4 50.6 65.4 C50.6 59 53.4 52 64 52 Z" transform="%s" {a}/>' % tilt
    f = ''
    tuft = ('<path d="M58.4 73.6 Q61 69.4 64.4 70.6 Q67.4 69 70.2 72.6 Q67.6 76.4 64.4 76.4 Q60.6 76.4 58.4 73.6 Z" fill="%s"/>' % BAT_HI)
    f += tuft
    if frame == 'hit':
        f += squeeze(62.8, 63.6, 7.6, BAT_LINE, w=2) + squeeze(72.6, 63.2, 6.4, BAT_LINE, flip=True, w=2)
        f += ('<path d="M65 69.8 Q67 68.4 69 69.8 Q68.6 72.6 67 72.6 Q65.4 72.6 65 69.8 Z" fill="%s"/>' % BAT_LINE)
    else:
        f += eye(ctx, 62.6, 63.6, 8.2, 10.6, BFACE, look=(0.8, 0.4)) + eye(ctx, 72.8, 63.2, 6.6, 10, BFACE, look=(0.8, 0.4))
        f += line('M64.6 69.6 Q66.6 71 68.8 69.4', BAT_LINE, 1.2)
        # tiny fangs
        f += ('<path d="M65.2 70 L66.4 70.5 L65.6 72.6 Z M67.6 70.4 L68.8 69.9 L68.4 72.2 Z" fill="#ffffff" stroke="%s" '
              'stroke-width="0.5" stroke-linejoin="round"/>') % BAT_LINE
    f += blush(58.4, 69.4, BFACE, rx=2.6, ry=1.5, op=0.7) + blush(76.2, 68.8, BFACE, rx=1.6, ry=1.3, op=0.7)
    P.append(Part('fill', body, fill=BAT, shade=BAT_SH, off=(-2.4, -2.6), over=gx(f, tilt),
                  hl=gx(spec(56.4, 57, 3, 1.6, rot=-38, op=0.75) + dot(60.4, 54.6, 0.8, '#ffffff', 0.8), tilt)))
    # little feet tucked under
    for x in (60.4, 67.4):
        P.append(Part('fill', xell(x, 77.6, 1.9, 1.5, tilt), fill=BAT_SH, shade=BAT_SH, off=(0, 0), no_shade=True))
    over = ''
    if frame == 'hit':
        over = sweat(80, 54, 0.55, 20) + line('M44 42 L40 37 M84 40 L89 35 M50 36 L49 30', '#ffffff', 1.2, op=0.9)
    return svg128(ctx, paint(ctx, P, BPAL) + over)


# ================================================================ Thornback, the spiked ghoul

SKIN, SKIN_SH, SKIN_LINE = '#7a8a6a', '#5a6a4e', '#161a14'
IRON, IRON_SH, IRON_HI, IRON_BAND = '#4f4f5e', '#363644', '#7a7a8e', '#8e8ea2'
SPIKE, SPIKE_SH = '#d6d6e2', '#9a9aae'
TPAL = dict(line=SKIN_LINE, rim=RIM, base=SKIN, shade=SKIN_SH)
TFACE = dict(line=SKIN_LINE, base=SKIN, iris0='#2a2a04', iris1='#9aa416', iris2='#f4ff7a', blush='#ff8f9a')

SPIKES = [(-62, 39.6, 81, 10.4), (-30, 49.4, 71.4, 11.4), (0, 62.4, 67.6, 12), (28, 75.4, 70.4, 11.4),
          (58, 85, 79.2, 10)]   # (lean degrees, base x, base y, height)


def spike(lean, bx, by, h, w=11.4):
    t = 'rotate(%s %s %s)' % (lean * 0.55, bx, by)
    d = 'M%.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f Z' % (
        bx - w / 2, by + 2, bx - w * 0.16, by - h * 0.5, bx, by - h, bx + w * 0.16, by - h * 0.5, bx + w / 2, by + 2)
    return Part('fill', xf(d, t), fill=SPIKE, shade=SPIKE_SH, off=(-1.4, 0), line=SKIN_LINE,
                hl=gx(line('M%.1f %.1f L%.1f %.1f' % (bx - w * 0.2, by - 1, bx - 0.4, by - h * 0.78), '#ffffff', 0.9, op=0.9), t))


# The brace before a charge: the shell tips forward and down like a bull's
# head, the back claws dig in behind. (thornback.gd mirrors its eye points.)
BRACE_TILT = 'translate(2.2 4.8) rotate(11 90 118)'


def thorn_svg(frame):
    ctx = Ctx('th' + frame[-2:])
    P = []
    a = 1 if frame == 'walk1' else (-1 if frame == 'walk2' else 0)
    bob = 0.8 if frame == 'walk2' else 0
    brace = frame == 'brace'
    tilt = 'rotate(-7 64 110)' if frame == 'hit' else (BRACE_TILT if brace else 'translate(0 %s)' % bob)
    # stubby legs, clawed feet (the back one darker); braced, the back foot
    # is pushed out behind and the front one planted ahead
    feet = ((56, 45.6, SKIN_SH, '#48563e'), (77, 82.4, SKIN, SKIN_SH)) if brace else (
        (56, 55 - 4 * a, SKIN_SH, '#48563e'), (77, 79 + 4 * a, SKIN, SKIN_SH))
    for (hx, fx, col, sh) in feet:
        P.append(Part('limb', pth('M%.1f 108 Q%.1f 114 %.1f 117.6' % (hx, (hx + fx) / 2, fx)), width=6.4, fill=col))
        P.append(Part('fill', pth('M%.1f 120.6 C%.1f 115.6 %.1f 114.6 %.1f 115.4 C%.1f 116 %.1f 118 %.1f 120.6 Z' % (
            fx - 4.6, fx - 4.2, fx + 1.4, fx + 3.8, fx + 6.6, fx + 7.6, fx + 7.6)), fill=col, shade=sh, off=(-1, -1.2),
            over=line('M%.1f 120.4 L%.1f 118.4 M%.1f 120.4 L%.1f 118.2' % (fx + 3.4, fx + 3.6, fx + 6, fx + 6.4), SKIN_LINE, 0.8)))
        P[-1].tpl = P[-1].tpl  # feet stay planted when the shell tilts
    # the body under the shell
    P.append(Part('fill', xell(66, 104, 21, 11, tilt), fill=SKIN, shade=SKIN_SH, off=(-2, -2)))
    # the face peeking out from under the front of the shell
    face = xf('M69 86.6 C80 82.6 96 86 97.4 98.4 C98.4 108 91.4 114 82.4 114 C73 114 66.4 109 66 100.4 C65.8 94 66 89 69 86.6 Z', tilt)
    f = ''
    if frame == 'hit':
        f += eye(ctx, 77.4, 100.6, 10.4, 12.8, TFACE, look=(0, 0))
        f += eye(ctx, 89.4, 100, 8.2, 12, TFACE, look=(0, 0))
        f += '<ellipse cx="84.2" cy="109.4" rx="2.1" ry="2.5" fill="%s"/>' % SKIN_LINE
    elif brace:
        # narrowed, fixed on Wick, teeth gritted
        f += eye(ctx, 77.4, 101, 10.4, 12.8, TFACE, look=(2.0, 0.8), lid=0.4) + eye(ctx, 89.4, 100.4, 8.2, 12, TFACE, look=(2.0, 0.8), lid=0.4)
        f += ('<path d="M80.4 108.4 Q84.4 107.4 88.6 108 L88.2 111.4 Q84.4 112.2 80.8 111.6 Z" fill="#ffffff" stroke="%s" stroke-width="0.9" stroke-linejoin="round"/>' % SKIN_LINE
              + line('M84.5 107.8 L84.5 111.8 M80.8 110 Q84.4 109.4 88.4 109.8', SKIN_LINE, 0.6))
    else:
        f += eye(ctx, 77.4, 101, 10.4, 12.8, TFACE, look=(1.2, 0.4), lid=0.14) + eye(ctx, 89.4, 100.4, 8.2, 12, TFACE, look=(1.2, 0.4), lid=0.14)
        f += line('M81 109.4 Q84.2 110.8 87.6 109', SKIN_LINE, 1.3)
        f += '<path d="M85.2 110 L86.9 109.4 L86.3 112.2 Z" fill="#ffffff" stroke="%s" stroke-width="0.5" stroke-linejoin="round"/>' % SKIN_LINE
    f += blush(72.6, 108, TFACE, rx=2.8, ry=1.6, op=0.6) + blush(94.2, 107.2, TFACE, rx=1.8, ry=1.3, op=0.6)
    P.append(Part('fill', face, fill=SKIN, shade=SKIN_SH, off=(-2, -2.4), over=gx(f, tilt),
                  hl=gx(spec(72, 96, 2, 1, rot=-30, op=0.4), tilt)))
    # tiny clawed hands
    for x, y in ((71 + 1.2 * a, 114), (91.6 - 1.2 * a, 113.6)):
        P.append(Part('fill', xell(x, y, 3, 2.4, tilt), fill=SKIN, shade=SKIN_SH, off=(-0.6, -0.8)))
    # the spiked iron shell: a heavy dome over its back and head, a steel band on its rim
    for sp in SPIKES:
        P.append(spike(*sp))
        P[-1].tpl = P[-1].tpl.replace('transform="', 'transform="%s ' % tilt)
        P[-1].hl = gx(P[-1].hl, tilt)
    shell_d = 'M31.6 100 C31.6 80 46 70 63.6 70 C82 70 95.6 79 96 90.6 C96.2 93.4 94.6 94 92 93.6 C82 92.4 74 93.4 66.6 97 C56 102 40 104.4 34 103.4 C32.2 103 31.6 102 31.6 100 Z'
    rivets = ''.join(dot(x, y, 1.1, '#23232e') + dot(x - 0.4, y - 0.4, 0.45, IRON_HI) for x, y in (
        (42, 86.4), (52.4, 79.8), (64.4, 77.6), (76.4, 79.6), (86.6, 83.6)))
    band = ('<path d="M33 97.2 C44 99.6 56 98 66 93.4 C76 89 86 88.4 95.8 88.6" fill="none" stroke="%s" stroke-width="2.6" stroke-linecap="round"/>'
            % IRON_BAND)
    shell_hl = (spec(45, 78.6, 7, 2.6, rot=-35, op=0.35) + line('M38.6 88 C42 79.4 50 73.6 58.6 72.2', IRON_HI, 1.4, op=0.9))
    P.append(Part('fill', xf(shell_d, tilt), fill=IRON, shade=IRON_SH, off=(-3, -3.4), over=gx(band + rivets, tilt),
                  hl=gx(shell_hl, tilt)))
    over = ''
    if frame == 'hit':
        over = sweat(99, 88, 0.6, 25) + line('M26 72 L20 67 M30 64 L26 57', '#ffffff', 1.3, op=0.9)
    elif brace:
        # grit kicked up behind the digging claws, and a snort
        over = ''.join('<circle cx="%s" cy="%s" r="%s" fill="%s" opacity="%s"/>' % c for c in (
            (37.6, 119.4, 3.4, '#8e8698', 0.8), (31.4, 116.8, 2.6, '#8e8698', 0.65), (26.4, 120.2, 2.0, '#8e8698', 0.5),
            (35.2, 114.2, 1.2, '#b8b0c4', 0.8)))
        over += line('M22 121.4 L32 121.4 M18.6 118.2 L25.4 118.2', '#b8b0c4', 1.1, op=0.8)
        over += line('M101.6 112.2 Q105 110.4 107.2 112.4 M102.8 115.6 Q106.6 115.6 108.2 118', '#ffffff', 1.1, op=0.85)
    return svg128(ctx, shadow(64 if brace else 66, 23 if brace else 22) + paint(ctx, P, TPAL) + over)


def files():
    out = {}
    for fr in ('walk1', 'walk2', 'hit', 'bones'):
        out['art/enemies/skel_%s.svg' % fr] = skeleton_svg(fr)
    for fr in ('up', 'down', 'hit'):
        out['art/enemies/bat_%s.svg' % fr] = bat_svg(fr)
    for fr in ('walk1', 'walk2', 'hit', 'brace'):
        out['art/enemies/thorn_%s.svg' % fr] = thorn_svg(fr)
    return out
