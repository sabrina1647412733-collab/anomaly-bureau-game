extends SceneTree
## 本轮 7 项的实机截图
##   --path . --script res://scripts/tests/prologue_qol_shot.gd
const OUT := "res://_预览/洗衣店/出租屋优化/"

var game
var frames := 0
var idx := 0
var shoot := false
var steps := ["1_开场_黑屏", "2_手机_锁屏", "3_手机_聊天", "4_手机_钱包",
	"5_手机_通话", "6_信封_两个选项", "7_记事本_物页", "8_记事本_疑页",
	"9_诡异时钟", "10_ESC暂停菜单"]

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	RenderingServer.frame_post_draw.connect(_grab)

func _process(_d: float) -> bool:
	frames += 1
	if frames == 14:
		game._on_new_game()
		shoot = true                      # 1 开场黑屏
		return false
	# 等开场跑完
	if frames > 200 and game.state == "prologue" and idx == 1:
		game._open_phone()
		var p = game.phone_ui
		p._goto("lock")
		shoot = true
		return false
	if frames > 240 and idx == 2:
		game.phone_ui._goto("chat")
		shoot = true
		return false
	if frames > 280 and idx == 3:
		game.phone_ui._goto("wallet")
		shoot = true
		return false
	if frames > 320 and idx == 4:
		game.phone_ui._goto("calls")
		shoot = true
		return false
	if frames > 360 and idx == 5:
		game._close_phone()
		# 掉信封 + 捡起来，弹出两个选项
		game._prologue_drop_letter()
		game._pick_envelope()
	if frames > 460 and idx == 6:
		if game.choice == "env_choice":
			shoot = true                          # 6 两个选项
			return false
	if frames > 520 and idx == 7:
		game.choice = null
		game.state = "prologue"
		# 造几条记事本内容
		game.note("物", "通知书信封", "没有寄件人、没有邮票。邮戳是今天。")
		game.note("物", "灰色卫衣", "没有牌子、没有尺码标、没有产地。")
		game.note("人", "房东", "只在聊天里出现。他说他这楼里最近不太对劲。")
		game.note("话", "广播", "夜间请勿使用七号机。")
		game.note("疑", "门缝", "信封从门缝进来，可你没听见人上楼。")
		game._toggle_notebook()
		game.nb._go(0)
		shoot = true
		return false
	if frames > 560 and idx == 8:
		game.nb._go(3)
		shoot = true
		return false
	if frames > 620 and idx == 9:
		game.nb.close()
		game._spawn_weird_clock()
		game.wclock.total_min = 0
		game.wclock._update_hands()
		# 镜头对着钟
		var p2 = game.player
		p2.position = Vector3(1.1, 12.05, 322.3)
		p2.rotation.y = -0.7
		p2.pitch = -0.22
		p2.cam.rotation.x = -0.22
		shoot = true
		return false
	if frames > 680 and idx == 10:
		game._open_pause()
		shoot = true
		return false
	return false

func _grab() -> void:
	if not shoot:
		return
	shoot = false
	var img: Image = root.get_texture().get_image()
	var nm: String = steps[mini(idx, steps.size() - 1)]
	img.save_png(OUT + nm + ".png")
	print("[SHOT] ", nm)
	idx += 1
	if idx >= steps.size():
		quit()
		return
