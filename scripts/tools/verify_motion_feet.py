"""Blender后台验收修复动作逐帧鞋面互穿。输入.blend，输出.json。"""
import bpy,json,sys
from mathutils.bvhtree import BVHTree
source,output=sys.argv[sys.argv.index('--')+1:]
bpy.ops.wm.open_mainfile(filepath=source,load_ui=False,use_scripts=False)
arm=next(o for o in bpy.data.objects if o.type=='ARMATURE')
mesh=next(o for o in bpy.data.objects if o.type=='MESH' and any(m.type=='ARMATURE' and m.object==arm for m in o.modifiers))
for tr in arm.animation_data.nla_tracks:tr.mute=True
def foot_faces(side):
    ids={mesh.vertex_groups[n].index for n in ['mixamorig:'+side+'Foot','mixamorig:'+side+'ToeBase'] if n in mesh.vertex_groups}
    verts={v.index for v in mesh.data.vertices if sum(g.weight for g in v.groups if g.group in ids)>.5}
    return [list(p.vertices) for p in mesh.data.polygons if all(v in verts for v in p.vertices)]
left,right=foot_faces('Left'),foot_faces('Right');results={}
for name in ['JumpStart','JumpLoop','JumpLand','CrouchDown','CrouchIdle','CrouchWalk','CrouchUp']:
    action=bpy.data.actions[name];arm.animation_data.action=action
    if len(action.slots):arm.animation_data.action_slot=action.slots[0]
    bad=[];frames=range(int(action.frame_range[0]),int(action.frame_range[1])+1)
    for frame in frames:
        bpy.context.scene.frame_set(frame);bpy.context.view_layer.update()
        ev=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get());me=ev.to_mesh()
        points=[ev.matrix_world@v.co for v in me.vertices]
        if BVHTree.FromPolygons(points,left).overlap(BVHTree.FromPolygons(points,right)):bad.append(frame)
        ev.to_mesh_clear()
    results[name]={'frames':len(frames),'intersecting_frames':bad}
with open(output,'w',encoding='utf-8') as f:json.dump(results,f,indent=2)
print('MOTION_FEET_QA',json.dumps(results))
