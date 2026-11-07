// Grass blades: base-to-tip gradient and wind. Drawn in near-camera chunks only (visibility ranges).
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;

uniform vec3 base_col : source_color = vec3(0.2, 0.32, 0.1);
uniform vec3 tip_col : source_color = vec3(0.55, 0.65, 0.3);

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = UV.y;
	float w = sin(TIME * 1.7 + wp.x * 0.35 + wp.z * 0.3) * 0.5 + sin(TIME * 2.9 + wp.x * 0.9) * 0.2;
	VERTEX.x += w * h * h * 0.18;
	VERTEX.z += w * h * h * 0.1;
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	ALBEDO = mix(base_col, tip_col * COLOR.rgb, UV.y);
	BACKLIGHT = tip_col * 0.3;
	ROUGHNESS = 0.9;
}
