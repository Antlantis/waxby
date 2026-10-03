"""The Snuffer's parts for the story figures and portraits (story_figs.py,
story_faces.py): the same head, cassock, hands and snuffer pole as the fight
(tools/art/boss2.py, W6b), so the story shows the one Snuffer the player
fights: a brimless iron cone for a head with the face on it (two almond
sockets with pale pinprick eyes, a pure black mouth, a knob that curls
smoke), a buttoned cassock with a white collar and a cord, long thin grey
hands, and a brass pole with a snuffer bell hung off its crook.

Everything between the two "vendored" rules below is copied verbatim from
boss2.py (the drawing only: no frames, points or build), in its 384 frame
(feet at (192, 368), 2 units = 1 world px, like every character). If boss2.py
changes the Snuffer, copy its new cone_head .. neck and head_at here (or, in
the merged tree, replace this block with "from boss2 import *").
"""
import math

import kit
from kit import Part, pth
from common import Ctx, RIM, line, dot, sweat, swirl_eye, squeeze, spec, sparkle, star4, mix, gx, IN, CHAR_WEIGHTS, paint
from boss import tp, ell_d, place, rot_pt
from story_kit import weights

# ================================================================ vendored from boss2.py (W6b): begin

L = '#07040c'                                   # ink
CASSOCK, CASSOCK_SH, CASSOCK_HI = '#2a2436', '#1a1624', '#463c5a'
IRON, IRON_SH, IRON_HI, IRON_BAND = '#1e1a28', '#120f1a', '#4a4460', '#2e2a3e'
VOID = '#06030a'
HAND, HAND_SH = '#8a8698', '#646074'
BRASS, BRASS_SH, BRASS_HI, BRASS_LINE = '#b8862a', '#86601a', '#f0c870', '#2a1806'
SMOKE = '#b4aecb'
EYE, EYE_GLOW = '#eeeaf8', '#b8b0e8'
EMBER = '#ff9a4a'
PAL = dict(line=L, rim=RIM, base=CASSOCK, shade=CASSOCK_SH)
FOOT = (192, 368)
POLE_LEN = 308.0
HEIGHT = 220.0


def cone_head(ctx, mood='idle', lit=False, smoke=True):
    """The snuffer-cone head, local to the centre of its rim (0, 0): 100
    wide, 88 tall up to its knob. The face sits right of centre (he faces
    right): two black almond sockets with pale pinprick eyes and a pure
    black mouth. mood: idle, glare, roar, strain, shh, shock, dizzy.
    Returns (parts, fx) where fx is drawn over everything (smoke, glints)."""
    base, shade, hi = (IRON, IRON_SH, IRON_HI) if not lit else ('#3a3450', '#262238', '#a89cc8')
    cone = 'M-50 -2 C-45 -28 -18 -56 -8 -72 L8 -72 C18 -56 45 -28 50 -2 Q0 7 -50 -2 Z'
    f = ''
    # the rim band with its rivets
    band = 'M-50.6 -2.4 Q0 6.8 50.6 -2.4 L49 -10.4 Q0 -1.6 -49 -10.4 Z'
    f += '<path d="%s" fill="%s"/>' % (band, IRON_BAND if not lit else '#4a4462')
    f += line('M-49 -10.4 Q0 -1.6 49 -10.4', L, 1.2, op=0.8)
    f += ''.join(dot(x, y, 1.3, hi, 0.9) for x, y in ((-40, -5), (-22, -1.6), (-4, -0.2), (14, -0.6), (32, -3), (44, -5.4)))
    # a seam up the cone and a soot streak
    f += line('M-26 -12 C-20 -30 -10 -50 -4 -70', L, 1.1, op=0.6)
    # the face, on a duller sheen of iron so its black holes read
    plate = ctx.radgrad([(0, hi, 0.55), (0.6, hi, 0.22), (1, hi, 0)])
    f += '<ellipse cx="18" cy="-22" rx="30" ry="21" fill="%s"/>' % plate
    e1, e2 = (4, -29, 24, 19), (32.6, -31, 18.4, 16.6)
    halo = ctx.radgrad([(0, EYE_GLOW, 0.95), (0.45, EYE_GLOW, 0.4), (1, EYE_GLOW, 0)])
    for i, (x, y, w, h) in enumerate((e1, e2)):
        tilt = -8 if i == 0 else 6
        if mood in ('strain', 'dizzy'):
            f += '<path d="%s" fill="%s"/>' % (ell_d(x, y, w / 2, h / 2.6, tilt), VOID)
            if mood == 'strain':
                f += squeeze(x, y, h * 0.8, EYE, flip=i == 1, w=1.8)
            else:
                f += swirl_eye(x, y, h * 0.42, EYE, 1.4)
            continue
        if mood == 'shock':
            f += '<path d="%s" fill="%s"/>' % (ell_d(x, y - 1, w * 0.6, h * 0.72), VOID)
            f += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="none" stroke="%s" stroke-width="1.6"/>' % (x, y - 1, h * 0.46, EYE)
            f += dot(x, y - 1, 1.6, '#ffffff')
            continue
        # an almond socket, cut flat on top when he glares or roars
        s = ell_d(x, y, w / 2, h / 2, tilt)
        f += '<path d="%s" fill="%s"/>' % (s, VOID)
        if mood in ('glare', 'roar'):
            k = 1 if i == 0 else -1
            f += '<path d="M%.1f %.1f L%.1f %.1f L%.1f %.1f Z" fill="%s"/>' % (
                x - w * 0.62, y - h * 0.7, x + w * 0.62, y - h * 0.7 + k * h * 0.5, x - w * 0.62, y - h * 0.05 + (0 if k > 0 else h * 0.2), base)
        if mood == 'shh':
            f += '<path d="M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z" fill="%s"/>' % (
                x - w * 0.62, y - h * 0.7, x + w * 0.62, y - h * 0.7, x + w * 0.62, y + h * 0.02, x - w * 0.62, y + h * 0.02, base)
            f += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (x - w * 0.5, y + h * 0.02, x, y + h * 0.18, x + w * 0.5, y + h * 0.02), L, 1.2)
        ix, iy = x + w * 0.12, y + (h * 0.16 if mood == 'shh' else h * 0.04)
        r = (4.2 if mood != 'glare' else 4.6) * (1 if i == 0 else 0.86)
        f += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s"/>' % (ix, iy, r * 3.2, halo)
        f += dot(ix, iy, r, EYE) + dot(ix - r * 0.3, iy - r * 0.35, r * 0.34, '#ffffff')
        f += '<path d="%s" fill="none" stroke="%s" stroke-width="1" opacity="0.8"/>' % (ell_d(x, y, w / 2 + 0.6, h / 2 + 0.6, tilt), hi)
    # the mouth: pure black
    mx, my = 20, -11
    if mood == 'roar':
        m = 'M%.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f Z' % (mx - 17, my - 3, mx, my - 7, mx + 17, my - 4.6, mx + 2, my + 15, mx - 17, my - 3)
    elif mood == 'strain':
        m = 'M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (mx - 13, my - 2, mx + 13, my - 3.8, mx + 12, my + 2.4, mx - 12, my + 2.6)
    elif mood in ('shock', 'dizzy'):
        m = ell_d(mx, my, 5.6 if mood == 'shock' else 7, 7 if mood == 'shock' else 9.4)
    elif mood == 'shh':
        m = ell_d(mx - 1, my - 1, 4, 3.2)
    else:
        m = 'M%.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f Z' % (mx - 15, my - 2, mx, my - 5, mx + 15, my - 3, mx, my + 6.4, mx - 15, my - 2)
    f += '<path d="%s" fill="none" stroke="%s" stroke-width="3.2" stroke-linejoin="round" opacity="0.95"/>' % (m, hi)
    f += '<path d="%s" fill="%s"/>' % (m, VOID)
    if mood == 'strain':
        f += line('M%.1f %.1f L%.1f %.1f M%.1f %.1f L%.1f %.1f' % (mx - 4, my - 2.6, mx - 4, my + 2, mx + 4, my - 3, mx + 4, my + 1.8), hi, 1.0)
    hl = (line('M-40 -12 C-34 -30 -18 -52 -10 -66', hi, 3.2, op=0.9)
          + line('M-30 -14 C-26 -26 -18 -40 -12 -50', hi, 1.2, op=0.6)
          + spec(-12, -60, 2.6, 5, rot=30, op=0.35))
    P = [Part('fill', pth(cone), fill=base, shade=shade, off=(-6, -3), over=f, hl=hl)]
    # the knob on its little neck
    P.append(Part('fill', pth('M-4.4 -71 L4.4 -71 L3.6 -76 L-3.6 -76 Z'), fill=base, shade=shade, off=(-1, 0)))
    P.append(Part('fill', pth(ell_d(0, -81, 7.2, 7)), fill=base, shade=shade, off=(-1.6, -1.8),
                  hl=spec(-2.6, -84, 2.2, 1.4, rot=-30, op=0.6, col=hi)))
    fx = ''
    if smoke:
        fx += smoke_curl(0, -90)
    return P, fx


def smoke_curl(x, y, k=1.0, op=0.75):
    """A thin curl of smoke rising from (x, y)."""
    d = 'M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f' % (
        x, y, x - 8 * k, y - 8 * k, x + 8 * k, y - 16 * k, x + 2 * k, y - 24 * k,
        x - 4 * k, y - 31 * k, x + 10 * k, y - 36 * k, x + 6 * k, y - 46 * k,
        x + 3 * k, y - 52 * k, x + 12 * k, y - 54 * k, x + 13 * k, y - 60 * k)
    return (line(d, L, 4.2 * k, op=0.35 * op) + line(d, SMOKE, 2.6 * k, op=op)
            + '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s" opacity="%.2f"/>' % (x + 13 * k, y - 62 * k, 2.2 * k, SMOKE, op * 0.7))


# ================================================================ the cassock

CASSOCK_D = ('M172 238 C181 233.6 207 233.6 216 238 C223 242 227 252 229 264 C234 296 240 326 243 352 L237 366 L230 355 '
             'L222 367 L214 356 L206 368 L198 357 L190 368 L182 357 L174 367 L166 356 L159 366 L152 355 L146 364 L145 350 '
             'C148 324 154 296 159 264 C161 252 165 242 172 238 Z')
COLLAR_D = 'M168 240 C178 234.6 210 234.6 220 240 L219.4 246.6 C209 242 179 242 168.6 246.6 Z'


def body_fn(dx, sy, lift=0.0):
    """The lean: points shift by dx at the shoulders (y 236), none at the hem;
    sy squashes toward the ground; lift raises the whole body (hovering)."""
    def f(x, y):
        t = (368 - y) / 132.0
        return x + dx * t, 368 - (368 - y) * sy - lift
    return f


def cassock(dx, sy, lift=0.0, lit=False, smoky=True, fn=None):
    """The cassock, bent by body_fn(dx, sy, lift), or by fn(x, y) if given."""
    f = fn or body_fn(dx, sy, lift)
    base, shade, hi = (CASSOCK, CASSOCK_SH, CASSOCK_HI) if not lit else ('#4a3e62', '#302842', '#8a7aa8')
    folds = line(tp('M174 262 Q168 300 163 350 M204 266 Q211 306 218 352 M186 300 Q186 330 184 356', f), L, 1.6, op=0.7)
    folds += line(tp('M178 266 Q174 300 170 340 M228 290 Q233 318 237 344', f), hi, 1.6, op=0.8)
    # a row of tiny buttons down the front, and a cord at the waist
    btn = ''.join('<circle cx="%.1f" cy="%.1f" r="1.6" fill="%s" stroke="%s" stroke-width="0.8"/>' % (
        f(x, y) + (mix(BRASS, base, 0.35), L)) for x, y in ((208, 252), (209.4, 262), (210.8, 272), (212.2, 282), (213.6, 292)))
    cord = tp('M160 298 Q196 308 234 296', f)
    btn += line(cord, L, 4.4) + line(cord, '#6a6282' if not lit else '#a89cc8', 2.2)
    kx, ky = f(220, 302)
    tails = tp('M220 302 Q218 318 214 330 M221 302 Q226 316 227 324', f)
    btn += line(tails, L, 3.8) + line(tails, '#6a6282' if not lit else '#a89cc8', 1.8)
    btn += '<circle cx="%.1f" cy="%.1f" r="3" fill="#6a6282" stroke="%s" stroke-width="%.1f"/>' % (kx, ky, L, IN())
    # rents in the cloth that show the dark inside him
    holes = ''.join('<path d="%s" fill="%s"/>' % (tp(d, f), VOID) for d in (
        'M168 330 L172 322 L175 331 L171 336 Z', 'M224 318 L227 312 L229 320 Z', 'M198 340 L202 333 L205 342 Z'))
    P = [Part('fill', pth(tp(CASSOCK_D, f)), fill=base, shade=shade, off=(-5, -3), over=folds + holes + btn,
              hl=line(tp('M166 250 Q157 290 152 330', f), hi, 3, op=0.85)),
         Part('fill', pth(tp(COLLAR_D, f)), fill='#d6d0e4' if not lit else '#ffffff', shade='#a09ab8', off=(-2, -1),
              lw=1.2, over='<path d="%s" fill="%s"/>' % (tp('M176 239.4 C186 236.4 202 236.4 212 239.4 C202 241 186 241 176 239.4 Z', f), VOID))]
    under = ''
    if smoky:
        under = hem_smoke(f)
    return P, under


def hem_smoke(f, trail=0.0):
    """Soft smoke pooling round the hem (no outline: it's what he's made of)."""
    s = ''
    for x, y, r, op in ((154, 366, 12, 0.35), (172, 370, 10, 0.3), (196, 371, 12, 0.32), (220, 370, 10, 0.3),
                        (238, 366, 11, 0.32), (142, 356, 7, 0.28), (250, 356, 7, 0.28)):
        px, py = f(x, y - 4)
        s += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s" opacity="%.2f"/>' % (px - trail, min(py + 4, 372 - r * 0.5), r, SMOKE, op)
    return s


# ================================================================ arms and hands

def sleeve(S, E, W, lit=False):
    """A thin ragged sleeve from the shoulder S through the elbow E to the wrist W."""
    base = CASSOCK if not lit else '#4a3e62'
    d = 'M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (S[0], S[1], E[0], E[1], W[0], W[1])
    ang = math.degrees(math.atan2(W[1] - E[1], W[0] - E[0]))
    cuff = place([Part('fill', pth('M-2 -8.4 L6 -9.6 L4.4 -4 L8.6 -1 L4.6 2 L7.8 6.6 L-1 8.4 Z'), fill=base,
                       shade=CASSOCK_SH, off=(-1, -1))], 'translate(%.1f %.1f) rotate(%.1f)' % (W[0], W[1], ang))
    return [Part('limb', pth(d), width=10, fill=base, over=line(d, CASSOCK_HI, 1.4, op=0.5))] + cuff


def hand(x, y, ang, pose='grip', lit=False):
    """A long thin grey hand at the wrist (x, y), fingers toward ang degrees.
    pose: grip (curled round a pole), open (splayed), hang (limp, curling),
    shh (index finger raised)."""
    base, shade = (HAND, HAND_SH) if not lit else ('#c4c0d4', '#9a96ac')
    t = 'translate(%.1f %.1f) rotate(%.1f)' % (x, y, ang)
    P = [Part('fill', pth(ell_d(6, 0, 7, 5.4)), fill=base, shade=shade, off=(-1.2, -1.2))]
    if pose == 'grip':
        for fy in (-3.6, 0, 3.6):
            P.append(Part('limb', pth('M11 %.1f Q17 %.1f 16 %.1f Q14 %.1f 11 %.1f' % (fy - 1, fy - 2, fy + 2.4, fy + 4, fy + 3.4)),
                          width=2.2, fill=base))
        P.append(Part('limb', pth('M6 -4.4 Q11 -8 15.6 -6'), width=2.2, fill=base))
    elif pose == 'open':
        for a, ln in ((-40, 17), (-14, 20), (12, 19), (38, 15)):
            ex, ey = 10 + ln * math.cos(math.radians(a)), ln * math.sin(math.radians(a))
            mx, my = 10 + ln * 0.55 * math.cos(math.radians(a - 8)), ln * 0.55 * math.sin(math.radians(a - 8))
            P.append(Part('limb', pth('M10 0 Q%.1f %.1f %.1f %.1f' % (mx, my, ex, ey)), width=2.2, fill=base))
    elif pose == 'hang':
        for a, ln in ((-18, 16), (0, 19), (16, 17), (32, 13)):
            ex, ey = 10 + ln * math.cos(math.radians(a)), ln * math.sin(math.radians(a))
            P.append(Part('limb', pth('M10 0 Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f' % (
                10 + ln * 0.6 * math.cos(math.radians(a)), ln * 0.6 * math.sin(math.radians(a)), ex, ey,
                ex + 1, ey + 3, ex - 2.4, ey + 4.4)), width=2.2, fill=base))
    else:   # shh
        P.append(Part('limb', pth('M10 -1 L27 -2.4'), width=2.4, fill=base))
        for fy in (1.6, 4.6):
            P.append(Part('limb', pth('M10 %.1f Q15 %.1f 14 %.1f' % (fy, fy + 1, fy + 4)), width=2.2, fill=base))
        P.append(Part('limb', pth('M6 -4 Q9 -7 12 -5'), width=2.2, fill=base))
    return place(P, t)


# ================================================================ the snuffer pole and its bell

def snuff_bell(glow_rim=False, lit=False):
    """The snuffer bell, local to the point it hangs from (0, 0): a brass
    cone 50 wide and 50 tall, a dark mouth below. Returns parts."""
    body = 'M-6 8 C-10 16 -22 34 -25 44 Q0 50.4 25 44 C22 34 10 16 6 8 Z'
    f = line('M-21.6 38 Q0 43.4 21.6 38', BRASS_HI, 1.6, op=0.9) + line('M-22.8 40.6 Q0 46 22.8 40.6', BRASS_LINE, 1.0, op=0.7)
    f += line('M-9 16 Q0 18 9 16', BRASS_HI, 1.2, op=0.8)
    hl = line('M-14 38 C-11 28 -7 18 -4.6 11', '#fff0c0', 2.2, op=0.9)
    P = [Part('fill', pth('M-2 0 L2 0 L2 5 L-2 5 Z'), fill=BRASS_SH, shade=BRASS_SH, off=(0, 0), line=BRASS_LINE),
         Part('fill', pth(ell_d(0, 6.4, 4.6, 3)), fill=BRASS, shade=BRASS_SH, off=(-0.8, -0.8), line=BRASS_LINE),
         Part('fill', pth(body), fill=BRASS, shade=BRASS_SH, off=(-4, -2), line=BRASS_LINE, over=f, hl=hl)]
    mouth = '<path d="%s" fill="%s" stroke="%s" stroke-width="1.2"/>' % (ell_d(0, 45.6, 24.4, 4), VOID, BRASS_LINE)
    if glow_rim:
        mouth += '<path d="%s" fill="none" stroke="%s" stroke-width="3.4"/>' % (ell_d(0, 45.6, 25, 4.4), EMBER)
        mouth += '<path d="%s" fill="none" stroke="#fff0c8" stroke-width="1.2"/>' % ell_d(0, 45.6, 25, 4.4)
    P[-1].over += mouth
    return P


def bell_glow(ctx, x, y, r=40, squash=0.55):
    g = ctx.radgrad([(0, EMBER, 0.55), (0.5, EMBER, 0.2), (1, EMBER, 0)])
    return '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s"/>' % (x, y, r, r * squash, g)


def pole(H, ang, f, crook=1, bell_rot=0.0, glow_rim=False, bell_at=None, tip_at=None, length=POLE_LEN):
    """The brass pole gripped at H, pointing ang degrees from straight up
    (clockwise), f of its length behind the grip, its crook curling to the
    right of the pole (crook = -1 curls left). The bell hangs off the crook's
    tip, turned bell_rot (0 = hanging straight down), or at bell_at.
    tip_at places the crook's tip there instead (H is then ignored; the
    grip is f along the pole from its butt). length is the pole's drawn
    length (shorter when it's foreshortened, pointing into the picture).
    info['at'](k) is the point k along the pole from the butt, for the hands.
    Returns (parts behind the hands, bell parts, info)."""
    a = math.radians(ang)
    u = (math.sin(a), -math.cos(a))
    n = (math.cos(a) * crook, math.sin(a) * crook)
    if tip_at:
        T = (tip_at[0] - n[0] * 27, tip_at[1] - n[1] * 27)
        B = (T[0] - u[0] * length, T[1] - u[1] * length)
    else:
        T = (H[0] + u[0] * length * (1 - f), H[1] + u[1] * length * (1 - f))
        B = (H[0] - u[0] * length * f, H[1] - u[1] * length * f)

    def p(base, du, dn):
        return (base[0] + u[0] * du + n[0] * dn, base[1] + u[1] * du + n[1] * dn)
    c1, c2, tip = p(T, 16, 2), p(T, 16, 26), p(T, 0, 27)
    shaft = 'M%.1f %.1f L%.1f %.1f' % (B[0], B[1], T[0], T[1])
    crook_d = 'M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f' % (T[0], T[1], c1[0], c1[1], c2[0], c2[1], tip[0], tip[1])
    rings = ''
    for k in (0.12, 0.5, 0.88):
        x, y = B[0] + (T[0] - B[0]) * k, B[1] + (T[1] - B[1]) * k
        rings += line('M%.1f %.1f L%.1f %.1f' % (x - n[0] * 3.4, y - n[1] * 3.4, x + n[0] * 3.4, y + n[1] * 3.4), BRASS_LINE, 3.8, cap='butt')
        rings += line('M%.1f %.1f L%.1f %.1f' % (x - n[0] * 3.4, y - n[1] * 3.4, x + n[0] * 3.4, y + n[1] * 3.4), BRASS_HI, 2.2, cap='butt')
    hi = line('M%.1f %.1f L%.1f %.1f' % (B[0] - n[0] * 1.2 + u[0] * 6, B[1] - n[1] * 1.2 + u[1] * 6,
                                         T[0] - n[0] * 1.2 - u[0] * 4, T[1] - n[1] * 1.2 - u[1] * 4), '#ffe6a8', 1.1, op=0.8)
    P = [Part('limb', pth(shaft), width=5, fill=BRASS, line=BRASS_LINE, over=hi + rings),
         Part('limb', pth(crook_d), width=4.6, fill=BRASS, line=BRASS_LINE),
         Part('fill', pth(ell_d(B[0], B[1], 3.8, 3.8)), fill=BRASS_SH, shade=BRASS_SH, off=(0, 0), line=BRASS_LINE)]
    hang = bell_at or (tip[0] + n[0] * 1.5, tip[1] + 3)
    bell = place(snuff_bell(glow_rim), 'translate(%.1f %.1f) rotate(%.1f)' % (hang[0], hang[1], bell_rot))
    mouth = rot_pt(hang[0], hang[1] + 45.6, hang[0], hang[1], bell_rot)
    return P, bell, dict(top=T, butt=B, tip=tip, hang=hang, mouth=mouth,
                         at=lambda k: (B[0] + u[0] * length * k, B[1] + u[1] * length * k))


# ================================================================ the frames

def neck(dx, sy, lift=0.0):
    """Where the head's rim centre sits for a lean."""
    return body_fn(dx, sy, lift)(194, 238)


HEAD_PT = {}


def head_at(ctx, pos, rot, mood, lit=False, smoke=True, scale=1.0):
    """The head placed with its rim centre at pos, turned rot; the face's
    centre (the hit target) is left in HEAD_PT['face']."""
    parts, fx = cone_head(ctx, mood, lit=lit, smoke=smoke)
    HEAD_PT['face'] = rot_pt(pos[0] + 18 * scale, pos[1] - 31 * scale, pos[0], pos[1], rot)
    t = 'translate(%.1f %.1f) rotate(%.1f) scale(%.2f) translate(0 -9)' % (pos[0], pos[1], rot, scale)
    void = '<path d="%s" fill="%s"/>' % (ell_d(0, 9, 30, 7.4), VOID)
    parts[0].under = gx(void, t)
    return place(parts, t), gx(fx, t)


# ================================================================ vendored from boss2.py (W6b): end


# ================================================================ the story's Snuffer

# The figure frame (256, feet at (128, 244)) holds the fight's 384 frame at
# FIG_K figure units per Snuffer unit. At h FIG_H one Snuffer unit is 0.9375
# panel units, as one unit of Wick's frame is for the actor (h 120), so the
# Snuffer stands on a panel at the size he fights at, beside Waxby.
FIG_K = 0.6
FIG_H = 256 * (120.0 / 128.0) / FIG_K
EYE_R = 4.2          # cone_head's pinprick eye radius (the far eye is 0.86 of it)


def to_fig(p):
    """A Snuffer-frame point in the figure frame."""
    return (round(128 + (p[0] - FOOT[0]) * FIG_K, 2), round(244 + (p[1] - FOOT[1]) * FIG_K, 2))


def fig_body(body):
    """Snuffer-frame drawing placed in the figure frame."""
    return '<g transform="translate(128 244) scale(%.4f) translate(%d %d)">%s</g>' % (FIG_K, -FOOT[0], -FOOT[1], body)


def eye_points(pos, rot, mood='idle', scale=1.0, mirror=False):
    """The pinprick eyes' centres of a head placed at pos (its rim centre)
    turned rot, as cone_head draws them."""
    pts = []
    for x, y, w, h in ((4, -29, 24, 19), (32.6, -31, 18.4, 16.6)):
        ix, iy = x + w * 0.12, y + (h * 0.16 if mood == 'shh' else h * 0.04)
        lx, ly = ix * scale * (-1 if mirror else 1), (iy - 9) * scale
        pts.append(rot_pt(pos[0] + lx, pos[1] + ly, pos[0], pos[1], rot))
    return pts


def render(ctx, parts):
    with weights(CHAR_WEIGHTS):
        return paint(ctx, parts, PAL)


def stand(ctx):
    """Standing with the pole upright and the bell hanging off its crook, the
    fight's idle, his head tipped a little down at whoever he's talking to.
    Returns (drawing, eye points), Snuffer frame."""
    dx, sy = 0, 1
    f = body_fn(dx, sy)
    body, under = cassock(dx, sy)
    pp, bell, info = pole((262, 292), 0, 0.24)
    nk, rot = neck(dx, sy), 6
    head, hfx = head_at(ctx, nk, rot, 'idle')
    back = sleeve(f(170, 250), (160, 278), (156, 300)) + hand(156, 301, 96, 'hang')
    front = sleeve(f(218, 250), (240, 272), (252, 290)) + hand(252, 291, 8, 'grip')
    return under + render(ctx, back + body + pp + bell + head + front) + hfx, eye_points(nk, rot)


def reach(ctx):
    """Reaching the pole up and forward in both hands, the bell hanging off
    the crook over a candle ahead of him, his head tipped up to watch it go
    out. Returns (drawing, eye points, the bell's mouth), Snuffer frame."""
    dx, sy = 8, 1
    f = body_fn(dx, sy)
    body, under = cassock(dx, sy)
    ang = 30.0
    pp, bell, info = pole((190, 366), ang, 0.0)
    gx_, gy_ = 8.7, 5.0                      # a gripping wrist sits this far off the pole
    g1, g2 = info['at'](0.45), info['at'](0.62)
    nk, rot = neck(dx, sy), -8
    head, hfx = head_at(ctx, nk, rot, 'idle')
    back = sleeve(f(170, 250), (214, 270), (g1[0] - gx_, g1[1] - gy_)) + hand(g1[0] - gx_, g1[1] - gy_, ang, 'grip')
    front = sleeve(f(218, 250), (256, 236), (g2[0] - gx_, g2[1] - gy_)) + hand(g2[0] - gx_, g2[1] - gy_, ang, 'grip')
    art = under + render(ctx, back + body + pp + head + bell + front) + hfx
    return art, eye_points(nk, rot), info['mouth']


# the crack that split the cone, in head_at's placed frame (rim centre at
# (0, 0), the knob up at y -90): down between the eyes and through the mouth
CRACK = [(0, -104), (5, -86), (-2, -74), (9, -62), (6, -52), (20, -44), (15, -32), (24, -24), (17, -14), (23, -4), (19, 8)]


def broken(ctx):
    """The cone split in two where he fell: each half tipped over onto its
    outer side (one of the fight's dizzy eyes in each), a last curl of smoke
    rising from the gap, and the snuffer bell toppled a little way off, a
    snapped stub of the pole still on it. Returns the drawing, Snuffer frame."""
    parts, _ = head_at(ctx, (0, 0), 0, 'dizzy', smoke=False)
    head = render(ctx, parts)
    edge = 'M' + ' L'.join('%.1f %.1f' % p for p in CRACK)
    cut = ' L'.join('%.1f %.1f' % p for p in CRACK)
    # the broken edge: ink, and the iron's pale thickness just inside it
    crack = line(edge, L, 4.4) + line(edge, IRON_HI, 1.4, op=0.9)
    fx = FOOT[0] + 40            # clear of Hollin, who sits just left of the cone's anchor
    out = '<ellipse cx="%.1f" cy="368" rx="104" ry="7" fill="#07040a" opacity="0.32"/>' % (fx + 36)
    # (clip, crack nudge, the rim corner it pivots on, where that corner lands, tip)
    for clip, nudge, corner, land, ang in (('M-80 -110 L%s L-80 12 Z' % cut, -1.6, (-50, -11), (fx - 60, 368), -15),
                                           ('M80 -110 L%s L80 12 Z' % cut, 1.6, (50, -11), (fx + 76, 368), 17)):
        half = '<g clip-path="%s">%s%s</g>' % (ctx.clip('<path d="%s"/>' % clip), head, gx(crack, 'translate(%.1f 0)' % nudge))
        out += gx(half, 'translate(%.1f %.1f) rotate(%.1f) translate(%.1f %.1f)' % (land[0], land[1], ang, -corner[0], -corner[1]))
    # the bell on its side, mouth toward him, with its crook and a stub of pole
    pp, bell, _ = pole((fx + 110, 348), -100, 0.0, crook=1, length=40)
    out += render(ctx, pp + place(snuff_bell(), 'translate(%.1f 344) rotate(96)' % (fx + 134)))
    out += smoke_curl(fx + 6, 364, 1.3, 0.8) + smoke_curl(fx + 16, 360, 0.8, 0.55)
    return out


def portrait_head(ctx, mood, face, s, lw, rot=0.0):
    """The head for a portrait, mirrored to face left (NPCs sit on the box's
    right and turn toward its middle), its face centred on face at scale s
    and turned rot, drawn with line weights lw (so its lines match the other
    portraits'). Returns (parts drawing, fx drawing, the transform)."""
    parts, fx = cone_head(ctx, mood, smoke=False)
    ox, oy = rot_pt(-18 * s, -31 * s, 0, 0, rot)          # the face from the rim centre
    px, py = face[0] - ox, face[1] - oy
    t = 'translate(%.2f %.2f) rotate(%.1f) scale(%.3f %.3f) translate(0 -9)' % (px, py, rot, -s, s)
    parts[0].under = gx('<path d="%s" fill="%s"/>' % (ell_d(0, 9, 30, 7.4), VOID), t)
    with weights(lw):
        art = paint(ctx, place(parts, t), PAL)
    return art, gx(fx, t), t
