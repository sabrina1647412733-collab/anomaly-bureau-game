"""Scoped, repeatable Blender repair of the existing case-one finish source.

blender --background --factory-startup --disable-autoexec --python this.py -- PROJECT
Keeps the historical source intact. Godot coordinates, metres, Y up.
"""
import bpy
import json
import math
import sys
from pathlib import Path
from mathutils import Vector

PROJECT = Path(sys.argv[sys.argv.index('--') + 1]).resolve()
bpy.ops.wm.open_mainfile(filepath=str(PROJECT / 'source_art/case1_finish_source.blend'), load_ui=False, use_scripts=False)
BODY = bpy.data.collections['BODY']
REAR = bpy.data.collections.new('Round1_Backroom')
bpy.context.scene.collection.children.link(REAR)
KEYS = bpy.data.collections.new('Round1_BoilerKeys')
bpy.context.scene.collection.children.link(KEYS)
retired = []

def p(v):
    return Vector((v[0], -v[2], v[1]))

def mat(name, color, rough=.75, metal=0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*color, 1)
    bsdf.inputs['Roughness'].default_value = rough
    bsdf.inputs['Metallic'].default_value = metal
    return m

wood = mat('Rear_Oak', (.22, .17, .10))
paint = mat('Rear_PaintedSteel', (.14, .22, .19), .74, .12)
metal = mat('Rear_Steel', (.30, .33, .29), .48, .7)
brass = mat('Rear_Brass', (.34, .26, .11), .45, .7)
paper = mat('Rear_Paper', (.67, .61, .43), .95)
ink = mat('Rear_Ink', (.07, .09, .07), .9)
cloth = mat('Rear_Raincoat', (.43, .36, .10), .68)
rubber = mat('Rear_Rubber', (.035, .045, .035), .88)
glass = mat('Rear_GaugeGlass', (.68, .68, .56), .32, .08)

def own(o, name, material, collection=REAR):
    o.name = name
    for c in list(o.users_collection):
        c.objects.unlink(o)
    collection.objects.link(o)
    if material:
        o.data.materials.append(material)
    return o

def bevel(o, width=.003):
    b = o.modifiers.new('Small finished edges', 'BEVEL')
    b.width = width
    b.segments = 2
    b.limit_method = 'ANGLE'
    b.harden_normals = True
    n = o.modifiers.new('Weighted flat normals', 'WEIGHTED_NORMAL')
    n.keep_sharp = True
    return o

def box(name, at, size, material, collection=REAR, edge=.003):
    bpy.ops.mesh.primitive_cube_add(size=1, location=p(at))
    o = own(bpy.context.object, name, material, collection)
    o.scale = (size[0], size[2], size[1])
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if edge:
        bevel(o, min(edge, min(size) / 4))
    return o

def cyl(name, at, radius, length, material, axis=(0, 1, 0), collection=REAR, vertices=32):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=length, location=p(at))
    o = own(bpy.context.object, name, material, collection)
    o.rotation_mode = 'QUATERNION'
    o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(p(axis).normalized())
    for face in o.data.polygons:
        face.use_smooth = len(face.vertices) == 4
    bevel(o, .0015)
    return o

def line(name, points, radius, material, collection=REAR):
    curve = bpy.data.curves.new(name, 'CURVE')
    curve.dimensions = '3D'
    curve.bevel_depth = radius
    curve.bevel_resolution = 2
    spl = curve.splines.new('POLY')
    spl.points.add(len(points) - 1)
    for v, pt in zip(spl.points, points):
        v.co = (*p(pt), 1)
    o = bpy.data.objects.new(name, curve)
    collection.objects.link(o)
    o.data.materials.append(material)
    return o

def retire(o):
    o['round1_retired'] = True
    o.hide_render = True
    o.hide_set(True)
    retired.append(o.name)

# Thick solid steps were at eye level underneath the next flight. Retain floor
# heights, the continuous ramp colliders and the same 2.5m stairwell opening.
for o in list(BODY.objects):
    name = o.name
    if '楼梯' in name and any(w in name for w in ['西跑', '东跑', '西踏步', '东踏步', '灯架', '灯座']):
        retire(o)
    if '梯帽_门槛' in name:
        retire(o)
    if o.get('fl') == 'F2' and name.startswith('F2后房_') and '横梁' not in name:
        retire(o)
for o in bpy.data.collections['COLLISION'].objects:
    if o.get('fl')=='F2' and any(w in o.name for w in ['后房_铁架台','后房_水表箱']):
        retire(o)
    if '梯帽_门槛' in o.name:
        retire(o)

floor_material = next(o.data.materials[0] for o in BODY.objects if o.name == 'F2洗衣店地面')

def stair(floor, x0, x1, z0, z1, y0, y1, side):
    count = 10
    # Closed profile with stepped upper edge and a sloping .18m concrete waist.
    profile = [(z0, y0 - .18), (z0, y0)]
    for i in range(count):
        z = z0 + (z1-z0) * i/count
        h = y0 + (y1-y0) * (i+1)/count
        profile.extend([(z, h), (z0 + (z1-z0)*(i+1)/count, h)])
    profile.append((z1, y1 - .18))
    verts = [tuple(p((x, y, z))) for x in [x0, x1] for z, y in profile]
    n = len(profile)
    faces = [tuple(reversed(range(n))), tuple(range(n, n*2))]
    faces.extend((i, (i+1)%n, (i+1)%n+n, i+n) for i in range(n))
    mesh = bpy.data.meshes.new('ClosedStairProfile')
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    o = bpy.data.objects.new(floor + '_踏步薄板_' + side, mesh)
    BODY.objects.link(o)
    o['fl'] = floor
    o.data.materials.append(floor_material)
    # Explicit normal recalculation is important for the reversed east flight.
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    o.select_set(False)
    bevel(o, .002)

for floor, low, rise in [('F1', 0, 3.5), ('F2', 3.5, 3.4), ('F3', 6.9, 2.9), ('F4', 9.8, 2.9), ('F5', 12.7, 2.9)]:
    stair(floor, .34, 1.44, 10.92, 13.2, low, low+rise/2, 'W')
    stair(floor, 1.66, 2.76, 13.46, 11.2, low+rise/2, low+rise, 'E')

# A usable work corner; the central entrance and turning area stay empty.
box('registry_table_top', (-2.84, 4.25, .45), (.57, .055, .66), wood)
for x in [-3.06, -2.62]:
    for z in [.18, .72]:
        box('registry_table_leg', (x, 3.86, z), (.035, .72, .035), paint)
box('registry_table_apron', (-2.84, 4.12, .45), (.52, .15, .60), paint)
box('registry_cover', (-2.80, 4.298, .45), (.35, .032, .43), wood)
box('registry_pages', (-2.80, 4.32, .45), (.33, .014, .41), paper)
for x in [-2.925, -2.87, -2.815, -2.76, -2.705, -2.65]:
    box('registry_rule', (x, 4.328, .45), (.0012, .001, .36), ink, edge=0)
for z in [.29, .34, .39, .44, .49, .54, .59]:
    box('registry_row', (-2.80, 4.329, z), (.29, .001, .001), ink, edge=0)
box('registry_book_spine', (-2.98, 4.31, .45), (.018, .052, .43), paint)

box('old_sign_wood', (-1.72, 4.74, -.65), (1.34, .40, .055), wood)
box('old_sign_painted_face', (-1.72, 4.74, -.616), (1.29, .355, .016), paint)
for x in [-2.32, -1.12]:
    cyl('sign_old_screw', (x, 4.74, -.601), .008, .006, brass, (0,0,1), vertices=12)
line('sign_support_cord', [(-2.22, 4.95, -.65), (-1.72, 5.13, -.67), (-1.22, 4.95, -.65)], .006, rubber)

# Cylindrical boiler, gauge, joined pipes and plinth rather than an empty marker.
cyl('boiler_tank', (-.48, 4.26, -.25), .29, 1.30, paint)
for y in [3.64, 4.88]:
    cyl('boiler_lid', (-.48, y, -.25), .31, .05, metal)
for x in [-.67, -.29]:
    box('boiler_foot', (x, 3.57, -.25), (.075, .14, .38), metal)
for y in [3.95, 4.64]:
    cyl('boiler_belt', (-.48, y, -.25), .298, .028, metal)
cyl('boiler_gauge_rim', (-.48, 4.47, .06), .095, .055, brass, (0,0,1))
cyl('boiler_gauge_face', (-.48, 4.47, .092), .081, .008, glass, (0,0,1))
line('boiler_gauge_needle', [(-.48,4.47,.10),(-.515,4.515,.10)], .003, ink)
for i in range(9):
    t = math.pi*.1 + i*math.pi*.8/8
    line('boiler_gauge_tick', [(-.48+math.cos(t)*.061,4.47+math.sin(t)*.061,.10),(-.48+math.cos(t)*.072,4.47+math.sin(t)*.072,.10)], .0015, ink)
line('boiler_supply_pipe', [(-.48,4.92,-.25),(-.48,5.42,-.25),(-.48,5.42,-.58),(-.48,6.25,-.58)], .025, metal)
line('boiler_return_pipe', [(-.19,3.99,-.25),(-.07,3.99,-.25),(-.07,3.99,.20),(-.07,3.58,.20)], .023, metal)
box('boiler_maintenance_tag', (-.48, 4.08, .044), (.17,.12,.009), paper)
for z in [-.40,-.15,.10,.35]:
    box('rear_wall_old_waterline',(-.014,4.13,z),(.008,.024,.245),rubber,edge=0)
line('key_hook', [(-.48,5.38,-.25),(-.48,5.38,.055),(-.48,5.264,.055)], .009, brass)

# Separate moving/hidden item, with its own origin at the interaction anchor.
# Export in local coordinates, so hiding the root also hides all three keys.
for j in range(24):
    angle=2*math.pi*j/24
    nxt=2*math.pi*(j+1)/24
    line('key_ring', [(math.cos(angle)*.034,math.sin(angle)*.034,0),(math.cos(nxt)*.034,math.sin(nxt)*.034,0)], .003, brass, KEYS)
for i,x in enumerate([-.026,0,.026]):
    cyl('key_bow', (x,-.052,.004*i), .014, .006, metal if i<2 else brass, (0,0,1), KEYS, 20)
    box('key_shank', (x,-.09,.004*i), (.008,.063,.007), metal if i<2 else brass, KEYS, .001)
    for y in [-.104,-.116]:
        box('key_bit', (x+.007,y,.004*i), (.016,.006,.007), metal if i<2 else brass, KEYS, .001)

# Mounted photo board and newspaper: no new story facts or evidence ownership.
box('photo_board', (-3.16, 4.99, 1.13), (.035,.68,.79), wood)
for y in [4.66,5.32]:box('photo_frame', (-3.13,y,1.13), (.035,.025,.81), paint)
for z in [.745,1.515]:box('photo_frame', (-3.13,4.99,z), (.035,.68,.025), paint)
box('photo_family_paper', (-3.132,5.07,1.09), (.009,.34,.47), paper)
# The existing, approved family-photo texture is mounted by the Godot module.
cyl('photo_pin', (-3.11,5.24,.90), .008,.01,brass,(1,0,0),vertices=12)
box('clipping_backing', (-3.16,4.80,.12), (.028,.40,.42), wood)
box('clipping_paper', (-3.139,4.80,.12), (.008,.35,.36), paper)
box('clipping_picture', (-3.131,4.80,.02), (.003,.14,.12), paint)
for y in [4.91,4.87,4.83,4.79,4.75,4.71]:
    box('clipping_columns', (-3.131,y,.205), (.003,.003,.14), ink, edge=0)

# Thin cloth raincoat: shaped shoulders, sleeves, hanging hem and hollow hood.
# Model an object, not a new character; no body or facial mesh is used.
def coat_panel(name, outline, x, depth):
    verts = [tuple(p((xx,y,z))) for xx in [x,x+depth] for z,y in outline]
    n=len(outline)
    faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]
    faces.extend((i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n))
    mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update()
    o=bpy.data.objects.new(name,mesh);REAR.objects.link(o);o.data.materials.append(cloth)
    bpy.context.view_layer.objects.active=o;o.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT');o.select_set(False)
    bevel(o,.008)

coat_panel('raincoat_body',[(.98,5.02),(.88,4.96),(.88,4.72),(.84,4.37),(.96,4.34),(1.08,4.37),(1.21,4.34),(1.32,4.38),(1.27,4.74),(1.27,4.96),(1.17,5.02)],-.15,.035)
coat_panel('raincoat_sleeve_left',[(.90,4.98),(.75,4.87),(.69,4.58),(.78,4.55),(.88,4.78),(.98,4.88)],-.14,.045)
coat_panel('raincoat_sleeve_right',[(1.25,4.98),(1.40,4.87),(1.47,4.58),(1.37,4.55),(1.27,4.78),(1.17,4.88)],-.14,.045)
line('raincoat_zipper',[(-.165,4.36,1.075),(-.17,4.94,1.075)],.004,metal)
for z in [.94,1.20]:line('raincoat_fold',[(-.16,4.4,z-.03),(-.18,4.65,z),(-.16,4.89,z+.02)],.009,cloth)
# Open hood rim plus fabric shell; the dark opening faces into the room (-X).
hood=[]
for i in range(19):
    t=-math.pi*.15 + i*math.pi*1.3/18
    hood.append((-.17,5.025+math.sin(t)*.12,1.075+math.cos(t)*.105))
line('raincoat_hood_rim',hood,.014,cloth)
box('raincoat_hood_back',(-.085,5.075,1.075),(.04,.17,.16),cloth,edge=.025)
box('raincoat_hook_plate',(-.025,5.19,1.075),(.025,.07,.06),metal)
line('raincoat_hook',[(-.04,5.20,1.075),(-.12,5.20,1.075),(-.12,5.15,1.075)],.007,brass)
box('raincoat_damp_patch',(-.22,3.507,1.08),(.29,.009,.54),rubber,edge=.003)

def export(path, objects):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:
        o.hide_set(False)
        o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_apply=True,export_animations=False,export_cameras=False,export_lights=False)

def export_batches(path, objects):
    # Keep editable parts in the author scene; only the exported copies are
    # collapsed by material. Static dressing must not add hundreds of draws.
    copies=[]
    for o in objects:
        clone=o.copy();clone.data=o.data.copy();REAR.objects.link(clone);copies.append(clone)
    bpy.ops.object.select_all(action='DESELECT')
    for o in copies:o.select_set(True)
    bpy.context.view_layer.objects.active=copies[0]
    bpy.ops.object.convert(target='MESH')
    groups={}
    for o in list(bpy.context.selected_objects):
        groups.setdefault(o.data.materials[0].name,[]).append(o)
    joined=[]
    for material, members in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        for o in members:o.select_set(True)
        bpy.context.view_layer.objects.active=members[0]
        if len(members)>1:bpy.ops.object.join()
        o=bpy.context.view_layer.objects.active;o.name=material;joined.append(o)
    export(path,joined)
    for o in joined:bpy.data.objects.remove(o,do_unlink=True)
    return len(joined)

for floor in ['F1','F2','F3','F4','F5','ROOF']:
    selected=[o for o in BODY.objects if o.type=='MESH' and o.get('fl')==floor and not o.get('round1_retired')]
    # Same dynamic-door/machine exclusions as the established finish exporter.
    hidden=['F2后房门','F2配电门','F4_402门','F5_503门','F3_302门','F3_303门','F3_304门','F4_403门','F4_401门','F5_502门']
    selected=[o for o in selected if o.name not in hidden and not (floor=='F2' and any(s in o.name for s in ['洗衣机','烘干机','七号机','长椅']))]
    export(PROJECT/f'assets/models/laundry_finish/{floor}_finish.glb',selected)

# Remove only the two obsolete furniture colliders. The building shell,
# stairs and ramp hulls keep their established source geometry.
for floor in ['F2','ROOF']:
    if not any(o.get('fl')==floor and o.get('round1_retired') for o in bpy.data.collections['COLLISION'].objects):
        continue
    export(PROJECT/f'assets/models/laundry_rebuild/{floor}_collision.glb',
           [o for o in bpy.data.collections['COLLISION'].objects if o.type=='MESH' and o.get('fl')==floor and not o.get('round1_retired')])

out=PROJECT/'assets/models/laundry_backroom'
out.mkdir(parents=True,exist_ok=True)
rear_groups=export_batches(out/'backroom.glb',list(REAR.objects))
key_groups=export_batches(out/'boiler_keys.glb',list(KEYS.objects))
manifest={
    'coordinates':'Godot Y up, metres, absolute laundry world coordinates; keys are local',
    'waist_thickness':.18,'steps_per_flight':10,'retired':retired,
    'points':{'l_registry':[-2.80,4.33,.45],'l_sign':[-1.72,4.74,-.60],
              'l_photowall':[-3.11,5.07,1.09],'l_clipping':[-3.13,4.80,.12],
              'l_boiler':[-.48,4.47,.10],'l_raincoat':[-.17,4.72,1.075],
              'l_keyring':[-.48,5.23,.055]},
    'collisions':[{'id':'registry_table','center':[-2.84,3.89,.45],'size':[.57,.78,.66]},
                  {'id':'boiler','center':[-.48,4.23,-.25],'size':[.64,1.46,.64]}],
    'backroom_parts':len(REAR.objects),'keys_parts':len(KEYS.objects),
    'backroom_draw_groups':rear_groups,'keys_draw_groups':key_groups
}
(out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
for o in BODY.objects:
    if o.get('round1_retired'):
        o.hide_set(True)
bpy.ops.wm.save_as_mainfile(filepath=str(PROJECT/'source_art/case1_interior_round1.blend'),compress=True)
print('CASE1_INTERIOR_REPAIR_OK',len(retired),manifest['backroom_parts'])
