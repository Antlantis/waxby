extends RefCounted
## The level's lights (v3): what the dark shows, and what counts as lit.
## world.gd holds one as `world.lights` and its light functions delegate here:
##   add_light / move_light / remove_light / lights_tagged   the dynamic lights
##   pack(view)          every frame: the v3 priority table into the shader
##   lit_at(p, pad, opts) gameplay lights only, nominal radii, 8 px hysteresis
##   dim / undim         the one dimming pipeline for the hero's own light
##   hero_radius()       spec §1.7: dims (dim_resist each), the floor, LIGHT_MIN, the override
##   light_override(r)   the finale's give (r >= 0 forces the radius, -1 releases)
##   reflect(spans)      mirror lights over ice and the lake (at most 4)
##   set_dark / set_warm the shader's colours, tweened (the brightness setting stays on top)
##   counts()            {lights, hush, tint, refl} for the perf line
## It also builds the darkness node itself (attach): Plan A, the full-size
## field (darkness.gdshader), or Plan B, the field at reduced size in a
## SubViewport with the bands cut at full size (darkness_field +
## darkness_apply). The plan is one setting: LIGHT_FIELD below, overridden by
## the project setting `waxby/render/light_field` and by `--light-field=` on
## the command line ("full" | "quarter" | "half").
##
## Light dicts (from features.lights(), e.lights(), kit.lights(),
## mode.lights()): {p, r, s, tint?: Color (a = amount), tag?: "a,b",
## kind?: String, gameplay?: bool, rule_r?: float}. s < 0 is a Hush light.
## `kind` picks the packing group (else the source's default): hush, tell,
## shot, beacon, refl, altar (altars, lanterns, lamps), boss, eye, pickup,
## deco (decorative tinted: fungi, shard lamps, windows), sconce, lava.
##
## With W1-W2's lights this packs exactly the set v2's world.gd packed (the
## order within it can differ, which the shader doesn't see; W1-W2 never reach
## 48 candidates, so no cap binds there): test_render checks it at 88 places,
## and the screenshots are identical (tools/perf/shot_diff.py).

const Combat := preload("res://scripts/combat.gd")
const LevelData := preload("res://scripts/level_data.gd")
const DARKNESS := preload("res://shaders/darkness.gdshader")
const LightFieldScript := preload("res://scripts/light_field.gd")

const TILE := 32
const MAX_LIGHTS := 48
const GROW := 120.0                 # lights are taken from the view grown by this (v2)
# The v3 packing order (spec §11.2) and its caps.
const ORDER := ["hero", "hush", "tell", "shot", "beacon", "refl", "altar", "boss", "eye", "pickup", "deco", "sconce", "lava"]
const CAPS := {"hush": 6, "tell": 8, "shot": 4, "refl": 4, "altar": 14, "boss": 3, "eye": 8, "pickup": 6, "deco": 10}
const WINDOWS_MAX := 6              # backdrop windows among the decorative lights (v2)
const DECO_LEAVE := 4               # decorative lights never take the last 4 slots (v2's windows rule)
const HUSH_SCREENS := 1.5           # Hush lights count within 1.5 screens of the view's centre
const REFL_ABOVE := 128.0           # a light reflects in a span it is at most this far above
const LIT_HYSTERESIS := 8.0
const DIM_FLOOR := {"dusk": 0.50, "nightfall": 0.40, "witching": 0.30}   # until combat.gd has DIM_FLOOR
const DIM_RESIST_CAP := 0.50
const HERO_GUARD := 1.0
const LIGHT_FIELD := "full"         # Plan A. "quarter" is Plan B (the field at 1/4 size each way)
# The phone's GPU test (decisions.md, wave 2): levels keep the full field;
# the 4-layer lit cutscenes take the quarter field (Plan B for cutscenes
# only: one light loop at 1/16 the pixels that every layer reads).
const CUTSCENE_FIELD := "quarter"
const FIELD_SCALES := {"quarter": 0.25, "half": 0.5}
# v2's pickups: it lit the first 6 untaken pickups of the level's list,
# in view or not, with the Guttered Pool's light outside those 6; and its
# eyes stopped only between monsters, so a pair could make a 9th. Kept for
# W1-W2's identity (see the Phase 0 report); false lights the 6 nearest in
# view, the pool among them, and at most CAPS.eye eyes.
const LEGACY_PICKUP_CAP := true

var world: Node
var dyn := {}                       # id -> {p, r, s, life, tag, tint}
var _next := 1
var dims := {}                      # key -> {m, until} (until < 0: until undim)
var override_r := -1.0
var mirrors: Array = []             # [{p, h, seed, k}] flames glow draws upside down (reflections)
var spans_in_view: Array = []       # the reflecting spans near the view this frame
var field := LIGHT_FIELD            # the plan in use
var materials: Array = []           # every ShaderMaterial that holds light uniforms
var dark_mat: ShaderMaterial        # the one holding dark_color (Plan A's or Plan B's apply)
var node: Control                   # the darkness node on the dark layer
var _field: Node = null             # Plan B's light_field.gd
var _vp: SubViewport                # its SubViewport
var _counts := {"lights": 0, "hush": 0, "tint": 0, "refl": 0}
var _lit_mem := {}
var _base_dark := Color(0.30, 0.25, 0.40)
var _bright := 0.0
var _warm := Color(1.0, 0.95, 0.86)
var _tw := {}                       # "dark" / "warm" -> {from, to, t, dur}
var _clock := 0.0
var _last_hero := false
var _gl_cache: Array = []           # gameplay_lights() for this tick (lit_at asks per cell)
var _gl_key := -1.0
var _gl_hero := true


func _init(w: Node = null) -> void:
	world = w


static var force_field := ""        # the GPU spike switches plans between its runs
static var force_cutscene_field := ""   # tests and the spike pick the cutscenes' plan


static func field_mode() -> String:
	## The plan: force_field (the spike), else --light-field= on the command
	## line, else the project setting, else LIGHT_FIELD.
	if force_field != "":
		return force_field
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a.begins_with("--light-field="):
			return a.get_slice("=", 1)
	if ProjectSettings.has_setting("waxby/render/light_field"):
		return str(ProjectSettings.get_setting("waxby/render/light_field"))
	return LIGHT_FIELD


static func cutscene_field_mode() -> String:
	## The cutscenes' plan (cutscene.gd asks): force_cutscene_field, else
	## --cutscene-field= on the command line, else the project setting
	## waxby/render/cutscene_field, else a level plan other than "full" (a
	## Plan B run keeps its scenes on it), else CUTSCENE_FIELD.
	if force_cutscene_field != "":
		return force_cutscene_field
	for a in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a.begins_with("--cutscene-field="):
			return a.get_slice("=", 1)
	if ProjectSettings.has_setting("waxby/render/cutscene_field"):
		return str(ProjectSettings.get_setting("waxby/render/cutscene_field"))
	var lv := field_mode()
	if FIELD_SCALES.has(lv):
		return lv
	return CUTSCENE_FIELD


# ---------------------------------------------------------------- the darkness node

func attach(layer: Node, mode := "") -> Control:
	## Builds the darkness node under `layer` (the dark CanvasLayer) and
	## returns it. dark_mat is the material that takes dark_color.
	field = mode if mode != "" else field_mode()
	materials.clear()
	if not FIELD_SCALES.has(field):
		field = "full"
		var cr := ColorRect.new()
		cr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dark_mat = ShaderMaterial.new()
		dark_mat.shader = DARKNESS
		cr.material = dark_mat
		materials.append(dark_mat)
		node = cr
		layer.add_child(cr)
		return cr
	# Plan B: the field in a SubViewport (light_field.gd), the bands at full size.
	var holder := Control.new()
	holder.name = "DarknessB"
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(holder)
	_field = LightFieldScript.new()
	_field.scale = float(FIELD_SCALES[field])
	holder.add_child(_field)
	_vp = _field.viewport()
	var apply := ColorRect.new()
	apply.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	apply.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dark_mat = _field.make_bands_material(false)
	apply.material = dark_mat
	holder.add_child(apply)
	materials.append(_field.field_mat)
	materials.append(dark_mat)
	node = holder
	return holder


func material() -> ShaderMaterial:
	return dark_mat


func set_param(name: String, value) -> void:
	for m in materials:
		m.set_shader_parameter(name, value)


# ---------------------------------------------------------------- colours

func theme_dark(col: Color, bright: float) -> void:
	## world._apply_theme_dark: the theme's dark and the brightness setting
	## (lightened on top, as v2).
	_base_dark = col
	_bright = bright
	_tw.erase("dark")
	_apply_colors()


func set_dark(color: Color, seconds: float) -> void:
	_tw["dark"] = {"from": _base_dark, "to": color, "t": 0.0, "dur": maxf(seconds, 0.0)}
	if seconds <= 0.0:
		_base_dark = color
		_tw.erase("dark")
	_apply_colors()


func set_warm(color: Color, seconds: float) -> void:
	_tw["warm"] = {"from": _warm, "to": color, "t": 0.0, "dur": maxf(seconds, 0.0)}
	if seconds <= 0.0:
		_warm = color
		_tw.erase("warm")
	_apply_colors()


func dark_color() -> Color:
	return _base_dark.lightened(_bright)


func _step_colors(dt: float) -> void:
	for key in _tw.keys():
		var tw: Dictionary = _tw[key]
		tw["t"] = float(tw["t"]) + dt
		var k := clampf(float(tw["t"]) / maxf(float(tw["dur"]), 0.0001), 0.0, 1.0)
		var c: Color = (tw["from"] as Color).lerp(tw["to"], k)
		if key == "dark":
			_base_dark = c
		else:
			_warm = c
		if k >= 1.0:
			_tw.erase(key)
	_apply_colors()


func _apply_colors() -> void:
	if dark_mat == null:
		return
	set_param("dark_color", _base_dark.lightened(_bright))
	if _warm != Color(1.0, 0.95, 0.86) or not _tw.is_empty():
		set_param("warm_color", Vector3(_warm.r, _warm.g, _warm.b))


# ---------------------------------------------------------------- dynamic lights

func add(pos: Vector2, r: float, s := 0.8, life := -1.0, tag := "", tint := Color(0, 0, 0, 0)) -> int:
	## A light for the dark (-1 life = until removed). Returns its id. A
	## negative s is a Hush light; tint.a is the tint amount; tag may list
	## several, comma-separated ("lantern,haven,anchor").
	var id := _next
	_next += 1
	dyn[id] = {"p": pos, "r": r, "s": s, "life": life, "tag": tag, "tint": tint}
	_gl_key = -1.0
	return id


func move(id: int, pos: Vector2, r := -1.0) -> void:
	if dyn.has(id):
		dyn[id]["p"] = pos
		if r >= 0.0:
			dyn[id]["r"] = r
		_gl_key = -1.0


func remove(id: int) -> void:
	dyn.erase(id)
	_gl_key = -1.0


func tagged(tag: String) -> Array:
	## [{p, r, s, ...}] of the live dynamic lights carrying this tag.
	var out := []
	for id in dyn:
		if has_tag(str(dyn[id]["tag"]), tag):
			out.append(dyn[id])
	return out


static func has_tag(tags: String, tag: String) -> bool:
	if tags == tag:
		return true
	if tags.find(",") < 0:
		return false
	for t in tags.split(","):
		if t.strip_edges() == tag:
			return true
	return false


func step(dt: float) -> void:
	## The World's tick (where v2 aged its dynamic lights).
	for id in dyn.keys():
		var l: Dictionary = dyn[id]
		if float(l["life"]) >= 0.0:
			l["life"] = float(l["life"]) - dt
			if float(l["life"]) <= 0.0:
				dyn.erase(id)


# ---------------------------------------------------------------- dimming

func _now() -> float:
	if world == null:
		return _clock
	var ft = world.get("ftime")
	if ft != null:
		return float(ft)
	var t = world.get("_t")
	return float(t) if t != null else _clock


func dim(key: String, mult: float, seconds: float) -> void:
	## The one path that dims the hero's own light. Re-dimming a key
	## refreshes it. seconds < 0 holds until undim(key).
	dims[key] = {"m": clampf(mult, 0.0, 1.0), "until": (_now() + seconds) if seconds >= 0.0 else -1.0}


func undim(key: String) -> void:
	dims.erase(key)


const DOUSE_DIM := 0.5            # v2's douse (a Dripkin's drip, the Snuffer's douse)
const LATCH_DIM := 0.55           # v2's Gutterwing latch


func dim_product() -> float:
	## The active dims, each softened by dim_resist, multiplied, then floored
	## by the difficulty (spec §1.7). 1.0 with none. v2's douse (x0.5) and
	## the Gutterwing's latch (x0.55) are entries too (since the wave-1
	## merge), so dim_resist softens them and the floor holds under them;
	## alone each is at or above Dusk's floor, as in v2. Sporeward
	## (stats.flags.spore_resist) eases a "spore..." dim first.
	var now := _now()
	var resist := 0.0
	var spore_resist := 0.0
	var pl: Node2D = world.player if world != null else null
	var stats = pl.stats if pl != null else {}
	if stats is Dictionary:
		resist = clampf(float(stats.get("dim_resist", 0.0)), 0.0, _resist_cap())
		var fl = stats.get("flags", {})
		if fl is Dictionary:
			spore_resist = clampf(float(fl.get("spore_resist", 0.0)), 0.0, 1.0)
	var entries: Array = []
	if pl != null and pl.has_method("has_status"):
		if pl.has_status("douse"):
			entries.append(DOUSE_DIM)
		if pl.has_status("latch"):
			entries.append(LATCH_DIM)
	for key in dims.keys():
		var d: Dictionary = dims[key]
		if float(d["until"]) >= 0.0 and now >= float(d["until"]):
			dims.erase(key)
			continue
		var m := float(d["m"])
		if spore_resist > 0.0 and str(key).begins_with("spore"):
			m = 1.0 - (1.0 - m) * (1.0 - spore_resist)
		entries.append(m)
	if entries.is_empty():
		return 1.0
	# PR's rule (Combat.dim_mult, which test_progression pins) when it's
	# there; this file's copy of the same rule otherwise.
	if _has_dim_mult():
		return float((Combat as Script).call("dim_mult", entries, resist, str(world.get("diff")) if world != null else "dusk"))
	var prod := 1.0
	for m in entries:
		prod *= 1.0 - (1.0 - float(m)) * (1.0 - resist)
	return maxf(prod, _dim_floor())


static var _dim_mult_known := -1


static func _has_dim_mult() -> bool:
	if _dim_mult_known < 0:
		_dim_mult_known = 1 if (Combat as Script).get_script_method_list().any(func(f): return f["name"] == "dim_mult") else 0
	return _dim_mult_known == 1


func dimmed() -> bool:
	## Any dim active (the HUD's grey ring).
	return dim_product() < 1.0


static var _combat_consts := {}


static func _combat(key: String, fallback):
	## A combat.gd constant that PR adds in Phase 0 (DIM_FLOOR, DIM_RESIST_CAP),
	## with this file's copy until it lands.
	if _combat_consts.is_empty():
		var sc: Script = load("res://scripts/combat.gd")
		_combat_consts = sc.get_script_constant_map() if sc != null else {"_": 0}
	return _combat_consts.get(key, fallback)


func _dim_floor() -> float:
	var d := str(world.get("diff")) if world != null else "dusk"
	var tab: Dictionary = _combat("DIM_FLOOR", DIM_FLOOR)
	return float(tab.get(d, tab.get("dusk", 0.5)))


func _resist_cap() -> float:
	return float(_combat("DIM_RESIST_CAP", DIM_RESIST_CAP))


func light_override(r: float) -> void:
	override_r = r


func hero_radius() -> float:
	## Spec §1.7: v2's radius with every dim entry (dim_resist each, the
	## product floored), clamped to LIGHT_MIN, then any override.
	var pl: Node2D = world.player
	var mult: float = world.features.light_mult() if world.features and world.features.has_method("light_mult") else 1.0
	# (douse and the latch are dim_product's entries: dim_resist and the floor)
	mult *= dim_product()
	var extra := 0.0
	if world.kit:
		for l in world.kit.lights():
			if l.get("hero", false):
				extra += float(l["r"])
	var r := Combat.light_radius(pl.life_frac(), pl.stats, world.diff, mult, extra)
	if override_r >= 0.0:
		return override_r
	return r


# ---------------------------------------------------------------- lit_at

func lit_at(p: Vector2, pad := 0.0, opts := {}) -> bool:
	## Is p inside a gameplay light (nominal radius + pad)? Gameplay lights:
	## the hero's (unless opts.exclude_hero), the dynamic lights (braziers,
	## lanterns, beacons), lit altars, and feature / mode / kit lights with
	## gameplay: true. Never monsters' lights, Hush lights or decoration.
	## opts.tag: only lights carrying that tag (e.g. "haven"). 8 px of
	## hysteresis: once lit, p stays lit until 8 px further out. opts.key
	## names the asker (default: p rounded) so a moving asker keeps its memory.
	var key = opts.get("key", p.round())
	var was: bool = bool(_lit_mem.get(key, false))
	var slack := pad + (LIT_HYSTERESIS if was else 0.0)
	var tag: String = str(opts.get("tag", ""))
	var lit := false
	for l in gameplay_lights(not bool(opts.get("exclude_hero", false))):
		if tag != "" and not has_tag(str(l.get("tag", "")), tag):
			continue
		var r: float = float(l.get("rule_r", l["r"]))
		if p.distance_to(l["p"]) <= r + slack:
			lit = true
			break
	if _lit_mem.size() > 1024:
		_lit_mem.clear()
	_lit_mem[key] = lit
	return lit


func gameplay_lights(with_hero := true) -> Array:
	## [{p, r, s, tag}] of the lights that count for lit_at (cached for the
	## tick: the World's clock _t).
	var tk = world.get("_t")
	var key: float = float(tk) if tk != null else -2.0
	if key == _gl_key and with_hero == _gl_hero and key >= 0.0:
		return _gl_cache
	var out := []
	var pl = world.player
	if with_hero and pl != null and pl.alive:
		out.append({"p": pl.center() + Vector2(0, -8), "r": hero_radius(), "s": 1.0, "tag": "hero"})
	for id in dyn:
		var l: Dictionary = dyn[id]
		if float(l["s"]) > 0.0 and not has_tag(str(l["tag"]), "deco"):
			out.append(l)
	var altars = world.get("altars")
	if altars is Array:
		for a in altars:
			if a["lit"]:
				out.append({"p": a["flame"], "r": 150.0, "s": 0.95, "tag": "altar"})
	for src in [world.features, world.get("mode"), world.kit]:
		if src == null or not src.has_method("lights"):
			continue
		for l in src.lights():
			if l.get("gameplay", false) and float(l.get("s", 0.8)) > 0.0:
				out.append(l)
	_gl_cache = out
	_gl_key = key
	_gl_hero = with_hero
	return out


# ---------------------------------------------------------------- reflections

func reflect(spans: Array) -> Array:
	## Mirror lights for the reflecting spans [{x0, x1, y, tint, k}] (ice
	## tops, the lake): the hero's first, then up to 3 other flames within
	## REFL_ABOVE above a span; at (p.x, 2y - p.y), r x 0.6, s x k, the
	## span's tint. Also fills `mirrors` for glow's upside-down flames.
	## Returns the mirror light dicts (<= CAPS.refl).
	var out := []
	mirrors.clear()
	spans_in_view = spans
	if spans.is_empty():
		return out
	var srcs := []
	var pl = world.player
	if pl != null and pl.alive:
		srcs.append({"p": pl.center() + Vector2(0, -8), "r": hero_radius(), "s": 1.0, "flame": world.rig.flame_point() if world.rig else pl.center(), "hero": true})
	var view: Rect2 = world.view_rect().grow(GROW)
	for s in world.sconces:
		if view.has_point(s):
			srcs.append({"p": s, "r": 110.0, "s": 0.85, "flame": s, "h": 11.0, "seed": s.x * 0.13})
	for a in world.altars:
		if a["lit"] and view.has_point(a["flame"]):
			srcs.append({"p": a["flame"], "r": 150.0, "s": 0.95, "flame": a["flame"], "h": 15.0 + float(a["glow"]) * 10.0, "seed": a["flame"].x * 0.07})
	for src in srcs:
		if out.size() >= int(CAPS["refl"]):
			break
		var sp: Vector2 = src["p"]
		for span in spans:
			var y: float = float(span["y"])
			if sp.x < float(span["x0"]) or sp.x > float(span["x1"]) or sp.y > y or y - sp.y > REFL_ABOVE:
				continue
			var tint: Color = span.get("tint", Color(0, 0, 0, 0))
			var k: float = float(span.get("k", 0.4))
			out.append({"p": Vector2(sp.x, 2.0 * y - sp.y), "r": float(src["r"]) * 0.6, "s": float(src["s"]) * k, "tint": tint})
			var fp: Vector2 = src["flame"]
			mirrors.append({"p": Vector2(fp.x, 2.0 * y - fp.y), "hero": src.get("hero", false),
					"h": float(src.get("h", 0.0)), "seed": float(src.get("seed", 0.0)), "k": k, "y": y})
			break
	return out


# ---------------------------------------------------------------- the packer

func pack(view: Rect2) -> void:
	## Every frame (world._process): the v3 priority table into the shader.
	## `view` is the world's view rect; lights are taken from it grown by
	## GROW (v2), Hush lights from 1.5 screens.
	var dt := world.get_process_delta_time() if world.is_inside_tree() else 0.0
	_clock += dt
	if not _tw.is_empty():
		_step_colors(dt)
	var xf: Transform2D = world.get_viewport().get_canvas_transform()
	var k := xf.get_scale().x
	var t: float = float(world.get("_t"))
	var flick := 1.0 + 0.03 * sin(t * 13.0) + 0.02 * sin(t * 23.0)
	var grown := view.grow(GROW)
	var g := {}
	for name in ORDER:
		g[name] = []
	var pl = world.player
	var state := str(world.get("state"))
	var hero := false
	# 1. The hero (or the snuff light where he went out).
	if pl.alive:
		var r := hero_radius()
		if override_r < 0.0:
			if pl.hurt_time < 0.3:
				r *= 0.6 + pl.hurt_time * 1.3
			if pl.life_frac() < 0.25:
				r *= 0.9 + 0.1 * sin(t * TAU)
			r *= flick
		g["hero"].append([pl.center() + Vector2(0, -8), r, 1.0, null])
		hero = true
	elif state == "dead":
		g["hero"].append([pl.center(), 60.0 * maxf(0.0, 1.0 - float(world.snuff_time)), 0.8, null])
		hero = true
	# Monsters' lights: tells (a Hush light if s < 0).
	for e in world.enemies:
		if e.alive and e.active:
			for l in e.lights():
				_put(g, l, "tell")
	# Shots: v2 counted the first 4 shots with a light, in view or not.
	var nshots := 0
	for s in world.shots:
		if float(s["light"]) > 0.0 and nshots < int(CAPS["shot"]):
			g["shot"].append([s["pos"], float(s["light"]), 0.8, null])
			nshots += 1
	if world.kit:
		for l in world.kit.lights():
			if not l.get("hero", false):
				_put(g, l, "beacon")
	for id in dyn:
		var l: Dictionary = dyn[id]
		var tags := str(l["tag"])
		var grp := "beacon"
		if float(l["s"]) < 0.0:
			grp = "hush"
		elif has_tag(tags, "lantern") or has_tag(tags, "altar") or has_tag(tags, "lamp") or has_tag(tags, "haven") or has_tag(tags, "anchor"):
			grp = "altar"
		elif has_tag(tags, "deco"):
			grp = "deco"
		g[grp].append([l["p"], float(l["r"]), float(l["s"]), l.get("tint", null)])
	if world.features:
		for l in world.features.lights():
			_put(g, l, "tell")
	var md = world.get("mode")
	if md != null and md.has_method("lights"):
		for l in md.lights():
			_put(g, l, "beacon")
	for a in world.altars:
		if a["lit"]:
			g["altar"].append([a["flame"], (150.0 + float(a["glow"]) * 60.0) * flick, 0.95, null])
	var boss = world.boss
	if boss != null and is_instance_valid(boss) and boss.get("state") != "sleep":
		var flare := 1.0
		if boss.get("state") == "windup":
			flare = 1.5 + 0.3 * sin(t * 30.0)
		g["boss"].append([boss.center() + Vector2(0, -20), 130.0 * flare, 0.7 if boss.alive else 0.4, null])
	var neyes := 0
	for e in world.enemies:
		if neyes >= int(CAPS["eye"]):
			break
		if e.alive and e.active and e != boss:
			for p in e.eye_points():
				if grown.has_point(p):
					g["eye"].append([p, 16.0, 0.35, null])
					neyes += 1
	for b in world.bells:
		g["altar"].append([b["top"] + Vector2(0, 50), 90.0, 0.5, null])
	if not world.pool.is_empty():
		g["pickup"].append([world.pool["pos"], 60.0, 0.7, null])
	_pickups(g, grown)
	for s in world.sconces:
		g["sconce"].append([s, 110.0 * (1.0 + 0.04 * sin(t * 11.0 + s.x)), 0.85, null])
	_windows(g, view, grown)
	_lava(g, grown, t)
	# Reflections (the features' spans: ice tops, the lake).
	if world.features and world.features.has_method("reflectors"):
		var spans := []
		for sp in world.features.reflectors():
			if float(sp["x1"]) >= grown.position.x and float(sp["x0"]) <= grown.end.x:
				spans.append(sp)
		for l in reflect(spans):
			g["refl"].append([l["p"], l["r"], l["s"], l["tint"]])
	else:
		mirrors.clear()
		spans_in_view = []
	# Pack, in order.
	var lights := PackedVector4Array()
	var tints := PackedVector4Array()
	var nh := 0
	var nt := 0
	var nr := 0
	var hush_box := Rect2(view.get_center() - view.size * HUSH_SCREENS * 0.5, view.size * HUSH_SCREENS)
	for name in ORDER:
		var list: Array = g[name]
		if list.is_empty():
			continue
		var cap: int = int(CAPS.get(name, MAX_LIGHTS))
		if LEGACY_PICKUP_CAP:
			if name == "eye":
				cap = maxi(cap, list.size())   # the gather stopped at a monster's end, as v2 (a pair can make 9)
			elif name == "pickup" and not world.pool.is_empty():
				cap += 1                       # the pool's light, outside v2's 6
		var taken := 0
		if name == "hush":
			list = _nearest(list, pl.center(), hush_box, view)
		for l in list:
			if lights.size() >= MAX_LIGHTS or taken >= cap:
				break
			var p: Vector2 = l[0]
			if name == "deco" and lights.size() >= MAX_LIGHTS - DECO_LEAVE:
				break
			if name != "hush" and not grown.has_point(p):
				continue
			var at: Vector2 = xf * p
			var s: float = l[2]
			lights.append(Vector4(at.x, at.y, float(l[1]) * k, s))
			var tn = l[3]
			if tn is Color and (tn as Color).a > 0.0:
				tints.append(Vector4(tn.r, tn.g, tn.b, tn.a))
				nt += 1
			else:
				tints.append(Vector4.ZERO)
			if s < 0.0:
				nh += 1
			if name == "refl":
				nr += 1
			taken += 1
	var n := lights.size()
	_last_hero = hero and n > 0
	while lights.size() < MAX_LIGHTS:
		lights.append(Vector4.ZERO)
		tints.append(Vector4.ZERO)
	set_param("lights", lights)
	set_param("tints", tints)
	set_param("light_count", n)
	set_param("view_size", world._view_size())
	set_param("hero_guard", HERO_GUARD if _last_hero else 0.0)
	_counts = {"lights": n, "hush": nh, "tint": nt, "refl": nr}


func _put(g: Dictionary, l: Dictionary, default: String) -> void:
	var s: float = float(l.get("s", 0.8))
	var grp: String = str(l.get("kind", ""))
	if s < 0.0:
		grp = "hush"
	elif grp == "" or not g.has(grp):
		grp = default
		var tags := str(l.get("tag", ""))
		if tags != "":
			for cand in ["tell", "lantern", "altar", "lamp", "haven", "anchor", "deco", "beacon", "brazier", "sconce", "eye", "pickup", "boss", "shot"]:
				if has_tag(tags, cand):
					grp = {"lantern": "altar", "lamp": "altar", "haven": "altar", "anchor": "altar", "brazier": "beacon"}.get(cand, cand)
					break
	g[grp].append([l["p"], float(l["r"]), s, l.get("tint", null)])


func _nearest(list: Array, from: Vector2, box: Rect2, view: Rect2) -> Array:
	## Hush lights: those whose centre is within 1.5 screens and whose circle
	## reaches the view, nearest the hero first.
	var out := []
	for l in list:
		var p: Vector2 = l[0]
		var r: float = float(l[1])
		if not box.has_point(p):
			continue
		var cx := clampf(p.x, view.position.x, view.end.x)
		var cy := clampf(p.y, view.position.y, view.end.y)
		if Vector2(cx, cy).distance_to(p) > r:
			continue
		out.append(l)
	out.sort_custom(func(a, b): return (a[0] as Vector2).distance_squared_to(from) < (b[0] as Vector2).distance_squared_to(from))
	return out


func _pickups(g: Dictionary, grown: Rect2) -> void:
	var npick := 0
	if LEGACY_PICKUP_CAP:
		for p in world.pickups:
			if npick >= int(CAPS["pickup"]):
				break
			if p["taken"]:
				continue
			match p["kind"]:
				"ember":
					g["pickup"].append([p["pos"], 34.0, 0.55, null])
				"relic", "item":
					g["pickup"].append([p["pos"], 90.0, 0.9, null])
				"sigil":
					g["pickup"].append([p["pos"], 60.0, 0.7, null])
			npick += 1
		return
	var near: Array = []
	for p in world.pickups:
		if not p["taken"] and grown.has_point(p["pos"]) and p["kind"] in ["ember", "relic", "item", "sigil"]:
			near.append(p)
	var c: Vector2 = world.player.center()
	near.sort_custom(func(a, b): return (a["pos"] as Vector2).distance_squared_to(c) < (b["pos"] as Vector2).distance_squared_to(c))
	for p in near:
		var rs: Array = {"ember": [34.0, 0.55], "relic": [90.0, 0.9], "item": [90.0, 0.9], "sigil": [60.0, 0.7]}[p["kind"]]
		# (a kill's ember piece, world.ember_size 2-3, lights a little wider)
		var r: float = float(rs[0]) * (1.0 + 0.25 * (int(p.get("size", 1)) - 1))
		g["pickup"].append([p["pos"], r, rs[1], null])


func _windows(g: Dictionary, view: Rect2, grown: Rect2) -> void:
	## The backdrop's glowing bits (stained glass, candle clusters), decorative.
	var bd = world.backdrop
	if bd == null:
		return
	var cam0 := view.position
	var nwin := 0
	for wnd in bd.windows:
		if nwin >= WINDOWS_MAX:
			break
		var off: Vector2 = bd.layer_offset(wnd["layer"], cam0)
		var wc: Vector2 = (wnd["center"] if wnd.get("rose", false) else (wnd["rect"] as Rect2).get_center()) + off
		if not grown.has_point(wc):
			continue
		var r: float = float(wnd["radius"]) * 1.5 if wnd.get("rose", false) else 70.0
		g["deco"].append([wc, r, float(wnd.get("s", 0.42)), wnd.get("tint", null)])
		nwin += 1


func _lava(g: Dictionary, grown: Rect2, t: float) -> void:
	var level: RefCounted = world.level
	var x0 := maxi(floori(grown.position.x / TILE), 0)
	var x1 := mini(floori(grown.end.x / TILE), level.width - 1)
	var y0 := maxi(floori(grown.position.y / TILE), 0)
	var y1 := mini(floori(grown.end.y / TILE), level.height - 1)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1, 2):
			if g["lava"].size() >= MAX_LIGHTS:
				return
			if level.tile(x, y) == LevelData.LAVA and level.tile(x, y - 1) != LevelData.LAVA:
				g["lava"].append([Vector2(x * TILE + 16, y * TILE + 10), 85.0 * (1.0 + 0.06 * sin(t * 3.0 + x)), 0.75, null])


func counts() -> Dictionary:
	return _counts.duplicate()


func census(view: Rect2) -> Dictionary:
	## How many candidates each group had this frame (tools/perf, the tests):
	## packs, then reports {group: n} plus "total".
	pack(view)
	return _counts.duplicate()
