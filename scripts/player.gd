# 내 기체: 손가락 움직임을 그대로 따라감(관성 없음, 결정 007). 자동으로 쉬지 않고 쏨.
class_name Player
extends Node2D

const HITBOX := 7.0
var fire_t := 0.0
var invuln := 0.0
var lives := 3
var shots: Bullets
var core: Node2D
var body: Node2D
var muzzle := 0

func _ready() -> void:
	body = Node2D.new()
	add_child(body)
	var hull := Polygon2D.new()
	hull.polygon = PackedVector2Array([Vector2(0, -42), Vector2(12, -10), Vector2(38, 18), Vector2(14, 22), Vector2(0, 34), Vector2(-14, 22), Vector2(-38, 18), Vector2(-12, -10)])
	hull.color = Color(0.85, 0.9, 1.0)
	body.add_child(hull)
	var trim := Line2D.new()
	trim.points = PackedVector2Array([Vector2(-38, 18), Vector2(-12, -10), Vector2(0, -42), Vector2(12, -10), Vector2(38, 18)])
	trim.width = 3.0
	trim.default_color = Color(0.6, 1.6, 2.6)
	body.add_child(trim)
	for s in [-1, 1]:
		var flame := Polygon2D.new()
		flame.polygon = PackedVector2Array([Vector2(-5, 0), Vector2(5, 0), Vector2(0, 26)])
		flame.color = Color(2.6, 1.3, 0.5)
		flame.position = Vector2(9 * s, 26)
		body.add_child(flame)
	# 판정 점(작게 빛나게 — 어디가 맞는 곳인지 보이게)
	core = Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 12:
		pts.append(Vector2.from_angle(TAU * i / 12) * HITBOX)
	(core as Polygon2D).polygon = pts
	(core as Polygon2D).color = Color(3.0, 3.0, 3.0)
	add_child(core)

func move_by(d: Vector2) -> void:
	position = (position + d).clamp(Vector2(30, 120), Vector2(690, 1230))

func update(dt: float, firing: bool) -> void:
	if invuln > 0.0:
		invuln -= dt
		visible = int(invuln * 20.0) % 2 == 0
	else:
		visible = true
	body.position.y = sin(Time.get_ticks_msec() * 0.01) * 1.5
	if not firing:
		return
	fire_t -= dt
	if fire_t <= 0.0:
		fire_t += 1.0 / 16.0
		muzzle += 1
		var p := position + Vector2(0, -40)
		var c := Color(0.7, 1.8, 2.8, 0.9)
		shots.spawn(p, Vector2(0, -1700), 6.0, c)
		shots.spawn(p + Vector2(-18, 14), Vector2(-90, -1650), 5.0, c)
		shots.spawn(p + Vector2(18, 14), Vector2(90, -1650), 5.0, c)
