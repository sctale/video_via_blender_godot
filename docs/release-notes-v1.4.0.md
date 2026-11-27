# v1.4.0 — 电影化质量升级

本版在不改变作业流程、旁白与 87.7 秒时长的前提下，把体素技术演示升级为
**黄金时刻工业产品片**：重做光照与轻后期、重排 21 个镜头、补机械细节与材质层次、
加入同步音效与分层混音，并把预览和验收脚本化。

> 开源范围不变：代码/脚本/文档 **MIT**；示例视频与媒体 **All Rights Reserved**，
> 不允许二次创作、再分发或商用。详见 `LICENSE-DEMO.md`。

## 画面

- **黄金时刻光照**：低角度暖阳 + 冷色补光/轮廓光，环境光从 0.9 降至 0.48，
  `shadow_normal_bias` 从 1.5 降至 0.45，减少悬浮阴影；加雾、SSAO、辉光与 Filmic 曝光。
- **轻后期**：独立 CanvasLayer shader 给 3D 画面加暗角、细颗粒与轻暖调，HUD 不被污染；
  4×MSAA + FXAA。
- **21 镜头重排**：混合 28–45mm 等效 FOV、侧跟/俯拍/特写；吸附（29.7s）、对位（47.6s）、
  落板（57/74.9s）增加近景，动作末段 ease-out。
- **机械细节**：肩/肘/腕轴与螺栓、液压缸/活塞/卡箍、管线；料车低多边形轮毂与胎纹；
  履带板循环、轮毂旋转、换位轻微起伏与料车牵引摆动、行驶/落板沙尘。
- **材质环境**：256px 多尺度沙地 + 法线、透明车辙；组件电池片细母线、金属边框反光；
  保留原有光伏阵列、云、远山与工人。

## 声音

- 新增 `tools/make_sfx.py` + `tools/sfx_cues.json`：27 个程序化同步 cue，
  含伺服、液压、吸附、释放、落板、行驶、确认音与环境风。
- BGM 升级为 pad + 低音 + 琶音 + 轻脉冲 + 上升音 + 片尾主和弦。
- 逐段旁白归一至约 -18 LUFS；BGM/SFX 侧链（attack 20–25ms）；两遍 loudnorm。

## 流程

- `preview_stills.ps1`：按关键时间点渲静帧并生成带时间标签的 contact sheet。
- `verify_video.ps1`：检查分辨率、帧数、像素格式、BT.709 标记、黑段、EBU R128 与 true peak，
  输出 `out/verify-v1.4.0.json`。
- `render_video.ps1`：资产 → 音频 → Movie Maker → BT.709 压制 → poster/contact sheet → 自动验收。
- PowerShell 脚本优先使用 `py -3`，避免 Windows Store `python.exe` 占位符问题。

## 验证结果

- 1920×1080 / 30fps / **2630 帧 / 87.667s**；H.264 High + AAC 48kHz 立体声。
- `pix_fmt=yuv420p`、`color_range=tv`、BT.709 matrix/transfer/primaries 三标记齐全。
- 综合响度 **-16.0 LUFS**，true peak **-2.0 dBTP**；无 ≥0.15s 黑段。
- 抓取 err ≤0.002m；落板角高与 v1.3.1 基本一致（差异约 1–2mm）。
- MP4 146,994,088 B（约 140.2 MiB）；`poster.jpg` 368,846 B；
  `contact_sheet.jpg` 669,726 B。

## 说明

- 本版取代 v1.3.1；旧 MMR Release 已下线，仅保留 v1.4.0。
- 体素化原创演绎，非官方产品视频；与丽天智能无隶属或背书关系。
- 官方参考照片仅用于对照，未进入本仓库。
