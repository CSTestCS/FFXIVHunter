// Hair: strand-like albedo variation, anisotropic sheen and optional tip highlights.
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec3 base_color : source_color = vec3(0.3, 0.2, 0.12);
uniform vec3 highlight_color : source_color = vec3(0.8, 0.6, 0.3);
uniform float highlight_amount = 0.0;

varying vec3 lp;

float h1(float x) { return fract(sin(x * 127.1) * 43758.5453); }

void vertex() {
	lp = VERTEX;
}

void fragment() {
	// strands run roughly top -> bottom; vary brightness around the head
	float ang = atan(lp.x, lp.z);
	float strand = h1(floor(ang * 60.0)) * 0.5 + h1(floor(ang * 160.0 + lp.y * 8.0)) * 0.5;
	float tips = smoothstep(0.02, -0.2, lp.y);
	vec3 col = base_color * (0.82 + 0.3 * strand);
	col = mix(col, highlight_color * (0.85 + 0.3 * strand), highlight_amount * clamp(tips * 0.8 + strand * 0.35 - 0.1, 0.0, 1.0));
	ALBEDO = col;
	ROUGHNESS = 0.42 + 0.15 * strand;
	SPECULAR = 0.55;
	BACKLIGHT = col * 0.25;
}
