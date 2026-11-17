# 블록 건물·부서짐·주저앉기·파편(결정 004). 모든 건물 블록은 MultiMesh 1개, 파편도 MultiMesh 1개.
class_name City
extends Node3D

class Bld:
	var ox: float
	var oz: float
	var nx: int
	var nz: int
	var nf: int
	var start: int
	var total: int
	var alive: int
	var lit := true
	var collapsing := false
	var tint: Color
	func center() -> Vector3:
		return Vector3(ox + nx * T.BLOCK * 0.5, 0.0, oz + nz * T.BLOCK * 0.5)

signal block_destroyed(count: int, pos: Vector3)
signal collapse_started(b: Bld)
signal collapse_finished(b: Bld)
signal lights_went_out(b: Bld)

var buildings: Array[Bld] = []
var alive := PackedByteArray()
var total := 0
var destroyed := 0
var rng := RandomNumberGenerator.new()
var mm: MultiMesh
var block_mat: ShaderMaterial

# 파편(고리 버퍼)
var dmm: MultiMesh
var dbuf := PackedFloat32Array()
var dpos := PackedVector3Array()
var dvel := PackedVector3Array()
var daxis := PackedVector3Array()
var dang := PackedFloat32Array()
var dspin := PackedFloat32Array()
var dlife := PackedFloat32Array()
var dsize := PackedFloat32Array()
var dnext := 0
var _fresh := false  # 새 파편이 생겨 버퍼를 다시 올려야 함
var dactive := 0
const STRIDE := 20  # transform 12 + color 4 + custom 4

func build(seed: int) -> void:
	rng.seed = seed
	block_mat = ShaderMaterial.new()
	block_mat.shader = load("res://shaders/block.gdshader")
	var half := (T.GRID - 1) * 0.5
	for gx in T.GRID:
		for gz in T.GRID:
			if gx == T.GRID / 2 and gz == T.GRID / 2:
				continue  # 가운데 광장(시작 자리)
			var b := Bld.new()
			b.nx = rng.randi_range(2, 4)
			b.nz = rng.randi_range(2, 4)
			var d := Vector2(gx - half, gz - half).length()
			b.nf = clampi(rng.randi_range(T.FLOORS_MIN, T.FLOORS_MIN + 4) + int((2.2 - d) * 2.0), T.FLOORS_MIN, T.FLOORS_MAX)
			var cx := (gx - half) * T.LOT + rng.randf_range(-1.5, 1.5)
			var cz := (gz - half) * T.LOT + rng.randf_range(-1.5, 1.5)
			b.ox = cx - b.nx * T.BLOCK * 0.5
			b.oz = cz - b.nz * T.BLOCK * 0.5
			b.tint = Color.from_hsv(rng.randf_range(0.6, 0.72), rng.randf_range(0.06, 0.2), rng.randf_range(0.2, 0.34))
			b.start = total
			b.total = b.nx * b.nz * b.nf
			b.alive = b.total
			total += b.total
			buildings.append(b)
	alive.resize(total)
	alive.fill(1)

	mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	mm.mesh = box
	mm.instance_count = total
	for b in buildings:
		var seedv := rng.randf()
		for f in b.nf:
			for z in b.nz:
				for x in b.nx:
					var i := _idx(b, x, z, f)
					mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * T.BLOCK), block_pos(b, x, z, f)))
					var v := rng.randf_range(0.9, 1.08)
					mm.set_instance_color(i, Color(b.tint.r * v, b.tint.g * v, b.tint.b * v))
					mm.set_instance_custom_data(i, Color(1.0, seedv + i * 0.013, 0.0, 1.0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = block_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.custom_aabb = AABB(Vector3(-150, -10, -150), Vector3(300, 80, 300))
	add_child(mmi)

	dmm = MultiMesh.new()
	dmm.transform_format = MultiMesh.TRANSFORM_3D
	dmm.use_colors = true
	dmm.use_custom_data = true
	dmm.mesh = box
	dmm.instance_count = T.DEBRIS_CAP
	dbuf.resize(T.DEBRIS_CAP * STRIDE)
	dbuf.fill(0.0)
	# Packed 배열은 값으로 복사되므로 하나씩 늘린다
	dpos.resize(T.DEBRIS_CAP)
	dvel.resize(T.DEBRIS_CAP)
	daxis.resize(T.DEBRIS_CAP)
	dang.resize(T.DEBRIS_CAP)
	dspin.resize(T.DEBRIS_CAP)
	dlife.resize(T.DEBRIS_CAP)
	dsize.resize(T.DEBRIS_CAP)
	dlife.fill(0.0)
	dmm.buffer = dbuf
	var dmi := MultiMeshInstance3D.new()
	dmi.multimesh = dmm
	dmi.material_override = block_mat
	dmi.custom_aabb = mmi.custom_aabb
	add_child(dmi)

func _idx(b: Bld, x: int, z: int, f: int) -> int:
	return b.start + (f * b.nz + z) * b.nx + x

func block_pos(b: Bld, x: int, z: int, f: int) -> Vector3:
	return Vector3(b.ox + (x + 0.5) * T.BLOCK, (f + 0.5) * T.BLOCK, b.oz + (z + 0.5) * T.BLOCK)

func fraction() -> float:
	return float(destroyed) / float(max(total, 1))

func _kill(b: Bld, x: int, z: int, f: int, vel: Vector3, debris_chance: float) -> bool:
	var i := _idx(b, x, z, f)
	if alive[i] == 0:
		return false
	alive[i] = 0
	b.alive -= 1
	destroyed += 1
	mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), Vector3.ZERO))
	if rng.randf() < debris_chance:
		var p := block_pos(b, x, z, f)
		# 블록 하나를 작은 덩어리 2개로
		for k in 2:
			spawn_debris(p + Vector3(rng.randf_range(-0.8, 0.8), rng.randf_range(-0.6, 0.6), rng.randf_range(-0.8, 0.8)),
				vel + Vector3(rng.randf_range(-2, 2), rng.randf_range(0, 2), rng.randf_range(-2, 2)),
				rng.randf_range(0.7, 1.5), b.tint)
	return true

func _near(b: Bld, c: Vector3, r: float) -> bool:
	return not (c.x + r < b.ox or c.x - r > b.ox + b.nx * T.BLOCK or c.z + r < b.oz or c.z - r > b.oz + b.nz * T.BLOCK)

# 구 안의 블록을 부순다. push는 파편이 날아갈 방향(쇠공 속도). 부순 개수를 돌려준다.
func damage_sphere(c: Vector3, r: float, push: Vector3) -> int:
	var removed := 0
	for b in buildings:
		if b.alive <= 0 or not _near(b, c, r):
			continue
		var x0 := clampi(floori((c.x - r - b.ox) / T.BLOCK), 0, b.nx - 1)
		var x1 := clampi(floori((c.x + r - b.ox) / T.BLOCK), 0, b.nx - 1)
		var z0 := clampi(floori((c.z - r - b.oz) / T.BLOCK), 0, b.nz - 1)
		var z1 := clampi(floori((c.z + r - b.oz) / T.BLOCK), 0, b.nz - 1)
		var f0 := clampi(floori((c.y - r) / T.BLOCK), 0, b.nf - 1)
		var f1 := clampi(floori((c.y + r) / T.BLOCK), 0, b.nf - 1)
		var cols := {}
		var here := 0
		for f in range(f0, f1 + 1):
			for z in range(z0, z1 + 1):
				for x in range(x0, x1 + 1):
					var p := block_pos(b, x, z, f)
					if p.distance_to(c) > r + T.BLOCK * 0.45:
						continue
					var v := (p - c).normalized() * rng.randf_range(4.0, 9.0) + push * 0.6 + Vector3(0, rng.randf_range(2.0, 7.0), 0)
					if _kill(b, x, z, f, v, 0.9):
						here += 1
						cols[Vector2i(x, z)] = true
		if here > 0:
			removed += here
			for col in cols:
				here += _drop_column(b, col.x, col.y)
			lights_out(b)
			block_destroyed.emit(here, c)
			if not b.collapsing and b.alive < b.total * T.COLLAPSE_BELOW:
				_collapse(b)
	return removed

# 아래가 빈 기둥 블록은 떨어진다.
func _drop_column(b: Bld, x: int, z: int) -> int:
	var hole := false
	var n := 0
	for f in b.nf:
		var i := _idx(b, x, z, f)
		if alive[i] == 0:
			hole = true
		elif hole and rng.randf() < T.DROP_COLUMN:
			if _kill(b, x, z, f, Vector3(rng.randf_range(-1.5, 1.5), -1.0, rng.randf_range(-1.5, 1.5)), 0.55):
				n += 1
	return n

# 위층부터 주저앉기.
func _collapse(b: Bld) -> void:
	b.collapsing = true
	collapse_started.emit(b)
	for f in range(b.nf - 1, -1, -1):
		var any := false
		for z in b.nz:
			for x in b.nx:
				if _kill(b, x, z, f, Vector3(rng.randf_range(-3, 3), -3.0, rng.randf_range(-3, 3)), 0.35):
					any = true
		if any:
			block_destroyed.emit(b.nx * b.nz, Vector3(b.center().x, (f + 0.5) * T.BLOCK, b.center().z))
			await get_tree().create_timer(0.07).timeout
	collapse_finished.emit(b)

func lights_out(b: Bld) -> void:
	if not b.lit:
		return
	b.lit = false
	for f in b.nf:
		for z in b.nz:
			for x in b.nx:
				var i := _idx(b, x, z, f)
				var cd := mm.get_instance_custom_data(i)
				cd.r = 0.0
				mm.set_instance_custom_data(i, cd)
	lights_went_out.emit(b)

func blackout_near(p: Vector3, radius: float) -> void:
	for b in buildings:
		if b.lit and b.center().distance_to(Vector3(p.x, 0, p.z)) < radius:
			lights_out(b)

# 쇠공이 블록에 파묻힌 만큼 밀어낼 벡터(가장 깊은 것 하나).
func contact_push(c: Vector3, r: float) -> Vector3:
	var best := Vector3.ZERO
	var best_d := 0.0
	var h := T.BLOCK * 0.5
	for b in buildings:
		if b.alive <= 0 or not _near(b, c, r):
			continue
		var x0 := clampi(floori((c.x - r - b.ox) / T.BLOCK), 0, b.nx - 1)
		var x1 := clampi(floori((c.x + r - b.ox) / T.BLOCK), 0, b.nx - 1)
		var z0 := clampi(floori((c.z - r - b.oz) / T.BLOCK), 0, b.nz - 1)
		var z1 := clampi(floori((c.z + r - b.oz) / T.BLOCK), 0, b.nz - 1)
		var f1 := clampi(floori((c.y + r) / T.BLOCK), 0, b.nf - 1)
		for f in range(0, f1 + 1):
			for z in range(z0, z1 + 1):
				for x in range(x0, x1 + 1):
					if alive[_idx(b, x, z, f)] == 0:
						continue
					var p := block_pos(b, x, z, f)
					var q := c.clamp(p - Vector3(h, h, h), p + Vector3(h, h, h))
					var d := c - q
					var dist := d.length()
					if dist >= r:
						continue
					var depth := r - dist
					if depth > best_d:
						best_d = depth
						var n := d / dist if dist > 0.001 else Vector3(c.x - p.x, 0, c.z - p.z).normalized()
						best = n * depth
	return best

func nearest_building(p: Vector3) -> Bld:
	var best: Bld = null
	var bd := INF
	for b in buildings:
		if b.alive <= 0 or b.collapsing:
			continue
		var d := b.center().distance_squared_to(Vector3(p.x, 0, p.z))
		if d < bd:
			bd = d
			best = b
	return best

func spawn_debris(p: Vector3, v: Vector3, s: float, tint: Color) -> void:
	var k := dnext
	dnext = (dnext + 1) % T.DEBRIS_CAP
	dpos[k] = p
	dvel[k] = v
	daxis[k] = Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
	dang[k] = rng.randf() * TAU
	dspin[k] = rng.randf_range(-8.0, 8.0)
	dlife[k] = rng.randf_range(4.5, 6.5)
	_fresh = true
	dsize[k] = s
	var o := k * STRIDE
	var v2 := rng.randf_range(0.75, 1.1)
	dbuf[o + 12] = tint.r * v2
	dbuf[o + 13] = tint.g * v2
	dbuf[o + 14] = tint.b * v2
	dbuf[o + 15] = 1.0
	for j in 4:
		dbuf[o + 16 + j] = 0.0

func _process(dt: float) -> void:
	if dmm == null or (dactive == 0 and not _fresh):
		return
	_fresh = false
	var n := 0
	for k in T.DEBRIS_CAP:
		if dlife[k] <= 0.0:
			continue
		dlife[k] -= dt
		var o := k * STRIDE
		if dlife[k] <= 0.0:
			for j in 12:
				dbuf[o + j] = 0.0
			continue
		n += 1
		var p := dpos[k]
		var s := dsize[k]
		if dlife[k] < 1.5:
			p.y -= dt * s * 0.8  # 땅속으로 가라앉아 사라짐
		else:
			var v := dvel[k]
			v.y -= 28.0 * dt
			p += v * dt
			if p.y < s * 0.5:
				p.y = s * 0.5
				if v.y < 0.0:
					v.y = -v.y * 0.25
				v.x *= 0.5
				v.z *= 0.5
				dspin[k] *= 0.4
			dvel[k] = v
			dang[k] += dspin[k] * dt
		dpos[k] = p
		var bas := Basis(daxis[k], dang[k]).scaled(Vector3.ONE * s)
		dbuf[o + 0] = bas.x.x; dbuf[o + 1] = bas.y.x; dbuf[o + 2] = bas.z.x; dbuf[o + 3] = p.x
		dbuf[o + 4] = bas.x.y; dbuf[o + 5] = bas.y.y; dbuf[o + 6] = bas.z.y; dbuf[o + 7] = p.y
		dbuf[o + 8] = bas.x.z; dbuf[o + 9] = bas.y.z; dbuf[o + 10] = bas.z.z; dbuf[o + 11] = p.z
	dactive = n
	dmm.buffer = dbuf
