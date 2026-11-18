// 적탄: 빛 번짐(글로우)에 기대지 않고도 또렷하게 — 하얀 심 + 색 몸통 + 어두운 테두리.
// 실기기(mobile 렌더러)에서 2D 글로우가 약해 탄이 안 보이던 문제(사용자 판정)를 고침. 배경이 밝아도 테두리로 구분됨.
shader_type canvas_item;
render_mode blend_mix;

varying vec4 tint;

void vertex() {
	tint = COLOR;  // 탄마다 다른 색(MultiMesh 인스턴스 색, HDR 값일 수 있음)
}

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	vec3 c = tint.rgb / max(max(tint.r, tint.g), max(tint.b, 1.0));  // HDR 색을 0~1로
	float core = smoothstep(0.42, 0.30, d);
	float body = smoothstep(0.74, 0.66, d);
	float edge = smoothstep(0.98, 0.86, d);
	vec3 col = mix(vec3(0.06, 0.0, 0.04), c, body);
	col = mix(col, vec3(1.0), core);
	COLOR = vec4(col, edge * tint.a);
}
