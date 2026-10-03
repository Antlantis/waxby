"""The five Callings as paper-doll rigs: game/art/heroes/<cls>/<part>.svg,
rig.json and the dialogue portraits.

Every part is drawn on the one 128-unit frame (feet at (64, 122), facing
right), in its rest pose at its rest place, with the SAME pivots for every
calling (wick.PIVOTS, mirrored in scripts/wick_rig.gd), so the engine stacks
and turns any calling's parts the same way:
  cape, leg_back, leg_front, body, arm_back, arm_front      the body
  head, head_blink, head_hurt, head_happy, head_fierce      one face recipe
  candle      rides on the head; the engine's flame burns at rig.json flame_tip
  weapon      drawn upright, gripped at its pivot (64, 96), which the rig
              puts on the front fist HAND (76, 101), turned weapon_rest_deg
  offhand     (knight, sexton) held at its pivot (52, 101) = HAND_BACK
rig.json also gives weapon_tip, the weapon's business end in its own upright
frame (wick_rig.weapon_point()). Capes are drawn to show as the rig turns them
POSITIVE (the hem swinging back, a flare); negative tucks them behind the body.
The knight is Waxby as he always was (wick.py's parts) plus the lantern
shield. The others share the knight's face, eyes, line weights and cel
shading and differ in their headgear, candle, clothes and weapon, so that
each reads as its own character at 64 px.

portrait_<mood>.svg: the head, candle and shoulders, cropped by a per-calling
viewBox (rig.json portrait_viewbox) that keeps the flame's base inside the
circle the dialogue box draws it in. The flame itself is drawn live by the
engine at rig.json portrait_flame [x, y, h]: portrait units measured from the
crop's corner (NOT the 128 frame), see rig_json().

cape_trim_<band|tongues|stitch|bells|scallop>.svg (v3, P2): trims along the
hem and the outer edge of each cape, for a cape_trim rig part drawn over the
cape with the cape's pivot (58, 84) and turn, white with a 1-unit ink line and
coloured by modulate; see trim_files().
Run from the repo root: python3 tools/art/build.py heroes
"""
import json
import math

import kit
import wick
from kit import Part, ell, pth, shp
from common import (Ctx, RIM, GOLD, GOLD_SH, GOLD_HI, GOLD_LINE, WAX, WAX_SH, WAX_LINE, svg128, paint, line, dot,
                    spec, sparkle, sweat, mix, IN, xf, xell, gx)

L = wick.L
PIVOTS = dict(wick.PIVOTS, weapon=(64, 96), offhand=(52, 101))
HAND, HAND_BACK = wick.HAND_FRONT, wick.HAND_BACK
CALLINGS = ['knight', 'witch', 'runner', 'founder', 'sexton']
MOODS = [('head', 'normal'), ('head_blink', 'blink'), ('head_hurt', 'hurt'), ('head_happy', 'happy'),
         ('head_fierce', 'fierce')]
PORTRAITS = [('normal', 'normal'), ('happy', 'happy'), ('fierce', 'fierce'), ('hurt', 'hurt')]
PORTRAIT_PX = 640          # every portrait texture is this square, whatever its crop
PAL = dict(line=L, rim=RIM, base='#ffffff', shade='#cccccc')

SKIN, SKIN_SH = wick.SKIN, wick.SKIN_SH


def _clip(ctx, tpl):
    return ctx.clip(shp(tpl))


def P2(pts):
    return ' L'.join('%.1f %.1f' % p for p in pts)


# ================================================================ shared pieces

def face_look(skin, skin_sh, iris, blush_col, lid=0.0, mouth=True, extra=None):
    F = dict(line=L, base=skin, iris0=iris[0], iris1=iris[1], iris2=iris[2], blush=blush_col)
    return dict(face=F, lid=lid, mouth=mouth, extra=extra, skin=skin, skin_sh=skin_sh)


def face_part(ctx, look, mood, bangs_tips, hair, hair_hi, bangs_top=52, over_extra=''):
    """The face in its opening (wick.FACE_C, the knight's), bangs from under
    the headgear clipped to it, and the calling's face drawn on it."""
    fx, fy, frx, fry = wick.FACE_C
    face = ell(fx, fy, frx, fry)
    bd = wick.bangs_path(bangs_tips, bangs_top)
    bangs = ('<g clip-path="%s"><path d="%s" fill="%s"/>'
             '<path d="M57.4 %.1f Q60.4 %.1f 62.8 %.1f M70 %.1f Q72.6 %.1f 74.6 %.1f" fill="none" stroke="%s" '
             'stroke-width="1.1" stroke-linecap="round"/>'
             '<path d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linejoin="round"/></g>') % (
        _clip(ctx, face), bd, hair, bangs_top + 3.8, bangs_top + 4.2, bangs_top + 5.6, bangs_top + 3.8,
        bangs_top + 4.4, bangs_top + 6.2, hair_hi, bd, L, IN())
    return Part('fill', face, fill=look['skin'], shade=look['skin_sh'], off=(-2.4, -2.6),
                over=bangs + wick.face_art(ctx, mood, look) + over_extra)


def mood_fx(mood):
    if mood == 'hurt':
        return sweat(93.5, 60, 0.7, 20)
    if mood == 'happy':
        return sparkle(95, 44, 3.4, L) + sparkle(33, 62, 2.6, L)
    return ''


def fist_d(hx, hy, k=1.0):
    """The fist around the hand point, knuckles forward (wick.py's, scalable)."""
    def P(x, y):
        return '%.1f %.1f' % (hx + x * k, hy + y * k)
    return ('M%s C%s %s %s C%s %s %s C%s %s %s C%s %s %s Z' % (
        P(-4.2, -0.8), P(-4.2, -3.4), P(-2.2, -3.8), P(0, -3.8), P(3, -3.8), P(4.6, -3), P(4.6, -0.2),
        P(4.6, 2.8), P(2.8, 4), P(0, 4), P(-2.8, 4), P(-4.2, 2.4), P(-4.2, -0.8)))


def fist(hx, hy, fill, shade, k=1.0, line_col=None):
    fingers = line('M%.1f %.1f L%.1f %.1f M%.1f %.1f L%.1f %.1f' % (
        hx + 1.4 * k, hy - 0.9 * k, hx + 4.2 * k, hy - 0.9 * k, hx + 1.4 * k, hy + 1.7 * k, hx + 4 * k, hy + 1.7 * k),
        L, 0.8, op=0.8)
    thumb = line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (hx - 2.8 * k, hy - 2 * k, hx - 0.2 * k, hy - 1.2 * k,
                                                     hx + 0.6 * k, hy + 1.4 * k), L, 0.9, op=0.85)
    return Part('fill', pth(fist_d(hx, hy, k)), fill=fill, shade=shade, off=(-1.3, -1.5), over=fingers + thumb,
                line=line_col, hl=spec(hx - 1.8 * k, hy - 2.2 * k, 1.3, 0.8, rot=-20, op=0.7))


def arm_points(front):
    sx, sy = PIVOTS['arm_front' if front else 'arm_back']
    hx, hy = HAND if front else HAND_BACK
    return sx, sy, hx, hy


def sleeve_d(front, w0=1.9, w1=3.3, cuff_y=-2.6):
    """The tapered sleeve of wick.py: slim at the shoulder (the head hides
    the joint at rest), wider down to the cuff just above the fist."""
    sx, sy, hx, hy = arm_points(front)
    ax, ay = sx + 0.4, sy + 3.2
    return ('M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f L%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z' % (
        ax - w0, ay + 0.6, ax - w0, ay - 1.6, ax + w0, ay - 1.6, ax + w0, ay + 0.6,
        hx + w1 + 0.1, hy + cuff_y - 1, hx + 1.4, hy + cuff_y, hx - 1.4, hy + cuff_y, hx - w1 + 0.1, hy + cuff_y - 1))


def shoe(x0, tip, heel_top, sole, fill, shade, over='', toe_up=0.0):
    """A soft low shoe or boot: heel at x0, toe tip at tip, sole on sole;
    toe_up curls the toe (the Taperwitch's slippers)."""
    w = tip - x0
    d = ('M%.1f %.1f L%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f '
         'C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z') % (
        x0, sole, x0, heel_top + 3.6,
        x0, heel_top + 0.8, x0 + w * 0.22, heel_top, x0 + w * 0.42, heel_top,
        x0 + w * 0.64, heel_top, x0 + w * 0.72, heel_top + 2.2, x0 + w * 0.78, heel_top + 3.8,
        x0 + w * 0.9, heel_top + 4.4, tip - 1, heel_top + 4.6 - toe_up, tip, heel_top + 5.2 - toe_up,
        tip + 1.4, heel_top + 6 - toe_up * 0.6, tip + 0.8, sole, tip - 2, sole)
    return Part('fill', pth(d), fill=fill, shade=shade, off=(-1.4, -1.6), over=over,
                hl=spec(x0 + w * 0.3, heel_top + 2, 1.3, 0.7, rot=-20, op=0.7))


def svg_of(prefix, fn, *args):
    ctx = Ctx(prefix)
    return svg128(ctx, fn(ctx, *args))


# ================================================================ knight: Waxby

def knight_shield(ctx):
    """The lantern shield, carried in front on the back hand: a round steel
    shield with a stained-glass rose window (gold, red and blue panes, lead
    between them) glowing in its centre, a little lantern-cap on top."""
    cx, cy, rx, ry, rot = 48.2, 99.6, 11.4, 13.2, -6
    P = []
    rim = ell(cx, cy, rx, ry, rot)
    face = ell(cx + 0.2, cy + 0.1, rx - 2.8, ry - 3.0, rot)
    t = 'rotate(%s %s %s)' % (rot, cx, cy)
    # the steel rim with its rivets
    rivets = ''.join(dot(cx + (rx - 1.4) * math.cos(a), cy + (ry - 1.4) * math.sin(a), 0.75, L, 0.7)
                     for a in (math.radians(d) for d in (-60, 20, 100, 160, 230)))
    P.append(Part('fill', rim, fill=wick.STEEL, shade=wick.STEEL_SH, off=(-2, -2.4), over=rivets,
                  hl=spec(cx - 5.4, cy - 8.6, 3.2, 1.2, rot=-38, op=0.95)))
    # the rose window: eight petals of red and blue glass on gold, leaded
    prx, pry = rx - 3.0, ry - 3.2
    gold_glass = ctx.radgrad([(0, '#fff0b0'), (0.55, '#f2c050'), (1, '#c88a2a')])
    petals = ''
    for i in range(8):
        a = math.radians(i * 45 - 90)
        pcx, pcy = cx + prx * 0.52 * math.cos(a), cy + pry * 0.52 * math.sin(a)
        col = '#d8403a' if i % 2 == 0 else '#3a6ae0'
        pa = math.degrees(math.atan2(pry * math.sin(a), prx * math.cos(a)))
        petals += ('<ellipse cx="%.2f" cy="%.2f" rx="%.2f" ry="%.2f" transform="rotate(%.1f %.2f %.2f)" fill="%s" '
                   'stroke="#2a2030" stroke-width="0.9"/>') % (pcx, pcy, prx * 0.4, prx * 0.2, pa, pcx, pcy, col)
        petals += dot(pcx - 0.5, pcy - 0.6, 0.7, '#ffffff', 0.55)
    glass = ('<g transform="%s"><ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s"/></g>' % (
        t, cx + 0.2, cy + 0.1, prx, pry, gold_glass)
             + '<g transform="%s">%s</g>' % (t, petals)
             + '<ellipse cx="%.1f" cy="%.1f" rx="2.6" ry="2.9" transform="%s" fill="%s" stroke="#2a2030" stroke-width="0.9"/>' % (
                 cx + 0.2, cy + 0.1, t, '#fff4d0')
             + dot(cx - 0.4, cy - 0.6, 0.8, '#ffffff'))
    P.append(Part('fill', face, fill='#2a2030', shade='#2a2030', no_shade=True, lw=1.2, over=glass))
    # a little lantern cap and ring at the top of the rim
    cap = pth('M%.1f %.1f L%.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f Z' % (
        cx - 3.2, cy - ry + 1.6, cx + 3.6, cy - ry + 1.2, cx + 2.2, cy - ry - 1.6, cx + 0.2, cy - ry - 3.2,
        cx - 2.2, cy - ry - 1.2))
    P.append(Part('fill', cap, fill=GOLD, shade=GOLD_SH, off=(-0.8, -0.8), line=GOLD_LINE,
                  over=dot(cx + 0.2, cy - ry - 3.6, 1.3, GOLD) + dot(cx + 0.2, cy - ry - 3.6, 0.5, GOLD_LINE)))
    return paint(ctx, P, dict(PAL, base=wick.STEEL, shade=wick.STEEL_SH))


# ================================================================ witch: the Taperwitch

W_HAT, W_HAT_SH, W_HAT_HI = '#40285a', '#2a1a40', '#6a4a8a'
W_ROBE, W_ROBE_SH = '#5c3a7e', '#40285c'
W_CREAM, W_CREAM_SH = '#f4ead6', '#d8c8a8'
W_ROSE, W_ROSE_SH = '#d86a8a', '#a84a68'
W_HAIR, W_HAIR_SH, W_HAIR_HI = '#f2d49a', '#d0a860', '#fff0c8'
W_WOOD, W_WOOD_SH = '#8a5a34', '#5e3a1e'
BRASS, BRASS_SH, BRASS_HI, BRASS_LINE = '#c8a04a', '#8e6a26', '#f2d88a', '#3a2408'


def witch_extra(ctx, mood):
    # freckles over both cheeks
    s = ''.join(dot(x, y, 0.62, '#c07a5a', 0.85) for x, y in (
        (54.6, 75.2), (57.2, 76.6), (55.2, 77.8), (58.4, 74.6), (85.4, 74.8), (87.4, 76), (86, 77.4)))
    return s


W_LOOK = face_look(SKIN, SKIN_SH, ('#2a0e3a', '#7a3aa8', '#e8a8ff'), '#ff8aa8', extra=witch_extra)


def witch_head(ctx, mood):
    P = []
    # long hair falling behind, down past the shoulders at the back
    hair = pth('M40 50 C37.4 62 37.2 76 39.8 88 C40.8 93 42.6 97.6 44.8 100.4 C45.6 97.6 46.8 95.8 48.4 95.2 '
               'C49.4 98.4 51.6 100.6 54.2 101 C53.4 97 53.6 93.6 54.8 91 C56.6 89 59 88.2 62 88 '
               'C78 88.4 88.6 81 90 70 C91 62 90.8 55 89.8 50 Z')
    strands = line('M43 60 C42 72 43 84 46.4 94 M48.4 66 C48 76 49.6 86 52.4 94', W_HAIR_SH, 1.0, op=0.9)
    P.append(Part('fill', hair, fill=W_HAIR, shade=W_HAIR_SH, off=(-3, -3), over=strands,
                  hl=line('M41.6 58 C40.6 66 40.8 74 42.2 80', W_HAIR_HI, 1.4, op=0.9)))
    # the face; side-swept bangs, a long lock down by the far eye
    tips = [(51.6, 60.4), (56.8, 63.2), (63.2, 64), (70, 63.2), (76.4, 61.2), (82.4, 63.6), (88.8, 71.4)]
    P.append(face_part(ctx, W_LOOK, mood, tips, W_HAIR, W_HAIR_HI))
    # the pointed hat: its cone leans forward and narrows into the taper's collar
    cone = pth('M44 50.6 C47.6 42.6 53.4 34.4 60.4 28.2 C64.4 24.8 68.4 22 71.8 20.4 L77.4 25.4 '
               'C77.8 32.4 80.8 42 84.8 50.6 Z')
    band = ('<g clip-path="%s">' % _clip(ctx, cone)
            + '<path d="M40 42.4 L90 42.4 L90 47.4 L40 47.4 Z" fill="%s"/>' % W_CREAM
            + ''.join('<path d="M%.1f 47 L%.1f 47 L%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z" fill="%s"/>' % (
                x - 1.2, x + 1.2, x + 1.2, 47 + ln, x + 1.2, 48.6 + ln, x - 1.2, 48.6 + ln, x - 1.2, 47 + ln, W_CREAM)
                      for x, ln in ((52, 1.6), (60.4, 2.6), (69.6, 1.2), (77.4, 2.2)))
            + line('M40 47.6 L90 47.6', W_CREAM_SH, 0.8, op=0.9)
            + '<path d="M40 40.6 L90 40.6 L90 42.8 L40 42.8 Z" fill="%s"/>' % W_ROSE
            + '</g>')
    creases = line('M58 30.6 Q61 38 60.4 46 M68.8 25.8 Q72.4 33 74.4 40.4', W_HAT_SH, 1.0, op=0.9)
    P.append(Part('fill', cone, fill=W_HAT, shade=W_HAT_SH, off=(-3.6, -2.4), over=creases + band,
                  hl=line('M49.6 43 C52.6 37 56.6 32 61.4 28', W_HAT_HI, 1.4, op=0.9)))
    # a rose ribbon bow on the band's near side
    bow = pth('M48.4 41.8 C46 39.2 42.8 39.8 43 42.4 C43.2 44.8 46.4 45 48.4 43.2 C50.4 45 53.6 44.8 53.8 42.4 '
              'C54 39.8 50.8 39.2 48.4 41.8 Z')
    P.append(Part('fill', bow, fill=W_ROSE, shade=W_ROSE_SH, off=(-0.6, -0.8), rim=False,
                  over=dot(48.4, 42.4, 1.2, W_ROSE_SH) + line('M47.8 43.4 L46.4 47 M49 43.4 L50.6 46.6', W_ROSE_SH, 1.2)))
    # the broad brim
    brim = ell(64.4, 50.8, 33.6, 5.4)
    P.append(Part('fill', brim, fill=W_HAT, shade=W_HAT_SH, off=(-1.6, -2.6),
                  over=line('M34 49.6 Q64 44.4 94.4 49.4', W_HAT_HI, 1.2, op=0.9)))
    return paint(ctx, P, dict(PAL, base=W_HAT, shade=W_HAT_SH)) + mood_fx(mood)


def witch_candle(ctx):
    """The tall taper standing out of the hat's tip in a gold collar,
    curling a little forward; its wick at flame_tip (84, 6)."""
    P = []
    taper = pth('M72.6 24.2 C73.6 19.6 76.2 15 79.6 11.4 L82.2 9.4 L86.2 11.4 C84.2 14.4 81.6 18.8 79.4 25.6 Z')
    drips = line('M80.8 12.6 Q80.2 15.6 80.8 17.6 M83.8 13 Q83 14.6 83.2 16', W_CREAM_SH, 1.0, op=0.9)
    P.append(Part('fill', taper, fill='#fffaec', shade=W_CREAM_SH, off=(-1.2, 0), line=WAX_LINE, over=drips,
                  hl=line('M75.4 21.2 Q77 16.6 80 13', '#ffffff', 0.9, op=0.9)))
    cap = pth('M81.4 9.6 C82.4 8.2 84.4 8 85.8 8.8 C86.8 9.4 87 10.4 86.4 11.4 L85.6 12.8 C85 13.8 83.8 13.4 84 12.4 '
              'L84.2 11.8 C83.4 11.6 82.6 11.6 82 12 C81 12.4 80.4 11.2 81.4 9.6 Z')
    P.append(Part('fill', cap, fill='#fffaec', shade='#e8dcbc', off=(-0.6, -0.4), line='#b89c6c', lw=0.8, rim=False))
    collar = ell(75.6, 23.8, 4.6, 2.2, -42)
    P.append(Part('fill', collar, fill=GOLD, shade=GOLD_SH, off=(-0.8, -0.8), line=GOLD_LINE,
                  hl=dot(74, 22.8, 0.7, GOLD_HI)))
    wick_line = line('M83.8 9.2 Q83.4 7.6 84 6.2', '#241a14', 1.4)
    return paint(ctx, P, dict(PAL, base=WAX, shade=WAX_SH)) + wick_line


def witch_body(ctx):
    P = []
    # the robe flares to a scalloped wax-drip hem
    xs = [84.6, 79.2, 73.8, 68.4, 63, 57.6, 52.2, 46.8, 43.4]
    d = 'M54.6 81.6 L73.4 81.6 C76.6 88.6 79.8 97 82.4 105 C83.4 108 84.2 110 84.6 111.6'
    for i, (x0, x1) in enumerate(zip(xs, xs[1:])):
        mx = (x0 + x1) / 2
        drop = 2.6 if i % 2 == 0 else 1.4
        d += ' Q%.1f %.1f %.1f %.1f' % (mx, 112.4 + drop * 1.6, x1, 111.6)
    d += ' C43.8 110 44.6 108 45.6 105 C48.2 97 51.4 88.6 54.6 81.6 Z'
    robe = pth(d)
    wax = ('<g clip-path="%s"><path d="M40 108.6 Q45 106.6 50 108.6 Q55 106.2 60 108.4 Q65 106.4 70 108.6 Q75 106.2 80 108.4 '
           'Q84 106.8 88 108.4 L88 120 L40 120 Z" fill="%s"/>%s</g>') % (
        _clip(ctx, robe), W_CREAM, line('M40 108.8 Q45 106.8 50 108.8 Q55 106.4 60 108.6 Q65 106.6 70 108.8 Q75 106.4 80 108.6 Q84 107 88 108.6',
                                         W_CREAM_SH, 0.8))
    folds = line('M58.6 96 Q56.4 102 55 107.6 M70.4 95.6 Q72.8 101.6 74.2 107.4', W_ROBE_SH, 1.1, op=0.9)
    P.append(Part('fill', robe, fill=W_ROBE, shade=W_ROBE_SH, off=(-3, -2.4), over=folds + wax,
                  hl=spec(58.4, 88.4, 1.3, 3.6, rot=10, op=0.35)))
    # a rose sash with three tiny unlit candles hanging from it
    sash = pth('M50.8 97.2 L78 97.2 L78.6 100.8 L50.2 100.8 Z')
    candles = ''
    for x in (56, 64, 72):
        candles += ('<path d="M%.1f 101 L%.1f 101 L%.1f 106.2 L%.1f 106.2 Z" fill="%s" stroke="%s" stroke-width="0.8"/>' % (
            x - 1.3, x + 1.3, x + 1.3, x - 1.3, '#fffaec', WAX_LINE)
                    + '<path d="M%.1f 105.6 L%.1f 105.6 L%.1f 107.8 Q%.1f 108.6 %.1f 107.8 Z" fill="%s" stroke="%s" stroke-width="0.8"/>' % (
            x - 2, x + 2, x + 1.4, x, x - 1.4, GOLD, GOLD_LINE)
                    + line('M%.1f 101 L%.1f 99.8' % (x, x), '#241a14', 0.8))
    knot = ('<path d="M66.4 97.4 L70 97 L69.6 101 L66.8 101.2 Z" fill="%s" stroke="%s" stroke-width="0.8"/>' % (W_ROSE_SH, L)
            + line('M67.4 101 Q66.8 104 67.8 106.4 M69 101 Q70.2 103.4 70.4 105.4', W_ROSE_SH, 1.3))
    P.append(Part('fill', sash, fill=W_ROSE, shade=W_ROSE_SH, off=(-0.8, -1.2), rim=False, over=knot + candles))
    # the wax-drip collar and its gold star clasp
    collar = pth('M55.6 81.4 L72.8 81.4 L72.2 85.6 Q70.8 87.6 69.4 85.6 Q67.8 88.8 66.2 86 Q64.6 88.2 63 86 '
                 'Q61.4 88.8 59.8 86 Q58.2 87.6 56.8 85.6 Z')
    P.append(Part('fill', collar, fill=W_CREAM, shade=W_CREAM_SH, off=(-0.8, -1), rim=False,
                  over=kit.star5(65, 88.6, 2.6, GOLD, GOLD_LINE, lw=0.8)))
    return paint(ctx, P, dict(PAL, base=W_ROBE, shade=W_ROBE_SH))


W_CAPE_HEM = [(38.4, 107.2), (42.2, 111), (45.8, 106.8), (49.6, 110), (52.8, 105.6), (56.6, 108), (60.2, 102.4)]


def witch_cape(ctx):
    """A plum capelet in the hat's dark plum, its dagged hem trimmed in gold
    over a rose lining. It falls past the ends of her hair, so its points
    show behind the robe at rest and fan out when it flares back."""
    hem = W_CAPE_HEM
    d = ('M62 81.4 C55.6 81 50.4 82.8 47.4 86.6 C43.6 91.4 40.4 98.6 %.1f %.1f ' % hem[0]
         + ' '.join('L%.1f %.1f' % p for p in hem[1:]) + ' L62.8 94 Z')
    hem_d = 'M' + ' L'.join('%.1f %.1f' % p for p in hem)
    lift = 'M' + ' L'.join('%.1f %.1f' % (x + 0.6, y - 2.4) for x, y in hem)
    trim = ('<g clip-path="%s">%s%s</g>') % (_clip(ctx, pth(d)), line(lift, W_ROSE, 2.2), line(hem_d, GOLD, 2.4))
    P = [Part('fill', pth(d), fill=W_HAT, shade=W_HAT_SH, off=(-2.6, -2), line='#1c1020',
              over=line('M50.4 89.6 Q47.2 97 45.4 104.6 M55.4 90.4 Q53.6 97 53 103', W_HAT_SH, 1.1, op=0.9) + trim,
              hl=line('M46.2 89.6 C44 93.4 42.2 98 40.8 103', W_HAT_HI, 1.2, op=0.8))]
    return paint(ctx, P, PAL)


def witch_arm(ctx, front):
    """A long bell sleeve flowing past the wrist, the hand peeking out."""
    sx, sy, hx, hy = arm_points(front)
    robe = W_ROBE if front else mix(W_ROBE, '#000000', 0.18)
    robe_sh = W_ROBE_SH if front else mix(W_ROBE_SH, '#000000', 0.18)
    ax, ay = sx + 0.4, sy + 3.2
    d = ('M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f '
         'C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z') % (
        ax - 2.1, ay + 0.8,
        ax - 2.1, ay - 1.8, ax + 2.1, ay - 1.8, ax + 2.1, ay + 0.8,
        ax + 3.4, ay + 5, hx + 6.6, hy - 5.4, hx + 7.2, hy - 1.8,
        hx + 7.4, hy + 0.4, hx + 5, hy + 1.2, hx + 3.2, hy - 0.4,
        hx - 0.6, hy - 1.6, hx - 4, hy - 0.2, hx - 6.2, hy + 5.4,
        hx - 6.4, hy - 1.6, hx - 4.6, hy - 5.8, ax - 2.1, ay + 0.8)
    lining = ('<g clip-path="%s"><path d="M%.1f %.1f Q%.1f %.1f %.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f Z" fill="%s"/></g>') % (
        _clip(ctx, pth(d)), hx - 7, hy + 6, hx - 2, hy - 3.4, hx + 8, hy - 1.4, hx + 8, hy + 3, hx, hy + 1.4, hx - 7, hy + 8, W_CREAM)
    P = [fist(hx, hy + 0.6, SKIN, SKIN_SH, 0.9),
         Part('fill', pth(d), fill=robe, shade=robe_sh, off=(-1.4, -0.8), over=lining +
              line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (ax, ay + 5, ax + 1.6, ay + 9, hx + 2, hy - 4), robe_sh, 0.9, op=0.9))]
    return paint(ctx, P, dict(PAL, base=robe, shade=robe_sh))


def witch_leg(ctx, front):
    """Striped stockings and curl-toed slippers under the robe."""
    if front:
        leg, x0, tip, rose, rose_sh = 'M68 104.4 Q68.6 109.4 69.2 114', 63.8, 78.4, W_ROSE, W_ROSE_SH
    else:
        leg, x0, tip, rose, rose_sh = 'M60 104.4 Q59.8 109.4 59.6 114', 53.8, 67, mix(W_ROSE, '#000000', 0.2), mix(W_ROSE_SH, '#000000', 0.2)
    stripes = ''.join(line('M%.1f %.1f l4.4 -0.4' % ((66 if front else 57.6) - 0.2, y), '#40285c', 1.4)
                      for y in (110.6, 113.2))
    P = [Part('limb', pth(leg), width=5.4, fill=W_CREAM if front else W_CREAM_SH, over=stripes),
         shoe(x0, tip, 113.8, 120.6, rose, rose_sh, toe_up=4.2,
              over=dot(x0 + (tip - x0) * 0.5, 115.4, 1.1, GOLD) + dot(tip + 0.6, 112.6 - 0.2, 1.0, GOLD))]
    return paint(ctx, P, PAL)


def witch_weapon(ctx):
    """The taper staff: a crooked wooden staff topped by a three-candle
    candelabra fork (unlit; the engine sparks it while charging)."""
    P = []
    haft = 'M64.8 115 C65.6 106 62.8 100 63.8 92 C64.8 84 62.4 76 63.6 68 C64.4 62 63 57.8 63.4 53.4'
    P.append(Part('limb', pth(haft), width=3.6, fill=W_WOOD,
                  over=line('M63.4 72 Q64.6 70.4 64.2 68.6 M64.8 106.4 Q65.8 104.6 65.2 103', W_WOOD_SH, 0.9)
                  + line('M62.6 90.6 L65.4 91.6 M62.4 92.8 L65.2 93.8', W_ROSE_SH, 1.2)))
    # the brass candelabra: two curled arms and a centre stem, three cups
    for k in (-1, 1):
        arm = 'M63.4 57.6 C%.1f 57.8 %.1f 55.6 %.1f 52 C%.1f 50 %.1f 48.6 %.1f 47.4' % (
            63.4 + k * 6.4, 63.4 + k * 9.4, 63.4 + k * 9, 63.4 + k * 8.6, 63.4 + k * 8.6, 63.4 + k * 8.6)
        P.append(Part('limb', pth(arm), width=2.2, fill=BRASS))
        P.append(Part('limb', pth('M%.1f 52.4 C%.1f 54 %.1f 54.6 %.1f 53.4' % (63.4 + k * 9.2, 63.4 + k * 10.8, 63.4 + k * 11.2, 63.4 + k * 11)),
                      width=1.2, fill=BRASS))
    P.append(Part('limb', pth('M63.4 58 L63.4 45.4'), width=2.4, fill=BRASS))
    for x, y in ((54.8, 47.2), (63.4, 45), (72, 47.2)):
        P.append(Part('fill', pth('M%.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f Z' % (
            x - 3.2, y - 0.8, x + 3.2, y - 0.8, x + 2.8, y + 1.8, x, y + 2, x - 2.8, y + 1.8, x - 3.2, y - 0.8)),
            fill=BRASS, shade=BRASS_SH, off=(-0.6, -0.6), line=BRASS_LINE, hl=dot(x - 1.6, y, 0.6, BRASS_HI)))
    for x, y, h in ((54.8, 46.6, 7.6), (63.4, 44.4, 9.4), (72, 46.6, 7.6)):
        wax = 'M%.1f %.1f L%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f L%.1f %.1f Z' % (
            x - 2, y, x - 2, y - h + 1, x - 2, y - h - 0.2, x + 2, y - h - 0.2, x + 2, y - h + 1, x + 2, y)
        P.append(Part('fill', pth(wax), fill='#fffaec', shade=W_CREAM_SH, off=(-1.1, 0), line=WAX_LINE,
                      over=line('M%.1f %.1f L%.1f %.1f' % (x, y - h - 0.2, x + 0.3, y - h - 2.2), '#241a14', 1.0)
                      + line('M%.1f %.1f L%.1f %.1f' % (x + 1.1, y - h + 0.8, x + 1.1, y - h + 3.2), W_CREAM_SH, 1.0)))
    P.append(Part('fill', ell(63.4, 58.4, 2.6, 2), fill=BRASS, shade=BRASS_SH, off=(-0.5, -0.5), line=BRASS_LINE,
                  hl=dot(62.6, 57.8, 0.6, BRASS_HI)))
    return paint(ctx, P, dict(PAL, base=BRASS, shade=BRASS_SH))


# ================================================================ runner: the Sootrunner

R_HOOD, R_HOOD_SH, R_HOOD_HI, R_HOOD_IN = '#48405e', '#2e2a40', '#6a6284', '#1e1a2c'
R_JERK, R_JERK_SH = '#5a5274', '#3e3858'
R_SCARF, R_SCARF_SH = '#c4ae8c', '#9a8466'
R_SPOT = '#6a5a86'
R_HAIR, R_HAIR_SH = '#eceaf4', '#b8b4c8'
R_LEG, R_LEG_SH = '#3a3650', '#2a2640'
R_BOOT, R_BOOT_SH = '#6a5a52', '#4a3e38'
R_LEATHER, R_LEATHER_SH = '#7a5a3a', '#553c24'

R_LOOK = face_look(SKIN, SKIN_SH, ('#0e1a2a', '#3a6a9a', '#b0e8ff'), '#ff9aa0', mouth=False)


def feeler(x0, y0, cx, cy, x1, y1, w, n=22):
    """A feathered moth antenna along a quadratic curve: a comb of barbs
    either side of a thin spine (a zigzag outline), widest past its middle,
    tapering to a curled tip."""
    left, right, spine = [], [], []
    for i in range(n + 1):
        t = i / float(n)
        x = (1 - t) ** 2 * x0 + 2 * (1 - t) * t * cx + t * t * x1
        y = (1 - t) ** 2 * y0 + 2 * (1 - t) * t * cy + t * t * y1
        dx = 2 * (1 - t) * (cx - x0) + 2 * t * (x1 - cx)
        dy = 2 * (1 - t) * (cy - y0) + 2 * t * (y1 - cy)
        ln = math.hypot(dx, dy) or 1
        tx, ty = dx / ln, dy / ln
        nx, ny = -ty, tx
        hw = w * (0.25 + 0.75 * math.sin(math.pi * min(1.0, 0.15 + t * 0.95)))
        if i % 2 == 0 and 0 < i < n:
            # a barb tip, swept toward the antenna's tip
            left.append((x + nx * hw + tx * hw * 0.7, y + ny * hw + ty * hw * 0.7))
            right.append((x - nx * hw + tx * hw * 0.7, y - ny * hw + ty * hw * 0.7))
        else:
            left.append((x + nx * hw * 0.3, y + ny * hw * 0.3))
            right.append((x - nx * hw * 0.3, y - ny * hw * 0.3))
        spine.append((x, y))
    d = 'M%s Z' % P2(left + list(reversed(right)))
    return d, 'M' + P2(spine[:-1]), ''


def runner_head(ctx, mood):
    P = []
    # the moth feelers first, so the hood hides their roots
    for (x0, y0, cx, cy, x1, y1, w) in ((50.6, 40, 36, 24, 27.4, 31.4, 3.1), (56.6, 34.6, 52.4, 12, 40.4, 13.4, 3.1)):
        d, spine, _ = feeler(x0, y0, cx, cy, x1, y1, w)
        P.append(Part('fill', pth(d), fill=R_SCARF, shade=R_SCARF_SH, off=(-0.6, -0.8), lw=0.8,
                      over=line(spine, '#6a5640', 0.9)))
    # the deep soot hood; its tip curls forward to hold the caged tealight
    hood = pth('M40.6 86.4 C37 76 36.2 62 38.6 52 C40.6 43.6 45.6 37.6 51.4 33.8 C56.4 30 61.6 27.6 66.8 27.6 '
               'C73.4 27.6 78.8 30.4 82.4 35.4 C80 34.8 77.6 35.2 76 36.8 C82.4 39.2 88.6 45 91 53.6 '
               'C93.2 62 92.8 72 90.2 80 C88.4 85.2 84.4 88 80 88.8 C70 90 52 90 40.6 86.4 Z')
    fx, fy, frx, fry = wick.FACE_C
    inner = ('<g clip-path="%s"><ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s"/>%s</g>' % (
        _clip(ctx, hood), fx - 0.6, fy + 0.4, frx + 2.8, fry + 2.6, R_HOOD_IN,
        line('M44 44 Q47 60 44.4 80 M86 44 Q88.6 52 89 60', R_HOOD_SH, 1.2, op=0.9)))
    fold = line('M60.4 31.4 C66 31.2 71.6 33 75.4 36.6', R_HOOD_SH, 1.2, op=0.95)
    P.append(Part('fill', hood, fill=R_HOOD, shade=R_HOOD_SH, off=(-3.4, -3.6), over=inner + fold,
                  hl=line('M42.6 54 C43.6 46 47.4 40.4 52.6 36.6 C57 33.4 61.6 31 66.4 30.6', R_HOOD_HI, 1.4, op=0.9)))
    # the face in the hood's shadow, silver bangs
    tips = [(51.6, 59), (56.6, 62.2), (62.8, 62.8), (69.4, 63.8), (75.6, 60.8), (81.6, 61.8), (88, 59.4)]
    P.append(face_part(ctx, R_LOOK, mood, tips, R_HAIR, R_HAIR_SH))
    # the scarf pulled up over the mouth, wrapping round into the hood
    scarf = pth('M49.2 75.8 C58 72.8 74 72 91.4 74.8 C92.8 78.4 92.4 82.8 90.4 86.6 C80 91 60 91.2 47.2 87.2 '
                'C46.4 83 47 79 49.2 75.8 Z')
    folds = line('M53 81.4 Q70 78.4 89.4 80.8 M55 86 Q68 84 86 85.6', R_SCARF_SH, 1.0, op=0.95)
    breath = ''
    if mood == 'hurt':
        breath = line('M70.4 79 Q72.6 77.6 74.8 79', L, 1.0, op=0.8)
    elif mood == 'happy':
        breath = line('M69.4 78.4 Q72.6 80.4 75.8 78.2', L, 1.0, op=0.7)
    P.append(Part('fill', scarf, fill=R_SCARF, shade=R_SCARF_SH, off=(-1.6, -2.2), over=folds + breath,
                  hl=line('M52 76.6 Q66 74 84 75', '#f0e2c8', 1.2, op=0.9)))
    return paint(ctx, P, dict(PAL, base=R_HOOD, shade=R_HOOD_SH)) + mood_fx(mood)


def runner_candle(ctx):
    """A tealight in a little brass cage perched on the hood's curled tip."""
    P = []
    cup = pth('M72.6 27.4 L83.4 27.4 L82.4 32.8 Q78 34.4 73.6 32.8 Z')
    bars = line('M74.8 27.6 L75.4 33 M78 27.6 L78 33.8 M81.2 27.6 L80.6 33', BRASS_LINE, 1.0)
    P.append(Part('fill', cup, fill=BRASS, shade=BRASS_SH, off=(-1, -1), line=BRASS_LINE, over=bars,
                  hl=line('M73.8 29 L82.2 29', BRASS_HI, 0.8, op=0.9)))
    light = pth('M73.8 27.8 C73.8 26.6 75.6 26 78 26 C80.4 26 82.2 26.6 82.2 27.8 C82.2 28.8 80.4 29.4 78 29.4 '
                'C75.6 29.4 73.8 28.8 73.8 27.8 Z')
    P.append(Part('fill', light, fill='#fffaec', shade='#e8dcbc', off=(-0.6, -0.5), line=WAX_LINE, lw=0.9, rim=False,
                  over='<ellipse cx="78" cy="27.4" rx="2.4" ry="0.8" fill="%s"/>' % WAX_SH))
    # the cage's rim ring, in front of the tealight
    P.append(Part('fill', pth('M72.2 26.6 L83.8 26.6 L83.6 28.2 L72.4 28.2 Z'), fill=BRASS, shade=BRASS_SH, off=(-0.4, -0.6),
                  line=BRASS_LINE, lw=0.8, rim=False))
    wick_line = line('M78 27.2 Q77.6 26.4 78 25.8', '#241a14', 1.3)
    return paint(ctx, P, dict(PAL, base=BRASS, shade=BRASS_SH)) + wick_line


def runner_body(ctx):
    P = []
    jerk = pth('M54 82 C54 80.8 57.4 80.2 64 80.2 C70.6 80.2 74 80.8 74 82 L76.2 104 C76.4 106.6 75.6 108.8 73.4 109.2 '
               'L66.8 110.2 L64 107.4 L61.2 110.2 L54.6 109.2 C52.4 108.8 51.6 106.6 51.8 104 Z')
    seams = line('M64 83.6 L64 107 M55.4 92 Q57.6 94 57.2 99', R_JERK_SH, 0.9, op=0.9)
    P.append(Part('fill', jerk, fill=R_JERK, shade=R_JERK_SH, off=(-2.6, -2.2), over=seams,
                  hl=spec(57.4, 87.6, 1.2, 3.2, rot=10, op=0.3)))
    # a belt with a silver buckle and a pouch on the hip
    belt = pth('M51.6 100.2 L76.4 100.2 L76.6 103.6 L51.4 103.6 Z')
    P.append(Part('fill', belt, fill=R_LEATHER, shade=R_LEATHER_SH, off=(-0.8, -1), rim=False,
                  over='<rect x="62.4" y="99.8" width="4.6" height="4.4" rx="1" fill="#c3c7d6" stroke="%s" stroke-width="0.9"/>' % L))
    pouch = pth('M52.6 102.4 L58 102.4 L58 107.4 Q55.4 108.8 52.8 107.4 Z')
    P.append(Part('fill', pouch, fill=R_LEATHER, shade=R_LEATHER_SH, off=(-0.6, -0.8), rim=False,
                  over=line('M52.8 104 Q55.4 105.2 58 104', R_LEATHER_SH, 0.8)))
    # the bandolier of little knives, shoulder to hip
    strap = pth('M72 81.4 L76 83.4 L56.4 102.2 L52.6 100 Z')
    hilts = ''
    for t in (0.22, 0.46, 0.7):
        x, y = 74 + (54.5 - 74) * t, 82.4 + (101 - 82.4) * t
        hilts += ('<path d="M%.1f %.1f L%.1f %.1f" stroke="%s" stroke-width="2.6" stroke-linecap="round"/>' % (x, y, x - 2.2, y - 3.2, L)
                  + '<path d="M%.1f %.1f L%.1f %.1f" stroke="%s" stroke-width="1.4" stroke-linecap="round"/>' % (x, y, x - 2.2, y - 3.2, '#3a2a20')
                  + dot(x - 2.6, y - 3.8, 1.2, '#e0e4ee') + dot(x - 2.6, y - 3.8, 0.45, L))
    P.append(Part('fill', strap, fill=R_LEATHER, shade=R_LEATHER_SH, off=(-0.6, -0.8), rim=False,
                  over=line('M73 82.6 L54 101', '#9a7a52', 0.7, op=0.9) + hilts))
    return paint(ctx, P, dict(PAL, base=R_JERK, shade=R_JERK_SH))


R_WING_EDGE = ('M34.4 93.6 C32.4 95.2 32.6 97.8 35 98.4 Q37 100.4 36.4 102.6 Q39.2 103 39.6 105.4 L45.4 104.6 '
               'L41.2 107.4 C38.2 109 38.2 112.4 41.4 113.4 C44.4 114.4 47.6 113 49.4 110.2')


def runner_cape(ctx):
    """The moth-wing cloak: a forewing with a round apex and a scalloped
    trailing edge, a notch, then a round hindwing, in the scarf's dusty tan
    with a soot margin and a violet eye-spot on each wing. Folded down his
    back under the hood at rest, it opens behind him as the cape flares back
    (a dash, a cling)."""
    d = ('M64.4 80.6 C58 80.2 52.6 81.6 48 84.4 C43.6 87 38.4 90.4 ' + R_WING_EDGE[1:]
         + ' C51.8 106.6 53.8 102.8 56.6 99.4 C58.8 96.6 61.4 94.4 64.6 93.2 Z')
    veins = line('M57.4 86 Q46 90 36.4 96 M56.6 88.6 Q47.4 95 38.8 101.6 M55.4 92.4 Q50 99 45.6 103.8 '
                 'M53.8 100.4 Q47.4 105.4 42 111.4', R_SCARF_SH, 0.9, op=0.9)
    margin = line(R_WING_EDGE, '#8a7658', 2.6) + line('M48 84.4 C43.6 87 38.4 90.4 34.4 93.6', '#8a7658', 1.6)
    spots = ''.join('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s" stroke="%s" stroke-width="0.8"/>'
                    '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s"/>%s' % (
                        x, y, r, R_SPOT, '#3e3858', x, y, r * 0.45, '#e8d8a8', dot(x - r * 0.25, y - r * 0.3, r * 0.2, '#ffffff'))
                    for x, y, r in ((41.6, 96.4, 3.2), (43.6, 109.8, 2.3)))
    inner = '<g clip-path="%s">%s%s%s</g>' % (_clip(ctx, pth(d)), veins, margin, spots)
    P = [Part('fill', pth(d), fill=R_SCARF, shade=R_SCARF_SH, off=(-2.2, -2), line='#1c1020', over=inner,
              hl=line('M49.4 85.6 C45 88.2 40.6 91 37.2 93.8', '#f0e2c8', 1.2, op=0.9))]
    return paint(ctx, P, PAL)


def runner_arm(ctx, front):
    sx, sy, hx, hy = arm_points(front)
    sleeve = R_JERK if front else mix(R_JERK, '#000000', 0.2)
    sleeve_sh = R_JERK_SH if front else mix(R_JERK_SH, '#000000', 0.2)
    wrap = '#d8c8a8' if front else '#b0a080'
    P = [Part('fill', pth(sleeve_d(front, 1.8, 2.9)), fill=sleeve, shade=sleeve_sh, off=(-1.1, -0.6))]
    cuff = pth('M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (hx - 3.4, hy - 6.8, hx + 3.6, hy - 6.8, hx + 3.2, hy - 2.6,
                                                                 hx - 3, hy - 2.6))
    P.append(Part('fill', cuff, fill=wrap, shade=mix(wrap, '#000000', 0.2), off=(-0.8, -0.6),
                  over=line('M%.1f %.1f L%.1f %.1f M%.1f %.1f L%.1f %.1f' % (hx - 3.2, hy - 4.6, hx + 3.4, hy - 5.8,
                                                                         hx - 3, hy - 3, hx + 3.2, hy - 4.2), '#8a7a5a', 0.7)))
    P.append(fist(hx, hy, SKIN if front else SKIN_SH, SKIN_SH, 0.92))
    return paint(ctx, P, dict(PAL, base=sleeve, shade=sleeve_sh))


def runner_leg(ctx, front):
    if front:
        leg, x0, tip, fill, sh, boot, boot_sh = 'M68 104.4 Q68.6 109.4 69.2 113.6', 63.8, 77.2, R_LEG, R_LEG_SH, R_BOOT, R_BOOT_SH
    else:
        leg, x0, tip, fill, sh, boot, boot_sh = 'M60 104.4 Q59.8 109.4 59.6 113.6', 54, 66.2, mix(R_LEG, '#000000', 0.2), R_LEG_SH, mix(R_BOOT, '#000000', 0.2), mix(R_BOOT_SH, '#000000', 0.2)
    wraps = line('M%.1f 114.6 L%.1f 113.4 M%.1f 116.6 L%.1f 115.4' % (x0 + 0.4, x0 + 6.4, x0 + 0.4, x0 + 6.8), '#c8b898', 1.2)
    P = [Part('limb', pth(leg), width=5.8, fill=fill),
         shoe(x0, tip, 111.8, 120.6, boot, boot_sh, over=wraps
              + line('M%.1f 119.4 L%.1f 119.4' % (x0 + 0.4, tip - 1.4), '#2a2020', 1.3, cap='butt'))]
    return paint(ctx, P, PAL)


def runner_weapon(ctx):
    """The snuffer knife: a slim steel blade, a wrapped grip and a pommel
    that is a tiny brass snuffer bell."""
    P = []
    blade = pth('M61.8 86.6 L61.8 71.2 C61.8 67 62.8 63.4 64.6 60.4 C66 63.6 66.6 67.2 66.4 71.2 L66.4 86.6 Z')
    P.append(Part('fill', blade, fill='#e4e8f2', shade='#9ea4bc', off=(-1.6, 0),
                  over=line('M64.2 64 L64.2 85', '#9ea4bc', 0.9) + line('M62.8 68 L62.8 85.6', '#ffffff', 0.9)))
    P.append(Part('limb', pth('M64 90 L64 100.6'), width=3.4, fill='#3a2a3a',
                  over=line('M62.6 92.4 L65.4 93.6 M62.6 95.4 L65.4 96.6 M62.6 98.4 L65.4 99.6', '#6a5a6a', 0.8)))
    guard = pth('M58.6 86.2 Q57.6 87.8 58.8 89.6 L69.2 89.6 Q70.4 87.8 69.4 86.2 Z')
    P.append(Part('fill', guard, fill=BRASS, shade=BRASS_SH, off=(-0.8, -1), line=BRASS_LINE))
    bell = pth('M61.2 106 C61.2 103.2 62.4 101.8 64 101.8 C65.6 101.8 66.8 103.2 66.8 106 L67.8 107.4 L60.2 107.4 Z')
    P.append(Part('fill', bell, fill=BRASS, shade=BRASS_SH, off=(-0.6, -0.8), line=BRASS_LINE,
                  over=dot(64, 108.4, 0.9, BRASS_LINE), hl=dot(63, 103.8, 0.6, BRASS_HI)))
    return paint(ctx, P, dict(PAL, base='#e4e8f2', shade='#9ea4bc'))


# ================================================================ founder: the Bellfounder

F_IRON, F_IRON_SH, F_IRON_HI = '#5c5c72', '#3e3e52', '#9494ae'
F_TUNIC, F_TUNIC_SH = '#b8542a', '#86381c'
F_APRON, F_APRON_SH = '#7a4a2a', '#553018'
F_HAIR, F_HAIR_SH, F_HAIR_HI = '#c8602e', '#8e3e1a', '#f09a5a'
F_ASH, F_ASH_SH = '#6a6272', '#4a4456'
BRONZE, BRONZE_SH, BRONZE_HI, BRONZE_LINE = '#c8893a', '#8e5a24', '#f2c07a', '#3a2008'
F_SKIN, F_SKIN_SH = '#f8d0b0', '#e8ae8e'
F_WOOD, F_WOOD_SH = '#c8a070', '#94703e'
F_BOOT, F_BOOT_SH = '#5e3c24', '#3e2616'


def founder_extra(ctx, mood):
    # soot on the near cheek, in every face
    return ('<ellipse cx="59.2" cy="74.6" rx="3.4" ry="1.5" fill="#3a3040" opacity="0.42" transform="rotate(-14 59.2 74.6)"/>'
            + dot(62.6, 73.2, 0.8, '#3a3040', 0.4) + dot(84.6, 72.6, 0.7, '#3a3040', 0.35))


F_LOOK = face_look(F_SKIN, F_SKIN_SH, ('#0e2a14', '#2a7a3a', '#b8f070'), '#ff8a80', extra=founder_extra)


def founder_head(ctx, mood):
    P = []
    # two short copper braids down the back
    for x0, x1, k in ((42.4, 40.6, 1.0), (47.6, 46.4, 0.9)):
        braid = 'M%.1f 72 Q%.1f 82 %.1f 91' % (x0, x0 - 2.4, x1)
        ties = line('M%.1f 76 l2.6 1 M%.1f 80.6 l2.6 1 M%.1f 85.2 l2.6 1' % (x0 - 2.4, x0 - 2.8, x0 - 2.6), F_HAIR_SH, 1.0)
        P.append(Part('limb', pth(braid), width=4.6 * k, fill=F_HAIR, over=ties))
        P.append(Part('fill', pth('M%.1f 90 L%.1f 90 L%.1f 95.6 Q%.1f 94 %.1f 96 Q%.1f 94 %.1f 95.6 Z' % (
            x1 - 2.4, x1 + 2.4, x1 + 2.6, x1 + 1, x1, x1 - 1, x1 - 2.6)), fill=F_HAIR, shade=F_HAIR_SH, off=(-0.6, -0.6),
            over=line('M%.1f 90.2 L%.1f 90.2' % (x1 - 2.6, x1 + 2.6), '#2a7a3a', 1.6)))
    hair = pth('M40 52 C38.6 66 44 84.6 64 86.4 C84 84.6 90.2 68 88.8 52 Z')
    P.append(Part('fill', hair, fill=F_HAIR, shade=F_HAIR_SH, off=(-3, -3)))
    # a blunt copper fringe
    tips = [(51, 59.4), (56, 61.2), (61.6, 61.4), (67.4, 62.2), (73.4, 61), (79.4, 61.4), (86, 60)]
    P.append(face_part(ctx, F_LOOK, mood, tips, F_HAIR, F_HAIR_HI, bangs_top=54))
    # the iron pot-helm: a flat-topped pot, a riveted rim and short cheek flaps
    flap_n = pth('M39.6 55 L51.2 55 L51.8 69.4 C51.8 74.6 49 78.6 45 78.6 C41.8 78.6 40 76 39.8 71.8 Z')
    flap_f = pth('M86.6 55 L92 55 L91.6 70.6 C91.4 74.4 89.6 76.8 87.6 77 C86.8 70 86.4 62 86.6 55 Z')
    for fl in (flap_n, flap_f):
        P.append(Part('fill', fl, fill=F_IRON, shade=F_IRON_SH, off=(-1.4, -1.8),
                      over=dot(45.4, 60.4, 0.9, L, 0.6) if fl is flap_n else ''))
    pot = pth('M41 53 L42.2 40.4 C42.6 36.6 45 35 49.2 34.6 L79.2 34.6 C83.4 35 85.8 36.6 86.2 40.4 L87.4 53 Z')
    dents = line('M50 38 Q52 44 51.4 50 M73.6 37.6 Q76.4 44 76.4 50', F_IRON_SH, 1.0, op=0.8)
    P.append(Part('fill', pot, fill=F_IRON, shade=F_IRON_SH, off=(-4, -3.6), over=dents,
                  hl=line('M45.4 50 L46.4 41 C46.8 38.6 48.2 37.6 50.4 37.4 L60 37.4', F_IRON_HI, 1.5, op=0.9)))
    rim = pth('M36.8 48.8 L91.4 48.8 C92.6 48.8 93.4 49.8 93.2 51.2 L92.6 55 C92.4 56.2 91.6 56.8 90.4 56.8 '
              'L37.8 56.8 C36.6 56.8 35.8 56.2 35.6 55 L35 51.2 C34.8 49.8 35.6 48.8 36.8 48.8 Z')
    rivets = ''.join(dot(x, 52.8, 1.1, L, 0.7) + dot(x - 0.3, 52.4, 0.4, F_IRON_HI) for x in (39.6, 48.6, 57.8, 67.2, 76.6, 86))
    P.append(Part('fill', rim, fill=F_IRON, shade=F_IRON_SH, off=(-1.4, -2.2), over=rivets,
                  hl=line('M37.4 50.6 L90.6 50.6', F_IRON_HI, 1.1, op=0.9)))
    return paint(ctx, P, dict(PAL, base=F_IRON, shade=F_IRON_SH)) + mood_fx(mood)


def founder_candle(ctx):
    """A brazier dish on three iron prongs holding three glowing coals; the
    flame (1.25x wide) sits on them at (62, 22)."""
    P = []
    for leg in ('M55.2 28.4 L52.6 35.4', 'M62 29 L62 35.4', 'M68.8 28.4 L71.4 35.4'):
        P.append(Part('limb', pth(leg), width=1.8, fill=F_IRON))
    dish = pth('M50 23.6 L74 23.6 C73.8 27.4 69.6 29.8 62 29.8 C54.4 29.8 50.2 27.4 50 23.6 Z')
    P.append(Part('fill', dish, fill=F_IRON, shade=F_IRON_SH, off=(-1.2, -1.2),
                  over=line('M51.4 25 Q62 27.4 72.6 25', F_IRON_HI, 0.9, op=0.9)
                  + ''.join(dot(x, 26.6, 0.7, L, 0.6) for x in (55, 62, 69))))
    coals = [(56, 23.2, 3.8, 2.4), (68.4, 23.2, 3.6, 2.3), (62.2, 22.4, 4, 2.7)]
    for cx, cy, rx, ry in coals:
        P.append(Part('fill', ell(cx, cy, rx, ry), fill='#e0602a', shade='#a8361a', off=(-0.8, -0.8), line='#2a1410', lw=0.9,
                      rim=False,
                      over=line('M%.1f %.1f L%.1f %.1f L%.1f %.1f' % (cx - rx * 0.6, cy, cx - rx * 0.1, cy - ry * 0.4, cx + rx * 0.5, cy + ry * 0.2),
                                '#2a1410', 0.7) + dot(cx - rx * 0.35, cy - ry * 0.35, ry * 0.35, '#ffd07a')))
    return paint(ctx, P, dict(PAL, base=F_IRON, shade=F_IRON_SH))


def founder_body(ctx):
    P = []
    tunic = pth('M50 82.4 C50 80.8 55 79.6 64 79.6 C73 79.6 78 80.8 78 82.4 L82.8 104 C83.2 107 82.2 110.6 78.8 111 '
                'L49.2 111 C45.8 110.6 44.8 107 45.2 104 Z')
    P.append(Part('fill', tunic, fill=F_TUNIC, shade=F_TUNIC_SH, off=(-3, -2.4),
                  hl=spec(52.4, 88.6, 1.3, 3.4, rot=10, op=0.3)))
    # the heavy leather apron over it, strapped at the shoulders with bell buckles
    apron = pth('M52.2 86.4 L75.8 86.4 C77 94 78 104 78.4 114.6 C73 116 55 116 49.6 114.6 C50 104 51 94 52.2 86.4 Z')
    scorch = (dot(58, 106.6, 1.6, '#3a2010', 0.55) + dot(71.2, 99.4, 1.2, '#3a2010', 0.5) + dot(55.4, 95, 0.9, '#3a2010', 0.45))
    pocket = ('<path d="M59 100.4 L69 100.4 L68.6 106.6 Q64 108 59.4 106.6 Z" fill="none" stroke="%s" stroke-width="0.9"/>' % F_APRON_SH
              + line('M59.2 102 L68.8 102', '#a8784a', 0.7, op=0.8))
    stitch = '<path d="M52.8 88 C51.8 96 51.2 104 51 113" fill="none" stroke="#a8784a" stroke-width="0.6" stroke-dasharray="1.2 1.2"/>'
    P.append(Part('fill', apron, fill=F_APRON, shade=F_APRON_SH, off=(-2.4, -2.2), over=scorch + pocket + stitch,
                  hl=spec(55.4, 90, 1, 2.6, rot=8, op=0.35)))
    for x0, x1 in ((54.4, 55.6), (73.6, 72.4)):
        P.append(Part('limb', pth('M%.1f 87 L%.1f 80.6' % (x0, x1)), width=2.6, fill=F_APRON))
    for x in (54.2, 73.8):
        bell = pth('M%.1f 89.8 C%.1f 87.2 %.1f 85.6 %.1f 85.6 C%.1f 85.6 %.1f 87.2 %.1f 89.8 L%.1f 90.8 L%.1f 90.8 Z' % (
            x - 2, x - 2, x - 1, x, x + 1, x + 2, x + 2, x + 2.8, x - 2.8))
        P.append(Part('fill', bell, fill=BRONZE, shade=BRONZE_SH, off=(-0.5, -0.6), line=BRONZE_LINE, lw=0.8,
                      over=dot(x, 91.4, 0.7, BRONZE_LINE), hl=dot(x - 0.7, 87.4, 0.5, BRONZE_HI)))
    # the apron's waist tie showing at the sides
    P.append(Part('limb', pth('M45.8 99.4 L50.6 99.4'), width=1.6, fill='#d8b890', rim=False))
    return paint(ctx, P, dict(PAL, base=F_TUNIC, shade=F_TUNIC_SH))


F_CAPE_HEM = [(38.8, 104.6), (41.8, 102.8), (43, 107.2), (46, 103.2), (48.6, 107.4), (51.2, 102.8), (54.2, 105.4),
              (56.4, 100)]


def founder_cape(ctx):
    """A short ash-grey mantle, its ragged hem singed; it hangs just past the
    ends of her braids, so the burnt hem shows behind her at rest."""
    hem = F_CAPE_HEM
    d = ('M62 81 C55 80.8 50 82.4 47.4 85.8 C44.2 89.8 41 96.4 %.1f %.1f ' % hem[0]
         + ' '.join('L%.1f %.1f' % p for p in hem[1:]) + ' L62.6 90 Z')
    hem_d = 'M' + ' L'.join('%.1f %.1f' % p for p in hem)
    glow_d = 'M' + ' L'.join('%.1f %.1f' % (x + 0.4, y - 1.4) for x, y in hem[:-1])
    singe = ('<g clip-path="%s">%s</g>') % (_clip(ctx, pth(d)), line(hem_d, '#3a2418', 2.6)
                                           + line(glow_d, '#c8602e', 0.9, op=0.8))
    P = [Part('fill', pth(d), fill=F_ASH, shade=F_ASH_SH, off=(-2.4, -2), line='#1c1020',
              over=singe + line('M50 88 Q47 95 45.8 102', F_ASH_SH, 1.1, op=0.9))]
    return paint(ctx, P, PAL)


def founder_arm(ctx, front):
    """A rolled sleeve, a thick bare forearm, a chunky leather bracer and a big fist."""
    sx, sy, hx, hy = arm_points(front)
    tunic = F_TUNIC if front else mix(F_TUNIC, '#000000', 0.2)
    tunic_sh = F_TUNIC_SH if front else mix(F_TUNIC_SH, '#000000', 0.2)
    skin = F_SKIN if front else F_SKIN_SH
    ax, ay = sx + 0.4, sy + 3.2
    fore = pth('M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (
        ax - 2.4, ay + 0.6, ax - 2.4, ay - 1.8, ax + 2.4, ay - 1.8, ax + 2.4, ay + 0.6, hx + 3.8, hy - 3.4, hx - 3.4, hy - 3.4))
    P = [Part('fill', fore, fill=skin, shade=F_SKIN_SH if front else mix(F_SKIN_SH, '#000000', 0.12), off=(-1.2, -0.6))]
    roll = pth('M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f L%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z' % (
        ax - 2.8, ay + 0.8, ax - 2.8, ay - 2.2, ax + 2.8, ay - 2.2, ax + 2.8, ay + 0.8,
        ax + 3.6, ay + 5, ax + 1, ay + 6.2, ax - 1.6, ay + 6.2, ax - 3.4, ay + 5))
    P.append(Part('fill', roll, fill=tunic, shade=tunic_sh, off=(-1, -0.8),
                  over=line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (ax - 3.2, ay + 3.6, ax, ay + 4.6, ax + 3.4, ay + 3.6), tunic_sh, 0.9)))
    bracer = pth('M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (hx - 4.6, hy - 8.2, hx + 5, hy - 8.2, hx + 4.8, hy - 2.8, hx - 4.4, hy - 2.8))
    P.append(Part('fill', bracer, fill=F_APRON, shade=F_APRON_SH, off=(-1, -0.8),
                  over=line('M%.1f %.1f L%.1f %.1f' % (hx - 4.4, hy - 5.6, hx + 4.8, hy - 5.6), '#3a2010', 1.0)
                  + dot(hx + 2.8, hy - 6.8, 0.7, BRONZE) + dot(hx + 2.8, hy - 4.2, 0.7, BRONZE)))
    P.append(fist(hx, hy + 0.2, skin, F_SKIN_SH, 1.12))
    return paint(ctx, P, dict(PAL, base=tunic, shade=tunic_sh))


def founder_leg(ctx, front):
    """Heavy hobnail boots with iron toe caps."""
    if front:
        leg, x0, tip, pants = 'M68.4 104.4 Q69 109 69.6 112.6', 62.4, 80, '#4a3a34'
        boot, boot_sh = F_BOOT, F_BOOT_SH
    else:
        leg, x0, tip, pants = 'M59.6 104.4 Q59.4 109 59.2 112.6', 52.2, 68.4, '#3a2c28'
        boot, boot_sh = mix(F_BOOT, '#000000', 0.2), mix(F_BOOT_SH, '#000000', 0.2)
    w = tip - x0
    d = ('M%.1f 120.6 L%.1f 112.8 C%.1f 110.4 %.1f 109.4 %.1f 109.4 C%.1f 109.4 %.1f 110.6 %.1f 113.4 '
         'C%.1f 113.8 %.1f 115.4 %.1f 120.6 Z') % (x0, x0, x0, x0 + w * 0.2, x0 + w * 0.42, x0 + w * 0.64, x0 + w * 0.7,
                                                x0 + w * 0.72, x0 + w * 0.96, tip, tip)
    cap = pth('M%.1f 120 L%.1f 113.8 C%.1f 114.2 %.1f 116 %.1f 120 Z' % (x0 + w * 0.7, x0 + w * 0.72, x0 + w * 0.96, tip, tip))
    nails = ''.join(dot(x0 + w * k, 121.2, 0.6, '#c3c7d6') for k in (0.12, 0.3, 0.48, 0.66, 0.84))
    P = [Part('limb', pth(leg), width=8.2, fill=pants),
         Part('fill', pth(d), fill=boot, shade=boot_sh, off=(-1.4, -1.8),
              over=line('M%.1f 119.4 L%.1f 119.4' % (x0 + 0.4, tip - 0.4), '#2a1a10', 1.8, cap='butt')
              + line('M%.1f 111.8 L%.1f 111.8' % (x0 + 0.6, x0 + w * 0.66), '#2a1a10', 0.9, op=0.7),
              hl=spec(x0 + w * 0.3, 111.4, 1.4, 0.8, rot=-20, op=0.6)),
         Part('fill', cap, fill=F_IRON, shade=F_IRON_SH, off=(-0.8, -1), rim=False, hl=spec(tip - 4, 115.2, 1.2, 0.7, op=0.9))]
    return paint(ctx, P, PAL) + nails


def scale_d(d, ox, oy, k):
    """Path data (absolute M L C Q Z only) scaled by k about (ox, oy)."""
    out, nums = [], []
    for tok in d.replace(',', ' ').split():
        if tok[0].isalpha():
            out.append(tok[0])
            tok = tok[1:]
            if not tok:
                continue
        nums.append(float(tok))
        if len(nums) == 2:
            out.append('%.2f %.2f' % (ox + (nums[0] - ox) * k, oy + (nums[1] - oy) * k))
            nums = []
    return ' '.join(out)


def founder_weapon(ctx):
    """The Founder's Maul: an ash haft whose head is a bronze hand-bell turned
    sideways, its mouth leading, the clapper showing."""
    P = []
    P.append(Part('limb', pth('M64 113.4 L64 68'), width=4.6, fill=F_WOOD,
                  over=line('M62.8 76 Q64 80 63.6 84', F_WOOD_SH, 0.8, op=0.9)
                  + line('M61.8 91.4 L66.2 92.6 M61.8 94.4 L66.2 95.6 M61.8 97.4 L66.2 98.6 M61.8 100.4 L66.2 101.6', '#553018', 1.1)))
    P.append(Part('fill', pth('M61 110 L67 110 L67.4 115 Q64 116.4 60.6 115 Z'), fill=F_IRON, shade=F_IRON_SH, off=(-0.6, -0.6)))
    # the head, drawn at full size and set down to 86% about the haft's top
    k, ox, oy = 0.86, 64, 70

    def S(d):
        return scale_d(d, ox, oy, k)

    def X(x, y):
        return ox + (x - ox) * k, oy + (y - oy) * k
    body = pth(S('M49.6 55 C49.6 51.8 51.8 50.4 55 50.6 L64.6 51.4 C69.4 51.6 73.2 48.6 76.4 45.8 C78.6 44 81.2 45 81.2 48 '
                 'L81.2 71 C81.2 74 78.6 75 76.4 73.2 C73.2 70.4 69.4 67.4 64.6 67.6 L55 68.4 C51.8 68.6 49.6 67.2 49.6 64 Z'))
    bands = line(S('M57.4 51.2 L57.4 67.8 M70.8 48.6 L70.8 70.2'), BRONZE_SH, 1.6) + line(S('M58.2 51.6 L58.2 67.4'), BRONZE_HI, 0.7, op=0.9)
    P.append(Part('fill', body, fill=BRONZE, shade=BRONZE_SH, off=(-2, -2.4), line=BRONZE_LINE, over=bands,
                  hl=spec(*X(62, 54.6), 3.4, 1.1, rot=-6, op=0.9) + spec(*X(75.4, 49), 1.4, 0.7, rot=-40, op=0.9)))
    # the crown's knob, and the mouth: a lip, the dark inside, the clapper
    kx, ky = X(47.6, 59.4)
    P.append(Part('fill', ell(kx, ky, 2.6 * k, 3.6 * k), fill=BRONZE, shade=BRONZE_SH, off=(-0.6, -0.6), line=BRONZE_LINE))
    mx, my = X(81, 59.4)
    lx, ly = X(81.6, 59.4)
    cx, cy = X(81.4, 66.4)
    P.append(Part('fill', ell(mx, my, 3 * k, 13.6 * k), fill='#3a2008', shade='#3a2008', no_shade=True, line=BRONZE_LINE,
                  over='<ellipse cx="%.2f" cy="%.2f" rx="%.2f" ry="%.2f" fill="none" stroke="%s" stroke-width="1.8"/>' % (
                      lx, ly, 2 * k, 11.6 * k, BRONZE) + dot(cx, cy, 2.4, BRONZE_SH) + dot(cx - 0.6, cy - 0.8, 0.8, BRONZE_HI)))
    P.append(Part('fill', pth(S('M60.2 67.6 L67.8 67.2 L67.4 70.4 L60.6 70.6 Z')), fill=F_IRON, shade=F_IRON_SH, off=(-0.6, -0.6)))
    return paint(ctx, P, dict(PAL, base=BRONZE, shade=BRONZE_SH))


# ================================================================ sexton: the Sexton

X_HAT, X_HAT_SH, X_HAT_HI = '#2e2640', '#1c1628', '#4e4468'
X_COAT, X_COAT_SH, X_COAT_HI = '#433a62', '#2a2346', '#62568a'
X_LAV, X_LAV_SH = '#a89ad8', '#7a6aae'
X_HAIR, X_HAIR_SH, X_HAIR_HI = '#2e2440', '#1c1630', '#5a4a7a'
X_SKIN, X_SKIN_SH = '#f6e6e4', '#dcc4cc'
BONE, BONE_SH, BONE_LINE = '#f0e8d8', '#c8bca4', '#3a2e24'
X_WOOD, X_WOOD_SH = '#7a4a2a', '#553018'
X_IRON, X_IRON_SH = '#8b90a8', '#646982'


def sexton_extra(ctx, mood):
    # soft lavender shadows under the eyes
    s = ''
    if mood in ('normal', 'blink', 'fierce'):
        for cx, cy, w, h in (wick.E1, wick.E2):
            s += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (cx - w * 0.38, cy + h * 0.56, cx, cy + h * 0.72, cx + w * 0.38, cy + h * 0.56),
                      '#b49cff', 1.2, op=0.7)
    return s


X_LOOK = face_look(X_SKIN, X_SKIN_SH, ('#1a1030', '#5a4a8a', '#d0c0ff'), '#e8a0c8', lid=0.42, extra=sexton_extra)


def sexton_head(ctx, mood):
    P = []
    # the mourning ribbon's tail hanging down the back of the hat
    P.append(Part('fill', pth('M49 44 L53.4 45 C52.4 51 50.8 57 47.8 62.6 L45.2 60.2 L43.2 63 C45.2 57 47 50.6 49 44 Z'),
                  fill=X_LAV, shade=X_LAV_SH, off=(-0.8, -1)))
    # a straight dark bob
    hair = pth('M39.8 50 C38.6 64 39.8 78 42.4 87 L47.4 84.6 L50.4 88.6 L53.8 84 C60 86.4 70 87 80 85.2 L84.2 88.4 '
               'L86.4 83.6 L89.8 85 C91.2 76 91 62 89.8 50 Z')
    P.append(Part('fill', hair, fill=X_HAIR, shade=X_HAIR_SH, off=(-3, -3),
                  hl=line('M42.8 56 C41.8 64 42.2 72 43.6 80', X_HAIR_HI, 1.4, op=0.9)))
    tips = [(51.4, 61), (56.4, 62.4), (61.6, 62.2), (67, 62.8), (72.6, 62.2), (78.4, 62.4), (84.2, 61.8), (89.4, 60.4)]
    P.append(face_part(ctx, X_LOOK, mood, tips, X_HAIR, X_HAIR_HI))
    # the stovepipe, a little crooked
    crown = pth('M50.4 50.4 L51.6 24.2 C51.7 22.6 53 21.6 54.8 21.6 L74.4 22.6 C76.2 22.7 77.4 23.8 77.6 25.4 L79.6 50.8 Z')
    ribbon = ('<g clip-path="%s"><path d="M40 42.2 L90 43.2 L90 48.4 L40 47.6 Z" fill="%s"/>%s</g>' % (
        _clip(ctx, crown), X_LAV, line('M40 43.6 L90 44.6', '#d8d0f8', 0.8, op=0.9)))
    P.append(Part('fill', crown, fill=X_HAT, shade=X_HAT_SH, off=(-3.2, -2), over=ribbon,
                  hl=line('M55.4 25.6 L54.6 40', X_HAT_HI, 1.6, op=0.9)))
    # the bow on the band
    P.append(Part('fill', pth('M52.6 44.4 C50.4 41.8 47.6 42.4 47.8 45 C48 47.4 50.8 47.6 52.6 45.8 Z'), fill=X_LAV, shade=X_LAV_SH,
                  off=(-0.5, -0.6), rim=False))
    brim = ell(64.8, 50.8, 26.8, 4.4)
    P.append(Part('fill', brim, fill=X_HAT, shade=X_HAT_SH, off=(-1.4, -2.2),
                  over=line('M39.4 49.8 Q64 45.6 90.4 50', X_HAT_HI, 1.2, op=0.9)))
    return paint(ctx, P, dict(PAL, base=X_HAT, shade=X_HAT_SH)) + mood_fx(mood)


def sexton_candle(ctx):
    """A tiny round smiling skull perched on the crown, a candle stub set in
    its pate, the wick at (62, 6)."""
    P = []
    skull = pth('M56.8 17.4 C56.8 13.4 59.8 10.8 63.6 10.8 C67.4 10.8 70.4 13.4 70.4 17.4 C70.4 19.4 69.4 20.8 68 21.4 '
                'L68 22.6 L59.2 22.6 L59.2 21.4 C57.8 20.8 56.8 19.4 56.8 17.4 Z')
    face = ('<ellipse cx="61.4" cy="17.4" rx="1.7" ry="1.9" fill="%s"/><ellipse cx="66.4" cy="17.4" rx="1.6" ry="1.8" fill="%s"/>' % (
        BONE_LINE, BONE_LINE)
            + dot(61, 16.8, 0.5, '#ffffff') + dot(66, 16.8, 0.45, '#ffffff')
            + '<path d="M63.6 19 L63 20 L64.2 20 Z" fill="%s"/>' % BONE_LINE
            + line('M60.8 21 Q63.6 22.6 66.6 21', BONE_LINE, 0.8)
            + line('M62.2 21.4 L62.2 22.4 M63.6 21.8 L63.6 22.6 M65 21.4 L65 22.4', BONE_LINE, 0.5))
    P.append(Part('fill', skull, fill=BONE, shade=BONE_SH, off=(-1.4, -1.2), line=BONE_LINE, over=face,
                  hl=spec(59.6, 13.6, 1.4, 0.8, rot=-30, op=0.9)))
    stub = pth('M60 12.4 L60 8.8 L64.4 8.8 L64.4 12.4 Z')
    P.append(Part('fill', stub, fill=WAX, shade=WAX_SH, off=(-1, 0), line=WAX_LINE))
    cap = pth('M59.6 9 C59.6 8 60.6 7.6 62.2 7.6 C63.8 7.6 64.8 8 64.8 9 L64.8 11 C64.8 11.8 63.8 11.8 63.8 11 L63.8 10.2 '
              'C63.4 9.8 62.8 9.8 62.4 10.2 L62.4 13.4 C62.4 14.4 61 14.4 61 13.4 L61 10.2 C60.6 9.8 60.2 9.8 59.6 10 Z')
    P.append(Part('fill', cap, fill='#fffaec', shade='#e8dcbc', off=(-0.6, -0.4), line='#b89c6c', lw=0.8, rim=False))
    wick_line = line('M62.2 8 Q61.8 7 62 6.1', '#241a14', 1.3)
    return paint(ctx, P, dict(PAL, base=BONE, shade=BONE_SH)) + wick_line


def sexton_body(ctx):
    P = []
    coat = pth('M53.8 81.8 L74.2 81.8 C76.6 90 78.6 100 79.8 110.6 C80 112.6 79.4 114.4 77.6 114.6 L66.2 115.2 L64 111.8 '
               'L61.8 115.2 L50.4 114.6 C48.6 114.4 48 112.6 48.2 110.6 C49.4 100 51.4 90 53.8 81.8 Z')
    lapels = ('<g clip-path="%s"><path d="M56 81 L63.6 81 L64.6 96 Z" fill="%s"/><path d="M72 81 L65.4 81 L64.6 96 Z" fill="%s"/>%s</g>' % (
        _clip(ctx, coat), X_COAT_HI, X_COAT_SH, line('M64.6 96 L64 112', '#140e20', 1.0)))
    buttons = ''.join(dot(x, y, 1.1, GOLD) + dot(x - 0.3, y - 0.3, 0.4, '#fff6d0') for x, y in ((66.8, 99.4), (67, 104.2), (67.2, 109)))
    P.append(Part('fill', coat, fill=X_COAT, shade=X_COAT_SH, off=(-3, -2.4), over=lapels + buttons,
                  hl=spec(56.8, 90, 1.2, 3.6, rot=10, op=0.3)))
    # the lavender cravat, its ends down the shirt front
    cravat = pth('M61 82 L68.6 82 L67.4 85.4 L68.4 93.4 L65.6 91.8 L64 94.6 L63.2 85.4 Z')
    P.append(Part('fill', cravat, fill=X_LAV, shade=X_LAV_SH, off=(-0.8, -1), rim=False,
                  over=line('M64.2 85.4 L66.4 85.4', X_LAV_SH, 1.0)))
    return paint(ctx, P, dict(PAL, base=X_COAT, shade=X_COAT_SH))


X_CAPE_D = ('M61.6 82 C56 82.4 52 84.6 50 89 C47.4 95 46 104 45.4 116.8 L49.8 113.4 L52.6 118.2 C53.8 112 55.4 104.4 57.6 98.4 '
            'L58.8 104.6 L60.4 117.6 L62.8 113.8 L62.8 90 Z')


def sexton_cape(ctx):
    """The frock coat's split tails."""
    d = X_CAPE_D
    lining = ('<g clip-path="%s">%s</g>') % (_clip(ctx, pth(d)), line('M45 116.8 L49.8 113.4 L52.6 118.2 M60.4 117.6 L62.8 113.8', X_LAV_SH, 2.4))
    P = [Part('fill', pth(d), fill=X_COAT, shade=X_COAT_SH, off=(-2.4, -2), line='#120c1c',
              over=lining + line('M52.6 92 Q50.6 102 50 111', X_COAT_SH, 1.1, op=0.9))]
    return paint(ctx, P, PAL)


def sexton_arm(ctx, front):
    sx, sy, hx, hy = arm_points(front)
    coat = X_COAT if front else mix(X_COAT, '#000000', 0.2)
    coat_sh = X_COAT_SH if front else mix(X_COAT_SH, '#000000', 0.2)
    P = [Part('fill', pth(sleeve_d(front, 1.9, 3.5)), fill=coat, shade=coat_sh, off=(-1.2, -0.6),
              over=line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (sx - 1, sy + 7, sx + 1.4, sy + 8.4, sx + 3, sy + 7.4), coat_sh, 0.8, op=0.8))]
    cuff = pth('M%.1f %.1f Q%.1f %.1f %.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f Z' % (
        hx - 4, hy - 5.4, hx, hy - 6.2, hx + 4.2, hy - 5.4, hx + 3.6, hy - 2.6, hx, hy - 3.2, hx - 3.4, hy - 2.6))
    P.append(Part('fill', cuff, fill='#e4dcec', shade='#b8aec8', off=(-0.8, -0.6)))
    P.append(fist(hx, hy, X_SKIN if front else X_SKIN_SH, X_SKIN_SH, 0.9))
    return paint(ctx, P, dict(PAL, base=coat, shade=coat_sh))


def sexton_leg(ctx, front):
    if front:
        leg, x0, tip, pants, shoe_c = 'M68 104.4 Q68.6 109.4 69.2 113.6', 63.8, 79.2, '#2a2438', '#241c30'
    else:
        leg, x0, tip, pants, shoe_c = 'M60 104.4 Q59.8 109.4 59.6 113.6', 54, 67.8, '#1e1a2a', '#1a1424'
    buckle = ('<rect x="%.1f" y="114.8" width="3.2" height="2.6" rx="0.6" fill="none" stroke="%s" stroke-width="0.9"/>' % (
        x0 + (tip - x0) * 0.46, GOLD))
    P = [Part('limb', pth(leg), width=5.4, fill=pants),
         shoe(x0, tip, 113, 120.6, shoe_c, '#120c1a', over=buckle, toe_up=0.8)]
    return paint(ctx, P, PAL)


def sexton_weapon(ctx):
    """A gravedigger's spade: a wooden haft with a D-grip, an iron blade."""
    P = []
    P.append(Part('limb', pth('M64 110 L64 63.4'), width=3.6, fill=X_WOOD,
                  over=line('M63 74 Q64 78 63.4 82', X_WOOD_SH, 0.8, op=0.9)))
    grip = pth('M59.6 110.2 L68.4 110.2 L68.4 114.2 C68.4 117 66.4 118.6 64 118.6 C61.6 118.6 59.6 117 59.6 114.2 Z')
    P.append(Part('fill', grip, fill=X_WOOD, shade=X_WOOD_SH, off=(-0.8, -0.8),
                  over='<path d="M61.8 112 L66.2 112 L66.2 114 C66.2 115.6 65.2 116.4 64 116.4 C62.8 116.4 61.8 115.6 61.8 114 Z" fill="#1c1410"/>'))
    P.append(Part('fill', pth('M61 62 L67 62 L66.6 68.4 L61.4 68.4 Z'), fill=X_IRON, shade=X_IRON_SH, off=(-0.6, -0.6),
                  over=dot(64, 65, 0.7, L, 0.7)))
    blade = pth('M56 62.4 L56.2 49.6 C56.4 44.2 59.8 40 64 38.2 C68.2 40 71.6 44.2 71.8 49.6 L72 62.4 C69 64 59 64 56 62.4 Z')
    P.append(Part('fill', blade, fill=X_IRON, shade=X_IRON_SH, off=(-2, -1.6),
                  over=line('M64 43 L64 60', X_IRON_SH, 0.9, op=0.8) + dot(61.4, 46, 1.1, '#6a4a30', 0.55)
                  + dot(66.6, 41.8, 0.8, '#6a4a30', 0.5),
                  hl=line('M57.6 50.6 C57.8 46.2 60.4 42.6 63.6 40.6', '#e8ecf6', 1.2, op=0.9)))
    return paint(ctx, P, dict(PAL, base=X_IRON, shade=X_IRON_SH))


BELL_TILT = 45     # degrees the handbell hangs back from straight down, at rest


def sexton_bell(ctx):
    """The passing bell: a brass handbell on a turned wooden handle, gripped
    at HAND_BACK (52, 101) and carried tilted back, so at rest its whole bell
    (crown, flared waist, lip and clapper) hangs clear behind the coat and the
    back heel. Drawn mouth-down about the grip, then tilted by BELL_TILT."""
    P = []
    t = 'rotate(%s 52 101)' % BELL_TILT
    # the handle: a knob above the fist, the shaft down to a brass collar
    P.append(Part('limb', xf('M52 98 L52 105.4', t), width=2.6, fill=X_WOOD,
                  over=gx(line('M52.6 102.6 L52.6 104.6', X_WOOD_SH, 0.8), t)))
    P.append(Part('fill', xell(52, 96.4, 1.9, 1.7, t), fill=X_WOOD, shade=X_WOOD_SH, off=(-0.5, -0.5)))
    P.append(Part('fill', xell(52, 105.8, 2.8, 1.2, t), fill=GOLD, shade=GOLD_SH, off=(-0.5, -0.5), line=GOLD_LINE))
    # the bell: a round shoulder, sides that flare gently to a rolled lip (a
    # cup, not a trumpet, so it reads as a bell even at 64 px)
    bell = ('M48.2 109 C48.2 107 49.8 106 52 106 C54.2 106 55.8 107 55.8 109 C56 111.6 56.4 114 57.4 115.6 '
            'C57.9 116.4 58.6 116.9 59.2 117.2 L59.2 118.4 Q52 119.6 44.8 118.4 L44.8 117.2 '
            'C45.4 116.9 46.1 116.4 46.6 115.6 C47.6 114 48 111.6 48.2 109 Z')
    marks = (line('M47.4 114.6 Q52 115.6 56.6 114.6', GOLD_SH, 0.9)
             + line('M45.2 117.4 Q52 118.6 58.8 117.4', GOLD_LINE, 0.7, op=0.8))
    mouth = ('<ellipse cx="52" cy="118.6" rx="6.4" ry="1.1" fill="%s"/>' % GOLD_LINE
             + dot(52, 119.8, 1.5, GOLD_SH) + dot(51.6, 119.4, 0.6, GOLD_HI))
    P.append(Part('fill', xf(bell, t), fill=GOLD, shade=GOLD_SH, off=(-1.2, -1), line=GOLD_LINE,
                  over=gx(marks + mouth, t),
                  hl=gx(spec(50, 110.4, 1.0, 2.6, rot=6, op=0.9) + dot(48.6, 116.2, 0.6, '#fff6d0', 0.9), t)))
    return paint(ctx, P, dict(PAL, base=GOLD, shade=GOLD_SH))


# ================================================================ the callings

def knight_head_art(ctx, mood):
    return wick.head_art(ctx, mood)


def knight_arm(ctx, front):
    return wick.arm_art(ctx, front)


CALLING = {
    'knight': dict(
        head=knight_head_art, candle=wick.candle_art, body=wick.body_art, arm=knight_arm,
        cape=None, leg=None, weapon=None, offhand=knight_shield,
        rig=dict(flame_tip=[60, 19], flame_scale=1.0, light_mult=1.0, offhand=True, offhand_front=True,
                 weapon_rest_deg=80, candle_base=[60, 34.4], portrait_viewbox=[23, 11, 82, 82],
                 weapon_tip=[64, 41.6])),               # the sword's point
    'witch': dict(
        head=witch_head, candle=witch_candle, body=witch_body, arm=witch_arm, cape=witch_cape, leg=witch_leg,
        weapon=witch_weapon, offhand=None,
        rig=dict(flame_tip=[84, 6], flame_scale=0.95, light_mult=1.0, offhand=False, offhand_front=False,
                 weapon_rest_deg=12, candle_base=[75.6, 23.8], portrait_viewbox=[20, -4.5, 100, 100],
                 weapon_tip=[63.4, 34.8])),             # the fork's centre taper, at its wick
    'runner': dict(
        head=runner_head, candle=runner_candle, body=runner_body, arm=runner_arm, cape=runner_cape, leg=runner_leg,
        weapon=runner_weapon, offhand=None,
        rig=dict(flame_tip=[78, 26], flame_scale=0.85, light_mult=0.9, offhand=False, offhand_front=False,
                 weapon_rest_deg=70, candle_base=[78, 33.6], portrait_viewbox=[26, 16, 80, 80],
                 weapon_tip=[64.6, 60.4])),             # the knife's point
    'founder': dict(
        head=founder_head, candle=founder_candle, body=founder_body, arm=founder_arm, cape=founder_cape,
        leg=founder_leg, weapon=founder_weapon, offhand=None,
        rig=dict(flame_tip=[62, 22], flame_scale=1.25, light_mult=1.0, offhand=False, offhand_front=False,
                 weapon_rest_deg=88, candle_base=[62, 35.4], portrait_viewbox=[25, 14, 80, 80],
                 weapon_tip=[78.6, 60.9])),             # the middle of the bell's mouth
    'sexton': dict(
        head=sexton_head, candle=sexton_candle, body=sexton_body, arm=sexton_arm, cape=sexton_cape, leg=sexton_leg,
        weapon=sexton_weapon, offhand=sexton_bell,
        rig=dict(flame_tip=[62, 6], flame_scale=1.0, light_mult=1.0, offhand=True, offhand_front=False,
                 weapon_rest_deg=55, candle_base=[63.6, 22.6], portrait_viewbox=[18, -2, 95, 95],
                 weapon_tip=[64, 38.2])),               # the spade blade's point
}


PORTRAIT_FLAME_H = 0.25    # the portrait flame's height, as a share of the crop's width (0.5 r in the circle)


def rig_json(cls):
    """rig.json: the rig's numbers, plus where the portrait's live flame goes.
    portrait_flame is [x, y, h] in portrait units measured from the crop's
    corner (flame_tip minus portrait_viewbox's x and y; h scaled by
    flame_scale), so the dialogue draws its flame at
        c + (portrait_flame.xy / viewbox_w - 0.5) * 2r,  height h * 2r / viewbox_w
    and portrait_flame_uv is the same point as a fraction of the square
    portrait (c + (uv - 0.5) * 2r). weapon_tip is the weapon's business end
    in its own upright 128 frame (wick_rig.weapon_point())."""
    r = dict(CALLING[cls]['rig'])
    vx, vy, vw, vh = r['portrait_viewbox']
    fx, fy = r['flame_tip']
    fh = PORTRAIT_FLAME_H * vw * r['flame_scale']
    r['portrait_flame'] = [round(fx - vx, 2), round(fy - vy, 2), round(fh, 2)]
    r['portrait_flame_uv'] = [round((fx - vx) / float(vw), 4), round((fy - vy) / float(vh), 4)]
    return json.dumps(r, indent=1, sort_keys=True) + '\n'


def portrait_svg(cls, mood):
    """Head, candle and shoulders, cropped close by the calling's viewBox."""
    C = CALLING[cls]
    ctx = Ctx('pt%s%s' % (cls[:2], mood[:2]))
    cape = C['cape'] or wick.cape_art
    parts = [cape(ctx), C['arm'](ctx, False), C['body'](ctx), C['head'](ctx, mood), C['candle'](ctx)]
    body = ''.join(parts)
    vx, vy, vw, vh = C['rig']['portrait_viewbox']
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="%s %s %s %s">\n'
            '<defs>%s</defs>\n%s\n</svg>\n') % (PORTRAIT_PX, PORTRAIT_PX, vx, vy, vw, vh, ''.join(ctx.defs), body)


def calling_files(cls):
    C = CALLING[cls]
    base = 'art/heroes/%s/' % cls
    out = {}
    if cls == 'knight':
        # Waxby's parts are wick.py's own, the sword renamed weapon
        out[base + 'cape.svg'] = wick.cape_svg()
        out[base + 'leg_back.svg'] = wick.leg_svg(False)
        out[base + 'leg_front.svg'] = wick.leg_svg(True)
        out[base + 'body.svg'] = wick.body_svg()
        out[base + 'arm_back.svg'] = wick.arm_svg(False)
        out[base + 'arm_front.svg'] = wick.arm_svg(True)
        out[base + 'candle.svg'] = wick.candle_svg()
        out[base + 'weapon.svg'] = wick.sword_svg()
        for name, mood in MOODS:
            out[base + name + '.svg'] = wick.head_svg(mood)
    else:
        k = cls[:2]
        out[base + 'cape.svg'] = svg_of('%sk' % k, C['cape'])
        out[base + 'leg_back.svg'] = svg_of('%slb' % k, C['leg'], False)
        out[base + 'leg_front.svg'] = svg_of('%slf' % k, C['leg'], True)
        out[base + 'body.svg'] = svg_of('%sb' % k, C['body'])
        out[base + 'arm_back.svg'] = svg_of('%sab' % k, C['arm'], False)
        out[base + 'arm_front.svg'] = svg_of('%saf' % k, C['arm'], True)
        out[base + 'candle.svg'] = svg_of('%sc' % k, C['candle'])
        out[base + 'weapon.svg'] = svg_of('%sw' % k, C['weapon'])
        for name, mood in MOODS:
            out[base + name + '.svg'] = svg_of('%sh%s' % (k, mood[:2]), C['head'], mood)
    if C['offhand']:
        out[base + 'offhand.svg'] = svg_of('%so' % cls[:2], C['offhand'])
    for name, mood in PORTRAITS:
        out[base + 'portrait_%s.svg' % name] = portrait_svg(cls, mood)
    out[base + 'rig.json'] = rig_json(cls)
    return out


# ================================================================ cape trims (v3, P2)
# art/heroes/<cls>/cape_trim_<pattern>.svg: a hem band for the rig's
# cape_trim part, a sibling drawn over the cape with the cape's pivot and
# turn, coloured by modulate (never by the coat's rarity). White fill and a
# 1-unit ink line, so any colour of the nine takes. Each runs along the hem
# and up the cape's outer edge (the part of a cape that shows behind the
# body), its colour carried out over the inner half of the cape's own ink
# outline; its band is clipped to the cape's outline, and its bells, flames,
# lace and corner drop hang out past it. The five patterns, each one calling's
# four Trial Golds (spec 7.5):
#   band     Heraldic Band   (Candleknight): a broad band set with lozenges, a tassel at the corner
#   tongues  Flame Hem       (Taperwitch):   flames rising off the hem and licking back off the edge
#   stitch   Soot Stitch     (Sootrunner):   a hem line, a row of cross-stitches, a knotted end
#   bells    Bell Hem        (Bellfounder):  up to five little bells hung straight down, the tenor at the corner
#   scallop  Shroud Scallop  (Sexton):       lace scallops standing out past the edge, pierced, a lace drop

TRIMS = ['band', 'tongues', 'stitch', 'bells', 'scallop']
TRIM_INK = '#1c1830'
TRIM_WHITE = '#ffffff'
# wick.py's cape_art outline (Waxby's v1 cape; test_art checks the trims sit on it)
K_CAPE_D = ('M62 81.4 C56 81.4 51 83 48.4 86.6 C45 91.6 42.4 100 40 110.4 L44.2 108.4 L45.4 113.6 L49.4 109.6 '
            'L52.4 114.4 L55.4 109.8 L59.6 113 L62.6 104 Z')


def cape_outline(cls):
    """The calling's cape outline, as its cape function draws it."""
    if cls == 'knight':
        return K_CAPE_D
    if cls == 'witch':
        hem = W_CAPE_HEM
        return ('M62 81.4 C55.6 81 50.4 82.8 47.4 86.6 C43.6 91.4 40.4 98.6 %.1f %.1f ' % hem[0]
                + ' '.join('L%.1f %.1f' % p for p in hem[1:]) + ' L62.8 94 Z')
    if cls == 'runner':
        return ('M64.4 80.6 C58 80.2 52.6 81.6 48 84.4 C43.6 87 38.4 90.4 ' + R_WING_EDGE[1:]
                + ' C51.8 106.6 53.8 102.8 56.6 99.4 C58.8 96.6 61.4 94.4 64.6 93.2 Z')
    if cls == 'founder':
        hem = F_CAPE_HEM
        return ('M62 81 C55 80.8 50 82.4 47.4 85.8 C44.2 89.8 41 96.4 %.1f %.1f ' % hem[0]
                + ' '.join('L%.1f %.1f' % p for p in hem[1:]) + ' L62.6 90 Z')
    return X_CAPE_D


def flatten(d, step=0.8):
    """Points along an absolute M/L/Q/C path (no Z), about step apart."""
    toks = d.replace(',', ' ').split()
    pts = []
    i = 0
    cur = (0.0, 0.0)
    cmd = 'M'
    while i < len(toks):
        if toks[i][0].isalpha():
            cmd = toks[i][0]
            rest = toks[i][1:]
            if rest:
                toks[i] = rest
            else:
                i += 1
        n = {'M': 2, 'L': 2, 'Q': 4, 'C': 6}[cmd]
        v = [float(x) for x in toks[i:i + n]]
        i += n
        if cmd in 'ML':
            p = (v[0], v[1])
            if cmd == 'L' and pts:
                ln = math.hypot(p[0] - cur[0], p[1] - cur[1])
                k = max(1, int(ln / step))
                pts += [(cur[0] + (p[0] - cur[0]) * j / k, cur[1] + (p[1] - cur[1]) * j / k) for j in range(1, k + 1)]
            else:
                pts.append(p)
            cur = p
        else:
            ctrl = [cur] + [(v[j], v[j + 1]) for j in range(0, n, 2)]
            k = 16
            for j in range(1, k + 1):
                t = j / float(k)
                if cmd == 'Q':
                    a, b, c = ctrl
                    x = (1 - t) ** 2 * a[0] + 2 * (1 - t) * t * b[0] + t * t * c[0]
                    y = (1 - t) ** 2 * a[1] + 2 * (1 - t) * t * b[1] + t * t * c[1]
                else:
                    a, b, c, e = ctrl
                    x = (1 - t) ** 3 * a[0] + 3 * (1 - t) ** 2 * t * b[0] + 3 * (1 - t) * t * t * c[0] + t ** 3 * e[0]
                    y = (1 - t) ** 3 * a[1] + 3 * (1 - t) ** 2 * t * b[1] + 3 * (1 - t) * t * t * c[1] + t ** 3 * e[1]
                pts.append((x, y))
            cur = ctrl[-1]
    return pts


def edge_below(d, y0):
    """An outer-edge curve (drawn downward) from where it crosses y0 down."""
    pts = flatten(d)
    out = []
    for a, b in zip(pts, pts[1:]):
        if a[1] < y0 <= b[1]:
            t = (y0 - a[1]) / (b[1] - a[1])
            out.append((a[0] + (b[0] - a[0]) * t, y0))
        if b[1] >= y0:
            out.append(b)
    return out


# Each calling's trim path, as (edge, hem, ref): the cape's outer edge (the
# back one, away from the body) from where it comes into view with the cape
# flared, down to the hem's back corner, then the hem to the front; ref is a
# point inside the cape the band grows toward. Behind the body only a cape's
# back corner and outer edge ever show (Waxby's shield, the founder's braids
# and the sexton's coat cover the rest of the hem, and the witch's hair the
# top of her capelet), so every trim runs up that edge as well as along the
# hem, and the bells, flames and lace hang out past it.
K_HEM = [(40, 110.4), (44.2, 108.4), (45.4, 113.6), (49.4, 109.6), (52.4, 114.4), (55.4, 109.8), (59.6, 113), (61.4, 107.6)]
TRIM_PATHS = {
    'knight': [(edge_below('M48.4 86.6 C45 91.6 42.4 100 40 110.4', 90), K_HEM, (52, 96))],
    'witch': [(edge_below('M47.4 86.6 C43.6 91.4 40.4 98.6 38.4 107.2', 93), W_CAPE_HEM, (53, 92))],
    'runner': [([], flatten(R_WING_EDGE), (50, 94))],
    'founder': [(edge_below('M47.4 85.8 C44.2 89.8 41 96.4 38.8 104.6', 97), F_CAPE_HEM, (52, 90))],
    'sexton': [(edge_below('M50 89 C47.4 95 46 104 45.4 116.8', 95), [(45.4, 116.8), (49.8, 113.4), (52.6, 118.2), (54, 110)],
                (50.6, 106)),
               ([], [(59.2, 107.6), (60.4, 117.6), (62.8, 113.8)], (61.4, 106))],
}
EDGE_OUT = 1.0     # a trim's colour reaches this far past the cape's edge, over the inner half of its ink outline
# The cape's back corner (where the outer edge meets the hem) is the one bit
# of every cape in sight in every pose, even at rest behind Waxby's shield or
# the founder's braids; each trim hangs something there: a tassel, a flame, a
# knotted cord, the biggest bell, a lace drop. (Not the runner, whose whole
# wing shows, nor the sexton, whose coat tails already reach his heels.)
CORNER_DROP = {'knight', 'witch', 'founder'}


def trim_path(edge, hem):
    """The edge and the hem as one polyline (they meet at the back corner)."""
    return edge[:-1] + hem if edge else list(hem)


def poly_d(pts):
    return 'M' + ' L'.join('%.2f %.2f' % p for p in pts)


def along(pts, step, ref, start=None):
    """(point, tangent, inward normal) every step along a polyline."""
    segs = []
    total = 0.0
    for a, b in zip(pts, pts[1:]):
        ln = math.hypot(b[0] - a[0], b[1] - a[1])
        if ln > 1e-6:
            segs.append((a, b, ln))
            total += ln
    out = []
    s = step * 0.5 if start is None else start
    while s < total:
        acc = 0.0
        for a, b, ln in segs:
            if acc + ln >= s:
                t = (s - acc) / ln
                p = (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
                tx, ty = (b[0] - a[0]) / ln, (b[1] - a[1]) / ln
                nx, ny = -ty, tx
                if (ref[0] - p[0]) * nx + (ref[1] - p[1]) * ny < 0:
                    nx, ny = -nx, -ny
                out.append((p, (tx, ty), (nx, ny)))
                break
            acc += ln
        s += step
    return out


def hem_band(pts, w, ink=1.0):
    """A band w wide inside the hem (once clipped to the cape) with an ink
    line on its inner side: the hem stroked twice as wide, ink under white."""
    d = poly_d(pts)
    return (line(d, TRIM_INK, 2 * (w + ink), cap='round') + line(d, TRIM_WHITE, 2 * w, cap='round'))


BELL_W = 3.2       # a hem bell's lip, in frame units
BELL_GAP = 1.0     # at least this much air between two bells


def hem_bells(hem, w=BELL_W, most=5, x_from=None):
    """Bells hung straight down from the hem, as many as fit (up to most)
    with BELL_GAP between them, spread evenly from end to end (or from
    x_from on): the (x, y) of each hanger, on the hem's lowest point there."""
    xs = [p[0] for p in hem]
    x0, x1 = min(xs) + w * 0.5 + 0.4, max(xs) - w * 0.5 - 0.4
    if x_from is not None:
        x0 = max(x0, x_from + w * 0.5)
    n = max(1, min(most, 1 + int((x1 - x0) / (w + BELL_GAP))))
    out = []
    for i in range(n):
        x = (x0 + x1) * 0.5 if n == 1 else x0 + (x1 - x0) * i / float(n - 1)
        ys = []
        for a, b in zip(hem, hem[1:]):
            lo, hi = min(a[0], b[0]), max(a[0], b[0])
            if lo <= x <= hi and hi - lo > 1e-6:
                t = (x - a[0]) / (b[0] - a[0])
                ys.append(a[1] + (b[1] - a[1]) * t)
        out.append((x, max(ys) if ys else hem[0][1]))
    return out


def bell_d(x, y, w=BELL_W, h=4.0):
    """A little bell hung from (x, y): a round crown flaring to a lip, h tall."""
    a = w / 2.0
    return ('M%.2f %.2f C%.2f %.2f %.2f %.2f %.2f %.2f C%.2f %.2f %.2f %.2f %.2f %.2f L%.2f %.2f '
            'C%.2f %.2f %.2f %.2f %.2f %.2f C%.2f %.2f %.2f %.2f %.2f %.2f Z') % (
        x, y, x + a * 0.66, y, x + a * 0.74, y + h * 0.3, x + a * 0.74, y + h * 0.55,
        x + a * 0.74, y + h * 0.78, x + a * 0.88, y + h * 0.9, x + a, y + h, x - a, y + h,
        x - a * 0.88, y + h * 0.9, x - a * 0.74, y + h * 0.78, x - a * 0.74, y + h * 0.55,
        x - a * 0.74, y + h * 0.3, x - a * 0.66, y, x, y)


def edging(pts):
    """The trim's colour carried EDGE_OUT past the cape's edge (drawn under
    the band, unclipped): the colour runs right out to the cape's outline."""
    return line(poly_d(pts), TRIM_WHITE, 2 * EDGE_OUT)


def flame_at(x, y, ang, w=3.4, h=5.8, lean=0.0):
    d = flame_d_local(w, h) if lean == 0.0 else flame_d_lean(w, h, lean)
    return ('<path d="%s" transform="translate(%.2f %.2f) rotate(%.1f)" fill="%s" stroke="%s" stroke-width="0.8" '
            'stroke-linejoin="round"/>') % (d, x, y, ang, TRIM_WHITE, TRIM_INK)


def cord(x, y0, y1, w=0.9):
    """A cord hung from (x, y0) to (x, y1): white, inked either side."""
    d = 'M%.2f %.2f L%.2f %.2f' % (x, y0, x, y1)
    return line(d, TRIM_INK, w + 1.4) + line(d, TRIM_WHITE, w)


def knob(x, y, r):
    return '<circle cx="%.2f" cy="%.2f" r="%.2f" fill="%s" stroke="%s" stroke-width="0.8"/>' % (x, y, r, TRIM_WHITE, TRIM_INK)


def tassel(x, y):
    """A heraldic tassel hung from (x, y): cord, knob and a fringed skirt."""
    skirt = 'M%.2f %.2f L%.2f %.2f L%.2f %.2f Q%.2f %.2f %.2f %.2f Z' % (
        x - 1.3, y + 3.9, x + 1.3, y + 3.9, x + 2.1, y + 8.6, x, y + 9.5, x - 2.1, y + 8.6)
    return (cord(x, y - 0.6, y + 2.6) + knob(x, y + 3.0, 1.35)
            + '<path d="%s" fill="%s" stroke="%s" stroke-width="0.8" stroke-linejoin="round"/>' % (skirt, TRIM_WHITE, TRIM_INK)
            + line('M%.2f %.2f L%.2f %.2f M%.2f %.2f L%.2f %.2f' % (x - 0.6, y + 5, x - 0.9, y + 8.4, x + 0.6, y + 5, x + 0.9, y + 8.4),
                   TRIM_INK, 0.6))


def knotted_cord(x, y):
    """A loose end of the stitching's thread, two knots and a bead on it."""
    return cord(x, y - 0.6, y + 6.6, 1.1) + knob(x, y + 2.6, 1.0) + knob(x, y + 5.0, 1.0) + knob(x, y + 7.6, 1.6)


def lace_drop(x, y):
    """A lace pendant: a teardrop hung from (x, y), pierced with an eyelet."""
    d = 'M%.2f %.2f C%.2f %.2f %.2f %.2f %.2f %.2f C%.2f %.2f %.2f %.2f %.2f %.2f Z' % (
        x, y, x + 1.2, y + 2.2, x + 2.6, y + 3.8, x, y + 7.4, x - 2.6, y + 3.8, x - 1.2, y + 2.2, x, y)
    return ('<path d="%s" fill="%s" stroke="%s" stroke-width="0.9" stroke-linejoin="round"/>' % (d, TRIM_WHITE, TRIM_INK)
            + dot(x, y + 4.5, 0.8, TRIM_INK) + knob(x, y + 8.4, 0.9))


def trim_body(cls, pattern):
    """The trim's drawing, as (under, inside, over): inside is clipped to the
    cape's outline; under (beneath it) and over are not."""
    under, inside, over = '', '', ''
    for edge, hem, ref in TRIM_PATHS[cls]:
        pts = trim_path(edge, hem)
        if pattern == 'band':
            under += edging(pts)
            inside += hem_band(pts, 4.4)
            for p, t, n in along(pts, 4.4, ref):
                cx, cy = p[0] + n[0] * 2.2, p[1] + n[1] * 2.2
                q = [(cx + t[0] * 1.5, cy + t[1] * 1.5), (cx + n[0] * 1.1, cy + n[1] * 1.1),
                     (cx - t[0] * 1.5, cy - t[1] * 1.5), (cx - n[0] * 1.1, cy - n[1] * 1.1)]
                inside += '<path d="%s Z" fill="%s"/>' % (poly_d(q), TRIM_INK)
            if edge and cls in CORNER_DROP:
                over += tassel(edge[-1][0] + 0.4, edge[-1][1])
        elif pattern == 'tongues':
            under += edging(pts)
            inside += hem_band(pts, 1.5)
            for p, t, n in along(hem, 3.6, ref):
                # along the hem every tongue rises into the cape, however the
                # dagged hem zigzags under it
                up = unit(ref[0] - p[0], ref[1] - p[1])
                inside += flame_at(p[0], p[1], math.degrees(math.atan2(up[0], -up[1])))
            for p, t, n in along(edge, 3.8, ref):
                # up the outer edge they lick out behind it, rising (so they
                # stream up off the cape as it flares)
                d = unit(-n[0] * 0.6, -n[1] * 0.6 - 1.0)
                bx, by = p[0] + n[0] * 0.9, p[1] + n[1] * 0.9
                over += flame_at(bx, by, math.degrees(math.atan2(d[0], -d[1])), 3.4, 6.2, -1.3)
            if edge and cls in CORNER_DROP:
                # the biggest tongue licks back off the corner
                c = edge[-1]
                over += flame_at(c[0] + 0.9, c[1] - 0.6, -38.0, 4.4, 8.6, -2.0)
        elif pattern == 'stitch':
            under += edging(pts)
            inside += hem_band(pts, 1.1)
            for p, t, n in along(pts, 3.0, ref):
                cx, cy = p[0] + n[0] * 3.4, p[1] + n[1] * 3.4
                a = ((t[0] + n[0]) * 1.1, (t[1] + n[1]) * 1.1)
                b = ((t[0] - n[0]) * 1.1, (t[1] - n[1]) * 1.1)
                d = 'M%.2f %.2f L%.2f %.2f M%.2f %.2f L%.2f %.2f' % (cx - a[0], cy - a[1], cx + a[0], cy + a[1],
                                                                      cx - b[0], cy - b[1], cx + b[0], cy + b[1])
                inside += line(d, TRIM_INK, 3.0) + line(d, TRIM_WHITE, 1.4)
            if edge and cls in CORNER_DROP:
                over += knotted_cord(edge[-1][0] + 0.4, edge[-1][1])
        elif pattern == 'bells':
            under += edging(pts)
            inside += hem_band(pts, 1.7)
            bells = []
            x_from = None
            if edge and cls in CORNER_DROP:
                # the tenor: the biggest bell, on a longer loop from the corner
                c = edge[-1]
                bells.append((c[0] + 0.3, c[1], 4.2, 5.0, 2.2))
                x_from = c[0] + 0.3 + 2.1 + BELL_GAP
            for x, y in hem_bells(hem, most=5 - len(bells), x_from=x_from):
                bells.append((x, y, BELL_W, 4.0, 0.8))
            for x, y, w, h, loop in bells:
                # hung straight down (in the cape's own frame) on a short
                # loop from the hem, the clapper just under the lip
                over += ('<path d="M%.2f %.2f L%.2f %.2f" stroke="%s" stroke-width="1.5" stroke-linecap="round"/>'
                         '<path d="%s" fill="%s" stroke="%s" stroke-width="0.9" stroke-linejoin="round"/>'
                         '<circle cx="%.2f" cy="%.2f" r="%.2f" fill="%s"/>') % (
                    x, y - 1.4, x, y + loop, TRIM_INK, bell_d(x, y + loop - 0.3, w, h), TRIM_WHITE, TRIM_INK,
                    x, y + loop - 0.3 + h + 0.55, 0.6 + w * 0.05, TRIM_INK)
        else:   # scallop
            # lace: a row of scallops standing out past the edge, a band
            # inside it, and each scallop pierced with an eyelet
            for p, t, n in along(pts, 3.4, ref):
                under += '<circle cx="%.2f" cy="%.2f" r="1.9" fill="%s" stroke="%s" stroke-width="1"/>' % (
                    p[0] - n[0] * 0.3, p[1] - n[1] * 0.3, TRIM_WHITE, TRIM_INK)
            inside += hem_band(pts, 2.6)
            for p, t, n in along(pts, 3.4, ref):
                over += dot(p[0] - n[0] * 0.3, p[1] - n[1] * 0.3, 0.6, TRIM_INK)
            for p, t, n in along(pts, 3.4, ref, start=0.0):
                inside += dot(p[0] + n[0] * 1.7, p[1] + n[1] * 1.7, 0.45, TRIM_INK)
            if edge and cls in CORNER_DROP:
                over += lace_drop(edge[-1][0] - 0.2, edge[-1][1] + 1.2)
    return under, inside, over


def unit(x, y):
    ln = math.hypot(x, y) or 1.0
    return x / ln, y / ln


def flame_d_local(w, h):
    """A small flame standing on the origin, its tip h above (up is -y)."""
    a = w / 2.0
    return ('M0 %.2f C%.2f %.2f %.2f %.2f %.2f %.2f C%.2f %.2f %.2f 0 0 0 C%.2f 0 %.2f %.2f %.2f %.2f '
            'C%.2f %.2f %.2f %.2f 0 %.2f Z') % (
        -h, a * 0.3, -h * 0.7, a, -h * 0.5, a, -h * 0.22, a, -h * 0.06, a * 0.5, -a * 0.5, -a, -h * 0.06, -a, -h * 0.22,
        -a, -h * 0.5, -a * 0.3, -h * 0.7, -h)


def flame_d_lean(w, h, lean):
    """flame_d_local with its tip flicked lean to the side (a licking flame)."""
    a = w / 2.0
    return ('M%.2f %.2f C%.2f %.2f %.2f %.2f %.2f %.2f C%.2f %.2f %.2f 0 0 0 C%.2f 0 %.2f %.2f %.2f %.2f '
            'C%.2f %.2f %.2f %.2f %.2f %.2f Z') % (
        lean, -h, a * 0.3 + lean * 0.7, -h * 0.72, a, -h * 0.5, a, -h * 0.22, a, -h * 0.06, a * 0.5, -a * 0.5, -a, -h * 0.06,
        -a, -h * 0.22, -a, -h * 0.55, -a * 0.3 + lean * 0.9, -h * 0.8, lean, -h)


def cape_trim_svg(cls, pattern):
    ctx = Ctx('ct%s%s' % (cls[:2], pattern[:2]))
    under, inside, over = trim_body(cls, pattern)
    clip = ctx.clip('<path d="%s"/>' % cape_outline(cls))
    return svg128(ctx, '%s<g clip-path="%s">%s</g>%s' % (under, clip, inside, over))


def trim_files():
    return {'art/heroes/%s/cape_trim_%s.svg' % (cls, pat): cape_trim_svg(cls, pat) for cls in CALLINGS for pat in TRIMS}


def files():
    out = {}
    for cls in CALLINGS:
        out.update(calling_files(cls))
    out.update(trim_files())
    return out


if __name__ == '__main__':
    import build
    for rel, text in files().items():
        build.write(rel, text)
    print('wrote %d hero files' % len(files()))
