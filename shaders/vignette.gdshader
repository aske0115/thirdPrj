// 화면 가장자리를 살짝 어둡게(시선을 가운데로).
shader_type canvas_item;
uniform float strength = 0.55;
void fragment() {
	vec2 p = UV - 0.5;
	p.x *= 0.75;
	float v = smoothstep(0.35, 0.85, length(p));
	COLOR = vec4(0.0, 0.0, 0.02, v * strength);
}
