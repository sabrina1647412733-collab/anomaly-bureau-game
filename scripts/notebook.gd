extends CanvasLayer
## 记事本（Tab 打开）· 四页：人 / 物 / 话 / 疑
## ---------------------------------------------------------------------------
## 剧本 9-E「收集与记录」：
##   人：这栋楼里出现过的人
##   物：拿到的东西（可看 3D 预览，这里做成条目 + 描述）
##   话：听到的对话、广播
##   疑：玩家自己标问号的地方（Q 键）
##
## 视觉沿用 0017 那套（暖橙 / 深底 / 细线 / 无圆角）。
## 用法：
##   nb = Notebook.new(); add_child(nb); nb.setup(font)
##   nb.add("物", "灰色卫衣", "没有牌子、没有尺码标。")
##   nb.toggle() / nb.open() / nb.close()
##   signal closed

signal closed

const W := 1020.0
const H := 700.0
const BG := Color(0.032, 0.036, 0.044, 0.96)
const EDGE := Color(0.886, 0.631, 0.29, 0.50)
const ACCENT := Color(0.886, 0.631, 0.29)
const TEXT := Color(0.88, 0.90, 0.93)
const DIM := Color(0.65, 0.70, 0.67)

const PAGES := ["物", "人", "话", "疑"]
const PAGE_EN := {"物": "OBJECTS", "人": "PEOPLE", "话": "WORDS", "疑": "DOUBTS"}

var font: Font
var root: Control
var panel: Panel
var page := 0
var entries := {"物": [], "人": [], "话": [], "疑": []}
var list_box: VBoxContainer
var detail: Label
var sel := -1
var tab_btns: Array = []
var detail_rows: Array = []
var detail_sel := 0

func setup(f: Font) -> void:
	font = f
	layer = 5
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)

	panel = Panel.new()
	panel.position = Vector2((1600 - W) * 0.5, (900 - H) * 0.5)
	panel.size = Vector2(W, H)
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG
	sb.border_color = EDGE
	sb.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", sb)
	root.add_child(panel)

	# 标题
	var t := _lab("记 事 本", 22, ACCENT, Vector2(34, 22), Vector2(300, 30))
	panel.add_child(t)
	var sub := _lab("NOTES · 第一案 · 得利洗衣店", 10, DIM, Vector2(36, 52), Vector2(420, 18))
	panel.add_child(sub)
	var hint := _lab("Tab 关闭   1-4 或 ←→ 翻页   ↑↓ 选条目", 10, DIM,
		Vector2(W - 440, 24), Vector2(410, 18))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	panel.add_child(hint)
	# 分隔线
	var line := ColorRect.new()
	line.color = EDGE
	line.position = Vector2(34, 78)
	line.size = Vector2(W - 68, 1)
	panel.add_child(line)

	# 四个页签
	for i in range(PAGES.size()):
		var b := Button.new()
		b.flat = true
		b.position = Vector2(34 + i * 238, 94)
		b.size = Vector2(226, 40)
		b.add_theme_font_override("font", font)
		b.add_theme_font_size_override("font_size", 16)
		var nm: String = PAGES[i]
		b.text = nm + "　" + PAGE_EN[nm]
		b.pressed.connect(func(): _go(i))
		panel.add_child(b)
		tab_btns.append(b)
	# 左：条目列表
	var sc := ScrollContainer.new()
	sc.position = Vector2(34, 150)
	sc.size = Vector2(400, H - 190)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(sc)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 4)
	list_box.custom_minimum_size = Vector2(390, 0)
	sc.add_child(list_box)
	# 右：详情
	var rline := ColorRect.new()
	rline.color = Color(1, 1, 1, 0.06)
	rline.position = Vector2(452, 150)
	rline.size = Vector2(1, H - 190)
	panel.add_child(rline)
	detail = _lab("", 18, TEXT, Vector2(478, 152), Vector2(W - 512, H - 200))
	detail.add_theme_constant_override("line_spacing", 8)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	panel.add_child(detail)

	visible = false

# ---------------------------------------------------------------- 数据
func add(cat: String, title: String, body := "", once := true) -> void:
	if not entries.has(cat):
		return
	for e in entries[cat]:
		if once and String(e["t"]) == title:
			return
	entries[cat].append({"t": title, "b": body})
	if visible:
		_refresh()

func has(cat: String, title: String) -> bool:
	if not entries.has(cat):
		return false
	for e in entries[cat]:
		if String(e["t"]) == title:
			return true
	return false

func count(cat: String) -> int:
	return entries.get(cat, []).size()

func total() -> int:
	var n := 0
	for k in entries.keys():
		n += entries[k].size()
	return n

# ---------------------------------------------------------------- 开关 / 翻页
func toggle() -> void:
	if visible: close()
	else: open()

func open() -> void:
	visible = true
	_refresh()

func close() -> void:
	visible = false
	closed.emit()

func _go(i: int) -> void:
	page = clampi(i, 0, PAGES.size() - 1)
	detail_sel = 0
	_refresh()

func _refresh() -> void:
	for i in range(tab_btns.size()):
		var b: Button = tab_btns[i]
		var on := (i == page)
		b.add_theme_color_override("font_color", ACCENT if on else DIM)
		b.add_theme_color_override("font_hover_color", ACCENT)
		b.add_theme_color_override("font_pressed_color", ACCENT)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.886, 0.631, 0.29, 0.12 if on else 0.0)
		sb.border_color = Color(0.886, 0.631, 0.29, 0.85 if on else 0.0)
		sb.border_width_bottom = 1
		b.add_theme_stylebox_override("normal", sb)
	# 列表
	for c in list_box.get_children():
		c.queue_free()
	var cat: String = PAGES[page]
	var arr: Array = entries[cat]
	if arr.is_empty():
		var e := _lab("（这一页还是空的）", 12, Color(0.34, 0.39, 0.45), Vector2(4, 8), Vector2(360, 40))
		list_box.add_child(e)
		detail.text = _empty_hint(cat)
		return
	for i in range(arr.size()):
		var it: Dictionary = arr[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(390, 40)
		b.flat = true
		b.add_theme_font_override("font", font)
		b.add_theme_font_size_override("font_size", 13)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "  %02d   %s" % [i + 1, String(it["t"])]
		var on := (i == detail_sel)
		b.add_theme_color_override("font_color", ACCENT if on else TEXT)
		b.add_theme_color_override("font_hover_color", ACCENT)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.886, 0.631, 0.29, 0.10 if on else 0.0)
		sb.border_color = Color(0.886, 0.631, 0.29, 0.60 if on else 0.0)
		sb.border_width_left = 2 if on else 0
		b.add_theme_stylebox_override("normal", sb)
		var idx := i
		b.pressed.connect(func(): detail_sel = idx; _refresh())
		list_box.add_child(b)
	# 详情
	var cur: Dictionary = arr[clampi(detail_sel, 0, arr.size() - 1)]
	detail.text = "【%s】\n\n%s" % [String(cur["t"]), String(cur["b"])]

func _empty_hint(cat: String) -> String:
	match cat:
		"物": return "还没有拿到东西。\n看到可疑的、能带走的，[E] 拿起来。"
		"人": return "还没有遇到人。\n这栋楼里本来不该有人。"
		"话": return "还没听见什么。\n这里能听到的，多半不是你该听的。"
		"疑": return "还没有标记。\n对着任何东西按 [Q]，把问号记下来。"
	return ""

# ---------------------------------------------------------------- 输入
func _unhandled_input(e: InputEvent) -> void:
	if not visible:
		return
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_TAB, KEY_ESCAPE:
				close()
			KEY_LEFT:
				_go(page - 1)
			KEY_RIGHT:
				_go(page + 1)
			KEY_1, KEY_2, KEY_3, KEY_4:
				_go(e.keycode - KEY_1)
			KEY_UP:
				detail_sel = maxi(0, detail_sel - 1)
				_refresh()
			KEY_DOWN:
				var n: int = entries[PAGES[page]].size()
				detail_sel = mini(maxi(0, n - 1), detail_sel + 1)
				_refresh()
			_:
				return
		get_viewport().set_input_as_handled()

# ---------------------------------------------------------------- 控件工厂
func _lab(text: String, fs: int, col: Color, pos: Vector2, sz: Vector2) -> Label:
	var l := Label.new()
	if font != null:
		l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.text = text
	l.position = pos
	l.size = sz
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
