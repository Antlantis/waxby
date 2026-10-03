"""Item icons: game/art/items/<slot>_<tier>.svg (and weapon_<cls>_<tier>.svg),
on the 64 x 64 frame at 128 px, centred, no background (the engine draws
the rarity frame and beam). The relic icons' recipe: stickered, cel-shaded,
bold silhouettes that still read at 26 px.

Tiers climb in material and glory, the same way in every slot:
  1  humble: iron, wood, tallow, leather; plain shapes
  2  better: steel, brass, a trim, a small gem or charm, one sparkle
  3  grand:  gold, bone or radiant steel, a soft glow behind, two sparkles
  4  rimed:   frost steel, ice, pale bronze; a cold rime glow, ice crystals (v3)
  5  radiant: white gold, rose-window glass or night-ink and silver; a halo of
              twelve rays behind, four warm sparkles (v3; see WEAPONS45)
Names (spec 4.1): knight Arming Sword / Vigil Blade / Dawnsteel, founder
Foundry Maul / Belfry Maul / Tenor Maul, witch Taper Staff / Candelabra
Staff / Chandelier Staff, runner Wick Knife / Moth Knife / Soot Fang, sexton
Grave Spade / Sexton's Spade / Ossuary Spade; candle Tallow Stub / Chapel
Candle / Pillar Candle; coat Padded Coat / Chain Coat / Choir Plate; boots
Worn Boots / Pilgrim Boots / Sabatons; charm Bead / Knot / Locket.
"""
import math

from kit import Part, ell, pth, shp, star4
from common import (Ctx, RIM, GOLD, GOLD_SH, GOLD_HI, GOLD_LINE, WAX, WAX_SH, WAX_LINE, FLAME, svg64, paint, line,
                    dot, flame, flame_d, glow, spec, sparkle, mix, xf, xell, gx)

L = '#140e1c'
STEEL, STEEL_SH, STEEL_HI = '#dfe3ee', '#9ea4bc', '#ffffff'
IRON, IRON_SH = '#9a9eb2', '#6a6e86'
WOOD, WOOD_SH = '#8a5a34', '#5e3a1e'
ASH, ASH_SH = '#c8a070', '#94703e'
LEATHER, LEATHER_SH = '#7a4a2a', '#553018'
BRASS, BRASS_SH, BRASS_LINE = '#c8a04a', '#8e6a26', '#3a2408'
BRONZE, BRONZE_SH, BRONZE_HI, BRONZE_LINE = '#c8893a', '#8e5a24', '#f2c07a', '#3a2008'
BONE, BONE_SH, BONE_LINE = '#f0e8d8', '#c8bca4', '#3a2e24'
LAV, LAV_SH = '#b49cff', '#7a6aae'
DIAG = 'translate(32 32) rotate(-45)'


def pal(line_col=L, base='#ffffff', shade='#cccccc'):
    return dict(line=line_col, rim=RIM, base=base, shade=shade)


def D(d):
    """A path shape along the icon's diagonal (drawn along +x, handle left)."""
    return xf(d, DIAG)


def De(cx, cy, rx, ry):
    return xell(cx, cy, rx, ry, DIAG)


def Dg(body):
    return gx(body, DIAG)


def grand(ctx, col=FLAME, op=0.5):
    """Tier 3's soft glow behind the icon."""
    return glow(ctx, 32, 32, 30, col, op)


def shine(tier, a=(51, 11), b=(12, 52), col=L):
    """The sparkles that climb with the tier."""
    if tier == 1:
        return ''
    s = sparkle(a[0], a[1], 3.2, col)
    if tier == 3:
        s += sparkle(b[0], b[1], 2.6, col)
    return s


def sword(ctx, tier):
    blade = {1: ('#c8ccd8', '#8a8ea6'), 2: (STEEL, STEEL_SH), 3: ('#fff6d8', '#e0b458')}[tier]
    s = grand(ctx, '#ffe08a', 0.55) if tier == 3 else ''
    P = []
    grip = {1: LEATHER, 2: '#8a2a3a', 3: '#f2f0ff'}[tier]
    P.append(Part('limb', D('M-26 0 L-14.4 0'), width=4.2, fill=grip,
                  over=Dg(line('M-24 -2 L-22.6 2 M-21 -2 L-19.6 2 M-18 -2 L-16.6 2', mix(grip, '#000000', 0.4), 0.8))))
    tip = 31.6 if tier > 1 else 29
    P.append(Part('fill', D('M-12 -3.4 L%.1f -3.4 L%.1f 0 L%.1f 3.4 L-12 3.4 Z' % (tip - 7.6, tip, tip - 7.6)),
                  fill=blade[0], shade=blade[1], off=(0, -1.8), line=L,
                  over=Dg(line('M-9 0 L%.1f 0' % (tip - 9), blade[1], 1.2) + line('M-9 -2 L%.1f -2' % (tip - 8), '#ffffff', 0.9))
                  + (Dg(line('M-8 0 C-2 -1.6 6 1.6 14 0', '#ffd98a', 1.2)) if tier == 3 else '')))
    if tier == 1:
        P.append(Part('fill', D('M-14.4 -9 L-11.6 -9 L-11.6 9 L-14.4 9 Z'), fill=IRON, shade=IRON_SH, off=(-0.8, 0), line=L))
        P.append(Part('fill', De(-28.6, 0, 3, 3), fill=IRON, shade=IRON_SH, off=(-0.6, -0.6), line=L))
    elif tier == 2:
        P.append(Part('fill', D('M-15.6 -10.4 Q-13.2 -11.4 -12 -9.6 L-12.2 9.6 Q-13.2 11.4 -15.6 10.4 Q-14 0 -15.6 -10.4 Z'),
                      fill=GOLD, shade=GOLD_SH, off=(-1, 0), line=GOLD_LINE))
        P.append(Part('fill', De(-13.8, 0, 2.6, 2.6), fill='#e03a3a', shade='#a01a2a', off=(-0.6, -0.6), line=GOLD_LINE,
                      hl=Dg(dot(-14.4, -0.8, 0.7, '#ffffff'))))
        P.append(Part('fill', De(-28.8, 0, 3, 3), fill=GOLD, shade=GOLD_SH, off=(-0.6, -0.8), line=GOLD_LINE))
    else:
        # a sunburst guard: a gold disc and its rays
        rays = ''.join('M%.1f %.1f L%.1f %.1f ' % (-13.4 + 5 * math.cos(a), 5 * math.sin(a), -13.4 + 10.4 * math.cos(a),
                                                   10.4 * math.sin(a)) for a in (math.radians(d) for d in range(0, 360, 45)))
        s += Dg(line(rays, GOLD_LINE, 4.2) + line(rays, GOLD, 2.2))
        P.append(Part('fill', De(-13.4, 0, 5.2, 5.2), fill=GOLD, shade=GOLD_SH, off=(-1, -1), line=GOLD_LINE,
                      over=Dg(dot(-13.4, 0, 2.4, '#fff4cf') + dot(-14, -0.6, 0.8, '#ffffff'))))
        P.append(Part('fill', De(-28.8, 0, 3.2, 3.2), fill=GOLD, shade=GOLD_SH, off=(-0.6, -0.8), line=GOLD_LINE,
                      hl=Dg(dot(-29.6, -0.8, 0.8, GOLD_HI))))
    return s + paint(ctx, P, pal()) + shine(tier)


def maul(ctx, tier):
    s = grand(ctx, '#ffb24a', 0.55) if tier == 3 else ''
    P = []
    haft = ASH if tier > 1 else WOOD
    P.append(Part('limb', D('M-28 0 L6 0'), width=4.8, fill=haft,
                  over=Dg(line('M-24 -2.2 L-22.4 2.2 M-21 -2.2 L-19.4 2.2 M-18 -2.2 L-16.4 2.2', LEATHER_SH, 1.0))
                  + (Dg(line('M-8 -2.4 L-8 2.4 M0 -2.4 L0 2.4', GOLD, 1.6)) if tier == 3 else '')))
    if tier == 1:
        # a plain iron sledge head
        P.append(Part('fill', D('M6 -9 L18 -9 Q20 -9 20 -7 L20 7 Q20 9 18 9 L6 9 Q4 9 4 7 L4 -7 Q4 -9 6 -9 Z'),
                      fill=IRON, shade=IRON_SH, off=(-1.6, -1.6), line=L,
                      over=Dg(line('M7 -9 L7 9 M17 -9 L17 9', IRON_SH, 1.0) + dot(12, -5.4, 0.9, L, 0.6) + dot(12, 5.4, 0.9, L, 0.6)),
                      hl=Dg(spec(9, -6, 2.4, 0.9, rot=0, op=0.9))))
    else:
        k = 1.0 if tier == 2 else 1.06
        hx = 10.4 if tier == 2 else 8.4
        body, body_sh, hi = (BRONZE, BRONZE_SH, BRONZE_HI) if tier == 2 else ('#e8b24a', '#a8742a', '#fff0b0')

        def B(x, y):
            return '%.2f %.2f' % (hx + x * k, y * k)
        bell = ('M%s C%s %s %s L%s C%s %s %s C%s %s %s L%s C%s %s %s C%s %s %s L%s C%s %s %s Z' % (
            B(-8, -6), B(-8, -8), B(-6.4, -9), B(-4, -9), B(3, -9.6), B(6, -10), B(8.6, -13), B(10.4, -14.4),
            B(12.4, -15.6), B(14, -14.6), B(14, -12.4), B(14, 12.4), B(14, 14.6), B(12.4, 15.6), B(10.4, 14.4),
            B(8.6, 13), B(6, 10), B(3, 9.6), B(-4, 9), B(-6.4, 9), B(-8, 8), B(-8, 6)))
        bands = line('M%s L%s M%s L%s' % (B(-3, -9.2), B(-3, 9.2), B(6.6, -11.4), B(6.6, 11.4)), body_sh, 1.6)
        if tier == 3:
            bands += line('M%s L%s' % (B(1.6, -9.6), B(1.6, 9.6)), GOLD_LINE, 1.0) + ''.join(
                dot(*[float(v) for v in B(1.6, y).split()], r=0.9, col='#e03a3a') for y in (-5, 0, 5))
        P.append(Part('fill', D(bell), fill=body, shade=body_sh, off=(-1.8, -2), line=BRONZE_LINE, over=Dg(bands),
                      hl=Dg(spec(float(B(0, -6).split()[0]), float(B(0, -6).split()[1]), 3.4, 1.0, rot=0, op=0.9))))
        mx, my = [float(v) for v in B(14, 0).split()]
        P.append(Part('fill', De(mx, my, 2.4 * k, 14.2 * k), fill='#3a2008', shade='#3a2008', no_shade=True, line=BRONZE_LINE,
                      over=Dg(dot(mx + 0.4, my + 4.6 * k, 2.4 * k, body_sh) + dot(mx, my + 4 * k, 0.8, hi))))
        kx, ky = [float(v) for v in B(-9.6, 0).split()]
        P.append(Part('fill', De(kx, ky, 2.2 * k, 3.2 * k), fill=body, shade=body_sh, off=(-0.6, -0.6), line=BRONZE_LINE))
        if tier == 3:
            s_in = Dg(glow(ctx, mx + 4, my, 9, '#ffb24a', 0.7))
            P[-2].under = s_in
    P.append(Part('fill', De(-29.2, 0, 3.2, 3.2), fill=IRON, shade=IRON_SH, off=(-0.6, -0.6), line=L))
    return s + paint(ctx, P, pal()) + shine(tier)


def staff(ctx, tier):
    s = grand(ctx, '#ffd28a', 0.55) if tier == 3 else ''
    P = []
    wood, wood_sh = (WOOD, WOOD_SH) if tier < 3 else ('#e8c878', '#b08a3a')
    haft = 'M-26.6 1 C-19 -1.6 -12 2 -4 0 C2 -1.4 6 0.6 10 0'
    P.append(Part('limb', D(haft), width=4.4, fill=wood,
                  over=Dg(line('M-16 -1.4 Q-14.6 0.2 -15.4 1.6', wood_sh, 0.9) + line('M-6 -1.8 L-5 1.8 M-3.6 -1.8 L-2.6 1.8', '#d86a8a', 1.3))))
    fl = ''
    if tier == 1:
        # one taper in a wooden cup
        P.append(Part('fill', D('M8.4 -4.6 L13.6 -4.6 L13.6 4.6 L8.4 4.6 Z'), fill=BRASS, shade=BRASS_SH, off=(-0.6, -0.6), line=BRASS_LINE))
        P.append(Part('fill', D('M13.6 -3 L25.4 -3 C26.6 -3 26.6 3 25.4 3 L13.6 3 Z'), fill='#fffaec', shade='#d8c8a8',
                      off=(0, -1.6), line=WAX_LINE, over=Dg(line('M16.6 3 Q18.6 4.4 20.4 3', '#d8c8a8', 1.2))))
        fl = flame_at(ctx, 26.8, 0, 11)
    elif tier == 2:
        for k in (-1, 1):
            P.append(Part('limb', D('M8 0 C10 %.1f 11 %.1f 15.4 %.1f' % (k * 7, k * 9.6, k * 9.6)), width=2.6, fill=BRASS, line=BRASS_LINE))
        P.append(Part('limb', D('M8 0 L16.4 0'), width=2.8, fill=BRASS, line=BRASS_LINE))
        for y, ln in ((-9.6, 6.6), (0, 8.2), (9.6, 6.6)):
            x0 = 16 if y else 17
            P.append(Part('fill', D('M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (x0 - 1.6, y - 3.2, x0, y - 3.2, x0, y + 3.2, x0 - 1.6, y + 3.2)),
                          fill=BRASS, shade=BRASS_SH, off=(-0.4, -0.4), line=BRASS_LINE))
            P.append(Part('fill', D('M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (x0, y - 2.1, x0 + ln, y - 2.1, x0 + ln, y + 2.1, x0, y + 2.1)),
                          fill='#fffaec', shade='#d8c8a8', off=(0, -1.1), line=WAX_LINE))
            fl += flame_at(ctx, x0 + ln + 1, y, 7.6)
    else:
        # the chandelier: a gold hoop hung from the staff's crook, three lit candles and crystal drops
        # the chandelier: a gold crown of three lit candles on curled arms,
        # crystal drops hanging between them
        for k in (-1, 1):
            P.append(Part('limb', D('M6 0 C8 %.1f 10 %.1f 15 %.1f C17 %.1f 18 %.1f 17.4 %.1f' % (
                k * 5, k * 11, k * 11.4, k * 11.6, k * 10, k * 8.6)), width=2.6, fill=GOLD, line=GOLD_LINE))
        P.append(Part('limb', D('M6 0 L16 0'), width=3, fill=GOLD, line=GOLD_LINE))
        P.append(Part('fill', De(8, 0, 3.4, 3.4), fill=GOLD, shade=GOLD_SH, off=(-0.6, -0.6), line=GOLD_LINE,
                      over=Dg(dot(8, 0, 1.4, '#d8304a'))))
        for y, ln in ((-11, 6.4), (0, 8), (11, 6.4)):
            x0 = 16.4 if y else 16.6
            P.append(Part('fill', D('M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (x0 - 1.8, y - 3.4, x0, y - 3.4, x0, y + 3.4, x0 - 1.8, y + 3.4)),
                          fill=GOLD, shade=GOLD_SH, off=(-0.4, -0.4), line=GOLD_LINE))
            P.append(Part('fill', D('M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (x0, y - 2.1, x0 + ln, y - 2.1, x0 + ln, y + 2.1, x0, y + 2.1)),
                          fill='#fffaec', shade='#d8c8a8', off=(0, -1.1), line=WAX_LINE))
            fl += flame_at(ctx, x0 + ln + 1, y, 7.6)
        for y in (-6, 6):
            s += Dg('<path d="M11 %.1f L13.4 %.1f L11 %.1f L8.6 %.1f Z" fill="#bfe8ff" stroke="%s" stroke-width="0.9"/>' % (
                y - 1.6, y, y + 1.6, y, '#3a6a9a'))
    return s + paint(ctx, P, pal()) + fl + shine(tier, a=(12, 13))


def flame_at(ctx, x, y, h):
    """A small upright flame at a point on the diagonal (x along it)."""
    c, sn = math.cos(math.radians(-45)), math.sin(math.radians(-45))
    px, py = 32 + x * c - y * sn, 32 + x * sn + y * c
    return flame(ctx, px, py + 1.2, h * 0.56, h, lean=0.5, line_w=1.1, halo=False)


def knife(ctx, tier):
    s = grand(ctx, '#b49cff', 0.5) if tier == 3 else ''
    P = []
    if tier == 1:
        P.append(Part('limb', D('M-20 0 L-6 0'), width=5, fill=WOOD, over=Dg(line('M-16 -2 L-16 2 M-11 -2 L-11 2', WOOD_SH, 1.0))))
        P.append(Part('fill', D('M-6 -3.6 L10 -3.6 C16 -3.6 20 -1.6 23 1.4 C17 3.4 10 3.4 -6 3.4 Z'), fill='#c8ccd8', shade='#8a8ea6',
                      off=(0, -1.6), line=L, over=Dg(line('M-3 -1.8 L12 -1.8', '#ffffff', 0.9))))
        P.append(Part('fill', D('M-7.4 -5 L-5 -5 L-5 5 L-7.4 5 Z'), fill=IRON, shade=IRON_SH, off=(-0.4, 0), line=L))
    elif tier == 2:
        P.append(Part('limb', D('M-21 0 L-8 0'), width=4.4, fill='#3a2a3a',
                      over=Dg(line('M-19 -1.8 L-17.6 1.8 M-16 -1.8 L-14.6 1.8 M-13 -1.8 L-11.6 1.8', '#6a5a6a', 0.8))))
        P.append(Part('fill', D('M-6 -3.2 L8 -3.8 C16 -4 22 -1 26 3.4 C18 1.8 10 3.2 -6 3.2 Z'), fill=STEEL, shade=STEEL_SH,
                      off=(0, -1.6), line=L, over=Dg(line('M-3 -1.6 L12 -2.2', '#ffffff', 0.9))))
        # a moth-wing guard, dusty tan with violet eye-spots
        for k in (-1, 1):
            P.append(Part('fill', D('M-7 0 C-10 %.1f -5 %.1f -3 %.1f C-3 %.1f -5 %.1f -7 0 Z' % (k * 4, k * 11, k * 10, k * 6, k * 2)),
                          fill='#c4ae8c', shade='#9a8466', off=(-0.4, -0.4), line=L, over=Dg(dot(-4.6, k * 7.4, 1.4, '#6a5a86'))))
        P.append(Part('fill', De(-22.6, 0, 2.6, 2.6), fill=BRASS, shade=BRASS_SH, off=(-0.5, -0.5), line=BRASS_LINE))
    else:
        # the Soot Fang: a black curved fang, a violet edge, a bone grip
        P.append(Part('limb', D('M-22 0 L-8 0'), width=4.6, fill=BONE, over=Dg(line('M-18 -2 L-18 2 M-14 -2 L-14 2 M-10 -2 L-10 2', BONE_SH, 1.0))))
        P.append(Part('fill', D('M-7 -4 C4 -5.6 16 -4 27 -8 C22 0 12 5 -7 4 Z'), fill='#2a2440', shade='#16122a', off=(0, 1.8), line=L,
                      over=Dg(line('M-4 -3.4 C6 -4.4 16 -3.4 25 -6.6', '#c8b0ff', 1.4) + line('M-2 2 C8 2 16 0 22 -3', '#6a5aa8', 0.9, op=0.8))))
        P.append(Part('fill', D('M-9 -6 C-7 -3 -7 3 -9 6 L-6.6 6 C-5 3 -5 -3 -6.6 -6 Z'), fill=BONE, shade=BONE_SH, off=(-0.4, 0), line=BONE_LINE))
        P.append(Part('fill', De(-23.4, 0, 2.8, 2.8), fill=BONE, shade=BONE_SH, off=(-0.5, -0.5), line=BONE_LINE))
        s += ''.join('<circle cx="%.1f" cy="%.1f" r="%.1f" fill="#d0d4e0" opacity="%.2f"/>' % (x, y, r, o)
                     for x, y, r, o in ((50, 20, 2.6, 0.5), (54, 15, 1.8, 0.4), (46, 14.6, 1.4, 0.35)))
    return s + paint(ctx, P, pal()) + shine(tier, a=(48, 48), b=(14, 14))


def spade(ctx, tier):
    s = grand(ctx, '#b49cff', 0.5) if tier == 3 else ''
    P = []
    if tier < 3:
        P.append(Part('limb', D('M-24 0 L6 0'), width=3.8, fill=WOOD if tier == 1 else '#6a3a22',
                      over=Dg(line('M-10 -1.4 Q-8 0 -8.6 1.6', WOOD_SH, 0.9))))
    else:
        # a haft of little vertebrae
        P.append(Part('limb', D('M-24 0 L6 0'), width=4.2, fill=BONE,
                      over=Dg(line(''.join('M%.1f -2.2 L%.1f 2.2 ' % (x, x) for x in range(-20, 6, 4)), BONE_LINE, 1.0))))
    grip = BONE if tier == 3 else WOOD
    P.append(Part('fill', D('M-30.6 -4.6 L-24 -4.6 L-24 4.6 L-30.6 4.6 C-32.4 4.6 -33 3 -33 0 C-33 -3 -32.4 -4.6 -30.6 -4.6 Z'),
                  fill=grip, shade=mix(grip, '#000000', 0.3), off=(-0.6, -0.6), line=L,
                  over=Dg('<path d="M-30 -2.4 L-26 -2.4 L-26 2.4 L-30 2.4 Z" fill="%s"/>' % L)))
    blade = {1: (IRON, IRON_SH), 2: ('#8b90a8', '#646982'), 3: ('#d8dcf0', '#9ea4c4')}[tier]
    P.append(Part('fill', D('M6 -3 L10.4 -3 L10.4 3 L6 3 Z'), fill=IRON, shade=IRON_SH, off=(-0.5, -0.5), line=L))
    P.append(Part('fill', D('M10 -8 L20 -8 C25 -7.6 29 -4 30.6 0 C29 4 25 7.6 20 8 L10 8 C9 4 9 -4 10 -8 Z'),
                  fill=blade[0], shade=blade[1], off=(-1.4, -1.8), line=L,
                  over=Dg(line('M12 0 L27 0', blade[1], 0.9, op=0.8) + (dot(23, 3.4, 1.2, '#6a4a30', 0.55) if tier == 1 else '')),
                  hl=Dg(line('M12 -6 L21 -6 C24 -5.6 27 -3.6 28.6 -1', '#ffffff', 1.1, op=0.8))))
    if tier == 2:
        # a little brass bell tied on with a lavender ribbon
        P.append(Part('limb', D('M-6 0 L-6 5.4'), width=1.2, fill=LAV, rim=False))
        P.append(Part('fill', D('M-9 10 C-9 7 -7.8 5.4 -6 5.4 C-4.2 5.4 -3 7 -3 10 L-2.2 11 L-9.8 11 Z'), fill=BRASS, shade=BRASS_SH,
                      off=(-0.5, -0.5), line=BRASS_LINE))
    if tier == 3:
        # a small skull on the socket
        P.append(Part('fill', De(8.4, 0, 4.4, 4.6), fill=BONE, shade=BONE_SH, off=(-0.6, -0.6), line=BONE_LINE,
                      over=Dg(dot(7.6, -1.8, 1.1, BONE_LINE) + dot(7.6, 1.8, 1.1, BONE_LINE) + line('M10.8 -1.4 L10.8 1.4', BONE_LINE, 0.8))))
        s_w = ''.join(wisp(x, y, k) for x, y, k in ((48, 46, 1.0), (14, 16, 0.8)))
        return s + paint(ctx, P, pal()) + s_w + shine(tier, a=(52, 12), b=(10, 50))
    return s + paint(ctx, P, pal()) + shine(tier, a=(52, 12))


def wisp(x, y, k=1.0):
    """A small mourning wisp: a pale flame with two dot eyes."""
    d = flame_d(x, y + 4 * k, 7 * k, 12 * k, 1.2 * k)
    return ('<path d="%s" fill="#e8ecff" stroke="%s" stroke-width="1.2" stroke-linejoin="round" opacity="0.95"/>' % (d, '#5a4a8a')
            + dot(x - 1.4 * k, y + 0.8 * k, 0.8 * k, '#2a2048') + dot(x + 1.4 * k, y + 0.8 * k, 0.8 * k, '#2a2048'))


WEAPONS = {'knight': sword, 'founder': maul, 'witch': staff, 'runner': knife, 'sexton': spade}


# ================================================================ candles

def candle(ctx, tier):
    s = grand(ctx, FLAME, 0.55) if tier == 3 else glow(ctx, 32, 22, 18, FLAME, 0.35)
    P = []
    if tier == 1:
        # a squat tallow stub in a dented tin dish
        P.append(Part('fill', pth('M11 48 L53 48 Q52 55 44 56.6 L20 56.6 Q12 55 11 48 Z'), fill='#a8acbc', shade='#767a90', off=(-1.4, -1.6),
                      line=L, over=line('M14 50.4 Q32 52.6 50 50.4', '#d8dce8', 1.1) + line('M40 53.6 L43 52', L, 0.8, op=0.6)))
        P.append(Part('fill', pth('M22.6 49.6 L22.6 34.6 L41.4 34.6 L41.4 49.6 Z'), fill='#f2e2a8', shade='#d0bc78', off=(-3, 0), line=WAX_LINE,
                      hl=spec(25.6, 42, 1.1, 4, rot=0, op=0.7)))
        P.append(Part('fill', pth('M21.8 35 C21.8 32 26 31 32 31 C38 31 42.2 32 42.2 35 L42.2 38.6 C42.2 40.4 39.6 40.4 39.6 38.6 '
                                  'L39.6 37.4 C37.6 36.6 35.6 36.8 34.4 38 L34.4 42 C34.4 44 31.6 44 31.6 42 L31.6 37.8 C29 37 26.6 37.2 24.6 38.2 '
                                  'L24.6 39.4 C24.6 41 21.8 41 21.8 39.4 Z'), fill='#fff4c8', shade='#e8d890', off=(-0.8, -0.6),
                      line='#b89c6c', lw=0.9, rim=False))
        wick_y, h = 31.6, 16
    elif tier == 2:
        # a tall chapel candle in a brass holder with a ring handle
        P.append(Part('limb', pth('M44.6 50.2 C51 47.6 55.6 50.6 54.6 54 C53.8 57 49.6 57.6 46.4 55.2'), width=2.4, fill=BRASS, line=BRASS_LINE))
        P.append(Part('fill', pth('M12 50 L52 50 Q51 56.6 42 57.6 L22 57.6 Q13 56.6 12 50 Z'), fill=BRASS, shade=BRASS_SH, off=(-1.4, -1.6),
                      line=BRASS_LINE, over=line('M15 52 Q32 54.4 49 52', '#f2d88a', 1.1)))
        P.append(Part('fill', pth('M25 51 L25 47 L39 47 L39 51 Z'), fill=BRASS, shade=BRASS_SH, off=(-0.8, -0.8), line=BRASS_LINE))
        P.append(Part('fill', pth('M26.6 47.6 L26.6 22 L37.4 22 L37.4 47.6 Z'), fill=WAX, shade=WAX_SH, off=(-2, 0), line=WAX_LINE,
                      hl=spec(28.4, 34, 0.9, 6, rot=0, op=0.8)))
        P.append(Part('fill', pth('M26 22.4 C26 20.2 28.4 19.6 32 19.6 C35.6 19.6 38 20.2 38 22.4 L38 26 C38 27.6 36 27.6 36 26 L36 24.6 '
                                  'C35 24 33.8 24.2 33.2 25 L33.2 31 C33.2 32.8 30.8 32.8 30.8 31 L30.8 25 C29.8 24.4 28.8 24.6 28 25.4 L28 27 '
                                  'C28 28.6 26 28.6 26 27 Z'), fill='#fffaec', shade='#e8dcbc', off=(-0.8, -0.6), line='#b89c6c', lw=0.9, rim=False))
        wick_y, h = 20.2, 15
    else:
        # a fat pillar candle with a gold band and the Vigil's flame on it
        P.append(Part('fill', pth('M12 52 L52 52 Q51 58 42 59 L22 59 Q13 58 12 52 Z'), fill=GOLD, shade=GOLD_SH, off=(-1.4, -1.6), line=GOLD_LINE,
                      over=line('M15 54 Q32 56.4 49 54', GOLD_HI, 1.1)))
        P.append(Part('fill', pth('M18.4 53 L18.4 26 L45.6 26 L45.6 53 Z'), fill=WAX, shade=WAX_SH, off=(-4, 0), line=WAX_LINE,
                      over='<path d="M18.6 41 L45.4 41 L45.4 46.6 L18.6 46.6 Z" fill="%s"/>' % GOLD
                      + line('M18.6 41.6 L45.4 41.6', GOLD_HI, 0.8) + line('M18.6 46.2 L45.4 46.2', GOLD_SH, 0.8)
                      + '<path d="%s" fill="%s" stroke="%s" stroke-width="0.8"/>' % (flame_d(32, 46, 4.4, 7, 0.4), '#c8352a', GOLD_LINE),
                      hl=spec(21.6, 33, 1.3, 4.6, rot=0, op=0.8)))
        P.append(Part('fill', pth('M17.4 26.6 C17.4 23.6 23 22.6 32 22.6 C41 22.6 46.6 23.6 46.6 26.6 L46.6 31 C46.6 33 43.6 33 43.6 31 L43.6 29.6 '
                                  'C41.6 28.6 39.6 28.8 38.6 30 L38.6 37.4 C38.6 39.6 35.4 39.6 35.4 37.4 L35.4 30 C33 29 30 29 27.4 30.4 L27.4 33.4 '
                                  'C27.4 35.4 24.4 35.4 24.4 33.4 L24.4 30.6 C22 29.8 19.6 30 17.4 31 Z'), fill='#fffaec', shade='#e8dcbc',
                      off=(-0.8, -0.6), line='#b89c6c', lw=0.9, rim=False))
        wick_y, h = 23.2, 17
    body = paint(ctx, P, pal(L))
    wick_line = line('M32 %.1f Q31.4 %.1f 32.2 %.1f' % (wick_y + 1, wick_y - 1, wick_y - 3), '#241a14', 1.5)
    fl = flame(ctx, 32.2, wick_y - 2, h * 0.52, h, lean=0.8, halo=False)
    return s + body + wick_line + fl + shine(tier, a=(52, 16), b=(12, 24))


# ================================================================ coats

def coat_shape():
    """A tunic laid flat: shoulders, short sleeves, a flared skirt."""
    return ('M22 12 C26 14.6 38 14.6 42 12 L52.4 17.4 C54 18.2 54.6 19.6 54 21.2 L50.6 30 L45 28.2 L46 48 '
            'C46.4 51.6 44.6 53.4 41 53.4 L23 53.4 C19.4 53.4 17.6 51.6 18 48 L19 28.2 L13.4 30 L10 21.2 '
            'C9.4 19.6 10 18.2 11.6 17.4 Z')


def coat(ctx, tier):
    s = grand(ctx, '#ffe08a', 0.5) if tier == 3 else ''
    P = []
    body = coat_shape()
    if tier == 1:
        quilt = ('<g clip-path="%s">%s</g>' % (ctx.clip(shp(pth(body))), line(
            ''.join('M%d 8 L%d 58 ' % (x, x + 26) for x in range(-20, 60, 7))
            + ''.join('M%d 8 L%d 58 ' % (x, x - 26) for x in range(10, 90, 7)), '#8a6a44', 0.9, op=0.9)))
        P.append(Part('fill', pth(body), fill='#c8a878', shade='#9a7a4a', off=(-3, -2.6), line=L, over=quilt
                      + line('M32 15 L32 53', '#8a6a44', 1.2) + ''.join(dot(33.8, y, 0.9, '#5e3a1e') for y in (22, 30, 38, 46))))
        P.append(Part('fill', pth('M24 12.6 C27 16 37 16 40 12.6 L38 17.6 C35 19.4 29 19.4 26 17.6 Z'), fill='#a8885a', shade='#7a5a34',
                      off=(-0.6, -0.8), line=L, rim=False))
    elif tier == 2:
        mail = ''
        clipid = ctx.clip(shp(pth(body)))
        rows = ''
        y, row = 10.0, 0
        while y < 58:
            x = 4.0 + (1.6 if row % 2 else 0)
            while x < 60:
                rows += 'M%.1f %.1f q1.6 1.8 3.2 0 ' % (x, y)
                x += 3.2
            y += 2.1
            row += 1
        mail = '<g clip-path="%s">%s</g>' % (clipid, line(rows, '#4a4e66', 0.8, op=0.8))
        P.append(Part('fill', pth(body), fill='#9aa0b8', shade='#6a7088', off=(-3, -2.6), line=L, over=mail,
                      hl=spec(24, 22, 2, 5, rot=10, op=0.5)))
        P.append(Part('fill', pth('M17.6 36 L46.4 36 L46.6 40.6 L17.4 40.6 Z'), fill=LEATHER, shade=LEATHER_SH, off=(-0.8, -1), line=L,
                      rim=False, over='<rect x="29.4" y="35.4" width="5.6" height="5.8" rx="1.2" fill="%s" stroke="%s" stroke-width="1"/>' % (
                          BRASS, BRASS_LINE)))
    else:
        # Choir Plate: a polished cuirass, round pauldrons, gold trim, the flame
        plate = ('M21 12.6 C25 17.4 39 17.4 43 12.6 L47.4 15.6 C49 27 48.4 39 45.4 47.4 C41 51.4 23 51.4 18.6 47.4 '
                 'C15.6 39 15 27 16.6 15.6 Z')
        skirt = 'M19.4 46.6 C25 50.6 39 50.6 44.6 46.6 L46.4 54 C40 57.6 24 57.6 17.6 54 Z'
        P.append(Part('fill', pth(skirt), fill='#3e4e8a', shade='#2c3868', off=(-1.4, -1.4), line=L,
                      over=line('M17.8 53.4 C24 57 40 57 46.2 53.4', GOLD, 1.6)))
        trim = '<g clip-path="%s">%s</g>' % (ctx.clip(shp(pth(plate))), line(plate, GOLD, 3.2))
        emblem = ('<path d="%s" fill="%s" stroke="%s" stroke-width="1.1" stroke-linejoin="round"/>' % (flame_d(32.2, 38.6, 9.6, 15, 0.8), GOLD, GOLD_LINE)
                  + '<path d="%s" fill="#fff0c0"/>' % flame_d(32.4, 37.8, 4.6, 7.6, 0.4))
        P.append(Part('fill', pth(plate), fill='#e4e8f2', shade='#9ea4bc', off=(-3, -2.6), line=L, over=trim + emblem
                      + line('M24.4 19.6 C24.2 30 25 38 27 44', '#ffffff', 1.0, op=0.7),
                      hl=spec(21.4, 24, 1.6, 5.4, rot=12, op=0.95)))
        for k in (-1, 1):
            x = 32 + k * 17.4
            P.append(Part('fill', pth('M%.1f 12 C%.1f 11 %.1f 13.6 %.1f 18.4 C%.1f 23 %.1f 26 %.1f 26.4 C%.1f 24 %.1f 18.6 %.1f 12 Z' % (
                x - k * 6, x + k * 1.6, x + k * 6.6, x + k * 7, x + k * 7.2, x + k * 5, x + k * 1.6, x - k * 2, x - k * 4.6, x - k * 6)),
                fill='#c3c7d6', shade='#8b90a8', off=(-1, -1.2), line=L,
                over=line('M%.1f 14.6 C%.1f 15.4 %.1f 18 %.1f 21.6' % (x - k * 2.6, x + k * 1.6, x + k * 4.4, x + k * 5.2), GOLD, 1.4)))
    return s + paint(ctx, P, pal()) + shine(tier, a=(55, 8), b=(8, 50))


# ================================================================ boots

def boot_d(x, y, k=1.0):
    """A boot in profile, its heel's bottom-left at (x, y), toe to the right."""
    def p(px, py):
        return '%.1f %.1f' % (x + px * k, y + py * k)
    return ('M%s L%s Q%s %s L%s Q%s %s L%s C%s %s %s L%s Z' % (
        p(0, 0), p(0, -24), p(0, -27), p(3, -27), p(13, -27), p(16, -27), p(16, -24), p(16, -12),
        p(22, -12.6), p(29, -9), p(29, -3.6), p(29, 0)))


def boots(ctx, tier):
    s = grand(ctx, '#ffe08a', 0.45) if tier == 3 else ''
    P = []
    for i, (x, y) in enumerate(((12.6, 45), (21.4, 54.4))):
        back = i == 0
        if tier == 1:
            base, shade = ('#7a5436', '#553820') if not back else ('#6a462c', '#4a301a')
            over = (line('M%.1f %.1f L%.1f %.1f' % (x + 0.6, y - 1.6, x + 28.4, y - 1.6), '#2a1a10', 2.2, cap='butt')
                    + '<path d="M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z" fill="#9a7048" stroke="%s" stroke-width="0.8"/>' % (
                        x + 3, y - 18, x + 9, y - 18.6, x + 9.4, y - 12.6, x + 3.4, y - 12, L)
                    + '<path d="M%.1f %.1f l1.6 1.6 M%.1f %.1f l1.6 -1.6" stroke="%s" stroke-width="0.7"/>' % (x + 4.2, y - 17, x + 4.2, y - 13.4, L))
        elif tier == 2:
            base, shade = ('#5e4632', '#3e2c1e') if not back else ('#4e3a28', '#34261a')
            over = (line('M%.1f %.1f L%.1f %.1f' % (x + 0.6, y - 1.6, x + 28.4, y - 1.6), '#1e140c', 2.4, cap='butt')
                    + ''.join('<rect x="%.1f" y="%.1f" width="16" height="2.6" fill="%s"/>' % (x, y - yy, LEATHER_SH) for yy in (21, 14.6))
                    + ''.join('<rect x="%.1f" y="%.1f" width="3.2" height="3.6" rx="0.6" fill="none" stroke="%s" stroke-width="1"/>' % (
                        x + 10.6, y - yy - 0.5, BRASS) for yy in (21, 14.6)))
        else:
            base, shade = ('#dfe3ee', '#9ea4bc') if not back else ('#b8bccc', '#8288a0')
            over = (line('M%.1f %.1f L%.1f %.1f M%.1f %.1f L%.1f %.1f' % (x + 0.6, y - 20, x + 15.4, y - 20, x + 0.6, y - 14.6, x + 15.4, y - 14.6),
                         GOLD, 1.6)
                    + line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (x + 16, y - 11.6, x + 18.4, y - 6.4, x + 17.4, y - 2.2), GOLD, 1.4)
                    + line('M%.1f %.1f L%.1f %.1f' % (x + 0.6, y - 1.6, x + 28.4, y - 1.6), '#26243a', 2.2, cap='butt')
                    + dot(x + 8, y - 8, 1.3, GOLD) + dot(x + 7.6, y - 8.4, 0.5, '#fff6d0'))
        P.append(Part('fill', pth(boot_d(x, y)), fill=base, shade=shade, off=(-2, -2), line=L, over=over,
                      hl=spec(x + 4.4, y - 22.6, 1.4, 0.9, op=0.9) + spec(x + 23.6, y - 8.2, 2, 0.9, rot=-12, op=0.9)))
        cuff = mix(base, '#ffffff', 0.2) if tier != 2 else '#c8a878'
        P.append(Part('fill', pth('M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (x - 1, y - 25.6, x + 17, y - 25.6, x + 16.4, y - 29,
                                                                                   x - 0.4, y - 29)),
                      fill=cuff, shade=base, off=(-0.8, -0.8), line=L))
    extra = ''
    if tier == 2:
        # a pilgrim's scallop shell hung on the front boot
        sx, sy = 33.4, 36
        extra = ('<path d="M%.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f Z" fill="#fff0d8" stroke="%s" stroke-width="1.1"/>' % (
            sx, sy + 4.6, sx - 4.6, sy - 1.6, sx - 3, sy - 5, sx, sy - 5, sx + 3, sy - 5, sx + 4.6, sy - 1.6, L)
                 + line('M%.1f %.1f L%.1f %.1f M%.1f %.1f L%.1f %.1f M%.1f %.1f L%.1f %.1f' % (
                     sx, sy + 4, sx, sy - 4.6, sx, sy + 4, sx - 2.6, sy - 3.8, sx, sy + 4, sx + 2.6, sy - 3.8), '#c8a878', 0.8))
    return s + paint(ctx, P, pal()) + extra + shine(tier, a=(50, 14), b=(54, 34))


# ================================================================ charms

def charm(ctx, tier):
    s = grand(ctx, '#ffe08a', 0.5) if tier == 3 else ''
    P = []
    if tier == 1:
        # a single wax bead on a knotted cord
        cord = 'M31 31 C22 26 16 18 18 12 C20 6 44 6 46 12 C48 18 42 26 33 31'
        P.append(Part('limb', pth(cord), width=2, fill='#a8885a'))
        P.append(Part('fill', ell(32, 42, 10.6, 10.2), fill='#f2e2a8', shade='#caa868', off=(-2.4, -2.6), line=WAX_LINE,
                      over=line('M24 38 Q32 34.8 40 38', '#fff8d8', 1.2, op=0.9) + dot(32, 42, 2.2, '#caa868'),
                      hl=spec(27.4, 37.6, 2.8, 1.8, rot=-30, op=0.9)))
        P.append(Part('fill', ell(32, 30.6, 2.6, 2.2), fill='#a8885a', shade='#7a5a34', off=(-0.5, -0.5), line=L))
        P.append(Part('limb', pth('M30 52 L28.6 58 M34 52 L35.4 58'), width=1.6, fill='#a8885a'))
    elif tier == 2:
        # a braided cord knot, red and gold, with two tassels
        P.append(Part('limb', pth('M32 25 C22 11 10 19 18 27 C24 33 32 29 32 25 C42 11 54 19 46 27 C40 33 32 29 32 25 '
                                  'C22 35 26 47 32 45 C38 47 42 35 32 25'), width=4.2, fill='#c8352a',
                      over=line('M32 25 C22 11 10 19 18 27 C24 33 32 29 32 25 C42 11 54 19 46 27 C40 33 32 29 32 25 '
                                'C22 35 26 47 32 45 C38 47 42 35 32 25', GOLD, 1.0, op=0.95)))
        P.append(Part('fill', ell(32, 25, 3.4, 3.4), fill=GOLD, shade=GOLD_SH, off=(-0.6, -0.6), line=GOLD_LINE))
        for x0, x1 in ((24, 18), (40, 46)):
            P.append(Part('fill', pth('M%.1f 35 L%.1f 37 L%.1f 50 C%.1f 52 %.1f 52 %.1f 50 Z' % (x0 - 1.6, x0 + 1.6, x1 + 2.6, x1 + 1.4, x1 - 2, x1 - 2.6)),
                          fill='#c8352a', shade='#8a1e1a', off=(-0.6, -0.6), line=L,
                          over=line('M%.1f 39 L%.1f 39' % (x1 - 1.4 + (x0 - x1) * 0.4, x1 + 2.2 + (x0 - x1) * 0.4), GOLD, 1.6)))
    else:
        # a gold locket on a chain, a garnet in its lid
        chain = ''.join(dot(32 + 16 * math.cos(a), 24 - 13 * math.sin(a), 1.2, GOLD) for a in (
            math.radians(d) for d in range(10, 171, 16)))
        s += ''.join('<circle cx="%.1f" cy="%.1f" r="1.9" fill="none" stroke="%s" stroke-width="1"/>' % (
            32 + 16 * math.cos(a), 24 - 13 * math.sin(a), GOLD_LINE) for a in (math.radians(d) for d in range(10, 171, 16)))
        s += chain
        heart = 'M32 36 C28.4 28.6 14.4 28.6 14.4 40 C14.4 49 24 53.6 32 59 C40 53.6 49.6 49 49.6 40 C49.6 28.6 35.6 28.6 32 36 Z'
        P.append(Part('fill', ell(32, 27.4, 3, 3), fill=GOLD, shade=GOLD_SH, off=(-0.6, -0.6), line=GOLD_LINE, over=dot(32, 27.4, 1.2, GOLD_LINE)))
        P.append(Part('fill', pth(heart), fill=GOLD, shade=GOLD_SH, off=(-2.6, -2.8), line=GOLD_LINE,
                      over=line('M18 40 C18 33 27 32 31 38', GOLD_HI, 1.4, op=0.9)
                      + '<path d="%s" fill="none" stroke="%s" stroke-width="1" opacity="0.8"/>' % (
                          'M32 40 C29.6 35 21 35 21 41.4 C21 46.6 26.6 49.6 32 53 C37.4 49.6 43 46.6 43 41.4 C43 35 34.4 35 32 40 Z', GOLD_SH),
                      hl=spec(20, 38, 1.8, 3.2, rot=20, op=0.9)))
        P.append(Part('fill', ell(32, 44, 4.4, 4.4), fill='#d8304a', shade='#8a1a2e', off=(-1, -1), line=GOLD_LINE,
                      hl=dot(30.6, 42.6, 1.2, '#ffffff')))
    return s + paint(ctx, P, pal()) + shine(tier, a=(52, 50), b=(11, 52))


SLOTS = {'candle': candle, 'coat': coat, 'boots': boots, 'charm': charm}


# ================================================================ tiers 4 and 5 (v3, spec 8.1)
# Two more steps up the same ladder, each with its own mark behind the icon
# so a tier reads before its details do:
#   4  rimed:   frost steel, ice and pale bronze from the Carillon; a cold
#               rime glow behind and three ice-crystal glints
#   5  radiant: white gold, rose-window glass, or night-ink with silver;
#               a halo of rays behind and four warm sparkles
# Names (spec 8.1): knight Carillon Blade / Lastlight, witch Lanternspire /
# Sunwick Staff, runner Glasswing Knife / Nightneedle, founder Bourdon Maul /
# Tollking, sexton Barrow Spade / Requiem Spade; candle Paschal Candle /
# Beacon Candle; coat Rime Mail / Sanctum Plate; boots Rimed Greaves /
# Deepwalkers; charm Reliquary / Halo.

FROST, FROST_SH, FROST_LINE = '#e4f4fc', '#9dbfd6', '#16283a'
ICE, ICE_SH, ICE_DEEP = '#bfe4f4', '#7eaecc', '#4a7ea4'
DAWN, DAWN_SH, DAWN_HI = '#fff0c0', '#e0b050', '#fffaf0'
INK, INK_SH = '#2c2644', '#17132a'
SILVER, SILVER_SH = '#dcdff0', '#9a9eb8'
NIGHT = '#e8e0ff'
ROSE, ROSE_SH = '#e0506a', '#a02a44'
BLUE, BLUE_SH = '#5a8ae8', '#2e56a8'
RIBBON = '#d86a8a'


def rimed(ctx):
    """Tier 4's mark: a cold rime glow behind the icon."""
    return glow(ctx, 32, 32, 30, ICE, 0.6)


def radiant(ctx, col='#ffe6a0', core='#ffc860'):
    """Tier 5's mark: a halo of twelve rays behind the icon, fading out, and
    a warm glow."""
    grad = ctx.radgrad([(0, col, 0.95), (0.55, col, 0.65), (0.85, col, 0.35), (1, col, 0)], cx=32, cy=32, r=30,
                        units='userSpaceOnUse')
    d = ''
    for i in range(12):
        a = math.pi * 2 * i / 12 + math.pi / 12
        pts = [(9, a - 0.2), (30, a - 0.04), (30, a + 0.04), (9, a + 0.2)]
        d += 'M' + ' L'.join('%.2f %.2f' % (32 + r * math.cos(t), 32 + r * math.sin(t)) for r, t in pts) + ' Z '
    return glow(ctx, 32, 32, 29, core, 0.5) + '<path d="%s" fill="%s"/>' % (d, grad)


def star6(x, y, r, col, op=1.0):
    pts = []
    for k in range(12):
        a = -math.pi / 2 + k * math.pi / 6
        rr = r if k % 2 == 0 else r * 0.36
        pts.append('%.2f %.2f' % (x + rr * math.cos(a), y + rr * math.sin(a)))
    return '<path d="M%sZ" fill="%s" opacity="%s"/>' % (' L'.join(pts), col, op)


def crystal(x, y, r, col=FROST_LINE):
    """Tier 4's glint: a six-point ice crystal, outlined."""
    return star6(x, y, r, col) + star6(x, y, r * 0.66, '#ffffff')


def glints(tier, pts, col=L):
    """Three ice crystals (tier 4) or four warm sparkles (tier 5)."""
    if tier == 4:
        return ''.join(crystal(x, y, 4.2 if i == 0 else 3.4) for i, (x, y) in enumerate(pts[:3]))
    return ''.join(sparkle(x, y, 3.4 if i == 0 else 2.7, col, '#fff6d8') for i, (x, y) in enumerate(pts[:4]))


def sc(x, y):
    """A point on the icon's diagonal (x along it, y across) in frame units."""
    c = math.cos(math.radians(-45))
    s = math.sin(math.radians(-45))
    return 32 + x * c - y * s, 32 + x * s + y * c


def icicle(x, y, w, h, line_col=FROST_LINE):
    """An icicle hanging from (x, y), w wide and h long."""
    return ('<path d="M%.1f %.1f L%.1f %.1f L%.1f %.1f Z" fill="%s" stroke="%s" stroke-width="1.1" stroke-linejoin="round"/>' % (
        x - w / 2, y, x + w / 2, y, x + w * 0.08, y + h, FROST, line_col)
            + line('M%.1f %.1f L%.1f %.1f' % (x - w * 0.18, y + 0.6, x - w * 0.02, y + h * 0.6), '#ffffff', 0.7))


def little_bell(x, y, k):
    """A small bell on the diagonal, its crown at +x and its mouth toward -x
    (hanging): a round crown, a waist, a flared lip."""
    return ('M%.2f %.2f C%.2f %.2f %.2f %.2f %.2f %.2f C%.2f %.2f %.2f %.2f %.2f %.2f L%.2f %.2f L%.2f %.2f '
            'L%.2f %.2f C%.2f %.2f %.2f %.2f %.2f %.2f Z') % (
        x + 2.6 * k, y - 2.6 * k,
        x + 4.8 * k, y - 2.6 * k, x + 4.8 * k, y + 2.6 * k, x + 2.6 * k, y + 2.6 * k,
        x + 0.6 * k, y + 3.0 * k, x - 1.8 * k, y + 3.2 * k, x - 3.2 * k, y + 4.8 * k,
        x - 4.2 * k, y + 4.8 * k, x - 4.2 * k, y - 4.8 * k, x - 3.2 * k, y - 4.8 * k,
        x - 1.8 * k, y - 3.2 * k, x + 0.6 * k, y - 3.0 * k, x + 2.6 * k, y - 2.6 * k)


def bell_part(x, y, k):
    """A little bronze bell (little_bell) as a Part, its lip band and clapper drawn."""
    return Part('fill', D(little_bell(x, y, k)), fill=BRONZE_HI, shade=BRONZE, off=(-0.6, -0.6), line=BRONZE_LINE,
                over=Dg(line('M%.2f %.2f L%.2f %.2f' % (x - 2.8 * k, y - 4.2 * k, x - 2.8 * k, y + 4.2 * k), BRONZE_SH, 0.9 * k)
                        + dot(x - 4.9 * k, y, 1.2 * k, BRONZE_LINE)),
                hl=Dg(dot(x + 2.8 * k, y - 1.2 * k, 0.7 * k, '#ffffff')))


def sword45(ctx, tier):
    P = []
    if tier == 4:
        # Carillon Blade: a broad frost blade, rime at its base, a bronze guard
        # hung with two little bells, a bell for a pommel
        s = rimed(ctx)
        P.append(Part('limb', D('M-26 0 L-15 0'), width=4.4, fill='#4a5a7a',
                      over=Dg(line('M-24 -2 L-22.6 2 M-21 -2 L-19.6 2 M-18 -2 L-16.6 2', '#26324a', 0.8))))
        rime = ('M-12 -4.2 Q-9.6 -1.4 -7.6 -4.2 Q-5.6 -0.8 -3 -4.2 Q-0.8 -1.6 1.4 -4.2 L1.4 4.2 Q-0.8 1.6 -3 4.2 '
                'Q-5.6 0.8 -7.6 4.2 Q-9.6 1.4 -12 4.2 Z')
        P.append(Part('fill', D('M-12 -4.2 L22.6 -4.2 L32 0 L22.6 4.2 L-12 4.2 Z'), fill=FROST, shade=FROST_SH, off=(0, -2),
                      line=FROST_LINE,
                      over=Dg(line('M-8 0.2 L22 0.2', ICE_SH, 1.5) + line('M-8 -2.6 L23 -2.6', '#ffffff', 0.9)
                              + '<path d="%s" fill="%s" opacity="0.95"/>' % (rime, ICE)
                              + line('M-11 -2 L-9 1.6 M-6 -2.4 L-4.6 2 M-1.4 -2 L0 1.4', '#ffffff', 0.8))))
        P.append(Part('fill', D('M-15.4 -9 L-12.2 -9 L-12.2 9 L-15.4 9 Z'), fill=BRONZE, shade=BRONZE_SH, off=(-0.8, 0),
                      line=BRONZE_LINE))
        for k in (-1, 1):
            P.append(bell_part(-14.6, k * 10.6, 1.3))
        P.append(Part('fill', De(-13.8, 0, 2.6, 2.6), fill=ICE, shade=ICE_DEEP, off=(-0.6, -0.6), line=FROST_LINE,
                      hl=Dg(dot(-14.4, -0.8, 0.8, '#ffffff'))))
        P.append(bell_part(-27.6, 0, 1.2))
        return s + paint(ctx, P, pal()) + glints(4, [(52, 14), (13, 48), (48, 40)])
    # Lastlight: a white-gold flame-bladed sword (a flamberge) with a candle's
    # core burning up it, wings for a guard, a little flame at the pommel
    s = radiant(ctx)
    P.append(Part('limb', D('M-26 0 L-15 0'), width=4.2, fill='#fff8e8',
                  over=Dg(line('M-23 -2.1 L-23 2.1 M-19 -2.1 L-19 2.1', GOLD, 1.4))))
    top, bot = [], []
    for i in range(9):
        x = -12 + i * 4.2
        w = 4.0 + (0.9 if i % 2 else -0.3)
        top.append('%.1f %.1f' % (x, -w))
        bot.append('%.1f %.1f' % (x, w))
    blade = 'M' + ' L'.join(top) + ' L34 0 L' + ' L'.join(reversed(bot)) + ' Z'
    P.append(Part('fill', D(blade), fill=DAWN, shade=DAWN_SH, off=(0, -2), line=GOLD_LINE,
                  over=Dg(line('M-9 0 C0 -1.2 10 1.2 26 0', '#ffa03a', 2.0) + line('M-8 0 C0 -1 10 1 24 0', '#fff6d8', 0.9)
                          + line('M-9 -2.6 L24 -2.6', '#ffffff', 0.8, op=0.9))))
    for k in (-1, 1):
        wing = ('M-12.4 %.1f C-14 %.1f -17 %.1f -21 %.1f C-19.4 %.1f -19.8 %.1f -18.4 %.1f C-18.6 %.1f -17.6 %.1f -16 %.1f '
                'C-15.8 %.1f -14.4 %.1f -12.4 %.1f Z') % (
            k * 1.6, k * 6, k * 11.6, k * 14.6, k * 11.8, k * 10.4, k * 9.6, k * 7.6, k * 6.8, k * 5.8, k * 4, k * 2.6, k * 2.2)
        P.append(Part('fill', D(wing), fill='#fffaf0', shade='#e8d49a', off=(-0.6, -0.6), line=GOLD_LINE,
                      over=Dg(line('M-14 %.1f L-18.4 %.1f' % (k * 3.4, k * 9.6), GOLD, 0.8))))
    P.append(Part('fill', De(-13.6, 0, 3.4, 3.4), fill=GOLD, shade=GOLD_SH, off=(-0.6, -0.6), line=GOLD_LINE,
                  over=Dg(dot(-13.6, 0, 1.6, '#ff8a3a') + dot(-14.2, -0.6, 0.6, '#ffffff'))))
    P.append(Part('fill', D('M-26.4 -3.4 L-29.4 -3.4 Q-31.6 0 -29.4 3.4 L-26.4 3.4 Z'), fill=GOLD, shade=GOLD_SH, off=(-0.5, -0.5),
                  line=GOLD_LINE))
    px, py = sc(-30.4, 0)
    fl = flame(ctx, px - 0.6, py - 0.4, 5.2, 9.4, lean=0.6, line_w=1.0, halo=False)
    return s + paint(ctx, P, pal()) + fl + glints(5, [(53, 12), (12, 30), (40, 54), (30, 8)])


def staff45(ctx, tier):
    P = []
    haft = 'M-26.6 1 C-19 -1.6 -12 2 -4 0 C2 -1.4 5 0.6 8 0'
    if tier == 4:
        # Lanternspire: a birch staff crowned with a spired lantern of frosted
        # glass, its flame inside
        s = rimed(ctx)
        P.append(Part('limb', D(haft), width=4.4, fill='#e6e0d6',
                      over=Dg(line('M-20 -1.8 L-18.4 -1.8 M-12 1.8 L-10 1.6 M-6 -1.6 L-4.6 -1.8', '#4a4038', 1.0)
                              + line('M-16 -1.4 L-15 1.8 M-2 -1.8 L-1 1.8', SILVER_SH, 1.3))))
        P.append(Part('fill', D('M6.4 -4.4 L9.6 -4.4 L9.6 4.4 L6.4 4.4 Z'), fill=SILVER, shade=SILVER_SH, off=(-0.4, -0.4),
                      line=FROST_LINE))
        glass = ctx.radgrad([(0, '#fff4cf'), (0.5, '#ffd88a'), (1, '#bfe4f4')], cx=0.5, cy=0.5, r=0.6)
        P.append(Part('fill', D('M9.4 -7.6 L20.8 -8.2 L20.8 8.2 L9.4 7.6 Z'), fill=glass, no_shade=True, line=FROST_LINE))
        P.append(Part('fill', D('M20.2 -9.8 L23.4 -9.8 L32 0 L23.4 9.8 L20.2 9.8 Z'), fill=SILVER, shade=SILVER_SH, off=(-0.8, -1),
                      line=FROST_LINE, over=Dg(line('M22.6 -7 L29.4 0 L22.6 7', ICE_SH, 0.9))))
        P.append(Part('fill', De(33.2, 0, 1.8, 1.8), fill=SILVER, shade=SILVER_SH, off=(-0.4, -0.4), line=FROST_LINE))
        gx_, gy_ = sc(15, 0)
        fl = glow(ctx, gx_, gy_, 11, '#ffd070', 0.7) + flame_at(ctx, 14.4, 0.6, 10.4)
        bars = Dg(line('M9.6 -2.8 L20.6 -3 M9.6 2.8 L20.6 3', FROST_LINE, 1.6) + line('M9.6 -2.8 L20.6 -3 M9.6 2.8 L20.6 3', SILVER, 0.8)
                  + '<path d="M10 -7.2 L20.4 -7.8 L20.4 -3.4 L10 -3.2 Z" fill="%s" opacity="0.35"/>' % ICE)
        return s + paint(ctx, P, pal()) + fl + bars + glints(4, [(14, 14), (52, 48), (8, 36)])
    # Sunwick Staff: white-gold, a red ribbon wound on it, a sun on its head
    # with a flame at its heart
    s = radiant(ctx)
    P.append(Part('limb', D(haft), width=4.4, fill='#f6e2a2',
                  over=Dg(line('M-6 -1.8 L-5 1.8 M-3.6 -1.8 L-2.6 1.8 M-20 -1.8 L-19 1.8', RIBBON, 1.4)
                          + line('M-14 -2 L-14 2', GOLD_SH, 1.4))))
    cx, cy = 17.4, 0
    rays = ''
    for i in range(12):
        a = math.pi * 2 * i / 12
        rays += 'M%.2f %.2f L%.2f %.2f L%.2f %.2f Z ' % (
            cx + 7.4 * math.cos(a - 0.2), cy + 7.4 * math.sin(a - 0.2), cx + 12 * math.cos(a), cy + 12 * math.sin(a),
            cx + 7.4 * math.cos(a + 0.2), cy + 7.4 * math.sin(a + 0.2))
    P.append(Part('fill', D(rays), fill=GOLD, shade=GOLD_SH, off=(-0.4, -0.4), line=GOLD_LINE, lw=0.9))
    P.append(Part('fill', D('M6 -3 L10.4 -3 L10.4 3 L6 3 Z'), fill=GOLD, shade=GOLD_SH, off=(-0.4, -0.4), line=GOLD_LINE))
    P.append(Part('fill', De(cx, cy, 8, 8), fill=DAWN, shade='#f0c870', off=(-1, -1), line=GOLD_LINE,
                  over=Dg('<circle cx="%.1f" cy="%.1f" r="5.6" fill="none" stroke="%s" stroke-width="1"/>' % (cx, cy, GOLD))))
    fl = flame_at(ctx, cx - 1.2, 1.2, 10)
    return s + paint(ctx, P, pal()) + fl + glints(5, [(12, 13), (54, 44), (38, 58), (5, 34)])


def knife45(ctx, tier):
    P = []
    if tier == 4:
        # Glasswing Knife: a blade of clear glass, prism-tinted, glass moth
        # wings for a guard
        s = rimed(ctx)
        P.append(Part('limb', D('M-21 0 L-8 0'), width=4.4, fill='#2e3a54',
                      over=Dg(line('M-19 -1.8 L-17.6 1.8 M-16 -1.8 L-14.6 1.8 M-13 -1.8 L-11.6 1.8', SILVER, 0.8))))
        for k in (-1, 1):
            P.append(Part('fill', D('M-7 0 C-11 %.1f -5.4 %.1f -2.4 %.1f C-2 %.1f -4.6 %.1f -7 0 Z' % (k * 4, k * 12.4, k * 11.4, k * 6.6, k * 2)),
                          fill='#e2f2fc', shade='#a8cce0', off=(-0.4, -0.4), line=FROST_LINE,
                          over=Dg(line('M-6.4 %.1f L-3.6 %.1f M-5.4 %.1f L-6.6 %.1f' % (k * 1.4, k * 10.4, k * 5.4, k * 9.6), ICE_DEEP, 0.8)
                                  + dot(-4.6, k * 8, 1.5, '#c8a8ff'))))
        glass = ctx.lingrad([(0, '#f4fbff'), (0.45, '#d8e8ff'), (0.75, '#e8d8ff'), (1, '#ffe0ec')], x1=0, y1=0, x2=1, y2=0)
        P.append(Part('fill', D('M-6 -3.8 L8 -4.2 C16 -4.4 22.4 -1.4 27.6 3.2 C19 2 10 3.4 -6 3.4 Z'), fill=glass, shade='#a8bcd8',
                      off=(0, -1.8), line=FROST_LINE,
                      over=Dg(line('M-3 -2 L14 -2.6 M2 2 L18 1.2', '#ffffff', 1.0) + line('M6 -3.8 L10 3.2 M14 -3.8 L17.6 2.2', '#a8bcd8', 0.8))))
        P.append(Part('fill', De(-22.6, 0, 2.6, 2.6), fill=ICE, shade=ICE_DEEP, off=(-0.5, -0.5), line=FROST_LINE,
                      hl=Dg(dot(-23.2, -0.8, 0.8, '#ffffff'))))
        return s + paint(ctx, P, pal()) + glints(4, [(48, 48), (14, 14), (56, 26)])
    # Nightneedle: a long black needle edged in silver, a crescent moon for a
    # guard, a star at its point
    s = radiant(ctx, NIGHT, '#b8b0f0')
    P.append(Part('limb', D('M-22 0 L-8.4 0'), width=4.4, fill=INK,
                  over=Dg(line('M-19 -2 L-19 2 M-15 -2 L-15 2 M-11 -2 L-11 2', SILVER, 1.1))))
    P.append(Part('fill', D('M-7 -2.6 L26 -1.1 L33 0 L26 1.1 L-7 2.6 Z'), fill=INK, shade=INK_SH, off=(0, 1.4), line=L,
                  over=Dg(line('M-5 -1.6 L27 -0.5', SILVER, 1.0) + line('M-5 1.4 L22 0.6', '#6a6490', 0.8))))
    P.append(Part('fill', D('M-9.6 -10.4 C-4 -7 -4 7 -9.6 10.4 C-7.4 5 -7.4 -5 -9.6 -10.4 Z'), fill=SILVER, shade=SILVER_SH,
                  off=(-0.6, 0), line=L))
    P.append(Part('fill', De(-24, 0, 3.2, 3.2), fill=NIGHT, shade='#b0a8d8', off=(-0.6, -0.6), line=L,
                  hl=Dg(dot(-24.8, -0.8, 1.0, '#ffffff'))))
    tx, ty = sc(33.6, 0)
    star = star4(tx, ty, 6.4, L) + star4(tx, ty, 4.6, '#ffffff')
    return s + paint(ctx, P, pal()) + star + glints(5, [(12, 12), (50, 50), (22, 56), (58, 30)])


def maul45(ctx, tier):
    P = []
    if tier == 4:
        # Bourdon Maul: the carillon's great bell on a haft, deep bronze
        # crusted with rime, icicles at its lip
        s = rimed(ctx)
        k, hx = 1.16, 5.2
        body, body_sh, hi = '#b0703a', '#744620', '#e6ae6a'
    else:
        # Tollking: a white-gold bell wearing a crown about its waist, its
        # mouth glowing
        s = radiant(ctx)
        k, hx = 1.1, 7.0
        body, body_sh, hi = '#fff0c4', '#dcae52', '#ffffff'
    haft = '#9aa6c0' if tier == 4 else '#f6e2a2'
    P.append(Part('limb', D('M-28 0 L6 0'), width=4.8, fill=haft,
                  over=Dg(line('M-24 -2.2 L-22.4 2.2 M-21 -2.2 L-19.4 2.2 M-18 -2.2 L-16.4 2.2', '#4a4e66' if tier == 4 else GOLD_SH, 1.0))))

    def B(x, y):
        return '%.2f %.2f' % (hx + x * k, y * k)

    def Bp(x, y):
        return [float(v) for v in B(x, y).split()]
    bell = ('M%s C%s %s %s L%s C%s %s %s C%s %s %s L%s C%s %s %s C%s %s %s L%s C%s %s %s Z' % (
        B(-8, -6), B(-8, -8), B(-6.4, -9), B(-4, -9), B(3, -9.6), B(6, -10), B(8.6, -13), B(10.4, -14.4),
        B(12.4, -15.6), B(14, -14.6), B(14, -12.4), B(14, 12.4), B(14, 14.6), B(12.4, 15.6), B(10.4, 14.4),
        B(8.6, 13), B(6, 10), B(3, 9.6), B(-4, 9), B(-6.4, 9), B(-8, 8), B(-8, 6)))
    line_col = BRONZE_LINE if tier == 4 else GOLD_LINE
    clipid = ctx.clip(shp(D(bell)))
    if tier == 4:
        crust = ('M%s C%s %s %s L%s C%s %s %s L%s C%s %s %s L%s Z' % (
            B(-9, -10), B(-6, -11), B(-4.4, -8.4), B(-3, -10.4), B(-2.2, -6), B(-3.8, -3), B(-2, 0), B(-3.6, 3),
            B(-2.2, 6.4), B(-3, 9.6), B(-4.6, 9.4), B(-6, 11), B(-9, 10)))
        deco = ('<g clip-path="%s"><path d="%s" transform="%s" fill="%s"/></g>' % (clipid, crust, DIAG, FROST)
                + Dg(line('M%s L%s' % (B(6.6, -11.4), B(6.6, 11.4)), body_sh, 1.6)
                     + ''.join(dot(*Bp(x, y), r=0.9, col='#ffffff') for x, y in ((4, -8), (8, 4), (10, -11), (5, 7)))))
    else:
        pts = []
        for i, y in enumerate((-9.8, -6.5, -3.3, 0, 3.3, 6.5, 9.8)):
            pts.append(B(-0.6 if i % 2 else 4.2, y))
        crown = 'M%s L%s L%s L%s Z' % (B(-2.6, -10), ' L'.join(pts), B(-2.6, 10), B(-2.6, -10))
        deco = (Dg('<path d="%s" fill="%s" stroke="%s" stroke-width="1" stroke-linejoin="round"/>' % (crown, GOLD, line_col)
                   + ''.join(dot(*Bp(x, y), r=1.1, col='#d8304a') for x, y in ((0.6, -6.5), (0.6, 0), (0.6, 6.5)))
                   + line('M%s L%s' % (B(8.6, -12.6), B(8.6, 12.6)), GOLD, 1.4)))
    P.append(Part('fill', D(bell), fill=body, shade=body_sh, off=(-1.8, -2), line=line_col, over=deco,
                  hl=Dg(spec(Bp(0, -6)[0], Bp(0, -6)[1], 3.4, 1.0, rot=0, op=0.9))))
    mx, my = Bp(14, 0)
    inside = '#1e2c40' if tier == 4 else '#5a2a08'
    P.append(Part('fill', De(mx, my, 2.4 * k, 14.2 * k), fill=inside, shade=inside, no_shade=True, line=line_col,
                  under=Dg(glow(ctx, mx + 4, my, 10, ICE if tier == 4 else '#ffb24a', 0.75)),
                  over=Dg(dot(mx + 0.4, my + 4.6 * k, 2.4 * k, body_sh) + dot(mx, my + 4 * k, 0.8, hi))))
    kx, ky = Bp(-9.6, 0)
    P.append(Part('fill', De(kx, ky, 2.2 * k, 3.2 * k), fill=body, shade=body_sh, off=(-0.6, -0.6), line=line_col))
    P.append(Part('fill', De(-29.2, 0, 3.2, 3.2), fill=SILVER if tier == 4 else GOLD, shade=SILVER_SH if tier == 4 else GOLD_SH,
                  off=(-0.6, -0.6), line=L))
    out = s + paint(ctx, P, pal())
    if tier == 4:
        for y, h in ((2.4, 6.4), (7.4, 5.2), (11.8, 4.2)):
            x, yy = sc(mx - 0.4, y * k)
            out += icicle(x, yy - 0.6, 2.8, h)
        return out + glints(4, [(14, 12), (10, 36), (40, 52)])
    return out + glints(5, [(12, 12), (8, 32), (36, 56), (58, 40)])


def spade45(ctx, tier):
    P = []
    grip = 'M-30.6 -4.6 L-24 -4.6 L-24 4.6 L-30.6 4.6 C-32.4 4.6 -33 3 -33 0 C-33 -3 -32.4 -4.6 -30.6 -4.6 Z'
    if tier == 4:
        # Barrow Spade: a dark iron blade shaped like a barrow's door, its
        # arch glowing faint blue, the edge crusted with rime; a grave
        # lantern hangs from the socket
        s = rimed(ctx)
        P.append(Part('limb', D('M-24 0 L6 0'), width=3.8, fill='#4a4e66',
                      over=Dg(line('M-16 -1.6 L-16 1.6 M-4 -1.6 L-4 1.6', ICE_SH, 1.2))))
        P.append(Part('fill', D(grip), fill='#8a90a8', shade='#5a5e78', off=(-0.6, -0.6), line=L,
                      over=Dg('<path d="M-30 -2.4 L-26 -2.4 L-26 2.4 L-30 2.4 Z" fill="%s"/>' % L)))
        P.append(Part('fill', D('M6 -3 L10.4 -3 L10.4 3 L6 3 Z'), fill=IRON, shade=IRON_SH, off=(-0.5, -0.5), line=L))
        blade = 'M10 -8.6 L19 -8.6 C25.6 -8.6 30.8 -4.8 30.8 0 C30.8 4.8 25.6 8.6 19 8.6 L10 8.6 C9 4 9 -4 10 -8.6 Z'
        door = 'M13 -4.4 L19.6 -4.4 C23 -4.4 25.4 -2.4 25.4 0 C25.4 2.4 23 4.4 19.6 4.4 L13 4.4 Z'
        edge = ('<g clip-path="%s"><path d="M24 -12 Q26.6 -6 27.4 -4 Q29 0 27.6 3.6 Q26.4 7 24 12 L40 12 L40 -12 Z" transform="%s" '
                'fill="%s"/></g>') % (ctx.clip(shp(D(blade))), DIAG, FROST)
        P.append(Part('fill', D(blade), fill='#5a6078', shade='#3a3e54', off=(-1.4, -1.8), line=L,
                      over=edge + Dg('<path d="%s" fill="%s" stroke="%s" stroke-width="1.1"/>' % (door, '#16283a', L)
                                     + '<path d="M14 -2.6 L19.6 -2.6 C22 -2.6 23.4 -1.2 23.4 0 C23.4 1.2 22 2.6 19.6 2.6 L14 2.6 Z" fill="%s" opacity="0.9"/>' % ICE_DEEP
                                     + dot(19, 0, 1.4, '#e4f4fc'))))
        lx, ly = sc(4, 3)
        chain = line('M%.1f %.1f L%.1f %.1f' % (lx, ly, lx, ly + 7), L, 1.2)
        lamp = ('<path d="M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z" fill="%s" stroke="%s" stroke-width="1.1"/>' % (
            lx - 3.4, ly + 7.6, lx + 3.4, ly + 7.6, lx + 2.8, ly + 15, lx - 2.8, ly + 15, '#e4f4fc', L)
                + '<path d="M%.1f %.1f L%.1f %.1f L%.1f %.1f Z" fill="%s" stroke="%s" stroke-width="1"/>' % (
                    lx - 4, ly + 7.8, lx + 4, ly + 7.8, lx, ly + 4.6, IRON, L)
                + '<path d="%s" fill="#bfe4f4"/>' % flame_d(lx, ly + 14, 3, 5.2, 0.2)
                + line('M%.1f %.1f L%.1f %.1f' % (lx - 3.2, ly + 15.4, lx + 3.2, ly + 15.4), IRON, 1.6))
        return s + paint(ctx, P, pal()) + chain + lamp + glints(4, [(52, 12), (10, 50), (54, 36)])
    # Requiem Spade: white gold, a lavender ribbon down its haft, a blade
    # like a bell's silhouette with a flame on it, a halo over its socket
    s = radiant(ctx, '#fff0d0', '#ffd890')
    P.append(Part('limb', D('M-24 0 L6 0'), width=4.0, fill='#f6e2a2',
                  over=Dg(line('M-20 -1.8 L-18 1.8 M-12 -1.8 L-10 1.8 M-4 -1.8 L-2 1.8', LAV, 1.5))))
    P.append(Part('fill', D(grip), fill=GOLD, shade=GOLD_SH, off=(-0.6, -0.6), line=GOLD_LINE,
                  over=Dg('<path d="M-30 -2.4 L-26 -2.4 L-26 2.4 L-30 2.4 Z" fill="%s"/>' % GOLD_LINE)))
    P.append(Part('fill', D('M6 -3.2 L10.4 -3.2 L10.4 3.2 L6 3.2 Z'), fill=GOLD, shade=GOLD_SH, off=(-0.5, -0.5), line=GOLD_LINE))
    blade = 'M10 -7 C14 -8.4 18 -9.6 22 -9.8 C26 -9.8 29 -6 30 -3 C31 -1.4 32.6 0 33.4 0 C32.6 0 31 1.4 30 3 C29 6 26 9.8 22 9.8 C18 9.6 14 8.4 10 7 C9 3 9 -3 10 -7 Z'
    P.append(Part('fill', D(blade), fill='#fff6dc', shade='#e4c070', off=(-1.4, -1.8), line=GOLD_LINE,
                  over=Dg(line('M12 -5.6 C18 -7.6 24 -7.8 28 -3.4', '#ffffff', 1.0, op=0.9)
                          + line('M12.6 5.8 C18 7.4 24 7.6 27.6 3.6', GOLD, 1.0))))
    ex, ey = sc(21, 0.4)
    emblem = ('<path d="%s" fill="#ffb040" stroke="%s" stroke-width="1"/>' % (flame_d(ex, ey + 4.4, 5.4, 9, 0.4), GOLD_LINE)
              + '<path d="%s" fill="#fff4d0"/>' % flame_d(ex, ey + 3.6, 2.6, 4.4, 0.2))
    hx, hy = sc(5.6, 0)
    halo = ('<ellipse cx="%.1f" cy="%.1f" rx="8.6" ry="3.2" fill="none" stroke="%s" stroke-width="4.2" transform="rotate(-45 %.1f %.1f)"/>'
            '<ellipse cx="%.1f" cy="%.1f" rx="8.6" ry="3.2" fill="none" stroke="%s" stroke-width="1.9" transform="rotate(-45 %.1f %.1f)"/>') % (
        hx, hy, GOLD_LINE, hx, hy, hx, hy, GOLD_HI, hx, hy)
    wisps = ''.join(pale_wisp(x, y, kk) for x, y, kk in ((50, 47, 1.0), (13, 15, 0.8)))
    return s + paint(ctx, P, pal()) + emblem + halo + wisps + glints(5, [(54, 12), (8, 44), (30, 58), (4, 22)])


def pale_wisp(x, y, k=1.0):
    """A gold-white wisp: the mourning wisp gone to rest."""
    d = flame_d(x, y + 4 * k, 7 * k, 12 * k, 1.2 * k)
    return ('<path d="%s" fill="#fff8e4" stroke="%s" stroke-width="1.2" stroke-linejoin="round" opacity="0.95"/>' % (d, GOLD_LINE)
            + dot(x - 1.4 * k, y + 0.8 * k, 0.8 * k, '#5a3a14') + dot(x + 1.4 * k, y + 0.8 * k, 0.8 * k, '#5a3a14'))


WEAPONS45 = {'knight': sword45, 'founder': maul45, 'witch': staff45, 'runner': knife45, 'sexton': spade45}


def wax_top(x0, x1, y, drips):
    """A candle's melted top edge from x0 to x1 at y, dripping at the given
    (x, length) points."""
    d = 'M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f' % (
        x0 - 0.6, y + 0.4, x0 - 0.6, y - 2.6, (x0 + x1) / 2 - 8, y - 3.6, (x0 + x1) / 2, y - 3.6,
        (x0 + x1) / 2 + 8, y - 3.6, x1 + 0.6, y - 2.6, x1 + 0.6, y + 0.4)
    d += ' L%.1f %.1f' % (x1 + 0.6, y + 4.4)
    for dx, ln in sorted(drips, reverse=True):
        d += ' C%.1f %.1f %.1f %.1f %.1f %.1f L%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f L%.1f %.1f' % (
            dx + 1.4, y + 5.6, dx + 1.4, y + 4.4 + ln, dx, y + 4.4 + ln, dx, y + 4.4 + ln,
            dx - 1.4, y + 4.4 + ln, dx - 1.4, y + 5.6, dx - 1.4, y + 4.4, dx - 1.4, y + 4.4)
    d += ' L%.1f %.1f Z' % (x0 - 0.6, y + 4.4)
    return d


def candle45(ctx, tier):
    P = []
    if tier == 4:
        # the Paschal Candle: tall and thick, painted with a red and gold band,
        # five red studs below it, on a frosted silver pricket
        s = rimed(ctx) + glow(ctx, 32, 17, 14, FLAME, 0.45)
        P.append(Part('fill', pth('M13 52 L51 52 Q50 58 41 59 L23 59 Q14 58 13 52 Z'), fill=SILVER, shade=SILVER_SH, off=(-1.4, -1.6),
                      line=FROST_LINE, over=line('M16 54 Q32 56.4 48 54', '#ffffff', 1.1)
                      + '<path d="M13.6 52.4 Q18 50.6 22 52.6 Q27 50.4 32 52.6 Q37 50.4 42 52.6 Q46 50.6 50.4 52.4 L50 54 Q32 56 14 54 Z" fill="%s"/>' % ICE))
        band = ('<path d="M21.4 30.4 L42.6 30.4 L42.6 35 L21.4 35 Z" fill="%s"/>' % ROSE
                + line('M21.4 30.8 L42.6 30.8 M21.4 34.6 L42.6 34.6', GOLD, 1.0)
                + '<path d="M32 37.2 L37.8 43.4 L32 49.6 L26.2 43.4 Z" fill="%s" stroke="%s" stroke-width="1.2" stroke-linejoin="round"/>' % (
                    ROSE, GOLD)
                + '<path d="%s" fill="%s" stroke="%s" stroke-width="0.8"/>' % (flame_d(32, 47, 4, 7.2, 0.3), GOLD, GOLD_LINE)
                + '<path d="M21.4 51 L42.6 51" stroke="%s" stroke-width="1.6"/>' % GOLD)
        P.append(Part('fill', pth('M21.4 53 L21.4 24 L42.6 24 L42.6 53 Z'), fill=WAX, shade=WAX_SH, off=(-3.4, 0), line=WAX_LINE,
                      over=band, hl=spec(24.4, 44, 1.1, 5, rot=0, op=0.8)))
        P.append(Part('fill', pth(wax_top(21.4, 42.6, 24.6, ((25.4, 5), (34.6, 8), (40, 3.6)))), fill='#fffaec', shade='#e8dcbc',
                      off=(-0.8, -0.6), line='#b89c6c', lw=0.9, rim=False))
        wick_y, h = 21.2, 15
        g = glints(4, [(52, 14), (11, 22), (54, 40)])
    else:
        # the Beacon Candle: a fat candle blazing in a gold brazier cup on a
        # stem, rubies round its rim
        s = radiant(ctx)
        P.append(Part('fill', pth('M19 54 L45 54 Q45.6 58.4 40 58.4 L24 58.4 Q18.4 58.4 19 54 Z'), fill=GOLD, shade=GOLD_SH, off=(-1, -1),
                      line=GOLD_LINE))
        P.append(Part('fill', pth('M28 47.6 L36 47.6 L37.4 54.6 L26.6 54.6 Z'), fill=GOLD, shade=GOLD_SH, off=(-0.8, -0.6), line=GOLD_LINE))
        P.append(Part('fill', pth('M21.6 40 L21.6 25.4 L42.4 25.4 L42.4 40 Z'), fill=WAX, shade=WAX_SH, off=(-3, 0), line=WAX_LINE))
        P.append(Part('fill', pth(wax_top(21.6, 42.4, 26, ((26.4, 4.4), (37.6, 6)))), fill='#fffaec', shade='#e8dcbc',
                      off=(-0.8, -0.6), line='#b89c6c', lw=0.9, rim=False))
        P.append(Part('fill', pth('M12.6 36 L51.4 36 C50.6 45 43 50 32 50 C21 50 13.4 45 12.6 36 Z'), fill=GOLD, shade=GOLD_SH,
                      off=(-2, -1.6), line=GOLD_LINE,
                      over=line('M13.4 38.6 L50.6 38.6', GOLD_HI, 1.4)
                      + ''.join('<circle cx="%.1f" cy="42.6" r="1.8" fill="#d8304a" stroke="%s" stroke-width="0.9"/>' % (x, GOLD_LINE)
                                for x in (20, 32, 44))
                      + dot(31.4, 42, 0.6, '#ffffff'),
                      hl=spec(19, 41.6, 1.4, 3, rot=30, op=0.8)))
        wick_y, h = 23.4, 16
        g = glints(5, [(52, 14), (11, 18), (55, 48), (8, 44)])
    body = paint(ctx, P, pal(L))
    wick_line = line('M32 %.1f Q31.4 %.1f 32.2 %.1f' % (wick_y + 1, wick_y - 1, wick_y - 3), '#241a14', 1.5)
    fl = flame(ctx, 32.2, wick_y - 2, h * 0.54, h, lean=0.8, halo=False)
    return s + body + wick_line + fl + g


def coat45(ctx, tier):
    P = []
    if tier == 4:
        # Rime Mail: frost-blue scale mail, a white fur collar, rime on the
        # shoulders, a blue belt
        s = rimed(ctx)
        body = coat_shape()
        rows = ''
        y, row = 16.0, 0
        while y < 58:
            x = 4.0 + (2.2 if row % 2 else 0)
            while x < 60:
                rows += 'M%.1f %.1f q2.2 3 4.4 0 ' % (x, y)
                x += 4.4
            y += 3.0
            row += 1
        scales = '<g clip-path="%s">%s</g>' % (ctx.clip(shp(pth(body))), line(rows, '#4e6c88', 0.9, op=0.9))
        P.append(Part('fill', pth(body), fill='#c6dcec', shade='#86a4be', off=(-3, -2.6), line=FROST_LINE, over=scales,
                      hl=spec(24, 24, 2, 5, rot=10, op=0.6)))
        P.append(Part('fill', pth('M17.8 38 L46.2 38 L46.4 42.4 L17.6 42.4 Z'), fill='#3a5a8a', shade='#26406a', off=(-0.8, -1),
                      line=FROST_LINE, rim=False,
                      over='<rect x="29.2" y="37.4" width="5.8" height="5.8" rx="1.2" fill="%s" stroke="%s" stroke-width="1"/>' % (
                          SILVER, FROST_LINE)))
        fur = ('M19.4 12.4 C20 9.2 23.4 9.4 25 10.4 C26.4 8.4 29.6 8.6 30.6 10.6 C32 8.6 35.4 8.8 36.2 10.8 C37.8 9.2 41.6 9.2 42.4 11 '
               'C45.6 10.6 46.4 14 44.6 15.6 C45 18.4 41.8 19.4 40.4 18 C39 20.6 35.4 20.4 34.4 18.6 C33 20.8 29.6 20.6 28.6 18.8 '
               'C27.4 20.6 23.6 20.4 23 18.2 C20.6 19.4 18 17.6 19 15.2 C17.2 14.6 17.6 12 19.4 12.4 Z')
        P.append(Part('fill', pth(fur), fill='#f6faff', shade='#c4d2e2', off=(-1, -1.2), line=FROST_LINE,
                      over=line('M24 14 L25 16 M30 13.6 L30.8 16 M36 13.8 L36.6 16.2 M41 14.2 L41.4 16', '#9eb2c8', 0.9)))
        g = crystal(14.2, 21, 3.4) + crystal(49.8, 21, 3.4) + glints(4, [(56, 8), (8, 50), (55, 48)])
        return s + paint(ctx, P, pal()) + g
    # Sanctum Plate: a gold cuirass with a rose window over the heart,
    # winged white pauldrons, a crimson skirt hemmed in gold
    s = radiant(ctx)
    plate = ('M21 12.6 C25 17.4 39 17.4 43 12.6 L47.4 15.6 C49 27 48.4 39 45.4 47.4 C41 51.4 23 51.4 18.6 47.4 '
             'C15.6 39 15 27 16.6 15.6 Z')
    skirt = 'M19.4 46.6 C25 50.6 39 50.6 44.6 46.6 L46.6 54.4 C40 58 24 58 17.4 54.4 Z'
    P.append(Part('fill', pth(skirt), fill='#a8304e', shade='#741c36', off=(-1.4, -1.4), line=L,
                  over=line('M17.6 53.8 C24 57.4 40 57.4 46.4 53.8', GOLD, 1.8)))
    rose = '<circle cx="32" cy="31" r="8.6" fill="%s" stroke="%s" stroke-width="1.4"/>' % (GOLD, GOLD_LINE)
    for i in range(8):
        a = math.pi * 2 * i / 8 - math.pi / 2
        x, y = 32 + 4.9 * math.cos(a), 31 + 4.9 * math.sin(a)
        rose += '<ellipse cx="%.2f" cy="%.2f" rx="2.6" ry="1.7" transform="rotate(%.1f %.2f %.2f)" fill="%s" stroke="%s" stroke-width="0.7"/>' % (
            x, y, math.degrees(a), x, y, (ROSE, BLUE)[i % 2], GOLD_LINE)
    rose += '<circle cx="32" cy="31" r="2.1" fill="#fff4c8" stroke="%s" stroke-width="0.8"/>' % GOLD_LINE
    trim = '<g clip-path="%s">%s</g>' % (ctx.clip(shp(pth(plate))), line(plate, '#fff4cc', 3.0))
    P.append(Part('fill', pth(plate), fill='#f2cc6a', shade='#bc8e30', off=(-3, -2.6), line=GOLD_LINE,
                  over=trim + rose + line('M24.4 19.6 C24.2 30 25 38 27 44', '#fff8e0', 1.1, op=0.8)
                  + line('M21 44.6 C26 47.6 38 47.6 43 44.6', GOLD_LINE, 1.0, op=0.5),
                  hl=spec(21.4, 24, 1.6, 5.4, rot=12, op=0.95)))
    for k in (-1, 1):
        x = 32 + k * 16.6
        wing = ('M%.1f 12 C%.1f 9.6 %.1f 10.6 %.1f 16 C%.1f 18 %.1f 20 %.1f 22.6 C%.1f 22.4 %.1f 24 %.1f 26.4 '
                'C%.1f 25 %.1f 21 %.1f 12 Z') % (
            x - k * 6, x + k * 2.4, x + k * 8, x + k * 9.4, x + k * 9.2, x + k * 8, x + k * 7.6, x + k * 5.6, x + k * 4.6,
            x + k * 3, x - k * 1, x - k * 2.6, x - k * 6)
        P.append(Part('fill', pth(wing), fill='#fffaf0', shade='#e0cc98', off=(-1, -1.2), line=GOLD_LINE,
                      over=line('M%.1f 14 C%.1f 15 %.1f 18 %.1f 21' % (x - k * 1, x + k * 3, x + k * 5.6, x + k * 6.4), GOLD, 1.1)))
    return s + paint(ctx, P, pal()) + glints(5, [(57, 8), (7, 8), (8, 52), (56, 50)])


def boots45(ctx, tier):
    P = []
    if tier == 4:
        # Rimed Greaves: frost steel, blue straps, rime crusting the cuffs, an
        # ice spur at each heel
        s = rimed(ctx)
        cols = (('#dcecf8', '#98b6cc'), ('#b8ccdc', '#7e98b0'))
    else:
        # Deepwalkers: night-ink boots trimmed in silver, their soles aglow,
        # the still water ringing under them
        s = radiant(ctx, NIGHT, '#b8b0f0')
        cols = (('#3a3458', '#201a36'), ('#2c2646', '#17132a'))
    for i, (x, y) in enumerate(((12.6, 45), (21.4, 54.4))):
        back = i == 0
        base, shade = cols[1] if back else cols[0]
        if tier == 4:
            over = (line('M%.1f %.1f L%.1f %.1f M%.1f %.1f L%.1f %.1f' % (x + 0.6, y - 20, x + 15.4, y - 20, x + 0.6, y - 14, x + 15.4, y - 14),
                         '#3a5a8a', 2.2, cap='butt')
                    + line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (x + 16, y - 11.6, x + 18.4, y - 6.4, x + 17.4, y - 2.2), FROST_LINE, 0.9, op=0.7)
                    + line('M%.1f %.1f L%.1f %.1f' % (x + 0.6, y - 1.6, x + 28.4, y - 1.6), '#26324a', 2.2, cap='butt')
                    + dot(x + 8, y - 8, 1.3, SILVER) + dot(x + 7.6, y - 8.4, 0.5, '#ffffff'))
        else:
            over = (line('M%.1f %.1f L%.1f %.1f' % (x + 0.6, y - 1.8, x + 28.4, y - 1.8), NIGHT, 2.0, cap='butt')
                    + line('M%.1f %.1f L%.1f %.1f M%.1f %.1f L%.1f %.1f' % (x + 0.6, y - 21, x + 15.4, y - 21, x + 15.8, y - 12, x + 18, y - 12.2),
                           SILVER, 1.3)
                    + line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (x + 16.4, y - 11, x + 22, y - 11, x + 26, y - 7.6), SILVER_SH, 1.0)
                    + dot(x + 8, y - 9, 1.6, NIGHT) + dot(x + 7.6, y - 9.4, 0.6, '#ffffff'))
        P.append(Part('fill', pth(boot_d(x, y)), fill=base, shade=shade, off=(-2, -2), line=L, over=over,
                      hl=spec(x + 4.4, y - 22.6, 1.4, 0.9, op=0.9) + spec(x + 23.6, y - 8.2, 2, 0.9, rot=-12, op=0.9)))
        if tier == 4:
            crust = ('M%.1f %.1f L%.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f '
                     'Q%.1f %.1f %.1f %.1f Z') % (x - 1, y - 25.6, x + 17, y - 25.6, x + 16.8, y - 30,
                                                 x + 14.6, y - 27, x + 12, y - 29.8, x + 9.4, y - 26.8, x + 7, y - 30.2,
                                                 x + 4.6, y - 27, x + 2, y - 29.6, x, y - 27, x - 1, y - 29.4)
            P.append(Part('fill', pth(crust), fill='#f6faff', shade='#c4d2e2', off=(-0.8, -0.8), line=FROST_LINE))
            P.append(Part('fill', pth('M%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (x + 0.6, y - 9.4, x - 7.4, y - 5.6, x + 0.6, y - 2.6)),
                          fill='#f6faff', shade=ICE, off=(-0.6, -0.8), line=FROST_LINE, lw=1.0))
        else:
            P.append(Part('fill', pth('M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (x - 1, y - 25.6, x + 17, y - 25.6, x + 16.4, y - 29,
                                                                                       x - 0.4, y - 29)),
                          fill=SILVER, shade=SILVER_SH, off=(-0.8, -0.8), line=L))
    extra = ''
    if tier == 5:
        for cx, cy, rx in ((27, 57.6, 14), (40, 59.4, 10)):
            extra += ('<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="2" fill="none" stroke="%s" stroke-width="2.6" opacity="0.8"/>'
                      '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="2" fill="none" stroke="%s" stroke-width="1.2"/>') % (
                cx, cy, rx, L, cx, cy, rx, NIGHT)
        return s + extra + paint(ctx, P, pal()) + glints(5, [(50, 12), (55, 34), (8, 20), (7, 56)])
    return s + paint(ctx, P, pal()) + glints(4, [(50, 13), (55, 34), (7, 55)])


def charm45(ctx, tier):
    P = []
    if tier == 4:
        # the Reliquary: a little frost-silver chasse (a casket with a low
        # pitched roof and a crest of finials) on a chain, its arched crystal
        # window showing the relic's flame
        s = rimed(ctx)
        pts = [(32 + 12 * math.cos(a), 21 - 10 * math.sin(a)) for a in (math.radians(d) for d in range(10, 171, 16))]
        s += ''.join('<circle cx="%.1f" cy="%.1f" r="1.9" fill="none" stroke="%s" stroke-width="1"/>' % (x, y, FROST_LINE) for x, y in pts)
        s += ''.join(dot(x, y, 1.2, SILVER) for x, y in pts)
        for x in (16.6, 47.4):
            P.append(Part('fill', ell(x, 52.6, 2.6, 2.4), fill=GOLD, shade=GOLD_SH, off=(-0.5, -0.5), line=GOLD_LINE))
        window = 'M26.4 47.6 L26.4 41.4 C26.4 38 28.8 37 32 37 C35.2 37 37.6 38 37.6 41.4 L37.6 47.6 Z'
        blind = ''.join('<path d="M%.1f 46.6 L%.1f 42 C%.1f 40 %.1f 39.4 %.1f 39.4 C%.1f 39.4 %.1f 40 %.1f 42 L%.1f 46.6" fill="none" '
                        'stroke="%s" stroke-width="1.1"/>' % (x0, x0, x0, x0 + 1.4, x0 + 3, x0 + 4.6, x0 + 6, x0 + 6, x0 + 6, FROST_SH)
                        for x0 in (18.4, 39.6))
        P.append(Part('fill', pth('M13.4 35 L50.6 35 L50.6 50.8 L13.4 50.8 Z'), fill=FROST, shade=FROST_SH, off=(-2.4, -2),
                      line=FROST_LINE,
                      over='<path d="M13.4 47.8 L50.6 47.8 L50.6 50.8 L13.4 50.8 Z" fill="%s"/>' % GOLD
                      + '<path d="M13.4 35 L16.4 35 L16.4 50.8 L13.4 50.8 Z M47.6 35 L50.6 35 L50.6 50.8 L47.6 50.8 Z" fill="%s"/>' % GOLD
                      + blind
                      + '<path d="%s" fill="#22324a" stroke="%s" stroke-width="1.1"/>' % (window, GOLD_LINE)
                      + '<path d="%s" fill="%s" opacity="0.5"/>' % (window, ICE),
                      hl=spec(19.6, 38.4, 2.4, 0.9, rot=0, op=0.9)))
        P.append(Part('fill', pth('M10.6 35.6 L18.4 25.8 L45.6 25.8 L53.4 35.6 Z'), fill=SILVER, shade=SILVER_SH, off=(-1.4, -1.4),
                      line=FROST_LINE,
                      over=line('M11.6 35 L52.4 35', GOLD, 1.6) + line('M19 26.4 L45 26.4', GOLD, 1.2)
                      + line('M16 32 L48 32 M20.4 28.8 L43.6 28.8', FROST_SH, 0.9, op=0.9)))
        for x, r in ((21.4, 1.9), (32, 2.8), (42.6, 1.9)):
            P.append(Part('fill', ell(x, 25.2 - r * 0.6, r, r), fill=GOLD, shade=GOLD_SH, off=(-0.5, -0.5), line=GOLD_LINE))
        fl = flame(ctx, 32, 47, 4.2, 7.4, lean=0.3, line_w=0.9, halo=False)
        return s + paint(ctx, P, pal()) + fl + glints(4, [(8, 46), (56, 46), (52, 10)])
    # the Halo: a gold halo ring, tilted, with a small flame burning at its
    # heart, floating free
    s = radiant(ctx)
    arc_b = 'M12.6 36 C12.6 30.4 21.4 27.4 32 27.4 C42.6 27.4 51.4 30.4 51.4 36'
    arc_f = 'M12.6 36 C12.6 41.6 21.4 44.6 32 44.6 C42.6 44.6 51.4 41.6 51.4 36'
    rim = line(arc_b, RIM, 10 + kit_rim()) + line(arc_f, RIM, 10 + kit_rim())
    back = rim + line(arc_b, GOLD_LINE, 10) + line(arc_b, GOLD_SH, 6.4) + line(
        'M14.6 34.4 C16.6 31 23 29.4 32 29.4 C41 29.4 47.4 31 49.4 34.4', GOLD, 1.2)
    heart = glow(ctx, 32, 32, 12, '#ffd070', 0.7) + flame(ctx, 32, 38.6, 7.4, 13, lean=0.6, line_w=1.1, halo=False)
    front = (''
             + '<path d="M12.6 36 C12.6 41.6 21.4 44.6 32 44.6 C42.6 44.6 51.4 41.6 51.4 36" fill="none" stroke="%s" stroke-width="10" '
             'stroke-linecap="round"/>' % GOLD_LINE
             + '<path d="M12.6 36 C12.6 41.6 21.4 44.6 32 44.6 C42.6 44.6 51.4 41.6 51.4 36" fill="none" stroke="%s" stroke-width="6.4" '
             'stroke-linecap="round"/>' % GOLD
             + '<path d="M16 39.4 C19.4 42 25 43 32 43" fill="none" stroke="%s" stroke-width="1.6" stroke-linecap="round"/>' % GOLD_HI
             + ''.join('<circle cx="%.1f" cy="%.1f" r="1.3" fill="#d8304a" stroke="%s" stroke-width="0.7"/>' % (x, y, GOLD_LINE)
                       for x, y in ((22, 42.6), (32, 44.6), (42, 42.6))))
    return s + back + heart + front + glints(5, [(52, 14), (12, 16), (54, 54), (10, 54)])


def kit_rim():
    import kit
    return kit.RIM_W


SLOTS45 = {'candle': candle45, 'coat': coat45, 'boots': boots45, 'charm': charm45}


def files():
    out = {}
    for cls, fn in WEAPONS.items():
        for tier in (1, 2, 3, 4, 5):
            ctx = Ctx('iw%s%d' % (cls[:2], tier))
            draw = fn if tier <= 3 else WEAPONS45[cls]
            out['art/items/weapon_%s_%d.svg' % (cls, tier)] = frost(svg64(ctx, draw(ctx, tier)), tier)
    for slot, fn in SLOTS.items():
        for tier in (1, 2, 3, 4, 5):
            ctx = Ctx('i%s%d' % (slot[:2], tier))
            draw = fn if tier <= 3 else SLOTS45[slot]
            out['art/items/%s_%d.svg' % (slot, tier)] = frost(svg64(ctx, draw(ctx, tier)), tier)
    return out


RIME_RIM = '#aee6ff'   # tier 4's sticker rim: frost, where every other tier's is candlelit cream


def frost(text, tier):
    """Tier 4 wears a frosted rim round its whole silhouette as well as its
    rime glow, so it reads as rimed by its outline, not by the glow's hue
    alone (the Sootrunner's and the Sexton's tier 3 already sit in a cool
    violet glow). Only the sticker rim is ever drawn in RIM."""
    return text.replace(RIM, RIME_RIM) if tier == 4 else text


if __name__ == '__main__':
    import build
    for rel, text in files().items():
        build.write(rel, text)
    print('wrote %d item icons' % len(files()))
