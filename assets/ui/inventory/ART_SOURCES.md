# 随身物品界面美术来源

运行时只读取本目录的静态PNG，无额外3D预览场景、网络请求或本机路径依赖。四类筛选和说明文字由Godot Control节点实现，参考图没有作为整张背景贴进游戏。

- `sweater.png`、`shoe.png`：从工程现有 `assets/models/case1_props/sweater.glb`、`shoe.glb` 渲染，不覆盖原模型或材质。
- 手机、信封、座钟、五类钥匙、纸件/管线图/证件：本轮原创程序模型和纸张纹理。生成工具为 `scripts/tools/build_inventory_textures.py`、`scripts/tools/render_inventory_art.gd`；文字使用已有NotoSansSC字体，原字体许可保留在 `assets/fonts/`。
- `materials/family_photo_v1.png`：使用内置image_gen工具新生成的虚构家庭照片纹理；没有采用网络照片或真实人物参考。父亲与孩子的照片脸部刮损遵守现有剧本，照片上的年份为2004，没有新增死亡结论。`photo.png`为该纹理的道具渲染图。
- `materials/`保留可重新渲染的来源材质。纸件仅按文书类型呈现；其准确名字和全文仍由已有游戏数据提供，避免把缩略图上的通用纹理当成新线索。
- 右侧是静态物品展示，没有旋转/翻面新玩法。原衣交还后只保留记录，记录归线索，不能通过分类重新获得原衣。

## 重新生成

```powershell
python scripts/tools/build_inventory_textures.py
godot --headless --path . --import
godot --path . --rendering-method gl_compatibility --script res://scripts/tools/render_inventory_art.gd -- --verify
godot --headless --path . --import
```

保留已提交的 `family_photo_v1.png`；纹理生成脚本不会覆盖它。新渲染后要检查透明背景、正面图层、字体边界及物品是否完整。

## 家庭照片最终生成提示词

模式：内置image_gen / 新图生成 / 非透明照片纹理。

> Use case: stylized-concept / game prop texture. Generate ONE original realistic old Chinese family photograph as a flat front-facing rectangular image asset for a fictional 3D investigation horror game. This will be the texture of a physical paper photograph and an inventory item, NOT a UI mockup. Whole image ratio around 6:5 landscape, the paper photograph fills the full image from edge to edge, NO exterior tabletop, no scene outside the paper, NO angled view, NO frame, no UI, no captions or watermarks. An aged ivory paper border about 4% thick surrounds a faded desaturated warm gray/olive/sepia film photograph of a Chinese family of EXACTLY THREE people: adult father on left in worn plain dark work jacket, adult mother about 40 on right with period-appropriate dark short hair and a modest cardigan, a six-year-old BOY in the center foreground wearing a plain navy knit sweater. Simple 1990s/early 2000s Chinese small-town portrait atmosphere, old domestic wall and curtain faintly behind them, gentle window lighting, printed analogue photograph with subdued realistic film grain and minor scuffs, faces and details softened by age. The mother remains faint and low-detail, a distant unposed natural expression, NO striking celebrity resemblance. Crucial narrative detail: the boy's face has been heavily scratched away from the PHOTO PAPER, leaving visible light cream paper fibers and irregular scrape lines; the father's face is also damaged and mostly obscured by scratched paper. This is damage to a photograph's emulsion, not physical injury, no blood, no wounds or gore. Still clearly readable as a family portrait of two parents and their boy. The rest of clothing and bodies must retain photographic realism and fabric detail, no blank vector shapes or cartoon silhouettes. Lower paper margin slightly wider with a small faint handwritten '2004' only. Do not add names, other dates, hospital imagery, death symbols, ghost faces, extra people, readable signage, decorative stamps, or supernatural effects. Natural restrained melancholy, not a horror poster. Photorealism, convincing physical paper texture, professional game evidence prop asset.
