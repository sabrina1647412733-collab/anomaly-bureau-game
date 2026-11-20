# Windows安装器完整性与交付

2026-10-31查明：本机旧工作目录F:\诡异事务局带有可继承的Low强制完整性标签。编译生成EXE时会继承该标签；Windows启动它时将进程限制到Low，即使当前账户有普通目录的Modify权限，仍不能向默认Medium目录写入。不要通过放宽玩家目录权限或关闭防护解决它。

构建目录的标签与EXE字节不同；两个SHA256相同的文件可能有不同的NTFS完整性标签。仅验证哈希或只在Low工作目录测试不能证明交付可用。Windows机制见[微软Mandatory Integrity Control文档](https://learn.microsoft.com/en-us/windows/win32/secauthz/mandatory-integrity-control)。

## 构建

`build_installer.ps1`与`build_windows.ps1`会检查构建进程和输出父目录；Low输出在压缩前拒绝，并检查新生成外层EXE、内层Setup和卸载入口。构建输出指定为普通F盘新目录，例如用户自行选择的发行目录；不自动修改目录ACL或标签。游戏开发工作目录可以保留原状。

既有EXE需要导出时，使用`export_installer.ps1 -Installer <原文件> -OutputDirectory <普通F盘新目录>`。脚本以CreateNew写入全新文件，只传输内容字节，不移动或复制NTFS安全元数据，最后验证SHA256和文件完整性级别，生成SHA256SUMS.txt与delivery-check.json。输出目录必须全新，父目录和执行进程须至少Medium；检查失败停止，不自动放宽权限。

## 验收

从最终交付目录实际执行安装器，安装到普通目录，检查外层/内层/安装后运行文件的完整性级别。使用同一目标下的Low/Medium版本对照可以定位此问题。不可仅看PowerShell本身或DACL；文件Mandatory Label存于SACL，普通Get-Acl输出不一定包含它。`installer/IntegrityProbe.cs`提供原生只读查询，无标签按Windows规则视为Medium。

完整验证新安装、已有版本覆盖、保留存档/设置、卸载、重装、快捷方式和实际主菜单。验收工具自身也必须正常运行，不能从Low EXE启动整个测试进程树再把它作为普通玩家环境。所有本机验证使用F盘私有桌面与Dummy音频，存档隔离。

## 玩家电脑

默认位置优先F盘可写目录、安装包旁的非系统盘位置及其他固定数据盘；没有这些位置时，显示当前用户Programs目录供玩家确认。目录页可修改位置，安装前仍在实际Setup进程下试写。游戏不依赖F盘、作者模型源目录或Godot编辑器。作者本机所有安装和测试仍明确选择F盘；不能把开发机的盘符偏好强加为所有玩家的必备条件。

公开Release上传/下载与跨电脑验收单独记录；本地修复完成不等于已上传，单机测试也不等于覆盖所有Windows配置。
