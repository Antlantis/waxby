"""World 2's boss: The Snuffer, the Hollow Wick. A keeper whose flame went
out: a tall ragged cassock with nothing inside, a black iron snuffer cone
for a head (a pure black mouth, two cold pinprick eyes, a knob that still
curls smoke) and long thin grey hands on a brass snuffer pole with a bell
hung from its crook. He is solid only in light; the engine may fade him
while he's hollow, so every frame is drawn opaque with smoke at the hem.

Frame: viewBox 0 0 384 384 at 768 px (2 units = 1 world px, like every
character), facing right, feet (the hem) at (192, 368). He stands about
220 units (110 px, 2.2 x Waxby) tall; the cone is 40% of that; the pole is
1.4 x his height.

  snuffer_idle     standing, the pole upright, its bell hanging off the crook
  snuffer_raise    the tell: pole heaved up behind his head, the bell's rim glowing
  snuffer_slam     the bell slammed over the floor ahead (mouth on y 368)
  snuffer_stuck    the bell wedged in the floor; hunched, head LOW, tugging (solid)
  snuffer_glide    drifting forward, hem streaming smoke
  snuffer_snuff    "shhh": a finger to his mouth, the bell lowered over a flame
  snuffer_lunge    laid flat, diving headfirst at head height (28-80 px up), the
                   cone's tip leading, the bell blown back off the trailing crook
  snuffer_curdled  caught in the light: lit up, solid, shocked
  snuffer_die      coming apart into smoke, the pole falling away

POINTS lists per frame (frame units): head (the face, his hit target),
bell_mouth, slam_centre and cone_tip, for the engine's hit zones and lights;
points_snuffer.json also gives the lunge's body box (LUNGE_BOX) in frame
units and as the Rect2 snuffer_boss.gd should use.
Run on its own: python3 tools/art/boss2.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import kit
from kit import Part, pth
from common import Ctx, RIM, svg, paint, line, dot, sweat, swirl_eye, squeeze, spec, sparkle, star4, mix, gx, IN
from boss import tp, ell_d, place, rot_pt

FRAMES = ['idle', 'raise', 'slam', 'stuck', 'glide', 'snuff', 'lunge', 'curdled', 'die']

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

POINTS = {}


def mark(frame, **pts):
    POINTS.setdefault(frame, {}).update({k: tuple(round(c, 1) for c in v) for k, v in pts.items()})


def motion(d, w=2.0, op=0.9):
    return line(d, L, w + 1.8, op=0.6) + line(d, '#ffffff', w, op=op)


# ================================================================ the cone head

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


# The lunge: the upright figure (cassock streamlined by lunge_fn) turned
# LUNGE_ROT about LUNGE_MID and set down on LUNGE_CENTRE, the head tipped
# LUNGE_HEAD back so the cone's point leads a little high and the face looks
# ahead. The engine hovers him HOVER (6 px) off the floor and hits with the
# box LUNGE_BOX (frame units: x, y, w, h); world px from the anchor are
# (x - 192) / 2 across and (368 - y) / 2 + 6 up.
LUNGE_ROT, LUNGE_HEAD = 90.0, -22.0
LUNGE_MID, LUNGE_CENTRE = (194.0, 256.0), (178.0, 274.0)
LUNGE_POLE = (-86.0, 0.66, 56.0, 165.0)   # angle, share ahead of the grip, bell turn, drawn length (foreshortened)
LUNGE_BOX = (92, 220, 200, 104)           # the body, tip to hem (not the trailing bell and smoke): x, y, w, h
HOVER = 6                                 # snuffer_boss.gd's HOVER: how far off the floor his feet point floats


def lunge_rect():
    """LUNGE_BOX in world px: x from the anchor, and the height band above the floor."""
    x, y, w, h = LUNGE_BOX
    return dict(x=(x - FOOT[0]) / 2.0, w=w / 2.0, top=(FOOT[1] - y) / 2.0 + HOVER, bottom=(FOOT[1] - y - h) / 2.0 + HOVER)


def lunge_fn(sy=0.80, taper=0.32, tails=1.4):
    """The cassock streamlined for the dive: shortened by sy and narrowed
    toward the hem, so the whole figure tapers back from the cone's rim; the
    hem's ragged points stretch back into streaming tails."""
    def f(x, y):
        k = min(max((y - 236.0) / 132.0, 0.0), 1.0)
        # each point streams back its own length, drooping a little
        e = max(y - 350.0, 0.0) * tails * (0.75 + 0.55 * math.sin(x * 0.23 + 1.0))
        return 194 + (x - 194) * (1 - taper * k) + e * 0.22, 236 + (y - 236) * sy + e
    return f


def lunge_xf():
    return 'translate(%.1f %.1f) rotate(%.1f) translate(%.1f %.1f)' % (
        LUNGE_CENTRE[0], LUNGE_CENTRE[1], LUNGE_ROT, -LUNGE_MID[0], -LUNGE_MID[1])


def lunge_pt(p):
    """An upright-figure point where the lunge puts it."""
    x, y = rot_pt(p[0], p[1], LUNGE_MID[0], LUNGE_MID[1], LUNGE_ROT)
    return x - LUNGE_MID[0] + LUNGE_CENTRE[0], y - LUNGE_MID[1] + LUNGE_CENTRE[1]


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


def frame(name):
    ctx = Ctx('sn' + name[:3])
    lit = name == 'curdled'
    solid = name in ('stuck', 'curdled')
    back, mid, front, under, over = [], [], [], '', ''
    fid = 'snuffer_' + name
    if name == 'idle':
        dx, sy, lift = 0, 1, 0
        f = body_fn(dx, sy)
        body, under = cassock(dx, sy)
        pp, bell, info = pole((262, 292), 0, 0.24)
        head, hfx = head_at(ctx, neck(dx, sy), 0, 'idle')
        back += sleeve(f(170, 250), (160, 278), (156, 300)) + hand(156, 301, 96, 'hang')
        front_arm = sleeve(f(218, 250), (240, 272), (252, 290)) + hand(252, 291, 8, 'grip')
        parts = back + body + pp + bell + head + front_arm
        over = hfx
        mark(fid, head=HEAD_PT['face'], bell_mouth=info['mouth'])
    elif name == 'raise':
        dx, sy = -14, 1
        f = body_fn(dx, sy)
        body, under = cassock(dx, sy)
        pp, bell, info = pole((226, 186), -40, 0.4, bell_rot=22, glow_rim=True)
        hx, hy = neck(dx, sy)
        head, hfx = head_at(ctx, (hx, hy), -8, 'glare')
        back += sleeve(f(170, 250), (180, 220), (210, 194)) + hand(210, 194, -60, 'grip')
        front_arm = sleeve(f(218, 250), (238, 226), (232, 190)) + hand(232, 190, -110, 'grip')
        parts = back + pp + body + head + front_arm + bell
        over = hfx + bell_glow(ctx, info['mouth'][0], info['mouth'][1], 34)
        over += motion('M262 196 L280 186 M266 212 L286 208 M110 250 L94 244 M112 266 L94 266', 2)
        mark(fid, head=HEAD_PT['face'], bell_mouth=info['mouth'])
    elif name == 'slam':
        dx, sy = 26, 0.94
        f = body_fn(dx, sy)
        body, under = cassock(dx, sy)
        bell_pos = (322, 320)
        pp, bell, info = pole(None, 118, 0, crook=1, tip_at=bell_pos, bell_at=bell_pos, glow_rim=True)
        hx, hy = neck(dx, sy)
        head, hfx = head_at(ctx, (hx, hy), 14, 'roar')
        g1, g2 = info['at'](0.62), info['at'](0.74)
        back += sleeve(f(172, 252), (214, 286), (g1[0] - 8, g1[1] - 4)) + hand(g1[0] - 8, g1[1] - 4, 28, 'grip')
        front_arm = sleeve(f(220, 252), (246, 272), (g2[0] - 8, g2[1] - 4)) + hand(g2[0] - 8, g2[1] - 4, 28, 'grip')
        parts = back + body + pp + head + bell + front_arm
        over = hfx + impact(bell_pos[0], 366) + bell_glow(ctx, bell_pos[0], 362, 44, 0.36)
        mark(fid, head=HEAD_PT['face'], bell_mouth=(bell_pos[0], 366), slam_centre=(bell_pos[0], 368))
    elif name == 'stuck':
        dx, sy = 40, 0.8
        f = body_fn(dx, sy)
        body, under = cassock(dx, sy, smoky=False)
        bell_pos = (318, 322)
        pp, bell, info = pole(None, 112, 0, crook=1, tip_at=bell_pos, bell_at=bell_pos, bell_rot=-6)
        hx, hy = neck(dx, sy)
        head, hfx = head_at(ctx, (hx + 6, hy + 16), 30, 'strain', smoke=False)
        g1, g2 = info['at'](0.66), info['at'](0.76)
        back += sleeve(f(174, 256), (222, 292), (g1[0] - 8, g1[1] - 4)) + hand(g1[0] - 8, g1[1] - 4, 22, 'grip')
        front_arm = sleeve(f(222, 256), (262, 276), (g2[0] - 8, g2[1] - 4)) + hand(g2[0] - 8, g2[1] - 4, 22, 'grip')
        parts = back + body + pp + bell + head + front_arm
        over = (cracks(318, 1.1) + rubble(318) + sweat(300, 196, 1.6, 24) + sweat(186, 214, 1.2, -20)
                + motion('M346 290 L360 280 M352 304 L370 300 M120 300 L104 294', 2)
                + smoke_curl(hx + 6 + 34 * math.sin(math.radians(30)) * 2.4, hy + 16 - 81 * math.cos(math.radians(30)), 0.6, 0.45))
        mark(fid, head=HEAD_PT['face'], bell_mouth=(318, 368))
    elif name == 'glide':
        dx, sy, lift = 34, 0.96, 12
        f = body_fn(dx, sy, lift)
        body, under = cassock(dx, sy, lift)
        under = hem_trail(f)
        pp, bell, info = pole((258, 292), -22, 0.24, bell_rot=34)
        hx, hy = neck(dx, sy, lift)
        head, hfx = head_at(ctx, (hx, hy), 12, 'idle')
        back += sleeve(f(172, 252), (160, 282), (140, 300)) + hand(140, 300, 150, 'hang')
        front_arm = sleeve(f(220, 252), (246, 270), (254, 290)) + hand(254, 290, 20, 'grip')
        parts = back + pp + bell + body + head + front_arm
        over = hfx + motion('M104 250 L78 250 M100 280 L70 282 M110 312 L84 318', 1.8, 0.7)
        mark(fid, head=HEAD_PT['face'], bell_mouth=info['mouth'])
    elif name == 'snuff':
        dx, sy = 12, 1
        f = body_fn(dx, sy)
        body, under = cassock(dx, sy)
        hx, hy = neck(dx, sy)
        pp, bell, info = pole((248, 290), 72, 0.74, crook=-1, bell_rot=-4)
        head, hfx = head_at(ctx, (hx, hy), 4, 'shh')
        back += sleeve(f(172, 252), (214, 282), (246, 290)) + hand(246, 290, 10, 'grip')
        mx, my = rot_pt(hx + 20, hy - 10, hx, hy, 4)
        front_arm = sleeve(f(222, 252), (232, 270), (mx - 4, my + 20)) + hand(mx - 4, my + 20, -84, 'shh')
        parts = pp + back + body + bell + head + front_arm
        over = hfx + whisper(mx + 30, my - 26)
        mark(fid, head=HEAD_PT['face'], bell_mouth=info['mouth'])
    elif name == 'lunge':
        # Diving headfirst at head height, laid out flat like a thrown spear:
        # the cone's tip leads, the body is lifted clear of the floor (the
        # engine's lunge box is LUNGE_BOX), the cassock streams back narrowing
        # into smoke, and the pole rides along his far side, its crook
        # trailing and the bell blown back off it like a windsock, mouth open
        # to the rear (so nothing reads as an arrowhead aimed backwards).
        g = lunge_fn()
        body, _ = cassock(0, 1, smoky=False, fn=g)
        nk = g(194, 238)
        head, hfx = head_at(ctx, nk, LUNGE_HEAD, 'roar', smoke=False)
        face = lunge_pt(HEAD_PT['face'])
        tip = lunge_pt(rot_pt(nk[0], nk[1] - 9 - 88, nk[0], nk[1], LUNGE_HEAD))
        # the near arm swept back along his belly onto the pole, the far one behind him
        wf, wb = (222, 304), (182, 300)
        arm_b = sleeve(g(170, 250), (174, 280), wb) + hand(wb[0], wb[1], 94, 'grip')
        arm_f = sleeve(g(218, 250), (230, 278), wf) + hand(wf[0], wf[1], 96, 'grip')
        t = lunge_xf()
        figure = place(arm_b + body + head + arm_f, t)
        grip = lunge_pt((wf[0], wf[1] + 10))
        pp, bell, info = pole(grip, LUNGE_POLE[0], LUNGE_POLE[1], crook=1, bell_rot=LUNGE_POLE[2], length=LUNGE_POLE[3])
        parts = pp + bell + figure
        under = streak(ctx)
        over = gx(hfx, t) + lunge_lines('%s translate(%.1f %.1f) rotate(%.1f) translate(0 -9)' % (t, nk[0], nk[1], LUNGE_HEAD))
        mark(fid, head=face, cone_tip=tip, bell_mouth=info['mouth'])
    elif name == 'curdled':
        dx, sy = -6, 1
        f = body_fn(dx, sy)
        body, under = cassock(dx, sy, lit=True, smoky=False)
        pp, bell, info = pole((258, 250), 14, 0.3, bell_rot=-18)
        hx, hy = neck(dx, sy)
        head, hfx = head_at(ctx, (hx, hy - 6), -6, 'shock', lit=True)
        back += sleeve(f(170, 250), (146, 238), (126, 214), lit=True) + hand(126, 214, -140, 'open', lit=True)
        front_arm = sleeve(f(218, 250), (240, 252), (254, 252), lit=True) + hand(254, 252, -40, 'grip', lit=True)
        parts = back + pp + bell + body + head + front_arm
        over = hfx + sweat(262, 170, 1.6, 20) + sweat(140, 176, 1.2, -24)
        over += motion('M276 150 L292 134 M290 176 L312 170 M118 160 L100 146 M108 186 L88 182 M200 118 L200 98', 2.2)
        mark(fid, head=HEAD_PT['face'], bell_mouth=info['mouth'])
    else:   # die
        dx, sy = -20, 0.9
        f = body_fn(dx, sy)
        body, _ = cassock(dx, sy, smoky=False)
        hx, hy = neck(dx, sy)
        head, hfx = head_at(ctx, (hx - 8, hy - 18), -24, 'dizzy', smoke=False)
        back += sleeve(f(170, 252), (150, 226), (136, 196)) + hand(136, 196, -110, 'open')
        front_arm = sleeve(f(218, 252), (246, 230), (262, 204)) + hand(262, 204, -60, 'open')
        pp, bell, info = pole((318, 366 - POLE_LEN * 0.2), -12, 0.2, bell_rot=-26)
        parts = back + body + head + front_arm + pp + bell
        # the lower half coming apart into smoke
        under = ''
        over = dissolve(f) + smoke_curl(hx - 30, hy - 100, 1.1, 0.8) + smoke_curl(hx + 20, hy - 96, 0.8, 0.6)
        over += motion('M110 150 L96 134 M196 120 L196 100', 2.2, 0.8) + motion('M300 70 Q318 76 326 92', 2, 0.8)
        mark(fid, head=HEAD_PT['face'])
    rim = RIM
    if lit:
        # the curdle: a hard white flash round his whole silhouette
        old = kit.RIM_W
        kit.RIM_W = 7.0
        body_svg = paint(ctx, parts, dict(PAL, rim='#ffffff'))
        kit.RIM_W = old
        glow = ctx.radgrad([(0, '#fff2c8', 0.5), (0.6, '#ffd98a', 0.18), (1, '#ffd98a', 0)])
        under = '<ellipse cx="200" cy="250" rx="150" ry="150" fill="%s"/>' % glow + under
    else:
        body_svg = paint(ctx, parts, dict(PAL, rim=rim))
    return svg(ctx, under + body_svg + over, 384, 384)


def hem_trail(f):
    """Smoke streaming back from a hem that's gliding forward."""
    s = ''
    for x, y, r, op in ((120, 352, 14, 0.3), (96, 348, 11, 0.24), (74, 342, 8, 0.18), (150, 360, 12, 0.32),
                        (60, 334, 6, 0.14), (180, 362, 10, 0.3), (212, 360, 9, 0.28)):
        s += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s" opacity="%.2f"/>' % (x, y - 8, r, SMOKE, op)
    return s


def streak(ctx):
    """The lunge's glowing trail: a wedge of cold light fading out behind
    him, and the smoke his hem streams into (no outline: it's what he's made of)."""
    g = ctx.lingrad([(0, EYE_GLOW, 0), (1, EYE_GLOW, 0.42)], x1=0, y1=0, x2=1, y2=0)
    s = '<path d="M150 240 Q84 250 10 262 L10 288 Q84 300 150 310 Z" fill="%s"/>' % g
    for x, y, r, op in ((104, 256, 13, 0.34), (98, 288, 12, 0.32), (80, 272, 13, 0.3), (60, 260, 9, 0.24),
                        (54, 288, 8, 0.22), (36, 274, 7, 0.18), (20, 266, 5, 0.14), (118, 304, 8, 0.3), (120, 244, 8, 0.3)):
        s += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s" opacity="%.2f"/>' % (x, y, r, SMOKE, op)
    return s


def lunge_lines(head_t):
    """Speed lines along the lunge, trailing from his back and belly, and the
    air sliding over the cone's point (drawn in the head's own frame, head_t,
    so it hugs the cone's back; nothing is drawn ahead of the point)."""
    d = 'M150 230 L96 230 M176 318 L122 320 M64 242 L30 244'
    air = 'M-10 -90 Q-24 -82 -30 -62 M-22 -86 Q-34 -78 -38 -64'
    return motion(d, 2.0, 0.75) + gx(motion(air, 1.8, 0.9), head_t)


def whisper(x, y):
    """The 'shhh': three soft curls drifting from his mouth."""
    s = ''
    for i, (dx, dy, k) in enumerate(((0, 0, 1.0), (16, -10, 0.8), (30, -22, 0.6))):
        d = 'M%.1f %.1f q%.1f %.1f %.1f %.1f q%.1f %.1f %.1f %.1f' % (
            x + dx, y + dy, 6 * k, -6 * k, 12 * k, 0, 6 * k, 6 * k, 12 * k, 0)
        s += line(d, L, 3.6 * k, op=0.5) + line(d, '#e8e4f4', 2 * k, op=0.9)
    return s


def dissolve(f):
    """Puffs of smoke eating the cassock from the hem up."""
    s = ''
    pts = ((146, 360, 16), (172, 364, 14), (198, 366, 16), (224, 362, 14), (248, 356, 12), (160, 340, 12), (210, 342, 13),
           (236, 336, 10), (186, 330, 11), (140, 330, 9), (262, 334, 8), (120, 350, 8), (274, 352, 7))
    for x, y, r in pts:
        px, py = f(x, y)
        s += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s" stroke="%s" stroke-width="1.6" opacity="0.92"/>' % (
            px, min(py, 368 - r), r, mix(SMOKE, '#ffffff', 0.25), L)
    for x, y, r in ((110, 300, 4), (284, 306, 5), (96, 330, 3), (298, 330, 3.4), (130, 280, 3), (270, 280, 3.4)):
        s += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s" opacity="0.7"/>' % (x, y, r, SMOKE)
    return s


def impact(cx, y):
    """Dust and shock lines where the bell hits the floor."""
    s = cracks(cx, 1.2)
    for x, y0, r in ((cx - 38, y - 6, 7), (cx - 50, y - 3, 4.6), (cx - 30, y - 14, 4.2), (cx + 36, y - 8, 6.4),
                     (cx + 46, y - 2, 3.8), (cx + 30, y - 16, 3.6)):
        s += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="#e8dcc8" stroke="%s" stroke-width="1.4" opacity="0.95"/>' % (x, y0, r, L)
    s += motion('M%.1f %.1f L%.1f %.1f M%.1f %.1f L%.1f %.1f M%.1f %.1f L%.1f %.1f M%.1f %.1f L%.1f %.1f' % (
        cx - 36, y - 36, cx - 48, y - 46, cx - 40, y - 22, cx - 56, y - 26, cx + 34, y - 38, cx + 44, y - 50,
        cx + 40, y - 24, cx + 50, y - 30), 2.2)
    s += star4(cx, y - 52, 7, '#fff2c8', 0.95)
    return s


def cracks(cx, k):
    d = ('M%.1f 369 L%.1f 372 L%.1f 374 M%.1f 369 L%.1f 373 L%.1f 375 M%.1f 369 L%.1f 373 M%.1f 369 L%.1f 373 L%.1f 374' % (
        cx - 30 * k, cx - 38 * k, cx - 46 * k, cx - 10 * k, cx - 14 * k, cx - 8 * k, cx + 12 * k, cx + 18 * k,
        cx + 28 * k, cx + 34 * k, cx + 38 * k))
    return line(d, '#07040a', 2.6) + line(d, '#8a7aa0', 0.8, op=0.8)


def rubble(cx):
    s = ''
    for rx, ry, w, h, c in ((cx - 34, 364, 8, 5.4, '#54496a'), (cx + 32, 364, 7.4, 5, '#54496a'),
                            (cx - 22, 367, 6.4, 3.6, '#3a3148'), (cx + 22, 367.4, 6.4, 3.4, '#3a3148')):
        s += '<path d="M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z" fill="%s" stroke="#0a0610" stroke-width="1.4" stroke-linejoin="round"/>' % (
            rx - w, ry + h * 0.4, rx - w * 0.4, ry - h, rx + w, ry - h * 0.3, rx + w * 0.6, ry + h * 0.6, c)
    return s


def points_json():
    """The Snuffer's engine points as JSON (frame units, anchor = the feet)."""
    import json
    doc = {'_doc': "The Snuffer's 384-unit frames: 2 units = 1 world px, facing right, anchor (feet) at (192, 368). "
                   'head = the face (his hit target); bell_mouth = the snuffer bell\'s mouth; slam_centre = where the '
                   'slam lands; cone_tip = the lunge\'s leading point. World offset = (point - anchor) / 2.',
           '_anchor': list(FOOT), '_height_units': HEIGHT, '_pole_units': POLE_LEN}
    r = lunge_rect()
    doc['_lunge_box'] = {
        'frame': list(LUNGE_BOX), 'x': r['x'], 'w': r['w'], 'up_from_floor': [r['bottom'], r['top']],
        'how': 'snuffer_lunge is drawn hovering %d px off the floor (HOVER); its body, cone tip to hem, fills this box. '
               'In snuffer_boss.gd body_rect() for "lunge" and "lunge_draw": Rect2(position.x - %g, floor_y - %g, %g, %g) '
               '(symmetric about the anchor, so it holds for either facing). The bell and smoke trailing behind it '
               'are harmless.' % (HOVER, -r['x'], r['top'], r['w'], r['top'] - r['bottom'])}
    doc.update({k: {n: list(p) for n, p in v.items()} for k, v in sorted(POINTS.items())})
    return json.dumps(doc, indent=1, sort_keys=True) + '\n'


def files():
    out = {'art/enemies/snuffer_%s.svg' % n: frame(n) for n in FRAMES}
    out['art/enemies/points_snuffer.json'] = points_json()
    return out


def build(write):
    for rel, text in files().items():
        write(rel, text)


if __name__ == '__main__':
    import build as _b
    build(_b.write)
    print('wrote %d files under game/' % len(FRAMES))
