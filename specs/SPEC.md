# SPEC — 丽天智能 MMR 光伏安装机器人示教视频（体素风格）

## 目标

用 Blender + Godot 制作一支 **75–90 秒、1080p30** 的中文示教视频，展示丽天智能
**MMR 自动导航组件安装机器人**完成一次完整作业：上料抓取 → 转运 → 视觉对位 →
落板 → 换位循环。

## 风格约束

- 视觉：**体素 / 方块风格**（受《我的世界》启发的通用体素美学）。
- 不使用 Minecraft 商标、Logo、角色（Steve / Creeper 等）、官方字体、音效或任何原版素材；
  模型、贴图、UI 全部原创生成。
- 机器人按公开资料形态（履带底盘 + 机械臂 + 真空吸盘 + 3D 视觉）做方块化原创设计，
  不承诺 1:1 还原真机；按实机参考采用 白色车身 + 绿色裙边 + 橙色布套机械臂 +
  银色吸盘架 + 蓝色吸盘 + LEAPTING 标识 + 黑色履带。
- 场景：沙漠光伏电站（对应丽天中东项目背景），方块地面、方块云、方块太阳。

## 工具链

| 环节 | 工具 | 说明 |
| --- | --- | --- |
| 建模/像素贴图 | Blender 4.5.15（Python 脚本） | 生成 GLB，贴图 16–64px、Nearest 采样 |
| 场景/动画/镜头/字幕 | Godot 4.7.2（Forward+） | Movie Maker 模式逐帧渲染 |
| 中文旁白 | edge-tts（zh-CN-YunxiNeural） | 分段生成，按实际时长校准时间轴 |
| 背景音乐 | Python/numpy 合成轻氛围垫乐 | 原创，无版权问题 |
| 混流/压制 | ffmpeg | H.264 CRF18 + AAC 192k，-16 LUFS |

## 时长与分段（目标 86s，允许 ±8s）

| # | 段落 | 目标时长 | 画面要点 |
| --- | --- | --- | --- |
| 0 | 片头 | 8s | 沙漠光伏场航拍滑入，标题「丽天智能 MMR 组件安装机器人」 |
| 1 | 设备概览 | 14s | 环绕机器人，标注：履带底盘 / 机械臂 / 真空吸盘 / 3D 视觉 |
| 2 | 上料抓取 | 12s | 机械臂转向承载平台，吸盘下压、吸附、抬升组件 |
| 3 | 转运 | 9s | 转台回摆，组件送到安装排上方，侧向跟拍 |
| 4 | 视觉对位 | 11s | 传感器特写 + HUD 对位读数收敛，组件微调悬停 |
| 5 | 落板 | 9s | 组件落到支架轨道，吸盘释放，机械臂回撤 |
| 6 | 换位循环 | 15s | 底盘前进一格，第二次落板，广角展示已铺装阵列 |
| 7 | 片尾 | 8s | 拉远收尾，品牌卡 + 三条能力亮点 |

旁白分段生成后，段落长度取 max(画面时长, 旁白时长+0.6s)，导演脚本按时间轴拉伸关键帧。

## 场景与资产

- Blender 导出：`mmr_robot.glb`（含命名关节 Chassis/Turret/ArmLower/ArmUpper/Wrist/EffectorRoll/Effector/Grip）、
  `pv_panel.glb`、`array_row.glb`（带板阵列）、`work_row.glb`（空轨道安装排）、
  `sand_block.glb`、`cloud.glb`、`worker.glb`、`rock.glb`、`panel_trailer.glb`（料车道具）。
- 关节轴向约定：Turret 绕 Godot 局部 Y 旋转（偏航），ArmLower/ArmUpper/Wrist 绕局部 X
  （俯仰），EffectorRoll 绕局部 Z（滚转，用于抓取时把吸盘长边对齐组件宽边）。
- 导演脚本用**两连杆解析 IK** 控制吸盘目标位姿，关键帧只写目标点，避免手调角度。
- 游戏化元素：方块云漂移、方块太阳、装好的组件出现时轻微弹跳 + 绿色描边闪光。

## 目录

```
installation-robot/
  specs/SPEC.md
  blender/build_assets.py, textures/, previews/
  godot/ (project.godot, assets/models, scenes/Main.tscn, scripts/)
  audio/narration/*.mp3, bgm.wav, mix.m4a
  installation-robot-v1.0.0.mp4, poster.png, contact_sheet.png   (交付物，项目根目录)
  tools/ (gen_narration.py, make_bgm.py, mix_audio.py, make_logo.py, render_video.ps1)
  一键生成视频.cmd
  godot/build/ (渲染中间帧，可清理)
```

## 验收标准

1. `installation-robot-v1.0.0.mp4`：1920×1080、30fps、H.264+AAC，时长 75–90s。
2. 8 个段落齐全，旁白与画面同步；字幕无错字、无遮挡关键动作。
3. 无缺贴图/黑帧/穿模；机器人抓取-对位-落板动作连贯，组件最终正确落在轨道上。
4. 音频峰值 ≤ -1dBFS，旁白清晰，音乐不盖人声。
5. 关键帧抽帧截图（5 张）与 poster 一并交付；`ffprobe` 元数据自检通过。

## 验证方法

- 每完成一段：Godot 以 640×360 / 15fps 出预览片段，人工抽帧检查。
- 最终：`ffprobe` 校验分辨率/帧率/时长；ffmpeg 抽取 5 张关键帧 + contact sheet；
  逐项勾掉本 SPEC 验收条。

## 执行清单

- [x] 项目骨架与 SPEC
- [x] Blender 体素资产（机器人/组件/轨道/环境道具 + 像素贴图）并导出 GLB
- [x] Blender 预览图（3/4 视图、正面、场景）
- [x] Godot 场景搭建与灯光/天空/方块云
- [x] 导演脚本：IK、镜头、字幕、HUD、段落时间轴
- [x] 中文旁白 TTS + 时长校准 + 原创 BGM + 混音
- [x] 低分辨率预览渲染（1280×720，含音频）
- [x] 用户反馈修正：组件纵向铺装（长边 2.4m 沿 20° 坡面、短边 1.2m 沿阵列方向、步距 1.25m，
      腕部新增 EffectorYaw 绕吸盘法线旋转，落位数值验证通过）
- [x] 按实机参考重做 MMR 外观：白车身 + 绿裙边 + 橙色布套臂 + 蓝吸盘 +
      LEAPTING 标识 + 后部控制柜/料架 + 料车；移除高桅杆雷达
- [x] 视觉复核与镜头修正（抓取/转运/对位/落板机位、标题避让、光照朝向、电池片纹理加密）
- [x] 最终 1080p30 渲染、压制、抽帧验证、交付

## 交付状态（2026-11-17）

- 成片：`installation-robot-v1.0.0.mp4`（1920×1080，30fps，87.67s，H.264 High + AAC 48kHz，
  约 134.6MB）
- 海报：`poster.png`（14s 设备概览）；联系人表：`contact_sheet.png`
- 音频：峰值 -3.4 dBFS，均值 -18 dB；中文旁白 edge-tts 分段合成，BGM 为 numpy 原创合成
- 数值验收：首次抓取 (3.8, 2.735, 11.80)；落板 (0, 1.42, 10.00)，法线 (0.342, 0.94, 0)，
  组件两角高 1.01/1.83 贴合轨道；第二次落板 (0, 1.43, 8.75)
- 镜头：片头/概览/上料/转运/对位/落板/换位/片尾 8 段；字幕、步骤条、标注与对位 HUD 全内嵌
- 复现：双击 `一键生成视频.cmd`（或 `tools\render_video.ps1`）。注意：
  - Movie Maker 出片尺寸取窗口尺寸，`project.godot` 的窗口 override 已设为 1920×1080；
  - 必须带 `--fixed-fps 30`；电影路径相对 Godot 工程目录（`godot/build/*.avi`）；
  - Movie Maker 的 AVI 自带一条静音 PCM 轨，ffmpeg 必须 `-map 0:v:0 -map 1:a:0`
    显式混入 `audio/mix.m4a`（脚本已修）。
- 备注：体素化原创演绎，非 1:1 工业还原；片头已注明“动画为原创示意”。
