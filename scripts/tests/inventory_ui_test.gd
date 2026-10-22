extends SceneTree
var passed:=0
var failed:=0
var game
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
	if ok:passed+=1;print("[PASS] ",label)
	else:failed+=1;push_error("FAIL "+label)
func key(code:Key):
	var event=InputEventKey.new();event.physical_keycode=code;event.pressed=true
	game.field_kit._input(event)
func click(control:Control):
	var at=control.get_global_rect().get_center()
	var motion=InputEventMouseMotion.new();motion.position=at;root.push_input(motion,true)
	for down in [true,false]:
		var event=InputEventMouseButton.new();event.position=at;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
		root.push_input(event,true)
	await process_frame
func run():
	create_timer(65).timeout.connect(func():quit(2))
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	game._hide_menu();game._start_prologue(false);game.set_process(false);game.player.set_physics_process(false)
	var kit=game.field_kit;var view=kit.inventory
	game.case_bag=[]
	for item in [["phone","手机"],["weird_clock","诡异时钟"],["envelope","入职通知书"],["photo","303家庭照片"],["sweater_record","原衣交还记录"],["drawer_key","303抽屉钥匙"],["tool_key","503检修盒钥匙"],["sweater","七号机原衣"],["sandal","蓝布鞋"]]:
		game.case_bag.append({"id":item[0],"name":item[1],"desc":"测试说明。\n".repeat(40),"kind":"物"})
	var original=game.case_bag.duplicate(true)
	kit.open_inventory(true);await process_frame
	check(view.CATEGORIES==["道具","线索","钥匙","衣物"] and view.tabs.size()==4,"只有四个分类，没有全部入口")
	check(view.category=="道具" and view.filtered.size()==2,"打开背包默认道具分类")
	check(kit.grid.columns==6 and kit.grid.get_child_count()==24,"保留六列四行方格")
	check(not game.player.can_move and not game.player.allow_capture,"背包打开时禁止现场移动和鼠标转头")
	var seen=[]
	for category in view.CATEGORIES:
		view.set_category(category)
		check(view.filtered.all(func(item):return view.category_of(item.id)==category),"分类实际过滤："+category)
		for item in view.filtered:seen.append(item.id)
	check(seen.size()==9 and seen.count("sweater_record")==1 and view.category_of("sweater_record")=="线索","物品不丢失，原衣记录归线索")
	check(game.case_bag==original,"切分类不会改写背包所有权或顺序")
	kit.select("photo");await process_frame
	check(view.category=="线索" and view.title.text=="303家庭照片" and kit.selected_id=="photo","指定物品自动进入所在分类并同步详情")
	check(kit.detail.get_parent() is ScrollContainer and kit.detail.get_parent().get_v_scroll_bar().max_value>105,"长说明可滚动，取出按钮不被文字推走")
	view.select_item("envelope");view.item_selected.emit("envelope")
	check(kit.detail.text.contains("五条须知") and not kit.detail.text.contains("活到交班"),"信封显示清楚摘要，正文保留原阅读入口")
	view.set_category("衣物");view.set_category("线索")
	check(kit.selected_id=="envelope","返回分类记住此前选中物品")
	view.tabs[2].pressed.emit()
	check(view.category=="钥匙" and kit.selected_id=="drawer_key","点击分类同步取出目标")
	key(KEY_RIGHT)
	check(kit.selected_id=="tool_key","方向键可以选择下一件物品")
	key(KEY_TAB)
	check(view.category=="衣物" and not game.nb_open,"Tab切分类，不误开记事本")
	kit.select("phone");key(KEY_E)
	check(not game.bag_open and kit.held_id=="phone" and kit.rig.item_id=="phone","E从新界面取出对应物品并显示持物模型")
	kit.stow();kit.open_inventory(true);await process_frame
	kit.select("envelope");view.take_button.pressed.emit()
	check(kit.held_id=="envelope" and not kit.inventory.visible,"鼠标取出按钮与快捷键行为一致")
	kit.stow();kit.open_inventory(true)
	check(view.category=="道具","重新打开仍默认道具")
	key(KEY_ESCAPE)
	check(not game.bag_open and game.player.can_move and game.player.allow_capture,"Esc关闭后恢复现场控制")
	kit.open_inventory(true);view.close_requested.emit()
	check(not game.bag_open,"右上关闭按钮可以关闭背包")
	if DisplayServer.get_name()!="headless":
		kit.open_inventory(true);await process_frame
		await click(view.tabs[1])
		check(view.category=="线索","真实窗口鼠标点击分类标签")
		await click(view.grid.get_child(1))
		check(kit.selected_id=="photo","真实窗口鼠标点击物品格")
		await click(view.take_button)
		check(kit.held_id=="photo" and not game.bag_open,"真实窗口鼠标点击取出按钮")
		kit.stow();kit.open_inventory(true)
		for extent in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(1600,900)]:
			root.size=extent;await process_frame;await process_frame
			check(root.get_visible_rect().encloses(view.panel.get_global_rect()),"窗口大小改变后面板仍在可视区域："+str(extent))
	game.case_bag=[];kit.open_inventory(true);await process_frame
	check(kit.selected_id=="" and view.art.texture==null and kit.take_button.disabled and view.empty.visible,"空分类清除旧详情和取出目标")
	key(KEY_E)
	check(kit.held_id=="" and game.bag_open,"空分类按E不会取出旧物品或关闭")
	for i in 31:game.case_bag.append({"id":"extra_%d"%i,"name":"长线索%d"%i,"desc":"记录","kind":"物"})
	kit.refresh_inventory();view.set_category("线索");await process_frame;await process_frame
	check(kit.grid.get_child_count()==36 and view.filtered.size()==31,"超过24件自动增加行数，不丢物品")
	view.move_selection(30);await process_frame;await process_frame
	check(kit.selected_id=="extra_30" and view.scroll.scroll_vertical>0,"选择底部物品时滚动跟随")
	var snapshot=preload("res://scripts/case_save.gd").capture(game)
	check(snapshot.bag.size()==31,"新分类不改变存档中的背包数据")
	for id in ["phone","envelope","weird_clock","sweater","shoe","photo","document","registered","pipe_map","badge","permcard","key","back_key","drawer_key","mail_key","tool_key","machine_key"]:
		var image=Image.load_from_file(ProjectSettings.globalize_path(view.ART+id+".png"))
		var used=image.get_used_rect()
		check(not image.is_empty() and image.get_width()==640 and used.size.x>100 and used.size.y>100,"物品缩略图非空且清晰："+id)
	game.queue_free();await process_frame;await process_frame
	print("INVENTORY_UI_RESULT PASS=",passed," FAIL=",failed);quit(1 if failed else 0)
