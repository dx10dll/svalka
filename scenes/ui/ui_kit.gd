class_name Ui
extends RefCounted
## Общий вид интерфейса: тёмные полупрозрачные плашки, мелкий тёплый текст,
## янтарный акцент. Всё собирается кодом, чтобы вид был один на всю игру.

const TEXT := Color(0.93, 0.9, 0.82)
const DIM := Color(0.93, 0.9, 0.82, 0.55)
const ACCENT := Color(1.0, 0.75, 0.35)
const DANGER := Color(1.0, 0.42, 0.32)
const GOOD := Color(0.6, 0.95, 0.5)
const BACK := Color(0.05, 0.05, 0.06, 0.72)

const SIZE_SMALL: int = 12
const SIZE_TEXT: int = 14
const SIZE_TITLE: int = 16
const SIZE_BIG: int = 24


static func box(color: Color = BACK, margin: float = 8.0, radius: int = 5) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin + 2.0
	style.content_margin_right = margin + 2.0
	style.content_margin_top = margin * 0.6
	style.content_margin_bottom = margin * 0.6
	return style


## Плашка под содержимое: сама сжимается до его размера.
static func panel(color: Color = BACK, margin: float = 8.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override(&"panel", box(color, margin))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func label(text: String = "", size: int = SIZE_TEXT, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.text = text
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Клавиша в рамочке: «E», «ЛКМ».
static func key(text: String) -> PanelContainer:
	var p := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.75, 0.35, 0.16)
	style.border_color = Color(1.0, 0.75, 0.35, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 5.0
	style.content_margin_right = 5.0
	style.content_margin_top = 0.0
	style.content_margin_bottom = 0.0
	p.add_theme_stylebox_override(&"panel", style)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(label(text, SIZE_SMALL, ACCENT))
	return p


## Строка подсказок «E — сесть · ЛКМ — взять» превращается в ряд клавиш с подписями.
static func hint_row(text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var first: bool = true
	for part: String in text.split(" · "):
		if not first:
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(6, 0)
			row.add_child(gap)
		first = false
		var bits: PackedStringArray = part.split(" — ", true, 1)
		if bits.size() == 2:
			row.add_child(key(bits[0].strip_edges()))
			row.add_child(label(bits[1].strip_edges(), SIZE_SMALL))
		else:
			row.add_child(label(part.strip_edges(), SIZE_SMALL, ACCENT if part == part.to_upper() else TEXT))
	return row


## Тонкая полоска прогресса.
static func bar(width: float, height: float = 5.0, color: Color = ACCENT) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.min_value = 0.0
	b.max_value = 1.0
	b.custom_minimum_size = Vector2(width, height)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var back := StyleBoxFlat.new()
	back.bg_color = Color(1.0, 1.0, 1.0, 0.14)
	back.set_corner_radius_all(2)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(2)
	b.add_theme_stylebox_override(&"background", back)
	b.add_theme_stylebox_override(&"fill", fill)
	return b
