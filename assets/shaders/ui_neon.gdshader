shader_type canvas_item;

uniform vec4 neon_color : source_color = vec4(0.3, 0.8, 1.0, 1.0);
uniform float intensity = 1.2;
uniform float pulse_speed = 1.5;

void fragment() {
	float pulse = 0.5 + 0.5 * sin(TIME * pulse_speed);
	vec4 col = neon_color * intensity * pulse;
	COLOR = col;
}
