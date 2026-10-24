# 槐安住宅 · 第二案世界空间 v1

现有工程新增第二案空间，不替换回潮镇五层火灾公寓。角色与剧情由独立控制器接入。

- 世界根坐标 `(1200,0,0)`，所有 GLB 为米制局部坐标，Godot +Y 朝上。
- 楼高 3m；1F/8F/16F/17F 必需室内，2—7F、9—15F 只有封闭公共候梯厅与真实楼梯，不表示制作了所有住户室内。
- 5 个静态模块：`core`、`F1`、`F8`、`F16`、`F17`。`*_whitebox.glb` 保留首轮可走白模，正式优先 `*_finish.glb`。
- `huaian_manifest.json` 同源输出碰撞、锚点、正常站位、楼层、模型模块；精修含 428 个静态盒与 32 个连续凸楼梯坡体。可见踏步不承担容易卡脚的逐阶碰撞。
- 17F 入口有可见实体门。剧情条件满足后 `set_anomaly_open(true)` 才解除碰撞；结案仅熄灯，不删除玩家脚下的地面或封住退路。
- 源模型 `source_art/case2_huaian_v1.blend`，首轮源 `source_art/case2_huaian_whitebox_v1.blend`；生成器 `scripts/tools/build_case2_huaian.py`。均为新建模块，未覆盖第一案资源。
- 使用现有工程已有纹理（墙、磨石、木材、布、金属），纹理署名继续沿用 `assets/textures/README.md`。模型有真实墙厚、18cm窗洞回口、倒角、窗框、门洞、窗台、吊管、接头、扶手、床架、桌腿、家具把手及物件轮廓；GLB UV 按米制面投影，不将长墙拉成单块贴图。

## 稳定接口

`case2_world.gd` 是 Node3D，先加入 SceneTree，再调用 `setup(game)`。

- `get_spots()`：`id,name,text,pos,r,floor,approach`；`pos/approach` 均世界坐标。
- `get_anchor(id)`、`get_floor_spawn(floor)`、`get_actor_anchor(id,floor)` 返回世界坐标。
- `get_route(id,player_position)`：经过真实房门和完整U形楼梯的世界坐标路径。
- `set_anomaly_open(bool)`、`set_resolved(bool)`、`set_active(bool)`。
- `refs.doors.anomaly`、`refs.valves.branch`、`refs.lights` 是可演出节点；禁止把静态模型路径当运行资源回写。

## 空间验收

首轮 `case2_world_walk_test.gd` 由 0.34m 半径、1.72m 高胶囊从 1F 单次起点出发，全程真实 `move_and_slide`，顺序走过 1F → 8F → 16F → 17F → 1F；24 个必需/补充物件的接近与视线通过。没有用逐物件传送代替通行。首轮日志和 JSON 在作者 F 盘验收目录。

物理通行不代表商业美术、全案剧情或人工长时间试玩通过；最终实机图、精修复测与限制需以当前交付记录为准。
