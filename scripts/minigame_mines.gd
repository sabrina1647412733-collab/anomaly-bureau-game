extends Control
## 值班室电脑：CRT 终端 + 扫雷 + 事故名单
signal closed

const N := 9
const MINES := 10
const NAMES := [
	"邵国平", "赵海生", "刘建军", "王德顺", "李长河",
	"周春生", "孙立民", "马国栋", "高志强", "何树林",
	"罗建平", "梁卫东", "宋新民", "郑长福", "谢文斌",
	"韩立国", "曹永强", "许国庆", "邓志明",
]

var font: Font
var mine := []
var opened := []
var flagged := []
var buttons := []
var started := false
var over := false
var won := false
var flag_count := 0
var status: Label
var grid: GridContainer
var file_view: Label
var tab_mines: Button
var tab_file: Button
var tab_notice: Button
var file_mode := "accident"
var style_cell: StyleBoxFlat
var style_cell_hover: StyleBoxFlat

func setup(f: Font) -> void:
	font = f
	_build()
	new_game()

func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.015, 0.02, 0.90)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var edge := ColorRect.new()
	edge.color = Color(0.88, 0.64, 0.29, 0.85)
	edge.position = Vector2(330, 70); edge.size = Vector2(940, 760)
	edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(edge)
	var panel := ColorRect.new()
	panel.color = Color(0.015, 0.055, 0.04, 0.98)
	panel.position = Vector2(338, 78); panel.size = Vector2(924, 744)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var title := _label("岚桥站 · 值班终端", 28, Color(0.55, 0.95, 0.70), Vector2(380, 98), Vector2(700, 40))
	title.add_theme_color_override("font_shadow_color", Color(0.1, 0.4, 0.25, 0.5))
	var sub := _label("2009.11.03 · 本地终端 / 无网络", 13, Color(0.30, 0.62, 0.45), Vector2(380, 140), Vector2(700, 24))
	tab_mines = _button("扫雷", Vector2(380, 178), Vector2(140, 38))
	tab_mines.pressed.connect(_show_mines)
	tab_file = _button("事故名单.txt", Vector2(532, 178), Vector2(190, 38))
	tab_file.pressed.connect(_show_file)
	tab_notice = _button("入职须知.txt", Vector2(684, 178), Vector2(190, 38))
	tab_notice.pressed.connect(_show_notice)
	var close := _button("关闭", Vector2(1130, 100), Vector2(100, 38))
	close.pressed.connect(func() -> void: closed.emit())
	_style_button(close)
	grid = GridContainer.new()
	grid.columns = N
	grid.position = Vector2(430, 240)
	grid.add_theme_constant_override("h_separation", 2)
	grid.add_theme_constant_override("v_separation", 2)
	add_child(grid)
	style_cell = StyleBoxFlat.new()
	style_cell.bg_color = Color(0.04, 0.13, 0.09)
	style_cell.border_color = Color(0.25, 0.62, 0.42)
	style_cell.set_border_width_all(1)
	style_cell.set_corner_radius_all(2)
	style_cell_hover = style_cell.duplicate()
	style_cell_hover.bg_color = Color(0.08, 0.22, 0.14)
	for y in range(N):
		for x in range(N):
			var b := Button.new()
			b.custom_minimum_size = Vector2(44, 44)
			b.focus_mode = Control.FOCUS_NONE
			b.mouse_filter = Control.MOUSE_FILTER_STOP
			b.add_theme_font_override("font", font)
			b.add_theme_font_size_override("font_size", 17)
			b.add_theme_color_override("font_color", Color(0.55, 0.95, 0.70))
			b.add_theme_stylebox_override("normal", style_cell)
			b.add_theme_stylebox_override("hover", style_cell_hover)
			b.add_theme_stylebox_override("pressed", style_cell_hover)
			b.gui_input.connect(_on_cell_input.bind(x, y))
			grid.add_child(b)
			buttons.append(b)
	status = _label("", 16, Color(0.55, 0.95, 0.70), Vector2(430, 690), Vector2(700, 28))
	var reset := _button("重新开始", Vector2(430, 728), Vector2(150, 38))
	reset.pressed.connect(new_game)
	_style_button(reset)
	file_view = _label("", 17, Color(0.60, 0.95, 0.72), Vector2(400, 230), Vector2(820, 470))
	file_view.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	file_view.visible = false
	file_view.text = _accident_text()
	var foot := _label("鼠标左键翻开 · 右键插旗 · Esc 退出", 12, Color(0.30, 0.62, 0.45), Vector2(430, 780), Vector2(700, 24))

func _label(text: String, fs: int, col: Color, pos: Vector2, size: Vector2) -> Label:
	var l := Label.new()
	if font != null:
		l.add_theme_font_override("font", font)
	l.text = text
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.position = pos; l.size = size
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l

func _button(text: String, pos: Vector2, size: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos; b.size = size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", Color(0.55, 0.95, 0.70))
	_style_button(b)
	add_child(b)
	return b

func _style_button(b: Button) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.13, 0.09)
	sb.border_color = Color(0.25, 0.62, 0.42)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	b.add_theme_stylebox_override("normal", sb)
	var hb := sb.duplicate()
	hb.bg_color = Color(0.08, 0.22, 0.14)
	b.add_theme_stylebox_override("hover", hb)
	b.add_theme_stylebox_override("pressed", hb)

func _names_text() -> String:
	var lines := []
	for i in range(NAMES.size()):
		var n := "%02d  %s" % [i + 1, NAMES[i]]
		if i % 3 == 2:
			lines.append(n)
		else:
			lines.append(n + "    ")
	var out := ""
	for i in range(lines.size()):
		out += lines[i]
		if i % 3 == 2:
			out += "\n"
	return out

func _accident_text() -> String:
	return "事故名单 · 2009.11.03 · 三道\n\n" + _names_text() + "\n\n官方报告：三道无人。\n\n—— 终端本地备份，未同步。"

func _notice_text() -> String:
	return "诡异事务局 · 临时入职须知（节选）\n\n01  不要相信站内广播的最后一句。\n02  若发现时间重复，请记录，不要纠正。\n03  你的权限是 D。D 级人员只需要活到交班。\n04  本局不存在。若有人问起，请回答：我在岚桥站上班。\n05  遇到 0017，先找那半秒。\n\n—— 外勤支援科 · 档案处\n（此文件不应出现在值班终端）"

func new_game() -> void:
	mine.clear(); opened.clear(); flagged.clear()
	for i in range(N * N):
		mine.append(false); opened.append(false); flagged.append(false)
	started = false; over = false; won = false; flag_count = 0
	grid.visible = true
	file_view.visible = false
	file_mode = "accident"
	file_view.text = _accident_text()
	if tab_mines != null:
		tab_mines.disabled = true
		tab_file.disabled = false
		if tab_notice != null:
			tab_notice.disabled = false
	status.text = "左键翻开 · 右键插旗 · 10 颗雷"
	for b in buttons:
		b.text = ""
		b.add_theme_color_override("font_color", Color(0.55, 0.95, 0.70))

func _show_mines() -> void:
	grid.visible = true
	file_view.visible = false
	tab_mines.disabled = true
	tab_file.disabled = false
	tab_notice.disabled = false

func _show_file() -> void:
	grid.visible = false
	file_view.visible = true
	file_mode = "accident"
	file_view.text = _accident_text()
	tab_mines.disabled = false
	tab_file.disabled = true
	tab_notice.disabled = false

func _show_notice() -> void:
	grid.visible = false
	file_view.visible = true
	file_mode = "notice"
	file_view.text = _notice_text()
	tab_mines.disabled = false
	tab_file.disabled = false
	tab_notice.disabled = true

func _idx(x: int, y: int) -> int:
	return y * N + x

func _inside(x: int, y: int) -> bool:
	return x >= 0 and x < N and y >= 0 and y < N

func _place_mines(sx: int, sy: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20091103
	var forbidden := {}
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if _inside(sx + dx, sy + dy):
				forbidden[_idx(sx + dx, sy + dy)] = true
	var placed := 0
	while placed < MINES:
		var x := rng.randi_range(0, N - 1)
		var y := rng.randi_range(0, N - 1)
		var i := _idx(x, y)
		if forbidden.has(i) or mine[i]:
			continue
		mine[i] = true
		placed += 1
	started = true

func _adj(x: int, y: int) -> int:
	var n := 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0: continue
			if _inside(x + dx, y + dy) and mine[_idx(x + dx, y + dy)]:
				n += 1
	return n

func _reveal(x: int, y: int) -> void:
	if over or not _inside(x, y): return
	var i := _idx(x, y)
	if opened[i] or flagged[i]: return
	if not started:
		_place_mines(x, y)
	if mine[i]:
		over = true
		status.text = "触雷 · 终端已锁死 · 按「重新开始」"
		for k in range(N * N):
			if mine[k]: opened[k] = true
		_refresh()
		return
	var stack: Array[Vector2i] = [Vector2i(x, y)]
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		var pi := _idx(p.x, p.y)
		if not _inside(p.x, p.y) or opened[pi] or flagged[pi] or mine[pi]:
			continue
		opened[pi] = true
		if _adj(p.x, p.y) == 0:
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dy == 0: continue
					if _inside(p.x + dx, p.y + dy) and not opened[_idx(p.x + dx, p.y + dy)]:
						stack.append(Vector2i(p.x + dx, p.y + dy))
	_check_win()
	_refresh()

func _toggle_flag(x: int, y: int) -> void:
	if over or not _inside(x, y): return
	var i := _idx(x, y)
	if opened[i]: return
	flagged[i] = not flagged[i]
	flag_count += 1 if flagged[i] else -1
	status.text = "剩余 %d 颗雷 · 左键翻开 · 右键插旗" % maxi(0, MINES - flag_count)
	_refresh()

func _check_win() -> void:
	var rest := 0
	for i in range(N * N):
		if not mine[i] and not opened[i]:
			rest += 1
	if rest == 0:
		won = true
		over = true
		status.text = "排雷完成 · 0017 次进路已锁"

func _refresh() -> void:
	for y in range(N):
		for x in range(N):
			var i := _idx(x, y)
			var b: Button = buttons[i]
			if opened[i]:
				if mine[i]:
					b.text = "X"
					b.add_theme_color_override("font_color", Color(1.0, 0.35, 0.28))
				else:
					var a := _adj(x, y)
					b.text = "" if a == 0 else str(a)
					var cols := [Color(0.55,0.95,0.70), Color(0.55,0.80,1.0), Color(0.95,0.80,0.40), Color(1.0,0.55,0.35), Color(1.0,0.40,0.40)]
					b.add_theme_color_override("font_color", cols[clampi(a - 1, 0, cols.size() - 1)])
			elif flagged[i]:
				b.text = "F"
				b.add_theme_color_override("font_color", Color(1.0, 0.72, 0.30))
			else:
				b.text = ""
				b.add_theme_color_override("font_color", Color(0.55, 0.95, 0.70))

func _on_cell_input(event: InputEvent, x: int, y: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_reveal(x, y)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			_toggle_flag(x, y)
			accept_event()