// Plan B, pass 2: the bands at full resolution from the reduced light field
// (darkness_field.gdshader's two halves), multiplying the screen as
// darkness.gdshader does.
shader_type canvas_item;
render_mode blend_mul, unshaded;

#include "res://shaders/light_bands.gdshaderinc"

uniform sampler2D field_tex : filter_linear, repeat_disable;
uniform vec2 field_size = vec2(211.0, 97.0);   // one half, in texels

void fragment() {
	// Keep the filter's footprint inside each half.
	float hx = 0.5 / field_size.x;
	float u = clamp(UV.x, hx, 1.0 - hx) * 0.5;
	vec4 a = texture(field_tex, vec2(u, UV.y));
	vec4 w = texture(field_tex, vec2(u + 0.5, UV.y));
	COLOR = vec4(band_color(a.r, a.g, w.rgb), 1.0);
}
