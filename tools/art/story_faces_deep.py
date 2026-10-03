"""The deeper worlds' dialogue portraits (v3, A5), in the v2 portraits'
frame and style (story_faces.py): head and shoulders in the 128 frame, face
near (64, 62), px 6, drawn in native units on a 144 box and scaled by 8/9;
the dialogue box crops them to the circle of radius 53.8 around (64, 62),
so every live flame and its holder sits inside it. NPCs turn a little
left, toward the box's middle.

  taper      + faint                 (her nub flame at 0.35 of its height)
  hollin     + worried, grin         (the helm's candle is live)
  rootmother keeping, wrath          (Mother Gravebough)
  yarrow     gentle, merry           (her hood's stub is live)
  tinker     ticking, wrath
  tickwell   dazed, kind
  saint      serene, wrath           (the Prism Saint)
  tessel     gentle, sad
  hush       open                    (its HUD and boss-card portrait)
  echo       glow                    (the six Lost Wicks, through CAST "face")

These are also the credits' cast roll (decisions.md, the owner's Q5).
"""
import math

import kit
from kit import Part, pth
from common import Ctx, GOLD_HI, line, dot, flame_d, spec, mix
from story_kit import NATIVE_W, P, E, LIMB, rrect_d, ell_d, candle, portrait_fit, portrait_pt, radial
from story_figs import TAPER, TFACE, HOL, HWARM, messy_hair, dented_helm, clipped, render

PX = 6
C = 72.0


def disc(ctx, inner, outer):
    """The portrait's own background: a soft disc filling the crop circle."""
    g = ctx.radgrad([(0, inner), (1, outer)], cx=0.45, cy=0.38, r=0.62)
    return '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s"/>' % (C, C, C, g)


def pt(x, y, h):
    fx, fy = portrait_pt(x, y)
    return [fx, fy, round(h * 8.0 / 9.0, 2)]


def doc(ctx, body):
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 128 128">\n'
            '<defs>%s</defs>\n%s\n</svg>\n') % (128 * PX, 128 * PX, ''.join(ctx.defs), portrait_fit(body))


NUB_Y = 27.0      # the top of Taper's nub-candle holder (story_faces.py)


def taper_faint(mood):
    """Mother Taper faint (from the_pull until the finale): the v2 portrait's
    hood, spectacles and nub candle (story_faces.taper), with her eyes half
    shut and heavy, pale cheeks, a small brave smile and a blanket round her
    shoulders; the nub's flame is tiny (0.35 of its height)."""
    ctx = Ctx('ptfa')
    T = TAPER
    s = disc(ctx, '#3a2a44', '#141020')
    parts = []
    # shoulders wrapped in the patchwork blanket from her chair
    blanket = 'M4 150 C6 122 36 108 72 108 C108 108 138 122 140 150 Z'
    patches = ''
    for i, (x0, y0, c) in enumerate(((10, 132, '#c86a5a'), (40, 118, '#6a8ac8'), (74, 116, '#d8b24a'), (104, 120, '#7aa86a'),
                                     (26, 140, '#8a6ab0'), (92, 138, '#c86a5a'), (60, 134, '#6a8ac8'), (120, 138, '#d8b24a'))):
        patches += '<path d="%s" fill="%s"/>' % (rrect_d(x0, y0, x0 + 26, y0 + 20, 3), c)
    stitches = ''.join(line('M%.1f %.1f l3 3' % (x, y), '#f4ead6', 1.2, op=0.8) for x, y in ((36, 126), (70, 124), (100, 128), (56, 144), (88, 146)))
    parts.append(Part('fill', pth(blanket), fill='#a85a60', shade='#7a3e48', off=(-8, -4),
                      over=clipped(ctx, blanket, patches) + stitches))
    hood = 'M72 16 C108 16 132 40 132 72 C132 100 118 118 100 124 L44 124 C26 118 12 100 12 72 C12 40 36 16 72 16 Z'
    tail = 'M112 34 C130 30 142 44 140 66 C136 56 128 50 118 50 Z'
    parts.append(P(tail, T['plum'], T['plum_sh'], off=(-3, -3)))
    fx, fy = 66, 80
    opening = ell_d(fx, fy, 42, 40)
    face_d = ell_d(fx + 1, fy + 2, 37, 35)
    trim = ('<path d="%s" fill="none" stroke="%s" stroke-width="4.6"/>' % (ell_d(fx, fy, 42.6, 40.6), T['trim_sh'])
            + '<path d="%s" fill="none" stroke="%s" stroke-width="2.4"/>' % (ell_d(fx, fy, 42.6, 40.6), T['trim']))
    parts.append(P(hood, T['plum'], T['plum_sh'], off=(-9, -7),
                   over='<path d="%s" fill="%s"/>' % (opening, T['plum_in']) + trim + line('M24 60 Q22 90 36 112', T['plum_hi'], 3, op=0.6),
                   hl=spec(44, 32, 12, 4.4, rot=-35, op=0.35)))
    F = ''
    fringe = 'M20 38 L112 38 L110 66 Q102 58 96 66 Q90 56 82 64 Q76 54 68 62 Q60 53 54 63 Q46 55 40 65 Q32 58 26 68 Z'
    F += clipped(ctx, face_d, '<path d="%s" fill="%s"/><path d="%s" fill="none" stroke="%s" stroke-width="1.6"/>' % (
        fringe, T['hair'], fringe, T['hair_sh']))
    ex_far, ex_near, ey = 50, 82, 86
    # pale cheeks: only a ghost of the blush
    F += kit.blush(94, 101, TFACE, 9, 5, lines=False, op=0.28)
    F += kit.blush(40, 101, TFACE, 7, 4.4, lines=False, op=0.28)
    near, far = (ex_near, ey, 15, 18), (ex_far, ey, 12.4, 16.4)
    for (x, y, w, h) in (far, near):
        F += kit.eye(ctx, x, y, w, h, TFACE, look=(-1.4, 1.6), lid=0.52)
    # tired shadows under the eyes
    for (x, y, w, h) in (far, near):
        F += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (x - w * 0.4, y + h * 0.62, x, y + h * 0.8, x + w * 0.4, y + h * 0.62), '#b88a9a', 1.6, op=0.7)
    for (x, r) in ((ex_far, 12.6), (ex_near, 14.6)):
        F += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="#ffffff" fill-opacity="0.12" stroke="%s" stroke-width="3.6"/>' % (x, ey + 2, r, T['trim_sh'])
        F += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="none" stroke="%s" stroke-width="1.9"/>' % (x, ey + 2, r, T['trim'])
    F += line('M%.1f %.1f Q66 %.1f %.1f %.1f' % (ex_far + 12.4, ey + 1, ey - 4, ex_near - 14.4, ey + 1), T['trim_sh'], 2.6)
    F += line('M%.1f %.1f L%.1f %.1f' % (ex_far - 12.6, ey, 26, ey - 4), T['trim_sh'], 2.4)
    F += '<ellipse cx="62" cy="100" rx="5" ry="4.2" fill="%s"/>' % T['skin_sh'] + dot(60.4, 98.4, 1.5, '#ffffff', 0.8)
    # a small brave smile
    F += line('M55 109 Q62 113 70 108', T['line'], 2.4)
    parts.append(Part('fill', pth(face_d), fill=mix(T['skin'], '#e8e0e8', 0.35), shade=T['skin_sh'], off=(-4, -3), over=F))
    ny = NUB_Y
    parts.append(LIMB('M50 %.1f Q70 %.1f 94 %.1f' % (ny + 12, ny - 2, ny + 12), T['leather'], 5.4))
    parts.append(P(rrect_d(86, ny + 4, 96, ny + 14, 2), T['trim'], T['trim_sh'], off=(-1, -1)))
    parts.append(P('M60 %.1f L82 %.1f Q81 %.1f 71 %.1f Q61 %.1f 60 %.1f Z' % (ny, ny, ny + 8, ny + 9, ny + 8, ny), T['trim'], T['trim_sh'],
                   off=(-2, -2), over=line('M75 %.1f l2.6 5' % (ny + 1), T['trim_sh'], 1.4),
                   hl=line('M63 %.1f L71 %.1f' % (ny + 1.6, ny + 1.6), GOLD_HI, 1.4, op=0.9)))
    cp, wk, tip = candle(ctx, 71, ny + 0.6, 11, 8, T['line'], drips=((0.25, 0.3), (0.7, 0.44)))
    parts += cp
    parts[-1].over += wk
    s += render(ctx, parts, T['line'], T['plum'])
    return doc(ctx, s), [pt(tip[0], tip[1], 13 * 0.35)]


def hollin_more(mood):
    """Hollin, warm and helmed (the relit portrait's head, story_faces.hollin):
    worried (brows up and together, his lip bitten) or grin (a big
    gap-toothed grin, blush). The helm's candle is live."""
    ctx = Ctx('ph' + mood[:3])
    H = HOL
    s = disc(ctx, '#4a3a4a' if mood == 'worried' else '#5a3e30', '#16121c' if mood == 'worried' else '#1e140e')
    parts = []
    parts.append(P('M4 152 C8 124 38 114 72 114 C106 114 136 124 140 152 Z', H['tabard'], H['tabard_sh'], off=(-8, -4),
                   over='<path d="%s" fill="%s" opacity="0.7"/>' % (flame_d(72, 146, 16, 24, 1), H['trim'])))
    fx, fy = 70, 90
    F = ''
    Fp = HWARM
    far, near = (50, fy - 2, 21, 26), (86, fy - 3, 24, 28)
    if mood == 'worried':
        for (x, y, w, h) in (far, near):
            F += kit.eye(ctx, x, y + 4, w, h * 0.86, Fp, look=(-1.0, 1.4))
        # (the brows ride over the helm's brim, the chibi way, so they show)
        brows = kit.worried_brows([(far[0], far[1] + 6, far[2], far[3]), (near[0], near[1] + 6, near[2], near[3])], Fp, lift=3, thick=4.0)
        # the lower lip caught in his teeth
        F += ('<path d="M58 %.1f Q66 %.1f 74 %.1f" fill="none" stroke="%s" stroke-width="2.6" stroke-linecap="round"/>' % (
            fy + 22, fy + 19, fy + 22, H['line']))
        F += '<rect x="62" y="%.1f" width="3.4" height="3" rx="0.6" fill="#ffffff" stroke="%s" stroke-width="0.8"/>' % (fy + 20.4, H['line'])
        F += '<rect x="66" y="%.1f" width="3.4" height="3" rx="0.6" fill="#ffffff" stroke="%s" stroke-width="0.8"/>' % (fy + 20.4, H['line'])
        F += kit.sweat(110, fy - 4, 0.9)
    else:
        for (x, y, w, h) in (far, near):
            F += kit.eye(ctx, x, y + 2, w + 2, h * 0.74, Fp, mood='happy')
        F += kit.blush(36, fy + 16, Fp, 9, 5.4) + kit.blush(102, fy + 14, Fp, 8, 5)
        # the big grin, a gap in the front teeth
        F += '<path d="M48 %.1f Q66 %.1f 86 %.1f Q80 %.1f 66 %.1f Q52 %.1f 48 %.1f Z" fill="%s"/>' % (
            fy + 14, fy + 16, fy + 13, fy + 32, fy + 33, fy + 30, fy + 14, H['line'])
        F += '<path d="M52 %.1f Q66 %.1f 83 %.1f L82 %.1f Q66 %.1f 53 %.1f Z" fill="#ffffff"/>' % (fy + 15.4, fy + 17.2, fy + 14.4, fy + 19, fy + 21, fy + 19.6)
        F += line('M66 %.1f L66.4 %.1f' % (fy + 16.6, fy + 21), H['line'], 2.2)
        F += '<path d="M58 %.1f Q66 %.1f 76 %.1f Q70 %.1f 66 %.1f Q62 %.1f 58 %.1f Z" fill="%s"/>' % (
            fy + 28, fy + 24, fy + 28, fy + 31.6, fy + 31.8, fy + 31.6, fy + 28, kit.TONGUE)
    parts.append(Part('fill', kit.head_tpl(fx, fy, 104, 90), fill=H['warm'], shade=H['warm_sh'], off=(-5, -5), over=F))
    parts.append(E(122, fy + 4, 7, 11, H['warm'], H['warm_sh'], off=(-1, -1)))
    parts.append(messy_hair(fx, fy - 8, 110, 64, H['hair'], H['hair_hi'], H['line']))
    helm, tip = dented_helm(ctx, fx - 2, 26, 112, stub=7)
    parts += helm
    s += render(ctx, parts, H['line'], H['tabard'])
    if mood == 'worried':
        s += brows
    return doc(ctx, s), [pt(tip[0], tip[1], 13)]


def rootmother(mood):
    """Mother Gravebough's head from the fight (story_rootmother.portrait:
    boss3.py's wimple, moss, carved face and crown): keeping, the eyes nearly
    shut over their glow, a smile, a skull fruit hanging by her cheek; wrath,
    the eye-lights flared green-white under a frown, a roar, roots curling in
    at the frame's edges. No live flame (the voice is hers)."""
    import story_rootmother as RM
    ctx = Ctx('prm' + mood[:3])
    wrath = mood == 'wrath'
    s = disc(ctx, '#4a5a34' if not wrath else '#4a3420', '#10140c')
    s += RM.portrait(ctx, mood, NATIVE_W)
    return doc(ctx, s), []


def yarrow(mood):
    """Mother Yarrow: Taper's roundness, older and see-through, a soft smile,
    yarrow in her straw-brimmed hood, her stub flame lit (merry: laughing,
    eyes creased shut)."""
    from story_figs_deep import YARROW, yarrow_face, yarrow_umbel
    ctx = Ctx('pya' + mood[:2])
    Y = YARROW
    s = disc(ctx, '#4a5a34', '#141a0e')
    parts = []
    parts.append(P('M4 152 C8 124 38 112 72 112 C106 112 136 124 140 152 Z', Y['habit'], Y['habit_sh'], off=(-8, -4),
                   over='<path d="M50 114 L94 114 L100 152 L44 152 Z" fill="%s"/>' % Y['apron']))
    hood = 'M72 22 C106 22 128 44 128 74 C128 100 114 116 98 122 L46 122 C30 116 16 100 16 74 C16 44 38 22 72 22 Z'
    parts.append(P(hood, Y['habit'], Y['habit_sh'], off=(-8, -6), over='<path d="%s" fill="#5a6a40"/>' % ell_d(70, 82, 40, 38)))
    face_d = ell_d(71, 84, 35, 33)
    F = clipped(ctx, face_d, '<path d="M30 60 Q70 44 112 60 Q70 70 30 60 Z" fill="#f8f4ec"/>')
    F += yarrow_face(ctx, 70, 84, 2.0, mood)
    if mood == 'merry':
        F += line('M28 56 l-8 -6 M26 66 l-10 -2 M116 58 l8 -6', Y['line'], 2.4, op=0.7)
    parts.append(Part('fill', pth(face_d), fill=Y['skin'], shade=Y['skin_sh'], off=(-4, -3), over=F))
    brim = 'M-2 48 C20 18 116 14 146 44 C112 34 34 34 -2 48 Z'
    weave = ''.join(line('M%.1f %.1f L%.1f %.1f' % (10 + i * 16, 40 - (8 if 1 < i < 7 else 2), 6 + i * 16, 46), Y['straw_sh'], 1.6, op=0.8)
                    for i in range(9))
    parts.append(P(brim, Y['straw'], Y['straw_sh'], off=(-3, -2), over=weave))
    parts += yarrow_umbel(20, 34, 1.8) + yarrow_umbel(36, 24, 1.4)
    cp, wk, tip = candle(ctx, 84, 40, 13, 10, Y['line'], drips=((0.25, 0.3), (0.7, 0.4)), wax='#f4f0dc', wax_sh='#d0c8a8')
    parts += cp
    parts[-1].over += wk
    s += '<g opacity="0.82">%s</g>' % render(ctx, parts, Y['line'], Y['habit']).replace('#ffeccc', '#f4ffe0')
    return doc(ctx, s), [pt(tip[0], tip[1], 13)]


def tinker(mood):
    """The Tinker of Hours from the fight (story_tinker.portrait: boss4.py's
    head, bell and chest clock): ticking, the lamp-lens eyes lit and calm,
    the chest's hands frozen at one minute to midnight, frost on the rim;
    wrath, brass shutters half down over the lenses, the hands spun to odd
    angles, the dial's glass cracked."""
    import story_tinker as TK
    ctx = Ctx('ptk' + mood[:2])
    wrath = mood == 'wrath'
    s = disc(ctx, '#2a3a50' if not wrath else '#3a2a40', '#0c1018')
    s += TK.portrait(ctx, mood, NATIVE_W)
    return doc(ctx, s), []


def tickwell(mood):
    """Master Tickwell: bald, a white fringe, a bristly moustache and his
    brass magnifier goggles; dazed: the goggles askew, eyes wide and
    blinking, the moustache drooping; kind: the goggles up, a warm crinkled
    smile, the moustache lifted."""
    import story_tinker as TK
    ctx = Ctx('ptw' + mood[:2])
    dazed = mood == 'dazed'
    s = disc(ctx, '#4a4a6a' if dazed else '#5a4a3a', '#141420')
    parts = [P('M4 152 C8 124 38 114 72 114 C106 114 136 124 140 152 Z', TK.COAT, TK.COAT_SH, off=(-8, -4),
               over='<path d="M50 118 L94 118 L100 152 L44 152 Z" fill="%s"/>' % TK.APRON + ''.join(dot(72, y, 2.6, TK.BRASS) for y in (126, 140)))]
    parts.append(E(22, 84, 9, 13, TK.SKIN, TK.SKIN_SH, off=(-1, -1)))
    parts.append(Part('fill', kit.head_tpl(70, 78, 110, 96), fill=TK.SKIN, shade=TK.SKIN_SH, off=(-6, -5),
                      over=TK.tickwell_face(ctx, 74, 84, 2.1, mood, lw=0.8),
                      hl=spec(44, 44, 14, 6, rot=-35, op=0.85)))
    for side in (-1, 1):
        x = 70 + side * 54
        parts.append(P('M%.1f 70 Q%.1f 88 %.1f 108 Q%.1f 92 %.1f 70 Z' % (x, x + side * 10, x - side * 6, x - side * 10, x), TK.HAIR, '#c8c8d8',
                       off=(-1, -1)))
    s += render(ctx, parts, TK.L, TK.COAT)
    s += TK.goggles(74, 40, 2.1, tilt=(-12 if dazed else 0))
    return doc(ctx, s), []


def saint(mood):
    """The Prism Saint from the fight (story_saint.portrait: boss5.py's hood
    of panes, glass mask and halo): serene, eyes closed, cold white panes, the
    halo's rays behind; wrath, the eyes open as white slits, the glass
    cracked, the halo flaring."""
    import story_saint as SA
    ctx = Ctx('psa' + mood[:2])
    s = disc(ctx, '#4a4468' if mood == 'serene' else '#5a3a58', '#141020')
    s += SA.portrait(ctx, mood, NATIVE_W)
    return doc(ctx, s), []


def tessel(mood):
    """Tessel: the same glass head lit warm in every colour, eyes open and
    kind with a small shy smile (gentle), or looking down with one blue pane
    on her cheek like a tear (sad)."""
    import story_saint as SA
    ctx = Ctx('pts' + mood[:2])
    s = disc(ctx, '#6a4a4a', '#1e1418')
    s += SA.portrait(ctx, mood, NATIVE_W)
    return doc(ctx, s), []


def hush(mood):
    """The Hush's eye cropped to the circle (its HUD and boss-card portrait):
    a pale violet white darkening at the corners, a dim violet ring, a
    pinprick pupil with one glint, black lids; no flame."""
    ctx = Ctx('phu')
    s = '<circle cx="72" cy="72" r="72" fill="#000000"/>'
    a, b = 70, 30
    cx, cy = 72, 74
    almond = 'M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z' % (
        cx - a, cy, cx - a * 0.5, cy - b * 1.34, cx + a * 0.5, cy - b * 1.34, cx + a, cy,
        cx + a * 0.5, cy + b * 1.34, cx - a * 0.5, cy + b * 1.34, cx - a, cy)
    white = ctx.radgrad([(0, '#e4e0f8'), (0.55, '#d8d4f0'), (0.85, '#8a82b0'), (1, '#3a3260')], cx=0.5, cy=0.5, r=0.55)
    clip = ctx.clip('<path d="%s"/>' % almond)
    inner = '<rect x="0" y="0" width="144" height="144" fill="%s"/>' % white
    iris = ctx.radgrad([(0, '#3a3060'), (0.7, '#4a3e78'), (0.86, '#6a5a9a'), (1, '#6a5a9a', 0)])
    inner += '<circle cx="%d" cy="%d" r="26" fill="%s"/>' % (cx, cy, iris)
    inner += '<circle cx="%d" cy="%d" r="23" fill="none" stroke="#6a5a9a" stroke-width="1.6"/>' % (cx, cy)
    inner += '<circle cx="%d" cy="%d" r="4.4" fill="#000000"/>' % (cx, cy)
    inner += dot(cx - 1.6, cy - 1.8, 1.3, '#ffffff')
    inner += '<path d="%s" fill="none" stroke="#1a1430" stroke-width="7" opacity="0.6"/>' % almond
    s += '<g clip-path="%s">%s</g>' % (clip, inner)
    s += line('M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f' % (cx - a, cy, cx - a * 0.5, cy - b * 1.34, cx + a * 0.5, cy - b * 1.34, cx + a, cy),
              '#4a3a7a', 1.6, op=0.9)
    s += line('M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f' % (cx - a, cy, cx - a * 0.5, cy + b * 1.34, cx + a * 0.5, cy + b * 1.34, cx + a, cy),
              '#2a2440', 1.2, op=0.9)
    for k in range(1, 5):
        s += '<path d="%s" fill="none" stroke="#2a2440" stroke-width="1.2" opacity="%.2f"/>' % (ell_d(cx, cy, a + 8 * k, b * 1.4 + 8 * k), 0.7 - k * 0.12)
    return doc(ctx, s), []


def echo(mood):
    """A Lost Wick: a soft gold glow inside a helm's outline, no face, one
    small flame at the crown (the six share it through CAST "face")."""
    ctx = Ctx('pec')
    s = disc(ctx, '#3a2e24', '#100c08')
    s += radial(ctx, 72, 84, 60, '#ffe0a0', 0.7)
    helm = ('M30 118 C26 90 30 62 48 46 C58 38 66 36 72 36 C78 36 86 38 96 46 C114 62 118 90 114 118 '
            'C104 124 84 126 72 126 C60 126 40 124 30 118 Z')
    s += '<path d="%s" fill="#ffe8b0" fill-opacity="0.25" stroke="#f2c75a" stroke-width="4" stroke-linejoin="round"/>' % helm
    s += '<path d="%s" fill="none" stroke="#fff6d8" stroke-width="1.6" opacity="0.8"/>' % helm
    s += line('M40 84 Q72 72 104 84', '#f2c75a', 3, op=0.8)
    s += '<path d="M62 36 L82 36 L80 28 Q72 24 64 28 Z" fill="#f2c75a" opacity="0.8"/>'
    for i in range(10):
        a = i * 0.63
        s += dot(72 + math.cos(a) * 36, 88 + math.sin(a) * 26, 1.4, '#fff6d8', 0.7)
    return doc(ctx, s), [pt(72, 28, 12)]


MOODS_ADD = [('taper', 'faint', taper_faint), ('hollin', 'worried', hollin_more), ('hollin', 'grin', hollin_more)]
CAST = [('rootmother', ['keeping', 'wrath'], '9fc46a', rootmother),
        ('yarrow', ['gentle', 'merry'], 'd8e8a0', yarrow),
        ('tinker', ['ticking', 'wrath'], '8ccfe8', tinker),
        ('tickwell', ['dazed', 'kind'], 'e0b870', tickwell),
        ('saint', ['serene', 'wrath'], 'eef0ff', saint),
        ('tessel', ['gentle', 'sad'], 'ff9ab8', tessel),
        ('hush', ['open'], '9a90c8', hush),
        ('echo', ['glow'], 'e8d8a0', echo)]
