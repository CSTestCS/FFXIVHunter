// Shared additive effect material. Per-instance colour/alpha so every effect shares one material.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

instance uniform vec4 tint : source_color = vec4(1.0, 0.6, 0.2, 1.0);
instance uniform float fade = 1.0;

void fragment() {
	float rim = 1.0 - abs(dot(NORMAL, VIEW));
	ALBEDO = tint.rgb * tint.a * fade * (0.35 + rim * 1.4);
}
