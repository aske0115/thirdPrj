// 빛나는 탄·불빛: 가산 합성, 카메라를 향하는 빌보드(billboard=1) 또는 바닥에 눕힌 줄무늬(streak).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform bool billboard = true;
uniform float streak = 0.0;
uniform float intensity = 1.0;
uniform float core_amt = 1.4;  // 하얀 심 세기(0이면 심 없는 은은한 빛 — 탄과 구분되는 장식용)

void vertex() {
	if (billboard) {
		MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
		MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0, 0, 0), vec4(0, length(MODEL_MATRIX[1].xyz), 0, 0), vec4(0, 0, length(MODEL_MATRIX[2].xyz), 0), vec4(0, 0, 0, 1));
	}
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	if (streak > 0.0) { p.y /= streak; }
	float d = length(p);
	float core = smoothstep(0.32, 0.0, d);
	float halo = pow(clamp(1.0 - d, 0.0, 1.0), 2.2);
	vec3 c = COLOR.rgb * halo + vec3(1.0) * core * core_amt;
	ALBEDO = c * intensity;
}
