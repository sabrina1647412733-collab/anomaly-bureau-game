extends Node3D
## Optional neighbours use the user's two meshes. No new quest state or dialogue
## session: a short, non-modal answer uses the existing subtitle lifecycle.
const BASE := "res://assets/models/chars/street_residents/"
const DEFINITIONS := [
	{"id":"resident_shopkeeper", "label":"电料店店主", "model":"electrical_shopkeeper.glb", "seed":551335, "side":1.4, "front":.42,
		"prompt":"向电料店店主问路", "line":"得利洗衣店就在沿街那栋，上二楼。先走楼下正门，再沿楼梯上去。雨天路滑，慢点走。",
		"return_line":"下班了？回出租公寓从原来的门进，别在雨里站太久。"},
	{"id":"resident_woman", "label":"附近住户", "model":"female_resident.glb", "seed":579349, "side":1.5, "front":.42,
		"prompt":"和附近住户打招呼", "line":"你是新来的夜班吧？得利洗衣店的门在楼下，工作间在二楼。进门看看值班登记，别错过报到。",
		"return_line":"雨一阵大一阵小的。下班就回出租公寓休息吧，门前那段路小心积水。"},
]

class HeadLook extends SkeletonModifier3D:
	var driver: Node3D
	var head := -1
	func _process_modification() -> void:
		if not is_instance_valid(driver):return
		var sk := get_skeleton()
		if sk == null:return
		if head < 0:head = sk.find_bone("mixamorig_Head")
		if head < 0 or absf(driver.head_yaw) < .0001:return
		# Imported bone axes differ from world Y. Apply a small world-up offset,
		# after animation evaluation, without rotating the planted feet or root.
		var world_basis := sk.global_basis * sk.get_bone_global_pose(head).basis
		var axis := world_basis.orthonormalized().inverse() * Vector3.UP
		var base := sk.get_bone_pose_rotation(head)
		sk.set_bone_pose_rotation(head, base * Quaternion(axis.normalized(), driver.head_yaw))

class Resident extends Node3D:
	var definition: Dictionary
	var animator: AnimationPlayer
	var skeleton: Skeleton3D
	var collider: StaticBody3D
	var look: HeadLook
	var idle := ""
	var head_yaw := 0.0
	var home_yaw := 0.0
	var grounded := false
	var ready_model := false
	var reply_cooldown := 0.0

var town
var game
var actors: Array[Resident] = []
var active := false
var grounding_pending := false

func setup(owner_town) -> void:
	town = owner_town
	game = town.game
	name = "StreetResidents"
	town.add_child(self)
	for definition in DEFINITIONS:
		var building: Dictionary = {}
		for entry in town.layout.get("buildings", []):
			if int(entry.get("seed", -1)) == int(definition.seed):
				building = entry
				break
		if building.is_empty():
			push_warning("街坊位置缺少对应原建筑："+str(definition.seed))
			continue
		var packed := load(BASE+String(definition.model)) as PackedScene
		if packed == null:
			push_error("用户街坊模型缺失："+String(definition.model))
			continue
		var actor := Resident.new()
		actor.name = String(definition.id)
		actor.definition = definition
		add_child(actor)
		actor.home_yaw = float(building.get("rot", 0.0))
		actor.rotation.y = actor.home_yaw # User models face +Z, the facade outward axis.
		var outward := Vector3(sin(actor.home_yaw), 0, cos(actor.home_yaw))
		var tangent := Vector3(cos(actor.home_yaw), 0, -sin(actor.home_yaw))
		actor.position = Vector3(float(building.fx), .03, float(building.fz)) + outward*float(definition.front) + tangent*float(definition.side)
		var model := packed.instantiate()
		actor.add_child(model)
		actor.animator = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		actor.skeleton = _find_skeleton(model)
		if actor.animator != null and actor.skeleton != null:
			# Source libraries are shared between instances: loop only this copy.
			for library_name in actor.animator.get_animation_library_list():
				var library := actor.animator.get_animation_library(library_name).duplicate(true)
				actor.animator.remove_animation_library(library_name)
				actor.animator.add_animation_library(library_name, library)
			for clip in actor.animator.get_animation_list():
				if String(clip).get_file().to_lower() == "idle":actor.idle = String(clip)
			if actor.idle != "":
				actor.animator.get_animation(actor.idle).loop_mode = Animation.LOOP_LINEAR
				actor.animator.play(actor.idle)
				actor.animator.advance(0.0)
				actor.animator.speed_scale = 0.0
				actor.ready_model = true
		if not actor.ready_model:
			push_error("街坊缺少完整站立动作，不能显示绑定姿势："+String(definition.id))
		actor.look = HeadLook.new()
		actor.look.driver = actor
		if actor.skeleton != null:actor.skeleton.add_child(actor.look)
		actor.collider = StaticBody3D.new()
		actor.collider.name = "ResidentBody"
		actor.collider.collision_layer = 0
		actor.collider.collision_mask = 0
		actor.add_child(actor.collider)
		var collision := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = .24
		capsule.height = 1.62
		collision.shape = capsule
		collision.position.y = .85
		actor.collider.add_child(collision)
		actor.visible = false
		actors.append(actor)

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:return node
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:return found
	return null

func activate() -> void:
	deactivate()
	active = true
	# Freshly built town collision enters the physics server on the next frame.
	# Keep bodies/meshes hidden until support has actually been measured.
	grounding_pending = true

func deactivate() -> void:
	active = false
	grounding_pending = false
	for actor in actors:
		actor.visible = false
		actor.collider.collision_layer = 0
		actor.head_yaw = 0.0
		actor.reply_cooldown = 0.0
		actor.look.active = false
		if actor.animator != null:actor.animator.speed_scale = 0.0

func _physics_process(_delta: float) -> void:
	if not active or not grounding_pending:return
	grounding_pending = false
	var exclude: Array[RID] = [game.player.get_rid()]
	for actor in actors:exclude.append(actor.collider.get_rid())
	for actor in actors:
		var at := actor.global_position
		var query := PhysicsRayQueryParameters3D.create(at+Vector3(0,.45,0), at-Vector3(0,.65,0), 1, exclude)
		var support := get_world_3d().direct_space_state.intersect_ray(query)
		actor.grounded = not support.is_empty() and support.normal.dot(Vector3.UP)>.9 and absf(support.position.y-town.global_position.y)<.25
		if actor.grounded:actor.global_position.y = support.position.y+.004
		else:push_warning("街坊站位未找到安全地面："+String(actor.definition.id))
		actor.visible = actor.ready_model and actor.grounded
		actor.collider.collision_layer = 1 if actor.visible else 0
		actor.look.active = actor.visible

func _can_act() -> bool:
	return active and town.active and game.state == "prologue" and game.prologue_stage == "town" and not game.bag_open and not game.phone_open and not game.nb_open and game.choice == null and not game.sub_pause

func _process(delta: float) -> void:
	var running := _can_act()
	for actor in actors:
		if actor.animator == null:continue
		actor.animator.speed_scale = 1.0 if running and actor.visible else 0.0
		if not running or not actor.visible:continue
		actor.reply_cooldown = maxf(0.0, actor.reply_cooldown-delta)
		var to_player: Vector3 = game.player.global_position-actor.global_position
		to_player.y = 0.0
		var target := 0.0
		if to_player.length() > .1 and to_player.length() < 3.5:
			var angle := angle_difference(actor.home_yaw, atan2(to_player.x, to_player.z))
			if absf(angle)<PI*.45:target = clampf(angle, -.25, .25)
		actor.head_yaw = lerpf(actor.head_yaw, target, minf(1.0, delta*3.0))

func interaction_candidates() -> Array:
	var result: Array = []
	if not _can_act() or game.sub != "" or not game.sub_queue.is_empty():return result
	if game.audio_system != null and game.audio_system.is_busy():return result
	for actor in actors:
		if actor.visible and actor.ready_model and actor.grounded and actor.reply_cooldown<=0.0:
			result.append({"kind":"town", "id":String(actor.definition.id), "text":String(actor.definition.prompt), "pos":actor.global_position+Vector3(0,1.35,0), "reach":2.8, "radius":.42})
	return result

func interact(id: String) -> bool:
	for actor in actors:
		if id != String(actor.definition.id):continue
		if not _can_act() or not actor.visible or actor.reply_cooldown>0.0:return true
		var selected: Variant = game.focus.select_target()
		if selected == null or selected.get("id", "") != id:return true
		# Ambient replies must not replace plot narration, a phone call, or a queued
		# story line. They introduce no parallel modal session or save return state.
		if game.sub != "" or not game.sub_queue.is_empty():return true
		if game.audio_system != null and game.audio_system.is_busy():return true
		var resting := game.laundry != null and game.laundry.campaign != null and bool(game.laundry.campaign.progress.rest_pending)
		var text := String(actor.definition.return_line if resting else actor.definition.line)
		actor.reply_cooldown = 4.0
		game._say_seq(String(actor.definition.label), text, 2.2, false)
		return true
	return false
