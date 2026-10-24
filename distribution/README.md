# 诡异事务局 Windows发行工具

当前公开正式版仍为 **v0.6.1**：[GitHub Releases](https://github.com/sabrina1647412733-collab/anomaly-bureau-game/releases/latest)。**v0.7.0为本地安装更新体验版**；2026-10-25创建GitHub草稿Release，附件上传已移交用户，移交时没有已完成附件。未公开v0.7.0，未替换v0.6.1附件。游戏、安装器、快捷方式统一称「诡异事务局」，英文下载文件前缀为AnomalyBureau。

## 工具

| 文件 | 用途 |
| --- | --- |
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

版本参数写入清单，引导器挂载后设置版本，无需修改其他会话占用的project.godot或导出预设。更换基础引擎、引导PCK或固定启动器协议时应走完整迁移。所有输出放F盘。发布仍须单独授权；当前只交付本地版本。源码进Git，EXE/PCK/ZIP/Setup和测试数据不进Git。

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
