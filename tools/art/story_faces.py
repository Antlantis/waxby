"""The dialogue portraits: head and shoulders in the 128 frame (face near
(64, 62), px 6), drawn in native units on a 144 box (the kit's face pieces
unhalved) and scaled by 8/9, which puts them at the calling portraits' size
and line weight. The dialogue box crops them to the circle of radius 0.42 of
the frame (53.8 units) around (64, 62) and shows it at r 46, so everything
that matters, live flames and their holders included, sits inside that
circle; each has its own soft disc behind it. NPCs sit on the box's right,
so they turn a little left, toward its middle.

  taper    warm, worried, stern, sad, proud      (the nub candle is live)
  waxley   grin, shifty, shock                   (two brim candles are live)
  tollgrave hushed, kind
  snuffer  cold, wrath
  hollin   lost, relit                           (relit: the helm's candle is live)
"""
import math

import kit
from kit import Part, ell, pth
from common import Ctx, RIM, GOLD, GOLD_SH, GOLD_HI, WAX, WAX_SH, line, dot, flame_d, spec, star4, mix, sparkle, gx
import story_snuffer as SN
from story_kit import (NATIVE_W, weights, P, E, LIMB, rect_d, rrect_d, ell_d, poly_d, candle, smoke_curl, unlit_wick,
                       portrait_fit, portrait_pt, shade_of)
from story_figs import (TAPER, TFACE, WAXLEY, WFACE, HOL, HCOLD, HWARM, mustache, messy_hair, dented_helm, clipped,
                        render, wax_drips, soft_hair)

PX = 6
C = 72.0          # the native box's centre (144 units)
NUB_Y = 27.0      # the top of Taper's nub-candle holder (native units)


def doc(ctx, body):
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 128 128">\n'
            '<defs>%s</defs>\n%s\n</svg>\n') % (128 * PX, 128 * PX, ''.join(ctx.defs), portrait_fit(body))


def disc(ctx, inner, outer):
    """The portrait's own background: a soft disc filling the crop circle."""
    g = ctx.radgrad([(0, inner), (1, outer)], cx=0.45, cy=0.38, r=0.62)
    return '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s"/>' % (C, C, C, g)


def pt(x, y, h):
    fx, fy = portrait_pt(x, y)
    return [fx, fy, round(h * 8.0 / 9.0, 2)]


# ================================================================ Mother Taper

def taper(mood):
    ctx = Ctx('pt' + mood[:3])
    T = TAPER
    s = disc(ctx, '#4a2e4e', '#1e1226')
    parts = []
    # shoulders: the plum robe and its gold-trimmed collar
    parts.append(P('M6 150 C8 124 36 110 72 110 C108 110 136 124 138 150 Z', T['plum'], T['plum_sh'], off=(-8, -4),
                   over=line('M38 118 Q72 132 106 118', T['trim'], 4.4) + line('M38 121.6 Q72 135.6 106 121.6', T['trim_sh'], 1.2)))
    # the hood
    hood = 'M72 16 C108 16 132 40 132 72 C132 100 118 118 100 124 L44 124 C26 118 12 100 12 72 C12 40 36 16 72 16 Z'
    tail = 'M112 34 C130 30 142 44 140 66 C136 56 128 50 118 50 Z'
    parts.append(P(tail, T['plum'], T['plum_sh'], off=(-3, -3)))
    fx, fy = 66, 80
    opening = ell_d(fx, fy, 42, 40)
    face_d = ell_d(fx + 1, fy + 2, 37, 35)
    trim = ('<path d="%s" fill="none" stroke="%s" stroke-width="4.6"/>' % (ell_d(fx, fy, 42.6, 40.6), T['trim_sh'])
            + '<path d="%s" fill="none" stroke="%s" stroke-width="2.4"/>' % (ell_d(fx, fy, 42.6, 40.6), T['trim']))
    parts.append(P(hood, T['plum'], T['plum_sh'], off=(-9, -7),
                   over='<path d="%s" fill="%s"/>' % (opening, T['plum_in']) + trim
                   + line('M24 60 Q22 90 36 112', T['plum_hi'], 3, op=0.6),
                   hl=spec(44, 32, 12, 4.4, rot=-35, op=0.35)))
    # the face and all it does
    F = ''
    fringe = ('M20 38 L112 38 L110 66 Q102 58 96 66 Q90 56 82 64 Q76 54 68 62 Q60 53 54 63 Q46 55 40 65 Q32 58 26 68 Z')
    F += clipped(ctx, face_d, '<path d="%s" fill="%s"/><path d="%s" fill="none" stroke="%s" stroke-width="1.6"/>' % (
        fringe, T['hair'], fringe, T['hair_sh']))
    ex_far, ex_near, ey = 50, 82, 84
    specs_y = ey + (6 if mood == 'warm' else 0)
    # cheeks
    F += kit.blush(94, 101, TFACE, 10, 6, lines=(mood == 'proud'), op=0.75 if mood == 'proud' else 0.6)
    F += kit.blush(40, 101, TFACE, 7.4, 5, lines=(mood == 'proud'), op=0.75 if mood == 'proud' else 0.6)
    near, far = (ex_near, ey, 15, 18), (ex_far, ey, 12.4, 16.4)
    if mood in ('warm', 'proud'):
        for (x, y, w, h) in (far, near):
            F += kit.eye(ctx, x, y + (0 if mood == 'proud' else -3), w + 2, h * 0.78, TFACE, mood='happy')
    else:
        look = (-2.2, 0.6) if mood != 'sad' else (-1.4, 2.6)
        for (x, y, w, h) in (far, near):
            F += kit.eye(ctx, x, y, w, h, TFACE, look=look)
    if mood == 'worried':
        F += kit.worried_brows([far, near], TFACE, lift=7, thick=3.4)
    elif mood == 'stern':
        F += kit.brow_fill(38, 64, 58, 70, TFACE, 3.8, bend=-1) + kit.brow_fill(72, 70, 94, 63, TFACE, 4.2, bend=-1)
    elif mood == 'sad':
        F += kit.worried_brows([far, near], TFACE, lift=7, thick=3.2)
        F += kit.tears([far, near], streams=True)
    else:
        F += kit.eager_brows([(far[0], far[1] - 2, far[2], far[3]), (near[0], near[1] - 2, near[2], near[3])], TFACE, lift=8, w=2.8)
    # the round spectacles (low on her nose when she's warm)
    for (x, r) in ((ex_far, 12.6), (ex_near, 14.6)):
        F += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="#ffffff" fill-opacity="0.14" stroke="%s" stroke-width="3.6"/>' % (x, specs_y, r, T['trim_sh'])
        F += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="none" stroke="%s" stroke-width="1.9"/>' % (x, specs_y, r, T['trim'])
        F += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (x - r * 0.6, specs_y - r * 0.2, x - r * 0.5, specs_y - r * 0.62, x - r * 0.1, specs_y - r * 0.72),
                  '#ffffff', 1.8, op=0.8)
    F += line('M%.1f %.1f Q66 %.1f %.1f %.1f' % (ex_far + 12.4, specs_y - 1, specs_y - 6, ex_near - 14.4, specs_y - 1), T['trim_sh'], 2.6)
    F += line('M%.1f %.1f L%.1f %.1f' % (ex_far - 12.6, specs_y - 2, 26, specs_y - 6), T['trim_sh'], 2.4)
    if mood == 'stern':
        # a glint across the near lens hides the eye: she means it
        F += '<circle cx="%.1f" cy="%.1f" r="12.4" fill="#ffffff" opacity="0.55"/>' % (ex_near, specs_y)
        F += sparkle(ex_near + 6, specs_y - 6, 6, T['line'], '#ffffff')
    # the nose and the mouth
    F += '<ellipse cx="62" cy="99" rx="5" ry="4.2" fill="%s"/>' % T['skin_sh'] + dot(60.4, 97.4, 1.5, '#ffffff', 0.8)
    if mood == 'proud':
        F += kit.mouth_open(62, 106, 18, 11, TFACE)
    elif mood == 'warm':
        F += line('M52 107 Q62 114 72 106', T['line'], 2.6)
    elif mood == 'worried':
        F += kit.mouth_frown(62, 110, 12, TFACE)
    elif mood == 'stern':
        F += line('M53 109 L71 108', T['line'], 2.8)
    else:
        F += ('<path d="M52 111 Q55 107 58 110 Q61 107 64 110 Q67 107 72 110" fill="none" stroke="%s" stroke-width="2.4" '
              'stroke-linecap="round" stroke-linejoin="round"/>') % T['line']
    parts.append(Part('fill', pth(face_d), fill=T['skin'], shade=T['skin_sh'], off=(-4, -3), over=F))
    # the nub of candle in its battered brass holder, buckled to the front of
    # the hood (low enough that the dialogue box's crop keeps it: the flame
    # sits inside the circle, the holder under it in full)
    ny = NUB_Y
    parts.append(LIMB('M50 %.1f Q70 %.1f 94 %.1f' % (ny + 12, ny - 2, ny + 12), T['leather'], 5.4))
    parts.append(P(rrect_d(86, ny + 4, 96, ny + 14, 2), T['trim'], T['trim_sh'], off=(-1, -1)))
    parts.append(P('M60 %.1f L82 %.1f Q81 %.1f 71 %.1f Q61 %.1f 60 %.1f Z' % (ny, ny, ny + 8, ny + 9, ny + 8, ny), T['trim'], T['trim_sh'],
                   off=(-2, -2), over=line('M75 %.1f l2.6 5' % (ny + 1), T['trim_sh'], 1.4),
                   hl=line('M63 %.1f L71 %.1f' % (ny + 1.6, ny + 1.6), GOLD_HI, 1.4, op=0.9)))
    cp, wk, tip = candle(ctx, 71, ny + 0.6, 11, 8, T['line'], drips=((0.25, 0.3), (0.7, 0.44)))
    parts += cp
    parts[-1].over += wk
    if mood == 'worried':
        # a small hand at her cheek
        parts.append(P('M92 128 C90 118 94 108 102 106 C106 100 112 100 112 106 C116 104 120 108 116 114 C118 118 114 124 108 126 Z',
                       T['skin'], T['skin_sh'], off=(-2, -2),
                       over=line('M104 108 L108 116 M110 106 L113 113', T['line'], 1.2, op=0.7)))
    s += render(ctx, parts, T['line'], T['plum'])
    return doc(ctx, s), [pt(tip[0], tip[1], 13)]


# ================================================================ Waxley

def waxley(mood):
    ctx = Ctx('pw' + mood[:3])
    X = WAXLEY
    s = disc(ctx, '#5a4028', '#221610')
    parts = []
    # shoulders: the mustard shirt and the apron's strap
    parts.append(P('M4 150 C8 122 40 112 72 112 C104 112 136 122 140 150 Z', X['shirt'], X['shirt_sh'], off=(-8, -4),
                   over=line('M48 116 L40 150 M96 116 L104 150', X['apron'], 7)))
    if mood == 'shifty':
        # rubbing his hands together, just in view
        parts.append(P('M40 146 C38 132 48 124 60 126 C66 122 74 126 72 134 C74 140 66 148 56 148 Z', X['skin'], X['skin_sh'], off=(-2, -2),
                       over=line('M52 130 L58 140 M60 128 L66 138', X['line'], 1.3, op=0.7)))
        parts.append(P('M104 146 C106 132 96 124 84 126 C78 122 70 126 72 134 C70 140 78 148 88 148 Z', X['skin'], X['skin_sh'], off=(-2, -2)))
    # the face
    fx, fy = 70, 84
    head = kit.head_tpl(fx, fy, 88, 80)
    F = ''
    F += kit.blush(38, 96, WFACE, 10, 6, lines=True, op=0.65) + kit.blush(104, 96, WFACE, 9, 6, lines=True, op=0.65)
    if mood == 'grin':
        for x, w in ((46, 18), (92, 20)):
            F += line('M%.1f 82 Q%.1f 70 %.1f 82' % (x - w / 2, x, x + w / 2), X['line'], 4.2)
        F += kit.brow_fill(34, 64, 56, 62, dict(line=X['brow']), 5.4, bend=-4) + kit.brow_fill(82, 62, 106, 64, dict(line=X['brow']), 5.6, bend=-4)
    elif mood == 'shifty':
        W2 = dict(WFACE)
        for x, w, h in ((46, 16, 18), (92, 18, 20)):
            F += kit.eye(ctx, x, 80, w, h, W2, look=(-4.4, 0.6), lid=0.36)
        F += kit.brow_fill(34, 64, 56, 66, dict(line=X['brow']), 5.2, bend=-1) + kit.brow_fill(80, 60, 104, 52, dict(line=X['brow']), 5.6, bend=-5)
    else:
        for x in (46, 92):
            F += '<circle cx="%d" cy="78" r="9" fill="#ffffff" stroke="%s" stroke-width="2.4"/>' % (x, X['line']) + dot(x, 78, 3.2, X['line'])
        F += kit.brow_fill(32, 56, 56, 58, dict(line=X['brow']), 5, bend=-6) + kit.brow_fill(82, 58, 106, 56, dict(line=X['brow']), 5, bend=-6)
    # the mouth, then the great mustache over it
    if mood == 'grin':
        F += kit.mouth_open(70, 110, 30, 14, WFACE, teeth=True)
    elif mood == 'shifty':
        F += line('M60 113 Q70 117 82 110', X['line'], 3)
    else:
        F += '<ellipse cx="70" cy="116" rx="8" ry="10" fill="%s"/><ellipse cx="70" cy="120" rx="5" ry="4" fill="#ff7f7f"/>' % X['line']
    lm, rm = mustache(70, 102, 56, 16, up=1.2 if mood == 'shock' else 0.25)
    wl = '#8a7050'
    for d in (lm, rm):
        F += '<path d="%s" fill="%s" stroke="%s" stroke-width="3.2" stroke-linejoin="round"/>' % (d, WAX, wl)
    F += line('M42 98 Q54 92 66 98 M76 98 Q88 92 100 98', '#ffffff', 2.6, op=0.8)
    if mood != 'shock':
        F += wax_drips(70, 106, 56, 1.1)
    F += '<ellipse cx="68" cy="92" rx="12" ry="10.4" fill="%s" stroke="%s" stroke-width="2.6"/>' % (X['nose'], X['line'])
    F += dot(64, 88, 3, '#ffffff', 0.8)
    if mood == 'shock':
        F += kit.sweat(116, 72, 1.3, 20)
    parts.append(Part('fill', head, fill=X['skin'], shade=X['skin_sh'], off=(-5, -5), over=F))
    parts.append(E(122, 86, 7, 11, X['skin'], X['skin_sh'], off=(-1, -1)))
    # the wide hat, two of its brim candles in view
    parts.append(P('M28 52 C26 22 44 6 72 6 C100 6 118 22 116 52 Z', X['hat'], X['hat_sh'], off=(-7, -5),
                   over='<path d="M28 40 Q72 50 116 40 L116 50 Q72 60 28 50 Z" fill="#3a2410"/>'
                   + '<rect x="84" y="41" width="12" height="11" rx="2" fill="%s" stroke="%s" stroke-width="1.8"/>' % (X['brass'], X['line'])))
    parts.append(Part('fill', ell(72, 54, 82, 15), fill=X['hat'], shade=X['hat_sh'], off=(-4, -5),
                      over=line('M-4 52 Q72 40 148 52', '#8a6440', 2.4, op=0.9)))
    tips = []
    for x in (40, 104):
        yb = 60
        cp, wk, tip = candle(ctx, x, yb, 11, 16, X['line'], drips=((0.25, 0.6), (0.75, 0.9)))
        parts += cp
        parts[-1].over += wk
        tips.append(tip)
    s += render(ctx, parts, X['line'], X['shirt'])
    if mood == 'shock':
        s += line('M14 20 L6 10 M130 20 L138 10 M72 0 L72 -6', X['line'], 2.6)
    return doc(ctx, s), [pt(t[0], t[1], 15) for t in tips]


# ================================================================ Old Tollgrave

def tollgrave(mood):
    import boss
    from enemies import BONE, BONE_SH, BONE_LINE, TEAL
    ctx = Ctx('pg' + mood[:3])
    s = disc(ctx, '#2e2a48' if mood == 'hushed' else '#4a3a38', '#100c1a')
    parts = []
    parts.append(P('M2 150 C6 120 38 108 72 108 C106 108 138 120 142 150 Z', boss.ROBE, boss.ROBE_SH, off=(-8, -4),
                   over=line('M30 124 Q72 138 114 124', boss.CORD, 5)))
    if mood == 'hushed':
        hood = 'M72 8 C112 8 136 36 136 74 C136 104 122 122 104 128 L40 128 C22 122 8 104 8 74 C8 36 32 8 72 8 Z'
        opening = ell_d(66, 80, 44, 46)
        inner = '<path d="%s" fill="#06030a"/>' % opening
        haze = ctx.radgrad([(0, '#6a4aa0', 0.6), (0.6, '#4a3a7a', 0.3), (1, '#4a3a7a', 0)])
        face = ''
        face += '<path d="%s" fill="%s"/>' % (ell_d(66, 82, 34, 34), mix(BONE, '#8ab8b0', 0.3))
        face += '<path d="%s" fill="%s"/>' % (ell_d(74, 90, 22, 22), mix(BONE_SH, '#5a8a84', 0.35))
        face += '<path d="%s" fill="%s"/>' % (ell_d(64, 80, 31, 32), mix(BONE, '#8ab8b0', 0.3))
        shadow = ctx.lingrad([(0, '#06030a', 1), (0.45, '#06030a', 0.85), (1, '#06030a', 0)])
        face += '<path d="%s" fill="%s"/>' % (ell_d(64, 50, 46, 24), shadow)
        face += '<path d="%s" fill="%s"/>' % (ell_d(66, 80, 44, 46), haze)
        # the jaw clenched: a hard straight row of teeth
        face += '<path d="M44 102 L90 100 L90 108 L44 110 Z" fill="%s"/>' % BONE_LINE
        face += ''.join('<rect x="%.1f" y="%.1f" width="5.4" height="6" rx="1" fill="#f4eee0"/>' % (46 + i * 7.4, 102.2 - i * 0.2) for i in range(6))
        face += '<path d="M66 92 C62 89 60 94 66 98 C71 94 70 89 66 92 Z" fill="%s"/>' % BONE_LINE
        from enemies import glow_eye
        face += glow_eye(ctx, 50, 78, 22, 20, look=(-1.4, 0), iris=0.42) + glow_eye(ctx, 82, 77, 20, 19, look=(-1.4, 0), iris=0.42)
        face += '<path d="M34 70 L60 76 L60 70 Z M100 69 L74 75 L74 69 Z" fill="#06030a"/>'
        edge = '<path d="%s" fill="none" stroke="%s" stroke-width="6"/>' % (ell_d(66, 80, 46, 48), boss.ROBE_HI)
        clip = ctx.clip('<path d="%s"/>' % opening)
        parts.append(P(hood, boss.ROBE, boss.ROBE_SH, off=(-8, -7),
                       over=inner + '<g clip-path="%s">%s</g>' % (clip, face) + edge,
                       hl=spec(36, 30, 12, 4, rot=-40, op=0.35)))
        s += render(ctx, parts, boss.L, boss.ROBE)
        s += '<ellipse cx="66" cy="78" rx="52" ry="30" fill="%s"/>' % ctx.radgrad([(0, TEAL, 0.18), (1, TEAL, 0)])
    else:
        # hood fallen back; a bare, kind old skull; wisps of white hair, a beard tuft
        parts.append(P('M14 118 C8 84 30 60 72 58 C114 60 136 84 130 118 Z', boss.ROBE, boss.ROBE_SH, off=(-6, -6),
                       over=line('M24 100 Q30 76 60 66', boss.ROBE_HI, 3, op=0.7)))
        sx, sy = 68, 70
        jaw = 'M44 92 C44 110 58 118 70 118 C84 118 96 110 96 92 Z'
        parts.append(Part('fill', pth(jaw), fill=BONE, shade=BONE_SH, off=(-2, -2), line=BONE_LINE))
        face = ''
        from enemies import glow_eye
        for ex, ey, w, h in ((54, 72, 22, 23), (86, 71, 19, 21)):
            face += glow_eye(ctx, ex, ey, w, h, look=(-1.2, 0.8), iris=0.36, col='#f7b64a')
        face += '<path d="M70 84 C66 81 64 86 70 90 C75 86 74 81 70 84 Z" fill="%s"/>' % BONE_LINE
        face += '<path d="M46 96 Q70 112 94 95 L94 100 Q70 118 46 101 Z" fill="%s"/>' % BONE_LINE
        for i in range(7):
            t = (i + 0.5) / 7.0
            x = 47 + t * 46
            y = 96 + 9.6 * math.sin(t * math.pi)
            face += '<rect x="%.1f" y="%.1f" width="4.6" height="4.4" rx="1" fill="#fffaf0"/>' % (x - 2.3, y)
        face += kit.blush(38, 92, dict(blush='#ff9a8a'), 6, 3.4, lines=False, op=0.45) + kit.blush(100, 90, dict(blush='#ff9a8a'), 5, 3, lines=False, op=0.45)
        parts.append(Part('fill', kit.head_tpl(sx, sy, 84, 76, squish=-0.08), fill=BONE, shade=BONE_SH, off=(-5, -5), line=BONE_LINE,
                          over=face, hl=spec(42, 48, 9, 4.4, rot=-38, op=0.95) + dot(54, 40, 2.4, '#ffffff', 0.9)))
        beard = 'M58 114 C50 126 56 140 66 146 C66 138 72 134 70 130 C76 136 82 132 84 116 C76 120 66 120 58 114 Z'
        parts.append(Part('fill', pth(beard), fill='#f8f4ff', shade='#c8c0d8', off=(-2, -2), line=BONE_LINE,
                          over=line('M68 122 Q68 132 70 138', '#c8c0d8', 1.6)))
        s += render(ctx, parts, boss.L, boss.ROBE)
        s += soft_hair(sx - 2, sy - 34, 1.3)
    return doc(ctx, s), []


# ================================================================ the Snuffer

def snuffer(mood):
    """The fight's cone head (story_snuffer.py) filling the circle, turned to
    face left, over his white collar: cold is the calm pinprick stare; wrath
    the glaring roar, a crack up the iron and smoke pouring off it."""
    ctx = Ctx('ps' + mood[:3])
    wrath = mood == 'wrath'
    s = disc(ctx, '#6a3a58' if wrath else '#5a5478', '#141020')
    # shoulders: the cassock, its white collar and the top buttons
    parts = [P('M-2 150 C4 124 36 112 76 112 C116 112 142 124 148 150 Z', SN.CASSOCK, SN.CASSOCK_SH, off=(-8, -4),
               over=line('M34 128 Q30 140 28 150 M116 126 Q122 138 124 150', SN.CASSOCK_SH, 3, op=0.9)
               + ''.join('<circle cx="%.1f" cy="%.1f" r="2.8" fill="%s" stroke="%s" stroke-width="1.4"/>' % (
                   x, y, mix(SN.BRASS, SN.CASSOCK, 0.35), SN.L) for x, y in ((72, 130), (71, 141)))),
             P('M36 116 C54 106 100 106 118 116 L116 126 C98 118 56 118 38 126 Z', '#d6d0e4', '#a09ab8', off=(-2, -2))]
    s += render(ctx, parts, SN.L, SN.CASSOCK)
    k = 1.05
    face = (70, 80)
    lw = tuple(w / k for w in NATIVE_W)
    if wrath:
        # smoke boiling off him, behind the head
        s += SN.smoke_curl(124, 70, 1.15, 0.8) + SN.smoke_curl(136, 100, 0.8, 0.65) + SN.smoke_curl(104, 30, 0.95, 0.8)
        s += SN.smoke_curl(20, 66, 0.9, 0.6) + SN.smoke_curl(34, 40, 0.7, 0.5)
    # wrath leans in, the cone tipped toward the box
    head, fx, t = SN.portrait_head(ctx, 'roar' if wrath else 'idle', face, k, lw, rot=-7 if wrath else 0)
    s += head + fx
    if wrath:
        # a crack up the iron (the side away from his face) and a notch in the rim
        crack = 'M-34 -4 L-30 -14 L-37 -22 L-29 -33 L-33 -44 L-27 -52'
        s += gx(line(crack, SN.L, 3.6) + line(crack, SN.IRON_HI, 1.0, op=0.9), t)
        s += gx('<path d="M-40 -8 L-34 -1 L-28 -8 Z" fill="%s"/>' % SN.VOID, t)
        # the chibi anger ticks by his brow
        s += line('M22 44 L12 36 M28 36 L24 24 M16 54 L4 52', SN.L, 5.4) + line('M22 44 L12 36 M28 36 L24 24 M16 54 L4 52', '#ff9ab8', 2.6)
    return doc(ctx, s), []


# ================================================================ Hollin

def hollin(mood):
    ctx = Ctx('ph' + mood[:3])
    H = HOL
    lost = mood == 'lost'
    s = disc(ctx, '#34384a' if lost else '#5a3e30', '#10121c' if lost else '#1e140e')
    parts = []
    parts.append(P('M4 152 C8 124 38 114 72 114 C106 114 136 124 140 152 Z', H['tabard'], H['tabard_sh'], off=(-8, -4),
                   over='<path d="%s" fill="%s" opacity="0.7"/>' % (flame_d(72, 146, 16, 24, 1), H['trim'])))
    skin, sk_sh = (H['ash'], H['ash_sh']) if lost else (H['warm'], H['warm_sh'])
    fx, fy = 70, 84 if lost else 90
    F = ''
    Fp = HCOLD if lost else HWARM
    far, near = (50, fy - 2, 21, 26), (86, fy - 3, 24, 28)
    if lost:
        for (x, y, w, h) in (far, near):
            F += kit.eye(ctx, x, y, w, h, Fp, look=(-1.4, 4.4))
        F += kit.worried_brows([far, near], Fp, lift=7, thick=3.4)
        F += kit.tears([far, near], streams=True)
        F += kit.mouth_frown(66, fy + 26, 14, Fp)
    else:
        for (x, y, w, h) in (far, near):
            F += kit.eye(ctx, x, y + 2, w + 2, h * 0.74, Fp, mood='happy')
        F += kit.tears([far, near], streams=True)
        F += kit.blush(36, fy + 16, Fp, 9, 5.4) + kit.blush(102, fy + 14, Fp, 8, 5)
        F += kit.mouth_open(66, fy + 20, 20, 12, Fp)
    parts.append(Part('fill', kit.head_tpl(fx, fy, 104, 90), fill=skin, shade=sk_sh, off=(-5, -5), over=F))
    parts.append(E(122, fy + 4, 7, 11, skin, sk_sh, off=(-1, -1)))
    parts.append(messy_hair(fx, fy - 8, 110, 80 if lost else 64, H['hair'], H['hair_hi'], H['line']))
    flames = []
    if not lost:
        # the helm sits a little lower and its stub is shorter than on the
        # figure, so the crop keeps the flame and its cup
        helm, tip = dented_helm(ctx, fx - 2, 26, 112, stub=7)
        parts += helm
        flames = [pt(tip[0], tip[1], 13)]
    s += render(ctx, parts, H['line'], H['tabard'])
    return doc(ctx, s), flames


# ================================================================ all

CAST = [('taper', ['warm', 'worried', 'stern', 'sad', 'proud'], 'f2c75a', taper),
        ('waxley', ['grin', 'shifty', 'shock'], 'f7b64a', waxley),
        ('tollgrave', ['hushed', 'kind'], '7ef0c8', tollgrave),
        ('snuffer', ['cold', 'wrath'], 'c9c2f0', snuffer),
        ('hollin', ['lost', 'relit'], 'a8b8d0', hollin)]


def portraits():
    out = {}
    files = {}
    for who, moods, col, fn in CAST:
        per = {}
        for mood in moods:
            svg, flames = fn(mood)
            files['art/story/portraits/%s_%s.svg' % (who, mood)] = svg
            per[mood] = flames
        first = per[moods[0]]
        # flame: the first mood's first live flame, left out when it has
        # none (a reader takes flame as an array); flames lists them all
        entry = {'moods': moods, 'color': col}
        if first:
            entry['flame'] = first[0]
        entry['flames'] = first
        differs = {m: f for m, f in per.items() if f != first}
        if differs:
            entry['mood_flames'] = differs
        out[who] = entry
    return out, files
