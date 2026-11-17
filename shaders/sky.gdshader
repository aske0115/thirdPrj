// 배경: 위로 흘러가는 구름층과 별, 아래쪽 노을빛. 코드로만 그림.
shader_type canvas_item;

uniform float speed = 1.0;

float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 4; i++) { v += a * n2(p); p *= 2.03; a *= 0.5; } return v; }

void fragment() {
	vec2 uv = UV;
	float t = TIME * speed;
	vec3 top = vec3(0.03, 0.03, 0.09);
	vec3 bot = vec3(0.22, 0.08, 0.16);
	vec3 col = mix(top, bot, smoothstep(0.2, 1.1, uv.y));
	// 별
	vec2 sp = uv * vec2(40.0, 70.0) + vec2(0.0, -t * 2.0);
	float st = step(0.985, h(floor(sp))) * smoothstep(0.5, 0.0, length(fract(sp) - 0.5));
	col += vec3(0.8, 0.85, 1.0) * st * 0.8;
	// 구름층 두 겹(가까울수록 빠름)
	float c1 = fbm(uv * vec2(3.0, 5.0) + vec2(0.0, -t * 0.25));
	float c2 = fbm(uv * vec2(5.0, 8.0) + vec2(3.0, -t * 0.55));
	col = mix(col, vec3(0.16, 0.1, 0.24), smoothstep(0.5, 0.8, c1) * 0.7);
	col = mix(col, vec3(0.35, 0.16, 0.26), smoothstep(0.55, 0.85, c2) * 0.55 * uv.y);
	COLOR = vec4(col, 1.0);
}
