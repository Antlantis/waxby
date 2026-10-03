"""WAXBY's new monsters, one SVG per frame on the 128 x 128 frame (2 units =
1 world px, drawn at sprite scale 0.25), facing right, feet on y 122 unless
noted. The same chibi kit and cel look as enemies.py (Rattle, Flit, Thornback).

  Bonebow, the skeleton archer    bonebow_idle, _draw, _loose, _hit, _bones
  Hollow Helm, empty wax armour   helm_walk1/2, _block, _bash, _noshield, _hit
  Gutterwing, the light moth      wing_fly1/2, _latch, _pop       centred on (64, 64)
  Dripkin, the living drip        drip_hang (hangs from y 10), _drop, _splat, _crawl1/2
  Brinejaw, the lure fish         jaw_hide, _leap, _fall          centred on (64, 64)
  Lidlurk, the reliquary mimic    lurk_open, _hop, _hit           60 wide, bottom on 122

POINTS lists, per frame, where the engine should hang its lights and shots
(frame units; world offset from the anchor = (p - anchor) / 2).

drip_hang is drawn on the Dripkin's usual feet frame (anchor (64, 122)) with
the ceiling line at frame y 10 (the wax smear above it hides in the ceiling
tile). enemy.gd turns `anchor` into sprite.offset once, in _ready (step()
refreshes only offset.x), so don't change `anchor` at runtime: while it hangs,
set sprite.position.y = DRIP_HANG_SPRITE_Y (56 = (122 - 10) / 2), which puts
frame y 10 on position.y = the ceiling line, and set it back to 0 when it lets
go. (Writing sprite.offset.y = -20 while hanging and -244 after works too.)
Run on its own: python3 tools/art/enemies2.py (writes under game/).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import kit
from kit import Part, ell, pth, shp, head_tpl
from common import (Ctx, RIM, WAX, WAX_SH, WAX_LINE, FLAME, svg128, paint, eye, blush, mouth_open, sweat, line, dot,
                    squeeze, swirl_eye, spec, sparkle, star4, flame, flame_d, glow, H, IN, mix, xf, xell, gx)
from enemies import (glow_eye, skel_leg, skel_arm, shadow, BONE, BONE_SH, BONE_LINE, BONE_BACK, BONE_BACK_SH, TEAL,
                     SPAL)

POINTS = {}   # frame name -> {point name: (x, y)}, filled as frames are drawn


def mark(frame, **pts):
    POINTS.setdefault(frame, {}).update({k: (round(v[0], 1), round(v[1], 1)) for k, v in pts.items()})


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


def ell_d(cx, cy, rx, ry, rot=0.0):
    """An ellipse as a path (so it can be clipped and transformed like one)."""
    k = 0.5523
    pts = [(rx, 0), (rx, ry * k), (rx * k, ry), (0, ry), (-rx * k, ry), (-rx, ry * k), (-rx, 0), (-rx, -ry * k),
           (-rx * k, -ry), (0, -ry), (rx * k, -ry), (rx, -ry * k), (rx, 0)]
    c, s = math.cos(math.radians(rot)), math.sin(math.radians(rot))
    P = ['%.2f %.2f' % (cx + x * c - y * s, cy + x * s + y * c) for x, y in pts]
    return 'M%s C%s %s %s C%s %s %s C%s %s %s C%s %s %s Z' % tuple(P)


def motion(d, w=1.4, op=0.9):
    """White motion lines with a dark keyline, readable on any background."""
    return line(d, '#07040a', w + 1.4, op=0.6) + line(d, '#ffffff', w, op=op)


# ================================================================ Bonebow, the skeleton archer

HAT, HAT_SH, HAT_HI = '#3e6e62', '#284a42', '#6aa090'
FEATHER, FEATHER_SH = '#b8324a', '#7a1e34'
LEATHER, LEATHER_SH, LEATHER_LINE = '#7a4a2a', '#553018', '#2a1408'
SINEW = '#f2e6c8'
BOW, BOW_SH = '#e2cc94', '#b0935a'      # the bow's bones are older and yellower than the archer's


def bb_skull(ctx, cx, cy, w, h, mood, t=''):
    """Rattle's round skull (see enemies.skull) with the archer's moods:
    'idle', 'aim' (near eye squinting down the arrow), 'hit', 'dizzy'."""
    k = w / 38.0
    t = t or 'translate(0 0)'
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
    P.append(Part('fill', xf(jaw_d, t), fill=BONE, shade=BONE_SH, off=(-1, -1.4), over=gx(teeth_low, t)))
    cran = head_tpl(cx, cy, w, h, squish=-0.08).replace(' {a}/>', ' transform="%s" {a}/>' % t)
    halo = ctx.radgrad([(0, TEAL, 0.5), (1, TEAL, 0)])
    f = '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s"/>' % (X(69), Y(81), 20 * k, 11 * k, halo)
    if mood == 'idle':
        f += glow_eye(ctx, X(60.4), Y(80.6), 12.4 * k, 13.8 * k, look=(0.9 * k, 0.2))
        f += glow_eye(ctx, X(77.6), Y(80.2), 9.8 * k, 12.6 * k, look=(0.9 * k, 0.2))
    elif mood == 'aim':
        # the near eye squeezed to a glowing slit, the far one wide and fixed on the target
        f += '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s"/>' % (X(60.4), Y(81.4), 6.4 * k, 5.2 * k, BONE_LINE)
        f += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (X(56), Y(81.8), X(60.4), Y(80.2), X(64.8), Y(81.4)), TEAL, 1.6 * k)
        f += glow_eye(ctx, X(77.6), Y(80.2), 10.6 * k, 13.2 * k, look=(1.6 * k, 0.4), iris=0.3)
        # a hard brow ridge over the open eye
        f += line('M%.1f %.1f L%.1f %.1f' % (X(71.6), Y(71.4), X(83.4), Y(73.6)), BONE_LINE, 1.6 * k)
    elif mood == 'hit':
        f += glow_eye(ctx, X(60.2), Y(80), 13.6 * k, 15 * k, look=(0, 0), iris=0.16, pin=True)
        f += glow_eye(ctx, X(77.6), Y(79.6), 10.8 * k, 13.6 * k, look=(0, 0), iris=0.16, pin=True)
    else:
        f += '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s"/>' % (X(60.4), Y(80.6), 6.2 * k, 6.9 * k, BONE_LINE)
        f += '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s"/>' % (X(77.6), Y(80.2), 4.9 * k, 6.3 * k, BONE_LINE)
        f += swirl_eye(X(60.4), Y(80.6), 4.6 * k, TEAL, 1.1) + swirl_eye(X(77.6), Y(80.2), 3.6 * k, TEAL, 1.0)
    # nose and the upper teeth
    f += '<path d="M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z" fill="%s"/>' % (
        X(70.4), Y(86.6), X(68.2), Y(85), X(66.8), Y(87.6), X(70.2), Y(90.2),
        X(73.2), Y(87.4), X(72.2), Y(85), X(70.4), Y(86.6), BONE_LINE)
    f += '<path d="M%.1f %.1f Q%.1f %.1f %.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f Z" fill="%s"/>' % (
        X(60.4), Y(91.6), X(71), Y(94.6), X(82.4), Y(90.6), X(82.4), Y(92.8), X(71), Y(97.4), X(60.4), Y(93.8), BONE_LINE)
    f += ''.join('<rect x="%.2f" y="%.2f" width="%.2f" height="%.2f" rx="%.2f" fill="#fffaf0"/>' % (
        X(x), Y(y), 2.7 * k, 2.6 * k, 0.5 * k) for x, y in ((62.6, 92.1), (65.8, 92.9), (69, 93.3), (72.2, 93.2),
                                                           (75.4, 92.7), (78.6, 91.8)))
    hl = spec(X(55), Y(69.4), 5.2 * k, 2.6 * k, rot=-38, op=0.95)
    P.append(Part('fill', cran, fill=BONE, shade=BONE_SH, off=(-3.4 * k, -3.6 * k), over=gx(f, t), hl=gx(hl, t)))
    return P


def archer_hat(cx, cy, k=1.0, t=''):
    """A little pointed felt cap sitting back on the skull (whose centre is
    (cx, cy) at scale k), its tip trailing behind, with a crimson feather."""
    t = t or 'translate(0 0)'

    def f(x, y):
        return '%.1f %.1f' % (cx + (x - 66) * k, cy + (y - 79) * k)
    feather = 'M%s C%s %s %s C%s %s %s Z' % (f(55, 64), f(47, 58.6), f(42.4, 50), f(40.2, 42.4), f(46.6, 46.4), f(52.4, 53), f(57.4, 62))
    quill = 'M%s Q%s %s M%s L%s M%s L%s' % (f(55.6, 63), f(47, 53), f(41, 43.4), f(47.4, 53.4), f(50.6, 52.4), f(44.6, 48.6), f(47.6, 47.4))
    crown = 'M%s C%s %s %s C%s %s %s C%s %s %s C%s %s %s Z' % (
        f(84, 66.4), f(82, 58), f(71, 54.4), f(59, 56.6), f(52, 58), f(45, 57.4), f(38.4, 54.6),
        f(40.6, 60.6), f(44, 66), f(48.4, 71.6), f(60, 66.4), f(72, 64), f(84, 66.4))
    band = 'M%s C%s %s %s L%s C%s %s %s Z' % (f(48, 71.2), f(60, 65.6), f(72, 63), f(84.6, 65.6),
                                             f(85.2, 69), f(72, 66.8), f(60, 69.4), f(49.2, 74.6))
    P = [Part('fill', xf(feather, t), fill=FEATHER, shade=FEATHER_SH, off=(-1 * k, -1 * k),
              over=gx(line(quill, '#ffd0d8', 0.8 * k, op=0.9), t)),
         Part('fill', xf(crown, t), fill=HAT, shade=HAT_SH, off=(-2 * k, -2.2 * k),
              hl=gx(line('M%s Q%s %s' % (f(51, 61.6), f(60, 57.8), f(72, 58)), HAT_HI, 1.1 * k, op=0.9), t)),
         Part('fill', xf(band, t), fill=LEATHER, shade=LEATHER_SH, off=(-0.6, -0.8),
              over=gx('<circle cx="%s" cy="%s" r="%.1f" fill="#d8b24a" stroke="%s" stroke-width="0.6"/>' % (
                  tuple(f(52.6, 70.4).split()) + (1.3 * k, LEATHER_LINE)), t))]
    return P


def bone_bow(gx_, gy, hh, bend, nock=None, loose=False):
    """The bone bow held at its grip (gx_, gy): two long bones curving away
    from the archer to knobbed tips hh above and below, bend back toward him.
    nock: where the string is drawn to (None = straight). Returns (parts, string)."""
    tx, ty = gx_ - bend, gy - hh
    bx, by = gx_ - bend, gy + hh
    top = 'M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (gx_, gy - 3, gx_ + 3.4, gy - hh * 0.92, tx, ty)
    bot = 'M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (gx_, gy + 3, gx_ + 3.4, gy + hh * 0.92, bx, by)
    P = [Part('limb', pth(top), width=3.8, fill=BOW, line=BONE_LINE,
              over=line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (gx_ + 0.6, gy - 5, gx_ + 2.6, gy - hh * 0.8, tx + 2.2, ty + 2.2),
                        '#ffffff', 0.7, op=0.7)),
         Part('limb', pth(bot), width=3.8, fill=BOW, line=BONE_LINE)]
    # knobbly bone ends at the tips (two little lobes each)
    for x, y, a in ((tx, ty, -1), (bx, by, 1)):
        P.append(Part('fill', ell(x - 1.3, y + a * 0.6, 2.1, 1.9), fill=BOW, shade=BOW_SH, off=(-0.5, -0.6), line=BONE_LINE))
        P.append(Part('fill', ell(x + 1.3, y - a * 0.4, 2.1, 1.9), fill=BOW, shade=BOW_SH, off=(-0.5, -0.6), line=BONE_LINE))
    # the leather-wrapped grip
    P.append(Part('fill', pth('M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (
        gx_ - 2.2, gy - 4.4, gx_ + 2.4, gy - 4.4, gx_ + 2.4, gy + 4.4, gx_ - 2.2, gy + 4.4)),
        fill=LEATHER, shade=LEATHER_SH, off=(-0.6, 0), line=LEATHER_LINE,
        over=line('M%.1f %.1f L%.1f %.1f M%.1f %.1f L%.1f %.1f' % (gx_ - 2, gy - 1.6, gx_ + 2.2, gy - 2.6,
                                                               gx_ - 2, gy + 1.6, gx_ + 2.2, gy + 0.6), LEATHER_LINE, 0.6)))
    if nock:
        d = 'M%.1f %.1f L%.1f %.1f L%.1f %.1f' % (tx, ty, nock[0], nock[1], bx, by)
    else:
        d = 'M%.1f %.1f L%.1f %.1f' % (tx, ty, bx, by)
    string = line(d, BONE_LINE, 1.9) + line(d, SINEW, 0.8)
    if loose:
        # the string still humming: two ghost strings either side
        for dx in (-2.2, 2.2):
            g = 'M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (tx, ty, tx + dx * 1.6, gy, bx, by)
            string += line(g, '#ffffff', 0.7, op=0.55)
    return P, string


def bone_arrow(x0, y, x1, glint=False):
    """A bone arrow from its nock (x0, y) to its tip (x1, y): a pale shaft,
    a sharp bone head and teal-tipped fletching."""
    s = line('M%.1f %.1f L%.1f %.1f' % (x0, y, x1 - 4, y), BONE_LINE, 2.8) + line('M%.1f %.1f L%.1f %.1f' % (x0, y, x1 - 4, y), SINEW, 1.2)
    head = 'M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (x1, y, x1 - 6, y - 3, x1 - 4.6, y, x1 - 6, y + 3)
    s += '<path d="%s" fill="#fffaf0" stroke="%s" stroke-width="1.2" stroke-linejoin="round"/>' % (head, BONE_LINE)
    for a in (-1, 1):
        fl = 'M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (x0 + 1, y, x0 - 1.6, y + a * 3.2, x0 + 3.6, y + a * 3.2, x0 + 6, y)
        s += '<path d="%s" fill="%s" stroke="%s" stroke-width="0.9" stroke-linejoin="round"/>' % (fl, '#9ad8c4', BONE_LINE)
    if glint:
        s += star4(x1 - 2, y, 6.4, '#0a3a34', 0.8) + star4(x1 - 2, y, 4.8, '#e8fff6') + dot(x1 - 2, y, 1.1, '#ffffff')
    return s


def quiver(tilt=0.0, arrows=3):
    """A slim leather quiver slung at the hip, bone arrows' fletching poking up."""
    t = 'rotate(%.1f 50 108)' % (-26 + tilt)
    P = []
    for i in range(arrows):
        x = 47.6 + i * 2.2
        P.append(Part('limb', pth('M%.1f 98 L%.1f 91' % (x, x)), width=1.2, fill=SINEW, line=BONE_LINE))
        P.append(Part('fill', pth('M%.1f 86.6 L%.1f 90.8 L%.1f 93 L%.1f 90.8 Z' % (x, x + 1.6, x, x - 1.6)),
                      fill='#9ad8c4', shade='#5aa892', off=(-0.4, 0), line=BONE_LINE))
    P.append(Part('fill', pth('M46 95.6 L54.4 95.6 L53.6 114 Q50.2 116 46.8 114 Z'), fill=LEATHER, shade=LEATHER_SH,
                  off=(-1, -0.6), line=LEATHER_LINE,
                  over=line('M46.2 98.4 L54.2 98.4', '#3a2418', 1.2, cap='butt') + line('M46.6 110 L53.8 110', '#3a2418', 1.0, cap='butt')))
    return place(P, t)


def torso(dy=0.0, t=''):
    """Rattle's spine, little ribcage and pelvis."""
    t = t or 'translate(0 %.1f)' % dy
    return place([
        Part('limb', pth('M64 96 L63.6 108'), width=2.8, fill=BONE),
        Part('fill', pth('M57.2 97.8 C57.2 95.8 70.8 95.8 70.8 97.8 L70 104 C68 106.2 60 106.2 58 104 Z'),
             fill=BONE, shade=BONE_SH, off=(-1, -1),
             over=line('M58.6 100.4 Q64 102.2 69.6 100.4 M59.2 103 Q64 104.6 69 103', BONE_LINE, 1.1)),
        Part('fill', pth('M57.8 108.2 C58 105.8 69.4 105.8 69.8 108.2 C69.6 111 66 111.4 63.8 109.8 C61.4 111.4 58 111 57.8 108.2 Z'),
             fill=BONE, shade=BONE_SH, off=(-0.8, -0.8))], t)


def open_hand(x, y, ang):
    """A bony hand flung open: palm and three splayed fingers toward ang."""
    t = 'translate(%.1f %.1f) rotate(%.1f)' % (x, y, ang)
    P = [Part('fill', pth(ell_d(0, 0, 2.6, 2.4)), fill=BONE, shade=BONE_SH, off=(-0.6, -0.6))]
    for a in (-38, 0, 38):
        ex, ey = 5.4 * math.cos(math.radians(a)), 5.4 * math.sin(math.radians(a))
        P.append(Part('limb', pth('M1.4 0 L%.1f %.1f' % (ex, ey)), width=1.3, fill=BONE))
    return place(P, t)


def bonebow_svg(frame):
    ctx = Ctx('bb' + frame[:3])
    P = []
    under = shadow(66, 17)
    over = ''
    name = 'bonebow_' + frame
    if frame == 'idle':
        P += quiver()
        P += skel_leg((61, 108.6), (57.4, 118.4), BONE_BACK, BONE_BACK_SH)
        # the bow arm (far side) holds the bow out front, ready
        P += skel_arm((59, 98.4), (88, 100.4), BONE_BACK, BONE_BACK_SH, elbow_out=2.4)
        P += torso()
        P += bb_skull(ctx, 66, 79, 38, 33, 'idle')
        P += archer_hat(66, 79)
        P += skel_leg((66.4, 108.6), (70.4, 118.4), BONE, BONE_SH)
        bow, string = bone_bow(0, 0, 22, 7.4)
        bow[0].under = string
        P += place(bow, 'translate(89.4 99.4) rotate(14)')
        # the string hand resting on the hip
        P += skel_arm((69.6, 98.6), (72.4, 108.2), BONE, BONE_SH, elbow_out=-1.6)
        mark(name, eyes=(69, 80), bow=(89.4, 99.4))
    elif frame == 'draw':
        lean = 'rotate(-4 64 110)'
        P += place(quiver(4), lean)
        P += skel_leg((61, 108.6), (54.6, 118.4), BONE_BACK, BONE_BACK_SH)
        gx_, gy = 97, 91.4
        P += place(skel_arm((59, 98.4), (gx_ - 0.4, gy + 0.6), BONE_BACK, BONE_BACK_SH, elbow_out=0.6), 'translate(0 0)')
        P += place(torso(), lean)
        P += bb_skull(ctx, 64.6, 79.6, 38, 33, 'aim', t='rotate(-3 64 96)')
        P += place(archer_hat(64.6, 79.6), 'rotate(-3 64 96)')
        P += skel_leg((66.4, 108.6), (75, 118.4), BONE, BONE_SH)
        nock = (72.6, gy)
        bow, string = bone_bow(gx_, gy, 18, 8.6, nock=nock)
        bow[0].under = string
        P += bow
        tip = (gx_ + 13.4, gy)
        arrow = bone_arrow(nock[0] - 2.4, gy, tip[0], glint=True)
        # the drawing hand pinches the nock at the cheek
        hand = skel_arm((69.6, 98.4), nock, BONE, BONE_SH, elbow_out=-4.4)
        hand[0].under = arrow
        P += hand
        over = motion('M%.1f %.1f L%.1f %.1f M%.1f %.1f L%.1f %.1f' % (tip[0] + 4, gy - 6, tip[0] + 8, gy - 9,
                                                                    tip[0] + 4, gy + 6, tip[0] + 8, gy + 9), 0.9)
        mark(name, arrow_tip=tip, glint=(tip[0] - 2, gy), nock=nock, eyes=(69, 80))
    elif frame == 'loose':
        P += quiver(-2)
        P += skel_leg((61, 108.6), (55.6, 118.4), BONE_BACK, BONE_BACK_SH)
        gx_, gy = 97, 92
        P += skel_arm((59, 98.4), (gx_ - 0.4, gy + 0.6), BONE_BACK, BONE_BACK_SH, elbow_out=0.6)
        P += torso()
        P += bb_skull(ctx, 65, 79, 38, 33, 'idle', t='rotate(3 64 96)')
        P += place(archer_hat(65, 79), 'rotate(3 64 96)')
        P += skel_leg((66.4, 108.6), (74, 118.4), BONE, BONE_SH)
        bow, string = bone_bow(gx_, gy, 19, 6.8, loose=True)
        bow[0].under = string
        P += bow
        # the drawing hand flung back open, fingers splayed
        P += skel_arm((69.6, 98.4), (52.6, 90.4), BONE, BONE_SH, elbow_out=-3)
        P += open_hand(51, 89.4, 200)
        over = (motion('M%.1f %.1f L%.1f %.1f' % (gx_ + 6, gy, 124, gy), 1.6)
                + motion('M%.1f %.1f L%.1f %.1f M%.1f %.1f L%.1f %.1f' % (gx_ + 12, gy - 4.6, 118, gy - 4.6,
                                                                       gx_ + 14, gy + 4.6, 116, gy + 4.6), 0.9, 0.7)
                + motion('M44 86 L39 83 M45 92 L39 92', 1.1))
        mark(name, arrow_out=(gx_ + 8, gy), eyes=(69, 80))
    elif frame == 'hit':
        P += quiver(-14)
        P += skel_leg((61, 108.6), (56.6, 118.4), BONE_BACK, BONE_BACK_SH)
        P += skel_arm((58.4, 98.6), (50, 92), BONE_BACK, BONE_BACK_SH, elbow_out=-2)
        P += torso()
        P += bb_skull(ctx, 63, 79, 38, 33, 'hit', t='rotate(-12 64 95)')
        # the cap pops off the skull
        P += place(archer_hat(66, 79), 'rotate(-24 60 60) translate(-4 -9)')
        P += skel_leg((66.4, 108.6), (72, 118.4), BONE, BONE_SH)
        bow, string = bone_bow(0, 0, 18, 6.4)
        bow[0].under = string
        P += place(bow, 'translate(90 92) rotate(-38)')
        P += skel_arm((69.6, 98.6), (86, 94), BONE, BONE_SH, elbow_out=-2)
        over = (motion('M88 66 L94 60 M92 74 L100 72 M40 72 L34 66', 1.4) + sweat(92, 82, 0.55, 25))
    else:   # bones: the collapsed pile, the bow snapped, the cap on top
        P += [Part('limb', pth('M45 118.4 L77 112.6'), width=3, fill=BONE_BACK)]
        P += [Part('fill', ell(x, y, 2.3, 2.1), fill=BONE_BACK, shade=BONE_BACK_SH, off=(-0.6, -0.7))
              for x, y in ((44.2, 117.2), (44.8, 120.2), (77.6, 111.2), (78.8, 114))]
        # the bow lying across the pile, its string slack
        bow, string = bone_bow(0, 0, 15, 5)
        bow[0].under = string
        P += place(bow, 'translate(80 110.6) rotate(-84)')
        P.append(Part('fill', pth('M50.2 116 C50.2 113.8 64 113.8 64 116 L63.2 120.4 C61.4 122.2 53.4 122.2 51.4 120.4 Z'),
                      fill=BONE, shade=BONE_SH, off=(-1, -1), over=line('M51.6 117.4 Q57 119 62.6 117.4', BONE_LINE, 1.0)))
        P += [Part('limb', pth('M52 112 L84 119.4'), width=3, fill=BONE)]
        P += [Part('fill', ell(x, y, 2.3, 2.1), fill=BONE, shade=BONE_SH, off=(-0.6, -0.7))
              for x, y in ((51.2, 110.6), (50.6, 113.4), (84.8, 118), (84.2, 121))]
        P += bb_skull(ctx, 64, 108.4, 22, 19, 'dizzy', t='rotate(14 64 116)')
        P += place(archer_hat(64, 108.4, 22 / 38.0), 'rotate(14 64 116)')
        over = (sparkle(48, 94, 2.6, BONE_LINE, '#bff8e6') + sparkle(82, 92, 2.2, BONE_LINE, '#bff8e6')
                + sparkle(70, 88, 1.8, BONE_LINE, '#bff8e6'))
        under = shadow(68, 24)
    return svg128(ctx, under + paint(ctx, P, SPAL) + over)


# ================================================================ Hollow Helm, the empty wax armour

HL = '#2e2016'                      # the armour's ink line
ARM, ARM_SH, ARM_HI = WAX, WAX_SH, '#fffaec'
ARM_BACK, ARM_BACK_SH = '#d9ccaa', '#b6a680'
VISOR = '#140c0a'
DOOR, DOOR_SH, DOOR_HI, DOOR_LINE = '#7a4a2a', '#553018', '#a06a40', '#241208'
IRON, IRON_SH, IRON_HI = '#4a4658', '#302c3c', '#8a86a0'
HPAL = dict(line=HL, rim=RIM, base=ARM, shade=ARM_SH)


def helm_head(ctx, mood='idle', smoke=False):
    """The great helm, local to its centre (0, 0): a round-topped wax bucket
    with a visor slit on its front (right), teal glints inside, breathing
    holes, a riveted rim, a wax drip and a snuffed wick on top.
    mood: idle, fierce (glints narrowed), wide (round, surprised), hurt (><)."""
    helm_d = 'M-16.4 13.6 L-16.6 -3 C-16.6 -12.6 -9.4 -17.4 0 -17.4 C9.6 -17.4 16.6 -12.4 16.6 -3 L16.4 13.6 Q0 17.4 -16.4 13.6 Z'
    f = ''
    # the visor: a dark slit and a breath slot, lit from inside by the glints
    slit = 'M-3.4 -3.6 L15.4 -3.6 Q16.6 -3.6 16.6 -2.2 L16.6 1.6 Q16.6 3 15.2 3 L-3.4 3 Q-4.8 3 -4.8 1.6 L-4.8 -2.2 Q-4.8 -3.6 -3.4 -3.6 Z'
    f += '<path d="%s" fill="%s"/>' % (slit, VISOR)
    f += '<path d="M6.6 3 L9.4 3 L9.4 10.4 Q8 11.4 6.6 10.4 Z" fill="%s"/>' % VISOR
    halo = ctx.radgrad([(0, TEAL, 0.9), (0.5, TEAL, 0.3), (1, TEAL, 0)])
    for ex in (2.6, 11.4):
        if mood == 'hurt':
            f += squeeze(ex, -0.3, 4.6, TEAL, flip=ex > 6, w=1.3)
            continue
        f += '<circle cx="%.1f" cy="-0.3" r="4.6" fill="%s"/>' % (ex, halo)
        if mood == 'fierce':
            f += '<path d="M%.1f -1.6 L%.1f 0.4 L%.1f 1.2 L%.1f -0.6 Z" fill="#e8fff6"/>' % (ex - 2.2, ex + 2.2, ex + 2.2, ex - 2.2)
        elif mood == 'wide':
            f += dot(ex, -0.3, 2.2, '#e8fff6') + dot(ex, -0.3, 1.0, TEAL)
        else:
            f += dot(ex, -0.3, 1.9, '#e8fff6') + dot(ex - 0.6, -0.9, 0.7, '#ffffff')
    for hx, hy in ((12.6, 6.2), (14.8, 6.2), (12.6, 8.8), (14.8, 8.8)):
        f += dot(hx, hy, 0.75, VISOR)
    # the rim: a riveted band round the bottom, and a ridge down the front
    f += line('M-16.2 9.6 Q0 13.2 16.4 9.6', HL, 0.9, op=0.7)
    f += ''.join(dot(x, y, 0.9, HL, 0.8) for x, y in ((-12, 11.4), (-4.4, 12.4), (4, 12.4), (11.6, 11.4)))
    f += line('M6.4 -16.6 Q9 -12 8 -3.8', ARM_SH, 1.2, op=0.9)
    # a drip of wax running down from the crown
    drip = 'M-8.4 -15.2 Q-12.6 -12 -12.8 -6 L-12.8 -1.6 Q-12.8 0.4 -11.4 0.4 Q-10 0.4 -10 -1.6 L-10 -6.4 Q-9.6 -11 -6.6 -14 Z'
    f += '<path d="%s" fill="%s" stroke="%s" stroke-width="0.7"/>' % (drip, ARM_HI, ARM_SH)
    hl = spec(-9.2, -11.4, 3.6, 1.6, rot=-40, op=0.95) + dot(-4.4, -14.6, 0.9, '#ffffff', 0.9)
    P = [Part('fill', pth(helm_d), off=(-2.6, -2.8), over=f, hl=hl)]
    # the snuffed wick on top (a part of its own, so it gets the sticker rim)
    P.insert(0, Part('limb', pth('M-0.4 -16 Q-1.6 -19.6 0.8 -22.6'), width=1.6, fill='#3a2a20', line=HL))
    if smoke:
        P[0].over = line('M1.2 -24.6 Q3.8 -27.4 1.4 -30 Q-1 -32.4 2 -35', '#d6cee0', 1.1, op=0.8)
    return P


def helm_body(dy=0.0, emblem=True):
    """Breastplate, pauldron and the faulds skirt (the neck hole left dark)."""
    t = 'translate(0 %.1f)' % dy
    P = []
    neck = '<ellipse cx="62" cy="91.6" rx="9.6" ry="3" fill="%s"/>' % VISOR
    plate = 'M50.4 94 C50.4 89.6 73.6 89.6 73.6 94 L72.4 108 Q62 112 51.6 108 Z'
    over = neck
    if emblem:
        # the Vigil's flame, etched and faded
        over += '<path d="%s" fill="none" stroke="%s" stroke-width="0.9" stroke-linejoin="round" opacity="0.8"/>' % (
            flame_d(64.6, 106, 6, 9.6, 0.6), ARM_SH)
    over += line('M52 97.4 Q62 99.4 72.2 97.4', HL, 0.8, op=0.45)
    P.append(Part('fill', pth(plate), off=(-2.2, -2.4), over=over, hl=spec(55.4, 96.4, 1.8, 3.2, rot=10, op=0.8)))
    for i, y in enumerate((108.4, 111.6)):
        P.append(Part('fill', pth('M%.1f %.1f L%.1f %.1f L%.1f %.1f Q62 %.1f %.1f %.1f Z' % (
            51.4 - i * 0.8, y, 72.6 + i * 0.8, y, 72.2 + i * 0.8, y + 3.6, y + 5.4, 51.8 - i * 0.8, y + 3.6)),
            off=(-0.8, -0.8), lw=1.0))
    return place(P, t)


def helm_leg(hip, foot, back=False):
    fill, shade = (ARM_BACK, ARM_BACK_SH) if back else (ARM, ARM_SH)
    hx, hy = hip
    fx, fy = foot
    P = [Part('limb', pth('M%.1f %.1f L%.1f %.1f' % (hx, hy, fx, fy - 2.4)), width=5.4, fill=fill)]
    sab = 'M%.1f %.1f L%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z' % (
        fx - 4, fy + 2.6, fx - 4, fy - 1.6, fx - 3.6, fy - 4, fx + 1.4, fy - 4, fx + 2.6, fy - 1.8,
        fx + 5.4, fy - 1.2, fx + 7.2, fy + 0.6, fx + 7.2, fy + 2.6)
    P.append(Part('fill', pth(sab), fill=fill, shade=shade, off=(-0.8, -1),
                  over=line('M%.1f %.1f L%.1f %.1f' % (fx + 1.6, fy - 3, fx + 1.8, fy + 2.2), HL, 0.7, op=0.6)))
    return P


def gauntlet(x, y, ang=0.0, back=False, open_=False):
    fill, shade = (ARM_BACK, ARM_BACK_SH) if back else (ARM, ARM_SH)
    t = 'translate(%.1f %.1f) rotate(%.1f)' % (x, y, ang)
    P = [Part('fill', pth(ell_d(0, 0, 3.4, 3.1)), fill=fill, shade=shade, off=(-0.8, -0.8),
              over=line('M0.6 -1.6 L3 -1.6 M0.6 1 L3 1', HL, 0.6, op=0.7))]
    if open_:
        for a in (-50, -10, 30):
            ex, ey = 6.2 * math.cos(math.radians(a)), 6.2 * math.sin(math.radians(a))
            P.append(Part('limb', pth('M2 0 L%.1f %.1f' % (ex, ey)), width=1.6, fill=fill))
    return place(P, t)


def door_shield(flash=False, sparks=False):
    """The church-door shield, local to its centre (0, 0), 24 x 44 units:
    oak planks under an arched iron rim, two strap hinges curling at the
    ends, rivets and an iron ring knocker."""
    door = 'M-12 22 L-12 -9.6 C-12 -18.4 -6 -22 0 -22 C6 -22 12 -18.4 12 -9.6 L12 22 Z'
    f = ''
    f += line('M-4 -21 L-4 21.4 M4 -21 L4 21.4', DOOR_LINE, 0.9, op=0.75)
    f += line('M-7.6 -18 L-7.6 21 M0.6 -21.6 L0.6 21 M8.2 -18 L8.2 21', DOOR_HI, 0.6, op=0.5)
    f += '<path d="M-10 -9.6 C-10 -17 -5 -20 0 -20 C5 -20 10 -17 10 -9.6" fill="none" stroke="%s" stroke-width="2.2"/>' % IRON
    for y in (-6.4, 13):
        f += '<path d="M-12 %.1f L12 %.1f L12 %.1f L-12 %.1f Z" fill="%s" stroke="%s" stroke-width="0.8"/>' % (
            y - 1.9, y - 1.9, y + 1.9, y + 1.9, IRON, DOOR_LINE)
        f += line('M-11.4 %.1f L11.4 %.1f' % (y - 1, y - 1), IRON_HI, 0.6, op=0.8)
        f += ''.join(dot(x, y, 0.75, IRON_HI) for x in (-8.6, -2.6, 3.4, 9.2))
        # the hinge strap curls round the door's left edge
        f += line('M-12 %.1f Q-15.6 %.1f -14.2 %.1f' % (y, y + 1.6, y + 4), IRON, 1.6)
    # the ring knocker on its round plate
    f += dot(0.8, 3, 2.2, IRON, None) + dot(0.8, 3, 1.0, IRON_HI)
    f += '<circle cx="0.8" cy="6.4" r="3.4" fill="none" stroke="%s" stroke-width="2.4"/>' % DOOR_LINE
    f += '<circle cx="0.8" cy="6.4" r="3.4" fill="none" stroke="%s" stroke-width="1.3"/>' % IRON_HI
    f += '<path d="M-1.2 -13.4 L2.8 -13.4 L2.2 -10.4 L-0.6 -10.4 Z" fill="%s"/>' % DOOR_LINE
    rim = ''
    if flash:
        rim = ('<path d="%s" fill="none" stroke="#fff6dc" stroke-width="2.4" stroke-linejoin="round"/>' % door
               + '<path d="%s" fill="none" stroke="#ffffff" stroke-width="1" stroke-linejoin="round"/>' % door)
    P = [Part('fill', pth(door), fill=DOOR, shade=DOOR_SH, off=(-3, -1.6), line=DOOR_LINE, over=f + rim,
              hl=line('M-10.4 18 L-10.4 -9.4 C-10.4 -15 -7 -18.6 -2.6 -19.8', '#c08a5a', 1.2, op=0.8))]
    if sparks:
        P[0].over += (sparkle(9, -12, 3.6, HL, '#fff6dc') + sparkle(12.6, 3, 2.4, HL, '#fff6dc'))
    return P


def helm_svg(frame):
    ctx = Ctx('hh' + frame[:3] + frame[-1])
    name = 'helm_' + frame
    P = []
    under = shadow(66, 20)
    over = ''
    if frame in ('walk1', 'walk2'):
        a = 1 if frame == 'walk1' else -1
        bob = 0 if frame == 'walk1' else 1.0
        P += gauntlet(47 - 2 * a, 106 + bob, 150, back=True)
        P += helm_leg((57, 112 + bob), (54.6 - 3.6 * a, 119.4), back=True)
        P += helm_body(bob)
        P += helm_leg((66, 112 + bob), (68.6 + 3.6 * a, 119.4))
        P += place(helm_head(ctx), 'translate(61 %.1f)' % (76 + bob))
        P += place(door_shield(), 'translate(86.4 %.1f) rotate(2)' % (97.6 + bob * 1.4))
        P += gauntlet(76.6, 99 + bob, 10)
        mark(name, eyes=(68, 76 + bob), shield=(86.4, 97.6 + bob))
    elif frame == 'block':
        # braced behind the raised door, the helm ducked
        P += gauntlet(46, 104, 160, back=True)
        P += helm_leg((57, 113), (50.6, 119.4), back=True)
        P += helm_body(2.4)
        P += helm_leg((66, 113), (70.6, 119.4))
        P += place(helm_head(ctx, 'fierce'), 'translate(62 80.6) rotate(6)')
        P += place(door_shield(sparks=True), 'translate(88.6 93) rotate(-5)')
        P += gauntlet(78, 96, 0)
        over = motion('M104 72 L110 66 M107 84 L115 82 M106 97 L113 99', 1.3)
        mark(name, eyes=(69, 81), shield=(88.6, 93))
    elif frame == 'bash':
        lean = 'rotate(10 64 120)'
        P += place(gauntlet(45, 102, 170, back=True), lean)
        P += helm_leg((57, 112), (44.6, 119.4), back=True)
        P += place(helm_body(0), lean)
        P += helm_leg((66, 112), (76.4, 119.4))
        P += place(helm_head(ctx, 'fierce'), lean + ' translate(63 76)')
        P += place(door_shield(flash=True), 'translate(97.4 97) rotate(8)')
        P += place(gauntlet(79, 98, 0), lean)
        over = motion('M32 84 L20 84 M34 96 L18 96 M36 108 L24 108', 1.4, 0.8)
        mark(name, eyes=(72, 78), shield=(97.4, 97), rim=(108, 80))
    elif frame == 'noshield':
        # the door dropped flat behind him: arms up in a panic, his front open
        P += place(door_shield(), 'translate(30 118.6) rotate(-90) scale(0.26 1)')
        P += helm_leg((57, 112), (53.4, 119.4), back=True)
        P += gauntlet(44, 86, -120, back=True, open_=True)
        P += [Part('limb', pth('M53 96 Q46 94 45 88'), width=4.4, fill=ARM_BACK)]
        P += helm_body(0)
        P += helm_leg((66, 112), (70.4, 119.4))
        P += place(helm_head(ctx, 'wide'), 'translate(61 74) rotate(-4)')
        P += [Part('limb', pth('M71 96 Q80 94 83 87'), width=4.4, fill=ARM)]
        P += gauntlet(84, 85, -60, open_=True)
        over = sweat(83, 64, 0.6, 20) + motion('M88 66 L94 60 M40 66 L34 60', 1.3)
        mark(name, eyes=(68, 74))
    else:   # hit: the helm knocked up off the collar, a puff out of the hollow
        P += gauntlet(46, 104, 160, back=True)
        P += helm_leg((57, 112), (53, 119.4), back=True)
        P += helm_body(0.6)
        P += helm_leg((66, 112), (70, 119.4))
        puff = ''.join('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="#cfc6d8" stroke="%s" stroke-width="1" opacity="0.9"/>' % (
            x, y, r, HL) for x, y, r in ((55, 88.6, 3.2), (61, 86.4, 4), (67.6, 88, 3.4), (72.6, 86, 2.4)))
        P += place(helm_head(ctx, 'hurt', smoke=True), 'translate(58 68) rotate(-16)')
        P[-1].under = puff + P[-1].under
        P += place(door_shield(), 'translate(88 99) rotate(10)')
        P += gauntlet(78, 100, 20)
        over = motion('M78 50 L84 44 M86 60 L94 57 M36 62 L30 56', 1.3) + sweat(80, 64, 0.55, 25)
        mark(name, eyes=(64, 68))
    return svg128(ctx, under + paint(ctx, P, HPAL) + over)


# ================================================================ Gutterwing, the light moth

MOTH, MOTH_SH, MOTH_LINE = '#d8e8c8', '#aac0a0', '#1c2418'
MOTH_BACK = '#bcd0ae'
FUR, FUR_SH, FUR_HI = '#f4f2e0', '#d4d6bc', '#ffffff'
SPOT, SPOT_RING = '#2a2c24', '#f4f2e0'
MPAL = dict(line=MOTH_LINE, rim=RIM, base=MOTH, shade=MOTH_SH)
MFACE = dict(line=MOTH_LINE, base=FUR, iris0='#0e1218', iris1='#2c3a4c', iris2='#8aa8c0', blush='#ff9ab0')

# the left wing pair in each pose, x mirrored round 64 for the right one:
# (forewing path, hindwing path, forewing eye-spot, hindwing eye-spot)
WINGS = {
    'up': ('M58 57 Q44 38 27.4 32.6 Q21.6 34.4 24.4 42.6 Q29.4 55 45 60.6 Q52 62.6 58 62.6 Z',
           'M58 62 Q45 61.4 38.6 69 Q35.6 77.6 43.6 79.2 Q53.4 76.6 59 68 Z', (37.6, 45.4, 4.6), (45.6, 71.6, 2.6)),
    'down': ('M58 58 Q41.6 55 27 67.4 Q23.4 75.6 30 78.2 Q44 77.4 58 65 Z',
             'M58.6 64 Q49 69.4 46.6 79.4 Q47.6 86.4 54.2 83.4 Q59.4 76.4 60.4 68 Z', (36.6, 69.4, 4.4), (52.6, 77.6, 2.4)),
    'crumpled': ('M58 57 Q48 44 38 40.6 Q33 42 35 48.6 Q39.6 56 48 60.6 Q53 62.6 58 62.6 Z',
                 'M58 62 Q50 63 46 68.6 Q45 74 50 74.6 Q55.6 72.6 59 67 Z', (43.4, 49.6, 3.4), (50, 69.4, 2)),
}


def moth_wing(side, mode, tilt='translate(0 0)'):
    def X(x):
        return 64 + side * (64 - x)

    def mirror(d):
        import re
        nums = re.split(r'(-?\d+(?:\.\d+)?)', d)
        out, k = '', 0
        for tok in nums:
            if re.fullmatch(r'-?\d+(?:\.\d+)?', tok):
                v = float(tok)
                out += '%.1f' % (X(v) if k % 2 == 0 else v)
                k += 1
            else:
                out += tok
        return out
    fore, hind, fs, hs = WINGS[mode]
    near = side < 0
    col = MOTH if near else MOTH_BACK
    parts = []
    for d, sp in ((hind, hs), (fore, fs)):
        x, y, r = sp
        spot = (dot(X(x), y, r, SPOT) + '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="none" stroke="%s" stroke-width="0.8" opacity="0.9"/>' % (
            X(x), y, r * 0.62, SPOT_RING) + dot(X(x) - side * r * 0.2, y - r * 0.2, r * 0.26, '#ffffff'))
        veins = line('M%.1f %.1f L%.1f %.1f M%.1f %.1f L%.1f %.1f' % (X(58), 60, X(x + (58 - x) * 0.25), y + (60 - y) * 0.25,
                                                                   X(58), 61, X(x - 4), y + 7), MOTH_SH, 0.9, op=0.9)
        parts.append(Part('fill', xf(mirror(d), tilt), fill=col, shade=MOTH_SH, off=(-1.4, -1.6), over=gx(veins + spot, tilt)))
    return parts


def fuzzy_d(cx, cy, r, bumps=13, depth=1.6, ry=None):
    """A fluffy round outline: a circle of little outward scallops."""
    ry = ry or r
    pts = []
    for i in range(bumps + 1):
        a = -math.pi / 2 + i * 2 * math.pi / bumps
        pts.append((cx + r * math.cos(a), cy + ry * math.sin(a)))
    d = 'M%.1f %.1f' % pts[0]
    for i in range(bumps):
        a = -math.pi / 2 + (i + 0.5) * 2 * math.pi / bumps
        c = (cx + (r + depth * 2) * math.cos(a), cy + (ry + depth * 2) * math.sin(a))
        d += ' Q%.1f %.1f %.1f %.1f' % (c[0], c[1], pts[i + 1][0], pts[i + 1][1])
    return d + ' Z'


def feather_antenna(x0, y0, x1, y1, bend):
    """A fern-like moth antenna from (x0, y0) to its tip (x1, y1)."""
    mx, my = (x0 + x1) / 2 + bend, (y0 + y1) / 2
    stem = 'M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (x0, y0, mx, my, x1, y1)
    barbs = ''
    for i in range(1, 6):
        t = i / 6.0
        px = (1 - t) ** 2 * x0 + 2 * (1 - t) * t * mx + t * t * x1
        py = (1 - t) ** 2 * y0 + 2 * (1 - t) * t * my + t * t * y1
        ln = 3.2 * (1 - t * 0.5)
        barbs += 'M%.1f %.1f l%.1f %.1f M%.1f %.1f l%.1f %.1f ' % (px, py, -ln, -ln * 0.3, px, py, ln, -ln * 0.3)
    return Part('limb', pth(stem), width=1.3, fill=FUR_SH, over=line(barbs, MOTH_LINE, 0.9) + line(barbs, FUR, 0.4))


def moth_body(ctx, cx, cy, mood, tilt='translate(0 0)'):
    """The fuzzy round body with the face on it and the striped tail below."""
    P = []
    tail = 'M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z' % (
        cx - 5, cy + 7, cx - 5, cy + 14, cx - 2, cy + 19, cx, cy + 19, cx + 2, cy + 19, cx + 5, cy + 14, cx + 5, cy + 7)
    P.append(Part('fill', xf(tail, tilt), fill=MOTH, shade=MOTH_SH, off=(-1, -1),
                  over=gx(line('M%.1f %.1f Q%.1f %.1f %.1f %.1f M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (
                      cx - 4.4, cy + 11.6, cx, cy + 13.4, cx + 4.4, cy + 11.6, cx - 3.4, cy + 15.4, cx, cy + 16.8, cx + 3.4, cy + 15.4),
                      MOTH_LINE, 0.9, op=0.8), tilt)))
    P.append(feather_antenna(cx - 2.6, cy - 10, cx - 12, cy - 24, -3))
    P.append(feather_antenna(cx + 3, cy - 10, cx + 13, cy - 23, 3))
    P[-2].tpl = P[-2].tpl.replace(' {a}/>', ' transform="%s" {a}/>' % tilt)
    P[-1].tpl = P[-1].tpl.replace(' {a}/>', ' transform="%s" {a}/>' % tilt)
    P[-2].over, P[-1].over = gx(P[-2].over, tilt), gx(P[-1].over, tilt)
    f = ''
    # the fluffy ruff and a lighter forelock
    f += '<path d="%s" fill="%s"/>' % (fuzzy_d(cx, cy + 6.4, 9.4, 11, 1.1, 4.6), FUR_SH)
    f += '<path d="%s" fill="%s"/>' % (fuzzy_d(cx - 1, cy - 8.6, 5.4, 7, 0.9, 2.6), FUR_HI)
    e1, e2 = (cx - 2.4, cy - 0.6, 8, 10), (cx + 6.6, cy - 1, 6.4, 9.4)
    if mood == 'sip':
        for ex, ey, w, h in (e1, e2):
            f += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (ex - w / 2, ey, ex, ey - h * 0.4, ex + w / 2, ey), MOTH_LINE, 1.5)
        f += '<ellipse cx="%.1f" cy="%.1f" rx="1.4" ry="1.1" fill="%s"/>' % (cx + 3.4, cy + 5.4, MOTH_LINE)
    elif mood == 'hurt':
        f += squeeze(e1[0], e1[1], 7, MOTH_LINE, w=1.8) + squeeze(e2[0], e2[1], 6, MOTH_LINE, flip=True, w=1.8)
        f += '<path d="M%.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f Z" fill="%s"/>' % (
            cx + 1.4, cy + 5, cx + 3.2, cy + 3.8, cx + 5, cy + 5, cx + 3.2, cy + 8, cx + 1.4, cy + 5, MOTH_LINE)
    else:
        f += eye(ctx, *e1, MFACE, look=(0.8, 0.3)) + eye(ctx, *e2, MFACE, look=(0.8, 0.3))
        f += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (cx + 1.4, cy + 5.2, cx + 3, cy + 6.4, cx + 4.8, cy + 5.2), MOTH_LINE, 1.0)
    f += blush(cx - 6.6, cy + 4.4, MFACE, rx=2.2, ry=1.3, op=0.7) + blush(cx + 11.2, cy + 3.6, MFACE, rx=1.4, ry=1.1, op=0.7)
    body = xf(fuzzy_d(cx, cy, 11.4, 14, 1.2), tilt)
    P.append(Part('fill', body, fill=FUR, shade=FUR_SH, off=(-2, -2.2), over=gx(f, tilt),
                  hl=gx(spec(cx - 5.4, cy - 6.4, 2.6, 1.4, rot=-38, op=0.8), tilt)))
    return P


def wing_svg(frame):
    ctx = Ctx('gw' + frame[:2] + frame[-1])
    name = 'wing_' + frame
    over, under = '', ''
    if frame in ('fly1', 'fly2'):
        mode = 'up' if frame == 'fly1' else 'down'
        bob = 0 if frame == 'fly1' else 1.4
        k = 'translate(64 63) scale(0.86) translate(-64 -63)'
        P = moth_wing(1, mode, k) + moth_wing(-1, mode, k)
        P += moth_body(ctx, 64, 64 + bob, 'idle')
        # scale dust shed by the beat
        dust = ''.join(dot(x, y, r, '#f4f2e0', 0.8) for x, y, r in ((30, 84, 0.9), (98, 80, 0.8), (26, 60, 0.7)))
        over = dust
        mark(name, body=(64, 64 + bob))
    elif frame == 'latch':
        # hugging the flame: body over its tip, wings curled down round it
        fl = flame(ctx, 64, 64, 12.4, 22, lean=0.6, line_w=1.2)
        under = fl
        P = []
        for side in (1, -1):
            def X(x, side=side):
                return 64 + side * (64 - x)
            col = MOTH if side < 0 else MOTH_BACK
            fore = 'M%.1f 40 Q%.1f 42 %.1f 56 Q%.1f 68 %.1f 74 Q%.1f 76 %.1f 70.6 Q%.1f 58 %.1f 44 Z' % (
                X(60), X(46), X(42.6), X(43.4), X(52), X(56.4), X(55.6), X(53), X(60.4))
            spot = (dot(X(47.6), 58, 3.6, SPOT) + '<circle cx="%.1f" cy="58" r="2.2" fill="none" stroke="%s" stroke-width="0.8"/>' % (
                X(47.6), SPOT_RING) + dot(X(47.6) - side * 0.7, 57.2, 0.9, '#ffffff'))
            P.append(Part('fill', pth(fore), fill=col, shade=MOTH_SH, off=(-1.2, -1.4), over=spot))
        P += moth_body(ctx, 64, 34, 'sip')
        over = sparkle(84, 36, 2.4, MOTH_LINE, '#fff2c8') + sparkle(44, 30, 1.8, MOTH_LINE, '#fff2c8')
        mark(name, flame=(64, 64))
    else:   # pop: swatted off, wings crumpled, scales puffing out
        tilt = 'rotate(-16 64 64)'
        P = [place(moth_wing(1, 'crumpled'), tilt)[1], place(moth_wing(-1, 'crumpled'), tilt)[1]]
        P += moth_body(ctx, 64, 64, 'hurt', tilt=tilt)
        over = (''.join(dot(x, y, r, '#f4f2e0', 0.9) + '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="none" stroke="%s" stroke-width="0.6"/>' % (
            x, y, r, MOTH_LINE) for x, y, r in ((34, 44, 1.6), (94, 50, 1.4), (30, 76, 1.2), (98, 78, 1.5), (60, 30, 1.1)))
            + sweat(84, 46, 0.55, 20) + motion('M40 40 L34 34 M88 38 L94 32 M92 64 L100 64 M36 64 L28 66', 1.3))
    return svg128(ctx, under + paint(ctx, P, MPAL) + over)


# ================================================================ Dripkin, the living drip

DRIP, DRIP_SH, DRIP_LINE = '#fff2d6', '#e6cc9a', '#5a3a1e'
DPAL = dict(line=DRIP_LINE, rim=RIM, base=DRIP, shade=DRIP_SH)


def dot_eyes(pts, look=(0, 0), r=1.9, mood='open'):
    s = ''
    for i, (x, y) in enumerate(pts):
        if mood == 'wide':
            s += dot(x, y, r * 1.35, '#ffffff') + '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="none" stroke="%s" stroke-width="0.8"/>' % (
                x, y, r * 1.35, DRIP_LINE) + dot(x + look[0], y + look[1], r * 0.7, '#2a1a10')
        elif mood == 'dizzy':
            s += swirl_eye(x, y, r * 1.3, '#2a1a10', 0.9)
        elif mood == 'squish':
            s += squeeze(x, y, r * 2.6, '#2a1a10', flip=i == 1, w=1.3)
        else:
            s += dot(x + look[0], y + look[1], r, '#2a1a10') + dot(x + look[0] - r * 0.35, y + look[1] - r * 0.4, r * 0.38, '#ffffff')
    return s


def tiny_wick(x0, y0, x1, y1, bend=1.6):
    return Part('limb', pth('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (x0, y0, (x0 + x1) / 2 + bend, (y0 + y1) / 2, x1, y1)),
                width=1.5, fill='#3a2a20', line=DRIP_LINE)


def gloss(x, y, rx, ry, rot=-30):
    return spec(x, y, rx, ry, rot=rot, op=0.95) + dot(x + rx * 0.9, y + ry * 1.9, min(rx, ry) * 0.45, '#ffffff', 0.9)


def drip_svg(frame):
    ctx = Ctx('dk' + frame[:2] + frame[-1])
    name = 'drip_' + frame
    P = []
    over, under = '', ''
    if frame == 'hang':
        # glued to the ceiling (y 10) by a smear of wax, the bulb hanging below
        d = ('M55 -6 L73 -6 L73 8.4 C73 11.6 68.8 13.6 68.4 17.4 C68.2 20.4 69.6 22.6 71 24.4 C74.6 28.2 76.8 31 76.8 38 '
             'C76.8 45 71 49.4 64 49.4 C57 49.4 51.2 45 51.2 38 C51.2 31 53.4 28.2 57 24.4 '
             'C58.4 22.6 59.8 20.4 59.6 17.4 C59.2 13.6 55 11.6 55 8.4 Z')
        f = dot_eyes(((59.4, 40), (68.6, 40)), look=(0.3, 0.8)) + line('M62.4 44.8 Q64 45.8 65.6 44.8', DRIP_LINE, 0.9)
        f += line('M58 8.6 Q59.6 11.6 61.4 13 M70 8.6 Q68.4 11.6 66.6 13', DRIP_SH, 1.0, op=0.9)
        P.append(Part('fill', pth(d), off=(-2.4, -2), over=f, hl=gloss(56, 32.4, 2, 3.6, rot=-14)))
        mark(name, ceiling=DRIP_CEILING, glint=(57, 32.4), tip=(64, 49.4))
    elif frame == 'drop':
        d = 'M64 80 C66.4 88 76.4 98 76.4 108.6 C76.4 116.4 70.8 121.4 64 121.4 C57.2 121.4 51.6 116.4 51.6 108.6 C51.6 98 61.6 88 64 80 Z'
        f = dot_eyes(((59.4, 107.4), (68.6, 107.4)), look=(0, 0.5), mood='wide')
        f += '<ellipse cx="64" cy="114.2" rx="1.6" ry="2" fill="%s"/>' % DRIP_LINE
        P.append(tiny_wick(64, 81, 65.4, 73.4))
        P.append(Part('fill', pth(d), off=(-2.2, -1.8), over=f, hl=gloss(56.8, 101, 1.8, 3.6, rot=-14)))
        over = motion('M55 58 L55 76 M73 60 L73 78 M64 50 L64 64', 1.3, 0.85)
    elif frame == 'splat':
        d = ('M38.6 121.4 C38.2 117.6 42 116.8 45.4 115.6 C48 111.8 55 109.8 64 109.8 C73 109.8 80 111.8 82.6 115.6 '
             'C86 116.8 89.8 117.6 89.4 121.4 Z')
        f = dot_eyes(((58, 115.4), (70, 115.4)), mood='dizzy', r=2.2)
        P.append(tiny_wick(64, 110.4, 71.4, 106.4, bend=-2.4))
        P.append(Part('fill', pth(d), off=(-2.4, -1.6), over=f, hl=gloss(50, 113.4, 3.4, 1.4, rot=-8)))
        for x, y, k in ((33, 108, 0.8), (95, 104, 0.9), (44, 100, 0.6), (86, 96, 0.55)):
            over += ('<g transform="translate(%.1f %.1f) scale(%.2f)"><path d="M0 -6 C2.4 -2.4 4.4 0 4.4 2.6 C4.4 5 2.4 6.4 0 6.4 '
                     'C-2.4 6.4 -4.4 5 -4.4 2.6 C-4.4 0 -2.4 -2.4 0 -6 Z" fill="%s" stroke="%s" stroke-width="1.8"/>'
                     '<ellipse cx="-1.4" cy="2.4" rx="1" ry="1.6" fill="#ffffff"/></g>') % (x, y, k, DRIP, DRIP_LINE)
        over += kit.star5(64, 100, 3.2, '#ffe27a', DRIP_LINE, 1.0) + kit.star5(76, 103, 2.4, '#ffe27a', DRIP_LINE, 0.9)
        mark(name, top=(64, 110))
    else:   # crawl1 (stretched forward) and crawl2 (bunched up), a wax trail behind
        if frame == 'crawl1':
            d = 'M42 121.4 C42 115 48 109.6 58 107.4 C66 105.4 76 102.6 82 106.4 C88 110 88.6 116 88 121.4 Z'
            wick = (74.6, 104, 77, 96.6)
            eyes = ((75, 112.4), (83, 112.4))
            g = (52, 112.6, 3, 1.4)
            trail = 'M22 121.6 L44 121.6 Q40 118.4 30 119.4 Q24 120 22 121.6 Z'
        else:
            d = 'M48.4 121.4 C48 111 54.2 97.6 65 97.6 C75.8 97.6 81.2 110 80.6 121.4 Z'
            wick = (65.4, 98, 66.4, 90.4)
            eyes = ((68.2, 108.8), (76, 108.8))
            g = (56, 103.6, 1.8, 3.4)
            trail = 'M26 121.6 L50 121.6 Q46 118.2 36 119.2 Q29 119.8 26 121.6 Z'
        under = '<path d="%s" fill="%s" stroke="%s" stroke-width="1" opacity="0.85"/>' % (trail, DRIP_SH, DRIP_LINE)
        f = dot_eyes(eyes, look=(0.8, 0))
        f += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (eyes[0][0] + 2, eyes[0][1] + 4.4, eyes[0][0] + 4, eyes[0][1] + 5.6,
                                                     eyes[0][0] + 6, eyes[0][1] + 4.4), DRIP_LINE, 0.9)
        P.append(tiny_wick(*wick))
        P.append(Part('fill', pth(d), off=(-2.4, -1.8), over=f, hl=gloss(*g, rot=-20)))
    return svg128(ctx, under + paint(ctx, P, DPAL) + over)


# ================================================================ Brinejaw, the lure fish

JAW_SKIN, JAW_SKIN_SH = '#4c6e74', '#34505a'
FIN, FIN_SH = '#6aa6a0', '#447a76'
WATER, WATER_LINE = '#bfe8ff', '#3a6a9a'
JPAL = dict(line=BONE_LINE, rim=RIM, base=BONE, shade=BONE_SH)


def fish(ctx, mood, lure_back=False):
    """The fish local to its middle (0, 0), facing right: a dusky x-ray body
    with pale ribs, a spiny dorsal fin and a bone-rayed tail, a big bony
    skull with a teal eye and an underbite of needle teeth, and a lure on a
    stalk dangling a little false flame in front of its face.
    mood: calm (hide), bite (leap: jaws wide), dizzy (fall)."""
    P = []
    # the tail: a fan of bone rays with webbing between
    tail = 'M-17 -1 L-29.6 -12.6 Q-26 -1 -29.6 11.6 L-17 2 Z'
    rays = line('M-18 0 L-28 -10.4 M-18 0 L-27.4 -3.6 M-18 0.6 L-27.4 3.4 M-18 1 L-28 9.4', BONE, 1.2)
    P.append(Part('fill', pth(tail), fill=FIN, shade=FIN_SH, off=(-1, -1), over=rays))
    # the dorsal fin: spines with webbing
    dors = 'M-14 -6 L-11.6 -14 L-8.4 -8 L-5.2 -15 L-2.4 -8.4 L0.8 -13 L2.6 -6 Z'
    P.append(Part('fill', pth(dors), fill=FIN, shade=FIN_SH, off=(-0.6, -0.8),
                  over=line('M-11.6 -13 L-10.8 -7 M-5.2 -14 L-4.8 -7.4 M0.6 -12 L0.4 -6.6', BONE, 0.9)))
    # the body, ribs showing through
    body = 'M-18 -0.6 C-14 -8 -6 -9.6 2 -9 L2 9 C-6 9.6 -14 7.4 -18 1 Z'
    ribs = line('M-13.6 -5.2 Q-11.6 0 -13.6 5 M-9.4 -7 Q-7 0 -9.4 6.8 M-5 -7.8 Q-2.4 0 -5 7.6 M-0.6 -8.4 Q2 0 -0.6 8.2',
                '#d8f0e8', 1.3, op=0.9)
    spine = line('M-17 0 L2 0', '#d8f0e8', 1.4)
    P.append(Part('fill', pth(body), fill=JAW_SKIN, shade=JAW_SKIN_SH, off=(-1.4, -1.6), over=spine + ribs,
                  hl=line('M-14 -5.4 Q-6 -8.8 0 -8.4', '#7aa4a8', 1.1, op=0.9)))
    # the little pectoral fin
    P.append(Part('fill', pth('M3 6 Q-1.4 11.6 -5 12.4 Q-2 8.4 -0.4 5.4 Z'), fill=FIN, shade=FIN_SH, off=(-0.4, -0.6)))
    # the lower jaw: an underbite with needle teeth pointing up
    drop = 7.4 if mood == 'bite' else 0.0
    jt = 'rotate(%.1f 3 5)' % (drop * 3.2)
    jaw = 'M1.4 4 C6 7 14 8.6 21.4 5.4 C22.6 7.6 21.4 10.4 18.4 11.4 C12 13 5 11.6 1 8.2 Z'
    teeth = ''.join('<path d="M%.1f %.1f L%.1f %.1f L%.1f %.1f Z" fill="#fffaf0" stroke="%s" stroke-width="0.6" stroke-linejoin="round"/>' % (
        x, 6.6 + (x - 8) * 0.04, x + 1.1, 2.4 + (x - 8) * 0.02, x + 2.2, 6.4 + (x - 8) * 0.04, BONE_LINE) for x in (7.6, 11.2, 14.8, 18.2))
    P.append(Part('fill', xf(jaw, jt), fill=BONE, shade=BONE_SH, off=(-1, -1.2), over=gx(teeth, jt), under=gx(
        '<path d="M2 3 L21 2 L21 8 L2 8 Z" fill="%s"/>' % '#3a0e1a' if mood == 'bite' else '', jt)))
    # the skull
    skull = 'M-1 -9.4 C4 -13.6 15 -12.8 19.6 -6 C21.6 -3 22.2 1 21 4.4 C14 6.6 6 6 1 4 C-1.6 2 -2.6 -6 -1 -9.4 Z'
    f = ''
    halo = ctx.radgrad([(0, TEAL, 0.55), (1, TEAL, 0)])
    f += '<ellipse cx="9.6" cy="-3" rx="9" ry="7" fill="%s"/>' % halo
    if mood == 'dizzy':
        f += '<ellipse cx="9.6" cy="-3" rx="5" ry="5.4" fill="%s"/>' % BONE_LINE + swirl_eye(9.6, -3, 3.8, TEAL, 1.0)
    else:
        f += glow_eye(ctx, 9.6, -3, 10, 10.8, look=(1.2, -1.2 if mood == 'calm' else 0.4), iris=0.34)
        if mood == 'calm':
            f += '<path d="M4.2 -7.4 Q9.6 -9.8 15 -7.4 L15 -9.4 L4.2 -9.4 Z" fill="%s"/>' % BONE
            f += line('M4.4 -7.2 Q9.6 -9.4 14.8 -7.2', BONE_LINE, 1.1)
        else:
            f += line('M4.4 -9.4 L15 -7', BONE_LINE, 1.5)
    # upper teeth along the snout, a nostril and a gill crack
    f += ''.join('<path d="M%.1f 3.6 L%.1f 6.8 L%.1f 3.8 Z" fill="#fffaf0" stroke="%s" stroke-width="0.5"/>' % (x, x + 0.9, x + 1.8, BONE_LINE)
                 for x in (10, 13.4, 16.8))
    f += dot(18.2, -4.4, 0.8, BONE_LINE) + line('M1.4 -6 Q-0.4 -1 1.6 3', BONE_LINE, 0.9)
    P.append(Part('fill', pth(skull), fill=BONE, shade=BONE_SH, off=(-1.8, -2), over=f,
                  hl=spec(4.4, -8.8, 3, 1.2, rot=-20, op=0.95)))
    # the lure: a stalk from the brow, a little false flame at its end
    if lure_back:
        stalk, bulb = 'M3 -11 Q0 -22 -9 -21', (-10, -18.4)
    else:
        stalk, bulb = 'M5 -11 Q10 -26 22 -21', (23.4, -16.8)
    P.append(Part('limb', pth(stalk), width=1.2, fill='#8ab0a8', line=BONE_LINE))
    bx, by = bulb
    lure = glow(ctx, bx, by - 2, 8, FLAME, 0.7)
    lure += '<circle cx="%.1f" cy="%.1f" r="2.8" fill="#fff2c8" stroke="%s" stroke-width="1"/>' % (bx, by - 1.6, BONE_LINE)
    lure += '<path d="%s" fill="%s"/>' % (flame_d(bx, by - 0.8, 3.2, 5.6, 0.4), FLAME)
    lure += dot(bx - 0.6, by - 2.6, 0.8, '#ffffff')
    P[-1].over = lure
    return P, bulb


def water_drops(pts):
    s = ''
    for x, y, k, r in pts:
        s += ('<g transform="translate(%.1f %.1f) rotate(%.1f) scale(%.2f)"><path d="M0 -6 C2.4 -2.4 4.4 0 4.4 2.6 C4.4 5 2.4 6.4 0 6.4 '
              'C-2.4 6.4 -4.4 5 -4.4 2.6 C-4.4 0 -2.4 -2.4 0 -6 Z" fill="%s" stroke="%s" stroke-width="1.8"/>'
              '<ellipse cx="-1.4" cy="2.4" rx="1" ry="1.6" fill="#ffffff"/></g>') % (x, y, r, k, WATER, WATER_LINE)
    return s


def jaw_svg(frame):
    ctx = Ctx('bj' + frame[:2])
    name = 'jaw_' + frame
    over = ''
    if frame == 'hide':
        t, rot = 'translate(64 64)', 0
        P, bulb = fish(ctx, 'calm')
        over = ''.join('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="none" stroke="%s" stroke-width="1.1"/>' % (x, y, r, WATER)
                       + dot(x - r * 0.35, y - r * 0.35, r * 0.3, '#ffffff') for x, y, r in ((88, 44, 2.2), (84, 36, 1.5), (90, 30, 1.1)))
    elif frame == 'leap':
        t, rot = 'translate(64 64) rotate(-52)', -52
        P, bulb = fish(ctx, 'bite', lure_back=True)
        over = water_drops(((44, 90, 0.7, 20), (54, 98, 0.55, 0), (34, 82, 0.5, 40), (62, 90, 0.45, -10)))
        over += motion('M40 104 L34 112 M50 108 L48 118 M30 94 L22 98', 1.2, 0.8)
    else:   # fall: tumbling back down nose first, spray flung up behind
        t, rot = 'translate(64 64) rotate(58)', 58
        P, bulb = fish(ctx, 'dizzy', lure_back=True)
        over = water_drops(((44, 34, 0.6, 180), (56, 26, 0.5, 170), (36, 44, 0.45, 200)))
    P = place(P, t)
    bx, by = rot_pt(64 + bulb[0], 64 + bulb[1] - 1.6, 64, 64, rot)
    mark(name, lure=(bx, by), centre=(64, 64))
    return svg128(ctx, paint(ctx, P, JPAL) + over)


# ================================================================ Lidlurk, the reliquary mimic

LK = dict(base='#c08a3e', shade='#8a5824', line='#241208', light='#f0c878', panel='#5e3416', window='#1e0c06',
          rivet='#f0d08a')
MOUTH, GUM = '#2a0a12', '#7a2a3a'
LPAL = dict(line=LK['line'], rim=RIM, base=LK['base'], shade=LK['shade'])
LX0, LX1, LY0, LY1, SPLIT = 34.2, 93.8, 62.2, 121.8, 74.6   # the box (a reliquary's 59.6 units) and the lid's seam


def rrect_d(x0, y0, x1, y1, r_top, r_bot):
    return ('M%.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f '
            'L%.1f %.1f Q%.1f %.1f %.1f %.1f Z') % (
        x0 + r_top, y0, x1 - r_top, y0, x1, y0, x1, y0 + r_top, x1, y1 - r_bot, x1, y1, x1 - r_bot, y1,
        x0 + r_bot, y1, x0, y1, x0, y1 - r_bot, x0, y0 + r_top, x0, y0, x0 + r_top, y0)


def lurk_body(ctx, flame_on=True):
    """The box below the seam: the reliquary's bevel, panel and gothic window."""
    c = LK
    art = line('M%.1f %.1f L%.1f %.1f' % (LX0 + 3.8, LY1 - 12, LX0 + 3.8, SPLIT + 1.6), c['light'], 2.0, op=0.9)
    panel = rrect_d(LX0 + 7.8, SPLIT + 3.4, LX1 - 7.8, LY1 - 7.8, 2, 2)
    art += '<path d="%s" fill="%s" stroke="%s" stroke-width="1.4"/>' % (panel, c['panel'], c['line'])
    art += line('M%.1f %.1f L%.1f %.1f' % (LX1 - 8.4, SPLIT + 4, LX1 - 8.4, LY1 - 8.4), c['light'], 1.2, op=0.45)
    x0, x1, top, bot = 53.6, 74.4, SPLIT + 5.4, LY1 - 9.8
    w = x1 - x0
    win = ('M%.1f %.1f L%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f L%.1f %.1f Z' % (
        x0, bot, x0, top + w * 0.5, x0, top + w * 0.2, x0 + w * 0.3, top, (x0 + x1) / 2, top - 1,
        x1 - w * 0.3, top, x1, top + w * 0.2, x1, top + w * 0.5, x1, bot))
    art += '<path d="%s" fill="%s" stroke="%s" stroke-width="1.4"/>' % (win, c['window'], c['line'])
    if flame_on:
        halo = ctx.radgrad([(0, FLAME, 0.6), (0.6, FLAME, 0.2), (1, FLAME, 0)])
        art += '<g clip-path="%s"><ellipse cx="64" cy="%.1f" rx="11" ry="13" fill="%s"/></g>' % (
            ctx.clip('<path d="%s"/>' % win), bot - 10, halo)
        art += flame(ctx, 64, bot - 1.4, 9.6, 16, lean=0.8, halo=False, lcol=c['line'])
    for x, y in ((LX0 + 4.2, LY1 - 4.2), (LX1 - 4.2, LY1 - 4.2)):
        art += dot(x, y, 2.1, c['line']) + dot(x, y, 1.4, c['base']) + dot(x - 0.5, y - 0.5, 0.6, c['rivet'])
    for x, y in ((LX0 + 4, (SPLIT + LY1) / 2), (LX1 - 4, (SPLIT + LY1) / 2), (64, LY1 - 4)):
        art += dot(x, y, 1.2, c['line'], 0.8)
    return Part('fill', pth(rrect_d(LX0, SPLIT, LX1, LY1, 0.6, 5)), off=(-2.6, -2.6), over=art, rim=True)


def lurk_lid(t):
    """The lid: the reliquary's top band with its corner rivets, turned by t."""
    c = LK
    art = line('M%.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f L%.1f %.1f' % (
        LX0 + 3.8, SPLIT - 1.4, LX0 + 3.8, LY0 + 6.6, LX0 + 3.8, LY0 + 3.8, LX0 + 6.6, LY0 + 3.8, LX1 - 10, LY0 + 3.8),
        c['light'], 2.0, op=0.9)
    art += line('M%.1f %.1f L%.1f %.1f' % (LX0 + 7.6, SPLIT - 1.2, LX1 - 7.6, SPLIT - 1.2), c['line'], 1.2, op=0.7)
    for x in (LX0 + 4.2, LX1 - 4.2):
        art += dot(x, LY0 + 4.2, 2.1, c['line']) + dot(x, LY0 + 4.2, 1.4, c['base']) + dot(x - 0.5, LY0 + 3.7, 0.6, c['rivet'])
    art += dot(64, LY0 + 4, 1.2, c['line'], 0.8)
    return Part('fill', xf(rrect_d(LX0, LY0, LX1, SPLIT, 5, 0.6), t), off=(-2.4, -1.6), over=gx(art, t),
                hl=gx(spec(LX0 + 10, LY0 + 6.4, 4, 1.4, rot=-8, op=0.5), t))


def teeth_row(x0, x1, y, n, down, t=''):
    s = ''
    step = (x1 - x0) / float(n)
    for i in range(n):
        x = x0 + i * step
        tip = y + (3.8 if down else -3.8)
        s += '<path d="M%.1f %.1f L%.1f %.1f L%.1f %.1f Z" fill="#fffaf0" stroke="%s" stroke-width="0.8" stroke-linejoin="round"/>' % (
            x + 0.3, y, x + step / 2, tip, x + step - 0.3, y, LK['line'])
    return gx(s, t) if t else s


def mimic_eyes(pts, mood='open'):
    s = ''
    for i, (x, y, r) in enumerate(pts):
        if mood == 'hurt':
            s += squeeze(x, y, r * 1.8, '#ffe27a', flip=i == 1, w=1.4)
            continue
        g = '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="#ffe27a" opacity="0.35"/>' % (x, y, r * 1.6)
        s += g + dot(x, y, r, '#fff2b0') + '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="none" stroke="%s" stroke-width="0.8"/>' % (
            x, y, r, LK['line'])
        s += '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s"/>' % (x + r * 0.3, y + r * 0.1, r * 0.34, r * 0.62, MOUTH)
        s += dot(x - r * 0.3, y - r * 0.4, r * 0.24, '#ffffff')
    return s


def tongue(d, groove):
    return Part('fill', pth(d), fill=kit.TONGUE, shade='#e05a6a', off=(-1.2, -1.2), line='#5a1420',
                over=line(groove, '#c8404e', 1.0, op=0.9), hl=spec(0, 0, 0, 0, op=0))


def lurk_svg(frame):
    ctx = Ctx('lk' + frame[:2])
    name = 'lurk_' + frame
    P = []
    under = shadow(64, 30)
    over = ''
    hinge = (LX0 + 0.6, SPLIT)
    if frame == 'open':
        ang = -34
        t = 'rotate(%d %.1f %.1f)' % (ang, hinge[0], hinge[1])
        fx, fy = rot_pt(LX1, SPLIT, hinge[0], hinge[1], ang)
        # the gaping mouth between the lid and the box, teeth on both rims
        mouth = 'M%.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f Z' % (hinge[0], hinge[1], fx, fy, LX1 + 2, (fy + SPLIT) / 2, LX1, SPLIT)
        inside = '<path d="%s" fill="%s" stroke="%s" stroke-width="1.4" stroke-linejoin="round"/>' % (mouth, MOUTH, LK['line'])
        inside += '<path d="M%.1f %.1f Q%.1f %.1f %.1f %.1f" fill="none" stroke="%s" stroke-width="3"/>' % (
            hinge[0] + 8, SPLIT - 1.6, 64, SPLIT - 4, LX1 - 1, SPLIT - 1.4, GUM)
        inside += mimic_eyes(((58, 64.6, 4.2), (70.4, 58.8, 3.6)))
        inside += teeth_row(LX0 + 5, LX1 - 1, SPLIT, 8, False)
        inside += teeth_row(LX0 + 8, LX1 - 1, SPLIT, 7, True, t)
        P.append(lurk_body(ctx, flame_on=False))
        P[-1].under = inside
        P.append(lurk_lid(t))
        P.append(tongue('M78 76.6 C86 74 96 76 100.6 84 C104 90 102 98 97 100.4 C93.4 102 91 99 92.4 95 C93.8 91 92 86 86.4 84.4 '
                        'C82 83.4 78.4 81 78 76.6 Z', 'M84 78.6 Q95 81 97.6 92'))
        over = motion('M100 50 L106 44 M104 62 L112 60 M86 36 L88 28', 1.4) + sparkle(24, 70, 3, LK['line'], '#fff2b0')
        mark(name, eyes=(64, 62), mouth=(74, 66))
    elif frame == 'hop':
        up = 9.4
        lift = 'translate(0 %.1f)' % -up
        ang = -20
        t = lift + ' rotate(%d %.1f %.1f)' % (ang, hinge[0], hinge[1])
        # stubby little legs kicking under the box, toes forward
        for x0, x1, fx in ((46, 40.4, 36.6), (82, 86.6, 90.4)):
            P.append(Part('limb', pth('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (x0, LY1 - up - 1, (x0 + x1) / 2, 116, x1, 118.2)),
                          width=3.6, fill=LK['shade']))
            P.append(Part('fill', pth('M%.1f 121.4 C%.1f 117 %.1f 116.4 %.1f 117 C%.1f 117.6 %.1f 119.4 %.1f 121.4 Z' % (
                fx - 3, fx - 2.6, fx + 2, fx + 4, fx + 6.4, fx + 7.2, fx + 7.2)), fill=LK['base'], shade=LK['shade'], off=(-0.8, -0.8)))
        fx, fy = rot_pt(LX1, SPLIT, hinge[0], hinge[1], ang)
        mouth = 'M%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (hinge[0], hinge[1] - up, fx, fy - up, LX1, SPLIT - up)
        inside = '<path d="%s" fill="%s" stroke="%s" stroke-width="1.2"/>' % (mouth, MOUTH, LK['line'])
        inside += mimic_eyes(((62, SPLIT - up - 7.4, 3.4), (73, SPLIT - up - 10.4, 3)))
        inside += teeth_row(LX0 + 12, LX1 - 1, SPLIT - up, 6, False)
        inside += teeth_row(LX0 + 14, LX1 - 1, SPLIT, 6, True, t)
        body = place([lurk_body(ctx, flame_on=False)], lift)[0]
        body.under = inside
        P.append(body)
        P.append(lurk_lid(t))
        P.append(tongue('M86 62.4 C94 58 104 54.4 110 57.6 C113.6 60 112.4 64.4 108.4 65 C102 66 96 65.6 90 66.4 C87 66.8 85 64.6 86 62.4 Z',
                        'M89 63.4 Q100 61 108 60.6'))
        over = motion('M36 104 L28 108 M34 94 L24 94 M40 114 L32 120', 1.3, 0.8)
        under = shadow(64, 22, op=0.25)
        mark(name, eyes=(64, 62))
    else:   # hit: slammed shut crooked, eyes squeezed in the crack, tongue caught
        squash = 'translate(0 121.8) scale(1.04 0.93) translate(0 -121.8)'
        ang = -11
        t = squash + ' rotate(%d %.1f %.1f)' % (ang, hinge[0], hinge[1])
        body = place([lurk_body(ctx, flame_on=False)], squash)[0]
        fx, fy = rot_pt(LX1, SPLIT, hinge[0], hinge[1], ang)
        crack = mimic_eyes(((64, SPLIT - 4.4, 4.2), (78, SPLIT - 6.4, 3.8)), mood='hurt')
        body.under = gx('<path d="M%.1f %.1f L%.1f %.1f L%.1f %.1f Z" fill="%s" stroke="%s" stroke-width="1.2"/>' % (
            hinge[0], hinge[1], fx, fy, LX1, SPLIT, MOUTH, LK['line']) + crack, squash)
        P.append(body)
        P.append(lurk_lid(t))
        P.append(tongue('M84 %.1f C88 %.1f 92 %.1f 92 %.1f C92 %.1f 88 %.1f 86 %.1f C84 %.1f 82.6 %.1f 84 %.1f Z' % (
            SPLIT + 1, SPLIT + 1, SPLIT + 3, SPLIT + 8, SPLIT + 11, SPLIT + 12, SPLIT + 10, SPLIT + 8, SPLIT + 4, SPLIT + 1),
            'M87 %.1f L88.4 %.1f' % (SPLIT + 3, SPLIT + 9)))
        over = kit.star5(50, 52, 4, '#ffe27a', LK['line'], 1.2) + kit.star5(64, 46, 4.6, '#ffe27a', LK['line'], 1.2)
        over += kit.star5(78, 52, 4, '#ffe27a', LK['line'], 1.2) + sweat(98, 62, 0.7, 20)
        over += '<ellipse cx="64" cy="52" rx="20" ry="5" fill="none" stroke="#ffffff" stroke-width="1.2" opacity="0.6"/>'
        mark(name, eyes=(64, SPLIT))
    return svg128(ctx, under + paint(ctx, P, LPAL) + over)


# ================================================================ all files

BONEBOW = ['idle', 'draw', 'loose', 'hit', 'bones']
HELM = ['walk1', 'walk2', 'block', 'bash', 'noshield', 'hit']
WING = ['fly1', 'fly2', 'latch', 'pop']
DRIPKIN = ['hang', 'drop', 'splat', 'crawl1', 'crawl2']
JAW = ['hide', 'leap', 'fall']
LURK = ['open', 'hop', 'hit']


ANCHORS = {'bonebow': (64, 122), 'helm': (64, 122), 'wing': (64, 64), 'drip': (64, 122),
           'jaw': (64, 64), 'lurk': (64, 122)}
DRIP_CEILING = (64, 10)
DRIP_HANG_SPRITE_Y = (ANCHORS['drip'][1] - DRIP_CEILING[1]) / 2    # 56 world px: frame y 10 onto the ceiling line


def points_json():
    """The engine points as JSON (frame units; world offset = (p - anchor) / 2)."""
    import json
    doc = {'_doc': 'W6b monster frames: 128-unit frames, 2 units = 1 world px, facing right. '
                   'Each kind has one anchor (its feet, or its middle for fliers), drip_hang included. '
                   'Offsets from the anchor in world px = (point - anchor) / 2.',
           '_anchors': {k: list(v) for k, v in ANCHORS.items()},
           '_drip_hang': {'ceiling': list(DRIP_CEILING), 'sprite_position_y': DRIP_HANG_SPRITE_Y,
                          'how': 'drip_hang keeps the feet anchor (64, 122); its ceiling line is frame y 10. '
                                 'While hanging (position.y = the ceiling line), set sprite.position.y = 56 '
                                 '((122 - 10) / 2) so frame y 10 sits on the ceiling; set it back to 0 when it '
                                 'lets go. Or write sprite.offset.y = -20 while hanging and -244 after. Do not '
                                 'change anchor at runtime: enemy.gd applies it to sprite.offset only in _ready.'}}
    doc.update({k: {n: list(p) for n, p in v.items()} for k, v in sorted(POINTS.items())})
    return json.dumps(doc, indent=1, sort_keys=True) + '\n'


def files():
    out = {}
    for fr in BONEBOW:
        out['art/enemies/bonebow_%s.svg' % fr] = bonebow_svg(fr)
    for fr in HELM:
        out['art/enemies/helm_%s.svg' % fr] = helm_svg(fr)
    for fr in WING:
        out['art/enemies/wing_%s.svg' % fr] = wing_svg(fr)
    for fr in DRIPKIN:
        out['art/enemies/drip_%s.svg' % fr] = drip_svg(fr)
    for fr in JAW:
        out['art/enemies/jaw_%s.svg' % fr] = jaw_svg(fr)
    for fr in LURK:
        out['art/enemies/lurk_%s.svg' % fr] = lurk_svg(fr)
    out['art/enemies/points_monsters.json'] = points_json()
    return out


def build(write):
    for rel, text in files().items():
        write(rel, text)


if __name__ == '__main__':
    import build as _b
    build(_b.write)
    print('wrote %d files under game/' % len(files()))
