# 场景与动作可编辑源文件

2026-10-23新增：`view_hands_v1.blend`为独立近景手部七种握姿及外套袖口，CC0解剖拓扑起点与重建参数见`assets/models/view_hands/SOURCES.md`和`build_view_hands.py`；`laundry_detail_v1.blend`为现有店堂的壁架、洗涤瓶、衣篮、灯具、风扇与管线，脚本为`build_laundry_dressing.py`。两者已导出到assets，游戏不运行Blender。`first_person_hands_legacy.gd.txt`保留上一版程序手部，原全身角色、原白模和动作来源未覆盖。

- `laundry_repaired.blend`：以用户提供的洗衣楼白模为基础，修复楼梯、井体外壳、502/503通道和家具位置后的源文件。
- `xuyan_motion_repaired.blend`：沿用许砚骨架，修复七段跳跃/蹲下动作的双脚互穿。
- `.gdignore`：源文件不参与Godot导入，运行只使用assets中的GLB；其他机器不需要安装Blender。

生成与验收脚本在`scripts/tools/`。原始WorkBuddy交付位于工程旁的独立文件夹，未被覆盖。
执行Blender后台脚本时传入来源.blend和输出目录；生成结果可在此继续优化。

```powershell
blender --background --factory-startup --disable-autoexec --python scripts/tools/refine_laundry_assets.py -- "原始白模.blend" "assets/models/laundry_rebuild"
blender --background --factory-startup --disable-autoexec --python scripts/tools/refine_xuyan_motion.py -- "原始许砚动画.blend" "assets/town/xuyan/motion"
blender --background --factory-startup --disable-autoexec --python scripts/tools/verify_motion_feet.py -- "source_art/xuyan_motion_repaired.blend" "_预览/motion_validation.json"
```

重新运行修复脚本应始终使用原始交付作为输入，不要对已修复版本重复套用。配音生成脚本`generate_dialogue.ps1`使用Windows本机中文语音；29条对白已随工程提交，运行游戏不需要系统语音服务。
