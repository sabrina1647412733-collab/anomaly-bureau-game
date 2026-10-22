# 基础面部表演资源

三位NPC：zhou周秀兰、laozhou老周、aqi阿七。原角色GLB、材质和修正坐姿动画保留。运行时替换网格，沿用原来的Skin与骨骼，不跨角色套用资源。

每个ArrayMesh含SpeechOpen、Blink、Concern、Relief四种形变。面部局部细分保留原表面、UV及归一化蒙皮；沿嘴缝拆分并增加口腔内面。表情强度受限，口部运行上限0.48；只是基础说话、眨眼和忧虑/释然，不是完整FACS或逐音素口型。许砚本轮改善声音，未新增主角面部形变。

`landmarks.json` 坐标来自各自原始网格局部空间的嘴缝与双眼中心。生成入口：

`godot --headless --path . --script res://scripts/tools/build_face_shapes.gd -- --verify`

`audit.json` 记录输出顶点数。局部细分增加顶点，三份资源约12MB；不同低配机器仍需实际性能检查。

运行驱动为 `scripts/laundry/facial_performance.gd`；`speech_head_modifier.gd` 在身体动画之后只叠加很小的头部动作，不修改骨盆、四肢或座高。暂停冻结表演，读档和退出仍沿用现场系统。

检查入口 `performance_feedback_test.gd`，画面入口 `performance_feedback_review.gd`。原模型的三角形轮廓和贴图精度仍有限；需要更精细的近景表演时，应在原GLB基础上进行专门面部重拓扑与口腔制作。
