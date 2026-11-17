# 연출(디자인 담당 파일): 먼지·유리·불꽃 터짐, 불길, 그을음, 소리.
class_name Fx
extends Node3D

var pools := {}
var pool_i := {}
var voices: Array[AudioStreamPlayer] = []
var voice_i := 0
var sfx := {}
var fires := 0

const SFX := {
	"glass": ["impactGlass_heavy_000", "impactGlass_heavy_001", "impactGlass_medium_000", "impactGlass_medium_001"],
	"thud": ["impactPunch_heavy_000", "impactPunch_heavy_001"],
	"rumble": ["impactMining_000", "impactMining_001"],
	"metal": ["impactMetal_heavy_000", "impactMetal_heavy_001"],
	"step": ["footstep_concrete_000", "footstep_concrete_001"],
}

func _ready() -> void:
	for key in SFX:
		var arr: Array[AudioStream] = []
		for n in SFX[key]:
			arr.append(load("res://assets/sfx/%s.ogg" % n))
		sfx[key] = arr
	for i in 10:
		var a := AudioStreamPlayer.new()
		add_child(a)
		voices.append(a)
	_make_pool("dust", 8, "smoke_04", 28, 2.2, false, Color(0.55, 0.5, 0.6, 0.55), {spread = 80.0, vmin = 2.0, vmax = 7.0, grav = Vector3(0, 0.6, 0), damp = 2.5, smin = 4.0, smax = 8.0, sphere = 2.0})
	_make_pool("glass", 8, "spark_04", 40, 1.1, true, Color(0.75, 0.9, 1.0, 1.0), {spread = 70.0, vmin = 4.0, vmax = 11.0, grav = Vector3(0, -22, 0), smin = 0.25, smax = 0.6, sphere = 1.5})
	_make_pool("sparks", 6, "spark_04", 30, 0.6, true, Color(1.0, 0.6, 0.25, 1.0), {spread = 90.0, vmin = 6.0, vmax = 14.0, grav = Vector3(0, -18, 0), smin = 0.3, smax = 0.7})
	_make_pool("boom", 4, "flame_03", 24, 0.9, true, Color(1.0, 0.55, 0.2, 1.0), {spread = 60.0, vmin = 3.0, vmax = 8.0, grav = Vector3(0, 3, 0), smin = 2.0, smax = 4.0, sphere = 1.0})

func _make_pool(name: String, n: int, tex: String, amount: int, life: float, additive: bool, col: Color, o: Dictionary) -> void:
	var arr: Array[GPUParticles3D] = []
	for i in n:
		arr.append(_emitter(tex, amount, life, additive, col, o))
	pools[name] = arr
	pool_i[name] = 0

func _emitter(tex: String, amount: int, life: float, additive: bool, col: Color, o: Dictionary, one_shot := true) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = one_shot
	p.explosiveness = 0.92 if one_shot else 0.0
	p.emitting = false
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.color = col
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	pm.direction = Vector3.UP
	pm.spread = o.get("spread", 45.0)
	pm.initial_velocity_min = o.get("vmin", 1.0)
	pm.initial_velocity_max = o.get("vmax", 3.0)
	pm.gravity = o.get("grav", Vector3(0, -9.8, 0))
	pm.damping_min = o.get("damp", 0.0)
	pm.damping_max = o.get("damp", 0.0)
	pm.scale_min = o.get("smin", 1.0)
	pm.scale_max = o.get("smax", 1.0)
	if o.has("sphere"):
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = o["sphere"]
	if o.has("box"):
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = o["box"]
	p.process_material = pm
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = load("res://assets/fx/%s.png" % tex)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var q := QuadMesh.new()
	q.material = mat
	p.draw_pass_1 = q
	p.visibility_aabb = AABB(Vector3(-20, -5, -20), Vector3(40, 50, 40))
	add_child(p)
	return p

func burst(name: String, pos: Vector3, scale := 1.0) -> void:
	var arr: Array = pools[name]
	var i: int = pool_i[name]
	pool_i[name] = (i + 1) % arr.size()
	var p: GPUParticles3D = arr[i]
	p.global_position = pos
	p.scale = Vector3.ONE * scale
	p.restart()

func play(key: String, pitch := 1.0, vol_db := 0.0) -> void:
	var arr: Array = sfx[key]
	var a := voices[voice_i]
	voice_i = (voice_i + 1) % voices.size()
	a.stream = arr[randi() % arr.size()]
	a.pitch_scale = pitch * randf_range(0.92, 1.08)
	a.volume_db = vol_db
	a.play()

# 무너진 자리: 계속 타는 불길 + 그을음 + (앞의 몇 곳만) 주황 불빛.
func fire_at(pos: Vector3, size: float) -> void:
	if fires >= 8:
		return  # 계속 타는 입자·그을음 데칼 상한(Mobile 렌더러는 메시당 데칼 8개)
	var f := _emitter("flame_03", 26, 1.4, true, Color(1.0, 0.5, 0.15, 0.9), {spread = 15.0, vmin = 2.0, vmax = 5.0, grav = Vector3(0, 2, 0), smin = 1.5 * size, smax = 3.0 * size, box = Vector3(3.0 * size, 0.5, 3.0 * size)}, false)
	f.global_position = pos
	f.emitting = true
	var sm := _emitter("smoke_07", 14, 4.0, false, Color(0.12, 0.1, 0.14, 0.6), {spread = 10.0, vmin = 3.0, vmax = 5.0, grav = Vector3(0.6, 0.5, 0), smin = 4.0 * size, smax = 8.0 * size}, false)
	sm.global_position = pos + Vector3.UP * 3.0
	sm.emitting = true
	var d := Decal.new()
	d.texture_albedo = load("res://assets/fx/scorch_02.png")
	d.size = Vector3(10.0 * size, 4.0, 10.0 * size)
	d.modulate = Color(0, 0, 0, 0.85)
	add_child(d)
	d.global_position = pos
	fires += 1
	if fires <= 5:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.5, 0.18)
		l.light_energy = 2.5
		l.omni_range = 14.0
		l.shadow_enabled = false
		add_child(l)
		l.global_position = pos + Vector3.UP * 2.5
		var tw := create_tween().set_loops()
		tw.tween_property(l, "light_energy", 1.6, 0.13)
		tw.tween_property(l, "light_energy", 2.8, 0.17)
