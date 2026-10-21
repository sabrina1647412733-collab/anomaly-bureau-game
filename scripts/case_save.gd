extends RefCounted
## 本案版本化现场；不把运行时 Node/Vector3 直接写进 JSON。
const VERSION := 2
const PROGRESS_PATH := "user://laundry_archive.json"

static func read_progress() -> Dictionary:
	if FileAccess.file_exists(PROGRESS_PATH):
		var data = JSON.parse_string(FileAccess.get_file_as_string(PROGRESS_PATH))
		if typeof(data) == TYPE_DICTIONARY and typeof(data.get("endings")) == TYPE_ARRAY:
			return data
	return {"case_id": "00184", "endings": []}

static func record_ending(kind: String) -> void:
	if OS.get_cmdline_user_args().has("--verify"):
		return
	# 从测试/截图入口启动时也不写入玩家的结局解锁记录。
	for argument in OS.get_cmdline_args():
		if argument.begins_with("res://scripts/tests/"):
			return
	var data := read_progress()
	if not data["endings"].has(kind):
		data["endings"].append(kind)
	data["campaign_version"] = 3
	data["updated"] = Time.get_datetime_string_from_system(false, false)
	var file := FileAccess.open(PROGRESS_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))
		file.close()
const ROOM_FIELDS := ["prologue_seen", "prologue_letter_ready", "prologue_letter_read",
	"prologue_call_done", "prologue_anomaly_done", "prologue_objective",
	"prologue_radio_on", "prologue_radio_played", "prologue_wallphone_checked",
	"prologue_photo_checked", "prologue_room_lights_on", "envelope_taken", "envelope_refused"]
const CASE_FIELDS := ["t", "fired", "clues", "back_open", "has_back_key", "claimed",
	"final_open", "ended", "selected_ending"]

static func capture(g) -> Dictionary:
	var resume: String = g._pre_pause_state if g.state == "paused" else g.state
	if resume not in ["prologue", "play", "case_choice", "case_end"]:
		return {}
	var room := {}
	for key in ROOM_FIELDS:
		room[key] = g.get(key)
	var p: Vector3 = g.player.global_position
	var d := {"schema_version": VERSION, "case_id": "00184", "mode": g.case_mode,
		"state": resume, "stage": g.prologue_stage, "room": room, "bag": g.case_bag.duplicate(true),
		"position": [p.x, p.y, p.z], "yaw": g.player.rotation.y, "pitch": g.player.pitch,
		"camera_mode":g.player.cam_mode,
		"clock": g.clock_min, "time": Time.get_datetime_string_from_system(false, false),
		"objective": g.case_objective, "objective_done": g.case_obj_done.duplicate(true),
		"clock_appeared": g.clock_appeared}
	d["subtitle"] = {"text": g.sub, "who": g.hud_sub_title.text, "time": g.sub_time,
		"pause": g.sub_pause, "queue": g.sub_queue.duplicate(true), "hold": g._sub_hold_left}
	d["field_items"] = {"held_id": g.field_kit.held_id, "phone_owned": g.field_kit.phone_owned,
		"letter_accepted": g.field_kit.letter_accepted}
	d["director"] = g.director.capture()
	if g.nb != null:
		d["notes"] = g.nb.entries.duplicate(true)
	if g.wclock != null:
		d["room_clock"] = {"total_min": g.wclock.total_min, "fired": g.wclock.fired.duplicate()}
	if g.laundry != null:
		var lc := {}
		for key in CASE_FIELDS:
			lc[key] = g.laundry.get(key)
		# JSON 字典键只能是字符串；恢复时还原滚筒编号。
		lc["spinning"] = g.laundry.spinning.duplicate()
		if g.laundry.night != null and g.laundry.lady != null:
			lc["lady_walk"] = g.laundry.night._lady_walk_t
			lc["lady_state"] = g.laundry.night.lady_state
		d["laundry"] = lc
		if g.laundry.campaign != null:
			lc["campaign"] = g.laundry.campaign.capture()
	return d

static func valid(d: Dictionary) -> bool:
	if int(d.get("schema_version", 0)) != VERSION or d.get("case_id") != "00184":
		return false
	if d.get("mode", "") not in ["", "laundry"] or typeof(d.get("room")) != TYPE_DICTIONARY:
		return false
	if d.get("state") not in ["prologue", "play", "case_choice", "case_end"]:
		return false
	var pos = d.get("position")
	if typeof(pos) != TYPE_ARRAY or pos.size() != 3:
		return false
	for value in pos:
		if typeof(value) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(value)):
			return false
	return d.get("mode") != "laundry" or typeof(d.get("laundry")) == TYPE_DICTIONARY

static func restore(g, d: Dictionary) -> bool:
	if not valid(d):
		return false
	g._discard_laundry()
	g.field_kit.reset()
	g._clear_sub()
	g.choice = null
	g.choice_text = ""
	g._start_prologue(false)
	for key in ROOM_FIELDS:
		if d["room"].has(key):
			g.set(key, d["room"][key])
	g.case_bag = d.get("bag", []).duplicate(true)
	var field: Dictionary = d.get("field_items", {})
	g.field_kit.phone_owned = bool(field.get("phone_owned", g.bag_has("phone")))
	g.field_kit.letter_accepted = bool(field.get("letter_accepted", g.bag_has("envelope")))
	var held: String = field.get("held_id", "")
	g.field_kit.held_id = held if g.bag_has(held) else ""
	g.field_kit.rig.set_item(g.field_kit.held_id)
	g.field_kit.sync_world()
	g.director.restore(d.get("director",{}))
	if not d.has("director"):
		g.director.room_minutes = float(d.get("clock",g.director.ROOM_START))
		if g.prologue_call_done:
			g.phone_ui.messages["派遣科"] = [g.director.JOB]
			g.director.sent["job"] = true
	g.phone_ui.incoming = d.get("mode") != "laundry" and not g.prologue_call_done
	if g.nb != null:
		g.nb.entries = d.get("notes", {"物": [], "人": [], "话": [], "疑": []}).duplicate(true)
	g._set_prologue_room_lights(g.prologue_room_lights_on)
	if g.prologue_envelope != null:
		g.prologue_envelope.visible = g.prologue_letter_ready and not g.envelope_taken
	g.clock_appeared = bool(d.get("clock_appeared", false))
	if g.clock_appeared and g.wclock == null:
		g._make_weird_clock()
	if g.wclock != null:
		g.wclock.visible = g.clock_appeared and d.get("mode") != "laundry" and not g.bag_has("weird_clock")
		g.wclock.total_min = float(d.get("room_clock", {}).get("total_min", 0.0))
		g.wclock.fired = d.get("room_clock", {}).get("fired", {}).duplicate()
		g.wclock._update_hands()
	if d.has("laundry"):
		g.start_laundry_case()
		var lc: Dictionary = d["laundry"]
		for key in CASE_FIELDS:
			if lc.has(key):
				g.laundry.set(key, lc[key])
		g.laundry.spinning.clear()
		for key in lc.get("spinning", {}):
			g.laundry.spinning[int(key)] = bool(lc["spinning"][key])
		g.laundry.restore_visuals(lc)
		if d.get("mode") != "laundry":
			g.laundry.world.visible = false
			g.case_mode = ""
			g._apply_laundry_environment(false)
	if d.get("mode") != "laundry" and d.get("stage", "room") == "town" and g.town_bridge != null:
		g.town_bridge.enter(d.has("laundry"))
	g._clear_sub()
	g.case_objective = String(d.get("objective", ""))
	g.case_obj_done = d.get("objective_done", {}).duplicate()
	g.clock_min = float(d.get("clock", 1420.0))
	var p: Array = d["position"]
	g.player.global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
	g.safe_pos = g.player.global_position
	g.player.rotation.y = float(d.get("yaw", 0.0))
	g.player.pitch = float(d.get("pitch", 0.0))
	g.player.cam.rotation.x = g.player.pitch
	g.player.cam_mode = clampi(int(d.get("camera_mode",g.player.cam_mode)),0,2)
	g.player.body.visible = g.player.cam_mode!=0
	g.player._update_camera(0.0,0.0,false)
	g.player.velocity = Vector3.ZERO
	g.state = String(d.get("state", "prologue"))
	g._pre_pause_state = ""
	if g.state == "case_choice":
		g.state = "play"
		g.laundry.final_open = false
	elif g.state == "case_end" and g.laundry.selected_ending != "":
		g.laundry.ended = false
		g.laundry.complete_case()
	elif g.state == "case_end":
		g.state = "play"
	if d.has("subtitle") and g.state != "case_end":
		var subtitle: Dictionary = d["subtitle"]
		g._show_sub(String(subtitle.get("who", "旁白")), String(subtitle.get("text", "")), 3.0, bool(subtitle.get("pause", false)))
		g.sub_time = float(subtitle.get("time", 0.0))
		g.sub_queue = subtitle.get("queue", []).duplicate(true)
		g._sub_hold_left = float(subtitle.get("hold", 0.5))
		g._update_sub(0.0)
	g.menu.hide_all()
	g.hud.visible = true
	g.hud_fade.modulate.a = 0.0
	g.player.can_move = g.state in ["prologue", "play"]
	g.player.allow_capture = g.player.can_move
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if g.player.can_move else Input.MOUSE_MODE_VISIBLE
	g._update_hud()
	if g.phone_ui.incoming and g.case_mode != "laundry":
		g.audio_system.start_ring()
	return true
