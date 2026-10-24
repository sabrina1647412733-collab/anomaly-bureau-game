# 回潮镇街道更新 v2

运行入口仍是现有 `project.godot`。本目录不是独立项目。

## 资源和位置约定

- `town-layout.json` 原文件保持不变。10处既定地标的ID、名称、功能、中心、旋转和入口坐标不变；旧4个街道GLB保留。
- `layout_additions.json` 是固定种子的32处补建、12处低附房、墙根植被与入口保护信息。运行时合并到同一地图数据；街景本身没有新增可进入的普通民居户内空间。
- 旧普通建筑和旧街具模块不再显示，新的92个空间批次位于`models/`。旧重点地标03至10保留并使用既有PBR贴图，01洗衣楼、02出租公寓采用新的完整外立面。
- 洗衣楼外部高度15.8米、五层，用于对应现有二楼营业层、楼上调查路线；入口仍接回原独立室内。
- 414栋普通房屋包含原370栋、32栋补建和12栋低附房；门窗、窗帘、雨棚、屋檐、排水管、屋顶设施、线缆和街具为真实导出网格。旁观外墙不代表所有房子新增了内部空间。
- 道路交叉口采用平面布尔并集，地面/道路/铺装分区；地形碰撞使用同源三角面。河道0米处没有整镇地板，三座桥独立连接，河床-1.3米防止无限坠落；F8脱困保留。

## 编辑和复现

可编辑源是`source_art/huichao_street_v2.blend`，按材质及32米区块组织。运行无需Blender或Python；GLB已包含网格和顶点色，Godot应用共享PBR材质与天气参数。

从源数据重新生成需要Python的Shapely 2.2及Blender 4.5 LTS。先运行`scripts/tools/prepare_street_renewal.py PROJECT [SITE_PACKAGES]`，再执行`blender --factory-startup -b --python scripts/tools/build_street_renewal.py -- PROJECT`，最后用Godot导入资源。中间三角形计划在被Git忽略的`_tools/`，不需要交付。

2026-10-24自然街景层使用`scripts/tools/street_vegetation.py`作为两套导出器共享的植物几何源。主街近景由`build_street_hero_props.py`单独导出到`hero_props/`；这两套生成器都需要保留共享工具。普通住宅正立面推广原样板的30厘米厚墙与18厘米内退窗洞，后部保持封闭；两处浅店面的入口/后墙仍由原`shop_recesses`与碰撞共源约束。

原2072簇单三角草改为1017簇低矮、分品种的墙缝生长：窄叶、宽叶和小地被混合，不在门口与路心均匀撒点。根部按同源分区落在铺装`.0355m`或裸地`-.0235m`，不再假定统一平面；不增加碰撞。17处人工近景锚点和4处旧大草丛一起换为有中央折面的8段弯叶，少量枯叶留在墙脚；远景叶用4段并在42米外关闭。盆栽有空心盆口/土面与披垂叶，扫帚有分束干草，不再使用绿色实心块。

几何由本项目生成脚本制作。使用的真实纹理全部沿用项目已有Poly Haven CC0素材；完整清单在`assets/textures/README.md`，没有新增来源不明的素材。天空、玻璃、地表、积水和雨丝着色器为项目源码。

## 时间、天气和恢复

`street_weather.gd`沿用director的10倍时间与三夜夜次。包含昼夜天空、云、路灯、不同日期降雨强度、湿度积累与风干。04:00交班保留剧情晨光；不新增可跳过关键调查的事件时间。

雨丝使用一个1352实例的MultiMesh，按房屋旋转与屋檐范围限制最低高度。屋檐遮雨是保守轮廓近似，不是逐三角面水物理。积水使用羽化边缘网格、天空及灯光高光；没有承诺全场景镜面反射或真实水流模拟。兼容模式不依赖Decal、屏幕反射或计算粒子。

桌面保存位置继续在F盘工程/游戏旁的`_玩家数据`。新增`town_environment`可选字段，旧档仍能载入。室外使用独立环境副本，离开街道后恢复室内环境、景深和后期参数；暂停冻结雨和云。

## 验收入口

- `scripts/tests/street_renewal_test.gd`：碰撞、10入口、道路/桥梁、天气存档、真实键盘往返与跳蹲。
- `scripts/tests/street_weather_test.gd`：独立天气状态与室内环境恢复。
- `scripts/tools/street_renewal_review.gd`：相同玩家机位的18张昼夜/雨后Godot截图，输出F盘。
- `scripts/tests/normal_route_review.gd`：新游戏完整三夜实际输入路线，不绕过主线授予证据。
- `scripts/tools/validate_street_natural.py PROJECT REPORT_DIRECTORY BEFORE_DIRECTORY`：自然街景的GLB、草根高度、预算与旧碰撞契约检查。需要先保留旧manifest；结果不代替Godot实机/路线/性能验收。

详细结果和当前品质限制见工程根目录的`20261023_街道环境重构验收.md`。
