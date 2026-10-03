extends RefCounted
## v3's theme files, merged: every file in FILES that exists exports
##   const THEMES   := {id: {"style", "painter", "sky", "far", "mid", "near", "glass": [...], "banner", "dark_color", ...}}
##   const PALETTES := {id: {"stone", "shade", "lip", "mortar", "buried", ...}}
##   const AMBIENT  := {id: [{"kind", "count", "size", "color", "alpha", "drift", "sway", "parallax", "near_light"}]}
##   const EDGES    := {id: [{"what", "color", "alpha", "width"?}]}
## and they are merged here, so two art streams never edit one dictionary
## (A1 writes w3.gd and w4.gd, A2 w5.gd, w6.gd and modes.gd). modes.gd may
## also define `static func gilt(theme_id: String) -> Dictionary`, asked for
## any id ending in "_gilt" that no file lists (it receives the full id,
## e.g. "carillon_gilt", and picks its own base).
## v2's themes stay where they are (backdrop.gd THEMES, tile_view.gd
## PALETTES) and are not listed here: has_theme() is false for them, which is
## how backdrop.gd and tile_view.gd keep their v2 path.
##   const Themes := preload("res://scripts/themes/loader.gd")
##   Themes.theme("orchard")   Themes.palette("orchard")   Themes.ambient("orchard")

const FILES := [
	"res://scripts/themes/w3.gd",
	"res://scripts/themes/w4.gd",
	"res://scripts/themes/w5.gd",
	"res://scripts/themes/w6.gd",
	"res://scripts/themes/modes.gd",
]
const PAINTER_DIR := "res://scripts/tiles/"
const STYLE_DIR := "res://scripts/backdrops/"
const FALLBACK := "plain"          # scripts/tiles/plain.gd, scripts/backdrops/plain.gd

static var _themes := {}
static var _palettes := {}
static var _ambient := {}
static var _edges := {}
static var _gilt_src: Script = null
static var _extra: Array = []      # files registered by tests and tools
static var _loaded := false
static var _scripts := {}          # painter / style path -> Script (or null)


static func register(path: String) -> void:
	## Adds a theme file (tests, tools); reloads.
	if not _extra.has(path):
		_extra.append(path)
	_loaded = false


static func unregister(path: String) -> void:
	_extra.erase(path)
	_loaded = false


static func reload() -> void:
	_loaded = false


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	_themes = {}
	_palettes = {}
	_ambient = {}
	_edges = {}
	_gilt_src = null
	for path in FILES + _extra:
		if not ResourceLoader.exists(path):
			continue
		var sc = load(path)
		if sc == null or not (sc is Script):
			continue
		var cm: Dictionary = sc.get_script_constant_map()
		_merge(_themes, cm.get("THEMES", {}), path)
		_merge(_palettes, cm.get("PALETTES", {}), path)
		_merge(_ambient, cm.get("AMBIENT", {}), path)
		_merge(_edges, cm.get("EDGES", {}), path)
		for m in sc.get_script_method_list():
			if str(m["name"]) == "gilt":
				_gilt_src = sc


static func _merge(into: Dictionary, add, path: String) -> void:
	if not (add is Dictionary):
		return
	for k in add:
		if into.has(k):
			push_warning("themes: %s defines %s again (the later file wins)" % [path, k])
		into[k] = add[k]


static func has_theme(id: String) -> bool:
	_load()
	if _themes.has(id):
		return true
	return id.ends_with("_gilt") and _gilt_src != null


static func ids() -> Array:
	_load()
	return _themes.keys()


static func theme(id: String) -> Dictionary:
	## The theme's dictionary (a copy, with "dark" = "dark_color" for the
	## World), or {} when no file has it.
	_load()
	var t = _themes.get(id, null)
	if t == null and id.ends_with("_gilt") and _gilt_src != null:
		t = _gilt_src.call("gilt", id)
		if t is Dictionary and not t.is_empty():
			_themes[id] = t
	if not (t is Dictionary):
		return {}
	var out: Dictionary = t.duplicate()
	if not out.has("dark") and out.has("dark_color"):
		out["dark"] = out["dark_color"]
	return out


static func palette(id: String) -> Dictionary:
	## PALETTES[id], else the theme's own "palette", else its "base" theme's.
	_load()
	if _palettes.has(id):
		return _palettes[id]
	var t := theme(id)
	if t.get("palette") is Dictionary:
		return t["palette"]
	var base := str(t.get("base", ""))
	if base != "" and base != id and _palettes.has(base):
		return _palettes[base]
	return {}


static func ambient(id: String) -> Array:
	_load()
	var a = _ambient.get(id, null)
	if a == null:
		var base := str(theme(id).get("base", ""))
		a = _ambient.get(base, []) if base != "" else []
	return a if a is Array else []


static func edges(id: String) -> Array:
	_load()
	var e = _edges.get(id, null)
	if e == null:
		var base := str(theme(id).get("base", ""))
		e = _edges.get(base, []) if base != "" else []
	return e if e is Array else []


static func painter(id: String) -> Script:
	## The theme's tile painter (scripts/tiles/<painter>.gd), else the plain
	## fallback. null for "" / "v2" (tile_view.gd draws v2's stone itself).
	var name := str(theme(id).get("painter", FALLBACK))
	if name == "" or name == "v2":
		return null
	return _script(PAINTER_DIR, name)


static func style(id: String) -> Script:
	## The theme's backdrop style (scripts/backdrops/<style>.gd), else the
	## plain fallback. null for v2's "cathedral" and "cavern" (backdrop_layer.gd
	## draws those itself, unchunked, with the theme's colours).
	var name := str(theme(id).get("style", FALLBACK))
	if name == "cathedral" or name == "cavern":
		return null
	return _script(STYLE_DIR, name)


static func _script(dir: String, name: String) -> Script:
	var path := dir + name + ".gd"
	if _scripts.has(path):
		return _scripts[path]
	var sc: Script = null
	if ResourceLoader.exists(path):
		sc = load(path)
	if sc == null:
		push_warning("themes: no %s, drawing with %s%s.gd" % [path, dir, FALLBACK])
		sc = load(dir + FALLBACK + ".gd")
	_scripts[path] = sc
	return sc
