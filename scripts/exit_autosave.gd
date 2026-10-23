extends Node
## 独立自动存档，不覆盖玩家的三个手动槽位。
const Save := preload("res://scripts/case_save.gd")
static var PATH := preload("res://scripts/storage_paths.gd").file("autosave.json")
var game
var fallback: Dictionary={}
var elapsed := 0.0
var test_mode := false
var generation := -1
func setup(g) -> void:
	game=g;test_mode=OS.get_cmdline_user_args().has("--verify")
	for argument in OS.get_cmdline_args():
		if argument.replace("\\","/").contains("scripts/tests/"):test_mode=true
	get_tree().auto_accept_quit=false
	game.menu.auto_continue.connect(continue_game)
	refresh_menu()
func refresh_menu() -> void:
	var data=read_snapshot(PATH)
	game.menu.auto_button.disabled=data.is_empty()
	game.menu.auto_button.text="继续自动保存" if not data.is_empty() else "继续自动保存（暂无）"
func snapshot() -> Dictionary:
	if generation!=game.field_kit.generation:
		generation=game.field_kit.generation;fallback.clear()
	var original:String=game.state
	var normal:String=game._pre_pause_state if original=="paused" else original
	if normal=="clock_ui":normal=game.director.return_state
	elif normal=="prologue_ui":normal=game.field_kit.return_state
	elif normal=="prologue_choice":normal="prologue"
	elif normal=="case_reader":normal=game.laundry.campaign.return_state
	elif normal=="case_dialogue":normal=game.laundry.campaign.dialogue.return_state
	elif normal=="case_cinematic":normal=game.laundry.campaign.cinematic.return_state if game.laundry!=null and game.laundry.campaign.cinematic.active else game.field_kit.letter_camera.return_state
	game.state=normal
	var data=Save.capture(game)
	game.state=original
	if data.is_empty():return fallback.duplicate(true)
	var pos:Vector3=game.safety.save_position()
	data.position=[pos.x,pos.y,pos.z]
	if game.field_kit.letter_accepted:data.clock_appeared=true
	# 选信时退出，下次重新拿信，仍保留是否拒绝过的事实。
	if original in ["prologue_ui","prologue_choice"] and not game.field_kit.letter_accepted:
		data.room.envelope_taken=false
		data.field_items.held_id=""
	# 通话中退出，恢复为房东来电，避免错过挂断后的投信回调。
	if game.phone_ui.call_active or (data.mode!="laundry" and game.prologue_call_done and not game.prologue_letter_ready):
		data.room.prologue_call_done=false
	data["autosave"]=true
	return data
func write_snapshot(path: String, data: Dictionary) -> bool:
	if not Save.valid(data):return false
	var temp=path+".tmp";var file=FileAccess.open(temp,FileAccess.WRITE)
	if file==null:return false
	file.store_string(JSON.stringify(data));file.flush()
	var result=file.get_error();file.close()
	if result!=OK:return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temp),ProjectSettings.globalize_path(path))==OK
func read_snapshot(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):return {}
	var parser=JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path))!=OK:return {}
	var data=parser.data
	return data if data is Dictionary and Save.valid(data) else {}
func save_now() -> bool:
	if test_mode or game.state=="menu":return false
	var data=snapshot()
	var result=write_snapshot(PATH,data)
	if result:fallback=data;refresh_menu()
	return result
func continue_game() -> void:
	var data=read_snapshot(PATH)
	if data.is_empty():refresh_menu();return
	game.field_kit.reset()
	if Save.restore(game,data):
		game.safety.reset_zone()
		game.feedback.notify("已恢复自动保存","从上次离开的进度继续。手动存档仍在原槽位。")
func _process(delta: float) -> void:
	if game.state=="menu":return
	elapsed+=delta
	if elapsed<1:return
	elapsed=0
	if game.state in ["play","prologue","case_reader","case_dialogue","case_end"]:
		var data=snapshot()
		if not data.is_empty():fallback=data
func request_quit() -> void:
	if game.state!="menu" and not test_mode and not save_now():
		OS.alert("自动保存失败，游戏暂未退出。请在暂停菜单手动存档后再退出。","保存未完成")
		return
	get_tree().quit()
func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST and game!=null:request_quit()
