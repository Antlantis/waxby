# Story art contact sheets: rasterizes art/story/** straight from the SVG text
# with Image.load_svg_from_string (ThorVG, like the importer) and composes
# them the way the cutscene player (scripts/cutscene.gd) draws them:
#   layers, figures and the actor strictly by depth (a figure at its anchor's
#   depth + 0.001, the actor + 0.002; ties keep the manifest's order), each
#   unlit one shaded by the darkness bands of every light, lit layers left
#   as they are, and flames and eyes drawn live over everything.
#
#   <out>/panel_<id>.png      the panel raw (all layers, with the guides: the
#                             central 900 x 420, the dialogue box line, the
#                             anchors and lights), then lit, once per staging
#                             (figures and the actor where the story puts them)
#   <out>/views.png           the camera's frame on the phone (847 x 390, every
#                             layer at its own parallax), letterbox, box and
#                             portrait circle on
#   <out>/figures.png         every figure big, flame points marked and lit
#   <out>/lineup.png          every figure at its panel height beside Wick
#   <out>/portraits.png       every portrait big (the engine's crop circle
#                             marked), then cropped as the dialogue box crops
#                             it (centre (64, 62), UV radius 0.42) at 2x and 1x
# godot --headless --path game --script res://../tools/art/story_sheet.gd -- <out_dir> [all|panels|views|figures|portraits] [ids...]
extends SceneTree

const JSON_PATH := "res://art/story/panels.json"
const BG := Color("120c18")
const INK := Color("120d1a")
const WARM := Color(1.0, 0.95, 0.86)
# Wick's rig at rest (from tools/art/wick.py) for the actor: the 128 frame,
# feet at (64, 122), the candle's flame base.
const RIG_ORDER := ["cape", "leg_back", "arm_back", "body", "leg_front", "head", "candle", "arm_front"]
const RIG_FLAME := Vector2(60, 19)
const RIG_FEET := Vector2(64, 122)
# cutscene.gd: the actor's candle is 19 rig px tall (the rig is 64 px for its
# 128 frame) and lights h * 1.6 around it; eyes are EYE_GAP * h apart.
const ACTOR_FLAME := 19.0
const EYE_GAP := 5.2
# the dialogue box's portrait crop (cutscene.gd _portrait): UV centre and radius
const CROP_C := Vector2(64, 62)
const CROP_R := 0.42 * 128.0

# How the story scenes stage each panel (story.gd): {name, figs {anchor: fig},
# actor, off [lights], r {light: mult}, dawn}
const STAGING := {
	"glass_legend": [{"name": "legend"}],
	"lanternfold": [{"name": "intro"}, {"name": "snuffed", "off": ["lamp3", "lamp6", "lamp1", "lamp8"]}],
	"chapel": [{"name": "intro", "figs": {"taper": "taper_stand", "novice": "novice_back"}, "r": {"taper.head": 0.5}},
		{"name": "oath", "figs": {"taper": "taper_stand"}, "actor": "actor", "r": {"taper.head": 0.5}},
		{"name": "ending", "figs": {"taper": "taper_chair", "hollin": "hollin_warm"}, "actor": "actor", "r": {"taper.head": 0.22}}],
	"callings": [{"name": "dark", "off": ["plinth_knight", "plinth_founder", "plinth_witch", "plinth_runner", "plinth_sexton"]},
		{"name": "one", "off": ["plinth_knight", "plinth_founder", "plinth_runner", "plinth_sexton"]},
		{"name": "all"}],
	"crypt_row": [{"name": "lit", "figs": {"far": "snuffer_reach"}},
		{"name": "snuffed", "figs": {"far": "snuffer_reach"}, "off": ["c5", "c6", "c7", "c8"]}],
	"belfry": [{"name": "boss", "figs": {"boss": "tollgrave_boss"}, "off": ["bell_beam"]},
		{"name": "after", "figs": {"sit": "tollgrave_sit"}, "actor": "actor_after"},
		{"name": "taunt", "figs": {"sill": "snuffer_stand"}, "off": ["bell_beam"], "r": {"moon1": 0.6, "moon2": 0.6, "moon3": 0.6}},
		{"name": "taunt_floor", "figs": {"boss": "snuffer_stand"}, "off": ["bell_beam"], "r": {"moon1": 0.6, "moon2": 0.6, "moon3": 0.6}}],
	"tallow_vista": [{"name": "vista"}, {"name": "waxley", "figs": {"waxley": "waxley_pack"}, "actor": "edge"}],
	"undercandle": [{"name": "before", "figs": {"boss": "snuffer_reach"}, "r": {"under_flame": 0.35}},
		{"name": "after", "figs": {"cone": "cone_broken", "hollin": "hollin_cold"}, "actor": "actor_near", "r": {"under_flame": 0.35}},
		{"name": "relit", "figs": {"cone": "cone_broken", "hollin": "hollin_warm"}, "actor": "actor_near"}],
	"bells_all": [{"name": "dark", "off": ["bell1", "bell2", "bell3", "bell4", "bell5", "bell6", "bell7", "bell8", "under_flame"]},
		{"name": "half", "off": ["bell5", "bell6", "bell7", "bell8"]},
		{"name": "rung"}],
	"dawn_rise": [{"name": "dawn"}, {"name": "day", "dawn": 1.0}],
	"hush_eye": [{"name": "eye", "figs": {"eye": "hush_eye"}}],
}

var data: Dictionary
var cache := {}
var flame_cache := {}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "/tmp/story_sheet"
	var what: String = args[1] if args.size() > 1 else "all"
	var ids := PackedStringArray()
	for i in range(2, args.size()):
		ids.append(args[i])
	DirAccess.make_dir_recursive_absolute(out)
	var text := FileAccess.get_file_as_string(JSON_PATH)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("panels.json did not parse")
		quit(1)
		return
	data = parsed
	if what == "all" or what == "panels":
		var panels: Dictionary = data["panels"]
		for pid in panels:
			if ids.size() > 0 and not ids.has(pid):
				continue
			panel_sheet(pid).save_png("%s/panel_%s.png" % [out, pid])
			print("wrote panel_", pid)
	if what == "all" or what == "figures":
		figures_sheet(ids).save_png(out + "/figures.png")
		lineup().save_png(out + "/lineup.png")
		print("wrote figures, lineup")
	if what == "all" or what == "portraits":
		portraits_sheet().save_png(out + "/portraits.png")
		print("wrote portraits")
	if what == "all" or what == "views":
		views_sheet(ids).save_png(out + "/views.png")
		print("wrote views")
	quit()


# ---------------------------------------------------------------- raster helpers

func rast(res: String, scale: float) -> Image:
	var key := "%s@%.4f" % [res, scale]
	if cache.has(key):
		return cache[key]
	var text := FileAccess.get_file_as_string(res)
	var img := Image.new()
	if text == "" or img.load_svg_from_string(text, scale) != OK:
		push_error("could not rasterize " + res)
		img = Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
		img.fill(Color.MAGENTA)
	img.convert(Image.FORMAT_RGBA8)
	cache[key] = img
	return img


func canvas(w: int, h: int, col: Color = BG) -> Image:
	var img := Image.create_empty(maxi(w, 1), maxi(h, 1), false, Image.FORMAT_RGBA8)
	img.fill(col)
	return img


func paste(dst: Image, src: Image, x: int, y: int) -> void:
	dst.blend_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), Vector2i(x, y))


func flipped(src: Image) -> Image:
	var s: Image = src.duplicate()
	s.flip_x()
	return s


func hline(img: Image, y: int, x0: int, x1: int, col: Color) -> void:
	for x in range(maxi(0, x0), mini(img.get_width(), x1)):
		if y >= 0 and y < img.get_height():
			img.set_pixel(x, y, img.get_pixel(x, y).lerp(col, col.a))


func vline(img: Image, x: int, y0: int, y1: int, col: Color) -> void:
	for y in range(maxi(0, y0), mini(img.get_height(), y1)):
		if x >= 0 and x < img.get_width():
			img.set_pixel(x, y, img.get_pixel(x, y).lerp(col, col.a))


func box(img: Image, r: Rect2i, col: Color) -> void:
	hline(img, r.position.y, r.position.x, r.end.x, col)
	hline(img, r.end.y - 1, r.position.x, r.end.x, col)
	vline(img, r.position.x, r.position.y, r.end.y, col)
	vline(img, r.end.x - 1, r.position.y, r.end.y, col)


func cross(img: Image, p: Vector2, col: Color, r: int = 5) -> void:
	for i in range(-r, r + 1):
		for t in [0, 1]:
			var a := Vector2i(int(p.x) + i, int(p.y) + t)
			var b := Vector2i(int(p.x) + t, int(p.y) + i)
			for q in [a, b]:
				if q.x >= 0 and q.y >= 0 and q.x < img.get_width() and q.y < img.get_height():
					img.set_pixelv(q, col)


func ring(img: Image, c: Vector2, r: float, col: Color, w := 1.0) -> void:
	for y in range(int(c.y - r - w - 1), int(c.y + r + w + 2)):
		for x in range(int(c.x - r - w - 1), int(c.x + r + w + 2)):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			if absf(Vector2(x + 0.5, y + 0.5).distance_to(c) - r) <= w * 0.5:
				img.set_pixel(x, y, img.get_pixel(x, y).lerp(col, col.a))


# A live-looking flame (the Glow.flame teardrops), h px tall, its base at the bottom centre.
func flame_img(h: float, cold := false) -> Image:
	var hh := maxi(4, int(round(h)))
	var key := "%d%s" % [hh, "c" if cold else ""]
	if flame_cache.has(key):
		return flame_cache[key]
	var outc := "#9ab8ff" if cold else "#f2b84b"
	var midc := "#cfe0ff" if cold else "#ffd98a"
	var core := "#f4f8ff" if cold else "#fff2c8"
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" width="40" height="60" viewBox="0 0 40 60">'
	svg += '<circle cx="20" cy="34" r="19" fill="%s" opacity="0.10"/><circle cx="20" cy="34" r="13" fill="%s" opacity="0.14"/>' % [outc, outc]
	for t in [[outc, 1.0, 0.0], [midc, 0.74, 3.0], [core, 0.44, 6.0]]:
		var k: float = t[1]
		var dy: float = t[2]
		var r := 7.0 * k
		var top := 60.0 - 36.0 * k - 12.0 - dy * 0.3
		var by := 56.0 - dy * 0.4
		svg += '<path d="M20 %.1f C%.1f %.1f %.1f %.1f %.1f %.1f A%.1f %.1f 0 0 1 %.1f %.1f C%.1f %.1f %.1f %.1f 20 %.1f Z" fill="%s"/>' % [
			top, 20 + r * 0.3, top + 10 * k, 20 + r, by - r * 1.4, 20 + r, by - r, r, r, 20 - r, by - r,
			20 - r, by - r * 1.4, 20 - r * 0.3, top + 10 * k, top, t[0]]
	svg += '</svg>'
	var img := Image.new()
	img.load_svg_from_string(svg, hh / 44.0)   # the teardrop spans 44 of the doc's 60 units
	img.convert(Image.FORMAT_RGBA8)
	flame_cache[key] = img
	return img


func draw_flame(dst: Image, base: Vector2, h: float, cold := false) -> void:
	var f := flame_img(h, cold)
	paste(dst, f, int(base.x - f.get_width() / 2.0), int(base.y - maxf(4.0, h) * 56.0 / 44.0))


func glow_dot(dst: Image, p: Vector2, r: float, col: Color) -> void:
	for y in range(int(p.y - r * 2), int(p.y + r * 2) + 1):
		for x in range(int(p.x - r * 2), int(p.x + r * 2) + 1):
			if x < 0 or y < 0 or x >= dst.get_width() or y >= dst.get_height():
				continue
			var d := Vector2(x, y).distance_to(p)
			var a := 0.0
			if d <= r:
				a = 1.0
			elif d <= r * 2.0:
				a = 0.5 * (1.0 - (d - r) / r)
			if a > 0.0:
				var c := col.lerp(Color.WHITE, 0.55 if d < r * 0.5 else 0.0)
				dst.set_pixel(x, y, dst.get_pixel(x, y).lerp(c, a * col.a))


func vec(a) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


# ---------------------------------------------------------------- the engine's picture

# The camera (spec 7.2): [origin, scale] of the panel plane at depth d, for a
# view of vs px on a panel of size, with the camera [cx, cy, z].
func cam_xf(size: Vector2, vs: Vector2, cam: Array, d: float) -> Array:
	var z := maxf(float(cam[2]), 1.0)
	var s0 := maxf(vs.x / size.x, vs.y / size.y)
	var hv := vs / (2.0 * s0 * z)
	var c := Vector2(float(cam[0]) * size.x, float(cam[1]) * size.y)
	c.x = size.x * 0.5 if hv.x * 2.0 >= size.x else clampf(c.x, hv.x, size.x - hv.x)
	c.y = size.y * 0.5 if hv.y * 2.0 >= size.y else clampf(c.y, hv.y, size.y - hv.y)
	var P := size * 0.5
	var sd := s0 * (1.0 + (z - 1.0) * d)
	var cd := P + (c - P) * d
	return [vs * 0.5 - cd * sd, sd]


# A light's multiplier in a staging: off, light_r, or 1.
func light_k(st: Dictionary, id: String) -> float:
	if (st.get("off", []) as Array).has(id):
		return 0.0
	return float(st.get("r", {}).get(id, 1.0))


# The staging as the engine draws it on a vs-px view with the camera cam.
# raw: no darkness and no live flames (the panel as painted).
func render_scene(pn: Dictionary, st: Dictionary, vs: Vector2, cam: Array, raw := false) -> Image:
	var size: Vector2 = vec(pn["size"])
	var img := canvas(int(vs.x), int(vs.y), Color(0, 0, 0, 1))
	var anchors: Dictionary = pn["anchors"]
	var figs_all: Dictionary = data["figures"]
	# everything drawn far to near
	var items := []   # [depth, order, kind, data]
	var order := 0
	for lay in pn["layers"]:
		items.append([float(lay["depth"]), order, "layer", lay])
		order += 1
	var figs: Dictionary = st.get("figs", {})
	for aid in figs:
		if not anchors.has(aid) or not figs_all.has(figs[aid]):
			push_error("staging %s: no anchor %s or figure %s" % [st.get("name", ""), aid, figs[aid]])
			continue
		items.append([float(anchors[aid].get("depth", 1.0)) + 0.001, order, "fig", aid])
		order += 1
	var actor: String = st.get("actor", "")
	if actor != "" and anchors.has(actor):
		items.append([float(anchors[actor].get("depth", 1.0)) + 0.002, order, "actor", actor])
	items.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	# the lights (view px: [p, r, s]) and the live flames and eyes
	var lights := []
	var flames := []
	var pl: Dictionary = pn["lights"]
	for lid in pl:
		var L: Dictionary = pl[lid]
		var k := light_k(st, lid)
		if k <= 0.01:
			continue
		var x := cam_xf(size, vs, cam, float(L.get("depth", 1.0)))
		var sd: float = x[1]
		var p: Vector2 = x[0] + vec(L["p"]) * sd
		lights.append([p, float(L["r"]) * sd * (0.35 + 0.65 * minf(k, 1.5)), float(L["s"]) * minf(k, 1.0)])
		var kind: String = L.get("kind", "flame")
		if (kind == "flame" or kind == "cold") and L.has("h") and not L.get("hidden", false):
			flames.append({"p": p, "h": float(L["h"]) * sd * minf(k, 1.2), "cold": kind == "cold"})
		elif kind == "eyes":
			for e in L.get("pts", []):
				flames.append({"eye": x[0] + vec(e) * sd, "r": float(L.get("dot", 1.5)) * sd, "col": Color(L.get("color", "f7b64a"))})
	# where each figure and the actor go: [image, top-left]
	var placed := {}
	for it in items:
		if it[2] == "fig":
			var aid: String = it[3]
			var a: Dictionary = anchors[aid]
			var f: Dictionary = figs_all[figs[aid]]
			var x := cam_xf(size, vs, cam, float(a.get("depth", 1.0)))
			var h: float = float(a.get("h", f["h"]))
			var frame: Vector2 = vec(f["frame"])
			var kf: float = float(x[1]) * h / frame.y          # view px per frame unit
			var flip: bool = a.get("flip", false)
			var fimg := rast(f["tex"], kf / float(f.get("px", 4)))
			if flip:
				fimg = flipped(fimg)
			var feet: Vector2 = vec(f["feet"])
			var fx := feet.x if not flip else frame.x - feet.x
			var ap: Vector2 = x[0] + vec(a["p"]) * float(x[1])
			placed[aid] = [fimg, ap - Vector2(fx, feet.y) * kf]
			var styles: Dictionary = f.get("light", {})
			var fl: Dictionary = f.get("flames", {})
			for name in fl:
				var q: Array = fl[name]
				var k := light_k(st, "%s.%s" % [aid, name])
				if k <= 0.01:
					continue
				# a flipped figure mirrors its flame points about its feet
				var fp := Vector2(float(q[0]), float(q[1]))
				if flip:
					fp.x = 2.0 * feet.x - fp.x
				var pp: Vector2 = ap + (fp - feet) * kf
				var sty: Dictionary = styles.get(name, {})
				var kind: String = sty.get("kind", q[3] if q.size() > 3 else "flame")
				var lr: float = float(sty.get("r", float(q[2]) * 5.0)) * kf * (0.35 + 0.65 * minf(k, 1.5))
				lights.append([pp, lr, float(sty.get("s", 1.0)) * minf(k, 1.0)])
				if kind == "eyes":
					for e in sty.get("pts", []):
						var ep := vec(e)
						if flip:
							ep.x = 2.0 * feet.x - ep.x
						flames.append({"eye": ap + (ep - feet) * kf, "r": float(sty.get("dot", 3.0)) * kf,
								"col": Color(Color(sty.get("color", "7ef0c8")), minf(k, 1.0))})
				else:
					flames.append({"p": pp, "h": float(q[2]) * kf * minf(k, 1.2), "cold": kind == "cold"})
		elif it[2] == "actor":
			var a: Dictionary = anchors[it[3]]
			var x := cam_xf(size, vs, cam, float(a.get("depth", 1.0)))
			var ah: float = float(a.get("h", 120))
			var ka: float = float(x[1]) * ah / 128.0              # view px per rig frame unit
			# cutscene.gd: face whoever shares the shot, or the panel's middle
			var ap: Vector2 = vec(a["p"])
			var target := size.x * 0.5
			var best := INF
			for aid in figs:
				if anchors.has(aid):
					var fxp: float = vec(anchors[aid]["p"]).x
					if absf(fxp - ap.x) < best and absf(fxp - ap.x) > 1.0:
						best = absf(fxp - ap.x)
						target = fxp
			var face := 1 if target >= ap.x else -1
			var aimg := canvas(int(128 * ka) + 2, int(128 * ka) + 2, Color(0, 0, 0, 0))
			for part in RIG_ORDER:
				paste(aimg, rast("res://art/wick/%s.svg" % part, ka / 2.0), 0, 0)
			if face < 0:
				aimg = flipped(aimg)
			var feet := RIG_FEET if face > 0 else Vector2(128.0 - RIG_FEET.x, RIG_FEET.y)
			var sp: Vector2 = x[0] + ap * float(x[1])
			placed["@actor"] = [aimg, sp - feet * ka]
			var fb := RIG_FLAME if face > 0 else Vector2(128.0 - RIG_FLAME.x, RIG_FLAME.y)
			var fp: Vector2 = sp + (fb - feet) * ka
			var k := light_k(st, "actor")
			if k > 0.01:
				lights.append([fp, ah * 1.6 * float(x[1]) * (0.35 + 0.65 * minf(k, 1.5)), 0.95 * minf(k, 1.0)])
				flames.append({"p": fp, "h": ACTOR_FLAME * ka * 2.0 * minf(k, 1.2), "cold": false})
	# the darkness bands of every light, once for the view
	var dark = null
	if pn["dark"] != null and not raw:
		var dk: Array = pn["dark"]
		dark = Color(float(dk[0]), float(dk[1]), float(dk[2]))
		if st.has("dawn"):
			dark = (dark as Color).lerp(Color.WHITE, float(st["dawn"]))
	var band := band_map(lights, int(vs.x), int(vs.y)) if dark != null else PackedFloat32Array()
	for it in items:
		var src: Image
		var tl: Vector2
		var unlit := true
		if it[2] == "layer":
			var lay: Dictionary = it[3]
			var x := cam_xf(size, vs, cam, float(lay["depth"]))
			var rect: Array = lay["rect"]
			src = rast(lay["tex"], float(x[1]) / float(lay["px"]))
			tl = x[0] + Vector2(float(rect[0]), float(rect[1])) * float(x[1])
			unlit = not lay.get("lit", false)
		else:
			var key: String = it[3] if it[2] == "fig" else "@actor"
			src = placed[key][0]
			tl = placed[key][1]
		var at := Vector2i(int(round(tl.x)), int(round(tl.y)))
		if dark != null and unlit:
			src = shaded(src, at, band, int(vs.x), int(vs.y), dark)
		paste(img, src, at.x, at.y)
	if not raw:
		for f in flames:
			if f.has("eye"):
				glow_dot(img, f["eye"], maxf(1.2, f["r"]), f["col"])
			else:
				draw_flame(img, f["p"], f["h"], f["cold"])
	return img


# the darkness shader's stepped light (0..1) on a 2 px grid over a w x h view
func band_map(lights: Array, w: int, h: int) -> PackedFloat32Array:
	var gw := w / 2 + 1
	var gh := h / 2 + 1
	var grid := PackedFloat32Array()
	grid.resize(gw * gh)
	for gy in gh:
		for gx in gw:
			var px := float(gx * 2)
			var py := float(gy * 2)
			var lit := 0.0
			for L in lights:
				var p: Vector2 = L[0]
				var r: float = maxf(1.0, L[1])
				var dx: float = px - p.x
				var dy: float = py - p.y
				var d2 := dx * dx + dy * dy
				if d2 >= r * r:
					continue
				var v: float = (1.0 - smoothstep(0.22, 1.0, sqrt(d2) / r)) * float(L[2])
				lit = 1.0 - (1.0 - lit) * (1.0 - v)
			var b := lit * 3.0
			var seam := smoothstep(0.82, 1.0, b - floor(b))
			grid[gy * gw + gx] = clampf((floor(b) + seam) / 3.0, 0.0, 1.0)
	return grid


# src (placed at tl on the view) with the darkness applied the way the shader
# applies it to each layer: rgb *= mix(dark, warm, band)
func shaded(src: Image, tl: Vector2i, band: PackedFloat32Array, w: int, h: int, dark: Color) -> Image:
	var out: Image = src.duplicate()
	var gw := w / 2 + 1
	var x0 := maxi(0, -tl.x)
	var y0 := maxi(0, -tl.y)
	var x1 := mini(src.get_width(), w - tl.x)
	var y1 := mini(src.get_height(), h - tl.y)
	for y in range(y0, y1):
		var row := ((y + tl.y) / 2) * gw
		for x in range(x0, x1):
			var c := out.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var m := dark.lerp(WARM, band[row + (x + tl.x) / 2])
			out.set_pixel(x, y, Color(c.r * m.r, c.g * m.g, c.b * m.b, c.a))
	return out


# ---------------------------------------------------------------- panels

func panel_sheet(pid: String) -> Image:
	var panels: Dictionary = data["panels"]
	var pn: Dictionary = panels[pid]
	var size: Vector2 = vec(pn["size"])
	var k := minf(1.0, minf(1400.0 / size.x, 1100.0 / size.y))
	var w := int(size.x * k)
	var h := int(size.y * k)
	var vs := Vector2(w, h)
	var flat := [0.5, 0.5, 1.0]
	var stagings: Array = STAGING.get(pid, [{"name": "neutral"}])
	var out := canvas(w + 24, (h + 12) * (stagings.size() + 1) + 12)
	# raw, with guides
	var raw := render_scene(pn, {}, vs, flat, true)
	var cx := (size.x - 900.0) / 2.0
	var cy := (size.y - 420.0) / 2.0
	box(raw, Rect2i(int(cx * k), int(cy * k), int(900 * k), int(420 * k)), Color(0.3, 1, 0.5, 0.7))
	hline(raw, int(size.y * 0.7 * k), 0, w, Color(1, 0.4, 0.3, 0.6))
	var anchors: Dictionary = pn["anchors"]
	for aid in anchors:
		cross(raw, vec(anchors[aid]["p"]) * k, Color(0.3, 0.8, 1.0), 6)
	var lights: Dictionary = pn["lights"]
	for lid in lights:
		cross(raw, vec(lights[lid]["p"]) * k, Color(1, 0.85, 0.2), 4)
	paste(out, raw, 12, 12)
	var y := 12 + h + 12
	for st in stagings:
		paste(out, render_scene(pn, st, vs, flat), 12, y)
		y += h + 12
	return out


# ---------------------------------------------------------------- views: the camera's frame with the box on

# [panel, staging, [cx, cy, z] (the camera where the shot's lines play),
#  speaker side ("right" NPC, "left" Wick, "" narration)]
const VIEWS := [
	["glass_legend", "legend", [0.167, 0.5, 1.0], ""], ["lanternfold", "intro", [0.62, 0.47, 1.0], ""],
	["chapel", "intro", [0.42, 0.5, 1.16], "right"], ["chapel", "oath", [0.53, 0.52, 1.18], "left"],
	["chapel", "ending", [0.5, 0.52, 1.14], "right"], ["callings", "dark", [0.5, 0.5, 1.0], "right"],
	["crypt_row", "snuffed", [0.57, 0.46, 1.28], "right"], ["belfry", "boss", [0.53, 0.4, 1.3], "right"],
	["belfry", "after", [0.5, 0.55, 1.12], "right"], ["belfry", "taunt", [0.52, 0.45, 1.2], "right"],
	["belfry", "taunt_floor", [0.52, 0.45, 1.2], "right"], ["tallow_vista", "waxley", [0.28, 0.42, 1.12], "right"],
	["undercandle", "before", [0.6, 0.62, 1.25], "right"], ["undercandle", "after", [0.5, 0.8, 1.38], "right"],
	["bells_all", "dark", [0.5, 0.9, 1.0], ""], ["bells_all", "rung", [0.5, 0.1, 1.0], ""],
	["dawn_rise", "dawn", [0.5, 0.64, 1.16], ""], ["hush_eye", "eye", [0.5, 0.5, 1.08], ""],
]
const VS := Vector2(847, 390)
const SAFE := Rect2(62, 0, 723, 369)     # the 17 Pro Max in landscape: the island's inset each side, the home bar


func views_sheet(ids: PackedStringArray) -> Image:
	var list := []
	for v in VIEWS:
		if ids.size() == 0 or ids.has(v[0]):
			list.append(v)
	var cols := 2
	var rows := int(ceil(list.size() / float(cols)))
	var img := canvas(12 + cols * (int(VS.x) + 12), 12 + rows * (int(VS.y) + 12))
	var panels: Dictionary = data["panels"]
	for i in list.size():
		var v: Array = list[i]
		var st := {}
		for s2 in STAGING.get(v[0], []):
			if s2["name"] == v[1]:
				st = s2
		var crop := render_scene(panels[v[0]], st, VS, v[2])
		# letterbox bars, the dialogue box and the portrait circle
		crop.fill_rect(Rect2i(0, 0, int(VS.x), 28), INK)
		crop.fill_rect(Rect2i(0, int(VS.y) - 28, int(VS.x), 28), INK)
		if v[3] != "":
			var bx := Rect2i(int(SAFE.position.x + 12), int(SAFE.end.y - 6 - 96), int(SAFE.size.x - 24), 96)
			blend_box(crop, bx, Color(0.114, 0.082, 0.16, 0.94))
			var pc := Vector2(bx.end.x - 58, bx.position.y) if v[3] == "right" else Vector2(bx.position.x + 58, bx.position.y)
			for y in range(int(pc.y - 52), int(pc.y + 52)):
				for x in range(int(pc.x - 52), int(pc.x + 52)):
					if x >= 0 and y >= 0 and x < crop.get_width() and y < crop.get_height() and Vector2(x, y).distance_to(pc) <= 50.5:
						crop.set_pixel(x, y, Color("2a2238") if Vector2(x, y).distance_to(pc) <= 46 else Color("f2c75a"))
		else:
			hline(crop, int(VS.y) - 62, 120, int(VS.x) - 120, Color(1, 1, 1, 0.5))
		paste(img, crop, 12 + (i % cols) * (int(VS.x) + 12), 12 + (i / cols) * (int(VS.y) + 12))
	return img


func blend_box(img: Image, r: Rect2i, col: Color) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			img.set_pixel(x, y, img.get_pixel(x, y).lerp(Color(col.r, col.g, col.b), col.a))


# ---------------------------------------------------------------- figures

func figures_sheet(ids: PackedStringArray) -> Image:
	var figs: Dictionary = data["figures"]
	var names := []
	for fid in figs:
		if ids.size() == 0 or ids.has(fid):
			names.append(fid)
	var cell := 400
	var cols := 5
	var rows := int(ceil(names.size() / float(cols)))
	var img := canvas(12 + cols * (cell + 12), 12 + rows * (cell + 12))
	for i in names.size():
		var fid: String = names[i]
		var f: Dictionary = figs[fid]
		var frame: Array = f["frame"]
		var px: float = float(f.get("px", 4))
		var c := canvas(cell, cell, Color("2a2238") if i % 2 == 0 else Color("1d1526"))
		var sc := cell / float(frame[1])
		paste(c, rast(f["tex"], cell / (float(frame[1]) * px)), 0, 0)
		cross(c, vec(f["feet"]) * sc, Color(0.3, 0.8, 1.0), 6)
		var fl: Dictionary = f.get("flames", {})
		var styles: Dictionary = f.get("light", {})
		for name in fl:
			var q: Array = fl[name]
			var st: Dictionary = styles.get(name, {})
			if st.get("kind", "flame") == "eyes":
				for e in st.get("pts", []):
					glow_dot(c, vec(e) * sc, maxf(2.0, float(st.get("dot", 3.0)) * sc), Color(st.get("color", "7ef0c8")))
				# where a reader of the array alone puts them: EYE_GAP h apart
				var hq: float = float(q[2])
				for sx in [-0.5, 0.5]:
					cross(c, (Vector2(float(q[0]), float(q[1])) + Vector2(sx * EYE_GAP * hq, 0)) * sc, Color(1, 0.4, 1), 2)
			else:
				draw_flame(c, Vector2(float(q[0]), float(q[1])) * sc, float(q[2]) * sc, st.get("kind", "") == "cold")
			cross(c, Vector2(float(q[0]), float(q[1])) * sc, Color(1, 0.2, 0.2), 3)
		paste(img, c, 12 + (i % cols) * (cell + 12), 12 + (i / cols) * (cell + 12))
	return img


func lineup() -> Image:
	var figs: Dictionary = data["figures"]
	var k := 1.6
	var floor_y := 560
	var x := 20.0
	var img := canvas(2600, 620, Color("1d1526"))
	img.fill_rect(Rect2i(0, floor_y, 2600, 60), Color("2a2236"))
	var ka := 120.0 * k / 128.0
	var actor := canvas(int(128 * ka) + 2, int(128 * ka) + 2, Color(0, 0, 0, 0))
	for part in RIG_ORDER:
		paste(actor, rast("res://art/wick/%s.svg" % part, ka / 2.0), 0, 0)
	paste(img, actor, int(x), int(floor_y - RIG_FEET.y * ka))
	x += 130 * k * 0.8
	for fid in figs:
		if fid == "hush_eye":
			continue
		var f: Dictionary = figs[fid]
		var h: float = float(f["h"])
		var frame: Array = f["frame"]
		var kf := h * k / float(frame[1])
		var fimg := rast(f["tex"], kf / float(f.get("px", 4)))
		var feet: Vector2 = vec(f["feet"])
		paste(img, fimg, int(x - (feet.x - 128) * kf), int(floor_y - feet.y * kf))
		x += maxf(70.0, h * 0.62) * k
		if x > 2500:
			break
	return img


# ---------------------------------------------------------------- portraits

func portraits_sheet() -> Image:
	var ports: Dictionary = data["portraits"]
	var list := []
	for who in ports:
		for mood in ports[who]["moods"]:
			list.append([who, mood])
	var cell := 256
	var cols := 5
	var rows := int(ceil(list.size() / float(cols)))
	var rh := cell + 236 + 120
	var img := canvas(12 + cols * (cell + 12), 12 + rows * (rh + 12))
	for i in list.size():
		var who: String = list[i][0]
		var mood: String = list[i][1]
		var res := "res://art/story/portraits/%s_%s.svg" % [who, mood]
		var p: Dictionary = ports[who]
		var x := 12 + (i % cols) * (cell + 12)
		var y := 12 + (i / cols) * (rh + 12)
		var c := canvas(cell, cell, Color("2a2238"))
		var u := cell / 128.0
		paste(c, rast(res, cell / 768.0), 0, 0)
		ring(c, CROP_C * u, CROP_R * u, Color(0.3, 1, 0.5, 0.8), 1.5)
		for q in mood_flames(p, mood):
			draw_flame(c, Vector2(float(q[0]), float(q[1])) * u, float(q[2]) * u)
		paste(img, c, x, y)
		# the dialogue box's circle (r 46, a 2.5 px speaker ring and a 4 px ink
		# ring outside it) at 2x and 1x
		var col := Color(p.get("color", "f2c75a"))
		paste(img, circle_portrait(res, 46 * 2, col, 2.0, mood_flames(p, mood)), x, y + cell + 4)
		paste(img, circle_portrait(res, 46, col, 1.0, mood_flames(p, mood)), x + 70, y + cell + 4 + 236)
	return img


func mood_flames(p: Dictionary, mood: String) -> Array:
	var mf: Dictionary = p.get("mood_flames", {})
	if mf.has(mood):
		return mf[mood]
	return p.get("flames", [])


# The portrait as the dialogue box draws it: the frame cropped to the circle of
# UV radius 0.42 around (64, 62) and shown at radius r px, with its rings and
# live flames; k scales the rings (2 for the 2x copy).
func circle_portrait(res: String, r: int, ring_col: Color, k: float, flames: Array) -> Image:
	var pad := int(12 * k)
	var d := (r + pad) * 2
	var img := canvas(d, d, Color("1d1529"))
	var c := Vector2(r + pad, r + pad)
	var u := r / CROP_R                        # view px per frame unit
	var src := rast(res, u * 128.0 / 768.0)
	var o := c - CROP_C * u                    # where the frame's origin lands
	for y in img.get_height():
		for x in img.get_width():
			var q := Vector2(x + 0.5, y + 0.5)
			var dd := q.distance_to(c)
			if dd <= r:
				var sx := int(q.x - o.x)
				var sy := int(q.y - o.y)
				var s := Color(0, 0, 0, 0)
				if sx >= 0 and sy >= 0 and sx < src.get_width() and sy < src.get_height():
					s = src.get_pixel(sx, sy)
				img.set_pixel(x, y, ring_col.darkened(0.72).blend(s))
			elif dd <= r + 2.5 * k:
				img.set_pixel(x, y, ring_col)
			elif dd <= r + 6.5 * k:
				img.set_pixel(x, y, INK)
	for q in flames:
		draw_flame(img, o + Vector2(float(q[0]), float(q[1])) * u, float(q[2]) * u)
	return img
