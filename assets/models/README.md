# 序章出租屋 · 外部模型

本目录模型用于 `scripts/pro_room_art.gd` 的出租屋 Hero 场景，全部来自 **Poly Haven**（https://polyhaven.com/models），授权为 **CC0 1.0**（可商用、可修改、无需署名；此文件仅作来源记录）。

当前使用：

- `old_bed_frame`（2k PBR）
- `ClassicNightstand_01`
- `desk_lamp_arm_01`
- `alarm_clock_01`
- `book_encyclopedia_set_01`
- `wooden_table_02`
- `painted_wooden_chair_01`
- `binder_notebook`
- `painted_wooden_cabinet`
- `Television_01`
- `wooden_bookshelf_worn`
- `cardboard_box_01`
- `potted_plant_01`
- `vintage_telephone_wall_clock`

未使用的候选资产已在 2026-10-18 清理，避免把 40 MB 无关模型带进仓库。

---

## 洗衣店场景道具（`assets/models/props/`）

第一案「得利洗衣店」4F / 5F / 屋顶 / B1 与 2F 家具用的资产都在 `props/` 下，
明细见 **`props/README.md`**。要点：

- **Poly Haven CC0 17 件**：收音机、壁钟、工业管路、铁架、工具柜、配电箱、灯具、旧柜、木箱等
- **本工程自建 4 件**（`_setup/blender_washer.py` / `blender_furniture.py`，Blender 4.5.14）：
  `washer_01` 3420 面（滚筒独立 440 面）、`counter_01` 1392、`bench_01` 1864、`bin_01` 792
- 两个必须记住的 Blender 坑：boolean 后法线会内翻、`create_cube(size=1.0)` 的 size 是边长不是半边长
