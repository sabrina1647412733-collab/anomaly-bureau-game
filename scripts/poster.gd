extends Node3D
## 海报机位：渲染游戏主视觉（雾里 0017 的车灯）
const StationBuilder := preload("res://scripts/station.gd")
const Level := preload("res://scripts/level.gd")
const TrainScript := preload("res://scripts/train.gd")

func _ready() -> void:
    var sf: Font = load("res://assets/fonts/NotoSansSC-Regular.otf")
    if not (sf is Font):
        var sys := SystemFont.new()
        sys.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "SimHei"])
        sf = sys
    var e := Environment.new()
    e.background_mode = Environment.BG_COLOR
    e.background_color = Color(0.027, 0.043, 0.063)
    e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    e.ambient_light_color = Color(0.45, 0.55, 0.70)
    e.ambient_light_energy = 1.45
    e.fog_enabled = false
    e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
    e.tonemap_exposure = 1.0
    e.adjustment_enabled = true
    e.adjustment_contrast = 1.10
    e.adjustment_saturation = 0.80
    var we := WorldEnvironment.new()
    we.environment = e
    add_child(we)

    var b := StationBuilder.new(self)
    b.font = sf
    var l := Level.new()
    l.b = b
    l.font = sf
    l.build()
    b.commit()

    var t := TrainScript.new(self)
    t.root.position = Vector3(0, 0, -30.0)
    for n in t.root.get_children():
        if n is Light3D:
            n.visible = true
            if n is SpotLight3D:
                n.light_energy = 26.0
                n.spot_range = 90.0
                n.spot_angle = 22.0

    var c := Camera3D.new()
    c.fov = 55.0
    c.near = 0.05
    c.far = 420.0
    add_child(c)
    c.position = Vector3(-5.2, 1.58, 12.0)
    c.look_at(Vector3(2.4, 1.15, -20.0))
    c.current = true
