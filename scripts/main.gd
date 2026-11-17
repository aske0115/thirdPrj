# 진입점: 장면을 코드로 짓고 판 흐름·입력·카메라·손맛(히트스톱·흔들림·진동)·봇·화면 저장을 맡는다.
# 실행 인자(-- 뒤): --bot --seed=N --shot=경로 --shot-at=초 --quit-at=초 --lang=en
class_name Main
extends Node3D

static var lang := "ko"

static func L(ko: String, en: String) -> String:
	return ko if lang == "ko" else en

enum State { READY, PLAY, END }

var state := State.READY
var args := {}
var city: City
var fx: Fx
var ball: Ball
var cops: Cops
var hud: Hud
var cam: Camera3D
var time_left := T.RUN_SECONDS
var hp := T.HP
var rage := 0.0
var shake := 0.0
var hitstop_on := false
var last_destroyed := 0
var transformer: Node3D
var transformer_alive := true
var bot := false
var shot_done := false
var stats_t := 0.0
var elapsed := 0.0
var fps_min := 999.0
var cars_wrecked := 0

var joy_index := -1   # 조이스틱을 잡은 손가락

func _ready() -> void:
	Engine.time_scale = 1.0  # 히트스톱 중에 다시 하기를 눌러도 정상 속도로
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	lang = args.get("lang", "ko" if OS.get_locale_language() == "ko" else "en")
	bot = args.has("bot")
	var seed := int(args.get("seed", "7"))
	_build_world()
	city = City.new()
	add_child(city)
	city.build(seed)
	fx = Fx.new()
	add_child(fx)
	city.block_destroyed.connect(_on_blocks)
	city.collapse_started.connect(_on_collapse_start)
	city.collapse_finished.connect(_on_collapse_end)
	city.lights_went_out.connect(func(b): fx.burst("glass", b.center() + Vector3.UP * b.nf * T.BLOCK * 0.6, 1.4))
	ball = Ball.new()
	add_child(ball)
	ball.position = Vector3(0, ball.radius, 0)
	ball.reset_chain()
	cops = Cops.new()
	add_child(cops)
	cops.setup(seed)
	cops.car_wrecked.connect(_on_car_wrecked)
	cops.shot.connect(_on_shot)
	_build_transformer()
	cam = Camera3D.new()
	cam.fov = 55.0
	cam.far = 400.0
	add_child(cam)
	hud = Hud.new()
	add_child(hud)
	hud.retry_pressed.connect(func(): get_tree().reload_current_scene())
	hud.show_overlay(L("한밤의 쇠공\n\n화면을 끌어 쇠공을 굴리세요\n건물에 세게 박을수록 크게 부서져요\n\n누르면 시작", "Midnight Wrecker\n\nDrag to roll the wrecking ball\nHit harder, break more\n\nTap to start"), false)
	_update_cam(1.0)
	if bot:
		_start()

func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color("1b1640")
	psm.sky_horizon_color = Color("8a5a86")
	psm.ground_horizon_color = Color("3b2c55")
	psm.ground_bottom_color = Color("0b0916")
	psm.sun_angle_max = 0.0
	sky.sky_material = psm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("4a4380")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.fog_enabled = true
	env.fog_light_color = Color("3a2e62")
	env.fog_density = 0.006
	env.fog_sky_affect = 0.4
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.light_color = Color("9aa6ff")
	moon.light_energy = 0.45
	moon.rotation_degrees = Vector3(-55, 35, 0)
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 70.0
	add_child(moon)
	# 바닥(아스팔트)과 구획 보도
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(320, 320)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color("17141f")
	gm.roughness = 0.85
	ground.material_override = gm
	add_child(ground)
	var pad_mm := MultiMesh.new()
	pad_mm.transform_format = MultiMesh.TRANSFORM_3D
	var pb := BoxMesh.new()
	pb.size = Vector3(T.LOT - 7.0, 0.25, T.LOT - 7.0)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color("2a2633")
	pmat.roughness = 0.95
	pb.material = pmat
	pad_mm.mesh = pb
	pad_mm.instance_count = T.GRID * T.GRID
	var half := (T.GRID - 1) * 0.5
	for gx in T.GRID:
		for gz in T.GRID:
			pad_mm.set_instance_transform(gx * T.GRID + gz, Transform3D(Basis(), Vector3((gx - half) * T.LOT, 0.12, (gz - half) * T.LOT)))
	var pads := MultiMeshInstance3D.new()
	pads.multimesh = pad_mm
	add_child(pads)
	# 차선(희미한 노란 점선)
	var dash_mm := MultiMesh.new()
	dash_mm.transform_format = MultiMesh.TRANSFORM_3D
	var db := BoxMesh.new()
	db.size = Vector3(0.25, 0.04, 1.6)
	var dmat := StandardMaterial3D.new()
	dmat.albedo_color = Color(0.9, 0.75, 0.3)
	dmat.emission_enabled = true
	dmat.emission = Color(0.5, 0.38, 0.1)
	db.material = dmat
	dash_mm.mesh = db
	var dashes: Array[Transform3D] = []
	var span := T.GRID * T.LOT * 0.5 + 10.0
	for k in T.GRID - 1:
		var c := (k - half + 0.5) * T.LOT
		var t := -span
		while t < span:
			dashes.append(Transform3D(Basis(), Vector3(c, 0.03, t)))
			dashes.append(Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(t, 0.03, c)))
			t += 4.0
	dash_mm.instance_count = dashes.size()
	for i in dashes.size():
		dash_mm.set_instance_transform(i, dashes[i])
	var dmi := MultiMeshInstance3D.new()
	dmi.multimesh = dash_mm
	add_child(dmi)
	# 가로등 + 바닥 불빛 웅덩이(빛 대신 가산 사각형)
	var lamp_scene: PackedScene = load("res://assets/city/light-square.glb")
	var pool_mm := MultiMesh.new()
	pool_mm.transform_format = MultiMesh.TRANSFORM_3D
	var q := QuadMesh.new()
	q.size = Vector2(12, 12)
	q.orientation = PlaneMesh.FACE_Y
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.set_color(1, Color(1, 1, 1, 0))
	var gtex := GradientTexture2D.new()
	gtex.gradient = grad
	gtex.fill = GradientTexture2D.FILL_RADIAL
	gtex.fill_from = Vector2(0.5, 0.5)
	gtex.fill_to = Vector2(1.0, 0.5)
	qm.albedo_texture = gtex
	qm.albedo_color = Color(1.0, 0.5, 0.18, 0.35)
	q.material = qm
	pool_mm.mesh = q
	var spots: Array[Vector3] = []
	for ix in T.GRID - 1:
		for iz in T.GRID - 1:
			spots.append(Vector3((ix - half + 0.5) * T.LOT + 4.5, 0, (iz - half + 0.5) * T.LOT + 4.5))
	pool_mm.instance_count = spots.size()
	for i in spots.size():
		var lamp := lamp_scene.instantiate() as Node3D
		lamp.scale = Vector3.ONE * 9.0
		lamp.position = spots[i]
		add_child(lamp)
		pool_mm.set_instance_transform(i, Transform3D(Basis(), spots[i] + Vector3(-1.5, 0.06, 0)))
	var pmi := MultiMeshInstance3D.new()
	pmi.multimesh = pool_mm
	add_child(pmi)

# 정전 연쇄 PoC(GDD 제안): 변압기를 부수면 가까운 건물부터 차례로 창이 꺼진다.
func _build_transformer() -> void:
	transformer = Node3D.new()
	var half := (T.GRID - 1) * 0.5
	transformer.position = Vector3((1 - half + 0.5) * T.LOT, 0, (2 - half + 0.5) * T.LOT - 6.0)
	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.4, 2.6, 1.6)
	box.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.25, 0.3, 0.28)
	m.emission_enabled = true
	m.emission = Color(0.2, 0.7, 0.4)
	m.emission_energy_multiplier = 0.4
	box.material_override = m
	box.position.y = 1.3
	transformer.add_child(box)
	var l := OmniLight3D.new()
	l.light_color = Color(0.4, 1.0, 0.6)
	l.light_energy = 1.2
	l.omni_range = 6.0
	l.position.y = 3.0
	transformer.add_child(l)
	add_child(transformer)

func _start() -> void:
	state = State.PLAY
	hud.hide_overlay()

func _end(reason: String) -> void:
	if state == State.END:
		return
	state = State.END
	ball.input = Vector2.ZERO
	var f := city.fraction()
	var stars := 0
	for s in T.STAR_FRACTIONS:
		if f >= s:
			stars += 1
	var lit := 0
	for b in city.buildings:
		if b.lit and b.alive > 0:
			lit += 1
	var title: String = {"win": L("목표 달성! 도시 박살", "Target wrecked!"), "time": L("시간 종료", "Time's up"), "hp": L("쇠공이 멈췄어요", "The wrecker stopped")}[reason]
	var star_txt := "★".repeat(stars) + "☆".repeat(3 - stars)
	hud.show_overlay("%s\n\n%s\n%s %d%%\n%s %d" % [title, star_txt, L("파괴율", "Destroyed"), int(f * 100), L("불 켜진 건물 남음", "Buildings still lit"), lit], true)
	print("RESULT reason=%s destroyed=%.3f stars=%d time=%.1f hp=%.0f stage=%d cars=%d fps_min=%.0f" % [reason, f, stars, T.RUN_SECONDS - time_left, hp, ball.stage, cars_wrecked, fps_min])

# 손가락을 index로 구분: 첫 손가락은 조이스틱, 쾅! 버튼 자리는 어느 손가락이든 바로 일격.
func _input(e: InputEvent) -> void:
	if bot:
		return
	if e is InputEventScreenTouch:
		if e.pressed:
			if state == State.END:
				return  # 결과 창 버튼은 GUI가 처리
			if state == State.PLAY and hud.rage_btn.get_global_rect().has_point(e.position):
				_slam()
				get_viewport().set_input_as_handled()
				return
			if state == State.READY:
				_start()
			if joy_index == -1:
				joy_index = e.index
				hud.joy_on = true
				hud.joy_anchor = e.position
				hud.joy_vec = Vector2.ZERO
		elif e.index == joy_index:
			joy_index = -1
			hud.joy_on = false
			hud.joy_vec = Vector2.ZERO
		hud.joy.queue_redraw()
	elif e is InputEventScreenDrag and e.index == joy_index:
		hud.joy_vec = ((e.position - hud.joy_anchor) / 110.0).limit_length(1.0)
		hud.joy.queue_redraw()

func _process(delta: float) -> void:
	var real_dt := delta / maxf(Engine.time_scale, 0.001)
	elapsed += real_dt
	fps_min = minf(fps_min, Engine.get_frames_per_second()) if elapsed > 3.0 else fps_min
	if state == State.PLAY:
		time_left -= delta
		if bot:
			_bot_drive()
		ball.input = hud.joy_vec
		if time_left <= 0.0:
			time_left = 0.0
			_end("time")
	if state == State.END:
		ball.input = Vector2.ZERO
		ball.vel *= maxf(0.0, 1.0 - 6.0 * delta)  # 결과 창 뒤에는 멈춰 세움
	ball.step(delta)
	if state == State.PLAY:
		_collide()
	cops.update(delta, ball, state == State.PLAY)
	_update_cam(real_dt)
	if state == State.END:
		_debug_out(real_dt)
		return  # 결과 창 수치와 위쪽 표시가 달라지지 않게
	# HUD
	hud.time_lbl.text = "%d:%02d" % [int(time_left) / 60, int(time_left) % 60]
	var f := city.fraction()
	hud.pct_lbl.text = "%d%%" % int(f * 100)
	hud.pct_bar.value = f / T.WIN_FRACTION
	hud.hp_bar.value = hp / T.HP
	hud.set_rage(rage)
	# 성장·승리
	if state == State.PLAY:
		for s in range(T.STAGE_AT.size() - 1, ball.stage, -1):
			if f >= T.STAGE_AT[s]:
				ball.grow_to(s)
				hud.say(L("쇠공이 커졌다! %d단계" % (s + 1), "Bigger wrecker! Size %d" % (s + 1)))
				fx.play("rumble", 0.5, 4.0)
				break
		if f >= T.WIN_FRACTION:
			_end("win")
	_debug_out(real_dt)

func _collide() -> void:
	if ball.airborne > 0.0:
		return
	var c := ball.global_position
	var push := city.contact_push(c, ball.radius)
	if push != Vector3.ZERO:
		var n := Vector3(push.x, 0, push.z).normalized()
		var vn := -ball.vel.dot(n)
		if vn > T.IMPACT_MIN_SPEED:
			var k := clampf((vn - T.IMPACT_MIN_SPEED) / (ball.max_speed() - T.IMPACT_MIN_SPEED), 0.0, 1.0)
			var r := ball.radius * T.DAMAGE_MUL * (0.9 + 0.7 * k + 0.3 * ball.heat)
			var removed := city.damage_sphere(c - n * ball.radius * 0.4, r, ball.vel)
			if removed > 0:
				ball.vel *= T.IMPACT_SLOW + 0.25 * ball.heat
				_impact(removed, vn, c - n * ball.radius)
			else:
				ball.vel += n * vn * (1.0 + T.BOUNCE)
		elif vn > 0.0:
			ball.vel += n * vn * (1.0 + T.BOUNCE)
		ball.position += Vector3(push.x, 0, push.z)
	# 변압기
	if transformer_alive and c.distance_to(transformer.position + Vector3.UP * ball.radius) < ball.radius + 1.6:
		_blackout_chain()

func _impact(removed: int, speed: float, at: Vector3) -> void:
	var power := clampf(removed / 12.0, 0.15, 1.5)
	shake = maxf(shake, 0.25 + power * 0.9 * (1.0 + ball.stage * 0.4))
	fx.burst("dust", at, 0.8 + power * 0.6)
	fx.burst("sparks", at, 1.0)
	fx.play("thud", 1.1 - power * 0.3, -2.0 + power * 4.0)
	fx.play("glass", 1.0, -6.0)
	if removed >= 5:
		hitstop(0.04 + 0.03 * minf(power, 1.0))
	if removed >= 8 and not bot:
		Input.vibrate_handheld(40, 0.6)

func _on_blocks(count: int, pos: Vector3) -> void:
	var d := city.destroyed - last_destroyed
	last_destroyed = city.destroyed
	rage = minf(1.0, rage + d * T.RAGE_PER_BLOCK)
	if count >= 6:
		fx.burst("dust", pos, 1.2)

func _on_collapse_start(b: City.Bld) -> void:
	shake = maxf(shake, 1.2 + ball.stage * 0.4)
	hitstop(0.08)
	fx.play("rumble", 0.45, 6.0)
	fx.play("thud", 0.5, 4.0)
	if not bot:
		Input.vibrate_handheld(90, 1.0)

func _on_collapse_end(b: City.Bld) -> void:
	var c := b.center()
	fx.burst("dust", c + Vector3.UP * 2.0, 2.2)
	fx.fire_at(c, clampf((b.nx + b.nz) / 6.0, 0.6, 1.3))
	city.blackout_near(c, 26.0)
	hud.say(L("쾅! 건물 붕괴", "CRASH! Building down"))

func _blackout_chain() -> void:
	transformer_alive = false
	transformer.visible = false
	fx.burst("sparks", transformer.position + Vector3.UP * 2.0, 3.0)
	fx.burst("boom", transformer.position + Vector3.UP, 1.5)
	fx.play("metal", 0.7, 6.0)
	shake = maxf(shake, 1.0)
	hitstop(0.1)
	rage = minf(1.0, rage + 0.3)
	hud.say(L("변압기 폭발! 정전!", "Transformer blown! Blackout!"))
	var order := city.buildings.duplicate()
	var p := transformer.position
	order.sort_custom(func(a, b): return a.center().distance_to(p) < b.center().distance_to(p))
	for b in order:
		if b.lit:
			city.lights_out(b)
			fx.play("glass", 1.4, -10.0)
			await get_tree().create_timer(0.06).timeout

func _on_car_wrecked(pos: Vector3, cop: bool) -> void:
	cars_wrecked += 1
	fx.burst("boom", pos + Vector3.UP, 1.0)
	fx.burst("sparks", pos + Vector3.UP, 1.2)
	fx.play("metal", 1.0, 2.0)
	for k in 6:
		city.spawn_debris(pos + Vector3.UP, Vector3(randf_range(-6, 6), randf_range(5, 10), randf_range(-6, 6)), randf_range(0.4, 0.9), Color(0.15, 0.17, 0.3) if cop else Color(0.5, 0.45, 0.4))
	rage = minf(1.0, rage + (T.RAGE_PER_COP if cop else 0.02))
	if cop:
		ball.vel *= 1.25  # 범퍼처럼 튕겨 가속
		shake = maxf(shake, 0.5)

func _on_shot(from: Vector3, to: Vector3) -> void:
	if state != State.PLAY:
		return
	hp -= T.COP_DAMAGE
	hud.hurt()
	if hp <= 0.0:
		hp = 0.0
		_end("hp")

func _slam() -> void:
	if rage < 1.0 or state != State.PLAY or ball.airborne > 0.0:
		return
	rage = 0.0
	ball.airborne = 0.55
	await get_tree().create_timer(0.55).timeout
	if state != State.PLAY:
		return
	var c := Vector3(ball.global_position.x, ball.radius, ball.global_position.z)
	var r := ball.radius * T.SLAM_RADIUS
	city.damage_sphere(c, r, Vector3.ZERO)
	cops.wreck_within(c, r * 1.3)
	shake = 2.0
	hitstop(0.12)
	fx.burst("dust", c, 3.0)
	fx.burst("boom", c, 2.0)
	fx.play("rumble", 0.4, 8.0)
	if not bot:
		Input.vibrate_handheld(120, 1.0)

func hitstop(d: float) -> void:
	if hitstop_on:
		return
	hitstop_on = true
	Engine.time_scale = 0.05
	await get_tree().create_timer(d, true, false, true).timeout
	Engine.time_scale = 1.0
	hitstop_on = false

func _update_cam(dt: float) -> void:
	var dist: float = T.CAM_DIST[ball.stage]
	var target := Vector3(ball.global_position.x, 0, ball.global_position.z)
	var want := target + Vector3(0, 34.0, 13.0) * dist
	cam.global_position = cam.global_position.lerp(want, clampf(dt * 4.0, 0.0, 1.0)) if elapsed > 0.1 else want
	shake = maxf(0.0, shake - dt * 3.0)
	var off := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake * shake * 0.6
	cam.look_at(target + Vector3(0, 2, -2), Vector3.UP)
	cam.global_position += off

func _bot_drive() -> void:
	# 가장 가까운 건물(경찰차가 아주 가까우면 경찰차)로 달려가 박는다. 가끔 비켜 다시 달린다.
	var bp := ball.global_position
	var target := Vector3.ZERO
	var b := city.nearest_building(bp)
	if b:
		target = b.center()
	for c in cops.cars:
		if c.cop and c.node.global_position.distance_to(bp) < 10.0:
			target = c.node.global_position
	var to := target - bp
	to.y = 0
	var dir := Vector2(to.x, to.z).normalized()
	if ball.vel.length() < 2.0 and to.length() < ball.radius + 8.0:
		dir = -dir  # 붙어서 멈췄으면 물러났다가 다시 달림
	hud.joy_vec = dir.rotated(randf_range(-0.15, 0.15))
	if rage >= 1.0:
		_slam()

func _debug_out(dt: float) -> void:
	if args.has("shot") and not shot_done and elapsed >= float(args.get("shot-at", "5")):
		shot_done = true
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args["shot"])
		print("SHOT ", args["shot"])
	if bot:
		stats_t += dt
		if stats_t >= 5.0:
			stats_t = 0.0
			print("STATS t=%.0f fps=%d destroyed=%.3f debris=%d cops=%d hp=%.0f stage=%d draws=%d" % [elapsed, Engine.get_frames_per_second(), city.fraction(), city.dactive, cops.cop_count(), hp, ball.stage, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
	if args.has("quit-at") and elapsed >= float(args["quit-at"]):
		if state != State.END:
			_end("time")
		get_tree().quit()
