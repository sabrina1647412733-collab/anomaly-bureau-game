extends SceneTree
## State/operation regression. This directly exercises interfaces, not a player-route claim.
var game
var story
var passed := 0
var failed := 0
var deadline := 0
var completion_count := 0
var departure_count := 0

func check(ok: bool, message: String) -> void:
	if ok: passed += 1; print("[PASS] ",message)
	else: failed += 1; print("[FAIL] ",message)

func _initialize() -> void:
	deadline = Time.get_ticks_msec()+90000
	call_deferred("run")

func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() > deadline:
		print("[FAIL] deadline")
		quit(1)
	return false

func drain() -> void:
	if story == null: return
	for _i in range(60):
		if not story.dialogue.active: break
		story.dialogue.advance()
	game.audio_system.stop_voice()

func close() -> void:
	drain()
	if story.modal.visible: story.close_page()
	game._clear_sub()

func act(id: String) -> void:
	close()
	check(story.interact(id),"Recognized interaction "+id)
	drain()

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game._hide_menu()
	game._start_prologue(false)
	game.set_process(false)
	game.exit_save.set_process(false)
	game.player.set_physics_process(false)
	game.field_kit.letter_accepted = true
	story = preload("res://scripts/case2/case2_campaign.gd").new()
	game.add_child(story)
	story.setup(game)
	story.begin()
	story.request_departure.connect(func(): departure_count += 1)
	story.completed.connect(func(_summary): completion_count += 1)
	check(story.current_goal().id == "c2_aqi","Cooperation begins at the apartment door")
	act("c2_depart")
	check(departure_count == 0,"Departure cannot precede cooperation and address")
	act("c2_aqi")
	check(story.flag("coop_done"),"Aqi identifies herself as 临-07")
	check(not story.flag("orphanage_done"),"Conversation does not auto-complete address investigation")
	act("c2_orphanage")
	for key in ["name","place","photo"]: story.investigation.examine(key)
	drain()
	check(story.flag("orphanage_done") and story.has_evidence("c2_address_photo"),"Doorplate comparison preserves the photograph")
	check(story.has_evidence("c2_dispatch_order"),"00201 dispatched only after address verification")
	act("c2_depart")
	check(departure_count == 1,"Authorized departure signal emitted")
	story.on_arrival()
	drain()
	check(story.current_goal().id == "c2_register","Arrival explains the first concrete job")
	act("c2_master_meter")
	check(not story.flag("meter_recorded"),"No meter investigation before comparing source documents")
	act("c2_register")
	check(not story.investigation.choose_discrepancy(2),"Cannot answer unseen documents")
	for i in range(3): story.investigation.examine(str(i))
	check(not story.investigation.choose_discrepancy(0),"Normal building registration is not overwritten")
	check(story.investigation.choose_discrepancy(2),"Extra billing row identified")
	check(story.flag("register_matched"),"Document comparison persisted")
	act("c2_master_meter")
	check(not story.investigation.record_view("xuyan"),"Own record requires observing the moving needle")
	check(not story.investigation.observe_needle(2),"Stationary needle is not accepted")
	story.investigation.observe_needle(0)
	story.investigation.record_view("xuyan")
	check(not story.investigation.submit_pipe(),"One perspective is insufficient")
	story.investigation.record_view("aqi")
	story.investigation.select_branch("homes")
	check(not story.investigation.submit_pipe(),"Normal household branch not misidentified")
	story.investigation.select_branch("extra")
	check(story.investigation.submit_pipe(),"Two views and extra branch complete meter investigation")
	check(story.flag("meter_recorded") and story.has_evidence("c2_meter_record"),"Parallel transcript stored permanently")
	check(not story.flag("seventeen_open"),"17F does not open from the meter alone")
	var before_clock: Dictionary = story.capture()
	var clock_now: float = game.director.now()
	check(not story.advance_to(clock_now+300.0),"Clock cannot skip a required investigation")
	check(story.capture() == before_clock,"Rejected clock skip does not mutate investigation")
	act("c2_note")
	check(not story.flag("note_borrowed"),"Note cannot be taken before permission")
	act("c2_porridge")
	for key in ["pot","bowl","calendar"]: story.investigation.examine(key)
	drain()
	check(story.flag("meal_examined") and story.flag("note_borrowed"),"Meal comparison and borrowing dialogue complete")
	act("c2_storage")
	for key in ["bed","cup","kettle","rule"]: story.investigation.examine(key)
	check(story.flag("lived") and not story.flag("seventeen_open"),"Life evidence still needs a resident witness")
	act("c2_wage")
	check(not story.investigation.compare_signature(1),"Hidden signature not accepted from account front")
	story.investigation.flip_document()
	check(not story.investigation.compare_signature(0),"Incorrect handwriting can be retried")
	check(story.investigation.compare_signature(1),"Matching handwriting reveals the signed name")
	check(story.has_evidence("c2_wage"),"Wage evidence acquired only through examination")
	act("c2_schedule")
	act("c2_hebo")
	check(story.flag("he_confirmed") and story.flag("seventeen_open"),"Branch, life trace and one resident unlock 17F")
	act("c2_luggage")
	check(not story.flag("hospital_seen"),"Luggage inquiry follows corridor observation")
	act("c2_corridor")
	check(story.flag("sun_met") and not story.flag("corridor_complete"),"Meeting Sun is not a completed investigation")
	act("c2_corridor")
	check(not story.investigation.place_card("linen","06"),"Delivery order matters and can be rechecked")
	check(story.investigation.place_card("medicine","09"),"First delivery follows the written schedule")
	check(story.investigation.place_card("porridge","08"),"Second delivery preserves the ordinary care")
	check(story.investigation.place_card("linen","06"),"Third delivery completes the relational corridor")
	act("c2_luggage")
	story.invoke(0)
	drain()
	check(story.flag("hospital_seen"),"Returned hospital document records Sun's confirmed history")
	act("c2_aqi")
	check(story.flag("assist_history") and not story.flag("memory_shared"),"Four dispatches do not automatically grant protection")
	act("c2_aqi")
	check(story.flag("memory_shared"),"31.40 and the warm stop light exchanged")
	act("c2_dispatch")
	check(not story.flag("archive_approved"),"Archive cannot omit safety work or a second witness")
	act("c2_valves")
	story.investigation.select_branch("main")
	story.investigation.set_valve_value(90.0)
	check(not story.investigation.apply_valve(),"Main supply closure is safely rejected")
	check(not story.flag("leak_isolated") and not story.flag("source_closed"),"Rejected shutdown does not destroy relations")
	story.investigation.select_branch("leak")
	check(not story.investigation.apply_valve(),"Wrong-operation reset requires a deliberate valve turn")
	story.investigation.set_valve_value(90.0)
	check(story.investigation.apply_valve(),"Only the leaking segment is isolated")
	act("c2_intercom")
	check(story.flag("witness9"),"Second witness is independent, not duplicated He testimony")
	act("c2_dispatch")
	check(story.investigation.item_id == "archive","Complete material set opens evidence filing")
	check(not story.investigation.place_card("wage","living"),"Wage alone does not prove residence")
	for row in [["wage","identity"],["schedule","work"],["lived","living"],["he","relations"],["nine","relations"]]:
		check(story.investigation.place_card(row[0],row[1]),"Filed "+str(row))
	check(story.flag("archive_approved") and not story.flag("source_closed"),"Approval precedes the physical conclusion")
	act("c2_plaque")
	check(game.bag_has("c2_old_plaque") and not story.flag("plaque_hung"),"Old doorplate must be carried and hung")
	act("c2_rest_corner")
	check(story.flag("plaque_hung") and not game.bag_has("c2_old_plaque"),"Placed doorplate is not duplicated in inventory")
	act("c2_valves")
	story.investigation.select_branch("extra")
	story.investigation.set_valve_value(90.0)
	check(story.investigation.apply_valve(),"Approved abnormal source shut while household supply remains")
	check(story.flag("source_closed") and not story.flag("case_complete"),"Source closure still requires joint records")
	act("c2_aqi")
	check(story.flag("joint_signed") and not story.flag("name_returned"),"Both contributors have their evidence recorded")
	var salary_before := int(game.laundry.campaign.progress.earnings) if game.laundry != null else 0
	act("c2_aqi")
	check(completion_count == 1 and story.flag("case_complete"),"Unique ending and one completion signal")
	check(story.summary().returned_name == "沈知远" and story.summary().player_display_name == "许砚","Returned name does not arbitrarily rename player")
	check(not story.summary().cooperator_recorded and story.summary().cooperator_assistance_record,"Aqi assisted but remains unnamed and unrecorded in authority")
	check(story.summary().salary_amount == null,"No fabricated 800-yuan salary")
	if game.laundry != null: check(int(game.laundry.campaign.progress.earnings) == salary_before,"Second case cannot farm first-case wages")
	act("c2_dispatch")
	act("c2_aqi")
	check(completion_count == 1,"Revisiting conclusion does not duplicate payouts or finish")
	var state: Dictionary = story.capture()
	check(story.restore(JSON.parse_string(JSON.stringify(state))),"Completed case survives JSON round-trip")
	check(story.current_goal().id == "c2_exit" and story.flag("source_closed"),"Restored unique conclusion stays resolved")
	var invalid := state.duplicate(true)
	invalid.flags = []
	check(not story.restore(invalid),"Malformed flag containers rejected")
	invalid = state.duplicate(true)
	invalid.flags.case_complete = false
	check(not story.restore(invalid),"Inconsistent completion rejected")
	check(story.inspect_item("c2_returned_name"),"Acquired evidence can be taken out and reread")
	check(not story.inspect_item("c2_unknown"),"Unknown inventory IDs are not interpreted as clues")
	# Save/cancel midway through speech must not run its pending callback.
	close()
	var pending_finished := [false]
	story.speak("meter",func(): pending_finished[0] = true)
	story.cancel()
	check(not pending_finished[0] and not story.dialogue.active and not story.modal.visible,"Cancel stops the conversation without completing pending work")
	print("CASE2_CAMPAIGN_RESULT passed=%d failed=%d" % [passed,failed])
	for node in game.find_children("*","AudioStreamPlayer",true,false):
		node.stop()
		node.stream = null
	for node in game.find_children("*","AudioStreamPlayer3D",true,false):
		node.stop()
		node.stream = null
	game.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.2).timeout
	quit(1 if failed > 0 else 0)
