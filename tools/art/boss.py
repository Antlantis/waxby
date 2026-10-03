"""World 1's boss: Old Tollgrave, the Bell Warden. A giant hooded skeleton
bell-ringer monk who swings the tower's bronze bell as a hammer.

Frame: viewBox 0 0 256 256 at 512 px (2 units = 1 world px, like every
character), facing right, robe hem on y 244, body centered on x 128 and
filling about x 70..186, y 88..244 (the collision box is 116 x 156).

  boss_idle     standing, the bell hanging from his front hand at his side
  boss_windup   the tell: bell heaved up over and behind his head, eyes flaring
  boss_slam     bell smashed down in front (mouth on y 244, x 175..240), dust
  boss_stuck    bell stuck in the floor, hood fallen back, the skull LOW and
                forward (x 132..182, y 124..170): Wick's target
  boss_hurt     recoiling back, >< eyes, a cracked skull, the bell swinging loose

The robe leans by shearing its points (the hem stays on the ground and the
lines keep their weight); the hood, head and bell move rigidly; the arms are
posed per frame in world coordinates.
"""
import math
import re

import kit
from kit import Part, ell, pth, shp, head_tpl
from common import (Ctx, RIM, svg, paint, line, dot, sweat, swirl_eye, squeeze, spec, sparkle, star4, flame_d, mix,
                    gx, IN)
from enemies import glow_eye, BONE, BONE_SH, BONE_LINE, TEAL
from props import BRONZE, BRONZE_SH, BRONZE_HI, BRONZE_LINE

FRAMES = ['idle', 'windup', 'slam', 'stuck', 'hurt']

L = '#0c0812'
ROBE, ROBE_SH, ROBE_HI = '#4c3f60', '#31283f', '#6e5e86'
HOOD_IN = '#06030a'
CORD, CORD_SH = '#bc9c6a', '#80663e'
IRON, IRON_SH = '#77738e', '#4e4a62'
PAL = dict(line=L, rim=RIM, base=ROBE, shade=ROBE_SH)
STUCK_HEAD = (157, 147)      # the skull's center in boss_stuck (the stomp target)

NUM = re.compile(r'-?\d+(?:\.\d+)?')


def tp(d, fn):
    """Maps every (x, y) pair of an absolute M/L/C/Q path through fn."""
    seps = NUM.split(d)
    nums = NUM.findall(d)
    out = seps[0]
    for i in range(0, len(nums), 2):
        x, y = fn(float(nums[i]), float(nums[i + 1]))
        out += '%.2f' % x + seps[i + 1] + '%.2f' % y + seps[i + 2]
    return out


def ell_d(cx, cy, rx, ry, rot=0.0):
    k = 0.5523
    pts = [(rx, 0), (rx, ry * k), (rx * k, ry), (0, ry), (-rx * k, ry), (-rx, ry * k), (-rx, 0), (-rx, -ry * k),
           (-rx * k, -ry), (0, -ry), (rx * k, -ry), (rx, -ry * k), (rx, 0)]
    c, s = math.cos(math.radians(rot)), math.sin(math.radians(rot))
    P = ['%.2f %.2f' % (cx + x * c - y * s, cy + x * s + y * c) for x, y in pts]
    return 'M%s C%s %s %s C%s %s %s C%s %s %s C%s %s %s Z' % tuple(P)


def place(parts, t):
    """Gives every part the transform t (on the shapes themselves, which
    ThorVG keeps inside clip paths)."""
    for p in parts:
        if 'transform="' in p.tpl:
            p.tpl = p.tpl.replace('transform="', 'transform="%s ' % t, 1)
        else:
            p.tpl = p.tpl.replace(' {a}/>', ' transform="%s" {a}/>' % t)
        p.over, p.hl, p.under = gx(p.over, t), gx(p.hl, t), gx(p.under, t)
    return parts


def rot_pt(x, y, cx, cy, deg):
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return cx + (x - cx) * c - (y - cy) * s, cy + (x - cx) * s + (y - cy) * c


# ================================================================ the bell and its chain

BELL_BODY = ('M50 30 C54 26.6 74 26.6 78 30 C84.4 35 85.4 46 86.6 60 C88 76 94 88 106 96.6 C109 98.8 108 102.4 104 102.4 '
             'L24 102.4 C20 102.4 19 98.8 22 96.6 C34 88 40 76 41.4 60 C42.6 46 43.6 35 50 30 Z')
BELL_CANON = ('M58.4 29.6 L58.4 24.6 C58.4 17.6 69.6 17.6 69.6 24.6 L69.6 29.6 L66 29.6 L66 25 C66 22.4 62 22.4 62 25 '
              'L62 29.6 Z')


def bell(ctx, cx, top, k, rot):
    """The bronze bell, its canon's top at (cx, top), k times the level
    bell's size, turned rot degrees around that point (0 = mouth down)."""
    def f(x, y):
        return cx + (x - 64) * k, top + (y - 20) * k
    P = []
    P.append(Part('fill', pth(tp(BELL_CANON, f)), fill=BRONZE, shade=BRONZE_SH, off=(-1, -1.2), line=BRONZE_LINE))
    bands = (line(tp('M44.2 42.6 Q64 47 83.8 42.6', f), BRONZE_HI, 1.8)
             + line(tp('M28.8 91.8 Q64 98.2 99.2 91.8', f), BRONZE_HI, 2)
             + line(tp('M26 95.6 Q64 102 102 95.6', f), BRONZE_LINE, 0.9, op=0.6))
    ex, ey = f(64, 80)
    bands += '<path d="%s" fill="%s" stroke="%s" stroke-width="1.3" stroke-linejoin="round"/>' % (
        flame_d(ex, ey, 12 * k, 20 * k, k), BRONZE_HI, BRONZE_LINE)
    bands += '<path d="%s" fill="#fff6d8"/>' % flame_d(ex + 0.2, ey - k, 5.8 * k, 10 * k, 0.5 * k)
    hx, hy = f(52, 60)
    hl = spec(hx, hy, 2.4, 13 * k, rot=12, op=0.75) + line(tp('M31 96.4 Q40 92 44 84', f), '#ffe6b0', 1.2, op=0.8)
    P.append(Part('fill', pth(tp(BELL_BODY, f)), fill=BRONZE, shade=BRONZE_SH, off=(-4, -2.6), line=BRONZE_LINE,
                  over=bands, hl=hl))
    mx, my = f(64, 102.2)
    P.append(Part('fill', pth(ell_d(mx, my, 41.4 * k, 4.2 * k)), fill='#2a1608', no_shade=True, rim=False, sil=False,
                  line=BRONZE_LINE, lw=1.2))
    kx, ky = f(64, 104.6)
    P.append(Part('fill', pth(ell_d(kx, ky, 6 * k, 5.6 * k)), fill='#5a4a40', shade='#3a2e28', off=(-1, -1.2),
                  line=BRONZE_LINE, rim=False, sil=False, hl=dot(kx - 1.6, ky - 1.6, 1.1, '#9a8a80')))
    return place(P, 'rotate(%.1f %.1f %.1f)' % (rot, cx, top))


def chain(a, b, links=None):
    """An iron chain from a to b: a dark spine with rings on it."""
    (x0, y0), (x1, y1) = a, b
    ln = math.hypot(x1 - x0, y1 - y0)
    n = links or max(2, int(ln / 6.2))
    ang = math.degrees(math.atan2(y1 - y0, x1 - x0))
    P = [Part('limb', pth('M%.1f %.1f L%.1f %.1f' % (x0, y0, x1, y1)), width=1.6, fill=IRON_SH)]
    for i in range(n):
        t = (i + 0.5) / n
        x, y = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
        if i % 2:
            P.append(Part('fill', pth(ell_d(x, y, 3.8, 1.5, ang)), fill=IRON, shade=IRON_SH, off=(0, -0.6)))
        else:
            P.append(Part('fill', pth(ell_d(x, y, 3.8, 2.8, ang)), fill=IRON, shade=IRON_SH, off=(-0.6, -0.8),
                          over='<path d="%s" fill="%s"/>' % (ell_d(x, y, 1.9, 1.0, ang), L)))
    return P


# ================================================================ bones: hands and forearms

def bone_hand(x, y, ang, fist=True):
    """A skeletal hand at (x, y), its knuckles toward ang degrees (0 = right)."""
    t = 'translate(%.1f %.1f) rotate(%.1f)' % (x, y, ang)
    P = [Part('fill', pth(ell_d(-0.6, 0, 6.2, 5.6)), fill=BONE, shade=BONE_SH, off=(-1, -1.2), line=BONE_LINE)]
    if fist:
        for fy in (-3.8, 0, 3.8):
            P.append(Part('fill', pth(ell_d(5, fy, 2.6, 2.1)), fill=BONE, shade=BONE_SH, off=(-0.6, -0.6), line=BONE_LINE))
        P.append(Part('limb', pth('M-2.6 -4.6 L3 -6.6'), width=2.2, fill=BONE, line=BONE_LINE))
    else:
        for fy, ln in ((-4, 9), (0, 10), (4, 8.6)):
            P.append(Part('limb', pth('M3 %.1f L%.1f %.1f L%.1f %.1f' % (fy, 3 + ln * 0.6, fy * 1.3, 3 + ln, fy * 1.5 + 1.6)),
                          width=2.2, fill=BONE, line=BONE_LINE))
        P.append(Part('limb', pth('M-1 -5 L3 -9.4'), width=2.2, fill=BONE, line=BONE_LINE))
    return place(P, t)


def sleeve(S, C, ws=13, wc=22, fill=ROBE, shade=ROBE_SH):
    """A wide monk's sleeve from the shoulder S to the cuff C, flared, the
    cuff's dark opening facing along the arm."""
    (sx, sy), (cx, cy) = S, C
    dx, dy = cx - sx, cy - sy
    ln = math.hypot(dx, dy)
    ux, uy = dx / ln, dy / ln
    nx, ny = -uy, ux
    a, b = ws / 2.0, wc / 2.0
    p1 = (sx + nx * a, sy + ny * a)
    p2 = (cx + nx * b, cy + ny * b)
    p3 = (cx - nx * b, cy - ny * b)
    p4 = (sx - nx * a, sy - ny * a)
    m1 = ((p1[0] + p2[0]) / 2 + nx * 2.4, (p1[1] + p2[1]) / 2 + ny * 2.4)
    m2 = ((p3[0] + p4[0]) / 2 - nx * 2.4, (p3[1] + p4[1]) / 2 - ny * 2.4)
    back = (sx - ux * a * 1.3, sy - uy * a * 1.3)
    d = 'M%.1f %.1f Q%.1f %.1f %.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f Z' % (
        p1[0], p1[1], m1[0], m1[1], p2[0], p2[1], p3[0], p3[1], m2[0], m2[1], p4[0], p4[1], back[0], back[1], p1[0], p1[1])
    ang = math.degrees(math.atan2(uy, ux)) + 90
    hole = '<path d="%s" fill="%s"/>' % (ell_d(cx - ux * 1.2, cy - uy * 1.2, b * 0.82, 3.4, ang), HOOD_IN)
    fold = line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (sx + ux * ln * 0.3, sy + uy * ln * 0.3,
                                                   sx + ux * ln * 0.6 + nx * 2, sy + uy * ln * 0.6 + ny * 2,
                                                   cx - ux * 5 + nx * 3, cy - uy * 5 + ny * 3), L, 1.1, op=0.5)
    return Part('fill', pth(d), fill=fill, shade=shade, off=(-2, -2.4), over=fold + hole)


def forearm(a, b):
    """A bare forearm bone (the sleeve slid down a raised arm)."""
    return Part('limb', pth('M%.1f %.1f L%.1f %.1f' % (a[0], a[1], b[0], b[1])), width=3.4, fill=BONE, line=BONE_LINE)


# ================================================================ the robe

ROBE_D = ('M100 142 L160 142 C170 150 176 170 180 196 C183 214 185.6 228 186.6 241 L178.6 236 L174.6 242 L166 236.4 '
          'L158.6 242 L149.4 236.4 L140.6 242 L131 236.4 L121.6 242 L112.6 236.4 L103.4 242 L94.6 236.4 L86 242 '
          'L78.6 236.4 L70.4 241 C71 226 74.4 208 78.4 190 C82.6 170 88.6 152 100 142 Z')


def robe_fn(dx, sy):
    """The lean: points shift by dx at the shoulder line (y 142), none at the hem; sy squashes toward the ground."""
    def f(x, y):
        t = (244 - y) / 102.0
        return x + dx * t, 244 - (244 - y) * sy
    return f


def robe(ctx, dx, sy):
    f = robe_fn(dx, sy)
    folds = line(tp('M120 152 Q115 192 111 236 M147 154 Q153 194 158 236 M132 200 Q134 216 136 236 '
                    'M96 170 Q88 200 86 236', f), L, 1.2, op=0.55)
    folds += line(tp('M125 156 Q121 190 118 226 M172 170 Q178 200 181 228', f), ROBE_HI, 1.2, op=0.6)
    belt = tp('M79 186 Q128 198 180.6 186', f)
    cord = line(belt, L, 6.6) + line(belt, CORD, 3.6) + line(belt, '#e8d0a0', 1, op=0.8)
    kx, ky = f(152, 193)
    tails = tp('M152 193 Q150 206 147 220 M153 193 Q158 206 158 214', f)
    cord += line(tails, L, 5.8) + line(tails, CORD, 3)
    cord += '<circle cx="%.1f" cy="%.1f" r="4.4" fill="%s" stroke="%s" stroke-width="%.1f"/>' % (kx, ky, CORD, L, IN())
    for tx, ty in ((147, 220), (158, 214)):
        px, py = f(tx, ty)
        cord += '<path d="M%.1f %.1f L%.1f %.1f L%.1f %.1f Z" fill="%s" stroke="%s" stroke-width="1.2" stroke-linejoin="round"/>' % (
            px - 3, py, px + 3, py, px, py + 7, CORD_SH, L)
    return [Part('fill', pth(tp(ROBE_D, f)), off=(-4, -3), over=folds + cord,
                 hl=line(tp('M96 156 Q86 180 82 204', f), ROBE_HI, 2.4, op=0.8))]


# ================================================================ the hood and the skull

MANTLE_D = ('M90 150 C100 138 160 134 176 146 C180 152 181 160 180 168 L172 163 L166 171 L157 164 L148 172 L139 165 '
            'L129 172 L120 165 L110 171 L101 164 L92 169 L86 162 C86 157 87 153 90 150 Z')
HOOD_D = 'M100 152 C88 130 92 102 112 92 C126 85 150 86 164 96 C178 106 184 128 179 150 C166 158 112 160 100 152 Z'
HOOD_TIP_D = 'M106 98 C94 100 84 110 80 128 C88 121 97 116 108 114 Z'
OPEN = (151, 124, 20.5, 23.4, -6)


def hooded_head(ctx, eyes='idle'):
    """The mantle, the tattered hood and the skull deep inside it (rest pose)."""
    P = []
    P.append(Part('fill', pth(MANTLE_D), off=(-3, -3),
                  over=line('M100 150 Q128 156 170 150', L, 1.1, op=0.5) + line('M96 150 Q116 144 140 143', ROBE_HI, 1.4, op=0.7)))
    P.append(Part('fill', pth(HOOD_TIP_D), off=(-1.4, -1.6)))
    ox, oy, orx, ory, orot = OPEN
    opening = ell_d(ox, oy, orx, ory, orot)
    clip = ctx.clip('<path d="%s"/>' % opening)
    inner = '<path d="%s" fill="%s"/>' % (opening, HOOD_IN)
    # the skull in the dark, lit by its own eyes
    sk = ell_d(153.4, 128.4, 16.8, 17.6)
    face = '<path d="%s" fill="%s"/>' % (sk, mix(BONE, '#8ab8b0', 0.18))
    face += '<path d="%s" fill="%s"/>' % (ell_d(159, 133, 11, 12), mix(BONE_SH, '#5a8a84', 0.25))
    face += '<path d="%s" fill="%s"/>' % (ell_d(152.4, 127.4, 15.4, 16.4), mix(BONE, '#8ab8b0', 0.18))
    shadow = ctx.lingrad([(0, HOOD_IN, 1), (0.42, HOOD_IN, 0.85), (1, HOOD_IN, 0)], x1=0, y1=0, x2=0, y2=1)
    face += '<path d="%s" fill="%s"/>' % (ell_d(151, 112, 22, 12), shadow)
    if eyes == 'flare':
        wash = ctx.radgrad([(0, TEAL, 0.9), (0.55, TEAL, 0.45), (1, TEAL, 0.1)])
        face += '<path d="%s" fill="%s"/>' % (ell_d(152, 124, 22, 24), wash)
    halo = ctx.radgrad([(0, TEAL, 0.55), (1, TEAL, 0)])
    face += '<ellipse cx="153.4" cy="125" rx="20" ry="12" fill="%s"/>' % halo
    # the grin and the nose
    face += '<path d="M141.6 136.6 Q153 141.4 165 136.4 L165 139.4 Q153 145 141.6 139.8 Z" fill="%s"/>' % BONE_LINE
    face += ''.join('<rect x="%.1f" y="%.1f" width="2.8" height="2.9" rx="0.6" fill="#f4eee0"/>' % (x, y) for x, y in (
        (143.2, 137.2), (146.6, 138.1), (150, 138.5), (153.4, 138.5), (156.8, 138.1), (160.2, 137.2)))
    face += '<path d="M153.6 131 C151.6 129.6 150.4 132 153.4 134.2 C156.2 132 155.2 129.6 153.6 131 Z" fill="%s"/>' % BONE_LINE
    if eyes == 'flare':
        for ex, ey, w, h in ((145.6, 125, 14.6, 16.4), (161.2, 124.4, 11.6, 14.8)):
            face += glow_eye(ctx, ex, ey, w, h, look=(1.4, -0.4), iris=0.38)
    else:
        for ex, ey, w, h in ((145.6, 125.4, 13.6, 15.6), (161.2, 124.8, 10.8, 14.2)):
            face += glow_eye(ctx, ex, ey, w, h, look=(1.4, 0.4))
    edge = '<path d="%s" fill="none" stroke="%s" stroke-width="4.4"/>' % (ell_d(ox - 0.6, oy + 0.4, orx + 1.6, ory + 1.6, orot), ROBE_HI)
    edge += '<path d="%s" fill="none" stroke="%s" stroke-width="%.1f"/>' % (opening, L, IN())
    rips = line('M112 96 L116 104 L112 110 M170 104 L166 110', L, 1.2, op=0.6)
    P.append(Part('fill', pth(HOOD_D), off=(-3.6, -3.4), over=rips + '<g clip-path="%s">%s%s</g>' % (clip, inner, face) + edge,
                  hl=spec(114, 102, 7, 2.6, rot=-40, op=0.35) + line('M104 138 Q98 116 112 98', ROBE_HI, 1.6, op=0.8)))
    fx = ''
    if eyes == 'flare':
        # the eyes flash: a glint on each socket and a glow spilling out of
        # the hood (he's about to slam)
        spill = ctx.radgrad([(0, TEAL, 0.55), (0.5, TEAL, 0.2), (1, TEAL, 0)])
        fx += '<ellipse cx="153" cy="124" rx="44" ry="40" fill="%s"/>' % spill
        for ex, ey, r in ((146.4, 124.4, 13), (162, 123.6, 10.4)):
            fx += star4(ex, ey, r * 1.3, '#0a3a34', 0.9) + star4(ex, ey, r, '#e8fff6') + dot(ex, ey, r * 0.3, '#ffffff')
    return P, fx


def skull_exposed(ctx, cx, cy, rot, eyes='dizzy', crack=False):
    """The hood fallen back, the big skull bare (the target), centered on (cx, cy)."""
    t = 'translate(%.1f %.1f) rotate(%.1f)' % (cx, cy, rot)
    P = []
    # the hood crumpled behind the skull
    P.append(Part('fill', pth('M-4 -26 C-24 -30 -42 -16 -42 4 C-42 22 -30 32 -12 34 L8 31 C-4 24 -12 14 -12 2 '
                              'C-12 -10 -8 -19 -4 -26 Z'), off=(-2.6, -3),
                  over=line('M-30 -8 Q-34 6 -26 20 M-20 -18 Q-26 -4 -22 12', L, 1.2, op=0.5)
                  + line('M-36 -4 Q-34 -18 -18 -24', ROBE_HI, 1.6, op=0.8)))
    jaw = 'M-11 14 C-11 23 -3 26.6 5.6 26.4 C14 26.2 20 22.4 20 13.4 Z'
    teeth_low = ''.join('<rect x="%.1f" y="15" width="3" height="3.2" rx="0.6" fill="#fffaf0" stroke="%s" stroke-width="0.6"/>' % (x, BONE_LINE)
                        for x in (-5.4, -1.8, 1.8, 5.4, 9))
    if eyes == 'strain':
        jaw = 'M-11 14 C-11 20 -3 22.6 5.6 22.4 C14 22.2 20 19.4 20 13.4 Z'
    P.append(Part('fill', pth(jaw), fill=BONE, shade=BONE_SH, off=(-1, -1.4), line=BONE_LINE, over=teeth_low))
    f = ''
    halo = ctx.radgrad([(0, TEAL, 0.45), (1, TEAL, 0)])
    f += '<ellipse cx="3" cy="0" rx="26" ry="13" fill="%s"/>' % halo
    if eyes == 'dizzy':
        for ex, ey, w, h in ((-7.4, 0, 15.6, 17.4), (12.4, -0.6, 12.4, 15.4)):
            f += '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s"/>' % (ex, ey, w / 2, h / 2, BONE_LINE)
            f += swirl_eye(ex, ey, w * 0.36, TEAL, 1.5)
    elif eyes == 'hurt':
        f += '<ellipse cx="-7.4" cy="0" rx="7.8" ry="8.7" fill="%s"/><ellipse cx="12.4" cy="-0.6" rx="6.2" ry="7.7" fill="%s"/>' % (
            BONE_LINE, BONE_LINE)
        f += squeeze(-7.4, 0, 9.6, TEAL, w=2.2) + squeeze(12.4, -0.6, 8, TEAL, flip=True, w=2.2)
    else:
        f += glow_eye(ctx, -7.4, 0, 15.6, 17.4, look=(1, 0.4)) + glow_eye(ctx, 12.4, -0.6, 12.4, 15.4, look=(1, 0.4))
    # the grin (gritted when straining), the nose
    f += '<path d="M-10 11.4 Q4 16 20 11 L20 14 Q4 19.6 -10 14.6 Z" fill="%s"/>' % BONE_LINE
    f += ''.join('<rect x="%.1f" y="%.1f" width="3" height="3" rx="0.6" fill="#fffaf0"/>' % (x, y) for x, y in (
        (-7.6, 12.2), (-4, 13), (-0.4, 13.4), (3.2, 13.4), (6.8, 13.2), (10.4, 12.8), (14, 12.2)))
    f += '<path d="M4.4 5.8 C2.2 4.2 0.8 7 4.2 9.6 C7.6 7 6.4 4.2 4.4 5.8 Z" fill="%s"/>' % BONE_LINE
    if crack:
        f += line('M-14 -20 L-9 -13 L-13 -9 L-6 -3', BONE_LINE, 1.6)
        f += line('M-13.4 -19 L-8.4 -12.6', '#ffffff', 0.6, op=0.7)
    hl = spec(-12, -14, 7, 3.4, rot=-38, op=0.95) + dot(-3.6, -19, 1.6, '#ffffff', 0.9)
    P.append(Part('fill', head_tpl(0, 0, 50, 46, squish=-0.08), fill=BONE, shade=BONE_SH, off=(-3.6, -3.8), line=BONE_LINE,
                  over=f, hl=hl))
    return place(P, t)


# ================================================================ the frames

def neck_shift(dx, sy):
    x, y = robe_fn(dx, sy)(134, 148)
    return x - 134, y - 148


def frame(name):
    ctx = Ctx('bo' + name[:3])
    back, mid, front, over, under = [], [], [], '', ''
    if name == 'idle':
        dx, sy, hrot = 0, 1, 0
        f = robe_fn(dx, sy)
        back += [sleeve(f(106, 150), (84, 194), 13, 21, ROBE_SH, '#261e33')] + bone_hand(82, 202, 96)
        bl = bell(ctx, 197, 171, 0.7, 3)
        mid += bl + chain((192, 160), (197, 171.6))
        front_sleeve = [sleeve(f(158, 150), (182, 158), 14, 22)]
        hands = bone_hand(190, 160, 70)
        hx, hy = neck_shift(dx, sy)
        head, head_fx = hooded_head(ctx, 'idle')
        head = place(head, 'translate(%.1f %.1f) rotate(%.1f 134 148)' % (hx, hy, hrot))
        head_fx = gx(head_fx, 'translate(%.1f %.1f) rotate(%.1f 134 148)' % (hx, hy, hrot))
        parts = back + robe(ctx, dx, sy) + mid + front_sleeve + head + hands
    elif name == 'windup':
        dx, sy, hrot = -22, 1, -14
        f = robe_fn(dx, sy)
        hx, hy = neck_shift(dx, sy)
        # the bell heaved up over and behind his head, both hands on the chain
        bl = bell(ctx, 100, 66, 0.7, 116)
        back += bl + chain((118, 77), (100.6, 66.6))
        bs, bc = f(104, 152), (86, 114)
        back += [sleeve(bs, bc, 13, 20, ROBE_SH, '#261e33'), forearm((87, 110), (114, 80))] + bone_hand(117, 77, -60)
        fs, fc = f(164, 150), (180, 116)
        front_arm = [sleeve(fs, fc, 14, 21), forearm((178, 111), (127, 82))] + bone_hand(124, 79, -150)
        head, head_fx = hooded_head(ctx, 'flare')
        t = 'translate(%.1f %.1f) rotate(%.1f 134 148)' % (hx, hy, hrot)
        head = place(head, t)
        head_fx = gx(head_fx, t)
        parts = back + robe(ctx, dx, sy) + head + front_arm
        # the tell: strain marks and a glint on the bell
        over = (line('M166 86 L180 78 M170 98 L186 96 M56 128 L42 122 M58 140 L42 140', '#ffffff', 2.2, op=0.9)
                + sparkle(132, 44, 6, L, '#e8fff6') + sparkle(186, 64, 4, L, '#e8fff6'))
    elif name == 'slam':
        dx, sy, hrot = 28, 0.9, 20
        f = robe_fn(dx, sy)
        hx, hy = neck_shift(dx, sy)
        cx, top, k = 207.5, 181.6, 0.74
        back += [sleeve(f(106, 152), (172, 176), 13, 18, ROBE_SH, '#261e33')] + bone_hand(200, 176, 30)
        mid += bell(ctx, cx, top, k, 0) + chain((203, 172), (cx, top + 0.6), links=2)
        front_sleeve = [sleeve(f(158, 152), (192, 170), 14, 20)]
        hands = bone_hand(207, 172, 40)
        head, head_fx = hooded_head(ctx, 'idle')
        t = 'translate(%.1f %.1f) rotate(%.1f 134 148)' % (hx, hy, hrot)
        head = place(head, t)
        head_fx = gx(head_fx, t)
        parts = back + robe(ctx, dx, sy) + mid + front_sleeve + head + hands
        over = impact(ctx, cx)
    elif name == 'stuck':
        dx, sy = 12, 0.8
        f = robe_fn(dx, sy)
        hx, hy = neck_shift(dx, sy)
        cx, top, k = 207.5, 181.6, 0.74
        mid += bell(ctx, cx, top, k, 5)
        mid += chain((199, 176), (cx, top + 0.6), links=2)
        back += [sleeve(f(106, 152), (170, 184), 13, 18, ROBE_SH, '#261e33')] + bone_hand(196, 178, 10)
        front_sleeve = [sleeve(f(160, 152), (186, 178), 14, 19)]
        hands = bone_hand(203, 174, 30)
        mantle = place([Part('fill', pth(MANTLE_D), off=(-3, -3),
                             over=line('M100 150 Q128 156 170 150', L, 1.1, op=0.5))],
                       'translate(%.1f %.1f) rotate(6 134 148)' % (hx, hy))
        sx, sy2 = STUCK_HEAD
        head = skull_exposed(ctx, sx, sy2, 10, 'dizzy')
        head_fx = ''
        parts = back + robe(ctx, dx, sy) + mid + front_sleeve + mantle + head + hands
        rubble = []
        for rx, ry, w, h, c in ((176, 240, 8, 5.4, '#54496a'), (239, 240, 7.4, 5, '#54496a'), (188, 243, 6.4, 3.6, '#3a3148'),
                                (227, 243.4, 6.4, 3.4, '#3a3148'), (208, 244, 7, 3, '#3a3148')):
            rubble.append(Part('fill', pth('M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (
                rx - w, ry + h * 0.4, rx - w * 0.4, ry - h, rx + w, ry - h * 0.3, rx + w * 0.6, ry + h * 0.6)),
                fill=c, shade=mix(c, '#000000', 0.35), off=(-1, -1), line='#0a0610'))
        parts += rubble
        over = (dizzy_stars(sx, sy2 - 30) + sweat(186, 128, 1.3, 20)
                + line('M222 166 Q230 158 228 148 M232 172 Q242 164 241 152', '#ffffff', 2, op=0.85)
                + cracks(cx, 0.8))
    else:   # hurt
        dx, sy = -18, 1
        f = robe_fn(dx, sy)
        hx, hy = neck_shift(dx, sy)
        # the bell swings out loose on its chain
        bl = bell(ctx, 182, 140, 0.7, -64)
        mid += bl + chain((172, 128), (182, 140))
        back += [sleeve(f(104, 152), (74, 128), 13, 20, ROBE_SH, '#261e33')] + bone_hand(68, 122, -150, fist=False)
        front_sleeve = [sleeve(f(158, 150), (166, 132), 14, 21)]
        hands = bone_hand(170, 126, -40)
        mantle = place([Part('fill', pth(MANTLE_D), off=(-3, -3),
                             over=line('M100 150 Q128 156 170 150', L, 1.1, op=0.5))],
                       'translate(%.1f %.1f) rotate(-10 134 148)' % (hx, hy))
        head = skull_exposed(ctx, 124, 116, -20, 'hurt', crack=True)
        head_fx = ''
        parts = back + robe(ctx, dx, sy) + mantle + head + mid + front_sleeve + hands
        over = (line('M196 100 Q222 104 236 126 M206 90 Q232 96 246 118', '#ffffff', 2.2, op=0.8)
                + bone_chips() + star4(96, 76, 7, '#e8fff6', 0.95) + star4(150, 84, 5, '#e8fff6', 0.9))
    body = paint(ctx, parts, PAL)
    return svg(ctx, under + body + head_fx + over, 256, 256)


def impact(ctx, cx):
    """Dust, cracks and shock lines where the bell hits the floor."""
    s = cracks(cx, 1)
    for x, y, r in ((170, 238, 7), (160, 241, 4.6), (180, 232, 4.2), (243, 236, 6), (249.4, 242, 3.4), (236, 229, 3.8)):
        s += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="#e8dcc8" stroke="%s" stroke-width="1.4" opacity="0.95"/>' % (x, y, r, L)
    s += line('M168 212 L156 204 M170 224 L154 222 M244 210 L250 203 M245 222 L252 220', '#ffffff', 2.2, op=0.9)
    s += star4(207, 170, 6, '#fff2c8', 0.95)
    return s


def cracks(cx, k):
    d = ('M%.1f 245 L%.1f 248 L%.1f 250 M%.1f 245 L%.1f 249 L%.1f 251 M%.1f 245 L%.1f 249 M%.1f 245 L%.1f 249 L%.1f 250' % (
        cx - 30 * k, cx - 38 * k, cx - 46 * k, cx - 10 * k, cx - 14 * k, cx - 8 * k, cx + 12 * k, cx + 18 * k,
        cx + 28 * k, cx + 34 * k, cx + 38 * k))
    return line(d, '#07040a', 2.6) + line(d, '#8a7aa0', 0.8, op=0.8)


def dizzy_stars(x, y):
    s = ''
    for i, (dx, dy, r) in enumerate(((-22, 4, 5), (0, -4, 6), (22, 3, 5))):
        s += kit.star5(x + dx, y + dy, r, '#ffe27a', L, 1.4)
    s += '<ellipse cx="%.1f" cy="%.1f" rx="30" ry="7" fill="none" stroke="#ffffff" stroke-width="1.4" opacity="0.6"/>' % (x, y + 2)
    return s


def bone_chips():
    s = ''
    for x, y, r in ((98, 88, 20), (110, 72, -30)):
        s += '<path d="M%.1f %.1f l4 -2 l2 3 l-3 3 Z" fill="%s" stroke="%s" stroke-width="1.1" transform="rotate(%s %.1f %.1f)"/>' % (
            x, y, BONE, BONE_LINE, r, x, y)
    return s


def files():
    return {'art/enemies/boss_%s.svg' % n: frame(n) for n in FRAMES}
