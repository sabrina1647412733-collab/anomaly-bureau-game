# Windows 发行构建

玩家下载 GitHub Release 的安装包或免安装 ZIP，不需要 Godot。阅读同目录《开始游玩说明.txt》。安装包与大文件仅作为 Release 附件，不加入 Git 历史。

开发者使用 Godot **4.7.2 stable**、同版本 Windows x86_64 release 导出模板和 Inno Setup 6 编译：

```powershell
.\distribution\build_windows.ps1 -GodotBinary '你的Godot控制台程序.exe' -InnoCompiler '你的ISCC.exe'
```

输出在 `build/release/`：安装包、免安装 ZIP、游玩说明与 SHA256 校验文件。`export_presets.cfg` 的 Windows Desktop 预设保留在工程里。运行资产使用 `res://`，存档写 `user://`。程序默认使用 Forward+，兼容模式启动脚本切到 OpenGL。

安装到当前用户目录，无需管理员权限；卸载程序不删除玩家 AppData 存档。安装与免安装版共享同一份存档。升级沿用固定 AppId 与安装目录。Windows 安装包目前未做商业代码签名。

引擎版权与字体许可证随包提供。`ChineseSimplified.isl` 来自 [Inno Setup 官方源仓库](https://github.com/jrsoftware/issrc/blob/main/Files/Languages/ChineseSimplified.isl)，用于编译中文向导；保留文件内译者说明。Godot LICENSE / COPYRIGHT 来自 4.7.2-stable 官方源代码，字体许可证沿用工程内 Noto Sans SC 的原文件。

发行前先导入，跑三夜主线、引导和交互/脱困/自动存档测试，再验证导出的程序启动、安装和卸载。跨电脑的显卡、驱动与性能仍需真实设备验证。
