extends Control
## 体素风格 HUD：标题 / 步骤条 / 字幕 / 设备标注 / 对位仪表 / 片尾卡

const ACCENT := Color("#3ddc84")
const INK := Color("#0b1116")
const PAPER := Color("#f5f7f4")
const MUTED := Color("#a9bdb4")
const WARN := Color("#f2b45a")
const DIM := Color("#0b1116")

var font: Font
var camera: Camera3D
var timeline: Dictionary = {}
var segments: Array = []
var time := 0.0
var refs: Dictionary = {}
var grip: Node3D
var install_count := 0
var align_dx := 0.0
var align_dz := 0.0
var align_dtheta := 0.0
var align_progress := 0.0
var align_locked := false
var show_brackets := false

const CALL_OUTS := [
	{"key": "body", "label": "履带底盘", "at": 10.8, "dx": -190.0, "dy": 130.0, "out": 20.0},
	{"key": "arm", "label": "机械臂", "at": 13.4, "dx": 175.0, "dy": -90.0},
	{"key": "effector", "label": "真空吸盘", "at": 16.0, "dx": 165.0, "dy": 80.0},
	{"key": "vision", "label": "3D 视觉", "at": 18.6, "dx": -180.0, "dy": -95.0},
	{"key": "trailer", "label": "随行料车", "at": 20.8, "dx": -260.0, "dy": 70.0},
]


func setup(f: Font, cam: Camera3D, tl: Dictionary, anchors: Dictionary, grip_node: Node3D) -> void:
	font = f
	camera = cam
	timeline = tl
	segments = timeline.get("segments", [])
	refs = anchors
	grip = grip_node
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func refresh(t: float) -> void:
	time = t
	queue_redraw()


func segment_index(t: float) -> int:
	for i in segments.size():
		if t < float(segments[i]["end"]):
			return i
	return segments.size() - 1


func _draw() -> void:
	if font == null or segments.is_empty():
		return
	var idx := segment_index(time)
	_draw_title()
	if idx >= 1 and idx <= 6:
		_draw_step_chip(idx)
		_draw_caption(segments[idx])
	if idx == 1:
		_draw_callouts()
	if show_brackets:
		_draw_panel_brackets()
	if idx == 4 or (idx == 5 and time < 56.6):
		_draw_align_widget()
	if idx == 6:
		_draw_install_counter()
	_draw_end_card()


# ------------------------------------------------------------ helpers
func _measure(s: String, size: int) -> float:
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


func _text(pos: Vector2, s: String, size: int, col: Color, shadow := true) -> void:
	if shadow:
		draw_string(font, pos + Vector2(3, 3), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0, 0, 0, 0.5 * col.a))
	draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _text_center(cx: float, baseline: float, s: String, size: int, col: Color) -> void:
	var w := _measure(s, size)
	_text(Vector2(cx - w * 0.5, baseline), s, size, col)


func _panel(rect: Rect2, fill: Color, border: Color, width := 3.0) -> void:
	draw_rect(rect, fill, true)
	draw_rect(rect, border, false, width)


func _fade(a: float, b: float, c: float, d: float) -> float:
	if time < a or time > d:
		return 0.0
	if time < b:
		return (time - a) / max(b - a, 0.001)
	if time > c:
		return 1.0 - (time - c) / max(d - c, 0.001)
	return 1.0


# ------------------------------------------------------------ 片头
func _draw_title() -> void:
	var a := _fade(0.5, 1.5, 6.1, 7.3)
	if a <= 0.0:
		return
	var white := Color(PAPER.r, PAPER.g, PAPER.b, a)
	var accent := Color(ACCENT.r, ACCENT.g, ACCENT.b, a)
	var muted := Color(MUTED.r, MUTED.g, MUTED.b, a)
	draw_rect(Rect2(110, 330, 860, 310), Color(0.02, 0.05, 0.06, 0.38 * a), true)
	draw_rect(Rect2(110, 330, 10, 310), accent, true)
	_text(Vector2(164, 384), "LEAPTING  ·  ROBOT FOR SOLAR", 24, accent)
	_text(Vector2(160, 470), "丽天智能 MMR", 96, white)
	_text(Vector2(164, 548), "光伏组件安装机器人 · 作业示教", 36, muted)
	draw_rect(Rect2(164, 582, 260, 8), accent, true)
	_text(Vector2(164, 626), "体素演示 · 动画为原创示意", 24, Color(MUTED.r, MUTED.g, MUTED.b, 0.75 * a))


# ------------------------------------------------------------ 步骤条
func _draw_step_chip(idx: int) -> void:
	var names := {
		1: "设备概览",
		2: "上料抓取",
		3: "转运",
		4: "视觉对位",
		5: "精准落板",
		6: "自动换位",
	}
	var step_no := {2: 1, 3: 2, 4: 3, 5: 4, 6: 5}
	var rect := Rect2(100, 82, 620, 74)
	_panel(rect, Color(0.04, 0.07, 0.08, 0.78), Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.85), 3.0)
	draw_rect(Rect2(100, 82, 10, 74), ACCENT, true)
	if step_no.has(idx):
		_text(Vector2(132, 131), "步骤 %02d / 05" % step_no[idx], 24, ACCENT)
		_text(Vector2(356, 131), names[idx], 24, PAPER)
	else:
		_text(Vector2(132, 131), "设备概览 · MMR", 24, ACCENT)


# ------------------------------------------------------------ 字幕
func _draw_caption(seg: Dictionary) -> void:
	var t0 := float(seg["start"]) + 0.35
	var t1 := float(seg["end"]) - 0.55
	var a := _fade(t0, t0 + 0.35, t1 - 0.4, t1)
	if a <= 0.0:
		return
	var text: String = seg.get("caption", "")
	var box := Rect2(210, 926, 1500, 88)
	_panel(box, Color(0.035, 0.06, 0.07, 0.92 * a), Color(0.55, 0.75, 0.66, 0.35 * a), 2.0)
	draw_rect(Rect2(210, 926, 8, 88), Color(ACCENT.r, ACCENT.g, ACCENT.b, a), true)
	_text_center(960, 983, text, 36, Color(PAPER.r, PAPER.g, PAPER.b, a))


# ------------------------------------------------------------ 设备标注
func _draw_callouts() -> void:
	for item in CALL_OUTS:
		var at := float(item["at"])
		var out := float(item.get("out", 22.6))
		var a := _fade(at, at + 0.35, out, out + 0.7)
		if a <= 0.0 or not refs.has(item["key"]):
			continue
		var node: Node3D = refs[item["key"]]
		if node == null or not is_instance_valid(node):
			continue
		var wp: Vector3 = node.global_position
		if camera.is_position_behind(wp):
			continue
		var sp: Vector2 = camera.unproject_position(wp)
		if sp.x < -50 or sp.x > size.x + 50 or sp.y < -50 or sp.y > size.y + 50:
			continue
		var lx: float = sp.x + float(item["dx"])
		var ly: float = sp.y + float(item["dy"])
		var label: String = item["label"]
		var tw := _measure(label, 24)
		var box := Rect2(lx - tw * 0.5 - 18, ly - 22, tw + 36, 44)
		box.position.x = clamp(box.position.x, 110, size.x - box.size.x - 110)
		box.position.y = clamp(box.position.y, 120, size.y - box.size.y - 120)
		var col := Color(ACCENT.r, ACCENT.g, ACCENT.b, a)
		draw_line(sp, Vector2(lx, ly), Color(1, 1, 1, 0.55 * a), 2.0)
		draw_rect(Rect2(sp - Vector2(5, 5), Vector2(10, 10)), col, true)
		_panel(box, Color(0.035, 0.06, 0.07, 0.8 * a), col, 2.0)
		_text(Vector2(box.position.x + 18, box.position.y + 31), label, 24, Color(PAPER.r, PAPER.g, PAPER.b, a))


# ------------------------------------------------------------ 对位 HUD
func _draw_panel_brackets() -> void:
	if grip == null or not is_instance_valid(grip) or camera.is_position_behind(grip.global_position):
		return
	var xf := grip.global_transform
	var corners := [
		Vector3(-1.2, 0, -0.6), Vector3(1.2, 0, -0.6),
		Vector3(1.2, 0, 0.6), Vector3(-1.2, 0, 0.6),
	]
	var pts: Array[Vector2] = []
	for c in corners:
		pts.append(camera.unproject_position(xf * c))
	var col := Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.95) if align_locked else Color(WARN.r, WARN.g, WARN.b, 0.9)
	for i in 4:
		var p: Vector2 = pts[i]
		var prev: Vector2 = pts[(i + 3) % 4]
		var nxt: Vector2 = pts[(i + 1) % 4]
		draw_line(p, p + (prev - p).normalized() * 30.0, col, 3.0)
		draw_line(p, p + (nxt - p).normalized() * 30.0, col, 3.0)
	var center: Vector2 = camera.unproject_position(xf.origin)
	draw_line(center - Vector2(14, 0), center + Vector2(14, 0), col, 2.0)
	draw_line(center - Vector2(0, 14), center + Vector2(0, 14), col, 2.0)


func _draw_align_widget() -> void:
	var a := _fade(46.2, 46.8, 55.4, 56.2)
	if a <= 0.0:
		return
	var rect := Rect2(1400, 96, 420, 268)
	_panel(rect, Color(0.035, 0.06, 0.07, 0.82 * a), Color(0.55, 0.75, 0.66, 0.35 * a), 2.0)
	_text(Vector2(1430, 134), "视觉对位  VISION ALIGN", 24, Color(ACCENT.r, ACCENT.g, ACCENT.b, a))
	draw_line(Vector2(1430, 152), Vector2(1790, 152), Color(1, 1, 1, 0.18 * a), 2.0)
	var status_col := Color(ACCENT.r, ACCENT.g, ACCENT.b, a) if align_locked else Color(WARN.r, WARN.g, WARN.b, a)
	var status_txt := "对位锁定" if align_locked else "动态调整中"
	_text(Vector2(1430, 190), "ΔX", 24, Color(MUTED.r, MUTED.g, MUTED.b, a))
	_text(Vector2(1620, 190), "%+05.1f mm" % align_dx, 24, Color(PAPER.r, PAPER.g, PAPER.b, a))
	_text(Vector2(1430, 228), "ΔZ", 24, Color(MUTED.r, MUTED.g, MUTED.b, a))
	_text(Vector2(1620, 228), "%+05.1f mm" % align_dz, 24, Color(PAPER.r, PAPER.g, PAPER.b, a))
	_text(Vector2(1430, 266), "Δθ", 24, Color(MUTED.r, MUTED.g, MUTED.b, a))
	_text(Vector2(1620, 266), "%+05.2f°" % align_dtheta, 24, Color(PAPER.r, PAPER.g, PAPER.b, a))
	draw_rect(Rect2(1430, 288, 360, 14), Color(1, 1, 1, 0.12 * a), true)
	draw_rect(Rect2(1430, 288, 360 * clamp(align_progress, 0.0, 1.0), 14), status_col, true)
	_text(Vector2(1430, 342), status_txt, 24, status_col)


func _draw_install_counter() -> void:
	var a := _fade(64.8, 65.4, 79.0, 79.6)
	if a <= 0.0:
		return
	var rect := Rect2(1400, 96, 420, 150)
	_panel(rect, Color(0.035, 0.06, 0.07, 0.82 * a), Color(0.55, 0.75, 0.66, 0.35 * a), 2.0)
	_text(Vector2(1430, 134), "自动换位 · 循环安装", 24, Color(ACCENT.r, ACCENT.g, ACCENT.b, a))
	_text(Vector2(1430, 186), "已安装  %02d / 02" % install_count, 24, Color(PAPER.r, PAPER.g, PAPER.b, a))
	for i in 2:
		var on := i < install_count
		var col := Color(ACCENT.r, ACCENT.g, ACCENT.b, a) if on else Color(1, 1, 1, 0.14 * a)
		draw_rect(Rect2(1430 + i * 190, 208, 170, 14), col, true)


# ------------------------------------------------------------ 片尾
func _draw_end_card() -> void:
	var a := _fade(80.1, 81.3, 200.0, 201.0)
	if a <= 0.0:
		return
	var rect := Rect2(360, 300, 1200, 470)
	draw_rect(rect, Color(0.03, 0.05, 0.06, 0.82 * a), true)
	draw_rect(rect, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.9 * a), false, 3.0)
	draw_rect(Rect2(360, 300, 1200, 8), Color(ACCENT.r, ACCENT.g, ACCENT.b, a), true)
	var white := Color(PAPER.r, PAPER.g, PAPER.b, a)
	var green := Color(ACCENT.r, ACCENT.g, ACCENT.b, a)
	var muted := Color(MUTED.r, MUTED.g, MUTED.b, a)
	_text_center(960, 392, "LEAPTING  ·  ROBOT FOR SOLAR", 24, green)
	_text_center(960, 462, "丽天智能 MMR", 72, white)
	_text_center(960, 516, "LEAPTING · 光伏组件安装机器人", 36, muted)
	draw_rect(Rect2(830, 532, 260, 6), green, true)
	_text_center(960, 610, "3D 视觉对位   ·   自动导航   ·   循环作业", 36, green)
	_text_center(960, 686, "让光伏电站建设更高效、更安全", 24, Color(0.78, 0.85, 0.81, a))
