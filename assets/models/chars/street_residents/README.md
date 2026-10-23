# 用户街坊模型 v1

来自用户 `F:\角色3d模型\npc\3d` 的两份 Meshy GLB。原用户文件没有改写，也没有用此前暂停的派生角色替代。作者目录只是来源记录；游戏只加载本目录 `res://` 资源，不依赖作者的外部磁盘。

| 资源 | 对应来源 | 角色用途 | 三角面 / 关节 |
| --- | --- | --- | --- |
| electrical_shopkeeper.glb | Meshy_AI_Gray_Workwear_Portrai_All_Animations.glb | 电料店中年男店主 | 10,413 / 67 |
| female_resident.glb | Meshy_AI_Casual_Studio_Portrai_All_Animations.glb | 中年女住户 | 10,370 / 66 |

均为米制、约 1.70 米高，glTF +Y 向上、+Z 是面部方向；Blender 导入后是 Z 向上、-Y 面部朝向。两份骨架编号不同，按语义骨名处理，不能硬套数字索引。单网格 / 单材质，原 2048 底色、2048 法线、4096 金属粗糙度 PNG 原样内嵌。

动作名大小写为 `Idle`、`Walking`、`Running`。本轮游戏仅使用 `Idle` 驻足，不做行走巡逻。原始走跑动画保留不改，原 `Walking` 鞋底有约 2.4—5.9 厘米高度偏差，尚未作为地面移动验收，不能直接宣称巡逻接地已完成；`Running` 有原始腾空段。没有追加 WalkGrounded，也不播放声源。

`Idle` 是新增 4 秒独立循环，不是冻住 Walking 第一帧。保留各自的双腿、脚和根骨位置；依据各自骨轴降低上臂、轻屈肘、放松手指并稍降锁骨，胸、肩、头加入轻微周期动作。 torso 仅借用工程现有许砚 Idle 的世界绑定变形基准；没有复制整套局部四元数或源角色平移。两脚最低点差距最大约 1.52 毫米，根骨采样无漂移，动作首尾四元数误差约 2.2e-18。

生成脚本：`scripts/tools/prepare_street_npcs.py`。脚本采用 GLB 追加动画：原网格、皮肤、纹理和原走跑动画的二进制前缀与动作 JSON 保持不变。可编辑源在 `source_art/street_residents_user_v1.blend`，其中两个独立骨架保留各自三段动作与内嵌贴图，检查相机和地板仅为离线检查设施，不在运行 GLB 内。

工具可以用普通 Python + numpy 进行资源处理；`--blender-review` 需后台 Blender bpy。所有开发调用应继续遵守根 AGENTS 的无窗口、无声要求：Blender 使用 `--background -noaudio`，外部进程以 Hidden 启动；不能为检查打开桌面编辑器。

数值记录见 `preparation_manifest.json`。离线模型检查及接触/动作采样在 F 盘验收 `20261023_NPC后台接入`，离线图片不能冒充 Godot 实机验收。
