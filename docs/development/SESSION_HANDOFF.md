# 多会话接手

用户已经建立新会话。本轮不再创建会话，也不自动向其他会话发送消息。

## 新会话可直接使用的接手文字

> 继续现有工程 `F:\诡异事务局\得利洗衣店_接手工程`，不要另建替代项目。先读根目录AGENTS.md，以及docs/development下的STATUS.md、TASKS.md、SESSION_HANDOFF.md，再检查git状态。只执行我在本会话指定的任务，保留其他会话和用户的未提交改动。完成后记录改动文件、实测证据、限制与下一步；提交时只暂存本任务明确文件。旧24小时自动续办仍暂停。

## 推荐会话范围

| 会话用途 | 任务 | 文件范围与边界 |
| --- | --- | --- |
| 安装与更新 | 3、4、5 | distribution、更新服务/面板；游戏入口与存档路径改动需协调 |
| 场景与性能 | 6、7、10、12、13、18 | 对应场景、模型和加载；不顺带重写剧情 |
| 玩法与引导 | 8、14、15、16、17、19 | 案件、任务、时间、演出、存档；先做存档问题 |
| 配音与界面 | 9、11 | 声音资源/许可、音频脚本、UI；不要同时重写更新面板 |

范围只是建议，不代表已派发。用户可以只开两个会话，按阶段串行完成。

## 避免互相覆盖

1. 开始前在TASKS登记任务、会话名/链接、明确负责文件和开始提交。不依赖另一个会话的聊天记忆。
2. 同一文件同一时间只由一个会话修改。`scripts/game.gd`、存档、project.godot、全局UI等共享文件必须先协调；无法避开时排队。
3. 共享工作区先查看git diff；禁止整目录暂存、全局回退、清理未跟踪文件或强推。需要并行修改同一模块时再使用独立Git worktree分支，并指定一个会话负责合并。
4. 每个会话完成一个可验证阶段再提交，只提交自己修改的文件；不默认打包或发布。整理目录不构成恢复旧开发授权。
5. 大幅改结构/资源路径前先补迁移清单，通知总记录会话更新入口；不要让另一个会话按旧文件路径重复改。

## 完成记录模板

任务编号／会话：
开始提交／完成提交：
负责与实际改动文件：
已实现：
验证方法、结果与证据路径：
未验证、遗留问题：
需要其他会话配合的共享文件：
下一步：

任务状态使用“待开始／处理中／待验收／已完成”。仅写计划或通过局部测试不能标记整项完成。

## 2026-10-24 安装与更新专项

- 用户授权第3/4/5项及源码提交同步，但禁止公开新Release或替换v0.6.1附件。游戏显示名称为「诡异事务局」，英文文件名用AnomalyBureau。
- 新协议与构建入口改为distribution/build_grouped.ps1、build_windows.ps1和build_bridge.ps1，协议细节见distribution/AUTO_UPDATE.md。旧完整包工具保留兼容回归，不将其当新分组构建入口。
- 通过发行层独立引导PCK先挂载全部组，再加载原main.tscn；game.gd、storage_paths.gd、project.godot和export_presets.cfg未被本项改写。后续内容版必须复用已验收的-BaselineRuntime；更新基础文件要完整迁移。
- 玩家数据仍在EXE旁_玩家数据，更新缓存跟随EXE，不能因--data-dir或巡查目录改变而错位。安装器不依赖HKCU登记，卸载入口在安装目录内。
- 用户再次强调禁止窗口；最终验证通过HiddenDesktop工具创建不可见桌面，绝不SwitchDesktop，整个进程链隔离；Godot仍必须headless+Dummy。不可使用历史“已允许声音/画面”授权恢复可见运行。
- 当前进度及最终产物以STATUS和docs/verification/20261024/安装更新验收.md为准。

2026-10-25上传补充：用户要求上传GitHub后已创建v0.7.0草稿（id 422849708，目标82a652831f126727ca9c7c8693380ec1c96896d6），未公开。用户随后提出自己上传，代理已停止自己的上传进程，草稿移交时无已完成附件；不要误报完整上传已结束。下一步由用户网页上传，文件取F:\诡异事务局\交付\AnomalyBureau-0.7.0-local-final。v0.6.1公开附件未修改。源码已在main，不需重复打包或启动Godot。

## 2026-10-25 默认TEMP错误5补修

用户实机截图发现旧Setup在C盘TEMP初始化失败。已通过distribution/installer/TempHost.cs和build_installer.ps1在Inno前选择可写临时目录，build_windows接入；卸载快捷方式同样经过临时目录引导。30项安装检查及2项损坏包拒绝检查通过，不启动Godot或修改系统TEMP。当前应体验F:\诡异事务局\交付\AnomalyBureau-0.7.0-installer-tempfix\AnomalyBureau-Setup-0.7.0.exe，不能再推荐local-final内旧Setup解决此默认启动问题。游戏资源仍为原0.7.0；公开附件未覆盖，上传仍由用户操作。只读检查已见GitHub v0.7.0公开，早先草稿记录仅为历史状态。详见docs/verification/20261025/安装器临时目录修复.md。UI与存档会话的未提交内容均保持原样。

## 2026-10-25 任务11/17交付

UI设计经用户“可以改吧”确认后已实现，第二夜存档已修复。根因是出租屋case_reader保存误入旧车站写档器，以及保存成功未释放physics_frozen；另补通知书阅读恢复、原子校验/备份和旧梯间Tween清理。schema2保持兼容，正式、巡查和测试数据隔离。具体文件及证据见TASKS本会话记录与docs/verification/20261025/UI与第二夜存档验收.md。

F:/诡异事务局/验收/20261025_UI存档/查看实机对照.html 可切换720p/900p/1080p；actual_before是0432a01脚本的真实Godot图，actual_after_final和actual_forward_plus为本项实机，approved_references仅为AI设计稿。测试入口ui_save_review_test/visual、night2_save_route、night2_restore_checkpoints、night2_exit_restart，运行必须使用F盘独立--data-dir和--verify。50检查点正常三夜路线、86恢复检查及55集成检查通过；无安装包或新Release。

本项不占用安装/更新协议、面板、地图和模型；后续会话可重新登记文件。此前已覆盖又无备份的坏档不伪造进度恢复；未验收跨电脑或人工有声全案通关。

## 2026-10-25 发布端增量上传完成

当前推荐build_patch.ps1：指定上一版完整清单与原BaselineRuntime，日常默认仅输出v3清单、变化容器、校验文件及干净上传目录；无变化时两文件。新增transport=3跨Release来源，保留protocol=2本地挂载布局。publish_release支持DryRun/CheckOnly、历史依赖公开状态及大小/digest核验，不默认发完整安装包/免安装ZIP/桥接ZIP。0.7及更早固定启动器需要一次完整Setup迁移，完整旧目录覆盖至0.8已验证保存玩家数据。

实测UI/模型总上传约0.97/1.47MB，首次基础9文件约1.45GB；连续/跨版、旧源修复、下载失败/缓存/恢复均通过，证据在docs/verification/20261025/减少发布上传验收.md和F:\诡异事务局\验收\20261025_增量上传。体验包F:\诡异事务局\交付\AnomalyBureau-0.8.0-local来自已验收0.7.0导出快照，仅替换更新服务，不自动包含并行6b07c98的UI/存档整合。正式发行前按最终源码重建。未公开/上传Release、未覆盖附件，源码随本项同步；所有Godot验证仍须不可见桌面、headless、Dummy。不改其他会话代码或正式玩家目录。

## 2026-10-25 主流程整合正式发行完成

正式v0.8.0：https://github.com/sabrina1647412733-collab/anomaly-bureau-game/releases/tag/v0.8.0，运行目标源码5d8a5f7722ac27f96f4647c38f2afb9159408039；已经整合安装更新会话和UI/存档会话成果。实际Windows包、旧0.7覆盖升级和线上校验通过，证据见整合发行验收。后续版本使用F盘AnomalyBureau-0.8.0-release及其完整v3清单作为起点，不要误用0.8.0-local旧专项快照。只登记了其余待办，没有恢复旧24小时任务。
