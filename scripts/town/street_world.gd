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
	"ground":"rough_concrete", "sign":"painted_concrete", "stain":"damaged_plaster",
	"hero_plaster":"damaged_plaster", "road_patch":"asphalt_04",
	"limewash":"painted_plaster_wall", "mint_plaster":"grey_plaster_02"
}
const TINTS := {
	"glass":Color(.10,.17,.19),"window_warm":Color(.68,.44,.21),"window_cool":Color(.36,.52,.55),
	"cable":Color(.055,.064,.062),"grass":Color(.24,.31,.14),"leaf":Color(.18,.27,.15),
	"lamp":Color(.85,.53,.21),"paper":Color(.68,.61,.45),"curtain":Color(.38,.33,.24),
	"painted_metal":Color(.72,.71,.66),"galvanized":Color(.59,.62,.63),
	"wall_damp":Color(.24,.25,.20),"road_crack":Color(.14,.14,.13)
}
# Repetitions/metre and material response, calibrated against ordinary brick
# courses, door planks and paving at the player's eye height. Vertex paint is
# palette variation, not a second flat albedo pass over photographed materials.
const SURFACE_PROFILES := {
	"plaster":{"tex_scale":.54,"normal_strength":.68,"minimum_roughness":.79,"vertex_tint_strength":.30,"wall_age":1.0,"wet_response":.30},
	"brick":{"tex_scale":1.05,"normal_strength":.80,"minimum_roughness":.77,"vertex_tint_strength":.35,"wall_age":.75,"wet_response":.40},
	"graybrick":{"tex_scale":1.04,"normal_strength":.72,"minimum_roughness":.80,"vertex_tint_strength":.30,"wall_age":.85,"wet_response":.40,"albedo_saturation":.72},
	"concrete":{"tex_scale":.68,"normal_strength":.56,"minimum_roughness":.82,"vertex_tint_strength":.22,"wall_age":.45,"wet_response":.32},
	"trim":{"tex_scale":.85,"normal_strength":.54,"minimum_roughness":.80,"vertex_tint_strength":.25,"wall_age":.35,"wet_response":.35},
	"wood":{"tex_scale":.62,"normal_strength":.56,"minimum_roughness":.76,"vertex_tint_strength":.45,"wet_response":.35,"albedo_saturation":.78},
	"metal":{"tex_scale":.65,"normal_strength":.24,"minimum_roughness":.48,"vertex_tint_strength":.45,"wet_response":.50,"metalness":.68,"base_roughness":.92},
	"rust":{"tex_scale":.85,"normal_strength":.58,"minimum_roughness":.75,"vertex_tint_strength":.35,"wet_response":.42,"metalness":.12},
	"roof_tile":{"tex_scale":.52,"normal_strength":.62,"minimum_roughness":.78,"vertex_tint_strength":.40,"wet_response":.65},
	"roof_metal":{"tex_scale":.74,"normal_strength":.46,"minimum_roughness":.65,"vertex_tint_strength":.40,"wet_response":.68,"metalness":.28},
	"road":{"tex_scale":.75,"normal_strength":.88,"minimum_roughness":.82,"vertex_tint_strength":.10,"wet_response":.90,"macro_variation":.17,"tint":Color(.86,.87,.88)},
	"paving":{"tex_scale":.95,"normal_strength":.68,"minimum_roughness":.83,"vertex_tint_strength":.18,"wet_response":.72,"albedo_saturation":.32,"tint":Color(.94,.95,.95)},
	"ground":{"tex_scale":.78,"normal_strength":.67,"minimum_roughness":.86,"vertex_tint_strength":.15,"wet_response":.70,"albedo_saturation":.48,"tint":Color(.86,.84,.79)},
	"sign":{"tex_scale":.65,"normal_strength":.28,"minimum_roughness":.73,"vertex_tint_strength":1.0,"wet_response":.35},
	"stain":{"tex_scale":.56,"normal_strength":.78,"minimum_roughness":.84,"vertex_tint_strength":.05,"wall_age":1.0,"wet_response":.38},
	"hero_plaster":{"tex_scale":.54,"normal_strength":.82,"minimum_roughness":.80,"vertex_tint_strength":.10,"wall_age":.72,"wet_response":.36,"albedo_saturation":.65,"tint":Color(1.0,.98,.95)},
	"limewash":{"tex_scale":.48,"normal_strength":.37,"minimum_roughness":.86,"vertex_tint_strength":.12,"wall_age":.58,"wet_response":.32,"albedo_saturation":.18,"macro_variation":.055,"tint":Color(1.02,.99,.90)},
	"mint_plaster":{"tex_scale":.58,"normal_strength":.43,"minimum_roughness":.84,"vertex_tint_strength":.12,"wall_age":.86,"wet_response":.42,"albedo_saturation":.16,"macro_variation":.07,"tint":Color(.94,1.10,1.01)}
}

func setup(owner_town)->void:
	town=owner_town
	manifest=JSON.parse_string(FileAccess.get_file_as_string(BASE+"street_manifest.json"))
	for path in manifest.get("chunks",[]):
		var packed:PackedScene=load(path)
		if packed==null:push_error("街道模块缺失: "+path);continue
		var chunk=packed.instantiate();town.add_child(chunk);_materials(chunk)
	var faces=PackedVector3Array()
	var graded_indices: Dictionary = {}
	for index in manifest.get("graded_collision_indices",[]):
		graded_indices[int(index)] = true
	var flat_triangles: Array = manifest.get("collision",[])
	for index in flat_triangles.size():
		if graded_indices.has(index):continue
		var triangle: Array = flat_triangles[index]
		var a=Vector3(triangle[0][0],0,triangle[0][1])
		var b=Vector3(triangle[1][0],0,triangle[1][1])
		var c=Vector3(triangle[2][0],0,triangle[2][1])
		if (b-a).cross(c-a).y>0:faces.append_array([a,c,b])
		else:faces.append_array([a,b,c])
	for triangle in manifest.get("graded_collision_triangles",[]):
		var a=Vector3(triangle[0][0],triangle[0][1],triangle[0][2])
		var b=Vector3(triangle[1][0],triangle[1][1],triangle[1][2])
		var c=Vector3(triangle[2][0],triangle[2][1],triangle[2][2])
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
		light.shadow_enabled=bool(entry.get("shadow",false));lights.append(light)
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
			var match_kind=""
			for candidate in TEXTURES.keys()+TINTS.keys()+["puddle","water"]:
				if kind.begins_with(candidate) and String(candidate).length()>match_kind.length():match_kind=candidate
			if not match_kind.is_empty():kind=match_kind
		node.material_override=_material(kind)
		node.visibility_range_end=150. if kind in ["plaster","hero_plaster","limewash","mint_plaster","brick","graybrick","roof_tile","roof_metal"] else 100.
		if kind in ["leaf","grass","road_patch","wall_damp","road_crack"]:node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
	if kind=="road_patch":
		# Alpha is supplied by the maintenance mesh's inner/outer vertex ring.
		# Draw before puddles; transparent feathering never writes a depth outline.
		var patch=ShaderMaterial.new();patch.shader=preload("res://scripts/town/street_road_patch.gdshader")
		patch.render_priority=-1
		patch.set_shader_parameter("street_origin",town.global_position if is_instance_valid(town) else Vector3.ZERO)
		for slot in ["base_tex","normal_tex","rough_tex"]:
			var filename={"base_tex":"albedo.jpg","normal_tex":"normal.jpg","rough_tex":"rough.jpg"}[slot]
			patch.set_shader_parameter(slot,load("res://assets/textures/asphalt_04/"+filename))
		materials[kind]=patch;return patch
	if kind=="wall_damp":
		var damp=ShaderMaterial.new();damp.shader=preload("res://scripts/town/street_wall_damp.gdshader")
		materials[kind]=damp;return damp
	if kind in ["painted_metal","galvanized"]:
		# These are coated/oxidised service fixtures, not dark chequer-plate steel.
		var finish=ShaderMaterial.new();finish.shader=preload("res://scripts/town/street_metal_finish.gdshader")
		finish.set_shader_parameter("tint",TINTS[kind])
		finish.set_shader_parameter("street_origin",town.global_position if is_instance_valid(town) else Vector3.ZERO)
		finish.set_shader_parameter("metalness",1.0 if kind=="galvanized" else 0.)
		finish.set_shader_parameter("base_roughness",.61 if kind=="galvanized" else .72)
		finish.set_shader_parameter("mottle_amount",.055 if kind=="galvanized" else .022)
		materials[kind]=finish;return finish
	if not TEXTURES.has(kind):
		var simple=StandardMaterial3D.new();simple.albedo_color=TINTS.get(kind,Color(.45,.45,.4))
		simple.vertex_color_use_as_albedo=true;simple.cull_mode=BaseMaterial3D.CULL_DISABLED
		simple.roughness=.24 if kind=="glass" else .83
		if kind in ["lamp","window_warm","window_cool"]:
			simple.emission_enabled=true;simple.emission=simple.albedo_color;simple.emission_energy_multiplier=.8 if kind=="lamp" else .3
		materials[kind]=simple;return simple
	var material=ShaderMaterial.new();material.shader=preload("res://scripts/town/street_surface.gdshader")
	var folder="res://assets/textures/"+TEXTURES[kind]+"/"
	for slot in ["base_tex","normal_tex","rough_tex","ao_tex"]:
		var filename={"base_tex":"albedo.jpg","normal_tex":"normal.jpg","rough_tex":"rough.jpg","ao_tex":"ao.jpg"}[slot]
		material.set_shader_parameter(slot,load(folder+filename))
	material.set_shader_parameter("street_origin",town.global_position if is_instance_valid(town) else Vector3.ZERO)
	for parameter in SURFACE_PROFILES.get(kind,{}):
		material.set_shader_parameter(parameter,SURFACE_PROFILES[kind][parameter])
	materials[kind]=material;return material

func set_weather(wet:float,rain:float,elapsed:float)->void:
	for material in materials.values():
		if material is ShaderMaterial:material.set_shader_parameter("wetness",wet)
	for kind in ["window_warm","window_cool"]:
		if materials.has(kind):materials[kind].set_shader_parameter("daylight",float(town.weather.daylight))
	for water in waters:
		water.set_shader_parameter("rain_amount",rain);water.set_shader_parameter("weather_time",elapsed)
