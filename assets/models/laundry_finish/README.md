# 洗衣楼精修资源

在已审核的 `laundry_rebuild` 白模与碰撞上加细节；原版GLB与碰撞没有覆盖。长度单位米、Godot Y向上。

- 楼体八个 `_finish.glb` 保留原位置、楼层标高、门洞、楼梯与通路，只给可见边缘做毫米级倒角。
- 洗衣机正面为 Godot +Z；原点在机底。独立滚筒原点在圆心，+Z为正面。
- 长椅原点为落地中心；椅面顶高0.44m，靠背在+X侧。运行位置由 `laundry_finish.gd` 定义。
- 门原点在左侧合页底部，宽0.90m、高2.05m，门板沿+X。可动门与碰撞挂同一合页。
- 工作桌高度0.86m；所有新增细节位于原家具占用范围内，新增抽屉柜单独经过可达性检查。

可编辑源：`source_art/case1_finish_source.blend`。生成源：`scripts/tools/build_case1_finish.py`。脚本参数为原白模修复源 `.blend` 和输出目录，可用Blender后台执行。作者输出目录可自由指定，运行时只读 `res://assets/`。

程序材质与额外家具细节在 `scripts/laundry_finish.gd`、`shaders/aged_wall.gdshader`、`shaders/building_floor.gdshader`。材质继续使用项目现有CC0贴图，不改变街道建筑的名称或功能。

原始零件保留在Blender源中；导出洗衣机、滚筒、长椅和门时按材质合并静态部件，减少绘制批次。具体分组数见 `finish_manifest.json`。
