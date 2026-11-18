# 탄 묶음: 수천 발을 MultiMesh 하나로 그린다(그리기 호출 1번). 적탄·내 탄 각각 하나씩.
class_name Bullets
extends Node2D

const STRIDE := 12  # Transform2D 8 + 색 4
var cap := 0
var pos := PackedVector2Array()
var vel := PackedVector2Array()
var rad := PackedFloat32Array()
var life := PackedFloat32Array()
var col := PackedColorArray()
var dmg := PackedFloat32Array()   # 탄마다 피해 배율(기체 무기마다 다름)
var homing := PackedByteArray()   # 1이면 target 쪽으로 휘어짐
var target := Vector2.INF
var orient := false               # 날아가는 방향으로 그림을 눕힘(유도탄·부채꼴 내 탄)
var next := 0
var alive_count := 0
var look := Vector2(2.6, 2.6)   # 그림 크기 = 반지름 × look (판정보다 크게 보이게)
var mm: MultiMesh
var buf := PackedFloat32Array()
var bounds := Rect2(-80, -80, 880, 1440)

func setup(capacity: int, tex: Texture2D, look_scale: Vector2, mat: Material = null) -> void:
	cap = capacity
	look = look_scale
	pos.resize(cap)
	vel.resize(cap)
	rad.resize(cap)
	life.resize(cap)
	col.resize(cap)
	dmg.resize(cap)
	homing.resize(cap)
	life.fill(0.0)
	mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	mm.mesh = q
	mm.instance_count = cap
	# 그리기 범위를 화면 전체로 고정: 매 프레임 버퍼를 바꾸면 범위 재계산이 늦어, 흔들림(카메라 이동) 순간
	# 묶음 전체가 화면 밖으로 잘못 판정돼 탄이 통째로 사라졌다 나타남(실기기 녹화로 확인한 깜빡임)
	mm.custom_aabb = AABB(Vector3(-400, -400, -1), Vector3(1600, 2400, 2))
	buf.resize(cap * STRIDE)
	buf.fill(0.0)
	mm.buffer = buf
	var mmi := MultiMeshInstance2D.new()
	mmi.multimesh = mm
	mmi.texture = tex
	if mat:
		mmi.material = mat
	else:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		mmi.material = m
	add_child(mmi)

func spawn(p: Vector2, v: Vector2, r: float, c: Color, d := 1.0, h := false) -> void:
	for i in cap:
		var k := (next + i) % cap
		if life[k] <= 0.0:
			_put(k, p, v, r, c, d, h)
			return
	_put(next, p, v, r, c, d, h)  # 가득 차면 가장 오래된 자리를 덮어씀

func _put(k: int, p: Vector2, v: Vector2, r: float, c: Color, d := 1.0, h := false) -> void:
	dmg[k] = d
	homing[k] = 1 if h else 0
	pos[k] = p
	vel[k] = v
	rad[k] = r
	life[k] = 10.0
	col[k] = c
	next = (k + 1) % cap

func kill(k: int) -> void:
	life[k] = 0.0

func update(dt: float) -> void:
	var n := 0
	for k in cap:
		var o := k * STRIDE
		if life[k] <= 0.0:
			if buf[o] != 0.0 or buf[o + 5] != 0.0:
				buf[o] = 0.0
				buf[o + 5] = 0.0
			continue
		if homing[k] and target != Vector2.INF:
			var sp := vel[k].length()
			vel[k] = vel[k].lerp((target - pos[k]).normalized() * sp, 1.0 - pow(0.004, dt)).normalized() * sp
		var p := pos[k] + vel[k] * dt
		pos[k] = p
		life[k] -= dt
		if not bounds.has_point(p):
			life[k] = 0.0
			buf[o] = 0.0
			buf[o + 5] = 0.0
			continue
		n += 1
		var r := rad[k]
		var c := col[k]
		if orient:
			var n2 := vel[k].normalized()  # 그림의 세로축을 진행 방향으로(위로 나는 탄은 그대로)
			buf[o] = -n2.y * r * look.x
			buf[o + 1] = -n2.x * r * look.y
			buf[o + 4] = n2.x * r * look.x
			buf[o + 5] = -n2.y * r * look.y
		else:
			buf[o] = r * look.x
			buf[o + 1] = 0.0
			buf[o + 4] = 0.0
			buf[o + 5] = r * look.y
		buf[o + 3] = p.x
		buf[o + 7] = p.y
		buf[o + 8] = c.r
		buf[o + 9] = c.g
		buf[o + 10] = c.b
		buf[o + 11] = c.a
	alive_count = n
	mm.buffer = buf

# 원(c, r)에 닿은 탄 하나의 번호, 없으면 -1
func hit_circle(c: Vector2, r: float) -> int:
	for k in cap:
		if life[k] > 0.0:
			var rr := r + rad[k]
			if pos[k].distance_squared_to(c) < rr * rr:
				return k
	return -1

# 살아 있는 탄을 모두 지우고 위치 목록을 돌려줌(단계가 바뀔 때 보석으로 바꾸는 연출용)
func clear_all() -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in cap:
		if life[k] > 0.0:
			out.append(pos[k])
			life[k] = 0.0
	return out
