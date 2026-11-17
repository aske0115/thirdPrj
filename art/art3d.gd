# 그림 시안 ①: 3D CC0 모델 + 조명·재질·배경 깊이·연출·UI 마감.
# 실행: godot --path . res://art/art3d.tscn -- --out=/절대경로/파일.png --at=0.42
# 1170×2532(아이폰 세로) 화면 밖 렌더 → PNG 저장 후 종료.
extends Node

const W := 1170
const H := 2532
var vp: SubViewport
var world: Node3D
var t := 0.0
var out := ""
var at := 0.42
var mode := "break"
var saved := false
var exploded := false
var plate_hit: Node3D
var moving: Array[Dictionary] = []
var glow_mat_enemy: ShaderMaterial
var font_kr: FontFile
var font_en: FontFile
var metal: StandardMaterial3D
var dark_metal: StandardMaterial3D

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		if kv[0] == "out": out = kv[1]
		if kv[0] == "at": at = float(kv[1])
		if kv[0] == "mode": mode = kv[1]
	font_kr = load("res://assets/fonts/BlackHanSans-Regular.ttf")
	font_en = load("res://assets/fonts/Orbitron.ttf")
	vp = SubViewport.new()
	vp.size = Vector2i(W, H)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	vp.use_hdr_2d = true
	add_child(vp)
	var tr := TextureRect.new()
	tr.texture = vp.get_texture()
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(tr)
	world = Node3D.new()
	vp.add_child(world)
	metal = StandardMaterial3D.new()
	metal.albedo_color = Color(0.42, 0.44, 0.5)
	metal.metallic = 0.9
	metal.roughness = 0.32
	dark_metal = StandardMaterial3D.new()
	dark_metal.albedo_color = Color(0.13, 0.14, 0.18)
	dark_metal.metallic = 0.85
	dark_metal.roughness = 0.4
	_env()
	_backdrop()
	_boss()
	_player()
	_bullets()
	_ui()

func _env() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.01, 0.03)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.3, 0.5)
	env.ambient_light_energy = 0.35
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
	env.set_glow_level(5, 0.5)
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
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 80.0
	world.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.45, 0.65, 1.0)
	rim.light_energy = 1.4
	rim.rotation_degrees = Vector3(-25, 150, 0)
	world.add_child(rim)
	var cam := Camera3D.new()
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
	sp.radius = 11.0
	sp.height = 22.0
	sp.radial_segments = 64
	sp.rings = 32
	planet.mesh = sp
	var pmat := ShaderMaterial.new()
	pmat.shader = load("res://shaders/planet.gdshader")
	planet.material_override = pmat
	planet.position = Vector3(30, -95, -30)
	planet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(planet)
	_plane(Vector2(150, 220), -34.0, "res://shaders/clouds.gdshader", {tint = Vector3(0.22, 0.26, 0.55), density = 0.85, speed = 0.02, scale = 2.0})
	_plane(Vector2(120, 180), -12.0, "res://shaders/clouds.gdshader", {tint = Vector3(0.45, 0.32, 0.6), density = 0.5, speed = 0.06, scale = 3.0})
	# 아주 가까운 속도선 구름 조각(위로 빠르게 지나감)
	_plane(Vector2(60, 90), 6.0, "res://shaders/clouds.gdshader", {tint = Vector3(0.55, 0.5, 0.7), density = 0.12, speed = 0.35, scale = 5.0})

func _glow_mat(billboard: bool, streak := 0.0, intensity := 1.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/glow.gdshader")
	m.set_shader_parameter("billboard", billboard)
	m.set_shader_parameter("streak", streak)
	m.set_shader_parameter("intensity", intensity)
	return m

func _glow_quad(pos: Vector3, size: float, col: Color, parent: Node3D = null) -> MeshInstance3D:
	var q := MeshInstance3D.new()
	q.material_override = _glow_mat(true)
	q.mesh = _colored_quad(size, col)
	(parent if parent else world).add_child(q)
	q.position = pos
	return q

func _colored_quad(size: float, col: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := size * 0.5
	var pts := [Vector3(-h, -h, 0), Vector3(h, -h, 0), Vector3(h, h, 0), Vector3(-h, h, 0)]
	var uvs := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_color(col)
		st.set_uv(uvs[i])
		st.add_vertex(pts[i])
	return st.commit()

# 보스: Quaternius Executioner 몸통 + 코드로 만든 장갑판 6장 + Kenney 포탑 2기 + 빛나는 핵
func _boss() -> void:
	var boss := Node3D.new()
	boss.position = Vector3(0, 0, -9.5)
	world.add_child(boss)
	var hull: Node3D = load("res://assets/ships/Executioner.gltf").instantiate()
	hull.scale = Vector3.ONE * 2.1
	hull.rotation_degrees.y = 180.0  # 머리가 화면 아래(플레이어 쪽)
	boss.add_child(hull)
	for mi in hull.find_children("*", "MeshInstance3D", true, false):
		var src: Material = (mi as MeshInstance3D).get_active_material(0)
		if src is StandardMaterial3D:
			var m: StandardMaterial3D = (src as StandardMaterial3D).duplicate()
			m.albedo_color = Color(0.62, 0.64, 0.72)
			m.metallic = 0.75
			m.roughness = 0.38
			(mi as MeshInstance3D).material_override = m
	# 핵
	var core := MeshInstance3D.new()
	var cs := SphereMesh.new()
	cs.radius = 1.1
	cs.height = 2.2
	core.mesh = cs
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.1, 0.02, 0.02)
	cm.emission_enabled = true
	cm.emission = Color(1.0, 0.25, 0.08)
	cm.emission_energy_multiplier = 3.5
	core.material_override = cm
	core.position = Vector3(0, 2.4, -0.5)
	boss.add_child(core)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.45
	tm.outer_radius = 1.75
	ring.mesh = tm
	ring.material_override = metal
	ring.position = core.position
	ring.rotation_degrees.x = 70
	boss.add_child(ring)
	moving.append({node = ring, spin = Vector3(0, 0, 1.5)})
	_glow_quad(core.position + Vector3(0, 0.6, 0), 7.0, Color(1.6, 0.4, 0.12), boss)
	var cl := OmniLight3D.new()
	cl.light_color = Color(1.0, 0.4, 0.15)
	cl.light_energy = 3.0
	cl.omni_range = 9.0
	cl.position = core.position + Vector3(0, 1.5, 0)
	boss.add_child(cl)
	# 장갑판: 앞쪽 호를 따라 육각 판 6장(빛나는 이음새)
	var plate_pos := [Vector3(-6.2, 1.6, 4.0), Vector3(-3.8, 1.9, 5.6), Vector3(-1.3, 2.1, 6.5), Vector3(1.3, 2.1, 6.5), Vector3(3.8, 1.9, 5.6), Vector3(6.2, 1.6, 4.0)]
	for i in plate_pos.size():
		var p := _armor_plate()
		p.position = plate_pos[i]
		p.rotation_degrees.y = -atan2(plate_pos[i].x, 8.0) * 57.3
		boss.add_child(p)
		if i == 1:
			plate_hit = p
	# 포대(Kenney) — 같은 금속 재질로 덮어 화풍 통일
	for s in [-1, 1]:
		var tur: Node3D = load("res://assets/kenney-space/turret_double.glb").instantiate()
		tur.scale = Vector3.ONE * 2.6
		tur.position = Vector3(8.6 * s, 1.2, -1.0)
		tur.rotation_degrees.y = 180.0 + 12.0 * s
		boss.add_child(tur)
		for mi in tur.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = dark_metal
		_glow_quad(tur.position + Vector3(0, 1.4, 2.4), 2.2, Color(1.8, 0.6, 0.2), boss)
	# 엔진 불꽃(뒤쪽)
	for s in [-2.2, 0.0, 2.2]:
		_glow_quad(Vector3(s, 1.0, -9.0), 4.5, Color(0.5, 0.8, 1.8), boss)

func _armor_plate() -> Node3D:
	var n := Node3D.new()
	var body := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.radial_segments = 6
	cy.rings = 1
	cy.top_radius = 1.0
	cy.bottom_radius = 1.35
	cy.height = 0.9
	body.mesh = cy
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.62, 0.64, 0.7)
	pm.metallic = 0.9
	pm.roughness = 0.28
	body.material_override = pm
	body.rotation_degrees.y = 30
	n.add_child(body)
	var seam := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.02
	tm.outer_radius = 1.07
	tm.ring_segments = 6
	tm.rings = 6
	seam.mesh = tm
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color.BLACK
	sm.emission_enabled = true
	sm.emission = Color(1.0, 0.38, 0.1)
	sm.emission_energy_multiplier = 1.8
	seam.material_override = sm
	seam.position.y = 0.46
	seam.rotation_degrees.y = 30
	n.add_child(seam)
	var bolt := MeshInstance3D.new()
	var bs := SphereMesh.new()
	bs.radius = 0.22
	bs.height = 0.44
	bolt.mesh = bs
	bolt.material_override = sm
	bolt.position.y = 0.5
	bolt.scale = Vector3.ONE * 0.6
	n.add_child(bolt)
	return n

func _player() -> void:
	var ship: Node3D = load("res://assets/ships/Striker.gltf").instantiate()
	ship.scale = Vector3.ONE * 0.62
	ship.position = Vector3(-1.5, 2.0, 11.5)
	ship.rotation_degrees = Vector3(0, 180, -8)  # 기수가 보스 쪽, 살짝 기울어 회피 중인 자세
	world.add_child(ship)
	for mi in ship.find_children("*", "MeshInstance3D", true, false):
		var src: Material = (mi as MeshInstance3D).get_active_material(0)
		if src is StandardMaterial3D:
			var m: StandardMaterial3D = (src as StandardMaterial3D).duplicate()
			m.metallic = 0.6
			m.roughness = 0.35
			m.rim_enabled = true
			m.rim = 0.8
			m.rim_tint = 0.3
			(mi as MeshInstance3D).material_override = m
	for s in [-0.65, 0.65]:
		_glow_quad(ship.position + Vector3(s, 0.2, 2.6), 1.8, Color(0.4, 1.0, 2.2))
		var fl := MeshInstance3D.new()
		fl.mesh = _colored_quad(0.9, Color(0.3, 0.8, 2.0))
		fl.material_override = _glow_mat(false, 3.5, 1.0)
		fl.rotation_degrees.x = -90
		fl.scale = Vector3(1, 3.2, 1)
		fl.position = ship.position + Vector3(s, 0.1, 4.3)
		world.add_child(fl)
	# 판정 점(작게, 늘 보이게)
	_glow_quad(ship.position + Vector3(0, 1.6, 0.2), 0.9, Color(2.6, 2.6, 2.6))
	var hb := MeshInstance3D.new()
	var ht := TorusMesh.new()
	ht.inner_radius = 0.42
	ht.outer_radius = 0.5
	hb.mesh = ht
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.albedo_color = Color(2.0, 2.4, 2.8)
	hb.material_override = hm
	hb.position = ship.position + Vector3(0, 1.6, 0.2)
	world.add_child(hb)

func _bullets() -> void:
	# 내 탄: 세 줄기 연사(바닥에 눕힌 줄무늬), 보스 장갑까지 이어짐
	var shot := _glow_mat(false, 4.0, 0.9)
	for lane in [-0.9, 0.0, 0.9]:
		var z := 9.5
		while z > -2.5:
			var q := MeshInstance3D.new()
			q.mesh = _colored_quad(0.42, Color(0.25, 0.85, 2.0))
			q.material_override = shot
			q.rotation_degrees.x = -90
			q.scale = Vector3(1.0, 2.6, 1.0)
			q.position = Vector3(-1.5 + lane * (1.0 + (9.5 - z) * 0.06), 2.2, z)
			world.add_child(q)
			moving.append({node = q, vel = Vector3(lane * 0.6, 0, -60)})
			z -= 1.55
	# 적탄: 포대에서 뿌린 부채꼴(주황) + 핵에서 퍼지는 고리(자홍)
	var orb := _glow_mat(true, 0.0, 1.2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for s in [-1, 1]:
		var origin := Vector3(8.6 * s, 2.0, -7.5)
		for k in 3:
			var dist := 6.0 + k * 3.2
			for j in 6:
				var a := deg_to_rad(90.0 + s * 22.0 + (j - 2.5) * 8.0)
				var p := origin + Vector3(cos(a) * -s * 0.4, 0, sin(a)) * dist + Vector3(-s * dist * 0.35, 0, 0)
				var q := MeshInstance3D.new()
				q.mesh = _colored_quad(1.15, Color(2.4, 0.3, 0.55))
				q.material_override = orb
				q.position = p
				world.add_child(q)
	var center := Vector3(0, 2.6, -10.0)
	for k in 2:
		var r := 9.0 + k * 5.5
		for j in 22:
			var a := TAU * j / 22.0 + k * 0.14
			var p := center + Vector3(cos(a) * r, 0, sin(a) * r * 0.9)
			if p.z < -14.0:
				continue
			var q := MeshInstance3D.new()
			q.mesh = _colored_quad(0.95, Color(1.3, 0.45, 2.2))
			q.material_override = orb
			q.position = p
			world.add_child(q)

# 첫 장갑 파괴 순간: 섬광·불덩이·불꽃·충격파·파편·피해 숫자
func _explode() -> void:
	exploded = true
	var at_pos: Vector3 = plate_hit.global_position + Vector3(0, 0.8, 0)
	plate_hit.visible = false
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.6, 0.25)
	flash.light_energy = 14.0
	flash.omni_range = 16.0
	flash.position = at_pos + Vector3(0, 2, 0)
	world.add_child(flash)
	_glow_quad(at_pos + Vector3(0, 1.0, 0), 14.0, Color(1.6, 0.55, 0.15))
	_glow_quad(at_pos + Vector3(0, 1.2, 0), 6.0, Color(2.0, 1.2, 0.5))
	_glow_quad(at_pos + Vector3(0, 1.4, 0), 2.0, Color(2.6, 2.4, 2.0))
	var fire := _particles("res://assets/fx/flame_03.png", 70, 1.0, Color(2.6, 1.0, 0.3), 4.0, 12.0, 3.5, 8.0, false)
	fire.position = at_pos
	var sparks := _particles("res://assets/fx/spark_04.png", 90, 0.7, Color(3.0, 1.8, 0.7), 14.0, 30.0, 0.5, 1.2, false)
	sparks.position = at_pos
	var smoke := _particles("res://assets/fx/smoke_04.png", 18, 1.6, Color(0.25, 0.22, 0.3, 0.8), 1.5, 4.0, 3.0, 6.0, true)
	smoke.position = at_pos
	# 충격파 고리
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.97
	tm.outer_radius = 1.0
	tm.rings = 64
	ring.mesh = tm
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color(1.2, 0.5, 0.18, 0.35)
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ring.material_override = rm
	ring.position = at_pos
	world.add_child(ring)
	moving.append({node = ring, grow = 6.5})
	# 파편(장갑 조각)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 16:
		var c := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(rng.randf_range(0.25, 0.7), rng.randf_range(0.1, 0.25), rng.randf_range(0.25, 0.6))
		c.mesh = b
		c.material_override = metal if i % 3 else dark_metal
		c.position = at_pos
		c.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
		world.add_child(c)
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.3, 1.2), rng.randf_range(-0.4, 1.0)).normalized()
		moving.append({node = c, vel = dir * rng.randf_range(8, 18), spin = Vector3(rng.randf_range(-9, 9), rng.randf_range(-9, 9), 0), grav = true})
	# 피해 숫자
	var num := Label3D.new()
	num.text = "1,250"
	num.font = font_en
	num.font_size = 150
	num.outline_size = 48
	num.modulate = Color(1.0, 0.86, 0.35)
	num.outline_modulate = Color(0.25, 0.05, 0.0)
	num.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	num.no_depth_test = true
	num.pixel_size = 0.012
	num.position = at_pos + Vector3(5.6, 5.5, 5.4)
	world.add_child(num)
	var crit := Label3D.new()
	crit.text = "ARMOR BREAK!"
	crit.font = font_en
	crit.font_size = 78
	crit.outline_size = 30
	crit.modulate = Color(1.0, 0.62, 0.35)
	crit.outline_modulate = Color(0.1, 0.0, 0.0)
	crit.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	crit.no_depth_test = true
	crit.pixel_size = 0.012
	crit.position = num.position + Vector3(0, -1.6, 0.6)
	world.add_child(crit)

func _particles(tex: String, amount: int, life: float, col: Color, vmin: float, vmax: float, smin: float, smax: float, alpha: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.95
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0.3)
	pm.spread = 180.0
	pm.initial_velocity_min = vmin
	pm.initial_velocity_max = vmax
	pm.gravity = Vector3(0, -6, 0)
	pm.damping_min = 2.0
	pm.damping_max = 4.0
	pm.scale_min = smin
	pm.scale_max = smax
	pm.angle_min = -180
	pm.angle_max = 180
	pm.color = col
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if not alpha:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = load(tex)
	var q := QuadMesh.new()
	q.material = m
	p.draw_pass_1 = q
	world.add_child(p)
	p.emitting = true
	return p

func _ui() -> void:
	var layer := CanvasLayer.new()
	vp.add_child(layer)
	var root := Control.new()
	root.size = Vector2(W, H)
	layer.add_child(root)
	var vig := ColorRect.new()
	vig.size = Vector2(W, H)
	var vm := ShaderMaterial.new()
	vm.shader = load("res://shaders/vignette.gdshader")
	vig.material = vm
	root.add_child(vig)
	# 위쪽 그늘(글자 가독성)
	var shade := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.0, 0.0, 0.03, 0.85))
	g.set_color(1, Color(0.0, 0.0, 0.03, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.5, 0.0)
	gt.fill_to = Vector2(0.5, 1.0)
	shade.texture = gt
	shade.size = Vector2(W, 520)
	root.add_child(shade)
	var name_lbl := _label("1주차  강철 고래", font_kr, 64, Color(1, 1, 1))
	name_lbl.position = Vector2(64, 150)
	root.add_child(name_lbl)
	var sub := _label("WEEK 01  ·  IRON WHALE", font_en, 30, Color(1.0, 0.72, 0.45))
	sub.position = Vector2(68, 238)
	root.add_child(sub)
	var score := _label("128,450", font_en, 56, Color(1, 1, 1))
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score.size = Vector2(420, 70)
	score.position = Vector2(W - 64 - 420, 150)
	root.add_child(score)
	var sl := _label("SCORE", font_en, 22, Color(0.6, 0.75, 1.0))
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sl.size = Vector2(420, 30)
	sl.position = Vector2(W - 64 - 420, 238)
	root.add_child(sl)
	# 보스 체력 바: 테두리 + 그러데이션 채움 + 단계 구분 눈금
	var bar_bg := Panel.new()
	bar_bg.position = Vector2(64, 300)
	bar_bg.size = Vector2(W - 128, 30)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.1, 0.8)
	sb.border_color = Color(1.0, 0.55, 0.25, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(15)
	bar_bg.add_theme_stylebox_override("panel", sb)
	root.add_child(bar_bg)
	var fill := TextureRect.new()
	var fg := Gradient.new()
	fg.set_color(0, Color(1.0, 0.25, 0.15))
	fg.set_color(1, Color(1.0, 0.75, 0.3))
	var ft := GradientTexture2D.new()
	ft.gradient = fg
	ft.fill_to = Vector2(1, 0)
	fill.texture = ft
	fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fill.position = Vector2(70, 306)
	fill.size = Vector2((W - 140) * 0.94, 18)
	root.add_child(fill)
	for f in [0.33, 0.66]:
		var tick := ColorRect.new()
		tick.color = Color(0.05, 0.04, 0.1, 0.9)
		tick.position = Vector2(64 + (W - 128) * f, 300)
		tick.size = Vector2(4, 30)
		root.add_child(tick)
	var phase := _label("PHASE 1  ·  ARMOR 5/6", font_en, 24, Color(0.9, 0.92, 1.0, 0.95))
	phase.position = Vector2(68, 340)
	root.add_child(phase)
	# 목숨: 작은 기체 모양 3개
	for i in 3:
		var ic := Polygon2D.new()
		ic.polygon = PackedVector2Array([Vector2(0, -22), Vector2(16, 14), Vector2(0, 6), Vector2(-16, 14)])
		ic.color = Color(0.5, 0.95, 1.6)
		ic.position = Vector2(84 + i * 52, H - 150)
		root.add_child(ic)

func _label(text: String, font: Font, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", 10)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0.05, 0.85))
	l.add_theme_color_override("font_shadow_color", Color(1.0, 0.45, 0.15, 0.35))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 0)
	l.add_theme_constant_override("shadow_outline_size", 22)
	return l

func _process(dt: float) -> void:
	t += dt
	if mode == "break" and not exploded and t >= 0.25:
		_explode()
	for m in moving:
		var n: Node3D = m.node
		if m.has("vel"):
			var v: Vector3 = m.vel
			if m.has("grav"):
				v.y -= 25.0 * dt
				m.vel = v
			n.position += v * dt * 0.15
		if m.has("spin"):
			n.rotation += (m.spin as Vector3) * dt
		if m.has("grow"):
			n.scale = n.scale.lerp(Vector3.ONE * m.grow, 1.0 - pow(0.002, dt))
	if not saved and t >= at and out != "":
		saved = true
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png(out)
		print("SAVED ", out)
		get_tree().quit()
