extends Node3D
## 第一人称近景专用持物手。沿用许砚的外套配色，网格连续、平滑法线，五指贴合物品。
var skin: StandardMaterial3D
var cloth: StandardMaterial3D
var cuff: StandardMaterial3D
var nail: StandardMaterial3D

func build(id: String) -> void:
	name = "XuYanGripHands"
	skin = mat(Color("be9981"),.62)
	cloth = mat(Color("303b48"),.96)
	cuff = mat(Color("222f3a"),.9)
	nail = mat(Color("c6a99a"),.48)
	var texture_path := "res://assets/textures/rough_linen/albedo.jpg"
	if ResourceLoader.exists(texture_path):
		cloth.albedo_texture = load(texture_path)
		cloth.uv1_scale = Vector3(3,5,1)
	var offset := Vector3.ZERO
	if id in ["envelope","slip","registry","photo","marriage","cert","homework","return_card","discharge","testimony","pipe_map","notice","waterline","back_water","accident","sign"]:
		offset = Vector3(-.018,-.025,-.087)
	elif id == "weird_clock": offset = Vector3(.032,-.045,-.028)
	elif id in ["sweater","roof_copy"]: offset = Vector3(.020,-.035,-.105)
	elif id == "sandal": offset = Vector3(-.050,-.11,-.105)
	elif id.ends_with("key"): offset = Vector3(-.015,.005,-.005)
	var wrist := Vector3(.253,-.300,-.554)+offset
	# 外套袖筒以多道椭圆截面收口，袖口后端延伸到屏幕外，不露裁切端。
	var elbow := Vector3(.44,-.77,-.24)
	var sleeve_end := wrist+Vector3(.006,-.043,.012)
	var sleeve_points: Array[Vector3] = []
	var sleeve_radii: Array[float] = []
	for i in range(15):
		var t := float(i)/14.0
		sleeve_points.append(elbow.lerp(sleeve_end,t)+Vector3(-.012*sin(t*PI),0,-.012*sin(t*PI)))
		sleeve_radii.append(lerpf(.063,.040,t)*(1.0+.025*sin(t*PI*6)))
	sweep(sleeve_points,sleeve_radii,cloth,Vector2(1,.85),24)
	sweep([sleeve_end,wrist+Vector3(.001,-.012,.004),wrist], [.041,.037,.034],cuff,Vector2(1,.84),24)
	# 袖口细密的罗纹只改变轮廓极少量，避免一圈圈塑料关节。
	for i in range(4):
		var t := float(i+1)/5
		var center := sleeve_end.lerp(wrist,t)
		var tangent := (wrist-sleeve_end).normalized()
		sweep([center-tangent*.001,center+tangent*.001],[lerpf(.041,.034,t)+.0005,lerpf(.041,.034,t)+.0005],cuff,Vector2(1,.84),24)
	# 手掌由收窄的腕部过渡到掌骨，掌背略拱；前端藏在物品外侧。
	var centers: Array[Vector3] = [wrist,wrist+Vector3(-.001,.020,-.001),wrist+Vector3(-.004,.050,-.002),wrist+Vector3(-.006,.090,-.003),wrist+Vector3(-.009,.125,-.002),wrist+Vector3(-.012,.140,-.002)]
	sweep(centers,[.023,.028,.033,.035,.032,.018],skin,Vector2(1,.57),28)
	# 四指从手掌内侧绕到物品正面，圆润指腹保持接触，不能悬空伸直。
	for i in range(4):
		var y: float = -.174-float(i)*.024
		var length_factor: float = [1.0,1.04,.98,.82][i]
		var points: Array[Vector3] = [Vector3(.246,y,-.554),Vector3(.255,y+.002,-.539),Vector3(.248,y+.003,-.520),Vector3(.244,y+.002,-.504),Vector3(.232+(1.0-length_factor)*.022,y,-.498)]
		for j in points.size(): points[j] += offset
		var sampled := smooth_curve(points,4)
		var radii: Array[float] = []
		for j in sampled.size():
			var t := float(j)/float(sampled.size()-1)
			var radius := lerpf(.0100,.0080,t)*(1.0-.025*cos(t*PI*4))
			if t>.80: radius*=sqrt(maxf(.015,1.0-pow((t-.80)/.20,2)))
			radii.append(radius)
		sweep(sampled,radii,skin,Vector2(1,.88),16)
		# 短指甲只占末节一小块，颜色接近皮肤，避免白色假甲。
		# 指腹包住边缘，末端圆封口；不把四枚指甲作为白色圆点贴在指尖。
	# 拇指沿掌根向前内扣，压在手机/纸张的下角，和其余四指形成夹持。
	var thumb: Array[Vector3] = [Vector3(.263,-.274,-.546),Vector3(.263,-.266,-.519),Vector3(.254,-.252,-.495),Vector3(.228,-.244,-.494)]
	for i in thumb.size(): thumb[i] += offset
	var thumb_curve := smooth_curve(thumb,5)
	var thumb_radii: Array[float] = []
	for i in thumb_curve.size(): thumb_radii.append(lerpf(.016,.011,float(i)/float(thumb_curve.size()-1)))
	sweep(thumb_curve,thumb_radii,skin,Vector2(1,.85),18)
	ellipsoid(thumb_curve[-1]+Vector3(.006,0,.007),Vector3(.016,.009,.0012),nail)

func mat(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0
	return material

func smooth_curve(points: Array[Vector3], steps: int) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for i in range(points.size()-1):
		var a: Vector3 = points[maxi(0,i-1)]
		var b: Vector3 = points[i]
		var c: Vector3 = points[i+1]
		var d: Vector3 = points[mini(points.size()-1,i+2)]
		for j in range(steps):
			var t := float(j)/float(steps)
			result.append(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t))
	result.append(points[-1])
	return result

func sweep(points: Array[Vector3], radii: Array[float], material: Material, oval: Vector2, sides: int) -> void:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	for i in points.size():
		var tangent: Vector3 = (points[mini(i+1,points.size()-1)]-points[maxi(i-1,0)]).normalized()
		var reference := Vector3.FORWARD if absf(tangent.dot(Vector3.FORWARD))<.94 else Vector3.UP
		var axis_a := tangent.cross(reference).normalized()
		var axis_b := tangent.cross(axis_a).normalized()
		for j in range(sides):
			var angle := TAU*float(j)/float(sides)
			vertices.append(points[i]+radii[i]*(axis_a*cos(angle)*oval.x+axis_b*sin(angle)*oval.y))
			normals.append((axis_a*cos(angle)/oval.x+axis_b*sin(angle)/oval.y).normalized())
			uv.append(Vector2(float(j)/float(sides),float(i)/float(points.size()-1)))
	for i in range(points.size()-1):
		for j in range(sides):
			var a := i*sides+j
			var b := i*sides+(j+1)%sides
			var c := (i+1)*sides+j
			var d := (i+1)*sides+(j+1)%sides
			indices.append_array(PackedInt32Array([a,c,b,b,c,d]))
	# 两端封口，近景不能从腕部看到空洞。
	for end in [0,points.size()-1]:
		var center_index := vertices.size()
		vertices.append(points[end])
		var cap_normal := (points[0]-points[1]).normalized() if end==0 else (points[-1]-points[-2]).normalized()
		normals.append(cap_normal)
		uv.append(Vector2(.5,.5))
		for j in range(sides):
			var a: int = end*sides+j
			var b: int = end*sides+(j+1)%sides
			indices.append_array(PackedInt32Array([center_index,a,b] if end==0 else [center_index,b,a]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices
	arrays[Mesh.ARRAY_NORMAL]=normals
	arrays[Mesh.ARRAY_TEX_UV]=uv
	arrays[Mesh.ARRAY_INDEX]=indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var visual := MeshInstance3D.new()
	visual.mesh=mesh
	visual.material_override=material
	visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)

func ellipsoid(at: Vector3, extent: Vector3, material: Material) -> void:
	var mesh := SphereMesh.new()
	mesh.radius=.5
	mesh.height=1
	mesh.radial_segments=16
	mesh.rings=8
	var visual := MeshInstance3D.new()
	visual.mesh=mesh
	visual.position=at
	visual.scale=extent
	visual.material_override=material
	visual.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
