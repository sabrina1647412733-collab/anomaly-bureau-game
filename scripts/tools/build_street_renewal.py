"""Editable Blender street kit -> spatially batched GLBs. Original layout/GLBs stay intact.
Run Blender -b --python this_file -- PROJECT (after prepare_street_renewal.py).
Coordinates in construction helpers are Godot x/up/z; export converts only once.
"""
import bpy, sys, json, math, random
from pathlib import Path
from collections import defaultdict
from mathutils import Vector

ROOT=Path(sys.argv[sys.argv.index('--')+1]); OUT=ROOT/'assets/town/renewal'
PLAN=json.loads((ROOT/'_tools/street_surface_plan.json').read_text(encoding='utf8'))
DATA=json.loads((ROOT/'assets/town/town-layout.json').read_text(encoding='utf8'))
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
GEOM={}; GROUP=(0,0); YAW=0.;CENTER=(0.,0.); TINT=(1,1,1,1)
COLORS={'plaster':(.61,.60,.52,1),'brick':(.43,.29,.23,1),'graybrick':(.4,.43,.42,1),
 'concrete':(.5,.5,.46,1),'wood':(.32,.22,.13,1),'metal':(.26,.29,.28,1),
 'rust':(.36,.22,.13,1),'roof_tile':(.26,.30,.3,1),'roof_metal':(.36,.38,.35,1),
 'glass':(.065,.11,.13,1),'window_warm':(.56,.37,.16,1),'window_cool':(.25,.39,.4,1),
 'trim':(.53,.53,.46,1),'grass':(.22,.27,.13,1),'leaf':(.16,.23,.14,1),
 'cable':(.045,.053,.051,1),'sign':(.14,.23,.24,1),'paper':(.65,.60,.45,1),
 'road':(.42,.42,.4,1),'paving':(.62,.61,.55,1),'ground':(.4,.41,.35,1),
 'puddle':(.11,.16,.17,1),'water':(.10,.17,.17,1),'lamp':(.9,.62,.28,1),'curtain':(.44,.40,.30,1)}
manifest={'version':2,'chunks':[],'props':[],'lights':[],'signs':[],'drips':[],'counts':{},
 'collision':PLAN['surfaces']['collision'],'river_bed':PLAN['surfaces']['river'],'surface_validation':PLAN['validation'],'shop_recesses':[]}

def place(x,z,yaw=0):
 global GROUP,CENTER,YAW
 GROUP=(math.floor(x/32),math.floor(z/32));CENTER=(x,z);YAW=yaw
def point(p):
 x,y,z=p;c=math.cos(YAW);s=math.sin(YAW)
 return (CENTER[0]+x*c+z*s,y,CENTER[1]-x*s+z*c)
def face(mat,verts,faces,color=None,world=False):
 key=(GROUP,mat)
 if key not in GEOM:GEOM[key]=[[],[],[]]
 vv,ff,cc=GEOM[key];base=len(vv)
 for p in verts:
  x,y,z=p if world else point(p);vv.append((x,-z,y));cc.append(color or TINT)
 ff.extend(tuple(base+i for i in f) for f in faces)
def box(mat,at,size,color=None):
 x,y,z=at;a,b,c=[v/2 for v in size]
 vv=[(x+dx*a,y+dy*b,z+dz*c) for dx,dy,dz in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
 face(mat,vv,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(3,7,6,2),(0,4,7,3),(1,2,6,5)],color)
def tube(mat,a,b,r,n=7,r2=None):
 a=Vector(a);b=Vector(b);d=(b-a).normalized();u=d.cross(Vector((0,1,0)))
 if u.length<.1:u=d.cross(Vector((1,0,0)))
 u.normalize();v=d.cross(u);vv=[]
 for p,rad in [(a,r),(b,r if r2 is None else r2)]:
  for j in range(n):vv.append(tuple(p+rad*(u*math.cos(j*math.tau/n)+v*math.sin(j*math.tau/n))))
 faces=[tuple(range(n-1,-1,-1)),tuple(range(n,n*2))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
 face(mat,vv,faces)
def cable(a,b,sag=.45,r=.014):
 prev=a
 for i in range(1,13):
  t=i/12;p=tuple(a[k]*(1-t)+b[k]*t-(math.sin(t*math.pi)*sag if k==1 else 0) for k in range(3))
  tube('cable',prev,p,r,5);prev=p
def roof(w,d,h,kind):
 if kind=='flat':
  box('trim',(0,h+.06,0),(w+.3,.16,d+.3))
  for x in [-w/2,w/2]:box('plaster',(x,h+.31,0),(.18,.45,d+.28))
  for z in [-d/2,d/2]:box('plaster',(0,h+.31,z),(w,.45,.18))
  box('roof_metal',(w*.23,h+.55,-d*.17),(1.4,.7,1.2))
 else:
  peak=h+min(w*.22,1.7);e=d/2+.48;wing=w/2+.45
  for side in [-1,1]:
   face('roof_tile' if kind=='tile' else 'roof_metal',[(0,peak,-e),(side*wing,h+.10,-e),(side*wing,h+.10,e),(0,peak,e)],[(0,1,2,3)] if side<0 else [(3,2,1,0)])
   box('wood',(side*wing,h+.025,0),(.13,.18,d+1.05))
   tube('metal',(side*wing,h-.02,-e),(side*wing,h-.02,e),.065,7)
   for z in [-d/2-.23,d/2+.23]:tube('wood',(0,peak-.12,z),(side*wing,h-.05,z),.075,6)
  for z in [-d/2,d/2]:
   face('plaster',[(-w/2,h,z),(w/2,h,z),(0,peak-.09,z)],[(0,1,2)] if z<0 else [(2,1,0)])
  tube('roof_tile',(0,peak+.03,-e),(0,peak+.03,e),.10,8)
  # Closely spaced seams/tiles give thickness and highlights rather than a flat slab.
  for zi in range(max(2,int(d/.43))):
   z=-d/2+zi*.43
   for side in [-1,1]:tube('roof_tile' if kind=='tile' else 'metal',(0,peak+.015,z),(side*wing,h+.12,z),.023,5)
 # Downpipe is an actual elbow and cylinder, not a painted vertical line.
 x=w/2+.09;z=d/2-.22
 tube('metal',(x,h-.1,z),(x,.22,z),.048,8)
 tube('metal',(x,.22,z),(x+.22,.08,z),.048,8)
 for y in [1.,h*.5,h-.4]:box('rust',(x,y,z),(.13,.045,.13))
 manifest['drips'].append(list(point((x,h-.1,z))))
def window(x,y,z,width=1.05,height=1.35,lit=False,bars=False):
 box('trim',(x,y,z-.025),(width+.22,height+.22,.15))
 box('window_warm' if lit else 'glass',(x,y,z+.065),(width,height,.045))
 for dx in [-width/2,0,width/2]:box('wood',(x+dx,y,z+.12),(.055,height+.09,.07))
 for dy in [-height/2,height/2]:box('wood',(x,y+dy,z+.12),(width+.1,.055,.08))
 box('trim',(x,y-height/2-.08,z+.16),(width+.3,.10,.40))
 if lit:
  # Folded curtain strips in front of frosted glass interrupt a uniform luminous rectangle.
  for side in [-1,1]:
   for k in range(3):
    xx=x+side*(width*.5-.035-k*.045)
    box('curtain',(xx,y,z+.10+k*.002),(.055,height-.025,.018),(1.0-k*.08,1.0-k*.08,.92,1))
  box('curtain',(x,y+height*.43,z+.103),(width,.14,.018))
 if bars:
  for j in range(5):tube('metal',(x-width/2+j*width/4,y-height/2,z+.25),(x-width/2+j*width/4,y+height/2,z+.25),.014,5)
  for yy in [y-height*.35,y+height*.35]:tube('metal',(x-width/2,yy,z+.25),(x+width/2,yy,z+.25),.016,5)
def door(x,z,w=1.05):
 box('trim',(x,1.15,z),(w+.24,2.3,.16))
 box('wood',(x,1.08,z+.09),(w,2.16,.08))
 for yy in [.45,1.08,1.72]:box('wood',(x,yy,z+.145),(w-.12,.48,.055),(.72,.7,.62,1))
 tube('metal',(x+w*.32,.92,z+.21),(x+w*.32,1.12,z+.21),.024,8)
 box('trim',(x,.045,z+.27),(w+.3,.09,.55))
def awning(w,z,y=2.65):
 face('roof_metal',[(-w/2,y,z),(w/2,y,z),(w/2,y-.14,z+.7),(-w/2,y-.14,z+.7)],[(3,2,1,0)])
 for x in [-w/2,w/2]:tube('rust',(x,y-.55,z),(x,y-.14,z+.65),.022,6)
 box('rust',(0,y-.17,z+.71),(w,.1,.05))
def meter(x,y,z):
 box('metal',(x,y,z),(.43,.58,.15));box('glass',(x,y+.1,z+.085),(.22,.2,.025))
 for xx in [x-.12,x+.12]:tube('cable',(xx,y-.3,z),(xx,.15,z),.018,5)
def building(b,special=''):
 global TINT
 x,z=b['x'],b['z'];place(x,z,b.get('rot',0));r=random.Random(b.get('seed',round(x*93+z)))
 w,d,h=b['w'],b['d'],b.get('height',7);floors=max(1,b.get('floors',round(h/3.3)))
 wall=b.get('wall','plaster');wall=wall if wall in COLORS else 'plaster'
 shade=r.uniform(.83,1.10);palette=r.choice([(1.,.98,.92),(.87,.93,.94),(.96,.88,.73),(.80,.87,.83)])
 TINT=(shade*palette[0],shade*palette[1],shade*palette[2],1)
 if special=='laundry':h=15.8;floors=5 # Facade reflects the established F2 shop and upper story route.
 recess=b.get('seed') in [551335,469787]
 if recess:
  opening=1.6;depth=1.65
  box(wall,(0,h/2,-depth/2),(w,h,d-depth))
  for side in [-1,1]:box(wall,(side*(w/4+opening/4),h/2,d/2-depth/2),((w-opening)/2,h,depth))
  box(wall,(0,(h+2.3)/2,d/2-.10),(opening,h-2.3,.2))
  box('paving',(0,.02,d/2-depth/2),(opening,.04,depth))
  # A visible counter bounds the small vestibule; back wall is a real occluder.
  box('wood',(0,.42,d/2-1.28),(opening-.12,.84,.42))
  manifest['props'].append({'at':list(point((0,.42,d/2-1.28))),'size':[opening-.12,.84,.42],'yaw':b.get('rot',0)})
  for yy in [1.,1.45,1.90]:
   box('wood',(0,yy,d/2-1.5),(opening-.12,.055,.24))
   for k in range(4):box('paper',(-.52+k*.34,yy+.13,d/2-1.49),(.21,.25,.18),(.5,.45,.3,1))
  manifest['shop_recesses'].append({'seed':b['seed'],'depth':depth,'opening':opening})
 else:
  box(wall,(0,h/2,0),(w,h,d));box('graybrick',(0,.32,0),(w+.05,.64,d+.05))
 for level in range(1,floors):box('trim',(0,level*h/floors,0),(w+.12,.12,d+.12))
 if b.get('kind')=='annex':
  # Low weathered lean-to roof, with a narrow overhang inside the clearance mask.
  face('roof_metal',[(-w/2-.08,h+.14,-d/2-.08),(w/2+.08,h+.14,-d/2-.08),(w/2+.08,h-.02,d/2+.08),(-w/2-.08,h-.02,d/2+.08)],[(3,2,1,0)])
  for xx in [-w/2,w/2]:tube('metal',(xx,h,-d/2),(xx,h-.07,d/2),.025,6)
 else:roof(w,d,h,b.get('roof','tile'))
 if b.get('roof')=='flat' and b.get('rooftop')=='tank':
  tx=-w*.23;tz=-d*.17
  for xx in [tx-.35,tx+.35]:tube('rust',(xx,h+.1,tz),(xx,h+1.0,tz),.032,6)
  tube('metal',(tx,h+.8,tz),(tx,h+1.7,tz),.48,14)
  tube('metal',(tx+.4,h+1.,tz),(tx+.65,h+.9,tz+.15),.04,6)
 elif b.get('roof')=='flat' and b.get('rooftop')=='solar':
  face('glass',[(-1.1,h+.3,-.7),(1.1,h+.3,-.7),(1.1,h+.95,.5),(-1.1,h+.95,.5)],[(0,1,2,3)])
  for xx in [-1.1,-.55,0,.55,1.1]:tube('metal',(xx,h+.3,-.7),(xx,h+.95,.5),.018,5)
  for xx in [-1.05,1.05]:tube('metal',(xx,h+.1,.5),(xx,h+.95,.5),.024,6)
 bays=max(2,int(w/2.65));step=w/bays;front=d/2+.055
 for f in range(floors):
  y=f*h/floors+1.65
  for k in range(bays):
   xx=-w/2+step*(k+.5)
   if f==0 and abs(xx)<step*.62:continue
   window(xx,y,front,min(1.45,step*.64),1.3,r.random()<(.46 if special else .19),f==0 or r.random()<.25)
   if r.random()<.12 and f>0:
    box('metal',(xx+.65,y-.65,front+.27),(.6,.43,.5))
    for j in range(5):box('cable',(xx+.65,y-.8+j*.065,front+.53),(.48,.018,.014))
  # Complete rear facade; sides use the same window kit, rotated to their wall.
  rear_bays=1 if b.get('kind')=='annex' else max(2,bays//2)
  for k in range(rear_bays):
   xx=0 if rear_bays==1 else -w*.36+k*(w*.72/max(1,bays//2-1));old=YAW
   # Back windows are built by temporarily rotating the coordinate system around this building.
   place(x,z,b.get('rot',0)+math.pi);window(xx,y,d/2+.055,min(1.,w-.6),1.15,r.random()<.12)
   place(x,z,b.get('rot',0))
  for side in [-1,1]:
   place(x,z,b.get('rot',0)+side*math.pi/2)
   for zz in ([0.] if b.get('kind')=='annex' else [-d*.27,d*.27]):window(zz,y,w/2+.055,min(.85,d-.6),1.1,r.random()<.1,f==0)
   place(x,z,b.get('rot',0))
 if recess:
  # Open shutter leaf has thickness and stays against the side jamb, not across
  # the walkway. Its opening is backed by the actual lit shop vestibule above.
  box('metal',(-.84,1.08,front-.42),(.10,2.16,.90))
  for yy in [.18+i*.12 for i in range(16)]:box('rust',(-.90,yy,front-.42),(.018,.035,.85))
  for xx in [-.84,.84]:box('trim',(xx,1.15,front),(.10,2.3,.18))
  box('trim',(0,2.3,front),(1.78,.12,.18))
  manifest['lights'].append({'position':list(point((0,2.0,front-.55))),'color':'efd2a2','energy':.75,'range':3.5})
 else:door(0,front,1.3 if special else 1.0)
 awning(min(w*.72,4.4),front,min(2.7,h-.05))
 if b.get('shop') and not special:
  box('sign',(0,2.98,front+.15),(max(2.,w-.45),.58,.12))
  index=int(b.get('sign',0))%len(DATA['signs'])
  manifest['signs'].append({'text':DATA['signs'][index],'position':list(point((0,2.98,front+.22))),
   'yaw':b.get('rot',0),'size':.09})
 # Tiny service annexes share their parent building's meter; a front meter would
 # overlap the door on the narrowest 1.8m facade.
 if b.get('kind')!='annex':meter(min(w/2-.6,1.5),1.55,front+.15)
 # Localized contact staining as thin wall panels; never a full checkerboard overlay.
 for k in range(max(2,int(w/2))):
  xx=r.uniform(-w*.46,w*.46);hh=r.uniform(.16,.54)
  sw=r.uniform(.3,1.2);left=max(-w/2,xx-sw/2);right=min(w/2,xx+sw/2)
  spans=[(left,right)] if not recess else [(left,min(right,-opening/2-.06)),(max(left,opening/2+.06),right)]
  for start,end in spans:
   if end-start>.01:box('stain',((start+end)/2,hh/2,front+.006),(end-start,hh,.008),(.32,.36,.24,1))
 if r.random()<.40 and b.get('kind')!='annex':
  xx=-w*.29
  box('metal',(xx,h/floors+ .3,front+.45),(1.7,.1,.9))
  for k in range(8):tube('metal',(xx-.8+k*.23,h/floors+.36,front+.88),(xx-.8+k*.23,h/floors+1.18,front+.88),.014,5)
  tube('metal',(xx-.85,h/floors+1.2,front+.88),(xx+.85,h/floors+1.2,front+.88),.025,6)
 # Simple flowerpot, broom and bucket remain against the wall, outside the entrance clear width.
 if w>5:
  xx=w*.37;tube('rust',(xx,.05,front+.32),(xx,.35,front+.32),.18,10,r2=.23)
  for k in range(7):
   a=k*math.tau/7;tube('grass',(xx,.3,front+.32),(xx+math.sin(a)*.24,.65+r.random()*.2,front+.32+math.cos(a)*.24),.015,4,r2=.002)
  tube('wood',(-w*.36,.03,front+.37),(-w*.36-.18,1.35,front+.14),.018,6)
  box('grass',(-w*.36,.13,front+.4),(.25,.22,.08))
 if special:
  sy=5.5 if special=='laundry' else 3.1
  box('sign',(0,sy,front+.21),(7.1 if special=='laundry' else 4.5,.85,.16))
  manifest['signs'].append({'text':'得利洗衣店  ·  二楼' if special=='laundry' else '出租公寓',
   'position':list(point((0,sy,front+.315))),'yaw':b.get('rot',0),'size':.15 if special=='laundry' else .11})
  manifest['lights'].append({'position':list(point((0,2.6,front+1.0))),'color':'edc587','energy':1.5,'range':8.})
 TINT=(1,1,1,1)

# Non-overlapping road/sidewalk junctions. Triangulated from polygons with river holes.
for kind,tris in PLAN['surfaces'].items():
 if kind in ['collision','puddles']:continue
 mat={'river':'water','puddles':'puddle'}.get(kind,kind)
 y={'ground':-.024,'paving':.035,'road':0.,'river':-.42,'puddles':.006}[kind]
 for tri in tris:
  place(sum(p[0] for p in tri)/3,sum(p[1] for p in tri)/3)
  vv=[(p[0],y,p[1]) for p in tri]
  # Ensure upward normal after Godot-to-Blender conversion.
  if (vv[1][0]-vv[0][0])*(vv[2][2]-vv[0][2])-(vv[1][2]-vv[0][2])*(vv[2][0]-vv[0][0])>0:vv.reverse()
  face(mat,vv,[(0,1,2)],world=True)
for puddle in PLAN.get('puddle_regions',[]):
 cx,cz=puddle['center'];edge=puddle['edge'];place(cx,cz)
 # Inner fan plus alpha feather ring. Every edge fades back into the same road.
 count=len(edge);verts=[(cx,.008,cz)]
 verts.extend((cx+(x-cx)*.70,.008,cz+(z-cz)*.70) for x,z in edge)
 verts.extend((x,.008,z) for x,z in edge)
 ff=[]
 for i in range(count):
  j=(i+1)%count;ff.extend([(0,i+1,j+1),(i+1,count+i+1,count+j+1,j+1)])
 key=(GROUP,'puddle')
 if key not in GEOM:GEOM[key]=[[],[],[]]
 vv,faces,cc=GEOM[key];base=len(vv)
 vv.extend((x,-z,y) for x,y,z in verts);faces.extend(tuple(base+j for j in f) for f in ff)
 cc.extend([(1,1,1,1)]*(count+1)+[(1,1,1,0)]*count)
for b in DATA['buildings']+PLAN['infill']:building(b)
for b in DATA['landmarks']:
 if b['id'] in ['01','02']:building(b,'laundry' if b['id']=='01' else 'apartment')

# Existing boundary walls keep their full thickness/caps. Rail corridor is not a driveable road.
for wall in DATA['walls']:
 a=wall['a'];b=wall['b'];x,z=a[0],a[-1];xx,zz=b[0],b[-1];length=math.hypot(xx-x,zz-z);h=wall.get('h',2.)
 place((x+xx)/2,(z+zz)/2,math.atan2(xx-x,zz-z))
 box('graybrick',(0,h/2,0),(.18,h,length));box('trim',(0,h+.035,0),(.25,.07,length+.08))
rail=DATA['railway']['points']
for a,b in zip(rail[:-1],rail[1:]):
 x,z=a[0],a[-1];xx,zz=b[0],b[-1];length=math.hypot(xx-x,zz-z)
 place((x+xx)/2,(z+zz)/2,math.atan2(xx-x,zz-z))
 for side in [-1,1]:box('rust',(side*.72,.075,0),(.065,.15,length))
 for j in range(int(length/.7)+1):box('wood',(0,.01,-length/2+j*.7),(2.1,.09,.18))

# Drain grates, utility covers and small scraps follow the road edge, leaving its centre clear.
for i,road in enumerate(DATA['roads']):
 pts=road['points'];r=random.Random(i+184);width=road['width']
 for j in range(3,len(pts)-1,11):
  x,z=pts[j];xx,zz=pts[j+1];yaw=math.atan2(xx-x,zz-z)
  place(x,z,yaw);side=1 if j%2 else -1;offset=side*(width/2-.25)
  box('metal',(offset,.018,0),(.36,.03,.68))
  for k in range(8):box('cable',(offset,.036,-.28+k*.08),(.27,.008,.037))
  if j%3==0:
   box('metal',(0,.01,1.1),(.62,.02,.72));box('cable',(0,.022,1.1),(.53,.005,.63))
   for zz2 in [.88,1.,1.12,1.24]:box('rust',(0,.03,zz2),(.49,.012,.023))
  if r.random()<.45:box('paper',(-offset,.015,r.uniform(-.4,.4)),(.17,.004,.23),(.7,.7,.58,1))

# River banks and three bridge decks; stable collision is generated from the same bridge polygons.
points=DATA['river']['points'];rw=DATA['river'].get('width',11)/2
for a,b in zip(points[:-1],points[1:]):
 x,z=a[0],a[-1];xx,zz=b[0],b[-1];yaw=math.atan2(xx-x,zz-z);length=math.hypot(xx-x,zz-z)
 place((x+xx)/2,(z+zz)/2,yaw)
 for side in [-1,1]:box('graybrick',(side*(rw+.16),-.49,0),(.32,1.1,length+.1))
for b in DATA['bridges']:
 a=b['from'];end=b['to'];x,z=a[0],a[-1];xx,zz=end[0],end[-1];length=math.hypot(xx-x,zz-z);width=b['width']
 place((x+xx)/2,(z+zz)/2,math.atan2(xx-x,zz-z))
 box('paving',(0,-.08,0),(width,.16,length))
 for side in [-1,1]:
  for k in range(int(length/1.8)+1):tube('metal',(side*width/2,0,-length/2+k*1.8),(side*width/2,1.05,-length/2+k*1.8),.035,7)
  tube('metal',(side*width/2,1.05,-length/2),(side*width/2,1.05,length/2),.035,7)

# Tapered, leaning poles, insulators and visibly sagging wire bundles.
pole_ends=[]
for i,p in enumerate(DATA['poles']):
 place(p['x'],p['z'],p.get('rot',0));h=p['h'];lean=p.get('tilt',0)*h
 tube('concrete',(0,0,0),(lean,h,0),.13,10,r2=.085)
 box('metal',(lean,h-.55,0),(1.3,.075,.09))
 for x in [-.52,0,.52]:tube('paper',(lean+x,h-.55,0),(lean+x,h-.3,0),.055,8)
 if i%3==0:meter(.1,1.6,.14)
 pole_ends.append(point((lean,h-.3,0)))
 manifest['props'].append({'at':[p['x'],h/2,p['z']],'size':[.32,h,.32],'yaw':0})
for a,b in DATA['wires']:
 start=pole_ends[a];end=pole_ends[b];place((start[0]+end[0])/2,(start[2]+end[2])/2)
 for offset in [-.18,.18]:
  aa=(start[0]-CENTER[0]+offset,start[1],start[2]-CENTER[1]);bb=(end[0]-CENTER[0]+offset,end[1],end[2]-CENTER[1])
  cable(aa,bb,min(1.4,math.dist(start,end)*.035))
for p in DATA['serviceWires']:
 a=p['a'];b=p['b'];place((a[0]+b[0])/2,(a[2]+b[2])/2)
 cable((a[0]-CENTER[0],a[1],a[2]-CENTER[1]),(b[0]-CENTER[0],b[1],b[2]-CENTER[1]),.5,.011)

for p in DATA['lamps']:
 place(p['x'],p['z'],p.get('rot',0));h=p.get('h',4.3)
 tube('metal',(0,0,0),(0,h,0),.065,9);tube('metal',(0,h,0),(.5,h-.05,0),.045,7)
 box('metal',(.53,h-.12,0),(.48,.15,.29));box('lamp',(.53,h-.21,0),(.37,.025,.23))
 manifest['lights'].append({'position':list(point((.53,h-.30,0))),'color':'edb678','energy':1.7,'range':10.})

# Ground props have corresponding hard collision. Small wall dressing doesn't block walking.
for i,p in enumerate(DATA['props']):
 place(p['x'],p['z'],p.get('rot',0));kind=p['kind'];w=p.get('w',.7);d=p.get('d',.5)
 if kind=='utilitybox':
  box('concrete',(0,.12,0),(w+.15,.24,d+.15));box('metal',(0,.85,0),(w,1.45,d))
  box('metal',(0,.86,d/2+.025),(w-.10,1.27,.04))
  for yy in [.35,.42,.49,.56]:box('cable',(0,yy,d/2+.05),(w*.65,.018,.018))
  box('paper',(0,1.2,d/2+.055),(.19,.19,.008));tube('metal',(w*.32,.8,d/2+.08),(w*.32,1.,d/2+.08),.013,6)
  for xx in [-w*.25,w*.25]:tube('cable',(xx,.25,-d/2),(xx,.02,-d/2-.1),.024,6)
  height=1.58
 elif kind=='bench':
  w=max(w,1.6);d=.48;height=.93
  for j in range(4):box('wood',(0,.46,-.19+j*.125),(w,.045,.1))
  for j in range(3):box('wood',(0,.66+j*.12,-.25),(w,.09,.035))
  for xx in [-w*.37,w*.37]:
   tube('metal',(xx,.02,-.19),(xx,.89,-.25),.035,7);tube('metal',(xx,.02,.2),(xx,.48,.2),.035,7)
 elif kind in ['bike','scooter']:
  w=.55;d=1.7;height=1.1
  # Open wheel rings, frame triangles and handlebar, unlike solid placeholder blocks.
  for zz in [-.59,.59]:
   for j in range(18):
    a=j*math.tau/18;b=(j+1)*math.tau/18
    tube('cable',(0,.33+math.sin(a)*.29,zz+math.cos(a)*.29),(0,.33+math.sin(b)*.29,zz+math.cos(b)*.29),.025,5)
   for j in range(8):
    a=j*math.tau/8;tube('metal',(0,.33,zz),(0,.33+math.sin(a)*.27,zz+math.cos(a)*.27),.006,4)
  for a,b in [((0,.33,-.59),(0,.8,-.17)),((0,.8,-.17),(0,.34,.1)),((0,.34,.1),(0,.33,-.59)),((0,.8,-.17),(0,.8,.4)),((0,.8,.4),(0,.34,.1)),((0,.33,.59),(0,1.,.38))]:tube('metal',a,b,.027,7)
  tube('metal',(-.25,1.,.38),(.25,1.,.38),.025,7);box('wood',(0,.86,-.17),(.25,.07,.32))
  if kind=='scooter':box('metal',(0,.52,0),(.39,.36,.7))
 else:
  height=.85 if kind=='bin' else .55
  box('metal' if kind=='bin' else 'wood',(0,height/2,0),(w,height,d))
  for yy in [.12,height-.1]:box('metal',(0,yy,d/2+.015),(w+.02,.035,.025))
 manifest['props'].append({'at':[p['x'],height/2,p['z']],'size':[w,height,d],'yaw':p.get('rot',0)})

# Branch structure with individual tapered leaf blades; no primitive spherical crowns.
for i,t in enumerate(DATA['trees']):
 place(t['x'],t['z']);r=random.Random(t.get('seed',i));s=t.get('s',1);h=3.4*s
 tube('wood',(0,0,0),(.13*s,h,0),.16*s,9,r2=.055*s)
 for k in range(7):
  a=k*2.4;end=(math.cos(a)*1.0*s,h+r.uniform(-.2,.9)*s,math.sin(a)*s)
  tube('wood',(.08*s,h*.65,0),end,.052*s,6,r2=.014*s)
  for j in range(28):
   x=end[0]+r.uniform(-.9,.9)*s;y=end[1]+r.uniform(-.45,.55)*s;z=end[2]+r.uniform(-.9,.9)*s;sz=r.uniform(.14,.27)*s
   angle=r.random()*math.tau;dx=math.sin(angle)*sz;dz=math.cos(angle)*sz
   face('leaf',[(x-dx,y,z-dz),(x-dz*.45,y+.10*s,z+dx*.45),(x+dx,y,z+dz),(x+dz*.45,y-.025*s,z-dx*.45)],[(0,1,2,3)],(r.uniform(.7,1.15),r.uniform(.8,1.12),.8,1))
for x,z,s,seed in PLAN['grass']:
 place(x,z);r=random.Random(seed)
 for k in range(8):
  a=k*2.4;dx=math.cos(a)*s*.5;dz=math.sin(a)*s*.5;xx=r.uniform(-.08,.08);zz=r.uniform(-.08,.08)
  face('grass',[(xx-.018,.015,zz),(xx+.018,.015,zz),(xx+dx,.02+s*r.uniform(.6,1.1),zz+dz)],[(0,1,2)],(.8,r.uniform(.8,1.2),.75,1))

# Export chunks. Material names/nodes are a stable runtime contract for shared PBR overrides.
materials={}
for mat in set(k[1] for k in GEOM):
 m=bpy.data.materials.new(mat);m.diffuse_color=COLORS.get(mat,(.35,.38,.32,1));m.use_nodes=True
 bsdf=m.node_tree.nodes.get('Principled BSDF');bsdf.inputs['Base Color'].default_value=m.diffuse_color;bsdf.inputs['Roughness'].default_value=.8
 materials[mat]=m
chunks=defaultdict(list);vertices=0;faces_count=0
for (chunk,kind),(verts,faces,colors) in GEOM.items():
 mesh=bpy.data.meshes.new(kind);mesh.from_pydata(verts,[],faces);mesh.materials.append(materials[kind]);mesh.update()
 col=mesh.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='POINT')
 flat=[v for c in colors for v in c];col.data.foreach_set('color',flat)
 obj=bpy.data.objects.new(kind,mesh);bpy.context.collection.objects.link(obj);chunks[chunk].append(obj)
 vertices+=len(verts);faces_count+=len(faces)
modeldir=OUT/'models';modeldir.mkdir(exist_ok=True,parents=True)
for chunk,objects in sorted(chunks.items()):
 bpy.ops.object.select_all(action='DESELECT')
 for obj in objects:obj.select_set(True)
 filename='street_%d_%d.glb'%chunk
 bpy.ops.export_scene.gltf(filepath=str(modeldir/filename),export_format='GLB',use_selection=True,
  export_yup=True,export_texcoords=False,export_normals=True,export_vertex_color='ACTIVE',export_all_vertex_colors=True,export_materials='EXPORT',export_cameras=False,export_lights=False)
 manifest['chunks'].append('res://assets/town/renewal/models/'+filename)
manifest['counts']={'buildings':len(DATA['buildings'])+len(PLAN['infill']), 'grass_tufts':len(PLAN['grass']),
 'vertices':vertices,'polygons':faces_count,'chunks':len(chunks),'poles':len(DATA['poles']),'trees':len(DATA['trees'])}
(OUT/'street_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,separators=(',',':')),encoding='utf8')
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'source_art/huichao_street_v2.blend'),compress=True)
print('STREET_BUILT',manifest['counts'],flush=True)
