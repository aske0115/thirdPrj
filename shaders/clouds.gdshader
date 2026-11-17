// 중간층 구름(반투명, 흘러감): 배경과 전투 사이 깊이감.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 tint = vec3(0.25, 0.3, 0.55);
uniform float density = 0.6;
uniform float speed = 0.03;
uniform float scale = 3.0;

float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y); }
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 5; i++) { v += a * n2(p); p *= 2.07; a *= 0.5; } return v; }

void fragment() {
	vec2 uv = UV * scale + vec2(0.0, -TIME * speed);
	float c = fbm(uv);
	float m = smoothstep(0.45, 0.85, c);
	float edge = smoothstep(0.0, 0.15, UV.x) * smoothstep(1.0, 0.85, UV.x) * smoothstep(0.0, 0.15, UV.y) * smoothstep(1.0, 0.85, UV.y);
	ALBEDO = tint * (0.6 + c);
	ALPHA = m * density * edge;
}
