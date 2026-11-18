# 졸병(결정 012): 보스가 데리고 나오는 작은 적. 무기마다 활약할 표적을 만든다.
#   fighter(편대 전투기) — 떼로 내려오며 가끔 한 발씩: 부채꼴(와이드)이 유리
#   mine(기뢰)          — 천천히 떠다니다 안 부수면 고리 탄으로 터짐: 유도탄(헌터)이 유리
#   drone(방패 드론)     — 핵 주위를 돌며 내 탄을 막음: 굵은 탄(랜스)이 유리
# 판정은 2D(화면 좌표), 그림은 View3D가 3D 모델로. 졸병 몸에 닿아도 피해는 없음(탄만 위험 — 공정성).
class_name Minions
extends Node

class M:
	var kind: String
	var pos: Vector2
	var vel := Vector2.ZERO
	var r: float
	var hp: float
	var t := 0.0
	var fire_t := 0.0
	var phase := 0.0   # 드론 공전 각, 편대 흔들림 위상
	var alive := true

signal spawned(m: M)
signal died(m: M, killed: bool)

const STATS := {fighter = {r = 20.0, hp = 6.0, shards = 3}, mine = {r = 22.0, hp = 14.0, shards = 5}, drone = {r = 24.0, hp = 30.0, shards = 8}}
const MINE_FUSE := 4.5        # 이 시간 안에 못 부수면 터짐
const FIGHTER_SHOT_EVERY := 1.8
const SHOT_COL := Color(2.6, 0.9, 0.35)

var list: Array[M] = []
var boss: Boss
var enemy: Bullets
var player_pos := Vector2(360, 1000)
var plan: Array = []      # 단계별 [{kind, every, count}] (보스 데이터 "minions")
var timers := {}

func update(dt: float) -> void:
	if boss.dead or boss.entering > 0.0:
		return
	var ph: Array = plan[boss.phase - 1] if boss.phase - 1 < plan.size() else []
	for i in ph.size():
		var w: Dictionary = ph[i]
		var key := "%d:%d" % [boss.phase, i]
		if not timers.has(key):
			timers[key] = float(w.get("delay", 2.0))
		timers[key] -= dt
		if timers[key] <= 0.0:
			timers[key] += float(w.every) if float(w.every) > 0.0 else INF  # every 0 = 단계 시작에 한 번
			_wave(w.kind, int(w.count))
	for m in list:
		if not m.alive:
			continue
		m.t += dt
		match m.kind:
			"fighter":
				m.pos += m.vel * dt
				m.pos.x += sin(m.t * 2.2 + m.phase) * 70.0 * dt
				m.fire_t -= dt
				if m.fire_t <= 0.0 and m.pos.y > 80.0 and m.pos.y < 760.0:
					m.fire_t = FIGHTER_SHOT_EVERY
					enemy.spawn(m.pos, (player_pos - m.pos).normalized() * 200.0, 8.0, SHOT_COL)
				if m.pos.y > 1360.0:
					_remove(m, false)
			"mine":
				m.pos += m.vel * dt
				m.vel *= pow(0.5, dt)
				if m.t >= MINE_FUSE:
					for j in 10:  # 느린 고리 — 틈이 넓어 사람이 피할 수 있게
						enemy.spawn(m.pos, Vector2.from_angle(TAU * j / 10.0 + m.phase) * 150.0, 8.0, Color(1.0, 0.55, 2.6))
					_remove(m, false)
			"drone":
				var core := _core_pos()
				m.phase += dt * 1.1
				m.pos = core + Vector2.from_angle(m.phase) * 120.0
	list = list.filter(func(x: M) -> bool: return x.alive)

func _core_pos() -> Vector2:
	for p in boss.parts:
		if p.group == "core":
			return boss.part_world(p)
	return boss.global_position

func _wave(kind: String, n: int) -> void:
	var core := _core_pos()
	for i in n:
		var m := M.new()
		m.kind = kind
		m.r = STATS[kind].r
		m.hp = STATS[kind].hp
		match kind:
			"fighter":  # 화면 위 한쪽에서 V자로 내려옴
				var side := -1.0 if randi() % 2 else 1.0
				m.pos = Vector2(360.0 + side * (120.0 + i * 40.0), -40.0 - i * 50.0)
				m.vel = Vector2(-side * 30.0, 240.0)
				m.phase = i * 0.7
				m.fire_t = 0.8 + i * 0.25
			"mine":  # 보스에서 아래로 흩뿌림
				m.pos = core + Vector2(randf_range(-60, 60), 40)
				m.vel = Vector2.from_angle(PI / 2 + (i - (n - 1) / 2.0) * 0.5) * 260.0
				m.phase = randf() * TAU
			"drone":
				m.phase = TAU * i / n
				m.pos = core + Vector2.from_angle(m.phase) * 120.0
		list.append(m)
		spawned.emit(m)

func _remove(m: M, killed: bool) -> void:
	m.alive = false
	died.emit(m, killed)

func clear() -> void:
	for m in list:
		if m.alive:
			_remove(m, false)
	list.clear()

# 내 탄이 졸병에 맞았는지. 맞은 탄은 없어짐(드론이 탄을 막는 원리). 준 피해 합을 돌려줌.
func take_hits(shots: Bullets, dmg: float) -> float:
	if list.is_empty():
		return 0.0
	var dealt := 0.0
	for k in shots.cap:
		if shots.life[k] <= 0.0:
			continue
		var bp := shots.pos[k]
		for m in list:
			if not m.alive or bp.distance_squared_to(m.pos) > (m.r + 6.0) * (m.r + 6.0):
				continue
			shots.kill(k)
			var d := dmg * shots.dmg[k]
			m.hp -= d
			dealt += d
			if m.hp <= 0.0:
				_remove(m, true)
			break
	return dealt

# 유도탄 목표: 가장 가까운 졸병(없으면 INF)
func nearest(from: Vector2) -> Vector2:
	var best := Vector2.INF
	var bd := INF
	for m in list:
		if m.alive and m.pos.y > 0.0:
			var d := m.pos.distance_squared_to(from)
			if d < bd:
				bd = d
				best = m.pos
	return best
