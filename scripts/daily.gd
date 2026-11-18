# 오늘의 보스(결정 009 A): 날짜를 씨앗으로 보스 데이터를 만든다. 같은 날이면 전 세계 어느 기기든 같은 보스.
# 서버 없이 배포되는 대신, 같은 씨앗 → 같은 결과여야 하므로 이 파일 안에서는 전역 randf()를 쓰지 않는다.
# 시험: 실행 인자 --day=20261118
class_name Daily

const EPOCH := 20261118  # 오늘의 보스 #1

const ADJ := [["강철", "Iron"], ["붉은", "Crimson"], ["잠든", "Sleeping"], ["성난", "Raging"], ["녹슨", "Rusted"],
	["번개", "Thunder"], ["얼어붙은", "Frozen"], ["검은", "Black"], ["황금", "Golden"], ["울부짖는", "Howling"]]
const NOUN := [["고래", "Whale"], ["가오리", "Manta"], ["거북", "Turtle"], ["상어", "Shark"], ["해파리", "Jelly"],
	["까마귀", "Raven"], ["딱정벌레", "Beetle"], ["전갈", "Scorpion"], ["매", "Hawk"], ["뱀장어", "Eel"]]
const WARM := [[2.6, 0.9, 0.35], [2.6, 0.75, 0.3], [2.8, 0.6, 0.25], [2.6, 1.6, 0.4]]
# 적탄 색: 내 탄(청록·하늘색)과 헷갈리지 않게 파랑·청록 계열은 쓰지 않는다(사용자 원칙)
const COOL := [[1.0, 0.55, 2.6], [1.0, 0.6, 2.8], [2.8, 0.35, 0.6], [1.6, 0.5, 2.6]]

static func today() -> int:
	var d := Time.get_date_dict_from_system()
	return int(d.year) * 10000 + int(d.month) * 100 + int(d.day)

# 날짜(YYYYMMDD) → 오늘의 보스 번호(#1부터)
static func number(day: int) -> int:
	var a := Time.get_unix_time_from_datetime_dict({year = EPOCH / 10000, month = EPOCH / 100 % 100, day = EPOCH % 100})
	var b := Time.get_unix_time_from_datetime_dict({year = day / 10000, month = day / 100 % 100, day = day % 100})
	return int((b - a) / 86400) + 1

static func make(day: int) -> Dictionary:
	var r := RandomNumberGenerator.new()
	r.seed = hash("boss-rush-daily-%d" % day)
	var adj: Array = ADJ[r.randi() % ADJ.size()]
	var noun: Array = NOUN[r.randi() % NOUN.size()]
	var n := number(day)
	var hue := r.randf()
	var hull := Color.from_hsv(hue, 0.35, 0.32)
	var edge := Color.from_hsv(fmod(hue + 0.5, 1.0), 0.7, 1.0) * 2.2
	var parts := [{id = "core", group = "core", phase = 3, shape = "core", x = 0, y = 0, r = 62, hp = int(r.randf_range(850, 1050))}]
	var gx := r.randf_range(165, 230)
	var gy := r.randf_range(-80, -30)
	for s in [-1, 1]:
		parts.append({id = "gun_l" if s < 0 else "gun_r", group = "gun", phase = 2, shape = "gun", x = gx * s, y = gy, r = 46, hp = int(r.randf_range(260, 340))})
	# 장갑판: 앞쪽 호 위에 4~8장(핵 뒤로 숨지 않게 y > 60)
	var plates := r.randi_range(4, 8)
	var arc := r.randf_range(0.9, 1.25)
	var plate_hp := 280.0 / plates
	for i in plates:
		var a := PI / 2 + arc * (float(i) / (plates - 1) - 0.5) * 2.0
		parts.append({id = "plate%d" % (i + 1), group = "armor", phase = 1, shape = "plate", x = cos(a) * 270.0, y = sin(a) * 170.0 - 20.0, r = 38, hp = int(plate_hp * r.randf_range(0.85, 1.15))})
	# 해체 타일(결정 009 C): 선체를 덮은 작은 장갑. 언제든 벗겨지고 단계 진행과는 무관(phase 0).
	var k := 0
	for gy2 in range(-130, 171, 46):
		for gx2 in range(-275, 276, 50):
			var x := float(gx2) + (23.0 if (gy2 / 46) % 2 else 0.0)
			var y := float(gy2)
			if (x * x) / (290.0 * 290.0) + pow((y - 20.0) / 175.0, 2) > 1.0:
				continue
			if _near(parts, x, y):
				continue
			k += 1
			parts.append({id = "skin%d" % k, group = "skin", phase = 0, shape = "tile", x = x, y = y, r = 21, hp = 7})
	var warm: Array = WARM[r.randi() % WARM.size()]
	var cool: Array = COOL[r.randi() % COOL.size()]
	var phases := [
		{patterns = [_fan(r, "gun_l", warm, 0.0), _fan(r, "gun_r", warm, 0.55), _ring(r, "core", cool, 18, 1.6, 1.9)]},
		{patterns = [_gun2(r, "gun_l", warm, 1.0), _gun2(r, "gun_r", warm, -1.0), _fan(r, "core", cool, 0.0, 9, 70)]},
		{patterns = [_spiral(r, "core", warm, 5, 1.0, 0.085, 0.1), _ring(r, "core", cool, 28), _fan(r, "core", [2.8, 2.6, 2.2], 0.0, 3, 14, 520.0, 0.7)]},
	]
	return {
		id = "daily_%d" % day, day = day, week = n,
		name = {ko = "%s %s" % [adj[0], noun[0]], en = "%s %s" % [adj[1], noun[1]]},
		intro = {ko = "오늘의 보스 #%d — 전 세계가 같은 보스와 싸워요" % n, en = "Daily Boss #%d — everyone fights the same one today" % n},
		hull_color = [hull.r, hull.g, hull.b], edge_color = [edge.r, edge.g, edge.b],
		parts = parts, phases = phases,
	}

static func _near(parts: Array, x: float, y: float) -> bool:
	for p in parts:
		if Vector2(p.x, p.y).distance_to(Vector2(x, y)) < float(p.r) + 22.0:
			return true
	return false

# 아래 범위는 scripts/check_daily.gd 기준(iron_whale 최악값)을 넘지 않게 잡았다. 고치면 검사부터 돌릴 것.
static func _fan(r: RandomNumberGenerator, from: String, c: Array, delay: float, count := 0, spread := 0, speed := 0.0, every := 0.0) -> Dictionary:
	var n := count if count > 0 else r.randi_range(4, 5)
	# 탄 사이 각 9° 이상(옆으로 비킬 틈), 속도 380 이하
	var sp := spread if spread > 0 else roundi(r.randf_range(9.0, 11.0) * (n - 1))
	return {from = from, kind = "fan", count = n, spread = sp,
		speed = speed if speed > 0.0 else r.randf_range(300, 340), every = every if every > 0.0 else r.randf_range(1.2, 1.4), aim = true, delay = delay, color = c}

# 호 간격(700px 거리) 150 이상 → 최대 28발. 연속 고리 거리 speed×every 228 이상
static func _ring(r: RandomNumberGenerator, from: String, c: Array, count: int, every_lo := 1.2, every_hi := 1.7) -> Dictionary:
	return {from = from, kind = "ring", count = count + r.randi_range(-2, 0), speed = r.randf_range(190, 240), every = r.randf_range(every_lo, every_hi), spin = r.randf_range(4, 9), color = c}

# 팔 사이 반지름 간격 185 이상이 되도록 회전 속도 상한을 속도·팔 수로 계산
static func _spiral(r: RandomNumberGenerator, from: String, c: Array, arms: int, dir := 1.0, every_lo := 0.095, every_hi := 0.12) -> Dictionary:
	var speed := r.randf_range(240, 290)
	var hi := minf(140.0 if arms < 5 else 110.0, speed * 360.0 / arms / 190.0)
	return {from = from, kind = "spiral", arms = arms, speed = speed, every = r.randf_range(every_lo, every_hi), spin_rate = r.randf_range(90.0 if arms < 5 else 80.0, hi) * dir, color = c}

# 2단계 포탑: 날마다 나선이거나 빠른 부채꼴
static func _gun2(r: RandomNumberGenerator, from: String, c: Array, dir: float) -> Dictionary:
	if r.randf() < 0.6:
		return _spiral(r, from, c, 3, dir)
	var n := r.randi_range(5, 7)
	return _fan(r, from, c, 0.0 if dir > 0 else 0.35, n, roundi(r.randf_range(9.0, 10.5) * (n - 1)), r.randf_range(340, 380), r.randf_range(0.75, 0.9))
