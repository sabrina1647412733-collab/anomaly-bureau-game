extends Control
const FieldUI := preload("res://scripts/field_ui_style.gd")
## 统一夜班界面。原 HUD Label 保留引用，便于玩法与验收复用。
const INK := Color("101c20")
const PAPER := Color("e5decb")
const TEXT := Color("e9e4d7")
const MUTED := Color("a7b8b5")
const ACCENT := Color("d5b67e")
var game
var subtitle: Panel
var objective: Panel
var choice_panel: Panel
var result: Panel
var dim: ColorRect
var controls: Label
var rate_label: Label
var choice_buttons: Array[Button] = []
var choice_details: Array[Label] = []
var return_button: Button
var _choice_was_open := false
var prompt_panel: Panel
var objective_help: Label
var unread_label: Label
var last_objective := ""
var top_shade:Control

func setup(g) -> void:
	game = g
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = Theme.new()
	theme.default_font = g.font
	theme.default_font_size = 18
	dim = ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.015, 0.025, 0.028, 0.86)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	top_shade=Control.new();top_shade.size=Vector2(1600,230);top_shade.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(top_shade)
	FieldUI.gradient(top_shade,true)
	objective = _panel(Vector2(40, 43), Vector2(730, 112), Color.TRANSPARENT, Color.TRANSPARENT)
	var accent:=ColorRect.new();accent.position=Vector2(0,12);accent.size=Vector2(2,76);accent.color=FieldUI.BRASS;objective.add_child(accent)
	_text(objective, "当前目标", Vector2(18, 0), Vector2(650, 28), 18, FieldUI.BRASS)
	g.hud_objective.reparent(objective)
	_place(g.hud_objective, Vector2(18, 35), Vector2(690, 78), 28, FieldUI.PAPER)
	FieldUI.readable(g.hud_objective,28)
	g.hud_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_help=_text(self,"H  展开调查详情",Vector2(58,157),Vector2(650,28),18,FieldUI.MUTED)
	g.hud_clock.position = Vector2(1338, 45)
	g.hud_clock.size = Vector2(218, 44)
	FieldUI.readable(g.hud_clock,38)
	subtitle = _panel(Vector2(0, 620), Vector2(1600, 280), Color.TRANSPARENT, Color.TRANSPARENT)
	FieldUI.gradient(subtitle)
	g.hud_sub_title.reparent(subtitle)
	_place(g.hud_sub_title, Vector2(300, 82), Vector2(1000, 32), 21, FieldUI.BRASS)
	g.hud_sub_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	g.hud_sub.reparent(subtitle)
	_place(g.hud_sub, Vector2(250, 130), Vector2(1100, 115), 32, FieldUI.PAPER)
	FieldUI.readable(g.hud_sub,32);g.hud_sub.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_text(subtitle, "空格 / 点击  继续", Vector2(1310, 244), Vector2(260, 28), 17, FieldUI.MUTED)
	prompt_panel=_panel(Vector2(540,490),Vector2(520,86),Color(.07,.08,.07,.83),Color.TRANSPARENT)
	g.hud_prompt.reparent(prompt_panel)
	_place(g.hud_prompt, Vector2(16, 10), Vector2(488, 68), 24, FieldUI.PAPER)
	g.hud_prompt.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	g.hud_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	g.hud_prompt.add_theme_color_override("font_shadow_color", Color.BLACK)
	g.hud_prompt.add_theme_constant_override("shadow_offset_y", 2)
	controls = _text(self, "B  背包    ·    ESC  暂停", Vector2(40, 852), Vector2(680, 32), 18, FieldUI.MUTED)
	rate_label = _text(self,"",Vector2(1248,98),Vector2(308,28),18,FieldUI.MUTED)
	rate_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	unread_label=_text(self,"",Vector2(1350,145),Vector2(206,28),18,FieldUI.BRASS)
	unread_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	_build_choice()
	_build_result()

func _place(label: Label, pos: Vector2, extent: Vector2, fs: int, color: Color) -> void:
	label.position = pos
	label.size = extent
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.add_theme_font_size_override("font_size", fs)
	label.add_theme_color_override("font_color", color)
	FieldUI.readable(label,fs,color)

func _style(fill: Color, edge: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = edge
	s.set_border_width_all(1)
	s.shadow_color = Color(0, 0, 0, 0.28)
	s.shadow_size = 0 if fill.a==0 else 16
	return s

func _panel(pos: Vector2, extent: Vector2, fill: Color, edge: Color) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = extent
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", _style(fill, edge))
	add_child(p)
	return p

func _text(parent: Control, value: String, pos: Vector2, extent: Vector2, fs: int, color: Color) -> Label:
	var l := Label.new()
	l.text = value
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(l, pos, extent, fs, color)
	parent.add_child(l)
	return l

func _build_choice() -> void:
	choice_panel = _panel(Vector2(280, 378), Vector2(1040, 282), INK, ACCENT.darkened(0.45))
	_text(choice_panel, "处置记录  /  00184", Vector2(28, 18), Vector2(940, 20), 12, ACCENT)
	_text(choice_panel, "是不是洗好了？", Vector2(28, 46), Vector2(940, 40), 27, TEXT)
	var names := ["认领", "顶替", "抹平"]
	var keys := ["E", "C", "R"]
	for i in range(3):
		var b := Button.new()
		b.position = Vector2(28 + 332 * i, 108)
		b.size = Vector2(320, 126)
		b.text = "[ %s ]   %s" % [keys[i], names[i]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 22)
		b.add_theme_color_override("font_color", TEXT)
		b.add_theme_color_override("font_disabled_color", Color("87918b"))
		for state_name in ["normal", "hover", "pressed", "focus", "disabled"]:
			var fill := Color("243633") if state_name in ["hover", "focus"] else Color("18272a")
			var style := _style(fill, ACCENT if state_name in ["hover", "focus"] else Color("4a5b57"))
			style.content_margin_left = 20
			style.content_margin_top = 2
			style.content_margin_bottom = 38
			b.add_theme_stylebox_override(state_name, style)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var kind: String = ["A", "C", "B"][i]
		b.pressed.connect(func(): game.laundry.choose_final(kind))
		choice_panel.add_child(b)
		choice_buttons.append(b)
		choice_details.append(_text(b, "", Vector2(20, 78), Vector2(284, 34), 13, MUTED))
	_text(choice_panel, "缺少物品的处置暂不可选。按键与点击均可确认。", Vector2(28, 250), Vector2(984, 20), 12, MUTED)

func _build_result() -> void:
	result = _panel(Vector2(310, 72), Vector2(980, 756), PAPER, Color("b5a88c"))
	_text(result, "诡异事务局   /   外勤支援科", Vector2(48, 30), Vector2(680, 24), 13, Color("666854"))
	var stamp := _text(result, "处置归档", Vector2(770, 28), Vector2(160, 32), 20, Color("8b4d3b"))
	stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	game.hud_end_title.reparent(result)
	_place(game.hud_end_title, Vector2(48, 92), Vector2(884, 82), 33, INK)
	game.hud_end_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var line := ColorRect.new()
	line.position = Vector2(48, 184)
	line.size = Vector2(884, 1)
	line.color = Color("aaa18b")
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_child(line)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(48, 210)
	scroll.size = Vector2(884, 442)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	result.add_child(scroll)
	game.hud_end.reparent(scroll)
	game.hud_end.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game.hud_end.custom_minimum_size = Vector2(840, 0)
	game.hud_end.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	game.hud_end.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	game.hud_end.add_theme_font_size_override("font_size", 19)
	game.hud_end.add_theme_constant_override("line_spacing", 6)
	game.hud_end.add_theme_color_override("font_color", INK)
	return_button = Button.new()
	return_button.position = Vector2(684, 680)
	return_button.size = Vector2(248, 46)
	return_button.text = "返回值班台   [ ESC ]"
	return_button.add_theme_color_override("font_color", TEXT)
	for state_name in ["normal", "hover", "pressed", "focus"]:
		return_button.add_theme_stylebox_override(state_name, _style(Color("314c47") if state_name in ["hover", "focus"] else INK, Color("728779")))
	return_button.pressed.connect(game._on_to_menu)
	result.add_child(return_button)
	_text(result, "第一季 · 补丁   /   得利洗衣店", Vector2(48, 694), Vector2(610, 24), 12, Color("666854"))

func _process(_delta: float) -> void:
	if game == null:
		return
	var ending: bool = game.case_mode == "laundry" and game.state == "case_end"
	var choosing: bool = game.choice == "case_final" and game.state == "case_choice"
	dim.visible = ending
	result.visible = ending
	choice_panel.visible = choosing
	objective.visible = game.hud_objective.visible and not ending
	var field_modal: bool = game.field_kit != null and game.field_kit.letter_ui.visible
	var field_clear:bool=game.state in ["prologue","play"] and not game.bag_open and not game.phone_open and not game.nb_open and not field_modal
	objective.visible=objective.visible and field_clear and game.sub.is_empty()
	top_shade.visible=field_clear and game.sub.is_empty()
	objective_help.visible=objective.visible and (game.case_mode=="laundry" or (game.case2_controller!=null and game.case2_controller.active))
	if objective.visible:
		game.hud_objective.text=game.hud_objective.text.trim_prefix("▸ ").replace("按 E ","")
		if game.hud_objective.text.contains("（") and game.hud_objective.text.contains("）："):
			game.hud_objective.text=game.hud_objective.text.get_slice("）：",1)
		if not last_objective.is_empty() and last_objective!=game.hud_objective.text:
			game.feedback.notify("目标已更新",game.hud_objective.text)
		last_objective=game.hud_objective.text
	subtitle.visible = game.sub != "" and game.state not in ["menu", "paused", "case_end"] and not game.phone_open and not game.bag_open and not field_modal
	controls.visible = field_clear and game.sub.is_empty()
	game.hud_prompt.visible = not choosing and not ending and game.state in ["prologue","play"] and not game.phone_open and not game.bag_open and not game.nb_open
	prompt_panel.visible=game.hud_prompt.visible and not game.hud_prompt.text.is_empty() and game.sub.is_empty()
	if prompt_panel.visible and game.prompt!=null:
		var item:String=String(game.prompt.get("id",""))
		var objects:Dictionary={"l_m7":"七号洗衣机","l_m9":"九号烘干机","l_price":"夜班工作须知","c1_photo":"303家庭照片","c1_lady":"周秀兰","c1_tools":"403维修挂板"}
		if objects.has(item):game.hud_prompt.text=objects[item]+"\nE  "+("交谈" if item=="c1_lady" else "查看")
	game.hud_clock.visible = game.hud_clock.visible and not ending
	rate_label.visible = game.hud_clock.visible and game.state not in ["menu","paused"] and (game.case_mode == "laundry" or game.state.begins_with("prologue"))
	var night:int=game.laundry.campaign.night_number() if game.laundry!=null else 1
	rate_label.text="10月%d日 · 第%d夜" % [17+night,night]
	if game.case2_controller!=null and game.case2_controller.active:rate_label.text="案卷 00201"
	var unread:int=0
	if game.phone_ui!=null:
		for value in game.phone_ui.unread.values():unread+=int(value)
	unread_label.text="短信 · %d" % unread
	unread_label.visible=unread>0 and game.state=="case_dialogue"
	if choosing:
		var can_a: bool = game.laundry.has_clue("sweater")
		var can_c: bool = game.bag_has("hoodie")
		choice_buttons[0].disabled = not can_a
		choice_buttons[1].disabled = not can_c
		choice_details[0].text = "将童装毛衣交还给她" if can_a else "尚未取得七号机里的毛衣"
		choice_details[1].text = "交出自己的灰色卫衣" if can_c else "尚未取得灰色卫衣"
		choice_details[2].text = "砸掉七号机，让她忘记"
		if not _choice_was_open:
			choice_buttons[0 if can_a else (1 if can_c else 2)].grab_focus()
	_choice_was_open = choosing
