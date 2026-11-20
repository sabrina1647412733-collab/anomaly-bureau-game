extends RefCounted
## Original procedural moisture masks, shared by the world glass and close-up.
static var print_texture:Texture2D
static var dirt_texture:Texture2D
static func palm()->Texture2D:
	if print_texture!=null:return print_texture
	var image=Image.create(192,192,true,Image.FORMAT_RGBA8)
	for y in range(192):
		for x in range(192):
			var p=Vector2(x,y)/192.0
			var q=(p-Vector2(.50,.64))/Vector2(.16,.22)
			var distance=q.length()-1.0
			var alpha=clampf(-distance*8,0,1)*.68
			for finger in [[.365,.56,.30,.36,.028],[.42,.49,.395,.14,.031],[.51,.47,.515,.10,.033],[.59,.49,.63,.17,.029],[.65,.55,.735,.32,.025]]:
				var d=Geometry2D.get_closest_point_to_segment(p,Vector2(finger[0],finger[1]),Vector2(finger[2],finger[3])).distance_to(p)
				alpha=maxf(alpha,clampf((float(finger[4])-d)*180,0,1)*.76)
			var grain=fmod(absf(sin(x*12.9898+y*78.233)*43758.5453),1.0)
			var pressure=.45+.3*sin(x*.11+y*.07)+.2*sin(x*.27-y*.1)
			var ridges=.79+.21*sin(q.length()*78+sin(x*.03)*3)
			image.set_pixel(x,y,Color(.57,.66,.63,alpha*clampf(pressure,0,1)*(.45+.55*grain)*ridges))
	image.generate_mipmaps();print_texture=ImageTexture.create_from_image(image);return print_texture

static func dirt()->Texture2D:
	if dirt_texture!=null:return dirt_texture
	var image=Image.create(96,96,true,Image.FORMAT_RGBA8)
	for y in range(96):
		for x in range(96):
			var p=(Vector2(x,y)-Vector2(48,48))/48
			var edge=clampf(1.0-p.length(),0,1)
			var grain=fmod(absf(sin(x*12.9898+y*78.233)*43758.5453),1.0)
			var streak=.5+.25*sin(y*.43+x*.09)+.25*sin(y*.12-x*.06)
			image.set_pixel(x,y,Color(.64,.68,.60,edge*edge*(.25+.75*grain)*streak*.67))
	image.generate_mipmaps();dirt_texture=ImageTexture.create_from_image(image);return dirt_texture
