# 기체 목록(기획·난이도 담당 수치): 기체마다 기본 무기 성격이 다르고, 보석으로 언락한다.
# 내 탄 색은 청록·초록·흰파랑 계열만 — 적탄(주황·자홍·빨강)과 절대 헷갈리지 않게(사용자 원칙).
# 피해량은 boss.take_hits의 기본 피해(2.5)에 곱하는 배율. 초당 피해는 비슷하게, 느낌은 다르게.
class_name Ships

# 상위 기체일수록 확실히 좋게(사용자 기준): 무기 성격은 다르게 + 특성(방어막·작은 판정·목숨)과 피해가 단계마다 더 좋아짐.
# shield = 방어막이 다시 차는 초(0이면 없음), hitbox = 판정 반지름 px, lives = 목숨, power = 피해 배율.
const LIST := [
	{id = "striker", ko = "스트라이커", en = "Striker", price = 0, weapon = "triple",
		model = "res://assets/ships/Striker.gltf", tex = "",
		shield = 0.0, hitbox = 7.0, lives = 3, power = 1.0,
		desc_ko = "세 갈래 연사 · 특성 없음", desc_en = "Triple stream · no perk",
		shot = [0.45, 1.3, 2.0]},
	{id = "wide", ko = "와이드", en = "Wide", price = 300, weapon = "spread",
		model = "res://assets/ships/Striker.gltf", tex = "res://assets/ships/Striker_Green.png",
		shield = 30.0, hitbox = 7.0, lives = 3, power = 1.1,
		desc_ko = "다섯 갈래 부채 · 30초마다 방어막", desc_en = "5-way fan · shield every 30s",
		shot = [0.5, 2.0, 0.9]},
	{id = "lance", ko = "랜스", en = "Lance", price = 800, weapon = "lance",
		model = "res://assets/ships/Imperial.gltf", tex = "res://assets/ships/Imperial_Blue.png",
		shield = 20.0, hitbox = 5.0, lives = 3, power = 1.2,
		desc_ko = "굵은 한 줄기 · 20초마다 방어막 · 작은 판정", desc_en = "Heavy beam · shield 20s · small hitbox",
		shot = [1.3, 1.7, 2.4]},
	{id = "hunter", ko = "헌터", en = "Hunter", price = 1600, weapon = "homing",
		model = "res://assets/ships/Imperial.gltf", tex = "res://assets/ships/Imperial_Purple.png",
		shield = 15.0, hitbox = 5.0, lives = 4, power = 1.3,
		desc_ko = "유도 미사일 · 15초마다 방어막 · 작은 판정 · 목숨 4", desc_en = "Homing · shield 15s · small hitbox · 4 lives",
		shot = [0.4, 2.0, 1.5]},
]

# 보석 경제: 날아다니는 조각 10개 = 보석 1, 격파 보너스 30. 한 판 약 15(짐)~50(격파).
# 하루 무료 50 + 광고 50×3. 여러 판 하고 광고도 봐야 살 수 있게(사용자 기준) — 헌터까지 광고 보면 약 9일.
const SHARDS_PER_GEM := 10
const WIN_BONUS := 30
const DAILY_FREE := 50
const AD_REWARD := 50
const AD_MAX := 3

static func get_ship(id: String) -> Dictionary:
	for s in LIST:
		if s.id == id:
			return s
	return LIST[0]

static func label(s: Dictionary) -> String:
	return s.ko if Main.lang == "ko" else s.en

# 저장: 보석·가진 기체·고른 기체
const SAVE := "user://save.cfg"

static func load_save() -> ConfigFile:
	var cf := ConfigFile.new()
	cf.load(SAVE)
	return cf

static func owned(cf: ConfigFile) -> Array:
	return cf.get_value("ships", "owned", ["striker"])
