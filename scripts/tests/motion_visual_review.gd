extends SceneTree
const OUT="res://_预览/动作验收/"
func _initialize():call_deferred("run")
func run():
 root.size=Vector2i(560,680);root.content_scale_size=Vector2i(560,680)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
 var world=Node3D.new();root.add_child(world)
 var env=WorldEnvironment.new();env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("222d32");env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color(.8,.85,.9);env.environment.ambient_light_energy=.8;world.add_child(env)
 var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-45,-30,0);world.add_child(light)
 var p=preload("res://scripts/player.gd").new();world.add_child(p);p.set_physics_process(false);p.flash.visible=false;p.body.visible=true
 var actor=preload("res://scripts/town/xuyan_character.gd").new();actor.setup(p,null);actor.set_physics_process(false)
 var camera=Camera3D.new();world.add_child(camera);camera.current=true;camera.fov=38;camera.position=Vector3(2.3,1.25,-3.3);camera.look_at(Vector3(0,.9,0))
 var floor=MeshInstance3D.new();var mesh=PlaneMesh.new();mesh.size=Vector2(6,6);floor.mesh=mesh;world.add_child(floor)
 for name in ["jump_start","jump_loop","jump_land","crouch_down","crouch_idle","crouch_walk","crouch_up"]:
  var clip="town/"+name;var animation=actor.animator.get_animation(clip)
  for i in range(5):
   actor.animator.play(clip,0);actor.animator.seek(animation.length*i/4.0,true);actor.animator.advance(0);actor.animator.pause()
   for f in range(3):await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png(OUT+name+"_%d.png"%i)
 world.queue_free();await process_frame;quit()
