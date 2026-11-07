// Terrain: grass / rock / sand / road / city paving blended by slope, height and painted masks.
// Detail comes from two tiling noise textures (cheap: 4 texture samples per pixel).
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 grass : source_color = vec3(0.37, 0.55, 0.23);
uniform vec3 grass2 : source_color = vec3(0.52, 0.64, 0.29);
uniform vec3 rock : source_color = vec3(0.52, 0.5, 0.47);
uniform vec3 sand : source_color = vec3(0.85, 0.79, 0.6);
uniform vec3 dirt : source_color = vec3(0.53, 0.44, 0.31);
uniform vec3 pave : source_color = vec3(0.62, 0.6, 0.56);
uniform float water_level = -1000.0;
uniform sampler2D detail : filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_n : hint_normal, filter_linear_mipmap, repeat_enable;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float cobble(vec2 p) {
	vec2 g = p * vec2(1.6, 2.2);
	g.x += step(1.0, mod(floor(g.y), 2.0)) * 0.5;
	vec2 f = fract(g) - 0.5;
	float d = max(abs(f.x) * 1.1, abs(f.y));
	return smoothstep(0.5, 0.38, d);
}

void fragment() {
	vec2 uv = wpos.xz;
	float n1 = texture(detail, uv * 0.045).r;
	float n2 = texture(detail, uv * 0.31).r;
	float slope = 1.0 - wnrm.y;
	vec3 g = mix(grass, grass2, smoothstep(0.35, 0.65, n1));
	g *= 0.85 + 0.3 * n2;
	vec3 col = g;
	float rough = 0.92;
	// sand near water
	float beach = 1.0 - smoothstep(water_level + 0.4, water_level + 1.8 + n1, wpos.y);
	col = mix(col, sand * (0.9 + 0.2 * n2), beach);
	// wet sand / underwater darkening
	float wet = 1.0 - smoothstep(water_level - 0.2, water_level + 0.5, wpos.y);
	// rock on slopes
	float rk = smoothstep(0.22, 0.38, slope + (n1 - 0.5) * 0.15);
	col = mix(col, rock * (0.75 + 0.45 * n2), rk);
	rough = mix(rough, 0.8, rk);
	// road
	float road = clamp(COLOR.r * (0.75 + 0.5 * n2), 0.0, 1.0);
	col = mix(col, dirt * (0.85 + 0.3 * n2), road);
	// city paving
	float pv = COLOR.b;
	float cb = cobble(uv);
	vec3 pcol = pave * (0.88 + 0.12 * n1) * mix(0.7, 1.0, cb);
	col = mix(col, pcol, pv);
	rough = mix(rough, mix(0.95, 0.7, cb), pv);
	col *= mix(1.0, 0.55, wet);
	rough = mix(rough, 0.25, wet * 0.8);
	ALBEDO = col;
	ROUGHNESS = rough;
	NORMAL_MAP = texture(detail_n, uv * 0.25).rgb;
	NORMAL_MAP_DEPTH = mix(mix(0.6, 1.4, rk), 0.35, pv);
}
