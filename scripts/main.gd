# 진입점: 장면을 코드로 짓고, 입력(손가락 그대로 따라감)·판 흐름·손맛(히트스톱·흔들림·진동)·자동 플레이·화면 저장을 맡는다.
# 실행 인자(-- 뒤): --auto(자동 플레이) --god(시험용 무적) --shot=경로 --shot-at=초 --quit-at=초 --lang=en --boss=iron_whale
class_name Main
extends Node2D

static var lang := "ko"

static func L(ko: String, en: String) -> String:
	return ko if lang == "ko" else en

var args := {}
var cam: Camera2D
var boss: Boss
var player: Player
var enemy: Bullets
var shots: Bullets
var fx: Fx
var hud: Hud
var view: View3D
var day := 0
var skin_sound_t := 0.0
var score := 0
var shake := 0.0
var hitstop_on := false
var touch_index := -1
var t := 0.0
var over := false
var auto := false
var shot_done := false
var hit_sound_t := 0.0
var num_t := 0.0
var num_acc := 0.0
var num_at := Vector2.ZERO
var stats_t := 0.0

func _ready() -> void:
	Engine.time_scale = 1.0
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	lang = args.get("lang", "ko" if OS.get_locale_language() == "ko" else "en")
	auto = args.has("auto")
	if args.has("shot"):
		# 촬영용: 창은 손톱만 하게 마지막 모니터 오른쪽 아래 구석에(사용자 작업 화면을 가리지 않게),
		# 그림은 창 크기와 무관하게 기준 해상도(가로 720)로 렌더해서 저장
		var w := get_window()
		w.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		w.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP  # 창이 어떤 모양이든 720×1280으로
		w.borderless = true
		w.size = Vector2i(36, 78)
		var sc := DisplayServer.get_screen_count() - 1
		w.position = DisplayServer.screen_get_position(sc) + DisplayServer.screen_get_size(sc) - w.size
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = false  # 실기기(mobile)에서 2D 글로우가 깜빡임·흐린 탄의 원인으로 의심 → 끄고 탄은 셰이더로 또렷하게
	env.glow_intensity = 0.9
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	cam = Camera2D.new()
	cam.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	add_child(cam)
	var dot := _dot_texture()
	enemy = Bullets.new()
	add_child(enemy)
	var bm := ShaderMaterial.new()
	bm.shader = load("res://shaders/bullet.gdshader")
	enemy.setup(1600, dot, Vector2(3.6, 3.6), bm)  # 판정보다 크게, 테두리 있는 또렷한 탄(빛 번짐 없이도 보이게)
	enemy.z_index = 5
	shots = Bullets.new()
	add_child(shots)
	shots.setup(500, dot, Vector2(1.6, 6.0))
	shots.z_index = 3
	boss = Boss.new()
	add_child(boss)
	boss.enemy = enemy
	# 기본은 오늘의 보스(결정 009 A). --boss=iron_whale 로 손으로 만든 보스, --day=YYYYMMDD 로 다른 날 보스.
	day = int(args.get("day", str(Daily.today())))
	if args.has("boss"):
		boss.load_boss("res://content/bosses/%s.json" % args["boss"])
	else:
		boss.load_data(Daily.make(day))
	boss.part_broken.connect(_on_part_broken)
	boss.phase_changed.connect(_on_phase)
	boss.defeated.connect(_on_defeated)
	boss.part_hit.connect(_on_part_hit)
	player = Player.new()
	player.shots = shots
	player.position = Vector2(360, 1060)
	player.z_index = 6
	add_child(player)
	# 그림은 3D 층이 맡고, 2D 보스·기체 몸통은 판정용으로만 남긴다(판정 점은 보이게 둠)
	boss.modulate = Color(1, 1, 1, 0)
	player.body.visible = false
	view = View3D.new()
	view.z_index = -50
	add_child(view)
	move_child(view, 0)
	view.setup(self)
	hud = Hud.new()
	add_child(hud)
	hud.retry.connect(func(): get_tree().reload_current_scene())
	fx = Fx.new()
	add_child(fx)
	fx.setup(hud.font_en, dot)
	fx.gem_collected.connect(func(n): if not over: score += n * 10)
	# 켜자마자: 경고 + 보스 등장(결정 007 — 첫 화면부터 터지게)
	var nm: Dictionary = boss.data["name"]
	var intro: Dictionary = boss.data["intro"]
	var daily := not args.has("boss")
	hud.boss_name.text = ("#%d  " % int(boss.data["week"])) + (nm["ko"] if lang == "ko" else nm["en"])
	hud.sub.text = ("DAILY BOSS #%d  ·  %s" if daily else "WEEK %02d  ·  %s") % [int(boss.data["week"]), String(nm["en"]).to_upper()]
	hud.show_banner("WARNING", Color(2.6, 0.4, 0.3), 0.7)
	hud.flash_screen(Color(1, 0.1, 0.05), 0.08)
	fx.play("warn", 1.0, -6.0)
	shake = 0.9
	get_tree().create_timer(1.0).timeout.connect(func(): hud.show_card("%s\n%s" % [nm[lang] if nm.has(lang) else nm["en"], intro[lang] if intro.has(lang) else intro["en"]]))
	lives_text()

func _dot_texture() -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 0.6, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	return gt

func lives_text() -> void:
	hud.lives_lbl.text = "♥".repeat(player.lives) + "♡".repeat(3 - player.lives)

func _input(e: InputEvent) -> void:
	if auto or over:
		return
	if e is InputEventScreenTouch:
		if e.pressed and touch_index == -1:
			touch_index = e.index
		elif not e.pressed and e.index == touch_index:
			touch_index = -1
	elif e is InputEventScreenDrag and e.index == touch_index:
		player.move_by(e.relative * 1.3)  # 손가락보다 조금 더 크게 움직여 엄지가 기체를 가리지 않게

func _process(delta: float) -> void:
	var real_dt := delta / maxf(Engine.time_scale, 0.001)
	t += real_dt
	if auto and not over:
		player.position = Vector2(360 + sin(t * 1.3) * 240.0, 1060 + sin(t * 0.7) * 60.0)
	boss.player_pos = player.position
	boss.update(delta)
	player.update(delta, not over and t > 0.35)
	enemy.update(delta)
	shots.update(delta)
	var dealt := 0.0 if over else boss.take_hits(shots, 2.5)  # 끝난 뒤 날아가던 탄이 결과를 바꾸지 않게
	if dealt > 0.0:
		score += int(dealt) * 3
	if not over and player.invuln <= 0.0 and enemy.hit_circle(player.position, Player.HITBOX) >= 0:
		_player_hit()
	fx.update(delta, player.position)
	view.sync(delta)
	hud.score_lbl.text = str(score)
	hud.boss_bar.value = boss.hp_fraction()
	# 카메라 흔들림(실제 시간 기준이라 히트스톱 중에도 흔들림)
	shake = maxf(0.0, shake - real_dt * 2.2)
	# 매 프레임 무작위로 튕기면 화면 전체가 깜빡여 보임(실기기 판정) → 부드러운 흔들림, 최대 약 12px
	cam.offset = Vector2(sin(t * 41.0) + 0.5 * sin(t * 97.0), cos(t * 37.0) + 0.5 * cos(t * 89.0)) * minf(shake, 1.2) * 6.0
	num_t -= real_dt
	if num_t <= 0.0 and num_acc > 0.0:
		num_t = 0.09
		fx.number(num_at, int(num_acc * 5.0), false)
		num_acc = 0.0
	hit_sound_t -= real_dt
	skin_sound_t -= real_dt
	_debug(real_dt)

func _on_part_hit(at: Vector2, amount: float, armored: bool) -> void:
	if armored:
		fx.burst("ping", at, 1.0)
		return
	num_acc += amount
	num_at = at
	if randf() < 0.18:
		fx.burst("spark", at, 0.6)
	if hit_sound_t <= 0.0:
		hit_sound_t = 0.06
		fx.play("shot", randf_range(0.9, 1.2), -16.0)

func _on_part_broken(p: Boss.Part, at: Vector2) -> void:
	view.part_broken(p, at)
	if p.group == "skin":
		# 해체 타일(결정 009 C): 작게·자주 터지는 손맛 — 히트스톱 없이 짧은 흔들림과 금속 소리
		shake = maxf(shake, 0.28)
		fx.burst("spark", at, 0.7)
		fx.shatter(at, p.r, Color(0.32, 0.34, 0.46), 4)
		fx.spawn_gems(at, 2, 120.0)
		score += 50
		if skin_sound_t <= 0.0:
			skin_sound_t = 0.05
			fx.play("metal", randf_range(1.4, 1.7), -12.0)
		_vibrate(8, 0.3)
		return
	var big := p.group != "armor"
	hitstop(0.09 if big else 0.06)
	shake = maxf(shake, 1.0 if big else 0.7)
	fx.burst("boom", at, 1.6 if big else 1.0)
	fx.burst("spark", at, 1.6)
	fx.burst("smoke", at, 1.2)
	fx.ring(at, p.r * 3.2, Color(2.6, 1.5, 0.6), 0.45, 12.0)
	fx.ring(at, p.r * 2.0, Color(3.0, 3.0, 3.0), 0.25, 6.0)
	fx.shatter(at, p.r, Color(0.32, 0.34, 0.46), 12 if big else 8)
	fx.spawn_gems(at, 30 if big else 16)
	fx.number(at + Vector2(0, -30), int(p.max_hp * 5.0), true)
	fx.play("metal", 0.8 if big else 1.0, 2.0)
	fx.play("boom", 1.0, 0.0)
	fx.play("glass", 1.2, -6.0)
	score += int(p.max_hp) * 10
	_vibrate(60 if big else 35, 0.9 if big else 0.6)

func _on_phase(ph: int) -> void:
	# 단계가 바뀌면 화면의 적탄이 모두 보석으로 바뀜(쾌감 + 숨 돌릴 틈)
	var left := enemy.clear_all()
	for i in left.size():
		if i % 3 == 0:
			fx.spawn_gems(left[i], 1, 60.0)
	hud.show_banner(L("%d단계!" % ph, "PHASE %d" % ph), Color(2.6, 1.8, 0.6), 0.5)
	fx.play("rumble", 0.6, 4.0)
	shake = maxf(shake, 1.2)

func _on_defeated(at: Vector2) -> void:
	over = true
	var left := enemy.clear_all()
	for i in left.size():
		if i % 2 == 0:
			fx.spawn_gems(left[i], 1, 80.0)
	Engine.time_scale = 0.25
	for k in 6:
		var p := at + Vector2(randf_range(-220, 220), randf_range(-120, 160))
		fx.burst("boom", p, 2.0)
		fx.ring(p, 260.0, Color(2.8, 1.6, 0.6), 0.6, 14.0)
		fx.play("boom", 0.8 + k * 0.05, 2.0)
		shake = 1.6
		await get_tree().create_timer(0.12, true, false, true).timeout
	boss.visible = false
	hud.flash_screen(Color(1, 1, 1), 0.6)
	Engine.time_scale = 1.0
	_vibrate(200, 1.0)
	hud.show_banner(L("격파!", "DEFEATED!"), Color(2.8, 2.2, 0.8), 1.2)
	await get_tree().create_timer(1.6).timeout
	var nm: Dictionary = boss.data["name"]
	var best := _record(score)
	hud.show_result(L("오늘의 보스 #%d\n%s 격파!\n\n점수 %d\n오늘 최고 %d\n시간 %.1f초\n\n내일은 새 보스가 와요", "Daily Boss #%d\n%s down!\n\nScore %d\nToday's best %d\nTime %.1fs\n\nA new boss arrives tomorrow") % [int(boss.data["week"]), nm[lang] if nm.has(lang) else nm["en"], score, best, t])
	print("RESULT win time=%.1f score=%d lives=%d" % [t, score, player.lives])

func _player_hit() -> void:
	if args.has("god"):  # 시험용 무적(끝까지 흐름 확인)
		return
	player.lives -= 1
	player.invuln = 2.0
	lives_text()
	hitstop(0.12)
	shake = 1.4
	hud.flash_screen(Color(1, 0.1, 0.1), 0.08)
	fx.burst("spark", player.position, 1.4)
	fx.ring(player.position, 90.0, Color(2.8, 0.6, 0.5), 0.35, 8.0)
	fx.play("thud", 0.7, 4.0)
	_vibrate(120, 1.0)
	# 맞으면 주변 적탄을 지워 숨 돌릴 틈
	for k in enemy.cap:
		if enemy.life[k] > 0.0 and enemy.pos[k].distance_to(player.position) < 260.0:
			enemy.kill(k)
	if player.lives <= 0:
		over = true
		player.visible = false
		var best := _record(score)
		hud.show_result(L("격추당했어요\n\n보스 체력 %d%% 남음\n점수 %d\n오늘 최고 %d", "Shot down\n\nBoss HP left %d%%\nScore %d\nToday's best %d") % [int(boss.hp_fraction() * 100), score, best])
		print("RESULT lose time=%.1f score=%d boss=%.2f" % [t, score, boss.hp_fraction()])

# 기기 안에 날짜별 최고 기록·도전 횟수 저장(1단계 — 순위표는 2단계 Firebase). 최고 기록을 돌려줌.
func _record(sc: int) -> int:
	if args.has("auto"):
		return sc
	var cf := ConfigFile.new()
	cf.load("user://daily.cfg")
	var key := str(day)
	var best := maxi(int(cf.get_value(key, "best", 0)), sc)
	cf.set_value(key, "best", best)
	cf.set_value(key, "tries", int(cf.get_value(key, "tries", 0)) + 1)
	cf.save("user://daily.cfg")
	return best

func hitstop(d: float) -> void:
	if hitstop_on:
		return
	hitstop_on = true
	Engine.time_scale = 0.04
	await get_tree().create_timer(d, true, false, true).timeout
	if not over or Engine.time_scale < 0.2:
		Engine.time_scale = 1.0
	hitstop_on = false

func _vibrate(ms: int, amp: float) -> void:
	if not auto:
		Input.vibrate_handheld(ms, amp)

func _debug(dt: float) -> void:
	if args.has("shot") and not shot_done and t >= float(args.get("shot-at", "3")):
		shot_done = true
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args["shot"])
		print("SHOT ", args["shot"], " window=", DisplayServer.window_get_position(), DisplayServer.window_get_size(), " screen=", DisplayServer.window_get_current_screen())
	if auto:
		stats_t += dt
		if stats_t >= 1.0:
			stats_t = 0.0
			print("STATS t=%.0f fps=%d phase=%d boss=%.2f bullets=%d gems=%d lives=%d" % [t, Engine.get_frames_per_second(), boss.phase, boss.hp_fraction(), enemy.alive_count, fx.gems.size(), player.lives])
	if args.has("quit-at") and t >= float(args["quit-at"]):
		get_tree().quit()
