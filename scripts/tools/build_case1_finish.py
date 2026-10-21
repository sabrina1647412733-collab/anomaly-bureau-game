"""Blender 4.5后台：保留通行尺寸，精修楼体边缘及洗衣机/长椅/门；不修改碰撞模块。
Usage: blender -b --factory-startup --disable-autoexec --python this.py -- source.blend output_dir
"""
import bpy,sys,math,json
from pathlib import Path
from mathutils import Vector
source,out=map(Path,sys.argv[sys.argv.index('--')+1:])
out.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(source),load_ui=False,use_scripts=False)
body=list(bpy.data.collections['BODY'].objects)
hidden=['F2后房门','F2配电门','F4_402门','F5_503门','F3_302门','F3_303门','F3_304门','F4_403门','F4_401门','F5_502门']
def visible(o):
    return o.type=='MESH' and o.name not in hidden and not (o.get('fl')=='F2' and any(s in o.name for s in ['洗衣机','烘干机','七号机','长椅']))
def bevel(o,width=.004):
    if min(o.dimensions)<.012:return
    b=o.modifiers.new('毫米级倒角','BEVEL');b.width=width;b.segments=2;b.limit_method='ANGLE';b.harden_normals=True
    n=o.modifiers.new('平面法线','WEIGHTED_NORMAL');n.keep_sharp=True;n.weight=30
def export(name,objects):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.export_scene.gltf(filepath=str(out/(name+'.glb')),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_cameras=False,export_lights=False)
stats={}
for floor in ['B1','F1','F2','F3','F4','F5','ROOF','BRIDGE']:
    objects=[o for o in body if visible(o) and o.get('fl')==floor]
    for o in objects:
        if not any(s in o.name for s in ['玻璃','水面','衣','纸']):bevel(o,.002 if any(s in o.name for s in ['墙','地面','天花']) else .005)
    if objects:export(floor+'_finish',objects);stats[floor]=len(objects)

# 新道具遵循Godot坐标（Y上、+Z正面）；转换只在作者工具内完成。
collection=bpy.data.collections.new('精修道具_单独导出');bpy.context.scene.collection.children.link(collection)
parts=[]
def mat(name,color,rough=.65,metal=0):
    m=bpy.data.materials.new(name);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
    return m
ivory=mat('搪瓷_灰米白',(.58,.61,.56),.38,.08)
enamel=mat('旧绿漆',(.18,.28,.25),.67,.12)
steel=mat('不锈钢',(.35,.4,.39),.27,.85)
rubber=mat('橡胶',(.025,.03,.028),.82)
black=mat('玻璃内暗部',(.012,.025,.025),.19,.32)
wood=mat('椅面旧木',(.27,.21,.14),.78)
brass=mat('旧黄铜',(.35,.27,.12),.4,.65)
paper=mat('泛黄铭牌',(.65,.61,.48),.9)
def own(o,name,m):
    o.name=name
    for c in list(o.users_collection):c.objects.unlink(o)
    collection.objects.link(o);o.data.materials.append(m);parts.append(o);return o
def pos(p):return Vector((p[0],-p[2],p[1]))
def box(name,p,size,m,b=.006):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos(p));o=own(bpy.context.object,name,m);o.scale=(size[0],size[2],size[1])
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if b:bevel(o,b)
    return o
def cyl(name,p,r,length,m,axis=(0,0,1),vertices=32):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=length,location=pos(p))
    o=own(bpy.context.object,name,m);o.rotation_mode='QUATERNION';o.rotation_quaternion=Vector((0,0,1)).rotation_difference(pos(axis).normalized())
    for f in o.data.polygons:f.use_smooth=len(f.vertices)==4
    bevel(o,.0018);return o
def ring(name,p,major,minor,m,axis=(0,0,1)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major,minor_radius=minor,major_segments=64,minor_segments=10,location=pos(p))
    o=own(bpy.context.object,name,m);o.rotation_mode='QUATERNION';o.rotation_quaternion=Vector((0,0,1)).rotation_difference(pos(axis).normalized())
    for f in o.data.polygons:f.use_smooth=True
    return o
def line(name,points,r,m):
    curve=bpy.data.curves.new(name,'CURVE');curve.dimensions='3D';curve.bevel_depth=r;curve.bevel_resolution=2
    spl=curve.splines.new('BEZIER');spl.bezier_points.add(len(points)-1)
    for bp,p in zip(spl.bezier_points,points):bp.co=pos(p);bp.handle_left_type='AUTO';bp.handle_right_type='AUTO'
    o=bpy.data.objects.new(name,curve);collection.objects.link(o);o.data.materials.append(m);parts.append(o);return o
def done(name):
    # Collapse static pieces by material, retaining editable originals in the .blend.
    copies=[]
    for o in parts:
        clone=o.copy();clone.data=o.data.copy();collection.objects.link(clone);copies.append(clone)
    bpy.ops.object.select_all(action='DESELECT')
    for o in copies:o.select_set(True)
    bpy.context.view_layer.objects.active=copies[0];bpy.ops.object.convert(target='MESH')
    groups={}
    for o in list(bpy.context.selected_objects):groups.setdefault(o.data.materials[0].name,[]).append(o)
    joined=[]
    for material,objects in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        for o in objects:o.select_set(True)
        bpy.context.view_layer.objects.active=objects[0]
        if len(objects)>1:bpy.ops.object.join()
        o=bpy.context.view_layer.objects.active;o.name=name+'_'+material;joined.append(o)
    export(name,joined);stats[name]={'source_parts':len(parts),'draw_groups':len(joined)}
    for o in joined:bpy.data.objects.remove(o,do_unlink=True)
    for o in parts:o.hide_set(True)
    parts.clear()
box('机壳',(0,.45,0),(.66,.88,.67),ivory,.014)
box('上盖',(0,.902,.0),(.674,.036,.69),ivory,.008)
box('控制面板',(0,.788,.346),(.636,.16,.026),enamel,.006)
box('洗涤剂抽屉',(-.19,.795,.365),(.2,.085,.017),ivory,.004)
box('抽屉拉手',(-.19,.815,.381),(.115,.012,.012),steel,.002)
cyl('程序旋钮',(.16,.805,.381),.036,.027,ivory)
box('旋钮指针',(.16,.823,.398),(.003,.018,.003),rubber,.001)
for x in [.06,.1]:cyl('按键',(x,.764,.365),.009,.012,rubber)
cyl('门内暗腔',(0,.438,.344),.218,.012,black,vertices=64)
ring('搪瓷门框',(0,.438,.36),.223,.022,ivory)
ring('密封胶圈',(0,.438,.379),.196,.014,rubber)
ring('外侧金属压环',(0,.438,.387),.216,.006,steel)
box('门扣把手',(.208,.46,.409),(.035,.106,.03),enamel,.006)
for y in [.32,.56]:box('门铰链',(-.225,y,.367),(.035,.053,.025),steel,.003)
box('滤网检修盖',(.18,.11,.344),(.15,.13,.012),ivory,.004)
box('底裙板',(0,.045,.35),(.63,.055,.02),enamel,.003)
for x in [-.25,.25]:
    for z in [-.25,.25]:cyl('橡胶脚',(x,.018,z),.032,.036,rubber,axis=(0,1,0),vertices=16)
for x in [-.29,.29]:
    for y in [.08,.68]:cyl('十字螺钉',(x,y,.346),.006,.004,steel,vertices=12)
line('后排水软管',[(.24,.62,-.32),(.27,.54,-.4),(.26,.12,-.42),(.34,.06,-.44)],.012,rubber)
box('维修铭牌',(-.18,.674,.347),(.13,.033,.003),paper,.001)
done('washer_finish')

cyl('滚筒内壁',(0,0,-.01),.181,.03,steel,vertices=64)
cyl('滚筒暗底',(0,0,.009),.145,.005,black,vertices=64)
for radius,count in [(.163,36),(.13,28),(.1,20)]:
    for i in range(count):
        a=i*math.tau/count;cyl('排水孔',(math.cos(a)*radius,math.sin(a)*radius,.013),.004,.002,rubber,vertices=8)
for i in range(3):
    a=i*math.tau/3
    o=box('翻衣筋',(math.cos(a)*.12,math.sin(a)*.12,.025),(.016,.12,.02),steel,.002)
    o.rotation_euler[1]=a
done('drum_finish')

for x in [-.16,0,.16]:box('椅面木条',(x,.415,0),(.145,.05,1.54),wood,.006)
for z in [-.56,.56]:
    for x in [-.18,.18]:box('钢腿',(x,.195,z),(.036,.39,.052),enamel,.004)
    box('座面支架',(0,.375,z),(.44,.04,.055),enamel,.003)
    box('靠背支架',(.205,.63,z),(.038,.59,.046),enamel,.004)
for h in [.61,.75,.89]:box('靠背木条',(.218,h,0),(.04,.115,1.54),wood,.005)
for z in [-.56,.56]:
    for x in [-.16,0,.16]:cyl('固定螺栓',(x,.442,z),.007,.004,brass,axis=(0,1,0),vertices=12)
box('脚踏板',(-.02,.055,0),(.1,.035,1.48),enamel,.003)
done('bench_finish')

box('门扇',(.45,1.025,0),(.9,2.05,.045),enamel,.006)
for y,h in [(.48,.61),(1.34,.91)]:
    box('门板内嵌',(.45,y,.026),(.68,h,.012),wood,.004)
    for x in [.092,.808]:box('门板竖边',(x,y,.035),(.018,h+.05,.015),enamel,.003)
    for yy in [y-h/2-.014,y+h/2+.014]:box('门板横边',(.45,yy,.035),(.73,.02,.015),enamel,.003)
for y in [.22,1.0,1.82]:cyl('合页',(.012,y,0),.014,.1,steel,axis=(0,1,0),vertices=16)
for z in [-.045,.045]:
    cyl('锁座',(.77,.98,z),.026,.008,brass)
    cyl('把手轴',(.77,.98,z*1.5),.01,.035,brass)
    box('门把手',(.725,.98,z*1.9),(.11,.018,.02),brass,.006)
done('door_finish')

for z in [-.31,.31]:
    for x in [-.24,.24]:box('工具桌脚',(x,.4,z),(.055,.8,.055),enamel,.003)
box('工具桌面',(0,.83,0),(.64,.06,.76),wood,.005)
box('桌下抽屉',(0,.68,0),(.5,.2,.58),enamel,.004)
box('抽屉把手',(0,.68,.315),(.14,.018,.025),brass,.004)
done('workbench_finish')

# 所有源几何保留在独立作者文件，原白模与碰撞资源没有被覆盖。
for o in collection.objects:o.hide_set(False)
bpy.ops.wm.save_as_mainfile(filepath=str(out/'case1_finish_source.blend'))
(out/'finish_manifest.json').write_text(json.dumps(stats,ensure_ascii=False,indent=2),encoding='utf8')
print('FINISH_EXPORT_OK',stats)
