"""Wick, the candle knight: a parts rig. Every part is its own SVG on the one
128 x 128 frame, drawn in its rest pose at its rest position, so the engine
stacks them unmoved and turns each around its pivot (PIVOTS).

Draw order, back to front (ORDER): cape, leg_back, arm_back, body,
leg_front, head, candle, sword, arm_front. The head comes in five faces.
Light from the top left; one hard cel band on the lower right of each shape.
"""
import kit
from kit import Part, ell, pth, shp
from common import (Ctx, RIM, GOLD, GOLD_SH, GOLD_HI, GOLD_LINE, WAX, WAX_SH, WAX_LINE, DEEP_RED, DEEP_RED_SH, FLAME,
                    FLAME_CORE, svg128, paint, eye, blush, mouth_open, sweat, line, dot, squeeze, flame_d, spec,
                    sparkle, H, IN)

L = '#1c1830'
STEEL, STEEL_SH, STEEL_HI = '#c3c7d6', '#8b90a8', '#f2f4fb'
STEEL_BACK, STEEL_BACK_SH = '#a2a7bc', '#767b96'
MAIL, MAIL_SH = '#8e93ad', '#686c88'
MAIL_BACK, MAIL_BACK_SH = '#747892', '#555872'
TABARD, TABARD_SH = '#3e4e8a', '#2c3868'
TRIM, TRIM_SH = '#d8b24a', '#a8842a'
SKIN, SKIN_SH = '#ffd9c0', '#f4b89e'
HAIR, HAIR_SH = '#9a5a2a', '#6e3a18'
LEATHER, LEATHER_SH = '#7a4a2a', '#553018'

PAL = dict(line=L, rim=RIM, base=STEEL, shade=STEEL_SH)
FACE = dict(line=L, base=SKIN, iris0='#2a1406', iris1='#8a4a12', iris2='#ffc04a', blush='#ff9aa0')

PIVOTS = {
    'cape': (58, 84), 'leg_back': (60, 104), 'arm_back': (54, 86), 'body': (64, 108), 'leg_front': (68, 104),
    'head': (64, 84), 'candle': (60, 34), 'sword': (64, 96), 'arm_front': (74, 86),
}
ORDER = ['cape', 'leg_back', 'arm_back', 'body', 'leg_front', 'head', 'candle', 'sword', 'arm_front']
HEADS = ['head', 'head_blink', 'head_hurt', 'head_happy', 'head_fierce']
HAND_FRONT = (76, 101)   # the sword's grip goes here
HAND_BACK = (52, 101)
FLAME_BASE = (60, 19)    # the engine's candle flame sits on the wick tip

# the face: the near (left, bigger) eye first
E1 = (62.8, 69.6, 12.8, 17)
E2 = (80.6, 69.1, 10.4, 16)
FACE_C = (70.6, 69, 18, 15.6)


def _clip(ctx, tpl):
    return ctx.clip(shp(tpl))


# ================================================================ head

def mail_rows(ctx, tpl, x0, x1, y0, y1, step=4.2, col=None, op=0.55):
    """Rows of little U scallops (chainmail), clipped to tpl."""
    col = col or L
    s = ''
    row = 0
    y = y0
    while y <= y1:
        x = x0 + (step / 2 if row % 2 else 0)
        while x <= x1:
            s += 'M%.1f %.1f q%.2f %.2f %.2f 0 ' % (x, y, step / 2, step * 0.55, step)
            x += step
        y += step * 0.62
        row += 1
    return '<g clip-path="%s">%s</g>' % (_clip(ctx, tpl), line(s, col, 0.8, op=op))


BANG_TIPS = [(51, 58.6), (57.2, 61.6), (64.6, 62.4), (71.8, 64.2), (78, 61), (84.2, 61.6), (90, 58)]


def bangs_path(tips=None, top=52):
    """Soft pointed bangs hanging from under the brim, a longer lock between
    the eyes. tips: the locks' points, back (left) to front; top: where they
    start under the headgear. The other callings pass their own cut."""
    tips = tips or BANG_TIPS
    d = 'M50 %s L91 %s L%.1f %.1f' % (top, top, tips[-1][0], tips[-1][1])
    back = list(reversed(tips))
    for (x0, y0), (x1, y1) in zip(back, back[1:]):
        mx = (x0 + x1) / 2.0
        top = min(y0, y1) - 4.2
        d += ' Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f' % (x0 - 0.8, top + 1.6, mx, top, x1 + 1.2, top + 0.6, x1, y1)
    return d + ' Z'


# How a calling's face differs from the knight's: its palette (skin, irises,
# blush), a resting lid (the Sexton's sleepy eyes), whether the mouth shows
# (the Sootrunner's scarf hides it) and extra marks drawn last (freckles,
# soot, under-eye shadows: a function of the mood). The eyes, brows and
# mouths themselves are one recipe for every calling.
KNIGHT_LOOK = dict(face=FACE, lid=0.0, mouth=True, extra=None)


def face_art(ctx, mood, look=None):
    look = look or KNIGHT_LOOK
    F = look['face']
    L = F['line']
    lid = look.get('lid', 0.0)
    show_mouth = look.get('mouth', True)
    s = ''
    if mood == 'normal':
        kw = {'lid': lid} if lid else {}
        s += eye(ctx, *E1, F, look=(1.2, 0.3), **kw) + eye(ctx, *E2, F, look=(1.2, 0.3), **kw)
        s += blush(56, 78.6, F, rx=3.9) + blush(87, 78, F, rx=2.6, ry=1.9)
        if show_mouth:
            s += mouth_open(72.6, 79.6, 5.6, 3.8, F)
    elif mood == 'blink':
        for (cx, cy, w, h) in (E1, E2):
            y = cy + h * 0.12
            s += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (cx - w / 2, y - 1, cx, y + w * 0.34, cx + w / 2, y - 1), L, 2.2)
            s += line('M%.1f %.1f l%.1f %.1f' % (cx + w / 2 - 0.4, y - 0.6, w * 0.2, -w * 0.12), L, 1.2)
        s += blush(56, 78.6, F, rx=3.9) + blush(87, 78, F, rx=2.6, ry=1.9)
        if show_mouth:
            s += line('M69.8 79.4 Q72.6 81.6 75.4 79.2', L, 1.5)
    elif mood == 'hurt':
        s += squeeze(E1[0], E1[1] + 1, 9.5, L, w=2.3) + squeeze(E2[0], E2[1] + 1, 8, L, flip=True, w=2.3)
        # worried brows, inner ends up
        s += line('M57 61.4 Q61.8 58.8 67.2 58', L, 1.8) + line('M77.4 58 Q81.6 58.6 85.4 61', L, 1.8)
        s += blush(56, 79, F, rx=4, lines=False, op=0.75) + blush(87, 78.4, F, rx=2.8, ry=2, lines=False, op=0.75)
        # a wobbly open "ouch"
        if show_mouth:
            s += ('<path d="M68.4 80.4 Q70.2 78 72 79.6 Q73.8 78 75.6 79.6 Q77.2 78.4 78 80.6 Q75.6 84.2 73 83.6 '
                  'Q70 84.4 68.4 80.4 Z" fill="%s"/>') % L
            s += '<path d="M70.4 82.6 Q73 80.8 75.8 82.4 Q73.2 84 70.4 82.6 Z" fill="%s"/>' % kit.TONGUE
    elif mood == 'happy':
        for (cx, cy, w, h) in (E1, E2):
            s += eye(ctx, cx, cy + 1.2, w + 0.6, h * 0.8, F, mood='happy')
        s += blush(55.8, 77.4, F, rx=4.3, ry=2.5) + blush(87, 76.8, F, rx=3, ry=2.2)
        if show_mouth:
            s += mouth_open(72.6, 77, 8.8, 6.6, F)
    elif mood == 'fierce':
        flid = max(0.3, lid + 0.1)
        s += eye(ctx, *E1, F, look=(2.2, 0.6), lid=flid) + eye(ctx, *E2, F, look=(2.2, 0.6), lid=flid)
        # brows set low and hard, inner ends down
        s += '<path d="M55.2 58.4 Q61.6 58.2 69.6 62.4 L69 64.6 Q61.6 61.2 55.6 61.2 Z" fill="%s"/>' % L
        s += '<path d="M74.8 63.6 Q80 59.6 86.2 59 L86.6 61.4 Q81 62 75.8 65.4 Z" fill="%s"/>' % L
        s += blush(56, 79, F, rx=3.4, op=0.5) + blush(87, 78.4, F, rx=2.4, ry=1.8, op=0.5)
        # gritted teeth
        if show_mouth:
            s += ('<path d="M68.6 78.6 L76.8 78 Q77.2 82 72.8 82.2 Q68.4 82.3 68.6 78.6 Z" fill="#ffffff" stroke="%s" '
                  'stroke-width="1.2" stroke-linejoin="round"/>') % L
            s += line('M68.8 80.2 L77 79.9 M71.3 78.4 L71.4 82 M74.2 78.2 L74.3 82', L, 0.7)
    if look.get('extra'):
        s += look['extra'](ctx, mood)
    return s


def head_svg(mood='normal'):
    ctx = Ctx('wh' + mood[:2])
    return svg128(ctx, head_art(ctx, mood))


def head_art(ctx, mood='normal'):
    """The head's SVG body in the 128 frame (for head_svg and the app icon)."""
    P = []
    # the mail coif under the kettle hat, framing the face
    coif = pth('M39.2 50 C37.6 68 45.6 86.6 64 86.6 C82.4 86.6 90.8 70 88.8 50 Z')
    rows = mail_rows(ctx, coif, 36.4, 92, 60, 90, step=4.2, op=0.35)
    P.append(Part('fill', coif, fill=MAIL, shade=MAIL_SH, off=(-3, -4), over=rows))
    # the face in the coif's opening, with a rolled mail edge around it
    fx, fy, frx, fry = FACE_C
    face = ell(fx, fy, frx, fry)
    edge = ('<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="none" stroke="%s" stroke-width="3.2"/>' % (
        fx - 0.4, fy + 0.2, frx + 1.9, fry + 1.9, '#a9aec4'))
    # bangs peeking out from under the brim
    bangs_d = bangs_path()
    bangs = ('<g clip-path="%s"><path d="%s" fill="%s"/>'
             '<path d="M57.4 55.8 Q60.4 56.2 62.8 57.6 M70 55.8 Q72.6 56.4 74.6 58.2" fill="none" stroke="#c98a4a" stroke-width="1.1" stroke-linecap="round"/>'
             '<path d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linejoin="round"/></g>') % (
        _clip(ctx, face), bangs_d, HAIR, bangs_d, L, IN())
    P.append(Part('fill', face, fill=SKIN, shade=SKIN_SH, off=(-2.4, -2.6), over=bangs + face_art(ctx, mood)))
    # the rolled edge is the coif's, so it draws under the face
    P[0].over += '<g clip-path="%s">%s</g>' % (_clip(ctx, coif), edge)
    # the kettle hat: a round steel dome with a flat crown where the candle sits
    dome = pth('M40.2 51.5 C39.4 40 48.6 32.6 59.6 32.6 C74.4 32.6 88.4 38.6 88.4 51.5 Z')
    ridge = line('M61.4 33.4 Q70.6 37 73.4 47', L, 0.9, op=0.45) + line('M59.6 34.6 Q68 38 70.6 46.6', STEEL_HI, 1.0, op=0.8)
    rivets = ''.join(dot(x, y, 1.05, L, 0.55) for x, y in ((45.5, 46.5), (82.5, 46.2)))
    P.append(Part('fill', dome, off=(-4.2, -4.6), over=ridge + rivets,
                  hl=spec(49.4, 40.6, 5.6, 2.6, rot=-42, op=0.9) + spec(54.8, 36.4, 1.6, 1.0, rot=-30, op=0.9)))
    # its broad brim, seen nearly edge on
    brim = ell(64.4, 50.4, 29.6, 4.9)
    brim_over = (line('M37 49.2 Q64 44.2 91.6 49.2', STEEL_HI, 1.2, op=0.9)
                 + ''.join(dot(x, y, 0.95, GOLD, 1) + dot(x - 0.3, y - 0.3, 0.35, '#fff6d0') for x, y in (
                     (44, 52.6), (54, 53.8), (64.4, 54.2), (74.8, 53.8), (84.8, 52.6))))
    P.append(Part('fill', brim, fill=STEEL, shade=STEEL_SH, off=(-1.6, -2.4), over=brim_over))
    body = paint(ctx, P, PAL)
    fx_art = ''
    if mood == 'hurt':
        fx_art = sweat(93.5, 60, 0.7, 20)
    elif mood == 'happy':
        fx_art = sparkle(95, 44, 3.4, L) + sparkle(33, 62, 2.6, L)
    return body + fx_art


# ================================================================ candle

def candle_svg():
    ctx = Ctx('wc')
    return svg128(ctx, candle_art(ctx))


def candle_art(ctx):
    P = []
    # the tiny gold cup fixed to the helmet's crown
    cup = pth('M52.6 30.6 L67.4 30.6 Q67.2 33.6 64.6 34.8 Q60 36.2 55.4 34.8 Q52.8 33.6 52.6 30.6 Z')
    P.append(Part('fill', cup, fill=GOLD, shade=GOLD_SH, off=(-1.4, -1.6), line=GOLD_LINE,
                  over=line('M55 32.2 Q60 33.4 65 32.2', GOLD_HI, 0.9, op=0.9)))
    # the wax stub, a melted cap on top dripping down its front
    wax = pth('M54.8 31.6 L54.8 23.4 L65.2 23.4 L65.2 31.6 Z')
    P.append(Part('fill', wax, fill=WAX, shade=WAX_SH, off=(-1.8, 0), line=WAX_LINE,
                  hl=spec(56.6, 29, 0.7, 1.6, rot=0, op=0.8)))
    cap = pth('M54.2 23.4 C54.2 21.5 56.8 20.8 60 20.8 C63.2 20.8 65.8 21.5 65.8 23.4 L65.8 26.8 '
              'C65.8 28.1 64 28.1 64 26.8 L64 25.4 C63.5 24.8 62.7 24.8 62.3 25.5 L62.3 29.6 C62.3 31.1 60.2 31.1 60.2 29.6 '
              'L60.2 25.8 C59.2 25 57.9 25.1 57.3 26 L57.3 27.4 C57.3 28.6 55.5 28.6 55.5 27.4 L55.5 25.8 '
              'C54.7 25.2 54.2 24.5 54.2 23.4 Z')
    well = ('<ellipse cx="60" cy="22.5" rx="4" ry="1.15" fill="%s"/>' % WAX_SH
            + line('M56.6 23.9 Q60 24.9 63.4 23.9', '#ffffff', 0.7, op=0.9))
    P.append(Part('fill', cap, fill='#fffaec', shade='#e8dcbc', off=(-0.9, -0.6), line='#b89c6c', lw=0.9, over=well,
                  hl=dot(61.2, 28.6, 0.5, '#ffffff')))
    wick = line('M60 22.4 Q59.5 20.8 60.1 18.9', '#241a14', 1.5)
    body = paint(ctx, P, dict(line=L, rim=RIM, base=WAX, shade=WAX_SH))
    return body + wick


# ================================================================ body

def body_svg():
    ctx = Ctx('wb')
    return svg128(ctx, body_art(ctx))


def body_art(ctx):
    P = []
    # the mail shirt, its skirt showing under the tabard
    mail = pth('M51.2 86 C51.2 82.4 55.4 80.6 64 80.6 C72.6 80.6 76.8 82.4 76.8 86 L79.2 106 '
               'C79.4 108.6 78.6 111.6 76 112 C73 112.6 70.4 111.2 67.8 112 C65.6 112.8 62.4 112.8 60.2 112 '
               'C57.6 111.2 55 112.6 52 112 C49.4 111.6 48.6 108.6 48.8 106 Z')
    P.append(Part('fill', mail, fill=MAIL, shade=MAIL_SH, off=(-2, -2.4),
                  over=mail_rows(ctx, mail, 46, 82, 80, 114, step=3.6, op=0.5)))
    # the tabard: deep blue, split hem trimmed in gold, a flame on the chest
    tab = pth('M53.4 82 L74.6 82 C76.6 90 78 99 78.4 108.6 L70.6 110.4 L64 106.8 L57.4 110.4 L49.6 108.6 '
              'C50 99 51.4 90 53.4 82 Z')
    hem = 'M48 108.2 L57.4 110.4 L64 106.8 L70.6 110.4 L80 108.2'
    trim = ('<g clip-path="%s">%s%s</g>') % (_clip(ctx, tab), line(hem, TRIM, 5.6, cap='butt'),
                                             line('M48 105.6 L57.4 107.6 L64 104 L70.6 107.6 L80 105.6', TRIM_SH, 0.9))
    side_trim = ('<g clip-path="%s">%s</g>') % (_clip(ctx, tab), line('M53.6 82 C51.6 90 50.4 99 49.8 108.6', TRIM, 2.4)
                                               + line('M74.4 82 C76.4 90 77.8 99 78.2 108.6', TRIM_SH, 2.4))
    em = flame_d(64.6, 99.2, 7.6, 11.6, 0.8)
    emblem = ('<path d="%s" fill="%s" stroke="%s" stroke-width="1.1" stroke-linejoin="round"/>' % (em, TRIM, GOLD_LINE)
              + '<path d="%s" fill="%s"/>' % (flame_d(64.8, 98.6, 3.6, 5.8, 0.4), '#fff0c0'))
    P.append(Part('fill', tab, fill=TABARD, shade=TABARD_SH, off=(-3, -2.4), over=side_trim + trim + emblem,
                  hl=spec(57.6, 88, 1.3, 3.6, rot=10, op=0.35)))
    # a leather belt with a gold buckle
    belt = pth('M50.6 100.4 L77.6 100.4 L77.9 104.4 L50.3 104.4 Z')
    buckle = ('<rect x="61.6" y="99.6" width="6" height="5.6" rx="1.2" fill="%s" stroke="%s" stroke-width="1"/>'
              '<rect x="63.3" y="101.3" width="2.6" height="2.2" fill="%s"/>') % (GOLD, GOLD_LINE, LEATHER_SH)
    P.append(Part('fill', belt, fill=LEATHER, shade=LEATHER_SH, off=(-0.8, -1.2), rim=False, over=buckle))
    return paint(ctx, P, PAL)


# ================================================================ cape

def cape_svg():
    ctx = Ctx('wk')
    return svg128(ctx, cape_art(ctx))


def cape_art(ctx):
    d = ('M62 81.4 C56 81.4 51 83 48.4 86.6 C45 91.6 42.4 100 40 110.4 L44.2 108.4 L45.4 113.6 L49.4 109.6 '
         'L52.4 114.4 L55.4 109.8 L59.6 113 L62.6 104 Z')
    folds = line('M47.6 92 Q46 101 44.8 108 M52.4 90 Q51.4 101 51.8 109.4', DEEP_RED_SH, 1.1, op=0.9)
    lining = ('<g clip-path="%s"><path d="M38 108 L44.2 108.4 L45.4 113.6 L49.4 109.6 L52.4 114.4 L55.4 109.8 L59.6 113 '
              'L60 116 L38 116 Z" fill="#b24a5e"/></g>') % _clip(ctx, pth(d))
    P = [Part('fill', pth(d), fill=DEEP_RED, shade=DEEP_RED_SH, off=(-2.6, -2), over=folds + lining, line='#1c1020')]
    return paint(ctx, P, PAL)


# ================================================================ legs

def boot(x0, tip, heel_top=110.6, sole=120.6, steel=STEEL, shade=STEEL_SH):
    """An iron boot whose heel is at x0 and toe tip at tip, sole on sole."""
    w = tip - x0
    d = ('M%.1f %.1f L%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f '
         'C%.1f %.1f %.1f %.1f %.1f %.1f Z') % (
        x0, sole, x0, heel_top + 4.4,
        x0, heel_top + 1, x0 + w * 0.2, heel_top, x0 + w * 0.4, heel_top,
        x0 + w * 0.62, heel_top, x0 + w * 0.7, heel_top + 1.6, x0 + w * 0.72, heel_top + 4.2,
        x0 + w * 0.95, heel_top + 4.6, tip, heel_top + 6.6, tip, sole)
    over = (line('M%.1f %.1f L%.1f %.1f' % (x0 + 0.4, sole - 1.4, tip - 0.4, sole - 1.4), '#3a3a52', 1.6, cap='butt')
            + line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (x0 + w * 0.66, heel_top + 4.6, x0 + w * 0.7, heel_top + 7,
                                                        x0 + w * 0.64, sole - 2.2), L, 0.8, op=0.6))
    return Part('fill', pth(d), fill=steel, shade=shade, off=(-1.4, -1.8), over=over,
                hl=spec(x0 + w * 0.3, heel_top + 2.4, 1.4, 0.8, rot=-20, op=0.9)
                + spec(tip - 3, heel_top + 5.8, 1.2, 0.7, rot=-10, op=0.8))


def leg_svg(front=True):
    ctx = Ctx('wl' + ('f' if front else 'b'))
    if front:
        P = [Part('limb', pth('M68 104.4 Q68.6 109.4 69.2 113.6'), width=7.2, fill=MAIL),
             boot(63.6, 78.2)]
    else:
        P = [Part('limb', pth('M60 104.4 Q59.8 109.4 59.6 113.6'), width=7.2, fill=MAIL_BACK),
             boot(53.8, 66.8, steel=STEEL_BACK, shade=STEEL_BACK_SH)]
    return svg128(ctx, paint(ctx, P, PAL))


# ================================================================ arms

def arm_svg(front=True):
    ctx = Ctx('wa' + ('f' if front else 'b'))
    return svg128(ctx, arm_art(ctx, front))


def arm_art(ctx, front=True):
    if front:
        sx, sy = PIVOTS['arm_front']
        hx, hy = HAND_FRONT
        sleeve, steel, shade = MAIL, STEEL, STEEL_SH
    else:
        sx, sy = PIVOTS['arm_back']
        hx, hy = HAND_BACK
        sleeve, steel, shade = MAIL_BACK, STEEL_BACK, STEEL_BACK_SH
    # the sleeve: tapered, narrow at the shoulder, starting just under the
    # pivot. At rest the arm hangs over the chin, so it must stay slim there
    # (the head hides the joint); it widens down to the cuff.
    ax, ay = sx + 0.4, sy + 3.2
    sleeve_d = ('M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f L%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z' % (
        ax - 1.9, ay + 0.6, ax - 1.9, ay - 1.6, ax + 1.9, ay - 1.6, ax + 1.9, ay + 0.6,
        hx + 3.4, hy - 3.6, hx + 1.4, hy - 2.6, hx - 1.4, hy - 2.6, hx - 3.2, hy - 3.6))
    P = [Part('fill', pth(sleeve_d), fill=sleeve, shade=MAIL_SH if front else MAIL_BACK_SH, off=(-1.2, -0.6),
              over=line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (ax - 2.2, ay + 4.2, ax + 0.4, ay + 5.2, ax + 2.8, ay + 4.2), L, 0.7, op=0.5))]
    # the gauntlet: a short flared cuff and the fist, knuckles forward; the
    # fist closes round the sword grip at the hand point
    cuff = pth('M%.1f %.1f Q%.1f %.1f %.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f Z' % (
        hx - 4.2, hy - 5.4, hx, hy - 6.4, hx + 4.4, hy - 5.4, hx + 3.6, hy - 2.6, hx, hy - 3.2, hx - 3.4, hy - 2.6))
    P.append(Part('fill', cuff, fill=steel, shade=shade, off=(-1, -0.8)))
    fist = pth('M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f '
               'C%.1f %.1f %.1f %.1f %.1f %.1f Z' % (
                   hx - 4.2, hy - 0.8,
                   hx - 4.2, hy - 3.4, hx - 2.2, hy - 3.8, hx, hy - 3.8,
                   hx + 3, hy - 3.8, hx + 4.6, hy - 3, hx + 4.6, hy - 0.2,
                   hx + 4.6, hy + 2.8, hx + 2.8, hy + 4, hx, hy + 4,
                   hx - 2.8, hy + 4, hx - 4.2, hy + 2.4, hx - 4.2, hy - 0.8))
    fingers = line('M%.1f %.1f L%.1f %.1f M%.1f %.1f L%.1f %.1f' % (hx + 1.4, hy - 0.9, hx + 4.2, hy - 0.9,
                                                                 hx + 1.4, hy + 1.7, hx + 4, hy + 1.7), L, 0.8, op=0.8)
    thumb = line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (hx - 2.8, hy - 2, hx - 0.2, hy - 1.2, hx + 0.6, hy + 1.4), L, 0.9, op=0.85)
    P.append(Part('fill', fist, fill=steel, shade=shade, off=(-1.3, -1.5), over=fingers + thumb,
                  hl=spec(hx - 1.8, hy - 2.2, 1.3, 0.8, rot=-20, op=0.95)))
    return paint(ctx, P, PAL)


# ================================================================ sword

def sword_svg():
    ctx = Ctx('ws')
    P = []
    blade = pth('M60.6 86.4 L60.6 48.6 L64 41.6 L67.4 48.6 L67.4 86.4 Z')
    bover = (line('M64 48 L64 84', STEEL_SH, 1.0, op=0.9) + line('M61.9 50 L61.9 85', '#ffffff', 1.0, op=0.95))
    P.append(Part('fill', blade, fill='#dfe3ee', shade='#9ea4bc', off=(-1.8, 0), over=bover,
                  hl=spec(62.2, 47.2, 0.7, 2.2, rot=-25, op=1)))
    # grip, wrapped in leather
    P.append(Part('limb', pth('M64 90.4 L64 101.4'), width=3.8, fill=LEATHER,
                  over=line('M62.4 92.6 L65.6 93.8 M62.4 95.6 L65.6 96.8 M62.4 98.6 L65.6 99.8', LEATHER_SH, 0.8)))
    guard = pth('M54.4 86.2 Q53.2 88.2 54.8 89.8 L73.2 89.8 Q74.8 88.2 73.6 86.2 Z')
    P.append(Part('fill', guard, fill=GOLD, shade=GOLD_SH, off=(-1, -1.2), line=GOLD_LINE,
                  over=dot(64, 88, 1.5, '#c8352a') + dot(63.5, 87.5, 0.5, '#ffd0c0'),
                  hl=line('M56 87.2 L62 87.2', GOLD_HI, 0.8)))
    P.append(Part('fill', ell(64, 104.2, 3, 2.8), fill=GOLD, shade=GOLD_SH, off=(-0.8, -1), line=GOLD_LINE,
                  hl=dot(63, 103.2, 0.8, GOLD_HI)))
    return svg128(ctx, paint(ctx, P, PAL))


# ================================================================ all files

def files():
    out = {
        'art/wick/cape.svg': cape_svg(),
        'art/wick/leg_back.svg': leg_svg(False),
        'art/wick/leg_front.svg': leg_svg(True),
        'art/wick/body.svg': body_svg(),
        'art/wick/arm_back.svg': arm_svg(False),
        'art/wick/arm_front.svg': arm_svg(True),
        'art/wick/candle.svg': candle_svg(),
        'art/wick/sword.svg': sword_svg(),
    }
    for name, mood in zip(HEADS, ('normal', 'blink', 'hurt', 'happy', 'fierce')):
        out['art/wick/%s.svg' % name] = head_svg(mood)
    return out
