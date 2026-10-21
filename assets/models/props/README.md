# 得利洗衣店 · 场景道具模型（assets/models/props/）

本目录是第一案「得利洗衣店」4F / 5F / 屋顶 / B1 与 2F 家具用的外部资产。
每个子目录带一个 `SOURCE.json` 记录来源、授权与面数。

## Poly Haven（CC0 1.0）

| 目录 | 用在哪 |
|---|---|
| `vintage_radio_transceiver` | 402 老周家：那台「只在播 2004 年节目」的收音机 |
| `wall_clock` | 402 墙上 |
| `modular_industrial_pipes_01` / `modular_pipes` | B1 锅炉房的管线 |
| `steel_frame_shelves_01` | 402 水表墙旁的铁架 |
| `metal_tool_chest` | 402 工具台 / B1 工作台 |
| `utility_box_01` | 4F 电表箱 |
| `industrial_wall_lamp` / `mounted_fluorescent_lights` | 走廊与地下室灯具 |
| `pull_chain_light_socket` / `caged_hanging_light` / `hanging_industrial_lamp` | 吊灯（B1、5F） |
| `vintage_wooden_drawer_01` / `vintage_cabinet_01` | 403 杂物间旧家具 |
| `wooden_crate_01` | 403 / 402 |
| `plastic_monobloc_chair_01` | 4F 走廊那辆不要的椅子 |
| `metal_stool_01` | 403 缝纫机旁的凳 |

## 本工程自建（CC0，脚本可复现）

| 目录 | 面数 | 生成脚本 | 说明 |
|---|---|---|---|
| `washer_01`（含 `washer_01_drum`） | 3420 / 440 | `_setup/blender_washer.py` | 老式波轮洗衣机：倒角机身 + boolean 圆洞 + torus 门圈 + 碗状凹玻璃 + 斜控制面板。滚筒单独导出供旋转 |
| `counter_01` | 1392 | `_setup/blender_furniture.py` | 2F 柜台：台面 + 三扇嵌板柜门 + 踢脚 + 四角防撞条 |
| `bench_01` | 1864 | 同上 | 2F 三座长椅：蓝色硬塑料座 + 后倾靠背 + 钢架 |
| `bin_01` | 792 | 同上 | 2F 铁皮垃圾桶：歪盖 + 露出的布头 + 两道箍 |

> 三个 Blender 脚本都用 `--background` 跑，产物先出到 `_blout/`，确认能加载再 `cp` 进本目录。
> 两个必须记住的坑：① boolean 之后要 `normals_make_consistent(inside=False)`，否则导出到 Godot 后
> 整个外壳被背面剔除；② `bmesh.ops.create_cube(size=1.0)` 的 `size` 是**边长**，按半尺寸传会小一半。
