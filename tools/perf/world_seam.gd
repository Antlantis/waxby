extends "res://scripts/world.gd"
## The v3 light seam on v2's World, by override: exactly the world.gd change
## W0-core makes in Phase 0 (tools/perf/world_seam.patch has it as a patch), so
## this copy's tests, screenshots and spikes run the real wiring before the
## merge. Nothing here is new behaviour: every body is a delegation to
## world_lights.gd (world.lights), ambient.gd and edge_lines.gd.
##   load("res://../tools/perf/world_seam.gd").new()   in place of world.gd

const WorldLights := preload("res://scripts/world_lights.gd")
const AmbientScript := preload("res://scripts/ambient.gd")
const EdgeLinesScript := preload("res://scripts/edge_lines.gd")

var lights: RefCounted              # world_lights.gd
var ambient: Node2D
var edges: Node2D
var light_field_mode := ""          # "" = world_lights.field_mode()


func _build() -> void:
	lights = WorldLights.new(self)
	super._build()
	# world.gd v3 builds the darkness through world_lights (one call in place
	# of the ColorRect block): here the v2 one is swapped for it.
	var layer: Node = _darkness.get_parent()
	_darkness.queue_free()
	layer.remove_child(_darkness)
	var dn: Control = lights.attach(layer, light_field_mode)
	_darkness = dn as ColorRect if dn is ColorRect else null
	_dark_mat = lights.material()
	_apply_theme_dark()
	# Under glow: the readability lines, then the ambient motes.
	var glow_layer: Node = glow.get_parent()
	edges = EdgeLinesScript.new()
	glow_layer.add_child(edges)
	glow_layer.move_child(edges, glow.get_index())
	edges.build(level, int(level.get("world")) if level.get("world") != null else 0)
	ambient = AmbientScript.new()
	ambient.world = self
	glow_layer.add_child(ambient)
	glow_layer.move_child(ambient, glow.get_index())
	ambient.set_theme(level.theme)


func _apply_theme_dark() -> void:
	var c: Dictionary = backdrop.colors()
	var dark := {"nave": Color(0.30, 0.25, 0.42), "crypt": Color(0.24, 0.30, 0.32), "choir": Color(0.40, 0.24, 0.24), "tower": Color(0.26, 0.28, 0.46)}
	var col: Color = c.get("dark", dark.get(_theme(), dark["nave"]))
	var bright := float(Game.setting("brightness"))
	if lights != null and lights.dark_mat != null:
		lights.theme_dark(col, bright)
	elif _dark_mat != null:
		_dark_mat.set_shader_parameter("dark_color", col.lightened(bright))


func _update_lights() -> void:
	lights.pack(view_rect())


func _redraw_at(x: int) -> void:
	if edges:
		edges.redraw_cell(x)
	super._redraw_at(x)


func tick(dt: float) -> void:
	super.tick(dt)
	lights.step(dt)


func add_light(pos: Vector2, r: float, s := 0.8, life := -1.0, tag := "", tint := Color(0, 0, 0, 0)) -> int:
	return lights.add(pos, r, s, life, tag, tint)


func move_light(id: int, pos: Vector2, r := -1.0) -> void:
	lights.move(id, pos, r)


func remove_light(id: int) -> void:
	lights.remove(id)


func lights_tagged(tag: String) -> Array:
	return lights.tagged(tag)


func hero_light_radius() -> float:
	return lights.hero_radius()


func set_dark(color: Color, seconds: float) -> void:
	lights.set_dark(color, seconds)


func set_warm(color: Color, seconds: float) -> void:
	lights.set_warm(color, seconds)


func lit_at(p: Vector2, pad := 0.0, opts := {}) -> bool:
	return lights.lit_at(p, pad, opts)


func dim(key: String, mult: float, seconds: float) -> void:
	lights.dim(key, mult, seconds)


func undim(key: String) -> void:
	lights.undim(key)


func light_override(r: float) -> void:
	lights.light_override(r)
