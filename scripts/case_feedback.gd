extends Node
## 操作反馈独立于剧情字幕；阅读、电话、对白期间保留，回到现场再显示。
var game
var panel: PanelContainer
var title: Label
var detail: Label
var pending: Array[Dictionary] = []
var current: Dictionary = {}
var remaining := 0.0
const ITEM_HELP := {
 "phone":"B 收纳手机；空手按 B 打开背包，再次取出。",
 "envelope":"入职已确认；任务会发到手机。空手 B 打开背包，取出通知书后按 F 重读。",
 "weird_clock":"T 打开随身时钟；可推进到下一事件。",
 "back_key":"用于 2F 后房外门，不能开启七号机。",
 "drawer_key":"用于 3F303 最下层抽屉。",
 "mail_key":"用于 1F503 信箱，不能开启五楼503房门。",
 "tool_key":"用于 5F503 检修盒，不能直接开启七号机。",
 "machine_key":"用于 2F 七号机滚筒锁。"
}
func setup(g) -> void:
 game=g
 var layer=CanvasLayer.new();layer.layer=20;add_child(layer)
 panel=PanelContainer.new();panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
 panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
 panel.offset_left=38;panel.offset_top=-236;panel.offset_right=490;panel.offset_bottom=-112
 panel.add_theme_stylebox_override("panel",game.phone_ui.style(Color(.06,.12,.13,.96),10,Color("738a70")))
 layer.add_child(panel)
 var margin=MarginContainer.new();margin.mouse_filter=Control.MOUSE_FILTER_IGNORE
 for side in ["left","right","top","bottom"]:margin.add_theme_constant_override("margin_"+side,16)
 panel.add_child(margin)
 var stack=VBoxContainer.new();stack.mouse_filter=Control.MOUSE_FILTER_IGNORE;stack.add_theme_constant_override("separation",8);margin.add_child(stack)
 title=Label.new();title.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;title.add_theme_font_override("font",game.font);title.add_theme_font_size_override("font_size",21);title.modulate=Color("e0c992");stack.add_child(title)
 detail=Label.new();detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;detail.add_theme_font_override("font",game.font);detail.add_theme_font_size_override("font_size",17);detail.modulate=Color("d1ddd0");stack.add_child(detail)
 panel.visible=false
func reset() -> void:
 pending.clear();current.clear();remaining=0;panel.visible=false
func notify(heading: String, body: String) -> void:
 var notice={"title":heading,"detail":body}
 if current==notice or pending.has(notice):return
 pending.append(notice)
 if pending.size()>8:pending.pop_front()
func acquired(id: String, name: String) -> void:
 notify("已收入背包 · "+name,ITEM_HELP.get(id,"证据已保管。空手按 B 打开背包，可取出重读。"))
func available() -> bool:
 return game.state in ["play","prologue"] and not game.bag_open and not game.phone_open and not game.nb_open and not game.field_kit.letter_ui.visible and not game.audio_system.is_busy() and game.sub_queue.is_empty()
func step(delta: float) -> void:
 panel.visible=false
 if not available():return
 if current.is_empty() and not pending.is_empty():
  current=pending.pop_front();remaining=5.0
  title.text=current.title;detail.text=current.detail
  game.audio_system.sfx("ui_tap",-20)
 if current.is_empty():return
 panel.visible=true;remaining-=delta
 if remaining<=0:current.clear();panel.visible=false
func _process(delta: float) -> void:step(delta)
