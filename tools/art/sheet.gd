# WICK art contact sheet: rasterizes every SVG under game/art (and game/icon.svg)
# straight from its text with Image.load_svg_from_string (ThorVG, like the game's
# importer, so no import cache is touched) and composes PNGs on the dark
# cathedral background:
#   <out>.png           everything, stacked
#   <out>_wick.png      the assembled rig (rest, sword forward, walk and swing
#                       poses that test the pivots, every face), then in-game size
#   <out>_parts.png     each Wick part alone, its pivot marked with a red cross
#   <out>_enemies.png   every enemy frame, big, then in-game size
#   <out>_boss.png      Old Tollgrave's frames big (collision box, ground line
#                       and the stuck head's target marked on a second copy),
#                       then at in-game size on the tower blue and the dark purple
#   <out>_props.png     props, big, then in-game size (32 px tiles)
#   <out>_items.png     relics, HUD and touch glyphs, logo, icon
#   <out>_heroes.png    every Calling's rig assembled as wick_rig.gd does it
#                       (rest with its flame, the two run strides, jump, the
#                       swing's wind-up, middle and follow-through, hurt, and
#                       the knight's guard), its five faces, then in-game size
#                       on the dark purple and the tower blue
#   <out>_lineup.png    the five at rest side by side: 64 px (one world px per
#                       px), 192 px (the iPhone's 3x) and each candle tier
#   <out>_closeup.png   the five big (3 px per unit), at rest and mid-run
#   <out>_hparts.png    each Calling's parts alone, pivots marked
#   <out>_portraits.png the dialogue portraits, square and in their circle
#   <out>_loot.png      the item icons at 96, 48, 32 and 26 px
# godot --headless --path game --script res://../tools/art/sheet.gd -- /abs/out.png [section ...]
# (sections: scene wick parts enemies boss props items heroes lineup closeup hparts portraits loot)
extends SceneTree

const BG := Color("1d1526")
const LIT := Color("3a3148")
const PAD := 12

# Wick's rig: draw order and pivots (frame units), mirrored from tools/art/wick.py
const ORDER := ["cape", "leg_back", "arm_back", "body", "leg_front", "head", "candle", "sword", "arm_front"]
const PIVOTS := {
	"cape": Vector2(58, 84), "leg_back": Vector2(60, 104), "arm_back": Vector2(54, 86), "body": Vector2(64, 108),
	"leg_front": Vector2(68, 104), "head": Vector2(64, 84), "candle": Vector2(60, 34), "sword": Vector2(64, 96),
	"arm_front": Vector2(74, 86),
}
const HAND_FRONT := Vector2(76, 101)
const FLAME_BASE := Vector2(60, 19)
const HEADS := ["head", "head_blink", "head_hurt", "head_happy", "head_fierce"]

var cache := {}
var _crops := {}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/wick_sheet.png"
	var base := out.get_basename()
	var only := args.slice(1)
	var sections := []
	var makers := {"scene": scene_section, "wick": wick_section, "parts": parts_section, "enemies": enemy_section,
		"boss": boss_section, "props": props_section, "items": items_section, "heroes": heroes_section,
		"lineup": lineup_section, "closeup": closeup_section, "hparts": hparts_section,
		"portraits": portraits_section, "loot": loot_section}
	for name in makers:
		if only.size() > 0 and not only.has(name):
			continue
		var img: Image = makers[name].call()
		img.save_png("%s_%s.png" % [base, name])
		sections.append(img)
	if only.size() > 0:
		print("wrote the sections ", only)
		quit()
		return
	# a close-up of the rest pose and the in-game strip, for critique
	var big := canvas(1600, 700, Color("120c18"))
	paste(big, rig({"sword": 90, "flame_mark": true}, "head", 4.0, 176, 136, 16, 4), 0, 0)
	paste(big, rig({"sword": 90}, "head_fierce", 4.0, 176, 136, 16, 4, LIT), 800, 0)
	big.save_png("%s_big.png" % base)
	var w := 0
	var h := 0
	for s in sections:
		w = maxi(w, s.get_width())
		h += s.get_height()
	var all := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	all.fill(Color("0c0810"))
	var y := 0
	for s in sections:
		all.blend_rect(s, Rect2i(Vector2i.ZERO, s.get_size()), Vector2i(0, y))
		y += s.get_height()
	all.save_png(out)
	print("wrote ", out, " (", w, "x", h, ") and its sections")
	edge_report()
	quit()


# Lists every SVG whose art reaches its frame's edge (clipped), except the
# ones meant to: the tile-filling reliquaries, the icon, the bell rope and
# the altar standing on its frame's bottom.
func edge_report() -> void:
	var files := PackedStringArray(["icon.svg"])
	for cls in CALLINGS:
		for f in list_svgs("art/heroes/" + cls):
			if not f.get_file().begins_with("portrait_"):
				files.append(f)
	for dir in ["art/wick", "art/enemies", "art/props", "art/relics", "art/ui", "art/items"]:
		files.append_array(list_svgs(dir))
	var bad := []
	for f in files:
		var n := f.get_file()
		if n.begins_with("reliquary") or n == "icon.svg":
			continue
		var img := rast(f, 1.0)
		var w := img.get_width()
		var h := img.get_height()
		var sides := []
		var edges := {"top": [], "bottom": [], "left": [], "right": []}
		for x in w:
			if img.get_pixel(x, 0).a > 0.05:
				edges["top"].append(x)
			if img.get_pixel(x, h - 1).a > 0.05:
				edges["bottom"].append(x)
		for y in h:
			if img.get_pixel(0, y).a > 0.05:
				edges["left"].append(y)
			if img.get_pixel(w - 1, y).a > 0.05:
				edges["right"].append(y)
		for k in edges:
			if edges[k].size() > 0:
				sides.append("%s(%d px)" % [k, edges[k].size()])
		if sides.size() > 0:
			bad.append("%s: %s" % [f, ", ".join(sides)])
	print("art touching its frame edge: ", "none" if bad.is_empty() else "")
	for b in bad:
		print("  ", b)


# ---------------------------------------------------------------- rasterizing

func rast(rel: String, scale: float) -> Image:
	var key := "%s@%s" % [rel, scale]
	if cache.has(key):
		return cache[key]
	var text := FileAccess.get_file_as_string("res://" + rel)
	var img := Image.new()
	if text == "" or img.load_svg_from_string(text, scale) != OK:
		push_error("could not rasterize " + rel)
		img = Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
		img.fill(Color.MAGENTA)
	img.convert(Image.FORMAT_RGBA8)
	cache[key] = img
	return img


func list_svgs(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open("res://" + dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".svg"):
			out.append(dir + "/" + f)
	out.sort()
	return out


func canvas(w: int, h: int, col: Color = BG) -> Image:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(col)
	return img


func paste(dst: Image, src: Image, x: int, y: int) -> void:
	dst.blend_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), Vector2i(x, y))


func fill_rect(dst: Image, r: Rect2i, col: Color) -> void:
	dst.fill_rect(r, col)


func small(src: Image, w: int, h: int) -> Image:
	var s := src.duplicate()
	s.resize(w, h, Image.INTERPOLATE_LANCZOS)
	return s


func zoom(src: Image, k: int) -> Image:
	var s := src.duplicate()
	s.resize(src.get_width() * k, src.get_height() * k, Image.INTERPOLATE_NEAREST)
	return s


func cross(dst: Image, p: Vector2, col: Color = Color(1, 0.15, 0.15), r: int = 7) -> void:
	var x := int(round(p.x))
	var y := int(round(p.y))
	for i in range(-r, r + 1):
		for t: int in [0, 1]:
			var px: int = x + i
			var py: int = y + t
			if px >= 0 and px < dst.get_width() and py >= 0 and py < dst.get_height():
				dst.set_pixel(px, py, col)
			px = x + t
			py = y + i
			if px >= 0 and px < dst.get_width() and py >= 0 and py < dst.get_height():
				dst.set_pixel(px, py, col)


# Blends src into dst turned by ang (radians) around src_pivot, which lands
# on dst_pos. Bilinear, premultiplied.
func blend_xf(dst: Image, src_full: Image, pivot_full: Vector2, dst_pos: Vector2, ang: float) -> void:
	if absf(ang) < 0.0001:
		paste(dst, src_full, int(round(dst_pos.x - pivot_full.x)), int(round(dst_pos.y - pivot_full.y)))
		return
	# only the part's drawn pixels are turned: crop to them first (cached)
	var used := src_full.get_used_rect()
	if used.size.x == 0 or used.size.y == 0:
		return
	var ckey := src_full.get_instance_id()
	if not _crops.has(ckey):
		_crops[ckey] = src_full.get_region(used.grow(1).intersection(Rect2i(Vector2i.ZERO, src_full.get_size())))
	var src: Image = _crops[ckey]
	var src_pivot := pivot_full - Vector2(used.grow(1).intersection(Rect2i(Vector2i.ZERO, src_full.get_size())).position)
	var c := cos(ang)
	var s := sin(ang)
	var sw := src.get_width()
	var sh := src.get_height()
	var mn := Vector2(1e9, 1e9)
	var mx := Vector2(-1e9, -1e9)
	for q: Vector2 in [Vector2(0, 0), Vector2(sw, 0), Vector2(0, sh), Vector2(sw, sh)]:
		var d: Vector2 = q - src_pivot
		var t := dst_pos + Vector2(d.x * c - d.y * s, d.x * s + d.y * c)
		mn = Vector2(minf(mn.x, t.x), minf(mn.y, t.y))
		mx = Vector2(maxf(mx.x, t.x), maxf(mx.y, t.y))
	var x0 := maxi(0, int(floor(mn.x)))
	var x1 := mini(dst.get_width() - 1, int(ceil(mx.x)))
	var y0 := maxi(0, int(floor(mn.y)))
	var y1 := mini(dst.get_height() - 1, int(ceil(mx.y)))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var dx := x + 0.5 - dst_pos.x
			var dy := y + 0.5 - dst_pos.y
			var sx := src_pivot.x + dx * c + dy * s - 0.5
			var sy := src_pivot.y - dx * s + dy * c - 0.5
			if sx < -1 or sy < -1 or sx > sw or sy > sh:
				continue
			var ix := int(floor(sx))
			var iy := int(floor(sy))
			var fx := sx - ix
			var fy := sy - iy
			var acc := Color(0, 0, 0, 0)
			for k in 4:
				var px := ix + (k & 1)
				var py := iy + (k >> 1)
				if px < 0 or py < 0 or px >= sw or py >= sh:
					continue
				var wgt := (fx if (k & 1) else 1.0 - fx) * (fy if (k >> 1) else 1.0 - fy)
				var p := src.get_pixel(px, py)
				acc.r += p.r * p.a * wgt
				acc.g += p.g * p.a * wgt
				acc.b += p.b * p.a * wgt
				acc.a += p.a * wgt
			if acc.a <= 0.002:
				continue
			var col := Color(acc.r / acc.a, acc.g / acc.a, acc.b / acc.a, acc.a)
			dst.set_pixel(x, y, dst.get_pixel(x, y).blend(col))


# ---------------------------------------------------------------- the in-game scene

# Everything together at its real in-game size (1 world px = 1 px, so a 128
# unit frame is 64 px and a tile 32 px) on a strip of floor, then doubled.
func scene_section() -> Image:
	var w := 720
	var h := 150
	var ground := 128
	var sc := canvas(w, h)
	var floor_col := Color("2a2236")
	sc.fill_rect(Rect2i(0, ground, w, h - ground), floor_col)
	for x in range(0, w, 32):
		sc.fill_rect(Rect2i(x, ground, 1, h - ground), Color("1d1526"))
	sc.fill_rect(Rect2i(0, ground, w, 1), Color("54496a"))
	var ch := func(rel: String, x: int) -> void:
		# a character frame: its ground line (122 of 128) on the floor
		paste(sc, rast(rel, 0.25), x, ground - 61)
	var wick_img := rig({"sword": 90}, "head", 0.5, 176, 136, 16, 4, Color(0, 0, 0, 0))
	paste(sc, wick_img, 20 - 8, ground - int(126 * 0.5))
	ch.call("art/enemies/skel_walk1.svg", 120)
	ch.call("art/enemies/thorn_walk1.svg", 190)
	paste(sc, rast("art/enemies/bat_up.svg", 0.25), 260, ground - 96)
	ch.call("art/enemies/skel_bones.svg", 320)
	# a row of blocks in the air, pickups, a sconce on the wall
	for i in 3:
		var names := ["art/props/reliquary.svg", "art/props/reliquary_gold.svg", "art/props/reliquary_spent.svg"]
		paste(sc, rast(names[i], 0.25), 400 + i * 32, ground - 96)
	paste(sc, rast("art/props/wax.svg", 0.25), 400, ground - 32)
	paste(sc, rast("art/props/sigil.svg", 0.25), 436, ground - 36)
	paste(sc, rast("art/props/sconce.svg", 0.25), 480, ground - 70)
	paste(sc, rast("art/props/altar_lit.svg", 0.25), 520, ground - 48)
	paste(sc, rast("art/props/altar.svg", 0.25), 556, ground - 48)
	paste(sc, rast("art/props/bell_beam.svg", 0.25), 600, ground - 96)
	paste(sc, rast("art/props/bell.svg", 0.25), 600, ground - 96)
	# the five Callings among the monsters, loot dropped at their feet
	var sc2 := canvas(w, h)
	sc2.fill_rect(Rect2i(0, ground, w, h - ground), floor_col)
	for x in range(0, w, 32):
		sc2.fill_rect(Rect2i(x, ground, 1, h - ground), Color("1d1526"))
	sc2.fill_rect(Rect2i(0, ground, w, 1), Color("54496a"))
	for i in CALLINGS.size():
		var cls: String = CALLINGS[i]
		var rest := deg_to_rad(float(rig_data(cls).get("weapon_rest_deg", 80)))
		var hr := hero_rig(cls, {"weapon": rest}, 0.5, 150.0, 170.0, 11.0, 42.0, Color(0, 0, 0, 0), {"flame": true})
		paste(sc2, hr, 12 + i * 112, ground - int(164 * 0.5))
		var loot := ["art/items/weapon_%s_2.svg" % cls, "art/items/candle_%d.svg" % (i % 3 + 1)]
		paste(sc2, rast(loot[0], 0.25), 12 + i * 112 + 70, ground - 32)
	paste(sc2, rast("art/enemies/skel_walk1.svg", 0.25), 580, ground - 61)
	paste(sc2, rast("art/props/reliquary.svg", 0.25), 660, ground - 96)
	var img := canvas(PAD * 2 + w * 3 + 8, PAD * 3 + h * 4, Color("120c18"))
	paste(img, sc, PAD, PAD)
	var big := sc.duplicate()
	big.resize(w * 2, h * 2, Image.INTERPOLATE_NEAREST)
	paste(img, big, PAD + w + 8, PAD)
	paste(img, sc2, PAD, PAD * 2 + h * 2)
	var big2 := sc2.duplicate()
	big2.resize(w * 2, h * 2, Image.INTERPOLATE_NEAREST)
	paste(img, big2, PAD + w + 8, PAD * 2 + h * 2)
	return img


# ---------------------------------------------------------------- Wick

# Assembles the rig into a w x h frame-unit canvas at k px per unit, the 128
# frame's origin at (ox, oy) frame units. pose: part -> angle in degrees;
# "sword" is placed with its grip on the front hand (after the arm's turn).
func rig(pose: Dictionary, head: String, k: float, w: float, h: float, ox: float, oy: float, bg: Color = BG) -> Image:
	var img := canvas(int(w * k), int(h * k), bg)
	var scale := k / 2.0    # the SVGs are 2 px per unit at scale 1
	var origin := Vector2(ox, oy)
	for part in ORDER:
		var file: String = head if part == "head" else part
		var src := rast("art/wick/%s.svg" % file, scale)
		var ang := deg_to_rad(float(pose.get(part, 0.0)))
		var piv: Vector2 = PIVOTS[part]
		var at: Vector2 = piv
		if part == "candle":
			# the candle rides on the head
			var ha := deg_to_rad(float(pose.get("head", 0.0)))
			at = PIVOTS["head"] + (piv - PIVOTS["head"]).rotated(ha)
			ang += ha
		elif part == "sword":
			var aa := deg_to_rad(float(pose.get("arm_front", 0.0)))
			at = PIVOTS["arm_front"] + (HAND_FRONT - PIVOTS["arm_front"]).rotated(aa)
			ang += aa
		blend_xf(img, src, piv * k, (at + origin) * k, ang)
	if pose.get("flame_mark", false):
		var ha2 := deg_to_rad(float(pose.get("head", 0.0)))
		var fb: Vector2 = PIVOTS["head"] + (FLAME_BASE - PIVOTS["head"]).rotated(ha2)
		cross(img, (fb + origin) * k, Color(1, 0.8, 0.1), 5)
	return img


func wick_section() -> Image:
	var k := 2.0
	var cw := 176.0    # frame units per composite cell (wider than 128 for the sword)
	var chh := 136.0
	var ox := 16.0
	var oy := 4.0
	var poses := [
		{"sword": 90, "flame_mark": true},                     # rest, sword held forward
		{},                                                    # the raw rest pose (sword straight up in the hand)
		{"leg_front": 28, "leg_back": -26, "arm_front": -24, "arm_back": 26, "body": 3, "head": 4, "cape": 12, "sword": 80},
		{"leg_front": -22, "leg_back": 24, "arm_front": 30, "arm_back": -22, "body": -2, "head": -3, "cape": 20, "sword": 70},
		{"arm_front": -150, "sword": 40, "head": -4, "body": -4, "arm_back": 30, "cape": 16},   # wind up
		{"arm_front": -60, "sword": 30, "head": 5, "body": 6, "arm_back": -20, "leg_front": 14, "leg_back": -10},  # swing
	]
	var heads_pose := {"sword": 90}
	var row1 := []
	for p in poses:
		row1.append(rig(p, "head_fierce" if p.has("arm_front") and absf(float(p["arm_front"])) > 50 else "head", k, cw, chh, ox, oy))
	var row2 := []
	for hname in HEADS:
		row2.append(rig(heads_pose, hname, k, cw, chh, ox, oy))
	var lit := rig(heads_pose, "head", k, cw, chh, ox, oy, LIT)
	row2.append(lit)
	var cell_w := int(cw * k)
	var cell_h := int(chh * k)
	var cols := 6
	var small_w := int(cw * 0.5)
	var small_h := int(chh * 0.5)
	var img := canvas(PAD + cols * (cell_w + PAD), PAD + 2 * (cell_h + PAD) + 2 * (small_h * 2 + PAD) + PAD, Color("120c18"))
	var y := PAD
	for row in [row1, row2]:
		for i in row.size():
			paste(img, row[i], PAD + i * (cell_w + PAD), y)
		y += cell_h + PAD
	# in-game size (64 px for the 128 frame), and the same pixels doubled
	for row in [row1, row2]:
		var x := PAD
		for i in row.size():
			var s := small(row[i], small_w, small_h)
			paste(img, s, x, y + small_h / 2)
			paste(img, zoom(s, 2), x + small_w + 8, y)
			x += small_w * 3 + 24
		y += small_h * 2 + PAD
	return img


func parts_section() -> Image:
	var files := list_svgs("art/wick")
	var cell := 256
	var cols := 7
	var rows := int(ceil(files.size() / float(cols)))
	var img := canvas(PAD + cols * (cell + PAD), PAD + rows * (cell + PAD), Color("120c18"))
	for i in files.size():
		var f: String = files[i]
		var name := f.get_file().get_basename()
		var piv: Vector2 = PIVOTS.get(name, PIVOTS["head"] if name.begins_with("head") else Vector2(-100, -100))
		var c := canvas(cell, cell)
		# the frame's edge and the ground line
		for x in cell:
			c.set_pixel(x, 244, Color(0.35, 0.3, 0.45))
		paste(c, rast(f, 1.0), 0, 0)
		cross(c, piv * 2.0)
		if name == "arm_front":
			cross(c, HAND_FRONT * 2.0, Color(0.2, 1, 0.4), 5)
		if name == "candle":
			cross(c, FLAME_BASE * 2.0, Color(1, 0.8, 0.1), 5)
		paste(img, c, PAD + (i % cols) * (cell + PAD), PAD + (i / cols) * (cell + PAD))
	return img


# ---------------------------------------------------------------- enemies, props, items

func grid(files: PackedStringArray, big: float, small_px: int, cols: int, frame_px: Vector2i, bg: Color = BG) -> Image:
	# big: raster scale for the large view; small_px: the in-game width of one frame
	var cw := int(frame_px.x * big)
	var ch := int(frame_px.y * big)
	var rows := int(ceil(files.size() / float(cols)))
	var sw := small_px
	var sh := int(round(small_px * frame_px.y / float(frame_px.x)))
	var img := canvas(PAD + cols * (cw + PAD), PAD + rows * (ch + PAD) + rows * (sh * 2 + PAD) + PAD, Color("120c18"))
	for i in files.size():
		var c := canvas(cw, ch, bg)
		paste(c, rast(files[i], big), 0, 0)
		paste(img, c, PAD + (i % cols) * (cw + PAD), PAD + (i / cols) * (ch + PAD))
	var y0 := PAD + rows * (ch + PAD)
	for i in files.size():
		var c := canvas(sw, sh, bg)
		paste(c, small(rast(files[i], big), sw, sh), 0, 0)
		var x := PAD + (i % cols) * (cw + PAD)
		var y := y0 + (i / cols) * (sh * 2 + PAD)
		paste(img, c, x, y + sh / 2)
		paste(img, zoom(c, 2), x + sw + 8, y)
	return img


func enemy_section() -> Image:
	var files := PackedStringArray()
	for f in list_svgs("art/enemies"):
		if not f.get_file().begins_with("boss_"):
			files.append(f)
	return grid(files, 1.0, 64, 6, Vector2i(256, 256))


const TOWER := Color("0e1020")
const BOSS_FRAMES := ["idle", "windup", "slam", "stuck", "hurt"]


func boss_section() -> Image:
	var cell := 384     # 256 frame units at 1.5 px each
	var n := BOSS_FRAMES.size()
	var img := canvas(PAD + n * (cell + PAD), PAD + 2 * (cell + PAD) + 2 * (256 + PAD) + 200, Color("120c18"))
	for i in n:
		var rel := "art/enemies/boss_%s.svg" % BOSS_FRAMES[i]
		if not FileAccess.file_exists("res://" + rel):
			continue
		var big := rast(rel, 0.75)
		for row in 2:
			var c := canvas(cell, cell, TOWER if row == 0 else BG)
			paste(c, big, 0, 0)
			if row == 1:
				# the collision box (116 x 156 on x 128, standing on 244) and the ground line
				var k := 1.5
				var r := Rect2i(int(70 * k), int(88 * k), int(116 * k), int(156 * k))
				for x in range(r.position.x, r.end.x):
					c.set_pixel(x, r.position.y, Color(0.3, 1, 0.5, 0.8))
					c.set_pixel(x, r.end.y - 1, Color(0.3, 1, 0.5, 0.8))
				for y in range(r.position.y, r.end.y):
					c.set_pixel(r.position.x, y, Color(0.3, 1, 0.5, 0.8))
					c.set_pixel(r.end.x - 1, y, Color(0.3, 1, 0.5, 0.8))
				if BOSS_FRAMES[i] == "stuck":
					cross(c, Vector2(157, 147) * k, Color(1, 0.2, 0.2), 9)
			paste(img, c, PAD + i * (cell + PAD), PAD + row * (cell + PAD))
		# in-game size: 128 px on both backgrounds, and doubled
		var y0 := PAD + 2 * (cell + PAD)
		for row in 2:
			var s := canvas(128, 128, TOWER if row == 0 else BG)
			paste(s, small(rast(rel, 1.0), 128, 128), 0, 0)
			paste(img, s, PAD + i * (cell + PAD), y0 + row * (256 + PAD) + 64)
			paste(img, zoom(s, 2), PAD + i * (cell + PAD) + 128 + 4, y0 + row * (256 + PAD))
	# scale check: Wick beside the boss at in-game size on the tower floor
	var yb := PAD + 2 * (cell + PAD) + 2 * (256 + PAD)
	var strip := canvas(420, 170, TOWER)
	strip.fill_rect(Rect2i(0, 150, 420, 20), Color("1c2038"))
	var wick_img := rig({"sword": 90}, "head_fierce", 0.5, 176, 136, 16, 4, Color(0, 0, 0, 0))
	paste(strip, wick_img, 30, 150 - int(126 * 0.5))
	if FileAccess.file_exists("res://art/enemies/boss_idle.svg"):
		paste(strip, rast("art/enemies/boss_idle.svg", 0.25), 150, 150 - 122)
		paste(strip, rast("art/enemies/boss_stuck.svg", 0.25), 280, 150 - 122)
	paste(img, strip, PAD, yb)
	return img


func stack(imgs: Array) -> Image:
	var w := 0
	var h := 0
	for s in imgs:
		w = maxi(w, s.get_width())
		h += s.get_height()
	var img := canvas(w, h, Color("120c18"))
	var y := 0
	for s in imgs:
		paste(img, s, 0, y)
		y += s.get_height()
	return img


func props_section() -> Image:
	var tiles := PackedStringArray()
	var tall := PackedStringArray()
	var bell := PackedStringArray()
	for f in list_svgs("art/props"):
		var n := f.get_file()
		if n.begins_with("altar"):
			tall.append(f)
		elif n.begins_with("bell"):
			bell.append(f)
		else:
			tiles.append(f)
	var parts := [grid(tiles, 2.0, 32, 8, Vector2i(128, 128))]
	var row := Image.create_empty(1, 1, false, Image.FORMAT_RGBA8)
	var a := grid(tall, 2.0, 32, 2, Vector2i(128, 192))
	var b := grid(bell, 1.0, 64, 2, Vector2i(256, 384))
	# the bell composed on its beam (both share the frame)
	var comp := canvas(256, 384)
	for f in ["art/props/bell_beam.svg", "art/props/bell.svg"]:
		if FileAccess.file_exists("res://" + f):
			paste(comp, rast(f, 1.0), 0, 0)
	cross(comp, Vector2(64, 20) * 2.0)
	var swing := canvas(256, 384)
	if FileAccess.file_exists("res://art/props/bell.svg"):
		paste(swing, rast("art/props/bell_beam.svg", 1.0), 0, 0)
		blend_xf(swing, rast("art/props/bell.svg", 1.0), Vector2(128, 40), Vector2(128, 40), deg_to_rad(12))
	var side := canvas(a.get_width() + b.get_width() + 2 * 256 + 4 * PAD, maxi(a.get_height(), b.get_height()), Color("120c18"))
	paste(side, a, 0, 0)
	paste(side, b, a.get_width(), 0)
	paste(side, comp, a.get_width() + b.get_width() + PAD, PAD)
	paste(side, swing, a.get_width() + b.get_width() + 2 * PAD + 256, PAD)
	parts.append(side)
	return stack(parts)


func items_section() -> Image:
	var relics := grid(list_svgs("art/relics"), 2.0, 32, 8, Vector2i(128, 128))
	var ui64 := PackedStringArray()
	var btns := PackedStringArray()
	for f in list_svgs("art/ui"):
		var n := f.get_file()
		if n.begins_with("btn_"):
			btns.append(f)
		elif n != "logo.svg":
			ui64.append(f)
	var hud := grid(ui64, 2.0, 24, 8, Vector2i(128, 128))
	var buttons := grid(btns, 1.0, 64, 4, Vector2i(256, 256), Color("2a2238"))
	var logo_img := canvas(10, 10)
	if FileAccess.file_exists("res://art/ui/logo.svg"):
		var l := rast("art/ui/logo.svg", 1.0)
		logo_img = canvas(l.get_width() + 2 * PAD + 260 + PAD, l.get_height() + 2 * PAD)
		paste(logo_img, l, PAD, PAD)
		paste(logo_img, small(l, 256, int(256 * l.get_height() / float(l.get_width()))), l.get_width() + 2 * PAD, PAD)
	var icon_img := canvas(10, 10)
	if FileAccess.file_exists("res://icon.svg"):
		var ic := rast("icon.svg", 0.5)
		icon_img = canvas(512 + 3 * PAD + 120 + 60 + PAD, 512 + 2 * PAD, Color("120c18"))
		paste(icon_img, ic, PAD, PAD)
		paste(icon_img, small(ic, 120, 120), 512 + 2 * PAD, PAD)
		paste(icon_img, small(ic, 60, 60), 512 + 3 * PAD + 120, PAD)
	return stack([relics, hud, buttons, logo_img, icon_img])


# ---------------------------------------------------------------- the Callings

const CALLINGS := ["knight", "witch", "runner", "founder", "sexton"]
const TOWER_BLUE := Color("0e1020")
const FRAME_FEET := Vector2(64, 122)
const HAND_BACK := Vector2(52, 101)
const HAND := Vector2(76, 101)
# mirrored from scripts/wick_rig.gd PIVOTS (test_art checks they agree)
const RIG_PIVOTS := {
	"cape": Vector2(58, 84), "leg_back": Vector2(60, 104), "arm_back": Vector2(54, 86),
	"body": Vector2(64, 108), "leg_front": Vector2(68, 104), "head": Vector2(64, 84),
	"candle": Vector2(60, 34), "arm_front": Vector2(74, 86), "weapon": Vector2(64, 96), "offhand": Vector2(52, 101),
}


func rig_data(cls: String) -> Dictionary:
	var p := "res://art/heroes/%s/rig.json" % cls
	if not FileAccess.file_exists(p):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(p))
	return d if d is Dictionary else {}


# The rig's own poses (wick_rig.gd _process), in radians; missing keys rest.
# The cape angles are the ones asked of wick_rig.gd: positive swings the
# cape's hem back, behind the hero (a flare), negative tucks it behind the
# body where it can't be seen.
func pose_of(name: String, rest: float) -> Dictionary:
	match name:
		"run_a":
			return {"leg_b": 0.75, "leg_f": -0.75, "arm_b": -0.6, "arm_f": 0.2, "bob": -2.2, "lean": 0.07, "head": -0.03, "cape": 0.35, "weapon": rest}
		"run_b":
			return {"leg_b": -0.75, "leg_f": 0.75, "arm_b": 0.6, "arm_f": -0.5, "bob": -2.2, "lean": 0.07, "head": -0.03, "cape": 0.35, "weapon": rest}
		"jump":
			return {"leg_b": 0.55, "leg_f": -0.7, "arm_b": -2.0, "arm_f": -0.9, "cape": 0.5, "weapon": rest, "head": -0.05}
		"fall":
			return {"leg_b": 0.25, "leg_f": -0.2, "arm_b": -2.5, "arm_f": -1.4, "cape": 0.8, "weapon": rest, "head": 0.06}
		"windup":
			return {"arm_f": -2.8, "weapon": 2.2, "lean": 0.08, "face": "head_fierce"}
		"swing":
			return {"arm_f": -0.61, "weapon": 2.2, "lean": 0.08, "face": "head_fierce"}
		"follow":
			return {"arm_f": -0.3, "weapon": 2.2, "lean": 0.08, "face": "head_fierce"}
		"hurt":
			return {"lean": -0.25, "arm_b": -1.8, "arm_f": -1.2, "face": "head_hurt", "weapon": rest}
		"guard":
			return {"arm_b": -1.35, "weapon": rest, "face": "head_fierce"}
	return {"weapon": rest}


func tear_svg(h: float, r: float) -> String:
	# the Glow layer's flame: three teardrops, base at (r+2, h+2)
	var w := r * 2.0 + 4.0
	var hh := h + 4.0
	var bx := r + 2.0
	var by := h + 2.0
	var body := ""
	for layer in [[1.0, 1.0, 0.0, "e8742a"], [0.72, 0.78, 0.1, "ffd98a"], [0.42, 0.5, 0.2, "fff2c8"]]:
		var rr: float = r * float(layer[0])
		var th: float = h * float(layer[1])
		var y0: float = by - r * float(layer[2])
		body += "<path d=\"M%.2f %.2f A%.2f %.2f 0 0 0 %.2f %.2f Q%.2f %.2f %.2f %.2f Q%.2f %.2f %.2f %.2f Z\" fill=\"#%s\"/>" % [
			bx - rr, y0 - rr, rr, rr, bx + rr, y0 - rr, bx + rr * 0.95, y0 - th * 0.55, bx, y0 - th, bx - rr * 0.95, y0 - th * 0.55, bx - rr, y0 - rr, layer[3]]
	return "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"%d\" height=\"%d\" viewBox=\"0 0 %.2f %.2f\">%s</svg>" % [int(ceil(w * 2)), int(ceil(hh * 2)), w, hh, body]


func flame_img(h: float, r: float, k: float) -> Image:
	var img := Image.new()
	img.load_svg_from_string(tear_svg(h, r), k / 2.0)
	img.convert(Image.FORMAT_RGBA8)
	return img


# Assembles a Calling at k px per frame unit on a w x h (frame units) canvas,
# the frame's origin at (ox, oy), the joints nested and turned exactly as
# wick_rig.gd does. opts: flame (draw it at flame_tip), candle_scale (the
# candle tier, scaled about rig.json candle_base), fixed_shield (the current
# rig: offhand_front stays put instead of following the back hand).
func hero_rig(cls: String, pose: Dictionary, k: float, w: float, h: float, ox: float, oy: float, bg: Color, opts := {}) -> Image:
	var img := canvas(int(w * k), int(h * k), bg)
	var dir := "art/heroes/%s/" % cls
	var rd := rig_data(cls)
	var sc := k / 2.0
	var P := RIG_PIVOTS
	var bob: float = float(pose.get("bob", 0.0)) * 2.0     # world px -> frame units
	var lean: float = float(pose.get("lean", 0.0))
	var root := Transform2D(0.0, Vector2(ox, oy) + FRAME_FEET)
	var sway := func(part: String) -> Vector2:
		return Vector2(0, bob) + Vector2(lean * 20.0, 0) * (1.0 if part == "head" else 0.5)
	var T := {}
	T["cape"] = root * Transform2D(float(pose.get("cape", 0.0)), P["cape"] - FRAME_FEET + sway.call("cape"))
	T["leg_back"] = root * Transform2D(float(pose.get("leg_b", 0.0)), P["leg_back"] - FRAME_FEET)
	T["arm_back"] = root * Transform2D(float(pose.get("arm_b", 0.0)), P["arm_back"] - FRAME_FEET + sway.call("arm_back"))
	T["offhand"] = T["arm_back"] * Transform2D(float(pose.get("offhand", 0.0)), HAND_BACK - P["arm_back"])
	if rd.get("offhand_front", false) and opts.get("fixed_shield", false):
		T["offhand"] = root * Transform2D(float(pose.get("offhand", 0.0)), HAND_BACK - FRAME_FEET)
	T["body"] = root * Transform2D(lean, P["body"] - FRAME_FEET + sway.call("body"))
	T["leg_front"] = root * Transform2D(float(pose.get("leg_f", 0.0)), P["leg_front"] - FRAME_FEET)
	T["head"] = root * Transform2D(float(pose.get("head", 0.0)), P["head"] - FRAME_FEET + sway.call("head"))
	T["candle"] = T["head"] * Transform2D(0.0, P["candle"] - P["head"])
	T["arm_front"] = root * Transform2D(float(pose.get("arm_f", 0.0)), P["arm_front"] - FRAME_FEET + sway.call("arm_front"))
	T["weapon"] = T["arm_front"] * Transform2D(float(pose.get("weapon", deg_to_rad(float(rd.get("weapon_rest_deg", 80))))), HAND - P["arm_front"])
	var order := ["cape", "leg_back", "arm_back"]
	var off_front: bool = rd.get("offhand_front", false)
	if rd.get("offhand", false) and not off_front:
		order.append("offhand")
	order.append_array(["body", "leg_front", "head", "candle", "weapon", "arm_front"])
	if rd.get("offhand", false) and off_front:
		order.append("offhand")
	var cs: float = float(opts.get("candle_scale", 1.0))
	var cb := Vector2(rd.get("candle_base", [60, 34])[0], rd.get("candle_base", [60, 34])[1])
	for part in order:
		var file: String = str(pose.get("face", "head")) if part == "head" else part
		var path := dir + file + ".svg"
		if not FileAccess.file_exists("res://" + path):
			continue
		var t: Transform2D = T[part]
		if part == "candle" and absf(cs - 1.0) > 0.001:
			# scaled about its base: rasterize bigger or smaller, pin the base
			var src := rast(path, sc * cs)
			var at: Vector2 = t * (cb - P["candle"])
			blend_xf(img, src, cb * k * cs, at * k, t.get_rotation())
			continue
		blend_xf(img, rast(path, sc), P[part] * k, t.origin * k, t.get_rotation())
	if opts.get("flame", false) and rd.has("flame_tip"):
		var tip := Vector2(rd["flame_tip"][0], rd["flame_tip"][1])
		tip = cb + (tip - cb) * cs
		var at2: Vector2 = T["candle"] * (tip - P["candle"])
		var fh := 38.0 * float(rd.get("flame_scale", 1.0))
		var fr := fh * 0.32
		var fl := flame_img(fh, fr, k)
		paste(img, fl, int(round(at2.x * k - (fr + 2.0) * k)), int(round(at2.y * k - (fh + 2.0) * k)))
	return img


func heroes_section() -> Image:
	var k := 1.5
	var cw := 180.0
	var chh := 150.0
	var ox := 26.0
	var oy := 22.0
	var names := ["rest", "run_a", "run_b", "jump", "fall", "windup", "swing", "follow", "hurt", "guard"]
	var cell_w := int(cw * k)
	var cell_h := int(chh * k)
	var rows := []
	for cls in CALLINGS:
		var rd := rig_data(cls)
		var rest := deg_to_rad(float(rd.get("weapon_rest_deg", 80)))
		var row := canvas(PAD + names.size() * (cell_w + PAD), cell_h + PAD + 120 + PAD, Color("120c18"))
		for i in names.size():
			var n: String = names[i]
			var pose := pose_of(n, rest)
			var c := hero_rig(cls, pose, k, cw, chh, ox, oy, BG, {"flame": n == "rest"})
			paste(row, c, PAD + i * (cell_w + PAD), 0)
		# faces, then the rest pose at in-game size on both backgrounds
		var x := PAD
		for f in ["head", "head_blink", "head_hurt", "head_happy", "head_fierce"]:
			var fimg := hero_rig(cls, {"weapon": rest, "face": f}, 0.75, cw, chh, ox, oy, BG)
			paste(row, fimg, x, cell_h + PAD)
			x += fimg.get_width() + 4
		for bgc in [BG, TOWER_BLUE]:
			for n2 in ["rest", "run_a", "windup", "swing"]:
				var small_img := hero_rig(cls, pose_of(n2, rest), 0.5, cw, chh, ox, oy, bgc, {"flame": n2 == "rest"})
				paste(row, small_img, x + 8, cell_h + PAD + 20)
				x += small_img.get_width() + 2
			x += 10
		rows.append(row)
	return stack(rows)


func lineup_section() -> Image:
	var cw := 150.0
	var chh := 160.0
	var ox := 11.0
	var oy := 32.0
	var strips := []
	for bgc in [BG, TOWER_BLUE]:
		for k in [0.5, 1.5]:
			var row := canvas(PAD + CALLINGS.size() * (int(cw * k) + PAD), int(chh * k) + 2 * PAD, bgc)
			for i in CALLINGS.size():
				var cls: String = CALLINGS[i]
				var rest := deg_to_rad(float(rig_data(cls).get("weapon_rest_deg", 80)))
				var img := hero_rig(cls, {"weapon": rest}, k, cw, chh, ox, oy, bgc, {"flame": true})
				paste(row, img, PAD + i * (int(cw * k) + PAD), PAD)
			strips.append(row)
	# each candle tier (x0.85 / 1 / 1.15 about candle_base) at 2 px per unit
	var tiers := canvas(PAD + CALLINGS.size() * 3 * (int(100 * 1.0) + 4) + CALLINGS.size() * PAD, 110 + 2 * PAD, BG)
	var x := PAD
	for cls in CALLINGS:
		var rest2 := deg_to_rad(float(rig_data(cls).get("weapon_rest_deg", 80)))
		for s in [0.85, 1.0, 1.15]:
			var img2 := hero_rig(cls, {"weapon": rest2}, 1.0, 100.0, 110.0, -14.0, 40.0, BG, {"flame": true, "candle_scale": s})
			paste(tiers, img2, x, PAD)
			x += 104
		x += PAD
	strips.append(tiers)
	return stack(strips)


func hparts_section() -> Image:
	var rows := []
	var cell := 192
	for cls in CALLINGS:
		var files := PackedStringArray()
		for f in list_svgs("art/heroes/" + cls):
			if not f.get_file().begins_with("portrait_"):
				files.append(f)
		var rd := rig_data(cls)
		var row := canvas(PAD + files.size() * (cell + 4), cell + 2 * PAD, Color("120c18"))
		for i in files.size():
			var f: String = files[i]
			var name := f.get_file().get_basename()
			var c := canvas(cell, cell)
			for xx in cell:
				c.set_pixel(xx, int(122 * 1.5), Color(0.35, 0.3, 0.45))
			paste(c, rast(f, 0.75), 0, 0)
			var piv: Vector2 = RIG_PIVOTS.get(name, RIG_PIVOTS["head"] if name.begins_with("head") else Vector2(-100, -100))
			cross(c, piv * 1.5, Color(1, 0.15, 0.15), 5)
			if name == "arm_front":
				cross(c, HAND * 1.5, Color(0.2, 1, 0.4), 4)
			if name == "arm_back":
				cross(c, HAND_BACK * 1.5, Color(0.2, 1, 0.4), 4)
			if name == "weapon" and rd.has("weapon_tip"):
				cross(c, Vector2(rd["weapon_tip"][0], rd["weapon_tip"][1]) * 1.5, Color(1, 0.3, 1), 4)
			if name == "candle" and rd.has("flame_tip"):
				cross(c, Vector2(rd["flame_tip"][0], rd["flame_tip"][1]) * 1.5, Color(1, 0.8, 0.1), 4)
				var cb = rd.get("candle_base", [60, 34])
				cross(c, Vector2(cb[0], cb[1]) * 1.5, Color(0.3, 0.8, 1), 4)
			paste(row, c, PAD + i * (cell + 4), PAD)
		rows.append(row)
	return stack(rows)


func portraits_section() -> Image:
	var rows := []
	var sz := 160
	for cls in CALLINGS:
		var rd := rig_data(cls)
		# headroom over the pictures: the live flame burns up out of them, over
		# the ring, as it does in the dialogue box
		var head := 44
		var row := canvas(PAD + 4 * (sz + PAD) + 4 * (100 + PAD) + 4 * 48, sz + 2 * PAD + head, Color("120c18"))
		var x := PAD
		for mood in ["normal", "happy", "fierce", "hurt"]:
			var p := "art/heroes/%s/portrait_%s.svg" % [cls, mood]
			if not FileAccess.file_exists("res://" + p):
				continue
			var src := rast(p, 1.0)
			var sq := canvas(sz, sz, Color("2a2238"))
			paste(sq, small(src, sz, sz), 0, 0)
			paste(row, sq, x, PAD + head)
			if rd.has("portrait_flame"):
				# where the dialogue burns it: portrait_flame is [x, y, h] in crop units
				var pf = rd["portrait_flame"]
				var vw := float(rd["portrait_viewbox"][2])
				var fh := float(pf[2]) / vw * sz
				var fl := flame_img(fh, fh * 0.32, 1.0)
				paste(row, fl, x + int(float(pf[0]) / vw * sz - (fh * 0.32 + 2.0)), PAD + head + int(float(pf[1]) / vw * sz - (fh + 2.0)))
			x += sz + PAD
		# in the dialogue box's circle (r 46 -> 92 px) and the bark's (r 20)
		for r in [46, 20]:
			var p2 := "art/heroes/%s/portrait_normal.svg" % cls
			if not FileAccess.file_exists("res://" + p2):
				continue
			var d: int = r * 2
			var src2 := small(rast(p2, 1.0), d, d)
			var circ := canvas(d + 8, d + 8, Color("241c30"))
			for yy in d:
				for xx in d:
					var q := Vector2(xx + 0.5 - r, yy + 0.5 - r)
					if q.length() <= r:
						var col := Color("2a2238").blend(src2.get_pixel(xx, yy))
						circ.set_pixel(xx + 4, yy + 4, col)
					elif q.length() <= r + 3:
						circ.set_pixel(xx + 4, yy + 4, Color("7aa8ff"))
			paste(row, circ, x, PAD + head)
			if rd.has("portrait_flame"):
				# c + (pf.xy / w - 0.5) * 2r, h * 2r / w: the dialogue's own sums
				var pf2 = rd["portrait_flame"]
				var vw2 := float(rd["portrait_viewbox"][2])
				var fh2 := float(pf2[2]) * d / vw2
				var fl2 := flame_img(fh2, fh2 * 0.32, 1.0)
				paste(row, fl2, x + int(4 + float(pf2[0]) / vw2 * d - (fh2 * 0.32 + 2.0)), PAD + head + int(4 + float(pf2[1]) / vw2 * d - (fh2 + 2.0)))
			x += d + 8 + PAD
		rows.append(row)
	return stack(rows)


func loot_section() -> Image:
	var files := list_svgs("art/items")
	var rows := []
	for bgc in [BG, TOWER_BLUE]:
		for px in [96, 48, 32, 26]:
			var cols := 15
			var n := files.size()
			var nrows := int(ceil(n / float(cols)))
			var img := canvas(PAD + cols * (px + 8), PAD + nrows * (px + 8), bgc)
			for i in n:
				var src := rast(files[i], 1.0)
				paste(img, small(src, px, px), PAD + (i % cols) * (px + 8), PAD + (i / cols) * (px + 8))
			rows.append(img)
	return stack(rows)


func closeup_section() -> Image:
	var k := 3.0
	var cw := 120.0
	var chh := 150.0
	var ox := 2.0
	var oy := 26.0
	var rows := []
	for which in ["rest", "run_a"]:
		var row := canvas(CALLINGS.size() * int(cw * k), int(chh * k), BG)
		for i in CALLINGS.size():
			var cls: String = CALLINGS[i]
			var rest := deg_to_rad(float(rig_data(cls).get("weapon_rest_deg", 80)))
			paste(row, hero_rig(cls, pose_of(which, rest), k, cw, chh, ox, oy, BG if which == "rest" else TOWER_BLUE, {"flame": which == "rest"}), i * int(cw * k), 0)
		rows.append(row)
	return stack(rows)
