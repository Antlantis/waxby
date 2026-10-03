extends SceneTree
## W6b's checks on the new monster, boss and prop art (tools/art/enemies2.py,
## boss2.py and props.py's World 2 additions): every frame the contract names
## is there, is an SVG ThorVG can draw (no <text>, no filters) on the right
## frame, stands on the right line (or hangs from, or floats round, the right
## point), stays inside its frame, imports as a texture of the right size, and
## the engine points in the JSON files sit on the art they describe. The
## Snuffer's lunge is checked against the engine's lunge box (flat, clear of
## the floor, the cone's tip leading, the bell trailing), and the hanging
## Dripkin's sprite shift against its ceiling line.
##
##     godot --headless --path game --import      (after regenerating the art)
##     godot --headless --path game --script res://tests/test_monster_art.gd

const MONSTERS := {
	"bonebow": ["idle", "draw", "loose", "hit", "bones"],
	"helm": ["walk1", "walk2", "block", "bash", "noshield", "hit"],
	"wing": ["fly1", "fly2", "latch", "pop"],
	"drip": ["hang", "drop", "splat", "crawl1", "crawl2"],
	"jaw": ["hide", "leap", "fall"],
	"lurk": ["open", "hop", "hit"],
}
const SNUFFER := ["idle", "raise", "slam", "stuck", "glide", "snuff", "lunge", "curdled", "die"]
const TALL_PROPS := ["brazier_lit", "brazier_out", "lantern_post_lit", "lantern_post_out"]
const TILE_PROPS := ["drip_spout", "waxfall_head", "nest_sconce", "false_stone_crack"]
# frames that are meant to touch an edge of their frame: the ones hanging from
# the ceiling touch the top; the standing props stand on the bottom
const TOUCH_OK := {
	"art/enemies/drip_hang.svg": ["top"],
	"art/props/drip_spout.svg": ["top"],
	"art/props/waxfall_head.svg": ["top"],
	"art/props/brazier_lit.svg": ["bottom"], "art/props/brazier_out.svg": ["bottom"],
	"art/props/lantern_post_lit.svg": ["bottom"], "art/props/lantern_post_out.svg": ["bottom"],
}
const SOLID := 0.5      # alpha that counts as drawn (the soft shadows and smoke are fainter)

var _passed := 0
var _failed := 0


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", what)


func _initialize() -> void:
	_test_monsters()
	_test_snuffer()
	_test_props()
	_test_points()
	_test_style_matches_family()
	print("test_monster_art: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# ---------------------------------------------------------------- helpers

func _text(rel: String) -> String:
	return FileAccess.get_file_as_string("res://" + rel)


# viewBox width and height, and the pixel size, read back from the SVG's header
func _header(text: String) -> Dictionary:
	var re := RegEx.create_from_string('width="(\\d+)" height="(\\d+)" viewBox="0 0 (\\d+) (\\d+)"')
	var m := re.search(text)
	if m == null:
		return {}
	return {"w": int(m.get_string(1)), "h": int(m.get_string(2)), "vw": int(m.get_string(3)), "vh": int(m.get_string(4))}


# the art rasterized at 1 px per frame unit
func _raster(text: String) -> Image:
	var img := Image.new()
	if img.load_svg_from_string(text, 0.5) != OK:
		return null
	img.convert(Image.FORMAT_RGBA8)
	return img


# the box of the pixels drawn at least `solid` opaque, in frame units
func _bbox(img: Image, solid: float = SOLID) -> Rect2i:
	var x0 := img.get_width()
	var y0 := img.get_height()
	var x1 := -1
	var y1 := -1
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a >= solid:
				x0 = mini(x0, x)
				y0 = mini(y0, y)
				x1 = maxi(x1, x)
				y1 = maxi(y1, y)
	if x1 < 0:
		return Rect2i()
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1)


func _edges(img: Image) -> Array:
	var out := []
	var w := img.get_width()
	var h := img.get_height()
	for side in ["top", "bottom", "left", "right"]:
		var n := 0
		var count := w if side in ["top", "bottom"] else h
		for i in count:
			var p: Color
			match side:
				"top":
					p = img.get_pixel(i, 0)
				"bottom":
					p = img.get_pixel(i, h - 1)
				"left":
					p = img.get_pixel(0, i)
				_:
					p = img.get_pixel(w - 1, i)
			if p.a > 0.05:
				n += 1
		if n > 0:
			out.append(side)
	return out


# the shared checks: present, drawable, the right frame, inside it, imported
func _frame(rel: String, vw: int, vh: int) -> Image:
	var text := _text(rel)
	_check(text != "", "%s exists" % rel)
	if text == "":
		return null
	_check(not text.contains("<text") and not text.contains("<filter"), "%s has no <text> or <filter> (ThorVG draws neither)" % rel)
	var hd := _header(text)
	_check(hd.get("vw", 0) == vw and hd.get("vh", 0) == vh and hd.get("w", 0) == vw * 2 and hd.get("h", 0) == vh * 2,
		"%s is a %dx%d frame at 2 px per unit (got %s)" % [rel, vw, vh, hd])
	var img := _raster(text)
	_check(img != null, "%s rasterizes" % rel)
	if img == null:
		return null
	var bb := _bbox(img)
	_check(bb.size.x * bb.size.y > vw * vh / 40, "%s has real art in it (%s)" % [rel, bb])
	var touching := _edges(img)
	var allowed: Array = TOUCH_OK.get(rel, [])
	for side in touching:
		_check(side in allowed, "%s stays inside its frame (touches the %s)" % [rel, side])
	for side in allowed:
		_check(side in touching, "%s reaches its %s edge (it hangs or stands there)" % [rel, side])
	var path := "res://" + rel
	_check(ResourceLoader.exists(path), "%s is imported (run --import)" % rel)
	if ResourceLoader.exists(path):
		var tex = load(path)
		_check(tex is Texture2D and tex.get_width() == vw * 2 and tex.get_height() == vh * 2,
			"%s loads as a %dx%d texture" % [rel, vw * 2, vh * 2])
	return img


# ---------------------------------------------------------------- the monsters

func _test_monsters() -> void:
	for kind in MONSTERS:
		for fr in MONSTERS[kind]:
			var rel := "art/enemies/%s_%s.svg" % [kind, fr]
			var img := _frame(rel, 128, 128)
			if img == null:
				continue
			var bb := _bbox(img)
			var foot := bb.end.y
			if kind in ["wing", "jaw"]:
				# fliers and the fish are centred on (64, 64): their body is drawn there
				# (a latched moth's anchor is the flame it hugs, whose base is (64, 64))
				_check(_near_art(img, Vector2(64, 64), 3), "%s is centred on (64, 64) (box %s)" % [rel, bb])
				_check(bb.size.x < 108 and bb.size.y < 104, "%s fits a flier's frame (box %s)" % [rel, bb])
			elif kind == "drip" and fr == "hang":
				_check(bb.position.y == 0, "drip_hang comes down out of the ceiling (top %d)" % bb.position.y)
				_check(foot >= 44 and foot <= 56, "drip_hang hangs about 20 px under the ceiling at y 10 (bottom %d)" % foot)
			else:
				# feet on y 122: the fill ends there, its ink and sticker rim a few units below
				_check(foot >= 120 and foot <= 127, "%s stands on y 122 (lowest drawn row %d)" % [rel, foot])
			if kind == "lurk":
				# the mimic is the reliquary's size: about 60 units wide, not counting its tongue
				var body := _bbox(img.get_region(Rect2i(0, 102, 128, 10)))
				_check(absi(body.size.x - 66) <= 8, "%s is a reliquary's width (%d)" % [rel, body.size.x])


# ---------------------------------------------------------------- the Snuffer

func _test_snuffer() -> void:
	var idle_h := 0
	for fr in SNUFFER:
		var rel := "art/enemies/snuffer_%s.svg" % fr
		var img := _frame(rel, 384, 384)
		if img == null:
			continue
		var bb := _bbox(img)
		if fr != "lunge":
			_check(bb.end.y >= 364 and bb.end.y <= 378, "%s stands on y 368 (lowest drawn row %d)" % [rel, bb.end.y])
		if fr == "idle":
			# his body without the pole (the columns left of it) and without the faint smoke
			var body := _bbox(img.get_region(Rect2i(0, 0, 250, 384)), 0.97)
			idle_h = 368 - body.position.y
		if fr == "lunge":
			_test_lunge(img)
	# 2.2 x Waxby's height (about 100 units to his candle's wick) = 220, his knob's ink and rim on top
	_check(idle_h >= 214 and idle_h <= 240, "the Snuffer stands about 2.2 x Waxby (%d units from his feet to his knob)" % idle_h)


# The lunge is a 34-damage attack the player jumps: the drawing must be the
# box that hurts. Flat, lifted clear of the floor (he hovers 6 px up, so frame
# y 368 is 6 px above it), the cone's tip at the front, nothing solid below
# the box or ahead of it, and the bell trailing behind rather than leading.
func _test_lunge(img: Image) -> void:
	var snuf := _json("art/enemies/points_snuffer.json")
	var lb: Dictionary = snuf.get("_lunge_box", {})
	_check(lb.has("frame") and lb.has("up_from_floor"), "points_snuffer.json gives the lunge's body box")
	if not lb.has("frame"):
		return
	var f: Array = lb["frame"]
	var box := Rect2i(int(f[0]), int(f[1]), int(f[2]), int(f[3]))
	var up: Array = lb["up_from_floor"]
	_check(is_equal_approx(float(up[0]), (368.0 - box.end.y) / 2.0 + 6.0) and is_equal_approx(float(up[1]), (368.0 - box.position.y) / 2.0 + 6.0),
		"the lunge box's height band %s matches its frame box %s" % [up, box])
	_check(float(up[0]) >= 24.0 and float(up[1]) <= 90.0, "the lunge flies at head height, clear of the floor (%s px up)" % [up])
	var bb := _bbox(img)
	_check(bb.size.x >= bb.size.y * 2, "the lunge lies flat (%s)" % bb)
	# nothing solid under the box (the hem used to drag on the floor), and only the
	# thin air lines over the cone's back rise above it
	_check(bb.end.y <= box.end.y + 2, "nothing in the lunge hangs below its box (lowest row %d, box bottom %d)" % [bb.end.y, box.end.y])
	_check(bb.position.y >= box.position.y - 12, "nothing in the lunge rises far above its box (top %d)" % bb.position.y)
	var mid := _bbox(img.get_region(Rect2i(box.position.x + 8, 0, box.size.x - 16, 384)), 0.97)
	_check(mid.position.y >= box.position.y - 4 and mid.end.y <= box.end.y + 2, "the lunge's body fills its box's height (%s in %s)" % [mid, box])
	# the front: the drawing ends at the box's front edge, on the cone's tip
	_check(bb.end.x <= box.end.x + 2 and bb.end.x >= box.end.x - 10, "the lunge's front is its box's front (%d vs %d)" % [bb.end.x, box.end.x])
	var fr: Dictionary = snuf.get("snuffer_lunge", {})
	_check(fr.has("cone_tip") and fr.has("bell_mouth"), "snuffer_lunge says where its cone tip and bell are")
	if fr.has("cone_tip") and fr.has("bell_mouth"):
		var tip := Vector2(float(fr["cone_tip"][0]), float(fr["cone_tip"][1]))
		var bell := Vector2(float(fr["bell_mouth"][0]), float(fr["bell_mouth"][1]))
		_check(tip.x >= bb.end.x - 8, "the cone's tip leads the lunge (tip x %.0f, front %d)" % [tip.x, bb.end.x])
		_check(Rect2(box).grow(2).has_point(tip), "the cone's tip is inside the lunge box")
		_check(bell.x < box.position.x, "the bell trails behind the body (mouth x %.0f)" % bell.x)
		_check(bell.y > box.position.y and bell.y < box.end.y, "the trailing bell stays at the body's height (mouth y %.0f)" % bell.y)


# ---------------------------------------------------------------- the props

func _test_props() -> void:
	for p in TALL_PROPS:
		var img := _frame("art/props/%s.svg" % p, 64, 96)
		if img:
			var bb := _bbox(img)
			_check(absf(bb.get_center().x - 32) < 4, "%s stands centred on x 32 (%s)" % [p, bb])
	for p in TILE_PROPS:
		_frame("art/props/%s.svg" % p, 64, 64)
	# the crack overlay is light and mostly see-through
	var crack := _raster(_text("art/props/false_stone_crack.svg"))
	if crack:
		var drawn := 0
		var light := 0
		for y in crack.get_height():
			for x in crack.get_width():
				var c := crack.get_pixel(x, y)
				if c.a >= SOLID:
					drawn += 1
					if c.get_luminance() > 0.7:
						light += 1
		_check(drawn > 40 and drawn < 64 * 64 / 5, "false_stone_crack is a thin overlay (%d px drawn)" % drawn)
		_check(light > drawn * 0.6, "false_stone_crack is drawn in light cream (%d of %d px light)" % [light, drawn])
	# lit and out read differently: the lit one is warmer and brighter up top
	for pair in [["brazier_lit", "brazier_out"], ["lantern_post_lit", "lantern_post_out"]]:
		var a := _raster(_text("art/props/%s.svg" % pair[0]))
		var b := _raster(_text("art/props/%s.svg" % pair[1]))
		if a and b:
			_check(_warmth(a, 0, 50) > _warmth(b, 0, 50) + 0.05, "%s is warmer than %s" % pair)


func _warmth(img: Image, y0: int, y1: int) -> float:
	var sum := 0.0
	var n := 0
	for y in range(y0, y1):
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a >= SOLID:
				sum += c.r - c.b + c.get_luminance()
				n += 1
	return sum / maxf(1.0, float(n))


# ---------------------------------------------------------------- the engine points

func _json(rel: String) -> Dictionary:
	var text := _text(rel)
	_check(text != "", "%s exists" % rel)
	var d = JSON.parse_string(text) if text != "" else null
	_check(d is Dictionary, "%s parses" % rel)
	return d if d is Dictionary else {}


func _near_art(img: Image, p: Vector2, r: int) -> bool:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var q := Vector2i(int(p.x) + dx, int(p.y) + dy)
			if q.x >= 0 and q.y >= 0 and q.x < img.get_width() and q.y < img.get_height() and img.get_pixel(q.x, q.y).a > 0.3:
				return true
	return false


func _test_points() -> void:
	var mons := _json("art/enemies/points_monsters.json")
	var anchors: Dictionary = mons.get("_anchors", {})
	for kind in ["bonebow", "helm", "wing", "drip", "jaw", "lurk"]:
		_check(anchors.has(kind), "points_monsters.json names %s's anchor" % kind)
	# drip_hang keeps the feet anchor: the engine shifts the sprite down by
	# (122 - 10) / 2 = 56 px so frame y 10 lands on the ceiling line (enemy.gd
	# applies `anchor` only once, so a runtime anchor change would never show)
	_check(not anchors.has("drip_hang"), "drip_hang has no anchor of its own")
	var dh: Dictionary = mons.get("_drip_hang", {})
	_check(dh.has("ceiling") and dh.has("sprite_position_y"), "points_monsters.json says how to hang the Dripkin")
	if dh.has("ceiling") and dh.has("sprite_position_y") and anchors.has("drip"):
		var feet := float(anchors["drip"][1])
		var ceil_y := float(dh["ceiling"][1])
		_check(is_equal_approx(float(dh["sprite_position_y"]), (feet - ceil_y) / 2.0),
			"the hanging sprite shift %s puts frame y %s on the ceiling" % [dh["sprite_position_y"], ceil_y])
		_check(is_equal_approx(float(dh["sprite_position_y"]), 56.0), "the hanging sprite shift is 56 px")
		if mons.has("drip_hang") and mons["drip_hang"].has("ceiling"):
			_check(is_equal_approx(float(mons["drip_hang"]["ceiling"][1]), ceil_y), "drip_hang's ceiling point matches")
		# with the shift, the hanging drip's bulb sits right under the ceiling, inside
		# dripkin.gd's hanging rect (ceiling_y to ceiling_y + 20)
		var img := _raster(_text("art/enemies/drip_hang.svg"))
		if img:
			var bb := _bbox(img)
			var bottom_px := (bb.end.y - feet) / 2.0 + float(dh["sprite_position_y"])
			_check(bottom_px >= 16.0 and bottom_px <= 24.0, "the hanging drip ends %.1f px under the ceiling" % bottom_px)
	_check(mons.has("bonebow_draw") and mons["bonebow_draw"].has("arrow_tip"), "the Bonebow's draw frame says where its arrow tip is")
	_check(mons.has("wing_latch") and mons["wing_latch"].has("flame"), "the latched Gutterwing says where the flame it hugs is")
	_check(mons.has("jaw_hide") and mons["jaw_hide"].has("lure"), "the Brinejaw says where its lure light is")
	_check(mons.has("drip_hang") and mons["drip_hang"].has("ceiling"), "the hanging Dripkin says where the ceiling is")
	var snuf := _json("art/enemies/points_snuffer.json")
	for fr in SNUFFER:
		_check(snuf.has("snuffer_" + fr) and snuf["snuffer_" + fr].has("head"), "snuffer_%s says where his face is" % fr)
	_check(snuf.has("snuffer_slam") and snuf["snuffer_slam"].has("slam_centre"), "snuffer_slam says where the slam lands")
	var props := _json("art/props/points_world2.json")
	for p in ["brazier_lit", "brazier_out", "lantern_post_lit", "lantern_post_out", "nest_sconce"]:
		_check(props.has(p) and props[p].has("flame"), "%s has a flame point" % p)
	_check(props.has("drip_spout") and props["drip_spout"].has("drip"), "drip_spout has a drip point")
	_check(props.has("waxfall_head") and props["waxfall_head"].has("pour"), "waxfall_head has a pour point")
	# every point sits on (or right by) the art it names, inside its frame
	var files := {}
	for key in mons:
		if not key.begins_with("_"):
			files[key] = ["art/enemies/%s.svg" % key, mons[key]]
	for key in snuf:
		if not key.begins_with("_"):
			files[key] = ["art/enemies/%s.svg" % key, snuf[key]]
	for key in props:
		if not key.begins_with("_"):
			files[key] = ["art/props/%s.svg" % key, props[key]]
	for key in files:
		var img := _raster(_text(files[key][0]))
		if img == null:
			_check(false, "%s's points have art to sit on" % key)
			continue
		var pts: Dictionary = files[key][1]
		for name in pts:
			var v = pts[name]
			if not (v is Array and v.size() == 2):
				continue
			var p := Vector2(float(v[0]), float(v[1]))
			var inside := p.x >= 0 and p.y >= 0 and p.x <= img.get_width() and p.y <= img.get_height()
			_check(inside, "%s.%s %s is inside the frame" % [key, name, p])
			if inside and name != "ceiling" and name != "slam_centre" and name != "smoke":
				_check(_near_art(img, p, 6), "%s.%s %s sits on its art" % [key, name, p])
	# the brazier's flame point is on top of its coals: art right below it, clear air a flame's height above
	var bz := _raster(_text("art/props/brazier_lit.svg"))
	if bz and props.has("brazier_lit"):
		var fp: Array = props["brazier_lit"]["flame"]
		var p := Vector2(float(fp[0]), float(fp[1]))
		_check(_near_art(bz, p + Vector2(0, 3), 2), "brazier_lit's flame point is on the coals")


# ---------------------------------------------------------------- family look

# the new monsters share the old ones' sticker rim: a warm cream line right
# outside the ink on every frame
func _test_style_matches_family() -> void:
	for rel in ["art/enemies/bonebow_idle.svg", "art/enemies/helm_walk1.svg", "art/enemies/wing_fly1.svg",
			"art/enemies/drip_crawl1.svg", "art/enemies/jaw_hide.svg", "art/enemies/lurk_open.svg",
			"art/enemies/snuffer_idle.svg", "art/props/brazier_lit.svg"]:
		var text := _text(rel)
		_check(text.to_lower().contains("#ffeccc"), "%s has the family's candlelit sticker rim" % rel)
