extends RefCounted
const UI := preload("res://scripts/field_ui_style.gd")
static func build(m) -> void:
	m.slots_panel=PanelContainer.new();m.slots_panel.position=Vector2(410,100);m.slots_panel.size=Vector2(1120,700)
	var style=UI.box(UI.INK,Color("49483d"));style.content_margin_left=30;style.content_margin_right=30;style.content_margin_top=25;style.content_margin_bottom=25
	m.slots_panel.add_theme_stylebox_override("panel",style);m.add_child(m.slots_panel)
	var v=VBoxContainer.new();v.add_theme_constant_override("separation",12);m.slots_panel.add_child(v)
	var header=HBoxContainer.new();v.add_child(header)
	var title=m._label("值班记录",34,UI.PAPER);title.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT;title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(title)
	for mode in ["save","load"]:
		var b=m._btn("保存" if mode=="save" else "读取",22);UI.button(b);b.pressed.connect(func():m.show_slots(mode));header.add_child(b)
	m.mode_hint=m._label("",18,UI.BRASS);m.mode_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT;v.add_child(m.mode_hint)
	m.archive_summary=m._label("",16,UI.MUTED);m.archive_summary.visible=false;v.add_child(m.archive_summary)
	m.archive_summary_sub=m._label("",16,UI.MUTED);m.archive_summary_sub.visible=false;v.add_child(m.archive_summary_sub)
	for i in 3:
		var row=HBoxContainer.new();row.add_theme_constant_override("separation",12);v.add_child(row)
		var b=m._btn("",22);UI.button(b);b.custom_minimum_size=Vector2(900,100);b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		b.alignment=HORIZONTAL_ALIGNMENT_LEFT;b.pressed.connect(func():m._on_slot_pressed(i));row.add_child(b);m.slot_btns.append(b)
		var del=m._btn("删除",18);UI.button(del);del.custom_minimum_size=Vector2(110,44);del.size_flags_vertical=Control.SIZE_SHRINK_CENTER
		del.pressed.connect(func():m._on_delete_pressed(i));row.add_child(del);m.slot_delete_btns.append(del)
	m.auto_slot_button=m._btn("",22);UI.button(m.auto_slot_button);m.auto_slot_button.custom_minimum_size=Vector2(1040,100);m.auto_slot_button.alignment=HORIZONTAL_ALIGNMENT_LEFT
	m.auto_slot_button.pressed.connect(func():m.auto_continue.emit());v.add_child(m.auto_slot_button)
	var gap=Control.new();gap.size_flags_vertical=Control.SIZE_EXPAND_FILL;v.add_child(gap)
	m.archive_note=m._label("自动档独立保留；覆盖手动槽位前会确认。",18,UI.BRASS);m.archive_note.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT
	m.archive_note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;m.archive_note.custom_minimum_size.y=52;v.add_child(m.archive_note)
	var footer=HBoxContainer.new();v.add_child(footer)
	var note=m._label("保存案件、证据、背包、时钟、位置与设备状态。",16,UI.MUTED);note.horizontal_alignment=HORIZONTAL_ALIGNMENT_LEFT;note.size_flags_horizontal=Control.SIZE_EXPAND_FILL;footer.add_child(note)
	var back=m._btn("ESC  返回",20);UI.button(back);back.custom_minimum_size=Vector2(190,44)
	back.pressed.connect(func():
		m.slots_panel.visible=false
		if m.pause_open:m.show_pause()
		else:m.center.visible=true;m.focus_main())
	footer.add_child(back)
	m.slot_confirm=ConfirmationDialog.new();m.slot_confirm.title="覆盖值班记录";m.slot_confirm.dialog_text="是否覆盖这个手动槽位？上一份有效记录会保留备份。"
	m.slot_confirm.ok_button_text="覆盖保存";m.slot_confirm.cancel_button_text="取消";m.add_child(m.slot_confirm)
	m.slot_confirm.confirmed.connect(func():m.save_slot.emit(m.pending_overwrite);m.pending_overwrite=-1)
	m.slot_confirm.canceled.connect(func():m.pending_overwrite=-1)
