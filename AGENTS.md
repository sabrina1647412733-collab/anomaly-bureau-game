# 项目接手规则

## 当前项目与剧情基准
- 在这个现有 Godot 工程上更新，不另起工程，不用历史地铁原型替换洗衣店。
- 当前目标是完成第一案「得利洗衣店」完整三夜内容与唯一结局。
- 唯一剧情基准是 `剧本/诡异事务局_回潮_前三案详细剧情稿_v2_唯一结局版.md`，同名 DOCX 为阅读版本；其他旧稿仅作历史参考。
- 许砚是主角，其他角色按照已有姓名对应。角色动作可自行设计。
- 已接入的回潮镇街道必须保留各建筑已有名称、对应功能和位置语义；先检查现有数据再修改。
- 沿用现有洗衣店、手机、背包、时间、地图、声音与视角系统。场景先修复；确需重做时先提交整体毛坯白模供用户审核，再精修材质、家具与灯光。

## 工程入口
- Godot 4.7.2 stable，入口 `project.godot`，主场景 `scenes/main.tscn`，主脚本 `scripts/game.gd`。
- Godot 导入后 F5 运行整个项目。启动游戏.bat 含原作者本机引擎路径，其他机器优先通过编辑器运行。
- 游戏依赖的资源应随工程放入 `assets/` 并使用 `res://`，不要新增对本机磁盘绝对路径的运行时依赖。
- 原始角色资产目录 `F:\角色3d模型` 仅是作者本机来源目录；不要假设其他开发者存在该目录。

## 当前进度（2026-10-21）
- 出租屋→回潮镇→独立洗衣店三夜调查→归还原衣→录名与阿七尾声→唯一结案已接入。
- 前两夜交班后须经街道回出租屋床边休息。夜次、证据、工资和电路状态支持存读档。
- 第二、第三案仅有剧本，未制作玩法。不要混淆第一案三夜与三个案件。
- 近景手部使用 `first_person_hands.gd` 专用平滑网格及分类握姿，第三人称仍使用许砚原角色。
- 用户提供的Meshy道具优化版在 `assets/models/case1_props/`，原始模型未覆盖。
- 时间倍率固定：现实 1 分钟＝游戏 10 分钟；随身时钟可跳时。
- 洗衣楼运行模块在`assets/models/laundry_rebuild/`，修复的可编辑源文件在`source_art/`（.gdignore避免要求Godot配置Blender）；生成脚本在`scripts/tools/`。七段动作在`assets/town/xuyan/motion/`。
- 最新验收见`20261021_重建接入验收.md`，本轮6组208项；`rebuild_walk_test.gd`使用真实move_and_slide检查上下楼。不要把上一版本285项作为本轮结果。
- 当前路线、操作和验证见 `第一案三夜_操作与验收.md`；旧验收文件仅代表历史版本。

## 修改与验证
- 最新表演/反馈源码小更新见`20261022_交互反馈与基础角色表演验收.md`：8组399项，窗口新增套件90项。失败卡片统一用`campaign.blocked`/`feedback.blocked`，不要改成必须手持指定钥匙，失败不强制弹阅读页；正确钥匙仍自动从包里使用。声音/韵律/包络在`assets/audio/performance/`，三位NPC面部网格在`assets/models/chars/performance/`，不要覆盖原GLB或坐姿动画。嘴部上限0.48，仅基础响度口型；许砚未新增脸部形变。泵已通电与排水完成后的重复操作必须幂等。
- 最新源码小更新见`20261022_暂停交互与脱困修复验收.md`：7组309项，另有窗口输入24项。`player.physics_frozen`用于暂停，恢复/读档/脱困必须解除；对白以`active`记录会话，不用面板可见性代替会话状态。菜单退出使用cancel，不能执行未完成回调。短信展示由`case_director.sync_toast`控制，模态期间保留剩余阅读时间。Release v0.3.2二进制不含本次源码修复。
- 2026-10-22 用户发行偏好：小更新只修改现有工程、完成相关验证并同步GitHub，不默认重新生成或上传安装包/免安装ZIP。大更新或用户明确要求试玩包时再打包发行。
- 2026-10-22：准星选择在`interaction_focus.gd`，脱困在`play_safety.gd`，退出自动档在`exit_autosave.gd`。保留三个手动槽位；`--verify`不得触发自动写入玩家目录。新增回归`focus_safety_save_test.gd`使用自己的临时测试文件并删除它。
- Windows导出与安装包流程见`distribution/README.md`，安装包放GitHub Release，禁止加入Git大文件历史。当前发行v0.3.1，本轮验收见`20261022_引导交互与发行验收.md`。
- 小范围修改，先读对应脚本和测试，保留 `.uid` 与资源导入设置文件；不要提交 `.godot/`。
- 测试脚本在 `scripts/tests/`，例如：`godot --headless --path . -s res://scripts/tests/case1_flow_test.gd`。
- `case1_flow_test.gd` 兼容入口继承 `case1_three_nights_test.gd`，不再测试旧B/C结局。
- 另有 `case1_hand_test.gd`、`case1_investigation_walk_test.gd`、`director_flow_test.gd` 和 `field_system_test.gd`。启动测试加 `-- --verify`，不得写入玩家存档或结案记录。
- 先导入资源，再做相关测试与主场景启动检查。报告实际运行结果，不把自动测试替代人工试玩。
- 提交前检查 `git status`，不要提交凭据、玩家存档、临时截图或导出安装包。不要强推或覆盖远端历史。

## 2026-10-22 美术与声音精修接手补充
- 当前发行 v0.3.2，本轮9组341项通过；最新验收见`20261022_美术与声音精修验收.md`。
- 新视觉资源在`assets/models/laundry_finish/`，原`laundry_rebuild`碰撞保留。程序细节在`laundry_finish.gd`。床垫与抽屉柜有新增匹配碰撞。
- 三位演员的修正动画库在`assets/models/chars/finish/*_clips.res`，不可跨角色套用。生成流程与骨轴转换规则见该目录README。
- 长椅椅面顶高0.44m；周秀兰、阿七均对齐当前椅子，不能恢复旧的0.49m座高和阿七旧X位置。
- 声音控制在`field_audio.gd`，许可与来源在`assets/audio/finish/`；不得删除Kevin MacLeod署名。配乐、音效、对白、环境四总线独立。
- `finish_audio_test.gd`检查分区、事件、循环、暂停、避让和姿态。画面对照用`art_audio_review.gd`，不是玩家流程入口。
- 近景手部使用独立SubViewport；viewmodel_view.gd中的补光已降低，避免手部过曝。不要直接套用主场景光照来解释近景问题。
- 角色仍为合成配音与基础动作，没有完整面部口型；第二、第三案仍仅有剧本。
