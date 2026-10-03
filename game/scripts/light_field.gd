extends Node
## Plan B's light field: the dark's per-pixel light loop run once, at a
## reduced size, into a SubViewport (darkness_field.gdshader: (lit, hush) in
## the left half, the tinted warm colour in the right), for full-size passes
## that only read it back and cut the bands:
##   the level's dark      make_bands_material(false)   darkness_apply.gdshader (multiplies the screen)
##   a cutscene's layers   make_bands_material(true)    darkness_lit_b.gdshader (multiplies the layer)
## Every layer of a scene shares one field, so four lit layers cost one light
## loop instead of four. world_lights.gd builds one for Plan B; cutscene.gd
## (ST) can build one the same way when world_lights.gd's field_mode() is not
## "full". set_param() routes a uniform to the field and to every bands
## material it made (lights, tints, light_count, view_size, warm_color,
## hero_guard go to the field; dark_color, hush_depth to the bands).
##   var f := LightField.new(); f.scale = 0.25; host.add_child(f)
##   layer.material = f.make_bands_material(true)
##   f.set_param("lights", arr) ...

const FIELD_SHADER := preload("res://shaders/darkness_field.gdshader")
const APPLY_SHADER := preload("res://shaders/darkness_apply.gdshader")
const LIT_B_SHADER := preload("res://shaders/darkness_lit_b.gdshader")

var scale := 0.25                   # of the window's pixels, each way
var field_mat := ShaderMaterial.new()
var bands: Array = []               # the bands materials made from this field
var _vp: SubViewport
var _rect: ColorRect
var _half := Vector2i(8, 8)


func _init() -> void:
	field_mat.shader = FIELD_SHADER
	_vp = SubViewport.new()
	_vp.disable_3d = true
	_vp.transparent_bg = false
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_rect = ColorRect.new()
	_rect.material = field_mat
	_vp.add_child(_rect)
	add_child(_vp)


func _ready() -> void:
	resize()
	get_viewport().size_changed.connect(resize)


func resize() -> void:
	var px := Vector2(1266, 585)
	if is_inside_tree():
		px = Vector2(get_tree().root.size)
	_half = Vector2i(maxi(ceili(px.x * scale), 8), maxi(ceili(px.y * scale), 8))
	_vp.size = Vector2i(_half.x * 2, _half.y)
	_rect.size = Vector2(_vp.size)
	for m in bands:
		(m as ShaderMaterial).set_shader_parameter("field_size", Vector2(_half))


func viewport() -> SubViewport:
	return _vp


func texture() -> Texture2D:
	return _vp.get_texture()


func half_size() -> Vector2i:
	return _half


func make_bands_material(for_layer: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = LIT_B_SHADER if for_layer else APPLY_SHADER
	m.set_shader_parameter("field_tex", _vp.get_texture())
	m.set_shader_parameter("field_size", Vector2(_half))
	bands.append(m)
	return m


func set_param(name: String, value) -> void:
	field_mat.set_shader_parameter(name, value)
	for m in bands:
		(m as ShaderMaterial).set_shader_parameter(name, value)
