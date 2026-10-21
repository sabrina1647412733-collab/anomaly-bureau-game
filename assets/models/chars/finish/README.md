# 原角色动作修正

原始角色GLB、纹理、身份与骨架保留。`zhou_clips.res`、`laozhou_clips.res`、`aqi_clips.res` 是给各自原骨架生成的动画库，不可跨角色混用。

修正内容：站立与行走的双臂后折、坐姿双手和脚踝接触、座位偏移与循环时的根部漂移。保留原角色身体与行走节奏；角色没有完整面部骨架，这些资源不包含电影级口型和表情。

生产步骤：

1. Blender后台运行 `scripts/tools/refine_seated_cast.py -- 原始角色.glb 输出目录 zhou`（其余用laozhou、aqi）。
2. 在Godot工程内运行 `scripts/tools/import_cast_deformations.gd -- 输出目录`，一次转换三人的动画库。
3. 运行时 `scripts/laundry/char_actor.gd` 把库中的骨骼轨道映射回原角色。

不能把不带蒙皮的普通节点动画直接复制到角色骨骼上；Blender导入后的骨轴与Godot原骨轴存在区别。作者工具使用网格空间变形矩阵，再结合原Godot骨架的静止姿势生成轨道，避免二次旋转。

`source_art/*_seated.blend` 为压缩的骨架和动作作者文件，预览时可按文件里的source_model名称关联原角色网格。`*_seated_audit.json` 是作者侧接触点采样；最终还须检查Godot实际截图与角色位置，不能只看该采样。
