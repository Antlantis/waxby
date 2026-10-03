"""The deeper worlds' story figures (v3, A5), in the v2 figures' frame and
style (story_figs.py): a 256 x 256 frame, feet at (128, 244) unless noted,
facing right, px 4, drawn in native units (twice WICK's) and fitted at
scale s, so every figure's lines come out the same weight on screen. The
engine draws the flames: each figure lists its flame points (frame units)
and how each lights the panel; a light may carry "off": true.

P0: hush_grasp, rootmother_boss, yarrow_spirit, tinker_boss, tickwell,
    cone_bell, saint_boss, tessel_lit, stolen_wick, hollin_carry
P1: rootmother_open, tollgrave_stand, townsfolk_line, deep_candle
P2: lost_wicks
The bosses are drawn in story_rootmother.py, story_tinker.py and
story_saint.py. EXTEND adds the `pupil` light (off) to v2's hush_eye.
"""
import math

import kit
from kit import Part, pth
from common import Ctx, RIM, WAX, line, dot, flame_d, spec, gx
from story_sets import INK
from story_kit import (NATIVE_W, weights, P, E, LIMB, fig_doc, rect_d, ell_d, poly_d, radial, candle, fit,
                       smoke_curl, shade_of, Rand)
from story_figs import Fig, shadow, clipped, render


def frame_render(ctx, parts, line_col, h, rim=RIM, base='#808080'):
    """Parts drawn straight in frame units for a figure whose frame covers h
    panel units, at the line weight every figure has on screen (a native
    drawing at s = 120 / h, fitted, comes out the same)."""
    k = 120.0 / h
    with weights(tuple(w * k for w in NATIVE_W)):
        return kit.render_parts(ctx, parts, dict(line=line_col, rim=rim, base=base, shade=shade_of(base)))


# ================================================================ the Hush's grasp (the_pull)

HUSH_INK, HUSH_INK_SH, HUSH_RIM, HUSH_EDGE, HUSH_PALE = '#0a0812', '#050409', '#4a3a7a', '#9a90c8', '#d8d4f0'


def smoke_hand(cx, cy, ang, k, curl=0.6, spread=1.0, fingers=4, reach=1.0):
    """One of the Hush's hands: a palm at (cx, cy) turned ang degrees (0 is
    fingers up), long smoke fingers curling curl (0 splayed, 1 closed) and
    pale fingertips. Frame units at scale k. Returns (parts, tips)."""
    a = math.radians(ang)
    ca, sa = math.cos(a), math.sin(a)

    def R(x, y):
        return (cx + (x * ca - y * sa) * k, cy + (x * sa + y * ca) * k)

    parts, tips = [], []
    w = 7.2 * k
    for i in range(fingers):
        t = (i - (fingers - 1) / 2.0) / max(1.0, (fingers - 1) / 2.0)
        bx, by = t * 13 * spread, -12 + abs(t) * 3
        L = (40 - abs(t) * 8) * reach
        # each finger bends in toward the palm's middle as it curls
        mx, my = bx + t * 6 * spread, by - L * 0.55
        ex, ey = bx * (1 - curl) + t * 10 * (1 - curl) * spread - t * 4 * curl, by - L * (1 - 0.25 * curl)
        ex += -t * curl * 12
        p0, p1, p2 = R(bx, by), R(mx, my), R(ex, ey)
        d = 'M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (p0 + p1 + p2)
        parts.append(Part('limb', pth(d), fill=HUSH_INK, width=w * (1 - abs(t) * 0.12),
                          over=line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (R(bx - 2.4, by - 4) + R(mx - 2.6, my) + R(ex - 1.4, ey + 3)),
                                    HUSH_RIM, 1.4 * k, op=0.9)))
        tips.append(p2)
    # the thumb, low on the side, hooking in
    t0, t1, t2 = R(-17 * spread, 2), R(-27 * spread, -14), R(-16 * spread + 8 * curl, -26)
    parts.append(Part('limb', pth('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (t0 + t1 + t2)), fill=HUSH_INK, width=w * 1.05))
    tips.append(t2)
    palm = 'M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z' % (
        R(-18, -10) + R(-22, 8) + R(-12, 22) + R(0, 22) + R(12, 22) + R(22, 8) + R(18, -10) + R(8, -18) + R(-8, -18) + R(-18, -10))
    parts.append(Part('fill', pth(palm), fill=HUSH_INK, shade=HUSH_INK_SH, off=(-2 * k, -2 * k),
                      over=line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (R(-14, -8) + R(-18, 8) + R(-8, 18)), HUSH_RIM, 1.6 * k, op=0.9)))
    return parts, tips


def fingertips(tips, k, op=0.95):
    """The pale fingertips, drawn over everything."""
    return ''.join(dot(x, y, 2.6 * k, HUSH_EDGE, op) + dot(x - 0.6 * k, y - 0.6 * k, 1.3 * k, HUSH_PALE, op) for x, y in tips)


def hush_grasp():
    """A mass of black smoke-like hands rising out of the bottom of the frame,
    the biggest closing round a flame at the top: ink with violet rims and
    pale fingertips (the fight's Hands), no face. Its feet (the pivot) are
    at (128, 200), under the undercandle's floor ring; the grip is the
    stolen light (off until the flame passes into it)."""
    H = 640.0
    f = Fig('hush_grasp', 1.0, feet=(128.0, 200.0), h=H)
    ctx = Ctx('fhg')
    rng = Rand(6406)
    parts = []
    tips = []
    # the smoke column: a wavering trunk of ink from the bottom up to the wrist
    col = ('M92 262 C96 234 106 216 108 192 C110 168 102 150 108 128 C112 112 118 102 118 88 L138 88 C138 102 144 114 148 130 '
           'C154 152 146 170 148 194 C150 218 160 236 164 262 Z')
    swirl = (line('M100 250 C104 226 112 210 113 188 C114 166 108 148 113 128', HUSH_RIM, 1.4, op=0.8)
             + line('M156 252 C152 230 144 214 143 192', HUSH_EDGE, 1.0, op=0.5))
    parts.append(Part('fill', pth(col), fill=HUSH_INK, shade=HUSH_INK_SH, off=(-3, -2), over=swirl))
    # two smaller hands reaching up from the smoke, and fingers poking out low
    for (x, y, ang, k, curl) in ((70, 150, -34, 0.78, 0.25), (190, 168, 30, 0.7, 0.35), (58, 222, -58, 0.55, 0.1),
                                 (204, 226, 52, 0.55, 0.15)):
        arm = 'M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (128 + (x - 128) * 0.12, y + 46, (x + 128) / 2.0, y + 26, x, y + 10)
        parts.append(Part('limb', pth(arm), fill=HUSH_INK, width=16 * k))
        hp, ht = smoke_hand(x, y, ang, k, curl=curl, spread=1.2)
        parts += hp
        tips += ht
    G = 8
    # the grasping hand: the palm under the flame, long fingers bowing out
    # round it and hooking in over it, a cage with gaps the flame shows through
    parts.append(Part('fill', pth('M104 96 C100 82 106 66 118 60 L138 60 C150 66 156 82 152 96 C146 104 110 104 104 96 Z', move=(0, G)),
                      fill=HUSH_INK, shade=HUSH_INK_SH, off=(-2, -2),
                      over=gx(line('M108 92 C106 82 110 72 118 66', HUSH_RIM, 1.8, op=0.9), 'translate(0 %d)' % G)))
    for (b, c1, c2, t, w) in (((108, 70), (80, 52), (94, 8), (116, 4), 8.4), ((118, 64), (100, 36), (108, 2), (124, -1), 7.6),
                              ((140, 64), (158, 36), (150, 2), (133, -1), 7.6), ((148, 70), (176, 52), (164, 10), (141, 5), 8.4)):
        b, c1, c2, t = [(q[0], q[1] + G) for q in (b, c1, c2, t)]
        d = 'M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f' % (b + c1 + c2 + t)
        rim_d = 'M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f' % (b[0] - 2, b[1], c1[0] - 3, c1[1], c2[0] - 2, c2[1], t[0], t[1] + 2)
        parts.append(Part('limb', pth(d), fill=HUSH_INK, width=w, over=line(rim_d, HUSH_RIM, 1.5, op=0.9)))
        tips.append(t)
    # the thumb hooks up across the front, under the flame
    parts.append(Part('limb', pth('M150 88 C170 80 166 50 146 40', move=(0, G)), fill=HUSH_INK, width=8.8,
                      over=gx(line('M152 84 C166 76 162 52 148 44', HUSH_RIM, 1.4, op=0.8), 'translate(0 %d)' % G)))
    tips.append((146, 40 + G))
    # curls of smoke peeling off the column
    wisps = ''
    for i in range(9):
        x = rng.u(80, 176)
        y = rng.u(96, 250)
        lean = 1 if x > 128 else -1
        d = 'M%.1f %.1f c%.1f %.1f %.1f %.1f %.1f %.1f' % (x, y, lean * 10, -6, lean * 16, -16, lean * 10, -26)
        wisps += line(d, HUSH_INK, 5, op=0.85) + line(d, HUSH_RIM, 1.2, op=0.7)
    body = wisps + frame_render(ctx, parts, HUSH_RIM, H, rim=HUSH_EDGE, base=HUSH_INK) + fingertips(tips, 1.0)
    f.set_flame('stolen', 128, 30, 16, dict(kind='flame', color='ffd070', r=300, s=1.0, off=True))
    return f, fig_doc(ctx, body)


# ================================================================ Mother Gravebough (boss_3)

# The bosses stand in the story as they fight (story_snuffer's FIG_H: the fight's
# size beside Waxby) where their panel has the headroom; in the Heartwood and
# the Escapement at 0.85 of it, so Gravebough's crown and the Tinker's lamp-lens
# eyes clear the letterbox through their scenes' cameras.
def boss_h(who):
    import story_rootmother as RM
    return RM.FIG_H * (1.0 if who == 'saint' else 0.85)


def rootmother(pose):
    """Mother Gravebough, about 3.5 x Waxby, as she fights (story_rootmother:
    boss3.py's parts): keeping (the fight's idle, the ember caged cold in her
    chest, eyes nearly shut) or open (P1: she lets go, as in her last fight
    frame: the cage empty, her heart a warm bloom in her crown, her eyes open
    and soft)."""
    import story_rootmother as RM
    fid = 'rootmother_boss' if pose == 'keep' else 'rootmother_open'
    f = Fig(fid, 1.0, h=boss_h('rootmother'))
    ctx = Ctx('frm' + pose[:2])
    art = RM.figure(pose)
    ctx.defs.append(art['defs'])
    body = shadow(128, 104, op=0.35) + art['body']
    (ax, ay), (bx, by) = art['eyes']
    eyes = dict(kind='eyes', color=RM.EYES_KEEP if pose == 'keep' else RM.EYES_OPEN, pts=[[ax, ay], [bx, by]], dot=1.7,
                r=90, s=0.6)
    f.set_flame('eyes', (ax + bx) / 2, (ay + by) / 2, 0, eyes)
    ex, ey = art['ember']
    if pose == 'keep':
        f.set_flame('ember', ex, ey, 14, dict(kind='cold', color=RM.EMBER_COLD, r=90, s=0.8))
    else:
        f.set_flame('ember', ex, ey - 4, 12, dict(kind='flame', r=110, s=0.95))
    return f, fig_doc(ctx, body)


def rootmother_boss():
    return rootmother('keep')


def rootmother_open():
    return rootmother('open')


# ================================================================ Mother Yarrow's spirit (boss_3_after)

YARROW = dict(habit='#b8cc90', habit_sh='#94a870', apron='#eef0d0', apron_sh='#c8cca8', straw='#e4cc80', straw_sh='#b89c54',
              skin='#f4ecd0', skin_sh='#dcd0a8', line='#3e4c2a', blush='#f0a890', flower='#fffaf0', flower_sh='#d8d8c0',
              trowel='#c8d0d8', trowel_sh='#8a94a0', handle='#a88a58')
YFACE = dict(line=YARROW['line'], base=YARROW['skin'], iris0='#2a3418', iris1='#6a8a4a', iris2='#c8e0a0', blush=YARROW['blush'])


def yarrow_umbel(x, y, k=1.0):
    """A sprig of white yarrow: a flat cluster of tiny flowers on a stalk."""
    Y = YARROW
    parts = [LIMB('M%.1f %.1f L%.1f %.1f' % (x, y + 10 * k, x, y), '#8aa060', 1.6 * k)]
    parts.append(E(x, y, 9 * k, 5 * k, Y['flower'], Y['flower_sh'], off=(-1, -1),
                   over=''.join(dot(x + dx * k, y - 1 * k + abs(dx) * 0.2 * k, 1.5 * k, '#ffffff') for dx in (-5, -2.5, 0, 2.5, 5))))
    return parts


def yarrow_face(ctx, cx, cy, k=1.0, mood='gentle'):
    """Yarrow's round old face: kind crinkled eyes, apple cheeks, laugh lines
    and a big smile (merry: laughing, eyes creased shut)."""
    Y = YARROW
    s = ''
    ex1, ex2, ey = cx - 9 * k, cx + 13 * k, cy
    s += kit.blush(ex1 - 4 * k, cy + 11 * k, YFACE, 7 * k, 4 * k, lines=False, op=0.7)
    s += kit.blush(ex2 + 4 * k, cy + 10 * k, YFACE, 5.4 * k, 3.6 * k, lines=False, op=0.7)
    for x, w in ((ex1, 9), (ex2, 8)):
        s += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (x - w / 2 * k, ey + 1.4 * k, x, ey - 4 * k, x + w / 2 * k, ey + 1.4 * k), Y['line'], 2.4 * k)
    # crow's feet and laugh lines
    s += line('M%.1f %.1f l%.1f %.1f M%.1f %.1f l%.1f %.1f' % (ex1 - 7 * k, ey - 1 * k, -3 * k, -2 * k, ex1 - 7 * k, ey + 2 * k, -3 * k, 1 * k),
              Y['line'], 1.0 * k, op=0.7)
    s += line('M%.1f %.1f l%.1f %.1f' % (ex2 + 7 * k, ey, 3 * k, -1.6 * k), Y['line'], 1.0 * k, op=0.7)
    s += '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s"/>' % (cx + 4 * k, cy + 7 * k, 3.2 * k, 2.6 * k, Y['skin_sh'])
    s += kit.mouth_open(cx + 3 * k, cy + 12 * k, (13 if mood == 'merry' else 10) * k, (8 if mood == 'merry' else 5.6) * k, YFACE)
    return s


def yarrow_spirit():
    """Mother Yarrow, Taper's teacher, come out of her grave: Wick-sized and
    round-cheeked like Taper, see-through (pale green-gold at 70%, a soft
    rim), a gardener's apron over her habit, a straw-brimmed hood with a
    sprig of white yarrow, a trowel in one hand, a big smile, and a stub
    candle on the hood (its flame off until she steps out)."""
    f = Fig('yarrow_spirit', 1.0)
    ctx = Ctx('fys')
    Y = YARROW
    parts = []
    # the habit, a wide bell to the ground (no feet: she floats a little)
    habit = 'M100 150 C88 180 78 214 72 238 Q98 246 128 242 Q158 246 184 238 C178 214 168 180 156 150 Z'
    parts.append(P(habit, Y['habit'], Y['habit_sh'], off=(-8, -3),
                   over=line('M94 196 Q90 216 88 236', Y['habit_sh'], 1.6, op=0.8)))
    # the apron with its pocket (a seed packet peeking out)
    apron = 'M108 164 L152 164 C156 190 160 214 162 236 Q130 242 100 236 C102 214 104 190 108 164 Z'
    pocket = ('<path d="M114 200 L136 200 L135 214 Q125 218 115 214 Z" fill="%s" stroke="%s" stroke-width="1.4"/>' % (Y['apron_sh'], Y['line'])
              + '<rect x="119" y="193" width="10" height="9" rx="1" fill="#e8a8a0" stroke="%s" stroke-width="1"/>' % Y['line'])
    parts.append(P(apron, Y['apron'], Y['apron_sh'], off=(-4, -2), over=pocket + line('M104 170 L156 170', Y['apron_sh'], 1.4)))
    # the back arm: a hand on the apron; the front arm holding up the trowel
    parts.append(P('M106 162 C98 172 96 186 100 196 L110 196 C110 186 112 176 116 170 Z', Y['habit'], Y['habit_sh'], off=(-2, -2)))
    parts.append(E(106, 199, 6.4, 6, Y['skin'], Y['skin_sh'], off=(-1, -1)))
    parts.append(P('M150 164 C162 164 172 158 178 148 L186 154 C180 168 166 176 154 178 Z', Y['habit'], Y['habit_sh'], off=(-2, -2)))
    parts.append(LIMB('M190 150 L187 168', Y['handle'], 5))
    parts.append(P('M183 146 C178 130 186 114 200 104 C206 118 205 134 196 148 Z', Y['trowel'], Y['trowel_sh'], off=(-1.4, -1.4),
                   over=line('M189 138 C188 128 192 118 198 112', '#f0f4f8', 1.4) + line('M191 146 L196 116', Y['trowel_sh'], 1.0)))
    parts.append(E(186, 152, 6.6, 6.2, Y['skin'], Y['skin_sh'], off=(-1, -1)))
    # the round head in its straw-brimmed hood
    hx, hy = 132, 118
    hood = ('M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f L%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f '
            'C%.1f %.1f %.1f %.1f %.1f %.1f Z') % (
        hx, hy - 44, hx + 30, hy - 44, hx + 46, hy - 22, hx + 46, hy + 4, hx + 46, hy + 26, hx + 34, hy + 40, hx + 18, hy + 44,
        hx - 22, hy + 44, hx - 38, hy + 40, hx - 46, hy + 26, hx - 46, hy + 4, hx - 46, hy - 22, hx - 30, hy - 44, hx, hy - 44)
    parts.append(P(hood, Y['habit'], Y['habit_sh'], off=(-6, -5), over='<path d="%s" fill="%s"/>' % (ell_d(hx + 6, hy + 6, 30, 28), '#5a6a40')))
    face_d = ell_d(hx + 6, hy + 7, 27, 25)
    parts.append(Part('fill', pth(face_d), fill=Y['skin'], shade=Y['skin_sh'], off=(-3, -2),
                      over=yarrow_face(ctx, hx + 6, hy + 8, 1.0, 'gentle')
                      + clipped(ctx, face_d, '<path d="M%.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f Z" fill="#f8f4ec"/>' % (
                          hx - 22, hy - 12, hx + 6, hy - 22, hx + 34, hy - 12, hx + 6, hy - 6, hx - 22, hy - 12))))
    # the straw brim, tipped back, the yarrow sprig tucked in it
    brim = 'M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z' % (
        hx - 56, hy - 18, hx - 30, hy - 44, hx + 44, hy - 46, hx + 66, hy - 16, hx + 40, hy - 26, hx - 30, hy - 26, hx - 56, hy - 18)
    weave = ''.join(line('M%.1f %.1f L%.1f %.1f' % (hx - 40 + i * 14, hy - 26 - (8 if 1 < i < 6 else 2), hx - 44 + i * 14, hy - 20), Y['straw_sh'], 1.2, op=0.8)
                    for i in range(8))
    parts.append(P(brim, Y['straw'], Y['straw_sh'], off=(-3, -2), over=weave))
    parts += yarrow_umbel(hx - 34, hy - 36, 1.0) + yarrow_umbel(hx - 24, hy - 44, 0.8)
    # the stub candle on the hood's crown
    cp, wk, tip = candle(ctx, hx + 14, hy - 38, 10, 9, Y['line'], drips=((0.25, 0.3), (0.7, 0.4)), wax='#f4f0dc', wax_sh='#d0c8a8')
    parts += cp
    parts[-1].over += wk
    ghost = radial(ctx, 132, 170, 110, '#d8e8a0', 0.35)
    body = ghost + '<g opacity="0.72">%s</g>' % render(ctx, parts, Y['line'], Y['habit']).replace('#ffeccc', '#f4ffe0')
    f.flame('head', tip[0], tip[1], 16, kind='flame', r=120, s=0.85, off=True)
    f.flame('aura', 132, 170, 8, kind='glow', color='d8e8a0', r=220, s=0.6)
    return f, fig_doc(ctx, fit(body, f.s))


# ================================================================ the Tinker of Hours and Master Tickwell (boss_4)

def tinker_boss():
    """The Tinker of Hours, about 3.3 x Waxby, as it fights (story_tinker:
    boss4.py's parts): the walking clockwork bell-body, the lamp-lens eyes,
    the frosted clock on its chest, the minute hand for a blade, and Master
    Tickwell frozen in the case on its back (spec 6.5 edit 4); his watch
    glows cold behind the frost (`heart`)."""
    import story_tinker as TK
    import story_rootmother as RM
    f = Fig('tinker_boss', 1.0, h=boss_h('tinker'))
    ctx = Ctx('ftk')
    art = TK.figure()
    ctx.defs.append(art['defs'])
    body = shadow(128, 70, op=0.35) + art['body']
    (ax, ay), (bx, by) = art['eyes']
    f.set_flame('eyes', (ax + bx) / 2, (ay + by) / 2, 0, dict(kind='eyes', color=TK.EYES, pts=[[ax, ay], [bx, by]], dot=2.2, r=70, s=0.6))
    wx, wy = art['watch']
    f.set_flame('heart', wx, wy, 6, dict(kind='cold', color='bfe8ff', r=50, s=0.6))
    return f, fig_doc(ctx, body)


def tickwell():
    """Master Tickwell, keeper of the Downward Bells, 70% of Waxby's height:
    bald with a white fringe, brass magnifier goggles pushed up, a bristly
    white moustache, a leather tool apron and a ring of keys, both hands
    holding his round lantern-watch with a candle inside its glass;
    blinking, as if just woken."""
    import story_tinker as TK
    f = Fig('tickwell', 1.0)
    ctx = Ctx('ftw')
    parts = []
    # little shoes and navy trousers
    for x in (116, 146):
        parts.append(LIMB('M%d 214 L%d 234' % (x, x + (x - 131) * 0.1), TK.COAT_SH, 13))
        parts.append(E(x + 4, 238, 12, 6.4, '#4a3020', '#2e1e14', off=(-1.5, -1.5)))
    # the navy coat, round-bellied, its tails
    coat = 'M104 172 C92 186 90 206 96 222 L112 226 L150 226 L166 222 C170 206 168 186 158 172 Z'
    parts.append(P(coat, TK.COAT, TK.COAT_SH, off=(-6, -3), over=''.join(dot(131 + 0.5, y, 1.8, TK.BRASS) for y in (184, 196, 208))))
    # the leather tool apron: a pocket of screwdrivers, tweezers
    apron = 'M110 186 L154 186 C156 200 158 212 158 224 L108 224 C108 212 108 200 110 186 Z'
    tools = ''.join(line('M%.1f 202 L%.1f 190' % (x, x + 1), c, 1.6) for x, c in ((118, '#b8bcc8'), (122, '#d8a850'), (126, '#b8bcc8')))
    tools += '<path d="M114 200 L132 200 L131 212 L115 212 Z" fill="#5e3e26" stroke="%s" stroke-width="1"/>' % TK.L
    parts.append(P(apron, TK.APRON, TK.APRON_SH, off=(-3, -2), over=tools + line('M112 190 L152 190', TK.APRON_SH, 1.2)))
    # a ring of keys at his hip
    keys = '<path d="%s" fill="none" stroke="%s" stroke-width="2"/>' % (ell_d(104, 206, 6, 6), TK.BRASS)
    for i, a in enumerate((70, 100, 130)):
        r = math.radians(a)
        x0, y0 = 104 + math.cos(r) * 6, 206 + math.sin(r) * 6
        keys += line('M%.1f %.1f L%.1f %.1f' % (x0, y0, x0 + math.cos(r) * 9, y0 + math.sin(r) * 9), TK.BRASS, 1.8)
        keys += dot(x0 + math.cos(r) * 9, y0 + math.sin(r) * 9, 1.6, TK.BRASS)
    # both arms round to the watch at his chest
    parts.append(P('M104 176 C96 186 98 198 112 202 L118 194 C110 190 108 184 110 178 Z', TK.COAT, TK.COAT_SH, off=(-2, -2)))
    parts.append(P('M158 176 C168 184 168 196 156 202 L150 194 C156 190 156 184 152 178 Z', TK.COAT, TK.COAT_SH, off=(-2, -2)))
    wp, wbase = TK.lantern_watch(136, 196, 1.3)
    parts += wp
    parts.append(E(122, 200, 6, 5.6, TK.SKIN, TK.SKIN_SH, off=(-1, -1)))
    parts.append(E(150, 200, 6, 5.6, TK.SKIN, TK.SKIN_SH, off=(-1, -1)))
    # the big bald head, white fringe, goggles pushed up
    hx, hy = 134, 146
    parts.append(E(hx - 30, hy + 6, 7, 10, TK.SKIN, TK.SKIN_SH, off=(-1, -1)))
    parts.append(Part('fill', kit.head_tpl(hx, hy, 70, 62), fill=TK.SKIN, shade=TK.SKIN_SH, off=(-4, -4),
                      over=TK.tickwell_face(ctx, hx + 6, hy + 4, 1.0, 'dazed'),
                      hl=spec(hx - 16, hy - 20, 9, 4.6, rot=-35, op=0.85)))
    for side in (-1, 1):
        parts.append(P('M%.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f Z' % (
            hx + side * 34, hy - 4, hx + side * 40, hy + 8, hx + side * 30, hy + 20, hx + side * 30, hy + 6, hx + side * 34, hy - 4),
            TK.HAIR, '#c8c8d8', off=(-1, -1)))
    body = shadow(132, 36) + render(ctx, parts, TK.L, TK.COAT) + keys
    body += TK.goggles(hx + 4, hy - 20, 1.0, tilt=-8)
    f.flame('watch', wbase[0], wbase[1], 12, kind='flame', r=110, s=0.85)
    return f, fig_doc(ctx, fit(body, f.s))


def cone_bell():
    """Hollin's Bell: the two halves of the Snuffer's iron cone riveted back
    together along a brass band from the pole, mouth down, a small clapper
    and a short wooden yoke; drawn in the Snuffer's frame at cone_broken's
    scale, so the pose on the bench swaps one for the other."""
    import story_snuffer as SN
    f = Fig('cone_bell', 1.0, h=SN.FIG_H)
    ctx = Ctx('fcbl')
    cx, rim = SN.FOOT[0] + 40, 350
    t = 'translate(%.1f %.1f)' % (cx, rim)
    cone = 'M-50 -2 C-45 -28 -18 -56 -8 -72 L8 -72 C18 -56 45 -28 50 -2 Q0 7 -50 -2 Z'
    band = ('<path d="M-6 -72 L6 -72 L8 4 L-8 4 Z" fill="%s" stroke="%s" stroke-width="1.4"/>' % (SN.BRASS, SN.BRASS_LINE)
            + ''.join(dot(0, y, 1.6, SN.BRASS_HI) for y in (-62, -48, -34, -20, -6)))
    rimband = ('<path d="M-50.6 -2.4 Q0 6.8 50.6 -2.4 L49 -10.4 Q0 -1.6 -49 -10.4 Z" fill="%s"/>' % SN.IRON_BAND
               + ''.join(dot(x, y, 1.3, SN.IRON_HI, 0.9) for x, y in ((-40, -5), (-22, -1.6), (14, -0.6), (32, -3), (44, -5.4))))
    seam = line('M-3 -70 L-5 -40 L-2 -20 L-4 2', SN.L, 1.2, op=0.6)
    parts = []
    # the clapper under the rim, on two little wedges it stands on
    parts.append(Part('fill', pth('M-6 2 L6 2 L4 14 Q0 18 -4 14 Z').replace(' {a}', ' transform="%s" {a}' % t), fill='#5a4a40', shade='#3a2e28',
                      off=(-1, -1), line=SN.L))
    for x in (-36, 30):
        parts.append(Part('fill', pth('M%d 4 L%d 4 L%d 18 L%d 18 Z' % (x, x + 8, x + 10, x - 2)).replace(' {a}', ' transform="%s" {a}' % t),
                          fill='#8a5a36', shade='#5e3a22', off=(-1, -1), line=SN.L))
    parts.append(Part('fill', pth(cone).replace(' {a}', ' transform="%s" {a}' % t), fill=SN.IRON, shade=SN.IRON_SH, off=(-10, -3), line=SN.L,
                      over=gx(rimband + seam + band, t), hl=gx(spec(-26, -30, 4, 14, rot=20, op=0.5, col=SN.IRON_HI), t)))
    # the short wooden yoke through the knob
    parts.append(Part('fill', pth('M-26 -78 L26 -78 Q30 -72 26 -68 L-26 -68 Q-30 -72 -26 -78 Z').replace(' {a}', ' transform="%s" {a}' % t),
                      fill='#8a5a36', shade='#5e3a22', off=(-2, -2), line=SN.L,
                      over=gx(line('M-24 -76 L22 -76', '#b07a4c', 1.4), t)))
    parts.append(Part('fill', pth('M-6 -78 C-8 -92 8 -92 6 -78 Z').replace(' {a}', ' transform="%s" {a}' % t), fill=SN.IRON, shade=SN.IRON_SH,
                      off=(-1, -1), line=SN.L))
    art = '<ellipse cx="%.1f" cy="368" rx="60" ry="6" fill="#07040a" opacity="0.3"/>' % cx
    art += SN.render(ctx, parts)
    f.set_flame('rim', 128 + (cx - SN.FOOT[0]) * SN.FIG_K, 244 + (rim - 20 - SN.FOOT[1]) * SN.FIG_K, 6,
                dict(kind='glow', color='ffd08a', r=60, s=0.3))
    return f, fig_doc(ctx, SN.fig_body(art))


# ================================================================ the Prism Saint and Tessel (boss_5)

def saint(lit):
    """The Prism Saint as she fights (story_saint: boss5.py's parts, at the
    size the engine draws her, the halo behind her head): cold white and
    lilac glass, eyes closed, the prism in her cupped hands, Tessel small in
    her heart pane; or, lit from behind (her last fight frame), Tessel: every
    pane warm, her eyes open and kind, her heart's candle (off until lit)."""
    import story_saint as SA
    import story_rootmother as RM
    fid = 'tessel_lit' if lit else 'saint_boss'
    f = Fig(fid, 1.0, h=boss_h('saint'))
    ctx = Ctx('fsa' + ('l' if lit else 'c'))
    art = SA.figure(lit)
    ctx.defs.append(art['defs'])
    glow = radial(ctx, 128, 150, 100, '#ffe8c0' if lit else '#e8ecff', 0.3)
    body = glow + art['body']
    (ax, ay), (bx, by) = art['eyes']
    eyes = dict(kind='eyes', color=SA.EYES_WARM if lit else SA.EYES_COLD, pts=[[ax, ay], [bx, by]], dot=1.6, r=70, s=0.6)
    if lit:
        f.set_flame('heart', art['heart'][0], art['heart'][1], 7, dict(kind='flame', r=120, s=0.95, off=True))
        f.set_flame('eyes', (ax + bx) / 2, (ay + by) / 2, 0, eyes)
    else:
        f.set_flame('eyes', (ax + bx) / 2, (ay + by) / 2, 0, eyes)
        f.set_flame('halo', art['halo'][0], art['halo'][1], 6, dict(kind='glow', color='f0f4ff', r=170, s=0.6))
        f.set_flame('prism', art['prism'][0], art['prism'][1], 6, dict(kind='glow', color='f0f4ff', r=50, s=0.6))
    return f, fig_doc(ctx, body)


def saint_boss():
    return saint(False)


def tessel_lit():
    return saint(True)


# ================================================================ the finale's figures (boss_6_after, lullaby, homecoming)

IVORY, IVORY_SH, IVORY_LINE = '#e8e0cc', '#b8ae96', '#2a2430'


def stolen_wick():
    """The Undercandle's stolen flame, gone out: an ancient ivory candle stub
    on a floating ring of set wax, a long curled black wick and a thin curl
    of cold smoke. Its flame (off) is the one that catches at the end."""
    f = Fig('stolen_wick', 1.0)
    ctx = Ctx('fsw')
    parts = []
    # the floating ring of set wax, flat on the black water
    parts.append(P(ell_d(128, 232, 70, 13), IVORY, IVORY_SH, off=(-6, -3),
                   over='<path d="%s" fill="#403a4a"/>' % ell_d(128, 229, 40, 6.4)
                   + line('M68 230 Q128 216 188 230', '#fffaf0', 2, op=0.7)))
    # the ancient stub: wide, pitted, drips frozen down its sides
    cp, wk, tip = candle(ctx, 128, 230, 50, 60, IVORY_LINE, drips=((0.15, 0.5), (0.4, 0.28), (0.7, 0.6), (0.9, 0.3)), wax=IVORY,
                         wax_sh=IVORY_SH, cap='#f4ecd8')
    parts += cp
    body = shadow(128, 72, y=236, op=0.4) + render(ctx, parts, IVORY_LINE, IVORY)
    # the long curled black wick
    wx, wy = 128, 168
    wick = 'M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f' % (
        wx, wy, wx - 2, wy - 12, wx + 10, wy - 18, wx + 12, wy - 28, wx + 14, wy - 38, wx + 4, wy - 42, wx - 2, wy - 36)
    body += line(wick, '#0a0810', 5) + line(wick, '#2a2430', 2)
    # a thin curl of cold smoke from its tip
    body += smoke_curl(wx - 2, wy - 38, 56, '#b4aecb', 2.4, op=0.6, lean=-0.6)
    f.flame('wick', wx + 4, wy - 20, 85, kind='flame', r=420, s=1.0, off=True)
    return f, fig_doc(ctx, fit(body, f.s))


def hollin_grin_face(ctx, cx, cy):
    """Hollin's big grin on a figure (the hollin_grin portrait's face, in
    hollin_face's layout, centred on (cx, cy)): eyes squeezed happy, blush,
    a wide gap-toothed grin and his tongue; no tears."""
    from story_figs import HOL, HWARM
    F, ln = HWARM, HOL['line']
    s = ''
    for ex, ey, w, h in ((cx - 15, cy + 1, 25, 32), (cx + 20, cy, 20.5, 30)):
        s += kit.eye(ctx, ex, ey + 2, w + 2, h * 0.74, F, mood='happy')
    s += kit.blush(cx - 26, cy + 18, F, 9, 5) + kit.blush(cx + 32, cy + 16, F, 6.4, 4)
    x0 = cx + 4 - 66                  # the portrait's grin, its middle under his nose
    s += '<path d="M%.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f Z" fill="%s"/>' % (
        x0 + 48, cy + 12, x0 + 66, cy + 14, x0 + 86, cy + 11, x0 + 80, cy + 30, x0 + 66, cy + 31, x0 + 52, cy + 28, x0 + 48, cy + 12, ln)
    s += '<path d="M%.1f %.1f Q%.1f %.1f %.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f Z" fill="#ffffff"/>' % (
        x0 + 52, cy + 13.4, x0 + 66, cy + 15.2, x0 + 83, cy + 12.4, x0 + 82, cy + 17, x0 + 66, cy + 19, x0 + 53, cy + 17.6)
    s += line('M%.1f %.1f L%.1f %.1f' % (x0 + 66, cy + 14.6, x0 + 66.4, cy + 19), ln, 2.2)
    s += '<path d="M%.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f Z" fill="%s"/>' % (
        x0 + 58, cy + 26, x0 + 66, cy + 22, x0 + 76, cy + 26, x0 + 70, cy + 29.6, x0 + 66, cy + 29.8, x0 + 62, cy + 29.6, x0 + 58, cy + 26,
        kit.TONGUE)
    return s


def hollin_carry():
    """Hollin, his helm lit, carrying tiny Mother Taper piggyback down the
    stair: she holds her ember up high in one hand, her own stub on her
    hood, her spectacles askew; both smiling. Hollin's Bell hangs at his belt."""
    from story_figs import taper_hood, TAPER, HOL
    f = Fig('hollin_carry', 1.0, h=140.0)
    ctx = Ctx('fhc2')
    H, T = HOL, TAPER
    parts = []
    tp_parts = []
    # Taper on his back: her hooded head up over his shoulder, her arm raised with the ember
    tp_parts.append(P('M64 90 C54 74 48 52 50 34 L62 32 C62 50 66 68 78 80 Z', T['plum'], T['plum_sh'], off=(-2, -2)))
    tp_parts.append(E(56, 30, 6, 5.6, T['skin'], T['skin_sh'], off=(-1, -1)))
    ttip = taper_hood(ctx, tp_parts, 66, 90, face_dx=6, k=0.82, nub=True, mood='proud')
    # Taper's little plum robe and arm behind him, her legs round his waist
    parts.append(P('M86 150 C74 160 72 182 84 196 L104 190 C100 176 100 164 104 154 Z', T['plum'], T['plum_sh'], off=(-3, -3)))
    parts.append(E(118, 206, 8, 5, T['shoe'], off=(-1, -1)))
    # Hollin: boots, legs, tabard, arms back holding her
    parts.append(E(112, 239, 13, 7, H['boot'], off=(-2, -2)))
    parts.append(E(152, 240, 13, 7, H['boot'], off=(-2, -2)))
    parts.append(LIMB('M116 208 L112 232', H['tunic'], 14))
    parts.append(LIMB('M146 208 L150 232', H['tunic'], 14))
    tab = 'M106 166 L152 166 C158 184 160 200 162 214 L150 218 L140 212 L130 219 L118 212 L108 218 L96 214 C98 200 100 184 106 166 Z'
    em = '<path d="%s" fill="%s" stroke="%s" stroke-width="1.6" opacity="0.8"/>' % (flame_d(130, 200, 13, 21, 1), H['trim'], H['line'])
    parts.append(P(tab, H['tabard'], H['tabard_sh'], off=(-5, -3), over=em + line('M100 206 L160 206', H['trim'], 2, op=0.6)))
    # Hollin's Bell at his belt: the little iron cone with its brass band
    parts.append(LIMB('M150 206 L156 212', '#6a4a30', 2.4))
    parts.append(P('M148 224 C150 214 154 210 158 210 C162 210 166 214 168 224 Q158 228 148 224 Z', '#2a2436', '#1a1624', off=(-2, -1),
                   over=line('M158 211 L158 226', '#b8862a', 2.4)))
    parts.append(P('M104 172 C96 170 88 176 88 186 L98 190 C98 184 102 180 108 180 Z', H['tunic'], H['tunic_sh'], off=(-2, -2)))
    parts.append(E(92, 192, 7, 6.6, H['warm'], H['warm_sh'], off=(-1, -1)))
    parts.append(P('M150 170 C160 176 164 186 160 196 L150 194 C152 188 150 182 146 178 Z', H['tunic'], H['tunic_sh'], off=(-2, -2)))
    parts.append(E(156, 198, 6.4, 6, H['warm'], H['warm_sh'], off=(-1, -1)))
    # his head, a happy grin (hollin_grin's, no tears now), the helm lit
    hx, hy = 138, 126
    parts.append(Part('fill', kit.head_tpl(hx, hy, 102, 86), fill=H['warm'], shade=H['warm_sh'], off=(-4, -4),
                      over=hollin_grin_face(ctx, hx + 4, hy + 8)))
    from story_figs import messy_hair, dented_helm
    parts.append(messy_hair(hx, hy - 6, 104, 70, H['hair'], H['hair_hi'], H['line']))
    helm, htip = dented_helm(ctx, hx - 2, 70, 94)
    parts += helm
    body = shadow(132, 50) + render(ctx, tp_parts + parts, H['line'], H['tabard'])
    # the ember held up high: a little glowing coal in her fingers
    body += radial(ctx, 56, 20, 12, '#ffb060', 0.8) + dot(56, 21, 4.4, '#ff9a4a') + dot(55, 20, 2.2, '#ffe0a0')
    f.flame('hollin', htip[0], htip[1], 30, kind='flame', r=240, s=1.0)
    f.flame('taper', 56, 20, 12, kind='flame', r=120, s=0.9)
    return f, fig_doc(ctx, fit(body, f.s))


def tollgrave_stand():
    """Old Tollgrave, freed, standing: hood back, white wisps and a beard tuft,
    amber eyes, a lantern on a pole in one hand and a bell rope coiled over
    his shoulder. Drawn in boss.py's units, like tollgrave_sit."""
    import boss
    from enemies import BONE, BONE_SH, BONE_LINE
    from story_figs import soft_hair
    H = 300.0
    f = Fig('tollgrave_stand', 1.0, h=H)
    ctx = Ctx('ftgs')
    L = boss.L
    parts = []
    # the lantern pole behind his front hand, the lantern hanging off its hook
    parts.append(LIMB('M190 244 L188 96 Q188 86 198 86 Q208 86 206 96', '#6a4a30', 3.4))
    lx, ly = 206, 100
    parts += [LIMB('M%.1f %.1f L%.1f %.1f' % (lx, ly - 4, lx, ly + 2), '#3a3446', 1.4),
              P('M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (lx - 8, ly + 8, lx + 8, ly + 8, lx + 4, ly + 2, lx - 4, ly + 2), '#4a4458', '#2e2a3a', off=(-1, -1))]
    glass = ctx.radgrad([(0, '#fff6d0'), (0.6, '#ffd878'), (1, '#e8a040')], cx=0.5, cy=0.65, r=0.6)
    parts.append(Part('fill', pth(rect_d(lx - 6.4, ly + 8, lx + 6.4, ly + 24)), fill=glass, no_shade=True,
                      over=line('M%.1f %.1f L%.1f %.1f M%.1f %.1f L%.1f %.1f' % (lx - 6.4, ly + 8, lx - 6.4, ly + 24, lx + 6.4, ly + 8, lx + 6.4, ly + 24), '#3a3446', 1.8)))
    parts.append(P('M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (lx - 9, ly + 24, lx + 9, ly + 24, lx + 6, ly + 28, lx - 6, ly + 28), '#4a4458', '#2e2a3a', off=(-1, -1)))
    # the robe, standing, the cord belt
    parts.append(Part('fill', pth(boss.ROBE_D), fill=boss.ROBE, shade=boss.ROBE_SH, off=(-6, -3),
                      over=line('M120 152 Q115 192 111 236 M147 154 Q153 194 158 236', L, 1.2, op=0.55)
                      + line('M84 190 Q128 200 178 188', L, 6) + line('M84 190 Q128 200 178 188', boss.CORD, 3.2)))
    # the bell rope coiled over his far shoulder
    for i in range(3):
        parts.append(Part('fill', pth(ell_d(104 - i * 2, 150 + i * 4, 18 - i, 10)), fill='none', no_shade=True, sil=False,
                          under=line(ell_d(104 - i * 2, 150 + i * 4, 18 - i, 10), boss.CORD_SH, 5) + line(ell_d(104 - i * 2, 150 + i * 4, 18 - i, 10), boss.CORD, 3)))
    parts.append(LIMB('M92 158 Q84 190 88 222', boss.CORD, 3.4))
    # the front arm holding the pole; the back hand at his side
    parts.append(boss.sleeve((166, 150), (184, 176), 13, 20))
    parts += boss.bone_hand(188, 180, -90, fist=True)
    parts.append(boss.sleeve((104, 152), (96, 186), 12, 18, boss.ROBE_SH, '#261e33'))
    parts += boss.bone_hand(96, 192, 100, fist=False)
    # the hood fallen back, the skull with its gentle smile
    hx, hy = 124, 118
    parts.append(Part('fill', pth(ell_d(hx - 14, hy + 8, 30, 26)), fill=boss.ROBE, shade=boss.ROBE_SH, off=(-3, -3)))
    parts.append(Part('fill', pth('M94 146 C104 134 150 134 160 146 C152 154 104 156 94 146 Z'), fill=boss.ROBE, shade=boss.ROBE_SH, off=(-2, -2)))
    sx, sy = 130, 112
    jaw = 'M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z' % (
        sx - 12, sy + 13, sx - 11, sy + 22, sx - 2, sy + 25, sx + 6, sy + 25, sx + 14, sy + 25, sx + 21, sy + 21, sx + 20, sy + 12)
    parts.append(Part('fill', pth(jaw), fill=BONE, shade=BONE_SH, off=(-1, -1), line=BONE_LINE))
    face = ''
    for ex, ey, w, h in ((sx - 8, sy - 1, 13, 14), (sx + 11, sy - 2, 11, 13)):
        face += '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="#1a0e08"/>' % (ex, ey, w / 2, h / 2)
    face += '<path d="M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z" fill="%s"/>' % (
        sx + 2.4, sy + 5, sx + 0.4, sy + 3.6, sx - 0.8, sy + 6.4, sx + 2.2, sy + 8.6, sx + 5.2, sy + 6.4, sx + 4.2, sy + 3.6, sx + 2.4, sy + 5, BONE_LINE)
    face += '<path d="M%.1f %.1f Q%.1f %.1f %.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f Z" fill="%s"/>' % (
        sx - 9, sy + 10.4, sx + 4, sy + 18, sx + 18, sy + 9.6, sx + 18, sy + 12.4, sx + 4, sy + 21.4, sx - 9, sy + 13.4, BONE_LINE)
    for i in range(6):
        t = (i + 0.5) / 6.0
        x = sx - 8 + t * 25
        y = sy + 11 + 6.2 * math.sin(t * math.pi) + 0.4
        face += '<rect x="%.1f" y="%.1f" width="2.8" height="2.6" rx="0.6" fill="#fffaf0"/>' % (x - 1.4, y)
    face += kit.blush(sx - 14, sy + 8, dict(blush='#ff9a8a'), 3, 1.8, lines=False, op=0.45)
    hl = spec(sx - 12, sy - 14, 6, 3, rot=-38, op=0.95)
    parts.append(Part('fill', kit.head_tpl(sx, sy, 46, 42, squish=-0.08), fill=BONE, shade=BONE_SH, off=(-3.4, -3.4), line=BONE_LINE,
                      over=face, hl=hl))
    beard = 'M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z' % (
        sx - 4, sy + 23, sx - 8, sy + 32, sx - 4, sy + 42, sx + 2, sy + 48, sx + 4, sy + 40, sx + 12, sy + 36, sx + 14, sy + 23,
        sx + 8, sy + 26, sx + 1, sy + 26, sx - 4, sy + 23)
    parts.append(Part('fill', pth(beard), fill='#f8f4ff', shade='#c8c0d8', off=(-1, -1), line=BONE_LINE))
    k = 240.0 / H
    with weights((4.0 * k, 3.2 * k, 1.4 * k, 1.0 * k)):
        art = kit.render_parts(ctx, parts, dict(line=L, rim=RIM, base=boss.ROBE, shade=boss.ROBE_SH))
    body = '<ellipse cx="128" cy="245" rx="70" ry="7" fill="#07040a" opacity="0.3"/>' + art + soft_hair(sx, sy - 19, 0.8)
    f.set_flame('eyes', sx + 1.5, sy - 1.5, 0, {'kind': 'eyes', 'color': 'f7b64a', 'pts': [[sx - 8, sy - 1], [sx + 11, sy - 2]],
                                              'dot': 3.0, 'r': 110, 's': 0.75})
    f.set_flame('lantern', lx, ly + 22, 10, {'kind': 'flame', 'r': 110, 's': 0.9})
    return f, fig_doc(ctx, body)


FOLK = ['#8a7a88', '#7a6a70', '#6a6478', '#8a7468', '#746a80', '#80706a', '#6a7078', '#887a7a']


def folk(ctx, x, floor, k, col, kind, rng):
    """One of Lanternfold's townsfolk in warm grey, holding up a little lamp.
    kind: baker, child (on a shoulder), old (a stick), twin, cat (on a hat).
    Returns (parts, lamp flame point)."""
    parts = []
    sk, sk_sh = '#e8c8b0', '#c8a088'
    top = floor - 90 * k
    parts.append(P('M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f L%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z' % (
        x - 20 * k, floor, x - 20 * k, floor - 30 * k, x - 14 * k, floor - 52 * k, x, floor - 52 * k,
        x, floor - 52 * k, x + 14 * k, floor - 52 * k, x + 20 * k, floor - 30 * k, x + 20 * k, floor), col, shade_of(col), off=(-3, -1)))
    if kind == 'baker':
        parts.append(P(rect_d(x - 12 * k, floor - 44 * k, x + 12 * k, floor - 4 * k), '#f4ecdc', '#c8c0b0', off=(-1, -1)))
    hx, hy = x, floor - 66 * k
    parts.append(E(hx, hy, 16 * k, 15 * k, sk, sk_sh, off=(-2, -2),
                   over=line('M%.1f %.1f q%.1f %.1f %.1f %.1f M%.1f %.1f q%.1f %.1f %.1f %.1f' % (
                       hx - 8 * k, hy, 2.4 * k, -2.4 * k, 4.8 * k, 0, hx + 3 * k, hy, 2.4 * k, -2.4 * k, 4.8 * k, 0), INK, 1.4 * k)
                   + line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (hx - 4 * k, hy + 6 * k, hx, hy + 9 * k, hx + 4 * k, hy + 6 * k), INK, 1.3 * k)))
    if kind == 'baker':
        parts.append(E(hx, hy - 16 * k, 14 * k, 8 * k, '#f8f4ec', '#d0c8b8', off=(-1, -1)))
    elif kind == 'old':
        parts.append(LIMB('M%.1f %.1f L%.1f %.1f' % (x - 24 * k, floor, x - 20 * k, floor - 50 * k), '#6a4a30', 3.4 * k))
        parts.append(P('M%.1f %.1f Q%.1f %.1f %.1f %.1f Z' % (hx - 14 * k, hy - 8 * k, hx, hy - 20 * k, hx + 14 * k, hy - 8 * k), '#f4f4f8', '#c8c8d8'))
    elif kind == 'cat':
        parts.append(P(rect_d(hx - 12 * k, hy - 26 * k, hx + 12 * k, hy - 12 * k), '#4a3a44', '#34282e', off=(-1, -1)))
        parts.append(P(rect_d(hx - 18 * k, hy - 14 * k, hx + 18 * k, hy - 10 * k), '#4a3a44', '#34282e', off=(-1, -1)))
        parts.append(E(hx + 2 * k, hy - 32 * k, 9 * k, 7 * k, '#3a3040', '#2a2030', off=(-1, -1),
                       over=dot(hx - 1 * k, hy - 33 * k, 1.2 * k, '#f8d860') + dot(hx + 5 * k, hy - 33 * k, 1.2 * k, '#f8d860')))
        parts.append(P('M%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (hx - 5 * k, hy - 37 * k, hx - 2 * k, hy - 44 * k, hx + 1 * k, hy - 38 * k), '#3a3040', '#2a2030'))
        parts.append(P('M%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (hx + 4 * k, hy - 38 * k, hx + 8 * k, hy - 44 * k, hx + 10 * k, hy - 36 * k), '#3a3040', '#2a2030'))
    elif kind == 'child':
        parts.append(E(hx + 4 * k, hy - 22 * k, 11 * k, 10 * k, sk, sk_sh, off=(-1, -1),
                       over=dot(hx + 1 * k, hy - 22 * k, 1.1 * k, INK) + dot(hx + 7 * k, hy - 22 * k, 1.1 * k, INK)))
    # the arm up with its lamp
    ax, ay = x + 18 * k, floor - 84 * k
    parts.append(LIMB('M%.1f %.1f L%.1f %.1f' % (x + 12 * k, floor - 44 * k, ax, ay + 10 * k), col, 6 * k))
    parts.append(P('M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (ax - 5 * k, ay + 8 * k, ax + 5 * k, ay + 8 * k, ax + 4 * k, ay - 4 * k, ax - 4 * k, ay - 4 * k),
                   '#ffd878', '#e8a040', off=(-1, -1)))
    return parts, (ax, ay + 4 * k)


def townsfolk_line():
    """Eight of Lanternfold's townsfolk in a row, each holding a lamp: a baker
    in an apron, a child on a shoulder, an old man with a stick, twins, a
    cat riding someone's hat; warm greys, silhouette-ish."""
    H = 220.0
    s_ = 120.0 / H
    f = Fig('townsfolk_line', s_)
    ctx = Ctx('ftl')
    rng = Rand(6601)
    parts = []
    tips = []
    kinds = ['baker', 'child', 'old', 'twin', 'twin', 'cat', 'plain', 'baker']
    span = 256 / s_
    x0 = 128 - span * 0.44
    for i, kind in enumerate(kinds):
        x = x0 + i * span * 0.88 / 7
        k = 1.0 if kind != 'twin' else 0.86
        pp, tip = folk(ctx, x, 244, k * 1.05, FOLK[i], kind, rng)
        parts += pp
        tips.append(tip)
    body = render(ctx, parts, INK, FOLK[0])
    for i, (x, y) in enumerate(tips):
        f.flame('lamp%d' % (i + 1), x, y, 14, kind='flame', r=110, s=0.8)
    return f, fig_doc(ctx, fit(body, f.s))


def deep_candle():
    """The Hush's own candle: a small plain candle standing on a floating wax
    lily pad (its flame off until lullaby lights it)."""
    f = Fig('deep_candle', 1.0)
    ctx = Ctx('fdc')
    parts = [P('M58 234 C58 222 98 216 128 216 C158 216 198 222 198 234 C198 244 158 248 128 248 C98 248 58 244 58 234 Z',
               '#d8e0c8', '#a8b098', off=(-5, -3), over='<path d="M128 232 L186 226" stroke="#a8b098" stroke-width="2" fill="none"/>'
               + line('M70 232 Q128 222 186 230', '#f4f8e8', 1.8, op=0.8))]
    cp, wk, tip = candle(ctx, 128, 228, 30, 64, INK)
    parts += cp
    parts[-1].over += wk
    body = shadow(128, 70, y=246) + render(ctx, parts, INK, WAX)
    f.flame('wick', tip[0], tip[1], 30, kind='flame', r=160, s=0.9, off=True)
    return f, fig_doc(ctx, fit(body, f.s))


def helm_outline(kind, x, base, k=1.0):
    """The outline of a Wick's helm: knight, hood, mask, bellhat, wimple, crown."""
    if kind == 'knight':
        d = 'M%.1f %.1f L%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f L%.1f %.1f Z' % (
            x - 18 * k, base, x - 18 * k, base - 20 * k, x - 16 * k, base - 36 * k, x + 16 * k, base - 36 * k, x + 18 * k, base - 20 * k,
            x + 18 * k, base)
        d += ' M%.1f %.1f L%.1f %.1f' % (x - 12 * k, base - 16 * k, x + 12 * k, base - 16 * k)
    elif kind == 'hood':
        d = 'M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f' % (
            x - 20 * k, base, x - 22 * k, base - 30 * k, x - 6 * k, base - 44 * k, x + 4 * k, base - 40 * k,
            x + 20 * k, base - 34 * k, x + 22 * k, base - 12 * k, x + 18 * k, base)
    elif kind == 'mask':
        d = 'M%.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f Z M%.1f %.1f L%.1f %.1f M%.1f %.1f L%.1f %.1f' % (
            x - 18 * k, base - 20 * k, x, base - 44 * k, x + 18 * k, base - 20 * k, x, base + 2 * k, x - 18 * k, base - 20 * k,
            x - 10 * k, base - 22 * k, x - 4 * k, base - 22 * k, x + 4 * k, base - 22 * k, x + 10 * k, base - 22 * k)
    elif kind == 'bellhat':
        d = 'M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z' % (
            x - 22 * k, base - 8 * k, x - 14 * k, base - 20 * k, x - 12 * k, base - 42 * k, x, base - 42 * k,
            x + 12 * k, base - 42 * k, x + 14 * k, base - 20 * k, x + 22 * k, base - 8 * k)
    elif kind == 'wimple':
        d = 'M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (
            x - 20 * k, base + 4 * k, x - 24 * k, base - 28 * k, x - 10 * k, base - 42 * k, x, base - 42 * k,
            x + 10 * k, base - 42 * k, x + 24 * k, base - 28 * k, x + 20 * k, base + 4 * k,
            x - 14 * k, base - 8 * k, x, base - 2 * k, x + 14 * k, base - 8 * k)
    else:
        pts = [(-18, 0), (-18, -26), (-12, -36), (-6, -28), (0, -40), (6, -28), (12, -36), (18, -26), (18, 0)]
        d = poly_d([(x + a * k, base + b * k) for a, b in pts])
    return d


LOST = ['knight', 'hood', 'mask', 'bellhat', 'wimple', 'crown']


def lost_wicks():
    """The six Lost Wicks come home (P2): soft gold glows in the outlines of
    Wicks' helms of different shapes, a loose row, each with a little flame
    at its crown (off until they come)."""
    f = Fig('lost_wicks', 1.0)
    ctx = Ctx('flw')
    s = ''
    tips = []
    for i, kind in enumerate(LOST):
        x = 30 + i * 39
        base = 214 + (i % 2) * 10
        s += radial(ctx, x, base - 24, 34, '#ffe0a0', 0.6)
        d = helm_outline(kind, x, base, 0.95)
        s += '<path d="%s" fill="#ffe8b0" fill-opacity="0.22" stroke="#f2c75a" stroke-width="2.6" stroke-linejoin="round" stroke-linecap="round"/>' % d
        s += '<path d="%s" fill="none" stroke="#fff6d8" stroke-width="1.0" opacity="0.8"/>' % d
        tips.append((x, base - 42))
    for i, (x, y) in enumerate(tips):
        f.flame('w%d' % (i + 1), x, y, 18, kind='flame', r=120, s=0.8, off=True)
    return f, fig_doc(ctx, fit(s, f.s))


def extend_hush_eye(e):
    """The stolen flame glinting in the Hush's pupil (and later its reflection):
    off until a cue lights it."""
    e['flames']['pupil'] = [128.0, 131.0, 10.0, 'flame', 'ffd84a']
    e.setdefault('light', {})['pupil'] = {'kind': 'flame', 'color': 'ffd84a', 'r': 80, 's': 0.6, 'off': True}


FIGURES = [hush_grasp, rootmother_boss, rootmother_open, yarrow_spirit, tinker_boss, tickwell, cone_bell, saint_boss,
           tessel_lit, stolen_wick, hollin_carry, tollgrave_stand, townsfolk_line, deep_candle, lost_wicks]
EXTEND = {'hush_eye': extend_hush_eye}
