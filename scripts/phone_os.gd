extends CanvasLayer
signal closed
signal opened_wallet
signal opened_album
signal answer_requested
signal hangup_requested
signal stow_requested
signal reject_requested
signal tap
const WHITE := Color("e7dfcc")
const DIM := Color("b0ac9f")
const GREEN := Color("c5a878")
const FieldUI := preload("res://scripts/field_ui_style.gd")
var font: Font
var root: Control
var panel: Panel
var screen: Control
var page := "lock"
var pages := {}
var incoming := false
var call_active := false
var caller := "房东"
var call_text := "许砚，你总得给我个准话。两个月房租，一共2160元。今天先交一部分。我明天还得来。"
var messages: Dictionary = {}
var unread: Dictionary = {}
var active_chat := "房东"
var quiet := false
var clock_labels: Array[Label] = []
var message_banner: Button

func set_time(minutes: float) -> void:
	var m := int(minutes) % 1440
	clock_labels = clock_labels.filter(func(label): return is_instance_valid(label))
	for label in clock_labels:
		label.text = "%02d:%02d" % [m / 60, m % 60]

func setup(f: Font) -> void:
	font = f
	reset_messages()
	layer = 24
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var shade := ColorRect.new()
	shade.color = Color(0.005, 0.014, 0.018, 0.62)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)
	panel = box(root, Vector2(586, 55), Vector2(428, 790), Color("111514"), 32)
	panel.add_theme_stylebox_override("panel", style(Color("111514"), 32, Color("716b5c")))
	screen = Control.new()
	screen.position = Vector2(15, 51)
	screen.size = Vector2(398, 664)
	screen.clip_contents = true
	panel.add_child(screen)
	lab(panel, "23:40", Vector2(26, 18), Vector2(90, 22), 15)
	lab(panel, "▥  Wi-Fi  87%", Vector2(274, 18), Vector2(133, 22), 12, DIM)
	box(panel, Vector2(164, 13), Vector2(100, 21), Color("060b0b"), 10)
	_goto("lock")
	visible = false

func style(color: Color, radius := 12, edge := Color(1, 1, 1, 0.09)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = edge
	s.set_border_width_all(1 if edge.a>.2 else 0)
	s.set_corner_radius_all(radius)
	return s

func box(parent: Control, pos: Vector2, extent: Vector2, color: Color, radius := 12) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = extent
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", style(color, radius))
	parent.add_child(p)
	return p

func lab(parent: Control, value: String, pos: Vector2, extent: Vector2, fs := 18, color := WHITE) -> Label:
	var l := Label.new()
	l.text = value
	l.position = pos
	l.size = extent
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size",maxi(fs,21) if parent==screen else fs)
	l.add_theme_constant_override("line_spacing",7)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	# 文本/字体先设置时Label会按未换行全文扩宽，最后恢复指定边界。
	l.size = extent
	if value == "23:40":
		clock_labels.append(l)
	return l

func btn(parent: Control, value: String, pos: Vector2, extent: Vector2, cb: Callable, color := Color("2c332a")) -> Button:
	var b := Button.new()
	b.text = value
	b.position = pos
	b.size = extent
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 18)
	if parent==screen:b.add_theme_font_size_override("font_size",22)
	b.add_theme_color_override("font_color", WHITE)
	b.add_theme_stylebox_override("normal", style(color))
	for state_name in ["hover", "focus", "pressed"]:
		b.add_theme_stylebox_override(state_name, style(color.lightened(.12), 12, GREEN))
	b.pressed.connect(cb)
	b.pressed.connect(func(): tap.emit())
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	parent.add_child(b)
	return b

func header(title: String) -> void:
	btn(screen, "‹", Vector2(4, 0), Vector2(42, 40), func(): _goto("home"))
	lab(screen, title, Vector2(60, 7), Vector2(330, 40), 23)

func reset_messages() -> void:
	messages = {"房东":["两个月房租合计2160元。","今天先交一部分，明天我还得来。"]}
	unread = {}
	caller = "房东"
	active_chat = "房东"
	call_text = "许砚，你总得给我个准话。两个月房租，一共2160元。今天先交一部分。我明天还得来。"

func receive(who: String, value: String) -> void:
	if not messages.has(who): messages[who] = []
	messages[who].append(value)
	unread[who] = int(unread.get(who,0)) + 1
	if visible and page in ["chat","conversation","home"]:
		_goto(page)
	elif visible:
		if is_instance_valid(message_banner): message_banner.queue_free()
		message_banner = btn(screen,"收到短信 · "+who+"\n点击查看完整消息",Vector2(8,48),Vector2(382,88),func(): active_chat=who; _goto("conversation"),Color("343d2f"))
		message_banner.add_theme_font_size_override("font_size",15)
		message_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _goto(name: String) -> void:
	if call_active and name!="in_call":end_call()
	if is_instance_valid(message_banner):
		message_banner.queue_free()
		message_banner = null
	page = name
	for c in screen.get_children():
		screen.remove_child(c)
		c.queue_free()
	pages[name] = screen
	match name:
		"lock":
			box(screen, Vector2.ZERO, screen.size, Color("20251f"), 12)
			lab(screen, "23:40", Vector2(55, 72), Vector2(320, 88), 64)
			lab(screen, "10 月 18 日   夜间", Vector2(97, 166), Vector2(240, 30), 18, DIM)
			btn(screen, "微语  ·  房东\n这个月再不交就搬。", Vector2(18, 268), Vector2(362, 88), func(): _goto("chat"))
			btn(screen, caller + "\n" + ("来电中 · 点击接听" if incoming else "最近通话 · 房租"), Vector2(18, 372), Vector2(362, 88), func(): _goto("calls"))
			btn(screen, "解锁  ›", Vector2(98, 552), Vector2(202, 55), func(): _goto("home"))
		"home":
			box(screen, Vector2.ZERO, screen.size, Color("20251f"), 12)
			lab(screen, "23:40", Vector2(26, 35), Vector2(300, 70), 48)
			lab(screen, "临江里   ·   小雨  16°", Vector2(28, 112), Vector2(330, 32), 17, DIM)
			var unread_total := 0
			for count in unread.values(): unread_total += int(count)
			if unread_total > 0:
				btn(screen,"微语 · "+str(unread_total)+"条未读任务消息",Vector2(22,160),Vector2(354,45),func(): _goto("chat"),Color("36594b"))
			var apps := [["微语", "chat", "语", "3a8e70"], ["电话", "calls", "☎", "478d6a"], ["钱包", "wallet", "¥", "397da0"], ["相册", "album", "▧", "9478a1"], ["备忘录", "notes", "记", "b58b48"], ["地图", "map", "路", "547e68"], ["时钟", "clock", "◷", "50636e"], ["设置", "settings", "⚙", "657575"]]
			for i in range(apps.size()):
				var app: Array = apps[i]
				var pos := Vector2(27 + (i % 4) * 94, 220 + int(i / 4) * 144)
				var target: String = app[1]
				var button := btn(screen, app[2], pos, Vector2(62, 62), func(): _goto(target), Color(app[3]))
				button.add_theme_font_size_override("font_size", 29)
				var caption := lab(screen, app[0], pos + Vector2(-8, 75), Vector2(78, 30), 15)
				caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lab(screen, "●  ○", Vector2(176, 559), Vector2(100, 26), 16, DIM)
		"chat":
			header("微语")
			var contacts=ScrollContainer.new();contacts.position=Vector2(12,64);contacts.size=Vector2(374,535)
			contacts.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;screen.add_child(contacts)
			var stack=VBoxContainer.new();stack.custom_minimum_size.x=352;stack.add_theme_constant_override("separation",12);contacts.add_child(stack)
			for contact in messages:
				var who := String(contact)
				var description := String(messages[who].back()).left(14)
				var count := int(unread.get(who,0))
				var row=btn(stack,who+(" · %d"%count if count>0 else "")+"\n"+description,Vector2.ZERO,Vector2(352,96),func():active_chat=who;_goto("conversation"))
				row.custom_minimum_size=Vector2(352,96);row.add_theme_font_size_override("font_size",22)
				row.clip_text=true
		"conversation":
			header(active_chat)
			unread[active_chat] = 0
			var scroll := ScrollContainer.new()
			scroll.position = Vector2(12,64)
			scroll.size = Vector2(374,510)
			scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			screen.add_child(scroll)
			var stack := VBoxContainer.new()
			stack.custom_minimum_size.x = 352
			stack.add_theme_constant_override("separation",16)
			scroll.add_child(stack)
			for message in messages.get(active_chat,[]):
				var bubble := PanelContainer.new()
				bubble.add_theme_stylebox_override("panel",style(Color("30362b"),6))
				stack.add_child(bubble)
				var margin := MarginContainer.new()
				for edge in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,14)
				bubble.add_child(margin)
				var line := Label.new()
				line.custom_minimum_size.x = 314
				line.text = String(message)
				line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				line.add_theme_font_override("font",font)
				line.add_theme_font_size_override("font_size",22)
				line.add_theme_constant_override("line_spacing",7)
				margin.add_child(line)
			scroll.set_deferred("scroll_vertical",100000)
			lab(screen,"消息已保留，可随时回看。",Vector2(16,581),Vector2(364,30),17,DIM)
		"wallet":
			header("钱包")
			var owner_game = get_parent()
			var wages := 0
			var due := 2160
			if owner_game.laundry != null and owner_game.laundry.campaign != null:
				wages = int(owner_game.laundry.campaign.progress.earnings)
				due = int(owner_game.laundry.campaign.progress.rent_due)
			var left := 31.40 + float(maxi(0,wages-2160))
			box(screen, Vector2(18, 80), Vector2(362, 170), Color("235346"), 18)
			lab(screen, "零钱余额", Vector2(40, 102), Vector2(300, 30), 17, DIM)
			lab(screen, "¥ %.2f"%left, Vector2(40, 151), Vector2(320, 70), 43)
			lab(screen, "夜班工资累计       ¥%d\n\n已交房租            ¥%d\n\n剩余欠租            ¥%d\n\n原有零钱            ¥31.40" % [wages,2160-due,due], Vector2(25, 290), Vector2(350, 355), 19)
			opened_wallet.emit()
		"album":
			header("相册 · 3 张")
			for i in range(3):
				var pos := Vector2(20, 75 + i * 180)
				box(screen, pos, Vector2(358, 125), [Color("4e6358"), Color("5e5144"), Color("111e23")][i], 8)
				lab(screen, ["旧院子里的树影", "福利院合影：中间空了一个位置", "这张照片没有保存下来。"][i], pos + Vector2(18, 42), Vector2(322, 55), 19)
				lab(screen, ["福利院 · 2010", "那时，灯还是亮的。", "文件损坏 · 无法查看"][i], pos + Vector2(0, 134), Vector2(350, 30), 15, DIM)
			opened_album.emit()
		"calls", "incoming":
			header("电话")
			if incoming:
				var who=lab(screen, caller + "\n来电中", Vector2(24, 125), Vector2(350, 140), 31)
				who.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
				btn(screen, "接听", Vector2(24, 385), Vector2(162, 65), func(): incoming = false; answer_requested.emit(); _goto("in_call"), Color("384c3e"))
				btn(screen, "拒接", Vector2(212,385),Vector2(162,65),func(): reject_requested.emit(),Color("563c35"))
			else:
				lab(screen, "最近通话\n\n未知号码     未接 ×13\n23:12\n\n房东           已接\n08:12\n\n未知号码     未接\n昨天 03:40", Vector2(24, 90), Vector2(350, 450), 21)
			lab(screen, "仅显示本机通话记录。", Vector2(24, 570), Vector2(350, 40), 17, DIM)
		"in_call":
			header("通话中")
			var who=lab(screen, caller, Vector2(38,100),Vector2(322,65),32)
			who.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
			var status=lab(screen,"通话中",Vector2(38,178),Vector2(322,35),21,GREEN)
			status.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
			var transcript=ScrollContainer.new();transcript.name="CallTranscript";transcript.position=Vector2(26,250);transcript.size=Vector2(346,245)
			transcript.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;screen.add_child(transcript)
			var caption=Label.new();caption.name="CallCaption";caption.custom_minimum_size.x=322;caption.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			caption.text=call_text;caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;caption.add_theme_font_override("font",font)
			FieldUI.readable(caption,23);transcript.add_child(caption)
			btn(screen, "结束通话", Vector2(50, 527), Vector2(298, 58), func(): end_call(); _goto("home"), Color("563c35"))
		"notes":
			header("备忘录")
			lab(screen, "待办\n\n□ 找一份工作\n□ 房租 2,160 元\n□ 修好厨房的灯\n\n最后修改：昨天 02:13", Vector2(24, 85), Vector2(350, 460), 21)
		"map":
			header("离线地图")
			lab(screen, "临江里 · 老街", Vector2(24, 76), Vector2(350, 36), 24)
			for i in range(5):
				box(screen, Vector2(24 + (i % 2) * 186, 135 + i * 67), Vector2(164, 48), Color("203e3c"), 3)
			lab(screen, "●  临江里 17 号\n     得利洗衣店 · 2F", Vector2(36, 310), Vector2(330, 95), 23, GREEN)
			lab(screen, "离线缓存。位置无法更新。", Vector2(24, 568), Vector2(350, 45), 16, DIM)
		"clock":
			header("时钟")
			lab(screen, "23:40", Vector2(64, 140), Vector2(300, 90), 61)
			lab(screen, "闹钟\n\n04:00   交班\n\n07:30   找工作", Vector2(24, 310), Vector2(350, 270), 23, DIM)
		"settings":
			header("手机设置")
			lab(screen, "临江移动\n\n电池健康 87%\n存储空间  28.4 / 32 GB\n系统版本  12.6\n\n本机无可用更新。", Vector2(24, 90), Vector2(350, 300), 19)
			btn(screen, "通知：" + ("静音" if quiet else "响铃"), Vector2(24, 460), Vector2(350, 54), func(): quiet = not quiet; _goto("settings"))
	btn(screen,"主屏",Vector2(12,620),Vector2(174,40),func():_goto("home"),Color("30352c"))
	btn(screen,"B  收纳",Vector2(212,620),Vector2(174,40),func():stow_requested.emit(),Color("30352c"))

func open() -> void:
	visible = true
	_goto("incoming" if incoming else "lock")

func close() -> void:
	end_call()
	visible = false
	closed.emit()

func end_call() -> void:
	if not call_active: return
	call_active = false
	hangup_requested.emit()
	if visible and page=="in_call":_goto("calls")

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()
