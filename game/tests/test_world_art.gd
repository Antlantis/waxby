extends SceneTree
## A1's World 3 and World 4 art (tools/test.sh runs it headless):
## the theme files merge and name their painter and style; no W3 mote rises
## (3-3's updraft is the one that does); every palette passes the contrast
## rule (p_artaudio 4.0: stone/mid >= 1.45, stone/near >= 1.75, lip/mid >=
## 3.0, and every walkable top of the worlds' own tiles, belts included,
## >= 3.0 against mid); the tell accent (W3 spore c8d46a, W4 frost e8fcff),
## and anything within 0.08 of it, is kept off every colour but the tells':
## themes, palettes, motes, edge lines, the styles' and painters' literals,
## every colour of every prop but the tell frames; the no-draw_circle grep
## on A1's scripts; every prop SVG is there at its frame (width = 2 x
## viewBox, no <text> or <filter>), the points files agree with the engine
## (the flame points of v2's frames, the movers' ledge sizes, the weight's
## hurt circle) and the bob's silhouette covers that circle; the painters
## paint every tile of the stand-in rooms and the real W3-W4 levels (when
## they exist) inside 6000 vertices a chunk, flushing each; the styles draw
## every layer of every theme, make their windows at build and put every far
## window above the mid wall; each backdrop slice paints only its own strip
## and the slices add up to the whole layer (nothing cut at a seam); nothing
## that reads as a clock shows over the Tinker's arena; at 24 and 36 rows (the
## shapes plan's E9, backdrop.gd tall()) the same budgets and seams, the
## strip's composition kept at the top, the deep band filled, 3-2's tower's
## three storeys at 36 rows (E11), and v2's arcade going on down.
##
## Two more modes, for looking (they need a window):
##   $G --path . --resolution 1266x585 --script res://tests/test_world_art.gd -- shots <out_dir> [theme,...] [x,...]
##       each theme's stand-in room (or its real level, when there is one;
##       "<level>@<theme>" draws a level file in one of A1's themes, lab-1's
##       stations for one)
##       at a few columns, three ways: dark (the game's dark, brightness
##       "Dark"), half (the same frame at half brightness: a phone at 30%)
##       and bare (no dark: the art against its backdrop); with the preview
##       of the props where the features and the World will draw them
##       (preview_*: what WL3, WL4 and W0 are asked to wire)
##   $G --path . --resolution 1266x585 --script res://tests/test_world_art.gd -- dc [out_file]
##       draw calls a frame across each theme's stand-in and real levels
##       (W3 <= 600, W4 <= 650; spec 13.1)
##   $G --path . --resolution 1266x585 --script res://tests/test_world_art.gd -- seams [out_dir]
##       every layer of every theme rendered sliced (as backdrop.gd cuts it)
##       and in one piece, and the pixels that differ (0 wanted), for a
##       380-column level
## WAXBY_A1_LEVELS=<dir> takes the real levels from another copy's
## game/levels (a level stream's, before they land).

const LevelData := preload("res://scripts/level_data.gd")
const TriBatch := preload("res://scripts/tri_batch.gd")
const Themes := preload("res://scripts/themes/loader.gd")
const Orchard := preload("res://scripts/tiles/orchard.gd")
const Frost := preload("res://scripts/tiles/frost.gd")

const W3_THEMES := ["orchard", "rootvault", "sporewood", "rootheart"]
const W4_THEMES := ["clockface", "gearworks", "icebells", "escapement"]
const LEVEL_OF := {"orchard": "3-1", "rootvault": "3-2", "sporewood": "3-3", "rootheart": "3-4",
		"clockface": "4-1", "gearworks": "4-2", "icebells": "4-3", "escapement": "4-4"}
const ACCENT := {3: Color("c8d46a"), 4: Color("e8fcff")}
const ACCENT_NEAR := 0.08        # an RGB distance: closer than this counts as the accent
const TELL_KEYS := ["spore", "spore_hi", "frost"]   # the palettes' tell colours (the features' tells)
const TELL_FRAMES := ["spore_pod_swell", "spore_pod_burst", "spore_pod_hang_swell", "spore_pod_hang_burst", "icicle_crack"]
const DC_LIMIT := {3: 600, 4: 650}
const FLOOR_CAM := 225.0         # the camera's top with the hero on a 15-row level's floor (world.gd BELOW)
const MINE := ["res://scripts/themes/w3.gd", "res://scripts/themes/w4.gd", "res://scripts/tiles/orchard.gd",
		"res://scripts/tiles/frost.gd", "res://scripts/backdrops/orchard.gd", "res://scripts/backdrops/clockwork.gd"]
const NO_IMMEDIATE := ["draw_circle(", "draw_colored_polygon(", "draw_polyline("]
const PROPS_W3 := ["vine_top", "spore_pod_closed", "spore_pod_swell", "spore_pod_burst", "spore_pod_hang_closed",
		"spore_pod_hang_swell", "spore_pod_hang_burst", "glowfruit_hang", "glowfruit_lit", "glowfruit_dim",
		"skull_lantern_lit", "skull_lantern_out", "root_seal_open", "root_seal_closed", "altar_orchard", "altar_orchard_lit",
		"bell_orchard", "bell_orchard_beam", "sconce_bone"]
const PROPS_W4 := ["gear_s", "gear_m", "gear_l", "gear_s_shine", "gear_m_shine", "gear_l_shine", "cog_tooth", "swing_ledge",
		"swing_ledge_2", "swing_ledge_3", "belt_teeth", "pendulum_bob", "pendulum_pivot", "icicle_hang", "icicle_crack",
		"icicle_fall", "brass_lamp_lit", "brass_lamp_out", "clock_door_open", "clock_door_closed", "altar_frost",
		"altar_frost_lit", "bell_frost", "bell_frost_beam", "sconce_brass"]
# The frames v2's engine draws on (props.py): what the themed props keep.
const FRAME := {"altar": [64, 96], "bell": [128, 192], "sconce": [64, 64], "lantern": [64, 96], "seal": [128, 192]}

const W3_ROOM := [
	"######################################################################################################################",
	"######################################################################################################################",
	"######################################################################################################################",
	"######################....vvvv.............*.......###########################################......................##",
	"........{.......8..................................#......{...}...{...}.............##########.........8............##",
	"........{..........................................#......{...}...{...}.............##########...........{..........##",
	"........{...................o.o.o..................#......{...}...{...{.............###FF#####...........{..........##",
	"........{...o.o............=====.........BB........#......{.......{...{......o......###FF................i............",
	"........{................................BB...............{.......{...*.............###FF................{............",
	"........{.#####........................####...............{.......{...{................................=={............",
	"....c...{.#####................%%%%%%..####....c..............................b..........................{......L.....",
	"........{.#####........................####.............................................::::.............{............",
	"..P..@..{.#####....s...K...p....r......####.*...s..r.@...^^^^^^^^^^^^^^^^^......s.....M.:::::....s.......{........E...",
	"############################::::::::::#######...########################################:::::#########################",
	"############################::::::::::################################################################################",
]
const W3_ARENA := [
	"################################################",
	"################################################",
	"##############........8.......8.........########",
	"##############.+.{......................########",
	"##############==={......................########",
	"##############...{...................{..########",
	"##############...{..........+........{+.########",
	"##......######...{.......======......{..########",
	"##.....c######...{...................{..########",
	"##......######...{...+...............{..########",
	".................{.=====.............{..########",
	".................{...................{..########",
	".P...K...........{..+...........+....{.X########",
	"################################################",
	"################################################",
]
const W4_ROOM := [
	"######################################################################################################################################################",
	"######################################################################################################################################################",
	"##################################............................########################################################################################",
	"##################################............................###############################################################.........................",
	"##################################............................###############################################################.........................",
	"######....V.....V.....V###########............................########################............................###FF######..........V..............",
	"######...................#########...........o.o.o............########################............................###FF...............................",
	"..........................########.......................................Y.....................o.o.......o.o......###FF..........____.................",
	"..................#.......................O.......O.....................................................................................%%%%%.........",
	"..................#.....................................................................................................BBB...........................",
	"....c.............Z.........c.......c......................c......c..............c......c.....TTT.......TTT....c........BBB..............L............",
	"..................Z.....##ZZZ##.........................................................................................BBB....--.....................",
	"..P...........j...Z.....#.ooo.#.s........................b.s......................s.................................q.......e...u.................E...",
	"IIIIIIIIIIIIIIII##################>>>>...................<<<<<#############################^^^^^^^^^^^^^^^^^^###################>>>>###......#########",
	"#######################################################################################################################################^^^^^^#########",
]
const W4_ARENA := [
	"##############################################",
	"##############################################",
	"##############..............................##",
	"##############..............+...............##",
	"##############.............=====............##",
	"##############..............Y...............##",
	"##############..............................##",
	"##......######........O.............O.......##",
	"##.....c######..............................##",
	"##......######...+.....................+....##",
	"...............=====..................=====.##",
	"............................................##",
	".P...K................X......+..............##",
	"################IIIIII##########IIIIII########",
	"##############################################",
]
const W3_PROPS := [
	"##############################",
	"##############################",
	"##############################",
	"##############################",
	"##############################",
	"##############################",
	"##############################",
	"..............................",
	"........##########...###......",
	"........*.*.*.8.8.....}.......",
	".....{................}....c..",
	".....*................}.......",
	".P...{.*.*.*....K...L....E....",
	"##############################",
	"##############################",
]
const W4_PROPS := [
	"##############################",
	"##############################",
	"##############################",
	"##############################",
	"##############################",
	"##############################",
	"##############################",
	"..............................",
	"........##########............",
	".........V.V.V.Y..............",
	"...........................c..",
	"..............................",
	".P....____......K...L....E....",
	"####################.#####>>>#",
	"##############################",
]

var passed := 0
var failed := 0


class RectLog extends RefCounted:
	## Stands in for a slice: remembers what draw_rect was asked to draw.
	var rects: Array = []        # [Rect2, Color]

	func draw_rect(r: Rect2, col: Color, _filled := true, _w := -1.0, _aa := false) -> void:
		rects.append([r, col])


class CountBatch extends "res://scripts/tri_batch.gd":
	## A batch that remembers the most vertices it held when flushed.
	var peak := 0
	var flushes := 0

	func flush(ci: CanvasItem) -> void:
		peak = maxi(peak, vertex_count())
		flushes += 1
		super.flush(ci)


func _check(ok: bool, what: String) -> void:
	if ok:
		passed += 1
		if OS.get_environment("WAXBY_A1_VERBOSE") != "":
			print("ok: ", what)
	else:
		failed += 1
		print("FAIL: ", what)


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var game = root.get_node_or_null("Game")
	if game != null:
		game.settings_path = "user://test_world_art_settings.json"
		game.save_path = "user://test_world_art_save.json"
		game.reset()
	await process_frame
	if args.size() > 0 and args[0] == "shots":
		await _shots(args.slice(1))
		quit()
		return
	if args.size() > 0 and args[0] == "dc":
		await _dc(args.slice(1))
		quit()
		return
	if args.size() > 0 and args[0] == "seams":
		await _seams_px(args.slice(1))
		quit()
		return
	_test_loader()
	_test_contrast()
	_test_accent()
	_test_grep()
	_test_props()
	_test_points()
	await _test_painters()
	await _test_styles()
	_test_seams()
	_test_arena_clocks()
	await _test_tall()
	await _test_tall_v2()
	await _test_world()
	print("test_world_art: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)


# ---------------------------------------------------------------- the rooms

static func room(theme: String) -> RefCounted:
	## A stand-in room for a theme (W3's or W4's; "<theme>_arena" is the
	## world's boss arena with an approach, "<theme>_props" one screen of the
	## props: pods and glowfruit or icicles and a weight, the altar, lantern,
	## sconce and bell).
	var arena := theme.ends_with("_arena")
	var props := theme.ends_with("_props")
	var th := theme.trim_suffix("_arena").trim_suffix("_props")
	var w := 3 if W3_THEMES.has(th) else 4
	var rows: Array = (W3_ARENA if arena else (W3_PROPS if props else W3_ROOM)) if w == 3 else (W4_ARENA if arena else (W4_PROPS if props else W4_ROOM))
	var head := "title: %s\ntheme: %s\narea: %d\nhints: Hold jump to climb|Grey vines snap\n" % [th.capitalize(), th, 13 if w == 3 else 18]
	if arena:
		head += "boss: %s\n" % ("rootmother" if w == 3 else "tinker")
	var lv = LevelData.new()
	lv.id = "%d-a1%s" % [w, "b" if arena else ""]
	lv.parse(head + "---\n" + "\n".join(rows) + "\n")
	return lv


static func real_level(theme: String) -> RefCounted:
	## The theme's level: levels/<id>.txt, or (WAXBY_A1_LEVELS=<dir>, to look
	## at a level stream's copy before its levels land) <dir>/<id>.txt.
	var id: String = LEVEL_OF.get(theme.trim_suffix("_arena"), "")
	var path := "res://levels/%s.txt" % id
	var other := OS.get_environment("WAXBY_A1_LEVELS")
	if other != "":
		path = other.path_join("%s.txt" % id)
	if id == "" or not FileAccess.file_exists(path):
		return null
	return LevelData.load_file(path)


# ---------------------------------------------------------------- colour

static func lum(c: Color) -> float:
	var ch := [c.r, c.g, c.b]
	var out := 0.0
	var wts := [0.2126, 0.7152, 0.0722]
	for i in 3:
		var v: float = ch[i]
		v = v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
		out += wts[i] * v
	return out


static func ratio(a: Color, b: Color) -> float:
	var la := lum(a)
	var lb := lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func dist(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


# ---------------------------------------------------------------- the theme files

func _test_loader() -> void:
	for id in W3_THEMES + W4_THEMES:
		var w := 3 if W3_THEMES.has(id) else 4
		_check(Themes.has_theme(id), "%s is a theme (themes/w%d.gd)" % [id, w])
		var t: Dictionary = Themes.theme(id)
		var keys_ok := true
		for k in ["sky", "far", "mid", "near", "banner", "dark_color"]:
			keys_ok = keys_ok and t.get(k) is Color
		_check(keys_ok and t.get("glass") is Array and not (t["glass"] as Array).is_empty() and t.get("dark") == t.get("dark_color"),
				"%s: sky, far, mid, near, glass, banner and dark_color (the World's dark)" % id)
		_check(str(t.get("variant")) == id, "%s: its variant is itself (the style's set; gilt copies keep it)" % id)
		_check(Themes.painter(id) == load("res://scripts/tiles/%s.gd" % ("orchard" if w == 3 else "frost")),
				"%s paints with tiles/%s.gd" % [id, "orchard" if w == 3 else "frost"])
		_check(Themes.style(id) == load("res://scripts/backdrops/%s.gd" % ("orchard" if w == 3 else "clockwork")),
				"%s draws with backdrops/%s.gd" % [id, "orchard" if w == 3 else "clockwork"])
		var pal: Dictionary = Themes.palette(id)
		var pal_ok := true
		for k in ["stone", "shade", "lip", "mortar", "buried", "brick", "brick_shade", "brick_lip", "slab", "slab_lip", "drip"]:
			pal_ok = pal_ok and pal.get(k) is Color
		_check(pal_ok, "%s: the palette has the contract's keys" % id)
		var amb: Array = Themes.ambient(id)
		var motes := 0
		for e in amb:
			if str(e.get("kind", "")) not in ["breath", "streak", "pool", "ripple"]:
				motes += int(e.get("count", 0))
		_check(not amb.is_empty() and motes <= 64, "%s: motes within ambient's cap of 64 (%d)" % [id, motes])
		if w == 4:
			_check(amb.any(func(e): return str(e.get("kind", "")) == "breath"), "%s: the frost breath" % id)
		else:
			# 3-3's secret cue is the one stream of spores going up (spec 3.9)
			_check(not amb.any(func(e): return (e.get("drift", Vector2(0, -6)) as Vector2).y < 0.0),
					"%s: no mote rises (the Sporewood's updraft is the only one that does)" % id)
		var edges: Array = Themes.edges(id)
		_check(not edges.is_empty(), "%s: EDGES of its own (edge_lines' W%d default never applies)" % [id, w])
		_check(not edges.any(func(e): return str(e.get("what", "")) == "vine"),
				"%s: no static vine veins (a snapped rotten run's vein would linger; the orchard feature draws them)" % id)
		# lip and shelf lines only once edge_lines leaves a fallen crumble unlined
		var crumble_aware := FileAccess.get_file_as_string("res://scripts/edge_lines.gd").contains("ledge_present")
		_check(crumble_aware or not edges.any(func(e): return str(e.get("what", "")) in ["lip", "ledge"]),
				"%s: no lip or shelf lines while edge_lines would line a fallen crumble" % id)
		var props: Dictionary = t.get("props", {})
		var props_ok := props.size() == 9
		for k in props:
			props_ok = props_ok and FileAccess.file_exists("res://art/props/%s.svg" % props[k])
		_check(props_ok, "%s: its props map names 9 props that exist" % id)
		_check(t.get("water") is Color and t.get("water_deep") is Color, "%s: water colours" % id)


func _test_contrast() -> void:
	for id in W3_THEMES + W4_THEMES:
		var t: Dictionary = Themes.theme(id)
		var p: Dictionary = Themes.palette(id)
		var mid: Color = t["mid"]
		var near: Color = t["near"]
		var sm := ratio(p["stone"], mid)
		var sn := ratio(p["stone"], near)
		var lm := ratio(p["lip"], mid)
		_check(sm >= 1.45 and sn >= 1.75 and lm >= 3.0, "%s: the contrast rule (stone/mid %.2f >= 1.45, stone/near %.2f >= 1.75, lip/mid %.2f >= 3.0)"
				% [id, sm, sn, lm])
		# every other walkable top of the world's own tiles reads as well as a lip
		var tops := ["bark_lip", "slab_lip"] if W3_THEMES.has(id) else ["ice_hi", "brass_hi", "slab_lip"]
		for k in tops:
			var r := ratio(p[k], mid)
			_check(r >= 3.0, "%s: the %s top against the backdrop %.2f >= 3.0" % [id, k, r])
		if W4_THEMES.has(id):
			# a belt's top: what the painter draws just under the top line, and
			# the teeth strip's top band (the feature draws it over the track)
			var lv = LevelData.new()
			lv.parse("theme: %s\n---\n....\n.>>.\n####\n" % id)
			var log := RectLog.new()
			Frost._belt(log, TriBatch.new(), lv, 1, 1, Vector2(32, 32), p)
			var top_col := Color(0, 0, 0, 0)
			for rc in log.rects:
				var rr: Rect2 = rc[0]
				if rr.position.y <= 32.0 + 2.0 and rr.end.y >= 32.0 + 2.0 and rr.position.x <= 48.0 and rr.end.x >= 48.0:
					top_col = rc[1]
			var tb_svg := FileAccess.get_file_as_string("res://art/props/belt_teeth.svg")
			var re := RegEx.new()
			re.compile("<rect x=\"0\" y=\"0\" width=\"96\" height=\"[0-9.]+\" fill=\"#([0-9a-fA-F]{6})\"")
			var bands := re.search_all(tb_svg)
			var band := Color(bands[bands.size() - 1].get_string(1)) if bands.size() >= 2 else Color.BLACK
			_check(ratio(top_col, mid) >= 3.0 and ratio(band, mid) >= 3.0, "%s: a belt's top reads against the backdrop (painted %.2f, belt_teeth %.2f >= 3.0)"
					% [id, ratio(top_col, mid), ratio(band, mid)])


func _style_literals(path: String) -> Array:
	var out := []
	var src := FileAccess.get_file_as_string(path)
	var re := RegEx.new()
	re.compile("Color\\(\"([0-9a-fA-F]{6})\"\\)")
	for m in re.search_all(src):
		out.append(Color(m.get_string(1)))
	return out


func _test_accent() -> void:
	for w in [3, 4]:
		var accent: Color = ACCENT[w]
		var ids: Array = W3_THEMES if w == 3 else W4_THEMES
		var bad := []
		for id in ids:
			var t: Dictionary = Themes.theme(id)
			for k in t:
				var v = t[k]
				if v is Color and dist(v, accent) < ACCENT_NEAR:
					bad.append("%s.%s" % [id, k])
				elif v is Array:
					for c in v:
						if c is Color and dist(c, accent) < ACCENT_NEAR:
							bad.append("%s.%s" % [id, k])
			for e in Themes.ambient(id):
				if e.get("color") is Color and dist(e["color"], accent) < ACCENT_NEAR:
					bad.append("%s ambient %s" % [id, e.get("kind")])
			for e in Themes.edges(id):
				if e.get("color") is Color and dist(e["color"], accent) < ACCENT_NEAR:
					bad.append("%s edge %s" % [id, e.get("what")])
			var key := "spore" if w == 3 else "frost"
			var pal: Dictionary = Themes.palette(id)
			_check((pal.get(key) as Color).is_equal_approx(accent), "%s: the palette's %s is the tell accent" % [id, key])
			# every other key the painter and the features draw with
			for k in pal:
				if k in TELL_KEYS:
					continue
				if pal[k] is Color and dist(pal[k], accent) < ACCENT_NEAR:
					bad.append("%s palette %s #%s" % [id, k, (pal[k] as Color).to_html(false)])
		for path in ["res://scripts/backdrops/%s.gd" % ("orchard" if w == 3 else "clockwork"),
				"res://scripts/tiles/%s.gd" % ("orchard" if w == 3 else "frost")]:
			for c in _style_literals(path):
				if dist(c, accent) < ACCENT_NEAR and not c.is_equal_approx(accent):
					bad.append("%s literal #%s" % [path.get_file(), c.to_html(false)])
		_check(bad.is_empty(), "W%d: the tell accent #%s is kept off decoration: themes, palettes, motes, lines, styles, painters (%s)"
				% [w, accent.to_html(false), ", ".join(bad)])
	# The painters never draw the accent: the W3 painter never reads "spore".
	var src := FileAccess.get_file_as_string("res://scripts/tiles/orchard.gd")
	_check(not src.contains("\"spore"), "the orchard painter never paints with the spore accent")
	# In the props, the accent (and anything within ACCENT_NEAR of it) is the
	# tells' alone: the pods' swell and burst, the icicle's crack.
	var leak := []
	var hexre := RegEx.new()
	hexre.compile("#([0-9a-fA-F]{6})\\b")
	for w in [3, 4]:
		for n in (PROPS_W3 if w == 3 else PROPS_W4):
			if n in TELL_FRAMES:
				continue
			var s := FileAccess.get_file_as_string("res://art/props/%s.svg" % n)
			for m in hexre.search_all(s):
				var c := Color(m.get_string(1))
				if dist(c, ACCENT[w]) < ACCENT_NEAR:
					leak.append("%s #%s" % [n, m.get_string(1)])
					break
	var tells_ok := true
	for n in TELL_FRAMES:
		var w2 := 3 if n.begins_with("spore") else 4
		tells_ok = tells_ok and FileAccess.get_file_as_string("res://art/props/%s.svg" % n).to_lower().contains("#" + ACCENT[w2].to_html(false))
	_check(leak.is_empty(), "every colour of every prop but the tell frames keeps %.2f off its world's accent (%s)" % [ACCENT_NEAR, ", ".join(leak)])
	_check(tells_ok, "and the tell frames carry it")
	var grind := []
	for n in PROPS_W4:
		if FileAccess.get_file_as_string("res://art/props/%s.svg" % n).to_lower().contains("#e0602a"):
			grind.append(n)
	for c in _style_literals("res://scripts/backdrops/clockwork.gd") + _style_literals("res://scripts/tiles/frost.gd"):
		if dist(c, Color("e0602a")) < 0.05:
			grind.append("a literal")
	_check(grind.is_empty(), "no platform, gear or backdrop has the Spurwheel's grinder rim #e0602a (%s)" % ", ".join(grind))


func _test_grep() -> void:
	for path in MINE:
		var hits := []
		for line in FileAccess.get_file_as_string(path).split("\n"):
			var code := line.strip_edges()
			if code.begins_with("#"):
				continue
			for bad in NO_IMMEDIATE:
				if code.contains(bad):
					hits.append(bad)
		_check(FileAccess.file_exists(path) and hits.is_empty(), "%s draws nothing one call at a time (%s)" % [path, ", ".join(hits)])


# ---------------------------------------------------------------- the props

static func svg_frame(path: String) -> Array:
	## [width, height, viewbox width, viewbox height] from an SVG's header.
	var s := FileAccess.get_file_as_string(path)
	var re := RegEx.new()
	re.compile("width=\"(\\d+)\" height=\"(\\d+)\" viewBox=\"0 0 (\\d+) (\\d+)\"")
	var m := re.search(s)
	if m == null:
		return []
	return [int(m.get_string(1)), int(m.get_string(2)), int(m.get_string(3)), int(m.get_string(4))]


func _test_props() -> void:
	var want := {}
	for n in ["altar_orchard", "altar_orchard_lit", "altar_frost", "altar_frost_lit", "skull_lantern_lit", "skull_lantern_out",
			"brass_lamp_lit", "brass_lamp_out"]:
		want[n] = [64, 96]
	for n in ["bell_orchard", "bell_orchard_beam", "bell_frost", "bell_frost_beam", "root_seal_open", "root_seal_closed",
			"clock_door_open", "clock_door_closed"]:
		want[n] = [128, 192]
	for n in ["gear_s", "gear_s_shine"]:
		want[n] = [64, 64]
	for n in ["gear_m", "gear_m_shine"]:
		want[n] = [128, 128]
	for n in ["gear_l", "gear_l_shine"]:
		want[n] = [192, 192]
	want["cog_tooth"] = [128, 32]
	want["swing_ledge"] = [64, 32]
	want["swing_ledge_2"] = [128, 32]
	want["swing_ledge_3"] = [192, 32]
	want["belt_teeth"] = [96, 16]
	want["pendulum_bob"] = [80, 80]
	var bad := []
	for n in PROPS_W3 + PROPS_W4:
		var path := "res://art/props/%s.svg" % n
		if not FileAccess.file_exists(path):
			bad.append(n + " (missing)")
			continue
		var s := FileAccess.get_file_as_string(path)
		if s.contains("<text") or s.contains("<filter"):
			bad.append(n + " (<text> or <filter>)")
		var f := svg_frame(path)
		if f.is_empty() or f[0] != 2 * f[2] or f[1] != 2 * f[3]:
			bad.append(n + " (width is not 2 x viewBox)")
			continue
		var size: Array = want.get(n, [64, 64])
		if f[2] != size[0] or f[3] != size[1]:
			bad.append("%s (%dx%d, not %dx%d)" % [n, f[2], f[3], size[0], size[1]])
		if not ResourceLoader.exists(path):
			bad.append(n + " (not imported)")
	_check(bad.is_empty(), "every W3 and W4 prop is there at its frame, imported (%s)" % ", ".join(bad))


static func _pt(d: Dictionary, prop: String, key: String) -> Vector2:
	var a = (d.get(prop, {}) as Dictionary).get(key, null)
	if not (a is Array) or (a as Array).size() < 2:
		return Vector2(-999, -999)
	return Vector2(float(a[0]), float(a[1]))


func _test_points() -> void:
	var d3 = JSON.parse_string(FileAccess.get_file_as_string("res://art/props/points_w3.json"))
	var d4 = JSON.parse_string(FileAccess.get_file_as_string("res://art/props/points_w4.json"))
	_check(d3 is Dictionary and d4 is Dictionary, "points_w3.json and points_w4.json parse")
	if not (d3 is Dictionary and d4 is Dictionary):
		return
	var missing := []
	for d in [d3, d4]:
		for k in d:
			if not str(k).begins_with("_") and not FileAccess.file_exists("res://art/props/%s.svg" % k):
				missing.append(k)
	_check(missing.is_empty(), "every prop the points files name exists (%s)" % ", ".join(missing))
	# v2's frames' points (props.py; world.gd and level_features.gd draw on them)
	var same := true
	for n in ["altar_orchard", "altar_orchard_lit"]:
		same = same and _pt(d3, n, "flame") == Vector2(32, 22)
	for n in ["altar_frost", "altar_frost_lit"]:
		same = same and _pt(d4, n, "flame") == Vector2(32, 22)
	same = same and _pt(d3, "sconce_bone", "flame") == Vector2(32, 14) and _pt(d4, "sconce_brass", "flame") == Vector2(32, 14)
	for n in ["skull_lantern_lit", "skull_lantern_out"]:
		same = same and _pt(d3, n, "flame") == Vector2(32, 30)
	for n in ["brass_lamp_lit", "brass_lamp_out"]:
		same = same and _pt(d4, n, "flame") == Vector2(32, 30)
	same = same and _pt(d3, "bell_orchard", "hang") == Vector2(64, 20) and _pt(d4, "bell_frost", "hang") == Vector2(64, 20)
	_check(same, "the themed altars (32,22), sconces (32,14), lanterns (32,30) and bells (64,20) keep v2's points")
	# the movers' sizes (movers.gd) and the weight's hurt circle (features/clockwork.gd)
	var Movers = load("res://scripts/movers.gd")
	var ledge_h := float(Movers.LEDGE_H)
	var tooth: Array = d4["cog_tooth"]["ledge"]
	_check(is_equal_approx(float(tooth[2]), 2.0 * 2 * 32) and is_equal_approx(float(tooth[3]), 2.0 * ledge_h),
			"cog_tooth's ledge is a 2-tile tooth, %d px tall (movers.gd)" % int(ledge_h))
	var swings_ok := true
	for n in [1, 2, 3]:
		var key := "swing_ledge" if n == 1 else "swing_ledge_%d" % n
		var r: Array = d4[key]["ledge"]
		swings_ok = swings_ok and is_equal_approx(float(r[2]), 64.0 * n) and is_equal_approx(float(r[3]), 2.0 * ledge_h)
	_check(swings_ok, "swing_ledge 1..3 tiles, the mover's height")
	var cw = load("res://scripts/features/clockwork.gd")
	var wr := float(cw.WEIGHT_R) if cw != null and cw.get_script_constant_map().has("WEIGHT_R") else 18.0
	_check(is_equal_approx(float(d4["pendulum_bob"]["hurt_r"]), 2.0 * wr), "the bob's frame names the weight's hurt circle (r %d px)" % int(wr))
	_bob_cover(wr)
	_check(is_equal_approx(float(d4["belt_teeth"]["period"]), 32.0), "belt_teeth repeat every 16 px")


func _bob_cover(wr: float) -> void:
	## pendulum_bob drawn as asked (40 x 40 px, centred on the bob): its
	## silhouette covers the weight's hurt circle (nothing hurts where nothing
	## is drawn), and reaches little past it but the rod's ring.
	var tex: Texture2D = load("res://art/props/pendulum_bob.svg")
	var img: Image = tex.get_image() if tex != null else null
	if img == null:
		_check(false, "pendulum_bob loads as an image")
		return
	if img.is_compressed():
		img.decompress()
	var w := img.get_width()
	var k := w / 40.0
	var c := Vector2(w, w) * 0.5
	var inside := 0
	var faint := 0
	var opaque := 0
	var past := 0
	for y in img.get_height():
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			var a := img.get_pixel(x, y).a
			var d := p.distance_to(c) / k
			if d <= wr:
				inside += 1
				if a < 0.5:
					faint += 1
			elif a >= 0.5:
				opaque += 1
				if d > wr + 1.5 and p.y / k > 5.0:
					past += 1
	var cover := 1.0 - float(faint) / maxf(inside, 1.0)
	_check(cover >= 0.97 and past <= 0.02 * inside, "the bob's silhouette covers its hurt circle (%.1f%% of r %d px; %d px drawn past it but the ring)"
			% [cover * 100.0, int(wr), past])


# ---------------------------------------------------------------- the painters

func _paint_all(lv: RefCounted, painter: Script, pal: Dictionary) -> Dictionary:
	## Paints every chunk of lv on a probe; {peak, flushes, chunks, left}.
	var probe := Node2D.new()
	root.add_child(probe)
	var cb := CountBatch.new()
	var res := {"peak": 0, "flushes": 0, "chunks": 0, "left": 0}
	probe.draw.connect(func():
		for i in ceili(lv.width / 16.0):
			painter.paint_chunk(probe, cb, lv, i * 16, mini(i * 16 + 16, lv.width), pal, null)
			res["chunks"] += 1
			res["left"] += cb.vertex_count()
		res["peak"] = cb.peak
		res["flushes"] = cb.flushes
	)
	probe.queue_redraw()
	await process_frame
	await process_frame
	probe.queue_free()
	return res


func _every_tile_room() -> RefCounted:
	## Every tile a W3 or W4 level may hold, in a few shapes (overhangs,
	## runs, buried, walls), for the painters.
	var rows := [
		"########################################",
		"#......v^v............{.}..............#",
		"#..=====..%%%%..___...{.}...BBB..IIII..#",
		"#.....................{.}...BBB........#",
		"#..FF..ZZ..<<>>..GGAA..........::::....#",
		"#..FF..ZZ..>><<..GGAA..........::::....#",
		"#......................................#",
		"#.......##############.................#",
		"#.......#............#......{{{........#",
		"#..P....#.....E......#......{{{........#",
		"##########################IIII##########",
		"########################################",
		"########################################",
		"########################################",
		"########################################",
	]
	var lv = LevelData.new()
	lv.id = "3-a1t"
	lv.parse("theme: orchard\n---\n" + "\n".join(rows) + "\n")
	return lv


func _test_painters() -> void:
	var every := _every_tile_room()
	for id in W3_THEMES + W4_THEMES:
		var w := 3 if W3_THEMES.has(id) else 4
		var painter: Script = Themes.painter(id)
		for which in ["room", "every"]:
			var lv: RefCounted = room(id) if which == "room" else every
			var r: Dictionary = await _paint_all(lv, painter, Themes.palette(id))
			_check(r["chunks"] > 0 and r["flushes"] == r["chunks"] and r["left"] == 0,
					"%s paints the %s: one flush a chunk, nothing left (%d chunks)" % [id, which, r["chunks"]])
			_check(r["peak"] > 0 and r["peak"] <= 6000, "%s: the %s room's chunks within 6000 vertices (at most %d)" % [id, which, r["peak"]])
	for id in ["rootheart_arena", "escapement_arena"]:
		var lv: RefCounted = room(id)
		var th: String = str(id).trim_suffix("_arena")
		var r: Dictionary = await _paint_all(lv, Themes.painter(th), Themes.palette(th))
		_check(r["peak"] > 0 and r["peak"] <= 6000, "%s: its arena chunks within 6000 vertices (at most %d)" % [th, r["peak"]])
	# Mother Gravebough's root mass: the wall behind her X
	var ar: RefCounted = room("rootheart_arena")
	var wall: Rect2i = Orchard.root_wall(ar)
	var bx := -1
	for e in ar.entities:
		if e["kind"] == "boss":
			bx = (e["cell"] as Vector2i).x
	_check(bx > 0 and wall.position.x == bx + 1 and wall.size.x == 8 and wall.position.y == 2 and wall.end.y == 13,
			"the root mass fills her wall: X + 1 .. + 8, rows 2 .. 12 (%s)" % str(wall))
	_check(Orchard.root_wall(room("orchard")).size == Vector2i.ZERO and Orchard.root_wall(room("escapement_arena")).size == Vector2i.ZERO,
			"and only where she stands")
	# a sealed door (stone where the level drew air) is drawn as the seal
	var door: Array = load("res://scripts/boss_arena.gd").find(ar, LevelData.cell_floor(Vector2i(bx, 12)))["door"]
	_check(door.size() == 6, "the arena's door is 2 x 3 cells")
	var sealed_before: bool = Orchard._sealed(ar, door[0].x, door[0].y)
	for c in door:
		ar.set_tile(c.x, c.y, LevelData.STONE)
	_check(not sealed_before and Orchard._sealed(ar, door[0].x, door[0].y) and not Orchard._sealed(ar, 0, 14),
			"a sealed door cell reads as the seal, plain stone doesn't")
	var rs: Dictionary = await _paint_all(ar, Orchard, Themes.palette("rootheart"))
	_check(rs["peak"] <= 6000, "the sealed arena still paints")
	# the rotten vine helper for the orchard feature: a frame's worth
	var probe := Node2D.new()
	root.add_child(probe)
	var cb := CountBatch.new()
	var lv3: RefCounted = room("rootvault")
	var n := [0]
	probe.draw.connect(func():
		for y in lv3.height:
			for x in lv3.width:
				if lv3.tile(x, y) == 13:
					Orchard.vine_cell(cb, lv3, x, y, true, Themes.palette("rootvault"), 2.0, 0.6)
					n[0] += 1
		cb.flush(probe)
	)
	probe.queue_redraw()
	await process_frame
	await process_frame
	probe.queue_free()
	_check(n[0] > 0 and cb.peak > 0 and cb.peak < 400 * n[0], "Orchard.vine_cell draws a rotten run (%d cells, %d vertices)" % [n[0], cb.peak])


# ---------------------------------------------------------------- the styles

static func _areas(log: RefCounted, tb) -> Dictionary:
	## The area drawn in each colour (rects and triangles), and the x extent.
	var out := {"_x0": INF, "_x1": -INF}
	for rc in log.rects:
		var r: Rect2 = rc[0]
		var k: String = (rc[1] as Color).to_html(true)
		out[k] = float(out.get(k, 0.0)) + absf(r.size.x * r.size.y)
		out["_x0"] = minf(out["_x0"], r.position.x)
		out["_x1"] = maxf(out["_x1"], r.end.x)
	var pts: PackedVector2Array = tb.points
	var idx: PackedInt32Array = tb.indices
	for t in range(0, idx.size(), 3):
		var a := pts[idx[t]]
		var b := pts[idx[t + 1]]
		var c := pts[idx[t + 2]]
		var k2: String = (tb.colors[idx[t]] as Color).to_html(true)
		out[k2] = float(out.get(k2, 0.0)) + absf((b - a).cross(c - a)) * 0.5
	for p in pts:
		out["_x0"] = minf(out["_x0"], p.x)
		out["_x1"] = maxf(out["_x1"], p.x)
	return out


func _test_seams() -> void:
	## Each slice paints exactly its strip [x0, x1) of the whole layer: nothing
	## outside it (the next slice's sky or wall would cover it), and the
	## slices add up, colour by colour, to the layer drawn in one piece (an
	## element cut at a seam, or one reaching past OVER, would come up short).
	var Backdrop = load("res://scripts/backdrop.gd")
	for id in W3_THEMES + W4_THEMES:
		var bd: Node2D = Backdrop.new()
		root.add_child(bd)
		bd.build(id, Vector2(380 * 32, 480), Vector2(844, 390))
		var style: Script = bd.style_script
		var inside := true
		var worst := 0.0
		var what := ""
		for i in 3:
			var sp: Vector2 = bd.span(i)
			var sum := {}
			var x := -256.0
			var x_end := x
			while x < sp.x + 200.0:
				var log := RectLog.new()
				var tb = TriBatch.new()
				style.draw(log, tb, i, bd.colors(), sp, x, x + 1024.0)
				var a := _areas(log, tb)
				inside = inside and float(a["_x0"]) >= x - 0.01 and float(a["_x1"]) <= x + 1024.0 + 0.01
				for k in a:
					if not str(k).begins_with("_"):
						sum[k] = float(sum.get(k, 0.0)) + float(a[k])
				x += 1024.0
				x_end = x
			var log2 := RectLog.new()
			var tb2 = TriBatch.new()
			style.draw(log2, tb2, i, bd.colors(), sp, -256.0, x_end)
			var whole := _areas(log2, tb2)
			for k in whole:
				if str(k).begins_with("_"):
					continue
				var d := absf(float(whole[k]) - float(sum.get(k, 0.0))) / maxf(float(whole[k]), 1.0)
				if d > worst:
					worst = d
					what = "layer %d #%s" % [i, k]
			for k in sum:
				if not whole.has(k):
					worst = 1.0
					what = "layer %d #%s only sliced" % [i, k]
		_check(inside, "%s: every slice draws inside its own strip" % id)
		_check(worst < 1e-3, "%s: the slices add up to the whole layer, colour by colour (worst %.5f, %s)" % [id, worst, what])
		bd.queue_free()


func _test_styles() -> void:
	var Backdrop = load("res://scripts/backdrop.gd")
	for id in W3_THEMES + W4_THEMES:
		var w := 3 if W3_THEMES.has(id) else 4
		var bd: Node2D = Backdrop.new()
		root.add_child(bd)
		var size := Vector2(380 * 32, 480)
		bd.build(id, size, Vector2(844, 390))
		_check(bd.style_script == Themes.style(id) and bd.slice_count() > 3, "%s: the backdrop is its style, sliced (%d slices)" % [id, bd.slice_count()])
		var style: Script = bd.style_script
		var worst := [0]
		var probe := Node2D.new()
		root.add_child(probe)
		var cb := CountBatch.new()
		var layers := {}
		probe.draw.connect(func():
			for i in 3:
				var sp: Vector2 = bd.span(i)
				var x := -256.0
				while x < sp.x + 200.0:
					style.draw(probe, cb, i, bd.colors(), sp, x, x + 1024.0)
					worst[0] = maxi(worst[0], cb.vertex_count())
					if cb.vertex_count() > 0:
						layers[i] = true
					cb.flush(probe)
					x += 1024.0
		)
		probe.queue_redraw()
		await process_frame
		await process_frame
		probe.queue_free()
		_check(layers.size() == 3, "%s: every layer draws" % id)
		_check(worst[0] <= 6000, "%s: a backdrop slice within 6000 vertices (at most %d)" % [id, worst[0]])
		var wins: Array = bd.windows
		var wins_ok := true
		for wd in wins:
			var has_pos: bool = (wd.get("rose", false) and wd.get("center") is Vector2 and float(wd.get("radius", 0)) > 0.0) \
					or (not wd.get("rose", false) and wd.get("rect") is Rect2)
			var tint_ok: bool = not wd.has("tint") or (wd["tint"] as Color).a <= 0.6
			wins_ok = wins_ok and has_pos and tint_ok and int(wd.get("layer", -1)) in [0, 1, 2]
		_check(wins_ok, "%s: its windows are made at build, on their layers, lightly tinted (%d)" % [id, wins.size()])
		# a far window's light comes from something you can see: with the
		# hero on the floor (the camera about 225 px down) its centre is
		# above the mid wall on screen (far y - 0.12 cam < wall - 0.35 cam)
		var wall: float = style.wall_top(str(bd.colors().get("variant", id)), bd.span(1))
		var seen := true
		var worst_y := -INF
		for wd in wins:
			if int(wd["layer"]) != 0:
				continue
			var cy: float = (wd["center"] as Vector2).y if wd.get("rose", false) else (wd["rect"] as Rect2).get_center().y
			worst_y = maxf(worst_y, cy)
			seen = seen and cy - 0.12 * FLOOR_CAM < wall - 0.35 * FLOOR_CAM
		_check(seen, "%s: every far window sits above the mid wall with the hero on the floor (lowest at %.0f, the wall shows from %.0f)"
				% [id, worst_y, wall - 0.23 * FLOOR_CAM])
		bd.queue_free()
		await process_frame


func _arena_view(lv: RefCounted, factor: float) -> float:
	## The first layer x a parallax layer shows while the hero is in lv's
	## boss arena (from its door to its far wall, the camera clamped).
	var bx := -1
	for e in lv.entities:
		if e["kind"] == "boss":
			bx = (e["cell"] as Vector2i).x
	if bx < 0:
		return INF
	var ar: Dictionary = load("res://scripts/boss_arena.gd").find(lv, LevelData.cell_floor(Vector2i(bx, 12)))
	var half := 850.0 * 0.5          # the phone's view is 847 wide
	var w := float(lv.width * 32)
	var cam := clampf(float(ar["left"]), half, w - half)
	return factor * (cam - half)


func _test_arena_clocks() -> void:
	## Nothing that reads as a clock over the Tinker's arena: the escape
	## wheels and their pendulums stay out of what the far layer shows there,
	## and the benches' little clocks in what the mid layer shows are handless.
	var cm: Script = load("res://scripts/backdrops/clockwork.gd")
	var Backdrop = load("res://scripts/backdrop.gd")
	var lvs := [room("escapement_arena")]
	var real: RefCounted = real_level("escapement")
	if real != null:
		lvs.append(real)
	var probe = LevelData.new()
	probe.id = "4-a1p"
	probe.parse("title: Probe\ntheme: escapement\narea: 18\nboss: tinker\n---\n" + "\n".join(_long_arena(170)) + "\n")
	lvs.append(probe)
	for lv in lvs:
		var bd: Node2D = Backdrop.new()
		root.add_child(bd)
		bd.build("escapement", lv.pixel_size(), Vector2(844, 390))
		var sp0: Vector2 = bd.span(0)
		var sp1: Vector2 = bd.span(1)
		var far0 := _arena_view(lv, 0.12)
		var mid0 := _arena_view(lv, 0.35)
		var clear := true
		for wh in cm._wheels(sp0):
			clear = clear and cm.wheel_extent(wh).y < far0 and cm.wheel_extent(wh).y < sp0.x - cm.ARENA_FAR
		_check(clear and far0 >= sp0.x - cm.ARENA_FAR and mid0 >= sp1.x - cm.ARENA_MID,
				"%d columns: no wheel or pendulum in the far layer over the arena (it shows from %.0f; the rule keeps %.0f..), "
				% [lv.width, far0, sp0.x - cm.ARENA_FAR] + "the mid's handless clocks from %.0f (it shows from %.0f)" % [sp1.x - cm.ARENA_MID, mid0])
		bd.queue_free()
	var n: int = cm._wheels(Vector2((170 * 32 - 844) * 0.12 + 844, 400)).size()
	_check(n == 1, "a 170-column 4-4 has its one great wheel, seen on the way in (%d)" % n)


static func _long_arena(width: int) -> Array:
	## W4_ARENA at the end of a level width columns wide (the approach flat).
	var rows := []
	for r in W4_ARENA.size():
		var line: String = W4_ARENA[r]
		var pad := ("#" if r < 2 or r >= 13 else ".").repeat(width - line.length())
		if r == 12:
			pad = ".P" + ".".repeat(width - line.length() - 2)
			line = line.replace(".P", "..")
		rows.append(pad + line)
	return rows


# ---------------------------------------------------------------- tall levels (the shapes plan's E9, E11)

const TALL_ROWS := [24, 36]
const FACTORS := [0.12, 0.35, 0.65]   # backdrop.gd's
const DEEP_MIN := 0.008          # the least of the deep band a tall level's mid and near layers fill (calibrated: the sparsest, 3-3's moss, 1.5%)
# Each style's own floor for its deep band, [far, mid, near]: about 60% of
# what it draws there at 24 and 36 rows (the lesser), so a style that loses
# its storeys' things below the strip fails, not only one gone bare (a
# near layer drawn sparse by design keeps its own low floor). The by-eye
# sign-off, with the dark on, waits for the real levels (the shapes plan).
const DEEP_FLOOR := {
	"orchard": [0.0, 0.068, 0.039], "rootvault": [0.0, 0.119, 0.126], "sporewood": [0.0, 0.161, 0.009],
	"clockface": [0.0, 0.048, 0.033], "gearworks": [0.0, 0.116, 0.009], "icebells": [0.0, 0.086, 0.009],
	"escapement": [0.0, 0.043, 0.009], "choirglass": [0.0, 0.05, 0.029], "rosewind": [0.0, 0.019, 0.009],
	"voidnave": [0.0, 0.008, 0.013], "stillshore": [0.0, 0.0, 0.011], "drownbell": [0.0, 0.0, 0.011],
	"trialhall": [0.0, 0.139, 0.065],
	"nave": [0.0, 0.13, 0.065], "crypt": [0.0, 0.13, 0.065], "choir": [0.0, 0.13, 0.065], "chandlery": [0.0, 0.13, 0.065],
	"waxfall": [0.0, 0.754, 0.124], "garden": [0.0, 0.736, 0.123]}


static func deep_floor(style: String, i: int) -> float:
	## The least style's layer i must fill of its deep band: its own floor,
	## never under DEEP_MIN.
	return maxf(DEEP_MIN, float((DEEP_FLOOR.get(style, [0.0, 0.0, 0.0]) as Array)[i]))


static func tall_elements(style: Script, colors: Dictionary, sp: Vector2, i: int, tall: float, y_top := INF) -> PackedStringArray:
	## Every rect narrower than a fill and every triangle a layer draws, as
	## text (slice by slice, as backdrop.gd cuts it), those wholly above
	## y_top only.
	var out := PackedStringArray()
	var x := -256.0
	while x < sp.x + 200.0:
		var log := RectLog.new()
		var tb = TriBatch.new()
		style.draw(log, tb, i, colors, sp, x, x + 1024.0, tall)
		for rc in log.rects:
			var r: Rect2 = (rc[0] as Rect2).abs()
			if r.size.x < 500.0 and r.end.y < y_top:
				out.append("%s %s" % [r, rc[1]])
		for t in range(0, tb.indices.size(), 3):
			var a: Vector2 = tb.points[tb.indices[t]]
			var b: Vector2 = tb.points[tb.indices[t + 1]]
			var c: Vector2 = tb.points[tb.indices[t + 2]]
			var cut := a.x in [x, x + 1024.0] or b.x in [x, x + 1024.0] or c.x in [x, x + 1024.0]
			if maxf(a.y, maxf(b.y, c.y)) < y_top and not cut:
				# (a piece clip_strip cut at the seam is the piece of a whole
				# element: one reaching down to the bottom is cut otherwise)
				out.append("%s %s %s %s" % [a, b, c, tb.colors[tb.indices[t]]])
		x += 1024.0
	return out


static func tall_cover(style: Script, colors: Dictionary, sp: Vector2, i: int, tall: float, y0: float, y1: float) -> float:
	## How much of the band y0..y1 across the layer its things cover (not
	## its fills: rects as wide as a slice), 0..1 (overlaps count twice).
	var area := 0.0
	var x := -256.0
	while x < sp.x + 200.0:
		var log := RectLog.new()
		var tb = TriBatch.new()
		style.draw(log, tb, i, colors, sp, x, x + 1024.0, tall)
		for rc in log.rects:
			var r: Rect2 = (rc[0] as Rect2).abs()
			if r.size.x >= 500.0 or (rc[1] as Color).a < 0.02:
				continue
			var a := maxf(r.position.y, y0)
			var b := minf(r.end.y, y1)
			if b > a:
				area += (b - a) * r.size.x
		for t in range(0, tb.indices.size(), 3):
			var p: Vector2 = tb.points[tb.indices[t]]
			var q: Vector2 = tb.points[tb.indices[t + 1]]
			var c: Vector2 = tb.points[tb.indices[t + 2]]
			var cy := (p.y + q.y + c.y) / 3.0
			if cy >= y0 and cy < y1:
				area += absf((q - p).cross(c - p)) * 0.5
		x += 1024.0
	return area / (sp.x * (y1 - y0))


static func deep_band(i: int, rows: int) -> Vector2:
	## The band of layer i only a level of this many rows shows: from the
	## deepest a 15-row level's camera shows it to the deepest this one's does.
	return Vector2(250.0 * FACTORS[i] + 390.0, (rows * 32 + 160 - 390) * FACTORS[i] + 390.0)


func _test_tall() -> void:
	## A1's styles at 24 and 36 rows (768 and 1152 px backdrops): each slice
	## inside 6000 vertices and only its own strip (adding up to the layer);
	## the strip's composition at the top as it was (every element of a
	## 15-row level's upper half drawn the same: nothing stretches), its far
	## set pieces where they were; the band only a tall level shows filled
	## (mid and near: at least the style's own floor, DEEP_FLOOR: no bare
	## wall where the strip's elements ran out); and
	## 3-2's tower (E11) at 36 rows: the canopy over the top, roots in the
	## bottom storey's view, the ossuary between.
	var Backdrop = load("res://scripts/backdrop.gd")
	for id in W3_THEMES + W4_THEMES:
		if id == "rootheart":
			continue   # (her arena is a strip)
		var strip: Node2D = Backdrop.new()
		root.add_child(strip)
		strip.build(id, Vector2(380 * 32, 480), Vector2(844, 390))
		var style: Script = strip.style_script
		for rows in TALL_ROWS:
			var bd: Node2D = Backdrop.new()
			root.add_child(bd)
			bd.build(id, Vector2(380 * 32, rows * 32), Vector2(844, 390))
			var worst := 0
			var inside := true
			var seam := 0.0
			var kept := true
			for i in 3:
				var sp: Vector2 = bd.span(i)
				var tall: float = bd.tall(i)
				var sum := {}
				var x := -256.0
				while x < sp.x + 200.0:
					var log := RectLog.new()
					var tb = TriBatch.new()
					style.draw(log, tb, i, bd.colors(), sp, x, x + 1024.0, tall)
					worst = maxi(worst, tb.vertex_count())
					var a := _areas(log, tb)
					inside = inside and float(a["_x0"]) >= x - 0.01 and float(a["_x1"]) <= x + 1024.0 + 0.01
					for k in a:
						if not str(k).begins_with("_"):
							sum[k] = float(sum.get(k, 0.0)) + float(a[k])
					x += 1024.0
				var log2 := RectLog.new()
				var tb2 = TriBatch.new()
				style.draw(log2, tb2, i, bd.colors(), sp, -256.0, x, tall)
				var whole := _areas(log2, tb2)
				for k in whole:
					if not str(k).begins_with("_"):
						seam = maxf(seam, absf(float(whole[k]) - float(sum.get(k, 0.0))) / maxf(float(whole[k]), 1.0))
				var top: float = strip.span(i).y * 0.5
				var have := {}
				for e in tall_elements(style, bd.colors(), sp, i, tall):
					have[e] = true
				for e in tall_elements(style, strip.colors(), strip.span(i), i, 0.0, top):
					kept = kept and have.has(e)
			_check(worst <= 6000, "%s, %d rows: a backdrop slice within 6000 vertices (%d)" % [id, rows, worst])
			_check(inside and seam < 1e-3, "%s, %d rows: each slice paints its own strip and they add up (worst %.5f)" % [id, rows, seam])
			_check(kept, "%s, %d rows: the strip's composition stays at the top, nothing stretched" % [id, rows])
			var far_kept := true
			for wd in bd.windows:
				if int(wd["layer"]) == 0:
					var found := false
					for sd in strip.windows:
						found = found or (int(sd["layer"]) == 0 and str(sd.get("center", sd.get("rect"))) == str(wd.get("center", wd.get("rect"))))
					far_kept = far_kept and found
			_check(far_kept, "%s, %d rows: its far set pieces (and their lights) where the strip has them" % [id, rows])
			for i in [1, 2]:
				var band := deep_band(i, rows)
				var old := tall_cover(style, bd.colors(), bd.span(i), i, 0.0, band.x, band.y)
				var now := tall_cover(style, bd.colors(), bd.span(i), i, bd.tall(i), band.x, band.y)
				_check(now >= deep_floor(id, i) and now >= old,
						"%s, %d rows: the %s layer's deep band (%.0f-%.0f) filled (%.3f, at least %.3f; drawn as a strip, %.3f)" % [id, rows, ["far", "mid", "near"][i], band.x, band.y, now, deep_floor(id, i), old])
			bd.queue_free()
		strip.queue_free()
	await process_frame
	# 3-2's tower (E11): three storeys that read as a climb.
	var orch: Script = Themes.style("rootvault")
	var bd36: Node2D = Backdrop.new()
	root.add_child(bd36)
	bd36.build("rootvault", Vector2(280 * 32, 36 * 32), Vector2(844, 390))
	var bd24: Node2D = Backdrop.new()
	root.add_child(bd24)
	bd24.build("rootvault", Vector2(280 * 32, 24 * 32), Vector2(844, 390))
	_check(orch._tower(bd36.tall(1), 1) and orch._tower(bd36.tall(2), 2) and not orch._tower(bd24.tall(1), 1),
			"rootvault: 36 rows is the tower, 24 rows the ossuary going on down")
	var sp36: Vector2 = bd36.span(1)
	var t36: float = bd36.tall(1)
	var c: Dictionary = bd36.colors()
	var base := Vector2(sp36.x, sp36.y - t36)
	var rl: float = orch._root_line(base, t36)
	# from the bottom storey's floor the mid layer shows about tall + 83 .. tall + 294 over his feet
	_check(rl >= orch.wall_top("rootvault", base) + 100.0 and rl <= t36 + 120.0,
			"the tower's roots start at %.0f: under the ossuary, inside the bottom storey's view (%.0f-%.0f)" % [rl, t36 + 83.0, t36 + 294.0])
	var canopy := tall_cover(orch, c, sp36, 1, t36, 60.0, 170.0) - tall_cover(orch, c, sp36, 1, 0.0, 60.0, 170.0)
	var roots := tall_cover(orch, c, sp36, 1, t36, t36 + 100.0, t36 + 294.0)
	var niches := 0
	var hole: Color = (c["mid"] as Color).darkened(0.55)
	var x := -256.0
	while x < sp36.x + 200.0:
		var log := RectLog.new()
		orch.draw(log, TriBatch.new(), 1, c, sp36, x, x + 1024.0, t36)
		for rc in log.rects:
			var r: Rect2 = rc[0]
			if r.size == Vector2(26.0, 22.0) and (rc[1] as Color).is_equal_approx(hole) and r.position.y > rl:
				niches += 1
		x += 1024.0
	var fronds := tall_cover(orch, c, bd36.span(2), 2, bd36.tall(2), 0.0, 200.0) - tall_cover(orch, c, bd36.span(2), 2, 0.0, 0.0, 200.0)
	_check(canopy > 0.05 and fronds > 0.02, "the tower's top: the canopy over the vaults (%.3f more of the mid's 60-170), fronds hanging (%.3f)" % [canopy, fronds])
	_check(roots > 0.2 and niches == 0, "its bottom storey: roots (%.3f of the band), the niches stopping over them (%d under)" % [roots, niches])
	bd36.queue_free()
	bd24.queue_free()
	# v2's cathedral (World 1-2, backdrop_layer.gd): a 36-row level's arcade
	# goes on down, a storey of glass among its storeys (lit as the strip's);
	# a 15-row level has none past the strip's.
	for th in ["nave", "crypt", "choir", "chandlery"]:
		var deep := []
		for rows in [15, 36]:
			var b: Node2D = Backdrop.new()
			root.add_child(b)
			b.build(th, Vector2(240 * 32, rows * 32), Vector2(844, 390))
			await process_frame
			await process_frame
			var n := 0
			for wd in b.windows:
				if int(wd["layer"]) == 1 and not wd.get("rose", false) and (wd["rect"] as Rect2).position.y > 300.0:
					n += 1
			deep.append(n)
			b.queue_free()
		_check(deep[0] == 0 and deep[1] > 0, "%s: the arcade's glass storey below the strip's at 36 rows (%d), none at 15" % [th, deep[1]])
	await process_frame


# ---------------------------------------------------------------- v2's backdrops at 24 and 36 rows

const V2_TALL := ["nave", "crypt", "choir", "waxfall", "chandlery", "garden"]   # W1-2's regular levels' themes
const V2_BUDGET := 32768         # a v2 layer's tall batch: one per layer, never past TriBatch's ceiling
const TOP_STEP := 8.0            # px between the points the top's composition is compared at
const TOP_X := 2400.0            # ...across this much of the layer


static func v2_log(bd: Node2D, i: int, flat := false) -> Array:
	## What v2's layer i draws (backdrop_layer.gd's log: [kind, ...]); flat:
	## as a strip's would at the same span (its tall band left out).
	var layer = bd._layers[i]
	layer.log = []
	layer.flat = flat
	layer._draw()
	var out: Array = layer.log
	layer.log = null
	layer.flat = false
	return out


static func _v2_box(e: Array) -> Rect2:
	match str(e[0]):
		"rect":
			return (e[1] as Rect2).abs()
		"poly", "pline":
			var r := Rect2((e[1] as PackedVector2Array)[0], Vector2.ZERO)
			for q in e[1]:
				r = r.expand(q)
			return r.grow(float(e[3]) * 0.5 + 1.0 if str(e[0]) == "pline" else 0.0)
		"circle", "arc":
			return Rect2(e[1] - Vector2(e[2], e[2]), Vector2(e[2], e[2]) * 2.0).grow(2.0)
		"line":
			return Rect2(e[1], Vector2.ZERO).expand(e[2]).grow(maxf(float(e[4]), 1.0) * 0.5 + 1.0)
	return Rect2()


static func _v2_hit(e: Array, p: Vector2) -> bool:
	## Does the draw e cover the point p?
	match str(e[0]):
		"rect":
			return (e[1] as Rect2).abs().has_point(p)
		"poly":
			return Geometry2D.is_point_in_polygon(p, e[1])
		"circle":
			return p.distance_to(e[1]) <= float(e[2])
		"arc":
			return absf(p.distance_to(e[1]) - float(e[2])) <= maxf(float(e[4]), 1.0) * 0.5
		"line":
			return p.distance_to(Geometry2D.get_closest_point_to_segment(p, e[1], e[2])) <= maxf(float(e[4]), 1.0) * 0.5
		"pline":
			var pts: PackedVector2Array = e[1]
			for k in pts.size() - 1:
				if p.distance_to(Geometry2D.get_closest_point_to_segment(p, pts[k], pts[k + 1])) <= maxf(float(e[3]), 1.0) * 0.5:
					return true
	return false


static func v2_top(log: Array, y1: float) -> PackedColorArray:
	## The colour on top at each point over the layer's top (x 0..TOP_X, y
	## 0..y1, TOP_STEP apart): what its composition shows there.
	var items := []
	for e in log:
		if str(e[0]) == "tris":
			var pts: PackedVector2Array = e[1]
			var idx: PackedInt32Array = e[2]
			for t in range(0, idx.size(), 3):
				var tri := PackedVector2Array([pts[idx[t]], pts[idx[t + 1]], pts[idx[t + 2]]])
				var box := Rect2(tri[0], Vector2.ZERO).expand(tri[1]).expand(tri[2])
				if box.position.y < y1 and box.position.x < TOP_X:
					items.append(["tri", tri, (e[3] as PackedColorArray)[idx[t]], box])
		else:
			var box := _v2_box(e)
			if box.position.y < y1 and box.position.x < TOP_X:
				items.append([e, null, null, box])
	var out := PackedColorArray()
	var y := 0.0
	while y < y1:
		var x := 0.0
		while x < TOP_X:
			var p := Vector2(x, y)
			var top := Color(0, 0, 0, 0)
			for it in items:
				if not (it[3] as Rect2).has_point(p):
					continue
				if it[0] is String:
					if Geometry2D.point_is_inside_triangle(p, it[1][0], it[1][1], it[1][2]):
						top = it[2]
				elif _v2_hit(it[0], p):
					var e: Array = it[0]
					top = e[3] if str(e[0]) == "circle" or str(e[0]) == "arc" or str(e[0]) == "line" else (e[2] if str(e[0]) != "pline" else e[2])
			out.append(top)
			x += TOP_STEP
		y += TOP_STEP
	return out


static func v2_cover(log: Array, sp: Vector2, y0: float, y1: float) -> float:
	## How much of the band y0..y1 across the layer its things cover (not its
	## fills: rects as wide as 500 px), 0..1, as tall_cover measures a style.
	var area := 0.0
	for e in log:
		match str(e[0]):
			"rect":
				var r: Rect2 = (e[1] as Rect2).abs()
				if r.size.x >= 500.0 or (e[2] as Color).a < 0.02:
					continue
				var a := maxf(r.position.y, y0)
				var b := minf(r.end.y, y1)
				if b > a:
					area += (b - a) * r.size.x
			"poly":
				var pts: PackedVector2Array = e[1]
				var idx := Geometry2D.triangulate_polygon(pts)
				for t in range(0, idx.size(), 3):
					var c := (pts[idx[t]] + pts[idx[t + 1]] + pts[idx[t + 2]]) / 3.0
					if c.y >= y0 and c.y < y1:
						area += absf((pts[idx[t + 1]] - pts[idx[t]]).cross(pts[idx[t + 2]] - pts[idx[t]])) * 0.5
			"circle":
				if float((e[1] as Vector2).y) >= y0 and float((e[1] as Vector2).y) < y1:
					area += PI * float(e[2]) * float(e[2])
			"line":
				var m: Vector2 = ((e[1] as Vector2) + (e[2] as Vector2)) * 0.5
				if m.y >= y0 and m.y < y1:
					area += (e[1] as Vector2).distance_to(e[2]) * maxf(float(e[4]), 1.0)
			"pline":
				var pts: PackedVector2Array = e[1]
				for k in pts.size() - 1:
					var m := (pts[k] + pts[k + 1]) * 0.5
					if m.y >= y0 and m.y < y1:
						area += pts[k].distance_to(pts[k + 1]) * maxf(float(e[3]), 1.0)
			"tris":
				var pts: PackedVector2Array = e[1]
				var idx: PackedInt32Array = e[2]
				for t in range(0, idx.size(), 3):
					var c := (pts[idx[t]] + pts[idx[t + 1]] + pts[idx[t + 2]]) / 3.0
					if c.y >= y0 and c.y < y1:
						area += absf((pts[idx[t + 1]] - pts[idx[t]]).cross(pts[idx[t + 2]] - pts[idx[t]])) * 0.5
	return area / (sp.x * (y1 - y0))


func _test_tall_v2() -> void:
	## v2's cathedral and cavern (backdrop_layer.gd: World 1-2's regular
	## levels' six themes) at 24 and 36 rows, as A1's styles are held: the
	## layer's tall batch within its budget (nothing dropped); the strip's
	## composition at the top as it was (the colour on top at every point of
	## a 15-row level's upper half the same: nothing stretches, no tall
	## level's storey reaches up into it); the band only a tall level shows
	## filled in the mid and near layers (at least DEEP_MIN and its own
	## floor, DEEP_FLOOR, and never less than the strip drawn that deep).
	var Backdrop = load("res://scripts/backdrop.gd")
	for th in V2_TALL:
		var strip: Node2D = Backdrop.new()
		root.add_child(strip)
		strip.build(th, Vector2(380 * 32, 480), Vector2(844, 390))
		for rows in TALL_ROWS:
			var bd: Node2D = Backdrop.new()
			root.add_child(bd)
			bd.build(th, Vector2(380 * 32, rows * 32), Vector2(844, 390))
			var worst := 0
			var dropped := 0
			var kept := true
			var off := 0
			for i in 3:
				var log := v2_log(bd, i)
				for e in log:
					if str(e[0]) == "tris":
						worst = maxi(worst, int(e[4]))
						dropped += int(e[5])
				var y1: float = strip.span(i).y * 0.5
				var a := v2_top(v2_log(strip, i), y1)
				var b := v2_top(log, y1)
				for k in a.size():
					if not a[k].is_equal_approx(b[k]):
						off += 1
				kept = kept and off == 0
				if i == 0:
					continue
				var band := deep_band(i, rows)
				var old := v2_cover(v2_log(bd, i, true), bd.span(i), band.x, band.y)
				var now := v2_cover(log, bd.span(i), band.x, band.y)
				var floor_: float = deep_floor(th, i)
				# (as a strip drawn this deep, less 1% of the band: a curtain's
				# waves kept at the strip's step cover a hair less than stretched)
				_check(now >= floor_ and now >= old - 0.01, "%s, %d rows: the %s layer's deep band (%.0f-%.0f) filled (%.3f, at least %.3f; drawn as a strip, %.3f)"
						% [th, rows, ["far", "mid", "near"][i], band.x, band.y, now, floor_, old])
			_check(worst <= V2_BUDGET and dropped == 0, "%s, %d rows: a layer's tall batch within %d vertices, nothing dropped (%d)" % [th, rows, V2_BUDGET, worst])
			_check(kept, "%s, %d rows: the strip's composition stays at the top, nothing stretched (%d points differ)" % [th, rows, off])
			bd.queue_free()
		strip.queue_free()
	await process_frame


# ---------------------------------------------------------------- the World

func _new_world(lv: RefCounted) -> Node:
	var ws: Script = load("res://scripts/world.gd")
	var w: Node = ws.new()
	w.setup(lv, true)
	root.add_child(w)
	return w


func _test_world() -> void:
	# A real World on each world's stand-in: the painter, the style, the
	# motes and the lines all run in the game's own pipeline.
	for id in ["orchard", "sporewood", "clockface", "escapement", "rootheart_arena", "escapement_arena"]:
		var lv: RefCounted = room(id)
		var w: Node = _new_world(lv)
		for i in 20:
			await physics_frame
		var th: String = str(id).trim_suffix("_arena")
		_check(w.backdrop.style_script == Themes.style(th) and w.chunks.size() == ceili(lv.width / 16.0),
				"%s: a World builds the stand-in with its style and painter" % id)
		if w.ambient != null:
			_check(not (w.ambient.table as Array).is_empty(), "%s: the World's motes are the theme's" % id)
		if w.edges != null:
			_check((w.edges.styles as Array) == Themes.edges(th), "%s: the World's edge lines are the theme's" % id)
		w.queue_free()
		await process_frame
	# The real levels, when WL3 and WL4 have landed them.
	for th in W3_THEMES + W4_THEMES:
		var lv: RefCounted = real_level(th)
		if lv == null:
			print("skipped: levels/%s.txt missing (W%s's level stream)" % [LEVEL_OF[th], LEVEL_OF[th][0]])
			continue
		_check(str(lv.theme) == th, "%s is drawn in %s" % [LEVEL_OF[th], th])
		var r: Dictionary = await _paint_all(lv, Themes.painter(th), Themes.palette(th))
		_check(r["peak"] > 0 and r["peak"] <= 6000, "%s: every chunk within 6000 vertices (at most %d)" % [LEVEL_OF[th], r["peak"]])


# ---------------------------------------------------------------- the preview (shots and dc modes)

class Preview extends Node2D:
	## Draws W3's and W4's moving and living props where the features and the
	## World are asked to draw them (A1's requests to WL3, WL4 and W0), in
	## place of the Phase 0 stand-ins, so the screenshots judge the art as it
	## will be: rotten vines by Orchard.vine_cell (they snap), pods, glowfruit,
	## the cogs (gear_l, its arms, cog_tooth ledges, the still shine), swings
	## (a rod and swing_ledge_N), weights (pendulum_pivot, a rod, pendulum_bob),
	## the belts' scrolling belt_teeth, icicles; and the theme's props map for
	## the altars, sconces, bells and lantern posts.
	var w: Node
	var tex := {}
	var props := {}
	var orchard_m = null
	var clock_m = null
	var tb = null
	var OrchardP: Script
	var ThemesL: Script

	func setup(world: Node) -> void:
		w = world
		OrchardP = load("res://scripts/tiles/orchard.gd")
		ThemesL = load("res://scripts/themes/loader.gd")
		tb = load("res://scripts/tri_batch.gd").new()
		for n in ["spore_pod_closed", "spore_pod_swell", "spore_pod_burst", "spore_pod_hang_closed", "spore_pod_hang_swell",
				"spore_pod_hang_burst", "glowfruit_hang", "glowfruit_lit", "gear_l", "gear_l_shine", "cog_tooth", "swing_ledge",
				"swing_ledge_2", "swing_ledge_3", "belt_teeth", "pendulum_bob", "pendulum_pivot", "icicle_hang", "icicle_crack"]:
			tex[n] = load("res://art/props/%s.svg" % n)
		props = ThemesL.theme(str(w.level.theme)).get("props", {})
		for k in props:
			tex["p_" + k] = load("res://art/props/%s.svg" % props[k])
		var f = w.features
		orchard_m = f.module("orchard") if f.has_method("module") else null
		clock_m = f.module("clockwork") if f.has_method("module") else null
		if f.get("_tex") is Dictionary:
			if tex.has("p_lantern_lit"):
				f._tex["lantern_post_lit"] = tex["p_lantern_lit"]
				f._tex["lantern_post_out"] = tex["p_lantern_out"]
		var under: Node2D = w.get_node("Under")
		for c in under.draw.get_connections():
			under.draw.disconnect(c["callable"])
		under.draw.connect(_under.bind(under))

	func swap_props() -> void:
		## The World's v2 altar, sconce and bell sprites, as the theme's props.
		var map := {"altar.svg": "p_altar", "altar_lit.svg": "p_altar_lit", "sconce.svg": "p_sconce", "bell.svg": "p_bell",
				"bell_beam.svg": "p_bell_beam"}
		for s in w.get_node("Props").get_children():
			if s is Sprite2D and s.texture != null:
				var k: String = map.get(s.texture.resource_path.get_file(), "")
				if k != "" and tex.has(k):
					s.texture = tex[k]

	func _process(_dt: float) -> void:
		swap_props()

	func _under(ci: Node2D) -> void:
		var f = w.features
		var mods: Array = f.modules
		f.modules = mods.filter(func(m): return m != orchard_m and m != clock_m)
		f.draw_under(ci)
		f.modules = mods
		var lv: RefCounted = w.level
		var view: Rect2 = w.view_rect().grow(96.0)
		var pal: Dictionary = ThemesL.palette(str(lv.theme))
		var ft: float = float(w.ftime)
		tb.origin = view.position
		# rotten vines (the orchard feature's runs)
		if orchard_m != null:
			for r in orchard_m.runs:
				if r["state"] == "snapped" or not view.has_point(Vector2(int(r["x"]) * 32 + 16, int(r["y0"]) * 32)):
					continue
				var a := 1.0
				if r["state"] == "regrow":
					a = 0.35 + 0.35 * sin(ft * 40.0)
				var sway := sin(ft * 50.0) * 3.0 * float(orchard_m.fray(r)) if r["state"] == "held" else 0.0
				for y in range(int(r["y0"]), int(r["y1"]) + 1):
					OrchardP.vine_cell(tb, lv, int(r["x"]), y, true, pal, sway, a)
		# the cogs' arms and the swings' and weights' rods, behind their props
		var cogs: Array = clock_m.cogs if clock_m != null else []
		var swings: Array = clock_m.swings if clock_m != null else []
		var weights: Array = clock_m.weights if clock_m != null else []
		var brass: Color = pal.get("brass", Color("c8983a"))
		var brass_sh: Color = pal.get("brass_sh", Color("8a6424"))
		var iron: Color = pal.get("iron", Color("3a3a48"))
		for cg in cogs:
			var hub: Vector2 = cg["hub"]
			if not view.grow(128.0).has_point(hub):
				continue
			for m in cg["teeth"]:
				var r2: Rect2 = m.rect()
				var tip := Vector2(r2.get_center().x, r2.end.y + 2.0)
				tb.line(hub, tip, 7.0, Color("140e08"))
				tb.line(hub, tip, 4.4, brass_sh)
		for m in swings:
			var r3: Rect2 = m.rect()
			if view.intersects(r3.grow(160.0)):
				var top := Vector2(r3.get_center().x, r3.position.y + 1.0)
				tb.line(m.anchor, top, 4.4, Color("140e08"))
				tb.line(m.anchor, top, 2.4, brass)
		for wt in weights:
			var anchor: Vector2 = wt["anchor"]
			if view.grow(200.0).has_point(anchor):
				var bob: Vector2 = wt["bob"]
				tb.line(anchor + Vector2(0, 10), bob - (bob - anchor).normalized() * 16.0, 5.0, Color("0c0c14"))
				tb.line(anchor + Vector2(0, 10), bob - (bob - anchor).normalized() * 16.0, 3.0, iron.lightened(0.15))
		tb.flush(ci)
		# the props
		for cg in cogs:
			var hub: Vector2 = cg["hub"]
			if not view.grow(128.0).has_point(hub):
				continue
			var t0: Rect2 = cg["teeth"][0].rect()
			var ang := (t0.get_center() - hub).angle() + PI * 0.5
			ci.draw_set_transform(hub, ang, Vector2.ONE)
			ci.draw_texture_rect(tex["gear_l"], Rect2(-48, -48, 96, 96), false)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			ci.draw_texture_rect(tex["gear_l_shine"], Rect2(hub - Vector2(48, 48), Vector2(96, 96)), false)
			for m in cg["teeth"]:
				ci.draw_texture_rect(tex["cog_tooth"], Rect2(m.rect().position, Vector2(64, 16)), false)
		for m in swings:
			var r4: Rect2 = m.rect()
			if view.intersects(r4.grow(64.0)):
				var n := clampi(int(round(r4.size.x / 32.0)), 1, 3)
				ci.draw_texture_rect(tex["swing_ledge" if n == 1 else "swing_ledge_%d" % n], Rect2(r4.position, Vector2(32 * n, 16)), false)
		for wt in weights:
			var anchor: Vector2 = wt["anchor"]
			if view.grow(200.0).has_point(anchor):
				ci.draw_texture_rect(tex["pendulum_pivot"], Rect2(anchor - Vector2(16, 0), Vector2(32, 32)), false)
				# the bob's ring toward the pivot: turned with the rod
				var bob2: Vector2 = wt["bob"]
				ci.draw_set_transform(bob2, (bob2 - anchor).angle() - PI * 0.5, Vector2.ONE)
				ci.draw_texture_rect(tex["pendulum_bob"], Rect2(-20, -20, 40, 40), false)
				ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if clock_m != null:
			var shift := fmod(ft * 80.0, 16.0)
			for c in clock_m.get("_belt"):
				var p := Vector2(c.x * 32, c.y * 32)
				if not view.has_point(p):
					continue
				var right: bool = lv.tile(c.x, c.y) == 18
				# the same offset both ways; a left belt only mirrors the drawing
				var off := fposmod(16.0 - shift, 16.0) * 4.0
				if right:
					ci.draw_texture_rect_region(tex["belt_teeth"], Rect2(p, Vector2(32, 8)), Rect2(off, 0, 128, 32))
				else:
					ci.draw_set_transform(p + Vector2(32, 0), 0.0, Vector2(-1, 1))
					ci.draw_texture_rect_region(tex["belt_teeth"], Rect2(Vector2.ZERO, Vector2(32, 8)), Rect2(off, 0, 128, 32))
					ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for e in lv.entities:
			var cell: Vector2i = e["cell"]
			var p2 := Vector2(cell.x * 32, cell.y * 32)
			if not view.has_point(p2):
				continue
			match str(e["kind"]):
				"pod":
					var st: String = ["closed", "swell", "burst"][cell.x % 3]
					var hang: bool = LevelData.is_solid(lv.tile(cell.x, cell.y - 1)) and not LevelData.is_solid(lv.tile(cell.x, cell.y + 1))
					ci.draw_texture_rect(tex["spore_pod_%s%s" % ["hang_" if hang else "", st]], Rect2(p2, Vector2(32, 32)), false)
				"glowfruit":
					ci.draw_texture_rect(tex["glowfruit_hang"], Rect2(p2, Vector2(32, 32)), false)
				"icicle":
					ci.draw_texture_rect(tex["icicle_crack" if cell.x % 2 == 0 else "icicle_hang"], Rect2(p2, Vector2(32, 32)), false)


func _wire_preview(w: Node) -> Node:
	var pv := Preview.new()
	w.add_child(pv)
	pv.setup(w)
	pv.swap_props()
	return pv


static func _quiet(lv: RefCounted) -> RefCounted:
	## No story beat over the level (a real level opens with one), for looking.
	var s = lv.get("story")
	if s is Dictionary:
		(s as Dictionary).erase("start")
		(s as Dictionary).erase("boss")
	return lv


func _floor_at(lv: RefCounted, x: int) -> Vector2:
	for y in range(lv.height - 1, 0, -1):
		var below: int = lv.tile(x, y + 1)
		if lv.tile(x, y) == 0 and (LevelData.is_solid(below) or LevelData.is_ledge(below)):
			return Vector2(x * 32 + 16, (y + 1) * 32)
	return Vector2(x * 32 + 16, 12 * 32)


func _place(w: Node, lv: RefCounted, x: int) -> void:
	w.test_pad = {}
	w.player.reset_at(_floor_at(lv, x))
	w.cam = w._clamp_cam(w.player.position)


func _shots(args: Array) -> void:
	var out: String = args[0] if args.size() > 0 else "/tmp/a1_shots"
	DirAccess.make_dir_recursive_absolute(out)
	var ids: Array = W3_THEMES + ["rootheart_arena", "orchard_props"] + W4_THEMES + ["escapement_arena", "clockface_props"]
	if args.size() > 1 and str(args[1]) != "all":
		ids = str(args[1]).split(",")
	var xs_arg: Array = []
	if args.size() > 2:
		for s in str(args[2]).split(","):
			xs_arg.append(int(s))
	var World: Script = load("res://scripts/world.gd")
	for id in ids:
		var lv: RefCounted = null
		var src := "level"
		if str(id).contains("@"):
			# a level file drawn in one of A1's themes: "lab-1@orchard"
			var parts: PackedStringArray = str(id).split("@")
			lv = LevelData.load_file("res://levels/%s.txt" % parts[0])
			lv.theme = parts[1]
			src = "retheme"
		elif not (str(id).ends_with("_arena") or str(id).ends_with("_props")):
			lv = real_level(id)
		if lv == null:
			lv = room(id)
			src = "stand-in"
		var xs: Array = xs_arg
		if xs.is_empty():
			xs = [6, 30, 56, 80, 104] if lv.width < 130 else [6, 34, 60, 90, 120, 140]
			if str(id).ends_with("_arena"):
				xs = [4, 24, 40]
			if str(id).ends_with("_props"):
				xs = [14]
		_quiet(lv)
		for x in xs:
			if x >= lv.width - 2:
				continue
			var w: Node = World.new()
			w.setup(lv)
			root.add_child(w)
			await process_frame
			_wire_preview(w)
			_place(w, lv, x)
			if str(id).ends_with("_props"):
				# light the altar and the lantern post, to see both states
				if not w.altars.is_empty():
					w._light_altar(w.altars[0])
				for l in w.features.lanterns:
					w.features.light(l, true)
			for i in 60:
				w.test_pad = {"right": i > 6 and i < 20}
				await physics_frame
			w.hud.visible = false
			if w.get("touch") != null:
				w.touch.visible = false
			for i in 6:
				await process_frame
			var dark := root.get_texture().get_image()
			var half := dark.duplicate()
			half.adjust_bcs(0.5, 1.0, 1.0)
			if w.get("_darkness") != null:
				w._darkness.visible = false
			await process_frame
			await process_frame
			var bare := root.get_texture().get_image()
			var sw := dark.get_width() / 2
			var sh := dark.get_height() / 2
			var sheet := Image.create_empty(sw, sh * 3 + 8, false, Image.FORMAT_RGBA8)
			sheet.fill(Color(0.1, 0.1, 0.1))
			var k := 0
			for im in [dark, half, bare]:
				var s: Image = im.duplicate()
				s.convert(Image.FORMAT_RGBA8)
				s.resize(sw, sh, Image.INTERPOLATE_BILINEAR)
				sheet.blit_rect(s, Rect2i(0, 0, sw, sh), Vector2i(0, k * (sh + 4)))
				k += 1
			id = str(id).replace("@", "_")
			var path := "%s/%s_%03d.png" % [out, id, x]
			sheet.save_png(path)
			dark.save_png("%s/%s_%03d_dark.png" % [out, id, x])
			bare.save_png("%s/%s_%03d_bare.png" % [out, id, x])
			print("saved %s (%s)" % [path, src])
			w.queue_free()
			await process_frame


func _render_layer(style: Script, i: int, colors: Dictionary, span: Vector2, sliced: bool, w: int) -> Image:
	var vp := SubViewport.new()
	vp.size = Vector2i(w, 480)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	root.add_child(vp)
	var starts := []
	var x := -256.0
	while x < span.x + 200.0:
		starts.append(x)
		x += 1024.0
	var ranges := []
	if sliced:
		for s in starts:
			ranges.append(Vector2(s, s + 1024.0))
	else:
		ranges.append(Vector2(-256.0, x))
	for rg in ranges:
		var sl := Node2D.new()
		vp.add_child(sl)
		var tb = TriBatch.new()
		sl.draw.connect(func():
			tb.origin = Vector2(rg.x, 0)
			style.draw(sl, tb, i, colors, span, rg.x, rg.y)
			tb.flush(sl))
	for k in 3:
		await process_frame
	var img := vp.get_texture().get_image()
	vp.queue_free()
	return img


func _seams_px(args: Array) -> void:
	var out: String = args[0] if args.size() > 0 else ""
	if out != "":
		DirAccess.make_dir_recursive_absolute(out)
	var Backdrop = load("res://scripts/backdrop.gd")
	var worst := 0
	for id in W3_THEMES + W4_THEMES:
		var bd: Node2D = Backdrop.new()
		root.add_child(bd)
		bd.build(id, Vector2(380 * 32, 480), Vector2(844, 390))
		for i in 3:
			var sp: Vector2 = bd.span(i)
			var w := int(minf(sp.x, 3200.0))
			var a: Image = await _render_layer(bd.style_script, i, bd.colors(), sp, true, w)
			var b: Image = await _render_layer(bd.style_script, i, bd.colors(), sp, false, w)
			var diff := 0
			var cols := {}
			for yy in a.get_height():
				for xx in a.get_width():
					var ca := a.get_pixel(xx, yy)
					var cb := b.get_pixel(xx, yy)
					if absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > 0.02:
						diff += 1
						cols[xx / 16 * 16] = true
			worst = maxi(worst, diff)
			var ks := cols.keys()
			ks.sort()
			print("[seams] %-10s layer %d  span %5.0f  differing px %d %s" % [id, i, sp.x, diff, str(ks.slice(0, 12)) if diff > 0 else ""])
			if out != "" and diff > 0:
				a.save_png("%s/%s_L%d_sliced.png" % [out, id, i])
				b.save_png("%s/%s_L%d_whole.png" % [out, id, i])
		bd.queue_free()
	print("[seams] worst %d differing px" % worst)


func _dc(args: Array) -> void:
	var out: String = args[0] if args.size() > 0 else ""
	var lines := []
	var ids: Array = W3_THEMES + ["rootheart_arena"] + W4_THEMES + ["escapement_arena"]
	var World: Script = load("res://scripts/world.gd")
	var worst := {3: 0, 4: 0}
	for id in ids:
		for which in ["level", "stand-in"]:
			var lv: RefCounted = real_level(id) if which == "level" and not str(id).ends_with("_arena") else null
			if which == "stand-in":
				lv = room(id)
			if lv == null:
				continue
			_quiet(lv)
			var wn := 3 if W3_THEMES.has(str(id).trim_suffix("_arena")) else 4
			for pv in [false, true]:
				var w: Node = World.new()
				w.setup(lv)
				root.add_child(w)
				await process_frame
				if pv:
					_wire_preview(w)
				var best := 0
				var at := 0
				for x in range(4, lv.width - 3, 10):
					_place(w, lv, x)
					for i in 4:
						await process_frame
					for i in 3:
						await process_frame
						var n := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
						if n > best:
							best = n
							at = x
				worst[wn] = maxi(worst[wn], best)
				var line := "[dc] %-18s %-8s %-10s max %4d at x %3d (limit %d) %s" % [id, which, "preview" if pv else "phase0", best, at, DC_LIMIT[wn],
						"ok" if best <= DC_LIMIT[wn] else "OVER"]
				print(line)
				lines.append(line)
				w.queue_free()
				await process_frame
	var tail := "[dc] worst W3 %d / 600, W4 %d / 650" % [worst[3], worst[4]]
	print(tail)
	lines.append(tail)
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string("\n".join(lines) + "\n")
