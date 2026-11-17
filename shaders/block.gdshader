// 블록 건물·파편 공용. 창문은 텍스처 없이 면 좌표로 그리고, INSTANCE_CUSTOM.r(전기)이 0이면 창이 꺼진다.
shader_type spatial;

varying vec3 lpos;
varying vec3 lnorm;
varying vec4 cdata;

void vertex() {
	lpos = VERTEX;
	lnorm = NORMAL;
	cdata = INSTANCE_CUSTOM;
}

float hash(float n) { return fract(sin(n) * 43758.5453); }

void fragment() {
	vec3 base = COLOR.rgb;
	float side = 1.0 - step(0.5, abs(lnorm.y));
	vec2 fuv = abs(lnorm.x) > 0.5 ? lpos.zy : lpos.xy;
	vec2 cell = fract(fuv * vec2(2.0, 1.0) + 0.5);
	float win = side * step(0.2, cell.x) * step(cell.x, 0.8) * step(0.28, cell.y) * step(cell.y, 0.78) * cdata.a;
	float id = floor((fuv.x + 0.5) * 2.0) + cdata.g * 97.0 + lnorm.x * 3.0 + lnorm.z * 7.0;
	float on = step(0.32, hash(id)) * cdata.r;
	float warm = hash(id + 5.0);
	float band = side * (1.0 - step(0.06, fract(lpos.y + 0.5))) * cdata.a;
	ALBEDO = mix(base * (1.0 - band * 0.35), vec3(0.04, 0.05, 0.09), win);
	EMISSION = win * on * mix(vec3(1.0, 0.42, 0.1), vec3(1.0, 0.62, 0.28), warm) * 1.25;
	ROUGHNESS = mix(0.92, 0.25, win);
	SPECULAR = mix(0.2, 0.6, win);
}
