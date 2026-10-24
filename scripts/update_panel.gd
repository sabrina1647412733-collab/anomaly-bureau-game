extends Control
## Reuses the existing menu's fonts, muted green panels, and amber buttons.
var menu: Control
var service: Node
var modal: Control
var heading: Label
var status: Label
var text: RichTextLabel
var bar: ProgressBar
var primary: Button
var secondary: Button
var more: Button
var close_button: Button
var mode := "update"
var dismissed := ""
var _last_focus: Control

func setup(owner_menu: Control, updater: Node) -> void:
	menu = owner_menu; service = updater
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var open_logs: Button = menu._ghost_btn("更新日志 · v" + service.current_version, show_history)
	open_logs.name = "UpdateLogButton"
	open_logs.position = Vector2(500, 804); open_logs.custom_minimum_size = Vector2(270, 32)
	menu.center.add_child(open_logs)
	modal = Control.new(); add_child(modal)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new(); modal.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); dim.color = Color(0, 0, 0, .8)
	var panel := PanelContainer.new(); modal.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -500; panel.offset_right = 500; panel.offset_top = -350; panel.offset_bottom = 350
	panel.add_theme_stylebox_override("panel", menu._panel_style())
	var column := VBoxContainer.new(); column.add_theme_constant_override("separation", 14); panel.add_child(column)
	heading = menu._label("版本更新", 26, Color("ddc491")); column.add_child(heading)
	status = menu._label("", 16); status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; column.add_child(status)
	text = RichTextLabel.new(); text.bbcode_enabled = false
	text.custom_minimum_size = Vector2(900, 390); text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.add_theme_font_override("normal_font", menu.font); text.add_theme_font_size_override("normal_font_size", 18)
	column.add_child(text)
	bar = ProgressBar.new(); bar.custom_minimum_size.y = 22; column.add_child(bar)
	var buttons := HBoxContainer.new(); buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12); column.add_child(buttons)
	primary = menu._primary_btn("立即更新", 16); primary.custom_minimum_size.x = 200; buttons.add_child(primary)
	secondary = menu._btn("检查更新", 16); secondary.custom_minimum_size.x = 200; buttons.add_child(secondary)
	more = menu._btn("加载更早版本", 16); more.custom_minimum_size.x = 200; buttons.add_child(more)
	close_button = menu._btn("稍后更新", 16); close_button.custom_minimum_size.x = 200; buttons.add_child(close_button)
	primary.pressed.connect(func():
		if mode == "history": mode = "update"; refresh(); service.check_updates()
		else: service.download_update())
	secondary.pressed.connect(func():
		if mode == "history": service.fetch_history()
		else: service.check_updates())
	more.pressed.connect(func(): service.fetch_history(false))
	close_button.pressed.connect(close)
	service.changed.connect(refresh)
	service.history_changed.connect(_history_changed)
	service.progress.connect(func(bytes: int, total: int):
		bar.max_value = maxi(total, 1); bar.value = bytes
		status.text = "正在下载 %.1f / %.1f MB（%.0f%%）" % [bytes / 1048576.0, total / 1048576.0, 100.0 * bytes / maxi(total, 1)])
	modal.hide()

func _process(_delta: float) -> void:
	if not menu.visible or not menu.center.visible or menu.pause_open: return
	if not modal.visible and service.recovery_notice:
		service.recovery_notice = false; show_update()
	if service.state in ["available", "unavailable"] and dismissed != str(service.latest.get("tag_name", "")) and not modal.visible: show_update()

func _open() -> void:
	_last_focus = get_viewport().gui_get_focus_owner()
	modal.show(); move_to_front(); refresh(); close_button.grab_focus()

func show_update() -> void:
	mode = "update"; _open()

func show_history() -> void:
	mode = "history"; _open(); service.fetch_history()

static func release_text(release: Dictionary) -> String:
	return "%s  ·  %s UTC\n%s\n\n%s" % [str(release.get("tag_name", "未知版本")), str(release.get("published_at", "")).replace("T", " ").trim_suffix("Z"), str(release.get("name", "")), str(release.get("body", "暂无更新说明。"))]

func _history_changed() -> void:
	if mode == "history": refresh()

func refresh() -> void:
	if not is_instance_valid(modal): return
	var busy: bool = service.state in ["downloading", "verifying", "installing"]
	bar.visible = mode == "update" and service.state == "downloading"
	if mode == "history":
		heading.text = "更新日志 · 当前 v" + service.current_version
		status.text = service.history_message
		var rows := PackedStringArray()
		for release in service.releases: rows.append(release_text(release))
		text.text = "\n\n──────────────────────────\n\n".join(rows)
		primary.visible = true; primary.text = "检查更新"; primary.disabled = busy
		secondary.text = "重新读取"; secondary.disabled = service.history_busy
		more.visible = service.history_has_more; more.disabled = service.history_busy
		close_button.text = "返回"; close_button.disabled = false
	else:
		heading.text = "版本更新 · 当前 v" + service.current_version
		status.text = service.message
		text.text = release_text(service.latest) if not service.latest.is_empty() else "启动时会自动检查 GitHub 正式版本。断网不影响继续游戏。\n\n更新只替换程序与资源，保留 _玩家数据 中的存档和设置。"
		primary.visible = not service.asset.is_empty()
		primary.text = "重试下载" if service.state == "error" else "立即更新"
		primary.disabled = busy or service.state == "checking"
		secondary.text = "重试检查" if service.state == "error" else "检查更新"
		secondary.disabled = busy or service.state == "checking"
		more.visible = false
		close_button.text = "取消下载" if service.state == "downloading" else "稍后更新"
		close_button.disabled = service.state in ["verifying", "installing"]
	# Keep keyboard navigation inside the modal, including Tab and Shift+Tab.
	var active: Array[Button] = []
	for button in [primary, secondary, more, close_button]:
		if button.visible and not button.disabled: active.append(button)
	for index in range(active.size()):
		var button: Button = active[index]
		var previous := button.get_path_to(active[(index + active.size() - 1) % active.size()])
		var next := button.get_path_to(active[(index + 1) % active.size()])
		button.focus_previous = previous; button.focus_next = next
		button.focus_neighbor_left = previous; button.focus_neighbor_top = previous
		button.focus_neighbor_right = next; button.focus_neighbor_bottom = next

func close() -> void:
	if service.state in ["verifying", "installing"]: return
	if service.state == "downloading": service.cancel_download()
	dismissed = str(service.latest.get("tag_name", "")); modal.hide()
	if is_instance_valid(_last_focus) and _last_focus.is_visible_in_tree(): _last_focus.grab_focus()
	else: menu.focus_main()

func _input(event: InputEvent) -> void:
	if not is_instance_valid(modal) or not modal.is_visible_in_tree(): return
	if event.is_action_pressed("ui_cancel"): close(); get_viewport().set_input_as_handled()
