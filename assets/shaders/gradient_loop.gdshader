shader_type canvas_item;

uniform float time_speed = 0.12;
uniform float light_intensity = 0.25;
uniform float ray_intensity = 0.22;
uniform float grain_intensity = 0.03;

uniform int ray_count = 8;

float random(vec2 st) {
	return fract(sin(dot(st.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

float circle(vec2 uv, vec2 pos, float radius, float softness) {
	float d = distance(uv, pos);
	return smoothstep(radius, radius - softness, d);
}

float vertical_ray(vec2 uv, float x_pos, float y_offset, float width) {
	float band = smoothstep(width, width - 0.015, abs(uv.x - x_pos));

	float y = fract(uv.y + y_offset);
	float fade_y = smoothstep(0.0, 0.25, y) * smoothstep(1.0, 0.75, y);

	return band * fade_y;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * time_speed;

	vec3 color = vec3(0.0);

	// =========================
	// Luces difuminadas base
	// =========================
	vec2 p1 = vec2(0.35 + 0.07 * sin(t), 0.55 + 0.05 * cos(t * 0.8));
	vec2 p2 = vec2(0.65 + 0.05 * cos(t * 0.6), 0.45 + 0.07 * sin(t * 0.9));

	vec3 red    = vec3(0.8, 0.1, 0.1);
	vec3 violet = vec3(0.4, 0.1, 0.6);
	vec3 blue   = vec3(0.1, 0.2, 0.7);

	color += red * circle(uv, p1, 0.42, 0.18) * light_intensity;
	color += mix(violet, blue, 0.5)
	       * circle(uv, p2, 0.45, 0.20) * light_intensity;

	// =========================
	// Rayos verticales con fade suave
	// =========================
	for (int i = 0; i < ray_count; i++) {
		float id = float(i);

		// Semillas estables
		float x_pos = random(vec2(id, 0.1));
		float speed = mix(0.10, 0.20, random(vec2(id, 0.2)));
		float width = mix(0.015, 0.030, random(vec2(id, 0.3)));

		// Fase de vida (0 → 1 → 0)
		float phase = sin(TIME * speed + id * 10.0) * 0.5 + 0.5;
		float life = smoothstep(0.0, 0.2, phase) * smoothstep(1.0, 0.7, phase);

		// Movimiento vertical
		float y_offset = TIME * speed;

		float ray = vertical_ray(uv, x_pos, y_offset, width);

		vec3 ray_color = mix(violet, blue, random(vec2(id, 0.4)));

		color += ray_color * ray * life * ray_intensity;
	}

	// =========================
	// Grano sutil
	// =========================
	float grain = random(uv + t) - 0.5;
	color += grain * grain_intensity;

	COLOR = vec4(color, 1.0);
}
