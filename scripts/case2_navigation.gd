extends Node
## Navigation points follow room openings and the usable lift, never an upstairs
## clue projected straight through the ceiling. The shared HUD owns story text.
var controller
var game
var pin: Control
var label: Label
var last_key:=""
var points:Array[Vector3]=[]
var target:=Vector3.ZERO

class Pin extends Control:
	func _draw()->void:
		var color:=Color("d9bc88")
		draw_circle(Vector2.ZERO,13,Color(.02,.05,.05,.8))
		draw_polyline(PackedVector2Array([Vector2(0,-9),Vector2(8,0),Vector2(0,9),Vector2(-8,0),Vector2(0,-9)]),color,1.5,true)
		draw_circle(Vector2.ZERO,2,color)

func setup(owner_controller)->void:
	controller=owner_controller;game=controller.game
	var layer:=CanvasLayer.new();layer.layer=8;add_child(layer)
	pin=Pin.new();pin.mouse_filter=Control.MOUSE_FILTER_IGNORE;layer.add_child(pin)
	label=Label.new();label.position=Vector2(-175,22);label.size=Vector2(350,60)
	label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font",game.font);label.add_theme_font_size_override("font_size",17)
	label.add_theme_color_override("font_color",Color("e0cfab"))
	label.add_theme_color_override("font_shadow_color",Color.BLACK);label.add_theme_constant_override("shadow_offset_x",1);label.add_theme_constant_override("shadow_offset_y",2)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE;pin.add_child(label);pin.visible=false

func _process(_delta:float)->void:
	pin.visible=false
	if not controller.active or not controller.in_residence or game.state!="play" or not game.focus.available():return
	var world=controller.world;var story=controller.campaign
	if not is_instance_valid(world):return
	var goal:Dictionary=story.current_goal();var id:=String(goal.get("id",""))
	if not world.manifest.anchors.has(id):return
	var row:Dictionary=world.manifest.anchors[id]
	var level:=clampi(int(round(world.to_local(game.player.global_position).y/3.))+1,1,17)
	var target_floor:=int(row.floor)
	var route_id:=id
	var caption:=String(row.get("text","调查目标"))
	if level!=target_floor and world.manifest.anchors.has("c2_lift_"+str(level)):
		route_id="c2_lift_"+str(level)
		caption="沿走廊到电梯 · 前往%dF"%target_floor
	var key:=String(goal.get("key",id))+"_"+str(level)+"_"+route_id
	if key!=last_key:
		last_key=key;points=world.get_route(route_id,game.player.global_position)
	while not points.is_empty():
		var flat:Vector3=points[0]-game.player.global_position;flat.y=0
		if flat.length()>.48:break
		points.pop_front()
	target=points[0]+Vector3(0,1.1,0) if not points.is_empty() else world.get_anchor(route_id)
	var cam:Camera3D=game.player.cam
	var view:Vector2=game.get_viewport().get_visible_rect().size
	var screen:Vector2=cam.unproject_position(target)
	if cam.is_position_behind(target):
		var local:Vector3=cam.global_transform.affine_inverse()*target
		screen=Vector2(70 if local.x<0 else view.x-70,view.y*.57)
	screen.x=clampf(screen.x,65,view.x-300);screen.y=clampf(screen.y,160,view.y-180)
	if game.prompt!=null and String(game.prompt.get("id",""))==id:return
	pin.position=screen;pin.visible=true
	label.text=caption+"\n"+("%dF · %.0f米"%[target_floor,game.player.global_position.distance_to(world.get_anchor(id))])
