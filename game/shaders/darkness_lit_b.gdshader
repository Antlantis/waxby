// Plan B for a cutscene layer: the bands from the shared reduced light field
// (light_field.gd's SubViewport, darkness_field.gdshader), multiplying the
// layer's own colour as darkness_lit.gdshader does, at screen positions.
shader_type canvas_item;
render_mode unshaded;

#include "res://shaders/light_bands.gdshaderinc"

uniform sampler2D field_tex : filter_linear, repeat_disable;
uniform vec2 field_size = vec2(211.0, 97.0);   // one half, in texels

void fragment() {
	float hx = 0.5 / field_size.x;
	float u = clamp(SCREEN_UV.x, hx, 1.0 - hx) * 0.5;
	vec4 a = texture(field_tex, vec2(u, SCREEN_UV.y));
	vec4 w = texture(field_tex, vec2(u + 0.5, SCREEN_UV.y));
	COLOR.rgb *= band_color(a.r, a.g, w.rgb);
}
