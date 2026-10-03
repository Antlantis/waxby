// Plan B, pass 1: the light field at reduced size, drawn into a SubViewport
// twice as wide as the field. The left half holds (lit, hush), the right half
// the tinted warm colour. darkness_apply.gdshader reads both halves back,
// filtered, and cuts the hard bands at full resolution (lit is smooth, so the
// bands stay crisp). world_lights.gd builds this when the light field is set
// to "quarter" (or "half").
shader_type canvas_item;
render_mode unshaded, blend_disabled;

#include "res://shaders/light_field.gdshaderinc"

void fragment() {
	bool second = UV.x >= 0.5;
	vec2 uv = vec2(second ? UV.x * 2.0 - 1.0 : UV.x * 2.0, UV.y);
	float lit;
	float hush;
	vec3 warm;
	light_field(uv * view_size, lit, hush, warm);
	COLOR = second ? vec4(warm, 1.0) : vec4(lit, hush, 0.0, 1.0);
}
