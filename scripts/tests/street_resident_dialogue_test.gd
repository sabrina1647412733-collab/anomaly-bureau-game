extends SceneTree
## Pure response checks use the real campaign goal resolver with light data stubs.
## No scene, audio player, model import, or player save is needed.
const Replies := preload("res://scripts/town/street_resident_dialogue.gd")
const Campaign := preload("res://scripts/laundry_campaign.gd")
const OUT := "F:/诡异事务局/验收/20261023_NPC生活化/"
const IDS := ["resident_shopkeeper","resident_woman"]
var passed := 0
var failed := 0
var errors: Array[String] = []

class FieldStub extends RefCounted:
	var letter_accepted := false

class LaundryStub extends RefCounted:
	var campaign
	var clues: Dictionary = {}
	var fired: Dictionary = {}
	var t := 0.0
	var back_open := false
	var ended := false
	var night = null
	func has_clue(id: String) -> bool:return bool(clues.get(id,false))

class GameStub extends RefCounted:
	var laundry = null
	var field_kit := FieldStub.new()
	var state := "prologue"
	var prologue_objective := "沿街前往得利洗衣店。"
	var case_objective := ""
	var case_bag: Array = []

func _initialize() -> void:call_deferred("run")

func check(ok: bool, label: String) -> void:
	if ok:passed+=1;print("PASS ",label)
	else:failed+=1;errors.append(label);push_error("FAIL "+label)

func expect(game, expected: String, label: String) -> void:
	for id in IDS:
		var reply: Dictionary = Replies.response(game,id)
		check(reply.get("context","")==expected,label+" / "+id+" context="+String(reply.get("context","")))
		check(not String(reply.get("text","")).is_empty() and not String(reply.get("label","")).is_empty() and not String(reply.get("prompt","")).is_empty(),label+" 回复、说话人和提示完整 / "+id)

func run() -> void:
	check(DisplayServer.get_name()=="headless","测试无窗口")
	check(AudioServer.get_driver_name()=="Dummy","测试无声音设备")
	check(Replies.response(null,"unknown").is_empty(),"未知居民不误用其他角色台词")
	expect(null,"unassigned","未提供游戏时保留普通街坊回应")
	var game := GameStub.new()
	expect(game,"unassigned","未接信封不假设玩家已接夜班")
	for id in IDS:
		var early: String = Replies.response(game,id).text
		check(not early.contains("交接") and not early.contains("夜班") and not early.contains("事务局"),"未入职不提前引导任务 / "+id)
	game.field_kit.letter_accepted = true
	expect(game,"arrival","接信后首次街道指向正门、一楼和二楼")
	for id in IDS:
		var first: String = Replies.response(game,id).text
		check(first.contains("一楼") and first.contains("二楼") and first.contains("正门"),"初来引导覆盖真实入口及楼层 / "+id)
	var laundry := LaundryStub.new()
	var campaign := Campaign.new()
	laundry.campaign = campaign
	campaign.lc = laundry
	campaign.game = game
	game.laundry = laundry
	expect(game,"arrival","真实首夜目标尚未签交接簿")
	campaign.mark("signed")
	expect(game,"rules","签完后转为工作须知")
	for id in IDS:
		check(not String(Replies.response(game,id).text).contains("先在一楼"),"不重复催已完成的一楼报到 / "+id)
	campaign.mark("rules_seen")
	expect(game,"record","只余纸张或机器核对时不再催报到")
	laundry.clues.slip = true
	campaign.mark("seven_seen")
	expect(game,"wait","首夜调查完成后只提醒返回等候")
	laundry.fired.oldlady = true
	campaign.mark("met_lady")
	campaign.mark("back_key")
	expect(game,"followup","后房调查只提供已有目标相关提醒")
	laundry.back_open = true
	laundry.clues.sign = true
	expect(game,"handover","未交班不能误导直接回家")
	campaign.progress.rest_pending = true
	expect(game,"rest1","首夜交班后转为回家休息")
	campaign.progress.night = 2
	expect(game,"rest2","第二夜交班后使用不同回家回应")
	campaign.progress.rest_pending = false
	expect(game,"night2_visit","第二夜目标去402时才提示修表住户")
	campaign.mark("zhou_open")
	expect(game,"night2_documents","402已见过后不反复提示初次敲门")
	laundry.clues.merge({"marriage":true,"photo":true,"cert":true,"return_card":true})
	campaign.mark("examined_photo")
	expect(game,"night2_mail","真实挂号件目标提醒楼内廊桥")
	for id in IDS:
		var mail: String = Replies.response(game,id).text
		check(mail.contains("廊桥") and mail.contains("小邮局"),"明确楼内存档间与街道小邮局不同 / "+id)
	laundry.clues.discharge = true
	expect(game,"night2_verify","医院材料后转为核实口述")
	laundry.clues.testimony = true
	expect(game,"night2_tools","口述完成后提醒区分维修钥匙用途")
	laundry.clues.tool_key = true
	expect(game,"night2_return","材料已齐才提醒回店对照")
	campaign.mark("name_told")
	expect(game,"handover","第二夜任务完成后仍先交班")
	campaign.progress.night = 3
	expect(game,"night3_access","第三夜检修盒阶段不复读第一夜报到")
	laundry.clues.machine_key = true
	campaign.mark("503_open")
	expect(game,"night3_verify","屋顶核对阶段不提前宣布事故结论")
	laundry.clues.merge({"roof_copy":true,"roof_patch":true})
	expect(game,"night3_power","第三夜电路目标给安全提醒")
	campaign.progress.power = 2
	expect(game,"night3_water","泵回路已接通后提醒水与落脚")
	campaign.mark("drained")
	laundry.clues.merge({"notice":true,"waterline":true})
	expect(game,"night3_water","竖井检修梯阶段仍强调安全")
	campaign.mark("ladder")
	laundry.clues.merge({"sandal":true,"back_water":true,"accident":true})
	expect(game,"night3_original","证据已核对后才提醒辨认原衣")
	laundry.clues.sweater = true
	expect(game,"night3_return","取到原衣后提醒完成交还")
	campaign.mark("recognized")
	expect(game,"closing","认领完成后提醒最后交接")
	laundry.ended = true
	expect(game,"resolved","结案后不再催夜班任务")
	var before := {"progress":campaign.progress.duplicate(true),"clues":laundry.clues.duplicate(true),"fired":laundry.fired.duplicate(true),"bag":game.case_bag.duplicate(true),"state":game.state,"objective":game.prologue_objective,"case_objective":game.case_objective,"accepted":game.field_kit.letter_accepted}
	for id in IDS:
		for i in range(8):Replies.response(game,id)
	var after := {"progress":campaign.progress.duplicate(true),"clues":laundry.clues.duplicate(true),"fired":laundry.fired.duplicate(true),"bag":game.case_bag.duplicate(true),"state":game.state,"objective":game.prologue_objective,"case_objective":game.case_objective,"accepted":game.field_kit.letter_accepted}
	check(before==after,"反复问路不修改旗标、线索、背包、任务或会话状态")
	var text_bank := ""
	for pair in Replies.LINES.values():
		for text in pair:text_bank+=String(text)
	check(not text_bank.contains("周小满") and not text_bank.contains("死亡") and not text_bank.contains("死了"),"街坊不提前透露孩子去向或宣告死亡")
	check(not text_bank.contains("诡异事务局") and not text_bank.contains("福利院"),"街坊不替核心剧情泄露身份及结局线索")
	campaign.free()
	DirAccess.make_dir_recursive_absolute(OUT)
	var report := {"passed":passed,"failed":failed,"errors":errors,"method":"headless Dummy pure replies using real campaign.current_goal; no scene/audio/model/save writes"}
	var file := FileAccess.open(OUT+"dialogue_test_result.json",FileAccess.WRITE)
	if file!=null:file.store_string(JSON.stringify(report,"\t"));file.close()
	print("STREET_RESIDENT_DIALOGUE_RESULT ",JSON.stringify(report))
	quit(1 if failed else 0)
