"""Independent case-2 derivatives of user-authorized resident bases.

No source asset is overwritten. New weighted vest/apron, glasses, grey hair and
low bun distinguish identities; existing faces/rig and planted Idle are reused.
Run Blender --background -noaudio --python this.py -- PROJECT AUDIT_DIR.
"""
import bpy, sys, math, json
from pathlib import Path
from mathutils import Vector
from mathutils.kdtree import KDTree
args=sys.argv[sys.argv.index('--')+1:];project=Path(args[0]);audit=Path(args[1]);audit.mkdir(parents=True,exist_ok=True)
out=project/'assets/models/case2/characters';out.mkdir(parents=True,exist_ok=True)
bpy.context.preferences.filepaths.save_version=0
records=[]

def material(name,color,rough=.88):
 m=bpy.data.materials.new(name);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=rough;return m
def weighted(o,arm,bone):
 vg=o.vertex_groups.new(name=bone);vg.add(list(range(len(o.data.vertices))),1.,'REPLACE')
 mod=o.modifiers.new('Own skeleton, rigid attachment','ARMATURE');mod.object=arm
def curve(name,points,r,mat):
 c=bpy.data.curves.new(name,'CURVE');c.dimensions='3D';c.bevel_depth=r;c.bevel_resolution=2
 s=c.splines.new('POLY');s.points.add(len(points)-1)
 for q,p in zip(s.points,points):q.co=(*p,1)
 o=bpy.data.objects.new(name,c);bpy.context.collection.objects.link(o);o.data.materials.append(mat)
 bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.convert(target='MESH');return bpy.context.object
def overlay(body,arm,name,indices,mat,offset=.005):
 source=body.data;old=sorted({i for p in indices for i in source.polygons[p].vertices});mapping={v:i for i,v in enumerate(old)}
 mesh=bpy.data.meshes.new(name);mesh.from_pydata([source.vertices[i].co+source.vertices[i].normal*offset for i in old],[],[[mapping[i] for i in source.polygons[p].vertices] for p in indices]);mesh.update()
 o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);o.matrix_world=body.matrix_world.copy();o.data.materials.append(mat)
 for group in body.vertex_groups:o.vertex_groups.new(name=group.name)
 for new,orig in enumerate(old):
  for group in source.vertices[orig].groups:o.vertex_groups[group.group].add([new],group.weight,'REPLACE')
 mod=o.modifiers.new('Own source skin, no cross-rig retarget','ARMATURE');mod.object=arm
 for face in mesh.polygons:face.use_smooth=True
 return o

for identity,filename in [('hebo','electrical_shopkeeper.glb'),('sun_suqin','female_resident.glb')]:
 bpy.ops.wm.read_factory_settings(use_empty=True);scene=bpy.context.scene;scene.render.fps=30
 bpy.ops.import_scene.gltf(filepath=str(project/'assets/models/chars/street_residents'/filename))
 arm=next(o for o in bpy.data.objects if o.type=='ARMATURE');body=max((o for o in bpy.data.objects if o.type=='MESH'),key=lambda o:len(o.data.vertices))
 head=next(b.name for b in arm.data.bones if b.name.endswith('Head'))
 # Imported animation ownership stays with this character's own armature.
 for track in arm.animation_data.nla_tracks:track.mute=True
 idle=next(t.strips[0].action for t in arm.animation_data.nla_tracks if t.strips and t.strips[0].action.name.startswith('Idle'))
 arm.animation_data.action=idle
 if hasattr(idle,'slots') and len(idle.slots):arm.animation_data.action_slot=idle.slots[0]
 scene.frame_start=0;scene.frame_end=120;scene.frame_set(0)
 coords=[body.matrix_world@v.co for v in body.data.vertices];height=max(v.z for v in coords)-min(v.z for v in coords)
 hv=[p for p in coords if p.z>height-.26]
 scalp=material(identity+'_greying_hair',(.39,.41,.38) if identity=='hebo' else (.15,.18,.17))
 body.data.materials.append(scalp);hair_index=len(body.data.materials)-1
 for face in body.data.polygons:
  centre=body.matrix_world@face.center
  if centre.z>height-.065 or (centre.z>height-.13 and centre.y>.01):face.material_index=hair_index
 new_objects=[]
 if identity=='hebo':
  vest_mat=material('Hebo_navy_wool_vest',(.067,.096,.118))
  kd=KDTree(len(coords))
  for i,p in enumerate(coords):kd.insert(p,i)
  kd.balance();verts=[];faces=[];nearest=[]
  # Tailored continuous front panels. Selecting whole source triangles created
  # ragged cut edges; this fitted grid has an intentional V neck and straight hem.
  for sign in [-1,1]:
   start=len(verts)
   for j in range(10):
    for i in range(10):
     fraction=i/9;x=sign*fraction*.235;top=1.16+fraction*.235;z=.965+j/9*(top-.965)
     near=[p.y for p in coords if abs(p.z-z)<.04 and abs(p.x-x)<.035]
     y=(min(near) if near else -.11)-.012
     p=Vector((x,y,z));verts.append(p);nearest.append(kd.find(p)[1])
   for j in range(9):
    for i in range(9):
     a=start+j*10+i;faces.append((a,a+1,a+11,a+10) if sign>0 else (a+10,a+11,a+1,a))
  # The back remains one smooth piece, shoulders have a deliberate collar line.
  start=len(verts)
  for j in range(9):
   for i in range(13):
    x=(i/12*2-1)*.235;z=.965+j/8*.43;near=[p.y for p in coords if abs(p.z-z)<.04 and abs(p.x-x)<.035]
    y=(max(near) if near else .095)+.012;p=Vector((x,y,z));verts.append(p);nearest.append(kd.find(p)[1])
  for j in range(8):
   for i in range(12):a=start+j*13+i;faces.append((a,a+13,a+14,a+1))
  mesh=bpy.data.meshes.new('Hebo_continuous_tailored_vest');mesh.from_pydata(verts,[],faces);mesh.update()
  vest=bpy.data.objects.new('Hebo_separate_knitted_vest',mesh);bpy.context.collection.objects.link(vest);vest.data.materials.append(vest_mat)
  for group in body.vertex_groups:vest.vertex_groups.new(name=group.name)
  hips=next(g.name for g in body.vertex_groups if g.name.endswith('Hips'));spine=next(g.name for g in body.vertex_groups if g.name.endswith('Spine2'))
  for i,p in enumerate(verts):
   t=max(0,min(1,(p.z-1.0)/.33));vest.vertex_groups[hips].add([i],1-t,'REPLACE');vest.vertex_groups[spine].add([i],t,'REPLACE')
  mod=vest.modifiers.new('Own torso bones, no arm weights','ARMATURE');mod.object=arm
  solid=vest.modifiers.new('Wool hem thickness','SOLIDIFY');solid.thickness=.004
  for p in mesh.polygons:p.use_smooth=True
  new_objects.append(vest)
  glasses_mat=material('Hebo_thin_spectacle_metal',(.09,.11,.10),.3)
  eye_z=height-.122;front=min(p.y for p in hv)+.022
  parts=[]
  for x in [-.038,.038]:parts.append(curve('Hebo_glasses_lens_rim',[(x+.031*math.cos(k/32*math.tau),front,eye_z+.023*math.sin(k/32*math.tau)) for k in range(33)],.0016,glasses_mat))
  parts.append(curve('Hebo_glasses_bridge',[(-.007,front,eye_z+.005),(0,front-.004,eye_z+.010),(.007,front,eye_z+.005)],.0014,glasses_mat))
  for x in [-.069,.069]:parts.append(curve('Hebo_glasses_temple',[(x,front,eye_z),(x,front+.07,eye_z),(x,front+.085,eye_z-.018)],.0015,glasses_mat))
  for o in parts:weighted(o,arm,head);new_objects.append(o)
 else:
  apron_mat=material('Sun_Suqin_worn_cotton_apron',(.50,.51,.42))
  kd=KDTree(len(body.data.vertices))
  for v,p in zip(body.data.vertices,coords):kd.insert(p,v.index)
  kd.balance();verts=[];faces=[];nearest=[];rows=13;cols=9
  for j in range(rows):
   z=.56+j/(rows-1)*.80
   width=.26 if z<1.02 else .26-(z-1.02)*.80 if z<1.17 else .14
   for i in range(cols):
    x=(i/(cols-1)*2-1)*width
    candidates=[p.y for p in coords if abs(p.z-z)<.045 and abs(p.x-x)<.045]
    front=min(candidates) if candidates else -.10
    y=min(front-.018,-.105) + .006*math.sin(i*1.9+j*.5)
    p=Vector((x,y,z));verts.append(p);nearest.append(kd.find(p)[1])
  for j in range(rows-1):
   for i in range(cols-1):
    a=j*cols+i;faces.append((a,a+1,a+cols+1,a+cols))
  mesh=bpy.data.meshes.new('Sun_apron_tailored_grid');mesh.from_pydata(verts,[],faces);mesh.update()
  apron=bpy.data.objects.new('Sun_separate_work_apron',mesh);bpy.context.collection.objects.link(apron);apron.data.materials.append(apron_mat)
  for group in body.vertex_groups:apron.vertex_groups.new(name=group.name)
  hips=next(g.name for g in body.vertex_groups if g.name.endswith('Hips'));spine=next(g.name for g in body.vertex_groups if g.name.endswith('Spine2'))
  for i,p in enumerate(verts):
   t=max(0,min(1,(p.z-1.10)/.24));apron.vertex_groups[hips].add([i],1-t,'REPLACE');apron.vertex_groups[spine].add([i],t,'REPLACE')
  mod=apron.modifiers.new('Own source skin, fitted apron','ARMATURE');mod.object=arm
  solid=apron.modifiers.new('Real cotton hem thickness','SOLIDIFY');solid.thickness=.003
  for p in apron.data.polygons:p.use_smooth=True
  new_objects.append(apron)
  # Low bun keeps the base facial topology, adds a separate recognizable silhouette.
  bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=12,radius=1,location=(0,.073,height-.14))
  bun=bpy.context.object;bun.name='Sun_low_work_bun';bun.scale=(.055,.045,.040);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
  bun.data.materials.append(scalp)
  for p in bun.data.polygons:p.use_smooth=True
  weighted(bun,arm,head);new_objects.append(bun)
  # A faded blue-green work blouse, distinct from the resident's plum jacket.
  blouse=material('Sun_faded_work_blouse',(.18,.27,.25))
  body.data.materials.append(blouse);blouse_index=len(body.data.materials)-1
  for f in body.data.polygons:
   p=body.matrix_world@f.center
   if .89<p.z<1.45 and abs(p.x)<.57:f.material_index=blouse_index
 # Only roughness is reduced to 1024; preserve the face/base and normal images.
 for image in bpy.data.images:
  if max(image.size)>2048:image.scale(1024,1024)
  if image.source=='FILE' or image.packed_file:image.pack()
 source=project/'source_art'/('case2_'+identity+'_v1.blend');bpy.ops.wm.save_as_mainfile(filepath=str(source),compress=True)
 bpy.ops.object.select_all(action='DESELECT')
 for o in list(bpy.data.objects):
  if o.type in ['MESH','ARMATURE','EMPTY']:o.select_set(True)
 bpy.context.view_layer.objects.active=arm
 bpy.ops.export_scene.gltf(filepath=str(out/(identity+'.glb')),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='ACTIVE_ACTIONS',export_apply=False,export_skins=True,export_morph=True,export_cameras=False,export_lights=False)
 # Offline contact frames; these are explicitly NOT Godot gameplay screenshots.
 scene.world=bpy.data.worlds.new('OFFLINE_inspection');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.25
 for name,power,pos,size in [('key',300,(-2,-3,3),3),('fill',120,(2,-1,2),3)]:
  data=bpy.data.lights.new('OFFLINE_'+name,'AREA');data.energy=power;data.shape='DISK';data.size=size;o=bpy.data.objects.new('OFFLINE_'+name,data);scene.collection.objects.link(o);o.location=pos;o.rotation_euler=(Vector((0,0,.85))-o.location).to_track_quat('-Z','Y').to_euler()
 data=bpy.data.cameras.new('OFFLINE_camera');camera=bpy.data.objects.new('OFFLINE_camera',data);scene.collection.objects.link(camera);scene.camera=camera;data.lens=55
 scene.render.engine='BLENDER_EEVEE_NEXT';scene.render.resolution_x=640;scene.render.resolution_y=800;scene.render.resolution_percentage=100;scene.render.image_settings.file_format='PNG';scene.view_settings.view_transform='AgX'
 frames=[]
 for index,phase in enumerate([0,.5,1]):
  scene.frame_set(int(phase*120));bpy.context.view_layer.update();camera.location=(1.8,-3.0,1.15);camera.rotation_euler=(Vector((0,0,.88))-camera.location).to_track_quat('-Z','Y').to_euler();scene.render.filepath=str(audit/(identity+'_OFFLINE_idle_'+str(index)+'.png'));bpy.ops.render.render(write_still=True)
  deps=bpy.context.evaluated_depsgraph_get();ev=body.evaluated_get(deps);m=ev.to_mesh();points=[ev.matrix_world@v.co for v in m.vertices];frames.append({'phase':phase,'feet_min':min(p.z for p in points),'height':max(p.z for p in points)-min(p.z for p in points)});ev.to_mesh_clear()
 records.append({'id':identity,'source':filename,'source_untouched':True,'reuse':'base face, body, own skeleton and planted Idle','added':[o.name for o in new_objects],'idle_samples':frames,'file_bytes':(out/(identity+'.glb')).stat().st_size})
(out/'derivation.json').write_text(json.dumps(records,ensure_ascii=False,indent=2),encoding='utf-8')
print('CASE2_CHARACTERS_OK',json.dumps(records,ensure_ascii=False))
