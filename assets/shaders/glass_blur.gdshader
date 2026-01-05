shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

// =====================
// BLUR SUAVE Y ESTABLE
// =====================
uniform float blur_amount : hint_range(0.0, 1.5) = 1.0;
uniform float blur_pixel : hint_range(0.5, 2.0) = 1.5;

// =====================
// OSCURECIMIENTO
// =====================
uniform float darken : hint_range(0.0, 1.0) = 6.0;
uniform float overlay_alpha : hint_range(0.0, 1.0) =6.1;

float luminance(vec3 c) {
	return dot(c, vec3(0.2126, 0.7152, 0.0722));
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE * blur_pixel;

	// =====================
	// BLUR 5-TAP (CRUZ)
	// =====================
	vec4 c = texture(screen_tex, uv) * 0.4;

	c += texture(screen_tex, uv + vec2(px.x, 0.0)) * 0.15;
	c += texture(screen_tex, uv - vec2(px.x, 0.0)) * 0.15;
	c += texture(screen_tex, uv + vec2(0.0, px.y)) * 0.15;
	c += texture(screen_tex, uv - vec2(0.0, px.y)) * 0.15;

	// Mezcla blur progresiva (clave para estabilidad)
	vec4 sharp = texture(screen_tex, uv);
	c = mix(sharp, c, blur_amount);

	// =====================
	// OSCURECIMIENTO CON PROTECCIÓN DE LUZ
	// =====================
	float lum = luminance(c.rgb);
	float protect = smoothstep(0.5, 0.9, lum);

	float final_darken = mix(darken, darken * 0.4, protect);
	c.rgb *= (1.0 - final_darken);

	c.a = overlay_alpha;
	COLOR = c;
}
