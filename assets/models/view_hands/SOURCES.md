# 许砚独立第一人称视图模型

此目录为本轮新增的近景手臂和持物姿势，不从许砚现有全身 GLB 截取手臂，第三人称角色与七段动作库保持独立。

- 解剖拓扑起点：MakeHuman/MPFB 自带的中性 `data/3dobjs/base.obj` 的手部区域与 `weights.default.json` 权重数据；两份来源文件明确声明 CC0。数据原版权方包含 Data Collection AB、Joel Palmius、Jonas Hauquier 等，沿用其公开释放的 CC0 数据许可。没有复制 MPFB 插件代码。
- 本轮制作：独立裁切、相机空间拟合、连续掌部与手指变形、袖筒/罗纹袖口、细分和平滑法线。手机、纸张、照片、时钟、衣物、鞋和钥匙共七种姿势；纸张、照片和毛衣为双手，其余以右手为主。
- 可编辑文件：`source_art/view_hands_v1.blend`。运行只加载本目录 GLB，其他电脑不需要 Blender 或作者的原始素材目录。
- 生成脚本：`scripts/tools/build_view_hands.py`。重建时由参数提供原始 CC0 OBJ 与权重；也可直接在现有 `.blend` 修改并选中对应姿势导出，不依赖作者磁盘路径。
- 运行中的外套材质使用项目已收录、已注明来源的 `poly_wool_herringbone`。旧程序手部留在 `source_art/first_person_hands_legacy.gd.txt`，原全身模型未覆盖。

这套资源包含七种已拟合的静态持物姿势，拿起/放下与切换由 Godot 过渡控制；不声称包含完整动作捕捉、摄影扫描皮肤或手指 IK。
