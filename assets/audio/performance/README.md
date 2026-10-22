# 第一案对白表演

30句中文合成录音，包含周秀兰、老周、许砚及阿七的主要现场对白。正文从 `scripts/laundry_campaign.gd` 的字幕提取；计数、擦纸、问衣和阿七尾声补入同一配置。未修改唯一结局或证据结论。

`lines.json` 保存逐句语速、音高、音量、停顿和情绪标记；`performance.json` 附实际 WAV 时长与50Hz响度包络。游戏使用录好的文件，不依赖系统语音、Python或网络。按播放位置采样包络，静音段闭口，跳句及停止时立即解除说话状态。

作者重建顺序：

1. Python运行 `scripts/tools/prepare_performance_lines.py`。
2. Windows PowerShell运行 `scripts/tools/generate_performance_voice.ps1`。使用已安装的中文 Microsoft Huihui、Kangkang、Yaoyao 与 System.Speech；不是真人克隆，也不是神经情感配音服务。
3. 安装numpy的作者Python运行 `scripts/tools/analyze_voice_envelopes.py`，再让Godot导入WAV。

语气采用适度的SSML韵律与停顿，不代表真人演绎。口型为响度驱动的基础开合，没有逐音素唇形、舌部或完整面部表演。
