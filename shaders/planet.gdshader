// 멀리 있는 가스 행성: 띠 무늬 + 대기 테두리 빛.
shader_type spatial;
render_mode shadows_disabled;

varying vec3 lp;
void vertex() { lp = VERTEX; }
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n2(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y); }
void fragment() {
	vec3 p = normalize(lp);
	float band = sin(p.y * 9.0 + n2(p.xz * 2.0) * 1.2) * 0.5 + 0.5;
	ALBEDO = mix(vec3(0.05, 0.08, 0.16), vec3(0.18, 0.26, 0.4), band * 0.7);
	ROUGHNESS = 0.9;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = vec3(0.3, 0.55, 1.2) * rim * 1.6;
}
