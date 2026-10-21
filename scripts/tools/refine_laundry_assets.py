"""Blender后台：修复作者交付的白模，输出可接入的模块；不覆盖来源文件。"""
import bpy, sys, os, json, math
from pathlib import Path
from mathutils import Vector
args=sys.argv[sys.argv.index('--')+1:]
source,out=args[0],args[1]
os.makedirs(out,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=source,load_ui=False,use_scripts=False)
def collection(name):
    return bpy.data.collections.get(name)
def remove(o): bpy.data.objects.remove(o,do_unlink=True)
def box(name,bounds,floor,collision=False,material=None):
    x0,y0,z0,x1,y1,z1=bounds
    bpy.ops.mesh.primitive_cube_add(size=1,location=((x0+x1)/2,-(z0+z1)/2,(y0+y1)/2))
    o=bpy.context.object; o.name=name
    o.scale=(x1-x0,z1-z0,y1-y0)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    for c in list(o.users_collection):c.objects.unlink(o)
    collection('COLLISION' if collision else 'BODY').objects.link(o)
    o['fl']=floor
    if material:o.data.materials.append(material)
    return o
wallmat=next(o.data.materials[0] for o in bpy.data.objects if o.name=='F5_502隔墙_0')
floormat=next(o.data.materials[0] for o in bpy.data.objects if o.name=='F5502地面')
def bounds(o):
    p=[o.matrix_world@Vector(v) for v in o.bound_box]
    return [min(v.x for v in p),min(v.z for v in p),min(-v.y for v in p),max(v.x for v in p),max(v.z for v in p),max(-v.y for v in p)]
# 保留可见踏步，换成连续斜坡碰撞；走路不依赖不存在的抬脚逻辑。
for o in list(bpy.data.objects):
    if o.name.startswith('COL_') and '楼梯_' in o.name and ('西跑' in o.name or '东跑' in o.name):remove(o)
for fl,y,rise in [('F1',0,3.5),('F2',3.5,3.4),('F3',6.9,2.9),('F4',9.8,2.9),('F5',12.7,2.9)]:
    for side,x0,x1,z0,z1,y0,y1 in [('W',.34,1.44,10.92,13.2,y,y+rise/2),('E',1.66,2.76,13.46,11.2,y+rise/2,y+rise)]:
        verts=[(x,-z,h) for h,z in [(y0,z0),(y1,z1),(y0-.18,z0),(y1-.18,z1)] for x in [x0,x1]]
        faces=[(0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3)]
        mesh=bpy.data.meshes.new('GEO_Ramp'); mesh.from_pydata(verts,[],faces); mesh.update()
        o=bpy.data.objects.new('COL_'+fl+'_Ramp'+side+'-colonly',mesh); collection('COLLISION').objects.link(o);o['fl']=fl
# 原白模漏建2F折返平台和3F落地平台，补齐实体和碰撞。
for c in [False,True]:
    prefix='COL_' if c else 'GEO_'; suffix='-colonly' if c else ''
    box(prefix+'F2楼梯_补中平台'+suffix,(.3,5.02,13.2,2.8,5.2,14.2),'F2',c,floormat)
    box(prefix+'F3楼梯_补顶平台'+suffix,(.3,6.7,10.1,2.8,6.9,11.2),'F3',c,floormat)
# 二楼上行段还缺可见踏步；全楼梯井补齐外壳，消除对外镂空。
for step in range(8):
    z=11.2+step*.25;h=3.5+(step+1)*1.7/8
    box('GEO_F2楼梯_西踏步'+str(step),(.34,3.48,z,1.44,h,z+.25),'F2',False,floormat)
    z=13.2-(step+1)*.25;h=5.2+(step+1)*1.7/8
    box('GEO_F2楼梯_东踏步'+str(step),(1.66,5.18,z,2.76,h,z+.25),'F2',False,floormat)
for c in [False,True]:
    box(('COL_' if c else 'GEO_')+'F2楼梯_中隔'+('-colonly' if c else ''),(1.44,3.5,11.2,1.66,6.9,13.2),'F2',c,wallmat)
for fl,lo,hi in [('F2',4.2,6.9),('F3',6.9,9.8),('F4',9.8,12.7),('F5',12.7,15.6)]:
    for side,b in [('W',(.14,lo,10.1,.3,hi,14.2)),('E',(2.8,lo,10.1,2.96,hi,14.2)),('S',(.14,lo,14.2,2.96,hi,14.36))]:
        for c in [False,True]:box(('COL_' if c else 'GEO_')+fl+'梯井外墙'+side+('-colonly' if c else ''),b,fl,c,wallmat)
# 屋顶楼板必须为整段楼梯井留洞，不能盖住上楼者头部。
for o in list(bpy.data.objects):
    if o.type!='MESH' or o.get('fl')!='ROOF' or '天窗' not in o.name:continue
    b=bounds(o)
    if b[3]<=.3 or b[0]>=2.8 or b[5]<=10.1:continue
    if b[1]<15.29 or b[4]>15.61:continue
    material=o.data.materials[0] if o.data.materials else floormat
    c=o.name.startswith('COL_');name=o.name;remove(o)
    parts=[(b[0],b[1],b[2],b[3],b[4],10.1),(b[0],b[1],10.1,.3,b[4],b[5]),(2.8,b[1],10.1,b[3],b[4],b[5])]
    for i,q in enumerate(parts):
        if q[3]>q[0] and q[5]>q[2]:box(name.replace('-colonly','')+'_Cut'+str(i)+('-colonly' if c else ''),q,'ROOF',c,material)
# 设备碰撞与接入后的实际机器位置一致。
for o in bpy.data.objects:
    if o.type!='MESH' or not o.name.startswith('COL_F2'):continue
    if '洗衣机_' in o.name or '烘干机_' in o.name:
        tail=o.name.split('机_')[-1].split('-')[0]
        if not tail.isdigit():continue
        number=int(tail); desired=(3.15+(number-1)*.92) if number<=6 else {8:2.6,9:4.1,10:5.6,11:8.6}.get(number)
        if desired is not None:o.location.y=-desired
# 贯通502/503双隔墙，补足两屋之间地面。
for x,room in [(-.4,'502'),(.4,'503')]:
    for o in list(bpy.data.objects):
        if 'F5_'+room+'隔墙' in o.name:remove(o)
    for index,b in enumerate([(x-.06,12.7,2.2,x+.06,15.3,3.8),(x-.06,12.7,4.9,x+.06,15.3,5.4),(x-.06,14.8,3.8,x+.06,15.3,4.9)]):
        name='GEO_F5_'+room+'_Passage'+str(index)
        box(name,b,'F5',False,wallmat);box('COL_'+name+'-colonly',b,'F5',True)
for c in [False,True]:box(('COL_' if c else 'GEO_')+'F5_PassageFloor'+('-colonly' if c else ''),(-.46,12.4,3.8,.46,12.7,4.9),'F5',c,floormat)
for o in list(bpy.data.objects):
    if 'F5_503湿床' in o.name:o.location.y+=1.4
    if 'F5_503玩具机' in o.name:
        index=int(o.name.split('玩具机')[1].split('-')[0])
        o.location.x=2.96;o.location.y=-(2.6+index*.34)
# 折叠桌移到西侧，不能堵住通往廊桥的东南出口。
for o in bpy.data.objects:
    if 'F2折叠桌' in o.name:o.location.x-=3.25
# 长椅改为两座，留出通往东侧配电盘的绕行口。
for o in list(bpy.data.objects):
    if 'F2长椅' not in o.name or o.type!='MESH' or o.name.startswith(('SEAT','STAND')):continue
    b=bounds(o)
    if b[2]>=7.42:remove(o);continue
    if b[5]>7.42:
        for v in o.data.vertices:
            w=o.matrix_world@v.co
            if -w.y>7.42:
                w.y=-7.42;v.co=o.matrix_world.inverted()@w
# 用空节点交付参考点，原点即实际坐标，不使用锥体中心冒充座面。
for o in list(bpy.data.objects):
    if any(c.name=='MARKERS' for c in o.users_collection):
        p=o.location.copy()
        if o.name.startswith(('SEAT','STAND','PT_')) and 'door' not in o.name:p.z-=.13
        e=bpy.data.objects.new(o.name+'_Anchor',None);e.location=p;e['fl']=o.get('fl','F2')
        collection('MARKERS').objects.link(e);remove(o)
# 导出可复用的PBR色板；运行时会按构件配置工程现有贴图。
palette={'wall':(.38,.39,.34,1),'floor':(.24,.27,.25,1),'metal':(.21,.26,.27,1),'furn':(.24,.19,.14,1),'ceil':(.46,.47,.42,1)}
for m in bpy.data.materials:
    name=m.name.lower()
    color=next((v for k,v in palette.items() if k in name),None)
    if color:
        m.diffuse_color=color;m.use_nodes=True
        bsdf=m.node_tree.nodes.get('Principled BSDF')
        if bsdf:bsdf.inputs['Base Color'].default_value=color;bsdf.inputs['Roughness'].default_value=.78
def export(path,predicate):
    bpy.ops.object.select_all(action='DESELECT')
    for o in bpy.data.objects:
        if o.type in ['MESH','EMPTY'] and predicate(o):o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path,export_format='GLB',use_selection=True,export_apply=True,export_yup=True,export_extras=True,export_cameras=False,export_lights=False,export_animations=False)
for fl in ['B1','F1','F2','F3','F4','F5','ROOF','BRIDGE']:
    for kind in ['body','collision']:
        groups=['BODY','DOORS'] if kind=='body' else ['COLLISION']
        export(os.path.join(out,fl+'_'+kind+'.glb'),lambda o,f=fl,g=groups:o.get('fl')==f and any(c.name in g for c in o.users_collection))
export(os.path.join(out,'anchors.glb'),lambda o:any(c.name=='MARKERS' for c in o.users_collection))
bpy.ops.wm.save_as_mainfile(filepath=str(Path(__file__).resolve().parents[2]/'source_art'/'laundry_repaired.blend'))
print('REFINED_WHITEBOX',out)
