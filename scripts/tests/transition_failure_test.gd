extends SceneTree
class MissingLoader extends "res://scripts/scene_transition.gd":
	var missing:=true
	func resources_for(destination:String)->Array[String]:
		return ["res://assets/town/intentional_missing_review.glb"] if missing else super.resources_for(destination)
var game
var passed:=0
var errors:Array[String]=[]
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	if ok:passed+=1
	else:errors.append(label);push_error(label)
func run()->void:
	create_timer(80).timeout.connect(func():quit(2))
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	game._hide_menu();game._start_prologue(false);game._clear_sub()
	game.scene_transition.queue_free()
	var loader=MissingLoader.new();game.add_child(loader);loader.setup(game);game.scene_transition=loader
	var original:Vector3=game.player.global_position
	loader.begin("town")
	for i in range(20):
		await process_frame
		if loader.error_actions.visible:break
	check(loader.busy and loader.error_actions.visible,"缺资源显示重试与返回")
	check(not game.player.can_move and game.player.physics_frozen,"缺资源不能掉进未建场景")
	check(preload("res://scripts/case_save.gd").capture(game).is_empty(),"准备状态不写坏玩家现场")
	loader.return_to_origin()
	check(not loader.busy and not loader.overlay.visible,"返回关闭失败界面")
	check(game.state=="prologue" and game.prologue_stage=="room","恢复原房间与状态")
	check(game.player.global_position.distance_to(original)<.01 and game.player.can_move and not game.player.physics_frozen,"恢复原位置和移动")
	loader.begin("town")
	for i in range(20):
		await process_frame
		if loader.error_actions.visible:break
	loader.missing=false;loader.retry()
	while loader.busy:await process_frame
	check(game.prologue_stage=="town" and game.town_bridge.imported,"修复资源后重试可进街道")
	check(game.player.is_on_floor() and game.player.can_move,"碰撞与落地就绪才交还控制")
	check(game.town_bridge.layout.landmarks.size()==10,"复用十个原地标")
	game.town_bridge.leave();loader.generation+=1
	game.queue_free();await process_frame;await process_frame
	print("TRANSITION_FAILURE_RESULT ",JSON.stringify({"passed":passed,"failed":errors.size(),"errors":errors}));quit(0 if errors.is_empty() else 1)
