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
var trailer: Node3D
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
var wheel_nodes: Array[Node3D] = []
var track_treads: Array[Dictionary] = []
var travel_dust: CPUParticles3D
var impact_dust: CPUParticles3D

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
var camera_style := "CLASSIC"
var audit_mode := false


func _ready() -> void:
	still_mode = OS.has_environment("STILL_T")
	camera_style = "CLASSIC"
	audit_mode = OS.has_environment("CAMERA_AUDIT")
	_load_timeline()
	_build_environment()
	_build_ground()
	_build_arrays()
	_build_props()
	_build_robot()
	_build_camera()
	_build_post()
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
		{"t": 26.4, "yaw": 0.0, "d": 3.4, "h": 4.15, "pitch": 0.0},
		{"t": 27.6, "yaw": 0.0, "d": 4.7, "h": 4.3, "pitch": 10.0},
		{"t": 28.6, "yaw": 0.0, "d": 5.0, "h": 4.3, "pitch": 25.0},
		{"t": 29.7, "yaw": 0.0, "d": 5.1, "h": 2.544, "pitch": 25.0},
		{"t": 30.9, "yaw": 0.0, "d": 5.05, "h": 3.8, "pitch": 25.0},
		{"t": 32.4, "yaw": 25.0, "d": 4.9, "h": 4.6, "pitch": 12.0},
		{"t": 35.66, "yaw": 70.0, "d": 4.8, "h": 4.62, "pitch": 0.0},
		{"t": 38.8, "yaw": 85.0, "d": 3.9, "h": 4.7, "pitch": 0.0},
		{"t": 40.4, "yaw": 90.0, "d": 3.3, "h": 4.62, "pitch": 0.0},
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
		{"t": 65.9, "yaw": 50.0, "d": 3.4, "h": 2.9, "pitch": 0.0},
		{"t": 67.0, "yaw": 0.0, "d": 3.4, "h": 2.9, "pitch": 0.0},
		{"t": 68.0, "yaw": 0.0, "d": 3.4, "h": 4.0, "pitch": 10.0},
		{"t": 69.0, "yaw": 0.0, "d": 4.7, "h": 4.25, "pitch": 20.0},
		{"t": 69.6, "yaw": 0.0, "d": 5.05, "h": 4.0, "pitch": 25.0},
		{"t": 70.2, "yaw": 0.0, "d": 5.155, "h": 2.426, "pitch": 25.0},
		{"t": 71.1, "yaw": 0.0, "d": 5.05, "h": 3.7, "pitch": 25.0},
		{"t": 71.9, "yaw": 25.0, "d": 4.7, "h": 4.4, "pitch": 12.0},
		{"t": 72.6, "yaw": 70.0, "d": 3.6, "h": 4.4, "pitch": 0.0},
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
		{"t": 29.7, "action": "attach", "index": 4},
		{"t": 57.0, "action": "detach"},
		{"t": 70.2, "action": "attach", "index": 3},
		{"t": 74.9, "action": "detach"},
	]
	shots = _shots_classic()


func _shots_classic() -> Array:
	return [
		{"t0": 0.0, "t1": 8.0, "p0": Vector3(23, 8, 0.0), "p1": Vector3(17, 5.5, 2.5),
		 "l0": Vector3(2.0, 1.5, 7.0), "l1": Vector3(2.2, 1.7, 7.0), "f0": 40.0, "f1": 37.0},
		{"t0": 8.0, "t1": 23.66, "orbit": true, "c": Vector3(3.8, 0, 7.2),
		 "r0": 15.5, "r1": 13.5, "a0": deg_to_rad(-45.0), "a1": deg_to_rad(15.0),
		 "h0": 5.2, "h1": 4.1, "l": Vector3(3.2, 1.9, 7.4), "f": 38.0},
		{"t0": 23.66, "t1": 35.66, "p0": Vector3(12.0, 2.4, 5.8), "p1": Vector3(13.8, 6.0, 2.4),
		 "l0": Vector3(3.8, 1.8, 4.9), "l1": Vector3(3.8, 3.5, 4.7), "f0": 42.0, "f1": 42.0},
		{"t0": 35.66, "t1": 44.68, "p0": Vector3(10.5, 7.5, 1.0), "p1": Vector3(9.0, 6.8, 5.5),
		 "follow": true, "loff": Vector3(0, 0.1, 0), "f": 40.0},
		{"t0": 44.68, "t1": 55.68, "p0": Vector3(2.2, 3.3, 5.9), "p1": Vector3(1.9, 3.1, 6.3),
		 "l0": Vector3(0.4, 1.85, 10.0), "l1": Vector3(0.35, 1.8, 10.0), "f0": 33.0, "f1": 32.0},
		{"t0": 55.68, "t1": 64.68, "p0": Vector3(3.4, 4.0, 4.8), "p1": Vector3(3.0, 3.7, 5.2),
		 "l0": Vector3(0.4, 1.55, 10.0), "l1": Vector3(0.4, 1.5, 10.0), "f0": 33.0, "f1": 33.0},
		{"t0": 64.68, "t1": 71.0, "p0": Vector3(15.0, 6.6, 3.2), "p1": Vector3(13.2, 6.0, 3.8),
		 "l0": Vector3(3.8, 2.2, 4.5), "l1": Vector3(3.8, 2.4, 4.3), "f0": 40.0, "f1": 40.0},
		{"t0": 71.0, "t1": 74.8, "p0": Vector3(13.0, 6.8, 4.6), "p1": Vector3(9.0, 5.8, 11.0),
		 "follow": true, "loff": Vector3(0, 0.1, 0), "f": 40.0},
		{"t0": 74.8, "t1": 77.2, "p0": Vector3(3.3, 4.2, 3.7), "p1": Vector3(3.1, 4.0, 4.1),
		 "l0": Vector3(0.2, 1.55, 8.85), "l1": Vector3(0.2, 1.5, 8.8), "f0": 33.0, "f1": 33.0},
		{"t0": 77.2, "t1": 87.68, "p0": Vector3(23, 10, 2), "p1": Vector3(32, 14, -4),
		 "l0": Vector3(2, 1.5, 7), "l1": Vector3(2, 1.5, 7), "f0": 40.0, "f1": 42.0},
	]


# ---------------------------------------------------------------- 环境
func _build_environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("#3f7fb0")
	sky_mat.sky_horizon_color = Color("#f2c58f")
	sky_mat.ground_bottom_color = Color("#7a5c3a")
	sky_mat.ground_horizon_color = Color("#d8b47c")
	sky_mat.sun_angle_max = 3.0
	sky_mat.sky_energy_multiplier = 0.85
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_color = Color("#9fb6cc")
	env.ambient_light_energy = 0.48
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.12
	env.adjustment_enabled = true
	env.adjustment_brightness = 1.0
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.04
	env.ssao_enabled = true
	env.ssao_radius = 1.25
	env.ssao_intensity = 1.15
	env.ssao_detail = 0.35
	env.glow_enabled = true
	env.glow_intensity = 0.22
	env.glow_bloom = 0.025
	env.glow_hdr_threshold = 1.05
	env.fog_enabled = true
	env.fog_light_color = Color("#e8c58f")
	env.fog_light_energy = 0.55
	env.fog_sun_scatter = 0.12
	env.fog_density = 0.0038
	env.fog_sky_affect = 0.18
	env.fog_height = 1.0
	env.fog_height_density = 0.08
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = Color("#ffd39a")
	sun.light_energy = 1.65
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 120.0
	sun.shadow_bias = 0.02
	sun.shadow_normal_bias = 0.45
	add_child(sun)
	sun.look_at_from_position(Vector3(58, 30, 38), Vector3(3.8, 0, 10))

	var fill := DirectionalLight3D.new()
	fill.light_color = Color("#a9c9ee")
	fill.light_energy = 0.38
	fill.shadow_enabled = false
	add_child(fill)
	fill.look_at_from_position(Vector3(25, 18, 55), Vector3(0, 0, 0))

	var rim := DirectionalLight3D.new()
	rim.light_color = Color("#9fc7ff")
	rim.light_energy = 0.42
	rim.shadow_enabled = false
	add_child(rim)
	rim.look_at_from_position(Vector3(-35, 22, -30), Vector3(3.8, 1.5, 7))

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
	mat.uv1_scale = Vector3(55, 55, 1)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.normal_enabled = true
	mat.normal_texture = load("res://assets/textures/sand_normal.png")
	mat.normal_scale = 0.45
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

	# 换位车辙：两条透明胎纹，跟随实际 1.25m 位移
	var tracks := MeshInstance3D.new()
	var tm := PlaneMesh.new()
	tm.size = Vector2(2.6, 3.2)
	tracks.mesh = tm
	var tmat := StandardMaterial3D.new()
	tmat.albedo_texture = load("res://assets/textures/track.png")
	tmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tmat.albedo_color = Color(0.55, 0.42, 0.25, 0.55)
	tmat.roughness = 1.0
	tracks.material_override = tmat
	tracks.position = Vector3(ROBOT_X, 0.025, 9.55)
	add_child(tracks)


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

	# 随行料车：挂在控制柜相反的一端（−z），整台随机器人换位
	trailer = load("res://assets/models/panel_trailer.glb").instantiate()
	trailer.position = Vector3(0, 0, -5.582)
	trailer.rotation_degrees.y = 180.0
	robot.add_child(trailer)
	_nearest_materials(trailer)
	for n in trailer.find_children("Wheel_*", "Node3D", true, false):
		wheel_nodes.append(n as Node3D)
	for n in robot.find_children("TrackTread_*", "Node3D", true, false):
		track_treads.append({"node": n as Node3D, "base": (n as Node3D).position.z})
	travel_dust = _make_dust(robot, Vector3(0, 0.18, 2.0), 36)
	impact_dust = _make_dust(self, Vector3.ZERO, 28)

	# 倾斜料鼓上的组件（Godot 生成，便于逐块拾取/隐藏）
	var tilt := deg_to_rad(25.0)
	for i in 5:
		var p := panel_scene.instantiate()
		trailer.add_child(p)
		var off := 0.2 + 0.13 * i
		p.position = Vector3(0, 1.892 + cos(tilt) * off, -0.177 - sin(tilt) * off)
		p.rotation.x = -tilt
		_nearest_materials(p)
		stack_panels.append(p)

	carried = panel_scene.instantiate()
	grip.add_child(carried)
	carried.position = Vector3.ZERO
	carried.visible = false
	_nearest_materials(carried)


func _make_dust(parent: Node3D, pos: Vector3, amount: int) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.position = pos
	p.amount = amount
	p.lifetime = 1.1
	p.emitting = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(0.9, 0.08, 0.25)
	p.direction = Vector3(0, 0.35, 1)
	p.spread = 28.0
	p.gravity = Vector3(0, 0.15, 0)
	p.initial_velocity_min = 0.25
	p.initial_velocity_max = 0.8
	p.scale_amount_min = 0.35
	p.scale_amount_max = 1.1
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.35, 0.35)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.72, 0.57, 0.36, 0.28)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh.material = mat
	p.mesh = mesh
	parent.add_child(p)
	return p


func _build_camera() -> void:
	camera = Camera3D.new()
	camera.fov = 36.0
	camera.near = 0.1
	camera.far = 700.0
	camera.current = true
	add_child(camera)


func _build_post() -> void:
	# 独立低层 CanvasLayer：只给 3D 画面加暗角/颗粒/暖调，HUD 保持干净。
	var layer := CanvasLayer.new()
	layer.layer = -1
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color.WHITE
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/cinematic.gdshader")
	rect.material = mat
	layer.add_child(rect)


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
		"arm": arm_lower,
		"effector": effector,
		"vision": vision_node,
		"stack": stack_panels[2] if stack_panels.size() > 2 else chassis,
		"trailer": trailer.find_child("Drum", true, false),
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
	var err := 0.0
	if stack_index < stack_panels.size():
		err = grip.global_position.distance_to(stack_panels[stack_index].global_position)
		stack_panels[stack_index].visible = false
	carried.visible = true
	attached = true
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


func _ease(u: float, mode: String) -> float:
	match mode:
		"linear":
			return u
		"out":
			return 1.0 - pow(1.0 - u, 3.0)
		"in":
			return u * u * u
		"sine":
			return 0.5 - 0.5 * cos(PI * u)
		_:
			return u * u * (3.0 - 2.0 * u)


func _update_camera(t: float) -> void:
	var sh: Dictionary = shots[shots.size() - 1]
	for s in shots:
		if t >= float(s["t0"]) and t < float(s["t1"]):
			sh = s
			break
	var span := maxf(float(sh["t1"]) - float(sh["t0"]), 0.001)
	var u := clampf((t - float(sh["t0"])) / span, 0.0, 1.0)
	var hold := float(sh.get("hold", 0.0))
	var e := 1.0 if hold > 0.0 and u >= 1.0 - hold else _ease(u, String(sh.get("ease", "smooth")))
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
	elif sh.get("follow", false):
		var loff: Vector3 = sh["loff"]
		target = grip.global_position + loff
		if sh.has("offset"):
			pos = grip.global_position + Vector3(sh["offset"])
		else:
			pos = Vector3(sh["p0"]).lerp(Vector3(sh["p1"]), e)
		fov = float(sh["f"])
	else:
		pos = Vector3(sh["p0"]).lerp(Vector3(sh["p1"]), e)
		target = Vector3(sh["l0"]).lerp(Vector3(sh["l1"]), e)
		if sh.has("f0"):
			fov = lerpf(float(sh["f0"]), float(sh["f1"]), e)
		else:
			fov = float(sh["f"])
	camera.global_position = pos
	camera.fov = fov
	camera.look_at(target, Vector3.UP)


func _active_panel_for_audit(t: float) -> Node3D:
	if t < 29.7:
		return stack_panels[4]
	if t < 57.0:
		return carried if carried.visible else placed_panels[0]
	if t < 68.0:
		return placed_panels[0]
	if t < 70.2:
		return stack_panels[3]
	if t < 74.9:
		return carried
	return placed_panels[1]


func _ray_aabb_t(o: Vector3, d: Vector3, b: AABB) -> float:
	var tmin := 0.0
	var tmax := 1.0
	for axis in range(3):
		var orig := o[axis]
		var dir := d[axis]
		var mn := b.position[axis]
		var mx := b.end[axis]
		if absf(dir) < 0.00001:
			if orig < mn or orig > mx:
				return -1.0
		else:
			var t1 := (mn - orig) / dir
			var t2 := (mx - orig) / dir
			tmin = maxf(tmin, minf(t1, t2))
			tmax = minf(tmax, maxf(t1, t2))
			if tmin > tmax:
				return -1.0
	return tmin


func _audit_point(label: String, node: Node3D, exclude_root: Node3D, t: float) -> void:
	if node == null:
		return
	var wp := node.global_position
	var sp := camera.unproject_position(wp)
	var vp := get_viewport().get_visible_rect().size
	var in_frame := sp.x >= vp.x * 0.05 and sp.x <= vp.x * 0.95 and sp.y >= vp.y * 0.05 and sp.y <= vp.y * 0.95 and not camera.is_position_behind(wp)
	var occluded := false
	if in_frame:
		var from := camera.global_position
		var delta := wp - from
		for n in find_children("*", "MeshInstance3D", true, false):
			if n == exclude_root or (exclude_root != null and exclude_root.is_ancestor_of(n)):
				continue
			if not n.is_visible_in_tree() or n.mesh == null or n.mesh is PlaneMesh:
				continue
			if n.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				continue
			var aabb: AABB = n.global_transform * n.mesh.get_aabb()
			var hit := _ray_aabb_t(from, delta, aabb)
			if hit > 0.01 and hit < 0.97:
				occluded = true
				break
	print("[cam-audit] style=%s t=%.2f node=%s screen=(%.0f,%.0f) in_frame=%s occluded=%s" % [
		camera_style, t, label, sp.x, sp.y, str(in_frame).to_lower(), str(occluded).to_lower()])


func _camera_audit(t: float) -> void:
	var panel := _active_panel_for_audit(t)
	var target := placed_panels[0] if t < 68.0 else placed_panels[1]
	_audit_point("grip", grip, effector, t)
	_audit_point("panel", panel, panel, t)
	_audit_point("target", target, target, t)
	_audit_point("body", chassis, chassis, t)


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
	var z := _chassis_z(t)
	robot.position.z = z
	var moving := t > 66.2 and t < 67.8
	var move_u := clampf((t - 66.2) / 1.6, 0.0, 1.0)
	var move_env := sin(move_u * PI)
	robot.position.y = sin(t * 18.0) * 0.008 * move_env
	trailer.rotation.y = PI + sin((t - 66.2) * 5.0) * 0.018 * move_env
	for w in wheel_nodes:
		w.rotation.x = (z - SLOT_Z0) / 0.36
	var tread_shift := (SLOT_Z0 - z) * 1.8
	for item in track_treads:
		var n: Node3D = item["node"]
		n.position.z = wrapf(float(item["base"]) + tread_shift, -2.1, 2.1)
	travel_dust.emitting = moving
	for meta in cloud_meta:
		var node3d: Node3D = meta["node"]
		var base: Vector3 = meta["base"]
		node3d.position = Vector3(base.x + fmod(t * 0.35, 160.0), base.y, base.z)
	var pose := _pose_at(t)
	_apply_pose(pose)
	_handle_events(t)
	var impact := (t >= 57.0 and t < 57.35) or (t >= 74.9 and t < 75.25)
	impact_dust.emitting = impact
	if impact:
		impact_dust.global_position = grip.global_position + Vector3(0, -0.55, 0)
	_update_camera(t)
	if audit_mode:
		if not still_mode or absf(t - float(OS.get_environment("STILL_T"))) < 0.001:
			_camera_audit(t)
	_update_hud(t)
	last_time = t
