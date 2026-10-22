# 许砚跳跃、蹲下动作：原骨架坐标轴修正

运行时使用 `corrected_clips.res` 的七段动画；原始七个GLB和 `source_art/xuyan_motion_repaired.blend` 保留作为来源。

此前导入只按骨骼名称复制局部变换，Blender重新定向后的骨骼局部坐标轴与原Godot骨架不同，造成手臂、膝盖扭曲。同名骨骼不能直接套用旋转。

生成方式：先在Blender中导出每根骨骼的网格空间形变矩阵，再在Godot中乘回**原角色全局静置矩阵**，重建父子相对位置、旋转、缩放。66根骨骼、每段198条轨道；采样为30fps。`axis_audit.json`记录逐帧重建误差（最大约0.000005m）。没有覆盖人物网格、材质、Skin或原始GLB。

```powershell
blender --background --python scripts/tools/export_xuyan_deformations.py -- source_art/xuyan_motion_repaired.blend 临时目录/xuyan_deform.json
godot --headless --path . --script res://scripts/tools/import_xuyan_deformations.gd -- 临时目录/xuyan_deform.json
godot --headless --path . --script res://scripts/tests/xuyan_motion_test.gd -- --verify
```

临时形变JSON不参与游戏运行，无需随工程交付。原许砚网格有8个骨骼权重，CPU蒙皮检查必须按数组实际步长计算。原Idle蒙皮鞋底低于静态AABB约3.32cm，`xuyan_character.gd`的 `SKIN_FLOOR_OFFSET`用于补偿，不能通过缩短腿或移动碰撞体掩盖。

起跳当帧播放 `jump_start`，之后进入滞空，实际落地播放缓冲；蹲下/起身按片段时长完成。暂停冻结主角动画及过渡计时。渲染验收脚本为 `scripts/tests/motion_visual_review.gd`，输出正、侧面各35帧到 `_预览/动作验收/`。

当前仍是原有短动作片段与程序过渡，不包含逐级台阶脚部IK、复杂越障或专业动作捕捉。
