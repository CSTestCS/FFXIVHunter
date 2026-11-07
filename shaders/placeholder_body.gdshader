// Placeholder VRoid body: PBR skin with subsurface scattering, and "painted on" clothing per body region.
// Only used for the generated placeholder models; your own VRoid models keep their own materials.
// UV2.x = region id (see tools/make_placeholder_vrm.py), COLOR.rgb = rest-pose position.
shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 skin_color : source_color = vec3(0.9, 0.75, 0.65);
// rgb = cloth colour, a = 1 cloth / 0 skin.  Order: head neck torso uarm larm hand pelvis thigh shin foot bust
uniform vec4 region_colors[11];
uniform float cloth_rough = 0.85;
uniform float cloth_metal = 0.0;
uniform float sss = 0.35;
uniform vec3 head_center = vec3(0.0, 1.54, -0.008);
uniform float body_scale = 1.0;
uniform vec3 lip_color : source_color = vec3(0.7, 0.4, 0.4);
uniform int marking = 0;
uniform vec3 marking_color : source_color = vec3(0.6, 0.1, 0.1);
uniform float bruise = 0.0;
uniform vec3 scale_tint : source_color = vec3(0.4, 0.3, 0.2);
uniform float scales = 0.0;

varying flat int region;
varying vec3 rest;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	region = int(UV2.x + 0.5);
	rest = vec3(COLOR.r * 2.0 - 1.0, COLOR.g * 2.0, COLOR.b * 2.0 - 1.0) / body_scale;
}

void fragment() {
	vec4 rc = region_colors[clamp(region, 0, 10)];
	float cloth = rc.a;
	vec3 skin = skin_color;
	// subtle skin variation: warmer at cheeks, knuckles, knees
	float n = vnoise(rest * 90.0) * 0.5 + vnoise(rest * 23.0) * 0.5;
	skin *= 0.94 + 0.08 * n;
	vec3 h = (rest - head_center) / vec3(0.088, 0.112, 0.1);
	if (region == 0) {
		float cheeks = smoothstep(0.5, 0.0, length(vec2(abs(h.x) - 0.48, h.y + 0.25))) * step(h.z, -0.3);
		skin = mix(skin, skin * vec3(1.05, 0.86, 0.84), cheeks * 0.35);
		// lips
		float lips = smoothstep(0.09, 0.0, length(vec2(h.x * 0.45, h.y + 0.62))) * step(h.z, -0.4);
		skin = mix(skin, lip_color, lips * 0.85);
		// face markings
		float m = 0.0;
		if (marking == 1) m = step(abs(fract(h.y * 4.0) - 0.5), 0.12) * step(0.35, abs(h.x)) * step(h.y, 0.0) * step(-0.55, h.y);
		else if (marking == 2) m = smoothstep(0.12, 0.05, abs(h.y - 0.05)) * step(h.z, -0.2);
		else if (marking == 3) m = smoothstep(0.12, 0.08, length(vec2(h.x, h.y - 0.55))) * step(h.z, -0.3);
		else if (marking == 4) m = step(0.82, vnoise(rest * 400.0)) * smoothstep(0.5, 0.2, length(vec2(abs(h.x) - 0.4, h.y + 0.15))) * step(h.z, -0.3);
		else if (marking == 5) m = step(abs(h.x - h.y * 0.3 - 0.3), 0.07) * step(h.y, 0.3) * step(-0.6, h.y) + step(abs(-h.x - h.y * 0.3 - 0.3), 0.07) * step(h.y, 0.3) * step(-0.6, h.y);
		else if (marking == 6) m = step(abs(h.x - 0.35 + h.y * 0.5), 0.025) * step(abs(h.y + 0.05), 0.35) * step(h.z, -0.3);
		skin = mix(skin, marking_color, clamp(m, 0.0, 1.0) * 0.9);
	}
	if (scales > 0.0) {
		float sc = step(0.55, vnoise(rest * 140.0)) * smoothstep(0.2, 0.6, vnoise(rest * 6.0));
		skin = mix(skin, scale_tint, sc * scales * 0.6);
	}
	if (bruise > 0.0) {
		float b = smoothstep(0.62, 0.8, vnoise(rest * 11.0 + 3.0));
		float dirt = smoothstep(0.4, 0.9, vnoise(rest * 34.0));
		skin = mix(skin, vec3(0.35, 0.2, 0.3) * skin, b * bruise * 0.7);
		skin = mix(skin, vec3(0.3, 0.24, 0.18), dirt * bruise * 0.4);
	}
	// cloth: woven fabric pattern + soft folds
	float weave = 0.9 + 0.1 * vnoise(rest * vec3(420.0, 420.0, 420.0)) + 0.06 * sin(rest.y * 900.0) * sin(rest.x * 900.0 + rest.z * 900.0);
	float folds = 0.92 + 0.08 * vnoise(rest * vec3(12.0, 30.0, 12.0));
	vec3 cloth_col = rc.rgb * weave * folds;
	ALBEDO = mix(skin, cloth_col, cloth);
	ROUGHNESS = mix(0.48 + 0.1 * n, cloth_rough, cloth);
	METALLIC = cloth * cloth_metal;
	SPECULAR = mix(0.38, 0.28, cloth);
	SSS_STRENGTH = (1.0 - cloth) * sss;
	if (region == 0) {
		RIM = 0.15;
		RIM_TINT = 0.6;
	}
}
