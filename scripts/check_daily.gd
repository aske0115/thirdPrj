# 오늘의 보스 공정성 검사(데이터만 계산, 게임 안 띄움). 실행:
#   godot --headless --path . --script res://scripts/check_daily.gd
# 기준값은 손으로 만든 보스 content/bosses/iron_whale.json(사람이 PoC에서 피해 본 수준)의 최악값을 넘지 않게 잡았다.
# "봇이 산다"가 아니라 "사람이 틈을 눈으로 읽고 몸이 들어갈 시간이 있다"가 기준이다.
extends SceneTree

const DAYS := 60
const DIST := 700.0           # 보스 y≈300 ~ 기체 y≈1000
const HIT_R := 7.0            # 기체 판정 반지름
const SHOT_VIS := 2.8         # 탄 그림 반지름 = 판정 반지름 × 2.8
# iron_whale 최악값(주석은 근거)
const RING_ARC_MIN := 150.0   # 28발 고리: 2π·700/28=157px
const RING_VIS_GAP_MIN := 100.0  # 위 호 간격에서 탄 그림 지름(8×2.8×2=45) 뺀 값 ≈112
const RING_STEP_MIN := 228.0  # 연속 고리 사이 거리 speed×every: 190×1.2
const RATE_CAP := [20.0, 73.0, 90.0]  # 단계별 초당 탄 수: 1단계 20, 2단계 73, 3단계 90
const FAN_GAP_DEG := 8.5      # 탄 4발 이상 조준 부채꼴 탄 사이 각: 8.75°(70/8)
const FAN_GAP_DEG_SMALL := 7.0  # 3발 이하(14/2=7°)
const FAN_SPEED_MAX := 380.0  # 4발 이상 부채꼴 최고 속도(iron 380). 3발 이하는 520까지
const FAN_SPEED_SMALL := 520.0
const SPIRAL_ARM_GAP := 185.0 # 팔 사이 반지름 방향 간격 speed×(360/arms)/spin_rate: iron 최소 189(5팔 250·95)
const SPIRAL_SPIN_MAX := 140.0

func _init() -> void:
	var Daily = load("res://scripts/daily.gd")
	var bad := 0
	print("day       ph  rate  ringArc ringVis ringStep fanGap fanSpd spiralGap  verdict")
	for i in DAYS:
		var day := _add_days(Daily.EPOCH, i)
		var data: Dictionary = Daily.make(day)
		for pi in data.phases.size():
			var m := _measure(data.phases[pi].patterns)
			var errs: Array = []
			if m.rate > RATE_CAP[pi]: errs.append("rate")
			if m.ring_arc < RING_ARC_MIN: errs.append("ringArc")
			if m.ring_vis < RING_VIS_GAP_MIN: errs.append("ringVis")
			if m.ring_step < RING_STEP_MIN: errs.append("ringStep")
			if m.fan_gap_bad: errs.append("fanGap/speed")
			if m.spiral_gap < SPIRAL_ARM_GAP or m.spin > SPIRAL_SPIN_MAX: errs.append("spiral")
			if not errs.is_empty(): bad += 1
			print("%d  %d  %5.1f  %6.0f  %6.0f  %6.0f  %5.1f  %5.0f  %7.0f   %s" % [day, pi + 1, m.rate, m.ring_arc, m.ring_vis, m.ring_step, m.fan_gap, m.fan_spd, m.spiral_gap, "FAIL " + ",".join(errs) if not errs.is_empty() else "ok"])
	print("RESULT bad_phases=%d / %d" % [bad, DAYS * 3])
	quit(1 if bad > 0 else 0)

func _measure(pats: Array) -> Dictionary:
	var m := {rate = 0.0, ring_arc = INF, ring_vis = INF, ring_step = INF, fan_gap = INF, fan_spd = 0.0, fan_gap_bad = false, spiral_gap = INF, spin = 0.0}
	for p in pats:
		match p.kind:
			"fan":
				m.rate += float(p.count) / p.every
				if p.count > 1:
					var gap: float = float(p.spread) / (p.count - 1)
					var big: bool = p.count > 3
					m.fan_gap = minf(m.fan_gap, gap)
					m.fan_spd = maxf(m.fan_spd, p.speed)
					if gap < (FAN_GAP_DEG if big else FAN_GAP_DEG_SMALL) or p.speed > (FAN_SPEED_MAX if big else FAN_SPEED_SMALL):
						m.fan_gap_bad = true
			"ring":
				m.rate += float(p.count) / p.every
				var arc: float = TAU * DIST / p.count
				m.ring_arc = minf(m.ring_arc, arc)
				m.ring_vis = minf(m.ring_vis, arc - 2.0 * 8.0 * SHOT_VIS)
				m.ring_step = minf(m.ring_step, p.speed * p.every)
			"spiral":
				m.rate += float(p.arms) / p.every
				m.spiral_gap = minf(m.spiral_gap, p.speed * (360.0 / p.arms) / absf(p.spin_rate))
				m.spin = maxf(m.spin, absf(p.spin_rate))
	return m

func _add_days(base: int, n: int) -> int:
	var t := Time.get_unix_time_from_datetime_dict({year = base / 10000, month = base / 100 % 100, day = base % 100}) + n * 86400
	var d := Time.get_date_dict_from_unix_time(int(t))
	return d.year * 10000 + d.month * 100 + d.day
