# v1.0.0 — Blender × Godot 体素视频制作方法

首个公开版本：**Blender 程序化建模 + Godot 实时导演 + Movie Maker 出片**的完整方法，
以及一支用于展示的体素风格示例成片。

> **开源范围**：本仓库的代码、脚本、文档为 **MIT**。
> **示例视频与媒体不开源**：视频、海报、3D 模型、贴图、旁白、音乐等
> **All Rights Reserved**，不允许二次创作、再分发或商用。详见仓库
> `LICENSE-DEMO.md` 与 `NOTICE.md`。

## 示例成片（版权保留）

- 文件：`installation-robot-v1.0.0.mp4`
- 规格：1920×1080 · 30fps · 87.7s · H.264 High + AAC 48kHz
- 内容：体素化原创演绎的 MMR 光伏组件安装机器人作业示教（上料→转运→视觉对位→落板→换位）
- 声明：非官方产品视频，与丽天智能无隶属或背书关系；画面为原创示意，不是 1:1 工业还原。

## 仓库内容（MIT）

- **Blender**：程序化体素机器人/组件/轨道/道具、numpy 像素贴图、GLB 导出、关节命名约定
- **Godot 4**：两连杆解析 IK、腕部法线旋转保持组件纵向、镜头调度、字幕/HUD、
  事件驱动的吸附/落板、Movie Maker 逐帧渲染
- **音频**：edge-tts 中文旁白、numpy 原创 BGM、ffmpeg 铺轨与 sidechain 混音
- **工具**：一键首次生成、终渲/压制/抽帧验证脚本
- **文档**：SPEC（分段、验收、实现记录）与常见坑（窗口尺寸、`--fixed-fps 30`、
  Movie Maker 静音 PCM 轨必须显式 `-map`）

## 复现

```powershell
git clone https://github.com/sctale/video_via_blender_godot.git
cd video_via_blender_godot
pip install -r requirements.txt
powershell -ExecutionPolicy Bypass -File tools\first_run.ps1
```

前置：Blender 4.5+、Godot 4.7+、Python 3.10+、ffmpeg/ffprobe 在 PATH，联网（TTS）。
详见 README。

## 致谢

- 像素字体 Fusion Pixel Font © 2022 TakWolf（MIT）
- Blender / Godot 社区
- 示例成片中的品牌标识仅用于演示，权利归其所有者
