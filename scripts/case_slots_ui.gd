extends RefCounted
## 本案专用槽位页；旧车站档案数据仍保留在原文件中。
static func build(m) -> void:
	m.slots_panel = PanelContainer.new()
	m.slots_panel.position = Vector2(280, 140)
	m.slots_panel.size = Vector2(1040, 620)
	m.slots_panel.add_theme_stylebox_override("panel", m._panel_style())
	m.add_child(m.slots_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	m.slots_panel.add_child(v)
	var header := HBoxContainer.new()
	v.add_child(header)
	var title: Label = m._label("值班记录", 28, Color("e9e4d7"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	m.mode_hint = m._label("", 14, Color("d5b67e"))
	header.add_child(m.mode_hint)
	var sub: Label = m._label("案卷 00184  /  得利洗衣店  /  三夜调查 · 唯一结局", 14, Color("a7b8b5"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(sub)
	v.add_child(m._line(988, Color(0.6, 0.65, 0.57, 0.3)))
	m.archive_summary = m._label("", 17, Color("d5b67e"))
	m.archive_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(m.archive_summary)
	m.archive_summary_sub = m._label("保存当前位置、调查线索、背包与记事本。", 13, Color("a7b8b5"))
	m.archive_summary_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	v.add_child(m.archive_summary_sub)
	for i in range(3):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		v.add_child(row)
		var b: Button = m._btn("", 18)
		b.custom_minimum_size = Vector2(872, 88)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func(): m._on_slot_pressed(i))
		row.add_child(b)
		m.slot_btns.append(b)
		var del: Button = m._btn("删除", 14)
		del.custom_minimum_size = Vector2(100, 42)
		del.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		del.pressed.connect(func(): m._on_delete_pressed(i))
		row.add_child(del)
		m.slot_delete_btns.append(del)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(gap)
	m.archive_note = m._label("", 13, Color("a7b8b5"))
	m.archive_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	m.archive_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	m.archive_note.custom_minimum_size.y = 24
	v.add_child(m.archive_note)
	var footer := HBoxContainer.new()
	v.add_child(footer)
	var note: Label = m._label("旧版车站存档保留，槽位会标明所属章节。", 12, Color("a7b8b5"))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(note)
	var back: Button = m._btn("返回  [ ESC ]", 16)
	back.custom_minimum_size = Vector2(200, 44)
	back.pressed.connect(func():
		m.slots_panel.visible = false
		if m.pause_open:
			m.show_pause()
		else:
			m.center.visible = true
			m.focus_main())
	footer.add_child(back)
