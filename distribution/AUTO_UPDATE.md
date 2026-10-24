# Windows 游戏内更新

当前工程在原游戏中加入 GitHub 正式版本检查、更新内容、下载进度、取消/重试、历史日志和独立更新器。数据源固定为公开仓库 `sabrina1647412733-collab/anomaly-bureau-game`，客户端不携带 GitHub Token。私有仓库不能直接用于此公开客户端；如以后转私有，需要另设公开发行仓库。

## 玩家使用

首次运行安装程序，或完整解压 Windows ZIP。此后始终通过 `AnomalyBureau.exe` 或安装程序创建的快捷方式启动；三个 EXE/PCK 文件必须一起保留。每次启动会在后台请求 `/releases/latest`，只接受较新的正式 `vX.Y.Z`，不降级、不安装草稿/预发行。网络超时不妨碍继续游戏。

主菜单「更新日志 · v版本」从 `/releases` 读取版本号、UTC 发布日期与正文，每页 20 项，可加载更早版本。正文以纯文本展示，保留 GitHub Markdown 字符，不执行远程 HTML/图片/链接。日志页可重新读取，也可检查更新。

新版本提示只在主菜单出现；若检查完成时已进入游戏，等返回主菜单才显示。「稍后更新」本次运行不再弹同一版本，下次启动会重新检查。「立即更新」下载完整包，显示字节数和百分比；下载期间可以取消。失败可重试检查或重新下载。下载失败不会退出游戏。校验与交接阶段锁定关闭按钮，避免重复安装。

原 v0.3.x/v0.5.x 程序不含更新器，需要首次安装本版。后续版本发布专用更新包后，玩家即可在游戏内更新。

## 文件布局与保护范围

| 路径 | 用途 |
|---|---|
| `AnomalyBureau.exe` | 固定 .NET Framework 启动器 / 故障恢复入口 |
| `AnomalyBureau.Game.exe` | Godot Windows x64 程序 |
| `AnomalyBureau.Game.pck` | 游戏资源与脚本 |
| `_玩家数据/` | 保留原工程存档、设置与结案记录 |
| `_更新缓存/` | 下载、暂存、上一版备份、事务记录与启动确认 |

更新器只允许修改 `AnomalyBureau.Game.exe` 和 `AnomalyBureau.Game.pck`。不会解压或删除存档目录、设置、启动器、任意其他文件；安装程序也不注册玩家数据为卸载文件。桌面存档仍使用原 `storage_paths.gd` 规则，未改回 AppData。测试使用隔离目录，不能使用玩家实际存档。

下载包上限为 2,000,000,000 字节，低于 Godot HTTPRequest 原生有符号 32 位长度上限；当前完整包约 784 MB。没有增量更新和断点续传，重试会完整重下。安装目录须可写，建议预留至少 4 GB 空间，更新期间不移动目录。

## 安装、确认与回滚

1. 游戏校验附件大小与 GitHub Releases API 的 `digest: sha256:...`，校验在线程中完成。
2. 从固定启动器复制出 `_更新缓存/Updater.exe`；发送任务，收到独立进程就绪确认后才关闭游戏。
3. 更新器等待原游戏进程退出，再次校验 ZIP 的 SHA256。ZIP 只能有清单和两个游戏文件；拒绝重复条目、额外文件、路径穿越、目录联接和不支持的协议。逐文件验证长度与 SHA256。
4. 在修改前完整备份两个旧文件。每次替换前将意图写入事务记录，支持中途断电后恢复。
5. 自动启动新游戏。游戏完成场景/主菜单初始化并经历两个帧后，写入随机令牌确认。更新器等待最长 120 秒，并额外观察进程存活两秒，才提交成功。
6. 替换失败、启动失败、进程提前退出或确认超时则恢复旧文件并重新启动。只有本次更新器创建且尚未确认健康的新进程可能被结束，不强关其他玩家进程。
7. 若更新器自身异常退出或系统断电，下次从固定启动器进入，先恢复未完成事务，再启动旧游戏。若未确认的新游戏仍运行，会要求先正常退出它，避免替换正在使用的文件。失败原因在游戏内展示，可重新检查/下载。

这是程序启动与主菜单健康检查，不代表新版本所有关卡都已验收。旧版备份不覆盖玩家数据，也不回退玩家新产生的存档；未来变更存档 schema 时仍应保持向后兼容。当前协议只替换两个运行文件；如以后引入外置 DLL，需先更新协议与启动器，再发行。

## 开发者构建

依赖 Godot **4.7.2 stable** 及同版 Windows x86_64 模板。启动器使用 Windows 自带 .NET Framework 4.x 编译器，运行不依赖 PowerShell 执行策略，不需另装 .NET SDK。安装程序使用已有 Inno Setup 6；便携版和游戏内更新不依赖 Inno。

```powershell
# 修改 project.godot 的 application/config/version，以及 Windows 预设的文件/产品版本。
# 每版使用新的 X.Y.Z；GitHub Tag 必须是对应 vX.Y.Z。
.\distribution\build_update.ps1 -GodotBinary 'Godot控制台程序.exe' -OutputDirectory 'F:\交付\版本目录'

# 同时生成首次安装用的 Setup.exe；沿用原 AppId，安装到当前用户可写目录。
.\distribution\build_windows.ps1 -GodotBinary 'Godot控制台程序.exe' -InnoCompiler 'ISCC.exe' -OutputDirectory 'F:\交付\版本目录'
```

输出：`Windows/` 可玩文件夹、首次安装用的完整便携 ZIP、`AnomalyBureau-update-win64.zip`、`manifest.json`、`SHA256SUMS.txt`；安装构建另含 `AnomalyBureau-Setup-X.Y.Z.exe`。Windows 预设排除发行工具、源码美术、测试、玩家数据和更新缓存。便携 ZIP 使用明确文件清单，不打包已经试玩产生的数据。`build_portable.ps1` 也调用同一构建流程，避免漏带启动器。

更新清单协议：`protocol=1`，`version=X.Y.Z`，`files=[{path,size,sha256},...]`，恰好包含两份允许的运行文件。清单由构建脚本自动生成。

## 发布 GitHub Release

先完成源码同步和回归，使用对应源码完整 commit SHA；不要将 EXE、PCK、安装包或玩家存档提交到 Git。发布脚本使用 Git Credential Manager 中已有的 GitHub 登录，直接调用官方 Releases API；凭据仅在开发者进程内存，不写入游戏或附件。也可以通过 GitHub 网页发布：

```powershell
# 先在本机完成GitHub的Git登录；脚本不在后台弹出登录框。
# 默认只创建草稿，正文直接使用中文 Markdown 文件。
.\distribution\publish_release.ps1 -ReleaseDirectory 'F:\交付\版本目录' -NotesFile '.\distribution\RELEASE-0.6.0.md' -TargetCommit '对应源码完整40位SHA'
# 检查草稿后在 GitHub 发布，或在上述命令显式增加 -Publish。
```

Release 附件必须包含固定名称 `AnomalyBureau-update-win64.zip`；GitHub 自动产生 SHA256 digest。安装 EXE 和完整便携 ZIP 用于首次安装。不要上传 GitHub 自动生成的 Source code ZIP 作为更新包。未来每次只需升版本、构建、测试、填写 Release 正文并发布，客户端会自动读取。相同 Tag 的已发布附件不要替换，修正内容应发布更高版本。

没有有效专用包或 GitHub digest 时，游戏会说明尚不能安装，不会尝试执行旧安装 EXE。当前线上 v0.3.1/v0.3.2 只有旧安装包；本次本地构建不会自动变成线上发布。

## 验证命令

```powershell
.\distribution\test_updater.ps1 -OutputDirectory 'F:\验收\更新器'
godot --headless --audio-driver Dummy --path . -s res://scripts/tests/update_system_test.gd -- --verify --github-live
godot --headless --audio-driver Dummy --path . -s res://scripts/tests/focus_safety_save_test.gd -- --verify
.\distribution\test_update_e2e.ps1 -ReleaseDirectory 'F:\交付\版本目录' -OutputDirectory 'F:\验收\新隔离目录' -GodotBinary 'Godot控制台程序.exe' -PythonBinary 'python.exe'
```

端到端测试仅在隔离测试驱动中注入 localhost HTTP，生产客户端仍严格选择指定仓库的 HTTPS 附件。测试将旧版小型探针升级到完整正式游戏，覆盖实际下载、交接、文件替换、主菜单健康确认及存档/设置字节保护。单元测试另外覆盖异常 ZIP、校验错误、文件占用、替换失败、事务中断与启动失败回滚。界面检查脚本为 `update_visual_review.gd`。

接口参考：[GitHub Releases API](https://docs.github.com/en/rest/releases/releases)、[GitHub 附件 digest](https://github.blog/changelog/2025-06-03-releases-now-expose-digests-for-release-assets/)、[Godot HTTPRequest](https://docs.godotengine.org/en/stable/classes/class_httprequest.html)。
