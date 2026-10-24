# Windows安装与分组更新

线上已确认存在v0.7.0；实时状态以GitHub为准，先前草稿移交只是历史记录。当前本地0.8.0支持跨版本复用资源，不再要求每次上传完整资源容器。游戏与安装器名称为「诡异事务局」，英文下载文件前缀为AnomalyBureau。本会话不公开新Release或覆盖既有附件。

## 当前发布传输：transport=3

AnomalyBureau-manifest-v3.json包含完整目标快照。protocol=2继续表示现有本地合并布局，新增transport=3表示跨版本传输。引擎与小型引导PCK不变，仍在原main场景和脚本解析前挂载完整选定组。

每个files条目新增source_version；containers记录来源版本、受限容器名、完整大小及SHA256。未变资源继承原条目的压缩校验值、容器、偏移及版本；新内容按原有单资源ZIP格式拼入一个AnomalyBureau-patch-容器SHA256.bin。客户端严格从同一固定GitHub仓库的对应历史版本读取范围，不接受任意域名或路径；仍逐块校验下载内容并逐资源校验合并结果。连续、跳版与同版本修复都以完整目标快照计算，不需要历史补丁顺序。

build_patch.ps1默认不生成六个完整容器、Setup、免安装ZIP或旧客户端迁移ZIP；每次只选清单、变化容器和SHA256SUMS，无变化时不产生容器。publish-plan.json留在开发侧，不作为玩家附件。prepare_upload.ps1复核计划中每份文件后生成只含必要附件的F盘“上传这些”目录。publish_release默认仍为草稿；-DryRun仅核对本地文件和显示实际上传量，-CheckOnly只读验证源码及历史附件，均不修改Release。真正草稿上传前，必须检查所有历史附件公开状态、大小、digest，缺失、被替换或仍为草稿时拒绝创建新Release。

build_grouped不传PreviousManifest时建立新基础，重新提供六组合并传输容器并令来源全部指向新基础版本。它清除新清单对旧远端版本的引用；客户端本地内容没变仍可复用，不会因容器位置变化重下全部资源。旧公开附件不自动删除，避免中断旧客户端正在进行的下载。完整安装包按需另建，首次基础9文件约1.45GB，日常样板3文件约0.97/1.47MB；不能把基础建立成本当成已消失。

v0.7.0及更早的固定启动器不支持此扩展。0.8.0及之后的发布计划只选v3清单，不同时上传v2清单让旧更新器误走内容更新；旧版需一次完整安装覆盖，真实替换固定启动器和游戏更新服务。完整0.7.0安装目录到0.8.0的迁移已验证菜单启动及存档设置保留。新玩家可下载完整基础安装器，随后直接更新到最新版；需要每个小版本都提供最新离线完整包时，那一份完整包仍需要额外上传，不能承诺免上传。

下方关于v2同Release传输与v0.6旧桥接的内容保留为兼容记录，当前日常发布优先使用上述v3流程。验收见docs/verification/20261025/减少发布上传验收.md。

## 运行布局与加载顺序

| 路径 | 用途 |
| --- | --- |
| AnomalyBureau.exe | 固定.NET Framework启动器，旧事务恢复与独立更新工作进程 |
| AnomalyBureau.Game.exe | 固定Godot 4.7.2 x64引擎 |
| AnomalyBureau.Game.pck | 极小的独立引导项目，不预加载任何游戏脚本 |
| _运行文件/active.json | 当前完整资源快照、版本、基础文件标识 |
| _运行文件/packs/组名-内容标识.zip | 六组本地合并资源包；只挂载清单选定的一套 |
| _运行文件/manifests/ | 当前与上一版清单，支持原子切换和回滚 |
| _更新缓存/v2/ | 下载、工作进程状态、事务、健康确认 |
| _更新缓存/migration/ | v0.6.x一次性完整迁移及原生文件备份 |
| _玩家数据/ | 原有存档与设置；更新、覆盖安装、默认卸载均不改动 |

引擎首先只读取引导PCK。bootstrap.gd按base、code_ui、maps、case1、case2、characters_audio挂载选定资源包，全部成功后才动态加载scenes/main.tscn。game.gd及其preload依赖在此之后解析，因此不会先缓存旧脚本再提示更新完成。游戏场景、入口脚本、存档路径与存档schema未改动。更新缓存固定跟随EXE，独立于--data-dir和巡查数据隔离。

Godot挂载ZIP/PCK不会重新应用其中的project.binary，所以资源快照排除此文件；引导项目保留真实项目设置，并在挂载后从清单设置application/config/version。基础引擎及引导PCK的联合SHA256为baseline；后续内容更新必须通过-BaselineRuntime复用同一对文件。基础不兼容时明确要求完整安装，不能假设旧协议会替换新布局。

## 按真实导出依赖分组

构建先执行真实Windows资源导出，再读取每份.import和.remap的目标路径，给导入模型、贴图、二进制场景和脚本建立归属。一个导出路径只进一组；共享目标归base。所有组在主场景前一并挂载，无需将依赖重复复制到每个案件组。

| 组 | 内容与更新频率 |
| --- | --- |
| base | 共享字体、纹理、全局导出元数据等，通常低频 |
| code_ui | 脚本、UI、着色器、主入口场景，通常高频且小 |
| maps | 镇内地图与街景资源 |
| case1 | 第一案场景与道具 |
| case2 | 第二案专有资源 |
| characters_audio | 已有角色、动作及声音资源 |

本次导出共有2,092个资源路径、2,005份不同内容。相同内容跨路径只传输一次；运行时仍保留导入引用需要的路径别名。分组影响本地合并范围，网络按单个资源的内容校验值复用，不会因为改一个模型就重下整组角色或贴图。

## 清单与网络格式

AnomalyBureau-manifest-v2.json为protocol=2，包含version、baseline和完整files数组。每条记录为：

```json
{"path":"scripts/example.gdc","group":"code_ui","size":1234,"sha256":"资源内容SHA256","asset":"r-资源内容SHA256.zip","download_size":789,"download_sha256":"传输块SHA256","bundle":"AnomalyBureau-resources-code_ui.bin","offset":456}
```

传输块为只含data条目的ZIP；六个.bin容器将传输块顺序拼接。客户端只发起Range: bytes=offset-(offset+download_size-1)，严格要求206及准确Content-Range，再校验长度和SHA256。服务端忽略Range时直接失败，不会悄悄下载完整容器。2026-10-24已用线上v0.6.1附件实测100字节范围得到206和准确100字节响应。

这样每版只需发布六个资源容器、一份清单、完整免安装包、Setup、旧协议迁移包及校验文件，避免超出GitHub每个Release的1,000附件限制。单附件必须小于2GiB，publish_release.ps1有检查；未来超过此限应拆容器，不能放宽校验。

生产客户端只接受固定公开仓库sabrina1647412733-collab/anomaly-bureau-game的正式版本、精确附件名、HTTPS下载URL和GitHub返回的SHA256 digest。资源容器URL由清单所在Release目录和受限容器名组成；客户端不含Token。localhost HTTP仅供独立验收使用。

## 下载、修复、合并与恢复

1. 启动检查GitHub正式版本。先下载并校验小型完整清单，再由后台工作进程逐资源校验本地包和完整下载缓存，计算缺失资源的精确压缩字节数。菜单在确认更新前显示本次MiB与精确字节数。
2. 只下载变化、缺失或损坏的资源。每块最多重试三次，显示进度与明确错误。已完整通过SHA256的块保留并复用；.part残片不当成完整下载。取消或退出下载时写取消标记，旧版本仍可启动。
3. 独立更新器发出ready后游戏才正常退出。原进程未退出时取消更新，不关闭用户的其他游戏或程序。
4. 本地合并目标组ZIP：从已校验旧包复制未变资源，从缓存补入变化资源；再次逐资源验证。完整目标包准备好之前不改active.json。每次是完整目标快照，删除资源不会残留在旧覆盖层中，跨版本不依赖逐个历史补丁。
5. 保存旧、新清单及写前事务，再原子切换active.json并启动新游戏。真实主菜单初始化完成并经过两个帧后写随机令牌；额外存活两秒才提交。120秒未确认、启动退出或更新失败时恢复旧清单。仅本事务创建的未健康子进程可能被结束；不结束用户已有进程。
6. 断电或更新器异常退出后，固定启动器先恢复未完成事务。若上次创建的游戏仍活着，提示先正常退出，避免替换其正在使用的文件。存档与设置不参与回滚。
7. 每次成功后保留当前及上一版所需的组包与清单，清理更早版本和已合入的下载缓存。文件占用导致清理失败时保留现场，不能把已健康的新版本当作更新失败。没有无限累积的覆盖包链。

同版本公开清单也会验证资源，支持缺失/损坏资源修复。若固定EXE、引导PCK、启动器本身损坏而无法进入游戏，应使用完整Setup覆盖原目录或完整免安装包修复；不能把尚未启动的游戏描述为可在线自修复。安装目录必须可写，需要为目标组、上一版及临时合并预留空间。

## v0.6.x实际迁移

旧启动器协议1只接受manifest.json和两个AnomalyBureau.Game文件，禁止替换启动器或新增目录。本次继续提供固定名称AnomalyBureau-update-win64.zip：它包含旧协议可接受的Godot引擎和专用桥接PCK，桥接PCK内嵌完整新版文件夹。

旧更新器依照原协议下载、备份、替换并启动桥接项目。桥接项目校验完整负载、解压至安装目录内的更新缓存，校验每份文件，写旧协议健康确认；等旧事务committed后才退出并交给新独立迁移器。迁移器等旧更新器释放锁，备份真正旧版运行文件（从旧协议backup取回原版，不把桥接PCK误当旧游戏），再安装不可变组包、替换固定启动器与引导文件、最后切换清单。

新版真实主菜单健康确认后才提交迁移。失败可恢复原版启动器、真正的旧版PCK和旧布局。迁移中断后，新固定启动器能恢复未完成迁移。通过现有v0.6.1二进制实测完成整条链路，而非用修改后的启动器模拟旧协议。此迁移允许一次完整下载；新0.7.x内容更新随后只传变化资源。没有更新器的0.3.x/0.5.x使用完整包。

新玩家始终只需一个完整安装包或免安装包，不需要下载历史补丁。需要更换基础引擎/引导层/固定启动器时，再使用完整包或兼容桥接迁移，不能直接发资源清单。

## 安装与卸载

2026-10-25追加：用户默认双击旧Setup在C盘TEMP创建目录即错误5，发生于Inno脚本执行前；下方旧验收使用F盘TEMP，不能覆盖该失败条件。现由installer/TempHost.cs外层引导在启动Inno前选定可写临时目录，只对子进程设置TEMP/TMP。build_installer.ps1编译引导、卸载入口并嵌入带SHA256校验的Inno负载；build_windows统一走此入口。卸载快捷方式改为AnomalyBureau.Uninstall.exe，先复制到临时目录并退出原入口后再启动unins000.exe，避免卸载时自身EXE仍被占用。不要直接双击unins000.exe绕过此处理。最终30项安装检查及2项损坏包拒绝检查通过，详见docs/verification/20261025/安装器临时目录修复.md。新版完整安装器位于独立installer-tempfix交付目录，未替换原产物或公开附件。

旧Setup已复现：文件解压后，开始菜单写入与HKCU卸载项RegCreateKeyEx均报错误5（拒绝访问），随后整包回滚。本次去掉对这些写入的强制依赖。原先口述“初始化失败”不再当作已知根因；实际复现证据是权限失败与安装回滚。

Setup使用当前用户权限，可选择位置；F盘存在时建议F:\Games\AnomalyBureau。标准目录/准备安装页显示实际文件所需空间，并额外预留1GiB。默认创建「诡异事务局」桌面快捷方式，指向固定启动器并使用参考图转换的正式ICO。桌面无写权限时明确报告并保留安装目录内的游戏快捷方式。不会强制关闭进程或修改音量。

首次安装、原目录覆盖升级、重复安装、卸载及重装均使用同一套运行文件。卸载入口在安装目录内，默认保留_玩家数据；不依赖系统“已安装应用”注册。测试用/DESKTOPDIR=F盘隔离目录验证真实.lnk，避免操作用户桌面。

## 玩家更新日志

游戏内仅显示版本、日期、「新增内容」「修复问题」「必要的已知问题」。新版本从明确的玩家段落读取短句，构建和验收章节不显示。v0.6.0/0.6.1旧长日志使用固定玩家摘要，历史Release正文和附件不修改。技术记录留在本文件及docs/verification。

## 构建与验收入口

构建命令见README.md。后续内容版必须传-BaselineRuntime，保持基础原生文件不变。build_grouped.ps1使用真实Windows导出；layout_manifest.py和package_portable.py采用明确安装文件清单，排除玩家数据、缓存、巡查与测试输出。build_windows.ps1复用Windows目录，build_bridge.ps1为旧客户端建立完整迁移包。publish_release.ps1支持全部容器与清单，默认草稿；本轮未运行发布。

```powershell
.\distribution\test_updater.ps1 -OutputDirectory 'F:\验收\旧协议单测'
.\distribution\test_grouped.ps1 -OutputDirectory 'F:\验收\分组单测'
.\distribution\test_migration.ps1 -OutputDirectory 'F:\验收\迁移故障'
.\distribution\test_install.ps1 -Installer 'F:\交付\AnomalyBureau-Setup-0.7.0.exe' -RuntimeDirectory 'F:\交付\Windows' -OutputDirectory 'F:\验收\全新安装目录' -LegacyRuntimeDirectory 'F:\旧版\Windows'
python distribution/test_grouped_e2e.py --release 'F:\交付' --output 'F:\验收\全新样板目录' --godot 'Godot控制台程序.exe'
# 同一目录继续验证真实加载内容、同版本修复与正常退出下载：
python distribution/resume_grouped_e2e.py --release 'F:\交付' --output 'F:\验收\全新样板目录' --godot 'Godot控制台程序.exe'
python distribution/test_exit_download.py --release 'F:\交付' --output 'F:\验收\全新样板目录' --godot 'Godot控制台程序.exe'
.\distribution\test_legacy_migration.ps1 -ReleaseDirectory 'F:\交付' -LegacyRuntimeDirectory 'F:\旧版\Windows' -OutputDirectory 'F:\验收\全新迁移目录'
```

所有Godot验证使用--headless --audio-driver Dummy和隔离数据，后台隐藏进程；不打开编辑器，不播放声音，不操作正式存档。验收仅证明安装、资源加载和主菜单健康，不等于人工通关、听感验收或跨电脑验证。具体结果与限制见docs/verification/20261024/安装更新验收.md。

用户禁止窗口期间，应先用Framework csc将updater/HiddenDesktop.cs编译为F盘的winexe，再将测试驱动脚本放入它创建的私有桌面中运行。参数顺序为：F盘状态文件、当前PowerShell绝对EXE路径（可用(Get-Process -Id $PID).Path取得）、-NoProfile、-File、F盘驱动脚本。它从不SwitchDesktop，隔离失败时直接退出，不回退到主桌面；所有后代进程仍须headless+Dummy。最终记录中isolated-desktop-status.txt和unit-desktop-status.txt均为isolated_desktop=true、exit=0。

参考：[Godot资源包加载](https://docs.godotengine.org/en/stable/tutorials/export/exporting_pcks.html)、[ProjectSettings](https://docs.godotengine.org/en/stable/classes/class_projectsettings.html)、[GitHub Release限制](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases)。
