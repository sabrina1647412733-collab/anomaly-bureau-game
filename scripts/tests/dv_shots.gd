extends SceneTree
## 固定机位逐帧摆位，用于截图（不走过场计时器）
var game
var f := 0
var s0 := 0.0
var s1 := 0.0
func _initialize() -> void:
    game = load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
func _process(_d: float) -> bool:
    f += 1
    match f:
        3:
            game._on_start()
            game.round = 3
            game.divert = true
            game.train.set_divert(true)
            s0 = game.train.s_at_z(-160.0)
            s1 = game.train.s_at_z(-62.0) + game.train.last_front_offset()
            game.state = "frozen"
            game.player.can_move = false
            game.player.allow_capture = false
            game.hud_fade.modulate.a = 0.0
            game.hud_sub.text = ""
            game.hud_sub_title.text = ""
            game.hud_prompt.text = ""
            game.train.lights_on(true)
            var cc := Camera3D.new()
            cc.fov = 62.0
            cc.near = 0.05
            cc.far = 420.0
            game.add_child(cc)
            game.cutcam = cc
            cc.current = true
        4, 5, 6, 7, 8, 9, 10, 11, 12:
            var k := float(f - 3) / 9.0
            game.train.place(lerpf(s0, s1, k))
            game.cutcam.position = Vector3(16.6, 3.40, -78.0).lerp(Vector3(16.2, 3.40, -84.0), k)
            game.cutcam.look_at(Vector3(6.0, 0.8, -104.0).lerp(Vector3(13.0, 0.6, -66.0), k))
            print("shot f=", f, " s=%.0f" % lerpf(s0, s1, k), " 头 z=%.0f" % game.train.cars[0].position.z, " 尾 z=%.0f" % game.train.cars[5].position.z)
    return f > 13
