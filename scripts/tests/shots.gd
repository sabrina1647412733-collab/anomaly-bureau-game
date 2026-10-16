extends SceneTree
## P1~P10 自动截图（只读地驱动游戏状态，不改任何游戏代码）
const OUT := "res://_预览/截图/"
var game

func _initialize() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
    game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    _run()

func _settle(n := 10) -> void:
    for i in range(n):
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        await process_frame
    await RenderingServer.frame_post_draw

func _shot(nm: String) -> void:
    await RenderingServer.frame_post_draw
    var img: Image = root.get_texture().get_image()
    img.save_png(OUT + nm + ".png")
    print("[SHOT] ", nm, "  ", img.get_width(), "x", img.get_height())

func _wait_until(cond: Callable, maxf := 400) -> void:
    var n := 0
    while n < maxf and not bool(cond.call()):
        Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
        await process_frame
        n += 1

func _look(x: float, z: float, yaw: float, pitch_v: float) -> void:
    game.player.global_position = Vector3(x, 0.25, z)
    game.player.rotation.y = yaw
    game.player.pitch = pitch_v
    game.player.cam.rotation.x = pitch_v

func _run() -> void:
    await _settle(40)
    game._on_start()
    await _settle(20)

    # ---- P1 序章开场：站在调度台前，三个钮可用 ----
    _look(-14.35, -13.60, PI * 0.5, -0.04)
    await _settle(25)
    await _shot("P1_序章开场")

    # ---- P2 车站地图总览：站台中央朝北，右上角地图面板 ----
    _look(-6.0, 6.0, 0.0, 0.02)
    await _settle(25)
    await _shot("P2_车站地图总览")

    # ---- P3 调度台操作面板：贴近调度台与三个钮 ----
    _look(-15.30, -14.00, PI * 0.5, -0.10)
    await _settle(25)
    await _shot("P3_调度台操作面板")

    # ---- P4 乘客详情：第 1 轮，站在林岚面前 ----
    game.round = 0
    game._refresh_visibility()
    _look(-12.60, 28.20, PI * 0.5, -0.02)
    await _settle(25)
    await _shot("P4_乘客详情_林岚")

    # ---- P5 线索板：背包（3 件已收集 / 2 件未解锁） ----
    game.items[0]["got"] = true
    game.items[1]["got"] = true
    game.items[2]["got"] = true
    game._set_sel(0)
    game._refresh_items_ui()
    game._toggle_bag(true)
    await _settle(25)
    await _shot("P5_线索板_背包")
    game._toggle_bag(false)
    await _settle(10)

    # ---- P6 广播与事件提示 ----
    _look(-6.0, -2.0, 0.0, 0.0)
    game._say("站内广播", "0017 次，岚桥站呼叫。前方四道占用，立即停车，等待人工引导。站台乘客请后退至黄线内。")
    await _settle(70)
    await _shot("P6_广播与事件提示")

    # ---- P7 循环重置画面：00:17 过场（环绕下一轮人物） ----
    game._begin_cutscene()
    await _wait_until(func(): return String(game.cut_phase) == "preview")
    await _settle(40)
    await _shot("P7_循环重置过场")

    # ---- P8 / P9 / P10 三个结局 ----
    game.hud_end.modulate.a = 1.0
    game._show_end("A")
    await _settle(70)
    await _shot("P8_结局A_零点之后")

    game.hud_end.modulate.a = 1.0
    game._show_end("B")
    await _settle(70)
    await _shot("P9_结局B_最后一班")

    game.hud_end.modulate.a = 1.0
    game._show_end("C")
    await _settle(70)
    await _shot("P10_未达成_那半秒")

    print("[SHOT] 全部完成")
    quit()
