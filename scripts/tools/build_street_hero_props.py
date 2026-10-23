"""Author a small, reusable street hero-prop layer without rebuilding the town.

Blender -b --factory-startup --python this_file -- PROJECT
All construction coordinates are Godot X/Y-up/Z. GLB does the only axis conversion.
The three groups anchor to the actual building front/yaw, not guessed world axes.
"""
import bpy
import bmesh
import json
import math
import random
import sys
from collections import defaultdict
from pathlib import Path
from mathutils import Vector

ROOT = Path(sys.argv[sys.argv.index('--') + 1])
OUT = ROOT / 'assets/town/renewal/hero_props'
OUT.mkdir(parents=True, exist_ok=True)
DATA = json.loads((ROOT / 'assets/town/town-layout.json').read_text(encoding='utf8'))
BUILDINGS = {b['seed']: b for b in DATA['buildings']}
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
GEOM = {}
ANCHOR = None
GROUP = ''
DETAIL_ID = None
DETAIL_VERTS = defaultdict(list)
RAND = random.Random(95131)
MANIFEST = {'version': 1, 'chunks': [], 'props': [], 'anchors': [],
            'preserve_materials': ['wicker', 'enamel', 'enamel_flower', 'linen', 'verge_green'],
            'validation': {}, 'notes': [
                'Authoring source uses existing town-layout building front/yaw.',
                'No characters, gameplay, landmark names or entrance positions are changed.',
                'Boxes are declared alongside the geometry that they bound.',
                'Door protection is 0.65 m; road volumes are never narrowed by these props.',
                'Wicker and enamel use exported native PBR plus vertex colour; do not override.',
                'This layer is additive. Do not load it twice or merge into old town GLBs.']}


def set_anchor(seed, label):
    global ANCHOR, GROUP
    ANCHOR = BUILDINGS[seed]
    GROUP = label
    MANIFEST['anchors'].append({'seed': seed, 'group': label,
        'front': [ANCHOR['fx'], ANCHOR['fz']], 'yaw': ANCHOR['rot']})


def world(p):
    x, y, z = p
    c, s = math.cos(ANCHOR['rot']), math.sin(ANCHOR['rot'])
    return (ANCHOR['fx'] + x*c + z*s, y, ANCHOR['fz'] - x*s + z*c)


def face(mat, verts, polys, color=(1, 1, 1, 1), smooth=False):
    # Both adjoining fronts share one small galvanized hardware batch. All
    # positions stay in town space; this avoids extra draw calls per doorway.
    batch = 'electrical_shop' if mat == 'galvanized' else GROUP
    key = (batch, mat)
    vv, ff, cc, ss = GEOM.setdefault(key, [[], [], [], []])
    off = len(vv)
    for p in verts:
        x, y, z = world(p)
        vv.append((x, -z, y))
        cc.append(color)
        if DETAIL_ID is not None:
            DETAIL_VERTS[(ANCHOR['seed'],DETAIL_ID,mat)].append(tuple(p))
    ff.extend(tuple(off+i for i in f) for f in polys)
    ss.extend([smooth] * len(polys))


def box(mat, at, size, color=(1, 1, 1, 1), bevel=0.):
    x, y, z = at
    a, b, c = (v*.5 for v in size)
    verts = [(x+dx*a, y+dy*b, z+dz*c) for dx, dy, dz in
        [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),
         (-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
    polys = [(0,3,2,1),(4,5,6,7),(0,1,5,4),(3,7,6,2),(0,4,7,3),(1,2,6,5)]
    if bevel:
        bm = bmesh.new()
        vs = [bm.verts.new(v) for v in verts]
        for f in polys:
            bm.faces.new([vs[i] for i in f])
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=2,
                        affect='EDGES', profile=.5)
        bm.verts.index_update()
        verts = [tuple(v.co) for v in bm.verts]
        polys = [tuple(v.index for v in f.verts) for f in bm.faces]
        bm.free()
    face(mat, verts, polys, color)


def sweep(mat, path, r, sides=7, color=(1,1,1,1), closed=False):
    verts = []
    path = [Vector(p) for p in path]
    previous_u = None
    for i, p in enumerate(path):
        if closed:
            tangent = (path[(i+1) % len(path)] - path[i-1]).normalized()
        else:
            tangent = (path[min(i+1, len(path)-1)] - path[max(i-1, 0)]).normalized()
        # Parallel-transport the frame. Rebuilding it from world-up at each
        # sample flips a vertical cable loop at its apex and folds a quad.
        u = (previous_u-tangent*previous_u.dot(tangent)) if previous_u is not None else tangent.cross(Vector((0,1,0)))
        if u.length < .01:
            u = tangent.cross(Vector((0,0,1)))
        u.normalize()
        previous_u = u.copy()
        v = tangent.cross(u)
        for j in range(sides):
            a = j * math.tau / sides
            verts.append(tuple(p + r*(math.cos(a)*u + math.sin(a)*v)))
    polys = []
    for i in range(len(path) if closed else len(path)-1):
        ni = (i+1) % len(path)
        for j in range(sides):
            k = (j+1) % sides
            polys.append((i*sides+j, i*sides+k, ni*sides+k, ni*sides+j))
    if not closed:
        polys.extend([tuple(range(sides-1,-1,-1)),
            tuple((len(path)-1)*sides+j for j in range(sides))])
    face(mat, verts, polys, color, True)


def tube(mat, a, b, r, sides=7, color=(1,1,1,1)):
    sweep(mat, [a,b], r, sides, color)


def lathe(mat, center, profile, n=48, color=(1,1,1,1)):
    x, y, z = center
    verts = [(x+r*math.cos(j*math.tau/n), y+yy, z+r*math.sin(j*math.tau/n))
             for r,yy in profile for j in range(n)]
    polys = []
    for k in range(len(profile)-1):
        for j in range(n):
            jj = (j+1) % n
            polys.append((k*n+j,(k+1)*n+j,(k+1)*n+jj,k*n+jj))
    polys.extend([tuple(range(n)),
                  tuple((len(profile)-1)*n+j for j in range(n-1,-1,-1))])
    face(mat, verts, polys, color, True)


def collision(label, at, size):
    MANIFEST['props'].append({'id': label, 'group': GROUP,
        'anchor_seed': ANCHOR['seed'], 'at': list(world(at)),
        'size': list(size), 'yaw': ANCHOR['rot'], 'local_at': list(at)})


def cane_color(light=1.):
    v = RAND.uniform(.78, 1.13) * light
    return (.37*v, .255*v, .145*v, 1)


def wicker_chair(x, z):
    # Real open weave, bent cane rails and separate legs. The back leans away
    # from the player; geometry remains under 0.63 m from the original wall.
    seat = .46
    for xx in [-.232,.232]:
        tube('wicker',(x+xx*.96,.045,z-.215),(x+xx,1.04,z-.27),.023,9,cane_color())
        tube('wicker',(x+xx*.98,.045,z+.225),(x+xx,.705,z+.17),.023,9,cane_color())
        sweep('wicker',[(x+xx,.68,z+.19),(x+xx,.735,z+.13),
            (x+xx,.74,z-.07),(x+xx,.71,z-.23)],.023,9,cane_color())
        tube('wicker',(x+xx,.22,z-.215),(x+xx,.22,z+.215),.015,8,cane_color(.8))
    for zz in [-.225,.225]:
        tube('wicker',(x-.24,seat,z+zz),(x+.24,seat,z+zz),.023,9,cane_color())
        tube('wicker',(x-.23,.22,z+zz),(x+.23,.22,z+zz),.015,8,cane_color(.8))
    for xx in [-.23,.23]:
        tube('wicker',(x+xx,seat,z-.225),(x+xx,seat,z+.225),.023,9,cane_color())
    # One smooth bent top/back frame, with 12 mm weave spacing and subtle
    # over-under motion rather than a solid grid texture.
    sweep('wicker',[(x-.232,.46,z-.225),(x-.245,.93,z-.269),
        (x-.205,1.035,z-.278),(x-.10,1.08,z-.28),(x+.10,1.08,z-.28),
        (x+.205,1.035,z-.278),(x+.245,.93,z-.269),(x+.232,.46,z-.225)],
        .024,9,cane_color())
    for i in range(23):
        a = -.198+i*.018
        path=[]
        for j in range(23):
            zz=-.198+j*.018
            path.append((x+a,seat+.007+math.cos((j+i)*math.pi)*.0045,z+zz))
        sweep('wicker',path,.0045,4,cane_color())
    for j in range(23):
        zz=-.198+j*.018
        path=[(x-.198+i*.018,seat+.007-math.cos((i+j)*math.pi)*.0045,z+zz)
              for i in range(23)]
        sweep('wicker',path,.0045,4,cane_color())
    for i in range(22):
        xx=-.19+i*.018
        path=[]
        for j in range(27):
            yy=.515+j*.018
            zz=z-.23-(yy-.46)*.091 + math.cos((j+i)*math.pi)*.0045
            path.append((x+xx,yy,zz))
        sweep('wicker',path,.0045,4,cane_color())
    for j in range(27):
        yy=.515+j*.018
        zz=z-.23-(yy-.46)*.091
        path=[(x-.19+i*.018,yy,zz-math.cos((i+j)*math.pi)*.0045) for i in range(22)]
        sweep('wicker',path,.0045,4,cane_color())
    # Wrapped ties at structural joints, staying visibly separate from the weave.
    for xx in [-.232,.232]:
        for yy,zz in [(.465,z+.225),(.465,z-.225),(.71,z-.24)]:
            for k in range(4):
                ang=[j*math.tau/10 for j in range(10)]
                sweep('wicker',[(x+xx+.027*math.cos(a),yy-.012+k*.008,
                                 zz+.027*math.sin(a)) for a in ang],
                      .003,4,cane_color(.63),True)
    collision('bent_cane_chair',(x,.56,z-.015),(.53,1.07,.55))


def enamel_basin(x,z):
    # Small splayed stool; basin is a closed profile with outer and inner wall,
    # rolled lip, bottom thickness and visible water-free concave interior.
    y=.375
    for xx in [-.145,.145]:
        for zz in [-.13,.13]:
            tube('wood',(x+xx*1.13,.045,z+zz*1.13),(x+xx,y-.02,z+zz),.027,8,(.65,.62,.50,1))
    for zz in [-.13,.13]:
        tube('wood',(x-.16,.15,z+zz),(x+.16,.15,z+zz),.014,7,(.60,.56,.45,1))
    for j in range(3):
        box('wood',(x,y,z-.12+j*.12),(.385,.045,.10),(.78,.75,.65,1),.009)
    profile=[(.001,.0),(.13,.0),(.17,.009),(.186,.026),(.235,.137),
             (.246,.15),(.257,.154),(.262,.163),(.258,.171),(.248,.173),
             (.24,.165),(.237,.151),(.178,.037),(.159,.025),(.001,.025)]
    lathe('enamel',(x,y+.027,z),profile,64,(.72,.74,.67,1))
    # Navy rim, enamel chips and exposed dark iron; profiles remain watertight.
    # The old ring was buried inside the solid rolled lip. Rest the blue
    # enamel on its exposed crest: basin origin + .027, white crest + .173.
    rim_y=y+.027+.176
    rim_r=.252
    sweep('enamel_flower',[(x+rim_r*math.cos(a),rim_y,z+rim_r*math.sin(a))
          for a in [j*math.tau/64 for j in range(64)]],.0045,6,(.035,.070,.105,1),True)
    for a in [1.95,3.20,4.04]:
        ang=[a+(j-3)*.025 for j in range(7)]
        sweep('enamel_flower',[(x+rim_r*math.cos(t),rim_y,z+rim_r*math.sin(t)) for t in ang],
              .0055,5,(.12,.10,.075,1))
    # Small hand-painted red flowers follow the outer curved wall.
    for angle in [.4,1.1,1.85,2.65,3.55,4.4,5.3]:
        for k in range(5):
            a=k*math.tau/5
            yy=y+.027+.087+math.sin(a)*.019
            theta=angle+math.cos(a)*.075
            rr=.186+(.235-.186)*((yy-y-.027-.026)/.111)+.0018
            verts=[(x+rr*math.cos(theta),yy,z+rr*math.sin(theta))]
            for j in range(9):
                aa=j*math.tau/8
                yy2=yy+math.sin(aa)*.010
                t=theta+math.cos(aa)*.042
                r2=.186+(.235-.186)*((yy2-y-.027-.026)/.111)+.0022
                verts.append((x+r2*math.cos(t),yy2,z+r2*math.sin(t)))
            # theta increases around the bowl, height increases upward. Their
            # old fan winding pointed inward, so Godot correctly culled it.
            face('enamel_flower',verts,[(0,j+2,j+1) for j in range(8)],(.42,.085,.055,1),True)
    collision('basin_stool',(x,.29,z),(.54,.51,.54))


def wire_coil(x,y,z):
    # Six irregular overlapping loops hang from a real hook. Only 7 mm radius;
    # open centre and a loose cut tail read as cable rather than a tyre.
    for j in range(6):
        path=[]
        for i in range(58):
            a=i*math.tau/58
            r=.22+.012*math.sin(3*a+j)+j*.003
            path.append((x+math.cos(a)*r,y+math.sin(a)*r,z+.015*j))
        sweep('metal',path,.008,6,(.14,.18,.17,1),True)
    sweep('metal',[(x+.02,y+.20,z),(x+.03,y+.09,z+.07),
          (x+.01,y-.14,z+.13),(x+.10,y-.33,z+.12),
          (x+.18,y-.39,z+.1)],.008,6,(.15,.16,.15,1))
    tube('rust',(x,y+.24,z-.035),(x,y+.24,z+.12),.009,7,(.65,.45,.3,1))
    box('rust',(x,y+.24,z-.02),(.09,.08,.035),(.75,.61,.42,1),.004)


def drawer_unit(x,z):
    # A narrow old electrical-parts apothecary cabinet: eight inset fronts,
    # one partly open drawer with a real empty interior, brass card holders.
    w,h,d=.65,.83,.34
    for xx in [-w/2,w/2]:
        box('wood',(x+xx,h/2+.05,z),(.035,h,d),(.60,.58,.48,1),.005)
    box('wood',(x,h/2+.05,z-d/2),(.65,h,.025),(.46,.44,.37,1))
    for yy in [.05,.25,.45,.65,.88]:
        box('wood',(x,yy,z),(.71,.035,d+.05),(.73,.69,.55,1),.007)
    box('wood',(x,.47,z),(.025,.8,d),(.60,.57,.47,1))
    for j in range(4):
        for i in range(2):
            xx=x+(-1 if i==0 else 1)*.166
            yy=.15+j*.2
            extended=.11 if (i,j)==(1,2) else 0
            face_z=z+d/2+extended
            box('wood',(xx,yy,face_z),(.294,.161,.025),
                (.75-j*.03,.68-j*.025,.52-j*.02,1),.005)
            if extended:
                box('wood',(xx,yy-.066,z+.07),(.27,.018,.39),(.48,.43,.32,1))
                for side in [-1,1]:
                    box('wood',(xx+side*.137,yy,z+.07),(.014,.13,.39),(.53,.47,.35,1))
            box('metal',(xx,yy+.02,face_z+.018),(.11,.052,.008),(.62,.52,.31,1),.002)
            box('paper',(xx,yy+.02,face_z+.023),(.075,.032,.003),(.75,.68,.49,1))
            sweep('metal',[(xx-.034,yy-.032,face_z+.021),(xx-.029,yy-.052,face_z+.045),
                (xx+.029,yy-.052,face_z+.045),(xx+.034,yy-.032,face_z+.021)],
                .0045,6,(.61,.49,.27,1))
    # Open bulb carton, six independent A-shaped glass envelopes with separate
    # screw bases. The neck emerges above the dividers, not as white marbles.
    by=.934
    box('paper',(x-.10,by-.03,z+.015),(.32,.055,.22),(.65,.56,.38,1),.004)
    for xx in [-.16,.16]:
        box('paper',(x-.10+xx,by+.045,z+.015),(.012,.145,.23),(.7,.61,.43,1))
    for zz in [-.11,.11]:
        box('paper',(x-.10,by+.045,z+.015+zz),(.32,.145,.012),(.7,.61,.43,1))
    for i in range(3):
        for j in range(2):
            bx=x-.20+i*.10;bz=z-.035+j*.10
            lathe('metal',(bx,by+.023,bz),[(.001,0),(.013,0),(.016,.006),
                (.016,.032),(.013,.037),(.001,.037)],32,(.67,.58,.38,1))
            for thread in range(4):
                ring=[(bx+.017*math.cos(a),by+.030+thread*.006,
                       bz+.017*math.sin(a)) for a in [k*math.tau/32 for k in range(32)]]
                sweep('metal',ring,.0015,5,(.60,.55,.43,1),True)
            lathe('enamel',(bx,by+.055,bz),[(.001,0),(.012,0),(.013,.012),
                (.018,.022),(.025,.034),(.031,.047),(.033,.058),
                (.032,.070),(.027,.081),(.019,.089),(.009,.094),(.001,.095)],
                40,(.62,.65,.59,1))
    collision('electrical_drawer_unit',(x,.49,z+.025),(.73,.91,.50))


def tile_stack(x,z):
    # Separate hollow curved clay tiles with chipped ends and real thickness.
    for row in range(2):
        for level in range(6):
            y=.06+level*.057
            xx=x+(row-.5)*.20+RAND.uniform(-.013,.013)
            zz=z+RAND.uniform(-.015,.015)
            verts=[]
            for end in [-1,1]:
                for inner in [False,True]:
                    for j in range(13):
                        a=.12+j*(math.pi-.24)/12
                        r=.125 if not inner else .107
                        verts.append((xx+r*math.cos(a),y+r*math.sin(a),zz+end*.24))
            polys=[]
            for j in range(12):
                polys.append((j,j+1,26+j+1,26+j))
                polys.append((13+j,39+j,39+j+1,13+j+1))
                for end in [0,26]:
                    polys.append((end+j,end+13+j,end+13+j+1,end+j+1))
            for j in [0,12]:polys.append((j,26+j,39+j,13+j))
            v=RAND.uniform(.65,.95)
            face('concrete',verts,polys,(v*.67,v*.59,v*.47,1),True)
    # Two intact tiles leaned against the wall behind the stack.
    for i in range(2):
        tube('wood',(x-.23+i*.35,.08,z-.10),(x-.23+i*.35,.52,z-.22),.012,6,(.4,.34,.23,1))
    collision('old_clay_tile_stack',(x,.28,z),(.49,.48,.52))


def weeds(x,z,seed):
    r=random.Random(seed)
    for k in range(19):
        a=r.random()*math.tau;length=r.uniform(.16,.44);width=r.uniform(.009,.021)
        bx=x+r.uniform(-.06,.06);bz=z+r.uniform(-.06,.06)
        dx,dz=math.cos(a),math.sin(a)
        vv=[(bx-width*dz,.046,bz+width*dx),(bx+width*dz,.046,bz-width*dx),
            (bx+dx*length*.30+width*.65*dz,.046+length*.62,bz+dz*length*.30-width*.65*dx),
            (bx+dx*length*.66,.046+length*.84,bz+dz*length*.66),
            (bx+dx*length*.30-width*.65*dz,.046+length*.62,bz+dz*length*.30+width*.65*dx)]
        # Match the later small wall-joint growth and keep both shapes in one
        # native plant batch instead of maintaining two dark-tinted materials.
        value=r.uniform(.78,1.08)
        face('verge_green',vv,[(0,1,2,3,4)],(.075*value,.105*value,.030*value,1))


def small_weeds(x,z,seed,height=.14):
    # Sparse wall-joint growth: bent leaves with a central fold, not crossed cards.
    # Native vertex colours retain green/brown variation without a second dark tint.
    r=random.Random(seed)
    for k in range(14):
        angle=r.random()*math.tau;dx,dz=math.cos(angle),math.sin(angle)
        bx=x+r.uniform(-.022,.022);bz=z+r.uniform(-.016,.016)
        leaf_height=height*r.uniform(.45,1.0)
        reach=r.uniform(.025,.075);width=r.uniform(.003,.008)
        verts=[]
        for t,flare in [(0.,.35),(.43,1.),(.78,.60)]:
            cx=bx+dx*reach*t*t;cz=max(.065,bz+dz*reach*t*t)
            yy=.036+leaf_height*t
            for side in [-1,0,1]:
                verts.append((cx-side*dz*width*flare,yy+(.0018 if side==0 else 0.),cz+side*dx*width*flare))
        verts.append((bx+dx*reach,.036+leaf_height,max(.065,bz+dz*reach)))
        polys=[(a,a+1,a+4,a+3) for a in [0,1,3,4]]+[(6,7,9),(7,8,9)]
        value=r.uniform(.75,1.15)
        color=(.070*value,.105*value,.027*value,1) if k%5 else (.15*value,.13*value,.055*value,1)
        face('verge_green',verts,polys,color,True)
    MANIFEST.setdefault('small_weeds',[]).append({'seed':seed,'anchor_seed':ANCHOR['seed'],
        'root':list(world((x,.036,z))),'height_m':round(height,3),'collision':False})


def drying_rack():
    # A household drying rack is fixed above head height, within the facade strip.
    for x in [-1.05,1.05]:
        tube('rust',(x,3.65,.035),(x,3.65,.60),.017,8)
        tube('rust',(x,3.30,.035),(x,3.65,.55),.013,8)
    tube('metal',(-1.05,3.65,.58),(1.05,3.65,.58),.009,8)
    for index,(cx,color) in enumerate([(-.43,(.47,.56,.53,1)),(.39,(.68,.60,.43,1))]):
        verts=[];nx,ny=8,13;width=.57;height=.98 if index==0 else .79
        for j in range(ny):
            t=j/(ny-1)
            for i in range(nx):
                u=i/(nx-1);fold=math.sin(u*math.tau*2.4)*.032*(.25+.75*t)
                verts.append((cx+(u-.5)*width,3.64-height*t-.018*math.sin(u*math.pi),.58+fold+.018*t*t))
        polys=[]
        for j in range(ny-1):
            for i in range(nx-1):
                a=j*nx+i;polys.append((a,a+1,a+1+nx,a+nx))
        face('linen',verts,polys,color,True)
        for dx in [-.19,.19]:
            box('wood',(cx+dx,3.65,.582),(.018,.065,.026),(.7,.57,.37,1),.003)


def profile_along_x(mat, profile_yz, left, right, color):
    """Closed folded-sheet section, not a plane laid across a doorway."""
    n=len(profile_yz)
    vv=[(x,y,z) for x in [left,right] for y,z in profile_yz]
    ff=[tuple(range(n-1,-1,-1)),tuple(n+i for i in range(n))]
    ff.extend((i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n))
    face(mat,vv,ff,color)


def wall_repair(left,right,bottom,top,seed):
    # Local bedded mortar, cut with an irregular outline and 8-13mm thickness.
    # The back intersects the old masonry rather than hovering in front of it.
    r=random.Random(seed)
    outline=[(left,bottom+.035),(left+.10,bottom),
        (right-.08,bottom+.014),(right,bottom+.10),
        (right-.025,top-.11),(right-.11,top),
        (left+(right-left)*.42,top-.045),(left+.018,top-.14)]
    n=len(outline)
    outer=[(x,y,.035+r.uniform(-.002,.003)) for x,y in outline]
    inner=[(x,y,.016) for x,y in outline]
    # Positive Z is facade outward. Counterclockwise front and reversed back.
    vv=outer+inner
    ff=[tuple(range(n)),tuple(n+i for i in range(n-1,-1,-1))]
    ff.extend((i,n+i,n+(i+1)%n,(i+1)%n) for i in range(n))
    face('concrete',vv,ff,(.91,.90,.81,1))
    # Three real shallow trowel joints near the repair's lower edge. These
    # recesses are masonry returns, not floating dirt/decal planes.
    for i in range(3):
        xx=left+.09+i*(right-left-.16)/3
        box('concrete',(xx,bottom+.046,.031),
            (.10,.013,.013),(.58,.61,.55,1),.003)


def drip_flashing():
    # Existing awning has corrugation, braces and a rectangular front batten.
    # This slim Z-fold wraps only that batten's exposed edge, with a return
    # below it to break surface tension and keep runoff away from the facade.
    w=min(ANCHOR['w']*.72,4.4)
    yy=2.7
    p=[(yy-.120,.778),(yy-.120,.807),
       (yy-.218,.807),(yy-.235,.824),
       (yy-.232,.827),(yy-.215,.811),
       (yy-.116,.811),(yy-.116,.778)]
    profile_along_x('galvanized',p,-w/2-.012,w/2+.012,(.72,.74,.71,1))
    for xx in [-w*.40,0,w*.40]:
        # Fixings have a washer and closed shank; no unsupported extra pipes.
        tube('galvanized',(xx,yy-.155,.799),(xx,yy-.155,.818),.0065,10,(.61,.64,.64,1))
        ring=[(xx+.011*math.cos(a),yy-.155+.011*math.sin(a),.815)
              for a in [j*math.tau/12 for j in range(12)]]
        sweep('galvanized',ring,.002,5,(.66,.67,.62,1),True)
    # Existing downpipe is at the far negative jamb. A rain chain is avoided:
    # it would occupy the resident/player corridor below this overhead trim.


def entrance_craft(shop=False):
    global DETAIL_ID
    DETAIL_ID='drip_flashing'
    drip_flashing()
    DETAIL_ID='threshold_nosing'
    if shop:
        # The open shop remains 1.6m wide. An 11mm return sits at paving level,
        # not a new high step or a collider placed across its opening.
        profile_along_x('galvanized',[(.036,.012),(.036,.071),
            (.046,.071),(.046,.065),(.042,.065),(.042,.012)],
            -.785,.785,(.64,.65,.60,1))
    else:
        # Existing stone sill ends at z=.60, y=.09. Only its worn nose receives
        # a flush bevel; the maximum height is unchanged.
        profile_along_x('concrete',[(.039,.578),(.078,.578),(.089,.591),
            (.089,.599),(.077,.614),(.039,.614)],-.642,.642,(.94,.92,.85,1))
        # A tiny bedded repair at one jamb has real end faces and no extra box
        # collision; it remains entirely behind the resident walking strip.
        DETAIL_ID='threshold_jamb_repair'
        box('concrete',(-.65,.135,.034),(.055,.18,.025),(.74,.74,.67,1),.006)
    DETAIL_ID='bedded_mortar_repair'
    if shop:
        wall_repair(.98,1.33,.10,.55,58421)
        wall_repair(-2.35,-1.90,.09,.40,58422)
    else:
        wall_repair(.85,1.30,.10,.56,58423)
        wall_repair(2.78,3.11,.11,.49,58424)
    # Runoff leaves a localized, moss-coloured coarse mortar return below the
    # actual downpipe outlet. No broad planar stain covers masonry or windows.
    DETAIL_ID='drain_outlet_splash_repair'
    px=-ANCHOR['w']/2+.13
    box('concrete',(px+.055,.085,.046),(.22,.083,.032),(.45,.50,.39,1),.012)
    DETAIL_ID=None


set_anchor(579349,'doorstep_cane')
wicker_chair(-1.20,.315)
enamel_basin(-1.92,.285)
weeds(-.80,.095,3271)
for i,(x,z) in enumerate([(-3.02,.08),(-2.77,.10),(.96,.08),(1.32,.10),(1.85,.09),(3.04,.08)]):
    small_weeds(x,z,8201+i,[.10,.16,.09,.13,.17,.12][i])
# One tiny tuft at the outside edge of the existing foreground drain, derived
# from the same road-point rule as the grate. Never cover its water opening.
for road in DATA['roads']:
    if road['id']!='r_main':continue
    pts=road['points']
    for j in range(3,len(pts)-1,11):
        x,z=pts[j];xx,zz=pts[j+1];yaw=math.atan2(xx-x,zz-z)
        offset=(1 if j%2 else -1)*(road['width']/2+.07)
        wx,wz=x+offset*math.cos(yaw),z-offset*math.sin(yaw)
        if not (150<wx<158 and 120<wz<128):continue
        c,s=math.cos(ANCHOR['rot']),math.sin(ANCHOR['rot'])
        dx,dz=wx-ANCHOR['fx'],wz-ANCHOR['fz']
        small_weeds(dx*c-dz*s,dx*s+dz*c,8250,.08)
entrance_craft(shop=False)

set_anchor(551335,'electrical_shop')
drawer_unit(-1.35,.225)
wire_coil(-1.38,1.46,.105)
weeds(-1.81,.10,4520)
for i,(x,z) in enumerate([(-2.40,.08),(-2.12,.08),(1.12,.08),(1.43,.07)]):
    small_weeds(x,z,8301+i,[.12,.17,.10,.14][i])
entrance_craft(shop=True)

set_anchor(993505,'tile_corner')
tile_stack(-1.38,.28)
weeds(-1.03,.08,4512)
weeds(-1.77,.07,4513)
drying_rack()
for i,(x,z) in enumerate([(-3.05,.08),(-2.78,.10),(-2.02,.09),(.98,.08),(1.40,.10),(1.95,.09)]):
    small_weeds(x,z,8401+i,[.16,.11,.14,.09,.18,.12][i])


def segment_distance(p,a,b):
    ax,az=a;bx,bz=b;px,pz=p
    dx,dz=bx-ax,bz-az
    t=max(0.,min(1.,((px-ax)*dx+(pz-az)*dz)/(dx*dx+dz*dz)))
    return math.hypot(px-ax-t*dx,pz-az-t*dz)


def min_road_clearance(points):
    clearance=1.e9
    for p in points:
        for road in DATA['roads']:
            pts=road['points']
            for a,b in zip(pts[:-1],pts[1:]):
                clearance=min(clearance,segment_distance(p,a,b)-road['width']/2)
    return clearance


# Door/collision validation is measured from the same object declarations, not
# hand-maintained hardcoded world positions. Exact contact checked in Godot too.
valid=[]
for prop in MANIFEST['props']:
    b=BUILDINGS[prop['anchor_seed']]
    x,y,z=prop['local_at'];w,h,d=prop['size'];yaw=prop['yaw']
    c,s=math.cos(yaw),math.sin(yaw)
    points=[]
    for xx in [x-w/2,x,x+w/2]:
        for zz in [z-d/2,z,z+d/2]:
            points.append((b['fx']+xx*c+zz*s,b['fz']-xx*s+zz*c))
    # Distance to rectangular footprint (not only its centre).
    door=math.hypot(max(abs(x)-w/2,0),max(abs(z)-d/2,0))
    road=min_road_clearance(points)
    valid.append({'id':prop['id'],'door_clearance_m':round(door,4),
                  'road_edge_clearance_m':round(road,4)})
    if door < .65:
        raise ValueError('Prop violates protected doorway: '+prop['id'])
    if road < -.01:
        raise ValueError('Prop extends into road: '+prop['id']+' '+str(road))
MANIFEST['validation']['clearances']=valid

# The actor movement specification is supplied by the runtime owner. Keep a
# swept capsule corridor in the same local facade coordinates for QA; do not
# infer that a stationary source model has already passed gameplay testing.
NPC_ROUTES=[{'id':'resident_shopkeeper','seed':551335,'side_min':.68,'side_max':1.40},
            {'id':'resident_woman','seed':579349,'side_min':.78,'side_max':1.50}]
MANIFEST['npc_swept_corridors']=[]
for route in NPC_ROUTES:
    route=dict(route,outward_m=.42,capsule_radius_m=.24,
               capsule_bottom_m=.04,capsule_top_m=1.90,safety_margin_m=.025)
    MANIFEST['npc_swept_corridors'].append(route)
MANIFEST['frontage_details']=[]
for (seed,label,kind),verts in DETAIL_VERTS.items():
    lo=[min(v[i] for v in verts) for i in range(3)]
    hi=[max(v[i] for v in verts) for i in range(3)]
    MANIFEST['frontage_details'].append({'seed':seed,'detail':label,'material':kind,
        'bounds_local':[lo,hi],'solid_geometry':True})
    for route in MANIFEST['npc_swept_corridors']:
        if route['seed']!=seed:continue
        pad=route['capsule_radius_m']+route['safety_margin_m']
        # Low existing threshold repairs retain their old height; roof trim is
        # checked against full standing height, not only against the feet.
        overlap_x=hi[0]>route['side_min']-pad and lo[0]<route['side_max']+pad
        overlap_y=hi[1]>.10 and lo[1]<route['capsule_top_m']
        overlap_z=hi[2]>route['outward_m']-pad and lo[2]<route['outward_m']+pad
        if overlap_x and overlap_y and overlap_z:
            raise ValueError('Detail enters resident walking corridor: '+str(seed)+' '+label)
MANIFEST['validation']['new_detail_npc_corridor_overlap']=False

basecolors={'wood':(.38,.28,.16,1),'metal':(.28,.31,.28,1),
    'rust':(.38,.22,.12,1),'concrete':(.46,.44,.37,1),'paper':(.67,.60,.44,1),
    'grass':(.23,.30,.12,1),'leaf':(.18,.27,.13,1),
    'wicker':(1,1,1,1),'enamel':(1,1,1,1),'enamel_flower':(1,1,1,1),'linen':(1,1,1,1),'verge_green':(1,1,1,1),
    'galvanized':(.59,.62,.63,1)}
materials={}
for kind in sorted(set(k[1] for k in GEOM)):
    m=bpy.data.materials.new(kind);m.use_nodes=True
    bsdf=m.node_tree.nodes['Principled BSDF']
    bsdf.inputs['Base Color'].default_value=basecolors[kind]
    bsdf.inputs['Roughness'].default_value=.30 if kind=='enamel' else (.39 if kind=='enamel_flower' else (.55 if kind=='galvanized' else .83))
    bsdf.inputs['Metallic'].default_value=1. if kind in ['metal','galvanized'] else 0.
    if kind=='enamel':bsdf.inputs['Coat Weight'].default_value=.22
    col=m.node_tree.nodes.new('ShaderNodeVertexColor');col.layer_name='Color'
    if kind in ['wicker','enamel','enamel_flower','linen','verge_green']:
        m.node_tree.links.new(col.outputs['Color'],bsdf.inputs['Base Color'])
    m.diffuse_color=basecolors[kind]
    m.use_backface_culling=kind not in ['grass','leaf','linen','verge_green']
    if kind=='linen':bsdf.inputs['Sheen Weight'].default_value=.22
    materials[kind]=m

groups=defaultdict(list)
total_verts=total_tris=0
stats={}
group_bounds={}
zero_area=0
for (group,kind),(vv,ff,cc,ss) in sorted(GEOM.items()):
    mesh=bpy.data.meshes.new(kind);mesh.from_pydata(vv,[],ff);mesh.update()
    mesh.materials.append(materials[kind])
    zero_area+=sum(p.area<1.e-12 for p in mesh.polygons)
    if any(not math.isfinite(v) for p in vv for v in p):
        raise ValueError('Non-finite vertex in '+group+'/'+kind)
    bounds=group_bounds.setdefault(group,[[float('inf')]*3,[-float('inf')]*3])
    for px,pz,py in vv:
        for axis,value in enumerate((px,py,-pz)):
            bounds[0][axis]=min(bounds[0][axis],value)
            bounds[1][axis]=max(bounds[1][axis],value)
    col=mesh.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='POINT')
    col.data.foreach_set('color',[v for color in cc for v in color])
    for poly,smooth in zip(mesh.polygons,ss):poly.use_smooth=smooth
    # UVs are a useful fallback for inspection/export; runtime shared materials
    # use world-projection. Native cane/enamel carry vertex colour directly.
    uv=mesh.uv_layers.new(name='UVMap')
    for poly in mesh.polygons:
        n=poly.normal
        for li in poly.loop_indices:
            p=mesh.vertices[mesh.loops[li].vertex_index].co
            if abs(n.z)>.6:u,v=p.x,p.y
            elif abs(n.y)>.6:u,v=p.x,p.z
            else:u,v=p.y,p.z
            uv.data[li].uv=(u,v)
    obj=bpy.data.objects.new(kind,mesh);bpy.context.collection.objects.link(obj)
    groups[group].append(obj)
    mesh.calc_loop_triangles()
    tris=len(mesh.loop_triangles)
    total_verts+=len(vv);total_tris+=tris
    stats[group+'/'+kind]={'vertices':len(vv),'triangles':tris}
if total_tris>60000:raise ValueError('Exceeded new prop triangle budget: '+str(total_tris))
if len(GEOM)>20:raise ValueError('Exceeded material batch budget: '+str(len(GEOM)))
if zero_area:raise ValueError('Degenerate polygons: '+str(zero_area))
for group,objs in groups.items():
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objs:obj.select_set(True)
    filename=group+'.glb'
    bpy.ops.export_scene.gltf(filepath=str(OUT/filename),export_format='GLB',use_selection=True,
        export_yup=True,export_normals=True,export_texcoords=True,
        export_vertex_color='ACTIVE',export_all_vertex_colors=True,
        export_materials='EXPORT',export_cameras=False,export_lights=False,
        export_animations=False)
    MANIFEST['chunks'].append('res://assets/town/renewal/hero_props/'+filename)
MANIFEST['counts']={'vertices':total_verts,'triangles':total_tris,
    'material_batches':len(GEOM),'glb_bytes':sum((OUT/(g+'.glb')).stat().st_size for g in groups)}
MANIFEST['geometry']=stats
MANIFEST['bounds_godot']=group_bounds
MANIFEST['validation']['zero_area_polygons']=zero_area
MANIFEST['validation']['door_protection_m']=.65
MANIFEST['validation']['road_volume_overlap']=False
(OUT/'hero_props_manifest.json').write_text(json.dumps(MANIFEST,ensure_ascii=False,indent=2),encoding='utf8')
bpy.ops.object.select_all(action='SELECT')
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'source_art/street_hero_props_v1.blend'),compress=True)
print('STREET_HERO_PROPS_BUILT',json.dumps(MANIFEST['counts']),flush=True)
