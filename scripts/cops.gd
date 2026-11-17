# 경찰차(쫓아와 쏨)와 주차된 차. 쇠공·사슬에 닿으면 터진다.
class_name Cops
extends Node3D

class Car:
	var node: Node3D
	var cop := false
	var shoot_t := 0.0
	var siren: Array[MeshInstance3D] = []
	var spot: SpotLight3D

signal car_wrecked(pos: Vector3, cop: bool)
signal shot(from: Vector3, to: Vector3)

var cars: Array[Car] = []
var rng := RandomNumberGenerator.new()
var police_scene: PackedScene
var parked_scenes: Array[PackedScene] = []
var tracers: Array[MeshInstance3D] = []
var tracer_i := 0
var spawn_t := T.COP_FIRST
var elapsed := 0.0
var spots := 0
var red_mat: StandardMaterial3D
var blue_mat: StandardMaterial3D

func setup(seed: int) -> void:
	rng.seed = seed + 7
	police_scene = load("res://assets/cars/police.glb")
	for n in ["sedan", "taxi", "van"]:
		parked_scenes.append(load("res://assets/cars/%s.glb" % n))
	red_mat = _glow(Color(1.0, 0.1, 0.1))
	blue_mat = _glow(Color(0.2, 0.4, 1.0))
	var tm := _glow(Color(1.0, 0.9, 0.6))
	for i in 8:
		var m := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.08, 0.08, 1.0)
		m.mesh = bm
		m.material_override = tm
		m.visible = false
		m.top_level = true
		add_child(m)
		tracers.append(m)
	# 주차된 차: 도로 가장자리
	var half := (T.GRID - 1) * 0.5
	for i in T.PARKED_CARS:
		var c := Car.new()
		c.node = parked_scenes[rng.randi() % parked_scenes.size()].instantiate()
		add_child(c.node)
		var along := rng.randf_range(-half * T.LOT, half * T.LOT)
		var lane := (rng.randi_range(0, T.GRID - 2) - half + 0.5) * T.LOT + (3.0 if rng.randf() < 0.5 else -3.0)
		if rng.randf() < 0.5:
			c.node.position = Vector3(along, 0, lane)
			c.node.rotation.y = PI * 0.5
		else:
			c.node.position = Vector3(lane, 0, along)
		c.node.scale = Vector3.ONE * 1.3
		cars.append(c)

func _glow(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	return m

func _spawn_cop(target: Vector3) -> void:
	var c := Car.new()
	c.cop = true
	c.node = police_scene.instantiate()
	c.node.scale = Vector3.ONE * 1.3
	add_child(c.node)
	var lim := T.GRID * T.LOT * 0.5 + 4.0
	var side := rng.randi() % 4
	var t := rng.randf_range(-lim, lim)
	var p: Vector3 = [Vector3(t, 0, -lim), Vector3(t, 0, lim), Vector3(-lim, 0, t), Vector3(lim, 0, t)][side]
	c.node.position = p
	c.shoot_t = rng.randf_range(0.5, T.COP_SHOOT_EVERY)
	for k in 2:
		var s := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.35, 0.18, 0.3)
		s.mesh = sm
		s.position = Vector3(-0.3 + k * 0.6, 1.25, 0)
		s.material_override = red_mat if k == 0 else blue_mat
		c.node.add_child(s)
		c.siren.append(s)
	if spots < 3:
		spots += 1
		var sp := SpotLight3D.new()
		sp.light_color = Color(0.85, 0.9, 1.0)
		sp.light_energy = 6.0
		sp.spot_range = 30.0
		sp.spot_angle = 14.0
		sp.top_level = true
		add_child(sp)
		c.spot = sp
	cars.append(c)

func cop_count() -> int:
	var n := 0
	for c in cars:
		if c.cop:
			n += 1
	return n

func update(dt: float, ball: Ball, playing: bool) -> void:
	if not playing:
		return  # 시작 전·결과 창 뒤에는 멈춤(등장 간격에 대기 시간이 섞이지 않게)
	elapsed += dt
	if playing:
		spawn_t -= dt
		if spawn_t <= 0.0 and cop_count() < T.COP_MAX:
			_spawn_cop(ball.global_position)
			spawn_t = lerpf(T.COP_EVERY_START, T.COP_EVERY_END, clampf(elapsed / T.RUN_SECONDS, 0.0, 1.0))
	var bp := ball.global_position
	var tip := ball.chain_tip()
	var speed := ball.vel.length()
	var blink := int(elapsed * 6.0) % 2 == 0
	for i in range(cars.size() - 1, -1, -1):
		var c := cars[i]
		var p := c.node.global_position
		var flat := Vector3(bp.x, 0, bp.z)
		var d := p.distance_to(flat)
		# 쇠공에 닿거나, 빨리 휘두른 사슬 끝에 닿으면 터짐
		var hit := d < ball.radius + 1.6 and ball.airborne <= 0.0
		if not hit and speed > 6.0 and p.distance_to(Vector3(tip.x, 0, tip.z)) < 1.8:
			hit = true
		if hit:
			_wreck(i)
			continue
		if not c.cop:
			continue
		for k in c.siren.size():
			c.siren[k].visible = blink == (k == 0)
		if playing:
			var to := flat - p
			if d > T.COP_RANGE * 0.6:
				c.node.global_position += to.normalized() * T.COP_SPEED * dt
			if to.length() > 0.1:
				c.node.look_at(flat, Vector3.UP)
				c.node.rotate_object_local(Vector3.UP, PI)  # Kenney 차는 +Z가 앞
			c.shoot_t -= dt
			if c.shoot_t <= 0.0 and d < T.COP_RANGE:
				c.shoot_t = T.COP_SHOOT_EVERY * rng.randf_range(0.8, 1.2)
				_tracer(p + Vector3.UP * 1.2, bp)
				shot.emit(p, bp)
		if c.spot:
			c.spot.global_position = p + Vector3.UP * 5.0
			c.spot.look_at(bp, Vector3.UP)

func _tracer(a: Vector3, b: Vector3) -> void:
	var m := tracers[tracer_i]
	tracer_i = (tracer_i + 1) % tracers.size()
	var mid := (a + b) * 0.5
	m.global_transform = Transform3D(Basis(), mid).looking_at(b, Vector3.UP)
	m.scale = Vector3(1, 1, a.distance_to(b))
	m.visible = true
	get_tree().create_timer(0.06).timeout.connect(func(): m.visible = false)

func _wreck(i: int) -> void:
	var c := cars[i]
	var p := c.node.global_position
	if c.spot:
		c.spot.queue_free()
		spots -= 1
	c.node.queue_free()
	cars.remove_at(i)
	car_wrecked.emit(p, c.cop)

# 분노 일격 범위의 차를 모두 터뜨림
func wreck_within(p: Vector3, r: float) -> void:
	for i in range(cars.size() - 1, -1, -1):
		if cars[i].node.global_position.distance_to(Vector3(p.x, 0, p.z)) < r:
			_wreck(i)
