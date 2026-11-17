// 먼 배경: 성운과 별(코드로만). 깊은 남색 바탕에 청록·자주 성운, 따뜻한 먼지띠.
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform float scroll = 0.0;

float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y); }
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 6; i++) { v += a * n2(p); p = p * 2.02 + vec2(1.7, 9.2); a *= 0.5; } return v; }

void fragment() {
	vec2 uv = UV * 6.0 + vec2(0.0, -TIME * 0.02 - scroll);
	float a = fbm(uv);
	float b = fbm(uv * 1.7 + vec2(a * 2.0, 3.1));
	float c = fbm(uv * 3.1 - vec2(b, a));
	vec3 base = vec3(0.012, 0.014, 0.04);
	vec3 teal = vec3(0.02, 0.22, 0.32);
	vec3 mag = vec3(0.32, 0.05, 0.28);
	vec3 warm = vec3(0.55, 0.22, 0.08);
	vec3 col = base;
	col = mix(col, teal, smoothstep(0.45, 0.85, a) * 0.85);
	col = mix(col, mag, smoothstep(0.5, 0.9, b) * 0.7);
	col += warm * pow(smoothstep(0.55, 0.95, c), 2.0) * 0.6;
	// 별: 작은 점 + 드문 밝은 별
	vec2 sp = UV * 900.0;
	float s = step(0.996, h(floor(sp))) * smoothstep(0.45, 0.0, length(fract(sp) - 0.5));
	vec2 sp2 = UV * 160.0;
	float s2 = step(0.995, h(floor(sp2) + 7.0)) * pow(smoothstep(0.5, 0.0, length(fract(sp2) - 0.5)), 3.0);
	col += vec3(0.8, 0.9, 1.0) * (s * 1.2 + s2 * 6.0);
	ALBEDO = col;
}
