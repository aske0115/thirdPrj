# 기체 목록(기획·난이도 담당 수치): 기체마다 기본 무기 성격이 다르고, 보석으로 언락한다.
# 내 탄 색은 청록·초록·흰파랑 계열만 — 적탄(주황·자홍·빨강)과 절대 헷갈리지 않게(사용자 원칙).
# 피해량은 boss.take_hits의 기본 피해(2.5)에 곱하는 배율. 초당 피해는 비슷하게, 느낌은 다르게.
class_name Ships

const LIST := [
	{id = "striker", ko = "스트라이커", en = "Striker", price = 0, weapon = "triple",
		model = "res://assets/ships/Striker.gltf", tex = "",
		desc_ko = "세 갈래 연사 · 무난한 기본기", desc_en = "Triple stream · all-rounder",
		shot = [0.45, 1.3, 2.0]},
	{id = "wide", ko = "와이드", en = "Wide", price = 400, weapon = "spread",
		model = "res://assets/ships/Striker.gltf", tex = "res://assets/ships/Striker_Green.png",
		desc_ko = "다섯 갈래 부채 · 장갑을 넓게 벗김", desc_en = "5-way fan · peels armor wide",
		shot = [0.5, 2.0, 0.9]},
	{id = "lance", ko = "랜스", en = "Lance", price = 900, weapon = "lance",
		model = "res://assets/ships/Imperial.gltf", tex = "res://assets/ships/Imperial_Blue.png",
		desc_ko = "굵은 한 줄기 · 한 곳을 빠르게 뚫음", desc_en = "Heavy beam · drills one spot",
		shot = [1.3, 1.7, 2.4]},
	{id = "hunter", ko = "헌터", en = "Hunter", price = 1600, weapon = "homing",
		model = "res://assets/ships/Imperial.gltf", tex = "res://assets/ships/Imperial_Purple.png",
		desc_ko = "유도 미사일 · 피하기에 집중해도 맞음", desc_en = "Homing missiles · hits while you dodge",
		shot = [0.4, 2.0, 1.5]},
]

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
