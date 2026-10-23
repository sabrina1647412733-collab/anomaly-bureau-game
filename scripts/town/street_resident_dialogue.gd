extends RefCounted
## Read-only neighbourhood replies. Existing campaign goals remain the authority;
## residents do not grant clues, flags, jobs, or an independent dialogue session.
const PEOPLE := {
	"resident_shopkeeper": {"label":"电料店店主", "prompt":"和电料店店主聊两句"},
	"resident_woman": {"label":"附近住户", "prompt":"和附近住户打招呼"},
}
const LINES := {
	"unassigned": [
		"这几间门面挨得近，找人先认门牌。我这儿是电料店，走错了也没事。",
		"这条街转角多，头一回来容易绕。沿着街走就好，别急着钻房子后面的窄缝。"],
	"arrival": [
		"得利洗衣店就在沿街那栋。走楼下正门，先在一楼传达室签交接簿，再上二楼。雨天路滑，慢点。",
		"找得利洗衣店？别绕后面，楼下正门能进去。一楼办交接，店在二楼，沿楼梯上去就到。"],
	"rules": [
		"交接簿签过就行。上二楼看看店里贴的工作须知，不熟悉的机器先别动。",
		"已经办过交接了？那就去二楼看看工作须知。刚接手，先弄清要做什么，别着急。"],
	"record": [
		"旧票据和机器上的号码，最好当面核一遍。记清楚了再操作，省得拿错东西。",
		"待取的衣物多，光记样子容易混。票据、号码都留着，回头还好对。"],
	"wait": [
		"还没交班就别走远。要等消息，回店里等着；听见什么先记下来，免得回头记混。",
		"夜里这条街安静，屋里的动静反倒听得清。你还有事要等，就先回店里吧。"],
	"followup": [
		"钥匙多了，先分清哪把开哪扇门。拧不动就看看标记，别硬撬。",
		"老房子的牌子旧，字有时要凑近才看得清。看过的东西记一下，少跑一趟冤枉路。"],
	"handover": [
		"还没办完交接吧？回二楼柜台把今晚的事说清楚，回执拿好，再往家走。",
		"忙完手里的活，也别漏了交接。先回店里办妥，回家才能踏实歇着。"],
	"night1_work": [
		"头一晚不熟悉很正常。先把眼前这一件事做明白，别一会儿跑一头。",
		"夜里风一过，门缝就响。你先忙手里的事，走的时候看着脚下。"],
	"night2_visit": [
		"又来这边了？找修表的老师傅，就认楼内四楼402。手里有单子，带给他看看。",
		"那位修表师傅住四楼402。到门边先看看维修牌，别在街上挨家找。"],
	"night2_documents": [
		"旧东西得对着看，光凭一眼容易记岔。照片正反面、纸上的字，都仔细看看。",
		"找旧材料啊？照片背面有时也写着字。收好再看，别让雨把纸打湿了。"],
	"night2_mail": [
		"找楼里的旧件？先核编号，再从楼内二楼的廊桥去存档间。街上的小邮局是另一处，别走岔。",
		"退件卡要带好，找件得按编号。旧存档间从那栋楼二楼的廊桥过去，不用跑街上的小邮局。"],
	"night2_verify": [
		"问旧事就把手里的原件带上。人记的和纸上写的，能对上多少算多少，别替别人补话。",
		"那时候的事，有人记得多，有人记得少。听不准的先记着，再找东西核实。"],
	"night2_tools": [
		"修理用的钥匙未必开房门，先认清挂板上写的用途。工具用完也记着归位。",
		"找维修钥匙就看看楼里的挂板，别一把把乱试。旧锁头经不住硬拧。"],
	"night2_return": [
		"材料找到了，就带回店里再核一遍。纸别淋湿，话也别只记一半。",
		"你来回跑了好几趟，先回店里把找到的东西理顺吧。别急，能核实的一件件来。"],
	"night2_work": [
		"今天走起来熟些了吧？要查楼里的事，顺着你已经记下的那一条接着找。",
		"又见面了。昨天没弄清的，今天慢慢对；记过的东西就别落下了。"],
	"night3_access": [
		"去检修的地方，先把门牌、钥匙和维修记录对上。走不通就查原来的记录，别硬翻。",
		"还是往楼里去？先看好维修记录上的路线，别看见一道门就去拧。"],
	"night3_power": [
		"碰上进过水的电路，先隔离，再动设备。没弄清前别直接合闸，这事可不能图快。",
		"湿的地方别急着碰电器。先照维修记录确认安全，再往下做。"],
	"night3_water": [
		"排水之前先确认电路已经处理好。水没退、梯子没稳，就别往下面探。",
		"下面要是还有水，先把排水和落脚的地方弄妥。东西再要紧，人也得站稳了。"],
	"night3_verify": [
		"水痕、维修印和纸上的日期得相互对照。只看一处，容易把前后顺序弄反。",
		"这些年补过不少地方，新旧痕迹掺在一起。拿着记录慢慢对，没证据的先别下结论。"],
	"night3_original": [
		"同款未必就是同一件。认东西得看留下的细节，还得跟原来的单子对得上。",
		"要交回的东西，再仔细认一遍。看着相似的，不能随便拿来顶数。"],
	"night3_return": [
		"该找的找到了，就回店里把交接做完。东西认准，话说清楚，别留个糊涂账。",
		"这两天辛苦了。先把手里的东西交妥，再忙后面的事，别半道落下。"],
	"night3_work": [
		"第三回走这段路，脚下也熟了。越是快忙完，越得把记录再对一遍。",
		"又来啦。前两天记下的东西都带着吧？今天别赶，照着已经查清的往下走。"],
	"rest1": [
		"交完班了？沿原路回出租公寓，进原来的门。回执收好，别在雨里站着了。",
		"天快亮了，回出租公寓歇会儿吧。原来的门进去，到床边把这一班收个尾。"],
	"rest2": [
		"第二班也交完了？回出租公寓歇着吧。东西先收好，明晚的事明晚再理。",
		"这两天你来回跑得勤。交班就先回出租公寓休息，别站在路上接着熬。"],
	"closing": [
		"店里的事办妥了？先把最后的交接手续办完。该留的记录留好，再歇口气。",
		"看你松了口气。还有交班的事，就先回去办完，别漏了最后这一道。"],
	"resolved": [
		"忙完了就歇一歇吧。老街的路还是这条，往后经过，进来打声招呼。",
		"总算能缓口气了吧。回去好好休息，路上小心些。"],
}

static func response(game, resident_id: String) -> Dictionary:
	if not PEOPLE.has(resident_id):return {}
	var person: Dictionary = PEOPLE[resident_id]
	var campaign = null
	var laundry = game.laundry if game != null else null
	if is_instance_valid(laundry):campaign = laundry.campaign
	var context := "unassigned"
	var night := 1
	if is_instance_valid(campaign):
		night = clampi(int(campaign.progress.get("night",1)),1,3)
		var flags: Dictionary = campaign.progress.get("flags",{})
		var goal_id := String(campaign.current_goal().get("id",""))
		if bool(laundry.ended):context = "resolved"
		elif bool(flags.get("recognized",false)):context = "closing"
		elif bool(campaign.progress.get("rest_pending",false)):context = "rest1" if night==1 else "rest2"
		elif night==1:
			if not bool(flags.get("signed",false)):context = "arrival"
			elif not bool(flags.get("rules_seen",false)):context = "rules"
			elif goal_id in ["l_m9","l_m7"]:context = "record"
			elif goal_id in ["c1_broadcast","c1_lady"]:context = "wait"
			elif goal_id in ["l_backdoor","l_sign"]:context = "followup"
			elif goal_id=="c1_terminal":context = "handover"
			else:context = "night1_work"
		elif night==2:
			if goal_id=="l_locked_402":context = "night2_verify" if bool(flags.get("zhou_open",false)) else "night2_visit"
			elif goal_id in ["c1_drawer","c1_photo","c1_cert","lb_box503"]:context = "night2_documents"
			elif goal_id=="c1_mail_letter":context = "night2_mail"
			elif goal_id=="c1_tools":context = "night2_tools"
			elif goal_id=="c1_lady":context = "night2_return"
			elif goal_id=="c1_terminal":context = "handover"
			else:context = "night2_work"
		else:
			if goal_id in ["c1_keybox","c1_unlock503"]:context = "night3_access"
			elif goal_id=="c1_power":context = "night3_power"
			elif goal_id in ["c1_valve","c1_ladder","c1_sandal"]:context = "night3_water"
			elif goal_id in ["c1_roof_copy","c1_roof_patch","c1_notice","c1_waterline","l_boiler","c1_accident"]:context = "night3_verify"
			elif goal_id=="l_m7":context = "night3_original"
			elif goal_id=="c1_lady":context = "night3_return"
			else:context = "night3_work"
	elif game != null and game.field_kit != null and bool(game.field_kit.letter_accepted):
		context = "arrival"
	var pair: Array = LINES[context]
	var text := String(pair[0 if resident_id=="resident_shopkeeper" else 1])
	var prompt := String(person.prompt)
	if context=="arrival":prompt = "向电料店店主问路" if resident_id=="resident_shopkeeper" else "向附近住户问路"
	elif context in ["rest1","rest2"]:prompt = "问问回出租公寓的路"
	return {"text":text,"label":String(person.label),"context":context,"prompt":prompt}
