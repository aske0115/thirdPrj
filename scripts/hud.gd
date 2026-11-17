# 화면 표시(디자인 담당 파일): 시간·파괴율·체력·분노 버튼·조이스틱·시작/결과 창.
class_name Hud
extends CanvasLayer

signal rage_pressed
signal retry_pressed

var time_lbl: Label
var pct_lbl: Label
var pct_bar: ProgressBar
var hp_bar: ProgressBar
var rage_btn: Button
var toast: Label
var overlay: PanelContainer
var overlay_lbl: Label
var retry_btn: Button
var joy: Control
var flash: ColorRect
var joy_anchor := Vector2.ZERO
var joy_vec := Vector2.ZERO
var joy_on := false

func _ready() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Apple SD Gothic Neo", "Noto Sans CJK KR", "Noto Sans KR", "sans-serif"])
	font.font_weight = 700
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 30
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme
	add_child(root)

	flash = ColorRect.new()
	flash.color = Color(1, 0.1, 0.05, 0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash)

	joy = Control.new()
	joy.set_anchors_preset(Control.PRESET_FULL_RECT)
	joy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joy.draw.connect(_draw_joy)
	root.add_child(joy)

	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 28
	top.offset_right = -28
	top.offset_top = 40
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	var row := HBoxContainer.new()
	top.add_child(row)
	time_lbl = _label("2:00", 44)
	row.add_child(time_lbl)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	pct_lbl = _label("0%", 44)
	row.add_child(pct_lbl)
	pct_bar = _bar(Color(1.0, 0.55, 0.2))
	top.add_child(pct_bar)
	hp_bar = _bar(Color(0.95, 0.25, 0.3))
	hp_bar.custom_minimum_size.y = 10
	top.add_child(hp_bar)

	toast = _label("", 40)
	toast.set_anchors_preset(Control.PRESET_CENTER)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.position.y -= 260
	toast.modulate.a = 0.0
	root.add_child(toast)

	rage_btn = Button.new()
	rage_btn.text = Main.L("쾅!", "SLAM!")
	rage_btn.custom_minimum_size = Vector2(170, 170)
	rage_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	rage_btn.offset_left = -210
	rage_btn.offset_top = -230
	rage_btn.offset_right = -40
	rage_btn.offset_bottom = -60
	rage_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 터치는 main._input에서 index로 처리(여러 손가락)
	root.add_child(rage_btn)
	set_rage(0.0)

	overlay = PanelContainer.new()
	overlay.set_anchors_preset(Control.PRESET_CENTER)
	overlay.custom_minimum_size = Vector2(560, 0)
	overlay.position = Vector2(-280, -220)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.12, 0.82)
	sb.set_corner_radius_all(24)
	sb.content_margin_left = 32
	sb.content_margin_right = 32
	sb.content_margin_top = 32
	sb.content_margin_bottom = 32
	overlay.add_theme_stylebox_override("panel", sb)
	root.add_child(overlay)
	var ov := VBoxContainer.new()
	ov.add_theme_constant_override("separation", 20)
	overlay.add_child(ov)
	overlay_lbl = _label("", 34)
	overlay_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ov.add_child(overlay_lbl)
	retry_btn = Button.new()
	retry_btn.text = Main.L("다시 하기", "Play again")
	retry_btn.custom_minimum_size.y = 90
	retry_btn.pressed.connect(func(): retry_pressed.emit())
	ov.add_child(retry_btn)

func _label(t: String, size: int) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _bar(col: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, 16)
	b.max_value = 1.0
	b.step = 0.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.45)
	bg.set_corner_radius_all(8)
	var fg := StyleBoxFlat.new()
	fg.bg_color = col
	fg.set_corner_radius_all(8)
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b

func show_overlay(text: String, with_retry: bool) -> void:
	overlay.visible = true
	overlay_lbl.text = text
	retry_btn.visible = with_retry

func hide_overlay() -> void:
	overlay.visible = false

func set_rage(v: float) -> void:
	rage_btn.disabled = v < 1.0
	rage_btn.modulate = Color(1, 1, 1, 0.35 + 0.65 * v)
	rage_btn.text = Main.L("쾅!", "SLAM!") if v >= 1.0 else "%d%%" % int(v * 100)

func say(t: String) -> void:
	toast.text = t
	toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(0.9)
	tw.tween_property(toast, "modulate:a", 0.0, 0.5)

func hurt() -> void:
	flash.color.a = 0.22
	create_tween().tween_property(flash, "color:a", 0.0, 0.25)

func _draw_joy() -> void:
	if not joy_on:
		return
	joy.draw_arc(joy_anchor, 110, 0, TAU, 48, Color(1, 1, 1, 0.25), 4)
	joy.draw_circle(joy_anchor + joy_vec * 110, 34, Color(1, 0.7, 0.4, 0.55))
