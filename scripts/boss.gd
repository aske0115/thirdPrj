# 보스: content/bosses/*.json을 읽어 부위를 다각형으로 짓고, 단계마다 탄막 패턴을 쏜다.
# 부위는 자기 단계일 때만 맞고(아니면 튕김), 그룹이 다 부서지면 다음 단계.
class_name Boss
extends Node2D

class Part:
	var id: String
	var group: String
	var phase: int
	var shape: String
	var offset: Vector2
	var r: float
	var hp: float
	var max_hp: float
	var alive := true
	var node: Node2D
	var flash := 0.0
	var dmg_acc := 0.0

signal part_broken(part: Part, at: Vector2)
signal phase_changed(phase: int)
signal defeated(at: Vector2)
signal part_hit(at: Vector2, amount: float, armored: bool)

var data: Dictionary
var parts: Array[Part] = []
var phase := 1
var t := 0.0
var entering := 1.4
var home := Vector2(360, 300)
var timers := {}
var spin := {}
var player_pos := Vector2(360, 1050)
var enemy: Bullets
var dead := false
var hull_col: Color
var edge_col: Color
var total_hp := 0.0

func load_boss(path: String) -> void:
	load_data(JSON.parse_string(FileAccess.get_file_as_string(path)))

func load_data(d: Dictionary) -> void:
	data = d
	var hc: Array = data["hull_color"]
	var ec: Array = data["edge_color"]
	hull_col = Color(hc[0], hc[1], hc[2])
	edge_col = Color(ec[0], ec[1], ec[2])
	position = Vector2(360, -320)
	_build_hull()
	for pd in data["parts"]:
		var p := Part.new()
		p.id = pd["id"]
		p.group = pd["group"]
		p.phase = int(pd["phase"])
		p.shape = pd["shape"]
		p.offset = Vector2(pd["x"], pd["y"])
		p.r = pd["r"]
		p.hp = pd["hp"]
		p.max_hp = p.hp
		if p.group != "skin":  # 해체 타일은 보스 체력 바에 넣지 않음(덤으로 벗기는 재미)
			total_hp += p.hp
		p.node = _make_part(p)
		add_child(p.node)
		parts.append(p)

func _poly(points: PackedVector2Array, fill: Color, edge: Color, width := 3.0) -> Node2D:
	var n := Node2D.new()
	var pg := Polygon2D.new()
	pg.polygon = points
	pg.color = fill
	n.add_child(pg)
	var ln := Line2D.new()
	var closed := points.duplicate()
	closed.append(points[0])
	ln.points = closed
	ln.width = width
	ln.default_color = edge
	ln.joint_mode = Line2D.LINE_JOINT_ROUND
	n.add_child(ln)
	return n

func _ngon(n: int, r: float, rot := 0.0, squash := Vector2.ONE) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := rot + TAU * i / n
		pts.append(Vector2(cos(a) * r * squash.x, sin(a) * r * squash.y))
	return pts

# 깨지지 않는 몸통: 고래 같은 넓은 선체 + 지느러미 날개
func _build_hull() -> void:
	var body := PackedVector2Array([Vector2(-150, -150), Vector2(150, -150), Vector2(250, -40), Vector2(300, 60),
		Vector2(200, 150), Vector2(60, 200), Vector2(-60, 200), Vector2(-200, 150), Vector2(-300, 60), Vector2(-250, -40)])
	add_child(_poly(body, hull_col, edge_col * 0.9, 5.0))
	for s in [-1, 1]:
		var fin := PackedVector2Array([Vector2(260 * s, -10), Vector2(350 * s, -90), Vector2(330 * s, 70)])
		add_child(_poly(fin, hull_col * 0.8, edge_col * 0.4, 3.0))
	# 선체 위 빛 줄(창문 같은 점선)
	for i in 9:
		var dot := _poly(_ngon(4, 5, PI / 4), edge_col * 1.2, edge_col * 1.2, 1.0)
		dot.position = Vector2(-160 + i * 40, 175)
		add_child(dot)

func _make_part(p: Part) -> Node2D:
	var n: Node2D
	match p.shape:
		"core":
			n = _poly(_ngon(8, p.r, PI / 8), Color(0.25, 0.08, 0.12), edge_col, 4.0)
			var eye := _poly(_ngon(16, p.r * 0.45), Color(2.6, 0.5, 0.25), Color(3.0, 1.6, 0.8), 2.0)
			n.add_child(eye)
		"gun":
			n = _poly(_ngon(6, p.r, 0.0, Vector2(1.0, 0.85)), hull_col * 1.4, edge_col, 3.0)
			var barrel := _poly(PackedVector2Array([Vector2(-12, 0), Vector2(12, 0), Vector2(9, 70), Vector2(-9, 70)]), hull_col * 0.7, edge_col * 0.8, 2.0)
			n.add_child(barrel)
			var mouth := _poly(_ngon(10, 9), Color(2.6, 0.8, 0.3), Color(2.6, 0.8, 0.3), 1.0)
			mouth.position = Vector2(0, 70)
			n.add_child(mouth)
		_:
			var pts := PackedVector2Array([Vector2(-p.r, -p.r * 0.6), Vector2(-p.r * 0.5, -p.r), Vector2(p.r * 0.5, -p.r),
				Vector2(p.r, -p.r * 0.6), Vector2(p.r, p.r * 0.6), Vector2(p.r * 0.5, p.r), Vector2(-p.r * 0.5, p.r), Vector2(-p.r, p.r * 0.6)])
			n = _poly(pts, Color(0.32, 0.34, 0.46), edge_col * 0.9, 3.0)
			var rivet := _poly(_ngon(4, 6, PI / 4), edge_col * 1.4, edge_col * 1.4, 1.0)
			n.add_child(rivet)
	n.position = p.offset
	return n

func part_world(p: Part) -> Vector2:
	return global_position + p.offset

func vulnerable(p: Part) -> bool:
	return p.alive and (p.phase == phase or p.phase == 0) and entering <= 0.0  # phase 0 = 해체 타일, 언제든 벗겨짐

func update(dt: float) -> void:
	if dead:
		return
	t += dt
	if entering > 0.0:
		entering -= dt
		position = position.lerp(home, 1.0 - pow(0.02, dt))
		return
	position = home + Vector2(sin(t * 0.55) * 95.0, sin(t * 1.1) * 16.0)
	for p in parts:
		if p.flash > 0.0:
			p.flash = maxf(0.0, p.flash - dt * 8.0)
			var f := 1.0 + p.flash * 2.5
			p.node.modulate = Color(f, f, f)
	_fire(dt)

func _fire(dt: float) -> void:
	var list: Array = data["phases"][phase - 1]["patterns"]
	for i in list.size():
		var pat: Dictionary = list[i]
		var key := "%d:%d" % [phase, i]
		var src := _part_by_id(pat["from"])
		if src == null or not src.alive:
			continue
		if not timers.has(key):
			timers[key] = float(pat.get("delay", 0.0)) + 0.6
			spin[key] = 0.0
		var sp: float = spin[key]
		if pat["kind"] == "spiral":
			sp += float(pat["spin_rate"]) * dt
			spin[key] = sp
		timers[key] -= dt
		if timers[key] > 0.0:
			continue
		timers[key] += float(pat["every"])
		var origin := part_world(src) + (Vector2(0, 70) if src.shape == "gun" else Vector2.ZERO)
		var ca: Array = pat["color"]
		var c := Color(ca[0], ca[1], ca[2])
		var speed: float = pat["speed"]
		match pat["kind"]:
			"fan":
				var base := PI / 2
				if pat.get("aim", false):
					base = (player_pos - origin).angle()
				var n: int = pat["count"]
				var spread := deg_to_rad(float(pat["spread"]))
				for j in n:
					var a: float = base + (spread * (float(j) / maxi(n - 1, 1) - 0.5) if n > 1 else 0.0)
					enemy.spawn(origin, Vector2.from_angle(a) * speed, 9.0, c)
			"ring":
				var n2: int = pat["count"]
				sp += deg_to_rad(float(pat.get("spin", 0.0)))
				spin[key] = sp
				for j in n2:
					enemy.spawn(origin, Vector2.from_angle(sp + TAU * j / n2) * speed, 8.0, c)
			"spiral":
				var arms: int = pat["arms"]
				for j in arms:
					enemy.spawn(origin, Vector2.from_angle(deg_to_rad(sp) + TAU * j / arms) * speed, 7.0, c)

func _part_by_id(id: String) -> Part:
	for p in parts:
		if p.id == id:
			return p
	return null

# 유도탄 목표: 지금 맞을 수 있는 큰 부위(장갑·포탑·핵) 중 가까운 곳, 없으면 해체 타일
func aim_point(from: Vector2) -> Vector2:
	var best := Vector2.INF
	var bd := INF
	for pass_skin in [false, true]:
		for p in parts:
			if vulnerable(p) and (p.group == "skin") == pass_skin:
				var d := part_world(p).distance_squared_to(from)
				if d < bd:
					bd = d
					best = part_world(p)
		if best != Vector2.INF:
			return best
	return best

# 내 탄이 부위에 맞았는지 처리. 피해를 준 총량을 돌려줌.
func take_hits(shots: Bullets, dmg: float) -> float:
	if dead or entering > 0.0:
		return 0.0
	var dealt := 0.0
	for k in shots.cap:
		if shots.life[k] <= 0.0:
			continue
		var bp := shots.pos[k]
		for p in parts:
			if not p.alive:
				continue
			var wp := part_world(p)
			if bp.distance_squared_to(wp) > (p.r + 6.0) * (p.r + 6.0):
				continue
			shots.kill(k)
			if vulnerable(p):
				var d := dmg * shots.dmg[k]  # 기체 무기마다 탄 한 발 피해가 다름
				p.hp -= d
				p.flash = 1.0
				dealt += d
				part_hit.emit(bp, d, false)
				if p.hp <= 0.0:
					_break(p)
			else:
				part_hit.emit(bp, 0.0, true)
			break
	return dealt

func _break(p: Part) -> void:
	p.alive = false
	var at := part_world(p)
	p.node.visible = false
	part_broken.emit(p, at)
	if p.group == "core":
		dead = true
		defeated.emit(at)
		return
	var left := false
	for q in parts:
		if q.alive and q.phase == phase:
			left = true
	if not left:
		phase += 1
		phase_changed.emit(phase)

func hp_fraction() -> float:
	var s := 0.0
	for p in parts:
		if p.alive and p.group != "skin":
			s += p.hp
	return s / total_hp
