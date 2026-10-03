// The dark's field for a cutscene layer (the sibling of darkness.gdshader,
// no string surgery): the same lights, tints, Hush lights and bands,
// multiplying the layer's own colour instead of the screen. Positions are
// screen positions (SCREEN_UV), as the cutscene packs them. hero_guard stays
// 0 here (no hero light in a scene). panels.json lights map `color` to a
// tint and `hush: true` to a negative strength.
shader_type canvas_item;
render_mode unshaded;

#include "res://shaders/light_field.gdshaderinc"
#include "res://shaders/light_bands.gdshaderinc"

void fragment() {
	vec2 p = SCREEN_UV * view_size;
	float lit;
	float hush;
	vec3 warm;
	light_field(p, lit, hush, warm);
	COLOR.rgb *= band_color(lit, hush, warm);
}
