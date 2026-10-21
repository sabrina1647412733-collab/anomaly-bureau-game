extends Node
## 本案共用时间、任务短信和便携时钟。时间以游戏分钟保存。
const RATE := 10.0
const ROOM_START := 23.0 * 60.0 + 10.0
const JOB := "临江里17号（老街27号院）二楼，得利自助洗衣店。今晚23:40报到，04:00交班，夜班报酬800元。工作：观察店内异常、记录线索，交班前留在店里。门下的通知书请本人确认。"
const EVENTS := [[1420.0,"23:40 到洗衣店报到"],[1441.0,"00:01 店内广播"],[1460.0,"00:20 再听一次广播"],[1530.0,"01:30 来客"],[1590.0,"02:30 停电"],[1630.0,"03:10 数衣服"],[1660.0,"03:40 回应她"],[1675.0,"03:55 交班"],[1676.0,"03:56 领取报酬"],[1678.0,"03:58 广播"],[1680.0,"04:00 天亮"],[1681.0,"04:01 长椅"],[1682.0,"04:02 归档"]]
var game
var room_minutes := ROOM_START
var sent := {}
var idle := 0.0
var modal: Control
var time_label: Label
var event_label: Label
var toast: Button
var toast_time := 0.0
var toast_sender := ""
var return_state := "prologue"

func setup(g) -> void:
	game = g
	var layer := CanvasLayer.new()
	layer.layer = 27
	add_child(layer)
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(modal)
	game.field_kit.shade(modal)
	var ui = game.phone_ui
	var panel: Panel = ui.box(modal, Vector2(350,100), Vector2(900,700), Color("18282b"), 12)
	ui.lab(panel,"诡异时钟",Vector2(44,30),Vector2(800,50),32)
	ui.lab(panel,"现实1分钟 = 游戏10分钟  ·  24小时制",Vector2(44,88),Vector2(800,32),18,Color("adb8ac"))
	time_label = ui.lab(panel,"23:10:00",Vector2(44,150),Vector2(800,90),62)
	event_label = ui.lab(panel,"",Vector2(44,255),Vector2(800,95),23)
	ui.btn(panel,"拨快10分钟",Vector2(44,380),Vector2(250,64),func(): advance(10.0))
	ui.btn(panel,"拨快30分钟",Vector2(325,380),Vector2(250,64),func(): advance(30.0))
	ui.btn(panel,"到下一事件",Vector2(606,380),Vector2(250,64),next_event,Color("416856"))
	ui.lab(panel,"拨时会停在下一件关键事件，先处理眼前的事，再继续拨。\n暂停、背包和阅读界面期间，时间停走。事件发生后保留记录。",Vector2(44,490),Vector2(810,86),18,Color("b8c5ba"))
	ui.btn(panel,"收起时钟  [ B / ESC ]",Vector2(540,610),Vector2(316,50),func(): close_clock(true))
	modal.visible = false
	var notifications := CanvasLayer.new()
	notifications.layer = 21
	add_child(notifications)
	var notification_root := Control.new()
	notification_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	notification_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notifications.add_child(notification_root)
	toast = ui.btn(notification_root,"",Vector2(740,130),Vector2(810,94),open_message,Color("253e3e"))
	toast.add_theme_font_size_override("font_size",17)
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast.visible = false

func reset() -> void:
	room_minutes = ROOM_START
	sent.clear()
	idle = 0.0
	modal.visible = false
	toast.visible = false
	toast_time = 0.0
	game.phone_ui.reset_messages()

func now() -> float:
	return game.laundry.START_MIN + game.laundry.t / 60.0 if game.case_mode == "laundry" and game.laundry != null else room_minutes

func hhmm(value: float, seconds := false) -> String:
	var t := int(value * 60.0) % 86400
	return "%02d:%02d:%02d" % [t / 3600,(t / 60) % 60,t % 60] if seconds else "%02d:%02d" % [t / 3600,(t / 60) % 60]

func send_once(id: String, who: String, text: String) -> void:
	if sent.has(id): return
	sent[id] = true
	game.phone_ui.receive(who,text)
	toast_sender = who
	toast.text = who + " · 新消息\n" + text.left(68) + "  [点击查看]"
	toast.visible = true
	toast_time = 9.0
	game.audio_system.sfx("ui_tap",-6)

func open_message() -> void:
	if game.state not in ["prologue","play"] or game.choice != null: return
	if not game.field_kit.phone_owned:
		game._prologue_set_objective("手机在书桌上。走近，按 E 拿起。")
		return
	game.field_kit.equip("phone")
	game._open_phone()
	game.phone_ui.active_chat = toast_sender
	game.phone_ui._goto("conversation")
	toast.visible = false

func after_rent_call() -> void:
	var run: int = game.field_kit.generation
	await get_tree().create_timer(1.0).timeout
	if run != game.field_kit.generation or game.case_mode == "laundry" or game.state == "menu": return
	send_once("job","派遣科",JOB)
	game.note("话","夜班招聘 · 800元",JOB)
	game._prologue_set_objective("房租还差很多。得利洗衣店招夜班，800元。先取门下的通知书。")
	if not game.prologue_letter_ready: game._prologue_drop_letter()

func accepted() -> void:
	send_once("accepted","派遣科","已确认入职。今晚去洗衣店值夜班，不是去洗衣服。带上通知书和桌上的黄铜时钟，从房门出发；23:40报到，04:00交班领800元。")

func on_arrival() -> void:
	send_once("arrive","派遣科","你已到一楼门厅。沿门厅向里走到尽头，上左侧楼梯到二楼，进入得利洗衣店。先读价目表和广播须知，再记录异常。空闲时可按T拨动随身时钟。")

func step(delta: float) -> void:
	if game.state == "menu":
		toast.visible = false
		return
	if game.state == "paused": return
	if game.case_mode != "laundry" and not game.state.begins_with("prologue") and game.state != "clock_ui": return
	toast_time -= delta
	if toast_time <= 0: toast.visible = false
	if game.bag_open or game.phone_open or game.field_kit.letter_ui.visible or modal.visible: toast.visible = false
	var free: bool = game.state in ["prologue","play"] and not game.phone_open and not game.bag_open and not game.nb_open and not modal.visible and game.choice == null and not game.sub_pause
	if free and game.case_mode != "laundry": room_minutes += delta * RATE / 60.0
	game.clock_min = now()
	if game.wclock != null:
		game.wclock.total_min = now() - 1420.0
		game.wclock._update_hands()
	if free:
		idle += delta
		if idle > 45.0:
			idle = 0.0
			var objective: String = game.case_objective if game.case_mode == "laundry" else game.prologue_objective
			send_once("hint_"+objective,"派遣科" if game.prologue_call_done else "房东",objective)
	if game.case_mode == "laundry" and game.laundry != null:
		var t: float = game.laundry.t / 60.0
		if t >= 21: send_once("bc1","派遣科","广播已经响了。先看清七号机、价目表和后房。信息可用Tab记在记事本里，之后用T跳到下一事件。")
		if t >= 40: send_once("bc2","派遣科","第二遍广播少了一个字。留意七号机里的衣服；钥匙在后房附近，先搜集线索，再等01:30的来客。")
		if t >= 110: send_once("visitor","派遣科","有客人进来了。先观察她，不要急着答话。03:10她会清点衣物，看看还缺少什么。")
		if t >= 210: send_once("count","派遣科","她停在第五件。检查七号机里的童装毛衣，03:40她会向你要一个回答。")
		if game.laundry.selected_ending != "": send_once("handover","派遣科","处置已记录。接下来03:55交班、03:56领报酬、04:00天亮。你可以继续探索，也可以用T拨到交班。")
	if modal.visible: refresh_clock()

func open_clock() -> void:
	if not game.bag_has("weird_clock") or game.state not in ["prologue","play"] or game.choice != null: return
	if game.phone_open: game._close_phone()
	if game.bag_open: game.field_kit.open_inventory(false)
	return_state = game.state
	game.state = "clock_ui"
	game.player.can_move = false
	game.player.allow_capture = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	modal.visible = true
	refresh_clock()

func close_clock(stow := false) -> void:
	modal.visible = false
	game.state = return_state
	game.player.can_move = true
	game.player.allow_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if stow: game.field_kit.stow()

func next_mark() -> Array:
	for event in EVENTS:
		if float(event[0]) > now() + .02:
			return event
	return [now()+10.0,"本夜事件已结束"]

func refresh_clock() -> void:
	time_label.text = hhmm(now(),true)
	event_label.text = "下一事件  " + String(next_mark()[1])
	if game.case_mode != "laundry": event_label.text += "\n先从房门去洗衣店报到。"

func next_event() -> void:
	advance(maxf(.1,float(next_mark()[0])-now()))

func advance(minutes: float) -> void:
	if not modal.visible: return
	var target := minf(now()+minutes,float(next_mark()[0]))
	close_clock(false)
	if game.case_mode == "laundry" and game.laundry != null:
		game.laundry.t = maxf(game.laundry.t,(target-1420.0)*60.0)
		game.laundry._timeline()
	else:
		room_minutes = maxf(room_minutes,minf(target,1420.0))
		game._prologue_set_objective("23:40去得利洗衣店报到，值夜班到04:00，报酬800元。带通知书，从房门出发。")
	game.clock_min = now()
	game.audio_system.sfx("ui_tap",-8)
	idle = 0.0

func capture() -> Dictionary:
	return {"room_minutes":room_minutes,"sent":sent.duplicate(true),"messages":game.phone_ui.messages.duplicate(true),"unread":game.phone_ui.unread.duplicate(true)}

func restore(data: Dictionary) -> void:
	room_minutes = float(data.get("room_minutes",ROOM_START))
	sent = data.get("sent",{}).duplicate(true)
	game.phone_ui.messages = data.get("messages",game.phone_ui.messages).duplicate(true)
	game.phone_ui.unread = data.get("unread",{}).duplicate(true)

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if modal.visible and event.physical_keycode in [KEY_ESCAPE,KEY_B]:
		close_clock(true)
		get_viewport().set_input_as_handled()
	elif event.physical_keycode == KEY_T and game.bag_has("weird_clock") and game.state in ["prologue","play"] and not game.nb_open:
		open_clock()
		get_viewport().set_input_as_handled()
