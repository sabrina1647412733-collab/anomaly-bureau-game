"""Blender CLI: original rig/mesh retained; author a contact-safe seated loop.
blender -b --python ... -- character.glb output_dir prefix
The generated clip only contains this character's own skeleton animation.
"""
import bpy,sys,math,json
from pathlib import Path
from mathutils import Vector,Matrix
sys.path.insert(0,str(Path(__file__).resolve().parent))
from delivery_glb_writer import write_clip_glb
from delivery_glb_writer import C,C_INV
source,out,prefix=sys.argv[sys.argv.index('--')+1:];out=Path(out);out.mkdir(exist_ok=True,parents=True)
bpy.ops.wm.read_factory_settings(use_empty=True);bpy.ops.import_scene.gltf(filepath=source)
arm=next(o for o in bpy.data.objects if o.type=='ARMATURE');P='mixamorig:'
for tr in arm.animation_data.nla_tracks:tr.mute=True
idle=next(a for a in bpy.data.actions if a.name=='Idle')
arm.animation_data.action=idle
if idle.slots:arm.animation_data.action_slot=idle.slots[0]
bpy.context.scene.frame_set(0);bpy.context.view_layer.update()
base={b.name:b.matrix_basis.copy() for b in arm.pose.bones}
arm.animation_data.action=None
action=bpy.data.actions.new(prefix+'_Seated');arm.animation_data.action=action
inv=arm.matrix_world.inverted()
deformations={'bones':[b.name.replace(':','_') for b in arm.pose.bones],'clips':{}}
def capture(act,name,end,fps):
    arm.animation_data.action=act
    if act.slots:arm.animation_data.action_slot=act.slots[0]
    data=[]
    for f in range(end+1):
        bpy.context.scene.frame_set(f);bpy.context.view_layer.update();frame=[]
        for b in arm.pose.bones:
            # A mesh-space deformation survives Blender/Godot bone-axis conventions.
            m=C@arm.matrix_world@b.matrix@b.bone.matrix_local.inverted()@inv@C_INV
            frame.append([round(m[row][col],7) for col in range(4) for row in range(3)])
        data.append(frame)
    deformations['clips'][name]={'fps':fps,'frames':data}
def head(name):return arm.matrix_world@arm.pose.bones[P+name].head
def aim(name,target):
    b=arm.pose.bones[P+name];m=arm.matrix_world@b.matrix
    following=name.replace('UpLeg','Leg') if name.endswith('UpLeg') else (name.replace('ForeArm','Hand') if name.endswith('ForeArm') else (name.replace('Arm','ForeArm') if name.endswith('Arm') else name.replace('Leg','Foot')))
    current=head(following)-m.translation
    rot=current.rotation_difference(Vector(target)-m.translation).to_matrix().to_4x4()
    b.matrix=inv@Matrix.Translation(m.translation)@rot@Matrix.Translation(-m.translation)@m
    bpy.context.view_layer.update()
def leg(side):
    hip=head(side+'UpLeg');ankle=Vector((.12 if side=='Left' else -.12,-.25,.107))
    upper=arm.pose.bones[P+side+'UpLeg'];lower=arm.pose.bones[P+side+'Leg']
    l1=(head(side+'Leg')-hip).length;l2=(head(side+'Foot')-head(side+'Leg')).length
    d=(ankle-hip).length;axis=(ankle-hip).normalized();a=(l1*l1-l2*l2+d*d)/(2*d)
    pole=Vector((0,-1,0));pole=(pole-axis*pole.dot(axis)).normalized()
    knee=hip+axis*a+pole*math.sqrt(max(0,l1*l1-a*a))
    foot_matrix=arm.matrix_world@arm.pose.bones[P+side+'Foot'].matrix
    foot_orientation=foot_matrix.to_quaternion()
    aim(side+'UpLeg',knee);aim(side+'Leg',ankle)
    foot=arm.pose.bones[P+side+'Foot'];p=arm.matrix_world@foot.matrix
    foot.matrix=inv@Matrix.LocRotScale(p.translation,foot_orientation,foot_matrix.to_scale())
    bpy.context.view_layer.update()
frames=120;facts=[]
for f in range(frames+1):
    bpy.context.scene.frame_set(f)
    for b in arm.pose.bones:b.matrix_basis=base[b.name]
    bpy.context.view_layer.update()
    hips=arm.pose.bones[P+'Hips'];m=arm.matrix_world@hips.matrix
    # Hip joint above the 0.49m seat; centred in X, small backward body offset.
    m.translation=Vector((0,.15,.625));hips.matrix=inv@m;bpy.context.view_layer.update()
    for side,sign in [('Left',1),('Right',-1)]:
        leg(side)
        aim(side+'Arm',Vector((sign*.205,-.015,.85)))
        aim(side+'ForeArm',Vector((sign*.135,-.22,.66)))
    # Small thoracic breathing, zero root travel and stable feet across the loop seam.
    spine=arm.pose.bones[P+'Spine2'];spine.rotation_mode='QUATERNION'
    spine.rotation_quaternion.rotate(__import__('mathutils').Quaternion((1,0,0),.004*math.sin(f/frames*math.tau)))
    for b in arm.pose.bones:
        b.rotation_mode='QUATERNION';b.keyframe_insert('rotation_quaternion',frame=f,group=b.name);b.keyframe_insert('location',frame=f,group=b.name)
    if f%30==0:facts.append({'frame':f,'bones':{n:list(head(n)) for n in ['Hips','LeftHand','RightHand','LeftFoot','RightFoot','LeftLeg','RightLeg']}})
capture(action,'SitIdle',frames,30)
(out/(prefix+'_seated_audit.json')).write_text(json.dumps(facts,indent=2),encoding='utf8')
# Repair arm direction in the supplied standing/walking clips, keeping their body and leg motion.
originals=[a for a in bpy.data.actions if a.name in ['Idle','Walk','LookDown','OpenDoor','CloseDoor','StandUp']]
for original in originals:
    arm.animation_data.action=original
    if original.slots:arm.animation_data.action_slot=original.slots[0]
    end=int(original.frame_range[1]);samples=[]
    for f in range(end+1):
        bpy.context.scene.frame_set(f);bpy.context.view_layer.update()
        samples.append({b.name:b.matrix_basis.copy() for b in arm.pose.bones})
    fixed=bpy.data.actions.new(original.name+'_finish');arm.animation_data.action=fixed
    for f in range(end+1):
        bpy.context.scene.frame_set(f)
        for b in arm.pose.bones:b.matrix_basis=samples[f][b.name]
        bpy.context.view_layer.update()
        hip=head('Hips')
        for side,sign in [('Left',1),('Right',-1)]:
            shoulder=head(side+'Arm');swing=.10*math.sin(f/max(end,1)*math.tau)*sign if original.name=='Walk' else .009*math.sin(f/max(end,1)*math.tau)
            aim(side+'Arm',Vector((shoulder.x+sign*.065,hip.y-.045+swing,shoulder.z-.21)))
            aim(side+'ForeArm',Vector((shoulder.x+sign*.065,hip.y-.10+swing,shoulder.z-.43)))
        for b in arm.pose.bones:
            b.rotation_mode='QUATERNION';b.keyframe_insert('rotation_quaternion',frame=f,group=b.name);b.keyframe_insert('location',frame=f,group=b.name)
    capture(fixed,original.name,end,24)
(out/(prefix+'_deform.json')).write_text(json.dumps(deformations,separators=(',',':')),encoding='utf8')
for obj in list(bpy.data.objects):
    if obj!=arm:bpy.data.objects.remove(obj,do_unlink=True)
for image in list(bpy.data.images):bpy.data.images.remove(image)
for act in bpy.data.actions:act.use_fake_user=True
arm['source_model']=Path(source).name
bpy.ops.wm.save_as_mainfile(filepath=str(out/(prefix+'_seated.blend')),compress=True)
print('SEATED_REFINED',prefix)
