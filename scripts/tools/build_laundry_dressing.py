"""Additive Blender dressing for the approved shop; no floorplan replacement.
All inputs/outputs under the existing project. Godot metre coordinates below.
"""
import bpy,sys,math,json
from pathlib import Path
from mathutils import Vector
project=Path(sys.argv[sys.argv.index('--')+1]);out=project/'assets/models/laundry_detail';out.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def point(p):return Vector((p[0],-p[2],p[1]))
def mat(name,c,r=.7,metal=0):
 m=bpy.data.materials.new(name);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*c,1);p.inputs['Roughness'].default_value=r;p.inputs['Metallic'].default_value=metal;return m
wood=mat('Oak',(.23,.155,.086),.83);steel=mat('PaintedSteel',(.10,.16,.14),.65,.25);black=mat('Rubber',(.018,.024,.022),.8)
ivory=mat('WarmEnamel',(.58,.55,.44),.64);linen=mat('Linen',(.42,.43,.35),.98);silver=mat('Metal',(.29,.33,.31),.31,.8)
soap=mat('Detergent',(.26,.36,.27),.5);paper=mat('Paper',(.65,.59,.44),.91);light=mat('Tube',(.7,.77,.74),.5)
p=light.node_tree.nodes.get('Principled BSDF');p.inputs['Emission Color'].default_value=(.62,.75,.72,1);p.inputs['Emission Strength'].default_value=2.
def own(o,name,m):o.name=name;o.data.materials.append(m);return o
def box(name,p,s,m,bevel=.003):
 bpy.ops.mesh.primitive_cube_add(size=1,location=point(p));o=own(bpy.context.object,name,m);o.scale=(s[0],s[2],s[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if bevel:b=o.modifiers.new('Edge','BEVEL');b.width=bevel;b.segments=3;n=o.modifiers.new('Normals','WEIGHTED_NORMAL')
 return o
def cyl(name,p,r,h,m,axis=(0,1,0),n=24):
 bpy.ops.mesh.primitive_cylinder_add(vertices=n,radius=r,depth=h,location=point(p));o=own(bpy.context.object,name,m);o.rotation_mode='QUATERNION';o.rotation_quaternion=Vector((0,0,1)).rotation_difference(point(axis).normalized())
 for f in o.data.polygons:f.use_smooth=len(f.vertices)==4
 return o
def line(name,pts,r,m):
 c=bpy.data.curves.new(name,'CURVE');c.dimensions='3D';c.bevel_depth=r;c.bevel_resolution=2;s=c.splines.new('POLY');s.points.add(len(pts)-1)
 for q,p in zip(s.points,pts):q.co=(*point(p),1)
 o=bpy.data.objects.new(name,c);bpy.context.collection.objects.link(o);o.data.materials.append(m);return o
# Wall-mounted shelves above west-side machines, outside circulation space.
for z in [3.75,5.7,7.65]:
 for y in [5.01,5.57]:
  box('Shelf',(-2.86,y,z),(.46,.035,1.58),wood)
  for zz in [z-.61,z+.61]:
   box('ShelfBracket',(-3.01,y-.15,zz),(.025,.30,.025),steel)
   box('ShelfSupport',(-2.85,y-.035,zz),(.34,.025,.025),steel)
 for i in range(4):
  zz=z-.54+i*.30
  cyl('SoapBottle',(-2.83,5.16,zz),.052,.26,soap if i%2 else ivory)
  cyl('SoapCap',(-2.83,5.305,zz),.027,.032,steel)
  box('BottleLabel',(-2.774,5.16,zz),(.003,.11,.075),paper,.001)
 for i in range(5):box('FoldedTowel',(-2.83,5.61+i*.027,z-.25),(.31,.026,.46),linen,.008)
# Woven laundry baskets have open tops and actual slats, not a solid cube.
for x,z in [(-2.68,4.07),(-2.68,6.83),(2.69,2.6)]:
 y=4.45
 box('BasketBase',(x,y,z),(.39,.025,.49),steel)
 for yy in [.06,.16,.26]:
  for xx in [-.20,.20]:box('BasketRail',(x+xx,y+yy,z),(.016,.022,.51),steel,.002)
  for zz in [-.25,.25]:box('BasketRail',(x,y+yy,z+zz),(.40,.022,.016),steel,.002)
 for i in range(9):
  for xx in [-.2,.2]:box('BasketWeave',(x+xx,y+.14,z-.22+i*.055),(.014,.26,.012),steel,.002)
 for i in range(7):
  for zz in [-.25,.25]:box('BasketWeave',(x-.17+i*.055,y+.14,z+zz),(.012,.26,.014),steel,.002)
 for i in range(3):box('LaundryInBasket',(x,y+.045+i*.045,z),(.32,.05,.41),linen,.015)
# Visible overhead fluorescent fixtures and surface-mounted electrical conduit.
for z in [4.4,8.6]:
 box('FixtureHousing',(.0,6.30,z),(.46,.07,1.18),steel,.009)
 for x in [-.13,.13]:cyl('FluorescentTube',(x,6.245,z),.022,1.05,light,(0,0,1),16)
 for zz in [z-.53,z+.53]:box('TubeEndCap',(0,6.245,zz),(.37,.06,.05),ivory)
 line('CeilingConduit',[(-3.08,6.29,1.98),(-3.08,6.29,z),(0,6.29,z)],.012,steel)
# Exposed copper service lines, with fastening collars and shut-off valve.
for yy in [5.95,6.12]:
 line('ServicePipe',[(3.06,yy,2),(3.06,yy,8.9),(2.98,yy,9.25)],.018,silver)
 for zz in [2.5,4.8,7.8]:box('PipeClip',(3.077,yy,zz),(.035,.075,.022),steel)
# Wall fan, guard rings and motor: small enough for the existing wall.
cx,cy,cz=-3.035,5.74,9.0
cyl('FanMotor',(cx+.11,cy,cz),.065,.18,steel,(1,0,0))
for r in [.09,.15,.21,.26]:
 pts=[(cx+.24,cy+r*math.cos(i/64*math.tau),cz+r*math.sin(i/64*math.tau)) for i in range(65)];line('FanGuard',pts,.0025,silver)
for i in range(12):
 a=i/12*math.tau;line('FanSpoke',[(cx+.25,cy,cz),(cx+.25,cy+.26*math.cos(a),cz+.26*math.sin(a))],.002,silver)
for i in range(3):
 a=i/3*math.tau;blade=box('FanBlade',(cx+.19,cy+.135*math.cos(a),cz+.135*math.sin(a)),(.015,.10,.23),steel,.02);blade.rotation_euler.x=a
# Warm counter lamp lives above the existing counter, away from the clue target.
cyl('DeskLampBase',(-2.4,4.64,9.1),.105,.025,steel)
line('DeskLampArm',[(-2.4,4.66,9.1),(-2.4,4.95,9.1),(-2.25,5.07,9.1)],.012,silver)
bpy.ops.mesh.primitive_cone_add(vertices=32,radius1=.12,radius2=.04,depth=.10,location=point((-2.25,5.07,9.1)));own(bpy.context.object,'DeskLampShade',ivory)
# Collapse by material for the runtime GLB; keep editable objects in the .blend.
bpy.ops.wm.save_as_mainfile(filepath=str(project/'source_art/laundry_detail_v1.blend'))
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.convert(target='MESH')
groups={}
for o in list(bpy.context.selected_objects):groups.setdefault(o.data.materials[0].name,[]).append(o)
for name,objects in groups.items():
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:o.select_set(True)
 bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();bpy.context.object.name='Detail_'+name
bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(out/'shop_detail.glb'),export_format='GLB',use_selection=True,export_apply=True,export_animations=False)
print('SHOP_DETAIL_OK',len(bpy.data.objects))
