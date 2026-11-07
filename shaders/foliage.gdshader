// Tree canopies / bushes: wind sway in the vertex shader, light transmission for backlit leaves.
shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform vec3 leaf : source_color = vec3(0.25, 0.42, 0.16);
uniform float sway = 0.12;

varying float var_n;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float ph = wp.x * 0.13 + wp.z * 0.11;
	float h = max(VERTEX.y - 1.0, 0.0);
	VERTEX.x += sin(TIME * 1.3 + ph) * sway * h * 0.08;
	VERTEX.z += cos(TIME * 1.1 + ph) * sway * h * 0.06;
	var_n = fract(sin(dot(floor(VERTEX * 3.0), vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void fragment() {
	vec3 c = leaf * COLOR.rgb * (0.8 + 0.35 * var_n);
	ALBEDO = c;
	ROUGHNESS = 0.75;
	BACKLIGHT = c * 0.6;
	SPECULAR = 0.3;
}
