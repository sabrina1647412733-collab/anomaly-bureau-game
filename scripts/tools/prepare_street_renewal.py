"""Make non-overlapping street surfaces and deterministic, clearance-tested infill.
Usage: python prepare_street_renewal.py PROJECT [SHAPELY_SITE_PACKAGES]
Only the generated renewal data is written; the supplied town-layout.json is kept.
"""
import json, math, random, sys
from pathlib import Path
if len(sys.argv) > 2:
    sys.path.insert(0, sys.argv[2])
from shapely import constrained_delaunay_triangles
from shapely.geometry import Polygon, LineString, Point, box
from shapely.ops import unary_union, nearest_points
from shapely.affinity import rotate, translate

root = Path(sys.argv[1]); output = root/'assets/town/renewal'
output.mkdir(parents=True, exist_ok=True)
data = json.loads((root/'assets/town/town-layout.json').read_text(encoding='utf8'))
rng = random.Random(18420261023)

def footprint(b, margin=0):
    shape = box(-b['w']/2-margin, -b['d']/2-margin, b['w']/2+margin, b['d']/2+margin)
    return translate(rotate(shape, -math.degrees(b.get('rot', 0)), origin=(0, 0)), b['x'], b['z'])

roads = [(r, LineString(r['points'])) for r in data['roads']]
road = unary_union([line.buffer(r['width']/2, quad_segs=3) for r,line in roads]).buffer(0)
river_line = LineString(data['river']['points'])
river = river_line.buffer(data['river']['width']/2, quad_segs=4)
bridge_shapes = []
for bridge in data['bridges']:
    bridge_shapes.append(LineString([bridge['from'], bridge['to']]).buffer(bridge['width']/2, cap_style='square'))
bridges = unary_union(bridge_shapes)
terrain = box(-15,-15,315,255).difference(river.difference(bridges))
existing = [footprint(b) for b in data['buildings']]
existing += [footprint(b) for b in data['landmarks'] if b['id'] not in ['04','08']]
occupied = unary_union(existing)
access = []
for b in data['landmarks']:
    front=Point(b['front'])
    nearest=nearest_points(front,road)[1]
    access.append(LineString([front,nearest]).buffer(1.4))
    access.append(front.buffer(1.7))
access = unary_union(access)
rail = LineString([(p[0],p[-1]) for p in data['railway']['points']]).buffer(6.0)
protected = unary_union([road.buffer(.55),river.buffer(1.3),access,rail])
infill = []
candidates = []
for r,line in roads:
    for k in range(8,int(line.length),7):
        p=line.interpolate(k); before=line.interpolate(max(0,k-.2));after=line.interpolate(min(line.length,k+.2))
        tangent=(after.x-before.x, after.y-before.y)
        length=math.hypot(*tangent)
        if length<.01:continue
        normal=(-tangent[1]/length,tangent[0]/length)
        for side in [-1,1]:
            candidates.append((0 if 123<p.x<194 and 80<p.y<147 else 1,r,p,normal,side))
candidates.sort(key=lambda x:x[0])
for priority,r,p,n,side in candidates:
    if len(infill)>=32:break
    if priority==0 and sum(1 for b in infill if b['district']=='first_case')>=12:continue
    w=rng.uniform(3.5,5.6);d=rng.uniform(3.3,4.9)
    distance=r['width']/2+d/2+rng.uniform(.7,1.2)
    x=p.x+n[0]*distance*side;z=p.y+n[1]*distance*side
    if not (4<x<296 and 6<z<233):continue
    yaw=math.atan2(p.x-x,p.y-z)
    b={'id':'fill_%03d'%(len(infill)+1),'x':round(x,3),'z':round(z,3),'w':round(w,3),'d':round(d,3),
       'rot':round(yaw,5),'height':6.35 if rng.random()<.55 else 3.25,'floors':2 if rng.random()<.55 else 1,
       'wall':rng.choice(['plaster','brick','graybrick']),'roof':rng.choice(['tile','metal','flat']),
       'seed':rng.randrange(999999),'kind':'house','shop':0,'district':'first_case' if priority==0 else 'town'}
    b['floors']=2 if b['height']>4 else 1
    shape=footprint(b)
    if shape.buffer(.75).intersects(occupied) or shape.intersects(protected):continue
    b['fx']=round(x+math.sin(yaw)*d/2,3);b['fz']=round(z+math.cos(yaw)*d/2,3)
    infill.append(b);occupied=unary_union([occupied,shape])

# Low service annexes compact the first-case street without turning access alleys
# into blocked building plots. Their smaller roof overhang is authored separately.
wall_buffer=unary_union([LineString([w['a'],w['b']]).buffer(.25) for w in data['walls']])
shop_clearance=unary_union([Point(b['fx'],b['fz']).buffer(1.8) for b in data['buildings'] if b.get('shop')])
annex_candidates=[]
for r,line in roads:
    for k in range(4,int(line.length),4):
        p=line.interpolate(k)
        if not (127<p.x<188 and 86<p.y<141):continue
        before=line.interpolate(max(0,k-.2));after=line.interpolate(min(line.length,k+.2))
        length=math.hypot(after.x-before.x,after.y-before.y)
        if length<.01:continue
        nx=-(after.y-before.y)/length;nz=(after.x-before.x)/length
        for side in [-1,1]:
            for extra in [1.8,3.1,4.4]:annex_candidates.append((r,p,nx,nz,side,extra))
annex_count=0
for r,p,nx,nz,side,extra in annex_candidates:
    if annex_count>=12:break
    w=rng.uniform(1.8,3.1);d=rng.uniform(1.9,3.0);distance=r['width']/2+extra
    x=p.x+nx*distance*side;z=p.y+nz*distance*side;yaw=math.atan2(p.x-x,p.y-z)
    b={'id':'annex_%02d'%(annex_count+1),'x':round(x,3),'z':round(z,3),'w':round(w,3),'d':round(d,3),'rot':round(yaw,5),
       'height':round(rng.uniform(2.35,2.7),3),'floors':1,'wall':rng.choice(['brick','plaster','graybrick']),
       'roof':'metal','seed':rng.randrange(999999),'kind':'annex','shop':0,'district':'first_case'}
    shape=footprint(b)
    if shape.buffer(.20).intersects(occupied) or shape.intersects(unary_union([protected,wall_buffer,shop_clearance])):continue
    b['fx']=round(x+math.sin(yaw)*d/2,3);b['fz']=round(z+math.cos(yaw)*d/2,3)
    infill.append(b);occupied=unary_union([occupied,shape]);annex_count+=1

# Partition surfaces so road junctions and the old road/sidewalk planes cannot z-fight.
road_surface=road.intersection(terrain).difference(occupied.buffer(.02))
paving=unary_union([road.buffer(.65).difference(road),access]).intersection(terrain).difference(occupied.buffer(.02)).difference(road_surface)
bare=terrain.difference(unary_union([road_surface,paving]))

def triangles(shape):
    result=[]
    parts=list(shape.geoms) if hasattr(shape,'geoms') else [shape]
    for part in parts:
        if part.geom_type!='Polygon' or part.area<.0001:continue
        for tri in constrained_delaunay_triangles(part).geoms:
            result.append([[round(x,4),round(y,4)] for x,y in list(tri.exterior.coords)[:3]])
    return result

surfaces={'ground':triangles(bare),'road':triangles(road_surface),'paving':triangles(paving),
          'collision':triangles(terrain),'river':triangles(river.intersection(box(-15,-15,315,255)).difference(bridges))}

# Sparse wall-joint vegetation. The height/root plane comes from the same
# partition as the visible paving; no floating grass on a guessed global y=0.
# Most trafficked door strips stay clean, while shaded side/back joints can grow.
grass=[];vegetation=[]
for i,b in enumerate(data['buildings']+infill):
    local=random.Random(b.get('seed',i+13))
    for k in range(local.randint(2,4)):
        side=local.randrange(4);a=local.uniform(-.46,.46)
        if side<2:lx=(b['w']/2+.10)*(1 if side==0 else -1);lz=a*b['d']
        else:lx=a*b['w'];lz=(b['d']/2+.10)*(1 if side==2 else -1)
        if side==2 and (abs(lx)<.95 or local.random()<.58):continue
        # These three frontages have deliberately authored foreground plants.
        if side==2 and b.get('seed') in [579349,551335,993505]:continue
        yaw=b.get('rot',0);x=b['x']+lx*math.cos(yaw)+lz*math.sin(yaw);z=b['z']-lx*math.sin(yaw)+lz*math.cos(yaw)
        point=Point(x,z)
        if road.buffer(.16).contains(point) or river.contains(point) or access.contains(point):continue
        height=round(local.uniform(.055,.145),3);seed=local.randrange(99999)
        on_paving=paving.contains(point)
        root_y=.0355 if on_paving else -.0235
        species=local.choices(['crabgrass','plantain','clover'],[6,3,2])[0]
        grass.append([round(x,3),round(z,3),height,seed])
        vegetation.append({'x':round(x,3),'z':round(z,3),'root_y':root_y,
                           'height':height,'seed':seed,'species':species,
                           'surface':'paving' if on_paving else 'ground',
                           'anchor_seed':b.get('seed',0),'collision':False})

puddles=[];puddle_regions=[]
for i,(r,line) in enumerate(roads):
    for k in range(5,int(line.length),13):
        p=line.interpolate(k)
        blob=Point(p.x+rng.uniform(-.5,.5),p.y+rng.uniform(-.5,.5)).buffer(rng.uniform(.3,.9),quad_segs=6)
        blob=blob.intersection(road_surface)
        if blob.area>.12:
            puddles.extend(triangles(blob))
            parts=list(blob.geoms) if hasattr(blob,'geoms') else [blob]
            for part in parts:
                if part.geom_type!='Polygon' or part.area<.05:continue
                center=part.representative_point()
                puddle_regions.append({'center':[center.x,center.y],'edge':[list(p) for p in list(part.exterior.coords)[:-1]]})
surfaces['puddles']=puddles

out={'version':2,'source':'town-layout.json preserved','seed':18420261023,'infill':infill,
     'surfaces':surfaces,'puddle_regions':puddle_regions,'grass':grass,'protected_fronts':[b['front'] for b in data['landmarks']],
     'vegetation':vegetation,'vegetation_policy':{'version':2,'root_planes':{'paving':.0355,'ground':-.0235},
         'traffic_strip_kept_clear':True,'maximum_tuft_height_m':.167,'collision':False},
     'validation':{'road_overlap_area':round(road_surface.intersection(paving).area,9),
                   'infill_count':len(infill),'annex_count':annex_count,'grass_count':len(grass),
                   'infill_over_road':sum(footprint(b).intersection(road).area for b in infill)}}
(output/'layout_additions.json').write_text(json.dumps({k:v for k,v in out.items() if k not in ['surfaces','puddle_regions']},ensure_ascii=False,indent=2),encoding='utf8')
plan=root/'_tools/street_surface_plan.json'
plan.write_text(json.dumps(out,ensure_ascii=False,separators=(',',':')),encoding='utf8')
print('STREET_PLAN',json.dumps(out['validation']),{k:len(v) for k,v in surfaces.items()})
