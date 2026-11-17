# 화면 표시(디자인 담당 파일): 보스 체력·이름 카드·점수·목숨·경고·결과.
class_name Hud
extends CanvasLayer

signal retry

var font: SystemFont
var boss_bar: ProgressBar
var boss_name: Label
var score_lbl: Label
var lives_lbl: Label
var banner: Label
var card: Label
var panel: PanelContainer
var panel_lbl: Label
var flash: ColorRect

func _ready() -> void:
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Apple SD Gothic Neo", "Noto Sans CJK KR", "Noto Sans KR", "sans-serif"])
	font.font_weight = 800
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new()
	th.default_font = font
	th.default_font_size = 30
	root.theme = th
	add_child(root)
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
	boss_name = _lbl("", 26)
	row.add_child(boss_name)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	score_lbl = _lbl("0", 30)
	row.add_child(score_lbl)
	boss_bar = ProgressBar.new()
	boss_bar.show_percentage = false
	boss_bar.custom_minimum_size = Vector2(0, 14)
	boss_bar.max_value = 1.0
	boss_bar.step = 0.0
	boss_bar.value = 1.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	bg.set_corner_radius_all(7)
	var fg := StyleBoxFlat.new()
	fg.bg_color = Color(2.2, 0.5, 0.3)
	fg.set_corner_radius_all(7)
	boss_bar.add_theme_stylebox_override("background", bg)
	boss_bar.add_theme_stylebox_override("fill", fg)
	boss_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(boss_bar)
	lives_lbl = _lbl("", 30)
	lives_lbl.position = Vector2(24, 130)
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
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
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

func show_result(text: String) -> void:
	panel_lbl.text = text
	panel.visible = true
