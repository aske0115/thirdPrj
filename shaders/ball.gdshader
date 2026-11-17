// 쇠공: 녹·쇠 무늬 위에 열기(heat 0~1)에 따라 균열이 붉게 → 희게 빛남. 테두리 빛으로 어두운 화면에서도 보이게.
shader_type spatial;

uniform float heat : hint_range(0.0, 1.0) = 0.0;
varying vec3 lp;

void vertex() { lp = VERTEX; }

float h3(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }
float noise(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1,0,0)), f.x), mix(h3(i + vec3(0,1,0)), h3(i + vec3(1,1,0)), f.x), f.y),
	           mix(mix(h3(i + vec3(0,0,1)), h3(i + vec3(1,0,1)), f.x), mix(h3(i + vec3(0,1,1)), h3(i + vec3(1,1,1)), f.x), f.y), f.z);
}

void fragment() {
	vec3 p = normalize(lp);
	float n = noise(p * 5.0) * 0.6 + noise(p * 13.0) * 0.4;
	vec3 rust = mix(vec3(0.16, 0.08, 0.04), vec3(0.45, 0.21, 0.08), n);
	vec3 steel = vec3(0.24, 0.24, 0.27);
	ALBEDO = mix(steel, rust, smoothstep(0.4, 0.7, n) * (1.0 - heat * 0.7));
	METALLIC = 0.35;
	ROUGHNESS = 0.6 + 0.3 * n;
	float crack = smoothstep(0.06, 0.0, abs(noise(p * 4.0 + 3.1) - 0.5));
	vec3 hot = mix(vec3(1.0, 0.22, 0.04), vec3(1.0, 0.85, 0.6), smoothstep(0.75, 1.0, heat));
	EMISSION = hot * (crack * (0.08 + 2.6 * heat) + heat * heat * heat * 0.6);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION += vec3(1.0, 0.55, 0.25) * rim * 0.4;
}
