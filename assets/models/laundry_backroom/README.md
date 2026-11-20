# 第一案后房模型

2026-10-25第一轮场景修复。沿用原后房墙、地面、天花、门洞和三夜证据链；替换旧空白几何与错位物件，不新增剧情事实。

- `backroom.glb`：桌与顾客簿、实体旧招牌、锅炉/表盘/管道、照片板、剪报及儿童雨衣。绝对Godot世界坐标，Y向上、米制，父节点必须保持原点。
- `boiler_keys.glb`：局部原点为钥匙环圆心，由`manifest.json`中的`l_keyring`定位。整个根节点随既有存档所有权隐藏/显示，不能只隐藏其中一把钥匙。
- `manifest.json`：物件交互位置、两个新增家具碰撞、退出使用的旧几何清单及导出分组数。`laundry_rebuild.gd::POINTS`须与它一致；专项测试核对实际网格距离及中心准星选择，不能只核对两份坐标。
- 三口之家照片沿用`assets/ui/inventory/materials/family_photo_v1.png`，由`laundry_backroom.gd`安装到照片板上；原图未修改。

可编辑源为`source_art/case1_interior_round1.blend`；原`case1_finish_source.blend`与`laundry_repaired.blend`原样保留。`scripts/tools/repair_case1_interiors.py`从原精修源重新生成本轮资源，不对已修复源叠加操作。作者源保留旧零件并标记`round1_retired`，导出前排除；仅导出的副本按材质合批。

运行时由`scripts/laundry_backroom.gd`接回原`LaundryWorld`，继续使用项目PBR贴图与原交互阅读系统。不要重新叠加旧`floor2_backroom.gd::build()`；否则会重复墙体、家具和交互外观。

楼梯修复同时更新F1—F5与ROOF的finish资源：10级踏步/梯跑、18cm斜向梯板底部、侧墙灯具；楼层标高、连续斜坡碰撞与门洞不变。F2旧铁架台/水表箱碰撞已移除，桌和锅炉由本模块生成匹配碰撞。
