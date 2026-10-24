extends "res://scripts/tests/normal_route_review.gd"
## Normal keyboard route; actual pause/slot button/overwrite confirmation at checkpoints.
var saves:Array=[]
var serial:=0
func _initialize() -> void:
	var isolated:=false
	for arg in OS.get_cmdline_user_args():
		if arg.replace("\\","/").begins_with("--data-dir=F:"):isolated=true
	if not OS.get_cmdline_user_args().has("--verify") or not isolated:
		push_error("--verify and an explicit F drive --data-dir are required");quit(2);return
	super._initialize()
func shot(label:String) -> void:
	await checkpoint(label)
func checkpoint(label:String) -> void:
	if game==null or game.state=="menu":return
	var prior:String=game.state
	var expected:Dictionary=preload("res://scripts/case_save.gd").capture(game)
	game._open_pause();game.menu.set_slots(game.slots_info(),"save");game.menu.show_slots("save")
	var slot:int=serial%3
	game.menu.slot_btns[slot].pressed.emit()
	if game.menu.slot_confirm.visible:
		game.menu.slot_confirm.confirmed.emit();game.menu.slot_confirm.hide()
	var reason:String=preload("res://scripts/case_save.gd").last_error
	var data:Dictionary=game.exit_save.read_snapshot(game.SLOT_PATHS[slot])
	var ok:bool=not data.is_empty() and game.state==prior and (not game.player.physics_frozen or prior=="case_cinematic") and data.get("mode")==expected.get("mode") and data.get("laundry",{}).get("campaign",{})==JSON.parse_string(JSON.stringify(expected.get("laundry",{}).get("campaign",{})))
	if not ok:fail("保存按钮未恢复原状态："+label)
	if not ok:print("SAVE_MISMATCH prior=",prior," now=",game.state," reason=",reason," note=",game.menu.archive_note.text," expected=",expected.get("laundry",{}).get("campaign",{})," actual=",data.get("laundry",{}).get("campaign",{}))
	if game.state=="paused":game._on_resume()
	var name:String="%03d_"%serial+label.validate_filename()+".json"
	var f=FileAccess.open(report_dir+name,FileAccess.WRITE);f.store_string(JSON.stringify(data));f.close()
	saves.append({"file":name,"label":label,"night":data.get("laundry",{}).get("campaign",{}).get("night",0),"mode":data.get("mode",""),"stage":data.get("stage",""),"saved":ok,"slot":slot})
	f=FileAccess.open(report_dir+"checkpoints.json",FileAccess.WRITE);f.store_string(JSON.stringify(saves,"\t"));f.close()
	serial+=1
func press_target(id:String,at:Vector3) -> bool:
	var result:bool=await super.press_target(id,at)
	if result and id=="case_rest":await checkpoint("床边休息页")
	return result
func town_to(id:String) -> bool:
	var result:bool=await super.town_to(id)
	if result:await checkpoint("街道入口_"+id)
	return result
