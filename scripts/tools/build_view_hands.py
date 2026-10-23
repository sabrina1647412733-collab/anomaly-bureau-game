"""Build independent view hands from the CC0 MakeHuman neutral topology, not XuYan.
Blender -b --factory-startup --disable-autoexec --python this.py -- base.obj weights.json project
The source mesh is only an anatomical starting point. Dedicated fitted poses, UVs,
coat sleeves and exports are authored here in camera-space metres.
"""
import bpy, sys, math, json
from pathlib import Path
from mathutils import Vector, Matrix
base, weight_path, project = map(Path, sys.argv[sys.argv.index('--')+1:])
out = project/'assets/models/view_hands'; out.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
verts=[]; faces=[]; groups={}; group=''; uvs=[]; face_uv=[]
for line in base.read_text().splitlines():
    p=line.split()
    if not p: continue
    if p[0]=='v': verts.append(Vector(tuple(float(x)*.1 for x in p[1:4])))
    elif p[0]=='vt': uvs.append(tuple(map(float,p[1:3])))
    elif p[0]=='g': group=p[1]; groups[group]=[]
    elif p[0]=='f':
        ids=[int(x.split('/')[0])-1 for x in p[1:]]
        groups[group].extend(ids)
        if group=='body':
            faces.append(ids); face_uv.append([int(x.split('/')[1])-1 for x in p[1:]])
def joint(name):
    a=set(groups['joint-r-'+name]); return sum((verts[i] for i in a),Vector())/len(a)
wrist=joint('hand'); longitudinal=(joint('finger-3-1')-wrist).normalized()
radial=(joint('finger-2-1')-joint('finger-5-1')).normalized()
radial=(radial-longitudinal*radial.dot(longitudinal)).normalized()
normal=radial.cross(longitudinal).normalized()
source_basis=Matrix((radial,longitudinal,normal)).transposed()
local=[source_basis.transposed()@(v-wrist) for v in verts]
weights=json.loads(weight_path.read_text())['weights']
selected={i for i,v in enumerate(local) if v.y>-.010 and v.y<.24 and abs(v.x)<.13 and abs(v.z)<.07 and verts[i].x<-.33}
chosen=[(f,uv) for f,uv in zip(faces,face_uv) if all(i in selected for i in f)]
used=sorted({i for f,uv in chosen for i in f}); remap={v:i for i,v in enumerate(used)}
vertex_weights={i:[] for i in used}
for bone,values in weights.items():
    if not bone.endswith('.R'): continue
    for i,w in values:
        if i in vertex_weights: vertex_weights[i].append((bone,w))
def gv(v): return Vector((v[0],-v[2],v[1])) # Godot -> Blender
def basis(a,b,reference=Vector((0,0,1))):
    y=(b-a).normalized(); x=y.cross(reference).normalized()
    if x.length<.1: x=y.cross(Vector((1,0,0))).normalized()
    return Matrix((x,y,x.cross(y))).transposed()
def material(name,c,rough):
    m=bpy.data.materials.new(name); m.use_nodes=True
    n=m.node_tree.nodes.get('Principled BSDF');n.inputs['Base Color'].default_value=(*c,1);n.inputs['Roughness'].default_value=rough
    return m
skin=material('Hand_skin',(.48,.315,.23),.62)
cloth=material('Coat_canvas',(.055,.066,.071),.91)
cuff=material('Cuff_knit',(.028,.033,.034),.92)
def sleeve(name,wrist_at,sign):
    a=Vector((sign*.49,-.69,-.20)); b=Vector(wrist_at); d=(b-a).normalized()
    x=d.cross(Vector((0,0,1))).normalized(); z=d.cross(x)
    vs=[];fs=[]
    for i in range(25):
        t=i/24; center=a.lerp(b,t)
        r=(.066*(1-t)+.035*t)*(1+.022*math.sin(t*math.pi*14))
        for j in range(40):
            ang=j/40*math.tau; fold=1+.045*math.cos(ang*5+t*4)*math.sin(t*math.pi)
            vs.append(gv(center+r*fold*(x*math.cos(ang)+z*.82*math.sin(ang))))
    for i in range(24):
        for j in range(40):a0=i*40+j;b0=i*40+(j+1)%40;fs.append((a0,b0,b0+40,a0+40))
    me=bpy.data.meshes.new(name);me.from_pydata(vs,[],fs);me.update()
    o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);o.data.materials.append(cloth);o.data.materials.append(cuff)
    for f in me.polygons:f.use_smooth=True;f.material_index=1 if f.center.z>999 else 0
    # last three rings are the ribbed cuff.
    for f in me.polygons:
        if f.index>=21*40:f.material_index=1
    return o
def make_hand(mode,sign=1):
    paper=mode in ['paper','photo']; clock=mode=='clock'; soft=mode=='cloth'
    if paper:
        tw=Vector((.267,-.295,-.585)); mcp=[(.224,-.215,-.622),(.231,-.241,-.625),(.242,-.264,-.624),(.257,-.283,-.619)]
        thumb=[(.261,-.290,-.590),(.230,-.269,-.582),(.208,-.243,-.582),(.187,-.237,-.582)]
    elif mode=='shoe':
        tw=Vector((.27,-.35,-.54));mcp=[(.218,-.30,-.64),(.226,-.32,-.64),(.236,-.34,-.63),(.246,-.36,-.62)]
        thumb=[(.25,-.335,-.57),(.228,-.32,-.545),(.209,-.31,-.54),(.19,-.31,-.545)]
    elif soft:
        tw=Vector((.29,-.37,-.43));mcp=[(.235,-.29,-.66),(.244,-.31,-.66),(.253,-.33,-.65),(.263,-.35,-.64)]
        thumb=[(.267,-.33,-.56),(.244,-.31,-.55),(.220,-.30,-.55),(.205,-.30,-.56)]
    else:
        dx=.028 if clock else 0.; dz=-.026 if clock else 0.
        tw=Vector((.295+dx,-.255,-.54+dz))
        mcp=[(.251+dx,-.150,-.548+dz),(.257+dx,-.176,-.551+dz),(.264+dx,-.201,-.550+dz),(.273+dx,-.224,-.545+dz)]
        thumb=[(.279+dx,-.266,-.529+dz),(.249+dx,-.254,-.496+dz),(.221+dx,-.243,-.490+dz),(.201+dx,-.238,-.492+dz)]
    # Palm affine fit makes a continuous anatomical web, rather than separate tubes.
    index_src=local[min(groups['joint-r-finger-2-1'])] # replaced with exact joint centres below
    def jl(n):return source_basis.transposed()@(joint(n)-wrist)
    si=jl('finger-2-1'); sp=jl('finger-5-1')
    source=Matrix((si,sp,Vector((0,0,.025)))).transposed()
    vi=Vector(mcp[0])-tw;vp=Vector(mcp[3])-tw
    target=Matrix((vi,vp,vi.cross(vp).normalized()*.025)).transposed()
    palm=target@source.inverted()
    transforms={}
    for finger in range(1,6):
        if finger==1:target_points=[Vector(v) for v in thumb]
        else:
            a=Vector(mcp[finger-2]); lengths=[(joint('finger-%d-%d'%(finger,k+1))-joint('finger-%d-%d'%(finger,k))).length for k in range(1,4)]
            if paper or soft:
                # fingers stay behind paper/cloth; thumb alone contacts its front.
                dirs=[Vector((-.7,.55,-.2)).normalized(),Vector((-.9,.05,.30)).normalized(),Vector((-.6,-.6,.45)).normalized()]
            else:dirs=[Vector((.60,.08,.80)).normalized(),Vector((-.16,.03,.99)).normalized(),Vector((-.94,-.06,.34)).normalized()]
            target_points=[a]
            for length,d in zip(lengths,dirs):target_points.append(target_points[-1]+d*length)
        for k in range(1,4):
            a=jl('finger-%d-%d'%(finger,k)); b=jl('finger-%d-%d'%(finger,k+1)); ta,tb=target_points[k-1:k+1]
            rot=basis(ta,tb)@basis(a,b).transposed()
            transforms['finger%d-%d.R'%(finger,k)]=(rot,ta-rot@a)
    posed=[]
    for i in used:
        v=local[i]; result=Vector(); total=0
        for bone,w in vertex_weights[i]:
            if bone in transforms:r,t=transforms[bone];result+=(r@v+t)*w
            else:result+=(palm@v+tw)*w
            total+=w
        if total<.001:result=palm@v+tw
        else:result/=total
        result.x=result.x*sign+(.15 if paper and sign==-1 else (.20 if soft and sign==-1 else 0.))
        posed.append(gv(result))
    name=('Right' if sign==1 else 'Left')+'Hand_'+mode
    me=bpy.data.meshes.new(name);me.from_pydata(posed,[],[[remap[i] for i in f] for f,uv in chosen]);me.update()
    if (palm.determinant()<0) != (sign==-1):
        for f in me.polygons:f.flip()
    o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);o.data.materials.append(skin)
    uv_layer=me.uv_layers.new(name='HandUV')
    for poly,(_,u) in zip(me.polygons,chosen):
        for loop,ui in zip(poly.loop_indices,u):uv_layer.data[loop].uv=uvs[ui]
        poly.use_smooth=True
    sub=o.modifiers.new('Anatomical_smoothing','SUBSURF');sub.levels=2;sub.render_levels=2
    tw.x=tw.x*sign+(.15 if paper and sign==-1 else (.20 if soft and sign==-1 else 0.))
    print(mode,sign,'palm determinant',palm.determinant())
    return [o,sleeve(name+'_Sleeve',tw,sign)]
stats={}
for mode in ['phone','paper','photo','clock','cloth','shoe','key']:
    objects=make_hand(mode)
    if mode in ['paper','photo','cloth']:objects+=make_hand(mode,-1)
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.export_scene.gltf(filepath=str(out/(mode+'.glb')),export_format='GLB',use_selection=True,export_apply=True,export_animations=False)
    stats[mode]={'hands':2 if len(objects)==4 else 1,'source_vertices_per_hand':len(used)}
    for o in objects:o.hide_set(True)
bpy.ops.wm.save_as_mainfile(filepath=str(project/'source_art/view_hands_v1.blend'))
(out/'manifest.json').write_text(json.dumps(stats,indent=2),encoding='utf8')
print('VIEW_HANDS_OK',stats)
