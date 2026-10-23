"""Preserve two user GLBs and add a foot-locked, independent standing loop.

Asset preparation is a raw GLB append: original mesh/skin/textures and original
Walking/Running animation accessors keep their original binary bytes. Torso uses
the existing Xu Yan Idle world-space bind deformation; arms/fingers are posed
from each target's own bone axes. Legs/root keep the target's own planted bind
pose; small periodic chest/shoulder rotations form a 4-second Idle.

Normal Python needs numpy. Blender's background Python includes numpy and also
supports --blender-review to save the editable .blend and offline pose renders.
No editor, desktop, sound playback or game process is opened by this script.
"""
from __future__ import annotations
import argparse
import copy
import hashlib
import json
import math
from pathlib import Path
import struct
import sys

try:
    import numpy as np
except ModuleNotFoundError:
    # Author's existing F-drive helper runtime; portable environments use numpy.
    sys.path.insert(0, r'F:\诡异事务局\_tools\street_python')
    import numpy as np

ROOT = Path(__file__).resolve().parents[2]
AUDIT = Path(r'F:\诡异事务局\验收\20261023_NPC后台接入')
DT = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16,
      5125: np.uint32, 5126: np.float32}
WIDTH = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}


def quat_matrix(q):
    x, y, z, w = np.asarray(q, dtype=float) / np.linalg.norm(q)
    return np.array(((1-2*(y*y+z*z), 2*(x*y-z*w), 2*(x*z+y*w)),
                     (2*(x*y+z*w), 1-2*(x*x+z*z), 2*(y*z-x*w)),
                     (2*(x*z-y*w), 2*(y*z+x*w), 1-2*(x*x+y*y))))


def matrix_quat(m):
    # Stable branch algorithm, glTF order x,y,z,w.
    m = np.asarray(m, dtype=float)
    tr = float(np.trace(m))
    if tr > 0:
        s = math.sqrt(tr+1.0)*2
        q = ((m[2,1]-m[1,2])/s, (m[0,2]-m[2,0])/s,
             (m[1,0]-m[0,1])/s, .25*s)
    else:
        i = int(np.argmax(np.diag(m)))
        if i == 0:
            s = math.sqrt(1+m[0,0]-m[1,1]-m[2,2])*2
            q = (.25*s, (m[0,1]+m[1,0])/s, (m[0,2]+m[2,0])/s,
                 (m[2,1]-m[1,2])/s)
        elif i == 1:
            s = math.sqrt(1+m[1,1]-m[0,0]-m[2,2])*2
            q = ((m[0,1]+m[1,0])/s, .25*s, (m[1,2]+m[2,1])/s,
                 (m[0,2]-m[2,0])/s)
        else:
            s = math.sqrt(1+m[2,2]-m[0,0]-m[1,1])*2
            q = ((m[0,2]+m[2,0])/s, (m[1,2]+m[2,1])/s, .25*s,
                 (m[1,0]-m[0,1])/s)
    q = np.array(q)
    return q/np.linalg.norm(q)


def axis_rotation(axis, angle):
    axis = np.asarray(axis, dtype=float)
    axis /= np.linalg.norm(axis)
    return quat_matrix([*(axis*math.sin(angle*.5)), math.cos(angle*.5)])


def align_direction(original, desired):
    a=np.asarray(original,dtype=float);a/=np.linalg.norm(a)
    b=np.asarray(desired,dtype=float);b/=np.linalg.norm(b)
    axis=np.cross(a,b);length=np.linalg.norm(axis)
    if length<1e-9:return np.eye(3)
    return axis_rotation(axis,math.atan2(length,float(np.dot(a,b))))


def node_matrix(node):
    if 'matrix' in node:
        return np.array(node['matrix'], dtype=float).reshape(4,4).T
    out = np.eye(4)
    out[:3,:3] = quat_matrix(node.get('rotation', [0,0,0,1])) @ np.diag(node.get('scale', [1,1,1]))
    out[:3,3] = node.get('translation', [0,0,0])
    return out


class GLB:
    def __init__(self, path):
        self.path = Path(path)
        self.original = self.path.read_bytes()
        magic, version, size = struct.unpack_from('<4sII', self.original)
        assert (magic, version, size) == (b'glTF', 2, len(self.original))
        chunks = {}; offset = 12
        while offset < size:
            length, kind = struct.unpack_from('<II', self.original, offset)
            offset += 8; chunks[kind] = self.original[offset:offset+length]; offset += length
        self.doc = json.loads(chunks[0x4e4f534a])
        self.binary = bytearray(chunks.get(0x004e4942, b''))
        self.original_binary = bytes(self.binary)
        self.parents = {child:i for i,n in enumerate(self.doc.get('nodes',[])) for child in n.get('children',[])}
        self.names = {n.get('name',''):i for i,n in enumerate(self.doc.get('nodes',[]))}
        self.local = {i:node_matrix(n) for i,n in enumerate(self.doc.get('nodes',[]))}
        self.world = self.world_matrices(self.local)

    def accessor(self, index):
        a = self.doc['accessors'][index]
        dtype = np.dtype(DT[a['componentType']]).newbyteorder('<'); width = WIDTH[a['type']]
        view = self.doc['bufferViews'][a['bufferView']]
        out = np.ndarray((a['count'],width), dtype=dtype, buffer=self.binary,
            offset=view.get('byteOffset',0)+a.get('byteOffset',0),
            strides=(view.get('byteStride',width*dtype.itemsize),dtype.itemsize)).copy()
        if a.get('normalized') and a['componentType'] != 5126:
            info = np.iinfo(dtype); out = out.astype(float)/info.max
            if info.min < 0: out = np.maximum(out,-1)
        return out

    def world_matrices(self, locals_):
        worlds = {}
        def get(i):
            if i not in worlds:
                worlds[i] = (get(self.parents[i]) if i in self.parents else np.eye(4)) @ locals_[i]
            return worlds[i]
        for i in locals_: get(i)
        return worlds

    def bind_matrices(self):
        skin = self.doc['skins'][0]
        inv = self.accessor(skin['inverseBindMatrices']).reshape(-1,4,4).transpose(0,2,1)
        return {node:np.linalg.inv(mat) for node,mat in zip(skin['joints'],inv)}

    def first_animation_world(self):
        """Existing Idle's first standing pose, evaluated against its node axes."""
        loc = {i:mat.copy() for i,mat in self.local.items()}
        properties = {i:copy.deepcopy(n) for i,n in enumerate(self.doc['nodes'])}
        animation = self.doc['animations'][0]
        for channel in animation['channels']:
            sampler = animation['samplers'][channel['sampler']]
            value = self.accessor(sampler['output'])[1 if sampler.get('interpolation')=='CUBICSPLINE' else 0]
            properties[channel['target']['node']][channel['target']['path']] = value.tolist()
        return self.world_matrices({i:node_matrix(n) for i,n in properties.items()})

    def add_accessor(self, array, type_):
        values = np.asarray(array, dtype='<f4')
        while len(self.binary)%4: self.binary.append(0)
        offset = len(self.binary); raw = values.tobytes(); self.binary.extend(raw)
        view = len(self.doc.setdefault('bufferViews',[]))
        self.doc['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':len(raw)})
        index = len(self.doc.setdefault('accessors',[]))
        a = {'bufferView':view,'componentType':5126,'count':len(values),'type':type_}
        if type_=='SCALAR': a.update(min=[float(values.min())],max=[float(values.max())])
        self.doc['accessors'].append(a)
        return index

    def write(self,path):
        assert bytes(self.binary[:len(self.original_binary)]) == self.original_binary
        self.doc['buffers'][0]['byteLength'] = len(self.binary)
        text = json.dumps(self.doc, separators=(',',':'),ensure_ascii=False).encode('utf8')
        text += b' '*((-len(text))%4)
        body = bytes(self.binary)+b'\0'*((-len(self.binary))%4)
        output = struct.pack('<4sII',b'glTF',2,12+8+len(text)+8+len(body))
        output += struct.pack('<II',len(text),0x4e4f534a)+text
        output += struct.pack('<II',len(body),0x004e4942)+body
        Path(path).write_bytes(output)


def prepare_asset(input_path, output_path, source_bind, source_idle):
    target = GLB(input_path)
    original_anims = copy.deepcopy(target.doc.get('animations',[]))
    joints = target.doc['skins'][0]['joints']
    bind = target.bind_matrices(); s_bind = source_bind.bind_matrices()
    source_pose = source_idle.first_animation_world()
    src_hips = source_bind.names['mixamorig:Hips']
    idle_hips = source_idle.names['mixamorig:Hips']
    hips_deform = source_pose[idle_hips][:3,:3] @ s_bind[src_hips][:3,:3].T
    baseline_world = {}; baseline_local = {}
    legs = ('UpLeg','Leg','Foot','Toe')
    order = sorted(joints, key=lambda i: depth(target,i))
    hip_id = target.names['mixamorig:Hips']
    for node in order:
        name = target.doc['nodes'][node]['name']
        parent = target.parents.get(node)
        if node == hip_id or any(part in name for part in legs):
            rotation = bind[node][:3,:3]
        elif name.endswith(('LeftShoulder','RightShoulder')):
            # Lower the clavicle slightly so T-pose jacket shoulders do not shrug.
            side=1 if 'Left' in name else -1
            rotation=axis_rotation([0,0,1],math.radians(-side*10))@bind[node][:3,:3]
        elif name.endswith(('LeftArm','RightArm','LeftForeArm','RightForeArm')):
            side=1 if 'Left' in name else -1
            forearm='ForeArm' in name
            child_name=name.replace('ForeArm','Hand') if forearm else name.replace('Arm','ForeArm')
            original=bind[target.names[child_name]][:3,3]-bind[node][:3,3]
            # Own bone lengths/axes, modest lateral clearance, softly bent elbow.
            desired=np.array([side*(.08 if forearm else .16),-.97,.20 if forearm else .04])
            rotation=align_direction(original,desired)@bind[node][:3,:3]
        elif name.endswith(('LeftHand','RightHand')):
            rotation=baseline_world[parent]@bind[parent][:3,:3].T@bind[node][:3,:3]
        elif 'Hand' in name and name[-1:].isdigit():
            rotation=baseline_world[parent]@bind[parent][:3,:3].T@bind[node][:3,:3]
            digit=int(name[-1]);angle={1:12,2:22,3:12}.get(digit,0)
            if 'Thumb' in name:angle*=.50
            if angle:
                hand=target.names['mixamorig:'+('LeftHand' if 'Left' in name else 'RightHand')]
                hand_deform=baseline_world[hand]@bind[hand][:3,:3].T
                palm_normal=hand_deform@np.array([0,-1,0])
                child=next((c for c in target.doc['nodes'][node].get('children',[]) if c in bind),None)
                if child is not None:
                    current_axis=(rotation@bind[node][:3,:3].T)@(bind[child][:3,3]-bind[node][:3,3])
                    curl_axis=np.cross(current_axis,palm_normal)
                    if np.linalg.norm(curl_axis)>1e-5:rotation=axis_rotation(curl_axis,math.radians(angle))@rotation
        elif name in source_bind.names and name in source_idle.names:
            sb = s_bind[source_bind.names[name]][:3,:3]
            sp = source_pose[source_idle.names[name]][:3,:3]
            rotation = hips_deform.T @ sp @ sb.T @ bind[node][:3,:3]
        elif parent in bind:
            rotation = baseline_world[parent] @ bind[parent][:3,:3].T @ bind[node][:3,:3]
        else:
            rotation = bind[node][:3,:3]
        baseline_world[node] = rotation
        p_rotation = baseline_world[parent] if parent in baseline_world else target.world[parent][:3,:3] if parent is not None else np.eye(3)
        baseline_local[node] = p_rotation.T @ rotation
    samples = 121
    tracks = {i:[] for i in joints}
    for frame in range(samples):
        phase = 2*math.pi*frame/(samples-1)
        for node in joints:
            name = target.doc['nodes'][node]['name']
            local = baseline_local[node].copy()
            amplitude = {'mixamorig:Spine':.16,'mixamorig:Spine1':.18,'mixamorig:Spine2':.14,
                         'mixamorig:LeftShoulder':.10,'mixamorig:RightShoulder':-.10,
                         'mixamorig:Head':.18}.get(name,0)
            if amplitude:
                axis = np.array([0,1,0]) if name.endswith('Head') else np.array([0,0,1]) if name.endswith('Shoulder') else np.array([1,0,0])
                axis = baseline_world[node].T @ axis
                motion = math.sin(phase) if not name.endswith('Head') else math.sin(phase)*.7+math.sin(phase*2)*.3
                local = local @ axis_rotation(axis,math.radians(amplitude)*motion)
            q = matrix_quat(local)
            if tracks[node] and np.dot(q,tracks[node][-1]) < 0: q = -q
            tracks[node].append(q)
    times = target.add_accessor(np.linspace(0,4,samples).reshape(-1,1),'SCALAR')
    animation = {'name':'Idle','samplers':[],'channels':[],
                 'extras':{'loop':True,'source':'Own bone-axis standing arms and relaxed fingers; existing torso Idle world bind deformation; legs/root locked; independent breathing loop'}}
    for node in joints:
        out = target.add_accessor(tracks[node],'VEC4')
        animation['samplers'].append({'input':times,'output':out,'interpolation':'LINEAR'})
        animation['channels'].append({'sampler':len(animation['samplers'])-1,'target':{'node':node,'path':'rotation'}})
    target.doc.setdefault('animations',[]).append(animation)
    target.doc.setdefault('extras',{})['street_resident_preparation'] = {
        'version':1,'units':'meters','up':'+Y','forward':'+Z','height':1.7,
        'source_file':Path(input_path).name,'source_sha256':hashlib.sha256(target.original).hexdigest(),
        'preserved_animations':[a.get('name') for a in original_anims],
        'standing':'Own planted legs, bone-axis lowered arms/soft elbows/relaxed fingers, four-second subtle breathing'}
    assert target.doc['animations'][:-1] == original_anims
    Path(output_path).parent.mkdir(parents=True,exist_ok=True)
    target.write(output_path)
    # Evaluate added tracks in raw glTF space to measure actual skinned shoe vertices.
    skin = target.doc['skins'][0]; inverse = target.accessor(skin['inverseBindMatrices']).reshape(-1,4,4).transpose(0,2,1)
    mesh_node = next(i for i,n in enumerate(target.doc['nodes']) if n.get('skin')==0)
    prim = target.doc['meshes'][target.doc['nodes'][mesh_node]['mesh']]['primitives'][0]
    positions = target.accessor(prim['attributes']['POSITION']); indices = target.accessor(prim['attributes']['JOINTS_0']).astype(int)
    weights = target.accessor(prim['attributes']['WEIGHTS_0']); homogeneous = np.c_[positions,np.ones(len(positions))]
    shoe = positions[:,1] < .22
    left = shoe & (positions[:,0]>0); right = shoe & (positions[:,0]<0)
    frames = []
    for frame in (0,15,30,45,60,75,90,105,120):
        locals_ = {i:m.copy() for i,m in target.local.items()}
        for node in joints:
            locals_[node][:3,:3] = quat_matrix(tracks[node][frame]) @ np.diag(target.doc['nodes'][node].get('scale',[1,1,1]))
        world = target.world_matrices(locals_)
        skinmats = np.array([world[node]@ib for node,ib in zip(joints,inverse)])
        transformed = np.einsum('vwij,vj->vwi',skinmats[indices],homogeneous)
        deformed = (transformed * weights[:,:,None]).sum(axis=1)[:,:3]
        frames.append({'frame':frame,'time':frame/30,'min':deformed.min(axis=0).tolist(),'max':deformed.max(axis=0).tolist(),
                       'left_shoe_min_y':float(deformed[left,1].min()),'right_shoe_min_y':float(deformed[right,1].min()),
                       'hips':world[hip_id][:3,3].tolist(),
                       'hands':{side:world[target.names['mixamorig:'+side+'Hand']][:3,3].tolist() for side in ('Left','Right')}})
    first = np.array([tracks[n][0] for n in joints]);last=np.array([tracks[n][-1] for n in joints])
    report = {'file':str(output_path),'source_file':str(input_path),'source_sha256':hashlib.sha256(target.original).hexdigest(),
              'output_sha256':hashlib.sha256(Path(output_path).read_bytes()).hexdigest(),
              'original_binary_prefix_preserved':True,'original_animations_preserved':True,
              'clips': [a.get('name') for a in target.doc['animations']], 'idle_seconds':4,
              'unit':'meter','up':'+Y','forward':'+Z',
              'idle_seam_max_quaternion_component_error':float(np.abs(first-last).max()),'sampled_frames':frames,
              'method':'Own bone-axis lowered arms/soft elbows/relaxed fingers; existing Idle torso world bind deformation; own bind legs/root; periodic chest/shoulder/head rotations'}
    report['original_motion_samples']=sample_original_motion(target)
    return report


def sample_original_motion(target):
    skin=target.doc['skins'][0];joints=skin['joints']
    inverse=target.accessor(skin['inverseBindMatrices']).reshape(-1,4,4).transpose(0,2,1)
    mesh_node=next(i for i,n in enumerate(target.doc['nodes']) if n.get('skin')==0)
    primitive=target.doc['meshes'][target.doc['nodes'][mesh_node]['mesh']]['primitives'][0]
    p=target.accessor(primitive['attributes']['POSITION']);homogeneous=np.c_[p,np.ones(len(p))]
    indices=target.accessor(primitive['attributes']['JOINTS_0']).astype(int)
    weights=target.accessor(primitive['attributes']['WEIGHTS_0'])
    result=[]
    for animation in target.doc['animations']:
        if animation.get('name')=='Idle':continue
        samplers=[]
        for sampler in animation['samplers']:
            assert sampler.get('interpolation','LINEAR')=='LINEAR'
            samplers.append((target.accessor(sampler['input']).flatten(),target.accessor(sampler['output'])))
        duration=max(float(t.max()) for t,v in samplers)
        rows=[]
        for time in np.linspace(0,duration,33):
            props={i:copy.deepcopy(n) for i,n in enumerate(target.doc['nodes'])}
            for channel in animation['channels']:
                times,values=samplers[channel['sampler']]
                after=min(len(times)-1,int(np.searchsorted(times,time,side='right')));before=max(0,after-1)
                amount=float(np.clip((time-times[before])/(times[after]-times[before]),0,1)) if after!=before else 0
                a=values[before].copy();b=values[after].copy();path=channel['target']['path']
                if path=='rotation' and np.dot(a,b)<0:b=-b
                value=a*(1-amount)+b*amount
                if path=='rotation':value/=np.linalg.norm(value)
                props[channel['target']['node']][path]=value.tolist()
            world=target.world_matrices({i:node_matrix(n) for i,n in props.items()})
            matrices=np.array([world[node]@ib for node,ib in zip(joints,inverse)])
            transformed=np.einsum('vwij,vj->vwi',matrices[indices],homogeneous)
            deformed=(transformed*weights[:,:,None]).sum(axis=1)[:,:3]
            rows.append({'time':float(time),'minimum_y':float(deformed[:,1].min()),
                         'height':float(np.ptp(deformed[:,1])),
                         'hips':world[target.names['mixamorig:Hips']][:3,3].tolist(),
                         'left_foot':world[target.names['mixamorig:LeftFoot']][:3,3].tolist(),
                         'right_foot':world[target.names['mixamorig:RightFoot']][:3,3].tolist()})
        result.append({'name':animation.get('name'),'duration':duration,'sample_count':len(rows),
                       'minimum_y_range':[min(r['minimum_y'] for r in rows),max(r['minimum_y'] for r in rows)],
                       'height_range':[min(r['height'] for r in rows),max(r['height'] for r in rows)],
                       'samples':rows})
    return result


def depth(asset,index):
    result=0
    while index in asset.parents: result+=1;index=asset.parents[index]
    return result


def main():
    args = sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else sys.argv[1:]
    parser=argparse.ArgumentParser()
    parser.add_argument('--input-dir',default=r'F:\角色3d模型\npc\3d')
    parser.add_argument('--output-dir',default=str(ROOT/'assets/models/chars/street_residents'))
    parser.add_argument('--review-dir',default=str(AUDIT))
    parser.add_argument('--blender-review',action='store_true')
    options=parser.parse_args(args)
    out=Path(options.output_dir);review=Path(options.review_dir);review.mkdir(parents=True,exist_ok=True)
    bind=GLB(ROOT/'assets/town/xuyan/character.glb')
    idle=GLB(ROOT/'assets/town/xuyan/idle.glb')
    reports=[]
    for source_name,dest_name in [
        ('Meshy_AI_Gray_Workwear_Portrai_All_Animations.glb','electrical_shopkeeper.glb'),
        ('Meshy_AI_Casual_Studio_Portrai_All_Animations.glb','female_resident.glb')]:
        reports.append(prepare_asset(Path(options.input_dir)/source_name,out/dest_name,bind,idle))
    (review/'prepared_npc_idle_audit.json').write_text(json.dumps(reports,ensure_ascii=False,indent=2),encoding='utf8')
    (out/'preparation_manifest.json').write_text(json.dumps(reports,ensure_ascii=False,indent=2),encoding='utf8')
    print('PREPARED_NPCS',json.dumps([{'file':r['file'],'clips':r['clips'],'seam':r['idle_seam_max_quaternion_component_error'],
        'feet':[r['sampled_frames'][0]['left_shoe_min_y'],r['sampled_frames'][0]['right_shoe_min_y']]}for r in reports]))
    if options.blender_review:
        blender_review(out,review)


def blender_review(out, review):
    import bpy
    from mathutils import Vector
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version=0
    temporary=review/'temp';temporary.mkdir(parents=True,exist_ok=True)
    bpy.context.preferences.filepaths.temporary_directory=str(temporary)
    scene=bpy.context.scene;scene.render.fps=30;scene.frame_start=1;scene.frame_end=121
    scene.unit_settings.system='METRIC'
    sets=[]
    for filename in ('electrical_shopkeeper.glb','female_resident.glb'):
        before=set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=str(out/filename))
        objects=list(set(bpy.data.objects)-before)
        arm=next(o for o in objects if o.type=='ARMATURE')
        if arm.animation_data:
            for track in arm.animation_data.nla_tracks: track.mute=True
        # Imported animation tracks, rather than global names, identify this rig's clip.
        action=next(t.strips[0].action for t in arm.animation_data.nla_tracks if t.strips and t.strips[0].action.name.startswith('Idle'))
        arm.animation_data.action=action
        if hasattr(action,'slots') and len(action.slots): arm.animation_data.action_slot=action.slots[0]
        sets.append((filename,objects,arm,action))
    for image in bpy.data.images:
        if image.source=='FILE' or image.packed_file: image.pack()
    scene.world=bpy.data.worlds.new('NPC_Review_World');scene.world.use_nodes=True
    scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.18,.20,.23,1)
    scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.35
    groundmat=bpy.data.materials.new('Review_ground');groundmat.diffuse_color=(.16,.17,.18,1)
    bpy.ops.mesh.primitive_plane_add(size=20,location=(0,0,-.003));ground=bpy.context.object;ground.name='REVIEW_FLOOR';ground.data.materials.append(groundmat)
    def light(name,pos,power,size):
        data=bpy.data.lights.new(name,'AREA');data.energy=power;data.shape='DISK';data.size=size
        obj=bpy.data.objects.new(name,data);scene.collection.objects.link(obj);obj.location=pos
        obj.rotation_euler=(Vector((0,0,.9))-obj.location).to_track_quat('-Z','Y').to_euler()
    light('REVIEW_KEY',(-2,-3,4),400,3)
    light('REVIEW_FILL',(3,-1,2),180,3)
    light('REVIEW_RIM',(0,2,3),240,2)
    camera_data=bpy.data.cameras.new('REVIEW_CAMERA');camera=bpy.data.objects.new('REVIEW_CAMERA',camera_data);scene.collection.objects.link(camera);scene.camera=camera
    scene.render.engine='BLENDER_EEVEE_NEXT';scene.render.resolution_x=640;scene.render.resolution_y=800;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG';scene.render.film_transparent=False
    scene.view_settings.view_transform='AgX'
    scene.render.image_settings.color_mode='RGB'
    for filename,objects,arm,action in sets:
        for _,other,_,_ in sets:
            for o in other:o.hide_render=o not in objects
        for suffix,location,target,frame in [
            ('idle_front',(0,-3.7,1.05),(0,0,.9),1),
            ('idle_phase_025',(0,-3.7,1.05),(0,0,.9),31),
            ('idle_phase_050',(0,-3.7,1.05),(0,0,.9),61),
            ('idle_phase_075',(0,-3.7,1.05),(0,0,.9),91),
            ('idle_phase_100',(0,-3.7,1.05),(0,0,.9),121),
            ('idle_threequarter',(2.5,-3,1.1),(0,0,.9),31),
            ('idle_side',(3.7,0,1.05),(0,0,.9),61)]:
            camera.location=location;camera.rotation_euler=(Vector(target)-camera.location).to_track_quat('-Z','Y').to_euler();camera_data.lens=55
            scene.frame_set(frame);bpy.context.view_layer.update()
            scene.render.filepath=str(review/(Path(filename).stem+'_'+suffix+'.png'))
            bpy.ops.render.render(write_still=True)
    # Store both editable rigs with their own material images and all source clips.
    for _,objects,_,_ in sets:
        for o in objects:o.hide_render=False
    source=ROOT/'source_art/street_residents_user_v1.blend'
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    print('BLENDER_REVIEW_DONE',str(source))


if __name__=='__main__':main()
