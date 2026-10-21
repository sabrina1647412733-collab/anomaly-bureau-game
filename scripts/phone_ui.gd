extends CanvasLayer
## 手机界面（出租屋开局）
## ---------------------------------------------------------------------------
## 锁屏 → 聊天（房东催债 / 陌生号码）→ 钱包 → 相册 → 通话记录
## 全部用 0017 那套视觉语言（暖橙 #e2a14a / 深底 / 细边框 / 无圆角）。
##
## 用法：
##   phone = PhoneUI.new(); add_child(phone)
##   phone.setup(font)
##   phone.open()   /   phone.close()
##   phone.closed 信号（玩家按 ESC 或点"锁屏"）

signal closed
signal opened_wallet
signal opened_album

const W := 380.0
const H := 720.0
const BG := Color(0.045, 0.050, 0.060, 0.97)
const EDGE := Color(0.886, 0.631, 0.29, 0.55)
const TEXT := Color(0.90, 0.92, 0.95)
const DIM := Color(0.48, 0.54, 0.61)
const ACCENT := Color(0.886, 0.631, 0.29)

var font: Font
var root: Control
var panel: Panel
var screen: Control          # 屏幕内容容器
var page := "lock"           # lock / chat / wallet / album / calls
var pages := {}              # page name -> Control

func setup(f: Font) -> void:
	font = f
	layer = 6
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	# 背景压暗
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)
	# 手机外壳
	panel = Panel.new()
	panel.position = Vector2(1600.0 * 0.5 - W * 0.5, 900.0 * 0.5 - H * 0.5)
	panel.size = Vector2(W, H)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.10, 0.12, 1.0)
	sb.border_color = Color(0.30, 0.33, 0.38, 1.0)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(26)
	panel.add_theme_stylebox_override("panel", sb)
	root.add_child(panel)
	# 屏幕
	var scr := ColorRect.new()
	scr.color = BG
	scr.position = Vector2(12, 44)
	scr.size = Vector2(W - 24, H - 96)
	scr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(scr)
	screen = Control.new()
	screen.position = scr.position
	screen.size = scr.size
	screen.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_child(screen)
	# 顶部听筒 + 底部返回
	var notch := _lab("23:40", 13, TEXT, Vector2(W * 0.5 - 30, 16), Vector2(60, 18))
	notch.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(notch)
	var back := _btn("‹  锁屏", Vector2(W * 0.5 - 60, H - 40), Vector2(120, 28), 12)
	back.pressed.connect(func(): close())
	panel.add_child(back)
	_build_pages()
	visible = false

func _build_pages() -> void:
	pages.clear()
	pages["lock"] = _build_lock()
	pages["chat"] = _build_chat()
	pages["wallet"] = _build_wallet()
	pages["album"] = _build_album()
	pages["calls"] = _build_calls()
	for k in pages.keys():
		var c: Control = pages[k]
		c.visible = (k == "lock")
		screen.add_child(c)

# ---------------------------------------------------------------- 锁屏
func _build_lock() -> Control:
	var c := Control.new()
	c.size = screen.size
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	var t := _lab("23:40", 54, Color(0.95, 0.96, 0.98), Vector2(0, 70), Vector2(screen.size.x, 64))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(t)
	var d := _lab("10 月 18 日 · 周六", 14, DIM, Vector2(0, 132), Vector2(screen.size.x, 22))
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(d)
	# 通知
	var n1 := _card(c, Vector2(14, 200), Vector2(screen.size.x - 28, 74),
		"房东", "这个月再不交就搬。", "刚刚", func(): _goto("chat"))
	var n2 := _card(c, Vector2(14, 286), Vector2(screen.size.x - 28, 74),
		"未知号码", "13 次未接来话", "23:12", func(): _goto("calls"))
	var n3 := _card(c, Vector2(14, 372), Vector2(screen.size.x - 28, 74),
		"钱包", "余额 ¥31.40", "", func(): _goto("wallet"))
	# 底部：上滑提示
	var hint := _lab("· 点击卡片进入 ·", 11, Color(0.35, 0.40, 0.46),
		Vector2(0, screen.size.y - 50), Vector2(screen.size.x, 20))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(hint)
	return c

# ---------------------------------------------------------------- 聊天
func _build_chat() -> Control:
	var c := Control.new()
	c.size = screen.size
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	c.add_child(_head("房东"))
	var msgs := [
		["房东", "在么", false],
		["房东", "这个月房租呢", false],
		["房东", "2160，欠了两个月了", false],
		["房东", "这个月再不交，你就搬走。", false],
		["我", "……知道了。", true],
		["房东", "我不是催你。", false],
		["房东", "但这楼里，最近不太对劲。", false],
		["房东", "你晚上别出门。", false],
	]
	var y := 62.0
	for m in msgs:
		var mine: bool = bool(m[2])
		var w := screen.size.x - 40
		var b := _bubble(c, String(m[1]), Vector2(20 if not mine else 40, y),
			Vector2(w - 20, 34), mine)
		y += 40.0
	# 底部输入条
	var bar := ColorRect.new()
	bar.color = Color(0.10, 0.11, 0.13)
	bar.position = Vector2(0, screen.size.y - 52)
	bar.size = Vector2(screen.size.x, 52)
	c.add_child(bar)
	var inp := _lab("发消息…", 13, DIM, Vector2(16, screen.size.y - 34), Vector2(200, 20))
	c.add_child(inp)
	var back := _btn("‹ 返回", Vector2(10, 2), Vector2(80, 26), 12)
	back.pressed.connect(func(): _goto("lock"))
	c.add_child(back)
	# 聊天里点房东头 = 去通话记录
	var calls := _btn("通话", Vector2(screen.size.x - 76, 2), Vector2(66, 26), 12)
	calls.pressed.connect(func(): _goto("calls"))
	c.add_child(calls)
	return c

# ---------------------------------------------------------------- 钱包
func _build_wallet() -> Control:
	var c := Control.new()
	c.size = screen.size
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	c.add_child(_head("钱包"))
	var big := _lab("¥ 31.40", 44, ACCENT, Vector2(0, 90), Vector2(screen.size.x, 56))
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(big)
	var sub := _lab("余额不足 · 距下次入账 3 天", 12, DIM, Vector2(0, 148), Vector2(screen.size.x, 20))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(sub)
	var rows := [
		["本月房租", "− ¥2,160.00", Color(0.85, 0.35, 0.30)],
		["上月房租", "− ¥2,160.00", Color(0.85, 0.35, 0.30)],
		["便利店夜班", "+ ¥ 180.00", Color(0.45, 0.75, 0.55)],
		["退瓶押金", "+ ¥  12.00", Color(0.45, 0.75, 0.55)],
	]
	var y := 210.0
	for r in rows:
		var row := ColorRect.new()
		row.color = Color(0.075, 0.085, 0.10)
		row.position = Vector2(14, y)
		row.size = Vector2(screen.size.x - 28, 46)
		c.add_child(row)
		var nm := _lab(String(r[0]), 13, TEXT, Vector2(28, y + 13), Vector2(180, 20))
		c.add_child(nm)
		var am := _lab(String(r[1]), 13, r[2], Vector2(screen.size.x - 170, y + 13), Vector2(140, 20))
		am.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		c.add_child(am)
		y += 54.0
	var note := _lab("三个月的房租，\n够一个人在这座城市里\n消失很久了。", 12,
		Color(0.45, 0.50, 0.56), Vector2(20, y + 20), Vector2(screen.size.x - 40, 80))
	c.add_child(note)
	var back := _btn("‹ 返回", Vector2(10, 2), Vector2(80, 26), 12)
	back.pressed.connect(func(): _goto("lock"))
	c.add_child(back)
	return c

# ---------------------------------------------------------------- 相册
func _build_album() -> Control:
	var c := Control.new()
	c.size = screen.size
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	c.add_child(_head("相册 · 3 张"))
	# 三张占位（用色块 + 说明，和 0017 的程序化美术一致）
	var items := [
		["福利院 · 2010", Color(0.28, 0.33, 0.30)],
		["父亲的调度席", Color(0.30, 0.26, 0.22)],
		["（这张是空的）", Color(0.10, 0.10, 0.12)],
	]
	var y := 70.0
	for it in items:
		var ph := ColorRect.new()
		ph.color = it[1]
		ph.position = Vector2(14, y)
		ph.size = Vector2(screen.size.x - 28, 120)
		c.add_child(ph)
		var cap := _lab(String(it[0]), 11, DIM, Vector2(20, y + 126), Vector2(240, 18))
		c.add_child(cap)
		y += 156.0
	var back := _btn("‹ 返回", Vector2(10, 2), Vector2(80, 26), 12)
	back.pressed.connect(func(): _goto("lock"))
	c.add_child(back)
	return c

# ---------------------------------------------------------------- 通话记录
func _build_calls() -> Control:
	var c := Control.new()
	c.size = screen.size
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	c.add_child(_head("通话记录"))
	var rows := [
		["未知号码", "未接 · 13 次", "23:12", true],
		["未知号码", "未接", "23:04", true],
		["房东", "已接 · 08:12", "08:12", false],
		["未知号码", "未接", "昨天 03:40", true],
	]
	var y := 66.0
	for r in rows:
		var row := ColorRect.new()
		row.color = Color(0.075, 0.085, 0.10)
		row.position = Vector2(14, y)
		row.size = Vector2(screen.size.x - 28, 52)
		c.add_child(row)
		var nm := _lab(String(r[0]), 13, TEXT if not bool(r[3]) else Color(0.85, 0.35, 0.30),
			Vector2(28, y + 8), Vector2(180, 18))
		c.add_child(nm)
		var sub := _lab(String(r[1]), 10, DIM, Vector2(28, y + 28), Vector2(180, 16))
		c.add_child(sub)
		var tm := _lab(String(r[2]), 10, DIM, Vector2(screen.size.x - 120, y + 18), Vector2(90, 16))
		tm.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		c.add_child(tm)
		y += 60.0
	var note := _lab("13 次。\n同一个号码，同一个不说话的呼吸声。", 12,
		Color(0.45, 0.50, 0.56), Vector2(20, y + 16), Vector2(screen.size.x - 40, 60))
	c.add_child(note)
	var back := _btn("‹ 返回", Vector2(10, 2), Vector2(80, 26), 12)
	back.pressed.connect(func(): _goto("lock"))
	c.add_child(back)
	return c

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

func _head(title: String) -> Control:
	var c := Control.new()
	c.size = Vector2(screen.size.x, 34)
	var t := _lab(title, 15, ACCENT, Vector2(96, 6), Vector2(180, 22))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	c.add_child(t)
	var line := ColorRect.new()
	line.color = EDGE
	line.position = Vector2(0, 34)
	line.size = Vector2(screen.size.x, 1)
	c.add_child(line)
	return c

func _card(parent: Control, pos: Vector2, sz: Vector2, title: String,
		body: String, when: String, cb: Callable) -> Button:
	var b := Button.new()
	b.position = pos
	b.size = sz
	b.flat = true
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.085, 0.095, 0.11, 0.96)
	sb.border_color = Color(1, 1, 1, 0.08)
	sb.set_border_width_all(1)
	b.add_theme_stylebox_override("normal", sb)
	var hov := sb.duplicate()
	hov.bg_color = Color(0.13, 0.14, 0.17, 0.98)
	hov.border_color = EDGE
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("pressed", hov)
	b.pressed.connect(cb)
	parent.add_child(b)
	var t := _lab(title, 12, ACCENT, Vector2(12, 8), Vector2(sz.x - 90, 18))
	b.add_child(t)
	var w := _lab(when, 9, DIM, Vector2(sz.x - 70, 10), Vector2(58, 14))
	w.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.add_child(w)
	var bd := _lab(body, 11, TEXT, Vector2(12, 30), Vector2(sz.x - 24, 38))
	b.add_child(bd)
	return b

func _bubble(parent: Control, text: String, pos: Vector2, sz: Vector2, mine: bool) -> Control:
	var c := Control.new()
	c.position = pos
	c.size = sz
	var bg := ColorRect.new()
	bg.color = Color(0.16, 0.19, 0.24) if mine else Color(0.11, 0.12, 0.15)
	bg.size = sz
	c.add_child(bg)
	var l := _lab(text, 12, TEXT, Vector2(10, 7), Vector2(sz.x - 20, sz.y - 12))
	c.add_child(l)
	parent.add_child(c)
	return c

func _btn(text: String, pos: Vector2, sz: Vector2, fs: int) -> Button:
	var b := Button.new()
	b.position = pos
	b.size = sz
	b.flat = true
	if font != null:
		b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", fs)
	b.add_theme_color_override("font_color", DIM)
	b.add_theme_color_override("font_hover_color", ACCENT)
	b.add_theme_color_override("font_pressed_color", ACCENT)
	return b

# ---------------------------------------------------------------- 开关 / 翻页
func open() -> void:
	visible = true
	page = "lock"
	_goto("lock")

func close() -> void:
	visible = false
	closed.emit()

func _goto(name: String) -> void:
	page = name
	for k in pages.keys():
		var c: Control = pages[k]
		c.visible = (k == name)
	match name:
		"wallet": opened_wallet.emit()
		"album": opened_album.emit()

func _unhandled_input(e: InputEvent) -> void:
	if not visible:
		return
	if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
