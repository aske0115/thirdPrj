# 3D 화면 층(디자인 담당 파일): 판정·이동은 2D 로직 그대로 두고, 그 위치를 3D 장면에 옮겨 그린다.
# 2D 점 → 카메라 광선이 바닥 평면(y=0)과 만나는 점. 그래서 3D 모델이 2D 판정 자리와 화면에서 정확히 겹친다.
# 3D는 SubViewport에서 그려 2D 맨 아래에 깔고, 탄·보석·숫자 같은 2D 연출은 그 위에 2D 빛 번짐으로 얹는다.
class_name View3D
extends Node2D

var main: Main
var vp: SubViewport
var sprite: Sprite2D
var world: Node3D
var cam: Camera3D
var vis := Vector2(720, 1280)
var metal: StandardMaterial3D
var dark_metal: StandardMaterial3D
var hull: Node3D
var hull_w := 0.0
var part_nodes := {}   # Boss.Part → {node, w, lift, mat}
var core_ring: Node3D
var ship: Node3D
var ship_w := 0.0
var ship_prev_x := 360.0
var bank := 0.0
var moving: Array[Dictionary] = []

func setup(m: Main) -> void:
	main = m
	vp = SubViewport.new()
	vp.msaa_3d = Viewport.MSAA_2X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	sprite = Sprite2D.new()
	sprite.centered = false
	sprite.texture = vp.get_texture()
	add_child(sprite)
	_fit_size()
	get_window().size_changed.connect(_fit_size)  # 폴더블 펼침·창 크기 변경 때 판정과 그림이 같이 따라가게
	world = Node3D.new()
	vp.add_child(world)
	metal = _mat(Color(0.42, 0.44, 0.5), 0.9, 0.32)
	dark_metal = _mat(Color(0.13, 0.14, 0.18), 0.85, 0.4)
	_env()
	_backdrop()
	_boss()
	_player()

# 3D 해상도는 창 픽셀 크기를 따르되 높이 1600을 넘지 않게(고해상도 폰에서 빛 번짐·MSAA 비용 상한)
func _fit_size() -> void:
	vis = get_viewport().get_visible_rect().size
	var ws := Vector2(get_window().size)
	if get_window().content_scale_mode == Window.CONTENT_SCALE_MODE_VIEWPORT:
		ws = vis * 1.5  # 촬영 모드: 창이 아주 작아도 3D는 선명하게
	vp.size = Vector2i(ws * minf(1.0, 1600.0 / ws.y))
	sprite.scale = vis / Vector2(vp.size)

func _mat(c: Color, metallic: float, rough: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metallic
	m.roughness = rough
	return m

# 2D 화면 좌표 → 3D. lift만큼 카메라 쪽으로 당겨도 화면 위치는 그대로(같은 광선 위).
func to3d(p: Vector2, lift := 0.0) -> Vector3:
	var s := p * Vector2(vp.size) / vis
	var o := cam.project_ray_origin(s)
	var d := cam.project_ray_normal(s)
	return o + d * (-o.y / d.y - lift)

func units_per_px(p: Vector2) -> float:
	return to3d(p + Vector2(1, 0)).x - to3d(p).x

func _env() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.01, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.3, 0.5)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.1
	env.glow_enabled = true
	env.glow_intensity = 0.85
	env.glow_strength = 1.1
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.set_glow_level(0, 0.0)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(4, 0.8)
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.12
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.86, 0.72)
	key.light_energy = 2.1
	key.rotation_degrees = Vector3(-58, -32, 0)
	world.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.45, 0.65, 1.0)
	rim.light_energy = 1.4
	rim.rotation_degrees = Vector3(-25, 150, 0)
	world.add_child(rim)
	cam = Camera3D.new()
	cam.fov = 48.0
	cam.position = Vector3(0, 40, 21)
	world.add_child(cam)
	cam.look_at(Vector3(0, 0, 0.5), Vector3.UP)

func _plane(size: Vector2, y: float, shader: String, params := {}) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = size
	m.mesh = pm
	var sm := ShaderMaterial.new()
	sm.shader = load(shader)
	for k in params:
		sm.set_shader_parameter(k, params[k])
	m.material_override = sm
	m.position.y = y
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(m)
	return m

func _backdrop() -> void:
	var neb := _plane(Vector2(420, 420), -90.0, "res://shaders/nebula.gdshader")
	neb.position.z = 30.0
	var planet := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 7.0
	sp.height = 14.0
	planet.mesh = sp
	var pmat := ShaderMaterial.new()
	pmat.shader = load("res://shaders/planet.gdshader")
	planet.material_override = pmat
	planet.position = Vector3(48, -95, -75)  # 화면 오른쪽 위 구석, 전투 구역을 가리지 않게
	world.add_child(planet)
	# 구름은 두 장만(겹칠수록 반투명 그리기 비용이 커짐 — ART_REVIEW 검수 의견)
	_plane(Vector2(150, 220), -34.0, "res://shaders/clouds.gdshader", {tint = Vector3(0.22, 0.26, 0.55), density = 0.85, speed = 0.02, scale = 2.0})
	_plane(Vector2(120, 180), -12.0, "res://shaders/clouds.gdshader", {tint = Vector3(0.45, 0.32, 0.6), density = 0.5, speed = 0.06, scale = 3.0})

func _glow_quad(size: float, col: Color, parent: Node3D, streak := 0.0) -> MeshInstance3D:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/glow.gdshader")
	m.set_shader_parameter("billboard", streak <= 0.0)
	m.set_shader_parameter("streak", streak)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := size * 0.5
	var pts := [Vector3(-h, -h, 0), Vector3(h, -h, 0), Vector3(h, h, 0), Vector3(-h, h, 0)]
	var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_color(col)
		st.set_uv(uvs[i])
		st.add_vertex(pts[i])
	var q := MeshInstance3D.new()
	q.mesh = st.commit()
	q.material_override = m
	parent.add_child(q)
	return q

# 모델을 감싼 노드를 만들고, 모델의 가로폭·가운데를 재서 (가운데가 원점, 가로폭 1)로 맞춘다.
func _wrap(model: Node3D, rot_y: float) -> Node3D:
	var w := Node3D.new()
	world.add_child(w)
	var inner := Node3D.new()
	inner.rotation_degrees.y = rot_y
	w.add_child(inner)
	inner.add_child(model)
	var box := AABB()
	var first := true
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (inner.transform * model.transform * _rel(mi as MeshInstance3D, model)) * (mi as MeshInstance3D).get_aabb()
		box = b if first else box.merge(b)
		first = false
	inner.position = -box.get_center()
	var s := 1.0 / maxf(box.size.x, box.size.z)  # 가장 긴 변(가로나 앞뒤)을 1로
	inner.position *= s
	inner.scale = Vector3.ONE * s
	return w

func _rel(n: Node3D, root: Node3D) -> Transform3D:
	var tr := Transform3D.IDENTITY
	var c: Node = n
	while c != root and c != null:
		tr = (c as Node3D).transform * tr
		c = c.get_parent()
	return tr

func _recolor(model: Node3D, fn: Callable) -> void:
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var src: Material = (mi as MeshInstance3D).get_active_material(0)
		(mi as MeshInstance3D).material_override = fn.call(src)

func _boss() -> void:
	var b := main.boss
	var model: Node3D = load("res://assets/ships/Executioner.gltf").instantiate()
	var hc := b.hull_col
	_recolor(model, func(src: Material) -> Material:
		var m: StandardMaterial3D = (src as StandardMaterial3D).duplicate() if src is StandardMaterial3D else StandardMaterial3D.new()
		m.albedo_color = Color(0.72, 0.74, 0.82).lerp(hc * 3.0, 0.25)  # 보스 데이터의 선체 색을 살짝 섞음(주마다 다른 색)
		m.metallic = 0.75
		m.roughness = 0.38
		return m)
	hull = _wrap(model, 180.0)  # 머리가 화면 아래(플레이어 쪽)
	hull_w = 640.0
	for p in b.parts:
		var n: Node3D
		var w: float
		var lift := 2.5
		var mat: StandardMaterial3D
		match p.shape:
			"core":
				n = Node3D.new()
				world.add_child(n)
				var core := MeshInstance3D.new()
				var cs := SphereMesh.new()
				cs.radius = 0.5
				cs.height = 1.0
				core.mesh = cs
				mat = StandardMaterial3D.new()
				mat.albedo_color = Color(0.1, 0.02, 0.02)
				mat.emission_enabled = true
				mat.emission = Color(1.0, 0.25, 0.08)
				mat.emission_energy_multiplier = 3.5
				core.material_override = mat
				n.add_child(core)
				core_ring = MeshInstance3D.new()
				var tm := TorusMesh.new()
				tm.inner_radius = 0.66
				tm.outer_radius = 0.8
				(core_ring as MeshInstance3D).mesh = tm
				(core_ring as MeshInstance3D).material_override = metal
				core_ring.rotation_degrees.x = 70
				n.add_child(core_ring)
				var g := _glow_quad(3.2, Color(1.6, 0.4, 0.12), n)
				g.position.y = 0.3
				var cl := OmniLight3D.new()
				cl.light_color = Color(1.0, 0.4, 0.15)
				cl.light_energy = 3.0
				cl.omni_range = 4.0
				cl.position.y = 0.8
				n.add_child(cl)
				w = p.r * 1.6
				lift = 3.0
			"gun":
				var tur: Node3D = load("res://assets/kenney-space/turret_double.glb").instantiate()
				mat = dark_metal.duplicate()
				mat.emission_enabled = true  # 맞을 때 번쩍임용 — 미리 켜 둬야 첫 피격에 셰이더 재컴파일로 끊기지 않음
				mat.emission = Color(1.0, 0.5, 0.2)
				mat.emission_energy_multiplier = 0.0
				_recolor(tur, func(_s: Material) -> Material: return mat)
				n = _wrap(tur, 180.0)
				var g2 := _glow_quad(0.8, Color(1.8, 0.6, 0.2), n)
				g2.position = Vector3(0, 0.3, 0.6)
				w = p.r * 2.2
			"tile":
				n = _armor_plate()
				mat = n.get_meta("mat")
				mat.albedo_color = Color(0.68, 0.7, 0.78).lerp(hc * 3.0, 0.3)
				(n.get_meta("seam") as StandardMaterial3D).emission_energy_multiplier = 0.9
				w = p.r * 2.25
				lift = 1.6
			_:
				n = _armor_plate()
				mat = n.get_meta("mat")
				w = p.r * 2.1
		var d := {node = n, w = w, lift = lift, mat = mat}
		if p.group == "skin":
			# 벗겨지면 드러나는 속 기계: 깜빡이는 주황 불빛(판마다 쏜 자리대로 모양이 달라짐)
			var inner := Node3D.new()
			world.add_child(inner)
			var ember := _glow_quad(1.3, Color(0.75, 0.16, 0.06), inner)  # 적탄(밝은 점)과 헷갈리지 않게 심 없는 크고 어두운 잔불
			(ember.material_override as ShaderMaterial).set_shader_parameter("core_amt", 0.0)
			var pit := MeshInstance3D.new()
			var pm := CylinderMesh.new()
			pm.radial_segments = 6
			pm.top_radius = 0.42
			pm.bottom_radius = 0.42
			pm.height = 0.05
			pit.mesh = pm
			pit.material_override = dark_metal
			pit.position.y = -0.3
			inner.add_child(pit)
			inner.visible = false
			d.inner = inner
			d.ph = randf() * TAU
		part_nodes[p] = d
	# 엔진 불꽃(선체 뒤쪽)
	for s in [-0.12, 0.0, 0.12]:
		var e := _glow_quad(0.1, Color(0.5, 0.8, 1.8), hull)
		e.position = Vector3(s, 0.05, -0.48)

func _armor_plate() -> Node3D:
	var n := Node3D.new()
	world.add_child(n)
	var body := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.radial_segments = 6
	cy.rings = 1
	cy.top_radius = 0.37
	cy.bottom_radius = 0.5
	cy.height = 0.33
	body.mesh = cy
	var pm := _mat(Color(0.62, 0.64, 0.7), 0.9, 0.28)
	pm.emission_enabled = true
	pm.emission = Color(1, 0.9, 0.8)
	pm.emission_energy_multiplier = 0.0
	body.material_override = pm
	body.rotation_degrees.y = 30
	n.add_child(body)
	var seam := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.38
	tm.outer_radius = 0.4
	tm.ring_segments = 6
	tm.rings = 6
	seam.mesh = tm
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color.BLACK
	sm.emission_enabled = true
	sm.emission = Color(1.0, 0.38, 0.1)
	sm.emission_energy_multiplier = 1.8
	seam.material_override = sm
	seam.position.y = 0.17
	seam.rotation_degrees.y = 30
	n.add_child(seam)
	n.set_meta("mat", pm)
	n.set_meta("seam", sm)
	return n

func _player() -> void:
	var model: Node3D = load("res://assets/ships/Striker.gltf").instantiate()
	_recolor(model, func(src: Material) -> Material:
		var m: StandardMaterial3D = (src as StandardMaterial3D).duplicate() if src is StandardMaterial3D else StandardMaterial3D.new()
		m.metallic = 0.6
		m.roughness = 0.35
		m.rim_enabled = true
		m.rim = 0.8
		m.rim_tint = 0.3
		return m)
	ship = _wrap(model, 180.0)  # 기수가 보스 쪽
	ship_w = 96.0
	for s in [-0.2, 0.2]:
		var g := _glow_quad(0.5, Color(0.4, 1.0, 2.2), ship)
		g.position = Vector3(s, 0.0, 0.45)
		var fl := _glow_quad(0.28, Color(0.3, 0.8, 2.0), ship, 3.5)
		fl.rotation_degrees.x = -90
		fl.scale = Vector3(1, 3.2, 1)
		fl.position = Vector3(s, -0.02, 0.85)

func _place(n: Node3D, at: Vector2, px_w: float, lift: float) -> void:
	n.position = to3d(at, lift)
	n.scale = Vector3.ONE * px_w * units_per_px(at)

# 보스 부위가 부서질 때: 3D 섬광 빛(주변 금속을 비춤) + 금속 파편
func part_broken(p: Boss.Part, at: Vector2) -> void:
	var d: Dictionary = part_nodes.get(p, {})
	if d.is_empty():
		return
	(d.node as Node3D).visible = false
	var pos := to3d(at, d.lift)
	var u := units_per_px(at)
	if d.has("inner"):
		(d.inner as Node3D).visible = true
		for i in 4:
			_debris(pos, p.r * u * 0.6, p.r * u * 0.18, i)
		return
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.6, 0.25)
	flash.light_energy = 14.0
	flash.omni_range = 260.0 * u
	flash.position = pos + Vector3(0, 2, 0)
	world.add_child(flash)
	moving.append({node = flash, fade = 14.0, life = 0.5})
	for i in (16 if p.group != "armor" else 10):
		_debris(pos, p.r * u * 0.6, p.r * u * 0.18, i)

# 금속 파편 하나: 튀어 올라 돌며 떨어짐(1.4초 뒤 정리)
func _debris(pos: Vector3, size: float, speed: float, i: int) -> void:
	var c := MeshInstance3D.new()
	var bx := BoxMesh.new()
	bx.size = Vector3(randf_range(0.25, 0.7), randf_range(0.1, 0.25), randf_range(0.25, 0.6)) * size
	c.mesh = bx
	c.material_override = metal if i % 3 else dark_metal
	c.position = pos
	c.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	world.add_child(c)
	var dir := Vector3(randf_range(-1, 1), randf_range(0.3, 1.2), randf_range(-0.4, 1.0)).normalized()
	moving.append({node = c, vel = dir * randf_range(8, 18) * speed, spin = Vector3(randf_range(-9, 9), randf_range(-9, 9), 0), grav = speed * 30.0 / 1.8, life = 1.4})

func sync(dt: float) -> void:
	var b := main.boss
	hull.visible = b.visible
	_place(hull, b.global_position + Vector2(0, 20), hull_w, 0.0)
	for p in part_nodes:
		var d: Dictionary = part_nodes[p]
		var n: Node3D = d.node
		if not p.alive:
			if d.has("inner"):
				var inner: Node3D = d.inner
				inner.visible = b.visible
				_place(inner, b.part_world(p), p.r * 2.2 * (0.9 + 0.1 * sin(b.t * 5.0 + d.ph)), 1.2)
			continue
		n.visible = b.visible
		_place(n, b.part_world(p), d.w, d.lift)
		var m: StandardMaterial3D = d.mat
		if p.shape == "core":
			m.emission_energy_multiplier = 3.5 + p.flash * 6.0 + (2.0 if b.vulnerable(p) else 0.0) * (0.6 + 0.4 * sin(b.t * 8.0))
		else:
			m.emission_energy_multiplier = p.flash * 0.5
	core_ring.rotation.z += dt * 1.5
	# 내 기체: 좌우로 움직이면 그쪽으로 기울어짐
	var pp := main.player.position
	if dt > 0.004:  # 히트스톱 중(dt≈0)엔 속도가 튀므로 기울기를 건너뜀
		var vx := (pp.x - ship_prev_x) / dt
		bank = lerpf(bank, clampf(-vx / 1400.0, -0.6, 0.6), 1.0 - pow(0.001, dt))
	ship_prev_x = pp.x
	ship.visible = main.player.visible
	_place(ship, pp + Vector2(0, 6), ship_w, 1.0)
	ship.rotation.z = bank
	for i in range(moving.size() - 1, -1, -1):
		var m2: Dictionary = moving[i]
		var n2: Node3D = m2.node
		m2.life -= dt
		if m2.has("vel"):
			var v: Vector3 = m2.vel
			v.y -= m2.grav * dt
			m2.vel = v
			n2.position += v * dt
			n2.rotation += (m2.spin as Vector3) * dt
		if m2.has("fade"):
			(n2 as OmniLight3D).light_energy = m2.fade * maxf(m2.life, 0.0) / 0.5
		if m2.life <= 0.0:
			n2.queue_free()
			moving.remove_at(i)
