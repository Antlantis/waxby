extends SceneTree
## A4's checks on the v3 boss art (tools/art/boss3.py .. boss6.py): Mother
## Gravebough, the Tinker of Hours, the Prism Saint and the Hush. Every frame,
## part and prop the contract names (contract.md §13) is there, is an SVG
## ThorVG can draw (no <text>, no filters) on its frame at 2 px a unit, stays
## inside it, stands on (or floats at) the right line, and imports as a
## texture of the right size; frames of 384 units and up import WITHOUT
## mipmaps (spec §11.5), and each boss's textures fit its budget (28 / 30 /
## 14 / 16 MB). The bosses read at phone scale (at least 96 x 128 px, spec
## §5.1; the Tinker's own frames); the engine points in each points_*.json
## sit on the art they name; and the few looks the fights rely on hold (the
## decoy blossom is violet and unlit, the lit hour bell is gold and the
## frosted one grey, the Tinker's spring shines gold only when he is Chimed,
## the dim mirror is darker, the Eye's almond is 3 tiles tall, the ring
## ledge is 3 tiles wide), and every window target and danger band sits where
## Waxby can use it (the Chimed spring in a standing slash's reach, the high
## Bough Sweep over his flame and under a row-10 ledge, Gravebough rooted clear
## of the vine lane, the Saint at her draw scale, the Grasp's art its column).
##
##     python3 tools/art/build.py boss3 boss4 boss5 boss6
##     godot --headless --path game --import
##     godot --headless --path game --script res://tests/test_boss_art.gd

const E := "art/enemies/"
const SOLID := 0.5
const MB := 1000000.0

# every texture each boss ships, and its frame (viewBox units)
const GRAVEBOUGH := {
	"rootmother_idle": [384, 384], "rootmother_dig": [384, 384], "rootmother_sweep_low": [384, 384],
	"rootmother_sweep_high": [384, 384], "rootmother_breath": [384, 384], "rootmother_hollow": [384, 384],
	"rootmother_hurt": [384, 384], "rootmother_wilt": [384, 384], "rootmother_bare": [384, 384], "rootmother_die": [384, 384],
	"rootmother_bough1": [224, 96], "rootmother_bough2": [224, 96], "rootmother_bough3": [224, 96], "rootmother_legs": [384, 128],
	"bloom_bud": [64, 64], "bloom_open": [64, 64], "bloom_decoy": [64, 64], "root_spear": [64, 128],
	"skull_seed": [64, 64], "thorn": [64, 64], "root_hump": [128, 64],
}
const TINKER := {
	"tinker_idle": [384, 384], "tinker_walk1": [384, 384], "tinker_walk2": [384, 384], "tinker_toss": [384, 384],
	"tinker_swing": [384, 384], "tinker_watch": [384, 384], "tinker_chimed": [384, 384], "tinker_rewind": [384, 384],
	"tinker_overwind": [384, 384], "tinker_die": [384, 384],
	"clock_face": [576, 576], "hour_bell_frozen": [64, 96], "hour_bell_lit": [64, 96], "gear_saw": [64, 64],
	"hour_hand": [96, 32], "soldier_hatch": [64, 32],
}
const SAINT := {
	"saint_idle": [256, 256], "saint_charge": [256, 256], "saint_beam": [256, 256], "saint_rose": [256, 256],
	"saint_sing": [256, 256], "saint_refracted": [256, 256], "saint_hurt": [256, 256], "saint_split": [256, 256],
	"saint_die": [256, 256], "saint_halo": [256, 256], "halo_shard": [64, 32], "saint_shard_red": [128, 128],
	"saint_shard_gold": [128, 128], "saint_shard_blue": [128, 128], "mirror_shard": [64, 128], "mirror_shard_dim": [64, 128],
}
const HUSH := {
	"hush_eye_open": [512, 256], "hush_eye_half": [512, 256], "hush_eye_shut": [512, 256], "hush_eye_wince": [512, 256],
	"hush_pupil": [64, 64], "hush_eye_small": [96, 48], "hush_hand_rise": [256, 256], "hush_hand_grasp": [256, 256], "hush_hand_splay": [256, 256],
	"hush_hand_sink": [256, 256], "hush_core": [128, 128], "stolen_flame": [64, 64], "sunken_bell": [64, 96],
	"sunken_bell_smothered": [64, 96], "ring_ledge": [192, 64],
}
const BUDGETS := {"Gravebough": 28.0, "the Tinker": 30.0, "the Saint": 14.0, "the Hush": 16.0}
# art that is meant to touch an edge of its frame: standing props on the bottom
const TOUCH_OK := {
	"root_spear": ["bottom", "top"], "root_hump": ["bottom", "top"], "bloom_bud": ["bottom"], "bloom_open": ["bottom"],
	"bloom_decoy": ["bottom"],
}

var _passed := 0
var _failed := 0
var _img := {}


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", what)


func _initialize() -> void:
	_test_set("Gravebough", GRAVEBOUGH)
	_test_set("the Tinker", TINKER)
	_test_set("the Saint", SAINT)
	_test_set("the Hush", HUSH)
	_test_gravebough()
	_test_tinker()
	_test_saint()
	_test_hush()
	print("test_boss_art: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# ---------------------------------------------------------------- helpers

func _text(rel: String) -> String:
	return FileAccess.get_file_as_string("res://" + rel)


func _header(text: String) -> Dictionary:
	var re := RegEx.create_from_string('width="(\\d+)" height="(\\d+)" viewBox="0 0 (\\d+) (\\d+)"')
	var m := re.search(text)
	if m == null:
		return {}
	return {"w": int(m.get_string(1)), "h": int(m.get_string(2)), "vw": int(m.get_string(3)), "vh": int(m.get_string(4))}


# the art at 1 px per frame unit (cached)
func _raster(name: String) -> Image:
	if _img.has(name):
		return _img[name]
	var text := _text(E + name + ".svg")
	var img := Image.new()
	if text == "" or img.load_svg_from_string(text, 0.5) != OK:
		_img[name] = null
		return null
	img.convert(Image.FORMAT_RGBA8)
	_img[name] = img
	return img


func _bbox(img: Image, solid: float = SOLID, region := Rect2i()) -> Rect2i:
	var r := region if region.size != Vector2i.ZERO else Rect2i(0, 0, img.get_width(), img.get_height())
	var x0 := r.end.x
	var y0 := r.end.y
	var x1 := -1
	var y1 := -1
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
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


func _near_art(img: Image, p: Vector2, r: int) -> bool:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var q := Vector2i(int(p.x) + dx, int(p.y) + dy)
			if q.x >= 0 and q.y >= 0 and q.x < img.get_width() and q.y < img.get_height() and img.get_pixel(q.x, q.y).a > 0.3:
				return true
	return false


# the average colour of the drawn pixels in a region (frame units)
func _mean(img: Image, r: Rect2i, solid: float = SOLID) -> Color:
	var s := Color(0, 0, 0, 0)
	var n := 0
	var rr := r.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	for y in range(rr.position.y, rr.end.y):
		for x in range(rr.position.x, rr.end.x):
			var c := img.get_pixel(x, y)
			if c.a >= solid:
				s += Color(c.r, c.g, c.b, 1)
				n += 1
	return Color(s.r / maxf(1, n), s.g / maxf(1, n), s.b / maxf(1, n), float(n))


# how many drawn pixels in a region pass a colour test
func _count(img: Image, r: Rect2i, ok: Callable) -> int:
	var n := 0
	var rr := r.intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	for y in range(rr.position.y, rr.end.y):
		for x in range(rr.position.x, rr.end.x):
			var c := img.get_pixel(x, y)
			if c.a >= SOLID and ok.call(c):
				n += 1
	return n


func _json(name: String) -> Dictionary:
	var text := _text(E + name)
	_check(text != "", "%s exists" % name)
	var d = JSON.parse_string(text) if text != "" else null
	_check(d is Dictionary, "%s parses" % name)
	return d if d is Dictionary else {}


func _v(a) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


# ---------------------------------------------------------------- every file

func _test_set(who: String, files: Dictionary) -> void:
	var bytes := 0.0
	for name in files:
		var rel: String = E + name + ".svg"
		var vw: int = files[name][0]
		var vh: int = files[name][1]
		var text := _text(rel)
		_check(text != "", "%s exists" % rel)
		if text == "":
			continue
		_check(not text.contains("<text") and not text.contains("<filter"), "%s has no <text> or <filter>" % rel)
		var hd := _header(text)
		_check(hd.get("vw", 0) == vw and hd.get("vh", 0) == vh and hd.get("w", 0) == vw * 2 and hd.get("h", 0) == vh * 2,
			"%s is a %dx%d frame at 2 px a unit (got %s)" % [rel, vw, vh, hd])
		var img := _raster(name)
		_check(img != null, "%s rasterizes" % rel)
		if img == null:
			continue
		var bb := _bbox(img)
		_check(bb.size.x * bb.size.y > vw * vh / 40, "%s has real art in it (%s)" % [rel, bb])
		var allowed: Array = TOUCH_OK.get(name, [])
		var touching := _edges(img)
		for side in touching:
			_check(side in allowed, "%s stays inside its frame (touches the %s)" % [rel, side])
		for side in allowed:
			_check(side in touching, "%s reaches its %s edge (it stands there)" % [rel, side])
		# imported at the right size; big frames without mipmaps
		var path := "res://" + rel
		_check(ResourceLoader.exists(path), "%s is imported (run --import)" % rel)
		var mips := true
		if ResourceLoader.exists(path):
			var tex = load(path)
			_check(tex is Texture2D and tex.get_width() == vw * 2 and tex.get_height() == vh * 2,
				"%s loads as a %dx%d texture" % [rel, vw * 2, vh * 2])
			if tex is Texture2D:
				mips = tex.get_image().has_mipmaps()
		var imp := FileAccess.get_file_as_string(path + ".import")
		if maxi(vw, vh) >= 384:
			_check(imp.contains("mipmaps/generate=false") and not mips,
				"%s (a %d-unit frame) imports without mipmaps" % [rel, maxi(vw, vh)])
		bytes += vw * 2 * vh * 2 * 4 * (4.0 / 3.0 if mips else 1.0)
	var mb := bytes / MB
	print("   %s: %.2f MB of textures (budget %d MB)" % [who, mb, BUDGETS[who]])
	_check(mb <= BUDGETS[who], "%s's textures fit %d MB (%.2f MB)" % [who, BUDGETS[who], mb])


# every point named in a points file sits on (or right by) the art of its frame
func _test_points(pts: Dictionary, frames: Array, keys: Array, loose: Array = []) -> void:
	for fr in frames:
		_check(pts.has(fr), "the points name %s" % fr)
		if not pts.has(fr):
			continue
		var row: Dictionary = pts[fr]
		for k in keys:
			_check(row.has(k), "%s says where its %s is" % [fr, k])
		var img := _raster(fr)
		if img == null:
			continue
		for k in row:
			var v = row[k]
			if not (v is Array and v.size() == 2 and not (v[0] is Array)):
				continue
			var p := _v(v)
			var inside := p.x >= 0 and p.y >= 0 and p.x <= img.get_width() and p.y <= img.get_height()
			_check(inside, "%s.%s %s is inside the frame" % [fr, k, p])
			if inside and not (k in loose):
				_check(_near_art(img, p, 6), "%s.%s %s sits on its art" % [fr, k, p])


func _stands(name: String, y: int, lo := 4, hi := 10) -> void:
	var img := _raster(name)
	if img == null:
		return
	var bb := _bbox(img)
	_check(bb.end.y >= y - lo and bb.end.y <= y + hi, "%s stands on y %d (lowest drawn row %d)" % [name, y, bb.end.y])


# ---------------------------------------------------------------- Gravebough

func _test_gravebough() -> void:
	var pts := _json("points_rootmother.json")
	var frames := []
	for n in GRAVEBOUGH:
		if n.begins_with("rootmother_") and not n.begins_with("rootmother_bough") and n != "rootmother_legs":
			frames.append(n)
	for fr in frames:
		_stands(fr, 368)
	_check(pts.get("_anchor", []) == [192, 368] or (pts.has("_anchor") and _v(pts["_anchor"]) == Vector2(192, 368)),
		"points_rootmother.json anchors her at (192, 368)")
	_test_points(pts, frames, ["heart", "eye_l", "eye_r", "face", "mouth", "crown", "bough", "trunk"], ["bough"])
	var idle := _raster("rootmother_idle")
	if idle:
		var bb := _bbox(idle, 0.97)
		# colossal: over 3 x Waxby (about 50 px) and well past the 96 x 128 px floor
		_check(bb.size.y >= 300 and bb.size.x >= 220, "Gravebough stands %d units tall and %d wide (at least 300 x 220)" % [bb.size.y, bb.size.x])
	# the sweep frames leave the near arm out (the bough parts are it)
	for fr in ["rootmother_sweep_low", "rootmother_sweep_high"]:
		var img := _raster(fr)
		if img and pts.has(fr):
			var sh := _v(pts[fr]["bough"])
			var right := _bbox(img, SOLID, Rect2i(int(sh.x) + 40, int(sh.y) - 10, 384 - int(sh.x) - 40, 60))
			_check(right.size.x * right.size.y < 200, "%s has no bough arm drawn past its shoulder (%s)" % [fr, right])
	# the hollow frame's chest is dark: the ember left
	var hol := _raster("rootmother_hollow")
	if idle and hol and pts.has("rootmother_idle") and pts.has("rootmother_hollow"):
		var hi := _v(pts["rootmother_idle"]["heart"])
		var hh := _v(pts["rootmother_hollow"]["heart"])
		var a := _count(idle, Rect2i(int(hi.x) - 20, int(hi.y) - 30, 40, 50), func(c: Color): return c.b > 0.8 and c.b > c.r + 0.15)
		var b := _count(hol, Rect2i(int(hh.x) - 20, int(hh.y) - 30, 40, 50), func(c: Color): return c.b > 0.8 and c.b > c.r + 0.15)
		_check(a >= 60, "the caged ember glows cold blue (%d px)" % a)
		_check(b <= a / 10, "rootmother_hollow's chest is dark: the ember left (%d px of blue)" % b)
	# the bough: a chain of 52-unit roots, pivot and joint on the art
	var bough: Dictionary = pts.get("_bough", {})
	_check(bough.has("pivot") and bough.has("joint") and bough.has("poses"), "points_rootmother.json describes the bough")
	for n in ["rootmother_bough1", "rootmother_bough2", "rootmother_bough3"]:
		var img := _raster(n)
		if img == null or not bough.has("pivot"):
			continue
		_check(_near_art(img, _v(bough["pivot"]), 2), "%s's pivot is on it" % n)
		if n != "rootmother_bough3":
			_check(_near_art(img, _v(bough["joint"]), 2), "%s's joint is on it" % n)
			var col := _bbox(img, SOLID, Rect2i(164, 0, 4, 96))
			_check(col.size.y >= 52 and col.size.y <= 68, "%s is about 52 units thick (%d with its ink)" % [n, col.size.y])
	var poses: Dictionary = bough.get("poses", {})
	for k in ["sweep_low_tell", "sweep_high_tell", "sweep_low_strike", "sweep_high_strike",
			"sweep_low_tell_p3", "sweep_high_tell_p3", "sweep_low_strike_p3", "sweep_high_strike_p3"]:
		_check(poses.has(k) and poses[k].get("chain", []).size() >= 3, "the bough has a %s pose" % k)
	if poses.has("sweep_low_tell") and poses.has("sweep_high_tell"):
		_check(float(poses["sweep_low_tell"]["chain"][0][1]) > 0 and float(poses["sweep_high_tell"]["chain"][0][1]) < 0,
			"the low sweep's tell drops the arm and the high one raises it")
	# the strikes lie on their bands, and the bands read: the high one over a standing
	# Waxby's candle flame (about 60 px) and under a row-10 ledge's top (96 px)
	var b2 := _raster("rootmother_bough2")
	if b2 and bough.has("pivot"):
		var bb2 := _bbox(b2, SOLID)
		var up := (float(bough["pivot"][1]) - bb2.position.y) / 2.0
		var down := (bb2.end.y - float(bough["pivot"][1])) / 2.0
		_check(up <= 16.5 and down <= 16.5, "the bough's art stays near its 28 px band (%.1f px up, %.1f down, with its knots and rim)" % [up, down])
		for k in ["sweep_high_strike", "sweep_high_strike_p3"]:
			if poses.has(k):
				var c := float(poses[k]["band_px"])
				var th := float(poses[k].get("thick", 1.0))
				var hurt := float(poses[k].get("hurt_px", 28.0))
				# a standing Waxby's flame tops out at 66..80 px by calling (the Candleknight's 73, the
				# Bellfounder's 77); a row-10 ledge's top is 96 px up; his hitbox is 38 px
				_check(c - down * th >= 76.0 and c + up * th <= 96.0,
					"%s's art runs %.1f..%.1f px: over Waxby's flame, under a row-10 ledge" % [k, c - down * th, c + up * th])
				_check(c - hurt / 2.0 > 38.0 and c + hurt / 2.0 < 96.0,
					"%s's hurt band (%.0f..%.0f px) misses a standing Waxby and one on a row-10 ledge" % [k, c - hurt / 2.0, c + hurt / 2.0])
		for k in ["sweep_low_strike", "sweep_low_strike_p3"]:
			if poses.has(k):
				var c := float(poses[k]["band_px"])
				_check(c - down >= -1.5 and c + up <= 32.0, "%s's art hugs the floor (%.1f..%.1f px)" % [k, c - down, c + up])
		for k in poses:
			if not poses[k].has("band_px") or not pts.has(poses[k]["frame"]):
				continue
			var y := float(pts[poses[k]["frame"]]["bough"][1]) - float(poses[k].get("rise", 0))
			for link in poses[k]["chain"]:
				y += sin(deg_to_rad(float(link[1]))) * (float(bough["joint"][0]) - float(bough["pivot"][0]))
			_check(absf((368.0 - y) / 2.0 - float(poses[k]["band_px"])) < 1.0, "%s ends on its band (%.1f px)" % [k, (368.0 - y) / 2.0])
	# Spore Breath: the tell swells her (the face and hood wider) and only it shows W3's chartreuse
	var br := _raster("rootmother_breath")
	if idle and br:
		var spore := func(c: Color): return absf(c.r - 0.78) < 0.12 and absf(c.g - 0.83) < 0.12 and c.b < 0.6 and c.g > c.b + 0.25
		var a := _count(br, Rect2i(0, 0, 384, 384), spore)
		var b := _count(idle, Rect2i(0, 0, 384, 384), spore)
		_check(a >= 600 and b == 0, "Spore Breath fans out chartreuse gill fins (%d px; idle %d)" % [a, b])
		if pts.has("rootmother_breath") and pts.has("rootmother_idle"):
			var fb := _v(pts["rootmother_breath"]["face"])
			var fi := _v(pts["rootmother_idle"]["face"])
			var wb := _bbox(br, SOLID, Rect2i(0, int(fb.y) - 10, 384, 20)).size.x
			var wi := _bbox(idle, SOLID, Rect2i(0, int(fi.y) - 10, 384, 20)).size.x
			_check(wb >= wi + 24, "her head swells for the breath (%d units across the face vs %d)" % [wb, wi])
	# P3: every frame lifts a tile over the stilt legs
	var p3: Dictionary = pts.get("_p3", {})
	_check(float(p3.get("rise", 0)) == 64.0 and p3.get("legs", "") == "rootmother_legs", "points_rootmother.json lifts every P3 frame a tile over rootmother_legs")
	var legs := _raster("rootmother_legs")
	if legs:
		var lb := _bbox(legs, SOLID)
		_check(lb.end.y >= 108 and lb.end.y <= 120 and lb.size.x >= 280, "rootmother_legs stands on its floor (y 112) and spreads wide (%s)" % lb)
		_check(lb.position.y >= 8 and lb.position.y <= 48, "the stilts reach up under her lifted trunk (top y %d)" % lb.position.y)
	# rooted clear of the col-25 vine lane at the anchor points_rootmother.json gives
	var place: Dictionary = pts.get("_placement", {})
	_check(place.has("anchor_x_r_arena"), "points_rootmother.json says where to root her")
	if place.has("anchor_x_r_arena"):
		var ax := float(place["anchor_x_r_arena"])
		for fr in frames + ["rootmother_legs"]:
			var img := _raster(fr)
			if img == null:
				continue
			var near := (_bbox(img, 0.3).end.x - 192) / 2.0
			_check(ax - near >= 848.0, "%s at her placement stays clear of the col-25 vine lane (nearest x %.0f)" % [fr, ax - near])
			if fr != "rootmother_legs" and pts.has(fr):
				var tb: Array = pts[fr]["trunk"]
				_check(ax - (float(tb[0]) + float(tb[2]) - 192) / 2.0 <= 916.0,
					"%s's trunk is in a slash's reach of Waxby at the wall face (front x %.0f)" % [fr, ax - (float(tb[0]) + float(tb[2]) - 192) / 2.0])
	# the blossoms: the open one amber and lit, the decoy violet and unlit, the box the 28 px blossom box
	var op := _raster("bloom_open")
	var de := _raster("bloom_decoy")
	var props: Dictionary = pts.get("_props", {})
	if op and de:
		var a := _mean(op, Rect2i(8, 4, 48, 48))
		var b := _mean(de, Rect2i(8, 4, 48, 48))
		_check(a.r > a.b + 0.3, "bloom_open is amber (%s)" % a)
		_check(b.b > b.g and b.b > 0.5, "bloom_decoy is violet (%s)" % b)
		_check(a.get_luminance() > b.get_luminance(), "bloom_open is brighter than the decoy")
		if props.has("bloom_open"):
			var box: Array = props["bloom_open"]["box"]
			var fl := _bbox(op, SOLID, Rect2i(0, 0, 64, 50))
			_check(absi(fl.position.x - int(box[0])) <= 5 and absi(fl.end.x - int(box[0]) - int(box[2])) <= 5,
				"bloom_open's petals fill its box across (%s vs %s)" % [fl, box])
	var sp := _raster("root_spear")
	if sp:
		var mid := _bbox(sp, SOLID, Rect2i(0, 60, 64, 4))
		_check(mid.size.x >= 50 and mid.size.x <= 64, "root_spear is the 26 px pillar (%d units across)" % mid.size.x)
		var top := _bbox(sp)
		_check(top.position.y <= 2, "root_spear is the whole 64 px pillar, its cap at the top (y %d)" % top.position.y)
		if props.has("root_spear"):
			var body: Array = props["root_spear"]["body"]
			_check(int(body[3]) == 128 and int(body[2]) == 52, "root_spear's body is 26 x 64 px (%s)" % [body])
	var hump := _raster("root_hump")
	if hump:
		var hb := _bbox(hump)
		_check(hb.position.y <= 3 and hb.size.x >= 110, "root_hump is a full tile tall and nearly two wide (%s)" % hb)
		var gap := 0
		for x in [24, 40, 64, 88, 104]:
			for y in range(8, 60, 4):
				if hump.get_pixel(x, y).a < SOLID:
					gap += 1
		_check(gap == 0, "root_hump is solid, with nothing to walk under (%d gaps)" % gap)
	for n in ["rootmother_idle", "rootmother_bough1", "bloom_open"]:
		_check(_text(E + n + ".svg").to_lower().contains("#ffeccc"), "%s has the family's candlelit sticker rim" % n)


# ---------------------------------------------------------------- the Tinker

func _test_tinker() -> void:
	var pts := _json("points_tinker.json")
	var frames := []
	for n in TINKER:
		if n.begins_with("tinker_"):
			frames.append(n)
	for fr in frames:
		_stands(fr, 368)
	_test_points(pts, frames, ["spring", "spring_box", "face", "key", "hand_l", "hand_r", "case"], ["key"])
	var idle := _raster("tinker_idle")
	if idle:
		var bb := _bbox(idle, 0.97)
		_check(bb.size.x >= 192 and bb.size.y >= 256, "the Tinker is at least 96 x 128 px (%d x %d units)" % [bb.size.x, bb.size.y])
	# Chimed: fallen forward (lower and wider than he stands), the spring the brightest gold on him
	var ch := _raster("tinker_chimed")
	if idle and ch:
		var a := _bbox(idle, 0.97)
		var b := _bbox(ch, 0.97)
		_check(b.position.y > a.position.y + 25 and b.size.x > b.size.y, "tinker_chimed lies fallen forward, lower and wider than he stands (%s vs %s)" % [b, a])
		if pts.has("tinker_chimed") and pts.has("tinker_idle"):
			var gold := func(c: Color): return c.r > 0.92 and c.g > 0.78 and c.b < 0.75
			var s := _v(pts["tinker_chimed"]["spring"])
			var si := _v(pts["tinker_idle"]["spring"])
			var lit := _count(ch, Rect2i(int(s.x) - 16, int(s.y) - 16, 32, 32), gold)
			var dim := _count(idle, Rect2i(int(si.x) - 16, int(si.y) - 16, 32, 32), gold)
			_check(lit >= 150, "the Chimed spring shines gold (%d bright px round it)" % lit)
			_check(dim * 4 <= lit, "the spring lights up only when Chimed (%d px standing, %d Chimed)" % [dim, lit])
			# the window's target is where every hero can hit it: a standing slash covers 8..42 px
			# over the floor, a floor wave 14..22 px, a stomp comes down on its top from a jump
			var up := (368.0 - s.y) / 2.0
			var box: Array = pts["tinker_chimed"]["spring_box"]
			var lo := (368.0 - float(box[1]) - float(box[3])) / 2.0
			var hi := (368.0 - float(box[1])) / 2.0
			_check(up <= 40.0, "the Chimed spring is %.0f px over the floor (a standing slash reaches it)" % up)
			_check(lo <= 1.0 and hi >= 22.0 and hi <= 44.0, "the Chimed spring's box spans %.0f..%.0f px: slash, floor wave and stomp" % [lo, hi])
			_check(absf(float(box[0]) + float(box[2]) / 2.0 - 192.0) <= 40.0, "the Chimed spring lies by his anchor (x %.0f)" % (float(box[0]) + float(box[2]) / 2.0))
	# the hour bells: lit is gold, frosted is grey-blue and paler
	var lit := _raster("hour_bell_lit")
	var fro := _raster("hour_bell_frozen")
	if lit and fro:
		var a := _mean(lit, Rect2i(8, 16, 48, 64))
		var b := _mean(fro, Rect2i(8, 16, 48, 64))
		_check(a.r > a.b + 0.25, "hour_bell_lit is gold (%s)" % a)
		_check(b.b >= b.r and absf(b.r - b.g) < 0.15, "hour_bell_frozen is frosted grey-blue (%s)" % b)
	var cf := _raster("clock_face")
	if cf:
		var bb := _bbox(cf)
		_check(bb.size.x >= 520, "clock_face is a great frozen face over 8 tiles across (%d units)" % bb.size.x)


# ---------------------------------------------------------------- the Saint

func _test_saint() -> void:
	var pts := _json("points_saint.json")
	var frames := []
	for n in SAINT:
		if n.begins_with("saint_") and not n in ["saint_halo", "saint_shard_red", "saint_shard_gold", "saint_shard_blue"]:
			frames.append(n)
	_test_points(pts, frames, ["mask", "halo_center", "prism", "heart"], ["halo_center"])
	# she floats: her gown's point is the anchor (128, 244)
	for fr in frames:
		if fr in ["saint_split", "saint_die"]:
			continue
		_stands(fr, 244, 10, 8)
	var idle := _raster("saint_idle")
	var halo := _raster("saint_halo")
	if idle and halo and pts.has("saint_idle"):
		var a := _bbox(idle, 0.97)
		var h := _bbox(halo, 0.5)
		# her halo drawn behind her head (its centre (128, 128) on halo_center): together they read at phone scale
		var hc := _v(pts["saint_idle"]["halo_center"])
		var top := mini(a.position.y, int(hc.y) - (128 - h.position.y))
		var both := Vector2i(maxi(a.size.x, h.size.x), a.end.y - top)
		_check(a.size.y >= 220, "the Saint is about 2.3 x Waxby tall (%d units)" % a.size.y)
		# at the draw scale the fight must use, her solid glass and the halo's solid rose read at phone scale
		var k := float(pts.get("_draw_scale", 1.0))
		var rim := float(pts.get("_parts", {}).get("saint_halo", {}).get("rim_r", 90))
		# the halo's solid radius: the largest ring round its centre that is 90% opaque (not the thin ray tips)
		var solid_r := 0
		for r in range(40, 128):
			var n := 0
			for i in 360:
				var q := Vector2(128, 128) + Vector2.from_angle(deg_to_rad(i)) * r
				if halo.get_pixel(clampi(int(q.x), 0, 255), clampi(int(q.y), 0, 255)).a >= 0.97:
					n += 1
			if n >= 324:
				solid_r = r
		_check(absf(solid_r - rim) <= 4, "saint_halo's solid rose reaches r %d (rim_r %d)" % [solid_r, rim])
		var solid := Vector2(maxf(a.size.x, solid_r * 2), a.end.y - minf(a.position.y, hc.y - solid_r)) * k
		_check(k >= 1.1 and k <= 1.2, "points_saint.json has the Saint drawn at %.2f (sharp up to about 1.18)" % k)
		_check(a.size.y * k >= 256, "the Saint alone is %.0f px tall at her draw scale (at least 128)" % (a.size.y * k / 2.0))
		_check(solid.x >= 192 and solid.y >= 256, "the Saint with her halo's solid rose is %s px at her draw scale (at least 96 x 128)" % (solid / 2.0))
	# Tessel's pane is never covered by the prism, and her candle is lit in it
	var bright := func(c: Color): return c.r > 0.93 and c.g > 0.78 and c.b > 0.45
	for fr in frames:
		if not pts.has(fr):
			continue
		var hp := _v(pts[fr]["heart"])
		var pp := _v(pts[fr]["prism"])
		_check(absf(pp.y - hp.y) >= 26.0 or absf(pp.x - hp.x) >= 30.0, "%s holds the prism clear of Tessel's pane (heart %s, prism %s)" % [fr, hp, pp])
		var img := _raster(fr)
		if img:
			var n := _count(img, Rect2i(int(hp.x) - 4, int(hp.y) - 13, 8, 10), bright)
			_check(n >= 12, "%s shows Tessel's candle flame in her heart (%d bright px)" % [fr, n])
		var bx: Array = pts[fr]["body"]
		var br := Rect2(float(bx[0]), float(bx[1]), float(bx[2]), float(bx[3]))
		_check(br.has_point(_v(pts[fr]["mask"])) and br.has_point(hp), "%s's body box holds her mask and heart" % fr)
	if pts.has("saint_idle") and pts.has("saint_refracted"):
		_check(pts["saint_idle"]["body"] != pts["saint_refracted"]["body"], "each Saint frame has its own body box")
	var m := _raster("mirror_shard")
	var md := _raster("mirror_shard_dim")
	if m and md:
		var bb := _bbox(m, 0.9)
		_check(absi(bb.size.x - 32) <= 8 and absi(bb.size.y - 112) <= 10, "mirror_shard is a 16 x 56 px pane (%s)" % bb)
		_check(_mean(md, bb).get_luminance() < _mean(m, bb).get_luminance() - 0.1, "mirror_shard_dim is dimmer")
	var sh := _raster("halo_shard")
	if sh:
		var c := _mean(sh, Rect2i(0, 0, 64, 32))
		_check(c.get_luminance() > 0.7 and absf(c.r - c.b) < 0.12, "halo_shard is white (the engine tints it) (%s)" % c)


# ---------------------------------------------------------------- the Hush

func _test_hush() -> void:
	var pts := _json("points_hush.json")
	for n in ["hush_eye_open", "hush_eye_half", "hush_eye_shut", "hush_eye_wince"]:
		var img := _raster(n)
		if img == null:
			continue
		var bb := _bbox(img, 0.9)
		_check(bb.size.x >= 400, "%s is a wide almond (%s)" % [n, bb])
	var eye := _raster("hush_eye_open")
	if eye:
		var bb := _bbox(eye, 0.9)
		_check(absi(bb.size.y - 192) <= 24, "the Eye opens 3 tiles tall (%d units)" % bb.size.y)
		if pts.has("_eye"):
			var c := _v(pts["_eye"]["iris_center"])
			var col := _mean(eye, Rect2i(int(c.x) - 30, int(c.y) - 30, 60, 60))
			_check(col.b > col.g and col.get_luminance() > 0.35, "the iris is pale violet (%s)" % col)
	var sh := _raster("hush_eye_shut")
	if eye and sh:
		_check(_mean(sh, Rect2i(156, 64, 200, 128)).get_luminance() < _mean(eye, Rect2i(156, 64, 200, 128)).get_luminance() - 0.2,
			"the shut Eye is dark where the open one is pale")
	var small := _raster("hush_eye_small")
	if small:
		var sb := _bbox(small, 0.9)
		_check(sb.size.x >= 64 and sb.size.x <= 84, "hush_eye_small is P1's Eye, a tile across (%d units)" % sb.size.x)
		var tex = load("res://" + E + "hush_eye_small.svg")
		_check(tex is Texture2D and tex.get_image().has_mipmaps(), "hush_eye_small keeps its mipmaps (it swims small)")
	if pts.has("_pupil") and pts.has("_eye"):
		_check(float(pts["_pupil"]["r"]) <= float(pts["_eye"]["iris_r"]) * 0.25, "the pupil is small, as v2's post-credits Eye's")
		_check(not String(pts["_eye"].get("note", "")).contains("0.07"), "the Eye's note no longer shrinks the unmipmapped frames for P1")
	var hands := ["hush_hand_rise", "hush_hand_grasp", "hush_hand_splay", "hush_hand_sink"]
	_test_points(pts, hands, ["wrist", "tips"], ["tips"])
	# the Grasp's hands are drawn inside its 40 x 64 px column: what you see is what hurts
	var col: Array = pts.get("_hand", {}).get("grasp_column", [88, 116, 80, 128])
	var cr := Rect2i(int(col[0]) - 6, int(col[1]) - 6, int(col[2]) + 12, int(col[3]) + 12)
	for n in ["hush_hand_rise", "hush_hand_grasp", "hush_hand_sink"]:
		var img := _raster(n)
		if img == null:
			continue
		var above := _bbox(img, SOLID, Rect2i(0, 0, 256, 238))
		_check(cr.encloses(above), "%s is drawn inside the Grasp's column (%s in %s)" % [n, above, cr])
	var spl := _raster("hush_hand_splay")
	if spl:
		_check(_bbox(spl, SOLID).size.x >= 220, "hush_hand_splay spreads as wide as its frame for the Snuff (%d units)" % _bbox(spl, SOLID).size.x)
	for n in hands:
		var img := _raster(n)
		if img == null:
			continue
		var bb := _bbox(img, 0.9)
		var c := _mean(img, bb)
		_check(c.get_luminance() < 0.3, "%s is black (%s)" % [n, c])
		_check(_text(E + n + ".svg").to_lower().contains("#c8c8f0"), "%s has the silver rim" % n)
	if pts.has("_splay_outline"):
		_check(pts["_splay_outline"].size() >= 12, "the palm outline for the Snuff's tell is in points_hush.json")
	var bell := _raster("sunken_bell")
	var smo := _raster("sunken_bell_smothered")
	if bell and smo:
		_check(_mean(smo, Rect2i(0, 0, 64, 96)).get_luminance() < _mean(bell, Rect2i(0, 0, 64, 96)).get_luminance() - 0.08,
			"sunken_bell_smothered is darker (the ooze)")
	var ring := _raster("ring_ledge")
	if ring:
		var bb := _bbox(ring, 0.3)
		_check(absi(bb.size.x - 192) <= 12, "ring_ledge is 3 tiles wide (%d units)" % bb.size.x)
		var c := _mean(ring, bb, 0.3)
		_check(c.b >= c.r - 0.02 and c.get_luminance() > 0.6, "ring_ledge is cold and pale (%s)" % c)
