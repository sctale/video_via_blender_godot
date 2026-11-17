extends Node3D
## 丽天智能 MMR 体素示教片 — 场景搭建 + 导演时间轴 + 两连杆 IK

const L1 := 2.5          # 大臂长度
const L2 := 3.3          # 小臂长度（腕部到吸盘架中心）
const GRIP_FWD := 0.0    # 腕部即吸盘架中心，无前伸
const GRIP_DOWN := 0.58  # 吸盘中心相对腕部下探（架体/吸盘）
const ROBOT_X := 3.8
const SLOT_Z0 := 10.0
const SLOT_DZ := -1.25  # 纵向组件沿阵列方向的步距

var timeline: Dictionary = {}
var duration := 88.0
var time := 0.0
var last_time := -0.001
var finished := false
var still_mode := false
var still_frames := 0

var robot_scene: PackedScene
var panel_scene: PackedScene
var row_scene: PackedScene
var work_row_scene: PackedScene
var block_scene: PackedScene
var cloud_scene: PackedScene
var worker_scene: PackedScene
var rock_scene: PackedScene

var robot: Node3D
var chassis: Node3D
var turret: Node3D
var arm_lower: Node3D
var arm_upper: Node3D
var wrist: Node3D
var effector_yaw: Node3D
var effector: Node3D
var grip: Node3D
var vision_node: Node3D
var stack_panels: Array[Node3D] = []
var placed_panels: Array[Node3D] = []
var carried: Node3D
var camera: Camera3D
var hud
var cloud_meta: Array = []

var pose_keys: Array = []
var events: Array = []
var placed_next := 0
var install_count := 0
var attached := false

var align_dx := 0.0
var align_dz := 0.0
var align_dtheta := 0.0
var align_progress := 0.0
var align_locked := false

var shots: Array = []


func _ready() -> void:
	still_mode = OS.has_environment("STILL_T")
	_load_timeline()
	_build_environment()
	_build_ground()
	_build_arrays()
	_build_props()
	_build_robot()
	_build_camera()
	_build_hud()
	_build_timeline_data()
	if still_mode:
		var t_still := float(OS.get_environment("STILL_T"))
		var steps := int(t_still * 30.0)
		for i in steps:
			apply_time(float(i) / 30.0)
		apply_time(t_still)
		print("[still] applied t=", t_still)
	else:
		apply_time(0.0)


func _process(delta: float) -> void:
	if finished:
		return
	if still_mode:
		still_frames += 1
		if still_frames >= 3:
			get_tree().quit()
		return
	time += delta
	apply_time(minf(time, duration))
	if time >= duration:
		finished = true
		get_tree().quit()


# ---------------------------------------------------------------- 基础
func _load_timeline() -> void:
	var f := FileAccess.open("res://data/timeline.json", FileAccess.READ)
	if f:
		timeline = JSON.parse_string(f.get_as_text())
	_duration_from_timeline()


func _duration_from_timeline() -> void:
	duration = float(timeline.get("duration", 88.0))


func _build_timeline_data() -> void:
	pose_keys = [
		{"t": 0.0, "yaw": 0.0, "d": 3.4, "h": 2.9, "pitch": 0.0},
		{"t": 8.0, "yaw": 0.0, "d": 3.4, "h": 2.9, "pitch": 0.0},
		{"t": 23.66, "yaw": 0.0, "d": 3.4, "h": 2.9, "pitch": 0.0},
		{"t": 26.4, "yaw": 170.0, "d": 2.0, "h": 3.7, "pitch": 0.0},
		{"t": 27.6, "yaw": 180.0, "d": 1.85, "h": 3.35, "pitch": 0.0},
		{"t": 29.7, "yaw": 180.0, "d": 1.8, "h": 2.73, "pitch": 0.0},
		{"t": 30.9, "yaw": 180.0, "d": 1.75, "h": 3.3, "pitch": 0.0},
		{"t": 32.4, "yaw": 180.0, "d": 1.55, "h": 4.55, "pitch": 0.0},
		{"t": 35.66, "yaw": 180.0, "d": 1.6, "h": 4.6, "pitch": 0.0},
		{"t": 38.8, "yaw": 120.0, "d": 2.0, "h": 4.68, "pitch": 0.0},
		{"t": 40.4, "yaw": 90.0, "d": 2.3, "h": 4.6, "pitch": 0.0},
		{"t": 42.6, "yaw": 90.0, "d": 3.75, "h": 3.0, "pitch": 4.0},
		{"t": 44.68, "yaw": 90.0, "d": 3.75, "h": 2.65, "pitch": 14.0},
		{"t": 47.6, "yaw": 90.0, "d": 3.8, "h": 2.15, "pitch": 18.0},
		{"t": 51.0, "yaw": 90.0, "d": 3.8, "h": 2.1, "pitch": 18.0},
		{"t": 54.0, "yaw": 90.0, "d": 3.8, "h": 1.72, "pitch": 20.0},
		{"t": 55.4, "yaw": 90.0, "d": 3.8, "h": 1.46, "pitch": 20.0},
		{"t": 55.68, "yaw": 90.0, "d": 3.8, "h": 1.44, "pitch": 20.0},
		{"t": 57.0, "yaw": 90.0, "d": 3.8, "h": 1.42, "pitch": 20.0},
		{"t": 58.4, "yaw": 90.0, "d": 3.75, "h": 2.3, "pitch": 6.0},
		{"t": 60.8, "yaw": 90.0, "d": 3.4, "h": 2.9, "pitch": 0.0},
		{"t": 64.68, "yaw": 90.0, "d": 3.35, "h": 2.9, "pitch": 0.0},
		{"t": 65.9, "yaw": 30.0, "d": 3.4, "h": 2.9, "pitch": 0.0},
		{"t": 67.0, "yaw": 0.0, "d": 3.4, "h": 2.9, "pitch": 0.0},
		{"t": 68.6, "yaw": 170.0, "d": 2.0, "h": 3.65, "pitch": 0.0},
		{"t": 69.5, "yaw": 180.0, "d": 1.85, "h": 3.32, "pitch": 0.0},
		{"t": 70.2, "yaw": 180.0, "d": 1.8, "h": 2.61, "pitch": 0.0},
		{"t": 71.1, "yaw": 180.0, "d": 1.72, "h": 3.4, "pitch": 0.0},
		{"t": 71.9, "yaw": 150.0, "d": 2.0, "h": 4.3, "pitch": 0.0},
		{"t": 72.6, "yaw": 100.0, "d": 2.4, "h": 4.3, "pitch": 0.0},
		{"t": 73.3, "yaw": 90.0, "d": 3.2, "h": 2.95, "pitch": 4.0},
		{"t": 73.9, "yaw": 90.0, "d": 3.8, "h": 2.0, "pitch": 16.0},
		{"t": 74.5, "yaw": 90.0, "d": 3.8, "h": 1.46, "pitch": 20.0},
		{"t": 74.9, "yaw": 90.0, "d": 3.8, "h": 1.43, "pitch": 20.0},
		{"t": 76.0, "yaw": 90.0, "d": 3.6, "h": 2.6, "pitch": 5.0},
		{"t": 77.5, "yaw": 20.0, "d": 3.4, "h": 2.9, "pitch": 0.0},
		{"t": 79.68, "yaw": 0.0, "d": 3.4, "h": 2.9, "pitch": 0.0},
		{"t": 100.0, "yaw": 0.0, "d": 3.4, "h": 2.9, "pitch": 0.0},
	]
	events = [
		{"t": 29.75, "action": "attach", "index": 4},
		{"t": 57.0, "action": "detach"},
		{"t": 70.25, "action": "attach", "index": 3},
		{"t": 74.9, "action": "detach"},
	]
	shots = [
		{"t0": 0.0, "t1": 8.0, "p0": Vector3(24, 8, 32), "p1": Vector3(17, 5.5, 24),
		 "l0": Vector3(0.2, 1.5, 6.5), "l1": Vector3(0.4, 1.7, 6.5), "f0": 40.0, "f1": 37.0},
		{"t0": 8.0, "t1": 23.66, "orbit": true, "c": Vector3(3.8, 0, 10),
		 "r0": 13.5, "r1": 11.5, "a0": deg_to_rad(-35.0), "a1": deg_to_rad(55.0),
		 "h0": 4.6, "h1": 3.9, "l": Vector3(3.2, 1.9, 10.0), "f": 38.0},
		{"t0": 23.66, "t1": 35.66, "p0": Vector3(-0.8, 4.6, 10.4), "p1": Vector3(-0.2, 4.3, 10.9),
		 "l0": Vector3(3.8, 2.55, 11.5), "l1": Vector3(3.8, 2.55, 11.45), "f0": 44.0, "f1": 44.0},
		{"t0": 35.66, "t1": 44.68, "p0": Vector3(10.2, 6.6, 6.4), "p1": Vector3(9.4, 6.2, 5.2),
		 "follow": true, "loff": Vector3(0, 0.1, 0), "f": 40.0},
		{"t0": 44.68, "t1": 55.68, "p0": Vector3(2.2, 3.3, 5.9), "p1": Vector3(1.9, 3.1, 6.3),
		 "l0": Vector3(0.4, 1.85, 10.0), "l1": Vector3(0.35, 1.8, 10.0), "f0": 33.0, "f1": 32.0},
		{"t0": 55.68, "t1": 64.68, "p0": Vector3(3.4, 4.0, 4.8), "p1": Vector3(3.0, 3.7, 5.2),
		 "l0": Vector3(0.4, 1.55, 10.0), "l1": Vector3(0.4, 1.5, 10.0), "f0": 33.0, "f1": 33.0},
		{"t0": 64.68, "t1": 71.0, "p0": Vector3(14.0, 5.2, 2.8), "p1": Vector3(15.0, 5.6, 1.4),
		 "l0": Vector3(2.8, 1.7, 8.9), "l1": Vector3(2.8, 1.8, 8.85), "f0": 38.0, "f1": 38.0},
		{"t0": 71.0, "t1": 79.68, "p0": Vector3(8.0, 3.7, 2.0), "p1": Vector3(7.2, 3.3, 1.3),
		 "l0": Vector3(1.4, 1.5, 9.0), "l1": Vector3(1.2, 1.4, 8.8), "f0": 36.0, "f1": 36.0},
		{"t0": 79.68, "t1": 87.68, "p0": Vector3(21, 9, 19), "p1": Vector3(31, 13, 31),
		 "l0": Vector3(2, 1.5, 3), "l1": Vector3(2, 1.5, 2), "f0": 40.0, "f1": 42.0},
	]


# ---------------------------------------------------------------- 环境
func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#3f93e8")
	sky_mat.sky_horizon_color = Color("#b7d9f7")
	sky_mat.ground_bottom_color = Color("#bfa877")
	sky_mat.ground_horizon_color = Color("#e3d3b0")
	sky_mat.sun_angle_max = 0.0
	sky_mat.sky_energy_multiplier = 1.0
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.ssao_enabled = true
	env.ssao_radius = 2.0
	env.ssao_intensity = 1.4
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.2
	env.fog_enabled = true
	env.fog_light_color = Color("#e9d9b6")
	env.fog_light_energy = 0.45
	env.fog_density = 0.0022
	env.fog_sky_affect = 0.25
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color("#fff0d6")
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 140.0
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.5
	add_child(sun)
	sun.look_at_from_position(Vector3(52, 46, 28), Vector3(3.8, 0, 10))

	var fill := DirectionalLight3D.new()
	fill.light_color = Color("#cfe4ff")
	fill.light_energy = 0.35
	fill.shadow_enabled = false
	add_child(fill)
	fill.look_at_from_position(Vector3(30, 20, 50), Vector3(0, 0, 0))

	var q := QuadMesh.new()
	q.size = Vector2(18, 18)
	var sm := MeshInstance3D.new()
	sm.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.albedo_color = Color(1.0, 0.96, 0.82)
	m.disable_receive_shadows = true
	sm.material_override = m
	sm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sm.position = Vector3(76, 68, 44)
	add_child(sm)


func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(360, 360)
	ground.mesh = pm
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/textures/sand.png")
	mat.uv1_scale = Vector3(180, 180, 1)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
	mat.roughness = 1.0
	ground.material_override = mat
	add_child(ground)

	var lane := MeshInstance3D.new()
	var lm := PlaneMesh.new()
	lm.size = Vector2(2.6, 46.0)
	lane.mesh = lm
	var lmat := StandardMaterial3D.new()
	lmat.albedo_texture = load("res://assets/textures/sand.png")
	lmat.albedo_color = Color(0.82, 0.77, 0.64)
	lmat.uv1_scale = Vector3(1.3, 23, 1)
	lmat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
	lmat.roughness = 1.0
	lane.material_override = lmat
	lane.position = Vector3(ROBOT_X, 0.012, 2.0)
	add_child(lane)


func _nearest_materials(node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null:
		for i in node.mesh.get_surface_count():
			var smat = node.mesh.surface_get_material(i)
			if smat is StandardMaterial3D:
				smat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC
	for c in node.get_children():
		_nearest_materials(c)


func _build_arrays() -> void:
	row_scene = load("res://assets/models/array_row.glb")
	work_row_scene = load("res://assets/models/work_row.glb")
	panel_scene = load("res://assets/models/pv_panel.glb")

	var work := work_row_scene.instantiate()
	add_child(work)
	_nearest_materials(work)

	for spec in [[-6.0, -4.0], [-12.0, 2.0], [-18.0, -6.0], [10.0, 4.0], [16.0, -3.0]]:
		var row := row_scene.instantiate()
		row.position = Vector3(spec[0], 0, spec[1])
		add_child(row)
		_nearest_materials(row)

	var b := _panel_basis()
	for z in [11.25, 12.5, 13.75]:
		var p := panel_scene.instantiate()
		p.transform = Transform3D(b, Vector3(0, 1.42, z))
		add_child(p)
		_nearest_materials(p)

	for slot in [SLOT_Z0, SLOT_Z0 + SLOT_DZ]:
		var p := panel_scene.instantiate()
		p.transform = Transform3D(b, Vector3(0, 1.42, slot))
		p.visible = false
		add_child(p)
		placed_panels.append(p)
		_nearest_materials(p)


func _panel_basis() -> Basis:
	# 纵向铺装：组件长边沿坡面，20° 倾角，仅绕阵列方向轴(Z)旋转
	return Basis(Vector3(0, 0, 1), deg_to_rad(-20.0))


func _build_props() -> void:
	block_scene = load("res://assets/models/sand_block.glb")
	cloud_scene = load("res://assets/models/cloud.glb")
	worker_scene = load("res://assets/models/worker.glb")
	rock_scene = load("res://assets/models/rock.glb")

	var trailer: Node3D = load("res://assets/models/panel_trailer.glb").instantiate()
	trailer.position = Vector3(-3.6, 0, 16.0)
	trailer.rotation_degrees.y = 90.0
	add_child(trailer)
	_nearest_materials(trailer)

	var probe := block_scene.instantiate()
	var block_mesh: Mesh = null
	for mi in probe.find_children("*", "MeshInstance3D", true, false):
		block_mesh = (mi as MeshInstance3D).mesh
		break
	probe.free()

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = block_mesh
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261117
	var trs: Array[Transform3D] = []
	for c in 46:
		var ang := rng.randf() * TAU
		var rad := rng.randf_range(38.0, 120.0)
		var base := Vector3(cos(ang) * rad, 0, sin(ang) * rad + 4.0)
		var layers := rng.randi_range(1, 3)
		for layer in layers:
			var cnt := rng.randi_range(2, 5) - layer
			for k in max(cnt, 1):
				var off := Vector3(rng.randf_range(-2.5, 2.5), float(layer), rng.randf_range(-2.5, 2.5))
				var sc := rng.randf_range(0.9, 1.6) if layer == 0 else 1.0
				var b := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3(sc, 1.0, sc))
				trs.append(Transform3D(b, base + off))
	mm.instance_count = trs.size()
	for i in trs.size():
		mm.set_instance_transform(i, trs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)
	var bm = mm.mesh.surface_get_material(0)
	if bm is StandardMaterial3D:
		bm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC

	for mesa in [
		[Vector3(-95, 0, -58), Vector3(26, 13, 18)],
		[Vector3(72, 0, -96), Vector3(30, 16, 20)],
		[Vector3(-132, 0, 34), Vector3(22, 10, 16)],
		[Vector3(112, 0, 62), Vector3(18, 8, 14)],
	]:
		var mi := MeshInstance3D.new()
		mi.mesh = block_mesh
		mi.position = mesa[0]
		mi.scale = mesa[1]
		mi.rotation.y = rng.randf_range(-0.4, 0.4)
		add_child(mi)

	for pos in [Vector3(-30, 0, 20), Vector3(-38, 0, -14), Vector3(24, 0, -24),
			Vector3(34, 0, 18), Vector3(-26, 0, -32), Vector3(40, 0, -6)]:
		var rk := rock_scene.instantiate()
		rk.position = pos
		rk.scale = Vector3.ONE * rng.randf_range(1.2, 2.4)
		rk.rotation.y = rng.randf_range(0, TAU)
		add_child(rk)
		_nearest_materials(rk)

	for cfg in [[Vector3(-2.4, 0, 5.6), 90.0], [Vector3(-3.4, 0, -7.5), -30.0]]:
		var w := worker_scene.instantiate()
		w.position = cfg[0]
		w.rotation_degrees.y = cfg[1]
		add_child(w)
		_nearest_materials(w)

	for i in 8:
		var cl := cloud_scene.instantiate()
		cl.scale = Vector3.ONE * rng.randf_range(2.4, 4.6)
		cl.position = Vector3(rng.randf_range(-100, 100), rng.randf_range(26, 44), rng.randf_range(-110, 40))
		add_child(cl)
		for mi in cl.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_nearest_materials(cl)
		cloud_meta.append({"node": cl, "base": cl.position})


# ---------------------------------------------------------------- 机器人
func _build_robot() -> void:
	robot_scene = load("res://assets/models/mmr_robot.glb")
	robot = robot_scene.instantiate()
	robot.position = Vector3(ROBOT_X, 0, SLOT_Z0)
	add_child(robot)
	_nearest_materials(robot)

	chassis = robot.find_child("Chassis", true, false)
	turret = robot.find_child("Turret", true, false)
	arm_lower = robot.find_child("ArmLower", true, false)
	arm_upper = robot.find_child("ArmUpper", true, false)
	wrist = robot.find_child("Wrist", true, false)
	effector_yaw = robot.find_child("EffectorYaw", true, false)
	effector = robot.find_child("Effector", true, false)
	grip = robot.find_child("Grip", true, false)
	vision_node = robot.find_child("EffectorCam", true, false)

	for i in 5:
		var p := panel_scene.instantiate()
		chassis.add_child(p)
		p.position = Vector3(0, 2.245 + i * 0.12, 1.8)
		_nearest_materials(p)
		stack_panels.append(p)

	carried = panel_scene.instantiate()
	grip.add_child(carried)
	carried.position = Vector3.ZERO
	carried.visible = false
	_nearest_materials(carried)


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.fov = 36.0
	camera.near = 0.1
	camera.far = 700.0
	camera.current = true
	add_child(camera)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var HUD_SCRIPT := preload("res://scripts/HUD.gd")
	hud = HUD_SCRIPT.new()
	layer.add_child(hud)
	var font: Font = load("res://assets/fonts/fusion-pixel-12px-proportional-zh_hans.otf")
	if font == null:
		font = ThemeDB.fallback_font
	if font is FontFile:
		font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
		font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
		font.hinting = TextServer.HINTING_NONE
	var anchors := {
		"body": robot.find_child("Track_L", true, false),
		"arm": arm_upper,
		"effector": effector,
		"vision": vision_node,
		"stack": stack_panels[2] if stack_panels.size() > 2 else chassis,
	}
	hud.setup(font, camera, timeline, anchors, grip)


# ---------------------------------------------------------------- 导演
func _chassis_z(t: float) -> float:
	if t <= 64.68:
		return SLOT_Z0
	if t <= 66.2:
		return SLOT_Z0
	if t <= 67.8:
		var u := (t - 66.2) / 1.6
		u = u * u * (3.0 - 2.0 * u)
		return lerpf(SLOT_Z0, SLOT_Z0 + SLOT_DZ, u)
	return SLOT_Z0 + SLOT_DZ


func _pose_at(t: float) -> Dictionary:
	var a: Dictionary = pose_keys[0]
	var b: Dictionary = pose_keys[pose_keys.size() - 1]
	for i in pose_keys.size() - 1:
		var k0: Dictionary = pose_keys[i]
		var k1: Dictionary = pose_keys[i + 1]
		if t >= float(k0["t"]) and t <= float(k1["t"]):
			a = k0
			b = k1
			break
	var span := maxf(float(b["t"]) - float(a["t"]), 0.001)
	var u := clampf((t - float(a["t"])) / span, 0.0, 1.0)
	u = u * u * (3.0 - 2.0 * u)
	var yaw := lerpf(float(a["yaw"]), float(b["yaw"]), u)
	var d := lerpf(float(a["d"]), float(b["d"]), u)
	var h := lerpf(float(a["h"]), float(b["h"]), u)
	var pitch := lerpf(float(a["pitch"]), float(b["pitch"]), u)

	align_dx = 0.0
	align_dz = 0.0
	align_dtheta = 0.0
	align_progress = 0.0
	align_locked = false
	if t >= 47.6 and t <= 53.9:
		var p := clampf((t - 47.6) / 6.0, 0.0, 1.0)
		var damp := (1.0 - p) * (1.0 - p)
		align_dx = sin((t - 47.6) * 2.6) * 46.0 * damp
		align_dz = cos((t - 47.6) * 2.1) * 24.0 * damp
		align_dtheta = sin((t - 47.6) * 1.9) * 1.2 * damp
		align_progress = p
		align_locked = p > 0.985
		d += align_dx * 0.0012
		h += align_dz * 0.0009
		yaw += align_dtheta * 0.35
	return {"yaw": yaw, "d": d, "h": h, "pitch": pitch}


func _apply_pose(pose: Dictionary) -> void:
	var yaw := deg_to_rad(float(pose["yaw"]))
	var pitch := deg_to_rad(float(pose["pitch"]))
	var off_f := GRIP_FWD * cos(pitch) + GRIP_DOWN * sin(pitch)
	var off_h := GRIP_FWD * sin(pitch) - GRIP_DOWN * cos(pitch)
	var pivot := arm_lower.global_position
	var d := float(pose["d"]) - off_f
	var h := float(pose["h"]) - off_h - pivot.y
	var r := sqrt(d * d + h * h)
	r = clampf(r, 0.3, L1 + L2 - 0.01)
	var c2 := clampf((r * r - L1 * L1 - L2 * L2) / (2.0 * L1 * L2), -1.0, 1.0)
	var q2 := -acos(c2)
	var phi := atan2(h, d)
	var th1 := phi - atan2(L2 * sin(q2), L1 + L2 * cos(q2))
	turret.rotation.y = yaw
	# 吸盘架绕自身法线反转，保持组件始终纵向（长边沿坡面）
	effector_yaw.rotation.y = -yaw
	arm_lower.rotation.x = th1
	arm_upper.rotation.x = q2
	wrist.rotation.x = pitch - (th1 + q2)


func _handle_events(t: float) -> void:
	for ev in events:
		var et := float(ev["t"])
		if last_time < et and t >= et:
			if ev["action"] == "attach":
				_attach_panel(int(ev["index"]), et)
			elif ev["action"] == "detach":
				_detach_panel(et)


func _attach_panel(stack_index: int, t: float) -> void:
	if stack_index < stack_panels.size():
		stack_panels[stack_index].visible = false
	carried.visible = true
	attached = true
	var err := grip.global_position.distance_to(Vector3(ROBOT_X - sin(turret.rotation.y) * 1.8, 2.73 if stack_index == 4 else 2.61, robot.position.z + 1.8))
	print("[attach t=%.2f] carried on, grip=%s err=%.3f" % [t, str(grip.global_position), err])


func _detach_panel(t: float) -> void:
	carried.visible = false
	attached = false
	if placed_next < placed_panels.size():
		var p := placed_panels[placed_next]
		p.global_transform = grip.global_transform
		p.visible = true
		placed_next += 1
		install_count = placed_next
		var xf := p.global_transform
		var heights: Array[float] = []
		for c in [Vector3(-1.2, 0, -0.6), Vector3(1.2, 0, -0.6), Vector3(1.2, 0, 0.6), Vector3(-1.2, 0, 0.6)]:
			heights.append((xf * c).y)
		print("[detach t=%.2f] grip=%s normal=%s heights=%s" % [t, str(grip.global_position), str(xf.basis.y.normalized()), str(heights)])


func _update_camera(t: float) -> void:
	var sh: Dictionary = shots[shots.size() - 1]
	for s in shots:
		if t >= float(s["t0"]) and t < float(s["t1"]):
			sh = s
			break
	var span := maxf(float(sh["t1"]) - float(sh["t0"]), 0.001)
	var u := clampf((t - float(sh["t0"])) / span, 0.0, 1.0)
	var e := u * u * (3.0 - 2.0 * u)
	var pos := camera.global_position
	var target := Vector3.ZERO
	var fov := camera.fov
	if sh.get("orbit", false):
		var ang := lerpf(float(sh["a0"]), float(sh["a1"]), e)
		var rad := lerpf(float(sh["r0"]), float(sh["r1"]), e)
		var c: Vector3 = sh["c"]
		pos = c + Vector3(cos(ang) * rad, lerpf(float(sh["h0"]), float(sh["h1"]), e), sin(ang) * rad)
		target = sh["l"]
		fov = float(sh["f"])
	else:
		var p0: Vector3 = sh["p0"]
		var p1: Vector3 = sh["p1"]
		pos = p0.lerp(p1, e)
		if sh.get("follow", false):
			var loff: Vector3 = sh["loff"]
			target = grip.global_position + loff
		else:
			var l0: Vector3 = sh["l0"]
			var l1: Vector3 = sh["l1"]
			target = l0.lerp(l1, e)
		if sh.has("f0"):
			fov = lerpf(float(sh["f0"]), float(sh["f1"]), e)
		else:
			fov = float(sh["f"])
	camera.global_position = pos
	camera.fov = fov
	camera.look_at(target, Vector3.UP)


func _update_hud(t: float) -> void:
	if hud == null:
		return
	hud.align_dx = align_dx
	hud.align_dz = align_dz
	hud.align_dtheta = align_dtheta
	hud.align_progress = align_progress
	hud.align_locked = align_locked
	hud.install_count = install_count
	hud.show_brackets = attached and t > 45.0 and t < 56.8
	hud.refresh(t)


func apply_time(t: float) -> void:
	robot.position.z = _chassis_z(t)
	for meta in cloud_meta:
		var node3d: Node3D = meta["node"]
		var base: Vector3 = meta["base"]
		node3d.position = Vector3(base.x + fmod(t * 0.35, 160.0), base.y, base.z)
	var pose := _pose_at(t)
	_apply_pose(pose)
	_handle_events(t)
	_update_camera(t)
	_update_hud(t)
	last_time = t
