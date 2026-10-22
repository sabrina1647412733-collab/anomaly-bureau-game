extends SceneTree
## Non-destructive facial blend meshes; original character GLBs and skin stay intact.
const OUT := "res://assets/models/chars/performance/"
const Actor := preload("res://scripts/laundry/char_actor.gd")
var face:Dictionary
var width:float
var original:Array
var output:Array
var shapes:Array
var head_count:=0

func _initialize():call_deferred("run")
func vec(a:Array)->Vector3:return Vector3(a[0],a[1],a[2])
func run():
	var config=JSON.parse_string(FileAccess.get_file_as_string(OUT+"landmarks.json"))
	var audit={}
	for id in ["zhou","laozhou","aqi"]:
		var instance=load(Actor.file_of(id)).instantiate();root.add_child(instance)
		var visual:MeshInstance3D=instance.find_children("*","MeshInstance3D",true,false)[0]
		face={"mouth":vec(config[id][0]),"eyes":[vec(config[id][1]),vec(config[id][2])]}
		width={"zhou":.027,"laozhou":.037,"aqi":.029}[id]
		original=visual.mesh.surface_get_arrays(0)
		output=[];output.resize(Mesh.ARRAY_MAX)
		output[Mesh.ARRAY_VERTEX]=PackedVector3Array();output[Mesh.ARRAY_NORMAL]=PackedVector3Array()
		output[Mesh.ARRAY_TANGENT]=PackedFloat32Array();output[Mesh.ARRAY_TEX_UV]=PackedVector2Array()
		output[Mesh.ARRAY_BONES]=PackedInt32Array();output[Mesh.ARRAY_WEIGHTS]=PackedFloat32Array()
		shapes=[]
		for i in 4:
			var blend=[];blend.resize(Mesh.ARRAY_MAX)
			blend[Mesh.ARRAY_VERTEX]=PackedVector3Array();blend[Mesh.ARRAY_NORMAL]=PackedVector3Array();blend[Mesh.ARRAY_TANGENT]=PackedFloat32Array()
			shapes.append(blend)
		var indices:PackedInt32Array=original[Mesh.ARRAY_INDEX]
		head_count=0
		for i in range(0,indices.size(),3):
			var triangle=[vertex(indices[i]),vertex(indices[i+1]),vertex(indices[i+2])]
			var lo:float=minf(triangle[0].p.y,minf(triangle[1].p.y,triangle[2].p.y))
			var hi:float=maxf(triangle[0].p.y,maxf(triangle[1].p.y,triangle[2].p.y))
			var near_mouth=false
			for v in triangle:
				if absf(v.p.x-face.mouth.x)<width*1.6 and v.p.z>face.mouth.z-.05:near_mouth=true
			if near_mouth and lo<face.mouth.y and hi>face.mouth.y:
				emit_polygon(clip(triangle,true),false)
				emit_polygon(clip(triangle,false),true)
			else:emit_polygon(triangle,hi<=face.mouth.y)
		var mesh=ArrayMesh.new()
		mesh.blend_shape_mode=Mesh.BLEND_SHAPE_MODE_NORMALIZED
		for name in ["SpeechOpen","Blink","Concern","Relief"]:mesh.add_blend_shape(name)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,output,shapes)
		add_cavity(mesh)
		var result=ResourceSaver.save(mesh,OUT+id+"_face.res",ResourceSaver.FLAG_COMPRESS)
		audit[id]={"result":result,"original_vertices":original[Mesh.ARRAY_VERTEX].size(),"vertices":output[Mesh.ARRAY_VERTEX].size(),"moving_face_vertices":head_count,"shapes":4,"surfaces":2}
		print(id," ",audit[id])
		instance.free()
	var file=FileAccess.open(OUT+"audit.json",FileAccess.WRITE);file.store_string(JSON.stringify(audit,"  "));file.close()
	quit()

func vertex(i:int)->Dictionary:
	var bones=[];var weights=[]
	for j in 4:bones.append(original[Mesh.ARRAY_BONES][i*4+j]);weights.append(original[Mesh.ARRAY_WEIGHTS][i*4+j])
	var tangent=Vector4(1,0,0,1)
	if original[Mesh.ARRAY_TANGENT]!=null and original[Mesh.ARRAY_TANGENT].size()>i*4+3:
		tangent=Vector4(original[Mesh.ARRAY_TANGENT][i*4],original[Mesh.ARRAY_TANGENT][i*4+1],original[Mesh.ARRAY_TANGENT][i*4+2],original[Mesh.ARRAY_TANGENT][i*4+3])
	return {"p":original[Mesh.ARRAY_VERTEX][i],"n":original[Mesh.ARRAY_NORMAL][i],"uv":original[Mesh.ARRAY_TEX_UV][i],"t":tangent,"b":bones,"w":weights}

func interpolate(a:Dictionary,b:Dictionary,t:float)->Dictionary:
	var weights={}
	for j in 4:
		weights[a.b[j]]=float(weights.get(a.b[j],0))+a.w[j]*(1-t)
		weights[b.b[j]]=float(weights.get(b.b[j],0))+b.w[j]*t
	var keys=weights.keys();keys.sort_custom(func(x,y):return weights[x]>weights[y])
	var bones=[0,0,0,0];var values=[0.,0.,0.,0.];var total=0.
	for j in mini(4,keys.size()):bones[j]=keys[j];values[j]=weights[keys[j]];total+=values[j]
	for j in 4:values[j]/=maxf(.0001,total)
	return {"p":a.p.lerp(b.p,t),"n":a.n.lerp(b.n,t).normalized(),"uv":a.uv.lerp(b.uv,t),"t":a.t.lerp(b.t,t),"b":bones,"w":values}

func clip(polygon:Array,upper:bool)->Array:
	var result=[]
	for i in polygon.size():
		var a:Dictionary=polygon[i];var b:Dictionary=polygon[(i+1)%polygon.size()]
		var ia:bool=a.p.y>=face.mouth.y if upper else a.p.y<=face.mouth.y
		var ib:bool=b.p.y>=face.mouth.y if upper else b.p.y<=face.mouth.y
		if ia:result.append(a)
		if ia!=ib:result.append(interpolate(a,b,(face.mouth.y-a.p.y)/(b.p.y-a.p.y)))
	return result

func emit_polygon(polygon:Array,lower:bool)->void:
	for i in range(1,polygon.size()-1):
		subdivide([polygon[0],polygon[i],polygon[i+1]],lower,0)

func subdivide(triangle:Array,lower:bool,depth:int)->void:
	var local_face=false;var eye_detail=false
	for v in triangle:
		if v.p.y>face.mouth.y-.075 and v.p.z>face.mouth.z-.065 and absf(v.p.x)<.12:local_face=true
		for eye in face.eyes:
			if absf(v.p.y-eye.y)<.05 and absf(v.p.x-eye.x)<.045 and v.p.z>eye.z-.04:eye_detail=true
	if local_face and depth<(3 if eye_detail else 2):
		var a:Dictionary=triangle[0];var b:Dictionary=triangle[1];var c:Dictionary=triangle[2]
		var ab=interpolate(a,b,.5);var bc=interpolate(b,c,.5);var ca=interpolate(c,a,.5)
		for child in [[a,ab,ca],[ab,b,bc],[ca,bc,c],[ab,bc,ca]]:subdivide(child,lower,depth+1)
	else:
		for v in triangle:emit_vertex(v,lower)

func mouth_weight(p:Vector3)->float:
	var wx=pow(maxf(0,1-pow((p.x-face.mouth.x)/width,2)),.65)
	return wx*clampf((p.z-face.mouth.z+.05)/.03,0,1)*clampf(1+(p.y-face.mouth.y)/.075,0,1)

func moved(p:Vector3,kind:int,lower:bool)->Vector3:
	var q=p
	if kind==0 and lower:
		var w=mouth_weight(p);q.y-=.013*w;q.z-=.0015*w
	elif kind==1:
		for eye in face.eyes:
			var wx=clampf((.025-absf(p.x-eye.x))/.008,0,1)
			var wy=1-smoothstep(.009,.028,absf(p.y-eye.y))
			var w=wx*wy*clampf((p.z-eye.z+.04)/.02,0,1)
			q.y-=(p.y-eye.y)*.97*w
	elif kind in [2,3]:
		for eye in face.eyes:
			var brow:Vector3=eye+Vector3(0,.023,0)
			var d=Vector2((p.x-brow.x)/.026,(p.y-brow.y)/.018)
			var w=maxf(0,1-d.length_squared())*clampf((p.z-eye.z+.02)/.016,0,1)
			var inner=clampf(1-absf(p.x)/.055,0,1)
			q.y+=(.005*inner if kind==2 else -.002)*w
		var lip=Vector2((absf(p.x-face.mouth.x)-width*.7)/.014,(p.y-face.mouth.y)/.018)
		var w=maxf(0,1-lip.length_squared())*clampf((p.z-face.mouth.z+.03)/.02,0,1)
		q.y+=(.003 if kind==3 else -.002)*w
	return q

func emit_vertex(v:Dictionary,lower:bool)->void:
	output[Mesh.ARRAY_VERTEX].append(v.p);output[Mesh.ARRAY_NORMAL].append(v.n);output[Mesh.ARRAY_TEX_UV].append(v.uv)
	for x in [v.t.x,v.t.y,v.t.z,v.t.w]:output[Mesh.ARRAY_TANGENT].append(x)
	for x in v.b:output[Mesh.ARRAY_BONES].append(x)
	for x in v.w:output[Mesh.ARRAY_WEIGHTS].append(x)
	for kind in 4:
		var p=moved(v.p,kind,lower)
		if p!=v.p and kind==0:head_count+=1
		shapes[kind][Mesh.ARRAY_VERTEX].append(p);shapes[kind][Mesh.ARRAY_NORMAL].append(v.n)
		for x in [v.t.x,v.t.y,v.t.z,v.t.w]:shapes[kind][Mesh.ARRAY_TANGENT].append(x)

func add_cavity(mesh:ArrayMesh)->void:
	var a=[];a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX]=PackedVector3Array();a[Mesh.ARRAY_NORMAL]=PackedVector3Array();a[Mesh.ARRAY_BONES]=PackedInt32Array();a[Mesh.ARRAY_WEIGHTS]=PackedFloat32Array()
	var blends=[]
	for kind in 4:
		var b=[];b.resize(Mesh.ARRAY_MAX);b[Mesh.ARRAY_VERTEX]=PackedVector3Array();b[Mesh.ARRAY_NORMAL]=PackedVector3Array();blends.append(b)
	var profile=[]
	for k in 17:
		var x=face.mouth.x+lerpf(-width,width,k/16.)
		var from=Vector3(x,face.mouth.y,face.mouth.z+.15);var best=Vector3(x,face.mouth.y,face.mouth.z-.01)
		var distance=INF;var indices:PackedInt32Array=original[Mesh.ARRAY_INDEX]
		for j in range(0,indices.size(),3):
			var va:Vector3=original[Mesh.ARRAY_VERTEX][indices[j]]
			if absf(va.y-face.mouth.y)>.13:continue
			var hit=Geometry3D.ray_intersects_triangle(from,Vector3(0,0,-1),va,original[Mesh.ARRAY_VERTEX][indices[j+1]],original[Mesh.ARRAY_VERTEX][indices[j+2]])
			if hit!=null and from.distance_to(hit)<distance:distance=from.distance_to(hit);best=hit
		var nearest=0;distance=INF
		for j in original[Mesh.ARRAY_VERTEX].size():
			var d=best.distance_squared_to(original[Mesh.ARRAY_VERTEX][j])
			if d<distance:distance=d;nearest=j
		var v=vertex(nearest);v.p=best-Vector3(0,0,.0012);profile.append(v)
	for k in 16:
		for entry in [[k,false],[k+1,false],[k,true],[k,true],[k+1,false],[k+1,true]]:
			var v:Dictionary=profile[entry[0]];var lower:bool=entry[1]
			a[Mesh.ARRAY_VERTEX].append(v.p);a[Mesh.ARRAY_NORMAL].append(Vector3.FORWARD)
			for x in v.b:a[Mesh.ARRAY_BONES].append(x)
			for x in v.w:a[Mesh.ARRAY_WEIGHTS].append(x)
			for kind in 4:
				blends[kind][Mesh.ARRAY_VERTEX].append(moved(v.p,kind,lower));blends[kind][Mesh.ARRAY_NORMAL].append(Vector3.FORWARD)
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,a,blends)
