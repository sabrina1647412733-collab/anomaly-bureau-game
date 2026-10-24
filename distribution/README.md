# Windows发行工具

当前已公开游戏：**v0.6.1**，下载见 [GitHub Releases](https://github.com/sabrina1647412733-collab/anomaly-bureau-game/releases/latest)。可用交付是完整免安装ZIP；Setup初始化故障尚未解决。现有更新下载完整包，固定基础包＋分组补丁仍是待实现方案。

## 工具与入口

| 文件 | 用途 |
| --- | --- |
| `build_update.ps1` | 生成固定启动器、完整Windows文件夹、免安装ZIP、专用更新ZIP及SHA256 |
| `build_portable.ps1` | 复用同一套构建流程的便携入口 |
| `build_windows.ps1`、`windows_installer.iss` | 编译安装器；编译成功不等于安装验收通过 |
| `publish_release.ps1` | 用已有开发者GitHub登录发布草稿、核对附件、正式公开 |
| `updater/` | 固定启动器、更新器及相关验证源码 |
| `test_*.ps1` | 安装/更新验证；使用F盘独立数据，不能操作玩家实际安装 |
| `RELEASE-*.md` | 各版本当时发布说明；旧版留档 |
| `开始游玩说明.txt` | 随Windows包提供的操作说明 |

完整协议、失败恢复与发布参数见 [AUTO_UPDATE.md](AUTO_UPDATE.md)。引擎及字体许可、简体中文安装器语言文件均为构建依赖，不删除。

## 构建

Godot **4.7.2 stable**及同版Windows x64导出模板；固定启动器使用Windows .NET Framework 4.x编译器；只有Setup构建额外需要Inno Setup 6。

```powershell
.\distributionuild_update.ps1 -GodotBinary '你的Godot控制台程序.exe' -OutputDirectory 'F:\交付\新版本'
```

发布前协调版本号、项目预设和Release标签，输出全部放F盘。源代码与运行资源进入Git；EXE/PCK/ZIP/Setup作为Release附件。只暂存本项文件，禁止把玩家数据、测试目录、缓存和凭据打包。已经公开的v0.6.1附件不可覆盖。

## 玩家文件

完整保留 `AnomalyBureau.exe`、`AnomalyBureau.Game.exe`、`AnomalyBureau.Game.pck`。始终从固定启动器启动；`_玩家数据/`保留存档与设置，`_更新缓存/`用于校验、备份和故障恢复。文件夹解压本身不会自动创建桌面快捷方式，安装器和图标接入仍待对应任务完成。
