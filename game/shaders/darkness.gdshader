// The dark (v3): multiplies the screen by a dim tint everywhere except near a
// light, where it warms up (or takes that light's tint) in three hard cel
// bands. Hush lights (negative strength) eat light and deepen the dark; the
// hero guard keeps them out of the hero's own pool. With no tints and no
// Hush lights the output is v2's exactly (tests/test_render.gd and the
// screenshot diff, tools/perf/shot_diff.py). The field and the bands live in
// the two includes, shared with darkness_lit.gdshader (cutscene layers) and
// Plan B's darkness_field / darkness_apply (world_lights.gd picks the plan).
shader_type canvas_item;
render_mode blend_mul, unshaded;

#include "res://shaders/light_field.gdshaderinc"
#include "res://shaders/light_bands.gdshaderinc"

void fragment() {
	vec2 p = UV * view_size;
	float lit;
	float hush;
	vec3 warm;
	light_field(p, lit, hush, warm);
	COLOR = vec4(band_color(lit, hush, warm), 1.0);
}
