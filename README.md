# 岚桥站 0017 · Godot 3D 版

《最后一班地铁：0017》的**表现层**（三层原型架构里最外层）。这不是界面原型，是可运行的 3D 实机版本；
交互层是 `deploy/v6-人话版.html`（单文件 2D 原型），交付层是界面设计稿。

## 怎么跑

- 引擎：**Godot 4.7.2 stable**（`Godot_v4.7.2-stable_win64.exe`）
- 工程入口：本目录的 `project.godot`（编辑器里「导入」后打开）
- 懒人方式：双击工作区根目录的 `启动岚桥站0017-游戏.bat`
- 主场景 `res://scenes/main.tscn`，窗口 1600×900，桌面用 Forward+ 渲染器

## 操作

`W/A/S/D` 移动 · 鼠标转向 · `E` 交互/推进对话 · `Tab` 背包 · `1`–`5` 切物品栏 · `Esc` 菜单 · `空格` 跳

## 玩法要点（与需求文档口径一致）

- 时间窗 **23:50 → 00:17**，`SEC_PER_MIN = 6`（现实 1 秒 ≈ 游戏 10 秒）
- **序章 + 四轮循环**，重置时只保留标记为「跨轮保留」的线索
- **5 件线索**：红灯延迟记录 / 倒放广播 / 停用钥匙 / 巡检簿 / 五号继电器
- 每个动作都有时间代价：合闸 −45s、推手柄 −60s、扳道岔 −35s
- 关键判定：手柄推到底时若已晚于 `T_LOCK`（00:16:43）或线索不足 → **结局 B**；
  正常锁进路则进二选一（`[E]` 公开真相 / `[R]` 封存）
- 三个 NPC 按轮次登场：林岚（序章）、周砚（第 1 轮）、陈默（第 2 轮）
- 三个存档槽：`user://save_1.json` ~ `save_3.json`

## 目录

| 路径 | 内容 |
|---|---|
| `scenes/` | `main.tscn` 主场景、`poster.tscn` 海报场景 |
| `scripts/` | 玩法脚本 11 个（约 3664 行），`scripts/tests/` 是开发期测试脚本 35 个 |
| `shaders/` | `surface.gdshader` |
| `assets/` | 主菜单海报贴图——**唯一的外部贴图**，其余几何、图标、物品、音频全部由代码生成 |
| `_预览/` | 31 张开发过程预览图（本地留档，未纳入版本控制） |
| `_shot/` | 渲染中间产物约 297 MB（未纳入版本控制，可随时删） |
| `_tools/` | ffmpeg / cloudflared / 导出模板包（未纳入版本控制） |

## 导出 Web 版（重要，别踩这个坑）

Web 导出**必须**走 Compatibility（GLES3）渲染器。`project.godot` 里已写入这三行，**删掉会导致导出的网页版打不开**：

```ini
[rendering]
renderer/rendering_method.web="gl_compatibility"
```

导出模板已装在 `%APPDATA%\Godot\export_templates\4.7.2.stable`（含 `web_nothreads_release.zip`）。导出命令：

```powershell
$G = "C:\Users\Sabrina\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe"
& $G --headless --path "C:\Users\Sabrina\Documents\ChatGPT\最后的地铁：0017\岚桥站0017-Godot" `
     --export-release "Web" "C:\Users\Sabrina\Documents\ChatGPT\最后的地铁：0017\deploy\game\index.html"
```

产物是 `deploy\game\` 下的 `index.html / index.js / index.wasm / index.pck`，再由工作区根目录打包成 `0017-网页版.zip`。

## 录屏

工作区根目录 `录制-岚桥站0017.bat`（Godot 内部逐帧录制 → 自动用 `_tools\ffmpeg.exe` 转 mp4），
输出到 `_record\`。细节见工作区根目录 `Godot录制说明.md`。
## 已验证（2026-10-16）

- **桌面端**：`Godot_v4.7.2-stable_win64.exe --headless --path . --quit-after 90` → 退出码 0、耗时 2.1s，无脚本报错（仅一条无害的 ObjectDB 泄漏警告）。
- **Web 端**：本机静态服务 + Edge headless（SwiftShader）打开 `deploy/game/`，引擎启动日志：

  ```
  Godot Engine v4.7.2.stable.official - https://godotengine.org
  OpenGL API OpenGL ES 3.0 (WebGL 2.0) - Compatibility - Using Device: WebKit - WebKit WebGL
  Build configuration: Emscripten 4.0.20, single-threaded, no GDExtension support.
  [0017] 可坐的位置 9 个 / 背包就绪
  [站内广播] 23:50。岚桥站最后一班车即将进站。……你接管夜班调度席。0017 次，进二道。
  [0017] 就绪 · 三角 8600 · 碰撞 119 · 灯 47
  ```

  即：**渲染器确实是 Compatibility**，场景（8600 三角面 / 119 个碰撞体 / 47 盏灯）构建完成，序章正常播放。
  日志里唯一的报错是 `A user gesture is required to request Pointer Lock` —— 无头浏览器没有点击，属正常现象；
  真人打开时点一下画面即可（导出壳里 `focusCanvas: true`）。
- **托管环境**：上面这轮验证跑在没有任何 COOP/COEP 头的普通静态服务上，说明单线程版可以直接丢到任意静态托管。
