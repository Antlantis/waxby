"""The deeper worlds' story panels (v3, A5): the Bone Orchard, the Frozen
Carillon, the Shattered Sanctum, the Hushdeep and the homecoming, in the
v2 panels' storybook style (story_sets.py): full local colour for the
darkness to light, lights placed first and painted toward, faces and focal
points in the upper two thirds of the camera's frame (the dialogue box
covers the bottom quarter).

  orchard_vista   world_3            heartwood       boss_3_before, boss_3_after
  carillon_vista  world_4            escapement      boss_4_before, boss_4_after
  sanctum_vista   world_5            glass_throne    boss_5_before, boss_5_after
  glass_truth     boss_5_after       hushdeep_vista  world_6
  hushdeep_heart  boss_6_before, boss_6_after (the finale's stage)
  homecoming      homecoming

Manifest-only additions to v2's panels (EXTEND): undercandle's `grasp`
anchor and its warm `under_warm` light (off), hush_eye's `float` anchor.

Floors sit where the scenes' cameras (story.gd) keep them above the box:
y 318-330 on the 460-tall panels, 415 in the Heartwood, 440 on the
Hushdeep's shore. story.py merges PANELS and EXTEND into panels.json.
"""
import math

from kit import Part, pth
from common import Ctx, line, dot, flame_d, spec, mix, gx
from story_kit import (Panel, P, E, LIMB, draw, fillp, rect_d, rrect_d, ell_d, poly_d, arch_d, round_arch_d, radial,
                       vgrad, Rand, bell_parts, Glass, GLASS, CAME, FRONT_W, MID_W, BACK_W, fade, BRONZE_LINE)
from story_sets import (street_lamp, cloud_d, townsfolk, house, mosaic, pane, glass_bell, mullion, IRON, IRON_SH,
                        IRON_HI, WOOD, WOOD_SH, WOOD_HI, INK)

# ================================================================ the Bone Orchard's kit

BARK, BARK_SH, BARK_HI, BARK_LINE = '#cfc4a8', '#9a8c70', '#e8dfc6', '#2e2018'
ROOT, ROOT_SH = '#6e4e36', '#4a3526'
MOSS, MOSS_SH, MOSS_HI = '#6a8a4a', '#4a6a34', '#8aaa5a'
YEW, YEW_SH, YEW_HI = '#46683e', '#30502c', '#6a8a50'
BONE, BONE_SH, BONE_LINE = '#e6dcc0', '#b8ab8a', '#3a2a1a'
SPORE = '#8a9a7a'
GLOWCAP, GLOWCAP_SH = '#a8e0a0', '#6aa870'
SCORCH, SCORCH_EDGE, CHAR = '#ff9a4a', '#c85a2a', '#241408'
STONE_G, STONE_G_SH = '#8a8a78', '#646656'


def taper_path(pts, w0, w1):
    """A tapered stroke through pts as a closed shape (w0 wide at the start, w1
    at the end): roots, branches, dangling tips."""
    n = len(pts)
    left, right = [], []
    for i, (x, y) in enumerate(pts):
        a = pts[max(0, i - 1)]
        b = pts[min(n - 1, i + 1)]
        dx, dy = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dy) or 1.0
        nx, ny = -dy / L, dx / L
        w = (w0 + (w1 - w0) * i / max(1, n - 1)) / 2.0
        left.append((x + nx * w, y + ny * w))
        right.append((x - nx * w, y - ny * w))
    ring = left + right[::-1]
    d = 'M%.1f %.1f' % ring[0]
    for i in range(1, len(ring)):
        x0, y0 = ring[i - 1]
        x1, y1 = ring[i]
        d += ' Q%.1f %.1f %.1f %.1f' % (x0, y0, (x0 + x1) / 2, (y0 + y1) / 2) if i % 2 else ' L%.1f %.1f' % (x1, y1)
    return d + ' Z'


def wiggle(rng, x0, y0, x1, y1, n=6, amp=8.0):
    """Points from (x0, y0) to (x1, y1) with a gentle sideways wander."""
    pts = []
    for i in range(n + 1):
        t = i / float(n)
        x = x0 + (x1 - x0) * t
        y = y0 + (y1 - y0) * t
        if 0 < i < n:
            x += rng.u(-amp, amp)
            y += rng.u(-amp * 0.4, amp * 0.4)
        pts.append((x, y))
    return pts


def skull_fruit(x, y, r, leaf=False, tilt=0.0, bone=BONE, sh=BONE_SH, ln=BONE_LINE):
    """A chibi skull the size of an apple, hanging by a stalk from its crown:
    round, cheerful, two big sockets and a tiny smile (cute, never gory)."""
    t = 'rotate(%.1f %.1f %.1f)' % (tilt, x, y)
    face = ('<ellipse cx="%.1f" cy="%.1f" rx="%.2f" ry="%.2f" fill="%s"/>' % (x - r * 0.36, y + r * 0.02, r * 0.26, r * 0.3, ln)
            + '<ellipse cx="%.1f" cy="%.1f" rx="%.2f" ry="%.2f" fill="%s"/>' % (x + r * 0.36, y + r * 0.02, r * 0.26, r * 0.3, ln)
            + dot(x - r * 0.42, y - r * 0.08, r * 0.08, '#ffffff', 0.8) + dot(x + r * 0.3, y - r * 0.08, r * 0.08, '#ffffff', 0.8)
            + '<path d="M%.1f %.1f Q%.1f %.1f %.1f %.1f" fill="none" stroke="%s" stroke-width="%.2f" stroke-linecap="round"/>' % (
                x - r * 0.3, y + r * 0.5, x, y + r * 0.72, x + r * 0.3, y + r * 0.5, ln, max(0.6, r * 0.12)))
    head = ('M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f '
            'C%.1f %.1f %.1f %.1f %.1f %.1f Z') % (
        x, y - r, x + r * 0.62, y - r, x + r, y - r * 0.5, x + r, y + r * 0.08, x + r, y + r * 0.6, x + r * 0.5, y + r * 0.86,
        x, y + r * 0.86, x - r * 0.5, y + r * 0.86, x - r, y + r * 0.6, x - r, y + r * 0.08, x - r, y - r * 0.5, x - r * 0.62, y - r, x, y - r)
    over = face + spec(x - r * 0.45, y - r * 0.55, r * 0.22, r * 0.12, rot=-35, op=0.8)
    if leaf:
        over += '<path d="M%.1f %.1f q%.1f %.1f %.1f %.1f q%.1f %.1f %.1f %.1f Z" fill="%s" stroke="%s" stroke-width="%.2f"/>' % (
            x + r * 0.1, y - r * 0.9, r * 0.5, -r * 0.6, r * 1.1, -r * 0.3, -r * 0.4, r * 0.5, -r * 1.1, r * 0.3, MOSS, ln, max(0.5, r * 0.08))
    return Part('fill', pth(head).replace(' {a}', ' transform="%s" {a}' % t), fill=bone, shade=sh, off=(-r * 0.2, -r * 0.2),
                line=ln, over=gx(over, t))


def headstone(x, base, w, h, tilt=0.0, col=STONE_G, sh=STONE_G_SH, moss=True, cross=False):
    """A rounded headstone standing on (x, base), tipped tilt degrees."""
    t = 'rotate(%.1f %.1f %.1f)' % (tilt, x, base)
    d = round_arch_d(x - w / 2, x + w / 2, base - h, base)
    over = ''
    if moss:
        over += '<path d="M%.1f %.1f Q%.1f %.1f %.1f %.1f L%.1f %.1f Z" fill="%s" opacity="0.85"/>' % (
            x - w / 2, base - h * 0.2, x, base - h * 0.34, x + w / 2, base - h * 0.14, x + w / 2, base, MOSS)
    if cross:
        over += line('M%.1f %.1f L%.1f %.1f M%.1f %.1f L%.1f %.1f' % (x, base - h * 0.78, x, base - h * 0.36, x - w * 0.16, base - h * 0.62,
                                                                    x + w * 0.16, base - h * 0.62), sh, max(1.0, w * 0.06))
    else:
        over += line('M%.1f %.1f L%.1f %.1f M%.1f %.1f L%.1f %.1f' % (x - w * 0.22, base - h * 0.62, x + w * 0.22, base - h * 0.62,
                                                                    x - w * 0.16, base - h * 0.5, x + w * 0.16, base - h * 0.5), sh, max(0.8, w * 0.04))
    return Part('fill', pth(d).replace(' {a}', ' transform="%s" {a}' % t), fill=col, shade=sh, off=(-w * 0.12, -2),
                over=gx(over, t))


def glowcap(x, base, k=1.0, lean=0.0):
    """A glowcap mushroom: a pale stalk and a round glowing green cap."""
    t = 'rotate(%.1f %.1f %.1f)' % (lean, x, base)
    stalk = Part('fill', pth('M%.1f %.1f Q%.1f %.1f %.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f Z' % (
        x - 2.2 * k, base, x - 3 * k, base - 7 * k, x - 1.6 * k, base - 12 * k, x + 1.6 * k, base - 12 * k, x + 3 * k, base - 7 * k,
        x + 2.2 * k, base)).replace(' {a}', ' transform="%s" {a}' % t), fill='#e8f0d8', shade='#b8c8a8', off=(-0.8 * k, 0))
    cap = Part('fill', pth('M%.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f Z' % (
        x - 8 * k, base - 11 * k, x, base - 24 * k, x + 8 * k, base - 11 * k, x, base - 8 * k, x - 8 * k, base - 11 * k))
        .replace(' {a}', ' transform="%s" {a}' % t), fill=GLOWCAP, shade=GLOWCAP_SH, off=(-2 * k, -1 * k),
        over=gx(dot(x - 3 * k, base - 16 * k, 1.3 * k, '#f0fff0', 0.9) + dot(x + 2.6 * k, base - 14 * k, 1.0 * k, '#f0fff0', 0.8), t))
    return [stalk, cap]


def spore_cloud(ctx, x, y, r, op=0.4):
    """A soft hanging cloud of spores: lumpy translucent blobs and motes."""
    s = ''
    for dx, dy, k in ((-0.45, 0.1, 0.62), (0.4, 0.14, 0.58), (0.0, -0.18, 0.7), (-0.1, 0.28, 0.5), (0.25, -0.3, 0.42)):
        s += '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s" opacity="%.2f"/>' % (x + dx * r, y + dy * r, r * k, r * k * 0.78, SPORE, op * 0.7)
    s += radial(ctx, x, y, r * 1.2, '#b8c8a0', op * 0.6)
    for i in range(7):
        a = i * 0.9
        s += dot(x + math.cos(a) * r * 0.8, y + math.sin(a) * r * 0.55, max(0.8, r * 0.035), '#e8f0c8', 0.7)
    return s


def seam_d(pts):
    d = 'M%.1f %.1f' % pts[0]
    for i in range(1, len(pts)):
        x0, y0 = pts[i - 1]
        x1, y1 = pts[i]
        d += ' Q%.1f %.1f %.1f %.1f' % (x0 + (x1 - x0) * 0.5 + (y1 - y0) * 0.18, y0 + (y1 - y0) * 0.5 - (x1 - x0) * 0.1, x1, y1)
    return d


def scorch_char(pts, w=6.0):
    """The charred rim the dragged flame burnt along pts (a shaded layer)."""
    return line(seam_d(pts), CHAR, w * 2.6, op=0.9)


def scorch_glow(pts, w=6.0):
    """The seam's glow: an orange band and a hot core (a lit layer, so it
    burns in the dark)."""
    d = seam_d(pts)
    return (line(d, SCORCH_EDGE, w * 1.5, op=0.85) + line(d, SCORCH, w * 0.8) + line(d, '#ffe2b0', w * 0.3, op=0.9))


def scorch_seam(pts, w=6.0):
    return scorch_char(pts, w) + scorch_glow(pts, w)


def yew(ctx, rng, x, base, k=1.0, fruit=6, lean=0.0, dark=None, w=MID_W, scorch=None):
    """An ossuary yew: a short thick knuckled trunk of bone-pale bark, roots
    gripping the ground, a dark drooping canopy hung with skull fruit."""
    parts = []
    tw = 36 * k
    top = base - 150 * k
    fdk = (lambda c: fade(c, dark, 0.25)) if dark else (lambda c: c)
    # roots gripping the ground
    for dx, L in ((-1, 1.0), (1, 0.9), (-0.4, 0.6), (0.5, 0.7)):
        rp = [(x + dx * tw * 0.3, base - 14 * k), (x + dx * tw * 0.9, base - 4 * k), (x + dx * tw * (1.2 + L * 0.6), base + 2 * k)]
        parts.append(P(taper_path(rp, 12 * k, 3 * k), fdk(BARK), fdk(BARK_SH), off=(-2, -2)))
    trunk = ('M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f L%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f '
             'C%.1f %.1f %.1f %.1f %.1f %.1f Z') % (
        x - tw * 0.62, base, x - tw * 0.4, base - 50 * k, x - tw * 0.62 + lean * 0.5, top + 60 * k, x - tw * 0.5 + lean, top + 20 * k,
        x - tw * 0.3 + lean, top, x + tw * 0.3 + lean, top, x + tw * 0.5 + lean, top + 20 * k,
        x + tw * 0.5 + lean, top + 20 * k, x + tw * 0.62 + lean * 0.5, top + 60 * k, x + tw * 0.4, base - 50 * k, x + tw * 0.62, base,
        x + tw * 0.2, base + 4 * k, x - tw * 0.2, base + 4 * k, x - tw * 0.62, base)
    knots = ''
    for i in range(3):
        kx = x + rng.u(-0.3, 0.3) * tw + lean * (1 - i * 0.3)
        ky = base - (30 + i * 36) * k
        knots += '<ellipse cx="%.1f" cy="%.1f" rx="%.1f" ry="%.1f" fill="%s"/>' % (kx, ky, 6 * k, 4.4 * k, fdk(BARK_SH))
        knots += line('M%.1f %.1f q%.1f %.1f %.1f %.1f' % (kx - 5 * k, ky - 1 * k, 5 * k, -4 * k, 10 * k, 0), fdk(BARK_LINE), 1.1 * k, op=0.6)
    knots += line('M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f' % (x - tw * 0.2, base - 6 * k, x - tw * 0.1, base - 60 * k, x - tw * 0.3 + lean, top + 60 * k,
                                                               x - tw * 0.2 + lean, top + 18 * k), fdk(BARK_HI), 2.2 * k, op=0.8)
    if scorch:
        knots += scorch_char(scorch, 3.4 * k)
    parts.append(P(trunk, fdk(BARK), fdk(BARK_SH), off=(-tw * 0.3, -2), over=knots))
    # the canopy: a heavy dark mass with drooping fronds
    cx, cy = x + lean, top - 10 * k
    blobs = [(-60, 10, 52, 38), (60, 14, 50, 36), (0, -22, 62, 44), (-30, -8, 46, 36), (32, -6, 46, 36), (-86, 34, 30, 22), (88, 36, 30, 22)]
    for (bx, by, rx, ry) in blobs:
        parts.append(E(cx + bx * k, cy + by * k, rx * k, ry * k, fdk(YEW), fdk(YEW_SH), off=(-6 * k, -4 * k)))
    # drooping fronds under the canopy's rim
    fr = ''
    for i in range(11):
        t = (i - 5) / 5.0
        fx = cx + t * 96 * k
        fy = cy + (30 - abs(t) * 6) * k
        L = rng.u(24, 44) * k
        fr += '<path d="%s" fill="%s"/>' % (taper_path([(fx, fy - 6 * k), (fx + t * 6 * k, fy + L * 0.5), (fx + t * 10 * k, fy + L)], 12 * k, 2 * k), fdk(YEW_SH))
    hl = ''.join(line('M%.1f %.1f q%.1f %.1f %.1f %.1f' % (cx + bx * k - rx * k * 0.5, cy + by * k - ry * k * 0.4, rx * k * 0.4, -ry * k * 0.4,
                                                        rx * k * 0.8, -ry * k * 0.2), fdk(YEW_HI), 2.2 * k, op=0.7)
                 for (bx, by, rx, ry) in blobs[:5])
    s_can = draw(ctx, parts, BARK_LINE, w) + fr + hl
    # skull fruit on short stalks, some with a sprig
    fp = []
    stalks = ''
    for i in range(fruit):
        t = (i + 0.5) / fruit
        fx = cx + (t - 0.5) * 170 * k + rng.u(-6, 6) * k
        fy = cy + (22 + 30 * math.sin(t * math.pi) * 0.4) * k + rng.u(0, 20) * k
        r = rng.u(8, 11) * k
        stalks += line('M%.1f %.1f L%.1f %.1f' % (fx, fy - 18 * k, fx, fy - r), fdk(BARK_LINE), 1.4 * k)
        fp.append(skull_fruit(fx, fy, r, leaf=(i % 3 == 1), tilt=rng.u(-14, 14), bone=fdk(BONE), sh=fdk(BONE_SH)))
    return s_can + stalks + draw(ctx, fp, BONE_LINE, w)


def hanging_roots(ctx, rng, x0, x1, top, bottom, col, sh, n=30, w0=18, braid=True, dark=None):
    """A curtain of roots hanging from the cavern roof: thick braided strands
    tapering to dangling tips at uneven lengths."""
    s = ''
    for i in range(n):
        x = x0 + (x1 - x0) * (i + rng.u(0, 0.8)) / n
        L = rng.u(0.35, 1.0) * (bottom - top)
        pts = wiggle(rng, x, top - 10, x + rng.u(-24, 24), top + L, n=5, amp=10)
        c = mix(col, sh, rng.u(0, 0.6))
        wv = w0 * rng.u(0.5, 1.2)
        s += '<path d="%s" fill="%s"/>' % (taper_path(pts, wv, 1.6), fade(c, dark, 0.2) if dark else c)
        if braid and wv > 12:
            for j in range(1, 5):
                px, py = pts[j]
                s += line('M%.1f %.1f q%.1f %.1f %.1f %.1f' % (px - wv * 0.3, py - 6, wv * 0.3, 5, wv * 0.6, 2), sh, 1.2, op=0.7)
    return s


# ================================================================ orchard_vista (world_3)

def orchard_vista():
    """The Bone Orchard from its upper edge: a cavern ceiling of hanging roots
    with the warm crack the flame was dragged through (top left); the scorch
    running from it across the roots and the ossuary yews to a dark hole at
    the bottom right; a root-wrapped stone lip where Waxby and Waxley stand."""
    p = Panel('orchard_vista', 1400, 460, [0.26, 0.30, 0.24], 'spores')
    FLOOR = 318
    rng = Rand(3301)
    for i, (x, y, r, d) in enumerate(((190, 52, 70, 0.35), (380, 120, 80, 0.35), (590, 190, 90, 0.7), (800, 250, 80, 0.7),
                                      (1000, 310, 70, 0.7), (1180, 372, 90, 0.7))):
        p.light('scorch%d' % (i + 1), x, y, r, 0.5, 'glow', depth=d, color='ff9a4a')
    for i, (x, y, d) in enumerate(((180, 305, 1.0), (706, 350, 0.7), (926, 390, 0.7), (1276, 380, 0.7))):
        p.light('glowcap%d' % (i + 1), x, y, 70, 0.45, 'glow', depth=d, color='a8e0a0')
    p.light('lantern', 330, 250, 150, 0.9, 'flame', h=12)
    p.anchor('edge', 250, FLOOR, h=120)
    p.anchor('waxley', 450, FLOOR, flip=True)
    p.anchor('cone', 555, FLOOR, h=260)
    dk = p.dark
    # ---------------------------------------------------------------- roof (0.35): the cavern, far trees, the crack
    ctx = Ctx('ovr')
    s = '<rect x="0" y="0" width="1400" height="460" fill="%s"/>' % vgrad(ctx, [(0, '#1a2016'), (0.55, '#2e3a2a'), (1, '#46563e')])
    # the far orchard: rows of yew silhouettes in the mist
    for row, (y, k, col) in enumerate(((300, 0.5, '#3a4a34'), (340, 0.62, '#34442e'))):
        x = -40 + row * 60
        while x < 1440:
            kk = k * rng.u(0.8, 1.1)
            s += '<path d="%s" fill="%s"/>' % (ell_d(x, y - 50 * kk, 70 * kk, 40 * kk), col)
            s += fillp(rect_d(x - 7 * kk, y - 30 * kk, x + 7 * kk, y + 40), col)
            x += rng.u(110, 170)
    s += fillp('M0 360 Q300 340 700 352 Q1100 336 1400 350 L1400 460 L0 460 Z', '#3e4e38')
    s += '<rect x="0" y="330" width="1400" height="130" fill="%s"/>' % vgrad(ctx, [(0, '#8a9a7a', 0), (1, '#8a9a7a', 0.35)])
    # the root ceiling
    s += fillp('M0 0 L1400 0 L1400 70 Q1200 96 1000 64 Q800 100 600 70 Q400 96 200 60 Q100 80 0 66 Z', '#1e2418')
    s += hanging_roots(ctx, rng, -20, 1420, 40, 250, '#5a4a36', '#3a3024', n=46, w0=22, dark=dk)
    # the warm crack at the top left: the Undercandle's floor, where the flame went through
    crack = 'M110 0 L270 0 L252 22 L262 40 L226 58 L214 84 L188 62 L160 72 L150 44 L124 36 Z'
    roof_seam = [(196, 70), (250, 96), (320, 118), (400, 134), (470, 160)]
    s += '<path d="%s" fill="none" stroke="%s" stroke-width="9" stroke-linejoin="round"/>' % (crack, CHAR)
    s += scorch_char(roof_seam, 5.0)
    p.layer('roof', 0.35, s, ctx=ctx)
    # the crack and the seam across the roots, burning (lit)
    ctx = Ctx('ovg')
    s = radial(ctx, 190, 30, 150, '#ff9a4a', 0.45)
    s += fillp(crack, '#ffb870') + fillp('M140 0 L240 0 L226 18 L232 32 L206 46 L196 62 L184 48 L164 54 L160 34 L146 26 Z', '#ffe2b0')
    s += '<path d="%s" fill="none" stroke="%s" stroke-width="3" stroke-linejoin="round"/>' % (crack, SCORCH_EDGE)
    s += scorch_glow(roof_seam, 5.0)
    p.layer('roof_glow', 0.35, s, lit=True, ctx=ctx, rect=(20, 0, 500, 190))
    # ---------------------------------------------------------------- trees (0.7): the ossuary yews
    ctx = Ctx('ovt')
    s = ''
    # the orchard floor: a slope of moss and bone-meal soil down to the right
    ground = 'M420 300 Q600 330 800 352 Q1000 372 1200 384 Q1320 390 1420 386 L1420 470 L420 470 Z'
    s += fillp(ground, '#4a5a38')
    s += fillp('M420 312 Q600 342 800 364 Q1000 384 1200 396 Q1320 402 1420 398 L1420 470 L420 470 Z', '#3e4c30')
    # the dark hole the scorch runs into, at the bottom right
    s += '<path d="%s" fill="%s"/>' % (ell_d(1188, 392, 70, 22), CHAR)
    s += '<path d="%s" fill="#070504"/>' % ell_d(1188, 394, 58, 16)
    # headstones knotted in the roots
    stones = []
    for (x, base, w, h, tilt, cr) in ((640, 336, 30, 40, -8, False), (760, 350, 26, 34, 6, True), (1060, 384, 34, 44, -4, False),
                                      (1300, 392, 28, 36, 10, True), (890, 366, 22, 28, -12, False)):
        stones.append(headstone(x, base, w, h, tilt, col=fade(STONE_G, dk, 0.15), sh=fade(STONE_G_SH, dk, 0.15)))
    s += draw(ctx, stones, BARK_LINE, MID_W)
    # the scorch across the ground to the hole (its glow is the seam layer)
    tree_seam = [(470, 180), (560, 200), (640, 232), (740, 262), (860, 290), (980, 318), (1090, 350), (1160, 384)]
    trunk_seam = [(800 - 30, 360 - 150 * 1.12), (800 - 10, 360 - 90 * 1.12), (800 + 12, 360 - 40 * 1.12), (800 + 30, 360)]
    s += scorch_char(tree_seam, 4.0)
    # the yews, far to near
    for (x, base, k, fruit, lean) in ((1350, 392, 0.8, 5, 6), (560, 330, 0.9, 6, -4), (1110, 386, 1.05, 7, 8), (800, 360, 1.12, 7, -6),
                                      (960, 374, 0.82, 5, 4)):
        sc = None
        if abs(x - 800) < 5:
            sc = [(x - 30, base - 150 * k), (x - 10, base - 90 * k), (x + 12, base - 40 * k), (x + 30, base)]
        s += yew(ctx, rng, x, base, k, fruit, lean, dark=dk, scorch=sc)
    # spore clouds hanging between the trees
    for (x, y, r) in ((680, 220, 40), (900, 250, 34), (1240, 260, 44), (1020, 180, 30)):
        s += spore_cloud(ctx, x, y, r)
    # glowcaps among the roots
    caps = []
    for (x, base, k) in ((700, 360, 1.2), (712, 362, 0.8), (920, 400, 1.1), (932, 402, 0.7), (1270, 330 + 60, 1.2), (1284, 392, 0.8)):
        caps += glowcap(x, base, k, lean=(x % 7) - 3)
    s += draw(ctx, caps, BARK_LINE, MID_W)
    p.layer('trees', 0.7, s, ctx=ctx)
    ctx = Ctx('ovs')
    s = scorch_glow(tree_seam, 4.0) + scorch_glow(trunk_seam, 3.4 * 1.12)
    s += '<path d="%s" fill="none" stroke="%s" stroke-width="2.4" opacity="0.8"/>' % (ell_d(1188, 392, 64, 19), SCORCH)
    p.layer('seam', 0.7, s, lit=True, ctx=ctx, rect=(440, 150, 820, 270))
    # ---------------------------------------------------------------- ledge (1.0): the root-wrapped lip
    ctx = Ctx('ovl')
    s = ''
    lip = ('M-20 %d L560 %d Q600 %d 616 %d Q630 %d 622 %d Q640 %d 628 %d L600 470 L-20 470 Z' % (
        FLOOR, FLOOR - 2, FLOOR - 4, FLOOR + 6, FLOOR + 20, FLOOR + 40, FLOOR + 70, FLOOR + 100))
    rock = [P(lip, '#7a7464', '#56504a', off=(-10, -4),
              over=line('M-20 %d L560 %d Q600 %d 616 %d' % (FLOOR + 3, FLOOR + 1, FLOOR, FLOOR + 8), '#a8a290', 3, op=0.9)
              + ''.join(line('M%.1f %.1f l%.1f %.1f' % (x, FLOOR + 30 + (x * 7) % 40, 18, 6), '#56504a', 2, op=0.8)
                        for x in range(20, 600, 70)))]
    # moss along the lip, roots wrapping over it
    moss = 'M-20 %d Q80 %d 160 %d Q260 %d 360 %d Q460 %d 560 %d L560 %d Q460 %d 360 %d Q260 %d 160 %d Q80 %d -20 %d Z' % (
        FLOOR - 4, FLOOR - 8, FLOOR - 3, FLOOR - 9, FLOOR - 3, FLOOR - 8, FLOOR - 3, FLOOR + 8, FLOOR + 14, FLOOR + 6, FLOOR + 16,
        FLOOR + 7, FLOOR + 14, FLOOR + 8)
    rock.append(P(moss, MOSS, MOSS_SH, off=(-3, -3), over=line('M-20 %d Q80 %d 160 %d Q260 %d 360 %d' % (
        FLOOR - 2, FLOOR - 6, FLOOR - 1, FLOOR - 7, FLOOR - 1), MOSS_HI, 2, op=0.8)))
    for (xa, xb, down, w) in ((40, 120, 90, 9), (190, 250, 120, 11), (470, 580, 110, 10), (548, 612, 70, 7)):
        rock.append(LIMB('M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f' % (xa, FLOOR - 3, (xa + xb) / 2.0, FLOOR - 6, xb, FLOOR + down * 0.3,
                                                                      xb + 6, FLOOR + down), ROOT, w,
                         over=line('M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f' % (xa + 2, FLOOR - 5, (xa + xb) / 2.0, FLOOR - 8,
                                                                                xb - 2, FLOOR + down * 0.3, xb + 3, FLOOR + down * 0.7),
                                   '#8a6a4a', 1.6, op=0.8)))
    s += draw(ctx, rock, BARK_LINE, FRONT_W)
    # the tipped headstone at the back of the lip, and glowcaps by the edge
    props = [headstone(96, FLOOR + 2, 44, 58, -14, cross=True)]
    props += glowcap(180, FLOOR + 2, 1.5, -6) + glowcap(194, FLOOR + 4, 1.0, 8) + glowcap(168, FLOOR + 3, 0.8, -12)
    # the crooked lantern post the lantern hangs from
    post = [LIMB('M300 %d C296 %d 306 %d 300 %d C296 %d 306 %d 318 %d' % (FLOOR + 2, FLOOR - 30, FLOOR - 50, FLOOR - 70, FLOOR - 82, FLOOR - 92, FLOOR - 96),
                 WOOD, 6.4, over=line('M298 %d l3 -3' % (FLOOR - 40), WOOD_SH, 1.2)),
            LIMB('M318 %d Q330 %d 332 %d' % (FLOOR - 96, FLOOR - 98, FLOOR - 90), WOOD, 3.6)]
    props += post
    s += draw(ctx, props, BARK_LINE, FRONT_W)
    # the lantern: a little iron cage with a candle (the light's flame base at (330, 250))
    lx, ly = 332, FLOOR - 90
    lant = [LIMB('M%.1f %.1f L%.1f %.1f' % (lx, ly, lx, ly + 6), IRON, 1.6),
            P('M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (lx - 11, ly + 14, lx + 11, ly + 14, lx + 6, ly + 6, lx - 6, ly + 6), IRON, IRON_SH, off=(-1, -1))]
    glass = ctx.radgrad([(0, '#fff6d0'), (0.6, '#ffd878'), (1, '#e8a040')], cx=0.5, cy=0.7, r=0.6)
    lant.append(Part('fill', pth(rect_d(lx - 9, ly + 14, lx + 9, ly + 36)), fill=glass, no_shade=True,
                     over=line('M%.1f %.1f L%.1f %.1f M%.1f %.1f L%.1f %.1f' % (lx - 9, ly + 14, lx - 9, ly + 36, lx + 9, ly + 14, lx + 9, ly + 36), IRON, 2.2)))
    lant.append(P('M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (lx - 12, ly + 36, lx + 12, ly + 36, lx + 9, ly + 41, lx - 9, ly + 41), IRON, IRON_SH, off=(-1, -1)))
    s += draw(ctx, lant, INK, FRONT_W)
    p.lights['lantern']['p'] = [lx, ly + 34]
    p.layer('ledge', 1.0, s, ctx=ctx, rect=(0, 150, 720, 310))
    return p


# ================================================================ heartwood (boss_3)

CAGES = [(100, 205), (200, 120), (320, 190), (800, 115), (880, 225), (950, 130)]


def root_cage(ctx, x, y, k=1.0, col=ROOT, sh=ROOT_SH, hang=None):
    """A knot of roots woven round a small kept light at (x, y): the strand it
    hangs from, four bowed ribs, a knot on top and a dangling tip."""
    parts = []
    top = hang if hang is not None else y - 90 * k
    parts.append(LIMB('M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f' % (x + 8 * k, top, x - 10 * k, (top + y) / 2, x + 6 * k, y - 34 * k,
                                                                   x, y - 24 * k), col, 5 * k))
    for dx in (-1.0, -0.4, 0.4, 1.0):
        parts.append(LIMB('M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f' % (x, y - 24 * k, x + dx * 26 * k, y - 18 * k, x + dx * 24 * k,
                                                                       y + 16 * k, x, y + 24 * k), col, 3.6 * k))
    parts.append(E(x, y - 24 * k, 7 * k, 5 * k, col, sh, off=(-1.5 * k, -1.5 * k)))
    parts.append(LIMB('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (x, y + 24 * k, x + 5 * k, y + 34 * k, x - 2 * k, y + 44 * k), col, 3 * k))
    inner = radial(ctx, x, y, 22 * k, '#cfe4ff', 0.55)
    return inner + draw(ctx, parts, BARK_LINE, MID_W)


def skull_cobbles(rng, x0, y0, x1, y1, r, col, sh, ln):
    """A wall of small skulls set in the roots like cobbles (flat, far)."""
    s = ''
    y = y0
    row = 0
    while y < y1:
        x = x0 + (r if row % 2 else 0)
        while x < x1:
            rr = r * rng.u(0.8, 1.05)
            s += '<path d="%s" fill="%s"/>' % (ell_d(x, y, rr, rr * 0.9), mix(col, sh, rng.u(0, 0.5)))
            s += dot(x - rr * 0.36, y + rr * 0.05, rr * 0.24, ln) + dot(x + rr * 0.36, y + rr * 0.05, rr * 0.24, ln)
            x += r * 2.3
        y += r * 2.0
        row += 1
    return s


def heartwood():
    """Mother Gravebough's hall: a vault ribbed with living roots, walls of
    little skulls set like cobbles, the Heartwood's trunk rising out of frame
    behind her, six root-cages hanging with the kept lights (cold; warm once
    she lets go), and Mother Yarrow's grave: a low mound, a trowel, yarrow."""
    p = Panel('heartwood', 1000, 600, [0.22, 0.28, 0.22], 'spores')
    FLOOR = 415
    rng = Rand(3402)
    for i, (x, y) in enumerate(CAGES):
        p.light('cage%d' % (i + 1), x, y, 70, 0.8, 'cold', h=12, depth=0.8, color='a8d0ff')
    for i, (x, y) in enumerate(CAGES):
        p.light('kept%d' % (i + 1), x, y, 90, 0.9, 'flame', h=14, depth=0.8, off=True)
    p.light('trowel', 425, 400, 70, 0.35, 'glow', depth=1.0, color='ffe8b0')
    p.light('moss1', 655, 395, 110, 0.4, 'glow', depth=1.0, color='a8e0a0')
    p.light('moss2', 540, 150, 120, 0.4, 'glow', depth=0.8, color='a8e0a0')
    p.anchor('boss', 620, FLOOR, flip=True)
    p.anchor('spirit', 430, FLOOR - 10, h=110, flip=True)
    p.anchor('actor', 240, FLOOR, h=120)
    dk = p.dark
    # ---------------------------------------------------------------- chamber (0.4)
    ctx = Ctx('hwc')
    s = '<rect x="0" y="0" width="1000" height="600" fill="%s"/>' % vgrad(ctx, [(0, '#141a12'), (0.6, '#26301e'), (1, '#34402a')])
    s += skull_cobbles(rng, -10, 60, 1010, 520, 10, fade('#5e5c48', dk, 0.5), fade('#4a4a3a', dk, 0.5), '#222418')
    # the root ribs of the vault, arching overhead
    for (xa, xb, top, w) in ((-60, 380, 20, 30), (120, 560, -10, 36), (440, 900, -20, 36), (640, 1080, 20, 30),
                             (-120, 240, 140, 22), (780, 1120, 150, 22)):
        cx = (xa + xb) / 2.0
        d = 'M%.1f 600 C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f 600' % (
            xa, xa, top + 120, cx - (xb - xa) * 0.3, top, cx, top, cx + (xb - xa) * 0.3, top, xb, top + 120, xb)
        s += line(d, fade('#3a2a1c', dk, 0.2), w + 8) + line(d, fade(ROOT_SH, dk, 0.25), w)
        s += line(d, fade(ROOT, dk, 0.3), w * 0.3, op=0.8)
    s += '<rect x="0" y="380" width="1000" height="220" fill="%s"/>' % vgrad(ctx, [(0, '#1a2014', 0), (1, '#1a2014', 0.7)])
    p.layer('chamber', 0.4, s, ctx=ctx)
    # ---------------------------------------------------------------- tree (0.8): the Heartwood and the cages
    ctx = Ctx('hwt')
    s = ''
    tx = 620
    trunk = ('M%d 440 C%d 360 %d 240 %d 140 C%d 80 %d 30 %d -20 L%d -20 C%d 30 %d 80 %d 140 C%d 240 %d 360 %d 440 Z' % (
        tx - 150, tx - 110, tx - 96, tx - 100, tx - 110, tx - 90, tx - 96, tx + 96, tx + 90, tx + 110, tx + 100, tx + 96, tx + 110, tx + 150))
    grain = ''
    for i in range(7):
        gx0 = tx - 80 + i * 26
        grain += line('M%.1f 430 C%.1f 320 %.1f 200 %.1f -10' % (gx0 - 10, gx0 + 8, gx0 - 6, gx0 + 4), '#3a2818', 2.6, op=0.8)
        grain += line('M%.1f 430 C%.1f 320 %.1f 200 %.1f -10' % (gx0 - 6, gx0 + 12, gx0 - 2, gx0 + 8), '#8a6a4a', 1.2, op=0.6)
    for (kx, ky) in ((tx - 50, 300), (tx + 40, 200), (tx - 30, 120), (tx + 60, 340)):
        grain += '<path d="%s" fill="%s"/>' % (ell_d(kx, ky, 16, 11), '#3a2818')
        grain += line('M%.1f %.1f q12 -8 24 0' % (kx - 12, ky - 2), '#8a6a4a', 1.6, op=0.6)
    # glowing fungus on the trunk behind her crown
    fungus = ''
    for (fx, fy, k) in ((540, 150, 1.0), (552, 132, 0.7), (528, 170, 0.6), (700, 100, 0.8)):
        fungus += '<path d="%s" fill="%s" stroke="%s" stroke-width="1.4"/>' % (ell_d(fx, fy, 16 * k, 6 * k), GLOWCAP, GLOWCAP_SH)
    parts = [P(trunk, '#5e4430', '#46321f', off=(-40, 0), over=grain + fungus)]
    # roots radiating across the floor from its foot
    for (ex, ey, w) in ((260, 440, 20), (380, 452, 24), (860, 452, 24), (990, 440, 20), (140, 430, 14), (1040, 430, 14)):
        parts.append(LIMB('M%d %d C%.1f %.1f %.1f %.1f %d %d' % (tx + (ex - tx) * 0.12, 400, tx + (ex - tx) * 0.4, 410, tx + (ex - tx) * 0.7,
                                                                 ey - 20, ex, ey), '#5e4430', w,
                          over=line('M%d %d C%.1f %.1f %.1f %.1f %d %d' % (tx + (ex - tx) * 0.12, 396, tx + (ex - tx) * 0.4, 404,
                                                                           tx + (ex - tx) * 0.7, ey - 26, ex, ey - 6), '#8a6a4a', 2, op=0.7)))
    s += draw(ctx, parts, BARK_LINE, MID_W)
    # the roots the cages hang from, down from the vault
    for (x, y) in CAGES:
        s += root_cage(ctx, x, y, 1.1, fade(ROOT, dk, 0.1), fade(ROOT_SH, dk, 0.1), hang=-10)
    p.layer('tree', 0.8, s, ctx=ctx)
    # ---------------------------------------------------------------- floor (1.0): moss, fallen fruit, Yarrow's grave
    ctx = Ctx('hwf')
    s = ''
    s += fillp('M-20 %d Q250 %d 500 %d Q750 %d 1020 %d L1020 620 L-20 620 Z' % (FLOOR - 8, FLOOR - 16, FLOOR - 6, FLOOR - 14, FLOOR - 6), '#4a5a34')
    s += fillp('M-20 %d Q250 %d 500 %d Q750 %d 1020 %d L1020 620 L-20 620 Z' % (FLOOR + 6, FLOOR + 2, FLOOR + 10, FLOOR + 4, FLOOR + 12), '#3e4c2c')
    for i in range(60):
        x = rng.u(-10, 1010)
        y = rng.u(FLOOR + 8, 600)
        s += '<path d="%s" fill="%s" opacity="0.7"/>' % (ell_d(x, y, rng.u(8, 22), rng.u(2, 5)), MOSS_SH if i % 2 else MOSS)
    parts = []
    # Yarrow's grave: a low mound with the trowel stuck in it
    gx0, gy = 430, FLOOR + 2
    parts.append(P('M%d %d C%d %d %d %d %d %d C%d %d %d %d %d %d Z' % (gx0 - 64, gy, gx0 - 50, gy - 26, gx0 - 20, gy - 32, gx0 + 6, gy - 32,
                                                                     gx0 + 34, gy - 32, gx0 + 56, gy - 24, gx0 + 70, gy),
                   '#5a6a3e', '#44522e', off=(-8, -2),
                   over=line('M%d %d C%d %d %d %d %d %d' % (gx0 - 50, gy - 12, gx0 - 30, gy - 26, gx0, gy - 28, gx0 + 30, gy - 24), MOSS_HI, 2, op=0.8)))
    parts.append(P('M%d %d L%d %d L%d %d L%d %d Z' % (gx0 + 16, gy - 30, gx0 + 30, gy - 30, gx0 + 34, gy - 58, gx0 + 12, gy - 58), '#9aa0b0', '#6a7080',
                   off=(-2, -2), over=line('M%d %d L%d %d' % (gx0 + 18, gy - 54, gx0 + 20, gy - 34), '#e0e4f0', 1.6)))
    parts.append(LIMB('M%d %d L%d %d' % (gx0 + 23, gy - 58, gx0 + 25, gy - 82), WOOD, 5.4))
    # tiny white yarrow umbels round it
    for (fx, fy) in ((gx0 - 44, gy - 14), (gx0 - 22, gy - 24), (gx0 + 44, gy - 16), (gx0 + 58, gy - 6), (gx0 - 58, gy - 4)):
        parts.append(LIMB('M%d %d L%d %d' % (fx, fy + 12, fx, fy), MOSS, 1.6))
        parts.append(E(fx, fy, 7, 4, '#f4f0e0', '#c8c0a8', off=(-1, -1),
                       over=''.join(dot(fx + dx, fy - 1, 1.2, '#fffaf0') for dx in (-4, -1.5, 1.5, 4))))
    # fallen bone fruit and glowcaps at the Heartwood's foot
    for (fx, fy, r, t) in ((170, FLOOR + 22, 9, -30), (560, FLOOR + 14, 8, 20), (820, FLOOR + 30, 10, -10), (900, FLOOR + 12, 7, 40)):
        parts.append(skull_fruit(fx, fy - r * 0.8, r, tilt=t))
    for (x, base, k) in ((650, FLOOR + 2, 1.5), (668, FLOOR + 4, 1.0), (636, FLOOR + 3, 0.9), (60, FLOOR + 6, 1.2), (950, FLOOR + 8, 1.2)):
        parts += glowcap(x, base, k, lean=(x % 9) - 4)
    s += draw(ctx, parts, BARK_LINE, FRONT_W)
    p.layer('floor', 1.0, s, ctx=ctx, rect=(0, 340, 1000, 260))
    return p


# ================================================================ the Frozen Carillon's kit

ICE, ICE_SH, ICE_HI = '#cfe6f0', '#8ab8d0', '#ffffff'
FSTONE, FSTONE_SH, FSTONE_HI = '#8a9ab8', '#5a6a88', '#b8c8e0'
DEEP = '#1e2a3a'
BRASS, BRASS_SH, BRASS_HI, BRASS_LINE = '#c8983a', '#8a6424', '#f0d080', '#3a2408'
FROST_LINE = '#1a2238'


def icicle(x, y, L, w, ang=90.0, col=ICE, sh=ICE_SH):
    """An icicle from (x, y), L long, w wide at its root, pointing ang degrees
    (90 = straight down; the carillon's grow sideways)."""
    a = math.radians(ang)
    dx, dy = math.cos(a), math.sin(a)
    nx, ny = -dy, dx
    tip = (x + dx * L, y + dy * L)
    d = 'M%.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f Z' % (
        x + nx * w / 2, y + ny * w / 2, x + dx * L * 0.5 + nx * w * 0.3, y + dy * L * 0.5 + ny * w * 0.3, tip[0], tip[1],
        x + dx * L * 0.5 - nx * w * 0.3, y + dy * L * 0.5 - ny * w * 0.3, x - nx * w / 2, y - ny * w / 2)
    return Part('fill', pth(d), fill=col, shade=sh, off=(-w * 0.25, 0), over=line('M%.1f %.1f L%.1f %.1f' % (
        x + nx * w * 0.2, y + ny * w * 0.2, x + dx * L * 0.6 + nx * w * 0.08, y + dy * L * 0.6 + ny * w * 0.08), '#ffffff', max(0.8, w * 0.12), op=0.8))


def clock_face(ctx, cx, cy, r, hands=(355.0, 0.0), rim=BRASS, face='#f4f0e0', frost=True, cracked=False):
    """A clock face: a brass rim, dashes for hours (no numerals), two hands
    (degrees from twelve: minute, hour), frost across its glass."""
    s = '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s" stroke="%s" stroke-width="%.1f"/>' % (cx, cy, r, face, BRASS_LINE, r * 0.05)
    s += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="none" stroke="%s" stroke-width="%.1f"/>' % (cx, cy, r * 0.93, rim, r * 0.1)
    s += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="none" stroke="%s" stroke-width="%.1f" opacity="0.8"/>' % (cx, cy, r * 0.88, BRASS_HI, r * 0.02)
    for i in range(12):
        a = math.radians(i * 30 - 90)
        r0, r1 = r * (0.66 if i % 3 == 0 else 0.72), r * 0.8
        s += line('M%.1f %.1f L%.1f %.1f' % (cx + math.cos(a) * r0, cy + math.sin(a) * r0, cx + math.cos(a) * r1, cy + math.sin(a) * r1),
                  '#1a2440', r * (0.06 if i % 3 == 0 else 0.035))
    for deg, L, w in ((hands[0], 0.72, 0.045), (hands[1], 0.5, 0.07)):
        a = math.radians(deg - 90)
        s += line('M%.1f %.1f L%.1f %.1f' % (cx - math.cos(a) * r * 0.1, cy - math.sin(a) * r * 0.1, cx + math.cos(a) * r * L,
                                             cy + math.sin(a) * r * L), '#1a2440', r * w)
    s += dot(cx, cy, r * 0.07, BRASS)
    if frost:
        g = ctx.radgrad([(0, '#ffffff', 0.0), (0.7, '#e8f8ff', 0.25), (1, '#ffffff', 0.7)])
        s += '<circle cx="%.1f" cy="%.1f" r="%.1f" fill="%s"/>' % (cx, cy, r * 0.86, g)
        s += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (cx - r * 0.6, cy - r * 0.4, cx - r * 0.3, cy - r * 0.7, cx + r * 0.1, cy - r * 0.76),
                  '#ffffff', r * 0.05, op=0.8)
    if cracked:
        s += line('M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f' % (cx + r * 0.1, cy - r * 0.8, cx + r * 0.02, cy - r * 0.4,
                                                                cx + r * 0.24, cy - r * 0.1, cx + r * 0.1, cy + r * 0.3), '#1a2440', r * 0.03)
    return s


def inv_arch_d(x0, x1, top, bottom, point=0.62):
    """A pointed arch upside down (the carillon hangs from the roof): flat on
    top, its point at the bottom."""
    cx = (x0 + x1) / 2.0
    w = x1 - x0
    spring = bottom - w * point
    return ('M%.1f %.1f L%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f L%.1f %.1f Z' % (
        x0, top, x0, spring, x0, spring + w * 0.36, cx - w * 0.2, bottom - w * 0.1, cx, bottom,
        cx + w * 0.2, bottom - w * 0.1, x1, spring + w * 0.36, x1, spring, x1, top))


# ================================================================ carillon_vista (world_4)

def carillon_vista():
    """Evenbell's secret, from the orchard's frozen lip: a bell tower built
    upside down, its base fused into the rock roof among the orchard's roots,
    its spire pointing down into blue-black depths; four open belfries, each
    bell crusted in wax-ice with icicles growing sideways; a great clock face
    frozen at one minute to twelve. Far below, a glitter of coloured glass."""
    p = Panel('carillon_vista', 1000, 900, [0.22, 0.28, 0.40], 'rime')
    FLOOR = 285
    rng = Rand(4401)
    TX = 640
    p.light('clock', TX, 430, 120, 0.5, 'glow', depth=0.75, color='bfe8ff')
    for i, y in enumerate((175, 315, 565, 680)):
        p.light('bell%d' % (i + 1), TX, y, 60, 0.35, 'glow', depth=0.75, color='a8d8ff')
    p.light('scorch', 430, 280, 90, 0.5, 'glow', depth=1.0, color='ff9a4a')
    for i, (x, y, d) in enumerate(((150, 330, 1.0), (520, 340, 1.0), (820, 250, 0.75))):
        p.light('ice%d' % (i + 1), x, y, 40, 0.3, 'glow', depth=d, color='e8f8ff')
    p.anchor('edge', 360, FLOOR, h=120)
    p.anchor('waxley', 470, FLOOR, flip=True)
    dk = p.dark
    # ---------------------------------------------------------------- abyss (0.35)
    ctx = Ctx('cva')
    s = '<rect x="0" y="0" width="1000" height="900" fill="%s"/>' % vgrad(ctx, [(0, '#34465e'), (0.35, '#26344a'), (0.75, '#141c2a'), (1, '#0a0e18')])
    for (y, h, op) in ((260, 60, 0.28), (420, 80, 0.22), (600, 70, 0.18), (740, 50, 0.14)):
        s += '<rect x="0" y="%d" width="1000" height="%d" fill="%s"/>' % (y, h, vgrad(ctx, [(0, '#c8e0f0', 0), (0.5, '#c8e0f0', op), (1, '#c8e0f0', 0)]))
    # far off, the glitter of coloured glass (a glimpse of the Sanctum)
    cols = ['#b8324e', '#3a6ab8', '#d8a830', '#5aa860', '#7a5ab8']
    for i in range(60):
        x, y = rng.u(120, 880), rng.u(730, 880)
        w = rng.u(2, 6)
        s += '<rect x="%.1f" y="%.1f" width="%.1f" height="%.1f" fill="%s" opacity="%.2f" transform="rotate(%.0f %.1f %.1f)"/>' % (
            x, y, w, w * 0.7, rng.pick(cols), rng.u(0.35, 0.8), rng.u(0, 90), x, y)
    # the rock roof at the top, its far edge
    s += fillp('M0 0 L1000 0 L1000 50 Q800 80 600 56 Q400 84 200 58 Q100 70 0 54 Z', '#1a2230')
    p.layer('abyss', 0.35, s, ctx=ctx, px=1.5)
    # ---------------------------------------------------------------- tower (0.75): the carillon, upside down
    ctx = Ctx('cvt')
    s = ''
    stone, stone_sh, stone_hi = fade(FSTONE, dk, 0.1), fade(FSTONE_SH, dk, 0.1), fade(FSTONE_HI, dk, 0.1)
    parts = []
    stages = [(40, 250, 150), (250, 372, 132), (372, 492, 120), (492, 622, 106), (622, 734, 88)]
    for i, (y0, y1, hw) in enumerate(stages):
        body = rect_d(TX - hw, y0, TX + hw, y1)
        courses = ''.join(line('M%.1f %.1f L%.1f %.1f' % (TX - hw, y, TX + hw, y), stone_sh, 1.4, op=0.7) for y in range(int(y0) + 22, int(y1), 22))
        # a frost-crusted cornice at each stage's bottom (it was the top, once) with sideways icicles
        corn = rect_d(TX - hw - 10, y1 - 12, TX + hw + 10, y1)
        parts.append(P(body, stone, stone_sh, off=(-hw * 0.28, 0), over=courses
                       + line('M%.1f %.1f L%.1f %.1f' % (TX + hw - 6, y0 + 4, TX + hw - 6, y1 - 4), stone_hi, 3, op=0.7)))
        parts.append(P(corn, stone, stone_sh, off=(-8, 0), over=line('M%.1f %.1f L%.1f %.1f' % (TX - hw - 10, y1 - 12, TX + hw + 10, y1 - 12), ICE, 4)))
        # little pinnacles pointing down at the corners
        for sx in (-1, 1):
            px = TX + sx * (hw + 4)
            parts.append(P('M%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (px - 9, y1, px + 9, y1, px, y1 + 34), stone, stone_sh, off=(-3, 0)))
    # the spire, pointing down to its tip
    parts.append(P('M%.1f 734 L%.1f 734 L%.1f 812 Z' % (TX - 70, TX + 70, TX), stone, stone_sh, off=(-22, 0),
                   over=line('M%.1f 740 L%.1f 806' % (TX + 36, TX + 4), stone_hi, 2.4, op=0.7)))
    parts.append(E(TX, 818, 7, 7, BRASS, BRASS_SH, off=(-1.4, -1.4)))
    s += draw(ctx, parts, FROST_LINE, MID_W)
    # the belfries: inverted arches, each with a bell crusted in ice
    bells = []
    # buttresses down the flanks, and lancet windows either side of each belfry
    for (y0, y1, hw) in stages:
        for sx in (-1, 1):
            bx = TX + sx * (hw - 16)
            s += fillp(inv_arch_d(bx - 9, bx + 9, y0 + 18, y1 - 24), '#1a2436')
            s += '<path d="%s" fill="none" stroke="%s" stroke-width="3"/>' % (inv_arch_d(bx - 9, bx + 9, y0 + 18, y1 - 24), stone_sh)
    for (y, hw) in ((175, 70), (315, 60), (565, 52), (680, 42)):
        s += fillp(inv_arch_d(TX - hw, TX + hw, y - hw * 1.1, y + hw * 0.9), '#141c2c')
        s += '<path d="%s" fill="none" stroke="%s" stroke-width="6"/>' % (inv_arch_d(TX - hw, TX + hw, y - hw * 1.1, y + hw * 0.9), stone_sh)
        bw = hw * 1.05
        s += line('M%.1f %.1f L%.1f %.1f' % (TX, y - hw * 1.1, TX, y - bw * 0.5), '#3a3446', 3)
        bells += bell_parts(TX, y - bw * 0.5, bw, bw * 0.9, 0)
        # its crust of wax-ice and the icicles growing sideways off it
        for sx in (-1, 1):
            bells.append(icicle(TX + sx * bw * 0.45, y + bw * 0.2, bw * 0.5, bw * 0.12, 90 - sx * 70))
            bells.append(icicle(TX + sx * bw * 0.3, y - bw * 0.1, bw * 0.34, bw * 0.1, 90 - sx * 60))
    s += draw(ctx, bells, BRONZE_LINE, MID_W)
    for (y, hw) in ((175, 70), (315, 60), (565, 52), (680, 42)):
        bw = hw * 1.05
        s += '<path d="M%.1f %.1f Q%.1f %.1f %.1f %.1f" fill="none" stroke="%s" stroke-width="%.1f" opacity="0.85"/>' % (
            TX - bw * 0.45, y - bw * 0.3, TX, y - bw * 0.6, TX + bw * 0.45, y - bw * 0.3, ICE, bw * 0.12)
    # the great clock, frozen at one minute to twelve, frozen chains hanging off it
    s += '<circle cx="%d" cy="430" r="92" fill="%s" stroke="%s" stroke-width="4"/>' % (TX, stone_sh, FROST_LINE)
    s += '<circle cx="%d" cy="430" r="84" fill="none" stroke="%s" stroke-width="3" stroke-dasharray="6 5"/>' % (TX, stone_hi)
    s += clock_face(ctx, TX, 430, 76, hands=(354.0, 359.5))
    chains = ''
    for (x0, L) in ((TX - 60, 150), (TX + 58, 110), (TX - 20, 90)):
        for j in range(int(L / 12)):
            y = 486 + j * 12
            chains += '<ellipse cx="%.1f" cy="%.1f" rx="3.6" ry="6" fill="none" stroke="%s" stroke-width="2.4"/>' % (x0 + (j % 2) * 0.8, y, '#6a7488')
        chains += '<path d="%s" fill="%s"/>' % (ell_d(x0, 486 + L, 5, 3), ICE)
    s += chains
    # sideways icicles off the stage corners
    ice = []
    for (y0, y1, hw) in stages:
        for sx in (-1, 1):
            for j in range(3):
                ice.append(icicle(TX + sx * (hw + 8), y1 - 6 - j * 3, 16 + j * 10 + rng.u(0, 8), 5 + j, 90 - sx * (60 + j * 10)))
    s += draw(ctx, ice, FROST_LINE, BACK_W)
    # the rock roof it hangs from, with the orchard's roots tangled into its masonry
    roof = 'M360 0 L920 0 L920 60 Q820 74 790 50 L490 50 Q450 74 360 58 Z'
    s += draw(ctx, [P(roof, fade('#4a5468', dk, 0.1), fade('#343c50', dk, 0.1), off=(-10, -4))], FROST_LINE, MID_W)
    s += hanging_roots(ctx, rng, 470, 820, 40, 150, '#5a4a36', '#3a3024', n=16, w0=14, dark=dk)
    p.layer('tower', 0.75, s, ctx=ctx, px=2.0)
    # ---------------------------------------------------------------- ledge (1.0): the frozen lip where the roots end
    ctx = Ctx('cvl')
    s = hanging_roots(ctx, rng, -20, 560, 0, 200, '#6e4e36', '#4a3526', n=18, w0=18, dark=dk)
    lip = 'M-20 %d L470 %d Q520 %d 548 %d Q560 %d 540 %d L500 400 L420 380 L300 410 L160 386 L-20 400 Z' % (
        FLOOR, FLOOR - 4, FLOOR - 6, FLOOR + 4, FLOOR + 18, FLOOR + 40)
    parts = [P(lip, '#6a7a98', '#4a5a78', off=(-10, -4))]
    snow = 'M-20 %d Q120 %d 250 %d Q380 %d 470 %d Q520 %d 548 %d L548 %d Q480 %d 380 %d Q250 %d 120 %d L-20 %d Z' % (
        FLOOR - 8, FLOOR - 14, FLOOR - 7, FLOOR - 13, FLOOR - 8, FLOOR - 10, FLOOR + 2, FLOOR + 12, FLOOR + 6, FLOOR + 14, FLOOR + 8,
        FLOOR + 14, FLOOR + 10)
    parts.append(P(snow, ICE, ICE_SH, off=(-3, -3), over=line('M-20 %d Q120 %d 250 %d Q380 %d 470 %d' % (
        FLOOR - 6, FLOOR - 12, FLOOR - 5, FLOOR - 11, FLOOR - 6), '#ffffff', 2.4, op=0.9)))
    for x in range(10, 540, 36):
        L = rng.u(30, 80)
        parts.append(icicle(x + rng.u(-8, 8), FLOOR + 14 + (x % 3) * 4, L, rng.u(8, 13)))
    s += draw(ctx, parts, FROST_LINE, FRONT_W)
    # the scorch's last mark on the ice, and a root end charred by it
    seam = [(300, FLOOR - 3), (360, FLOOR - 4), (420, FLOOR - 5), (452, FLOOR - 2)]
    s += scorch_char(seam, 3.4)
    p.layer('ledge', 1.0, s, ctx=ctx, rect=(0, 0, 1000, 420))
    ctx = Ctx('cvg')
    p.layer('scorch', 1.0, scorch_glow(seam, 3.4), lit=True, ctx=ctx, rect=(280, 260, 200, 40))
    return p


# ================================================================ escapement (boss_4)

def gear_d(cx, cy, r, teeth, depth=None, rot=0.0):
    """A gear wheel's outline: teeth teeth round a rim of radius r."""
    dp = depth if depth is not None else r * 0.14
    pts = []
    n = teeth * 4
    for i in range(n):
        a = math.radians(rot) + 2 * math.pi * i / n
        rr = r + (dp if i % 4 in (1, 2) else 0)
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    return poly_d(pts)


def gear(cx, cy, r, teeth, col=BRASS, sh=BRASS_SH, spokes=5, rot=0.0, frost=True, hub=None):
    """A brass gear: toothed rim, spokes, a hub, frost on its upper teeth."""
    over = '<path d="%s" fill="%s"/>' % (ell_d(cx, cy, r * 0.72, r * 0.72), sh)
    for i in range(spokes):
        a = math.radians(rot + i * 360.0 / spokes)
        over += line('M%.1f %.1f L%.1f %.1f' % (cx, cy, cx + math.cos(a) * r * 0.74, cy + math.sin(a) * r * 0.74), col, r * 0.16)
    over += '<path d="%s" fill="%s" stroke="%s" stroke-width="%.1f"/>' % (ell_d(cx, cy, r * 0.2, r * 0.2), col, BRASS_LINE, max(1, r * 0.04))
    over += dot(cx, cy, r * 0.07, BRASS_LINE)
    if frost:
        over += '<path d="M%.1f %.1f A%.1f %.1f 0 0 1 %.1f %.1f" fill="none" stroke="%s" stroke-width="%.1f" opacity="0.85"/>' % (
            cx - r * 0.9, cy - r * 0.3, r, r, cx + r * 0.6, cy - r * 0.76, ICE, max(1.5, r * 0.12))
    return Part('fill', pth(gear_d(cx, cy, r, teeth, rot=rot)), fill=col, shade=sh, off=(-r * 0.08, -r * 0.08), line=BRASS_LINE,
                over=over, hl=spec(cx - r * 0.5, cy - r * 0.55, r * 0.14, r * 0.06, rot=-40, op=0.6))


def escapement():
    """The clockwork heart of the carillon: a back wall of frosted gear wheels
    and six small clock faces all at one minute to twelve; the escapement
    wheel and its anchor, the great pendulum stopped at an angle, sheeted in
    wax-ice; an iron grate with frozen oil, and at the right Master Tickwell's
    bench: a vise, a tiny anvil, tongs, a lamp and a little forge pot."""
    p = Panel('escapement', 1000, 460, [0.22, 0.26, 0.38], 'rime')
    FLOOR = 322
    rng = Rand(4402)
    p.light('clock', 500, 110, 140, 0.5, 'glow', depth=0.45, color='bfe8ff')
    p.light('pend', 430, 236, 50, 0.35, 'glow', depth=0.8, color='e8f8ff')
    p.light('grate', 620, 300, 190, 0.35, 'glow', depth=1.0, color='9ac8e0')
    p.light('sconce', 130, 200, 150, 0.85, 'flame', h=10)
    p.light('bench_lamp', 870, 262, 160, 0.9, 'flame', h=10, off=True)
    p.light('forge', 942, 294, 120, 0.9, 'flame', h=16, color='f08a3a', off=True)
    p.anchor('boss', 560, FLOOR, flip=True)
    p.anchor('tickwell', 690, FLOOR, flip=True)
    p.anchor('bench', 820, FLOOR - 28, h=300)
    p.anchor('actor', 330, FLOOR, h=120)
    p.anchor('waxley', 240, FLOOR)
    dk = p.dark
    # ---------------------------------------------------------------- gears (0.45): the back wall
    ctx = Ctx('esg')
    s = '<rect x="0" y="0" width="1000" height="460" fill="%s"/>' % vgrad(ctx, [(0, '#1a2234'), (1, '#2a3450')])
    brass, brass_sh = fade(BRASS, dk, 0.45), fade(BRASS_SH, dk, 0.45)
    parts = []
    for (x, y, r, t, rot) in ((120, 110, 110, 16, 5), (320, 60, 70, 12, 0), (300, 230, 60, 10, 12), (500, 250, 90, 14, 3),
                              (690, 90, 100, 15, 8), (880, 220, 120, 18, 0), (760, 330, 60, 10, 6), (40, 320, 70, 11, 0),
                              (980, 40, 70, 11, 10), (560, 60, 40, 8, 0)):
        parts.append(gear(x, y, r, t, brass, brass_sh, rot=rot, frost=True))
    s += draw(ctx, parts, BRASS_LINE, BACK_W)
    # the row of six small clock faces, every one at one minute to twelve
    s += fillp(rrect_d(250, 92, 750, 136, 10), fade('#3a4458', dk, 0.3))
    for i in range(6):
        s += clock_face(ctx, 290 + i * 84, 114, 18, hands=(354.0, 359.5))
    # cracks in the wall's frost
    for (x, y) in ((200, 380), (620, 170), (840, 390)):
        s += line('M%.1f %.1f l12 -18 l-6 -10 l14 -20' % (x, y), '#0e1420', 2.4, op=0.8)
    p.layer('gears', 0.45, s, ctx=ctx)
    # ---------------------------------------------------------------- engine (0.8): the escapement and the pendulum
    ctx = Ctx('ese')
    s = ''
    parts = []
    # the escapement wheel: long hooked teeth, and the anchor rocking over it
    ex, ey, er = 240, 150, 92
    pts = []
    for i in range(30):
        a = 2 * math.pi * i / 30
        r = er * (1.18 if i % 2 == 0 else 1.0)
        a2 = a + (0.12 if i % 2 == 0 else 0)
        pts.append((ex + math.cos(a2) * r, ey + math.sin(a2) * r))
    over = '<path d="%s" fill="%s"/>' % (ell_d(ex, ey, er * 0.74, er * 0.74), BRASS_SH)
    for i in range(6):
        a = math.radians(i * 60 + 15)
        over += line('M%.1f %.1f L%.1f %.1f' % (ex, ey, ex + math.cos(a) * er * 0.76, ey + math.sin(a) * er * 0.76), BRASS, 12)
    over += '<path d="%s" fill="%s" stroke="%s" stroke-width="2"/>' % (ell_d(ex, ey, 18, 18), BRASS, BRASS_LINE)
    over += '<path d="M%.1f %.1f A%.1f %.1f 0 0 1 %.1f %.1f" fill="none" stroke="%s" stroke-width="10" opacity="0.8"/>' % (
        ex - er * 0.95, ey - er * 0.3, er * 1.05, er * 1.05, ex + er * 0.7, ey - er * 0.8, ICE)
    parts.append(Part('fill', pth(poly_d(pts)), fill=BRASS, shade=BRASS_SH, off=(-8, -8), line=BRASS_LINE, over=over))
    anchor_d = ('M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (
        ex - 110, ey - 60, ex - 90, ey - 84, ex, ey - 124, ex + 90, ey - 84, ex + 110, ey - 60, ex + 92, ey - 56, ex, ey - 100,
        ex - 92, ey - 56))
    parts.append(P(anchor_d, '#6a7488', '#4a5468', off=(-4, -4), over=dot(ex, ey - 110, 7, '#3a4458')))
    # the great pendulum, stopped at an angle, its bob crusted in ice
    px0, py0 = 520, -10
    bx, by = 430, 236
    parts.append(LIMB('M%.1f %.1f L%.1f %.1f' % (px0, py0, bx, by - 30), '#6a7488', 10,
                      over=line('M%.1f %.1f L%.1f %.1f' % (px0 - 2, py0, bx - 2, by - 30), '#a8b0c4', 2.4, op=0.8)))
    parts.append(Part('fill', pth(ell_d(bx, by, 40, 40)), fill=BRASS, shade=BRASS_SH, off=(-6, -6), line=BRASS_LINE,
                      over='<path d="%s" fill="none" stroke="%s" stroke-width="3"/>' % (ell_d(bx, by, 28, 28), BRASS_SH)
                      + clock_face(ctx, bx, by, 18, hands=(354.0, 359.5), frost=False),
                      hl=spec(bx - 18, by - 20, 8, 4, rot=-40, op=0.7)))
    for sx in (-1, 1):
        parts.append(icicle(bx + sx * 20, by + 30, 28, 8, 90 - sx * 20))
    parts.append(icicle(bx - 30, by, 20, 7, 150))
    s += draw(ctx, parts, BRASS_LINE, MID_W)
    # a sheet of wax-ice over the works
    s += '<path d="M120 40 Q240 20 360 50 L360 70 Q240 40 120 60 Z" fill="%s" opacity="0.8"/>' % ICE
    p.layer('engine', 0.8, s, ctx=ctx)
    # ---------------------------------------------------------------- floor (1.0): the grate and Tickwell's bench
    ctx = Ctx('esf')
    s = ''
    grate = rect_d(-20, FLOOR, 1020, 470)
    bars = ''.join(line('M%.1f %d L%.1f 470' % (x, FLOOR + 2, x + (x - 500) * 0.25, ), '#20242e', 5) for x in range(-20, 1040, 36))
    bars += ''.join(line('M-20 %.1f L1020 %.1f' % (y, y), '#20242e', 4) for y in (FLOOR + 22, FLOOR + 56, FLOOR + 100))
    oil = ''.join('<path d="%s" fill="%s" opacity="0.8"/>' % (ell_d(x, y, rng.u(20, 50), rng.u(4, 8)), '#9ac8e0')
                  for x, y in ((120, FLOOR + 30), (430, FLOOR + 60), (640, FLOOR + 28), (900, FLOOR + 70)))
    parts = [P(grate, '#4a4e5c', '#34384a', off=(0, -4), over=bars + oil
               + line('M-20 %d L1020 %d' % (FLOOR + 2, FLOOR + 2), '#7a8098', 3))]
    # the wall sconce at the left (Waxley's light)
    parts.append(LIMB('M96 %d Q100 %d 124 %d' % (FLOOR - 150, FLOOR - 146, FLOOR - 144), IRON, 5))
    s += draw(ctx, parts, FROST_LINE, FRONT_W)
    lant, tip = street_lamp(ctx, 130, FLOOR - 70, FLOOR - 170)
    s += lant
    p.lights['sconce']['p'] = [round(tip[0], 2), round(tip[1], 2)]
    # Tickwell's bench
    bench = []
    top = FLOOR - 28
    bench.append(P(rect_d(740, top, 912, top + 12), WOOD, WOOD_SH, off=(-3, -3),
                   over=line('M742 %d L910 %d' % (top + 3, top + 3), WOOD_HI, 2, op=0.8)))
    for x in (752, 900):
        bench.append(P(rect_d(x - 5, top + 12, x + 5, FLOOR + 2), WOOD, WOOD_SH, off=(-2, 0)))
    bench.append(P(rect_d(748, top + 36, 904, top + 42), WOOD, WOOD_SH, off=(-1, -1)))
    # the vise, the tiny anvil, the tongs
    bench.append(P('M752 %d L776 %d L776 %d L770 %d L770 %d L758 %d L758 %d L752 %d Z' % (top, top, top - 14, top - 14, top - 6, top - 6,
                                                                                   top - 14, top - 14), IRON, IRON_SH, off=(-2, -2)))
    bench.append(LIMB('M764 %d L764 %d' % (top - 14, top - 22), IRON_HI, 3))
    bench.append(P('M782 %d L806 %d L802 %d L814 %d L776 %d L786 %d Z' % (top, top, top - 8, top - 14, top - 14, top - 8), '#5a5e70', '#3a3e50',
                   off=(-2, -2)))
    bench.append(LIMB('M850 %d L880 %d M852 %d L882 %d' % (top - 2, top - 8, top - 5, top - 2), IRON, 2.4))
    # the lamp (its flame at (870, 262)) and the forge pot on the floor beside the bench
    bench.append(P('M862 %d L878 %d L876 %d L864 %d Z' % (top, top, top - 8, top - 8), BRASS, BRASS_SH, off=(-1, -1)))
    glass = ctx.radgrad([(0, '#fff6d0'), (0.6, '#e8e8f0'), (1, '#b8c8d8')], cx=0.5, cy=0.7, r=0.6)
    bench.append(Part('fill', pth('M864 %d Q862 %d 866 %d L874 %d Q878 %d 876 %d Z' % (top - 8, top - 20, top - 30, top - 30, top - 20, top - 8)),
                      fill=glass, no_shade=True))
    bench.append(P('M930 %d L954 %d L950 %d L934 %d Z' % (FLOOR - 28, FLOOR - 28, FLOOR - 6, FLOOR - 6), '#4a4458', '#2e2a3a', off=(-2, -2),
                   over='<path d="%s" fill="#1a1010"/>' % ell_d(942, FLOOR - 28, 12, 3)))
    for x in (934, 950):
        bench.append(LIMB('M%d %d L%d %d' % (x, FLOOR - 6, x + (x - 942) * 0.3, FLOOR + 2), '#4a4458', 2.4))
    s += draw(ctx, bench, INK, FRONT_W)
    p.lights['bench_lamp']['p'] = [870, top - 12]
    p.lights['forge']['p'] = [942, FLOOR - 30]
    p.layer('floor', 1.0, s, ctx=ctx, rect=(0, 100, 1000, 360))
    return p


# ================================================================ the Shattered Sanctum's kit

PANE_COLS = {'ruby': 'b8324e', 'cobalt': '3a6ab8', 'gold': 'd8a830', 'green': '5aa860', 'violet': '7a5ab8', 'rose': 'e07aa0'}
PANES = ['#' + PANE_COLS[k] for k in ('ruby', 'cobalt', 'gold', 'green', 'violet', 'rose')]


def shard(G, rng, pts, cols, motif=None, came=7.0):
    """A huge floating pane: a polygon of glass cut by lead cames into a few
    pieces (a fan from one corner), with a scrap of the legend on it."""
    cx = sum(p_[0] for p_ in pts) / len(pts)
    cy = sum(p_[1] for p_ in pts) / len(pts)
    s = ''
    n = len(pts)
    for i in range(n):
        a, b = pts[i], pts[(i + 1) % n]
        q = [(cx, cy), a, ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)]
        s += G.quad(q, cols[i % len(cols)], came * 0.7)
        q = [(cx, cy), ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2), b]
        s += G.quad(q, cols[(i + 1) % len(cols)], came * 0.7)
    if motif:
        s += motif(G, cx, cy)
    s += '<path d="%s" fill="none" stroke="%s" stroke-width="%.1f" stroke-linejoin="round"/>' % (poly_d(pts), CAME, came)
    return s


def m_hand_candle(G, cx, cy, k=1.0):
    """A small hand holding up a candle (a scrap of the legend)."""
    s = pane(G, 'M%.1f %.1f Q%.1f %.1f %.1f %.1f L%.1f %.1f Q%.1f %.1f %.1f %.1f Z' % (
        cx - 16 * k, cy + 30 * k, cx - 20 * k, cy + 8 * k, cx - 8 * k, cy, cx + 8 * k, cy, cx + 18 * k, cy + 10 * k, cx + 14 * k, cy + 30 * k),
        GLASS['flame'], None, 4)
    s += pane(G, rect_d(cx - 5 * k, cy - 26 * k, cx + 5 * k, cy), GLASS['ivory'], None, 3.4)
    s += pane(G, flame_d(cx, cy - 26 * k, 14 * k, 24 * k, 1), GLASS['gold'], None, 3.4)
    return s


def m_halo_face(G, cx, cy, k=1.0):
    """Half a haloed face, eyes closed."""
    s = ''
    for i in range(7):
        a0, a1 = math.radians(180 + i * 26), math.radians(180 + (i + 1) * 26)
        q = [(cx, cy), (cx + 44 * k * math.cos(a0), cy + 44 * k * math.sin(a0)), (cx + 44 * k * math.cos(a1), cy + 44 * k * math.sin(a1))]
        s += G.quad(q, GLASS['gold'] if i % 2 else '#f0d27a', 3.4)
    s += pane(G, 'M%.1f %.1f A%.1f %.1f 0 0 0 %.1f %.1f Z' % (cx, cy - 26 * k, 26 * k, 26 * k, cx, cy + 26 * k), '#f4e8e0', None, 4)
    s += line('M%.1f %.1f q%.1f %.1f %.1f %.1f' % (cx - 16 * k, cy - 2 * k, 5 * k, 4 * k, 10 * k, 0), CAME, 3)
    return s


def m_bell(G, cx, cy, k=1.0):
    return glass_bell(G, cx, cy - 22 * k, 40 * k, 38 * k, 8)


def m_eye(G, cx, cy, k=1.0):
    """Part of a great closed eye: a black lid, a sleeping lash line."""
    s = pane(G, 'M%.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f Z' % (cx - 44 * k, cy, cx, cy - 26 * k, cx + 44 * k, cy, cx, cy + 10 * k,
                                                                         cx - 44 * k, cy), GLASS['hush_dk'], None, 4)
    s += line('M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (cx - 40 * k, cy + 2 * k, cx, cy + 14 * k, cx + 40 * k, cy + 2 * k), CAME, 5)
    return s


def lead_strip(rng, x0, y0, x1, y1):
    """A bent strip of lead dangling between two shards, like a broken chain."""
    mx, my = (x0 + x1) / 2 + rng.u(-20, 20), max(y0, y1) + rng.u(20, 50)
    d = 'M%.1f %.1f Q%.1f %.1f %.1f %.1f' % (x0, y0, mx, my, x1, y1)
    return line(d, CAME, 6) + line(d, '#4a3a5a', 2, op=0.8)


# ================================================================ sanctum_vista (world_5)

def sanctum_vista():
    """The Shattered Sanctum: a chapel of glass hanging in pieces over a pale
    violet void; huge floating panes at angles, cut by lead cames, scraps of
    the legend on them (a hand holding a candle, half a haloed face, a bell,
    part of a closed eye), bent lead dangling between them, slanting beams
    of coloured light; a thick cracked glass slab at the left."""
    p = Panel('sanctum_vista', 1400, 460, [0.30, 0.26, 0.40], 'shards')
    FLOOR = 318
    rng = Rand(5501)
    for i, (x, y, c) in enumerate(((560, 160, 'ruby'), (760, 230, 'cobalt'), (960, 140, 'gold'), (1140, 250, 'green'),
                                   (1300, 170, 'violet'))):
        p.light('beam%d' % (i + 1), x, y, 120, 0.4, 'glow', depth=0.65, color=PANE_COLS[c])
    for i, (x, y, d) in enumerate(((180, 280, 1.0), (470, 330, 1.0), (860, 330, 0.65), (1220, 90, 0.65))):
        p.light('glint%d' % (i + 1), x, y, 90 if i == 0 else 40, 0.35, 'glow', depth=d, color='f0f4ff')
    p.anchor('edge', 270, FLOOR, h=120)
    p.anchor('waxley', 150, FLOOR)
    # ---------------------------------------------------------------- void (0.3)
    ctx = Ctx('svv')
    s = '<rect x="0" y="0" width="1400" height="460" fill="%s"/>' % vgrad(ctx, [(0, '#5a5070'), (0.6, '#4a4262'), (1, '#3a3450')])
    for i, c in enumerate(('#e07aa0', '#d8a830', '#5aa860', '#3a6ab8', '#7a5ab8')):
        s += '<path d="M-40 %d Q700 %d 1440 %d" fill="none" stroke="%s" stroke-width="26" opacity="0.08"/>' % (120 + i * 26, 60 + i * 26, 140 + i * 26, c)
    for i in range(70):
        x, y = rng.u(0, 1400), rng.u(0, 360)
        w = rng.u(3, 9)
        s += '<path d="%s" fill="%s" opacity="%.2f"/>' % (poly_d([(x, y), (x + w, y + w * 0.3), (x + w * 0.4, y + w)]), rng.pick(PANES), rng.u(0.3, 0.6))
    # the Hushdeep far below: a black ellipse with a pale rim
    s += '<path d="%s" fill="#08060e"/>' % ell_d(820, 470, 420, 70)
    s += '<path d="%s" fill="none" stroke="#9a90c8" stroke-width="3" opacity="0.6"/>' % ell_d(820, 470, 420, 70)
    p.layer('void', 0.3, s, ctx=ctx)
    # ---------------------------------------------------------------- shards (0.65)
    ctx = Ctx('svs')
    G = Glass(ctx)
    s = ''
    shards = [
        ([(470, 60), (640, 30), (660, 250), (500, 280)], ['#b8324e', '#e07aa0', '#b8324e'], lambda G, x, y: m_hand_candle(G, x, y + 10)),
        ([(700, 150), (850, 130), (880, 330), (720, 350)], ['#3a6ab8', '#6a9ad8', '#3a6ab8'], lambda G, x, y: m_bell(G, x, y)),
        ([(900, 40), (1060, 70), (1030, 250), (880, 220)], ['#d8a830', '#f0d27a', '#d8a830'], lambda G, x, y: m_halo_face(G, x, y)),
        ([(1080, 170), (1230, 150), (1250, 350), (1100, 380)], ['#5aa860', '#8ac890', '#5aa860'], None),
        ([(1240, 60), (1390, 90), (1370, 280), (1230, 250)], ['#7a5ab8', '#2a2040', '#7a5ab8'], lambda G, x, y: m_eye(G, x, y)),
        ([(610, 300), (700, 290), (690, 400), (620, 390)], ['#e07aa0', '#b8324e'], None),
        ([(990, 300), (1060, 290), (1070, 380), (990, 400)], ['#3a6ab8', '#d8a830'], None),
    ]
    for pts, cols, motif in shards:
        s += shard(G, rng, pts, cols, motif)
    for (x0, y0, x1, y1) in ((660, 250, 720, 300), (880, 220, 900, 300), (1030, 250, 1080, 300), (1230, 250, 1250, 330)):
        s += lead_strip(rng, x0, y0, x1, y1)
    p.layer('shards', 0.65, s, ctx=ctx)
    # ---------------------------------------------------------------- beams (0.65, lit): slanting coloured light
    ctx = Ctx('svb')
    s = ''
    for i, (x, c) in enumerate(((520, 'ruby'), (740, 'cobalt'), (950, 'gold'), (1150, 'green'), (1320, 'violet'))):
        g = vgrad(ctx, [(0, '#' + PANE_COLS[c], 0.0), (0.4, '#' + PANE_COLS[c], 0.22), (1, '#' + PANE_COLS[c], 0.0)])
        s += '<path d="M%.1f -10 L%.1f -10 L%.1f 470 L%.1f 470 Z" fill="%s"/>' % (x - 20, x + 30, x - 110, x - 200, g)
    p.layer('beams', 0.65, s, lit=True, ctx=ctx)
    # ---------------------------------------------------------------- ledge (1.0): the cracked glass slab
    ctx = Ctx('svl')
    G = Glass(ctx)
    s = ''
    slab = [(-30, FLOOR), (520, FLOOR - 6), (548, FLOOR + 10), (500, 470), (-30, 470)]
    s += G.pane(poly_d(slab), '#a8c0d8', 8, box=(-30, FLOOR - 6, 548, 470))
    s += '<path d="M-30 %d L520 %d L548 %d L520 %d L-30 %d Z" fill="#e8f4ff" opacity="0.9"/>' % (FLOOR, FLOOR - 6, FLOOR + 10, FLOOR + 14, FLOOR + 18)
    for (x, y) in ((120, FLOOR + 30), (330, FLOOR + 50), (460, FLOOR + 24)):
        s += line('M%.1f %.1f l20 26 l-10 18 l22 30 M%.1f %.1f l-16 22' % (x, y, x + 20, y + 26), '#40506a', 2.6, op=0.9)
    # wind streaks across the slab
    for (x, y, L) in ((40, FLOOR - 30, 180), (240, FLOOR - 60, 220), (120, FLOOR - 90, 140)):
        s += line('M%.1f %.1f q%.1f %.1f %.1f %.1f' % (x, y, L * 0.5, -8, L, -2), '#f0f4ff', 2.2, op=0.5)
    s += '<path d="M-30 %d L520 %d" fill="none" stroke="%s" stroke-width="6"/>' % (FLOOR, FLOOR - 6, CAME)
    p.layer('ledge', 1.0, s, ctx=ctx, rect=(0, 200, 620, 260))
    return p


# ================================================================ glass_throne (boss_5)

def rose_tracery(ctx, cx, cy, R, stone, sh, hi):
    """A colossal rose window's frame, a ring of 16 petals, empty of glass."""
    s = ''
    s += '<path d="%s" fill="none" stroke="%s" stroke-width="%.1f"/>' % (ell_d(cx, cy, R, R), sh, R * 0.1)
    s += '<path d="%s" fill="none" stroke="%s" stroke-width="%.1f"/>' % (ell_d(cx, cy, R, R), stone, R * 0.07)
    s += '<path d="%s" fill="none" stroke="%s" stroke-width="%.1f"/>' % (ell_d(cx, cy, R * 0.28, R * 0.28), stone, R * 0.05)
    for i in range(16):
        a = math.radians(i * 22.5)
        x0, y0 = cx + math.cos(a) * R * 0.28, cy + math.sin(a) * R * 0.28
        x1, y1 = cx + math.cos(a) * R * 0.96, cy + math.sin(a) * R * 0.96
        s += line('M%.1f %.1f L%.1f %.1f' % (x0, y0, x1, y1), stone, R * 0.04)
        # each petal's pointed head
        a0, a1 = math.radians(i * 22.5 + 1.5), math.radians(i * 22.5 + 21)
        m = math.radians(i * 22.5 + 11.25)
        d = 'M%.1f %.1f Q%.1f %.1f %.1f %.1f Q%.1f %.1f %.1f %.1f' % (
            cx + math.cos(a0) * R * 0.66, cy + math.sin(a0) * R * 0.66, cx + math.cos(m) * R * 1.02, cy + math.sin(m) * R * 1.02,
            cx + math.cos(m) * R * 0.86, cy + math.sin(m) * R * 0.86, cx + math.cos(m) * R * 1.02, cy + math.sin(m) * R * 1.02,
            cx + math.cos(a1) * R * 0.66, cy + math.sin(a1) * R * 0.66)
        s += line(d, stone, R * 0.025)
    s += '<path d="%s" fill="none" stroke="%s" stroke-width="%.1f" opacity="0.7"/>' % (ell_d(cx - R * 0.02, cy - R * 0.02, R * 1.03, R * 1.03), hi, R * 0.015)
    return s


def glass_throne():
    """The Prism Saint's nave: the colossal rose window at the back, empty of
    glass (she is its glass), cold white rays from it; altar steps strewn
    with broken glass and the empty iron frame she stood in. Behind her the
    actor stands at depth 0.96, so when he walks to her he is behind it."""
    p = Panel('glass_throne', 1000, 460, [0.26, 0.24, 0.40], 'shards')
    FLOOR = 318
    rng = Rand(5502)
    p.light('rose_center', 500, 175, 380, 0.6, 'glow', depth=0.5, color='f0f4ff')
    for i, ((x, y), c) in enumerate(zip(((380, 90), (620, 90), (325, 190), (675, 190), (385, 285), (615, 285)),
                                        ('ruby', 'cobalt', 'gold', 'green', 'violet', 'rose'))):
        p.light('pane%d' % (i + 1), x, y, 160, 0.55, 'glow', depth=1.0, color=PANE_COLS[c], off=True)
    for i, ((x, y), c) in enumerate(zip(((500, 340), (522, 376), (546, 412), (572, 448)), ('ruby', 'gold', 'cobalt', 'green'))):
        p.light('step%d' % (i + 1), x, y, 90, 0.4, 'glow', depth=1.0, color=PANE_COLS[c], off=True)
    p.anchor('saint', 500, FLOOR - 18)
    p.anchor('actor', 280, FLOOR, depth=0.96, h=120)
    dk = p.dark
    # ---------------------------------------------------------------- rose (0.5): the empty window
    ctx = Ctx('gtr')
    s = '<rect x="0" y="0" width="1000" height="460" fill="%s"/>' % vgrad(ctx, [(0, '#2a2440'), (1, '#3a3450')])
    stone, sh, hi = fade('#b8b0d0', dk, 0.2), fade('#7a7098', dk, 0.2), '#e8e4f8'
    rng2 = Rand(77)
    for y in range(0, 460, 40):
        for x in range(-int(rng2.u(0, 60)), 1000, 90):
            s += fillp(rrect_d(x + 2, y + 2, x + 88, y + 38, 3), mix(fade('#5a5270', dk, 0.2), '#000000', rng2.u(0, 0.15)))
    # the window's opening, pale void light through it
    cx, cy, R = 500, 175, 210
    s += '<path d="%s" fill="%s"/>' % (ell_d(cx, cy, R, R), ctx.radgrad([(0, '#f4f4ff'), (0.6, '#c8c4e8'), (1, '#8a84b0')]))
    s += rose_tracery(ctx, cx, cy, R, stone, sh, hi)
    # shards of the lost glass still caught at the rim
    for i in range(10):
        a = math.radians(rng.u(0, 360))
        x, y = cx + math.cos(a) * R * 0.92, cy + math.sin(a) * R * 0.92
        w = rng.u(8, 16)
        s += '<path d="%s" fill="%s" stroke="%s" stroke-width="2"/>' % (poly_d([(x, y), (x + w, y + w * 0.3), (x + w * 0.2, y + w)]), rng.pick(PANES), CAME)
    # pillars either side
    for x in (150, 850):
        s += fillp(rect_d(x - 34, 0, x + 34, 460), fade('#4a4262', dk, 0.2))
        s += line('M%.1f 0 L%.1f 460' % (x - 22, x - 22), fade('#6a6282', dk, 0.2), 4)
    p.layer('rose', 0.5, s, ctx=ctx)
    # ---------------------------------------------------------------- rays (0.5, lit)
    ctx = Ctx('gty')
    s = ''
    for i in range(14):
        a = math.radians(20 + i * 10.8)
        g = ctx.radgrad([(0, '#ffffff', 0.32), (0.5, '#e8ecff', 0.12), (1, '#e8ecff', 0)], cx=0.5, cy=0.0, r=1.0)
        w = math.radians(2.2)
        s += '<path d="M%.1f %.1f L%.1f %.1f L%.1f %.1f Z" fill="#f4f6ff" opacity="%.2f"/>' % (
            cx, cy, cx + math.cos(a - w) * 700, cy + math.sin(a - w) * 700, cx + math.cos(a + w) * 700, cy + math.sin(a + w) * 700,
            0.14 if i % 2 else 0.09)
    s += radial(ctx, cx, cy, 120, '#ffffff', 0.5)
    p.layer('rays', 0.5, s, lit=True, ctx=ctx)
    # ---------------------------------------------------------------- steps (1.0)
    ctx = Ctx('gts')
    s = ''
    parts = []
    for i, (y, w) in enumerate(((FLOOR, 520), (FLOOR + 30, 640), (FLOOR + 64, 780), (FLOOR + 100, 940))):
        parts.append(P(rect_d(500 - w / 2, y, 500 + w / 2, y + 34), fade('#9a94b8', dk, 0.1), fade('#6a6488', dk, 0.1), off=(0, -6),
                       over=line('M%.1f %.1f L%.1f %.1f' % (500 - w / 2, y + 2, 500 + w / 2, y + 2), '#d8d4ec', 2.4, op=0.9)))
    # the empty iron frame she stood in
    parts.append(LIMB('M430 %d L430 %d Q430 %d 500 %d Q570 %d 570 %d L570 %d' % (FLOOR, FLOOR - 120, FLOOR - 190, FLOOR - 200, FLOOR - 190,
                                                                               FLOOR - 120, FLOOR), IRON, 7))
    parts.append(LIMB('M430 %d L570 %d' % (FLOOR - 60, FLOOR - 60), IRON, 4))
    s += draw(ctx, parts, INK, FRONT_W)
    # broken glass on the steps
    for i in range(40):
        x, y = rng.u(200, 800), rng.u(FLOOR - 2, FLOOR + 130)
        w = rng.u(4, 12)
        s += '<path d="%s" fill="%s" stroke="%s" stroke-width="1.4" opacity="0.9"/>' % (
            poly_d([(x, y), (x + w, y + w * 0.2), (x + w * 0.4, y + w * 0.5)]), rng.pick(PANES + ['#e8ecff']), CAME)
    p.layer('steps', 1.0, s, ctx=ctx, rect=(0, 100, 1000, 360))
    return p


# ================================================================ glass_truth (boss_5_after)

TRUTH = (60, 940, 18, 446, 260)     # the one wide pointed arch: x0, x1, apex, sill, spring


def truth_arch_d(inset=0.0):
    x0, x1, apex, sill, spring = TRUTH
    x0, x1, apex, sill = x0 + inset, x1 - inset, apex + inset * 1.3, sill - inset
    cx = (x0 + x1) / 2.0
    w = x1 - x0
    return 'M%.1f %.1f L%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f L%.1f %.1f Z' % (
        x0, sill, x0, spring, x0, spring - 120, cx - w * 0.3, apex + 20, cx, apex, cx + w * 0.3, apex + 20, x1, spring - 120, x1, spring,
        x1, sill)


def truth_outline(inset, step):
    x0, x1, apex, sill, spring = TRUTH
    x0, x1, apex, sill = x0 + inset, x1 - inset, apex + inset * 1.3, sill - inset
    cx = (x0 + x1) / 2.0
    w = x1 - x0

    def cubic(p0, p1, p2, p3, t):
        u = 1 - t
        return (u * u * u * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t * t * t * p3[0],
                u * u * u * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t * t * t * p3[1])
    pts = [(x0, sill - (sill - spring) * i / 40.0) for i in range(40)]
    pts += [cubic((x0, spring), (x0, spring - 120), (cx - w * 0.3, apex + 20), (cx, apex), i / 90.0) for i in range(90)]
    pts += [cubic((cx, apex), (cx + w * 0.3, apex + 20), (x1, spring - 120), (x1, spring), i / 90.0) for i in range(90)]
    pts += [(x1, spring + (sill - spring) * i / 40.0) for i in range(41)]
    out = []
    acc = step / 2.0
    for (ax, ay), (bx, by) in zip(pts, pts[1:]):
        seg = math.hypot(bx - ax, by - ay)
        while acc <= seg and seg > 0:
            t = acc / seg
            out.append((ax + (bx - ax) * t, ay + (by - ay) * t, math.degrees(math.atan2(by - ay, bx - ax))))
            acc += step
        acc -= seg
    return out


def glass_girl(G, x, y, k=1.0):
    """The small girl with a candle on her head, like Waxby, mouth open,
    singing (in glass)."""
    s = ''
    s += pane(G, 'M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f L%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f Z' % (
        x - 26 * k, y, x - 24 * k, y - 26 * k, x - 12 * k, y - 44 * k, x, y - 44 * k,
        x + 4 * k, y - 44 * k, x + 20 * k, y - 36 * k, x + 26 * k, y - 10 * k, x + 28 * k, y), GLASS['rose'] if 'rose' in GLASS else '#e07aa0',
        (x - 28 * k, y - 44 * k, x + 28 * k, y), 4)
    s += pane(G, ell_d(x + 2 * k, y - 60 * k, 20 * k, 19 * k), '#f4e0d0', (x - 18 * k, y - 80 * k, x + 22 * k, y - 40 * k), 4)
    s += pane(G, 'M%.1f %.1f Q%.1f %.1f %.1f %.1f L%.1f %.1f Z' % (x - 18 * k, y - 66 * k, x + 2 * k, y - 90 * k, x + 22 * k, y - 66 * k,
                                                                x + 2 * k, y - 74 * k), '#8a5a36', None, 3.4)
    s += line('M%.1f %.1f q%.1f %.1f %.1f %.1f' % (x - 8 * k, y - 62 * k, 3 * k, -4 * k, 6 * k, 0), CAME, 3.2)
    s += line('M%.1f %.1f q%.1f %.1f %.1f %.1f' % (x + 4 * k, y - 62 * k, 3 * k, -4 * k, 6 * k, 0), CAME, 3.2)
    s += pane(G, ell_d(x + 12 * k, y - 50 * k, 5 * k, 6 * k), '#3a1a20', None, 2.4)
    s += pane(G, rect_d(x - 3 * k, y - 104 * k, x + 7 * k, y - 82 * k), GLASS['ivory'], None, 3)
    s += pane(G, flame_d(x + 2 * k, y - 104 * k, 16 * k, 26 * k, 1), GLASS['gold'], None, 3)
    return s


def glass_truth():
    """The window nobody was shown, in glass_legend's style: one wide pointed
    arch. At the bottom a black pit of violet rings with a huge closed eye,
    its lids black panes and a lead line making a small sleeping smile; at
    the pit's edge a small girl with a candle on her head, singing, cobalt
    song bands curling from her mouth down into it; a small bell either
    side; at the top one big gold flame, the first Undercandle, just lit."""
    p = Panel('glass_truth', 1000, 460, None, None, shimmer=True, title='The Girl Who Sang')
    ctx = Ctx('gtt')
    G = Glass(ctx)
    rng = Rand(5503)
    s = fillp(rect_d(0, 0, 1000, 460), '#1d1526')
    y = 0
    row = 0
    while y < 460:
        x = -(rng.u(0, 60) if row % 2 else 0)
        while x < 1000:
            w = rng.u(70, 120)
            s += fillp(rrect_d(x + 2, y + 2, x + w - 2, y + 44, 3), mix('#261c32', '#000000', rng.u(0, 0.2)))
            x += w
        y += 46
        row += 1
    s += '<path d="%s" fill="#3a3148"/>' % truth_arch_d(-18)
    s += '<path d="%s" fill="none" stroke="#54496a" stroke-width="4"/>' % truth_arch_d(-14)
    s += '<path d="%s" fill="#140e1c"/>' % truth_arch_d(-3)
    clip = ctx.clip('<path d="%s"/>' % truth_arch_d(22))

    def col(x, y, r):
        if y > 330:
            return r.pick([GLASS['hush_dk'], GLASS['hush'], '#3a2c64'])
        return r.pick([GLASS['cobalt'], '#2a4a8a', GLASS['cobalt'], '#34306e', '#4a7ac8'])
    pic = mosaic(G, rng, 70, 20, 930, 446, 48, 42, col)
    # the first Undercandle's flame at the top, a sunburst round it
    cx, cy = 500, 96
    for k in range(36):
        a0, a1 = math.radians(k * 10 - 5), math.radians(k * 10 + 5)
        rr = 230 if k % 2 else 190
        q = [(cx, cy), (cx + rr * math.cos(a0), cy + rr * math.sin(a0)), (cx + rr * math.cos(a1), cy + rr * math.sin(a1))]
        pic += G.quad(q, GLASS['gold'] if k % 2 else '#f0d27a', 4.4)
    pic += pane(G, ell_d(cx, cy, 70, 70), '#f6e2a0', None, 5)
    pic += pane(G, rect_d(470, 110, 530, 170), GLASS['ivory'], (470, 110, 530, 170))
    pic += pane(G, flame_d(500, 116, 80, 96, 4), GLASS['gold'], (460, 20, 540, 116))
    pic += pane(G, flame_d(501, 112, 50, 62, 3), '#ffd98a', None, 4)
    pic += pane(G, flame_d(502, 108, 26, 34, 1), GLASS['flame'], None, 3)
    # the pit: concentric violet panes, and the huge closed eye, sleeping
    pic += pane(G, 'M70 300 Q280 270 500 280 Q720 270 930 300 L930 460 L70 460 Z', GLASS['green'], (70, 270, 930, 460))
    for rx, ry, c in ((340, 116, GLASS['hush']), (280, 94, '#3a2c64'), (220, 74, GLASS['hush_dk']), (170, 56, '#120c20')):
        pic += pane(G, ell_d(500, 376, rx, ry), c, (500 - rx, 376 - ry, 500 + rx, 376 + ry), 5)
    # the huge closed eye: black lids, the lash line under them a small sleeping smile
    lid = 'M340 368 Q500 300 660 368 Q500 392 340 368 Z'
    pic += pane(G, lid, '#0a0812', None, 6)
    pic += pane(G, 'M372 360 Q500 318 628 360 Q500 372 372 360 Z', '#1e1830', None, 4)
    pic += line('M344 370 Q500 414 656 370', CAME, 7)
    for i in range(9):
        x = 372 + i * 32
        y = 370 + 44 * math.sin((x - 344) / 312.0 * math.pi) * 0.5
        pic += line('M%.1f %.1f l%.1f 14' % (x, y, (x - 500) * 0.05), CAME, 3.4)
    # the song: cobalt bands curling from her mouth down into the pit
    for i in range(3):
        d = 'M%.1f %.1f C%.1f %.1f %.1f %.1f %.1f %.1f' % (292, 262 + i * 6, 370, 250 + i * 14, 350, 320 + i * 10, 430 + i * 20, 340 + i * 6)
        pic += line(d, CAME, 16 - i * 2) + line(d, '#8ab8f0', 10 - i * 2)
    # the girl at the pit's edge, and a bell either side
    pic += line('M70 214 L930 214', CAME, 6)
    pic += glass_girl(G, 250, 300, 1.4)
    pic += glass_bell(G, 150, 170, 60, 58, -10)
    pic += glass_bell(G, 850, 170, 60, 58, 10)
    s += '<g clip-path="%s">%s</g>' % (clip, pic)
    for i, (x, y, a) in enumerate(truth_outline(10, 17)):
        c = (GLASS['ruby'], GLASS['cobalt'], GLASS['gold'])[i % 3]
        t = 'rotate(%.1f %.1f %.1f)' % (a, x, y)
        s += '<g transform="%s">%s</g>' % (t, G.pane(rect_d(x - 7, y - 7, x + 7, y + 7), c, 2.6, sliver=False))
    s += '<path d="%s" fill="none" stroke="%s" stroke-width="7"/>' % (truth_arch_d(0), CAME)
    s += '<path d="%s" fill="none" stroke="%s" stroke-width="6"/>' % (truth_arch_d(20), CAME)
    p.layer('glass', 1.0, s, lit=True, ctx=ctx)
    ctx = Ctx('gtm')
    s = mullion(ctx, 18) + mullion(ctx, 982)
    p.layer('mullions', 1.12, s, lit=True, ctx=ctx)
    return p


# ================================================================ the Hushdeep's kit

HBLACK, HRIPPLE, HRIM, STOLEN = '#05040a', '#1a1428', '#4a3a7a', '#ffd84a'


def ripples(cx, cy, rx0, ry0, n, step, col=HRIPPLE, w=2.4, op=0.9, fade_k=0.06):
    """Concentric rings on the still water (or the black above it)."""
    s = ''
    for k in range(n):
        rx, ry = rx0 + k * step, ry0 + k * step * (ry0 / float(rx0))
        s += '<path d="%s" fill="none" stroke="%s" stroke-width="%.1f" opacity="%.2f"/>' % (ell_d(cx, cy, rx, ry), col, w, max(0.05, op - k * fade_k))
    return s


def glass_tread(G, x, y, w, col, tilt=0.0, faint=0.6):
    """One tread of Tessel's glass stair: a thick pane, faintly coloured."""
    t = 'rotate(%.1f %.1f %.1f)' % (tilt, x, y)
    top = [(x - w / 2, y - 6), (x + w / 2, y - 6), (x + w / 2 - 6, y + 10), (x - w / 2 - 6, y + 10)]
    s = G.quad(top, col, 3.4)
    s += line('M%.1f %.1f L%.1f %.1f' % (x - w / 2 + 4, y - 3, x + w / 2 - 6, y - 3), '#ffffff', 2, op=0.6)
    return '<g transform="%s" opacity="%.2f">%s</g>' % (t, faint, s)


# ================================================================ hushdeep_vista (world_6)

def hushdeep_vista():
    """The lake of quiet at the bottom of the world: pure black above with the
    faintest violet ripples, a flat black mirror to the horizon, far out a
    tiny gold point seen under the surface (the stolen flame) with one faint
    ring; the last treads of Tessel's glass stair coming down at the top
    left; black sand, one dead reed. No motes: the stillness is the art."""
    p = Panel('hushdeep_vista', 1400, 460, [0.10, 0.09, 0.16], None)
    FLOOR = 318
    p.light('far_flame', 1020, 250, 50, 0.5, 'glow', depth=0.7, color='ffd84a')
    for i, ((x, y), c) in enumerate(zip(((60, 60), (130, 140), (190, 215), (240, 290)), ('ruby', 'gold', 'cobalt', 'green'))):
        p.light('stair%d' % (i + 1), x, y, 50, 0.3, 'glow', depth=1.0, color=PANE_COLS[c])
    p.anchor('edge', 390, FLOOR, h=120)
    # ---------------------------------------------------------------- sky (0.3)
    ctx = Ctx('hvs')
    s = fillp(rect_d(0, 0, 1400, 460), HBLACK)
    p.layer('sky', 0.3, s, ctx=ctx, px=0.25)
    # the faintest violet ripples on the black: lit, so the dark doesn't eat them
    ctx = Ctx('hvr')
    p.layer('ripples', 0.3, ripples(700, 60, 300, 40, 12, 60, '#3a3060', 2.0, 0.55, 0.04), lit=True, ctx=ctx, px=2.0)
    # ---------------------------------------------------------------- lake (0.7): the black mirror
    ctx = Ctx('hvl')
    s = '<rect x="0" y="170" width="1400" height="290" fill="%s"/>' % vgrad(ctx, [(0, '#0a0812'), (1, '#04030a')])
    s += line('M0 170 L1400 170', HRIM, 2, op=0.6)
    for i in range(14):
        y = 184 + i * i * 1.5
        s += line('M%.1f %.1f L%.1f %.1f' % (-10, y, 1410, y), HRIPPLE, 1.4 + i * 0.1, op=0.5)
    # the stolen flame, far out, under the surface: a gold point, one faint ring
    s += radial(ctx, 1020, 250, 26, '#ffd84a', 0.6) + dot(1020, 250, 3, '#ffe890')
    s += '<path d="%s" fill="none" stroke="#6a5a4a" stroke-width="1.4" opacity="0.8"/>' % ell_d(1020, 250, 40, 8)
    p.layer('lake', 0.7, s, ctx=ctx)
    ctx = Ctx('hvm')
    m = line('M0 170 L1400 170', '#6a5a9a', 2.2, op=0.55)
    for i in range(10):
        y = 184 + i * i * 2.2
        m += line('M%.1f %.1f L%.1f %.1f' % (-10, y, 1410, y), '#2e2650', 1.4 + i * 0.1, op=0.4)
    m += '<path d="%s" fill="none" stroke="#8a7a50" stroke-width="1.4" opacity="0.7"/>' % ell_d(1020, 250, 40, 8)
    p.layer('mirror', 0.7, m, lit=True, ctx=ctx, rect=(0, 160, 1400, 300), px=2.0)
    # ---------------------------------------------------------------- shore (1.0): the stair's last treads, black sand, a dead reed
    ctx = Ctx('hvh')
    G = Glass(ctx)
    s = ''
    sand = 'M-20 %d Q180 %d 380 %d Q520 %d 640 %d Q660 %d 640 %d L-20 470 Z' % (FLOOR, FLOOR - 6, FLOOR - 2, FLOOR + 4, FLOOR + 16, FLOOR + 30,
                                                                             FLOOR + 50)
    s += draw(ctx, [P(sand, '#141020', '#0a0810', off=(-6, -3), over=line('M-20 %d Q180 %d 380 %d Q520 %d 640 %d' % (
        FLOOR + 1, FLOOR - 5, FLOOR - 1, FLOOR + 5, FLOOR + 17), '#2a2440', 2, op=0.9))], '#040308', FRONT_W)
    for (x, y), c in zip(((60, 60), (130, 140), (190, 215), (240, 290)), ('ruby', 'gold', 'cobalt', 'green')):
        s += glass_tread(G, x, y + 8, 110, '#' + PANE_COLS[c], tilt=-8, faint=0.55)
    # one dead reed
    s += line('M560 %d C556 %d 566 %d 560 %d' % (FLOOR + 10, FLOOR - 30, FLOOR - 60, FLOOR - 96), '#2a2438', 3)
    s += line('M560 %d q-10 8 -16 22' % (FLOOR - 60), '#2a2438', 2)
    s += '<path d="%s" fill="#2a2438"/>' % ell_d(560, FLOOR - 104, 4, 11)
    p.layer('shore', 1.0, s, ctx=ctx, rect=(0, 0, 700, 460))
    return p


# ================================================================ hushdeep_heart (the finale)

# Tessel's glass stair on the 0.85 plane: a curve from the top-left corner
# down to the shore, the procession standing on its treads.
STAIR = ((110.0, -20.0), (190.0, 390.0), (760.0, 440.0))
STAIR_ON = {'town': (0.16, 150), 'waxley': (0.3, 120), 'carry': (0.44, 104), 'tollgrave': (0.58, 230),
            'tickwell': (0.72, 100), 'lost': (0.84, 100)}
STAIR_COLS = ('ruby', 'gold', 'cobalt', 'green', 'violet', 'rose')


def stair_pt(t):
    (ax, ay), (bx, by), (cx, cy) = STAIR
    u = 1 - t
    return (u * u * ax + 2 * u * t * bx + t * t * cx, u * u * ay + 2 * u * t * by + t * t * cy)


def stair_tan(t):
    (ax, ay), (bx, by), (cx, cy) = STAIR
    dx = 2 * (1 - t) * (bx - ax) + 2 * t * (cx - bx)
    dy = 2 * (1 - t) * (by - ay) + 2 * t * (cy - by)
    return math.degrees(math.atan2(dy, dx))


def hushdeep_heart():
    """The finale's stage, wide for the pan from the eye (right) to the stair
    (left): black with violet ripples; the lake, a great ring of ripples at
    the right where the eye rises; Tessel's glass stair descending in a long
    curve from the top-left corner to the shore, its treads in the six
    colours, faint until lit; black sand, the water's edge."""
    p = Panel('hushdeep_heart', 1800, 600, [0.08, 0.08, 0.14], None)
    FLOOR = 440
    for i, t in enumerate((0.07, 0.24, 0.38, 0.52, 0.66, 0.8)):
        x, y = stair_pt(t)
        p.light('stair%d' % (i + 1), x, y - 30, 120, 0.5, 'glow', depth=0.85, color=PANE_COLS[STAIR_COLS[i]], off=True)
    p.light('eye_glow', 1450, 300, 260, 0.45, 'glow', depth=0.75, color='d8d4f0')
    p.light('shore_glow', 900, 412, 180, 0.35, 'glow', depth=1.0, color='6a5a9a')
    p.anchor('eye', 1450, 300, depth=0.75, h=380)
    # Clear of the dialogue box's portrait circles on the phone through every
    # boss_6 camera (test_story_art's staging): the hero faces the Hush from
    # `actor`, then walks left to the cold wick floating off the spit
    p.anchor('wick', 790, FLOOR - 16, depth=0.92)
    p.anchor('actor', 950, FLOOR, h=120)
    p.anchor('actor_give', 870, FLOOR, h=120, face=-1)
    for aid, (t, h) in STAIR_ON.items():
        x, y = stair_pt(t)
        p.anchor(aid, x, y, depth=0.85, h=h)
    # ---------------------------------------------------------------- void (0.3)
    ctx = Ctx('hhv')
    s = fillp(rect_d(0, 0, 1800, 600), HBLACK)
    p.layer('void', 0.3, s, ctx=ctx, px=0.25)
    ctx = Ctx('hhr')
    p.layer('ripples', 0.3, ripples(900, 80, 400, 50, 14, 70, '#342c58', 2.2, 0.5, 0.03), lit=True, ctx=ctx, px=2.0)
    # ---------------------------------------------------------------- water (0.7): the lake, the eye's ring
    ctx = Ctx('hhw')
    s = '<rect x="0" y="150" width="1800" height="450" fill="%s"/>' % vgrad(ctx, [(0, '#0a0812'), (1, '#030208')])
    s += line('M0 150 L1800 150', HRIM, 2, op=0.5)
    for i in range(12):
        y = 164 + i * i * 2.2
        s += line('M-10 %.1f L1810 %.1f' % (y, y), HRIPPLE, 1.4 + i * 0.12, op=0.45)
    # where the eye rises: a great ring of ripples, and its pale reflection
    s += ripples(1450, 392, 150, 26, 8, 44, '#3a3060', 2.6, 0.9, 0.1)
    s += '<path d="%s" fill="%s"/>' % (ell_d(1450, 420, 170, 30), ctx.radgrad([(0, '#8a82b0', 0.35), (1, '#8a82b0', 0)]))
    p.layer('water', 0.7, s, ctx=ctx, px=1.2)
    ctx = Ctx('hhm')
    m = line('M0 150 L1800 150', '#6a5a9a', 2.2, op=0.5)
    for i in range(9):
        y = 164 + i * i * 3.2
        m += line('M-10 %.1f L1810 %.1f' % (y, y), '#2a2448', 1.4 + i * 0.1, op=0.4)
    m += ripples(1450, 392, 150, 26, 6, 44, '#4a3e78', 2.2, 0.55, 0.08)
    p.layer('mirror', 0.7, m, lit=True, ctx=ctx, rect=(0, 140, 1800, 460), px=2.0)
    # ---------------------------------------------------------------- stair (0.85): Tessel's glass stair
    ctx = Ctx('hhs')
    G = Glass(ctx)
    s = ''
    n = 22
    for i in range(n):
        t = i / float(n - 1)
        x, y = stair_pt(t)
        c = '#' + PANE_COLS[STAIR_COLS[min(5, int(t * 6))]]
        s += glass_tread(G, x, y + 8, 76 + t * 30, c, tilt=max(-10, min(10, stair_tan(t) - 50)) * 0.3, faint=0.5)
    p.layer('stair', 0.85, s, ctx=ctx, rect=(0, 0, 1150, 600), px=2.4)
    # ---------------------------------------------------------------- shore (1.0): black sand, the water's edge
    ctx = Ctx('hhh')
    s = ''
    near = 'M1020 %d Q1300 %d 1820 %d L1820 620 L1020 620 Z' % (FLOOR + 14, FLOOR + 8, FLOOR + 12)
    s += '<path d="%s" fill="%s"/>' % (near, vgrad(ctx, [(0, '#0a0812'), (1, '#030208')]))
    for i in range(6):
        y = FLOOR + 24 + i * i * 4
        s += line('M1030 %.1f L1810 %.1f' % (y, y), HRIPPLE, 1.6, op=0.6)
    sand = 'M520 %d Q600 %d 700 %d Q860 %d 1000 %d Q1040 %d 1060 %d Q1040 %d 1000 %d L1000 620 L520 620 Z' % (
        FLOOR + 30, FLOOR + 4, FLOOR - 2, FLOOR - 4, FLOOR - 2, FLOOR + 4, FLOOR + 14, FLOOR + 24, FLOOR + 30)
    s += draw(ctx, [P(sand, '#141020', '#0a0810', off=(-6, -3), over=line('M540 %d Q600 %d 700 %d Q860 %d 1000 %d Q1040 %d 1058 %d' % (
        FLOOR + 22, FLOOR + 3, FLOOR - 1, FLOOR - 3, FLOOR - 1, FLOOR + 5, FLOOR + 14), '#2a2440', 2, op=0.9))], '#040308', FRONT_W)
    s += line('M1000 %d Q1030 %d 1060 %d' % (FLOOR - 1, FLOOR + 6, FLOOR + 14), '#6a5a9a', 1.8, op=0.8)
    p.layer('shore', 1.0, s, ctx=ctx, rect=(500, 350, 1300, 250))
    return p


# ================================================================ homecoming

def feast_table(ctx, x0, x1, top):
    """A long feast table: a cloth, pies, loaves, a whole cheese and cups."""
    parts = [P(rect_d(x0, top, x1, top + 10), '#f4ecdc', '#d0c4b0', off=(-2, -2),
               over=''.join(line('M%.1f %.1f L%.1f %.1f' % (x, top + 10, x + 4, top + 34), '#d0c4b0', 1.6) for x in range(int(x0) + 20, int(x1), 40))),
             P('M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (x0, top + 10, x1, top + 10, x1 - 4, top + 34, x0 + 4, top + 34), '#e8dccc', '#c4b6a0',
               off=(-3, -1))]
    for x in (x0 + 10, x1 - 14):
        parts.append(P(rect_d(x, top + 30, x + 6, top + 56), WOOD, WOOD_SH, off=(-1, 0)))
    n = int((x1 - x0) / 46)
    for i in range(n):
        x = x0 + 24 + i * 46
        kind = i % 4
        if kind == 0:     # a pie
            parts.append(P('M%.1f %.1f Q%.1f %.1f %.1f %.1f Z' % (x - 16, top + 1, x, top - 14, x + 16, top + 1), '#d8964a', '#a86a2a', off=(-2, -1),
                           over=line('M%.1f %.1f l6 -5 M%.1f %.1f l6 -5' % (x - 8, top - 3, x + 1, top - 5), '#8a4a1a', 1.4)))
        elif kind == 1:   # a loaf
            parts.append(E(x, top - 5, 16, 8, '#c8864a', '#9a5a2a', off=(-2, -2), over=line('M%.1f %.1f l4 -5 M%.1f %.1f l4 -5' % (x - 6, top - 3, x + 2, top - 3), '#7a4a1a', 1.4)))
        elif kind == 2:   # the whole cheese (the Bellfounder was right)
            parts.append(P('M%.1f %.1f L%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (x - 16, top + 1, x + 16, top + 1, x + 14, top - 16, x - 14, top - 16),
                           '#f2c75a', '#c8a03a', off=(-2, -1), over=dot(x - 6, top - 8, 2.4, '#c8a03a') + dot(x + 6, top - 6, 1.8, '#c8a03a')))
        else:             # cups
            parts.append(P(rect_d(x - 5, top - 12, x + 5, top), '#b8bcd0', '#8a8ea8', off=(-1, -1)))
    return draw(ctx, parts, INK, FRONT_W)


def homecoming():
    """Lanternfold's square at dawn, everyone in it: the dawn sky and a low sun;
    Evenbell risen in lilac stone at the square's head, its great rose window
    glowing in all six colours (Tessel), its bell in the belfry, a young yew
    sapling by its door with candle-shaped blossoms (Yarrow's), strings of
    little lanterns to the houses; cobbles with melting snow, a well, a long
    feast table, townsfolk cheering at the edges, the cat on the wall."""
    p = Panel('homecoming', 1600, 460, [0.45, 0.42, 0.55], 'embers')
    FLOOR = 330
    rng = Rand(6602)
    lamp_x = (150, 300, 470, 730, 900, 1170, 1330, 1480)
    for i in range(10):
        x = 520 + i * 60
        y = 120 + 30 * math.sin(i * 0.7)
        p.light('bunting%d' % (i + 1), x, y, 50, 0.7, 'flame', h=6, depth=0.55)
    p.light('rose', 800, 150, 220, 0.6, 'glow', depth=0.55, color='ffd8b0')
    p.light('sun', 1320, 110, 400, 0.9, 'glow', depth=0.25)
    for aid, x, flip in (('tollgrave', 380, False), ('taper', 560, False), ('hollin', 660, True), ('waxley', 960, True),
                         ('tickwell', 1070, True)):
        p.anchor(aid, x, FLOOR, flip=flip)
    p.anchor('actor', 800, FLOOR, h=120, face=-1)
    # ---------------------------------------------------------------- sky (0.25)
    ctx = Ctx('hcs')
    s = '<rect x="0" y="0" width="1600" height="460" fill="%s"/>' % vgrad(ctx, [(0, '#a8c8ec'), (0.45, '#ffd9a0'), (0.85, '#f2a57a'), (1, '#e8906a')])
    s += radial(ctx, 1320, 110, 320, '#fff2c0', 0.8)
    s += '<circle cx="1320" cy="110" r="58" fill="#fff6d8"/>'
    for k in range(20):
        a = math.radians(-200 + k * 18)
        s += '<path d="M%.1f %.1f L%.1f %.1f L%.1f %.1f Z" fill="#fff2c0" opacity="0.3"/>' % (
            1320 + 66 * math.cos(a - 0.05), 110 + 66 * math.sin(a - 0.05), 1320 + 520 * math.cos(a), 110 + 520 * math.sin(a),
            1320 + 66 * math.cos(a + 0.05), 110 + 66 * math.sin(a + 0.05))
    for x, y, w in ((80, 90, 200), (380, 50, 160), (620, 110, 140), (1000, 70, 190), (1480, 60, 150)):
        s += '<path d="%s" fill="#ffc8b0" opacity="0.8"/>' % cloud_d(x, y, w, w * 0.22)
        s += '<path d="%s" fill="#ffe8d8" opacity="0.8"/>' % cloud_d(x + w * 0.1, y - 4, w * 0.7, w * 0.16)
    p.layer('sky', 0.25, s, ctx=ctx)
    # ---------------------------------------------------------------- evenbell (0.55)
    ctx = Ctx('hce')
    s = ''
    # the houses round the square, far side
    for (x0, x1, wt, pk, wall, roof, lean, timber, ch) in ((-30, 130, 190, 110, '#d8b8c8', '#6a3a48', -6, True, (60, 30)),
                                                           (130, 270, 210, 140, '#c8b8d8', '#4a3a6a', 6, False, None),
                                                           (270, 420, 196, 116, '#e8c8a8', '#5a3a4a', -8, True, (380, 30)),
                                                           (1150, 1290, 200, 124, '#e0c0a0', '#6a3a48', 8, True, (1250, 34)),
                                                           (1290, 1440, 214, 146, '#c0b0d8', '#443a6a', -6, False, None),
                                                           (1440, 1630, 194, 110, '#d8c0b0', '#5a3a4a', 6, True, (1520, 30))):
        hs, tips = house(ctx, rng, x0, x1, 300, wt, pk, wall, roof, lean, timber, ch, [((x0 + x1) / 2 - 12, wt + 30, 24, 30, True)])
        s += hs
    # Evenbell, risen, in lilac stone
    st, sh = '#7a6a9a', '#5a4a7a'
    cx, base, k = 800, 300, 1.0
    parts = []
    for tx in (cx - 150, cx + 150):
        parts.append(P(rect_d(tx - 44, base - 250, tx + 44, base), st, sh, off=(-8, 0),
                       over=fillp(arch_d(tx - 20, tx + 20, base - 228, base - 168), '#3a2e58') + line('M%.1f %.1f L%.1f %.1f' % (tx + 44, base - 250, tx + 44, base), '#ffe8b8', 3, op=0.8)))
        parts.append(P('M%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (tx - 50, base - 250, tx, base - 350, tx + 50, base - 250), sh, '#40345e', off=(-6, -2)))
    parts.append(P(rect_d(cx - 106, base - 200, cx + 106, base), st, sh, off=(-10, 0),
                   over=fillp(arch_d(cx - 26, cx + 26, base - 76, base), '#3a2e58')))
    parts.append(P('M%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (cx - 116, base - 200, cx, base - 290, cx + 116, base - 200), sh, '#40345e', off=(-6, -2)))
    parts.append(P('M%.1f %.1f L%.1f %.1f L%.1f %.1f Z' % (cx - 16, base - 286, cx, base - 390, cx + 16, base - 286), sh, '#40345e', off=(-2, -2)))
    # a bell in each belfry, the great one in the left
    for tx, bw in ((cx - 150, 34), (cx + 150, 28)):
        parts += bell_parts(tx, base - 222, bw, bw * 0.9, 0)
    s += draw(ctx, parts, '#241a3a', MID_W)
    # the great rose window, all six colours: Tessel
    G = Glass(ctx)
    R = 50
    s += '<circle cx="%d" cy="150" r="%d" fill="#3a2e58"/>' % (cx, R + 8)
    for i in range(12):
        a0, a1 = math.radians(i * 30), math.radians((i + 1) * 30)
        q = [(cx, 150), (cx + R * math.cos(a0), 150 + R * math.sin(a0)), (cx + R * math.cos(a1), 150 + R * math.sin(a1))]
        s += G.quad(q, PANES[i % 6], 3)
    s += G.pane(ell_d(cx, 150, R * 0.3, R * 0.3), '#fff2c8', 3, box=None)
    s += '<circle cx="%d" cy="150" r="%d" fill="none" stroke="%s" stroke-width="5"/>' % (cx, R + 3, '#241a3a')
    # Yarrow's sapling by the door, candle-shaped blossoms
    sap = [LIMB('M%d %d C%d %d %d %d %d %d' % (cx - 60, base, cx - 64, base - 30, cx - 54, base - 50, cx - 58, base - 76), '#8a6a4a', 5)]
    for (dx, dy) in ((-78, -66), (-40, -70), (-60, -92), (-86, -84), (-34, -90)):
        sap.append(E(cx + dx, base + dy, 12, 9, '#6a9a4a', '#4a7a34', off=(-2, -2)))
    s += draw(ctx, sap, '#241a3a', MID_W)
    for (dx, dy) in ((-78, -74), (-44, -80), (-62, -100), (-88, -90), (-36, -98)):
        s += fillp(rect_d(cx + dx - 2, base + dy - 6, cx + dx + 2, base + dy), '#fff4dc') + '<path d="%s" fill="#ffd060"/>' % flame_d(cx + dx, base + dy - 6, 4, 7)
    # strings of little lanterns from the towers to the houses
    pts = [(520 + i * 60, 120 + 30 * math.sin(i * 0.7)) for i in range(10)]
    d = 'M430 150 ' + ' '.join('Q%.1f %.1f %.1f %.1f' % ((pts[i - 1][0] + x) / 2 if i else 475, (pts[i - 1][1] + y) / 2 + 14 if i else 150, x, y)
                               for i, (x, y) in enumerate(pts)) + ' Q1100 150 1170 160'
    s += line(d, '#3a2e40', 1.8)
    for (x, y) in pts:
        s += fillp(rrect_d(x - 5, y, x + 5, y + 10, 2), '#ffd878') + line('M%.1f %.1f L%.1f %.1f' % (x - 5, y + 10, x + 5, y + 10), '#3a2e40', 1.6)
        p.lights['bunting%d' % (pts.index((x, y)) + 1)]['p'] = [round(x, 1), round(y + 4, 1)]
    p.layer('evenbell', 0.55, s, ctx=ctx)
    # ---------------------------------------------------------------- square (1.0)
    ctx = Ctx('hcq')
    s = ''
    s += fillp('M-20 %d L1620 %d L1620 470 L-20 470 Z' % (FLOOR - 42, FLOOR - 42), '#c8b8d8')
    for row, y in enumerate(range(FLOOR - 40, 470, 16)):
        x = -20 + (row % 2) * 18
        while x < 1620:
            s += fillp(rrect_d(x + 1.5, y + 1.5, x + 34, y + 14, 4), mix('#b8a8c8', '#8a7a9a', rng.u(0, 0.4)))
            x += 36
    # melting snow in patches
    for i in range(14):
        x, y = rng.u(0, 1600), rng.u(FLOOR - 30, 460)
        s += '<path d="%s" fill="#f4eef8" opacity="0.9"/>' % ell_d(x, y, rng.u(20, 60), rng.u(4, 9))
    # the low wall at the back with the cat on it
    s += draw(ctx, [P(rect_d(1080, FLOOR - 66, 1300, FLOOR - 40), '#9a8ab0', '#7a6a90', off=(-3, -3))], INK, FRONT_W)
    cat = [E(1210, FLOOR - 76, 14, 10, '#3a3040', '#2a2030', off=(-2, -2)),
           E(1224, FLOOR - 88, 9, 8, '#3a3040', '#2a2030', off=(-1, -1), over=dot(1221, FLOOR - 89, 1.4, '#f8d860') + dot(1228, FLOOR - 89, 1.4, '#f8d860')),
           P('M1217 %d L1219 %d L1223 %d Z' % (FLOOR - 94, FLOOR - 102, FLOOR - 95), '#3a3040', '#2a2030'),
           P('M1226 %d L1230 %d L1232 %d Z' % (FLOOR - 95, FLOOR - 102, FLOOR - 93), '#3a3040', '#2a2030'),
           LIMB('M1198 %d Q1188 %d 1192 %d' % (FLOOR - 72, FLOOR - 60, FLOOR - 50), '#3a3040', 3.4)]
    s += draw(ctx, cat, INK, FRONT_W)
    # the feast table, and the well
    s += feast_table(ctx, 1180, 1500, FLOOR - 46)
    well = [P(rect_d(170, FLOOR - 62, 260, FLOOR - 36), '#9a8ab0', '#7a6a90', off=(-4, -2),
              over=''.join(line('M%d %d L%d %d' % (x, FLOOR - 62, x, FLOOR - 36), '#7a6a90', 1.4) for x in (190, 214, 238))),
            E(215, FLOOR - 62, 45, 7, '#4a3a5a', '#3a2a4a', off=(0, 0)),
            LIMB('M178 %d L178 %d M252 %d L252 %d' % (FLOOR - 62, FLOOR - 112, FLOOR - 62, FLOOR - 112), WOOD, 5),
            P('M166 %d L215 %d L264 %d Z' % (FLOOR - 108, FLOOR - 134, FLOOR - 108), '#6a3a48', '#4a2430', off=(-3, -2))]
    s += draw(ctx, well, INK, FRONT_W)
    # townsfolk cheering at the edges
    for i, x in enumerate((20, 70, 1530, 1580)):
        s += townsfolk(ctx, x, FLOOR + 40 + (i % 2) * 10, rng.pick(['#5a4a7a', '#6a3a4a', '#3a4a6a', '#4a5a3a']), 1.2)
    # the lamps round the square
    tips = []
    for i, x in enumerate(lamp_x):
        ls, tip = street_lamp(ctx, x, FLOOR + 6, FLOOR - 150)
        s += ls
        tips.append(tip)
    p.layer('square', 1.0, s, ctx=ctx, rect=(0, 150, 1600, 310))
    for i, (x, y) in enumerate(tips):
        p.light('lamp%d' % (i + 1), x, y, 130, 0.9, 'flame', h=9)
    return p


# ================================================================ additions to v2's panels (manifest only)

def extend_undercandle(m):
    """The Hush's grasp rises from behind the floor ring (its bottom cropped)
    and closes on the flame; under_warm is the flame warm again (off until
    the_pull lights it; under_flame is its cold kind)."""
    m['anchors']['grasp'] = {'p': [500, 492], 'depth': 0.85, 'h': 640}
    m['lights']['under_warm'] = {'p': [500, 58], 'r': 700, 's': 1.0, 'kind': 'flame', 'depth': 0.8, 'h': 60,
                                 'color': 'ffd070', 'off': True}


def extend_hush_eye(m):
    """The Hush's own small candle floats on the black under the eye (lullaby)."""
    m['anchors']['float'] = {'p': [500, 352], 'depth': 1.0}


PANELS = [orchard_vista, heartwood, carillon_vista, escapement, sanctum_vista, glass_throne, glass_truth, hushdeep_vista,
          hushdeep_heart, homecoming]
EXTEND = {'undercandle': extend_undercandle, 'hush_eye': extend_hush_eye}
