extends RefCounted
## 本案版本化现场；不把运行时 Node/Vector3 直接写进 JSON。
const VERSION := 2
static var last_error := ""
static var PROGRESS_PATH := preload("res://scripts/storage_paths.gd").file("laundry_archive.json")

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
		if argument.replace("\\","/").contains("scripts/tests/"):
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
	last_error = ""
	if preload("res://scripts/storage_paths.gd").inspection_active:
		last_error = "开发者巡查不能写入玩家槽位。请先退出巡查。"
		return {}
	var resume: String = g._pre_pause_state if g.state == "paused" else g.state
	var reading_letter: bool = resume in ["prologue_ui", "prologue_choice"]
	if resume == "prologue_ui":resume = g.field_kit.return_state
	elif resume == "prologue_choice":resume = "prologue"
	var second:bool=g.case2_controller!=null and g.case2_controller.active
	if second and resume=="case2_read":resume=g.case2_controller.campaign.return_state
	if second and resume=="case_dialogue":resume=g.case2_controller.campaign.dialogue.return_state
	elif resume=="case_dialogue" and g.laundry!=null:
		resume=g.laundry.campaign.dialogue.return_state
	if resume=="clock_ui":resume=g.director.return_state
	if resume=="case_reader" and g.laundry!=null:resume=g.laundry.campaign.return_state
	if resume=="case_cinematic":
		resume=g.laundry.campaign.cinematic.return_state if g.laundry!=null and g.laundry.campaign.cinematic.active else g.field_kit.letter_camera.return_state
	if resume not in ["prologue", "play", "case_choice", "case_end"]:
		last_error = "正在切换场景或上下检修梯，请到达现场后再保存。" if resume.begins_with("exit_") or resume in ["case_climb", "leave_laundry", "case_title"] else "当前操作尚未结束，请返回调查现场后再保存。"
		return {}
	var room := {}
	for key in ROOM_FIELDS:
		room[key] = g.get(key)
	var p: Vector3 = g.safety.save_position()
	var d := {"schema_version": VERSION, "building_version": 2, "case_id": "00201" if second else "00184", "mode": g.case_mode,
		"state": resume, "stage": g.prologue_stage, "room": room, "bag": g.case_bag.duplicate(true),
		"position": [p.x, p.y, p.z], "yaw": g.player.rotation.y, "pitch": g.player.pitch,
		"camera_mode":g.player.cam_mode,
		"flashlight":g.player.flash.visible,
		"clock": g.director.now(), "time": Time.get_datetime_string_from_system(false, false),
		"objective": g.case_objective, "objective_done": g.case_obj_done.duplicate(true),
		"clock_appeared": g.clock_appeared}
	d["subtitle"] = {"text": g.sub, "who": g.hud_sub_title.text, "time": g.sub_time,
		"pause": g.sub_pause, "queue": g.sub_queue.duplicate(true), "hold": g._sub_hold_left}
	d["field_items"] = {"held_id": g.field_kit.held_id, "phone_owned": g.field_kit.phone_owned,
		"letter_accepted": g.field_kit.letter_accepted}
	d["director"] = g.director.capture()
	d["phone"] = {"quiet":g.phone_ui.quiet,"active_chat":g.phone_ui.active_chat}
	# Never resume a half-finished rent-call callback or an unaccepted letter UI.
	if not second and g.case_mode != "laundry" and (g.phone_ui.call_active or (g.prologue_call_done and not g.prologue_letter_ready)):
		d.room.prologue_call_done = false
	if reading_letter and not g.field_kit.letter_accepted:
		d.room.envelope_taken = false
		d.field_items.held_id = ""
	d["series"]=g.series.duplicate(true)
	if second:d["case2"]=g.case2_controller.capture()
	if g.town_bridge!=null and g.town_bridge.weather!=null:
		d["town_environment"]=g.town_bridge.weather.capture()
	if g.town_bridge!=null:
		d["town_residents"]=g.town_bridge.capture_residents()
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
		var cine=g.laundry.campaign.cinematic
		if cine.active and cine.event_id=="seven":lc["spinning"][7]=cine.prior_seven
		if g.laundry.night != null and g.laundry.lady != null:
			lc["lady_walk"] = g.laundry.night._lady_walk_t
			lc["lady_state"] = g.laundry.night.lady_state
		d["laundry"] = lc
		if g.laundry.campaign != null:
			lc["campaign"] = g.laundry.campaign.capture()
	d["slot_metadata"] = metadata(d)
	return d

static func metadata(d: Dictionary) -> Dictionary:
	var second:bool = d.get("case_id") == "00201"
	var night:int = int(d.get("laundry",{}).get("campaign",{}).get("night",1))
	var place:String = "回潮镇街道" if d.get("stage")=="town" else "出租屋"
	if d.get("mode")=="laundry":
		var p:Array = d.get("position",[0,0,0])
		var y:float = float(p[1])
		place = "得利洗衣店 · "+("B1" if y<0 else "屋顶" if y>=15.3 else "%dF" % (5 if y>=12.4 else 4 if y>=9.5 else 3 if y>=6.6 else 2 if y>=3.2 else 1))
		if float(p[0])>6:place = "楼内邮政存档间"
	elif d.get("mode")=="case2":place="槐安住宅"
	var minutes:int = int(float(d.get("clock",1420))) % 1440
	return {"case_id":d.get("case_id","00184"),"case_name":"十七楼的水表" if second else "得利洗衣店","night":night,"location":place,"game_time":"%02d:%02d" % [minutes/60,minutes%60],"saved_at":d.get("time","")}

static func read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:return {}
	return parser.data if parser.data is Dictionary and valid(parser.data) else {}

static func read_snapshot(path: String) -> Dictionary:
	last_error = ""
	var data := read_file(path)
	if not data.is_empty():return data
	data = read_file(path+".bak")
	if not data.is_empty():
		last_error = "主存档缺失或损坏，已使用上一份有效备份。"
		return data
	last_error = "存档损坏或版本不受支持，原文件已保留。" if FileAccess.file_exists(path) else "该槽位尚无存档。"
	return {}

static func write_snapshot(path: String, data: Dictionary) -> bool:
	last_error = ""
	if not valid(data):
		last_error = "现场记录不完整，本次未覆盖原存档。"
		return false
	var temp := path+".tmp"
	var file := FileAccess.open(temp,FileAccess.WRITE)
	if file == null:
		last_error = "无法写入存档目录："+error_string(FileAccess.get_open_error())+"。请检查磁盘空间和目录权限。"
		return false
	file.store_string(JSON.stringify(data));file.flush()
	var result := file.get_error();file.close()
	if result != OK or read_file(temp) != JSON.parse_string(JSON.stringify(data)):
		last_error = "存档写入或校验失败，原存档已保留。请检查磁盘空间后重试。"
		return false
	if not read_file(path).is_empty():
		result = DirAccess.copy_absolute(path,path+".bak.tmp")
		if result == OK:result = DirAccess.rename_absolute(path+".bak.tmp",path+".bak")
		if result != OK:
			last_error = "无法保留上一份有效存档："+error_string(result)+"。本次未覆盖。"
			return false
	result = DirAccess.rename_absolute(temp,path)
	if result != OK:
		last_error = "替换存档失败："+error_string(result)+"。原存档和备份已保留。"
		return false
	return true

static func valid(d: Dictionary) -> bool:
	if int(d.get("schema_version", 0)) != VERSION or d.get("case_id") not in ["00184","00201"]:
		return false
	if d.get("mode", "") not in ["", "laundry","case2"] or typeof(d.get("room")) != TYPE_DICTIONARY:
		return false
	if d.get("state") not in ["prologue", "play", "case_choice", "case_end"]:
		return false
	var pos = d.get("position")
	if typeof(pos) != TYPE_ARRAY or pos.size() != 3:
		return false
	for value in pos:
		if typeof(value) not in [TYPE_FLOAT, TYPE_INT] or not is_finite(float(value)):
			return false
	for key in ["clock","yaw","pitch"]:
		if d.has(key) and (typeof(d[key]) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(d[key]))):return false
	for key in ["bag","notes","director","field_items","subtitle","objective_done","phone"]:
		if d.has(key) and typeof(d[key]) != (TYPE_ARRAY if key=="bag" else TYPE_DICTIONARY):return false
	for item in d.get("bag",[]):
		if not item is Dictionary or not item.get("id") is String or not item.get("name") is String:return false
	for key in ROOM_FIELDS:
		if d.room.has(key):
			var expected:int=TYPE_DICTIONARY if key=="prologue_seen" else TYPE_STRING if key=="prologue_objective" else TYPE_INT if key=="envelope_refused" else TYPE_BOOL
			if typeof(d.room[key])!=expected and not (expected==TYPE_INT and typeof(d.room[key])==TYPE_FLOAT):return false
	var director:Dictionary=d.get("director",{})
	for key in ["sent","messages","unread"]:
		if director.has(key) and not director[key] is Dictionary:return false
	for who in director.get("messages",{}):
		if not director.messages[who] is Array:return false
		for message in director.messages[who]:
			if not message is String:return false
	var subtitle:Dictionary=d.get("subtitle",{})
	if subtitle.has("queue"):
		if not subtitle.queue is Array:return false
		for line in subtitle.queue:
			if not line is Dictionary or not line.get("text") is String:return false
	if d.has("laundry"):
		if not d.laundry is Dictionary:return false
		var lc:Dictionary=d.laundry
		if lc.has("t") and (typeof(lc.t) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(lc.t))):return false
		for key in ["back_open","has_back_key","claimed","final_open","ended"]:
			if lc.has(key) and typeof(lc[key])!=TYPE_BOOL:return false
		for key in ["campaign","fired","clues","spinning"]:
			if lc.has(key) and not lc[key] is Dictionary:return false
		var progress:Dictionary=lc.get("campaign",{})
		if progress.has("night") and (typeof(progress.night) not in [TYPE_FLOAT,TYPE_INT] or int(progress.night) not in [1,2,3]):return false
		if progress.has("flags") and not progress.flags is Dictionary:return false
	if d.get("case_id")=="00201":
		var c=d.get("case2")
		if not c is Dictionary or int(c.get("version",0))!=1 or not c.get("campaign") is Dictionary:return false
		if typeof(c.get("active"))!=TYPE_BOOL or not c.active or typeof(c.get("in_residence"))!=TYPE_BOOL:return false
		var progress:Dictionary=c.campaign
		if int(progress.get("version",0))!=1 or not progress.get("flags") is Dictionary or not progress.get("evidence") is Dictionary:return false
		for container in [progress.flags,progress.evidence]:
			for key in container:
				if typeof(key)!=TYPE_STRING or typeof(container[key])!=TYPE_BOOL:return false
		if typeof(progress.get("active"))!=TYPE_BOOL or typeof(progress.get("completed"))!=TYPE_BOOL:return false
		if progress.completed and not progress.flags.get("case_complete",false):return false
		var clock=c.get("clock_minutes")
		if typeof(clock) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(clock)) or float(clock)<0:return false
		if d.get("mode")=="case2" and not bool(c.get("in_residence",false)):return false
	elif d.get("mode")=="case2":return false
	if d.has("series") and not d.series is Dictionary:return false
	return d.get("mode") != "laundry" or typeof(d.get("laundry")) == TYPE_DICTIONARY

static func restore(g, d: Dictionary) -> bool:
	if not valid(d):
		return false
	if g.case2_controller!=null:g.case2_controller.reset()
	g._discard_laundry()
	g.field_kit.reset()
	g._clear_sub()
	g.choice = null
	g.choice_text = ""
	g._start_prologue(false)
	g.series=d.get("series",{"chapter":"00184","case1_complete":false,"case2_started":false,"case2_complete":false}).duplicate(true)
	var second:bool=d.get("case_id")=="00201"
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
	g.phone_ui.quiet = bool(d.get("phone",{}).get("quiet",false))
	g.phone_ui.active_chat = String(d.get("phone",{}).get("active_chat","房东"))
	if not d.has("director"):
		g.director.room_minutes = float(d.get("clock",g.director.ROOM_START))
		if g.field_kit.letter_accepted:
			g.phone_ui.messages["派遣科"] = [g.director.JOB]
			g.director.sent["job"] = true
	if not g.field_kit.letter_accepted:
		g.phone_ui.messages.erase("派遣科")
		g.director.sent.clear()
	g.phone_ui.incoming = not second and d.get("mode") != "laundry" and not g.prologue_call_done
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
	if d.has("laundry") and not second:
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
	if second and not g.case2_controller.restore(d["case2"]):return false
	if d.get("mode") not in ["laundry","case2"] and d.get("stage", "room") == "town" and g.town_bridge != null:
		g.town_bridge.enter(d.has("laundry"))
	g._clear_sub()
	g.case_objective = String(d.get("objective", ""))
	g.case_obj_done = d.get("objective_done", {}).duplicate()
	g.clock_min = float(d.get("clock", 1420.0))
	if g.town_bridge!=null and g.town_bridge.weather!=null:
		g.town_bridge.weather.restore(d.get("town_environment",{}))
	if g.town_bridge!=null:
		g.town_bridge.restore_residents(d.get("town_residents",{}))
	var p: Array = d["position"]
	g.player.global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
	if d.get("mode") == "laundry" and int(d.get("building_version",0)) < 2:
		g.player.global_position = Vector3(-.55,.08,-8.8)
	g.safe_pos = g.player.global_position
	g.player.rotation.y = float(d.get("yaw", 0.0))
	g.player.pitch = float(d.get("pitch", 0.0))
	g.player.cam.rotation.x = g.player.pitch
	g.player.cam_mode = clampi(int(d.get("camera_mode",g.player.cam_mode)),0,2)
	g.player.flash.visible=bool(d.get("flashlight",false))
	g.player.body.visible = g.player.cam_mode!=0
	g.player._update_camera(0.0,0.0,false)
	g.player.velocity = Vector3.ZERO
	g.state = String(d.get("state", "prologue"))
	g._pre_pause_state = ""
	if g.state == "case_choice":
		g.state = "play"
		g.laundry.final_open = false
	elif g.state=="case_end" and second and g.case2_controller.campaign.flag("case_complete"):
		g.finish_case2(g.case2_controller.campaign.summary())
	elif g.state == "case_end" and g.laundry!=null and g.laundry.selected_ending != "":
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
	g.player.physics_frozen = false
	g.player.set_physics_process(true)
	g.hud.visible = true
	g.hud_fade.modulate.a = 0.0
	g.player.can_move = g.state in ["prologue", "play"]
	g.player.allow_capture = g.player.can_move
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if g.player.can_move else Input.MOUSE_MODE_VISIBLE
	g._update_hud()
	if second:g.case2_controller.update_goal()
	if g.phone_ui.incoming and g.case_mode != "laundry":
		g.audio_system.start_ring()
	return true
