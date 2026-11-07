// Enemy attack telegraphs (flat ground markers). shape: 0 circle, 1 cone, 2 line, 3 donut.
// fill grows 0..1 during the wind-up so the player can read exactly when it lands.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform int shape = 0;
uniform float fill = 0.0;
uniform float angle = 1.0;     // cone half-angle (radians)
uniform float inner = 0.0;     // donut inner radius (0..1)
uniform vec4 color : source_color = vec4(1.0, 0.35, 0.1, 1.0);

void fragment() {
	vec2 p = UV * 2.0 - 1.0;  // -1..1, forward = -y
	float r = length(p);
	float inside = 0.0;
	float edge = 0.0;
	float prog = 0.0;
	if (shape == 0) {
		inside = step(r, 1.0);
		edge = smoothstep(0.9, 1.0, r) * inside;
		prog = step(r, fill);
	} else if (shape == 1) {
		float a = atan(p.x, -p.y);
		inside = step(r, 1.0) * step(abs(a), angle);
		edge = max(smoothstep(0.9, 1.0, r), smoothstep(angle - 0.06, angle, abs(a))) * inside;
		prog = step(r, fill);
	} else if (shape == 2) {
		inside = 1.0;
		edge = max(smoothstep(0.88, 1.0, abs(p.x)), smoothstep(0.96, 1.0, abs(p.y)));
		prog = step(1.0 - (UV.y), fill);
	} else {
		inside = step(r, 1.0) * step(inner, r);
		edge = (smoothstep(0.92, 1.0, r) + smoothstep(inner + 0.06, inner, r)) * inside;
		prog = step(r, inner + (1.0 - inner) * fill);
	}
	float a = inside * (0.18 + 0.32 * prog + 0.6 * edge);
	ALBEDO = color.rgb * a;
	ALPHA = 1.0;
}
