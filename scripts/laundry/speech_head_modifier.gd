extends SkeletonModifier3D
## Additive head motion runs after animation; pelvis/arms/seat alignment stay owned by clips.
var driver:Node
var head:=-1
func _process_modification() -> void:
	if not is_instance_valid(driver):return
	var sk=get_skeleton()
	if sk==null:return
	if head<0:head=sk.find_bone("mixamorig_Head")
	if head<0:return
	var base=sk.get_bone_pose_rotation(head)
	sk.set_bone_pose_rotation(head,base*Quaternion(Vector3.RIGHT,driver.nod)*Quaternion(Vector3.FORWARD,driver.tilt))
