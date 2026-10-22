"""Sample delivered motion in mesh space; preserve Blender source and original GLBs.
Blender --background --python this.py -- source.blend output.json
"""
import bpy, json, sys
from pathlib import Path
from mathutils import Matrix

source, output = sys.argv[sys.argv.index('--') + 1:]
bpy.ops.wm.open_mainfile(filepath=source, load_ui=False, use_scripts=False)
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
for track in arm.animation_data.nla_tracks:
    track.mute = True
C = Matrix(((1,0,0,0),(0,0,1,0),(0,-1,0,0),(0,0,0,1)))
inv = arm.matrix_world.inverted()
data = {'bones':[b.name.replace(':','_') for b in arm.pose.bones], 'clips':{}}
for name in ['JumpStart','JumpLoop','JumpLand','CrouchDown','CrouchIdle','CrouchWalk','CrouchUp']:
    action = bpy.data.actions[name]
    arm.animation_data.action = action
    if len(action.slots):
        arm.animation_data.action_slot = action.slots[0]
    frames = []
    for f in range(int(action.frame_range[1])+1):
        bpy.context.scene.frame_set(f)
        bpy.context.view_layer.update()
        row = []
        for b in arm.pose.bones:
            m = C @ arm.matrix_world @ b.matrix @ b.bone.matrix_local.inverted() @ inv @ C.inverted()
            row.append([m[r][c] for c in range(3) for r in range(3)] + list(m.translation))
        frames.append(row)
    data['clips'][name] = {'fps':30,'frames':frames}
Path(output).write_text(json.dumps(data,separators=(',',':')),encoding='utf8')
print('XUYAN_DEFORM_EXPORTED', output)
