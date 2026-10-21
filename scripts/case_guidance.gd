extends Node
## 单一当前目标：跨层先引向楼梯，同层显示方向和现场标记。
var story
var hint: Label
var marker: Label3D
var last_id := ""
func setup(campaign) -> void:
	story=campaign
	var layer=CanvasLayer.new();layer.layer=6;add_child(layer)
	hint=Label.new();hint.position=Vector2(38,134);hint.size=Vector2(760,68)
	hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_override("font",story.game.font);hint.add_theme_font_size_override("font_size",18)
	hint.modulate=Color("c9d8c7");layer.add_child(hint)
	marker=Label3D.new();marker.text="▼  当前目标";marker.font=story.game.font
	marker.font_size=44;marker.pixel_size=.004;marker.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	marker.modulate=Color("e9c57f");marker.outline_size=8
	story.lc.world.add_child(marker)
func _process(_delta: float) -> void:
	var g=story.game
	var active: bool=g.case_mode=="laundry" and g.state=="play" and not g.phone_open and not g.bag_open and not g.nb_open
	hint.visible=active;marker.visible=active
	if not active:return
	var goal: Dictionary=story.current_goal()
	var destination=Vector3.ZERO;var found=false
	for point in story.lc.spots():
		if point.id==goal.id:destination=point.pos;found=true;break
	if not found:marker.visible=false;hint.text=goal.why;return
	var p: Vector3=g.player.global_position
	var levels=[-3.0,0.0,3.5,6.9,9.8,12.7,15.6]
	var current=0;var target=0
	for i in range(levels.size()):
		if p.y+.25>=levels[i]:current=i
		if destination.y+.1>=levels[i]:target=i
	var extra=""
	# 井内分两跑引导，避免上到一半时目标又指回身后的梯口。
	var in_stair:bool=p.x>.25 and p.x<2.85 and p.z>10.65
	if in_stair and current!=target:
		var low=current
		if target<current and p.y<levels[current]+.2:low=maxi(1,current-1)
		var high=mini(low+1,levels.size()-1)
		var middle:float=(levels[low]+levels[high])*.5
		if target>current:
			if p.z>13.3 and p.x<1.95:destination=Vector3(2.21,middle+1.2,13.65)
			elif p.x<1.5:destination=Vector3(.89,middle+1.2,13.65)
			else:destination=Vector3(2.21,levels[high]+1.2,10.45)
			extra="沿左跑上行，在平台右转，再沿右跑继续上楼。"
		else:
			if p.z>13.3 and p.x>1.2:destination=Vector3(.89,middle+1.2,13.65)
			elif p.x>1.5:destination=Vector3(2.21,middle+1.2,13.65)
			else:destination=Vector3(.89,levels[low]+1.2,10.45)
			extra="沿右跑下行，在平台左转，再沿左跑继续下楼。"
	elif in_stair and current==target:
		destination=Vector3(1.55,levels[current]+1.2,9.65);extra="离开楼梯间，进入本层走廊。"
	elif current!=target:
		if current==1 and target==0:destination=Vector3(2.65,1,-8.1);extra="先到门厅北侧检修梯下B1。"
		elif current==0:destination=Vector3(2.55,-1.5,-8.1);extra="先沿检修梯回1F。"
		else:
			destination=Vector3(.89 if target>current else 2.2,levels[current]+1.2,11.6)
			extra="先沿楼梯上楼。" if target>current else "先沿楼梯下楼。"
	elif goal.id=="c1_power" and p.x<2.2:
		destination=Vector3(1.32,4.6,7.8) if p.z>7.9 else Vector3(2.6,4.6,7.8);extra="从长椅南端绕到东侧配电门。"
	marker.global_position=destination+Vector3(0,.24,0)
	var offset: Vector3=destination-g.player.cam.global_position;offset.y=0
	var facing: Vector3=-g.player.cam.global_basis.z;facing.y=0
	var angle=rad_to_deg(facing.signed_angle_to(offset.normalized(),Vector3.UP))
	var direction="前方" if absf(angle)<35 else ("身后" if absf(angle)>140 else ("左侧" if angle>0 else "右侧"))
	hint.text="%s  ·  %.1f米  %s\n%s"%[direction,offset.length(),extra,goal.why]
	if goal.id!=last_id:
		if last_id!="":g.director.send_once("goal_n%d_%s"%[story.night_number(),goal.id],"派遣科",goal.text+"\n"+goal.why)
		last_id=goal.id
