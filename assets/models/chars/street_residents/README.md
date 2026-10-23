# 用户街坊模型 v2：门前生活动作

来自用户 `F:\角色3d模型\npc\3d` 的两份 Meshy GLB。原用户文件没有改写，也没有用此前暂停的派生角色替代。作者目录只是来源记录；游戏只加载本目录 `res://` 资源，不依赖作者的外部磁盘。

| 资源 | 对应来源 | 角色用途 | 三角面 / 关节 |
| --- | --- | --- | --- |
| electrical_shopkeeper.glb | Meshy_AI_Gray_Workwear_Portrai_All_Animations.glb | 电料店中年男店主 | 10,413 / 67 |
| female_resident.glb | Meshy_AI_Casual_Studio_Portrai_All_Animations.glb | 中年女住户 | 10,370 / 66 |

均为米制、约 1.70 米高，glTF +Y 向上、+Z 是面部方向；Blender 导入后是 Z 向上、-Y 面部朝向。两份骨架编号不同，按语义骨名处理，不能硬套数字索引。单网格 / 单材质，原 2048 底色、2048 法线、4096 金属粗糙度 PNG 原样内嵌。

原始 `Walking`、`Running` 保留不改。新增 `WalkGrounded`、`ShortWalk`、`CareShop`、`Shelter`、`LookAround`、`TurnStepLeft`、`TurnStepRight`，加上既有 `Idle`，每人共10段动作。原Walking仍有2.4—5.9厘米鞋底高度偏差，不用于正式短线。

正式移动使用非循环 `ShortWalk`：2.4秒走0.72米，两小步后并脚回Idle。根位移按runtime.walk_distance_curve的分段smoothstep驱动，不能按平均速度匀速推角色；动画时间和真实CharacterBody移动共用物理步。备用WalkGrounded为1.2秒/0.72米循环，本轮未启用长距离巡逻。

90度换步使用1.8秒专用转身和runtime.turn_yaw_curve。正Godot Y偏转对应TurnStepRight，负偏转对应TurnStepLeft，必须读取turn_positive_clip/turn_negative_clip，不能只凭英文名称猜方向。生活动作均为空手：理袖、拢外套和看街，没有假拿道具；雨停时女住户改为看街。

脚部按各自腿长做双骨IK，迭代校正实际蒙皮鞋底高度和支撑面中心；正式ShortWalk两人的支撑脚速度p95约0.019—0.029米/秒，转身约0.025—0.038米/秒，仍不能称为任意中断和混合下的绝对零滑步。门前路线使用完整周期和匹配的90度转身，暂停冻结相位，挡路停让，离街停止动作及空间脚步音。

`Idle` 是新增 4 秒独立循环，不是冻住 Walking 第一帧。保留各自的双腿、脚和根骨位置；依据各自骨轴降低上臂、轻屈肘、放松手指并稍降锁骨，胸、肩、头加入轻微周期动作。 torso 仅借用工程现有许砚 Idle 的世界绑定变形基准；没有复制整套局部四元数或源角色平移。两脚最低点差距最大约 1.52 毫米，根骨采样无漂移，动作首尾四元数误差约 2.2e-18。

生成脚本：`scripts/tools/prepare_street_npcs.py`。脚本采用 GLB 追加动画：原网格、皮肤、纹理和原走跑动画的二进制前缀与动作 JSON 保持不变。可编辑源在 `source_art/street_residents_user_v1.blend`，保留双方所有动作和内嵌贴图并启用文件压缩；检查相机、地板和REVIEW_DRIVER只为离线检查，不在运行GLB内。

工具可以用普通 Python + numpy 进行资源处理；`--blender-review` 需后台 Blender bpy。所有开发调用应继续遵守根 AGENTS 的无窗口、无声要求：Blender 使用 `--background -noaudio`，外部进程以 Hidden 启动；不能为检查打开桌面编辑器。

数值记录见 `preparation_manifest.json`。本轮离线模型检查及接触/动作采样在F盘验收 `20261023_NPC生活化`，联系图和结构摘要随源码保存在 `source_art/art_direction/street_residents_v2`。离线图片不能冒充Godot实机验收。
