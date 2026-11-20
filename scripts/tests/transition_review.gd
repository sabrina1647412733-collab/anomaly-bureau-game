extends SceneTree
var game
var frames:Array[float]=[]
var results:Array=[]
var output:=""
var last_tick:=0
func _initialize()->void:call_deferred("run")
func sample(delta:float)->void:frames.append(delta*1000)
func transition(label:String,action:Callable,done:Callable)->void:
	frames.clear()
	var start=Time.get_ticks_usec()
	action.call()
	while not done.call():
		await process_frame
		if Time.get_ticks_usec()-start>90000000:push_error("transition timeout "+label);quit(2);return
	await process_frame
	var sum=0.0
	for value in frames:sum=maxf(sum,value)
	results.append({"label":label,"seconds":(Time.get_ticks_usec()-start)/1e6,"max_frame_ms":sum,"moving":game.player.can_move,"state":game.state,"grounded":game.player.is_on_floor()})
	print("TRANSITION_SAMPLE ",JSON.stringify(results.back()))
func run()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):output=arg.trim_prefix("--out=")
	Engine.max_fps=60;root.size=Vector2i(1600,900)
	last_tick=Time.get_ticks_usec()
	process_frame.connect(func():
		var now=Time.get_ticks_usec();sample((now-last_tick)/1e6);last_tick=now)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);await process_frame
	game._start_prologue(false);game.player.lock_look=true
	game._clear_sub();game.field_kit.letter_accepted=true
	await transition("room_town_cold",game._leave_room_to_town,func():return game.prologue_stage=="town" and game.state=="prologue" and not game._exit_to_town)
	game._clear_sub()
	await transition("town_laundry_cold",game._leave_room_to_laundry,func():return game.case_mode=="laundry" and game.state=="play" and not game._exit_to_laundry)
	game._clear_sub()
	await transition("laundry_town_warm",game._leave_laundry_to_town,func():return game.case_mode=="" and game.state=="prologue")
	game._clear_sub()
	await transition("town_laundry_warm",game._leave_room_to_laundry,func():return game.case_mode=="laundry" and game.state=="play" and not game._exit_to_laundry)
	if output!="":
		var f=FileAccess.open(output,FileAccess.WRITE);f.store_string(JSON.stringify({"renderer":RenderingServer.get_current_rendering_method(),"display":DisplayServer.get_name(),"results":results},"\t"))
	game._discard_laundry();game.queue_free();await process_frame;await process_frame;quit()
