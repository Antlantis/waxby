extends Node2D
## What lies behind the level, in three parallax layers drawn once. A theme
## is its colours, the dark's tint (world reads colors()["dark"]) and a
## style:
##   cathedral  far vaults and a great rose window, an arcade of pointed
##              arches with lancet windows, near pillars with chains and banners
##   cavern     (World 2) a far cave wall with drip columns and, per theme,
##              waxfall curtains, a giant melted candle or pale lilies; wax
##              terraces with candle stubs; near stalactites, drip columns
##              and hanging roots
## Each layer is placed every frame so it slides slower than the tiles. The
## glowing bits (stained glass, candle clusters) are listed in `windows` so
## the World can light them above the dark.
##
## v3's themes (scripts/themes/*, merged by themes/loader.gd) name a style,
## a script at scripts/backdrops/<style>.gd (the plain one when it's
## missing): each layer is then cut into SLICE px slices Godot can cull, each
## slice drawing its own anchors with the style's draw(), and the windows are
## the style's windows(), computed here at build (a culled slice never draws,
## so nothing may be appended while drawing). A v3 theme whose style is
## "cathedral" or "cavern" (the secret gilt variants of W1-W2) keeps v2's
## unchunked drawing with its own colours. v2's themes below are untouched.

const THEMES := {
	"nave": {"sky": Color("150f1e"), "far": Color("1f1730"), "mid": Color("2a2040"), "near": Color("181226"),
			"glass": [Color("b8324e"), Color("3a6ab8"), Color("d8a830"), Color("5aa860")], "banner": Color("7a2e4a"),
			"dark": Color(0.30, 0.25, 0.42), "style": "cathedral"},
	"crypt": {"sky": Color("0f1216"), "far": Color("182024"), "mid": Color("202a2c"), "near": Color("121818"),
			"glass": [Color("4a8a70"), Color("7ac0a0"), Color("3a5a80")], "banner": Color("3a4a3e"),
			"dark": Color(0.24, 0.30, 0.32), "style": "cathedral"},
	"choir": {"sky": Color("1c0d0c"), "far": Color("2c1614"), "mid": Color("3a1e1a"), "near": Color("1e0f0e"),
			"glass": [Color("e0602a"), Color("f2b84b"), Color("b8324e")], "banner": Color("8a2a1e"),
			"dark": Color(0.40, 0.24, 0.24), "style": "cathedral"},
	"tower": {"sky": Color("0e1020"), "far": Color("1a1c34"), "mid": Color("24264a"), "near": Color("14142a"),
			"glass": [Color("8aa0e0"), Color("c0c8f0"), Color("6a70c0")], "banner": Color("3a3a7a"),
			"dark": Color(0.26, 0.28, 0.46), "style": "cathedral"},
	# World 2: the Tallow Deep.
	"waxfall": {"sky": Color("14100e"), "far": Color("221a14"), "mid": Color("2e241a"), "near": Color("18120c"),
			"glass": [Color("e8c86a"), Color("f4ead6")], "banner": Color("6a4a2a"),
			"dark": Color(0.30, 0.26, 0.24), "style": "cavern", "wax": Color("cdb88e")},
	"chandlery": {"sky": Color("0c1418"), "far": Color("142228"), "mid": Color("1c2e34"), "near": Color("0e1a1e"),
			"glass": [Color("4ab8b0"), Color("bfe8ff")], "banner": Color("2a4a50"),
			"dark": Color(0.20, 0.28, 0.32), "style": "cathedral", "wax": Color("a8b8b0")},
	"garden": {"sky": Color("0c0f0c"), "far": Color("141a14"), "mid": Color("1c261c"), "near": Color("0e140e"),
			"glass": [Color("a8e0d0"), Color("d8e8c8")], "banner": Color("2a3a2a"),
			"dark": Color(0.15, 0.17, 0.16), "style": "cavern", "wax": Color("b8c8a8")},
	"undercandle": {"sky": Color("120e1e"), "far": Color("1e1830"), "mid": Color("2a2042"), "near": Color("141026"),
			"glass": [Color("8a6ae0"), Color("fff2c8")], "banner": Color("3a2a5a"),
			"dark": Color(0.20, 0.18, 0.30), "style": "cavern", "wax": Color("c8bcd8")},
}
const FACTORS := [0.12, 0.35, 0.65]
const SLICE := 1024.0            # a v3 style's slice width, in layer space
const Themes := preload("res://scripts/themes/loader.gd")

var theme := "nave"
var level_size := Vector2(2000, 480)
var view_size := Vector2(844, 390)
var windows: Array = []          # {layer, rect: Rect2 (layer space), color} or {layer, rose, center, radius}
var _layers: Array[Node2D] = []
var _colors := {}                # a v3 theme's colours (the loader's), else {} for v2's
var style_script: Script = null  # a v3 style (null: v2's cathedral / cavern drawing)


func build(p_theme: String, p_level_size: Vector2, p_view: Vector2) -> void:
	var v3 := not THEMES.has(p_theme) and Themes.has_theme(p_theme)
	theme = p_theme if THEMES.has(p_theme) or v3 else "nave"
	_colors = Themes.theme(theme) if v3 else {}
	style_script = Themes.style(theme) if v3 else null
	level_size = p_level_size
	view_size = p_view
	for c in get_children():
		c.queue_free()
	_layers.clear()
	windows.clear()
	var layer_script: Script = load("res://scripts/backdrop_layer.gd")
	for i in FACTORS.size():
		var layer := Node2D.new()
		layer.set_script(layer_script)
		layer.set("backdrop", self)
		layer.set("index", i)
		add_child(layer)
		_layers.append(layer)
		if style_script == null:
			continue
		# v3: cut into slices, and the windows now.
		layer.set("mode", 1)
		var sp := span(i)
		var x := -SLICE * 0.25
		while x < sp.x + 200.0:
			var sl := Node2D.new()
			sl.set_script(layer_script)
			sl.set("backdrop", self)
			sl.set("index", i)
			sl.set("mode", 2)
			sl.set("x0", x)
			sl.set("x1", x + SLICE)
			sl.set("style", style_script)
			layer.add_child(sl)
			x += SLICE
		for w in style_script.windows(i, colors(), sp):
			var wd: Dictionary = w
			wd["layer"] = i
			windows.append(wd)


func slice_count() -> int:
	var n := 0
	for l in _layers:
		n += l.get_child_count()
	return n


func span(i: int) -> Vector2:
	## How much of layer i there is to see across the level.
	var f: float = FACTORS[i]
	return Vector2(maxf(level_size.x - view_size.x, 0.0) * f + view_size.x, maxf(level_size.y - view_size.y, 0.0) * f + view_size.y)


func follow(cam_origin: Vector2) -> void:
	## cam_origin: the world point at the screen's top-left.
	for i in _layers.size():
		var f: float = FACTORS[i]
		_layers[i].position = cam_origin * (1.0 - f)


func layer_offset(i: int, cam_origin: Vector2) -> Vector2:
	return cam_origin * (1.0 - FACTORS[i])


func colors() -> Dictionary:
	return _colors if not _colors.is_empty() else THEMES[theme]


func style() -> String:
	return str(colors().get("style", "cathedral"))
