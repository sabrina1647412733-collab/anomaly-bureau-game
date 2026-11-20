# 诡异事务局 Windows发行工具

**发行版本：v0.8.0**。本目录记录 Windows 构建、安装器和更新系统的源码及操作说明，不在 README 中提供游戏下载链接。

## 当前推荐流程：只上传变化内容

日常使用build_patch.ps1：复用上一份完整清单中的资源来源，默认只生成新清单、一个变化资源容器和校验文件；完全没有资源变化时只有清单和校验文件。工具自动创建“上传这些”文件夹，窗口中全选该文件夹内文件即可，不上传Windows运行目录、导出ZIP或缓存。真实UI/模型样板总上传分别965,643/1,470,193字节，包含清单和校验文件。

首次启用、或定期合并远端资源时，使用build_grouped.ps1生成新基础版本；不指定PreviousManifest即为新基础，默认也不额外生成完整免安装ZIP。完整安装器通过build_installer.ps1单独生成；build_windows.ps1集成构建并刷新发布清单。需要完整免安装ZIP时对build_grouped显式传-CompletePackage。每日补丁不需要再次生成Setup、免安装ZIP和旧版迁移ZIP。

v0.7.0及更早客户端的旧启动器不能识别跨版本来源，需要一次完整Setup覆盖原目录以替换启动器，存档和设置保留。此路径已用完整0.7.0目录实测到0.8.0并进入真实主菜单。之后才能使用新的小补丁发布流程。新玩家可以安装完整基础包，再一次更新到最新，无需逐个安装历史补丁。

正式v0.8.0已从完整最新源码重建，直接复用GitHub现有v0.7.0六个资源容器，仅新增完整Setup、404,220字节补丁、完整清单和校验，共四附件781,053,507字节。此前“首次基础约1.45GB”的九附件方案是专项测试样板，不是此次实际上传。`AnomalyBureau-0.8.0-local`为旧专项快照，正式产物在`AnomalyBureau-0.8.0-release`。

具体命令及手动上传见[增量发布操作说明](增量发布_操作说明.md)，实测见[减少发布上传验收](../docs/verification/20261025/减少发布上传验收.md)。

## 工具

| 文件 | 用途 |
| --- | --- |
| build_patch.ps1、delta_transport.py、prepare_upload.ps1 | 日常增量发布、跨版本资源来源、仅包含必要附件的上传文件夹 |
| build_grouped.ps1、build_groups.py | 真实Windows资源导出、六组资源、自动清单和完整免安装ZIP |
| build_windows.ps1、windows_installer.iss | 使用同一Windows运行目录生成Setup |
| build_bridge.ps1 | v0.6.x旧启动器的一次性完整迁移包 |
| layout_manifest.py、package_portable.py | 只打包明确安装清单，排除玩家数据、缓存与测试文件 |
| publish_release.ps1 | 草稿上传、附件digest核对及显式公开；2026-10-25已创建草稿，上传中途移交用户，未使用-Publish |
| updater/、bootstrap/ | 固定启动器、工作进程、引导加载与旧版迁移源码 |
| test_*.ps1、test_grouped_e2e.py | 单测、安装、真实资源与旧客户端迁移验收 |
| build_update.ps1、build_portable.ps1 | 旧协议完整包工具，留作兼容回归；新内容版使用build_grouped |

## 构建

依赖Godot **4.7.2 stable**及同版Windows x64导出模板、Windows .NET Framework 4.x编译器、Python 3.11+与Pillow（图标格式转换）。Setup另需Inno Setup 6。图标沿用项目已有参考图，转换为16至256像素ICO，嵌入固定启动器、Setup及快捷方式。

```powershell
.\distribution\build_grouped.ps1 -GodotBinary 'Godot控制台程序.exe' -PythonBinary 'python.exe' -Version '0.7.0' -OutputDirectory 'F:\交付\AnomalyBureau-0.7.0'
# 后续内容版必须复用首次构建的基础文件：
# 增加 -BaselineRuntime 'F:\交付\AnomalyBureau-0.7.0\Windows'
.\distribution\build_windows.ps1 -GodotBinary 'Godot控制台程序.exe' -PythonBinary 'python.exe' -InnoCompiler 'ISCC.exe' -Version '0.7.0' -OutputDirectory 'F:\交付\AnomalyBureau-0.7.0' -SkipExport
.\distribution\build_bridge.ps1 -GodotBinary 'Godot控制台程序.exe' -PythonBinary 'python.exe' -ReleaseDirectory 'F:\交付\AnomalyBureau-0.7.0'
```

版本参数写入清单，引导器挂载后设置版本，无需修改其他会话占用的project.godot或导出预设。更换基础引擎、引导PCK或固定启动器协议时应走完整迁移。所有输出放F盘并使用新目录，禁止覆盖已有清单的验收产物。正式v0.8.0已获用户授权并公开；未来新版本仍按对应用户授权发布。源码进Git，EXE/PCK/ZIP/Setup和测试数据不进Git。

## 玩家文件

完整保留AnomalyBureau.exe、两个AnomalyBureau.Game文件及_运行文件目录。始终从固定启动器进入；_玩家数据保留存档和设置，_更新缓存用于下载、备份和恢复。

安装器可选择位置，建议F盘并显示所需空间；默认创建桌面快捷方式。升级选原目录。卸载入口是安装目录内「卸载诡异事务局」或unins000.exe，默认保留玩家数据。为避免受限HKCU导致整包回滚，不依赖Windows“已安装应用”登记，也不写开始菜单；桌面不可写时明确提示并保留目录内快捷方式。免安装ZIP解压本身不会创建桌面快捷方式。

协议、失败恢复、资源分组及验收命令见[AUTO_UPDATE.md](AUTO_UPDATE.md)。

## 2026-10-25 默认TEMP启动修复

用户双击旧Setup时，在C盘TEMP创建is-*.tmp目录即错误5。此前测试固定F盘TEMP，未覆盖此启动条件；原0.7.0安装器不能再作为该问题已解决的证据。修正版在F:\诡异事务局\交付\AnomalyBureau-0.7.0-installer-tempfix，仍安装已验收0.7.0运行文件，不含其他会话尚未提交的UI/存档改动。

build_windows现在通过build_installer.ps1构建独立临时目录引导层，内嵌Inno负载并校验SHA256，先选择可写目录再启动Inno。优先F盘缓存，其次安装包旁可写缓存，最后可写的系统临时目录；只修改子进程环境，不改注册表或系统TEMP。卸载请使用安装目录内“卸载诡异事务局”快捷方式，它同样选择可写TEMP并先脱离安装目录，避免锁住自己的EXE。诊断日志保留在选定缓存内，嵌入的完整安装负载执行后删除。

仅重建安装器、无需运行Godot：

```powershell
.\distribution\build_installer.ps1 -RuntimeDirectory 'F:\诡异事务局\交付\AnomalyBureau-0.7.0-local-final\Windows' -OutputDirectory 'F:\交付\新的安装器目录' -InnoCompiler 'ISCC.exe' -Version '0.7.0'
```

输出目录不得已有同名安装包，避免覆盖已交付文件。新验收见[安装器临时目录修复](../docs/verification/20261025/安装器临时目录修复.md)。本次未上传或替换任何Release附件。
