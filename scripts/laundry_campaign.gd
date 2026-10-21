extends Node
## 第一案三夜调查。剧情结果唯一；调查顺序和可选线索自由。
const Props := preload("res://scripts/case1_prop.gd")
const DOCS := {
	"slip": ["未取洗衣单", "秀兰干洗 · 留存联\n2004-11-07\n顾客：周秀兰\n七号机 · 童装一套\n状态：未取\n\n许砚：单子在，衣服就不会丢。"],
	"registry": ["旧顾客登记簿", "2004-11-07，周秀兰，七号机，童装一套，未取。\n店主签字：周秀兰。\n\n她和这家店同名。"],
	"sign": ["旧招牌拓记", "漆下凸起四个字：秀兰干洗。\n2004年事故之后，店名改成了得利。"],
	"photo": ["303家庭照片", "一家三口。孩子的脸被刮去，男方的脸也有损伤。\n背面：小满六岁，出院回来补拍。\n\n照片证明有人想留下这一天；不能据此判断孩子已经死亡。"],
	"marriage": ["结婚证", "女方：周秀兰。\n男方：姓名与照片被人为刮损。\n住址：老街27号303。\n\n她替他留的东西，比替自己留的多。"],
	"cert": ["周小满的接种证", "姓名：周小满　性别：男\n监护人：周秀兰\n住址：老街27号304\n\n这是一份接种记录，出院日期应另找医院的出院小结核实。"],
	"homework": ["最后一页作业", "2004-11-07\n妈妈说，衣服干了就能出门。\n\n门外有女人轻声说：鞋穿好，地上凉。\n你出去看，走廊却没有人。"],
	"stones": ["窗台上的日期", "366颗石头。先核对两端日期与数量，不必逐个捡起。\n最后一颗刻着：2004-11-06。\n\n许砚：不是玩石头。是在等一天。"],
	"return_card": ["503挂号信退件卡", "收件人：周秀兰\n转存号：27—503—1107\n旧件移存邮政存档间，入口经二楼东侧廊桥。\n\n这是楼内旧存档间，不是街道上的小邮局。"],
	"discharge": ["未投递的出院小结", "挂号件：27—503—1107\n患者：周小满，男，6岁\n出院日期：2004-11-06\n收件家属：周秀兰\n\n许砚：周小满。原来你不是没名字，是没人把信送来。"],
	"testimony": ["老周的口述", "她进去抱孩子。后房先冒烟。我们都盯着烟，谁也没看脚底下。\n出来的是水。整栋楼的水，都从那一间过。\n孩子？我没见着。没见着的事，你别替我写。\n\n证据类别：亲历者口述，待现场核实。"],
	"pipe_map": ["全楼管线图", "老周手绘：屋顶旁通管→2F后房→B1蓄水池。\n503检修盒与502之间有共用维修通道。\n配电操作：先隔离浸水回路，再接独立排水泵，最后开启排水阀。\n\n现场水痕和事故时间还需要逐项核实。"],
	"tool_key": ["503检修盒钥匙", "403维修挂板交接条：七号机钥匙移存503检修盒。\n这把钥匙只开检修盒，不开503房门。"],
	"machine_key": ["七号机专用钥匙", "503检修盒维修单：七号机滚筒锁专用。\n外门钥匙、303抽屉钥匙与信箱钥匙均不能代替。"],
	"roof_copy": ["重复的童装", "七件同款童装全部对应同一张未取单。\n七是异常的重复，不是七个孩子。\n周秀兰翻看衣角：不是这一回的。\n真正未取的原衣仍在七号机。"],
	"roof_patch": ["屋顶旁通维修印", "水箱旁的新补沥青带有维修印。\n印记与老周管线图上的旁通标记相同，管路向下通往后房和B1。"],
	"notice": ["未送达停水通知", "2004-11-08　01:40\n老街27号临时停水。\n附注：未送达。\n\n洗衣日是11月7日；次日凌晨的事故还有水的参与。"],
	"waterline": ["旧水位线记录", "池壁锈色水线比当前水面高出一米五，旁边写着2004-11-08。\n与后房旧水痕、管线图、停水通知和老周口述相互核对后，才能判断事故经过。"],
	"back_water": ["后房旧水痕", "水痕从地板缝往上，烟熏留在门上缘。\n同一间屋子既经历了火，也经历了倒灌的水。"],
	"sandal": ["竖井里的蓝布鞋", "一只旧蓝色儿童布鞋，外侧鞋头有手工补线。\n与304留下的另一只对应。\n\n鞋能证明孩子的生活联系，不能作为孩子死亡的证明。"],
	"sweater": ["七号机原衣", "藏青色童装毛衣，袖口两道白条。\n2004-11-07的未取原衣。\n所有东西都湿，只有它是干的。\n\n袋里五件，加上这一件，才是六件。"],
	"sweater_record": ["原衣交还记录", "七号机原衣已交还周秀兰。\n藏青色，袖口两道白条，2004-11-07未取。\n原衣随布袋离开，背包中保留这份证据记录。"],
	"accident": ["事故证据核对", "亲历口述＋管线图＋后房旧水痕＋B1水位与时间通知：\n周秀兰被困后房，倒灌洪水参与并造成死亡。\n\n接种证＋出院小结＋童鞋：周小满确曾在这户生活；事故后去向未明。\n不得把未确认的事填成结论。"],
}
const REQUIRED := ["slip","marriage","photo","cert","discharge","testimony","pipe_map","roof_copy","roof_patch","notice","waterline","back_water","sandal","sweater","accident"]
var lc
var game
var progress := {"night":1,"rest_pending":false,"paid":0,"rent_due":2160,"earnings":0,"spare":0,"flags":{},"power":0,"knocks":0}
var modal: Control
var heading: Label
var body: RichTextLabel
var action_box: VBoxContainer
var subtitle: Label
var return_state := "play"
var actions: Array = []
var physical := {}
var chapter: Label
var danger := 0.0
var bag_model: Node3D
var dawn_node: Node3D
var reflection

func setup(case_world) -> void:
	lc = case_world
	game = lc.game
	_build_reader()
	_build_evidence()
	reflection = preload("res://scripts/case1_mirror.gd").new()
	lc.world.add_child(reflection)
	reflection.setup(lc)
	# 阿七此时不可见；旧测试用童年秀兰替身不作为本案现场角色。
	lc.cast.aqi.visible = false
	if lc.cast.xiulan != null: lc.cast.xiulan.visible = false
	game.prologue_spots.append({"id":"case_rest","stage":"room","pos":Vector3(-2.35,12.65,319.0),"r":3.0,"label":"查看夜班回执 / 休息"})
	update_objective()

func night_number() -> int:
	return int(progress["night"])

func flag(id: String) -> bool:
	return bool(progress["flags"].get(id,false))

func mark(id: String) -> void:
	progress["flags"][id] = true

func _build_reader() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 35
	add_child(layer)
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(modal)
	game.field_kit.shade(modal)
	var panel: Panel = game.phone_ui.box(modal,Vector2(200,70),Vector2(1200,760),Color("17272a"),14)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,30)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation",16)
	margin.add_child(stack)
	subtitle = Label.new()
	subtitle.add_theme_font_override("font",game.font)
	subtitle.add_theme_font_size_override("font_size",17)
	subtitle.modulate = Color("bca77c")
	stack.add_child(subtitle)
	heading = Label.new()
	heading.add_theme_font_override("font",game.font)
	heading.add_theme_font_size_override("font_size",30)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(heading)
	body = RichTextLabel.new()
	body.add_theme_font_override("normal_font",game.font)
	body.add_theme_font_size_override("normal_font_size",23)
	body.add_theme_color_override("default_color",Color("e3e8dd"))
	body.add_theme_constant_override("line_separation",10)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.bbcode_enabled = false
	stack.add_child(body)
	action_box = VBoxContainer.new()
	action_box.add_theme_constant_override("separation",8)
	stack.add_child(action_box)
	modal.visible = false
	var hud := CanvasLayer.new()
	hud.layer = 5
	add_child(hud)
	chapter = Label.new()
	chapter.position = Vector2(38,105)
	chapter.add_theme_font_override("font",game.font)
	chapter.add_theme_font_size_override("font_size",16)
	chapter.modulate = Color("c5b687")
	hud.add_child(chapter)

func show_page(title: String, text: String, buttons: Array = []) -> void:
	if not modal.visible:
		return_state = game.state
		if game.phone_open: game._close_phone()
		if game.bag_open: game.field_kit.open_inventory(false)
		game._clear_sub()
	game.state = "case_reader"
	game.player.can_move = false
	game.player.allow_capture = false
	game.player.dragging = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	modal.visible = true
	subtitle.text = "案卷 00184  /  第%d夜  /  阅读期间时间暂停" % night_number()
	heading.text = title
	body.text = text
	body.scroll_to_line(0)
	actions = buttons.duplicate()
	for child in action_box.get_children():
		action_box.remove_child(child)
		child.queue_free()
	if actions.is_empty(): actions = [["收起，继续调查",close_page]]
	for i in actions.size():
		var item: Array = actions[i]
		var button := Button.new()
		button.text = "%d  ·  %s" % [i+1,item[0]]
		button.custom_minimum_size = Vector2(0,46)
		button.add_theme_font_override("font",game.font)
		button.add_theme_font_size_override("font_size",20)
		button.add_theme_stylebox_override("normal",game.phone_ui.style(Color("304c45"),6,Color("6e806c")))
		button.pressed.connect(func(): invoke(i))
		action_box.add_child(button)

func invoke(index: int) -> void:
	if index >= 0 and index < actions.size():
		var callback: Callable = actions[index][1]
		callback.call()

func close_page() -> void:
	modal.visible = false
	game.state = return_state if return_state in ["play","prologue"] else "play"
	game.player.can_move = true
	game.player.allow_capture = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	update_objective()

func _input(event: InputEvent) -> void:
	if not modal.visible or not event is InputEventKey or not event.pressed or event.echo: return
	var key: int = event.physical_keycode
	if key >= KEY_1 and key <= KEY_9:
		invoke(key-KEY_1)
	elif key in [KEY_E,KEY_ENTER,KEY_SPACE]:
		invoke(0)
	elif key == KEY_ESCAPE:
		close_page()
	else: return
	get_viewport().set_input_as_handled()

func doc(id: String) -> void:
	if not DOCS.has(id): return
	var data: Array = DOCS[id]
	if not lc.has_clue(id):
		lc._claim(id)
		game.bag_add(id,String(data[0]),String(data[1]),"物")
		game.note("物",String(data[0]),String(data[1]))
		game.audio_system.sfx("paper",-12)
		if physical.has(id): physical[id].visible = false
	show_page(String(data[0]),String(data[1]))
	update_objective()

func inspect_item(id: String) -> bool:
	if DOCS.has(id):
		show_page(String(DOCS[id][0]),String(DOCS[id][1]))
		return true
	return false

func _point(id: String, pos: Vector3, title: String, radius := 2.3) -> Dictionary:
	return {"id":"c1_"+id,"pos":pos,"r":radius,"label":title}

func spots() -> Array:
	var points := [
		_point("terminal",Vector3(-2.1,4.85,8.35),"查看交班终端 / 案件进度"),
		_point("lady",Vector3(1.65,4.45,6.70),"与取衣的老妇人交谈"),
		_point("towel",Vector3(1.90,4.08,6.72),"看叠好的毛巾"),
		_point("broadcast",Vector3(-2.80,5.55,8.85),"回听并对照两遍广播"),
	]
	if night_number() >= 2:
		points.append_array([
			_point("drawer",Vector3(-.52,7.75,3.15),"打开303最下层抽屉"),
			_point("photo",Vector3(-2.85,8.0,3.75),"查看303照片背面"),
			_point("cert",Vector3(2.70,7.65,4.05),"查看接种证"),
			_point("homework",Vector3(2.70,7.7,4.40),"翻儿童作业本"),
			_point("stones",Vector3(3.05,8.12,3.8),"核对窗台石头日期"),
			_point("shoe_room",Vector3(1.70,7.18,4.35),"查看留下的另一只布鞋"),
			_point("tools",Vector3(.45,10.95,4.65),"取维修挂板钥匙"),
			_point("pipe_map",Vector3(-3.05,11.35,4.25),"核对全楼管线图"),
			_point("sewing",Vector3(-.1,10.65,3.08),"看未缝完的小毛衣"),
			_point("mail_letter",Vector3(19.25,4.7,8.3),"按转存号取未投递挂号件"),
			_point("mail_route",Vector3(2.65,4.75,9.85),"查看邮政存档间路标"),
			_point("passage",Vector3(-.25,13.9,4.35),"进入共用维修通道"),
			_point("unlock503",Vector3(1.65,13.9,5.05),"从503内部解除插销"),
			_point("keybox",Vector3(2.8,13.5,4.6),"打开503检修盒"),
			_point("toys",Vector3(1.7,13.15,3.5),"观察七台玩具洗衣机"),
		])
	if night_number() >= 3:
		points.append_array([
			_point("roof_copy",Vector3(-.4,17.3,3.6),"核对晾衣绳上的七件童装",3.3),
			_point("roof_patch",Vector3(-3.2,15.95,8.4),"核对旁通管维修印"),
			_point("skylight_down",Vector3(-1.7,15.9,3.5),"沿天窗检修梯下到502"),
			_point("skylight_up",Vector3(-1.7,14.6,3.5),"沿检修梯上屋顶"),
			_point("power",Vector3(3.1,4.8,7.1),"操作配电房控制盘"),
			_point("valve",Vector3(-2.6,-1.6,-8.7),"确认并开启排水阀"),
			_point("notice",Vector3(3.20,-1.55,-4.3),"取未送达停水通知"),
			_point("waterline",Vector3(4.3,-1.6,3.2),"核对池壁旧水位线"),
			_point("ladder",Vector3(2.3,-1.55,-6.1),"放下竖井检修梯"),
			_point("sandal",Vector3(3.40,-2.78,-5.68),"拾取竖井里的布鞋"),
			_point("accident",Vector3(0,-1.5,-3.9),"在安全步道核对事故证据"),
		])
	return points

func interact(id: String) -> bool:
	if not id.begins_with("c1_") and id not in ["lb_box503","lb_booth","l_locked_402","l_locked_503","l_m7","l_m9","l_backdoor","l_keyring","l_registry","l_sign","l_photowall","l_clipping","l_boiler","l_raincoat"]: return false
	match id:
		"lb_booth":
			mark("signed")
			show_page("交接簿没有上一班", "最后日期2004-11-07。上一班姓名空白，已交接却盖了章。\n你签下许砚，字迹慢慢变成“待分配”。\n\n广播：到岗已确认。未经核定的姓名不予显示。\n\n本夜任务：核对价目表，查看九号烘干机，记录异常声音。")
		"l_m9": doc("slip")
		"c1_broadcast":
			show_page("广播记录对照","00:01　夜间请勿使用七号机。\n00:20　夜间勿使用七号机。\n\n许砚：少了一个字。" if lc.fired.has("bc2") else "第一遍广播尚未全部记录。可用T拨到00:01，稍后再对照。")
		"c1_lady": lady_talk()
		"c1_towel": show_page("叠好的毛巾","湿了就得擦。纸泡开，就认不出字了。\n\n毛巾背面露出旧绣字：秀兰。" if lc.fired.has("beat14") else "长椅上暂时没有毛巾。")
		"c1_terminal": terminal()
		"l_backdoor":
			if not flag("back_key"):
				show_page("后房外门","门锁着。等到03:40回应老妇人，她会交出外门钥匙。\n这把钥匙不能开启七号机。")
			else:
				lc.has_back_key = true
				lc.back_open = true
				lc.f2.doors["back"].rotation.y = 1.25
				show_page("后房","旧招牌露出秀兰干洗四字。照片里孩子的脸被刮去。\n锅炉上的钥匙是外门备用钥匙，七号机钥匙已移存楼上检修盒。")
		"l_keyring": show_page("外门备用钥匙","只用于后房外门；不能代替七号机专用钥匙。")
		"l_registry":
			if lc.back_open: doc("registry")
		"l_sign":
			if lc.back_open: doc("sign")
		"l_photowall":
			if lc.back_open: show_page("后房照片","一家三口，孩子的脸被刮去。背面的文字要去303原件核对。")
		"l_clipping":
			if lc.back_open: show_page("事故剪报","2004-11-08，秀兰干洗昨夜起火，一人失联。\n这张剪报尚未说明洪水，也没有证实孩子死亡。")
		"l_boiler":
			if lc.back_open: doc("back_water")
		"l_raincoat": show_page("儿童雨衣","挂钩上一件儿童雨衣。水滴落地，声音却来自楼下。")
		"l_m7":
			if not lc.has_clue("machine_key"):
				show_page("七号机","里面一件藏青色童装毛衣，袖口两道白条。\n筒在转，它却悬在正中间。\n\n锁需要专用钥匙，后房外门钥匙不能开启。")
			else:
				doc("sweater")
				lc.f2.sweater.visible = false
		"l_locked_402": knock()
		"l_locked_503":
			show_page("503从里面反锁","从未锁的502进入，寻找两间屋子之间的共用维修通道；或由屋顶天窗下到502。\n信箱钥匙只开1F信箱。")
		"c1_drawer":
			if flag("zhou_open"): doc("marriage")
			else: show_page("303上锁的抽屉","卧室门没锁，抽屉却打不开。去4F402找修水表的老周。")
		"c1_photo": doc("photo")
		"c1_cert": doc("cert")
		"c1_homework": doc("homework")
		"c1_stones": doc("stones")
		"c1_shoe_room": show_page("儿童房留下的鞋","只有一只蓝布鞋。外侧鞋头的手工补线清晰可辨。\n鞋口向着房门，旁边空了一只的位置。")
		"lb_box503":
			if flag("zhou_open"): doc("return_card")
			else: show_page("503信箱","锁很新。门牌与信箱各有自己的锁，先去402问有没有信箱钥匙。")
		"c1_mail_route": show_page("楼内邮政存档间","沿二楼东侧廊桥前往隔壁旧邮政存档间。维修木板覆盖了破损钢网，可以正常步行。\n按退件卡转存号找件：27—503—1107。")
		"c1_mail_letter":
			if lc.has_clue("return_card"): doc("discharge")
			else: show_page("挂号旧件","信格都有转存编号。先找503信箱里的退件卡，核实要找哪一件。")
		"c1_pipe_map":
			if lc.has_clue("discharge") and flag("zhou_open"): zhou_testimony()
			else: show_page("管线图","老周把图压在手边：先找到那封医院的信，再谈事故。")
		"c1_tools":
			if flag("zhou_open"): doc("tool_key")
			else: show_page("维修挂板","先问过402的老周，再取维修物品。")
		"c1_sewing": show_page("未缝完的小毛衣","藏青色，袖口两道白条，和七号机里的同款。\n旁边的纸箱存着从事故中抢救出的衣物。")
		"c1_passage": passage()
		"c1_unlock503":
			if game.player.global_position.z > 5.35: show_page("插销在门内","先经502共用维修通道进入503，才能从内打开走廊门。")
			else:
				mark("503_open")
				lc.buildings.f5.doors["503"].rotation.y = -1.35
				show_page("503捷径已打开","三道插销退开。现在可以从走廊直接进入，不必再绕维修通道。")
		"c1_keybox":
			if lc.has_clue("tool_key"): doc("machine_key")
			else: show_page("上锁的检修盒","盒上贴着七号机维修单。钥匙在4F403维修挂板，不能用信箱钥匙代替。")
		"c1_toys": show_page("七台小洗衣机","每一台都传出同一句：未取。\n整间屋子都在等同一件衣服。地上的空位不代表第八个孩子。")
		"c1_roof_copy": doc("roof_copy")
		"c1_roof_patch": doc("roof_patch")
		"c1_skylight_down": climb_skylight(true)
		"c1_skylight_up": climb_skylight(false)
		"c1_power": power_page()
		"c1_valve":
			if int(progress.power) == 2:
				progress.power = 3
				mark("drained")
				lc.buildings.b1.water.position.y -= .8
				game.audio_system.sfx("door",-14)
				show_page("排水泵启动","独立回路运转，排水阀方向与图一致。水位下降，露出通向竖井的安全步道。\n先在边缘放下检修梯，再拿童鞋。")
			else: show_page("先确认安全顺序","回二楼配电控制盘：隔离浸水线路→接通独立泵回路→开排水阀。")
		"c1_notice": doc("notice")
		"c1_waterline": doc("waterline")
		"c1_ladder":
			if flag("drained"):
				mark("ladder")
				game.audio_system.sfx("ladder",-8)
				show_page("检修梯放下了","梯脚已经抵到井底。沿步道靠近蓝布鞋，按E拾取，记得核对补线。")
			else: show_page("危险水域","漏电警告：浸水线路未隔离，水位尚未下降。先完成配电与排水。")
		"c1_sandal":
			if flag("drained") and flag("ladder"):
				doc("sandal")
				game.audio_system.speak("flood_memory")
			else: show_page("先放下检修梯","安全步道可以观察，取鞋前需要完成排水并放下检修梯。")
		"c1_accident": combine()
		_: return false
	update_objective()
	return true

func lady_talk() -> void:
	if flag("recognized"):
		show_page("认领已经完成","原衣已经交还。现在等到交班，可用T依次拨到工资、录名和长椅尾声。")
		return
	if not lc.fired.has("oldlady"):
		show_page("长椅空着","先调查九号烘干机，01:10会有来客。时钟可以拨快，事件会留下记录。")
		return
	if night_number() == 1:
		if lc.t/60.0 >= 240:
			mark("back_key")
			lc.has_back_key = true
			game.bag_add("back_key","后房外门钥匙","只开后房外门，不开七号机。")
			show_page("我还没找到那件","周秀兰：是不是洗好了？\n许砚：我还没找到那件。\n她让出袋口：钥匙别又放错地方。\n\n许砚：你先别急。我明天把钥匙找来。\n周秀兰：那我等着。\n\n外门钥匙已入包。先查看后房门边，再到柜台交班终端申请续查。")
		else: show_page("不是来洗的","老妇人：秀兰啊，今天生意怎么样？\n她用年轻一点的声音答：还行。还剩最后一单。\n\n许砚：您来洗衣服？\n老妇人：洗过了。\n许砚：那您是来取的？\n老妇人：得等他穿。")
	elif night_number() == 2:
		if lc.has_clue("cert") and lc.has_clue("discharge"):
			if not flag("name_told"): game.audio_system.speak("lady_name")
			mark("name_told")
			show_page("他叫周小满","许砚：他叫周小满。\n周秀兰：……小满。是。小满。\n她看着台阶：这孩子，鞋怎么少了一只。\n\n她指向楼上的水声：那件总也晾不干。\n\n第三夜要查明：上面的衣服与下面的水，怎么连起来？")
		else: show_page("她少记得一件事","周秀兰：你回来了。钥匙找着没有？\n她仍记得孩子，却越来越看不清那张脸。\n\n先核对303、304和那封未投递的医院挂号件。")
	else:
		if ready_to_claim():
			show_page("把第六件交还给她","五件在布袋里，第六件是七号机的原衣。\n住户材料与事故记录已经核对，周小满去向仍待查。",[["交还原衣，完成认领",claim]])
		elif lc.has_clue("roof_copy"): show_page("不是这一回的","她翻看复制品的衣角，把它退回来：不是这一回的。\n\n真正的原衣还在七号机。事故也需要核实，不能只把一件复制品塞进袋里。")
		else: show_page("还差一件","先找七号机原衣，核对屋顶与地下的管线和事故记录。\n她还在等，但不会因为你慢了一点就抹去已经找到的证据。")

func knock() -> void:
	game.audio_system.sfx("knock",-10)
	if night_number() < 2:
		show_page("402","里面有人：先把今晚的夜班值完。\n门边维修牌写：找修表师傅，两短一长。")
		return
	if flag("zhou_open"):
		if lc.has_clue("discharge"): zhou_testimony()
		else: show_page("老周","三楼她住过，抽屉钥匙给你。503信箱里还有一张退件卡。\n卧室门本身没锁，信箱钥匙也不能开503房门。")
		return
	show_page("第三次敲门","普通敲门时，里面说：没水。没电。没活人。走吧。\n\n维修牌：找修表师傅，两短一长。",[["照维修牌敲两短一长",open_zhou]])

func open_zhou() -> void:
	if not lc.has_clue("slip"):
		show_page("你是来找人的？","老周：先告诉我，你找谁？\n需要拿到九号烘干机的洗衣单，才能向他说明来意。")
		return
	mark("zhou_open")
	game.bag_add("drawer_key","303抽屉钥匙","老周交付，只开303最下层抽屉。")
	game.bag_add("mail_key","503信箱钥匙","只开一楼503信箱，不开五楼房门。")
	lc.buildings.f4.k.doors["402"].rotation.y = 1.25
	lc.cast.laozhou_open()
	show_page("老周开门","老周：……你不是来收房的。那你是来找人的。\n\n许砚：周秀兰住过这里？\n老周：三楼。她男人跑的时候，带走了一摞纸。病历，证件。人没带。\n许砚：你怎么还住这儿？\n老周：水表每个月得看。没人住，也会走。\n\n303抽屉钥匙、503信箱钥匙已入包。")

func zhou_testimony() -> void:
	if not lc.has_clue("testimony"): game.audio_system.speak("laozhou_memory")
	doc("testimony")
	if not lc.has_clue("pipe_map"):
		lc._claim("pipe_map")
		game.bag_add("pipe_map",DOCS.pipe_map[0],DOCS.pipe_map[1],"物")
		game.note("话","老周：没见着的别替我写",DOCS.testimony[1])
	body.text += "\n\n老周交给你全楼管线图。屋顶旁通、后房和B1相连；七号机钥匙在503检修盒，盒钥匙在403。"

func passage() -> void:
	show_page("502—503共用维修通道","窄门通往隔壁，地上有旧维修脚印。进503后可从内打开走廊门，建立捷径。")

func climb_skylight(down: bool) -> void:
	if not lc.has_clue("pipe_map"):
		show_page("封住的检修梯","先向老周核实管线图和检修路径，避免在陌生竖井盲目下探。")
		return
	game.state = "case_climb"
	game.player.can_move = false
	game.player.set_physics_process(false)
	game.audio_system.sfx("ladder",-8)
	var tween: Tween = game.create_tween()
	tween.tween_property(game.player,"global_position",Vector3(-1.7,12.78 if down else 15.68,3.5),2.0)
	await tween.finished
	game.player.velocity = Vector3.ZERO
	game.player.set_physics_process(true)
	game.player.can_move = true
	game.player.allow_capture = true
	game.safe_pos = game.player.global_position
	game.state = "play"

func power_page() -> void:
	if lc.buildings.power_room.door != null: lc.buildings.power_room.door.rotation.y = 0
	show_page("配电操作图", "墙上图示：\n①切断浸水区域电路\n②接通独立排水泵回路\n③到B1确认阀门方向后排水\n\n当前步骤：%d / 3。错误操作只跳闸，可重新隔离。" % int(progress.power),[
		["切断浸水回路",func(): power_action(1)],
		["接通独立排水泵",func(): power_action(2)],
		["先收起图纸",close_page]])

func power_action(step: int) -> void:
	if step == 1:
		progress.power = 1
		show_page("浸水回路已隔离","红色危险指示熄灭。接下来接通独立排水泵回路。",[["接通独立排水泵",func(): power_action(2)],["暂时离开",close_page]])
	elif int(progress.power) == 1:
		progress.power = 2
		game.director.send_once("pump_notice","派遣科","涉水作业不计特殊津贴。请按图隔离回路，排水后再取证。")
		show_page("独立回路接通","许砚：先问了我才知道。\n\n现在沿一楼检修梯下B1，到标有排水的阀门确认方向并开启。")
	else:
		progress.power = 0
		game.audio_system.sfx("door",-15)
		show_page("保护跳闸","浸水线路未隔离。先切断浸水回路，再接独立泵。没有丢失证据，可以复位重试。",[["按图重新隔离回路",func(): power_action(1)],["收起图纸",close_page]])

func combine() -> void:
	var missing: Array = []
	for key in ["testimony","pipe_map","back_water","notice","waterline","sandal"]:
		if not lc.has_clue(key): missing.append(DOCS[key][0])
	if not missing.is_empty():
		show_page("还有记录需要核对","尚缺：\n"+"\n".join(missing)+"\n\n已取证据全部保留，不会因为到04:00而丢失。")
		return
	doc("accident")

func ready_to_claim() -> bool:
	if night_number() != 3: return false
	for key in REQUIRED:
		if not lc.has_clue(key): return false
	return flag("drained")

func claim() -> void:
	if flag("recognized") or not ready_to_claim(): return
	game.audio_system.speak("lady_thanks")
	lc.selected_ending = "A"
	lc.claimed = true
	mark("recognized")
	lc.t = minf(lc.t,254.0*60.0)
	game.field_kit.held_id = ""
	game.field_kit.rig.set_item("")
	game.case_bag = game.case_bag.filter(func(item): return item.get("id","")!="sweater")
	game.bag_add("sweater_record",DOCS.sweater_record[0],DOCS.sweater_record[1])
	if lc.f2.sweater != null: lc.f2.sweater.visible = false
	show_page("她终于数到了", "周秀兰迅速叠好第六件：……齐了。\n广播：未取物归属成立。事故相关记录已归档，孩子去向仍待查。\n\n她在门口回头：谢谢你啊。你叫什么名字？\n许砚：许砚。\n周秀兰：许砚。我记着。\n\n她走出视线。镜子里，她抱着布袋站在你身旁。\n案卷00184：已认领。周小满后续去向待查。",[["等到交班，领取最后一夜回执",start_epilogue]])

func start_epilogue() -> void:
	close_page()
	lc.t = 255.0*60.0
	if lc.lady == null: return
	lc.night.lady_state = "leave"
	lc.lady.stand()
	if bag_model != null: bag_model.reparent(lc.lady,true)
	var tween: Tween = game.create_tween()
	tween.tween_interval(1.8)
	tween.tween_callback(func():
		if is_instance_valid(lc.lady):
			lc.lady.play("Walk")
			lc.lady.face_point(Vector3(0,3.5,9.5)))
	tween.tween_property(lc.lady,"global_position",Vector3(0,3.5,9.5),4.0)
	tween.tween_callback(func():
		if is_instance_valid(lc.lady): lc.lady.visible=false)

func terminal() -> void:
	if bool(progress.rest_pending):
		show_page("本夜已交班","工资已结算，请从一楼门厅回街道，进入出租公寓休息。不能连续驻守现场。")
		return
	if night_number() == 3:
		if ready_to_claim() and not flag("recognized"):
			show_page("证据核对完成","唯一处置流程：认领周秀兰与未取原衣。\n请把七号机的原衣交还长椅上的周秀兰。")
		else: show_page("第一案调查进度",objective()+"\n\n证据已收集：%d / %d。可用背包重读文件，时钟只会拨快，不会删除已发生的事件。" % [required_count(),REQUIRED.size()])
		return
	if lc.t / 60.0 < 240.0:
		show_page("现场继续观察","第一夜无现场处置权限。03:40回应老妇人，04:00再提交交班。\n现在可自由调查；T可以到下一事件。" if night_number()==1 else "续查中。完成本夜证据，03:40以后回应周秀兰，04:00交班。")
		return
	var keys := ["slip","sign"] if night_number()==1 else ["marriage","photo","cert","discharge","testimony","pipe_map","tool_key"]
	var missing: Array = []
	for key in keys:
		if not lc.has_clue(key): missing.append(String(DOCS[key][0]))
	if night_number()==1 and not flag("back_key"): missing.append("03:40向老妇人说明还没找到原衣")
	if night_number()==2 and not flag("name_told"): missing.append("向周秀兰说出周小满的名字")
	if not missing.is_empty():
		show_page("交班前还需确认","尚缺：\n"+"\n".join(missing)+"\n\n到点会保留调查窗口；找到后随时回来，不会触发坏结局。")
		return
	show_page("申请续查 · 本夜交班","终端：建议抹平。\n权限：临时工无现场处置权。\n\n许砚填写：现场待核，申请续查。\n每夜工资800元，交班后撤离、回住处休息。",[["提交续查记录，等到04:00交班",end_shift]])

func end_shift() -> void:
	var n := night_number()
	if int(progress.paid) < n:
		progress.paid = n
		progress.earnings = int(progress.earnings)+800
		progress.rent_due = maxi(0,2160-int(progress.earnings))
		game.bag_add("wage_%d"%n,"第%d夜工资回执"%n,"已领取800元，转交房租。余欠%d元。"%int(progress.rent_due))
	progress.rest_pending = true
	lc.t = 260.0*60.0
	lc._dawn_light()
	if lc.lady != null: lc.lady.visible = false
	game.director.room_minutes = 1680.0
	game.director.send_once("wage_%d"%n,"房东","800收到了。余欠%d元。你这工作……明天还去？" % int(progress.rent_due))
	game.director.send_once("continue_%d"%n,"派遣科","续查已登记。现场保留。04:00后请撤离休息，再于下一晚返岗核对。")
	show_page("第%d夜结束 · 工资800元"%n,"许砚：去。\n\n没有录名，没有永久权限卡。你已经答应明天把那件衣服找来。\n\n从一楼门厅回到街道，进入出租公寓，在床边选择休息至下一班。",[["收起回执，回出租屋",close_page]])

func rest_page() -> void:
	if not bool(progress.rest_pending):
		show_page("出租屋","夜班尚未交班。可以先整理线索，再返回洗衣店继续；完成交班后才能休息到下一晚。")
		return
	show_page("回到出租屋 · 第%d夜后"%night_number(),"房租余欠%d元。\n\n你把“明天把钥匙找来”抄在记事本上。%s\n\n现场已经撤离，休息后再去下一班，不违反连续驻守禁忌。" % [int(progress.rent_due),"手机里一张旧照片开始认不清拍摄位置。" if night_number()==2 else "窗外的雨还在下。"],[["休息至下一班",begin_next_night],["先整理物品",close_page]])

func begin_next_night() -> void:
	if not bool(progress.rest_pending) or night_number() >= 3: return
	close_page()
	progress.night = night_number()+1
	progress.rest_pending = false
	lc.t = 0.0
	lc.fired.clear()
	lc.selected_ending = ""
	lc.final_open = false
	if lc.night != null:
		lc.night.queue_free()
		lc.night = null
		lc.lady = null
	lc.spinning = {7:true}
	game.director.room_minutes = 1390.0
	game.audio_system.played.clear()
	for node in get_tree().get_nodes_in_group("case1_dawn"):
		node.queue_free()
	game._apply_laundry_environment(false)
	game._show_prologue_stage("room")
	game.state = "prologue"
	game.prologue_call_done = true
	game.phone_ui.incoming = false
	game.spots = lc.spots()
	game.director.send_once("night_%d"%night_number(),"派遣科","第%d夜续查。%s"%[night_number(),"先去402找修表师傅，再核对303、304和503信箱。" if night_number()==2 else "复核屋顶、503检修盒与B1。先隔离浸水电路，再排水取证。"])
	game._prologue_set_objective("第%d夜：从房门去洗衣店续查。23:40报到。"%night_number())
	game.field_kit.sync_world()

func required_count() -> int:
	var count := 0
	for id in REQUIRED:
		if lc.has_clue(id): count += 1
	return count

func objective() -> String:
	if bool(progress.rest_pending): return "本夜已交班：1F出门→街道出租公寓→床边休息至下一班。"
	if flag("recognized"): return "认领完成。用T依次到交班、领取工资、录名及长椅尾声。"
	if night_number()==1:
		if not flag("signed"): return "第1夜夜班报到：1F传达室查看交接簿，再上2F。"
		if not lc.has_clue("slip"): return "第1夜：上2F，查看价目表与9号烘干机里的未取洗衣单。"
		if not flag("back_key"): return "第1夜：对照两遍广播，观察来客；03:40向长椅上的老妇人说明还没找到原衣。T可拨时。"
		if not lc.has_clue("sign"): return "第1夜：用外门钥匙推开后房门，查看旧招牌；之后去柜台交班终端。"
		return "第1夜：在柜台交班终端提交“现场待核，申请续查”，04:00领工资后回家。"
	if night_number()==2:
		if not flag("zhou_open"): return "第2夜：上4F，402门边维修牌提示两短一长；出示洗衣单找老周。"
		if not lc.has_clue("marriage") or not lc.has_clue("photo"): return "第2夜：用钥匙开303抽屉，核对结婚证和照片背面。"
		if not lc.has_clue("cert"): return "第2夜：304儿童房书桌查看接种证；可选查看作业和窗台石头。"
		if not lc.has_clue("return_card"): return "第2夜：到1F，用503信箱钥匙取退件卡；房门与信箱不是同一把锁。"
		if not lc.has_clue("discharge"): return "第2夜：2F东侧廊桥→楼内邮政存档间，按27—503—1107取医院挂号件。"
		if not lc.has_clue("testimony"): return "第2夜：回4F402给老周看出院小结，核对口述与管线图。"
		if not lc.has_clue("tool_key"): return "第2夜：403维修挂板取检修盒钥匙，它只能开503的检修盒。"
		if not flag("name_told"): return "第2夜：回2F告诉周秀兰，他叫周小满；03:40后可到柜台交班。"
		return "第2夜：柜台交班终端提交续查，04:00后回出租屋休息。"
	if not lc.has_clue("machine_key"): return "第3夜：经5F502共用维修通道进入503，用403钥匙开检修盒，取七号机专用钥匙。"
	if not lc.has_clue("roof_copy") or not lc.has_clue("roof_patch"): return "第3夜：到屋顶核对七件重复童装和水箱旁的旁通维修印。"
	if int(progress.power)<2: return "第3夜：2F配电控制盘：隔离浸水线路→接独立排水泵，再下B1开阀。"
	if not flag("drained"): return "第3夜：1F检修梯下B1，确认排水阀方向后开启排水。"
	if not lc.has_clue("notice") or not lc.has_clue("waterline"): return "第3夜：B1安全步道核对停水通知和蓄水池旧水位线。"
	if not lc.has_clue("sandal"): return "第3夜：在B1竖井边放下检修梯，拾取蓝布鞋；补线与304那只对应。"
	if not lc.has_clue("back_water"): return "第3夜：回2F后房锅炉边核对由下向上的旧水痕。"
	if not lc.has_clue("accident"): return "第3夜：到B1安全步道核对事故证据，保留孩子去向未明的结论。"
	if not lc.has_clue("sweater"): return "第3夜：用专用钥匙开启2F七号机，取回干燥的原衣。"
	return "证据已齐：把第六件原衣交还2F长椅上的周秀兰。"

func update_objective() -> void:
	if game == null: return
	var text := objective()
	if game.case_mode == "laundry" and game.case_objective != text: game.set_case_objective(text)
	chapter.text = "10月%d日  ·  第%d夜  ·  现场证据 %d/%d" % [17+night_number(),night_number(),required_count(),REQUIRED.size()]
	chapter.visible = game.case_mode == "laundry" and game.state not in ["menu","case_end","case_title"]

func next_event() -> Array:
	if lc.selected_ending == "" and lc.t>=240*60:
		if night_number()==1 and not flag("back_key"): return [1420.0+lc.t/60.0,"当前：先回应老妇人，再继续拨时"]
		if night_number()==2 and not flag("name_told"): return [1420.0+lc.t/60.0,"当前：先向周秀兰核对小满姓名"]
	var events := [[21.0,"00:01 第一遍广播"],[40.0,"00:20 第二遍广播"],[90.0,"01:10 来客"],[170.0,"02:30 停电"],[210.0,"03:10 清点衣物"],[240.0,"03:40 核对与回应"],[255.0,"03:55 交班"],[256.0,"03:56 工资回执"],[258.0,"03:58 录名"],[260.0,"04:00 天亮"],[261.0,"04:01 长椅"],[262.0,"04:02 归档"]]
	for event in events:
		if float(event[0]) > lc.t/60.0+.02: return [1420.0+float(event[0]),event[1]]
	return [1682.0,"本夜到点，请完成当前调查"]

func timeline() -> void:
	if bool(progress.rest_pending) or lc.ended: return
	var e: float = lc.t/60.0
	# 无时间惩罚：未完成交班/认领时保留调查窗口。
	if lc.selected_ending == "": lc.t = minf(lc.t,260.0*60.0)
	if e >= 21 and lc._once("bc1"):
		lc._tell("站内广播","夜间请勿使用七号机。")
		game.note("话","第一遍广播","夜间请勿使用七号机。")
		game.director.send_once("bc1" if night_number()==1 else "bc1_n%d"%night_number(),"派遣科",objective())
	if e >= 40 and lc._once("bc2"):
		lc._tell("站内广播","夜间勿使用七号机。")
		game.note("话","第二遍广播","夜间勿使用七号机。")
		lc.spinning[1]=true; lc.spinning[2]=true; lc.spinning[3]=true
	if e >= 90 and lc._once("oldlady"):
		lc._spawn_lady()
		lc._tell("旁白","门开了。老妇人坐到长椅上，水印却向门外退。")
		if bag_model != null: bag_model.visible = true
	if e >= 170 and lc._once("beat13"): lc._blackout(3.2)
	if e >= 171 and lc._once("beat14"):
		lc._place_towel()
		lc._tell("她","湿了就得擦。纸泡开，就认不出字了。")
	if e >= 210 and lc._once("count"):
		lc._tell("她","一件……两件……三件……四件……五件……还差一件。")
		if lc.night != null: lc.night.lady_count()
	if e >= 240 and lc._once("ask"):
		lc._tell("她","是不是洗好了？")
		game.director.send_once("ask_%d"%night_number(),"派遣科",objective())
	if lc.selected_ending == "": return
	if e >= 255 and lc._once("handover"):
		lc._tell("广播","交班时间。请确认现场无人。……已确认。")
	if e >= 256 and lc._once("handover_items"):
		lc._place_handover_items()
		progress.paid = 3
		progress.earnings = 2400
		progress.rent_due = 0
		progress.spare = 240
		game.bag_add("badge","纸工牌 · 临-0131","此牌不作身份证明。")
		game.bag_add("wage_3","第3夜工资回执","工资800元，付清余欠560元，剩余新收入240元。")
		game.bag_add("permcard","录名权限卡","已录名，可查阅已结案卷结论页。")
	if e >= 258 and lc._once("recorded"):
		lc._tell("广播","许砚先生，工号临-0131。您已录名。")
	if e >= 260 and lc._once("dawn4"):
		lc._dawn_light()
		if lc.lady != null: lc.lady.visible = false
		if bag_model != null: bag_model.visible = false
	if e >= 261 and lc._once("aqi_line"):
		lc._show_aqi_on_bench()
		lc._tell("阿七","你现在能看见我了？")
	if e >= 262 and lc._once("case_end"):
		game.bag_add("address","向阳福利院旧址","归还的第一份来历：向阳福利院旧址。")
		game.director.send_once("rent_paid","房东","560收到了，欠租结清。")
		lc.complete_case()

func capture() -> Dictionary:
	return progress.duplicate(true)

func restore(data: Dictionary) -> void:
	if not data.is_empty(): progress.merge(data,true)
	# 旧单夜存档迁移为继续调查，不能直接跳过三夜。
	if not data.has("night"):
		lc.selected_ending = ""; lc.ended = false; lc.final_open = false
		lc.fired.erase("ask"); lc.fired.erase("case_end")
		lc.t = minf(lc.t,240.0*60.0)
	for id in physical:
		physical[id].visible = not lc.has_clue(id)
	if flag("zhou_open"): lc.buildings.f4.k.doors["402"].rotation.y = 1.25
	if flag("503_open"): lc.buildings.f5.doors["503"].rotation.y = -1.35
	if flag("drained"): lc.buildings.b1.water.position.y = lc.buildings.b1.water_base_y-.8
	if bag_model != null: bag_model.visible = lc.fired.has("oldlady") and not lc.fired.has("dawn4")
	game.spots = lc.spots()
	update_objective()

func _build_evidence() -> void:
	var a = lc.art
	var positions := {"marriage":Vector3(-.52,7.72,3.15),"photo":Vector3(-2.83,7.76,3.75),"cert":Vector3(2.70,7.60,4.05),"return_card":Vector3(-2.8,1.34,4.62),"discharge":Vector3(19.25,4.5,8.3),"tool_key":Vector3(.45,10.8,4.65),"machine_key":Vector3(2.8,13.48,4.6)}
	for id in positions:
		var node: MeshInstance3D = a.box(positions[id],Vector3(.19,.009,.13),a.plain(Color("d7c9a5")),false)
		physical[id] = node
	# 新模型按实际尺度归一化，保持源文件不变。
	var other_shoe := Props.place(lc.world,"shoe",Vector3(1.70,6.93,4.35),.19,0.3)
	if other_shoe != null: other_shoe.scale.x = -1.0
	physical["sandal"] = Props.place(lc.world,"shoe",Vector3(3.40,-2.94,-5.68),.19,-.5)
	if lc.buildings.b1.sandal_model != null: lc.buildings.b1.sandal_model.visible = false
	# 七号机里与屋顶的重复品用同一模型，只有原衣可完成认领。
	if lc.f2.sweater != null:
		var old_sweater: Node3D = lc.f2.sweater
		var new_sweater := Props.place(lc.world,"sweater",old_sweater.position-Vector3(0,.16,0),.37,0)
		if new_sweater != null:
			old_sweater.visible = false
			lc.f2.sweater = new_sweater
	bag_model = Props.place(lc.world,"bag",Vector3(1.42,4.03,6.25),.40,0)
	if bag_model != null: bag_model.visible = false
	if bag_model != null:
		for i in range(5):
			var fold: MeshInstance3D = a.box(Vector3(1.42,4.09+i*.025,6.25),Vector3(.25,.025,.22),a.plain(Color(.19+i*.05,.22+i*.035,.27+i*.02),.95),false)
			fold.reparent(bag_model,true)
	# 通行木板为可见实体，避免窄廊桥洞口吞掉角色。
	var wood = a.plain(Color("6c5940"),.9)
	for x in [5.0,6.8,8.7,11.0]: a.box(Vector3(x,3.50,10),Vector3(.75,.06,1.15),wood,true)
	a.box(Vector3(2.90,3.47,10.35),Vector3(.75,.12,.50),wood,true)
	a.box(Vector3(19.25,3.98,8.3),Vector3(.68,.96,.48),a.plain(Color("59695a")),true)
	a.label("邮政存档间（楼内） →",Vector3(3.0,5.35,10),.06,Color("ded5ac"),-PI/2)
	a.label("27—503—1107",Vector3(19.25,4.78,8.3),.045,Color("e4d1a2"),0)
	a.label("排水阀 →",Vector3(-2.5,-1.25,-8.65),.06,Color("d8c487"),0)
	a.label("先隔离浸水回路，再接排水泵",Vector3(3.03,5.18,7.1),.045,Color("eed8a2"),-PI/2)
	# 维修通道提示，位置来自两屋之间现有隔墙洞口。
	a.label("502 ↔ 503 共用维修通道",Vector3(-.22,14.45,4.3),.04,Color("b4c5aa"),-PI/2)

func _process(delta: float) -> void:
	if game == null: return
	update_objective()
	# 危险区域有预警且只退回安全节点，已读证据不清除。
	if game.case_mode != "laundry" or game.state != "play" or game.sub_pause: return
	if lc.fired.has("count") and not flag("recognized") and game.player.global_position.distance_to(Vector3(1.9,3.55,6.72)) < .48:
		danger += delta
		if danger > 1.0:
			game.hud_prompt.text = "衣角正在被抚平，呼吸变浅。请退开。"
		if danger > 4.0:
			game.player.global_position = Vector3(.1,3.56,7.8)
			game.player.velocity = Vector3.ZERO
			game.safe_pos = game.player.global_position
			danger = 0.0
			show_page("重复到岗已记录","袖口先被压成纸，画面渐白。你在最近安全位置醒来。\n已读线索全部保留。那只袋口不能把你当成第六件。")
	else: danger = 0.0
