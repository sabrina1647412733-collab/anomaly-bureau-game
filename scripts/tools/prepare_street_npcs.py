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
AUDIT = Path(r'F:\诡异事务局\验收\20261023_NPC生活化')
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
        location=target.add_accessor(np.tile(target.local[node][:3,3],(samples,1)),'VEC3')
        animation['samplers'].append({'input':times,'output':location,'interpolation':'LINEAR'})
        animation['channels'].append({'sampler':len(animation['samplers'])-1,'target':{'node':node,'path':'translation'}})
    target.doc.setdefault('animations',[]).append(animation)
    target.doc.setdefault('extras',{})['street_resident_preparation'] = {
        'version':1,'units':'meters','up':'+Y','forward':'+Z','height':1.7,
        'source_file':Path(input_path).name,'source_sha256':hashlib.sha256(target.original).hexdigest(),
        'preserved_animations':[a.get('name') for a in original_anims],
        'standing':'Own planted legs, bone-axis lowered arms/soft elbows/relaxed fingers, four-second subtle breathing'}
    life_report=add_life_actions(target,baseline_local)
    assert target.doc['animations'][:len(original_anims)] == original_anims
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
    report['life_actions']=life_report
    report['runtime']={'walk_clip':'ShortWalk','walk_speed_mps':.30,'walk_seconds':2.4,'stride_m':.72,
        'walk_distance_curve':[[0,0],[.04,0],[.30,.25],[.37,.25],[.63,.75],[.70,.75],[.96,1],[1,1]],
        'walk_distance_interpolation':'smoothstep changing segments; hold flat segments',
        'life_clip':'CareShop' if Path(output_path).stem=='electrical_shopkeeper' else 'Shelter',
        'turn_left_clip':'TurnStepLeft','turn_right_clip':'TurnStepRight','turn_seconds':1.8,
        'turn_positive_clip':'TurnStepRight','turn_negative_clip':'TurnStepLeft',
        'turn_degrees':90,'turn_yaw_curve':[[0,0],[.03,0],[.28,.5],[.36,.5],[.61,1],[1,1]],
        'turn_yaw_interpolation':'smoothstep changing segments; hold flat segments',
        'turn_max_yaw_degrees_per_sec':150}
    return report


class SkinContext:
    def __init__(self,asset):
        self.asset=asset;self.joints=asset.doc['skins'][0]['joints']
        self.inverse=asset.accessor(asset.doc['skins'][0]['inverseBindMatrices']).reshape(-1,4,4).transpose(0,2,1)
        primitive=asset.doc['meshes'][next(n['mesh'] for n in asset.doc['nodes'] if n.get('skin')==0)]['primitives'][0]
        positions=asset.accessor(primitive['attributes']['POSITION'])
        self.homogeneous=np.c_[positions,np.ones(len(positions))]
        self.indices=asset.accessor(primitive['attributes']['JOINTS_0']).astype(int)
        self.weights=asset.accessor(primitive['attributes']['WEIGHTS_0'])
        self.shoes={};self.soles={};self.bind_sole_centers={}
        for side,sign in [('Left',1),('Right',-1)]:
            mask=(positions[:,1]<.20)&(positions[:,0]*sign>0)
            self.shoes[side]=mask
            self.soles[side]=mask&(positions[:,1]<positions[mask,1].min()+.009)
            self.bind_sole_centers[side]=positions[self.soles[side]].mean(axis=0)
    def deform(self,world):
        matrices=np.array([world[node]@ib for node,ib in zip(self.joints,self.inverse)])
        return (np.einsum('vwij,vj->vwi',matrices[self.indices],self.homogeneous)*self.weights[:,:,None]).sum(axis=1)[:,:3]


def smooth(x):
    x=float(np.clip(x,0,1));return x*x*(3-2*x)


def set_world_rotation(asset,locals_,node,rotation):
    world=asset.world_matrices(locals_);parent=asset.parents.get(node)
    parent_rotation=world[parent][:3,:3] if parent is not None else np.eye(3)
    locals_[node][:3,:3]=np.linalg.inv(parent_rotation)@rotation


def two_bone_ik(asset,locals_,first,middle,end,target,pole,bind,foot_rotation=None):
    a=asset.names['mixamorig:'+first];b=asset.names['mixamorig:'+middle];c=asset.names['mixamorig:'+end]
    world=asset.world_matrices(locals_);origin=world[a][:3,3]
    length1=np.linalg.norm(bind[b][:3,3]-bind[a][:3,3]);length2=np.linalg.norm(bind[c][:3,3]-bind[b][:3,3])
    direction=np.asarray(target)-origin;distance=np.linalg.norm(direction)
    distance=float(np.clip(distance,abs(length1-length2)+.0001,length1+length2-.0001));direction/=np.linalg.norm(direction)
    perpendicular=np.asarray(pole,dtype=float)-direction*np.dot(pole,direction)
    if np.linalg.norm(perpendicular)<1e-5:perpendicular=np.array([0,0,1.0])
    perpendicular/=np.linalg.norm(perpendicular)
    along=(length1*length1-length2*length2+distance*distance)/(2*distance)
    knee=origin+direction*along+perpendicular*math.sqrt(max(0,length1*length1-along*along))
    first_r=align_direction(bind[b][:3,3]-bind[a][:3,3],knee-origin)@bind[a][:3,:3]
    set_world_rotation(asset,locals_,a,first_r)
    world=asset.world_matrices(locals_)
    second_r=align_direction(bind[c][:3,3]-bind[b][:3,3],np.asarray(target)-world[b][:3,3])@bind[b][:3,:3]
    set_world_rotation(asset,locals_,b,second_r)
    if foot_rotation is not None:set_world_rotation(asset,locals_,c,foot_rotation)


def set_legs(asset,locals_,targets,orientations,bind,skin,grounded=True):
    sole_goals={side:.001+targets[side][1]-bind[asset.names['mixamorig:'+side+'Foot']][:3,3][1] for side in targets}
    center_goals={}
    for side in targets:
        foot=bind[asset.names['mixamorig:'+side+'Foot']]
        offset=foot[:3,:3].T@(skin.bind_sole_centers[side]-foot[:3,3])
        center_goals[side]=targets[side]+orientations[side]@offset
    for iteration in range(6 if grounded else 1):
        for side in ('Left','Right'):
            foot_id=asset.names['mixamorig:'+side+'Foot']
            two_bone_ik(asset,locals_,side+'UpLeg',side+'Leg',side+'Foot',targets[side],[0,0,1],bind,orientations[side])
            # Toe/end orientations inherit a flat sole instead of roll from shin IK.
            for suffix in ('ToeBase','Toe_End'):
                node=asset.names.get('mixamorig:'+side+suffix)
                if node is not None:set_world_rotation(asset,locals_,node,orientations[side]@bind[foot_id][:3,:3].T@bind[node][:3,:3])
        if grounded and iteration<5:
            deformed=skin.deform(asset.world_matrices(locals_))
            for side in ('Left','Right'):
                # Correct actual skinned sole, per foot, rather than pushing root.
                targets[side][1]+=sole_goals[side]-float(deformed[skin.shoes[side],1].min())
                actual=deformed[skin.soles[side]].mean(axis=0)
                targets[side][[0,2]]+=(center_goals[side]-actual)[[0,2]]


def append_pose_clip(asset,name,duration,poses,metadata):
    time_index=asset.add_accessor(np.linspace(0,duration,len(poses)).reshape(-1,1),'SCALAR')
    animation={'name':name,'channels':[],'samplers':[],'extras':metadata}
    for node in asset.doc['skins'][0]['joints']:
        qs=[];ts=[]
        for pose in poses:
            q=matrix_quat(pose[node][:3,:3])
            if qs and np.dot(q,qs[-1])<0:q=-q
            qs.append(q);ts.append(pose[node][:3,3])
        for path,values,kind in [('rotation',qs,'VEC4'),('translation',ts,'VEC3')]:
            output=asset.add_accessor(values,kind)
            animation['samplers'].append({'input':time_index,'output':output,'interpolation':'LINEAR'})
            animation['channels'].append({'sampler':len(animation['samplers'])-1,'target':{'node':node,'path':path}})
    asset.doc['animations'].append(animation)


def base_pose(asset,baseline):
    pose={i:m.copy() for i,m in asset.local.items()}
    for node,r in baseline.items():pose[node][:3,:3]=r
    return pose


def local_world_tilt(asset,pose,name,axis,angle):
    node=asset.names['mixamorig:'+name];world=asset.world_matrices(pose)
    set_world_rotation(asset,pose,node,axis_rotation(axis,math.radians(angle))@world[node][:3,:3])


def life_pose(asset,baseline,kind,t,duration,bind,skin):
    pose=base_pose(asset,baseline);phase=t/duration
    envelope=smooth(phase/.22)*(1-smooth((phase-.72)/.28))
    if kind in ('CareShop','Shelter'):
        world=asset.world_matrices(pose)
        for side,sign in [('Left',1),('Right',-1)]:
            hand=asset.names['mixamorig:'+side+'Hand'];current=world[hand][:3,3]
            if kind=='CareShop':
                desired=np.array([-.105 if side=='Left' else -.18,1.10 if side=='Left' else 1.06,.245])
                if side=='Left':desired[0]+=.018*math.sin(phase*math.pi*8)*envelope
            else:desired=np.array([sign*.085,1.205 if side=='Left' else 1.165,.235])
            target=current*(1-envelope)+desired*envelope
            pole=np.array([sign*.8,-.15,.65])
            two_bone_ik(asset,pose,side+'Arm',side+'ForeArm',side+'Hand',target,pole,bind)
            # Wrist follows own forearm deformation; fingers retain relaxed Idle.
            current_world=asset.world_matrices(pose);forearm=asset.names['mixamorig:'+side+'ForeArm']
            set_world_rotation(asset,pose,hand,current_world[forearm][:3,:3]@bind[forearm][:3,:3].T@bind[hand][:3,:3])
        local_world_tilt(asset,pose,'Head',[0,1,0],envelope*(12 if kind=='CareShop' else -16))
        local_world_tilt(asset,pose,'Neck',[1,0,0],envelope*(7 if kind=='CareShop' else 3))
    elif kind=='LookAround':
        local_world_tilt(asset,pose,'Neck',[0,1,0],12*math.sin(2*math.pi*phase)*math.sin(math.pi*phase))
        local_world_tilt(asset,pose,'Head',[0,1,0],9*math.sin(2*math.pi*phase)*math.sin(math.pi*phase))
    return pose


def turn_fraction(phase):
    return .5*smooth((phase-.03)/.25)+.5*smooth((phase-.36)/.25)


def add_life_actions(asset,baseline):
    bind=asset.bind_matrices();skin=SkinContext(asset);hip=asset.names['mixamorig:Hips']
    step_seconds=1.2;speed=.60;stance=.60;half_stride=speed*step_seconds*stance*.5
    poses=[];rows=[]
    for t in np.linspace(0,step_seconds,73):
        pose=base_pose(asset,baseline);pose[hip][1,3]-=.055
        pose[hip][1,3]+=.004*(1-math.cos(4*math.pi*t/step_seconds))
        targets={};orientations={};support={}
        for side,offset in [('Left',0),('Right',.5)]:
            q=(t/step_seconds+offset)%1
            support[side]=bool(q<stance)
            z=half_stride-speed*step_seconds*q if q<stance else -half_stride+2*half_stride*smooth((q-stance)/(1-stance))
            lift=0 if q<stance else .065*math.sin(math.pi*(q-stance)/(1-stance))
            foot=asset.names['mixamorig:'+side+'Foot']
            targets[side]=bind[foot][:3,3]+np.array([0,lift,z])
            orientations[side]=bind[foot][:3,:3].copy()
        set_legs(asset,pose,targets,orientations,bind,skin)
        for side,sign in [('Left',1),('Right',-1)]:
            local_world_tilt(asset,pose,side+'Arm',[1,0,0],sign*5*math.sin(2*math.pi*t/step_seconds))
        world=asset.world_matrices(pose);deformed=skin.deform(world)
        rows.append({'time':float(t),'support':support,'feet':{side:{'min_y':float(deformed[skin.shoes[side],1].min()),
            'sole_center':deformed[skin.soles[side]].mean(axis=0).tolist()}for side in ('Left','Right')}})
        poses.append(pose)
    walk_meta={'loop':True,'cycle_seconds':step_seconds,'speed_mps':speed,'stride_m':speed*step_seconds,
               'step_m':speed*step_seconds*.5,'stance_fraction':stance,'left_phase':0,'right_phase':.5,
               'method':'Own two-bone leg IK, flat planted sole, stance local velocity=-runtime speed; actual skinned per-foot contact correction'}
    append_pose_clip(asset,'WalkGrounded',step_seconds,poses,walk_meta)
    slip={}
    for side in ('Left','Right'):
        residual=[];heights=[]
        for before,after in zip(rows,rows[1:]):
            if before['support'][side] and after['support'][side]:
                a=np.array(before['feet'][side]['sole_center']);b=np.array(after['feet'][side]['sole_center'])
                residual.append(float((b[2]-a[2])/(after['time']-before['time'])+speed))
                heights.append(after['feet'][side]['min_y'])
        slip[side]={'support_y_min':min(heights),'support_y_max':max(heights),
                    'world_support_speed_abs_p95':float(np.percentile(np.abs(residual),95)),
                    'world_support_speed_abs_max':float(np.max(np.abs(residual)))}
    report={'walk':dict(walk_meta,support_measurements=slip,samples=rows),'gestures':{},'turns':{}}
    short_seconds=2.4;short_distance=.72;short_poses=[];short_rows=[]
    short_curve=[[0,0],[.04,0],[.30,.25],[.37,.25],[.63,.75],[.70,.75],[.96,1],[1,1]]
    for t in np.linspace(0,short_seconds,145):
        phase=t/short_seconds
        distance=short_distance*(.25*smooth((phase-.04)/.26)+.50*smooth((phase-.37)/.26)+.25*smooth((phase-.70)/.26))
        pose=base_pose(asset,baseline);pose[hip][1,3]-=.055*smooth(phase/.10)*(1-smooth((phase-.90)/.10))
        targets={};orientations={};support={}
        for side in ('Left','Right'):
            foot=asset.names['mixamorig:'+side+'Foot'];point=bind[foot][:3,3].copy();lift=0;support[side]=True
            for moving,begin,end,landing in [('Left',.04,.30,.36),('Right',.37,.63,.72),('Left',.70,.96,.72)]:
                if moving!=side or phase<begin:continue
                desired=bind[foot][:3,3]+np.array([0,0,landing])
                if phase<end:
                    fraction=(phase-begin)/(end-begin);point=point*(1-smooth(fraction))+desired*smooth(fraction)
                    lift=.06*math.sin(math.pi*fraction);support[side]=False;break
                point=desired
            targets[side]=point+np.array([0,lift,-distance]);orientations[side]=bind[foot][:3,:3].copy()
        set_legs(asset,pose,targets,orientations,bind,skin)
        if phase<1e-8 or phase>1-1e-8:pose=base_pose(asset,baseline)
        deformed=skin.deform(asset.world_matrices(pose))
        short_rows.append({'time':float(t),'distance':float(distance),'support':support,
            'feet':{side:{'min_y':float(deformed[skin.shoes[side],1].min()),
                'world_sole_center':(deformed[skin.soles[side]].mean(axis=0)+[0,0,distance]).tolist()}for side in ('Left','Right')}})
        short_poses.append(pose)
    short_meta={'loop':False,'seconds':short_seconds,'stride_m':short_distance,'average_speed_mps':short_distance/short_seconds,
                'distance_curve':short_curve,'distance_interpolation':'smoothstep per changing segment',
                'returns_to_idle':True,'method':'Two slow steps and gather step, root-distance counter-compensated planted soles'}
    append_pose_clip(asset,'ShortWalk',short_seconds,short_poses,short_meta)
    short_metrics={}
    for side in ('Left','Right'):
        speeds=[];heights=[]
        for a,b in zip(short_rows,short_rows[1:]):
            if a['support'][side] and b['support'][side]:
                speeds.append(float(np.linalg.norm(np.array(b['feet'][side]['world_sole_center'])-a['feet'][side]['world_sole_center'])/(b['time']-a['time'])))
                heights.append(b['feet'][side]['min_y'])
        short_metrics[side]={'support_y_min':min(heights),'support_y_max':max(heights),'support_speed_p95':float(np.percentile(speeds,95)),
                             'support_speed_max':max(speeds)}
    report['short_walk']=dict(short_meta,support_measurements=short_metrics,samples=short_rows)
    for kind,duration in [('CareShop',4.0),('Shelter',4.2),('LookAround',3.6)]:
        sequence=[life_pose(asset,baseline,kind,float(t),duration,bind,skin) for t in np.linspace(0,duration,round(duration*30)+1)]
        append_pose_clip(asset,kind,duration,sequence,{'loop':False,'empty_hands':True,'returns_to_idle':True})
        minima=[]
        for pose in sequence[::max(1,len(sequence)//9)]:minima.append(float(skin.deform(asset.world_matrices(pose))[:,1].min()))
        report['gestures'][kind]={'seconds':duration,'ground_minimum_y':min(minima),'empty_hands':True}
    for sign,name in [(-1,'TurnStepLeft'),(1,'TurnStepRight')]:
        duration=1.8;sequence=[];turn_rows=[]
        schedule=[('Left' if sign>0 else 'Right',.03,.28,.5),('Right' if sign>0 else 'Left',.36,.61,1),('Left' if sign>0 else 'Right',.70,.95,1)]
        for t in np.linspace(0,duration,109):
            phase=t/duration;theta=sign*math.pi*.5*turn_fraction(phase)
            pose=base_pose(asset,baseline);pose[hip][1,3]-=.055*smooth(phase/.10)*(1-smooth((phase-.90)/.10))
            targets={};orientations={};support={}
            for side in ('Left','Right'):
                foot=asset.names['mixamorig:'+side+'Foot'];start=bind[foot][:3,3].copy();angle=0;point=start.copy();lift=0;support[side]=True
                for stepping,begin,end,land in schedule:
                    if side!=stepping or phase<begin:continue
                    desired=axis_rotation([0,1,0],sign*math.pi*.5*land)@start
                    if phase<end:
                        fraction=(phase-begin)/(end-begin);point=point*(1-smooth(fraction))+desired*smooth(fraction)
                        angle=angle*(1-smooth(fraction))+sign*math.pi*.5*land*smooth(fraction)
                        lift=.055*math.sin(math.pi*fraction);support[side]=False;break
                    point=desired;angle=sign*math.pi*.5*land
                targets[side]=axis_rotation([0,1,0],-theta)@point+np.array([0,lift,0])
                orientations[side]=axis_rotation([0,1,0],angle-theta)@bind[foot][:3,:3]
            set_legs(asset,pose,targets,orientations,bind,skin)
            deformed=skin.deform(asset.world_matrices(pose));external=axis_rotation([0,1,0],theta)
            turn_rows.append({'time':float(t),'yaw_fraction':turn_fraction(phase),'support':support,
                 'feet':{side:{'min_y':float(deformed[skin.shoes[side],1].min()),'world_sole_center':(external@deformed[skin.soles[side]].mean(axis=0)).tolist()}for side in ('Left','Right')}})
            sequence.append(pose)
        meta={'loop':False,'seconds':duration,'degrees':sign*90,'root_translation':False,
              'root_yaw_profile':[[0,0],[.03,0],[.28,.5],[.36,.5],[.61,1],[1,1]],
              'profile_interpolation':'smoothstep per changing segment','three_steps':True,
              'max_yaw_deg_per_sec':150,'requires_matching_runtime_yaw':True}
        append_pose_clip(asset,name,duration,sequence,meta)
        metrics={}
        for side in ('Left','Right'):
            residual=[]
            for a,b in zip(turn_rows,turn_rows[1:]):
                if a['support'][side] and b['support'][side]:
                    residual.append(float(np.linalg.norm(np.array(b['feet'][side]['world_sole_center'])-a['feet'][side]['world_sole_center'])/(b['time']-a['time'])))
            metrics[side]={'support_speed_p95':float(np.percentile(residual,95)),'support_speed_max':max(residual)}
        report['turns'][name]=dict(meta,support_measurements=metrics,samples=turn_rows)
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
        if animation.get('name') not in ('Running','Walking'):continue
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
    parser.add_argument('--review-only',action='store_true')
    parser.add_argument('--review-clips',default='')
    options=parser.parse_args(args)
    out=Path(options.output_dir);review=Path(options.review_dir);review.mkdir(parents=True,exist_ok=True)
    if options.review_only:
        blender_review(out,review,options.review_clips)
        return
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
        blender_review(out,review,options.review_clips)


def blender_review(out, review, clips=''):
    import bpy
    from mathutils import Vector
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version=0
    temporary=review/'temp';temporary.mkdir(parents=True,exist_ok=True)
    bpy.context.preferences.filepaths.temporary_directory=str(temporary)
    scene=bpy.context.scene;scene.render.fps=30;scene.frame_start=0;scene.frame_end=126
    scene.unit_settings.system='METRIC'
    sets=[]
    for filename in ('electrical_shopkeeper.glb','female_resident.glb'):
        before=set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=str(out/filename))
        objects=list(set(bpy.data.objects)-before)
        arm=next(o for o in objects if o.type=='ARMATURE')
        driver=bpy.data.objects.new('REVIEW_DRIVER_'+Path(filename).stem,None)
        bpy.context.scene.collection.objects.link(driver)
        for obj in objects:
            if obj.parent is None:obj.parent=driver
        objects.append(driver)
        arm['review_driver']=driver.name
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
    scene.render.engine='BLENDER_EEVEE_NEXT';scene.render.resolution_x=384;scene.render.resolution_y=512;scene.render.resolution_percentage=100
    if hasattr(scene.eevee,'taa_render_samples'):scene.eevee.taa_render_samples=32
    scene.render.image_settings.file_format='PNG';scene.render.film_transparent=False
    scene.view_settings.view_transform='AgX'
    scene.render.image_settings.color_mode='RGB'
    for filename,objects,arm,action in sets:
        for _,other,_,_ in sets:
            for o in other:o.hide_render=o not in objects
        root_object=bpy.data.objects[arm['review_driver']]
        root_original=root_object.matrix_world.copy()
        for clip,duration in [('Idle',4),('ShortWalk',2.4),('WalkGrounded',1.2),('CareShop',4),('Shelter',4.2),('LookAround',3.6),('TurnStepLeft',1.8),('TurnStepRight',1.8)]:
            if clips and clip not in clips.split(','):continue
            clip_action=next(t.strips[0].action for t in arm.animation_data.nla_tracks if t.strips and t.strips[0].action.name.startswith(clip))
            arm.animation_data.action=clip_action
            if hasattr(clip_action,'slots') and len(clip_action.slots):arm.animation_data.action_slot=clip_action.slots[0]
            for index,phase in enumerate((0,.25,.50,.75,1)):
                root_object.matrix_world=root_original
                distance=0
                if clip=='ShortWalk':distance=.72*(.25*smooth((phase-.04)/.26)+.50*smooth((phase-.37)/.26)+.25*smooth((phase-.70)/.26))
                elif clip=='WalkGrounded':distance=.72*phase
                root_object.location.y-=distance
                if clip.startswith('TurnStep'):
                    root_object.rotation_euler.z=(-1 if clip.endswith('Left') else 1)*math.pi*.5*turn_fraction(phase)
                camera.location=(2.5,-3.8-distance,1.15)
                camera.rotation_euler=(Vector((0,-distance,.86))-camera.location).to_track_quat('-Z','Y').to_euler();camera_data.lens=55
                frame=phase*duration*30;scene.frame_set(int(frame),subframe=frame-int(frame));bpy.context.view_layer.update()
                scene.render.filepath=str(review/(Path(filename).stem+'_'+clip+'_'+str(index)+'.png'))
                bpy.ops.render.render(write_still=True)
        root_object.matrix_world=root_original
        arm.animation_data.action=action
        if hasattr(action,'slots') and len(action.slots):arm.animation_data.action_slot=action.slots[0]
    # Store both editable rigs with their own material images and all source clips.
    for _,objects,_,_ in sets:
        for o in objects:o.hide_render=False
    scene.frame_set(0)
    source=ROOT/'source_art/street_residents_user_v1.blend'
    bpy.ops.wm.save_as_mainfile(filepath=str(source),compress=True)
    print('BLENDER_REVIEW_DONE',str(source))


if __name__=='__main__':main()
