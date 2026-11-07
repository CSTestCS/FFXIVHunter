// Water: depth-tinted, fresnel reflections from the sky, shoreline foam, scrolling normal maps.
// Uses the depth buffer only (no screen copy) to stay cheap.
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_disabled, specular_schlick_ggx;

uniform vec3 shallow : source_color = vec3(0.18, 0.5, 0.55);
uniform vec3 deep : source_color = vec3(0.03, 0.14, 0.24);
uniform float depth_scale = 0.18;
uniform sampler2D waves : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = wpos.xz;
	vec3 n1 = texture(waves, uv * 0.035 + TIME * vec2(0.012, 0.008)).rgb;
	vec3 n2 = texture(waves, uv * 0.09 - TIME * vec2(0.01, 0.017)).rgb;
	NORMAL_MAP = normalize(n1 + n2 - 1.0);
	NORMAL_MAP_DEPTH = 0.6;
	float d = texture(depth_tex, SCREEN_UV).r;
	vec4 world = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, d, 1.0);
	world.xyz /= world.w;
	float depth = clamp(wpos.y - world.y, 0.0, 50.0);
	if (!FRONT_FACING) depth = 4.0;
	float t = 1.0 - exp(-depth * depth_scale);
	vec3 col = mix(shallow, deep, t);
	float foam = (1.0 - smoothstep(0.0, 0.6, depth)) * (0.6 + 0.4 * sin(TIME * 1.5 + uv.x * 0.7 + uv.y * 0.5));
	ALBEDO = mix(col, vec3(0.9), foam * 0.7);
	ALPHA = clamp(0.55 + t * 0.45 + foam * 0.3, 0.0, 0.97);
	ROUGHNESS = 0.04;
	METALLIC = 0.0;
	SPECULAR = 0.6;
}
