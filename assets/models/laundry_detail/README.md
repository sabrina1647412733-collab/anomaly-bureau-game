# 现有洗衣店的附加精修

`shop_detail.glb` 是本工程新增的壁架、折叠毛巾、洗涤剂瓶、镂空衣篮、实体双管荧光灯、墙扇、管道/固定夹和柜台台灯。保留原楼层、门洞、楼梯及碰撞，摆放避开玩家通行范围。

可编辑源文件为 `source_art/laundry_detail_v1.blend`，生成脚本为 `scripts/tools/build_laundry_dressing.py`。几何由项目脚本原创生成，运行材质复用项目的已收录 PBR 贴图，不含新下载素材。GLB 按材质合并为八组，降低新增绘制调用。

运行接入见 `scripts/laundry_finish.gd`。结构和交互修正在 `scripts/laundry_rebuild.gd`、`building_routes.gd`；第一层检修盖板是带匹配碰撞的 Godot 动态补件。原始白模、原 GLB 和之前的精修资源均保留。
