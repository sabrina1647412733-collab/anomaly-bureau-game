extends SceneTree
const Save=preload("res://scripts/case_save.gd")
const Paths=preload("res://scripts/storage_paths.gd")
const UI=preload("res://scripts/field_ui_style.gd")
var game
var passed:=0
var failed:=0
var fixture:Dictionary
var issues:Array[String]=[]
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
	if ok:passed+=1;print("PASS ",label)
	else:failed+=1;issues.append(label);push_error("FAIL "+label)
func raw_write(path:String,value:String):
	var f=FileAccess.open(path,FileAccess.WRITE);f.store_string(value);f.close()
func restore_fixture():
	check(Save.restore(game,fixture),"恢复真实第二夜检查点")
	game.set_process(false);game.player.set_physics_process(false);game.safety.set_physics_process(false)
	game._clear_sub();game.audio_system.stop_voice()
func run():
	create_timer(180).timeout.connect(func():push_error("UI save test timeout");quit(2))
	if not OS.get_cmdline_user_args().has("--verify") or not Paths.root_dir().begins_with("F:"):
		push_error("Explicit isolated F drive test data required");quit(2);return
	var folder:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fixtures-dir="):folder=arg.trim_prefix("--fixtures-dir=")
	for name in DirAccess.get_files_at(folder):
		if name.contains("第2夜_c1_photo"):
			fixture=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join(name)));break
	if fixture.is_empty():push_error("Normal-route second-night fixture required");quit(2);return
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	restore_fixture()
	check(game.laundry.campaign.night_number()==2,"正常路线进入第二夜")
	var progress:Dictionary=game.laundry.campaign.capture()
	var goal:Dictionary=game.laundry.campaign.current_goal()
	var bag:Array=game.case_bag.duplicate(true)
	for i in 3:
		game._open_pause();game.menu.set_slots(game.slots_info(),"save");game.menu.show_slots("save")
		game.menu.slot_btns[i].pressed.emit()
		check(game.state=="play" and not game.player.physics_frozen and game.player.can_move,"手动槽位%d保存后解除物理冻结"%(i+1))
		check(not Save.read_file(game.SLOT_PATHS[i]).is_empty(),"槽位%d真实写入并校验"%(i+1))
		var meta:Dictionary=game.slots_info()[i]
		check(meta.night==2 and not meta.location.is_empty() and meta.clock.contains("游戏时间") and meta.time.contains("保存于"),"槽位元信息完整")
	game._open_pause();game.menu.set_slots(game.slots_info(),"save");game.menu.show_slots("save")
	var original:=FileAccess.get_sha256(game.SLOT_PATHS[0])
	game.menu.slot_btns[0].pressed.emit()
	check(game.menu.slot_confirm.visible and FileAccess.get_sha256(game.SLOT_PATHS[0])==original,"覆盖前确认，不提前写入")
	game.menu.slot_confirm.confirmed.emit();game.menu.slot_confirm.hide()
	check(not game.player.physics_frozen and FileAccess.file_exists(game.SLOT_PATHS[0]+".bak"),"确认覆盖后备份上一份有效档")
	check(game.game_load(0),"第二夜槽位正确恢复")
	check(game.laundry.campaign.capture()==progress and game.case_bag==bag and game.laundry.campaign.current_goal()==goal,"恢复案件状态、证据、背包与当前目标一致")
	check(not game.phone_open and not game.phone_ui.call_active and not game.audio_system.is_busy() and game.hud_fade.modulate.a==0 and game.player.cam.current,"不恢复电话语音、黑屏与临时镜头")
	for id in game.laundry.campaign.physical:
		check(game.laundry.campaign.physical[id].visible==not game.laundry.has_clue(id),"可交互物件与证据一致："+id)
	game.field_kit.show_letter(false);game._open_pause()
	check(game.game_save(1),"第二夜阅读入职通知书时可保存")
	game._on_resume();game.field_kit.close_letter()
	game.laundry.campaign.show_page("读取测试",game.laundry.campaign.DOCS.discharge[1]);game._open_pause()
	check(game.game_save(1),"调查阅读中保存")
	game._on_resume();game.laundry.campaign.close_page()
	game.laundry.campaign.dialogue.play([["许砚","记录仍待核实。"]]);game._open_pause()
	check(game.game_save(1),"对白暂停时保存稳定现场")
	game._on_resume();game.laundry.campaign.dialogue.cancel();game.state="play"
	game.laundry.campaign.cinematic.play("seven");game._open_pause()
	check(game.game_save(1),"临时镜头演出中保存")
	game._on_resume();game.laundry.campaign.cinematic.cancel();game.state="play"
	game.director.open_clock();game._open_pause();check(game.game_save(1),"时钟界面保存")
	game._on_resume();game.director.close_clock()
	game.laundry.clues["pipe_map"]=true
	game.laundry.campaign.climb_skylight(false)
	check(not game.player.is_physics_processing(),"建立真实检修梯临时输入状态")
	check(Save.restore(game,fixture) and game.player.is_physics_processing(),"读档取消旧梯间位移并恢复物理处理")
	var restored_position:Vector3=game.player.global_position
	game.player.set_physics_process(false)
	await create_timer(2.1).timeout
	check(game.player.global_position.distance_to(restored_position)<.01,"旧演出Tween不会继续搬动读档后的玩家")
	game.state="exit_to_town";game._pre_pause_state=""
	check(not game.game_save(1) and Save.last_error.contains("切换场景"),"场景切换明确说明暂不能保存")
	check(game.exit_save.snapshot().is_empty(),"退出自动档不会把旧场景fallback伪装为最新进度")
	game.state="play"
	var path:String=Paths.file("failure.json")
	check(Save.write_snapshot(path,Save.capture(game)),"写入失败前的有效档")
	var hash_before:=FileAccess.get_sha256(path)
	DirAccess.make_dir_recursive_absolute(path+".tmp")
	check(not Save.write_snapshot(path,Save.capture(game)) and not Save.last_error.is_empty(),"实际目录冲突触发写盘失败并给出原因")
	check(FileAccess.get_sha256(path)==hash_before,"写盘失败不破坏最后有效档")
	DirAccess.remove_absolute(path+".tmp")
	check(Save.write_snapshot(path,Save.capture(game)),"重复覆盖成功")
	raw_write(path,"{broken")
	check(not Save.read_snapshot(path).is_empty() and Save.last_error.contains("备份"),"损坏主档可回退有效备份")
	DirAccess.remove_absolute(path)
	check(not Save.read_snapshot(path).is_empty(),"主档缺失可回退有效备份")
	var malformed:Dictionary=fixture.duplicate(true);malformed.laundry.t="bad"
	check(not Save.valid(malformed) and not Save.write_snapshot(path,malformed),"结构损坏的JSON拒绝覆盖")
	var old:Dictionary=fixture.duplicate(true);old.erase("slot_metadata");old.erase("phone")
	check(Save.valid(old) and Save.restore(game,old),"既有schema2无新增字段存档兼容")
	# The real second-night failure: a retained laundry campaign in the apartment,
	# while its rest receipt is open, used to enter the obsolete station writer.
	game.laundry.world.visible=false;game.case_mode="";game.state="prologue";game._show_prologue_stage("room")
	game.laundry.campaign.show_page("休息前的调查记录","当前案件尚未结束。")
	game._open_pause();game._on_save_slot(2)
	var room_save:Dictionary=Save.read_file(game.SLOT_PATHS[2])
	check(room_save.get("case_id")=="00184" and room_save.get("mode")=="" and room_save.get("state")=="prologue","出租屋阅读回执时保存仍使用当前案件格式，不误写旧车站档")
	game._on_resume();game.laundry.campaign.close_page()
	check(game.delete_slot(0) and Save.read_snapshot(game.SLOT_PATHS[0]).is_empty(),"删除槽位同时移除备份，不会重新出现")
	Paths.inspection_active=true
	check(not game.game_save(2) and not game.exit_save.save_now(),"巡查拒绝写入正式槽位和自动档")
	Paths.inspection_active=false
	restore_fixture()
	game.phone_ui.quiet=true;game.field_kit.held_id="phone";game.field_kit.phone_owned=true
	game._open_phone();game.phone_ui.call_active=true;game.phone_ui._goto("in_call")
	check(game.game_save(1),"手机通话界面保存")
	check(game.game_load(1) and not game.phone_ui.call_active and game.phone_ui.quiet,"读档保留设备设置，停止瞬态通话")
	var long_text:String=(game.laundry.campaign.DOCS.testimony[1]+game.laundry.campaign.DOCS.discharge[1]).repeat(3)
	var pages:Array[String]=UI.pages(long_text,game.font,1100,32)
	check(pages.size()>2 and "".join(pages).replace("\n","")==long_text.replace("\n",""),"长中文逐页完整保留，无截断")
	game.laundry.campaign.dialogue.play([["许砚",long_text]])
	check(game.laundry.campaign.dialogue.text_pages.size()>2,"长对白采用实际分段控件")
	game.feedback.notify("线索已记录","303家庭照片");game.feedback.step(1);game.director.sync_toast(1)
	check(not game.feedback.panel.visible and not game.director.toast.visible,"对白期间线索与短信不抢占字幕")
	game.laundry.campaign.dialogue.finish(false)
	game._open_phone();game.phone_ui.call_text=long_text;game.phone_ui.call_active=true;game.phone_ui._goto("in_call")
	for i in 4:await process_frame
	var transcript=game.phone_ui.screen.get_node("CallTranscript")
	check(transcript.get_v_scroll_bar().max_value>transcript.size.y,"手机长字幕在屏内滚动")
	game.phone_ui.close();check(not game.phone_ui.call_active and not game.audio_system.is_busy(),"关闭电话停止对应语音")
	game.case_bag=[];game.field_kit.open_inventory(true);await process_frame
	check(game.field_kit.inventory.empty.visible and game.field_kit.take_button.disabled,"空背包不保留旧取出目标")
	game.field_kit.open_inventory(false)
	var out:Dictionary={"passed":passed,"failed":failed,"issues":issues,"fixture":"normal input route second-night photograph checkpoint","data_root":Paths.root_dir()}
	raw_write(Paths.file("results.json"),JSON.stringify(out,"\t"))
	game.audio_system.stop_voice();game.queue_free();await process_frame;await process_frame
	print("UI_SAVE_RESULT ",passed," passed ",failed," failed");quit(0 if failed==0 else 1)
