extends Node
## 一个主目标；先到入口再到物件，帮助按停滞时间逐级展开。
const LEVELS := [-3.0,0.0,3.5,6.9,9.8,12.7,15.6]
var story
var hint: Label
var marker: Control
var last_key := ""
var idle_seconds := 0.0
var best_distance := INF
var last_route := ""
func setup(campaign) -> void:
 story=campaign
 var layer=CanvasLayer.new();layer.layer=6;add_child(layer)
 hint=Label.new();hint.position=Vector2(38,138);hint.size=Vector2(780,110)
 hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;hint.mouse_filter=Control.MOUSE_FILTER_IGNORE
 hint.add_theme_font_override("font",story.game.font);hint.add_theme_font_size_override("font_size",18)
 hint.modulate=Color("c9d8c7");layer.add_child(hint)
 marker=preload("res://scripts/quest_marker.gd").new();layer.add_child(marker);marker.setup(story.game.font)
func floor_index(y: float) -> int:
 var floor_id=0
 for i in range(LEVELS.size()):
  if y>=LEVELS[i]:floor_id=i
 return floor_id
func point_for(id: String) -> Dictionary:
 for point in story.lc.spots():
  if point.id==id:return point
 return {}
func waypoint(at: Vector3, text: String, final:=false) -> Dictionary:
 return {"pos":at,"text":text,"final":final}
func route_for(goal: Dictionary, p: Vector3) -> Dictionary:
 var point=point_for(goal.id)
 if point.is_empty():return {}
 var destination:Vector3=point.pos
 var current=floor_index(p.y+.22);var target=floor_index(destination.y+.1)
 var in_stair:bool=p.x>.25 and p.x<2.85 and p.z>10.65
 var on_segment:bool=p.y>LEVELS[current]+.23
 if in_stair and (current!=target or on_segment):
  var low=current
  if target<current and p.y<LEVELS[current]+.2:low=maxi(1,current-1)
  var high=mini(low+1,LEVELS.size()-1);var middle:float=(LEVELS[low]+LEVELS[high])*.5
  if target>current:
   if p.z>13.3 and p.x<1.95:return waypoint(Vector3(2.21,middle+1.2,13.65),"在平台右转，换到右侧梯跑")
   if p.x<1.5:return waypoint(Vector3(.89,middle+1.2,13.65),"沿左侧梯跑上到折返平台")
   return waypoint(Vector3(2.21,LEVELS[high]+1.2,10.45),"沿右侧梯跑继续上楼")
  if p.z>13.3 and p.x>1.2:return waypoint(Vector3(.89,middle+1.2,13.65),"在平台左转，换到左侧梯跑")
  if p.x>1.5:return waypoint(Vector3(2.21,middle+1.2,13.65),"沿右侧梯跑下到折返平台")
  return waypoint(Vector3(.89,LEVELS[low]+1.2,10.45),"沿左侧梯跑继续下楼")
 if p.x>.25 and p.x<2.85 and p.z>9.85 and current==target:return waypoint(Vector3(.89 if p.x<1.5 else 2.21,LEVELS[current]+1.2,9.65),"离开楼梯间，进入本层走廊")
 if current!=target:
  if current==1 and target==0:return waypoint(Vector3(2.65,1,-8.1),"到1F北侧检修口，按 E 下到 B1")
  if current==0:return waypoint(Vector3(2.55,-1.5,-8.1),"回到检修梯，按 E 上到1F")
  var stair_x:float=.89 if target>current else 2.21
  if absf(p.x-stair_x)>.18:
   return waypoint(Vector3(p.x if p.z>9.85 else stair_x,LEVELS[current]+1.2,9.5),"先在楼梯口前对准"+("左侧上行梯跑" if target>current else "右侧下行梯跑"))
  return waypoint(Vector3(stair_x,LEVELS[current]+1.2,11.6),"到走廊尽头，沿楼梯"+("上楼" if target>current else "下楼"))
 # 同层先找正确入口，不能隔墙直接指向物件。
 if goal.id=="c1_mail_letter" and p.x<13.2:
  if p.x<2.8 and absf(p.z-9.5)>.25:return waypoint(Vector3(1.25,4.8,9.5),"先走到店堂南端的廊桥路标")
  if p.x<3.55:return waypoint(Vector3(3.6,4.8,9.5),"从东南侧门口进入廊桥")
  return waypoint(Vector3(13.8,4.8,9.5),"沿廊桥走到楼内邮政存档间")
 if goal.id=="c1_power" and p.x<3.2:
  if p.x<2.25:
   if p.z<7.7 or p.z>8.05:return waypoint(Vector3(1.25,4.8,7.85),"先沿过道走到长椅南端")
   return waypoint(Vector3(2.6,4.8,7.85),"从长椅南端绕到东侧")
  if p.z>7.12:return waypoint(Vector3(2.6,4.8,6.95),"沿椅背后方走到配电房门口")
 if goal.id in ["l_sign","l_registry","l_boiler","l_photowall","l_clipping"] and p.z>1.6:
  return waypoint(Vector3(-1.65,4.8,1.25),"从七号机左侧的后房门进入")
 if goal.id in ["c1_drawer","c1_photo"] and p.z>6.05:
  return waypoint(Vector3(-1.25,8.1,5.8),"从303门进入卧室")
 if goal.id=="c1_cert" and p.z>5.2:
  return waypoint(Vector3(1.55,8.1,4.95),"经304门进入，书桌在房间东侧")
 if goal.id=="c1_tools" and p.z>5.7:return waypoint(Vector3(0,11,5.3),"先到403维修间门口")
 if goal.id=="c1_keybox" and p.z>5.3:
  if story.flag("503_open"):return waypoint(Vector3(1.7,13.9,4.9),"503捷径已开，从房门进入")
  return waypoint(Vector3(-1.7,13.9,4.35),"先进入502，找东侧维修通道")
 if goal.id=="c1_keybox" and p.x<.5:
  if p.x<-.6 and absf(p.z-4.35)>.18:return waypoint(Vector3(-1.7,13.9,4.35),"沿502空屋走到维修通道前")
  return waypoint(Vector3(.9,13.9,4.35),"穿过维修通道，进入503")
 return waypoint(destination,"看向标记，走近后按 E 交互",true)
func available() -> bool:
 var g=story.game
 return g.case_mode=="laundry" and g.state=="play" and not g.phone_open and not g.bag_open and not g.nb_open
func sync_goal(goal: Dictionary) -> void:
 if last_key==goal.key:return
 var previous=last_key;last_key=goal.key;idle_seconds=0;best_distance=INF;last_route=""
 if previous!="" and goal.mode=="act":story.game.director.send_once("goal_"+goal.key,"派遣科",goal.text+"\n"+goal.why)
func track_progress(delta: float, goal: Dictionary, route: Dictionary, position: Vector3) -> void:
 sync_goal(goal)
 if goal.mode!="act":return
 var offset:Vector3=route.pos-position;offset.y=0
 if route.text!=last_route:
  last_route=route.text;best_distance=offset.length();idle_seconds=0
 elif offset.length()<best_distance-.6:
  best_distance=offset.length();idle_seconds=0
 else:idle_seconds+=delta
 if idle_seconds>=90:
  story.game.director.send_once("help_"+goal.key,"派遣科","调查提醒："+goal.text+"\n"+route.text+"。按 H 可展开当前提示。")
func _process(delta: float) -> void:
 hint.visible=available();marker.visible=false
 if not hint.visible:return
 var g=story.game
 if g.audio_system.is_busy() or not g.sub_queue.is_empty():
  hint.text="正在听现场对白，暂时不用拨动时钟。";return
 var goal:Dictionary=story.current_goal();var route=route_for(goal,g.player.global_position)
 if route.is_empty():hint.text=goal.why;return
 track_progress(delta,goal,route,g.player.global_position)
 if goal.mode!="act":
  hint.text=goal.why+"\n"+("T 到下一事件  ·  H 查看当前提示" if goal.mode=="wait" else "等她坐稳后，再走近按 E 交谈")
  return
 var destination:Vector3=route.pos
 var camera:Camera3D=g.player.cam
 if not camera.is_position_behind(destination):
  var screen:Vector2=camera.unproject_position(destination)
  var bounds:Vector2=g.get_viewport().get_visible_rect().size
  if screen.x>30 and screen.x<bounds.x-180 and screen.y>245 and screen.y<bounds.y-130:
   marker.position=screen+Vector2(0,-36);marker.caption.text=("调查" if route.final else "入口")+" · %.1fm"%g.player.global_position.distance_to(destination);marker.visible=true
 var offset:Vector3=destination-g.player.cam.global_position;offset.y=0
 var facing:Vector3=-g.player.cam.global_basis.z;facing.y=0
 var angle=rad_to_deg(facing.signed_angle_to(offset.normalized(),Vector3.UP))
 var direction="前方" if absf(angle)<35 else ("身后" if absf(angle)>140 else ("左侧" if angle>0 else "右侧"))
 var focused:bool=g.prompt!=null and g.prompt.get("id","")==goal.id
 hint.text=("" if focused else "%s · %.1f米 · %s\n"%[direction,offset.length(),route.text])+goal.why+"\nH 展开提示"+(" · "+route.text if idle_seconds>=45 else "")
func _input(event: InputEvent) -> void:
 if not available() or story.game.audio_system.is_busy():return
 if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_H:
  var goal:Dictionary=story.current_goal();var route=route_for(goal,story.game.player.global_position)
  story.show_page("当前调查提示",goal.text+"\n\n为什么："+goal.why+"\n\n怎么走："+String(route.get("text","按当前目标继续调查"))+"。\n\n可选调查不会拦住主线；找到的文件可在背包重读。")
  get_viewport().set_input_as_handled()
