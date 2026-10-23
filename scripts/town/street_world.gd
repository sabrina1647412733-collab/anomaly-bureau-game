extends RefCounted
## Blender spatial batches + exact polygon floor, shared PBR and weather parameters.
const BASE := "res://assets/town/renewal/"
var materials:Dictionary={}
var waters:Array[ShaderMaterial]=[]
var lights:Array[OmniLight3D]=[]
var manifest:Dictionary={}
var town
const TEXTURES := {
	"plaster":"grey_plaster_02", "brick":"brick_wall_04", "graybrick":"brick_4",
	"concrete":"rough_concrete", "trim":"chipped_concrete", "wood":"wood_planks_dirt",
	"metal":"metal_plate", "rust":"rusty_metal", "roof_tile":"dirty_tiles",
	"roof_metal":"worn_corrugated_iron", "road":"asphalt_04", "paving":"concrete_floor",
	"ground":"rough_concrete", "sign":"painted_concrete", "stain":"damaged_plaster"
}
const TINTS := {
	"glass":Color(.10,.17,.19),"window_warm":Color(.68,.44,.21),"window_cool":Color(.36,.52,.55),
	"cable":Color(.055,.064,.062),"grass":Color(.24,.31,.14),"leaf":Color(.18,.27,.15),
	"lamp":Color(.85,.53,.21),"paper":Color(.68,.61,.45),"curtain":Color(.38,.33,.24)
}

func setup(owner_town)->void:
	town=owner_town
	manifest=JSON.parse_string(FileAccess.get_file_as_string(BASE+"street_manifest.json"))
	for path in manifest.get("chunks",[]):
		var packed:PackedScene=load(path)
		if packed==null:push_error("街道模块缺失: "+path);continue
		var chunk=packed.instantiate();town.add_child(chunk);_materials(chunk)
	var faces=PackedVector3Array()
	for triangle in manifest.get("collision",[]):
		var a=Vector3(triangle[0][0],0,triangle[0][1])
		var b=Vector3(triangle[1][0],0,triangle[1][1])
		var c=Vector3(triangle[2][0],0,triangle[2][1])
		if (b-a).cross(c-a).y>0:faces.append_array([a,c,b])
		else:faces.append_array([a,b,c])
	# The river is open at street level, with a shallow physical bed instead of an endless fall.
	for triangle in manifest.get("river_bed",[]):
		var a=Vector3(triangle[0][0],-1.3,triangle[0][1])
		var b=Vector3(triangle[1][0],-1.3,triangle[1][1])
		var c=Vector3(triangle[2][0],-1.3,triangle[2][1])
		if (b-a).cross(c-a).y>0:faces.append_array([a,c,b])
		else:faces.append_array([a,b,c])
	var shape=ConcavePolygonShape3D.new();shape.set_faces(faces)
	var collision=CollisionShape3D.new();collision.name="StreetLandAndBridges";collision.shape=shape
	town.floor_body.add_child(collision)
	# Substantial prop volumes match generated models. Entrance protections filter these below.
	for prop in manifest.get("props",[]):
		var at=Vector3(prop.at[0],prop.at[1],prop.at[2])
		var entry_safe=false
		for landmark in town.layout.get("landmarks",[]):
			var front: Array=landmark.front
			if Vector2(at.x,at.z).distance_to(Vector2(front[0],front[1]))<2.0:entry_safe=true
		if not entry_safe:town._box(at,Vector3(prop.size[0],prop.size[1],prop.size[2]),float(prop.yaw))
	# Lights are limited by renderer distance; luminaire meshes remain visible farther away.
	for entry in manifest.get("lights",[]):
		var light=OmniLight3D.new();town.add_child(light)
		light.position=Vector3(entry.position[0],entry.position[1],entry.position[2])
		light.light_color=Color(entry.color);light.light_energy=float(entry.energy)
		light.set_meta("base_energy",light.light_energy);light.omni_range=float(entry.range)
		light.distance_fade_enabled=true;light.distance_fade_begin=45.;light.distance_fade_length=15.
		light.shadow_enabled=false;lights.append(light)
	for entry in manifest.get("signs",[]):
		var sign=Label3D.new();sign.name="LandmarkSign";sign.text=entry.text
		sign.font=town.game.font;sign.font_size=72;sign.pixel_size=.0065
		sign.modulate=Color("d5d0b5");sign.outline_size=4;sign.no_depth_test=false
		sign.position=Vector3(entry.position[0],entry.position[1],entry.position[2]);sign.rotation.y=float(entry.yaw)
		town.add_child(sign)

func _materials(node:Node)->void:
	if node is MeshInstance3D:
		var kind=String(node.name).get_slice(".",0)
		# Imported names can have a suffix when multiple spatial chunks share a material.
		if not TEXTURES.has(kind) and not TINTS.has(kind) and kind not in ["puddle","water"]:
			for candidate in TEXTURES.keys()+TINTS.keys()+["puddle","water"]:
				if kind.begins_with(candidate):kind=candidate;break
		node.material_override=_material(kind)
		node.visibility_range_end=150. if kind in ["plaster","brick","graybrick","roof_tile","roof_metal"] else 100.
		if kind in ["leaf","grass"]:node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():_materials(child)

func _material(kind:String)->Material:
	if materials.has(kind):return materials[kind]
	if kind in ["puddle","water"]:
		var water=ShaderMaterial.new();water.shader=preload("res://scripts/town/street_water.gdshader")
		water.set_shader_parameter("river",kind=="water");materials[kind]=water;waters.append(water);return water
	if kind in ["glass","window_warm","window_cool"]:
		var glass=ShaderMaterial.new();glass.shader=preload("res://scripts/town/street_glass.gdshader")
		glass.set_shader_parameter("tint",TINTS[kind]);glass.set_shader_parameter("lit",1. if kind!="glass" else 0.)
		materials[kind]=glass;return glass
	if not TEXTURES.has(kind):
		var simple=StandardMaterial3D.new();simple.albedo_color=TINTS.get(kind,Color(.45,.45,.4))
		simple.vertex_color_use_as_albedo=true;simple.cull_mode=BaseMaterial3D.CULL_DISABLED
		simple.roughness=.24 if kind=="glass" else .83
		if kind in ["lamp","window_warm","window_cool"]:
			simple.emission_enabled=true;simple.emission=simple.albedo_color;simple.emission_energy_multiplier=.8 if kind=="lamp" else .3
		materials[kind]=simple;return simple
	var material=ShaderMaterial.new();material.shader=preload("res://scripts/town/street_surface.gdshader")
	var folder="res://assets/textures/"+TEXTURES[kind]+"/"
	for slot in ["base_tex","normal_tex","rough_tex"]:
		var filename={"base_tex":"albedo.jpg","normal_tex":"normal.jpg","rough_tex":"rough.jpg"}[slot]
		material.set_shader_parameter(slot,load(folder+filename))
	material.set_shader_parameter("tex_scale",.38 if kind in ["plaster","concrete","trim"] else (.7 if kind in ["road","paving","ground"] else .6))
	material.set_shader_parameter("wet_response",.9 if kind in ["road","paving","ground"] else .35)
	material.set_shader_parameter("metalness",.55 if kind in ["metal","rust","roof_metal"] else 0.)
	material.set_shader_parameter("base_roughness",.8 if kind in ["metal","roof_metal"] else 1.)
	material.set_shader_parameter("tint",Color(.68,.72,.69) if kind=="ground" else Color.WHITE)
	materials[kind]=material;return material

func set_weather(wet:float,rain:float,elapsed:float)->void:
	for material in materials.values():
		if material is ShaderMaterial:material.set_shader_parameter("wetness",wet)
	for kind in ["window_warm","window_cool"]:
		if materials.has(kind):materials[kind].set_shader_parameter("daylight",float(town.weather.daylight))
	for water in waters:
		water.set_shader_parameter("rain_amount",rain);water.set_shader_parameter("weather_time",elapsed)
