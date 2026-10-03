// The light field, shared by the level's dark (darkness.gdshader, Plan A),
// the cutscene layers (darkness_lit.gdshader) and Plan B's quarter-size
// field (darkness_field.gdshader). Owned by the render foundation
// (world_lights.gd packs the lights; nothing else writes these uniforms).
//
// lights[i] = (x, y, radius, strength) in viewport pixels. strength < 0 is a
// Hush light: it eats the light round it and deepens the dark there.
// tints[i]  = (r, g, b, amount): amount 0 is the warm candle colour.
// hero_guard: 1.0 in levels while light 0 is the hero (or his snuff light):
// no Hush light dims anything inside 0.6 of light 0's radius, and the guard
// fades out by 1.0. 0 when no hero light is packed (and in cutscenes).
// With every tint amount 0 and no Hush light this is v2's field exactly.
uniform vec2 view_size = vec2(844.0, 390.0);
uniform int light_count = 0;
uniform vec4 lights[48];
uniform vec4 tints[48];
uniform vec3 warm_color : source_color = vec3(1.0, 0.95, 0.86);
uniform float hero_guard = 0.0;

void light_field(vec2 p, out float lit, out float hush, out vec3 warm) {
	lit = 0.0;
	hush = 0.0;
	vec3 tint_acc = vec3(0.0);
	float w_sum = 0.0;
	for (int i = 0; i < 48; i++) {
		if (i >= light_count) {
			break;
		}
		vec4 L = lights[i];
		vec2 dp = p - L.xy;
		float rr = max(L.z, 1.0);
		float dd = dot(dp, dp);
		if (dd >= rr * rr) {
			continue;            // outside: its term is exactly 0 in v2 too
		}
		float v = 1.0 - smoothstep(0.22, 1.0, sqrt(dd) / rr);
		if (L.w < 0.0) {
			hush = 1.0 - (1.0 - hush) * (1.0 - v * -L.w);
			continue;
		}
		v *= L.w;
		lit = 1.0 - (1.0 - lit) * (1.0 - v);
		vec4 T = tints[i];
		tint_acc += (T.rgb - warm_color) * (T.a * v);
		w_sum += v;
	}
	if (hero_guard > 0.0 && hush > 0.0) {
		vec4 H = lights[0];
		float hd = length(p - H.xy) / max(H.z, 1.0);
		hush = min(hush, mix(1.0 - hero_guard, 1.0, smoothstep(0.6, 1.0, hd)));
	}
	lit *= 1.0 - hush;
	warm = w_sum > 0.0 ? warm_color + tint_acc / w_sum : warm_color;
}
