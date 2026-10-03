// The dark's three hard cel bands with thin soft seams between them (v2's),
// and the Hush deepening the dark. Shared by darkness.gdshader,
// darkness_lit.gdshader and darkness_apply.gdshader (Plan B).
uniform vec3 dark_color : source_color = vec3(0.30, 0.25, 0.40);
uniform float hush_depth = 0.7;   // how much darker than dark a full Hush makes it

vec3 band_color(float lit, float hush, vec3 warm) {
	vec3 dark = dark_color * (1.0 - hush_depth * hush);
	float b = lit * 3.0;
	float seam = smoothstep(0.82, 1.0, fract(b));
	float stepped = clamp((floor(b) + seam) / 3.0, 0.0, 1.0);
	return mix(dark, warm, stepped);
}
