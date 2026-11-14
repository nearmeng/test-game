shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;

// 草叶：根部深、叶尖亮，顶点用时做风摆
uniform vec3 base_color : source_color = vec3(0.045, 0.10, 0.045);
uniform vec3 tip_color : source_color = vec3(0.19, 0.38, 0.14);
uniform float sway_amount = 0.11;
uniform float sway_speed = 1.7;

void vertex() {
	float h = UV.y;
	float phase = VERTEX.x * 0.85 + VERTEX.z * 1.15;
	float s = sin(TIME * sway_speed + phase);
	float c = cos(TIME * sway_speed * 0.75 + phase * 1.3);
	VERTEX.x += s * sway_amount * h * h;
	VERTEX.z += c * sway_amount * 0.65 * h * h;
}

void fragment() {
	vec3 col = mix(base_color, tip_color, clamp(UV.y * 1.15, 0.0, 1.0));
	ALBEDO = col * COLOR.rgb;
	ROUGHNESS = 0.93;
	SPECULAR = 0.0;
	BACKLIGHT = col * 0.3;
}
