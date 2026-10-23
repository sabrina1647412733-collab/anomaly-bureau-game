extends SceneTree
## Isolated contract checks: no game UI, player archives or imported scene needed.
var passed := 0
var failed := 0

class Clock extends RefCounted:
	var minutes := 1390.0
	func now() -> float:
		return minutes

class GameStub extends Node3D:
	var director := Clock.new()
	var laundry = null
	var env_node: WorldEnvironment
	var player: CharacterBody3D
	var state := "prologue"
	var phone_open := false
	var bag_open := false
	var nb_open := false
	var sub_pause := false
	var choice = null

class TownStub extends Node3D:
	var game: Node3D
	var renewal = null
	var layout := {"buildings": [
		{"x": 10.0, "z": 10.0, "w": 4.0, "d": 8.0, "rot": PI / 2.0, "height": 9.0},
	], "landmarks": [
		{"id": "01", "x": 40.0, "z": 40.0, "w": 26.0, "d": 19.0, "height": 8.6},
		{"id": "10", "x": 86.0, "z": 15.0, "w": 12.0, "d": 9.0, "height": 4.0, "rot": PI * 0.5},
	]}

func check(value: bool, label: String) -> void:
	if value:
		passed += 1
		print("PASS ", label)
	else:
		failed += 1
		push_error("FAIL " + label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game := GameStub.new()
	root.add_child(game)
	game.env_node = WorldEnvironment.new()
	game.env_node.environment = Environment.new()
	game.env_node.environment.ambient_light_energy = 0.47
	game.add_child(game.env_node)
	game.player = CharacterBody3D.new()
	game.add_child(game.player)
	game.player.position = Vector3(20, 0.1, 20)
	var old_moon := DirectionalLight3D.new()
	old_moon.light_energy = 0.06
	game.add_child(old_moon)
	var town := TownStub.new()
	town.game = game
	game.add_child(town)
	var weather = preload("res://scripts/town/street_weather.gd").new()
	weather.setup(town)
	weather.set_process(false)
	var original: Environment = game.env_node.environment
	check(is_equal_approx(float(weather.profile_at(1390.0).rain), 0.6), "首夜23:10小雨")
	check(float(weather.profile_at(720.0).rain) == 0.0, "正午可有无雨天气")
	check(float(weather.profile_at(720.0).daylight) == 1.0, "正午为日间")
	check(float(weather.profile_at(240.0).daylight) > 0.10, "04:00交班已有晨光")
	check(float(weather.profile_at(1390.0).daylight) == 0.0, "夜间天空不发日光")
	check(float(weather.profile_at(1440.0 + 60.0).rain) < float(weather.profile_at(60.0).rain), "连续夜次有天气差异")
	check(weather.roof_height_at(Vector2(13.9, 10)) > 9.0, "旋转屋顶坐标正确")
	check(weather.roof_height_at(Vector2(10, 12.5)) > 9.0, "屋檐内侧排除雨")
	check(weather.roof_height_at(Vector2(10, 13)) < 0.1, "离开屋檐雨落到道路")
	check(weather.roof_height_at(Vector2(40, 40)) >= 15.8, "洗衣楼屋顶与五层实际高度一致")
	check(weather.roof_height_at(Vector2(86, 15)) < 0.1, "露天铁路道口不误当整座屋顶")
	check(weather.roof_height_at(Vector2(80, 8.8)) >= 2.97, "铁路值班房实际屋顶遮雨")
	weather.activate()
	check(game.env_node.environment != original, "室外使用独立环境副本")
	check(is_equal_approx(original.ambient_light_energy, 0.47), "原室内环境未被修改")
	check(not old_moon.visible, "进入街道隐藏旧月光")
	check(weather.rain_node.multimesh.instance_count == 1352, "1352雨丝用一个MultiMesh批次")
	check(weather.environment.background_mode == Environment.BG_SKY, "街道显示真实天空")
	weather.refresh(1.0)
	check(weather.animation_time == 1.0, "游玩推进雨与云动画")
	var before: Dictionary = weather.capture()
	game.state = "paused"
	game.director.minutes += 20.0
	weather.refresh(10.0)
	check(weather.capture() == before, "暂停冻结雨云、天气与路面湿度")
	game.state = "prologue"
	weather.refresh(0.0)
	check(weather.last_clock == game.director.minutes, "恢复后按主时钟处理跳时")
	check(weather.wetness >= float(before.wetness), "雨中跳时增加地面湿度")
	var saved: Dictionary = weather.capture()
	weather.wetness = 0.0
	weather.animation_time = 0.0
	weather.restore(saved)
	check(weather.capture() == saved, "存读档保存同一雨云相位与湿度")
	weather.deactivate()
	check(game.env_node.environment == original, "离开街道恢复原环境资源")
	check(old_moon.visible and is_equal_approx(old_moon.light_energy, 0.06), "室内旧月光状态恢复")
	game.director.minutes = 720.0
	weather.restore({"version": 1, "wetness": 0.9, "last_clock": 720.0})
	weather.refresh(3.0)
	check(game.env_node.environment == original and is_equal_approx(original.ambient_light_energy, 0.47), "后台天气不向室内写环境")
	check(weather.animation_time == 0.0, "离开街道停止绘制动画")
	game.director.minutes = 900.0
	weather.refresh(0.0)
	check(weather.wetness < 0.9, "日间风干与后续降雨连续积分")
	weather.activate()
	check(weather.environment != original, "再进街道仍使用独立环境")
	weather.deactivate()
	game.queue_free()
	await process_frame
	print("STREET WEATHER: ", passed, " passed, ", failed, " failed")
	quit(1 if failed else 0)
