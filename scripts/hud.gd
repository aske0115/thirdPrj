# 화면 표시(디자인 담당 파일): 보스 체력·이름 카드·점수·목숨·경고·결과.
class_name Hud
extends CanvasLayer

signal retry
signal ship_pressed(id: String)
signal free_pressed
signal ad_pressed

var font: Font
var font_en: Font
var sub: Label
var boss_bar: ProgressBar
var boss_name: Label
var score_lbl: Label
var lives_lbl: Label
var banner: Label
var card: Label
var panel: PanelContainer
var panel_lbl: Label
var flash: ColorRect
var ship_row: HBoxContainer
var ship_info: Label
var free_btn: Button
var ad_btn: Button

func _ready() -> void:
	font = load("res://assets/fonts/BlackHanSans-Regular.ttf")
	font_en = load("res://assets/fonts/Orbitron.ttf")
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new()
	th.default_font = font
	th.default_font_size = 30
	root.theme = th
	add_child(root)
	var vig := ColorRect.new()
	vig.set_anchors_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vm := ShaderMaterial.new()
	vm.shader = load("res://shaders/vignette.gdshader")
	vig.material = vm
	root.add_child(vig)
	var shade := TextureRect.new()
	var sg := Gradient.new()
	sg.set_color(0, Color(0.0, 0.0, 0.03, 0.85))
	sg.set_color(1, Color(0.0, 0.0, 0.03, 0.0))
	var sgt := GradientTexture2D.new()
	sgt.gradient = sg
	sgt.fill_from = Vector2(0.5, 0.0)
	sgt.fill_to = Vector2(0.5, 1.0)
	shade.texture = sgt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.set_anchors_preset(Control.PRESET_TOP_WIDE)
	shade.custom_minimum_size.y = 260
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	flash = ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1, 1, 1, 0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash)
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 24
	top.offset_right = -24
	top.offset_top = 56
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	var row := HBoxContainer.new()
	top.add_child(row)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", 0)
	row.add_child(names)
	boss_name = _lbl("", 36)
	names.add_child(boss_name)
	sub = _lbl("", 15)
	sub.add_theme_font_override("font", font_en)
	sub.add_theme_color_override("font_color", Color(1.0, 0.72, 0.45))
	names.add_child(sub)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	score_lbl = _lbl("0", 32)
	score_lbl.add_theme_font_override("font", font_en)
	row.add_child(score_lbl)
	boss_bar = ProgressBar.new()
	boss_bar.show_percentage = false
	boss_bar.custom_minimum_size = Vector2(0, 18)
	boss_bar.max_value = 1.0
	boss_bar.step = 0.0
	boss_bar.value = 1.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.04, 0.1, 0.8)
	bg.border_color = Color(1.0, 0.55, 0.25, 0.9)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(9)
	# 채움: 빨강→주황 그러데이션(시안과 같은 바)
	var fgr := Gradient.new()
	fgr.set_color(0, Color(1.0, 0.25, 0.15))
	fgr.set_color(1, Color(1.0, 0.75, 0.3))
	var fgt := GradientTexture2D.new()
	fgt.gradient = fgr
	fgt.fill_to = Vector2(1, 0)
	var fg := StyleBoxTexture.new()
	fg.texture = fgt
	fg.set_content_margin_all(0)
	fg.expand_margin_top = -3
	fg.expand_margin_bottom = -3
	boss_bar.add_theme_stylebox_override("background", bg)
	boss_bar.add_theme_stylebox_override("fill", fg)
	boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(boss_bar)
	lives_lbl = _lbl("", 30)
	lives_lbl.add_theme_color_override("font_color", Color(0.55, 0.95, 1.0))
	lives_lbl.position = Vector2(24, 150)
	root.add_child(lives_lbl)
	banner = _lbl("", 76)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.size = Vector2(720, 100)
	banner.position = Vector2(0, 560)
	banner.modulate.a = 0.0
	root.add_child(banner)
	card = _lbl("", 30)
	card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.size = Vector2(720, 120)
	card.position = Vector2(0, 680)
	card.modulate.a = 0.0
	root.add_child(card)
	panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.03, 0.1, 0.88)
	sb.set_corner_radius_all(26)
	for side in ["left", "right", "top", "bottom"]:
		sb.set("content_margin_" + side, 34)
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(90, 420)
	panel.custom_minimum_size = Vector2(540, 0)
	panel.visible = false
	root.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 22)
	panel.add_child(v)
	panel_lbl = _lbl("", 34)
	panel_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(panel_lbl)
	# 기체 고르기·언락 줄(결과 창에서 다음 판 기체를 정함)
	ship_info = _lbl("", 20)
	ship_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ship_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ship_info.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	v.add_child(ship_info)
	ship_row = HBoxContainer.new()
	ship_row.add_theme_constant_override("separation", 8)
	v.add_child(ship_row)
	# 보석 받기: 하루 무료 1회 + 광고 하루 3회
	var offers := HBoxContainer.new()
	offers.add_theme_constant_override("separation", 8)
	v.add_child(offers)
	free_btn = _offer_btn(Color(0.95, 0.75, 0.3))
	free_btn.pressed.connect(func(): free_pressed.emit())
	offers.add_child(free_btn)
	ad_btn = _offer_btn(Color(0.5, 0.9, 1.0))
	ad_btn.pressed.connect(func(): ad_pressed.emit())
	offers.add_child(ad_btn)
	var b := Button.new()
	b.text = Main.L("다시 도전", "Retry")
	b.custom_minimum_size.y = 96
	b.pressed.connect(func(): retry.emit())
	v.add_child(b)

func _lbl(t: String, size: int) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_constant_override("outline_size", 10)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0.05, 0.85))
	l.add_theme_color_override("font_shadow_color", Color(1.0, 0.45, 0.15, 0.3))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 0)
	l.add_theme_constant_override("shadow_outline_size", 16)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func show_banner(text: String, col: Color, hold := 0.6) -> void:
	banner.text = text
	banner.add_theme_color_override("font_color", col)
	banner.modulate.a = 1.0
	banner.scale = Vector2(1.4, 1.4)
	banner.pivot_offset = banner.size / 2
	var tw := create_tween()
	tw.tween_property(banner, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)
	tw.tween_interval(hold)
	tw.tween_property(banner, "modulate:a", 0.0, 0.35)

func show_card(text: String) -> void:
	card.text = text
	var tw := create_tween()
	tw.tween_property(card, "modulate:a", 1.0, 0.25)
	tw.tween_interval(2.2)
	tw.tween_property(card, "modulate:a", 0.0, 0.5)

func flash_screen(c: Color, a: float) -> void:
	flash.color = Color(c.r, c.g, c.b, a)
	create_tween().tween_property(flash, "color:a", 0.0, 0.22)

func _offer_btn(edge: Color) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 64)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 20)
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(14)
	sb.bg_color = Color(0.1, 0.09, 0.16)
	sb.border_color = edge
	sb.set_border_width_all(2)
	for st in ["normal", "hover", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_disabled_color", Color(0.45, 0.45, 0.55))
	return b

func set_offers(free_text: String, free_on: bool, ad_text: String, ad_on: bool) -> void:
	free_btn.text = free_text
	free_btn.disabled = not free_on
	ad_btn.text = ad_text
	ad_btn.disabled = not ad_on

func set_ships(items: Array, info: String) -> void:
	ship_info.text = info
	for c in ship_row.get_children():
		c.queue_free()
	for it in items:
		var b := Button.new()
		b.text = it.text
		b.custom_minimum_size = Vector2(0, 84)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 20)
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(14)
		if it.selected:
			sb.bg_color = Color(0.1, 0.35, 0.45)
			sb.border_color = Color(0.5, 1.0, 1.0)
			sb.set_border_width_all(3)
		elif it.locked:
			sb.bg_color = Color(0.12, 0.1, 0.18) if it.afford else Color(0.08, 0.07, 0.12)
			sb.border_color = Color(1.0, 0.8, 0.3) if it.afford else Color(0.3, 0.3, 0.4)
			sb.set_border_width_all(2)
		else:
			sb.bg_color = Color(0.12, 0.16, 0.26)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
		b.add_theme_color_override("font_color", Color(1, 1, 1) if not it.locked or it.afford else Color(0.55, 0.55, 0.65))
		var id: String = it.id
		b.pressed.connect(func(): ship_pressed.emit(id))
		ship_row.add_child(b)

func show_result(text: String) -> void:
	panel_lbl.text = text
	panel.visible = true
