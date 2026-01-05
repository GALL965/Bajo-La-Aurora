shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

uniform vec4 tint : source_color = vec4(0.45, 0.25, 1.0, 0.35);
uniform float blur_strength : hint_range(0.0, 3.0) = 1.2;
uniform float glow_strength : hint_range(0.0, 2.0) = 0.6;
uniform float flow_speed : hint_range(0.0, 3.0) = 0.6;

void fragment() {
	vec2 uv = SCREEN_UV;

	// Movimiento ondulante (energía)
	float t = TIME * flow_speed;
	vec2 flow = vec2(
		sin((uv.y + t) * 6.0),
		cos((uv.x + t) * 6.0)
	) * 0.003;

	// --- Desenfoque simple (4 muestras) ---
	vec4 col = vec4(0.0);
	col += texture(screen_texture, uv + flow);
	col += texture(screen_texture, uv + flow + vec2(0.002, 0.0) * blur_strength);
	col += texture(screen_texture, uv + flow + vec2(-0.002, 0.0) * blur_strength);
	col += texture(screen_texture, uv + flow + vec2(0.0, 0.002) * blur_strength);
	col += texture(screen_texture, uv + flow + vec2(0.0, -0.002) * blur_strength);
	col /= 5.0;

	// --- Glow pulsante ---
	float pulse = 0.5 + 0.5 * sin(TIME * 2.0);
	vec3 glow = tint.rgb * pulse * glow_strength;

	// Mezcla final
	vec3 final_color = mix(col.rgb, glow + col.rgb, tint.a);

	COLOR = vec4(final_color, 1.0);
}
