"""The app icon: Waxby's face close up, candle lit, on the cathedral's deep
purple, a lancet window glowing faintly behind him and his lantern shield
raised at his side, its rose window catching the candlelight.

1024 square and opaque (the background is one full-size rect). Everything
that matters sits inside the central ~80% that iOS's rounded mask keeps;
the bust runs off the bottom edge on purpose. tools/art/render_icon.gd
rasterizes it to game/icons/icon_1024.png.
"""
import heroes
import wick
from common import Ctx, FLAME, FLAME_MID, FLAME_CORE, FLAME_EDGE, FLAME_LINE, RIM, flame_d, glow, star4, dot

PLACE = 'translate(540 598) scale(8.8) translate(-64 -60)'
SHIELD = 'translate(300 822) scale(9.4) translate(-48.2 -99.6)'


def icon_svg():
    ctx = Ctx('ic')
    bg = ctx.radgrad([(0, '#5a3474'), (0.5, '#34204a'), (1, '#1d1526')], cx=0.5, cy=0.52, r=0.72)
    s = '<rect width="1024" height="1024" fill="%s"/>' % bg
    # a lancet window behind him, faint stained glass
    win = ('M232 1024 L232 420 C232 250 380 150 512 110 C644 150 792 250 792 420 L792 1024 Z')
    glass = ctx.lingrad([(0, '#6a3c86', 0.55), (1, '#3a2452', 0.2)])
    s += '<path d="%s" fill="%s" stroke="#7a4a96" stroke-opacity="0.45" stroke-width="10"/>' % (win, glass)
    s += ('<path d="M512 110 L512 1024 M232 560 L792 560 M300 300 Q512 420 724 300" fill="none" stroke="#7a4a96" '
          'stroke-opacity="0.3" stroke-width="8"/>')
    # the candle's warm light spilling over the scene
    s += glow(ctx, 512, 330, 430, '#ffb24a', 0.42)
    # the bust: torso and arms, head, candle (the game's own parts)
    bust = wick.body_art(ctx) + wick.head_art(ctx, 'normal') + wick.candle_art(ctx)
    s += '<g transform="%s">%s</g>' % (PLACE, bust)
    # the flame, drawn in frame units on the wick tip (60, 19)
    fx, fy = wick.FLAME_BASE
    fl = ''
    fd = flame_d(fx, fy + 0.8, 10.4, 17.6, 0.9)
    fl += glow(ctx, fx, fy - 8, 22, FLAME, 0.6)
    fl += '<path d="%s" fill="%s" stroke="%s" stroke-width="3.4" stroke-linejoin="round"/>' % (fd, RIM, RIM)
    fl += '<path d="%s" fill="%s" stroke="%s" stroke-width="1.8" stroke-linejoin="round"/>' % (fd, FLAME_EDGE, FLAME_LINE)
    fl += '<path d="%s" fill="%s"/>' % (flame_d(fx - 0.1, fy + 0.4, 8.4, 14.6, 0.8), FLAME)
    fl += '<path d="%s" fill="%s"/>' % (flame_d(fx - 0.1, fy, 5.8, 10, 0.5), FLAME_MID)
    fl += '<path d="%s" fill="%s"/>' % (flame_d(fx - 0.1, fy - 0.4, 3.2, 5.6, 0.2), FLAME_CORE)
    fl += '<ellipse cx="%.1f" cy="%.1f" rx="0.8" ry="2.2" fill="#fffaf0" opacity="0.8" transform="rotate(18 %.1f %.1f)"/>' % (
        fx - 2.4, fy - 7, fx - 2.4, fy - 7)
    s += '<g transform="%s">%s</g>' % (PLACE, fl)
    # the lantern shield at his side, its glass lit from within
    s += glow(ctx, 300, 822, 210, '#ffc86a', 0.35)
    s += '<g transform="%s">%s</g>' % (SHIELD, heroes.knight_shield(ctx))
    # drifting embers
    for x, y, r in ((250, 300, 9), (800, 250, 7), (850, 520, 10), (190, 560, 6), (720, 150, 5)):
        s += dot(x, y, r * 1.8, '#ff9a3a', 0.25) + dot(x, y, r * 0.7, '#ffd27a', 0.95)
    s += star4(790, 380, 22, '#fff2c8', 0.9) + star4(262, 430, 14, '#fff2c8', 0.8) + star4(420, 680, 12, '#fff2c8', 0.85)
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">\n'
            '<defs>%s</defs>\n%s\n</svg>\n') % (''.join(ctx.defs), s)


def files():
    return {'icon.svg': icon_svg()}
