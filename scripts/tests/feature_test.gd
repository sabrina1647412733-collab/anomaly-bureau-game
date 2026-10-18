extends SceneTree
## 电脑/广播台/第三人称转身回归
var game

func _initialize() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	_run()

func _energy_sum(nodes: Array) -> float:
	var total := 0.0
	for l in nodes:
		if l is OmniLight3D:
			total += l.light_energy
	return total

func _run() -> void:
	for i in range(30):
		await process_frame
	game._on_start()
	for i in range(10):
		await process_frame
	# 车站照明开关：站台/隧道主灯变暗，应急灯保持不变，再开恢复。
	var plat = get_nodes_in_group("station_light_platform")
	var emerg = get_nodes_in_group("station_light_emergency")
	var side_lights := []
	for l in game.train.lamps:
		if l is OmniLight3D and l.has_meta("side_light"):
			side_lights.append(l)
	game.train.set_side_fill_scale(1.0)
	game.train.lights_on(true)
	var p_on := _energy_sum(plat)
	var e_on := _energy_sum(emerg)
	var s_on := _energy_sum(side_lights)
	game._act("station_light_switch")
	await process_frame
	var switch_off_ok: bool = not game.station_lights_on
	switch_off_ok = switch_off_ok and _energy_sum(plat) < p_on * 0.30
	switch_off_ok = switch_off_ok and absf(_energy_sum(emerg) - e_on) < 0.001
	switch_off_ok = switch_off_ok and _energy_sum(side_lights) < s_on * 0.40
	game._act("station_light_switch")
	await process_frame
	var switch_ok: bool = switch_off_ok and game.station_lights_on and absf(_energy_sum(plat) - p_on) < 0.01
	switch_ok = switch_ok and absf(_energy_sum(side_lights) - s_on) < 0.01
	game.train.lights_on(false)
	print("[FEAT] station_lights off=", switch_off_ok, " on=", switch_ok, " platform=", p_on, " emergency=", e_on, " side=", s_on)
	game._act("pc")
	await process_frame
	var pc_ok: bool = game.state == "minigame" and game.pc_overlay.visible
	var buttons: Array = game.pc_overlay.get("buttons")
	var file: Label = game.pc_overlay.get("file_view")
	var file_ok: bool = file != null and file.text.contains("邵国平") and file.text.contains("19")
	print("[FEAT] pc state=", game.state, " visible=", game.pc_overlay.visible, " buttons=", buttons.size(), " file=", file_ok)
	game._close_pc()
	await process_frame
	var close_ok: bool = game.state == "play" and not game.pc_overlay.visible
	game.round = 1
	game._act("studio_dial"); game._act("studio_dial"); game._act("studio_dial")
	await process_frame
	var tape_ok := false
	for it in game.items:
		if String(it["def"]["id"]) == "tape":
			tape_ok = bool(it["got"])
	game._act("studio_onair")
	var onair_ok: bool = game.studio_onair_on
	game.player.cam_mode = 1
	game.player.velocity = Vector3(1, 0, 0)
	var before: float = game.player.body.rotation.y
	game.player._update_body(0.1, 1.0)
	var after: float = game.player.body.rotation.y
	var turn_ok := absf(after - before) > 0.01
	print("[FEAT] close=", close_ok, " tape=", tape_ok, " onair=", onair_ok, " turn=", before, "->", after)
	game.round = 3
	game.handle = false
	game.late = true
	game._resolve_final()
	await process_frame
	var c_ok: bool = game.shown_end == "C" and game.hud_end_title.text.contains("结局 C")
	print("[FEAT] ending_c=", c_ok)
	var pass_ok: bool = switch_ok and pc_ok and file_ok and close_ok and tape_ok and onair_ok and turn_ok and c_ok
	print("[FEAT] PASS=", pass_ok)
	quit(0 if pass_ok else 1)