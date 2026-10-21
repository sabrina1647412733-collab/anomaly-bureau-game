"""沿用交付骨架，修复蹲姿双脚互穿；原始交付不变。Blender --python ... -- input.blend output"""
import bpy,sys,os,math
from pathlib import Path
from mathutils import Vector,Matrix
sys.path.insert(0,os.path.dirname(__file__))
from delivery_glb_writer import write_clip_glb
source,out=sys.argv[sys.argv.index('--')+1:]
os.makedirs(out,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=source,load_ui=False,use_scripts=False)
arm=next(o for o in bpy.data.objects if o.type=='ARMATURE')
mesh=next(o for o in bpy.data.objects if o.type=='MESH' and any(m.type=='ARMATURE' and m.object==arm for m in o.modifiers))
for track in arm.animation_data.nla_tracks:track.mute=True
P='mixamorig:'
left=(arm.data.bones[P+'LeftUpLeg'].head_local-arm.data.bones[P+'RightUpLeg'].head_local).normalized()
up=(arm.data.bones[P+'Head'].head_local-arm.data.bones[P+'Hips'].head_local).normalized()
forward=left.cross(up).normalized()
def rotate_thigh(pb,original,angle):
    center=original.translation
    pb.matrix=Matrix.Translation(center)@Matrix.Rotation(angle,4,forward)@Matrix.Translation(-center)@original
    bpy.context.view_layer.update()
for name in ['JumpStart','JumpLoop','JumpLand','CrouchDown','CrouchIdle','CrouchWalk','CrouchUp']:
    action=bpy.data.actions[name];arm.animation_data.action=action
    if len(action.slots):arm.animation_data.action_slot=action.slots[0]
    end=int(action.frame_range[1]);originals=[]
    for f in range(end+1):
        bpy.context.scene.frame_set(f);bpy.context.view_layer.update()
        originals.append({p.name:p.matrix_basis.copy() for p in arm.pose.bones})
    if name.startswith(('Crouch','Jump')):
        for f in range(end+1):
            bpy.context.scene.frame_set(f)
            for pb in arm.pose.bones:pb.matrix_basis=originals[f][pb.name]
            bpy.context.view_layer.update()
            t=f/end
            weight=t*t*(3-2*t) if name=='CrouchDown' else ((1-t)*(1-t)*(1+2*t) if name=='CrouchUp' else 1)
            hips=arm.pose.bones[P+'Hips']
            for side,sign in [('Left',1),('Right',-1)]:
                thigh=arm.pose.bones[P+side+'UpLeg'];foot=arm.pose.bones[P+side+'Foot']
                matrix=thigh.matrix.copy();orientation=foot.matrix.to_quaternion()
                current=(foot.head-hips.head).dot(left)
                target=current*(1-weight)+sign*.145*weight
                if name.startswith('Jump'):target=sign*max(sign*current,.145)
                rotate_thigh(thigh,matrix,.01)
                derivative=((foot.head-hips.head).dot(left)-current)/.01
                angle=max(-.45,min(.45,(target-current)/derivative)) if abs(derivative)>.00001 else 0
                rotate_thigh(thigh,matrix,angle)
                new_head=foot.head.copy()
                foot.matrix=Matrix.LocRotScale(new_head,orientation,Vector((1,1,1)))
                bpy.context.view_layer.update()
            ev=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get());me=ev.to_mesh()
            low=min((ev.matrix_world@v.co).z for v in me.vertices);ev.to_mesh_clear()
            # 所有着地动作保持地面，不能通过抬高整个人来隐藏互穿。
            delta=arm.matrix_world.to_3x3().inverted()@Vector((0,0,-.032-low))
            if name.startswith('Crouch'):hips.location+=arm.data.bones[P+'Hips'].matrix_local.to_3x3().inverted()@delta
            bpy.context.view_layer.update()
            for pb in arm.pose.bones:
                pb.rotation_mode='QUATERNION'
                pb.keyframe_insert('rotation_quaternion',frame=f,group=pb.name)
                pb.keyframe_insert('location',frame=f,group=pb.name)
    write_clip_glb(arm,action,end,name,os.path.join(out,name+'.glb'),loop=name in ['JumpLoop','CrouchIdle','CrouchWalk'])
arm.animation_data.action=bpy.data.actions['CrouchIdle']
bpy.context.scene.frame_set(0)
bpy.ops.wm.save_as_mainfile(filepath=str(Path(__file__).resolve().parents[2]/'source_art'/'xuyan_motion_repaired.blend'))
print('REFINED_MOTION',out)
