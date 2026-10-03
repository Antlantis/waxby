extends SceneTree
## A3's checks on the v3 monster art (tools/art/enemies3.py for Worlds 3-4 and
## enemies4.py for Worlds 5-6, contract.md §13 and spec §11.5): every frame the
## contract names is there, ThorVG can draw it (no <text>, no filters), it is a
## 128-unit frame at 2 px a unit, stays inside its frame, stands on its line
## (feet on y 122) or floats round its middle (64, 64), imports as a 256 x 256
## texture; no kind has more than 10 frames; the points files name every
## frame's eyes and hit box, and every point sits on its art; the eyes read in
## the dark (a hot highlight on a dark socket, big enough on W6); each world's
## family rim (warm ffeccc, W6 silver c8c8f0); the grinder rim e0602a is the
## Spurwheel's alone; the tinted glass kinds are drawn neutral for `modulate`;
## the rime overlay is see-through; the owl's heads sit on its body; the
## Paneguard is thin edge-on; the Creepbone is drawn vertical and stands on
## the feet line; `eyes` lists the lit eyes' points; each world's tell accent
## (by colour distance, not only its hex) stays off every frame but its tells,
## and every tell changes the outline; the turning Spurwheel and the aiming
## Refractor draw nothing that points a way; the Lurecoil has candle-less heads.
##
##     python3 tools/art/build.py enemies3 enemies4
##     godot --headless --path game --import
##     godot --headless --path game --script res://tests/test_monster_art3.gd

# kind prefix -> [frames, anchor kind]: feet (64, 122), middle (64, 64)
const KINDS := {
	"rootling": [["mound", "swell", "pop", "dazed", "walk1", "walk2", "hit"], "feet"],
	"weepcap": [["idle", "inhale", "puff", "hit", "die"], "feet"],
	"hound": [["prowl1", "prowl2", "howl", "run1", "run2", "crouch", "pounce", "land", "pant", "hit"], "feet"],
	"creep": [["crawl1", "crawl2", "coil", "lunge", "fall", "hit"], "feet"],
	"tick": [["march1", "march2", "wind", "charge", "dizzy", "hit"], "feet"],
	"spur": [["roll", "catch", "hit"], "middle"],
	"buckle": [["idle", "walk1", "walk2", "raise", "stomp", "slam", "thawed", "hit", "shell"], "feet"],
	"owl": [["body", "look_l", "look_c", "look_r", "screech", "hit", "broken"], "feet"],
	"mite": [["walk1", "walk2", "gnaw", "hit"], "feet"],
	"gust": [["idle1", "idle2", "inhale", "blow", "hit"], "middle"],
	"refractor": [["idle1", "idle2", "charge", "fire", "hit"], "middle"],
	"pane": [["face1", "face2", "turn", "edge", "cut", "hit", "shatter"], "feet"],
	"hushling": [["idle1", "idle2", "crouch", "lunge", "blink", "pop"], "feet"],
	"maw": [["idle", "strain", "open", "choke", "hit"], "middle"],
	"coil": [["head_closed", "head_open", "head_rest", "seg", "tail", "hit"], "middle"],
}
# frames A3 adds beyond contract §13's list (checked the same way)
const EXTRA := {"spur": ["face", "face_catch", "face_hit"],
	"coil": ["head_closed_bare", "head_open_bare", "head_rest_bare", "hit_bare"]}
# each kind's rest frame (the tell frames' outlines are compared with it)
const REST := {"rootling": "rootling_walk1", "weepcap": "weepcap_idle", "hound": "hound_prowl1", "creep": "creep_crawl1",
	"tick": "tick_march1", "spur": "spur_roll", "buckle": "buckle_idle", "owl": "owl_look_c", "mite": "mite_walk1",
	"gust": "gust_idle1", "refractor": "refractor_idle1", "pane": "pane_face1", "hushling": "hushling_idle1",
	"maw": "maw_idle", "coil": "coil_head_closed"}
const W3_4 := ["rootling", "weepcap", "hound", "creep", "tick", "spur", "buckle", "owl"]
const W6 := ["hushling", "maw", "coil"]
const TINTED := ["mite", "pane"]
# overlays and parts that don't stand on the line themselves
const OVERLAY := ["buckle_shell", "owl_look_l", "owl_look_c", "owl_look_r", "owl_screech", "owl_hit", "spur_face",
	"spur_face_catch", "spur_face_hit"]
# frames whose eyes are shut, squeezed, spun or dark (the dark test reads open eyes only)
const SHUT := ["rootling_hit", "rootling_dazed", "weepcap_puff", "weepcap_hit", "weepcap_die", "creep_fall",
	"creep_hit", "tick_dizzy", "tick_hit", "spur_hit", "buckle_thawed", "buckle_hit", "owl_hit", "owl_broken",
	"hound_hit", "hound_land", "hound_pant", "gust_blow", "gust_hit", "refractor_hit", "pane_edge", "pane_hit",
	"pane_shatter", "hushling_blink", "hushling_pop", "maw_choke", "maw_hit", "coil_hit", "coil_head_rest",
	"mite_hit", "spur_face_hit", "coil_hit_bare", "coil_head_rest_bare"]
# points that are meant to sit off the art (a star ring over a dazed head, a floor point)
const OFF_ART := ["stars", "column", "burst", "stomp", "cone", "front", "sparks", "floor", "lure_glow", "gust", "beam", "arc"]
# each world's tell accent (spec §11.1: decoration never uses it), by kind
const ACCENT := {"rootling": "#c8d46a", "weepcap": "#c8d46a", "hound": "#c8d46a", "creep": "#c8d46a",
	"tick": "#e8fcff", "spur": "#e8fcff", "buckle": "#e8fcff", "owl": "#e8fcff",
	"mite": "#f8f0ff", "gust": "#f8f0ff", "refractor": "#f8f0ff", "pane": "#f8f0ff",
	"hushling": "#e0e0ff", "maw": "#e0e0ff", "coil": "#e0e0ff"}
# the frames that show a tell (they may use the accent)
const TELL_FRAMES := ["rootling_swell", "weepcap_inhale", "hound_crouch", "hound_howl", "creep_coil", "tick_wind",
	"spur_catch", "spur_face_catch", "buckle_raise", "owl_screech", "mite_gnaw", "gust_inhale", "refractor_charge",
	"refractor_fire", "pane_turn", "pane_edge", "hushling_crouch", "maw_strain", "maw_open", "coil_head_open"]
# a colour within this RGB distance (0-255) of the accent counts as the accent
const ACCENT_NEAR := 24.0
# at most this share of a non-tell frame's solid pixels (its eyes left out) may be that near the accent
const ACCENT_SHARE := 0.01
# a tell frame's outline overlaps its kind's rest frame by at most this much (alpha 0.5 masks, IoU)
const TELL_IOU := 0.88
const OMEN_FRAMES := {"omen_glassed": 128, "omen_echo_dial": 128, "omen_spore_mote": 32, "omen_hush_mote": 32}
const SOLID := 0.5
const MAX_FRAMES := 10

var _passed := 0
var _failed := 0
var _skipped: Array = []
var _img := {}


func _check(ok: bool, what: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", what)


func _initialize() -> void:
	var p3 := _json("art/enemies/points_monsters3.json")
	var p4 := _json("art/enemies/points_monsters4.json")
	for kind in KINDS:
		var pts: Dictionary = p3 if kind in W3_4 else p4
		if pts.is_empty():
			if not _skipped.has(kind):
				_skipped.append(kind)
			continue
		_test_kind(kind, pts)
	_test_family(p3, p4)
	_test_specials(p3, p4)
	for k in _skipped:
		print("skipped: %s (its points file is missing)" % k)
	print("test_monster_art3: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


# ---------------------------------------------------------------- helpers

func _text(rel: String) -> String:
	return FileAccess.get_file_as_string("res://" + rel)


func _json(rel: String) -> Dictionary:
	var t := _text(rel)
	if t == "":
		return {}
	var d = JSON.parse_string(t)
	_check(d is Dictionary, "%s parses" % rel)
	return d if d is Dictionary else {}


func _header(text: String) -> Dictionary:
	var re := RegEx.create_from_string('width="(\\d+)" height="(\\d+)" viewBox="0 0 (\\d+) (\\d+)"')
	var m := re.search(text)
	if m == null:
		return {}
	return {"w": int(m.get_string(1)), "h": int(m.get_string(2)), "vw": int(m.get_string(3)), "vh": int(m.get_string(4))}


# 1 px per frame unit
func _raster(name: String) -> Image:
	if _img.has(name):
		return _img[name]
	var text := _text("art/enemies/%s.svg" % name)
	if text == "":
		return null
	var img := Image.new()
	if img.load_svg_from_string(text, 0.5) != OK:
		return null
	img.convert(Image.FORMAT_RGBA8)
	_img[name] = img
	return img


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


func _touches(img: Image) -> Array:
	var out := []
	var w := img.get_width()
	var h := img.get_height()
	for i in w:
		if img.get_pixel(i, 0).a > 0.05 and not out.has("top"):
			out.append("top")
		if img.get_pixel(i, h - 1).a > 0.05 and not out.has("bottom"):
			out.append("bottom")
	for i in h:
		if img.get_pixel(0, i).a > 0.05 and not out.has("left"):
			out.append("left")
		if img.get_pixel(w - 1, i).a > 0.05 and not out.has("right"):
			out.append("right")
	return out


func _near_art(img: Image, p: Vector2, r: int) -> bool:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var q := Vector2i(int(p.x) + dx, int(p.y) + dy)
			if q.x >= 0 and q.y >= 0 and q.x < img.get_width() and q.y < img.get_height() and img.get_pixel(q.x, q.y).a > 0.3:
				return true
	return false


func _v2(v) -> Vector2:
	return Vector2(float(v[0]), float(v[1]))


func _is_pt(v) -> bool:
	return v is Array and v.size() == 2 and not (v[0] is Array)


# The share of a frame's solid pixels (alpha 0.5 and up) within ACCENT_NEAR of
# the accent, leaving out its eyes (eyes are not decoration: W6's pale d8d4f0
# eyes are the spec's own).
func _accent_share(img: Image, acc: Color, fp: Dictionary) -> float:
	if img == null:
		return 0.0
	var eyes := []
	for k in ["eye1", "eye2", "eye"]:
		if fp.has(k):
			eyes.append(_v2(fp[k]))
	var er := float(fp.get("eye_r", 3.0)) + 1.5
	var solid := 0
	var near := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < SOLID:
				continue
			var in_eye := false
			for e in eyes:
				if Vector2(x, y).distance_to(e) <= er:
					in_eye = true
			if in_eye:
				continue
			solid += 1
			if Vector3(c.r - acc.r, c.g - acc.g, c.b - acc.b).length() * 255.0 <= ACCENT_NEAR:
				near += 1
	return float(near) / maxf(1, solid)


func _iou(a: Image, b: Image) -> float:
	var i := 0
	var u := 0
	for y in a.get_height():
		for x in a.get_width():
			var pa := a.get_pixel(x, y).a >= SOLID
			var pb := b.get_pixel(x, y).a >= SOLID
			if pa and pb:
				i += 1
			if pa or pb:
				u += 1
	return float(i) / maxf(1, u)


# ---------------------------------------------------------------- per kind

func _test_kind(kind: String, pts: Dictionary) -> void:
	var frames: Array = KINDS[kind][0]
	var anchor_kind: String = KINDS[kind][1]
	var anchors: Dictionary = pts.get("_anchors", {})
	_check(anchors.has(kind), "the points name %s's anchor" % kind)
	if anchors.has(kind):
		var want := Vector2(64, 122) if anchor_kind == "feet" else Vector2(64, 64)
		_check(_v2(anchors[kind]) == want, "%s's anchor is %s (got %s)" % [kind, want, anchors[kind]])
	# at most 10 frames a kind (every SVG with its prefix)
	var n := 0
	var d := DirAccess.open("res://art/enemies")
	if d:
		for f in d.get_files():
			if f.begins_with(kind + "_") and f.ends_with(".svg"):
				n += 1
	_check(n <= MAX_FRAMES, "%s has at most %d frames (%d)" % [kind, MAX_FRAMES, n])
	_check(n >= frames.size() + EXTRA.get(kind, []).size(), "%s has every frame the contract names, and A3's extras (%d of %d)" % [
		kind, n, frames.size() + EXTRA.get(kind, []).size()])
	for fr in frames + EXTRA.get(kind, []):
		var name := "%s_%s" % [kind, fr]
		var img := _frame(name)
		if img == null:
			continue
		var bb := _bbox(img)
		if name in OVERLAY:
			pass
		elif anchor_kind == "feet":
			_check(bb.end.y >= 120 and bb.end.y <= 127, "%s stands on y 122 (lowest drawn row %d)" % [name, bb.end.y])
		else:
			_check(_near_art(img, Vector2(64, 64), 4) or Rect2(bb).has_point(Vector2(64, 64)),
				"%s is drawn round its middle (64, 64) (box %s)" % [name, bb])
		_test_points(name, img, pts)


func _frame(name: String) -> Image:
	var rel := "art/enemies/%s.svg" % name
	var text := _text(rel)
	_check(text != "", "%s exists" % rel)
	if text == "":
		return null
	_check(not text.contains("<text") and not text.contains("<filter"), "%s has no <text> or <filter>" % rel)
	var hd := _header(text)
	_check(hd.get("vw", 0) == 128 and hd.get("vh", 0) == 128 and hd.get("w", 0) == 256 and hd.get("h", 0) == 256,
		"%s is a 128 frame at 2 px a unit (%s)" % [rel, hd])
	var img := _raster(name)
	_check(img != null, "%s rasterizes" % rel)
	if img == null:
		return null
	var bb := _bbox(img)
	_check(bb.size.x * bb.size.y > 128 * 128 / 60, "%s has real art in it (%s)" % [rel, bb])
	for side in _touches(img):
		_check(false, "%s stays inside its frame (touches the %s)" % [rel, side])
	var path := "res://" + rel
	_check(ResourceLoader.exists(path), "%s is imported (run --import)" % rel)
	if ResourceLoader.exists(path):
		var tex = load(path)
		_check(tex is Texture2D and tex.get_width() == 256 and tex.get_height() == 256, "%s loads as a 256 x 256 texture" % rel)
	return img


func _test_points(name: String, img: Image, pts: Dictionary) -> void:
	_check(pts.has(name), "the points file has %s" % name)
	if not pts.has(name):
		return
	var fp: Dictionary = pts[name]
	_check(fp.has("hit") and fp["hit"] is Array and fp["hit"].size() == 4, "%s has a hit box" % name)
	if fp.has("hit") and fp["hit"].size() == 4:
		var h: Array = fp["hit"]
		var r := Rect2(float(h[0]), float(h[1]), float(h[2]), float(h[3]))
		_check(r.size.x >= 8 and r.size.y >= 8 and Rect2(0, 0, 128, 128).encloses(r), "%s's hit box %s is inside the frame" % [name, r])
		# the box covers the body: most of the solid art is inside it
		var inside := 0
		var all := 0
		for y in range(0, 128, 2):
			for x in range(0, 128, 2):
				if img.get_pixel(x, y).a >= 0.9:
					all += 1
					if r.grow(4).has_point(Vector2(x, y)):
						inside += 1
		if name not in OVERLAY:
			_check(all == 0 or inside >= all * 0.6, "%s's hit box covers its body (%d of %d)" % [name, inside, all])
	for key in fp:
		var v = fp[key]
		if not _is_pt(v):
			continue
		var p := _v2(v)
		_check(p.x >= 0 and p.y >= 0 and p.x <= 128 and p.y <= 128, "%s.%s %s is inside the frame" % [name, key, p])
		if not (key in OFF_ART) and key != "head" and key != "neck":
			_check(_near_art(img, p, 6), "%s.%s %s sits on its art" % [name, key, p])
	var eyes := []
	for k in ["eye1", "eye2", "eye"]:
		if fp.has(k):
			eyes.append(_v2(fp[k]))
	if eyes.size() > 0:
		_check(fp.has("eye_r") and float(fp["eye_r"]) >= 2.5, "%s says how big its eyes are (%s)" % [name, fp.get("eye_r")])
		# `eyes` is the list of the lit eyes' points (both consumers read it so), eye_mid the middle of two
		var listed := []
		var ok_list: bool = fp.has("eyes") and fp["eyes"] is Array and fp["eyes"].size() == eyes.size()
		if ok_list:
			for q in fp["eyes"]:
				ok_list = ok_list and q is Array and q.size() == 2
				if ok_list:
					listed.append(_v2(q))
		_check(ok_list and listed == eyes, "%s lists its eyes' points in `eyes` (%s, want %s)" % [name, fp.get("eyes"), eyes])
		if eyes.size() == 2:
			_check(fp.has("eye_mid") and _v2(fp["eye_mid"]).distance_to((eyes[0] + eyes[1]) * 0.5) < 0.11,
				"%s gives eye_mid, the middle of its eyes" % name)
		var kind := name.split("_")[0]
		if kind in W6:
			_check(float(fp.get("eye_r", 0)) >= 5.5, "%s's eyes are at least 3 px (r %s units)" % [name, fp.get("eye_r")])
		if not (name in SHUT):
			for e in eyes:
				_eye_reads(name, img, e, float(fp.get("eye_r", 3.0)))


# An eye reads in the dark when the eye light (r 16 px) finds a hot highlight
# on a dark socket: the brightest pixel in the eye is near-white, the darkest
# is dark, and the eye is not smaller than a pixel and a half.
func _eye_reads(name: String, img: Image, e: Vector2, r: float) -> void:
	var hi := 0.0
	var lo := 1.0
	var rr := maxf(r, 2.0) + 0.5
	for dy in range(-int(rr) - 1, int(rr) + 2):
		for dx in range(-int(rr) - 1, int(rr) + 2):
			if Vector2(dx, dy).length() > rr:
				continue
			var q := Vector2i(int(round(e.x)) + dx, int(round(e.y)) + dy)
			if q.x < 0 or q.y < 0 or q.x >= img.get_width() or q.y >= img.get_height():
				continue
			var c := img.get_pixel(q.x, q.y)
			if c.a < 0.5:
				continue
			hi = maxf(hi, c.get_luminance())
			lo = minf(lo, c.get_luminance())
	_check(hi >= 0.78, "%s's eye at %s has a hot highlight for the dark (brightest %.2f)" % [name, e, hi])
	_check(hi - lo >= 0.45, "%s's eye at %s stands out from its socket (%.2f .. %.2f)" % [name, e, lo, hi])


# ---------------------------------------------------------------- family looks

func _test_family(p3: Dictionary, p4: Dictionary) -> void:
	for kind in KINDS:
		var rel := "art/enemies/%s_%s.svg" % [kind, KINDS[kind][0][0]]
		var t := _text(rel).to_lower()
		if t == "":
			continue
		if kind in W6:
			_check(t.contains("#c8c8f0"), "%s has W6's silver rim" % rel)
			_check(not t.contains("#ffeccc"), "%s has no warm rim (W6 is silver)" % rel)
		else:
			_check(t.contains("#ffeccc"), "%s has the family's candlelit sticker rim" % rel)
	# the grinder rim is the Spurwheel's alone
	for kind in KINDS:
		for fr in KINDS[kind][0]:
			var t := _text("art/enemies/%s_%s.svg" % [kind, fr]).to_lower()
			if t == "":
				continue
			if kind == "spur":
				_check(t.contains("#e0602a"), "spur_%s has the grinder rim" % fr)
			else:
				_check(not t.contains("#e0602a"), "%s_%s keeps off the Spurwheel's grinder rim colour" % [kind, fr])
	# the tell accent is for tells only: not its hex, and not a colour near it
	for kind in KINDS:
		var pts: Dictionary = p3 if kind in W3_4 else p4
		for fr in KINDS[kind][0] + EXTRA.get(kind, []):
			var name := "%s_%s" % [kind, fr]
			var t := _text("art/enemies/%s.svg" % name).to_lower()
			if t == "" or name in TELL_FRAMES:
				continue
			_check(not t.contains(ACCENT[kind]), "%s keeps off its world's tell accent %s (decoration never uses it)" % [name, ACCENT[kind]])
			var share := _accent_share(_raster(name), Color(ACCENT[kind]), pts.get(name, {}))
			_check(share < ACCENT_SHARE, "%s keeps off colours near its tell accent %s (%.1f%% of its solid pixels, eyes aside)" % [
				name, ACCENT[kind], share * 100.0])
	# every tell changes the outline, not only a colour: its mask differs from the kind's rest frame
	for name in TELL_FRAMES:
		var kind: String = name.split("_")[0]
		if name in OVERLAY or not KINDS.has(kind):
			continue
		var a := _raster(name)
		var b := _raster(REST[kind])
		if a == null or b == null:
			continue
		var iou := _iou(a, b)
		_check(iou <= TELL_IOU, "%s changes %s's outline (overlap with %s %.2f, at most %.2f)" % [name, kind, REST[kind], iou, TELL_IOU])
	# the tinted glass kinds are drawn neutral (enemy.gd tints them by modulate)
	for kind in TINTED:
		for fr in KINDS[kind][0]:
			var img := _raster("%s_%s" % [kind, fr])
			if img == null:
				continue
			var sat := 0.0
			var n := 0
			for y in range(0, 128, 2):
				for x in range(0, 128, 2):
					var c := img.get_pixel(x, y)
					if c.a >= 0.9 and c.v > 0.45:
						sat += c.s
						n += 1
			_check(n > 0 and sat / n <= 0.22, "%s_%s is drawn neutral for its tint (mean saturation %.2f)" % [kind, fr, sat / maxf(1, n)])


func _test_specials(p3: Dictionary, p4: Dictionary) -> void:
	if not p3.is_empty():
		# the rime overlay is see-through and covers the knight's torso and helm
		var sh := _raster("buckle_shell")
		var idle := _raster("buckle_idle")
		if sh and idle:
			var a := 0.0
			var n := 0
			for y in sh.get_height():
				for x in sh.get_width():
					var c := sh.get_pixel(x, y)
					if c.a > 0.1:
						a += c.a
						n += 1
			_check(n > 0 and a / n < 0.8, "buckle_shell is see-through (mean alpha %.2f)" % (a / maxf(1, n)))
			var sb := _bbox(sh, 0.1)
			_check(sb.has_point(Vector2i(64, 60)) and sb.has_point(Vector2i(64, 90)), "buckle_shell covers the helm and the torso (%s)" % sb)
			for fr in KINDS["buckle"][0]:
				if fr != "shell":
					var fp: Dictionary = p3.get("buckle_" + fr, {})
					_check(fp.has("shell_dx") and fp.has("shell_dy"), "buckle_%s says where its rime shell sits" % fr)
		# the owl's heads sit on its body's neck
		var body := _raster("owl_body")
		if body:
			var bb := _bbox(body)
			for fr in ["look_l", "look_c", "look_r", "screech", "hit"]:
				var h := _raster("owl_" + fr)
				if h == null:
					continue
				var hb := _bbox(h)
				_check(hb.end.y >= bb.position.y + 2 and hb.end.y <= bb.position.y + 16, "owl_%s sits on the body (head bottom %d, body top %d)" % [fr, hb.end.y, bb.position.y])
				_check(hb.position.y >= 40, "owl_%s is the head only (top %d)" % [fr, hb.position.y])
			var look := {"owl_look_l": -1.0, "owl_look_c": 0.0, "owl_look_r": 1.0}
			var cx := {}
			for k in look:
				var fp: Dictionary = p3.get(k, {})
				if fp.has("cone"):
					cx[k] = float(fp["cone"][0])
			if cx.size() == 3:
				_check(cx["owl_look_l"] < cx["owl_look_c"] and cx["owl_look_c"] < cx["owl_look_r"], "the owl's look frames turn its eyes left to right %s" % cx)
		# the Creepbone is drawn vertical (it lives on vines)
		for fr in ["crawl1", "crawl2", "lunge"]:
			var img := _raster("creep_" + fr)
			if img:
				var bb := _bbox(img)
				_check(bb.size.y >= bb.size.x * 2, "creep_%s is drawn head-up along its lane (%s)" % [fr, bb])
		# creep_fall draws no dizzy stars (turned onto the floor they would lie sideways: code draws them)
		_check(p3.has("creep_fall") and not p3["creep_fall"].has("stars"), "creep_fall leaves its dizzy stars to code")
		# the Rattlehound's lantern-glint burns in one socket
		for fr in KINDS["hound"][0]:
			var fp: Dictionary = p3.get("hound_" + fr, {})
			_check(fp.get("eyes", []).size() == 1, "hound_%s has one lit socket (%s)" % [fr, fp.get("eyes")])
		# the Spurwheel's frames turn with it: nothing drawn outside its teeth points a way
		for fr in ["roll", "catch", "hit"]:
			var img := _raster("spur_" + fr)
			if img == null:
				continue
			var far := 0.0
			for y in 128:
				for x in 128:
					if img.get_pixel(x, y).a >= SOLID:
						far = maxf(far, Vector2(x, y).distance_to(Vector2(64, 64)))
			_check(far <= 36.0, "spur_%s is only the cog round its hub (art reaches %.1f units, at most 36)" % [fr, far])
		# its upright face overlays cover the turning cog's hub face, with the same eyes
		for fr in ["face", "face_catch", "face_hit"]:
			var img := _raster("spur_" + fr)
			if img == null:
				continue
			var holes := 0
			for y in range(52, 77):
				for x in range(52, 77):
					if Vector2(x, y).distance_to(Vector2(64, 64)) <= 10.8 and img.get_pixel(x, y).a < 0.95:
						holes += 1
			_check(holes == 0, "spur_%s covers the hub (%d see-through pixels)" % [fr, holes])
			var a: Dictionary = p3.get("spur_" + fr, {})
			var b: Dictionary = p3.get("spur_roll", {})
			_check(a.get("eye1") == b.get("eye1") and a.get("eye2") == b.get("eye2"), "spur_%s's eyes are the cog's hub eyes" % fr)
		# the Rootling's mound is low: only the mound and its leaves
		var mound := _raster("rootling_mound")
		if mound:
			var bb := _bbox(mound, 0.9)
			_check(bb.position.y >= 96, "rootling_mound is only a low mound (top %d)" % bb.position.y)
	if not p4.is_empty():
		# edge-on the Paneguard is a thin line of lead
		var face := _raster("pane_face1")
		var edge := _raster("pane_edge")
		if face and edge:
			_check(_bbox(edge).size.x <= 30, "pane_edge is thin edge-on (%d units)" % _bbox(edge).size.x)
			_check(_bbox(face).size.x >= 48, "pane_face1 is broad face-on (%d units)" % _bbox(face).size.x)
		var tints: Dictionary = p4.get("_tints", {})
		_check(tints.size() == 3, "points_monsters4.json gives the glass kinds' three tints (%s)" % tints)
		# the Omen looks (P1): overlays for elites.gd, drawn on the glow layer
		var om: Dictionary = p4.get("_omens", {})
		for o in OMEN_FRAMES:
			var text := _text("art/enemies/%s.svg" % o)
			if om.is_empty() and text == "":
				continue
			_check(text != "" and not text.contains("<text") and not text.contains("<filter"), "%s is there and ThorVG-safe" % o)
			var hd := _header(text)
			var n: int = OMEN_FRAMES[o]
			_check(hd.get("vw", 0) == n and hd.get("w", 0) == n * 2, "%s is a %d frame at 2 px a unit" % [o, n])
			_check(om.get("frames", []).has(o), "points_monsters4.json _omens lists %s" % o)
			_check(ResourceLoader.exists("res://art/enemies/%s.svg" % o), "%s is imported" % o)
		# the Refractor aims at any angle and its sprite is not turned: its lock and fire frames draw no line
		var idle := _raster("refractor_idle1")
		for fr in ["charge", "fire"]:
			var img := _raster("refractor_" + fr)
			if img and idle:
				_check(_bbox(img).end.x <= _bbox(idle).end.x + 14, "refractor_%s draws no fixed aim line or beam (right edge %d, idle %d)" % [
					fr, _bbox(img).end.x, _bbox(idle).end.x])
			var fp: Dictionary = p4.get("refractor_" + fr, {})
			_check(fp.has("beam") and fp.has("lens") and _v2(fp["beam"]) == _v2(fp["lens"]), "refractor_%s's beam starts at its lens" % fr)
		# the Lurecoil's candle can be knocked loose: each head frame has a candle-less twin
		for fr in ["head_closed", "head_open", "head_rest", "hit"]:
			var lit: Dictionary = p4.get("coil_" + fr, {})
			var bare: Dictionary = p4.get("coil_%s_bare" % fr, {})
			_check(lit.has("lure"), "coil_%s holds the lit candle (lure)" % fr)
			_check(not bare.is_empty() and not bare.has("lure"), "coil_%s_bare has no candle" % fr)
			var a := _raster("coil_" + fr)
			var b := _raster("coil_%s_bare" % fr)
			if a and b:
				_check(_iou(a, b) < 0.99, "coil_%s_bare differs from coil_%s (the candle gone)" % [fr, fr])
		# the Glassmite's box is at least 20 px (40 units) tall (spec §4.5)
		for fr in KINDS["mite"][0]:
			var h: Array = p4.get("mite_" + fr, {}).get("hit", [0, 0, 0, 0])
			_check(float(h[3]) >= 40.0, "mite_%s's hit box is at least 20 px tall (%s units)" % [fr, h[3]])
		var seg := _raster("coil_seg")
		if seg:
			var bb := _bbox(seg)
			_check(absi(bb.size.x - 52) <= 10 and bb.size.y >= 44 and bb.size.y <= 72, "coil_seg is a 24 px ring (%s)" % bb)
