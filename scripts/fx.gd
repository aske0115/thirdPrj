# 연출(디자인 담당 파일): 불꽃·폭발 입자, 충격파 고리, 피해 숫자, 파편, 보석, 섬광, 소리.
class_name Fx
extends Node2D

var pools := {}
var pool_i := {}
var numbers: Array[Label] = []
var num_i := 0
var debris: Array[Dictionary] = []
var gems := PackedVector2Array()
var gem_vel := PackedVector2Array()
var gem_mm: MultiMesh
var gem_buf := PackedFloat32Array()
const GEM_CAP := 400
var voices: Array[AudioStreamPlayer] = []
var voice_i := 0
var sounds := {}
var font: Font
signal gem_collected(n: int)

func setup(f: Font, dot: Texture2D) -> void:
	font = f
	_pool("spark", 10, "spark_04", 24, 0.35, true, {spread = 180.0, vmin = 220.0, vmax = 620.0, smin = 0.08, smax = 0.22, grav = Vector2(0, 600), col = Color(2.6, 1.6, 0.6)})
	_pool("ping", 6, "spark_04", 6, 0.18, true, {spread = 60.0, vmin = 120.0, vmax = 260.0, smin = 0.05, smax = 0.1, grav = Vector2.ZERO, col = Color(1.2, 1.6, 2.4), dir = Vector2.DOWN})
	_pool("boom", 6, "flame_03", 30, 0.7, true, {spread = 180.0, vmin = 120.0, vmax = 520.0, smin = 0.4, smax = 1.1, grav = Vector2(0, -60), col = Color(2.8, 1.2, 0.4), damp = 300.0})
	_pool("smoke", 4, "smoke_04", 16, 1.4, false, {spread = 180.0, vmin = 40.0, vmax = 160.0, smin = 0.6, smax = 1.4, grav = Vector2(0, -40), col = Color(0.35, 0.3, 0.4, 0.7), damp = 60.0})
	for i in 24:
		var l := Label.new()
		l.add_theme_font_override("font", font)
		l.add_theme_constant_override("outline_size", 8)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		l.visible = false
		l.z_index = 20
		add_child(l)
		numbers.append(l)
	gem_mm = MultiMesh.new()
	gem_mm.transform_format = MultiMesh.TRANSFORM_2D
	gem_mm.use_colors = true
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	gem_mm.mesh = q
	gem_mm.instance_count = GEM_CAP
	gem_buf.resize(GEM_CAP * 12)
	gem_buf.fill(0.0)
	var gmi := MultiMeshInstance2D.new()
	gmi.multimesh = gem_mm
	gmi.texture = dot
	var gmat := CanvasItemMaterial.new()
	gmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	gmi.material = gmat
	add_child(gmi)
	for i in 10:
		var a := AudioStreamPlayer.new()
		add_child(a)
		voices.append(a)
	sounds["metal"] = [load("res://assets/sfx/impactMetal_heavy_000.ogg"), load("res://assets/sfx/impactMetal_heavy_001.ogg")]
	sounds["glass"] = [load("res://assets/sfx/impactGlass_heavy_000.ogg"), load("res://assets/sfx/impactGlass_medium_001.ogg")]
	sounds["thud"] = [load("res://assets/sfx/impactPunch_heavy_000.ogg"), load("res://assets/sfx/impactPunch_heavy_001.ogg")]
	sounds["rumble"] = [load("res://assets/sfx/impactMining_000.ogg"), load("res://assets/sfx/impactMining_001.ogg")]
	sounds["shot"] = [Synth.zap(1900.0, 700.0, 0.05, 0.25)]
	sounds["tick"] = [Synth.zap(3200.0, 2400.0, 0.025, 0.18)]
	sounds["boom"] = [Synth.noise_boom(0.6, 0.9), Synth.noise_boom(0.45, 0.8)]
	sounds["warn"] = [Synth.alarm()]

func _pool(name: String, n: int, tex: String, amount: int, life: float, additive: bool, o: Dictionary) -> void:
	var arr: Array[GPUParticles2D] = []
	for i in n:
		var p := GPUParticles2D.new()
		p.amount = amount
		p.lifetime = life
		p.one_shot = true
		p.explosiveness = 0.95
		p.emitting = false
		p.local_coords = false
		p.texture = load("res://assets/fx/%s.png" % tex)
		var pm := ParticleProcessMaterial.new()
		pm.particle_flag_disable_z = true
		var d: Vector2 = o.get("dir", Vector2.UP)
		pm.direction = Vector3(d.x, d.y, 0)
		pm.spread = o.get("spread", 180.0)
		pm.initial_velocity_min = o.get("vmin", 100.0)
		pm.initial_velocity_max = o.get("vmax", 300.0)
		var g: Vector2 = o.get("grav", Vector2.ZERO)
		pm.gravity = Vector3(g.x, g.y, 0)
		pm.damping_min = o.get("damp", 0.0)
		pm.damping_max = o.get("damp", 0.0)
		pm.scale_min = o.get("smin", 0.2)
		pm.scale_max = o.get("smax", 0.5)
		pm.angle_min = -180.0
		pm.angle_max = 180.0
		pm.color = o.get("col", Color.WHITE)
		var gr := Gradient.new()
		gr.set_color(0, Color(1, 1, 1, 1))
		gr.set_color(1, Color(1, 1, 1, 0))
		var gt := GradientTexture1D.new()
		gt.gradient = gr
		pm.color_ramp = gt
		p.process_material = pm
		if additive:
			var m := CanvasItemMaterial.new()
			m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
			p.material = m
		p.z_index = 10
		add_child(p)
		arr.append(p)
	pools[name] = arr
	pool_i[name] = 0

func burst(name: String, at: Vector2, s := 1.0) -> void:
	var arr: Array = pools[name]
	var i: int = pool_i[name]
	pool_i[name] = (i + 1) % arr.size()
	var p: GPUParticles2D = arr[i]
	p.global_position = at
	p.scale = Vector2.ONE * s
	p.restart()

func play(key: String, pitch := 1.0, db := 0.0) -> void:
	var arr: Array = sounds[key]
	var a := voices[voice_i]
	voice_i = (voice_i + 1) % voices.size()
	a.stream = arr[randi() % arr.size()]
	a.pitch_scale = pitch * randf_range(0.93, 1.07)
	a.volume_db = db
	a.play()

# 퍼지는 충격파 고리
func ring(at: Vector2, radius: float, c: Color, dur := 0.45, width := 10.0) -> void:
	var l := Line2D.new()
	var pts := PackedVector2Array()
	for i in 49:
		pts.append(Vector2.from_angle(TAU * i / 48))
	l.points = pts
	l.width = width / 10.0
	l.width_curve = null
	l.default_color = c
	l.position = at
	l.z_index = 12
	l.scale = Vector2.ONE * 10.0
	add_child(l)
	var tw := create_tween().set_parallel()
	tw.tween_property(l, "scale", Vector2.ONE * radius, dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "width", width / radius, dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)  # 커져도 선 굵기는 그대로
	tw.tween_property(l, "modulate:a", 0.0, dur)
	tw.chain().tween_callback(l.queue_free)

func number(at: Vector2, value: int, big: bool) -> void:
	var l := numbers[num_i]
	num_i = (num_i + 1) % numbers.size()
	l.text = str(value)
	l.add_theme_font_size_override("font_size", 46 if big else 28)
	l.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3) if big else Color(1, 1, 1))
	l.position = at + Vector2(randf_range(-30, 10), -20)
	l.visible = true
	l.modulate.a = 1.0
	l.scale = Vector2.ONE * (1.6 if big else 1.2)
	var tw := create_tween().set_parallel()
	tw.tween_property(l, "position:y", l.position.y - 70, 0.6).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector2.ONE, 0.15)
	tw.tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.35)

# 부서진 부위의 조각이 돌며 떨어짐
func shatter(at: Vector2, size: float, c: Color, n := 10) -> void:
	for i in n:
		var pg := Polygon2D.new()
		var s := randf_range(0.25, 0.55) * size
		pg.polygon = PackedVector2Array([Vector2(-s, -s * 0.6), Vector2(s * 0.8, -s * 0.4), Vector2(s * 0.5, s * 0.7), Vector2(-s * 0.6, s * 0.5)])
		pg.color = c
		pg.position = at + Vector2(randf_range(-size, size), randf_range(-size, size)) * 0.5
		pg.z_index = 8
		add_child(pg)
		debris.append({node = pg, vel = Vector2(randf_range(-420, 420), randf_range(-520, -80)), spin = randf_range(-9, 9), life = randf_range(1.0, 1.6)})

func spawn_gems(at: Vector2, n: int, spread := 260.0) -> void:
	for i in n:
		if gems.size() >= GEM_CAP:
			return
		gems.append(at)
		gem_vel.append(Vector2.from_angle(randf() * TAU) * randf_range(spread * 0.4, spread))

func update(dt: float, player_pos: Vector2) -> void:
	for i in range(debris.size() - 1, -1, -1):
		var d: Dictionary = debris[i]
		var node: Polygon2D = d.node
		d.vel += Vector2(0, 1400) * dt
		node.position += d.vel * dt
		node.rotation += d.spin * dt
		d.life -= dt
		node.modulate.a = clampf(d.life * 2.0, 0.0, 1.0)
		if d.life <= 0.0:
			node.queue_free()
			debris.remove_at(i)
	var got := 0
	var i2 := gems.size() - 1
	while i2 >= 0:
		var p := gems[i2]
		var v := gem_vel[i2]
		var to := player_pos - p
		var dist := to.length()
		v = v * pow(0.04, dt) + to.normalized() * 3200.0 * dt * clampf(1.0 - dist / 1600.0, 0.35, 1.0)
		p += v * dt
		if dist < 40.0:
			gems.remove_at(i2)
			gem_vel.remove_at(i2)
			got += 1
		else:
			gems[i2] = p
			gem_vel[i2] = v
		i2 -= 1
	for k in GEM_CAP:
		var o := k * 12
		if k < gems.size():
			var p2 := gems[k]
			gem_buf[o] = 18.0
			gem_buf[o + 3] = p2.x
			gem_buf[o + 5] = 18.0
			gem_buf[o + 7] = p2.y
			gem_buf[o + 8] = 2.6
			gem_buf[o + 9] = 2.0
			gem_buf[o + 10] = 0.6
			gem_buf[o + 11] = 1.0
		else:
			gem_buf[o] = 0.0
			gem_buf[o + 5] = 0.0
	gem_mm.buffer = gem_buf
	if got > 0:
		gem_collected.emit(got)
		play("tick", 1.0 + minf(got, 8) * 0.04, -14.0)
