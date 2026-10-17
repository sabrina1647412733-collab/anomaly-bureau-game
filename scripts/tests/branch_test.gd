extends SceneTree
## 岔区 / 道岔 / 改环线结局 的无头验证
var game
var f := 0

func _initialize() -> void:
    game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)

func _ray(a: Vector3, b: Vector3) -> String:
    var sp: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
    var q := PhysicsRayQueryParameters3D.create(a, b)
    var h: Dictionary = sp.intersect_ray(q)
    if h.is_empty():
        return "通 %.1f 米" % a.distance_to(b)
    return "挡在 %.2f 米" % a.distance_to(h["position"])

func _key(code: int) -> void:
    var ev := InputEventKey.new()
    ev.physical_keycode = code
    ev.pressed = true
    root.push_input(ev)
    var ev2 := InputEventKey.new()
    ev2.physical_keycode = code
    ev2.pressed = false
    root.push_input(ev2)

func _cars() -> String:
    var s := ""
    for c in game.train.cars:
        s += "(%.1f, %.0f) " % [c.position.x, c.position.z]
    return s

func _process(_d: float) -> bool:
    f += 1
    match f:
        30:
            print("[B] ── 岔区可达性 ──")
            print("  轨行区→岔区 (z=-90)：", _ray(Vector3(4.0, -0.4, -90.0), Vector3(13.0, -0.4, -90.0)))
            print("  轨行区→岔区 (z=-70)：", _ray(Vector3(4.0, -0.4, -70.0), Vector3(13.0, -0.4, -70.0)))
            print("  环线北墙门洞 (x=10.9)：", _ray(Vector3(10.9, -0.4, -63.0), Vector3(10.9, -0.4, -68.0)))
            print("  门洞西侧应挡 (x=9.0)：", _ray(Vector3(9.0, -0.4, -63.0), Vector3(9.0, -0.4, -68.0)))
            print("  侧线洞口 (x=15.5)：", _ray(Vector3(15.5, -0.4, -63.0), Vector3(15.5, -0.4, -68.0)))
            print("[B] ── 地板（-1.15 左右才对）──")
            for p in [Vector3(10.0, 3.0, -90.0), Vector3(15.5, 3.0, -110.0), Vector3(15.5, 3.0, -40.0), Vector3(15.5, 3.0, 40.0)]:
                print("  (%.1f, %.1f) 往下：%s" % [p.x, p.z, _ray(p, Vector3(p.x, -8.0, p.z))])
            print("[B] ── 顶 / 侧墙 ──")
            print("  岔区顶 (10,-90)：", _ray(Vector3(10.0, 0.0, -90.0), Vector3(10.0, 9.0, -90.0)))
            print("  侧线顶 (15.5,-40)：", _ray(Vector3(15.5, 0.0, -40.0), Vector3(15.5, 9.0, -40.0)))
            print("  侧线西墙：", _ray(Vector3(15.5, -0.4, -40.0), Vector3(8.0, -0.4, -40.0)))
            print("  侧线东墙：", _ray(Vector3(15.5, -0.4, -40.0), Vector3(24.0, -0.4, -40.0)))
        60:
            game._on_start()
            game.round = 3
            game.player.global_position = Vector3(5.8, -1.0, -110.5)
            game.player.rotation.y = 0.0
            print("[B] ── 交互 ──")
        95:
            print("  站到道岔机前 → 提示=", game.prompt)
            _key(KEY_E)
        105:
            print("  没钥匙按 E → divert=", game.divert, "（应为 false）")
            print("  信号灯红=", game.sig_red.material_override.emission_energy_multiplier, " 绿=", game.sig_green.material_override.emission_energy_multiplier)
            game.items[2]["got"] = true
        140:
            print("  拿到停用钥匙 → 提示=", game.prompt)
            _key(KEY_E)
        150:
            print("  按 E → divert=", game.divert, "（应为 true）")
            print("  信号灯红=", game.sig_red.material_override.emission_energy_multiplier, " 绿=", game.sig_green.material_override.emission_energy_multiplier)
            print("[B] ── 列车走岔道 ──")
            game.train.set_divert(true)
            for z in [-110.0, -95.0, -80.0, -70.0]:
                game.train.place(game.train.s_at_z(z))
                print("  车头在 z=%.0f → %s" % [z, _cars()])
            print("  路径总长=", game.train.total_len(), " 终点 s=", game._dv_end_s)
        160:
            game.sub = ""
            game.sub_queue.clear()
            game.sub_pause = false
            game.clock_min = 1457.2
        260:
            print("[B] 过场中 state=", game.state, " phase=", game.cut_phase, " 车头 z=%.1f" % game.train.cars[0].position.z)
        1080:
            print("[B] 结束 state=", game.state, " 结局=", game.shown_end, " 车头 z=%.1f" % game.train.cars[0].position.z)
            print("[B] 末节车厢 z=%.1f（应已进侧线隧道，> -66）" % game.train.cars[5].position.z)
            return true
    return false
