shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform vec4 tint : source_color = vec4(0.45, 0.20, 1.00, 0.35);
uniform float desaturate = 0.20;

void fragment() {
	vec4 base = texture(screen_texture, SCREEN_UV);
	float gray = dot(base.rgb, vec3(0.299, 0.587, 0.114));
	vec3 mixed = mix(base.rgb, vec3(gray), desaturate);
	mixed = mix(mixed, tint.rgb, tint.a);
	COLOR = vec4(mixed, 1.0);
}
