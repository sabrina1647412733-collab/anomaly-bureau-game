extends SceneTree
## 审计：① 每个可坐位置是否落在实体内部（两个高度各做一次点查询）② 每件线索物品离下方表面多高
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
    var sp: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
    print("=== 座位审计（0.70 / 1.10 两个高度（避开椅子/长椅自身 0.50 高的碰撞盒）各点查询一次；0 = 空，>0 = 坐进东西里）===")
    var bad_seats := 0
    for i in range(game.builder.seats.size()):
        var s: Dictionary = game.builder.seats[i]
        var bad := 0
        for hy in [0.70, 1.10]:
            var q := PhysicsPointQueryParameters3D.new()
            q.position = s["pos"] + Vector3(0, hy, 0)
            var hits: Array = sp.intersect_point(q, 8)
            bad += hits.size()
        if bad > 0:
            bad_seats += 1
        print("  #%d %s  → 命中 %d %s" % [i, s["pos"], bad, "穿模！" if bad > 0 else "OK"])
    print("=== 线索物品离下方表面高度（理想 0.00，就是贴着放）===")
    var bad_items := 0
    for d in game.ITEM_DEFS:
        var p0: Vector3 = d["pos"] + Vector3(0, 0.6, 0)
        var p1: Vector3 = d["pos"] - Vector3(0, 1.2, 0)
        var q := PhysicsRayQueryParameters3D.create(p0, p1)
        var hit: Dictionary = sp.intersect_ray(q)
        if hit.is_empty():
            print("  %-14s 世界 %s  下方 3 m 内没有支撑面" % [d["id"], d["pos"]])
            bad_items += 1
        else:
            var gap: float = d["pos"].y - float(hit["position"].y)
            if gap > 0.03 or gap < -0.05:
                bad_items += 1
            print("  %-14s 世界 y=%.3f  下方 y=%.3f  间隙 %+.3f m %s" % [d["id"], d["pos"].y, hit["position"].y, gap, "← 还飘着" if gap > 0.03 else ("← 陷进去了" if gap < -0.05 else "OK")])
    print("=== 汇总：%d 个座位异常，%d 件物品异常 ===" % [bad_seats, bad_items])
    quit()
