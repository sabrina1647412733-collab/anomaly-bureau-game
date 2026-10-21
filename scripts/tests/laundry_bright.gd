extends SceneTree
## 亮度测量：每个关键房间取一张渲染平均亮度，和「能看清」的阈值对比。
## 输出：房间名 / 平均亮度(0-255) / 判定
##   --headless 跑不了渲染 → 必须 windowed：
##   Godot_..._console.exe --path . --script res://scripts/tests/laundry_bright.gd

const TARGETS := [
	# name,            相机位置,                  看向
	["1F 门厅",        Vector3(-1.70, 1.62, 14.2), Vector3(0.30, 1.30, 0.0)],
	["1F 信箱墙",      Vector3(-1.35, 1.45, 5.45), Vector3(-3.2, 1.35, 4.15)],
	["2F 洗衣店",      Vector3(0.00, 5.15, 10.0), Vector3(-1.50, 4.40, 2.20)],
	["2F 后房",        Vector3(-1.15, 4.95, 1.55), Vector3(-1.60, 4.25, -0.70)],
	["3F 走廊",        Vector3(0.20, 8.42, 9.80), Vector3(-0.40, 8.10, 5.40)],
	["3F 303 卧室",    Vector3(-0.45, 8.40, 5.10), Vector3(-2.85, 7.75, 3.35)],
	["3F 302 后房",    Vector3(-0.35, 8.28, 1.72), Vector3(-2.95, 7.55, -0.60)],
	["4F 走廊",        Vector3(0.90, 11.15, 9.80), Vector3(-0.6, 10.75, 5.40)],
	["4F 402 老周家",  Vector3(-0.40, 11.30, 5.20), Vector3(-2.90, 10.62, 3.40)],
	["4F 403 杂物间",  Vector3(0.72, 11.18, 4.95), Vector3(-0.15, 10.35, 3.05)],
	["5F 走廊",        Vector3(0.90, 13.95, 9.80), Vector3(-0.60, 13.20, 5.60)],
	["5F 502 空屋",    Vector3(-0.55, 14.10, 5.00), Vector3(-1.75, 12.70, 3.40)],
	["5F 503 门缝",    Vector3(1.70, 13.42, 7.45), Vector3(1.70, 12.86, 5.50)],
	["屋顶",           Vector3(1.60, 17.30, 10.20), Vector3(-3.40, 16.40, 6.20)],
	["B1 锅炉房",      Vector3(2.90, -1.55, -2.20), Vector3(-3.30, -1.90, -5.60)],
	["B1 蓄水池",      Vector3(3.10, -1.42, 6.85), Vector3(2.60, -4.10, 3.10)],
	["B1 竖井底",      Vector3(2.10, -1.60, -4.60), Vector3(3.60, -2.85, -6.10)],
]

## 判定门槛（0-255 平均亮度）：
##   < 25 太黑，玩不了；25-45 偏暗但可辨；45-70 正常夜景；> 160 过曝
const TOO_DARK := 25.0
const DARK_OK := 45.0
const NORMAL := 70.0
const OVER := 190.0

var scene
var idx := -1
var frames := 0
var shoot_now := false
var results: Array = []
var cache_img: Image = null

func _initialize() -> void:
	scene = load("res://scenes/laundry.tscn").instantiate()
	root.add_child(scene)
	RenderingServer.frame_post_draw.connect(_grab)

func _process(_d: float) -> bool:
	frames += 1
	if frames < 20:
		return false
	if idx < 0:
		idx = 0
		_apply(0)
		return false
	if shoot_now:
		return false
	# 每次 grab 之后推进
	return false

func _grab() -> void:
	if not shoot_now:
		return
	shoot_now = false
	cache_img = root.get_texture().get_image()
	_measure(idx)
	idx += 1
	if idx >= TARGETS.size():
		_report()
		quit()
		return
	_apply(idx)

func _apply(i: int) -> void:
	var t = TARGETS[i]
	var cam: Camera3D = scene.get_node("Cam")
	cam.current = true
	cam.position = t[1]
	cam.fov = 70.0
	cam.look_at(t[2], Vector3.UP)
	shoot_now = true

func _measure(i: int) -> void:
	var t = TARGETS[i]
	var img := cache_img
	var w := img.get_width()
	var h := img.get_height()
	# 取中间 60% 区域的平均亮度（避开 HUD 和黑边）
	var x0 := int(w * 0.2)
	var x1 := int(w * 0.8)
	var y0 := int(h * 0.2)
	var y1 := int(h * 0.8)
	var sum := 0.0
	var n := 0
	var dark_px := 0
	for y in range(y0, y1, 4):
		for x in range(x0, x1, 4):
			var c := img.get_pixel(x, y)
			var lum := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
			sum += lum
			if lum < 0.02:
				dark_px += 1
			n += 1
	var avg := sum / float(max(n, 1)) * 255.0
	var dark_ratio := float(dark_px) / float(max(n, 1))
	results.append([t[0], avg, dark_ratio])

func _report() -> void:
	print("")
	print("================ 亮度测量（平均亮度 / 近乎全黑像素占比）================")
	var bad: Array = []
	for r in results:
		var name: String = r[0]
		var avg: float = r[1]
		var dr: float = r[2]
		var verdict := ""
		if avg < TOO_DARK:
			verdict = "★ 太黑，玩不了"
			bad.append(name)
		elif avg < DARK_OK:
			verdict = "偏暗（可辨）"
		elif avg < NORMAL:
			verdict = "正常夜景"
		elif avg > OVER:
			verdict = "过曝"
		else:
			verdict = "亮"
		print("  %-14s %6.1f  %5.1f%%  %s" % [name, avg, dr * 100.0, verdict])
	print("----------------------------------------------------------------")
	print("太黑（<%.0f）：%d 处 %s" % [TOO_DARK, bad.size(), str(bad)])
