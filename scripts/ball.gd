# 주인공: 철거용 쇠공(결정 006). 끄는 방향으로 가속(관성), 빨리 구를수록 달아오름, 끊어진 사슬을 끌고 다님.
class_name Ball
extends Node3D

const LINKS := 12

var radius := T.RADIUS[0]
var vel := Vector3.ZERO
var heat := 0.0
var input := Vector2.ZERO
var stage := 0
var airborne := 0.0          # 분노 일격 중 남은 공중 시간
var vis: MeshInstance3D
var mat: ShaderMaterial
var chain: PackedVector3Array
var chain_prev: PackedVector3Array
var chain_mm: MultiMesh
var shadow: MeshInstance3D

func _ready() -> void:
	vis = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 32
	sm.rings = 16
	vis.mesh = sm
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/ball.gdshader")
	vis.material_override = mat
	add_child(vis)
	# 어두운 화면·잔해 더미 속에서도 쇠공 자리가 보이게 바닥 빛 고리
	shadow = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	q.orientation = PlaneMesh.FACE_Y
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 0.75, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.15), Color(1, 1, 1, 0.9), Color(1, 1, 1, 0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.no_depth_test = true
	qm.albedo_texture = gt
	qm.albedo_color = Color(1.0, 0.55, 0.2, 0.8)
	q.material = qm
	shadow.mesh = q
	shadow.top_level = true
	add_child(shadow)
	# 사슬
	chain_mm = MultiMesh.new()
	chain_mm.transform_format = MultiMesh.TRANSFORM_3D
	var tor := TorusMesh.new()
	tor.inner_radius = 0.12
	tor.outer_radius = 0.3
	tor.rings = 12
	tor.ring_segments = 6
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.2, 0.18, 0.17)
	cm.metallic = 0.8
	cm.roughness = 0.5
	tor.material = cm
	chain_mm.mesh = tor
	chain_mm.instance_count = LINKS
	var cmi := MultiMeshInstance3D.new()
	cmi.multimesh = chain_mm
	cmi.custom_aabb = AABB(Vector3(-200, -5, -200), Vector3(400, 60, 400))
	cmi.top_level = true
	add_child(cmi)
	chain.resize(LINKS + 1)
	chain_prev.resize(LINKS + 1)
	_apply_radius()

func reset_chain() -> void:
	for i in LINKS + 1:
		chain[i] = global_position + Vector3(0, radius, i * 0.5)
		chain_prev[i] = chain[i]

func _apply_radius() -> void:
	vis.scale = Vector3.ONE * radius
	if shadow:
		shadow.scale = Vector3.ONE * radius * 3.2

func max_speed() -> float:
	return T.MAX_SPEED[stage]

func step(dt: float) -> void:
	var dir := Vector3(input.x, 0, input.y)
	if dir.length() > 1.0:
		dir = dir.normalized()
	vel += dir * T.ACCEL * dt
	var fr := T.FRICTION if dir.length() > 0.1 else T.FRICTION * 2.2
	vel *= maxf(0.0, 1.0 - fr * dt)
	var ms := max_speed()
	if vel.length() > ms * 1.5:
		vel = vel.normalized() * ms * 1.5   # 범퍼 가속은 최고 속도를 잠깐 넘을 수 있음
	elif vel.length() > ms and dir.length() > 0.1:
		vel = vel.normalized() * lerpf(vel.length(), ms, 4.0 * dt)
	vel.y = 0.0
	position += vel * dt
	var lim := T.GRID * T.LOT * 0.5 + 6.0
	position.x = clampf(position.x, -lim, lim)
	position.z = clampf(position.z, -lim, lim)
	# 굴러가는 회전
	var sp := vel.length()
	if sp > 0.05:
		var axis := Vector3.UP.cross(vel / sp)
		vis.rotate(axis, sp * dt / radius)
	# 최고 속도의 60%를 넘겨야 달아오르기 시작하고, 흰 쇠는 최고 속도를 몇 초 유지해야 나옴
	var target_heat := clampf((sp - ms * 0.6) / (ms * 0.4), 0.0, 1.0)
	heat = lerpf(heat, target_heat, (0.35 if target_heat > heat else 1.2) * dt)
	mat.set_shader_parameter("heat", heat)
	# 분노 일격: 솟았다가 떨어짐
	var y := radius
	if airborne > 0.0:
		airborne -= dt
		var t := 1.0 - airborne / 0.55
		y += sin(clampf(t, 0.0, 1.0) * PI) * radius * 3.0
	position.y = y
	shadow.global_position = Vector3(position.x, 0.1, position.z)
	_step_chain(dt)

func _step_chain(dt: float) -> void:
	var seg := 0.55 * radius / T.RADIUS[0]
	var anchor := global_position + Vector3(0, radius * 0.9, 0)
	chain[0] = anchor
	chain_prev[0] = anchor
	for i in range(1, LINKS + 1):
		var p := chain[i]
		var v := (p - chain_prev[i]) * 0.97
		chain_prev[i] = p
		p += v + Vector3(0, -30.0, 0) * dt * dt
		if p.y < 0.15:
			p.y = 0.15
		chain[i] = p
	for it in 4:
		for i in LINKS:
			var a := chain[i]
			var b := chain[i + 1]
			var d := b - a
			var l := d.length()
			if l < 0.0001:
				continue
			var diff := (l - seg) / l
			if i == 0:
				chain[i + 1] = b - d * diff
			else:
				chain[i] = a + d * diff * 0.5
				chain[i + 1] = b - d * diff * 0.5
		# 쇠공 몸을 뚫지 않게
		for i in range(1, LINKS + 1):
			var off := chain[i] - global_position
			if off.length() < radius:
				chain[i] = global_position + off.normalized() * radius
	var s := radius / T.RADIUS[0]
	for i in LINKS:
		var a := chain[i]
		var b := chain[i + 1]
		var z := b - a
		if z.length() < 0.001:
			z = Vector3.FORWARD
		z = z.normalized()
		var side := z.cross(Vector3.UP)
		if side.length() < 0.01:
			side = Vector3.RIGHT
		side = side.normalized()
		var up := side.cross(z)
		if i % 2 == 1:
			var tmp := side
			side = up
			up = -tmp
		chain_mm.set_instance_transform(i, Transform3D(Basis(side * s, up * s, z * s * 1.6), (a + b) * 0.5))

func chain_tip() -> Vector3:
	return chain[LINKS]

func grow_to(new_stage: int) -> void:
	stage = new_stage
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_method(_set_radius, radius, T.RADIUS[stage], 0.6)

func _set_radius(r: float) -> void:
	radius = r
	_apply_radius()
