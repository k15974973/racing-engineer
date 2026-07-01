extends PanelContainer

const VIEWPORT_SIZE := Vector2i(720, 320)
const CYLINDER_COLOR := Color(0.35, 0.78, 0.92, 0.34)
const PISTON_COLOR := Color(1.0, 0.38, 0.18, 0.78)
const FUEL_COLOR := Color(0.98, 0.84, 0.18, 0.78)
const AIR_COLOR := Color(0.18, 0.75, 0.92, 0.64)
const EXHAUST_COLOR := Color(1.0, 0.42, 0.18, 0.54)
const STEEL_COLOR := Color(0.74, 0.78, 0.82, 0.48)
const BRIGHT_STEEL_COLOR := Color(0.88, 0.92, 0.96, 0.82)
const DARK_STEEL_COLOR := Color(0.18, 0.22, 0.28, 0.70)
const COVER_COLOR := Color(0.04, 0.05, 0.06, 0.86)
const RUBBER_COLOR := Color(0.02, 0.025, 0.03, 0.88)

var _setup: Dictionary = {}
var _visual_state: Dictionary = {}
var _viewport: SubViewport
var _scene_root: Node3D
var _engine_root: Node3D
var _pistons: Array[Node3D] = []
var _cams: Array[Node3D] = []
var _spinners: Array[Node3D] = []
var _time := 0.0

func _init() -> void:
	custom_minimum_size = Vector2(0, 360)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_stylebox_override("panel", _panel_style())

func _ready() -> void:
	_build_shell()
	_rebuild_engine()

func set_setup(setup: Dictionary) -> void:
	_setup = setup.duplicate(true)
	if _scene_root != null:
		_rebuild_engine()

func get_visual_state() -> Dictionary:
	return _visual_state.duplicate(true)

func get_render_image() -> Image:
	if _viewport == null:
		return null
	if DisplayServer.get_name() == "headless":
		return null
	return _viewport.get_texture().get_image()

func _process(delta: float) -> void:
	_time += delta
	if _engine_root != null:
		_engine_root.rotation_degrees.y = sin(_time * 0.35) * 5.0

	for index in _pistons.size():
		var piston := _pistons[index]
		if not is_instance_valid(piston):
			continue
		piston.position.y = 0.12 + sin(_time * 5.8 + float(index) * 1.35) * 0.18

	for cam in _cams:
		if is_instance_valid(cam):
			cam.rotation_degrees.x += delta * 155.0

	for spinner in _spinners:
		if is_instance_valid(spinner):
			spinner.rotation_degrees.z += delta * 420.0

func _build_shell() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)

	var title := Label.new()
	title.text = "Live Engine Model"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color.html("#F8FAFC"))
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	stack.add_child(title)

	var note := Label.new()
	note.text = "Tuning sliders reshape chamber, intake, fuel rail, and rotating parts in real time."
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", Color.html("#CBD5E1"))
	note.autowrap_mode = TextServer.AUTOWRAP_OFF
	note.clip_text = true
	stack.add_child(note)

	var viewport_container := SubViewportContainer.new()
	viewport_container.stretch = true
	viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_container.custom_minimum_size = Vector2(0, 270)
	stack.add_child(viewport_container)

	_viewport = SubViewport.new()
	_viewport.size = VIEWPORT_SIZE
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(_viewport)

	_scene_root = Node3D.new()
	_viewport.add_child(_scene_root)

	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.html("#07111F")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.html("#20384A")
	env.ambient_light_energy = 0.55
	environment.environment = env
	_scene_root.add_child(environment)

	var camera := Camera3D.new()
	camera.position = Vector3(5.7, 3.4, 7.6)
	camera.fov = 50.0
	camera.current = true
	_scene_root.add_child(camera)
	camera.look_at(Vector3(0.0, 0.45, 0.0), Vector3.UP)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-46.0, -34.0, 0.0)
	key_light.light_energy = 1.4
	_scene_root.add_child(key_light)

	var fill_light := OmniLight3D.new()
	fill_light.position = Vector3(-2.8, 2.8, 3.2)
	fill_light.light_energy = 1.9
	fill_light.omni_range = 8.0
	_scene_root.add_child(fill_light)

	_scene_root.add_child(_box("base_grid", Vector3(0.0, -0.46, 0.0), Vector3(4.9, 0.015, 2.6), Color(0.24, 0.36, 0.46, 0.26)))

func _rebuild_engine() -> void:
	if _scene_root == null:
		return

	if is_instance_valid(_engine_root):
		_engine_root.queue_free()

	_pistons.clear()
	_cams.clear()
	_spinners.clear()
	_engine_root = Node3D.new()
	_scene_root.add_child(_engine_root)

	if _setup.has("error") or _setup.is_empty():
		_visual_state = {"valid": false}
		_engine_root.add_child(_box("placeholder_block", Vector3.ZERO, Vector3(2.0, 0.7, 1.0), Color(0.45, 0.53, 0.62, 0.28)))
		return

	var block: Dictionary = _setup.get("block", {})
	var induction: Dictionary = _setup.get("induction", {})
	var material: Dictionary = _setup.get("material", {})
	var tuning: Dictionary = _setup.get("tuning", {})
	var block_id := str(block.get("id", ""))
	var induction_id := str(induction.get("id", ""))
	var compression := clampf(float(tuning.get("compression", 10.5)), 8.0, 14.0)
	var boost := clampf(float(tuning.get("boost", 0.0)), 0.0, 3.0)
	var fuel_map := clampf(float(tuning.get("fuel_map", 0.0)), -10.0, 10.0)
	var ignition_timing := clampf(float(tuning.get("ignition_timing", 0.0)), -8.0, 8.0)
	var power_mult := float(induction.get("power_mult", 1.0))
	var cylinder_count := _cylinder_count(block_id)
	var chamber_scale := clampf(0.82 + ((compression - 8.0) / 6.0) * 0.40, 0.82, 1.22)
	var intake_scale := clampf(1.0 + boost * 0.18 + maxf(0.0, power_mult - 1.0) * 0.25, 0.9, 1.9)
	var fuel_scale := clampf(1.0 + fuel_map * 0.035, 0.68, 1.36)
	var spark_shift := ignition_timing * 0.025
	var material_mass_scale := clampf(float(material.get("mass_mult", 1.0)), 0.72, 1.14)
	var forced := induction_id != "na"

	if block_id == "rotary":
		_build_rotary(chamber_scale, intake_scale, fuel_scale, forced)
	else:
		_build_piston_engine(block_id, cylinder_count, chamber_scale, intake_scale, fuel_scale, material_mass_scale, spark_shift)

	_build_induction(induction_id, intake_scale, forced)
	_build_blueprint_frame()

	_visual_state = {
		"valid": true,
		"block_id": block_id,
		"induction_id": induction_id,
		"material_id": str(material.get("id", "")),
		"cylinder_count": cylinder_count,
		"piston_nodes": _pistons.size(),
		"chamber_scale": snappedf(chamber_scale, 0.001),
		"intake_scale": snappedf(intake_scale, 0.001),
		"fuel_scale": snappedf(fuel_scale, 0.001),
		"spark_shift": snappedf(spark_shift, 0.001),
		"has_forced_induction": forced,
		"visual_nodes": _engine_root.get_child_count()
	}

func _build_piston_engine(block_id: String, cylinder_count: int, chamber_scale: float, intake_scale: float, fuel_scale: float, material_mass_scale: float, spark_shift: float) -> void:
	var banks := 1
	if block_id == "v6" or block_id == "v8" or block_id == "boxer_4":
		banks = 2

	var cylinders_per_bank := int(ceil(float(cylinder_count) / float(banks)))
	var spacing := 0.58
	var block_width := maxf(1.8, float(cylinders_per_bank) * spacing + 0.35)
	var block_depth := 0.92 if banks == 1 else 1.45
	var block_height := 0.62 * chamber_scale
	_engine_root.add_child(_box("engine_block", Vector3(0.0, -0.03, 0.0), Vector3(block_width, block_height, block_depth) * material_mass_scale, DARK_STEEL_COLOR))
	_engine_root.add_child(_box("transparent_outline", Vector3(0.0, 0.18, 0.0), Vector3(block_width + 0.18, 0.88 * chamber_scale, block_depth + 0.15), Color(0.38, 0.78, 0.95, 0.14)))
	_build_valve_covers(block_id, banks, cylinders_per_bank, block_width, block_depth, chamber_scale)

	var built := 0
	for bank in banks:
		var z := 0.0
		var bank_tilt := 0.0
		var intake_z := 0.72
		var exhaust_z := -0.76
		if banks == 2:
			z = -0.38 if bank == 0 else 0.38
			bank_tilt = 12.0 if bank == 0 else -12.0
			intake_z = 0.0
			exhaust_z = -0.98 if bank == 0 else 0.98
			if block_id == "boxer_4":
				bank_tilt = 80.0 if bank == 0 else -80.0
				intake_z = 0.0
				exhaust_z = -1.08 if bank == 0 else 1.08

		for i in cylinders_per_bank:
			if built >= cylinder_count:
				break
			var x := (float(i) - float(cylinders_per_bank - 1) * 0.5) * spacing
			var sleeve := _cylinder("cylinder_%s" % built, Vector3(x, 0.37, z), 0.16 * chamber_scale, 0.72 * chamber_scale, CYLINDER_COLOR, Vector3(bank_tilt, 0.0, 0.0))
			_engine_root.add_child(sleeve)

			var piston := _cylinder("piston_%s" % built, Vector3(x, 0.13, z), 0.128 * chamber_scale, 0.13, PISTON_COLOR, Vector3(bank_tilt, 0.0, 0.0))
			_engine_root.add_child(piston)
			_pistons.append(piston)

			var spark := _cylinder("spark_%s" % built, Vector3(x + spark_shift, 0.82 * chamber_scale, z), 0.025, 0.24, Color(0.95, 0.97, 1.0, 0.72), Vector3(0.0, 0.0, 0.0))
			_engine_root.add_child(spark)
			_engine_root.add_child(_box("coil_%s" % built, Vector3(x + spark_shift, 0.96 * chamber_scale, z), Vector3(0.12, 0.055, 0.10), COVER_COLOR))
			_build_intake_runner(built, Vector3(x, 0.72 * chamber_scale, intake_z), Vector3(x, 0.70 * chamber_scale, z), intake_scale)
			_build_exhaust_runner(built, Vector3(x, 0.48 * chamber_scale, z), Vector3(x, 0.22, exhaust_z), block_width)
			built += 1

	var fuel_rail := _cylinder("fuel_rail", Vector3(0.0, 0.98 * chamber_scale, -0.58), 0.045 * fuel_scale, block_width * 0.9, FUEL_COLOR, Vector3(0.0, 0.0, 90.0))
	_engine_root.add_child(fuel_rail)

	var intake := _cylinder("intake_plenum", Vector3(0.0, 0.76 * chamber_scale, 0.78), 0.095 * intake_scale, block_width * 0.95, AIR_COLOR, Vector3(0.0, 0.0, 90.0))
	_engine_root.add_child(intake)

	var exhaust := _cylinder("exhaust_header", Vector3(0.0, 0.52 * chamber_scale, -0.86), 0.055, block_width * 0.95, EXHAUST_COLOR, Vector3(0.0, 0.0, 90.0))
	_engine_root.add_child(exhaust)

	var cam := _cylinder("cam_rail", Vector3(0.0, 1.08 * chamber_scale, 0.0), 0.045, block_width * 0.93, STEEL_COLOR, Vector3(0.0, 0.0, 90.0))
	_engine_root.add_child(cam)
	_cams.append(cam)

	var crank := _cylinder("crankshaft", Vector3(0.0, -0.35, 0.0), 0.055, block_width * 0.95, STEEL_COLOR, Vector3(0.0, 0.0, 90.0))
	_engine_root.add_child(crank)
	_cams.append(crank)

	var front_x := -block_width * 0.5 - 0.18
	var crank_pulley := _cylinder("crank_pulley", Vector3(front_x, -0.35, 0.0), 0.18, 0.08, STEEL_COLOR, Vector3(90.0, 0.0, 0.0))
	_engine_root.add_child(crank_pulley)
	_spinners.append(crank_pulley)
	var cam_pulley := _cylinder("cam_pulley", Vector3(front_x, 1.08 * chamber_scale, 0.0), 0.13, 0.07, STEEL_COLOR, Vector3(90.0, 0.0, 0.0))
	_engine_root.add_child(cam_pulley)
	_spinners.append(cam_pulley)
	_engine_root.add_child(_box("belt_run_left", Vector3(front_x, 0.35, -0.14), Vector3(0.025, 1.32 * chamber_scale, 0.025), Color(0.05, 0.07, 0.09, 0.74)))
	_engine_root.add_child(_box("belt_run_right", Vector3(front_x, 0.35, 0.14), Vector3(0.025, 1.32 * chamber_scale, 0.025), Color(0.05, 0.07, 0.09, 0.74)))
	_build_front_cover_detail(front_x, chamber_scale, block_depth)

func _build_valve_covers(block_id: String, banks: int, cylinders_per_bank: int, block_width: float, block_depth: float, chamber_scale: float) -> void:
	if banks == 1:
		var cover := _box("valve_cover_inline", Vector3(0.0, 1.12 * chamber_scale, 0.0), Vector3(block_width * 0.86, 0.18, block_depth * 0.48), COVER_COLOR)
		_engine_root.add_child(cover)
		_build_bolt_row("inline_cover_left", -block_width * 0.36, block_width * 0.36, cylinders_per_bank + 1, 1.23 * chamber_scale, -block_depth * 0.24)
		_build_bolt_row("inline_cover_right", -block_width * 0.36, block_width * 0.36, cylinders_per_bank + 1, 1.23 * chamber_scale, block_depth * 0.24)
		return

	for bank in banks:
		var z := -0.46 if bank == 0 else 0.46
		var tilt := 11.0 if bank == 0 else -11.0
		if block_id == "boxer_4":
			z = -0.72 if bank == 0 else 0.72
			tilt = 0.0
		var cover := _box("valve_cover_%s" % bank, Vector3(0.0, 1.08 * chamber_scale, z), Vector3(block_width * 0.82, 0.16, 0.34), COVER_COLOR)
		cover.rotation_degrees.x = tilt
		_engine_root.add_child(cover)
		_build_bolt_row("cover_%s_inner" % bank, -block_width * 0.34, block_width * 0.34, cylinders_per_bank + 1, 1.18 * chamber_scale, z - 0.17)
		_build_bolt_row("cover_%s_outer" % bank, -block_width * 0.34, block_width * 0.34, cylinders_per_bank + 1, 1.18 * chamber_scale, z + 0.17)

func _build_bolt_row(prefix: String, start_x: float, end_x: float, count: int, y: float, z: float) -> void:
	var safe_count: int = maxi(count, 2)
	for i in safe_count:
		var t := float(i) / float(safe_count - 1)
		var x := lerpf(start_x, end_x, t)
		_engine_root.add_child(_sphere("%s_bolt_%s" % [prefix, i], Vector3(x, y, z), 0.032, BRIGHT_STEEL_COLOR, 12, 6))

func _build_intake_runner(index: int, from_pos: Vector3, to_pos: Vector3, intake_scale: float) -> void:
	var high := Vector3((from_pos.x + to_pos.x) * 0.5, maxf(from_pos.y, to_pos.y) + 0.18, from_pos.z)
	var near_head := Vector3(to_pos.x, to_pos.y + 0.08, to_pos.z)
	var radius := 0.026 * intake_scale
	_engine_root.add_child(_pipe_between("intake_runner_%s_a" % index, from_pos, high, radius, AIR_COLOR, 12))
	_engine_root.add_child(_pipe_between("intake_runner_%s_b" % index, high, near_head, radius, AIR_COLOR, 12))
	_engine_root.add_child(_sphere("intake_runner_%s_elbow" % index, high, radius * 1.35, AIR_COLOR, 12, 6))

func _build_exhaust_runner(index: int, from_pos: Vector3, outside_pos: Vector3, block_width: float) -> void:
	var drop := Vector3(from_pos.x, from_pos.y - 0.18, outside_pos.z * 0.72)
	var sweep_x := block_width * 0.50 + 0.34
	var collector := Vector3(sweep_x, 0.02 + float(index % 2) * 0.035, outside_pos.z)
	var radius := 0.045
	_engine_root.add_child(_pipe_between("header_%s_a" % index, from_pos, drop, radius, EXHAUST_COLOR, 16))
	_engine_root.add_child(_pipe_between("header_%s_b" % index, drop, outside_pos, radius, EXHAUST_COLOR, 16))
	_engine_root.add_child(_pipe_between("header_%s_c" % index, outside_pos, collector, radius, EXHAUST_COLOR, 16))
	_engine_root.add_child(_sphere("header_%s_elbow_a" % index, drop, radius * 1.25, EXHAUST_COLOR, 12, 6))
	_engine_root.add_child(_sphere("header_%s_elbow_b" % index, outside_pos, radius * 1.25, EXHAUST_COLOR, 12, 6))
	if index % 2 == 0:
		_engine_root.add_child(_cylinder("collector_%s" % index, collector + Vector3(0.18, -0.02, 0.0), 0.08, 0.38, EXHAUST_COLOR, Vector3(0.0, 0.0, 90.0), 18))

func _build_front_cover_detail(front_x: float, chamber_scale: float, block_depth: float) -> void:
	var cover := _box("timing_cover", Vector3(front_x - 0.04, 0.22, 0.0), Vector3(0.10, 0.92 * chamber_scale, block_depth * 0.58), Color(0.52, 0.60, 0.68, 0.58))
	_engine_root.add_child(cover)
	for i in 10:
		var angle := TAU * float(i) / 10.0
		var z := cos(angle) * block_depth * 0.32
		var y := 0.20 + sin(angle) * 0.38 * chamber_scale
		_engine_root.add_child(_sphere("timing_bolt_%s" % i, Vector3(front_x - 0.105, y, z), 0.026, BRIGHT_STEEL_COLOR, 10, 5))

	var flywheel := _cylinder("flywheel", Vector3(front_x - 0.20, -0.17, 0.48), 0.34, 0.10, Color(0.76, 0.82, 0.88, 0.78), Vector3(90.0, 0.0, 0.0), 48)
	_engine_root.add_child(flywheel)
	_spinners.append(flywheel)
	for i in 24:
		var angle := TAU * float(i) / 24.0
		var y := -0.17 + sin(angle) * 0.34
		var z := 0.48 + cos(angle) * 0.34
		var tooth := _box("flywheel_tooth_%s" % i, Vector3(front_x - 0.27, y, z), Vector3(0.035, 0.018, 0.055), BRIGHT_STEEL_COLOR)
		tooth.rotation_degrees.x = rad_to_deg(angle)
		_engine_root.add_child(tooth)

func _build_rotary(chamber_scale: float, intake_scale: float, fuel_scale: float, forced: bool) -> void:
	_engine_root.add_child(_box("rotary_housing", Vector3(0.0, 0.05, 0.0), Vector3(1.9 * chamber_scale, 0.78 * chamber_scale, 1.0), DARK_STEEL_COLOR))
	for i in 2:
		var x := -0.45 if i == 0 else 0.45
		var rotor := _cylinder("rotor_%s" % i, Vector3(x, 0.16, 0.0), 0.31 * chamber_scale, 0.22, Color(1.0, 0.48, 0.18, 0.72), Vector3(90.0, 0.0, 0.0), 3)
		_engine_root.add_child(rotor)
		_spinners.append(rotor)
		_pistons.append(rotor)

	_engine_root.add_child(_cylinder("rotary_intake", Vector3(0.0, 0.78, 0.72), 0.12 * intake_scale, 1.5, AIR_COLOR, Vector3(0.0, 0.0, 90.0)))
	_engine_root.add_child(_cylinder("rotary_fuel", Vector3(0.0, 0.96, -0.48), 0.04 * fuel_scale, 1.35, FUEL_COLOR, Vector3(0.0, 0.0, 90.0)))
	_engine_root.add_child(_cylinder("rotary_exhaust", Vector3(0.0, 0.42, -0.78), 0.07, 1.35, EXHAUST_COLOR, Vector3(0.0, 0.0, 90.0)))
	var eccentric_shaft := _cylinder("eccentric_shaft", Vector3(0.0, -0.24, 0.0), 0.055, 1.55, STEEL_COLOR, Vector3(0.0, 0.0, 90.0))
	_engine_root.add_child(eccentric_shaft)
	_cams.append(eccentric_shaft)
	if forced:
		_engine_root.add_child(_box("rotary_pressure_box", Vector3(0.0, 1.18, 0.2), Vector3(1.2 * intake_scale, 0.16, 0.38), AIR_COLOR))

func _build_induction(induction_id: String, intake_scale: float, forced: bool) -> void:
	if not forced:
		var throttle := _cylinder("throttle_body", Vector3(-1.75, 0.72, 0.78), 0.16 * intake_scale, 0.26, AIR_COLOR, Vector3(0.0, 0.0, 90.0), 32)
		_engine_root.add_child(throttle)
		_engine_root.add_child(_cylinder("throttle_lip", Vector3(-1.91, 0.72, 0.78), 0.19 * intake_scale, 0.04, BRIGHT_STEEL_COLOR, Vector3(0.0, 0.0, 90.0), 32))
		for i in 4:
			var angle := TAU * float(i) / 4.0
			_engine_root.add_child(_sphere("throttle_bolt_%s" % i, Vector3(-1.94, 0.72 + sin(angle) * 0.13, 0.78 + cos(angle) * 0.13), 0.018, BRIGHT_STEEL_COLOR, 8, 4))
		return

	if induction_id == "supercharger":
		_engine_root.add_child(_box("supercharger_case", Vector3(0.0, 1.34, 0.0), Vector3(1.38 * intake_scale, 0.26, 0.44), Color(0.72, 0.76, 0.82, 0.68)))
		for i in 6:
			var x := -0.52 * intake_scale + float(i) * 0.21 * intake_scale
			_engine_root.add_child(_box("supercharger_rib_%s" % i, Vector3(x, 1.50, 0.0), Vector3(0.025, 0.08, 0.46), Color(0.90, 0.93, 0.96, 0.62)))
		var rotor_a := _cylinder("supercharger_rotor_a", Vector3(0.0, 1.34, -0.12), 0.055, 1.18 * intake_scale, BRIGHT_STEEL_COLOR, Vector3(0.0, 0.0, 90.0), 16)
		var rotor_b := _cylinder("supercharger_rotor_b", Vector3(0.0, 1.34, 0.12), 0.055, 1.18 * intake_scale, BRIGHT_STEEL_COLOR, Vector3(0.0, 0.0, 90.0), 16)
		_engine_root.add_child(rotor_a)
		_engine_root.add_child(rotor_b)
		_spinners.append(rotor_a)
		_spinners.append(rotor_b)
		_engine_root.add_child(_box("supercharger_scoop", Vector3(0.28, 1.58, 0.0), Vector3(0.72 * intake_scale, 0.16, 0.34), AIR_COLOR))
		var pulley := _cylinder("supercharger_pulley", Vector3(-0.92 * intake_scale, 1.34, 0.0), 0.16, 0.08, Color(0.94, 0.96, 1.0, 0.78), Vector3(90.0, 0.0, 0.0))
		_engine_root.add_child(pulley)
		_spinners.append(pulley)
		return

	var turbo_count := 2 if induction_id == "twin_turbo" else 1
	for i in turbo_count:
		var z := -0.76 if turbo_count == 2 and i == 0 else 0.76
		if turbo_count == 1:
			z = -0.86
		var turbo_center := Vector3(1.42, 0.34, z)
		var turbo := _cylinder("turbo_%s" % i, turbo_center, 0.18 * intake_scale, 0.16, Color(0.80, 0.86, 0.92, 0.76), Vector3(90.0, 0.0, 0.0), 32)
		_engine_root.add_child(turbo)
		_spinners.append(turbo)
		_engine_root.add_child(_cylinder("turbo_inlet_%s" % i, turbo_center + Vector3(0.0, 0.0, 0.13 if z >= 0.0 else -0.13), 0.11 * intake_scale, 0.12, AIR_COLOR, Vector3(90.0, 0.0, 0.0), 28))
		_engine_root.add_child(_sphere("turbo_core_%s" % i, turbo_center, 0.075 * intake_scale, BRIGHT_STEEL_COLOR, 16, 8))
		for blade in 8:
			var angle := TAU * float(blade) / 8.0
			var blade_pos := turbo_center + Vector3(cos(angle) * 0.095 * intake_scale, sin(angle) * 0.095 * intake_scale, 0.09 if z >= 0.0 else -0.09)
			var blade_mesh := _box("turbo_blade_%s_%s" % [i, blade], blade_pos, Vector3(0.07, 0.010, 0.024), BRIGHT_STEEL_COLOR)
			blade_mesh.rotation_degrees.z = rad_to_deg(angle)
			_engine_root.add_child(blade_mesh)
		_engine_root.add_child(_cylinder("charge_pipe_%s" % i, Vector3(0.9, 0.58, z * 0.55), 0.055 * intake_scale, 1.05, AIR_COLOR, Vector3(0.0, 0.0, 90.0)))
		_engine_root.add_child(_pipe_between("turbo_feed_%s" % i, turbo_center + Vector3(-0.12, 0.06, 0.0), Vector3(0.36, 0.72, z * 0.32), 0.035 * intake_scale, AIR_COLOR, 14))

func _build_blueprint_frame() -> void:
	var color := Color(0.58, 0.86, 1.0, 0.26)
	_engine_root.add_child(_box("frame_x_front", Vector3(0.0, 1.35, -1.18), Vector3(4.7, 0.015, 0.015), color))
	_engine_root.add_child(_box("frame_x_back", Vector3(0.0, 1.35, 1.18), Vector3(4.7, 0.015, 0.015), color))
	_engine_root.add_child(_box("frame_z_left", Vector3(-2.35, 1.35, 0.0), Vector3(0.015, 0.015, 2.35), color))
	_engine_root.add_child(_box("frame_z_right", Vector3(2.35, 1.35, 0.0), Vector3(0.015, 0.015, 2.35), color))
	_engine_root.add_child(_box("frame_y_left", Vector3(-2.35, 0.35, -1.18), Vector3(0.015, 2.0, 0.015), color))
	_engine_root.add_child(_box("frame_y_right", Vector3(2.35, 0.35, 1.18), Vector3(0.015, 2.0, 0.015), color))

func _cylinder_count(block_id: String) -> int:
	match block_id:
		"v8":
			return 8
		"v6":
			return 6
		"rotary":
			return 2
		_:
			return 4

func _box(node_name: String, position_value: Vector3, scale_value: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = position_value
	instance.scale = scale_value
	instance.material_override = _material(color)
	return instance

func _cylinder(node_name: String, position_value: Vector3, radius: float, height: float, color: Color, rotation_value: Vector3, segments: int = 24) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = position_value
	instance.rotation_degrees = rotation_value
	instance.material_override = _material(color)
	return instance

func _pipe_between(node_name: String, from_pos: Vector3, to_pos: Vector3, radius: float, color: Color, segments: int = 12) -> MeshInstance3D:
	var direction := to_pos - from_pos
	var length := direction.length()
	if length <= 0.001:
		return _cylinder(node_name, from_pos, radius, 0.001, color, Vector3.ZERO, segments)

	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = segments
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = from_pos + direction * 0.5
	instance.basis = Basis(Quaternion(Vector3.UP, direction.normalized()))
	instance.material_override = _material(color)
	return instance

func _sphere(node_name: String, position_value: Vector3, radius: float, color: Color, segments: int = 16, rings: int = 8) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = rings
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = position_value
	instance.material_override = _material(color)
	return instance

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.metallic = 0.15
	material.roughness = 0.38
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b, 1.0)
	material.emission_energy_multiplier = 0.18
	return material

func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.html("#0B1220")
	style.border_color = Color.html("#1D4D66")
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style
