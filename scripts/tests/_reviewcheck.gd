extends SceneTree
## 验证：① 值班台 M 回看的门槛与流程 ② 岔区机位触发「红灯晚了半秒」
var game

func _initialize() -> void:
    game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    _run()

func _run() -> void:
    for i in range(45):
        await process_frame
    game._on_start()
    for i in range(20):
        await process_frame
    # ① 站远处按 M：不该进监控
    game.player.global_position = Vector3(-8.0, 0.25, 6.0)
    game._toggle_cctv_review()
    print("[M] 站在远处 → cam_mode=%d（应为 0，未进入）" % game.player.cam_mode)
    # ② 走到值班台前按 M：应进入监控
    game.player.global_position = Vector3(-15.60, 0.25, -13.60)
    game._toggle_cctv_review()
    for i in range(10):
        await process_frame
    print("[M] 站在值班台前 → cam_mode=%d（应为 3）  当前机位 %s「%s」" % [game.player.cam_mode, game.player.cctv_tag(), game.player.cctv_name()])
    # ③ 换到岔区机位：应触发「晚了半秒」
    var guard := 0
    while game.player.cctv_i != 6 and guard < 12:
        game.player.next_cctv()
        game._cctv_tip()
        guard += 1
    for i in range(6):
        await process_frame
    print("[N] 换到 %s「%s」 → saw_lag=%s（应为 true）" % [game.player.cctv_tag(), game.player.cctv_name(), game.saw_lag])
    # ④ 再按 M：应退出并回到进入前的视角
    game._toggle_cctv_review()
    for i in range(6):
        await process_frame
    print("[M] 再按一次 → cam_mode=%d（应回到 0）  fov=%.0f" % [game.player.cam_mode, game.player.cam.fov])
    # 顺带出一张岔区监视器图
    game.player.global_position = Vector3(10.0, -0.60, -100.0)
    game.player.enter_cctv()
    game.player.cctv_i = 6
    for i in range(12):
        await process_frame
    quit()
