# 主街目标设计生成提示词

工具：内置image_gen；输入：`01_before_godot.png`（当前Godot实机，原样复制）。输出：`02_target_concept.png`（设计参考，非游戏实机）。初稿复核后增加一次门洞宽度定向修正；初稿仅在F盘验收目录保留，工程保存最终参考图。

```text
Use case: precise-object-edit.
Asset type: location-locked environment art paintover for an existing first-person narrative horror game. Produce ONE finished landscape 16:9 scene, not a comparison sheet.
Input image 1 is the EXACT edit target: the current Godot player-camera screenshot of Huichao old-town street in mainland China. Improve the environment design while preserving its recognizable camera and spatial layout.
Hard spatial invariants: match the original eye-level camera, perspective, street curve and vanishing point, road width, building footprints, relative heights, openings, side-lane entrances, and position of the green shop sign in the middle-left. The middle-left shop must still read exactly “电料”. Do not add a 得利洗衣店 sign: that landmark is BEHIND this camera. Do not add or relocate major buildings. Keep the central travel corridor and door approaches free. No people, characters, hands, monsters or new narrative events.
Remove the screenshot's HUD, minimap, crosshair and hotkey overlays, rebuilding the covered environmental areas consistently. Add only a small discreet lower-right caption reading exactly “目标设计参考 · 非实机”.
Primary request: design a believable, dense, lived-in Chinese county-town old street, with materially convincing, unified environmental detail. Preserve the existing neighborhood, greatly improve its craft. Realistic weathered small-town architecture with a restrained grounded horror-game mood; not Hong Kong, no cyberpunk, no fantasy, no European architecture, no neon spectacle.
Maintain diffuse OVERCAST DAYTIME, similar visibility and shadows to the source, so surface improvements can be compared honestly. No night conversion, dramatic sunset, heavy fog, depth of field, bloom, heavy grain or exaggerated film grading.
Foreground left: retain the iron-barred windows and wall silhouette; use distinct fine plaster, repaired render patches, worn brick base, believable junctions, thin galvanized downpipe, a few weeds growing from real cracks. Avoid repetitive all-over dirt.
Middle-left “电料” shop: retain its brick facade, green sign and existing shallow doorway. Give its 1.6m opening a roughly 1.65m shallow interior with a wooden counter and shelves; small coiled electrical cable, bulb cartons and old divided drawers belong against the walls or inside, not in the road. A warm practical lamp is subtle in daylight. Do not turn it into a deep new interior or a restaurant.
Foreground right: retain the closed timber door and adjacent home, improve worn wood joinery, repaired lower wall and threshold; place a small old woven chair and enamel washbasin to the side of the entrance, leaving a visibly clear doorway. Further right-side houses receive different useful details such as a rolled fabric awning, small air conditioner or galvanized gutter, rather than repeating the same kit on every facade.
Low annexes should look attached to an inhabited block, with short corrugated eaves, proper flashing, pipes, stacked old roof tiles at one wall, variations in brick and lime render. Roof supports meet walls; no floating balconies, no windows projecting beyond corners.
Road: realistically scaled patched grey asphalt, broken edges and subtle aggregate; narrow imperfect concrete drainage strips, a few localized shallow damp patches beside the existing right-foreground grate and drainpipe exits. The road center remains mostly matte and walkable; no mirror-like flooded road, excessive rubbish or giant puddles. Retain safe lane access.
Overhead: keep existing utility pole anchors, add plausible loose bundled service wires with controlled sag, wall ceramic insulators and meter connections. Sparse functional wiring, not a random tangled ceiling; clear headroom. Use layered eaves, small roofline variations and facade-specific silhouettes to create density.
Quality: coherent photorealistic environment concept with credible real-world scale, PBR material behavior, nonuniform edge wear, subtle contact shadows and readable details. Everything should form one consistent scene. Do not add arbitrary signage, red lanterns, vehicles in the road, modern luxury storefronts, or decorative clutter everywhere. Buildings and route remain those of the input image.
```

## 门洞宽度定向修正

输入1为初稿、输入2为原Godot截图；只收窄电料店开口，保留整体环境设计。

```text
Use case: precise-object-edit. Produce one landscape scene.
Image 1 is the edit target, an environment concept paintover. Image 2 is ONLY the original Godot geometry reference for the brick “电料” shop at middle left.
Make ONE precise correction to image 1: its electrical-supplies shop ground-floor opening is much too wide. Restore a NARROW CENTRAL doorway, about ONE THIRD of that brick building facade's total width (1.6m clear opening in a 5.2m facade); the original doorway is shallow, 1.65m deep. Restore substantial brick wall piers on BOTH sides of that doorway. No wide open bay, no full-width shop. Arrange a small wooden counter and a few shelves strictly INSIDE this narrow opening. If cable coils are added, they hang against one masonry pier rather than extending the opening. Preserve the green sign at the same position, with the exact text “电料”.
Keep everything else in image 1 unchanged: exact overall camera, road curve and width, building masses and heights, overcast daylight, rich plaster and brick materials, wiring, downpipes, chair and basin on the right, asphalt and localized damp patches. Keep the lower-right caption “目标设计参考 · 非实机”. No people, no new signs, no 得利洗衣店 sign, no camera change, no major restyling.
```
