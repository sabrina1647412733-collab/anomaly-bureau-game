# Windows 发行构建

**当前自动更新版为 v0.6.0。** 新的构建、安装、GitHub 发布与回滚流程见 [AUTO_UPDATE.md](AUTO_UPDATE.md)。`build_update.ps1` 生成带固定启动器的完整文件夹、便携 ZIP 和专用更新 ZIP；`build_windows.ps1` 再生成首次安装程序。下面的历史 v0.4.0 说明仅保留供追溯，当前以新文档为准。

2026-10-23构建脚本版本为v0.4.0。仅要完整可玩文件夹时使用下面命令，不生成ZIP或安装程序：

```powershell
.\distribution\build_portable.ps1 -GodotBinary '你的Godot控制台程序.exe' -OutputDirectory 'F:\交付\得利洗衣店_v0.4.0_Windows'
```

双击输出目录中的AnomalyBureau.exe，exe与pck必须一起分发。下面的完整发行流程用于明确需要安装包与ZIP的重大更新；当前本地试玩文件夹不代表已经创建GitHub Release。

玩家下载 GitHub Release 的安装包或免安装 ZIP，不需要 Godot。阅读同目录《开始游玩说明.txt》。安装包与大文件仅作为 Release 附件，不加入 Git 历史。

开发者使用 Godot **4.7.2 stable**、同版本 Windows x86_64 release 导出模板和 Inno Setup 6 编译：

```powershell
.\distribution\build_windows.ps1 -GodotBinary '你的Godot控制台程序.exe' -InnoCompiler '你的ISCC.exe'
```

输出在 `build/release/`：安装包、免安装 ZIP、游玩说明与 SHA256 校验文件。`export_presets.cfg` 的 Windows Desktop 预设保留在工程里。运行资产使用 `res://`，桌面存档写exe旁「_玩家数据」，Web使用user://。程序默认使用 Forward+，兼容模式启动脚本切到 OpenGL。

安装到当前用户目录，无需管理员权限；卸载程序不主动删除未登记的「_玩家数据」。安装与免安装版各自保存在所在目录，可手工复制该文件夹转移进度。升级沿用固定 AppId 与安装目录。Windows 安装包目前未做商业代码签名。

引擎版权与字体许可证随包提供。`ChineseSimplified.isl` 来自 [Inno Setup 官方源仓库](https://github.com/jrsoftware/issrc/blob/main/Files/Languages/ChineseSimplified.isl)，用于编译中文向导；保留文件内译者说明。Godot LICENSE / COPYRIGHT 来自 4.7.2-stable 官方源代码，字体许可证沿用工程内 Noto Sans SC 的原文件。

发行前先导入，跑三夜主线、引导和交互/脱困/自动存档测试，再验证导出的程序启动、安装和卸载。跨电脑的显卡、驱动与性能仍需真实设备验证。

当前脚本构建v0.4.0。声音署名与CC许可证同时复制到免安装包和安装目录；游戏内从主菜单「声音与素材鸣谢」读取相同内容。新增声音资源说明在assets/audio/polish/SOURCES.md，已有音频来源在assets/audio/finish/SOURCES.md。
