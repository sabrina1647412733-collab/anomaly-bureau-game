extends Control
## Field inventory presentation. Item ownership and story remain in field_items/game.
signal item_selected(id: String)
signal take_requested
signal close_requested
const CATEGORIES := ["道具", "线索", "钥匙", "衣物"]
const PAPER := Color("e1d9c7")
const MUTED := Color("99988b")
const BRASS := Color("bba16e")
const ART := "res://assets/ui/inventory/"
var panel: Panel
var grid: GridContainer
var scroll: ScrollContainer
var detail: Label
var title: Label
var kind_label: Label
var counter: Label
var empty: Label
var art: TextureRect
var take_button: Button
var tabs: Array[Button] = []
var items: Array = []
var filtered: Array = []
var selected_id := ""
var category := "道具"
var selected_by_category := {}
var font: Font
var detail_scroll: ScrollContainer
var scroll_hint: Label

static func category_of(id: String) -> String:
	if id.contains("key"): return "钥匙"
	if id in ["sweater", "roof_copy", "sandal", "hoodie"]: return "衣物"
	if id in ["phone", "weird_clock", "badge", "permcard"]: return "道具"
	return "线索"

static func art_of(id: String) -> String:
	if id=="c2_pipeline":return "pipe_map"
	if id in ["c2_hospital","c2_residence_record"]:return "registered"
	if id in ["roof_copy", "hoodie"]: return "sweater"
	if id == "sandal": return "shoe"
	if id.contains("key"): return id if id in ["back_key", "drawer_key", "mail_key", "tool_key", "machine_key"] else "key"
	if id in ["phone", "weird_clock", "envelope", "photo", "sweater", "pipe_map", "badge", "permcard"]: return id
	if id in ["return_card", "discharge"]: return "registered"
	return "document"

func setup(f: Font) -> void:
	font = f
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var theme_resource := Theme.new()
	theme_resource.default_font = font
	theme_resource.default_font_size = 18
	theme = theme_resource
	var dim := ColorRect.new()
	dim.color = Color(.012, .015, .016, .84)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	panel = Panel.new()
	panel.size = Vector2(1400, 800)
	panel.add_theme_stylebox_override("panel", style(Color("1a1b19"), Color("565346"), 3))
	add_child(panel)
	var surface := TextureRect.new()
	surface.texture = load(ART + "grain.png")
	surface.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	surface.stretch_mode = TextureRect.STRETCH_TILE
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	surface.modulate.a = .15
	surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(surface)
	var emblem := Label.new()
	emblem.text = "◈"; emblem.position = Vector2(30, 29); emblem.size = Vector2(52, 52)
	emblem.add_theme_font_size_override("font_size", 40)
	emblem.add_theme_color_override("font_color", BRASS)
	emblem.mouse_filter = Control.MOUSE_FILTER_IGNORE; panel.add_child(emblem)
	label("诡异事务局", Vector2(90, 39), Vector2(176, 38), 23, BRASS)
	rule(Vector2(265, 35), Vector2(1, 43))
	label("随身物品", Vector2(292, 26), Vector2(270, 60), 38, PAPER)
	label("许砚 / 现场携行记录", Vector2(568, 48), Vector2(400, 30), 16, MUTED)
	var close := button("×", Vector2(1326, 31), Vector2(42, 42))
	close.add_theme_font_size_override("font_size", 28)
	close.tooltip_text = "关闭背包（B / Esc）"
	close.pressed.connect(func():close_requested.emit())
	rule(Vector2(32, 106), Vector2(1336, 1))
	for i in CATEGORIES.size():
		var tab := button(CATEGORIES[i], Vector2(32+i*126, 117), Vector2(112, 42))
		tab.add_theme_font_size_override("font_size", 21)
		tab.pressed.connect(func():set_category(CATEGORIES[i]))
		tabs.append(tab)
	counter = label("", Vector2(572, 126), Vector2(256, 28), 15, MUTED)
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rule(Vector2(32, 162), Vector2(796, 1))
	rule(Vector2(865, 130), Vector2(1, 594))
	scroll = ScrollContainer.new()
	scroll.position = Vector2(32, 180); scroll.size = Vector2(810, 536)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	panel.add_child(scroll)
	grid = GridContainer.new(); grid.columns = 6
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)
	style_scroll(scroll)
	empty = label("", Vector2(126, 352), Vector2(610, 90), 19, MUTED)
	empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label("物品详情", Vector2(900, 126), Vector2(446, 28), 18, BRASS)
	rule(Vector2(1003, 141), Vector2(342, 1))
	art = TextureRect.new(); art.position = Vector2(900, 157); art.size = Vector2(448, 320)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(art)
	kind_label = label("", Vector2(904, 453), Vector2(430, 26), 14, BRASS)
	title = label("", Vector2(900, 486), Vector2(450, 45), 29, PAPER)
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail_scroll = ScrollContainer.new()
	detail_scroll.position = Vector2(904, 546); detail_scroll.size = Vector2(440, 105)
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(detail_scroll); style_scroll(detail_scroll)
	detail = Label.new(); detail.custom_minimum_size = Vector2(418, 0)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_color_override("font_color", PAPER)
	detail.add_theme_font_size_override("font_size", 18)
	detail.add_theme_constant_override("line_spacing", 5)
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail_scroll.add_child(detail)
	scroll_hint = label("滚轮查看完整说明", Vector2(904, 654), Vector2(430, 18), 12, MUTED)
	detail_scroll.get_v_scroll_bar().changed.connect(update_scroll_hint)
	rule(Vector2(904, 674), Vector2(440, 1))
	take_button = button("取出物品", Vector2(900, 691), Vector2(448, 48))
	take_button.add_theme_stylebox_override("normal", style(Color("bca77f"), Color("c6b797")))
	take_button.add_theme_stylebox_override("hover", style(Color("d0bc94"), Color("e1d0ad")))
	take_button.add_theme_stylebox_override("pressed", style(Color("a58e66"), BRASS))
	take_button.add_theme_color_override("font_color", Color("24251f"))
	take_button.add_theme_color_override("font_hover_color", Color("151812"))
	var keycap := Panel.new();keycap.position = Vector2(405,9);keycap.size = Vector2(30,30)
	keycap.add_theme_stylebox_override("panel",style(Color("282b24"),Color("8a7c5b"),3))
	keycap.mouse_filter = Control.MOUSE_FILTER_IGNORE;take_button.add_child(keycap)
	var key_text := Label.new();key_text.text = "E";key_text.size = Vector2(30,30)
	key_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER;key_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key_text.add_theme_color_override("font_color",PAPER);key_text.mouse_filter = Control.MOUSE_FILTER_IGNORE;keycap.add_child(key_text)
	take_button.pressed.connect(func():take_requested.emit())
	rule(Vector2(32, 755), Vector2(1336, 1))
	label("物品已妥善收纳", Vector2(34, 766), Vector2(350, 24), 14, MUTED)
	var hints := label("方向键 选择    Tab 分类    E 取出    B / Esc 返回", Vector2(704, 764), Vector2(642, 28), 14, MUTED)
	hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	resized.connect(fit_panel); fit_panel()
	visible = false

func fit_panel() -> void:
	if panel == null: return
	var extent := get_viewport_rect().size
	var factor := minf(1.0, minf((extent.x-48)/1400., (extent.y-48)/800.))
	panel.scale = Vector2.ONE * maxf(.25, factor)
	panel.position = (extent-panel.size*panel.scale)*.5

func style(bg: Color, edge: Color, radius := 2) -> StyleBoxFlat:
	var box := StyleBoxFlat.new(); box.bg_color = bg; box.border_color = edge
	box.set_border_width_all(1); box.set_corner_radius_all(radius)
	return box

func label(text: String, at: Vector2, extent: Vector2, font_size: int, color: Color) -> Label:
	var out := Label.new(); out.text = text; out.position = at; out.size = extent
	out.add_theme_font_size_override("font_size", font_size)
	out.add_theme_color_override("font_color", color)
	out.mouse_filter = Control.MOUSE_FILTER_IGNORE; panel.add_child(out); return out

func rule(at: Vector2, extent: Vector2) -> void:
	var line := ColorRect.new(); line.position = at; line.size = extent
	line.color = Color("49483e"); line.mouse_filter = Control.MOUSE_FILTER_IGNORE; panel.add_child(line)

func button(text: String, at: Vector2, extent: Vector2) -> Button:
	var out := Button.new(); out.text = text; out.position = at; out.size = extent
	out.focus_mode = Control.FOCUS_NONE
	out.add_theme_stylebox_override("normal", style(Color(0,0,0,0), Color(0,0,0,0)))
	out.add_theme_stylebox_override("hover", style(Color("292a23"), Color("5d5746")))
	out.add_theme_stylebox_override("pressed", style(Color("343126"), BRASS))
	out.add_theme_stylebox_override("disabled", style(Color("20211e"), Color("44443b")))
	out.add_theme_color_override("font_color", MUTED)
	out.add_theme_color_override("font_hover_color", PAPER)
	out.add_theme_color_override("font_pressed_color", PAPER)
	out.add_theme_color_override("font_disabled_color", Color("737469"))
	panel.add_child(out); return out

func style_scroll(sc: ScrollContainer) -> void:
	var bar := sc.get_v_scroll_bar()
	bar.custom_minimum_size.x = 5
	bar.add_theme_stylebox_override("scroll", style(Color("24251f"), Color(0,0,0,0)))
	for key in ["grabber", "grabber_highlight", "grabber_pressed"]:
		bar.add_theme_stylebox_override(key, style(Color("746951"), Color(0,0,0,0)))

func update_scroll_hint() -> void:
	if scroll_hint != null:
		var bar := detail_scroll.get_v_scroll_bar()
		scroll_hint.visible = bar.max_value > bar.page + 1.0

func refresh(all_items: Array, preferred := "") -> void:
	items = all_items
	filtered = items.filter(func(item):return category_of(String(item.id)) == category)
	for i in tabs.size():
		var count := items.filter(func(item):return category_of(String(item.id)) == CATEGORIES[i]).size()
		tabs[i].text = CATEGORIES[i] + "  " + str(count)
		tabs[i].add_theme_color_override("font_color", BRASS if CATEGORIES[i] == category else MUTED)
		var tab_style := style(Color(0,0,0,0), BRASS if CATEGORIES[i] == category else Color(0,0,0,0))
		tab_style.set_border_width_all(0); tab_style.border_width_bottom = 2 if CATEGORIES[i] == category else 0
		tabs[i].add_theme_stylebox_override("normal", tab_style)
	for child in grid.get_children():grid.remove_child(child);child.queue_free()
	for index in maxi(24, int(ceil(filtered.size()/6.))*6):
		var item: Dictionary = filtered[index] if index < filtered.size() else {}
		var id := String(item.get("id", ""))
		var cell := button("", Vector2.ZERO, Vector2(124,124))
		panel.remove_child(cell); grid.add_child(cell); cell.custom_minimum_size = Vector2(124,124)
		cell.set_meta("item_id", id); cell.disabled = id.is_empty()
		cell.add_theme_stylebox_override("disabled", style(Color("181a18"), Color("32352e")))
		cell.pressed.connect(func():select_item(id);item_selected.emit(id))
		var number := Label.new(); number.text = "%02d" % (index+1)
		number.position = Vector2(7,5);number.size = Vector2(30,16)
		number.add_theme_font_size_override("font_size",11)
		number.add_theme_color_override("font_color",Color("65675c"))
		number.mouse_filter = Control.MOUSE_FILTER_IGNORE; cell.add_child(number)
		if not id.is_empty():
			var image := TextureRect.new();image.position = Vector2(7,1);image.size = Vector2(110,96)
			image.texture = load(ART+art_of(id)+".png")
			image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			image.mouse_filter = Control.MOUSE_FILTER_IGNORE;cell.add_child(image)
			var name_label := Label.new();name_label.text = String(item.name)
			name_label.position = Vector2(5,97);name_label.size = Vector2(114,22)
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_label.add_theme_font_size_override("font_size",14)
			name_label.add_theme_color_override("font_color",PAPER)
			name_label.clip_text = true;name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE;cell.add_child(name_label)
			cell.tooltip_text = String(item.name)
			var corner := Polygon2D.new();corner.name = "SelectedCorner"
			corner.polygon = PackedVector2Array([Vector2(113,1),Vector2(123,1),Vector2(123,11)])
			corner.color = BRASS;cell.add_child(corner)
	counter.text = "%02d 件%s" % [filtered.size(),category]
	empty.text = "暂无"+category+"\n在现场找到后，会收纳在这里。"
	empty.visible = filtered.is_empty()
	var choice := preferred if has_visible(preferred) else String(selected_by_category.get(category, ""))
	if not has_visible(choice): choice = String(filtered[0].id) if not filtered.is_empty() else ""
	select_item(choice)

func has_visible(id: String) -> bool:
	return filtered.any(func(item):return String(item.id) == id)

func set_category(value: String) -> void:
	if value not in CATEGORIES:return
	category = value; scroll.scroll_vertical = 0
	refresh(items); item_selected.emit(selected_id)

func select_item(id: String) -> void:
	if not id.is_empty() and not has_visible(id):
		if not items.any(func(item):return String(item.id) == id): return
		category = category_of(id);refresh(items, id);return
	selected_id = id
	selected_by_category[category] = id
	for cell in grid.get_children():
		if String(cell.get_meta("item_id", "")).is_empty():continue
		var selected: bool = cell.get_meta("item_id") == id
		cell.add_theme_stylebox_override("normal", style(Color("29281f") if selected else Color("20221e"), BRASS if selected else Color("4c4d41")))
		cell.get_node("SelectedCorner").visible = selected
		if selected:scroll.ensure_control_visible(cell)
	take_button.disabled = id.is_empty()
	take_button.get_child(0).modulate.a = .35 if id.is_empty() else 1.0
	detail_scroll.scroll_vertical = 0
	if id.is_empty():
		art.texture = null;kind_label.text = category
		title.text = "暂无"+category;detail.text = "选择物品，查看它的来历与细节。";return
	for item in filtered:
		if String(item.id) != id:continue
		art.texture = load(ART+art_of(id)+".png")
		title.text = String(item.name);title.tooltip_text = title.text
		kind_label.text = category+" / 随身收纳"
		detail.text = "诡异事务局送来的入职通知书。\n取出后按 E 阅读正文与五条须知。" if id == "envelope" else String(item.get("desc", ""))
		if detail.text.is_empty():detail.text = "已收纳。取出后可查看。"
		return

func move_selection(step: int) -> void:
	if filtered.is_empty():return
	var index := 0
	for i in filtered.size():
		if String(filtered[i].id) == selected_id:index=i;break
	index = clampi(index+step,0,filtered.size()-1)
	select_item(String(filtered[index].id));item_selected.emit(selected_id)

func cycle_category() -> void:
	set_category(CATEGORIES[(CATEGORIES.find(category)+1)%CATEGORIES.size()])
