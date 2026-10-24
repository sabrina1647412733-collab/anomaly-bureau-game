"""Huaian case 2: metre-scale, closed modular building, editable Blender source.

Run Blender --background -noaudio --python this.py -- PROJECT [--whitebox].
Godot +Y up maps to Blender +Z up; all runtime coordinates remain local.
The manifest is the shared source for visual construction and collision.
"""
import bpy, sys, math, json
from pathlib import Path
from mathutils import Vector

args=sys.argv[sys.argv.index('--')+1:]
project=Path(args[0]); out=project/'assets/models/case2'; out.mkdir(parents=True,exist_ok=True)
white='--whitebox' in args
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
boxes=[]; ramps=[]; anchors={}; modules={}; mats={}

COLORS={'wall':(.53,.52,.45),'tile':(.39,.42,.38),'ceiling':(.66,.65,.58),'stair':(.41,.42,.38),
 'wood':(.24,.17,.11),'metal':(.20,.28,.26),'steel':(.37,.42,.40),'paper':(.72,.66,.51),
 'cloth':(.39,.42,.35),'glass':(.17,.25,.25),'rubber':(.026,.034,.031),'light':(.68,.76,.70),
 'rust':(.31,.19,.10),'patch':(.40,.40,.35),'red':(.34,.10,.07),'water':(.10,.19,.18),'paint':(.32,.41,.34)}
for name,color in COLORS.items():
 m=bpy.data.materials.new('C2_'+name);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF')
 p.inputs['Base Color'].default_value=(*((.58,.58,.58) if white else color),1)
 p.inputs['Roughness'].default_value=.88 if name in ['wall','ceiling','cloth','patch'] else .56
 p.inputs['Metallic'].default_value=.7 if name in ['steel','rust'] else .15 if name=='metal' else 0
 if name=='light':p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=1.3
 mats[name]=m

def point(p):return Vector((p[0],-p[2],p[1]))
def own(o,name,mat,module):
 o.name='GEO_'+name;o.data.materials.append(mats[mat]);o['module']=module;modules.setdefault(module,[]).append(o)
 return o
def box(name,p,s,mat='wall',col=False,module='core',bevel=.006):
 x,z,h=s[0]/2,s[2]/2,s[1]/2
 mesh=bpy.data.meshes.new('Mesh_'+name)
 mesh.from_pydata([(-x,-z,-h),(x,-z,-h),(x,z,-h),(-x,z,-h),(-x,-z,h),(x,-z,h),(x,z,h),(-x,z,h)],[],[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])
 mesh.update();o=bpy.data.objects.new('GEO_'+name,mesh);bpy.context.collection.objects.link(o);o.location=point(p);own(o,name,mat,module)
 # Metric per-face UVs, independent of primitive aspect ratio; no stretched tiny tiles.
 uv=o.data.uv_layers.new(name='UVMap')
 for f in o.data.polygons:
  n=f.normal;ax=max(range(3),key=lambda i:abs(n[i]));a,b=[i for i in range(3) if i!=ax]
  for li in f.loop_indices:
   v=o.data.vertices[o.data.loops[li].vertex_index].co;uv.data[li].uv=(v[a],v[b])
 if not white and bevel:
  mod=o.modifiers.new('Real edge bevel','BEVEL');mod.width=min(bevel,min(s)*.25);mod.segments=2
  o.modifiers.new('Weighted corner normals','WEIGHTED_NORMAL')
 if col:boxes.append({'name':name,'p':p,'s':s,'module':module})
 return o
def cyl(name,p,r,h,mat='metal',module='core',axis=(0,1,0),vertices=20):
 bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=h,location=point(p));o=own(bpy.context.object,name,mat,module)
 o.rotation_mode='QUATERNION';o.rotation_quaternion=Vector((0,0,1)).rotation_difference(point(axis).normalized())
 for f in o.data.polygons:f.use_smooth=len(f.vertices)==4
 return o
def line(name,pts,r,mat='metal',module='core'):
 c=bpy.data.curves.new(name,'CURVE');c.dimensions='3D';c.bevel_depth=r;c.bevel_resolution=2
 s=c.splines.new('POLY');s.points.add(len(pts)-1)
 for q,p in zip(s.points,pts):q.co=(*point(p),1)
 o=bpy.data.objects.new('GEO_'+name,c);bpy.context.collection.objects.link(o);o.data.materials.append(mats[mat]);o['module']=module;modules.setdefault(module,[]).append(o);return o
def anchor(id,p,r=1.65,text='查看',floor=1):anchors[id]={'pos':p,'r':r,'text':text,'floor':floor}
def panel(name,x,y,z,w=.45,h=.36,module='F1',facing=1):
 box(name+'board',(x,y,z),(w,h,.025),'wood',False,module)
 box(name+'paper',(x,y,z+facing*.017),(w-.04,h-.04,.008),'paper',False,module,.001)
 for i in range(4):box(name+'ink'+str(i),(x,y+h*.28-i*h*.15,z+facing*.023),(w*.73,.007,.002),'metal',False,module,.001)
def door(name,x,y,z,w=.94,module='core'):
 box(name+'leaf',(x,y+1.06,z),(w,2.12,.055),'wood',True,module,.01)
 for xx in [x-w/2-.034,x+w/2+.034]:box(name+'jamb',(xx,y+1.1,z),(.062,2.2,.16),'metal',False,module)
 box(name+'header',(x,y+2.20,z),(w+.15,.07,.16),'metal',False,module)
 cyl(name+'knob',(x+w*.32,y+1.01,z-.06),.024,.065,'steel',module,(0,0,1))
 box(name+'lock',(x+w*.32,y+.96,z-.038),(.06,.20,.015),'steel',False,module)

# Full enclosed stair core: every real floor reachable, while only story interiors are built.
for f in range(1,18):
 y=(f-1)*3;mod='core';story=f in [1,8,16,17]
 # Corridor floor/ceiling never covers the actual stair void.
 box('F%d_corridor_floor'%f,(-.05,y-.10,0),(3.5,.20,12.6),'tile',True,mod)
 box('F%d_corridor_ceiling'%f,(-.05,y+2.87,0),(3.5,.18,12.6),'ceiling',True,mod)
 for z in [-6.4,6.4]:box('F%d_end'%f,(-.05,y+1.4,z),(3.6,2.8,.20),'wall',True,mod)
 # West wall: story room doorway at z=-1, elevator entrance at z=4.5.
 for z0,z1 in [(-6.3,-1.65),(-.35,3.75),(5.25,6.3)]:
  box('F%d_west'%f,(-1.9,y+1.4,(z0+z1)/2),(.20,2.8,z1-z0),'wall',True,mod)
 for z,w in [(-1,1.3),(4.5,1.5)]:box('F%d_west_lintel'%f,(-1.9,y+2.5,z),(.20,.6,w),'wall',True,mod)
 # Closed unused room doorway still has a real jamb, not a wall pretending to open.
 if not story:box('F%d_closed_room'%f,(-1.9,y+1.08,-1),(.09,2.16,1.26),'metal',True,mod)
 # Stair passage, 1.6m clear opening aligned with full landings.
 for z0,z1 in [(-6.3,3.65),(5.3,6.3)]:box('F%d_east'%f,(1.80,y+1.4,(z0+z1)/2),(.20,2.8,z1-z0),'wall',True,mod)
 box('F%d_stair_header'%f,(1.80,y+2.55,4.475),(.20,.5,1.65),'wall',True,mod)
 # Elevator cabin is closed on three sides and has a ceiling on every served landing.
 box('F%d_lift_floor'%f,(-3.2,y-.1,4.5),(2.4,.2,2.4),'metal',True,mod)
 box('F%d_lift_west'%f,(-4.5,y+1.35,4.5),(.2,2.7,2.6),'metal',True,mod)
 for z in [3.2,5.8]:box('F%d_lift_side'%f,(-3.2,y+1.35,z),(2.6,2.7,.2),'metal',True,mod)
 box('F%d_lift_top'%f,(-3.2,y+2.76,4.5),(2.6,.16,2.6),'ceiling',True,mod)
 # Stair external walls cover every floor without shared horizontal head blockers.
 for x in [5.9]:box('F%d_stair_outer'%f,(x,y+1.5,2.65),(.2,3,6.2),'wall',True,mod)
 for z in [-.5,5.8]:box('F%d_stair_end'%f,(3.85,y+1.5,z),(4.1,3,.2),'wall',True,mod)
 box('F%d_landing'%f,(3.85,y-.1,4.65),(3.9,.2,2.1),'stair',True,mod)
 if f<17:
  box('F%d_half_landing'%f,(3.85,y+1.4,.1),(3.9,.2,1.0),'stair',True,mod)
  # Ten 15cm risers per run. Collision is a matching smooth convex wedge.
  for run,x in [(0,2.85),(1,4.85)]:
   z_start=3.6 if run==0 else .6;z_end=.6 if run==0 else 3.6
   lo=y+run*1.5;hi=lo+1.5
   for i in range(10):
    z=z_start+(z_end-z_start)*(i+.5)/10
    box('F%d_step%d_%d'%(f,run,i),(x,lo+(i+1)*.15-.08,z),(1.55,.16,.30),'stair',False,mod,.008)
    if not white:box('F%d_nosing%d_%d'%(f,run,i),(x,lo+(i+1)*.15+.004,z+(.14 if run==0 else -.14)),(1.53,.008,.035),'metal',False,mod,.001)
   ramps.append({'name':'F%d_Ramp%d'%(f,run),'x0':x-.775,'x1':x+.775,'z0':z_start,'z1':z_end,'y0':lo,'y1':hi,'module':'core'})
   # Continuous handrail, real rods, fixed outside walking capsule clearance.
   if not white:
    for xx in [x-.77,x+.77]:
     line('F%d_rail%d'%(f,run),[(xx,lo+.95,z_start),(xx,hi+.95,z_end)],.021,'metal',mod)
     for t in [0,.5,1]:cyl('Stair baluster',(xx,lo+(hi-lo)*t+.48,z_start+(z_end-z_start)*t),.014,.96,'steel',mod)
 # Stair lamp and vertical riser pipes are outside the walk line.
 if not white:
  box('F%d_lamp'%f,(5.75,y+2.3,4.6),(.09,.10,.48),'light',False,mod)
  cyl('F%d_riser'%f,(5.69,y+1.5,1.0),.043,3,'rust',mod)
  for zz in [-6.20,6.20]:box('F%d_base_end'%f,(-.05,y+.09,zz),(3.45,.18,.03),'metal',False,mod)

# Four story rooms share architecture language, but each has its own lived-in layout.
for f in [1,8,16,17]:
 y=(f-1)*3;mod='F%d'%f
 box(mod+'_room_floor',(-4.0,y-.10,-2.0),(4.0,.20,8.6),'tile',True,mod)
 box(mod+'_room_ceiling',(-4.0,y+2.87,-2.0),(4.0,.18,8.6),'ceiling',True,mod)
 if f!=17:
  wz,ww,wh,wy=(-2.1,1.6,1.25,1.55) if f==1 else (-3.3,1.3,1.05,1.80) if f==8 else (.1,1.0,.65,2.05)
  # Real recessed aperture: segmented solid wall, sealed pane, inset outside return.
  for za,zb in [(-6.4,wz-ww/2),(wz+ww/2,2.35)]:box(mod+'_window_wall',(-6.05,y+1.4,(za+zb)/2),(.2,2.8,zb-za),'wall',True,mod)
  for ya,yb in [(0,wy-wh/2),(wy+wh/2,2.8)]:box(mod+'_window_lintel',(-6.05,y+(ya+yb)/2,wz),(.2,yb-ya,ww),'wall',True,mod)
  box(mod+'_window_glass',(-6.14,y+wy,wz),(.016,wh-.06,ww-.06),'glass',True,mod,.001)
  box(mod+'_night_beyond',(-6.22,y+wy,wz),(.035,wh,ww),'rubber',False,mod,.001)
  for zz in [wz-ww/2,wz,wz+ww/2]:box(mod+'_window_frame',(-6.045,y+wy,zz),(.16,wh+.10,.04),'metal',False,mod)
  for yy in [wy-wh/2,wy+wh/2]:box(mod+'_window_frame',(-6.045,y+yy,wz),(.16,.05,ww+.10),'metal',False,mod)
  box(mod+'_sill',(-5.96,y+wy-wh/2-.04,wz),(.36,.07,ww+.20),'tile',False,mod,.015)
 else:box(mod+'_west',(-6.05,y+1.4,-2),(.2,2.8,8.8),'wall',True,mod)
 for z in [-6.4,2.35]:box(mod+'_side',(-4,y+1.4,z),(4.2,2.8,.2),'wall',True,mod)
 # Layered lower oil paint and projecting base course, fit to actual solid wall.
 if not white:
  box(mod+'_skirting',(-5.935,y+.10,-2),(.035,.20,8.4),'metal',False,mod)
  box(mod+'_paint_band',(-5.932,y+.40,-2),(.012,.70,8.4),'paint',False,mod,.001)
  for z in [-6.28,2.23]:box(mod+'_base',( -4,y+.10,z),(3.9,.20,.035),'metal',False,mod)
  for z in [-4,0]:
   box(mod+'_fixture',(-4,y+2.70,z),(.18,.07,1.0),'metal',False,mod)
   box(mod+'_tube',(-4,y+2.65,z),(.09,.045,.90),'light',False,mod)
  # Surface-mounted conduit, junctions, selective water damage tied to corners.
  line(mod+'_ceiling_conduit',[(-5.87,y+2.66,1.8),(-5.87,y+2.66,-4),(-4,y+2.66,-4)],.011,'metal',mod)
  box(mod+'_junction',(-5.87,y+2.58,1.8),(.055,.14,.14),'metal',False,mod)
  for k in range(3):box(mod+'_corner_repair',(-5.928,y+.85+k*.24,-5.95+k*.10),(.009,.32,.24),'patch',False,mod,.001)
  # Door reveal and threshold remain outside the 1.3m unobstructed opening.
  for zz in [-1.68,-.32]:box(mod+'_door_return',(-1.90,y+1.12,zz),(.26,2.24,.045),'metal',False,mod)
  box(mod+'_door_top',(-1.90,y+2.24,-1),(.26,.045,1.4),'metal',False,mod)
  box(mod+'_threshold',(-1.90,y+.01,-1),(.24,.02,1.28),'tile',False,mod)

# 1F: front desk with open public signing surface, total meter recess and pipe graph.
box('Counter',(-4.85,.5,.65),(1.7,1.0,.65),'wood',True,'F1',.025)
box('CounterTop',(-4.85,1.025,.65),(1.82,.05,.76),'wood',False,'F1',.015)
for i in range(3):
 box('CounterDrawer',(-4.85,.78-i*.24,.31),(1.58,.20,.025),'wood',False,'F1')
 box('CounterPull',(-4.85,.78-i*.24,.28),(.20,.024,.035),'steel',False,'F1')
panel('Register',-4.60,1.06,.23,.46,.32,'F1',-1)
box('MeterRecess',(-5.92,1.33,-3.5),(.12,1.02,1.50),'metal',False,'F1')
for z in [-3.92,-3.5,-3.08]:
 cyl('MeterBody',(-5.72,1.37,z),.105,.16,'metal','F1',(1,0,0),32)
 cyl('MeterFace',(-5.625,1.37,z),.086,.015,'paper','F1',(1,0,0),32)
 cyl('MeterGlass',(-5.609,1.37,z),.081,.005,'glass','F1',(1,0,0),32)
 line('MeterInlet',[(-5.75,.13,z),(-5.75,1.20,z)],.024,'rust','F1')
 line('MeterOutlet',[(-5.75,1.54,z),(-5.75,2.48,z),(-5.75,2.48,z+.3)],.024,'steel','F1')
 for h in [.5,2.1]:box('PipeBracket',(-5.88,h,z),(.12,.05,.05),'metal',False,'F1')
panel('PipeDiagram',-3.15,1.45,-6.26,.9,.68,'F1')
panel('BuildingRegister',-4.45,1.45,-6.26,.72,.68,'F1')
box('DispatchTerminal',(-2.6,.73,-4.7),(.6,1.46,.52),'metal',True,'F1',.025)
box('TerminalScreen',(-2.6,1.31,-4.41),(.42,.27,.02),'glass',False,'F1')
# Intercom with a real perforated front and button row.
box('Intercom',(-2.12,1.38,1.3),(.18,.40,.27),'metal',False,'F1')
for k in range(6):cyl('IntercomButton',(-2.22,1.24+k*.038,1.30),.008,.012,'steel','F1',(1,0,0),12)

# 8F: modest kitchen: used bowl, pot, calendar, note and household rhythm.
y=21
box('KitchenCounter',(-5.48,y+.44,-3.3),(.85,.88,3.0),'wood',True,'F8',.015)
box('KitchenWorktop',(-5.46,y+.91,-3.3),(.93,.06,3.10),'tile',False,'F8')
for z in [-4.35,-3.3,-2.3]:box('KitchenDrawer',(-5.015,y+.55,z),(.025,.52,.91),'wood',False,'F8')
for z in [-3.3,-2.3]:box('KitchenHandle',(-4.98,y+.67,z),(.035,.025,.24),'steel',False,'F8')
cyl('Pot',(-5.4,y+1.03,-3.5),.17,.18,'steel','F8',vertices=32)
cyl('PotLid',(-5.4,y+1.13,-3.5),.18,.025,'steel','F8',vertices=32)
cyl('PotHandle',(-5.4,y+1.17,-3.5),.034,.05,'rubber','F8')
for z in [-3.73,-3.27]:box('PotEar',(-5.4,y+1.07,z),(.11,.035,.08),'rubber',False,'F8')
cyl('UsedBowl',(-5.36,y+.99,-2.5),.105,.085,'paper','F8',vertices=32)
cyl('BowlInterior',(-5.36,y+1.034,-2.5),.081,.006,'metal','F8',vertices=32)
line('Chopstick',[(-5.46,y+1.07,-2.68),(-5.22,y+1.07,-2.29)],.004,'wood','F8')
panel('KitchenCalendar',-4.7,y+1.5,-6.26,.62,.68,'F8')
panel('BorrowedNote',-3.4,y+1.4,-6.26,.40,.29,'F8')
box('KitchenTable',(-3.25,y+.73,.45),(1.0,.07,.70),'wood',True,'F8')
for x in [-3.67,-2.83]:
 for z in [.17,.73]:box('TableLeg',(x,y+.36,z),(.05,.72,.05),'metal',False,'F8')
box('ChairSeat',(-4.3,y+.43,.55),(.42,.045,.42),'wood',True,'F8')
for x in [-4.47,-4.13]:
 for z in [.38,.72]:box('ChairLeg',(x,y+.22,z),(.035,.44,.035),'metal',False,'F8')
box('ChairBack',(-4.3,y+.72,.77),(.42,.43,.035),'wood',False,'F8')

# 16F: storage space was genuinely used as a room; fold cloth and bed frame, no solid-cube bed.
y=45
box('StorageBedFrame',(-5.1,y+.30,-4.6),(1.0,.12,1.95),'metal',True,'F16')
for x in [-5.52,-4.68]:
 for z in [-5.48,-3.72]:cyl('BedFoot',(x,y+.17,z),.023,.34,'metal','F16')
box('Mattress',(-5.1,y+.43,-4.6),(.96,.20,1.90),'cloth',False,'F16',.065)
box('Pillow',(-5.1,y+.575,-5.22),(.66,.10,.36),'cloth',False,'F16',.045)
for i in range(5):box('BlanketFold',(-5.1,y+.56+i*.012,-4.15+i*.025),(.94,.026,.64),'cloth',False,'F16',.01)
box('FoldingDesk',(-3.0,y+.75,-4.5),(1.3,.055,.7),'wood',True,'F16')
for x in [-3.55,-2.45]:
 for z in [-4.76,-4.24]:box('DeskLeg',(x,y+.38,z),(.03,.75,.03),'metal',False,'F16')
box('PayrollFoldedSheet',(-3.1,y+.789,-4.47),(.44,.008,.30),'paper',False,'F16',.001)
box('PayrollBackFold',(-3.1,y+.798,-4.57),(.44,.008,.10),'paper',False,'F16',.001)
for i in range(4):box('PayrollInk',(-3.1,y+.795,-4.36-i*.035),(.30,.002,.004),'metal',False,'F16',.001)
box('Recorder',(-2.65,y+.83,-4.5),(.28,.10,.19),'metal',False,'F16',.008)
for x in [-2.73,-2.57]:cyl('RecorderReel',(x,y+.885,-4.5),.034,.014,'rubber','F16')
cyl('Kettle',(-3.5,y+.88,-4.5),.072,.18,'steel','F16')
line('KettleHandle',[(-3.55,y+.96,-4.5),(-3.65,y+.98,-4.5),(-3.65,y+.86,-4.5),(-3.55,y+.84,-4.5)],.012,'rubber','F16')
# Cloth curtain consists of folded, thin geometry in a plane beside the entrance.
for i in range(12):
 x=-5.72+i*.16;box('CurtainPleat',(x,y+1.2,1.5+(.025 if i%2 else -.025)),(.17,2.30,.04),'cloth',False,'F16',.006)
line('CurtainRod',[(-5.9,y+2.45,1.5),(-3.82,y+2.45,1.5)],.014,'steel','F16')
box('LuggageBase',(-5.15,y+.22,-1.6),(.68,.40,.47),'cloth',True,'F16',.035)
box('LuggageLid',(-5.15,y+.52,-1.82),(.68,.40,.06),'cloth',False,'F16',.025)
for x in [-5.38,-4.92]:box('LuggageStrap',(x,y+.44,-1.59),(.035,.025,.48),'wood',False,'F16')
panel('HospitalReturn',-4.4,y+1.40,-6.26,.56,.38,'F16')
panel('Roster',-3.5,y+1.45,2.22,.64,.52,'F16',-1)
box('StorageShelf',(-5.65,y+1.4,.0),(.52,.045,1.3),'wood',False,'F16')
for i in range(4):box('FoldedSheet',(-5.65,y+1.46+i*.04,.0),(.43,.035,1.02),'cloth',False,'F16',.01)

# 17F: repeated service thresholds, blocked doors with explicit returns, rest corner at end.
y=48
for i,z in enumerate([-4.7,-2.5,-.3,1.9]):
 door('SharedDoor%d'%i,.0,y,z,.86,'F17') if False else None
 # Doors sit on a recessed west wall. They do not cross the central route.
 box('SharedDoor%d'%i,(-1.78,y+1.05,z),(.06,2.10,.88),'wood',False,'F17',.012)
 for zz in [z-.49,z+.49]:box('SharedJamb',(-1.73,y+1.08,zz),(.15,2.16,.055),'metal',False,'F17')
 box('DoorThreshold',(-1.37,y+.02,z),(.6,.04,.95),'tile',False,'F17')
 if i%3==0:
  box('MedicineBag',(-1.36,y+.20,z),(.18,.36,.12),'paper',False,'F17',.02)
  line('BagHandle',[(-1.43,y+.38,z),(-1.43,y+.44,z),(-1.30,y+.44,z),(-1.30,y+.38,z)],.006,'cloth','F17')
 elif i%3==1:
  box('Lunchbox',(-1.3,y+.12,z),(.31,.18,.24),'metal',False,'F17',.035)
  box('LunchboxLid',(-1.3,y+.22,z),(.33,.025,.26),'steel',False,'F17',.01)
 else:
  cyl('LaundryBucket',(-1.3,y+.22,z),.19,.42,'metal','F17',vertices=32)
  cyl('BucketDarkInterior',(-1.3,y+.433,z),.166,.007,'rubber','F17',vertices=32)
 # Exterior call button on corridor side.
 box('SharedBell',(-1.69,y+1.30,z-.61),(.04,.13,.08),'metal',False,'F17')
# Rest corner in the actual storage room footprint, discernible from service corridor.
box('RestBench',(-4.6,y+.42,-4.8),(1.45,.09,.52),'wood',True,'F17')
for x in [-5.18,-4.02]:box('BenchSupport',(x,y+.20,-4.8),(.06,.40,.45),'metal',False,'F17')
box('BedsideTable',(-5.3,y+.35,-3.8),(.42,.70,.42),'wood',True,'F17')
cyl('LampFoot',(-5.3,y+.72,-3.8),.12,.035,'metal','F17')
cyl('LampStem',(-5.3,y+.90,-3.8),.012,.34,'steel','F17')
box('LampShade',(-5.3,y+1.13,-3.8),(.28,.26,.28),'paper',False,'F17',.045)
box('DoorplateHolder',(-5.91,y+1.35,-4.8),(.035,.22,.45),'wood',False,'F17')
# Final branch valve alcove: a stopcock plus readable pipe lines, not an unexplained lever.
for z in [-4.0,-3.3]:
 cyl('BranchPipe',(1.59,y+1.4,z),.032,2.5,'rust','F17')
 for h in [.45,2.3]:box('BranchClamp',(1.65,y+h,z),(.13,.045,.075),'metal',False,'F17')
line('BranchLink',[(1.59,y+1.4,-4),(1.59,y+1.4,-3.3)],.032,'steel','F17')
cyl('ValveSpindle',(1.48,y+1.4,-3.65),.028,.22,'steel','F17',(1,0,0))

anchor('c2_exit',(-.1,1.20,5.95),1.9,'返回回潮镇',1)
anchor('c2_guard',(-4.25,1.2,.2),2.1,'与何伯交谈',1)
anchor('c2_register',(-4.45,1.45,-6.23),1.9,'核对建筑登记',1)
anchor('c2_meter',(-5.50,1.37,-3.5),1.8,'检查总水表',1)
anchor('c2_pipe_map',(-3.15,1.45,-6.23),1.9,'对照管线图',1)
anchor('c2_terminal',(-2.6,1.31,-4.38),1.7,'使用派遣终端',1)
anchor('c2_intercom',(-2.235,1.38,1.3),1.7,'呼叫独立住户',1)
anchor('c2_elevator',(-2.02,1.3,4.1),1.8,'选择楼层',1)
anchor('c2_he_door',(-1.78,22.15,-1),1.8,'征得何伯同意',8)
anchor('c2_calendar',(-4.7,22.5,-6.23),1.8,'检查照护日历',8)
anchor('c2_note',(-3.4,22.4,-6.23),1.8,'借阅送药便条',8)
anchor('c2_storage',(-1.78,46.15,-1),1.8,'查看无门牌储物间',16)
anchor('c2_payroll',(-3.1,45.82,-4.20),1.7,'核对署名工资单',16)
anchor('c2_bed',(-4.8,45.66,-4.3),1.8,'检查生活痕迹',16)
anchor('c2_recorder',(-2.65,45.91,-4.4),1.7,'播放普通留言',16)
anchor('c2_roster',(-3.5,46.45,2.19),1.8,'核对排班顺序',16)
anchor('c2_luggage',(-5.05,45.6,-1.6),1.7,'检查未收完的行李',16)
anchor('c2_hospital',(-4.4,46.4,-6.23),1.8,'检查退回住院单',16)
anchor('c2_corridor',(.0,49.25,3.0),2.0,'观察十七层',17)
anchor('c2_delivery',(-1.38,48.5,-.3),1.8,'核对送物顺序',17)
anchor('c2_sun',(-.65,49.2,-5.4),2.0,'与孙素琴交谈',17)
anchor('c2_valve',(1.35,49.4,-3.65),1.8,'核对支管阀门',17)
anchor('c2_doorplate',(-5.86,49.35,-4.8),1.8,'补回住过的门牌',17)
anchor('c2_rest_corner',(-4.6,49.0,-4.5),2,'确认她可以休息',17)

# Public campaign contract: semantic IDs match the investigation state machine.
for old,new in {'c2_guard':'c2_hebo','c2_meter':'c2_master_meter','c2_terminal':'c2_dispatch',
 'c2_payroll':'c2_wage','c2_roster':'c2_schedule','c2_valve':'c2_valves'}.items():anchors[new]=anchors.pop(old)
anchors.pop('c2_elevator')
for f in [1,8,16,17]:anchor('c2_lift_%d'%f,(-2.02,(f-1)*3+1.3,4.1),1.8,'选择电梯楼层',f)
anchor('c2_porridge',(-5.2,22.1,-3.5),1.8,'检查温粥与用过的碗',8)
anchor('c2_plaque',(-2.08,46.45,-1.75),1.8,'查看储物间旧门牌',16)
anchor('c2_aqi',(.90,1.25,-2.20),1.9,'与阿七核对记录',1)
for id,row in anchors.items():
 p=row['pos'];floor=row['floor'];y=(floor-1)*3+.05
 # All approached surfaces can be seen from standing positions in accessible space.
 if id.startswith('c2_lift'):approach=[-.55,y,4.1]
 elif id in ['c2_exit']:approach=[-.1,y,5.10]
 elif p[0]<-2.0:
  if p[2]<-5.9:approach=[p[0],y,-5.25]
  elif p[0]<-5.3:approach=[-4.35,y,p[2]]
  else:approach=[p[0]+.10,y,p[2]+.85]
 else:approach=[-.30,y,p[2]]
 if id in ['c2_wage','c2_recorder']:approach=[-3.15,y,-3.55]
 if id=='c2_rest_corner':approach=[-4.25,y,-3.60]
 if id=='c2_doorplate':approach=[-4.75,y,-4.65]
 if id=='c2_hebo':approach=[-3.50,y,.10]
 if id=='c2_intercom':approach=[-3.25,y,1.3]
 if id=='c2_hospital':approach=[-4.12,y,-5.25]
 if id=='c2_doorplate':approach=[-5.25,y,-5.75]
 if id=='c2_porridge':approach=[-4.45,y,-3.5]
 if id=='c2_plaque':approach=[-3.0,y,-1.75]
 if id=='c2_bed':approach=[-4.12,y,-3.2]
 if id=='c2_schedule':approach=[-3.5,y,1.25]
 row['approach']=approach

manifest={'version':1,'title':'槐安住宅·第二案','origin':[1200,0,0],'scale':'metres',
 'floors':{str(f):(f-1)*3 for f in range(1,18)},'story_floors':[1,8,16,17],
 'boxes':boxes,'ramps':ramps,'anchors':anchors,'modules':list(modules),
 'floor_spawn':[-.25,.05,4.4],'stair_entry':[2.85,.05,4.5],
 'note':'2—7、9—15层仅封闭公共梯间/候梯间；未制作全户室内。'}
(out/'huaian_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
stage='whitebox' if white else 'finish'
bpy.ops.wm.save_as_mainfile(filepath=str(project/'source_art'/('case2_huaian_whitebox_v1.blend' if white else 'case2_huaian_v1.blend')),compress=True)
# Keep editing objects in the source, export static surfaces joined by module and material.
for module,objects in modules.items():
 bpy.ops.object.select_all(action='DESELECT')
 for o in objects:o.select_set(True)
 bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.convert(target='MESH')
 groups={}
 for o in list(bpy.context.selected_objects):groups.setdefault(o.data.materials[0].name,[]).append(o)
 exports=[]
 for mat,parts in groups.items():
  bpy.ops.object.select_all(action='DESELECT')
  for o in parts:o.select_set(True)
  bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();o=bpy.context.object;o.name=module+'_'+mat;exports.append(o)
 bpy.ops.object.select_all(action='DESELECT')
 for o in exports:o.select_set(True)
 bpy.ops.export_scene.gltf(filepath=str(out/(module+'_'+stage+'.glb')),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_cameras=False,export_lights=False)
print('CASE2_WORLD_OK',stage,json.dumps({'modules':len(modules),'boxes':len(boxes),'ramps':len(ramps),'anchors':len(anchors)}))
