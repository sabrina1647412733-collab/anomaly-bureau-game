# 主街第二轮：真实Godot完成图

- 本轮改前：`../street_main_v1/04_after_godot.png`，上一轮已提交的Godot实机，基线`2a4e2a1`。
- 持续沿用的目标：`../street_main_v1/02_target_concept.png`，用户认可的AI概念图，非实机。
- `01_after_day.png`：本轮白天完成图，与改前相同机位、时刻、眼高、FOV和分辨率。
- `02_after_closeup.png`：封闭深窗、较新灰泥、门侧物件近景，已修正灰泥片浮进窗洞的问题。
- `03_after_night.png`：同主机位夜雨；夜间没有启用强天空环境贡献。
- `04_after_drying.png`：另一家的旧淡绿墙、窗洞、晾晒架、夹子和带褶皱织物。
- `05_after_weeds.png`：后续17簇低矮小杂草补景的实际近景截图，来源/散列另列manifest的supplements；前四张保留本轮原基线。

四张完成图均从最终Godot玩家相机帧缓冲截图原样复制，未修图。`reference_manifest.json`保留来源和SHA-256。完整32张本轮正式截图及早期对照仅留在F盘验收目录；这里保留有代表性的工程美术证据。

实际结构/碰撞仍以现有`town-layout.json`、`street_manifest.json`和`hero_props_manifest.json`为准。两栋样板房窗洞有背封，不能把它们当可穿过的入口；晾晒为静态模型；图像没有证明照片级美术或人工全程试玩已经完成。

详见工程根目录`20261023_启动修复与主街二轮验收.md`。
