# UI提升与第二夜存档验收（2026-10-25）

任务11、17。工程仍为 `F:/诡异事务局/得利洗衣店_接手工程`。起点0432a01，期间安装会话独立提交ebdb853；本项不修改或提交其文件。未制作安装包、未创建或修改Release。

## 设计确认与实现

先读取AGENTS、STATUS、SESSION_HANDOFF、TASKS和Git状态，登记共享文件范围。检查已认可的街景方向、现有四类背包及真实游戏界面，用现有场景/物品图制作Godot布局稿，再用内置image_gen生成五类设计参考图及两张文字排版说明稿。所有图均标注待确认，未作为实机交付。用户随后明确回复“可以改吧”，才开始修改运行UI外观。

局内：Noto Sans SC、旧纸白与黄铜色；目标去掉流程编号和重复按键，H仍展开原目标/原因/路线，45秒/90秒帮助保留。常驻长快捷键行收敛为背包/暂停；交互仍由原中心射线挑选，七号机等显示物件名与E操作。对白采用渐变衬底与下方居中排版，像素测量分段保留完整中文；通知排在对白之后，短信正文仍入箱。

背包：只有道具/线索/钥匙/衣物，保留六列方格及超量滚动、选中记忆、取出/F查看/B收纳；缩小详情图、扩大说明区和字号、显示数量。手机保留现有应用与触发顺序，聊天列表、正文与通话字幕可滚动；来电、拒接、返回主屏和收纳按钮均在屏内，离开通话页停止语音。拒接保留未接听事实，不冒充完成剧情。

暂停/存读档：同一局部色板、左侧操作栏、三个手动槽及独立自动档；覆盖前确认，显示案件、夜次、地点、游戏时间和保存日期。未将此主题赋给更新面板或全局窗口。

## 存档根因（均有复现）

1. **出租屋阅读休息回执时保存分流错误。** 此时case_mode为空，状态是case_reader或其暂停状态，但laundry案件对象仍保留。旧game_save只按case_mode和prologue前缀判断，误入旧车站写档器，写出round/got/btn格式并报告成功，丢失本案夜次与调查现场。普通第二夜室内调查并非一律写盘失败。真实键盘路线与sleep_input复现捕获了这个区别。
2. **保存后仍冻结。** _open_pause将physics_frozen设为true，原保存成功分支只恢复can_move，遗漏解除物理冻结。第二夜303检查点经实际槽位信号复现：文件有效，但角色不能移动。
3. **通知书阅读状态未正规化。** 手动capture不接受prologue_ui/prologue_choice，导致可安全恢复的阅读也被拒绝；旧提示把状态问题和写盘错误混为一谈。

修复：保留中的laundry案件始终走版本化写档；成功后复用正常继续游戏流程，操作反馈不再覆盖剧情字幕；阅读/对白/时钟/观察镜头正规化为稳定现场。切换场景或攀梯期间不保存，明确说明等到达现场后重试，退出失败时不退出。退出自动档不再用旧场景fallback冒充当前进度。

手动与自动档共用临时写入、flush、JSON和结构读回校验、有效旧档备份及原子替换。失败保留有效档；损坏/缺失主档可恢复有效.bak并说明，无法恢复则保留原文件、禁用读取。删除槽位同步删除其备份。schema_version仍为2，新元信息/手机设置为可选字段；已有正常档不用清空。显式--data-dir不再复制正式user://旧档。

读档取消旧检修梯Tween并恢复物理处理，避免旧演出继续搬动新现场玩家；不保存黑屏、临时相机或通话为永久状态。保存案件进度、证据、物品、设备、手机消息/静音、时钟、位置和朝向。

## 验证结果

证据根：`F:/诡异事务局/验收/20261025_UI存档/`。所有新测试使用显式F盘--data-dir与--verify；未覆盖正式槽位，不强关用户程序，不改系统音量。

| 检查 | 最终结果 | 证据 |
| --- | --- | --- |
| 新档正常输入三夜路线；真实暂停/槽位/覆盖确认 | 唯一A结束、52次路线交互、无错误；14次原拨时、9条派遣消息 | route_verified/route_result.json、checkpoints.json |
| 第一夜交班、出租屋回执、第二夜到店、303调查、第二夜交班与回家读档 | 9个路线检查点、86项通过 | restore_verified2/restore_results.json |
| 三槽位、覆盖、实际写入失败、备份、旧档、阅读/对白/手机/镜头/梯间恢复 | 55通过、0失败 | integration_complete/results.json |
| 正常退出后新Godot进程继续自动档 | 第二夜play状态、物理正常 | restart_verified/restart_result.json、exit_verified.log |
| 720p/900p/1080p、空背包、长对白/手机字幕、键盘与控件边界 | Compatibility 72通过，Forward+ 72通过 | actual_after_final/visual_results.json、actual_forward_plus/visual_results.json |
| 既有背包实际过滤/选取/滚动/取出回归 | 44通过 | inventory_test.log |
| 输入恢复、对白回调、落地回归 | 23通过 | input_test.log |
| 中心射线、安全位置、自动存档回归 | 56通过 | focus_verified.log |
| 第二案保存与跨案件恢复 | 30通过 | case2_integration_test.log |
| 注意力/45秒展开/90秒一次提醒/H | 40通过 | guidance_attention_test_verified.log |
| 反馈/真实路线/设备与恢复 | 33通过 | guidance_feedback_test_verified.log |

路线检查点中历史文件名“休息后进入下一夜”实际是在床边休息页打开时截取，夜次仍为休息前，正是旧格式分流的复现点。后续到店检查点证明休息后进入第二夜/第三夜。测试脚本标签已改为“床边休息页”，没有改写证据文件内容。

## 实机前后对照

- `actual_before/`：Git 0432a01的脚本快照运行，同一套机位/物品/状态配置，Compatibility；游戏资源复用当前未改的资源。
- `actual_after_final/`：本项实际代码，Compatibility，36张原始帧缓存图；`actual_forward_plus/`另有36张Forward+原图。
- `01_局内文字前后对照.png`、`02_其他界面前后对照.png`：将对应原始图等比并排排版，只加标题，不修图。
- `approved_references/`仅为获准的AI设计方向，`reference_prompts.json`记录内置image_gen提示；不冒充实机。

画面验证为实际Godot渲染的脚本配置状态与输入检查；长文本压力图使用案卷原文作为测试内容，不新增剧情台词。路线验证使用正常键盘走路、瞄准和交互，跳过阅读/语音等待，不当作人工通关时长。不是跨电脑或有声完整试玩；原地图中的设备文字、模型与结局均保留。

## 复验入口

先使用本机Godot4.7.2、F盘TEMP/TMP和独立数据目录。例如：

```powershell
Godot_v4.7.2-stable_win64_console.exe --headless --audio-driver Dummy --path . --script res://scripts/tests/night2_save_route.gd -- --verify --data-dir=F:/UI复验/route_data --route-report=F:/UI复验/route
Godot_v4.7.2-stable_win64_console.exe --headless --audio-driver Dummy --path . --script res://scripts/tests/night2_restore_checkpoints.gd -- --verify --data-dir=F:/UI复验/restore --fixtures-dir=F:/UI复验/route
Godot_v4.7.2-stable_win64_console.exe --headless --audio-driver Dummy --path . --script res://scripts/tests/ui_save_review_test.gd -- --verify --data-dir=F:/UI复验/integration --fixtures-dir=F:/UI复验/route
```

实机图用ui_save_review_visual.gd，加--review-dir=F:/UI复验/实机图，使用真实渲染而非headless；其运行需要--verify。退出跨进程脚本night2_exit_restart.gd第一次加--write-exit及--fixture=真实第二夜JSON，第二次沿用同一测试data-dir。

## 遗留与边界

未做跨电脑、安装包、听感或人工全案通关验收。此前已经被旧车站写档器覆盖、且没有有效备份的文件，不能凭空还原丢失的剧情数据；本项保留旧文件，不用清空进度绕过。正常schema2存档已验证兼容。

用户原project.godot注释、两份修改中的blend及四份未追踪blend保留。安装/更新会话的distribution、update_service等改动不纳入本项。TASKS等共享文档按本项内容单独暂存，保留另一会话新增的发布构建记录。
