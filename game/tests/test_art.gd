extends SceneTree
## test_art (W6a): the hero, item and UI art keeps its contracts.
## - Every Calling ships every rig part on the 128 frame, a rig.json that
##   agrees with classes.gd, and four portraits whose crop keeps the flame.
## - The joints line up: the weapon's grip, the fists, the offhand's grip,
##   the soles and the flame's wick sit where wick_rig.gd puts them, and
##   wick_rig.gd's PIVOTS are the ones the art was drawn to.
## - weapon_tip is on each weapon's business end, and portrait_flame is
##   [x, y, h] in portrait units from the crop's corner (the wick is there in
##   every portrait image).
## - The real rig loads each Calling from art/heroes/<cls>/ and its
##   flame_point() lands on the wick.
## - What the rig shows really shows: the Sexton's handbell hangs in sight at
##   rest, and every cape comes into view as it flares back (positive angles).
## - The five read as different characters at 64 px.
## - Items, buttons, relics, the WAXBY logo and the app icon exist, are
##   framed and centred, and use nothing ThorVG can't draw.
## - v3 (A8): all five item tiers, each tier 4 frost-rimmed in a cold rime glow and
##   each tier 5 behind a halo of rays, found by Items.icon; the 20 relics
##   (every id relics.gd knows has its icon, all 20 different pictures); the world tabs in their accents
##   and six shapes; the Candlemark; four medals of four metals and a ghost
##   for none; seals with one, two and three drips; the pill icons bold at
##   16 px (a warm drip, a lit spare wick, a black Hushing with a pale eye);
##   the 25 cape trims, white and ink only, along each cape's hem and outer
##   edge, and in sight on the rig at rest, through a run's stride and in the
##   Look tab's flared pose (the rig composed as wick_rig.gd poses it).
##
##     godot --headless --path game --script res://tests/test_art.gd

const CALLINGS := ["knight", "witch", "runner", "founder", "sexton"]
const PARTS := ["cape", "leg_back", "leg_front", "body", "arm_back", "arm_front", "head", "head_blink",
	"head_hurt", "head_happy", "head_fierce", "candle", "weapon"]
const MOODS := ["normal", "happy", "fierce", "hurt"]
const RIG_KEYS := ["flame_tip", "flame_scale", "light_mult", "offhand", "offhand_front", "weapon_rest_deg",
	"portrait_viewbox", "portrait_flame", "weapon_tip"]
# The art contract (tools/art/wick.py PIVOTS, spec 2.1): frame units
const PIVOTS := {
	"cape": Vector2(58, 84), "leg_back": Vector2(60, 104), "arm_back": Vector2(54, 86),
	"body": Vector2(64, 108), "leg_front": Vector2(68, 104), "head": Vector2(64, 84),
	"candle": Vector2(60, 34), "arm_front": Vector2(74, 86), "weapon": Vector2(64, 96), "offhand": Vector2(52, 101),
}
const HAND := Vector2(76, 101)
const HAND_BACK := Vector2(52, 101)
const FEET := Vector2(64, 122)
const ITEM_SLOTS := ["candle", "coat", "boots", "charm"]
const TIERS := [1, 2, 3, 4, 5]
const BUTTONS := ["btn_special_knight", "btn_special_witch", "btn_special_runner", "btn_special_founder",
	"btn_special_sexton", "btn_special_toll", "btn_flask"]
const NEW_RELICS := ["owls_eye", "wind_wick", "bell_shard", "choir_bone",
	# v3's eight (spec 8.3), two a world
	"sporeward", "bone_flute", "hoarfrost_bell", "clockheart", "leaded_pane", "sanctum_glass", "hush_pearl", "taper_match"]
# v3's UI art (contract 13): the map's world tabs (1 and 2 too, so all six tabs
# match), the Candlemark, the Trials' medals, the Waxworks' seals, the mode pill
const WORLD_ACCENT := {1: Color("d8b24a"), 2: Color("e8c86a"), 3: Color("c8d46a"), 4: Color("bfe4f4"), 5: Color("c83a5a"), 6: Color("d8d4f0")}
const MEDALS := ["bronze", "silver", "gold", "dawn"]
const SEALS := ["bronze", "silver", "gold"]
const PILLS := ["drip", "spare_wick", "hushing"]
# the cape trims (P2, spec 7.5): one pattern a calling's four Trial Golds, every calling wears all five
const TRIM_PATTERNS := ["band", "tongues", "stitch", "bells", "scallop"]

var _passed := 0
var _failed := 0
var _cache := {}


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", what)


func _initialize() -> void:
	_test_rig_contract()
	_test_knight_is_waxby()
	for cls in CALLINGS:
		_test_calling_files(cls)
		_test_joints(cls)
		_test_portraits(cls)
	await _test_real_rig()
	_test_in_sight()
	_test_distinct()
	_test_items()
	_test_ui_and_relics()
	_test_ui_v3()
	_test_cape_trims()
	_test_logo_and_icon()
	print("test_art: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# ---------------------------------------------------------------- helpers

func _svg(rel: String) -> String:
	var p := "res://" + rel
	return FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else ""


func _rast(rel: String, scale := 1.0) -> Image:
	## Rasterized straight from the SVG text, as the importer's ThorVG does.
	var key := "%s@%s" % [rel, scale]
	if _cache.has(key):
		return _cache[key]
	var img := Image.new()
	var text := _svg(rel)
	if text == "" or img.load_svg_from_string(text, scale) != OK:
		img = null
	else:
		img.convert(Image.FORMAT_RGBA8)
	_cache[key] = img
	return img


func _viewbox(text: String) -> PackedFloat32Array:
	var i := text.find("viewBox=\"")
	if i < 0:
		return PackedFloat32Array()
	var j := text.find("\"", i + 9)
	var out := PackedFloat32Array()
	for v in text.substr(i + 9, j - i - 9).split(" ", false):
		out.append(float(v))
	return out


func _opaque_near(img: Image, p: Vector2, r: float, a := 0.5) -> bool:
	## Is any pixel within r px of p (px) at least a opaque?
	for y in range(int(p.y - r), int(p.y + r) + 1):
		for x in range(int(p.x - r), int(p.x + r) + 1):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			if Vector2(x + 0.5, y + 0.5).distance_to(p) <= r and img.get_pixel(x, y).a >= a:
				return true
	return false


func _touches_edge(img: Image) -> bool:
	var w := img.get_width()
	var h := img.get_height()
	for x in w:
		if img.get_pixel(x, 0).a > 0.05 or img.get_pixel(x, h - 1).a > 0.05:
			return true
	for y in h:
		if img.get_pixel(0, y).a > 0.05 or img.get_pixel(w - 1, y).a > 0.05:
			return true
	return false


func _rig_json(cls: String) -> Dictionary:
	var p := "res://art/heroes/%s/rig.json" % cls
	if not FileAccess.file_exists(p):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(p))
	return d if d is Dictionary else {}


func _v(a) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


func _top_opaque_near(img: Image, x: float, half: int) -> float:
	## The first row (px) with an opaque pixel within half px of column x.
	for y in img.get_height():
		for xx in range(int(x) - half, int(x) + half + 1):
			if xx >= 0 and xx < img.get_width() and img.get_pixel(xx, y).a > 0.5:
				return float(y)
	return -1.0


func _lowest_opaque_row(img: Image) -> int:
	for y in range(img.get_height() - 1, -1, -1):
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				return y
	return -1


# ---------------------------------------------------------------- the rig contract

func _test_rig_contract() -> void:
	# wick_rig.gd's own joints must be the ones every part was drawn to
	var rig: GDScript = load("res://scripts/wick_rig.gd")
	_check(rig != null, "wick_rig.gd loads")
	if rig == null:
		return
	var c: Dictionary = rig.get_script_constant_map()
	var piv: Dictionary = c.get("PIVOTS", {})
	for part in PIVOTS:
		_check(piv.get(part, Vector2.INF) == PIVOTS[part], "wick_rig PIVOTS[%s] is %s" % [part, PIVOTS[part]])
	_check(c.get("HAND") == HAND, "wick_rig HAND is (76, 101)")
	_check(c.get("HAND_BACK") == HAND_BACK, "wick_rig HAND_BACK is (52, 101)")
	_check(c.get("FRAME_FEET") == FEET, "wick_rig FRAME_FEET is (64, 122)")


func _test_knight_is_waxby() -> void:
	# the knight is today's Waxby, moved: art/wick's parts, the sword renamed
	# weapon; art/wick itself stays whole as the rig's fallback
	for part in PARTS:
		var from: String = "sword" if part == "weapon" else part
		var wick := _svg("art/wick/%s.svg" % from)
		_check(wick != "", "art/wick/%s.svg is still there (the fallback)" % from)
		_check(wick == _svg("art/heroes/knight/%s.svg" % part), "the knight's %s is art/wick's %s" % [part, from])


func _test_calling_files(cls: String) -> void:
	var dir := "art/heroes/%s/" % cls
	var rd := _rig_json(cls)
	_check(not rd.is_empty(), "%s: rig.json parses" % cls)
	for k in RIG_KEYS:
		_check(rd.has(k), "%s: rig.json has %s" % [cls, k])
	var parts := PARTS.duplicate()
	if rd.get("offhand", false):
		parts.append("offhand")
	for part in parts:
		var rel: String = dir + part + ".svg"
		var text := _svg(rel)
		_check(text != "", "%s: %s.svg exists" % [cls, part])
		if text == "":
			continue
		_check(not text.contains("<text") and not text.contains("<filter"), "%s/%s: no <text> or <filter>" % [cls, part])
		_check(_viewbox(text) == PackedFloat32Array([0, 0, 128, 128]), "%s/%s: viewBox 0 0 128 128" % [cls, part])
		var img := _rast(rel)
		_check(img != null and img.get_size() == Vector2i(256, 256), "%s/%s: rasterizes at 256 px" % [cls, part])
		if img != null:
			_check(not _touches_edge(img), "%s/%s: stays inside its frame" % [cls, part])
	# the numbers the rig and the game share agree with classes.gd
	var classes: GDScript = load("res://scripts/classes.gd")
	var info: Dictionary = classes.get_script_constant_map().get("ALL", {}).get(cls, {}) if classes else {}
	if not info.is_empty() and rd.has("flame_tip"):
		_check(_v(rd["flame_tip"]) == _v(info["flame_tip"]), "%s: flame_tip matches classes.gd" % cls)
		_check(is_equal_approx(float(rd["flame_scale"]), float(info["flame_scale"])), "%s: flame_scale matches classes.gd" % cls)
		_check(is_equal_approx(float(rd["light_mult"]), float(info["light_mult"])), "%s: light_mult matches classes.gd" % cls)
	if rd.has("offhand"):
		_check(bool(rd["offhand"]) == (cls in ["knight", "sexton"]), "%s: offhand only for the knight's shield and the sexton's bell" % cls)
		_check(bool(rd["offhand_front"]) == (cls == "knight"), "%s: only the shield is carried in front" % cls)


func _test_joints(cls: String) -> void:
	var dir := "art/heroes/%s/" % cls
	var rd := _rig_json(cls)
	var weapon := _rast(dir + "weapon.svg")
	var armf := _rast(dir + "arm_front.svg")
	var armb := _rast(dir + "arm_back.svg")
	var candle := _rast(dir + "candle.svg")
	if weapon == null or armf == null or armb == null or candle == null:
		_check(false, "%s: joint parts rasterize" % cls)
		return
	# 2 px per unit: the grip at the weapon's pivot, the fists at the hands
	_check(_opaque_near(weapon, PIVOTS["weapon"] * 2.0, 3.0), "%s: the weapon's grip is at its pivot (64, 96)" % cls)
	_check(_opaque_near(armf, HAND * 2.0, 3.0), "%s: the front fist closes on HAND (76, 101)" % cls)
	_check(_opaque_near(armb, HAND_BACK * 2.0, 3.0), "%s: the back fist is at HAND_BACK (52, 101)" % cls)
	_check(_opaque_near(armf, PIVOTS["arm_front"] * 2.0 + Vector2(0, 8), 5.0), "%s: the front arm hangs from its shoulder" % cls)
	# the weapon's business end (wick_rig.weapon_point(): a spark's origin, a
	# maul's impact) is drawn there, at the far end from the grip
	if rd.has("weapon_tip"):
		var wt := _v(rd["weapon_tip"])
		_check(_opaque_near(weapon, wt * 2.0, 1.0, 0.9), "%s: weapon_tip %s is on the weapon" % [cls, rd["weapon_tip"]])
		_check(wt.distance_to(PIVOTS["weapon"]) >= 25.0, "%s: weapon_tip is the far end, not the grip" % cls)
		if cls == "founder":
			# the maul strikes with its bell's mouth: the dark inside, not the bronze
			var px := weapon.get_pixelv(Vector2i(wt * 2.0))
			_check(px.a > 0.9 and px.get_luminance() < 0.2, "founder: weapon_tip is in the bell's dark mouth (%s)" % px)
		else:
			# a point, a blade or the fork's middle taper: the top of the drawing there
			var top := _top_opaque_near(weapon, wt.x * 2.0, 2) / 2.0
			_check(wt.y - top >= 0.0 and wt.y - top <= 5.0, "%s: weapon_tip is at the weapon's top end (%.1f below its edge)" % [cls, wt.y - top])
	if rd.get("offhand", false):
		var off := _rast(dir + "offhand.svg")
		_check(off != null and _opaque_near(off, HAND_BACK * 2.0, 3.0), "%s: the offhand is held at its pivot (52, 101)" % cls)
	# the wick's tip is the flame's base; the candle's base sits on the headgear
	if rd.has("flame_tip"):
		var tip := _v(rd["flame_tip"]) * 2.0
		_check(_opaque_near(candle, tip + Vector2(0, 2), 2.5), "%s: the wick reaches flame_tip %s" % [cls, rd["flame_tip"]])
		_check(not _opaque_near(candle, tip - Vector2(0, 12), 2.0, 0.2), "%s: nothing drawn where the flame burns" % cls)
	if rd.has("candle_base"):
		var head := _rast(dir + "head.svg")
		var cb := _v(rd["candle_base"]) * 2.0
		_check(_opaque_near(candle, cb, 5.0) and _opaque_near(head, cb, 6.0), "%s: the candle's base meets the headgear" % cls)
	# both soles stand on the ground line (122)
	for leg in ["leg_front", "leg_back"]:
		var img := _rast(dir + leg + ".svg")
		var low := _lowest_opaque_row(img) / 2.0 if img else -1.0
		_check(low >= 119.5 and low <= 123.5, "%s: %s's sole is on the ground (lowest %.1f)" % [cls, leg, low])


func _test_portraits(cls: String) -> void:
	var rd := _rig_json(cls)
	if not rd.has("portrait_viewbox"):
		return
	var vb: Array = rd["portrait_viewbox"]
	var fl := _v(rd["portrait_flame"])
	# [x, y, h]: the dialogue draws the flame at c + (xy / w - 0.5) * 2r, h * 2r / w tall
	var pf: Array = rd["portrait_flame"]
	_check(pf.size() == 3, "%s: portrait_flame is [x, y, h]" % cls)
	if pf.size() == 3:
		var want_h := 0.25 * float(vb[2]) * float(rd.get("flame_scale", 1.0))
		_check(absf(float(pf[2]) - want_h) < 0.05, "%s: the portrait flame is a quarter of the crop tall (x flame_scale): %s" % [cls, pf[2]])
	_check(vb.size() == 4 and is_equal_approx(float(vb[2]), float(vb[3])), "%s: the portrait crop is square" % cls)
	# the flame's base in portrait units from the crop's corner, inside the
	# circle the dialogue box draws, with room to spare
	var size := float(vb[2])
	var r := size * 0.5
	var from_c := fl.distance_to(Vector2(r, r))

	_check(from_c <= r * 0.92, "%s: the portrait flame (%s) sits inside the circle (%.1f of %.1f)" % [cls, fl, from_c, r])
	_check(fl == _v(rd["flame_tip"]) - Vector2(float(vb[0]), float(vb[1])), "%s: portrait_flame is flame_tip rebased to the crop" % cls)
	if rd.has("portrait_flame_uv"):
		_check((_v(rd["portrait_flame_uv"]) - fl / size).length() < 0.001, "%s: portrait_flame_uv is portrait_flame / size" % cls)
	for mood in MOODS:
		var rel := "art/heroes/%s/portrait_%s.svg" % [cls, mood]
		var text := _svg(rel)
		_check(text != "", "%s: portrait_%s.svg exists" % [cls, mood])
		if text == "":
			continue
		var got := _viewbox(text)
		_check(got.size() == 4 and is_equal_approx(got[0], float(vb[0])) and is_equal_approx(got[1], float(vb[1]))
			and is_equal_approx(got[2], float(vb[2])), "%s/portrait_%s: its viewBox is rig.json's portrait_viewbox" % [cls, mood])
		var img := _rast(rel)
		_check(img != null and img.get_width() == img.get_height() and img.get_width() >= 512, "%s/portrait_%s: a square texture of 512 px or more" % [cls, mood])
		if img != null:
			# the wick really is at portrait_flame, measured from the crop's
			# corner in portrait units (not the 128 frame)
			var k := float(img.get_width()) / size
			var wick := fl * k
			_check(_opaque_near(img, wick + Vector2(0, k), 1.25 * k), "%s/portrait_%s: the wick is at portrait_flame" % [cls, mood])
			_check(not _opaque_near(img, wick - Vector2(0, 6.0 * k), 1.0 * k, 0.2), "%s/portrait_%s: nothing is drawn where the flame burns" % [cls, mood])
			# the face fills the middle of the circle
			var c := Vector2(img.get_width(), img.get_height()) * 0.5
			var face := (Vector2(70.6, 69) - Vector2(float(vb[0]), float(vb[1]))) / size * float(img.get_width())
			_check(face.distance_to(c) < img.get_width() * 0.3, "%s/portrait_%s: the face is near the middle" % [cls, mood])


# ---------------------------------------------------------------- the real rig

func _test_real_rig() -> void:
	var RigScript: GDScript = load("res://scripts/wick_rig.gd")
	for cls in CALLINGS:
		var rd := _rig_json(cls)
		var holder := Node2D.new()
		holder.position = Vector2(200, 200)
		root.add_child(holder)
		var rig = RigScript.new()
		rig.cls = cls
		holder.add_child(rig)
		await process_frame
		_check(str(rig.get("dir")) == "res://art/heroes/%s/" % cls, "%s: the rig loads art/heroes/%s/ (got %s)" % [cls, cls, rig.get("dir")])
		var textured := 0
		var stack := [rig]
		while stack.size() > 0:
			var n: Node = stack.pop_back()
			for ch in n.get_children():
				stack.append(ch)
			if n is Sprite2D and (n as Sprite2D).texture != null:
				textured += 1
		var want := 9 + (1 if rd.get("offhand", false) else 0)   # cape, legs, arms, body, head, candle, weapon (+ offhand)
		_check(textured == want, "%s: the rig shows %d textured parts (got %d)" % [cls, want, textured])
		# at rest the flame burns exactly on the wick tip
		if rd.has("flame_tip"):
			var fp: Vector2 = rig.flame_point() - rig.global_position
			var want_fp := (_v(rd["flame_tip"]) - FEET) * 0.5
			_check(fp.distance_to(want_fp) < 0.01, "%s: flame_point() is on the wick (%s vs %s)" % [cls, fp, want_fp])
		# a rig that reports its weapon's business end (W1's weapon_point())
		# finds it from rig.json weapon_tip: at rest, the tip turned about the
		# front fist by weapon_rest_deg
		if rig.has_method("weapon_point") and rd.has("weapon_tip"):
			var wp: Vector2 = rig.weapon_point() - rig.global_position
			var rest := deg_to_rad(float(rd.get("weapon_rest_deg", 80)))
			var want_wp := (HAND - FEET) * 0.5 + ((_v(rd["weapon_tip"]) - PIVOTS["weapon"]) * 0.5).rotated(rest)
			_check(wp.distance_to(want_wp) < 0.5, "%s: weapon_point() is on the weapon's tip (%s vs %s)" % [cls, wp, want_wp])
		holder.queue_free()
		await process_frame


# ---------------------------------------------------------------- five different characters

func _silhouette(cls: String) -> Image:
	return _compose(cls, 0.25)


func _compose(cls: String, k: float, skip := "", cape := 0.0) -> Image:
	## The Calling at rest, its 256 px textures at k (0.25: 64 px, one world
	## px per px; 0.5: one px per frame unit): every part where the rig puts
	## it, the weapon turned to its rest angle in the front fist, the cape
	## turned by cape radians about its pivot (positive swings its hem back).
	## skip leaves one part out.
	var rd := _rig_json(cls)
	var n := int(256 * k)
	var u := k * 2.0
	var img := Image.create_empty(n, n, false, Image.FORMAT_RGBA8)
	var order := ["cape", "leg_back", "arm_back"]
	var off_front: bool = rd.get("offhand_front", false)
	if rd.get("offhand", false) and not off_front:
		order.append("offhand")
	order.append_array(["body", "leg_front", "head", "candle", "weapon", "arm_front"])
	if rd.get("offhand", false) and off_front:
		order.append("offhand")
	for part in order:
		if part == skip:
			continue
		var src := _rast("art/heroes/%s/%s.svg" % [cls, part], k)
		if src == null:
			continue
		if part == "weapon":
			_blend_turned(img, src, PIVOTS["weapon"] * u, HAND * u, deg_to_rad(float(rd.get("weapon_rest_deg", 80))))
		elif part == "cape" and cape != 0.0:
			_blend_turned(img, src, PIVOTS["cape"] * u, PIVOTS["cape"] * u, cape)
		else:
			img.blend_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), Vector2i.ZERO)
	return img


func _shown(a: Image, b: Image) -> int:
	## How many pixels differ between two composites: what one part adds to
	## the picture once everything drawn over it has covered what it covers.
	var n := 0
	for y in a.get_height():
		for x in a.get_width():
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(x, y)
			if absf(p.a - q.a) + absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b) > 0.3:
				n += 1
	return n


func _blend_turned(dst: Image, src: Image, pivot: Vector2, at: Vector2, ang: float) -> void:
	## src turned by ang about pivot, the pivot landing on at (nearest pixel).
	var c := cos(ang)
	var s := sin(ang)
	for y in dst.get_height():
		for x in dst.get_width():
			var d := Vector2(x + 0.5, y + 0.5) - at
			var q := pivot + Vector2(d.x * c + d.y * s, -d.x * s + d.y * c)
			var qx := int(floor(q.x))
			var qy := int(floor(q.y))
			if qx < 0 or qy < 0 or qx >= src.get_width() or qy >= src.get_height():
				continue
			var p := src.get_pixel(qx, qy)
			if p.a > 0.0:
				dst.set_pixel(x, y, dst.get_pixel(x, y).blend(p))


# ---------------------------------------------------------------- in sight

func _test_in_sight() -> void:
	var verbose := OS.get_environment("ART_VERBOSE") != ""
	# the Sexton's handbell, carried behind him, hangs clear of the coat at
	# rest: a whole bell (at one px per unit, and still a bell's worth at 64 px),
	# not a sliver poking out at the heel (the first bell, hung straight back
	# from the fist, showed 125 and 35 px of itself)
	var full := _compose("sexton", 0.5)
	var bell := _shown(full, _compose("sexton", 0.5, "offhand"))
	var bell64 := _shown(_compose("sexton", 0.25), _compose("sexton", 0.25, "offhand"))
	if verbose:
		print("  sexton bell in sight at rest: %d px (128), %d px (64)" % [bell, bell64])
	_check(bell >= 180, "sexton: the handbell shows at rest (%d px of it at 128 px)" % bell)
	_check(bell64 >= 50, "sexton: the handbell reads at 64 px (%d px)" % bell64)
	# capes: tucked (negative) they hide behind the body and legs; flared back
	# (the run's +0.35) every Calling's cape comes further into view than at
	# rest, and plainly more than tucked
	for cls in CALLINGS:
		var bare := _compose(cls, 0.5, "cape")
		var rest := _shown(_compose(cls, 0.5), bare)
		var flared := _shown(_compose(cls, 0.5, "", 0.35), bare)
		var tucked := _shown(_compose(cls, 0.5, "", -0.35), bare)
		if verbose:
			print("  %s cape in sight: tucked %d, rest %d, flared %d px" % [cls, tucked, rest, flared])
		_check(flared > rest and flared >= tucked + 60, "%s: the cape shows as it flares back, not as it tucks in (flared %d, rest %d, tucked %d px)" % [cls, flared, rest, tucked])
		if cls != "knight":
			# (Waxby's cape is v1's, behind his shield)
			_check(flared >= 90, "%s: the cape flared back is plain to see (%d px at 128 px)" % [cls, flared])


func _palette(img: Image) -> PackedFloat32Array:
	## A coarse colour histogram (6 levels a channel) of the fill colours,
	## leaving out what every Calling shares: the ink lines and the cream rim.
	var h := PackedFloat32Array()
	h.resize(216)
	var n := 0.0
	for y in img.get_height():
		for x in img.get_width():
			var p := img.get_pixel(x, y)
			if p.a < 0.6 or p.get_luminance() < 0.12:
				continue
			if p.r > 0.9 and p.g > 0.84 and p.b > 0.72 and absf(p.r - p.b) < 0.25:
				continue
			var i := mini(5, int(p.r * 6.0)) * 36 + mini(5, int(p.g * 6.0)) * 6 + mini(5, int(p.b * 6.0))
			h[i] += 1.0
			n += 1.0
	for i in h.size():
		h[i] /= maxf(1.0, n)
	return h


func _iou(a: Image, b: Image) -> float:
	var inter := 0
	var uni := 0
	for y in 64:
		for x in 64:
			var pa := a.get_pixel(x, y).a > 0.5
			var pb := b.get_pixel(x, y).a > 0.5
			inter += int(pa and pb)
			uni += int(pa or pb)
	return inter / maxf(1.0, uni)


func _l1(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	var d := 0.0
	for i in a.size():
		d += absf(a[i] - b[i])
	return d


func _test_distinct() -> void:
	var sil := {}
	var pal := {}
	for cls in CALLINGS:
		sil[cls] = _silhouette(cls)
		pal[cls] = _palette(sil[cls])
	# the family colours every Calling shares (skin, gold trim, the blends
	# of rim and ink at this size) are taken out; what is left is each one's
	# own: how much of that differs between two of them, 0..1
	var shared := PackedFloat32Array()
	shared.resize(216)
	for i in 216:
		var m := 1.0
		for cls in CALLINGS:
			m = minf(m, pal[cls][i])
		shared[i] = m
	var own := {}
	for cls in CALLINGS:
		var r := PackedFloat32Array()
		r.resize(216)
		for i in 216:
			r[i] = pal[cls][i] - shared[i]
		own[cls] = r
	var apart := func(a: String, b: String) -> float:
		var d := 0.0
		var total := 0.0
		for i in 216:
			d += absf(own[a][i] - own[b][i])
			total += own[a][i] + own[b][i]
		return d / maxf(0.0001, total)
	# the measures themselves: a calling matches itself
	_check(is_equal_approx(_iou(sil["knight"], sil["knight"]), 1.0) and apart.call("knight", "knight") < 0.001,
		"the likeness measures see a calling as itself")
	for i in CALLINGS.size():
		for j in range(i + 1, CALLINGS.size()):
			var a: String = CALLINGS[i]
			var b: String = CALLINGS[j]
			var o := _iou(sil[a], sil[b])
			var dc: float = apart.call(a, b)
			if OS.get_environment("ART_VERBOSE") != "":
				print("  %s / %s: outline overlap %.2f, own colours apart %.2f" % [a, b, o, dc])
			# a different outline at 64 px and mostly different colours of their own
			_check(o < 0.82, "%s and %s have different outlines at 64 px (overlap %.2f)" % [a, b, o])
			_check(dc > 0.55, "%s and %s wear their own colours (%.2f of their own colour differs)" % [a, b, dc])


# ---------------------------------------------------------------- items, buttons, relics

func _opaque_rect(img: Image, a := 0.9) -> Rect2i:
	## The box round the drawing itself: its opaque px, not a faint glow or
	## the halo of rays behind it (which get_used_rect would count).
	var x0 := img.get_width()
	var y0 := img.get_height()
	var x1 := -1
	var y1 := -1
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > a:
				x0 = mini(x0, x)
				y0 = mini(y0, y)
				x1 = maxi(x1, x)
				y1 = maxi(y1, y)
	return Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1) if x1 >= 0 else Rect2i()


func _centred(img: Image, tol: float, a := 0.9) -> bool:
	var r := _opaque_rect(img, a)
	var c := Vector2(r.position) + Vector2(r.size) * 0.5
	return r.size.x > 0 and c.distance_to(Vector2(img.get_size()) * 0.5) <= tol


func _test_items() -> void:
	var names := []
	for cls in CALLINGS:
		for t in TIERS:
			names.append("weapon_%s_%d" % [cls, t])
	for slot in ITEM_SLOTS:
		for t in TIERS:
			names.append("%s_%d" % [slot, t])
	_check(names.size() == 45, "45 item icons are listed (five tiers of every weapon and slot)")
	for n in names:
		var rel := "art/items/%s.svg" % n
		var text := _svg(rel)
		_check(text != "", "%s.svg exists" % n)
		if text == "":
			continue
		_check(not text.contains("<text") and not text.contains("<filter"), "%s: no <text> or <filter>" % n)
		_check(_viewbox(text) == PackedFloat32Array([0, 0, 64, 64]) and text.contains("width=\"128\""), "%s: the 64 frame at 128 px" % n)
		var img := _rast(rel)
		if img == null:
			_check(false, "%s rasterizes" % n)
			continue
		_check(not _touches_edge(img), "%s: stays inside its frame" % n)
		# measured on the drawing's opaque px (a tier 4's rime glow and a tier
		# 5's rays fill the frame whatever the item inside them)
		var r := _opaque_rect(img)
		if OS.get_environment("ART_VERBOSE") != "":
			print("  %s: drawing %s" % [n, r])
		_check(_centred(img, 12.0), "%s: centred (the drawing %s)" % [n, r])
		_check(r.size.x >= 64 and r.size.y >= 64, "%s: fills its frame enough to read at 26 px (%s)" % [n, r.size])
	# the five tiers of a slot are five different drawings
	for group in ["weapon_knight", "weapon_witch", "weapon_runner", "weapon_founder", "weapon_sexton", "candle", "coat", "boots", "charm"]:
		var seen := {}
		for t in TIERS:
			seen[_svg("art/items/%s_%d.svg" % [group, t])] = true
		_check(seen.size() == TIERS.size(), "%s: five distinct tiers" % group)
		# the tier's mark reads before its details: tier 4 a cold rime glow,
		# tier 5 a halo of rays (tiers 1-3 have neither)
		var g4 := _glow_colour(_rast("art/items/%s_4.svg" % group))
		var g3 := _glow_colour(_rast("art/items/%s_3.svg" % group))
		_check(g4.b > g4.r + 0.08 and g4.g > g4.r + 0.08, "%s_4: its glow is cold rime, blue-green over red (%s)" % [group, g4])
		_check(not (g3.b > g3.r + 0.08 and g3.g > g3.r + 0.08), "%s_3: tier 3's glow is not rime's (%s)" % [group, g3])
		# and by its outline: tier 4's sticker rim is frost (aee6ff), every
		# other tier's the candlelit cream (ffeccc), so a tier 4 reads as
		# rimed even over a tier 3 that sits in a cool glow of its own
		var t4 := _svg("art/items/%s_4.svg" % group)
		_check(t4.contains("#aee6ff") and not t4.contains("#ffeccc"), "%s_4: a frosted rim round its silhouette" % group)
		for t in [1, 2, 3, 5]:
			_check(not _svg("art/items/%s_%d.svg" % [group, t]).contains("#aee6ff"), "%s_%d: only tier 4 is frost-rimmed" % [group, t])
		var rays := {}
		for t in [3, 4, 5]:
			rays[t] = _ray_count(_rast("art/items/%s_%d.svg" % [group, t]))
		if OS.get_environment("ART_VERBOSE") != "":
			print("  %s: glow t3 %s t4 %s; rays t3 %.2f t4 %.2f t5 %.2f" % [group, g3, g4, rays[3], rays[4], rays[5]])
		_check(rays[5] >= 0.1, "%s_5: a halo of rays behind it (rays %.2f brighter than the gaps)" % [group, rays[5]])
		_check(rays[4] < 0.03 and rays[3] < 0.03, "%s: only tier 5 wears the rays (tier 3 %.2f, tier 4 %.2f)" % [group, rays[3], rays[4]])
	# the game finds every tier's own picture (Items.icon clamps only a
	# missing one down to tier 3)
	var items: GDScript = load("res://scripts/items.gd")
	if items == null:
		_check(false, "items.gd loads")
		return
	for t in TIERS:
		for cls in CALLINGS:
			var want := "res://art/items/weapon_%s_%d.svg" % [cls, t]
			_check(items.icon({"slot": "weapon", "cls": cls, "tier": t}) == want, "Items.icon finds weapon_%s_%d" % [cls, t])
		for slot in ITEM_SLOTS:
			var want := "res://art/items/%s_%d.svg" % [slot, t]
			_check(items.icon({"slot": slot, "tier": t}) == want, "Items.icon finds %s_%d" % [slot, t])


func _glow_colour(img: Image) -> Color:
	## The mean colour of the faint pixels (the glow and rays behind an icon,
	## not the drawing itself).
	var sum := Color(0, 0, 0, 0)
	var n := 0.0
	if img == null:
		return sum
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			var p := img.get_pixel(x, y)
			if p.a > 0.04 and p.a < 0.45:
				sum += Color(p.r, p.g, p.b, p.a)
				n += 1.0
	return sum / maxf(1.0, n)


func _ray_count(img: Image) -> float:
	## Rays behind an icon (items_art.radiant: twelve, at 15 + 30k degrees):
	## how much brighter the faint pixels are on the rays than between them,
	## 18 to 28 units out, the median over the rays the drawing leaves in
	## sight (an opaque sample is the drawing, not the halo).
	if img == null:
		return 0.0
	var c := Vector2(img.get_size()) * 0.5
	var k := img.get_width() / 64.0
	var diffs := []
	for rr in [18.0, 22.0, 26.0, 28.0]:
		for i in 12:
			var on := deg_to_rad(15.0 + 30.0 * i)
			var off := on + deg_to_rad(15.0)
			var pa := img.get_pixelv(Vector2i(c + Vector2(cos(on), sin(on)) * rr * k)).a
			var pb := img.get_pixelv(Vector2i(c + Vector2(cos(off), sin(off)) * rr * k)).a
			if pa < 0.7 and pb < 0.7:
				diffs.append(pa - pb)
	if diffs.size() < 6:
		return 0.0
	diffs.sort()
	return diffs[diffs.size() / 2]


func _test_ui_and_relics() -> void:
	for n in BUTTONS:
		var rel := "art/ui/%s.svg" % n
		var text := _svg(rel)
		_check(text != "", "%s.svg exists" % n)
		if text == "":
			continue
		_check(_viewbox(text) == PackedFloat32Array([0, 0, 128, 128]), "%s: the 128 frame" % n)
		var img := _rast(rel)
		if img == null:
			continue
		_check(not _touches_edge(img), "%s: inside its frame" % n)
		_check(_centred(img, 16.0), "%s: centred" % n)
		# a light glyph: its opaque pixels are mostly cream
		var light := 0
		var opaque := 0
		for y in range(0, img.get_height(), 2):
			for x in range(0, img.get_width(), 2):
				var p := img.get_pixel(x, y)
				if p.a > 0.8:
					opaque += 1
					light += int(p.get_luminance() > 0.7)
		_check(opaque > 300 and light > opaque * 0.45, "%s: a light glyph (%d of %d light)" % [n, light, opaque])
	_check(_svg("art/ui/btn_special_toll.svg") != _svg("art/ui/btn_special_founder.svg"), "the Sexton's toll bell is not the Bellfounder's Peal")
	for id in NEW_RELICS:
		var rel := "art/relics/%s.svg" % id
		var text := _svg(rel)
		_check(text != "", "relic %s.svg exists" % id)
		if text == "":
			continue
		_check(_viewbox(text) == PackedFloat32Array([0, 0, 64, 64]), "relic %s: the 64 frame" % id)
		var img := _rast(rel)
		if img:
			_check(not _touches_edge(img), "relic %s: inside its frame" % id)
			_check(_centred(img, 12.0), "relic %s: centred" % id)


func _framed64(n: String, rel: String, tol := 12.0) -> Image:
	## The 64-frame contract for one piece of art; its raster, or null.
	var text := _svg(rel)
	_check(text != "", "%s exists" % rel)
	if text == "":
		return null
	_check(not text.contains("<text") and not text.contains("<filter"), "%s: no <text> or <filter>" % n)
	_check(_viewbox(text) == PackedFloat32Array([0, 0, 64, 64]) and text.contains("width=\"128\""), "%s: the 64 frame at 128 px" % n)
	var img := _rast(rel)
	if img == null:
		_check(false, "%s rasterizes" % n)
		return null
	_check(not _touches_edge(img), "%s: stays inside its frame" % n)
	# (the UI's ghosts are never solid: centred on all but the faintest px)
	_check(_centred(img, tol, 0.1), "%s: centred (drawn %s)" % [n, _opaque_rect(img, 0.1)])
	return img


func _hue_share(img: Image, want: Color, tol_deg := 25.0, min_s := 0.2) -> float:
	## The share of the drawing's opaque pixels in want's hue.
	var n := 0.0
	var hit := 0.0
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			var p := img.get_pixel(x, y)
			if p.a < 0.9:
				continue
			n += 1.0
			var d := absf(p.h - want.h) * 360.0
			d = minf(d, 360.0 - d)
			if d <= tol_deg and p.s >= min_s and p.v > 0.3:
				hit += 1.0
	return hit / maxf(1.0, n)


func _mask_iou(a: Image, b: Image) -> float:
	var inter := 0
	var uni := 0
	for y in a.get_height():
		for x in a.get_width():
			var pa := a.get_pixel(x, y).a > 0.5
			var pb := b.get_pixel(x, y).a > 0.5
			inter += int(pa and pb)
			uni += int(pa or pb)
	return inter / maxf(1.0, uni)


func _mean_fill(img: Image, c: Vector2, r0: float, r1: float) -> Color:
	## The mean colour of the opaque, not-ink pixels between r0 and r1 (px) of c.
	var sum := Color(0, 0, 0, 0)
	var n := 0.0
	for y in img.get_height():
		for x in img.get_width():
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d < r0 or d > r1:
				continue
			var p := img.get_pixel(x, y)
			if p.a > 0.9 and p.get_luminance() > 0.2:
				sum += p
				n += 1.0
	return sum / maxf(1.0, n)


func _runs(img: Image, y: int) -> int:
	## How many separate opaque runs cross row y.
	var runs := 0
	var inside := false
	for x in img.get_width():
		var on := img.get_pixel(x, y).a > 0.5
		if on and not inside:
			runs += 1
		inside = on
	return runs


func _test_ui_v3() -> void:
	# the world tabs: in their accents, six different shapes
	var tabs := {}
	for w in WORLD_ACCENT:
		var n := "world_%d" % w
		var img := _framed64(n, "art/ui/%s.svg" % n)
		if img == null:
			continue
		var share := _hue_share(img, WORLD_ACCENT[w], 25.0, 0.08 if w == 6 else 0.2)
		if OS.get_environment("ART_VERBOSE") != "":
			print("  %s: %.2f in its accent's hue" % [n, share])
		_check(share >= 0.2, "%s: drawn in its tab's accent %s (%.2f of it)" % [n, WORLD_ACCENT[w].to_html(false), share])
		tabs[w] = _rast("art/ui/%s.svg" % n, 0.25)
	for a in tabs:
		for b in tabs:
			if a < b:
				var o := _mask_iou(tabs[a], tabs[b])
				_check(o < 0.8, "world_%d and world_%d have different shapes at 32 px (overlap %.2f)" % [a, b, o])
	# the Candlemark: a gold star that holds at the HUD's 14 px
	var cm := _framed64("candlemark", "art/ui/candlemark.svg", 4.0)
	if cm:
		_check(_hue_share(cm, Color("f2c75a"), 20.0) >= 0.4, "candlemark: gold")
		var small := _rast("art/ui/candlemark.svg", 14.0 / 128.0)
		var on := 0
		for y in small.get_height():
			for x in small.get_width():
				on += int(small.get_pixel(x, y).a > 0.6)
		_check(on >= 40, "candlemark: a solid mark at 14 px (%d px of it)" % on)
		for tip in [Vector2(64, 22), Vector2(106, 64), Vector2(64, 106), Vector2(22, 64)]:
			_check(cm.get_pixelv(Vector2i(tip)).a > 0.9, "candlemark: its four points reach out (%s)" % tip)
	# medals: four metals, and the empty place is a ghost
	var metals := {}
	for m in MEDALS:
		var img := _framed64("medal_" + m, "art/ui/medal_%s.svg" % m)
		if img:
			metals[m] = _mean_fill(img, Vector2(64, 80), 12.0, 24.0)
	for a in metals:
		for b in metals:
			if a < b:
				var d := Vector3(metals[a].r - metals[b].r, metals[a].g - metals[b].g, metals[a].b - metals[b].b).length()
				_check(d > 0.1, "medal_%s and medal_%s are different metals (%.2f apart)" % [a, b, d])
	var seen := {}
	for m in MEDALS:
		seen[_svg("art/ui/medal_%s.svg" % m)] = true
	_check(seen.size() == MEDALS.size(), "four different medal drawings")
	var none := _framed64("medal_none", "art/ui/medal_none.svg")
	if none:
		# dashed lines at 0.75 over a dim wash: hardly any of it solid, where a
		# medal is solid through and through
		var drawn := 0
		var solid := 0
		for y in none.get_height():
			for x in none.get_width():
				var p := none.get_pixel(x, y)
				drawn += int(p.a > 0.1)
				solid += int(p.a > 0.9)
		_check(drawn > 2000 and solid < drawn * 0.1, "medal_none: a ghost, never solid (%d of %d px solid)" % [solid, drawn])
	# seals: one, two, three drips run off them
	for i in SEALS.size():
		var n: String = "seal_" + SEALS[i]
		var img := _framed64(n, "art/ui/%s.svg" % n)
		if img:
			var runs := _runs(img, 112)
			_check(runs == i + 1, "%s: %d drip(s) run off it (%d seen)" % [n, i + 1, runs])
	seen = {}
	for m in SEALS:
		seen[_svg("art/ui/seal_%s.svg" % m)] = true
	_check(seen.size() == SEALS.size(), "three different seals")
	# the pill icons read at 16 px
	for n in PILLS:
		var img := _framed64(n, "art/ui/%s.svg" % n)
		if img == null:
			continue
		var small := _rast("art/ui/%s.svg" % n, 16.0 / 128.0)
		var on := 0
		for y in small.get_height():
			for x in small.get_width():
				on += int(small.get_pixel(x, y).a > 0.6)
		_check(on >= 60, "%s: a bold shape at 16 px (%d of 256 px)" % [n, on])
	var drip := _rast("art/ui/drip.svg")
	if drip:
		var c := _mean_fill(drip, Vector2(64, 80), 0.0, 20.0)
		_check(c.r > c.b + 0.08, "drip: warm wax, never water's blue (%s)" % c)
	var sw := _rast("art/ui/spare_wick.svg")
	if sw:
		var flame := 0
		for y in range(0, 56):
			for x in sw.get_width():
				var p := sw.get_pixel(x, y)
				flame += int(p.a > 0.9 and p.r > 0.9 and p.g > 0.55 and p.b < 0.6)
		_check(flame >= 150, "spare_wick: a lit flame on top (%d px)" % flame)
	var hs := _rast("art/ui/hushing.svg")
	if hs:
		var dark := 0
		var pale := 0
		for y in hs.get_height():
			for x in hs.get_width():
				var p := hs.get_pixel(x, y)
				if p.a > 0.9:
					dark += int(p.get_luminance() < 0.2)
					pale += int(p.get_luminance() > 0.75 and p.b >= p.r)
		_check(dark > 2500 and pale > 400, "hushing: black, rimmed and eyed in the Hush's pale silver (%d dark, %d pale px)" % [dark, pale])
	# every relic the game knows has its icon, framed
	var relics: GDScript = load("res://scripts/relics.gd")
	if relics:
		for id in relics.ids():
			_check(_svg("art/relics/%s.svg" % id) != "", "relic %s has its icon" % id)
	# every relic icon there is (v1's eight, v2's four, v3's eight) is its
	# own drawing: no two the same text, nor the same picture at 32 px
	var all_ids := []
	for f in DirAccess.get_files_at("res://art/relics"):
		if f.ends_with(".svg"):
			all_ids.append(f.get_basename())
	_check(all_ids.size() >= 20, "art/relics holds the 20 relic icons (%d)" % all_ids.size())
	seen = {}
	var pics := {}
	for id in all_ids:
		seen[_svg("art/relics/%s.svg" % id)] = true
		pics[id] = _rast("art/relics/%s.svg" % id, 0.25)
	_check(seen.size() == all_ids.size(), "the %d relics are %d different texts" % [all_ids.size(), seen.size()])
	var closest := ""
	var most := 0.0
	for i in all_ids.size():
		for j in range(i + 1, all_ids.size()):
			var a: Image = pics[all_ids[i]]
			var b: Image = pics[all_ids[j]]
			if a == null or b == null:
				continue
			var o := _mask_iou(a, b)
			if o > most:
				most = o
				closest = "%s and %s" % [all_ids[i], all_ids[j]]
	if OS.get_environment("ART_VERBOSE") != "":
		print("  %d relics; the closest pair at 32 px: %s (%.2f)" % [all_ids.size(), closest, most])
	_check(most < 0.85, "the relics are different pictures at 32 px (the closest, %s, overlap %.2f)" % [closest, most])


func _on_ink_line(p: Color) -> bool:
	## Is p white, the trims' ink 1c1830, or a blend of the two?
	var ink := Color("1c1830")
	var t := clampf((1.0 - p.r) / (1.0 - ink.r), 0.0, 1.0)
	var want := Color.WHITE.lerp(ink, t)
	return absf(p.g - want.g) < 0.08 and absf(p.b - want.b) < 0.08


func _test_cape_trims() -> void:
	## art/heroes/<cls>/cape_trim_<pattern>.svg: on the cape's 128 frame (the
	## rig draws it with the cape's pivot and turn), white and ink only so
	## modulate colours it, along the cape's hem and outer edge, and in sight
	## on the rig (_test_trims_in_sight).
	for cls in CALLINGS:
		var cape := _rast("art/heroes/%s/cape.svg" % cls, 0.5)
		var masks := []
		for pat in TRIM_PATTERNS:
			var n := "%s/cape_trim_%s" % [cls, pat]
			var rel := "art/heroes/%s.svg" % n
			var text := _svg(rel)
			_check(text != "", "%s.svg exists" % n)
			if text == "":
				continue
			_check(not text.contains("<text") and not text.contains("<filter"), "%s: no <text> or <filter>" % n)
			_check(_viewbox(text) == PackedFloat32Array([0, 0, 128, 128]) and text.contains("width=\"256\""), "%s: the cape's 128 frame at 256 px" % n)
			var img := _rast(rel)
			var small := _rast(rel, 0.5)
			if img == null or small == null or cape == null:
				_check(false, "%s rasterizes" % n)
				continue
			masks.append(small)
			_check(not _touches_edge(img), "%s: stays inside its frame" % n)
			var drawn := 0
			var white := 0
			var grey := 0
			for y in range(0, img.get_height(), 2):
				for x in range(0, img.get_width(), 2):
					var p := img.get_pixel(x, y)
					if p.a <= 0.5:
						continue
					drawn += 1
					white += int(p.get_luminance() > 0.85)
					grey += int(_on_ink_line(p))
			_check(drawn >= 60, "%s: a trim worth seeing (%d px, every other one)" % [n, drawn])
			_check(grey == drawn, "%s: white and ink only, so modulate colours it (%d of %d px)" % [n, grey, drawn])
			_check(white >= drawn * 0.2, "%s: white enough to carry its colour (%d of %d px)" % [n, white, drawn])
			# along the cape's edge (at one px a unit): every px within 12 units
			# of both the cape and the air outside it, so never out in the
			# middle of the cape nor hanging far off it; and low on it, nothing
			# in the top fifth (the collar, under the head)
			var top := _top_opaque_near(cape, 64.0, 64)
			var bottom := float(_lowest_opaque_row(cape))
			var on := 0
			var edgy := 0
			var high := 0
			for y in small.get_height():
				for x in small.get_width():
					if small.get_pixel(x, y).a <= 0.5:
						continue
					on += 1
					var q := Vector2(x + 0.5, y + 0.5)
					edgy += int(_opaque_near(cape, q, 12.0, 0.5) and _clear_near(cape, q, 12.0))
					high += int(y < top + (bottom - top) * 0.2)
			_check(edgy >= on * 0.99, "%s: lies along the cape's edge (%d of %d px)" % [n, edgy, on])
			_check(high == 0, "%s: keeps to the hem and the outer edge, off the collar (%d px up there)" % [n, high])
		# five patterns that look different: in any two, a good share of the
		# px they cover between them differ (one white where the other is ink
		# or clear), not merely five different texts
		var least := 1.0
		for i in masks.size():
			for j in range(i + 1, masks.size()):
				least = minf(least, _pattern_diff(masks[i], masks[j]))
		_check(masks.size() == TRIM_PATTERNS.size() and least >= TRIM_DIFFER, "%s: five different trims (the closest two differ in %d%% of their px)" % [cls, int(least * 100)])
	_test_trims_in_sight()


const TRIM_DIFFER := 0.3


func _pattern_diff(a: Image, b: Image) -> float:
	## Of the px either trim covers, the share where they differ: clear, ink
	## or white in one and not the same in the other.
	var uni := 0
	var diff := 0
	for y in a.get_height():
		for x in a.get_width():
			var p := a.get_pixel(x, y)
			var q := b.get_pixel(x, y)
			var ka := 0 if p.a <= 0.5 else (2 if p.get_luminance() > 0.5 else 1)
			var kb := 0 if q.a <= 0.5 else (2 if q.get_luminance() > 0.5 else 1)
			if ka == 0 and kb == 0:
				continue
			uni += 1
			diff += int(ka != kb)
	return diff / maxf(1.0, uni)


func _clear_near(img: Image, p: Vector2, r: float) -> bool:
	## Is any pixel within r px of p (px) clear (or off the image)?
	for y in range(int(p.y - r), int(p.y + r) + 1):
		for x in range(int(p.x - r), int(p.x + r) + 1):
			if Vector2(x + 0.5, y + 0.5).distance_to(p) > r:
				continue
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height() or img.get_pixel(x, y).a < 0.5:
				return true
	return false


# How much of each trim the player sees, the rig composed at one px per frame
# unit as wick_rig.gd poses it: every part drawn after the cape laid over the
# trim. Three poses: at rest; the run's stride (the cape flared 0.35, arms
# and legs swinging, averaged over eight steps of it); and the Look tab's
# preview, standing with the cape flared 0.8 as in a fall (look_panel.gd
# holds it there with a kit pose {"cape": -0.8}). Floors: the share of the
# trim's white in sight, and the px of it at the Look tab's 2x.
const TRIM_RUN := 0.35
const TRIM_LOOK := 0.8
# At rest Waxby's shield and the Sexton's coat hide the whole cape (1-2% of
# it shows), so only the three whose capes show at rest are held to it.
# The founder's braids and wide tunic leave only her mantle's back corner in
# sight in any pose (8-15% of the cape), so her floors are the lowest.
const TRIM_REST_MIN := {"witch": 0.1, "runner": 0.7, "founder": 0.12}
const TRIM_RUN_MIN := {"knight": 0.15, "witch": 0.25, "runner": 0.8, "founder": 0.12, "sexton": 0.3}
const TRIM_LOOK_MIN := {"knight": 0.4, "witch": 0.4, "runner": 0.8, "founder": 0.2, "sexton": 0.5}
# px of trim in sight at the Look tab's 2x (one px a frame unit), at least
const TRIM_LOOK_PX := {"knight": 55, "witch": 45, "runner": 60, "founder": 20, "sexton": 50}
const OCC_WINDOW := Rect2i(12, 64, 76, 64)   # the cape's corner of the 128 frame: all a trim can reach


func _turned_into(dst: Image, src: Image, pivot: Vector2, at: Vector2, ang: float) -> void:
	## Marks dst (L8) where src, turned by ang about pivot with the pivot on
	## at, is opaque: over OCC_WINDOW only.
	var c := cos(ang)
	var s := sin(ang)
	for y in range(OCC_WINDOW.position.y, OCC_WINDOW.end.y):
		for x in range(OCC_WINDOW.position.x, OCC_WINDOW.end.x):
			var d := Vector2(x + 0.5, y + 0.5) - at
			var q := pivot + Vector2(d.x * c + d.y * s, -d.x * s + d.y * c)
			var qx := int(floor(q.x))
			var qy := int(floor(q.y))
			if qx < 0 or qy < 0 or qx >= src.get_width() or qy >= src.get_height():
				continue
			if src.get_pixel(qx, qy).a > 0.5:
				dst.set_pixel(x, y, Color.WHITE)


func _occluder(cls: String, pose: Dictionary) -> Image:
	## What the rig draws over the cape in a pose ({leg_b, leg_f, arm_b,
	## arm_f, lean}, radians as wick_rig.gd names them), at 128 px: the back
	## leg and arm, the offhand in the back hand, the body, the front leg, the
	## head and the front arm, each turned about its pivot, the upper body
	## shifted by the lean as the rig shifts it. (The weapon and the candle
	## are carried in front and above: never over the cape.)
	var rd := _rig_json(cls)
	var img := Image.create_empty(128, 128, false, Image.FORMAT_L8)
	var lean: float = pose.get("lean", 0.0)
	var shift := Vector2(lean * 10.0, 0.0)
	var arm_b: float = pose.get("arm_b", 0.0)
	var order := [["leg_back", pose.get("leg_b", 0.0), Vector2.ZERO], ["arm_back", arm_b, shift]]
	var off: bool = rd.get("offhand", false)
	var off_front: bool = rd.get("offhand_front", false)
	if off and not off_front:
		order.append(["offhand", arm_b, shift])
	order.append_array([["body", lean, shift], ["leg_front", pose.get("leg_f", 0.0), Vector2.ZERO], ["head", 0.0, shift * 2.0]])
	if off and off_front:
		order.append(["offhand", arm_b * 0.25, shift])
	order.append(["arm_front", pose.get("arm_f", 0.0), shift])
	for e in order:
		var part: String = e[0]
		var src := _rast("art/heroes/%s/%s.svg" % [cls, part], 0.5)
		if src == null:
			continue
		var pivot: Vector2 = PIVOTS[part]
		var at: Vector2 = pivot + e[2]
		if part == "offhand":
			# it rides in the back hand wherever the back arm swings it
			at = PIVOTS["arm_back"] + (HAND_BACK - PIVOTS["arm_back"]).rotated(arm_b) + e[2]
		_turned_into(img, src, pivot, at, e[1])
	return img


func _trim_seen(trim: Image, occ: Image, ang: float, shift := Vector2.ZERO) -> Vector2:
	## (white px of the trim in sight, white px of it) at 128 px, the trim
	## turned by ang about the cape's pivot under occ.
	var c := cos(ang)
	var s := sin(ang)
	var piv: Vector2 = PIVOTS["cape"]
	var n := 0
	var seen := 0
	for y in trim.get_height():
		for x in trim.get_width():
			var p := trim.get_pixel(x, y)
			if p.a < 0.8 or p.get_luminance() < 0.6:
				continue
			n += 1
			var d := Vector2(x + 0.5, y + 0.5) - piv
			var q := piv + Vector2(d.x * c - d.y * s, d.x * s + d.y * c) + shift
			var qx := int(floor(q.x))
			var qy := int(floor(q.y))
			if qx < 0 or qy < 0 or qx >= 128 or qy >= 128 or occ.get_pixel(qx, qy).r < 0.5:
				seen += 1
	return Vector2(seen, n)


func _test_trims_in_sight() -> void:
	var verbose := OS.get_environment("ART_VERBOSE") != ""
	for cls in CALLINGS:
		var rest := _occluder(cls, {})
		var stride := []
		for k in 8:
			var sn := sin(TAU * k / 8.0)
			stride.append(_occluder(cls, {"leg_b": 0.75 * sn, "leg_f": -0.75 * sn, "arm_b": -0.6 * sn,
					"arm_f": 0.35 * sn - 0.15, "lean": 0.07}))
		var line := "  %s trims in sight (rest / run / look):" % cls
		for pat in TRIM_PATTERNS:
			var trim := _rast("art/heroes/%s/cape_trim_%s.svg" % [cls, pat], 0.5)
			if trim == null:
				continue
			var n := "%s/cape_trim_%s" % [cls, pat]
			var at_rest := _trim_seen(trim, rest, 0.0)
			var run := 0.0
			for occ in stride:
				var v := _trim_seen(trim, occ, TRIM_RUN, Vector2(0.7, 0))
				run += v.x / maxf(v.y, 1.0) / stride.size()
			var look := _trim_seen(trim, rest, TRIM_LOOK)
			var rest_share := at_rest.x / maxf(at_rest.y, 1.0)
			var look_share := look.x / maxf(look.y, 1.0)
			line += "  %s %d/%d/%d%% (%d px)" % [pat, int(rest_share * 100), int(run * 100), int(look_share * 100), int(look.x)]
			if TRIM_REST_MIN.has(cls):
				_check(rest_share >= TRIM_REST_MIN[cls], "%s: shows at rest (%d%% of it in sight)" % [n, int(rest_share * 100)])
			_check(run >= TRIM_RUN_MIN[cls], "%s: shows in a run (%d%% of it in sight over the stride, want %d%%)" % [n, int(run * 100), int(TRIM_RUN_MIN[cls] * 100)])
			_check(look_share >= TRIM_LOOK_MIN[cls] and look.x >= TRIM_LOOK_PX[cls],
					"%s: shows in the Look tab's pose (%d%%, %d px at 2x)" % [n, int(look_share * 100), int(look.x)])
		if verbose:
			print(line)


func _test_logo_and_icon() -> void:
	var logo := _svg("art/ui/logo.svg")
	_check(_viewbox(logo) == PackedFloat32Array([0, 0, 1024, 400]), "the logo is 1024 x 400")
	_check(not logo.contains("<text") and not logo.contains("<filter"), "the logo is paths only")
	var img := _rast("art/ui/logo.svg")
	_check(img != null and img.get_size() == Vector2i(1024, 400), "the logo rasterizes at 1024 x 400")
	if img:
		_check(not _touches_edge(img), "the logo stays inside its frame")
	var icon := _svg("icon.svg")
	_check(_viewbox(icon) == PackedFloat32Array([0, 0, 1024, 1024]), "icon.svg is 1024 square")
	_check(not icon.contains("<text") and not icon.contains("<filter"), "icon.svg is paths only")
	var png := Image.new()
	var bytes := FileAccess.get_file_as_bytes("res://icons/icon_1024.png")
	if bytes.is_empty() or png.load_png_from_buffer(bytes) != OK:
		png = null
	_check(png != null and png.get_size() == Vector2i(1024, 1024), "icons/icon_1024.png is 1024 square")
	if png:
		_check(png.detect_alpha() == Image.ALPHA_NONE, "the app icon PNG is opaque (Apple rejects alpha)")
