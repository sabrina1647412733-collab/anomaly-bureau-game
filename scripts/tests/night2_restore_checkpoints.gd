extends SceneTree
const Save=preload("res://scripts/case_save.gd")
var game
var passed:=0
var failed:=0
var records:Array=[]
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
	if ok:passed+=1
	else:failed+=1;push_error(label)
func run():
	create_timer(240).timeout.connect(func():quit(2))
	var folder:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fixtures-dir="):folder=arg.trim_prefix("--fixtures-dir=")
	if not OS.get_cmdline_user_args().has("--verify") or folder.is_empty():quit(2);return
	var index=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join("checkpoints.json")))
	if not index is Array:quit(2);return
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	var chosen:Dictionary={}
	for row in index:
		var label:String=row.label
		var key:String="%d_"%int(row.night)+label
		if int(row.night)>2 or (not label.contains("c1_terminal") and not label.contains("c1_photo") and not label.contains("街道入口") and not label.contains("进入下一夜") and not label.contains("床边休息页")):continue
		if chosen.has(key):continue
		chosen[key]=true
		var d=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join(row.file)))
		var before_failed:int=failed
		check(d is Dictionary and Save.valid(d),"存档结构有效："+label)
		if not d is Dictionary or not Save.valid(d):continue
		check(Save.restore(game,d),"恢复："+label)
		game.set_process(false);game.player.set_physics_process(false);game.safety.set_physics_process(false)
		check(game.case_mode==d.mode and (d.mode=="laundry" or game.prologue_stage==d.stage),"恢复原地点和场景")
		check(game.laundry.campaign.night_number()==int(row.night) and game.laundry.campaign.capture()==d.laundry.campaign,"恢复原夜次、交班与工资记录")
		check(game.case_bag==d.bag and game.laundry.clues==d.laundry.clues,"背包与证据一致")
		check(game.director.capture().messages==d.director.messages,"手机消息不会重复或丢失")
		check(game.player.global_position.distance_to(Vector3(d.position[0],d.position[1],d.position[2]))<.01,"坐标一致")
		check(not game.player.physics_frozen and game.player.cam.current and game.hud_fade.modulate.a==0,"不恢复瞬态冻结、镜头或黑屏")
		var spinning:Dictionary={}
		for machine in d.laundry.spinning:spinning[int(machine)]=bool(d.laundry.spinning[machine])
		check(game.laundry.spinning==spinning,"设备状态一致")
		if game.case_mode=="laundry":check(game.case_objective==game.laundry.campaign.objective(),"现场任务与可交互对象一致")
		records.append({"file":row.file,"night":row.night,"label":label,"passed":before_failed==failed,"mode":game.case_mode,"stage":game.prologue_stage})
		print("RESTORE_CHECK ",JSON.stringify(records.back()))
		for i in 3:await process_frame
	var path:String=preload("res://scripts/storage_paths.gd").file("restore_results.json")
	var file=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify({"passed":passed,"failed":failed,"records":records},"\t"));file.close()
	game.queue_free();await process_frame;await process_frame
	print("RESTORE_CHECK_RESULT ",passed," passed ",failed," failed");quit(0 if failed==0 else 1)
