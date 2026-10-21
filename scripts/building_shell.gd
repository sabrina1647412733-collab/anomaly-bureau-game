extends RefCounted
## 外墙与楼梯附楼收口：内饰不再直接敞向室外。
static func build(art) -> void:
	var wall = art.pbr("grey_plaster_02",.35,Color(.46,.45,.41),.95)
	var edge = art.plain(Color("353b37"),.85)
	# 3F—5F完整外壳；既有室内窗格保留在内侧，外侧是磨砂暗窗。
	for x in [-3.48,3.48]:
		art.box(Vector3(x,11.15,4.70),Vector3(.24,8.9,11.32),wall,true)
	art.box(Vector3(0,11.15,-1.0),Vector3(7.20,8.9,.24),wall,true)
	# 背面两翼，中央与楼梯附楼接通。
	art.box(Vector3(-2.30,11.15,10.28),Vector3(2.10,8.9,.24),wall,true)
	art.box(Vector3(3.32,11.15,10.28),Vector3(.30,8.9,.24),wall,true)
	# 三楼回廊与南侧平台放进实体附楼，外缘有墙、屋顶与防坠碰撞。
	for x in [-1.04,3.15]:
		art.box(Vector3(x,11.15,13.90),Vector3(.20,8.9,7.40),wall,true)
	art.box(Vector3(1.05,11.15,17.50),Vector3(4.4,8.9,.20),wall,true)
	art.box(Vector3(-.37,15.55,13.95),Vector3(1.10,.20,7.20),wall,true)
	art.box(Vector3(1.05,15.55,15.85),Vector3(4.15,.20,3.20),wall,true)
	for y in [6.9,9.8,12.7]:
		# 外墙楼层线，避免大块灰墙没有尺度感。
		for x in [-3.63,3.63]: art.box(Vector3(x,y+.02,6.0),Vector3(.08,.12,8.8),edge)
		# 北侧窗只作为密闭玻璃，不是穿出建筑的洞。
		for x in [-2.2,1.8]:
			var glass = art.plain(Color("142024"),.22,.3)
			art.box(Vector3(x,y+1.5,1.56),Vector3(1.05,1.15,.03),glass)
			art.box(Vector3(x,y+1.5,1.53),Vector3(.045,1.15,.035),edge)
	# 回廊内部有看得见的墙面、踢脚、楼层提示和灯，不再是室外悬空桥。
	art.box(Vector3(-.88,7.4,13.6),Vector3(.07,1.0,6.8),edge)
	art.label("3F 住户层  →",Vector3(-.83,8.15,15.8),.07,Color("cfc5a7"),PI*.5)
	art.omni(Vector3(-.32,9.0,15.7),Color(1,.78,.52),.8,4.0,false)
