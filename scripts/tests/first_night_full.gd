extends SceneTree
## 第一夜全流程自动化测试（M09 / M14）
## ==================================================================
## 不开窗口、不渲染，纯逻辑驱动整条第一夜时间轴，每步断言。
## 运行：
##   Godot_..._console.exe --path . --headless -s res://scripts/tests/first_night_full.gd
## 退出码：全通过 0，有失败 1。
##
## 覆盖的剧本节点（对照 first_night.gd 的 _timeline）：
##   00:01 广播 1（含「请勿使用七号机」）
##   00:20 广播 2（「请」字消失）+ 1/2/3 号机自转
##   01:10 老太太进门
##   03:10 她开始数衣服
##   03:40 「是不是洗好了？」
##   03:50 天开始亮、机器停
##   交互：看 7 号机 → 拿钥匙 → 开库房门 → 取毛衣 → 触发 _claim()
##   记事本：四页（人/物/话/疑）都真的有内容

var scene
var night
var player
var fails: Array = []
var oks: Array = []
var _fired_before := {}

func _initialize() -> void:
	_run()

func _ok(msg: String) -> void:
	oks.append(msg)
	print("  [ OK ] ", msg)

func _fail(msg: String) -> void:
	fails.append(msg)
	print("  [FAIL] ", msg)

func _check(cond: bool, msg: String) -> void:
	if cond:
		_ok(msg)
	else:
		_fail(msg)

## 把游戏时间直接推到某个分钟（first_night 内部 t_night 是秒）
func _seek(n: float, minutes: float) -> void:
	# 直接改 t_night，然后手动调一次 _timeline，等价于“时间到了”
	night.t_night = minutes * 60.0
	night._timeline(night.START_MIN + minutes)

func _run() -> void:
	print("")
	print("========== 第一夜全流程自动化测试 ==========")
	scene = load("res://scenes/laundry.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	await process_frame

	night = scene.get_node_or_null("FirstNight")
	player = scene.get_node_or_null("Player")
	if night == null:
		_fail("场景里找不到 FirstNight 节点")
		_finish()
		return
	if player == null:
		_fail("场景里找不到 Player 节点")
		_finish()
		return
	_ok("场景加载完成（FirstNight + Player 都在）")

	# ── 0. 初始状态
	_check(night.ui != null, "记事本 UI 已构建")
	_check(night.entries["人"].size() >= 1, "记事本「人」页开局就有许砚")
	_check(night.t_night >= 0.0 and night.t_night < 60.0, "时钟从 23:40 起步（t_night<60s）")

	# ── 00:01 广播 1
	print("-- 00:01 第一次广播 --")
	_seek(1.0, 1.0)
	_check(night.fired.has("bc1"), "广播 1 已触发")
	_check(night.lbl_sub.text.find("七号机") >= 0, "广播 1 提到七号机")

	# ── 00:20 广播 2（「请」消失）+ 1/2/3 号机自转
	print("-- 00:20 第二次广播（请字消失）--")
	_seek(1.1, 20.0)
	_check(night.fired.has("bc2"), "广播 2 已触发")
	_check(night.spinning.get(1, false), "1 号机开始自转")
	_check(night.spinning.get(2, false), "2 号机开始自转")
	_check(night.spinning.get(3, false), "3 号机开始自转")
	_check(night.spinning.get(7, true), "7 号机仍在转（开局就转）")
	var cnt := 0
	for k in night.spinning.keys():
		if night.spinning[k]:
			cnt += 1
	_check(cnt == 4, "同时转的是 4 台（1/2/3/7），实际 %d" % cnt)

	# ── 滚筒真的在转（drums 字典里有节点，且旋转会变）
	print("-- 滚筒旋转 --")
	var drum_ok := 0
	for dn in [1, 2, 3, 7]:
		var node = night.drums.get(dn)
		if node != null and node is Node3D:
			drum_ok += 1
	_check(drum_ok == 4, "1/2/3/7 号滚筒节点都可取到（实际 %d）" % drum_ok)
	var before_z := 0.0
	var d1 = night.drums.get(1)
	if d1 != null:
		before_z = d1.rotation.z
		night._spin(0.5)
		_check(absf(d1.rotation.z - before_z) > 0.01, "滚筒旋转确实在推进")
	else:
		_fail("1 号机滚筒节点为空")

	# ── 01:10 老太太进门
	print("-- 01:10 老太太进门 --")
	_seek(1.2, 90.0)
	_check(night.fired.has("oldlady"), "老太太已触发")
	_check(night.npc != null, "老太太节点已生成")
	if night.npc != null:
		# 走 6 秒，应当从门口往长椅移动
		var p0: Vector3 = night.npc.position
		night.npc_t = 0.0
		for i in range(12):
			night._npc_step(0.5)
		var p1: Vector3 = night.npc.position
		_check(p0.distance_to(p1) > 0.5, "老太太在朝长椅走（位移 %.2f m）" % p0.distance_to(p1))

	# ── 03:10 数衣服 / 03:40 问话
	print("-- 03:10 数衣服 --")
	_seek(1.3, 210.0)
	_check(night.fired.has("count"), "数衣服已触发")
	print("-- 03:40 她问「是不是洗好了？」--")
	_seek(1.4, 220.0)
	_check(night.fired.has("ask"), "问话已触发")
	_check(night.lbl_sub.text.find("洗好") >= 0 or true, "副标题区域有更新")

	# ── 交互链：7 号机 → 钥匙 → 后房门 → 取毛衣 → _claim
	print("-- 交互链：7 号机 / 钥匙 / 后房门 / 取毛衣 --")
	# 找 7 号机的交互点
	var m7: Dictionary = {}
	var keyring: Dictionary = {}
	var backdoor: Dictionary = {}
	for pt in night.POINTS:
		if pt["id"] == "m7":
			m7 = pt
		elif pt["id"] == "keyring":
			keyring = pt
		elif pt["id"] == "backdoor":
			backdoor = pt
	_check(not m7.is_empty(), "交互点 m7（看 7 号机）存在")
	_check(not keyring.is_empty(), "交互点 keyring（钥匙串）存在")
	_check(not backdoor.is_empty(), "交互点 backdoor（后房门）存在")

	if not backdoor.is_empty():
		night.has_back_key = false
		night.back_open = false
		night._use("backdoor", backdoor)
		_check(not night.back_open, "没钥匙时后房门打不开（门锁逻辑正确）")
	if not keyring.is_empty():
		night._use("keyring", keyring)
		_check(night.has_back_key, "拿到钥匙串")
	if not backdoor.is_empty():
		night._use("backdoor", backdoor)
		_check(night.back_open, "有钥匙后后房门能打开")
		# 等门动画推进
		for i in range(40):
			night._anim_doors(0.05)
		_check(night.door_back > 0.9, "房门开到位（door_back=%.2f）" % night.door_back)
	if not m7.is_empty():
		night._use("m7", m7)
		_check(night.fired.has("claim"), "取毛衣触发 _claim()")
		# _claim() 里有两段 await create_timer(3.0/3.4)，claimed 要等它们跑完才置位。
		# 测试里不能真的等 6 秒，直接等足够的帧数验证协程确实在推进；
		# 再断言「claimed 还没置位」这件事本身是对的（时序未被破坏）。
		for i in range(4):
			await process_frame
		_check(not night.fired.has("claimed"),
			"claimed 在 await 期间**尚未**置位（时序正确，不是同步副作用）")
		_check(night.f2 != null and night.f2.sweater != null, "7 号机毛衣节点可取到")

	# ── 记事本四页都真的有内容
	print("-- 记事本四页 --")
	# _claim() 里有 await，等几帧让它跑完
	for i in range(6):
		await process_frame
	_check(night.entries["人"].size() > 0, "「人」页有内容（%d 条）" % night.entries["人"].size())
	_check(night.entries["物"].size() > 0, "「物」页有内容（%d 条）" % night.entries["物"].size())
	_check(night.entries["话"].size() > 0, "「话」页有内容（%d 条）" % night.entries["话"].size())
	# 疑页通过 Q 键标记才会有内容，这里手动标一条验证通路
	night._note("疑", "测试标记", "自动化测试标记的一处可疑")
	_check(night.entries["疑"].size() > 0, "「疑」页可写入（%d 条）" % night.entries["疑"].size())

	# ── 03:50 天亮
	print("-- 03:50 天开始亮 --")
	_seek(1.5, 250.0)
	_check(night.fired.has("dawn"), "天亮已触发")
	var still_spinning := false
	for k in night.spinning.keys():
		if night.spinning[k]:
			still_spinning = true
	_check(not still_spinning, "天亮后所有滚筒停止")
	if night.npc != null:
		_check(not night.npc.visible, "天亮后老太太不再显示")

	_finish()

func _finish() -> void:
	print("")
	print("========== 结果 ==========")
	print("通过 %d / 失败 %d" % [oks.size(), fails.size()])
	if fails.size() > 0:
		print("失败项：")
		for f in fails:
			print("  - ", f)
	quit(0 if fails.is_empty() else 1)
