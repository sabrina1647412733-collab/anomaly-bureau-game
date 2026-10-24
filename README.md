# 诡异事务局 · 回潮

Godot 4.7.2 的第一人称叙事恐怖游戏。所有开发继续在此工程进行。

**下载游戏：[最新 Windows 正式版](https://github.com/sabrina1647412733-collab/anomaly-bureau-game/releases/latest)**

目前正式版为 **v0.6.1 免安装版**。下载 `AnomalyBureau-Windows-0.6.1.zip`，完整解压后双击 `AnomalyBureau.exe`；无需安装Godot，三个EXE/PCK文件须一起保留。安装器仍有初始化故障；当前自动更新下载完整包，分组补丁尚未实现。

## 开发入口

使用 Godot **4.7.2 stable** 导入根目录 `project.godot`，等待资源导入后按F5。主场景为 `scenes/main.tscn`。

- `启动游戏.bat`：通过本机Godot运行源码。
- `打开Godot工程.bat`：打开现有工程编辑器。
- `开发者巡查.bat`：打开带登录的巡查入口。

启动脚本从PATH寻找Godot，支持设置 `GODOT_EXE`。作者本机主工程在F盘，其他电脑克隆后直接导入工程即可；运行不依赖作者本机的角色来源目录或Blender。

## 目录

| 目录 | 内容 |
| --- | --- |
| `scenes/`、`scripts/`、`shaders/` | 游戏场景、逻辑与着色器 |
| `assets/` | 随游戏运行的模型、贴图、字体、声音及各自许可 |
| `source_art/` | 可编辑美术源、构建来源和参考图；Godot不导入此目录 |
| `剧本/` | 最新唯一结局剧本；旧稿在其`历史稿/`中 |
| `distribution/` | Windows构建、更新器、安装器源码与发行说明 |
| `docs/player/` | 启动、操作、巡查和路线说明 |
| `docs/development/` | 当前进度、任务分工和多会话交接 |
| `docs/verification/` | 按日期归档的验收报告 |
| `docs/history/` | 已过时的交付与计划，仅供追溯 |

EXE、PCK、安装包、ZIP作为GitHub Releases附件发布，不加入源码库。缓存、玩家存档、测试数据和本机工具不提交。原始美术和运行资产保留独立用途，不因文件名相似就删除。

## 当前状态与接手

第一案三夜及唯一结局已实现；第二案已接入流程和首轮空间，但美术、语音和最终人工验收仍有缺口。玩家反馈的第二夜存档、楼梯穿模、引导和等待等问题仍待修复，不能以既往自动测试通过代替复现和处理。

- [当前进度与准确限制](docs/development/STATUS.md)
- [多会话接手与分工](docs/development/SESSION_HANDOFF.md)
- [19项改进任务表](docs/development/TASKS.md)
- [文档导航](docs/README.md)
- [操作与路线](docs/player/第一案三夜_操作与验收.md)
- [开发者巡查](docs/player/开发者巡查使用说明.md)
- [发行与构建](distribution/README.md)

桌面存档在工程或游戏旁的 `_玩家数据/`，升级和迁移时保留；开发巡查使用 `_开发者数据/`。两者均不进入Git。开始修改前先读 [AGENTS.md](AGENTS.md)，以用户最新授权和当前任务表为准。
