extends SceneTree

const EngineVisualizer3D := preload("res://scripts/ui/engine_visualizer_3d.gd")

var _visualizer: Control

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var game_data = root.get_node("/root/GameData")
	_visualizer = EngineVisualizer3D.new()
	root.add_child(_visualizer)
	await process_frame

	var base: Dictionary = game_data.calculate_engine_setup("inline_4", "na", "aluminum", {
		"compression": 10.5,
		"boost": 0.0,
		"fuel_map": 0.0,
		"ignition_timing": 0.0
	})
	if base.has("error"):
		_fail("Could not build base visual setup: %s" % base.get("error", ""))
		return

	_visualizer.set_setup(base)
	await process_frame
	var base_state: Dictionary = _visualizer.get_visual_state()
	if not _assert_valid_state(base_state, "base"):
		return
	if int(base_state.get("cylinder_count", 0)) != 4 or int(base_state.get("piston_nodes", 0)) != 4:
		_fail("Inline-4 visual should expose 4 cylinders and 4 moving piston nodes.")
		return
	if bool(base_state.get("has_forced_induction", true)):
		_fail("NA visual should not report forced induction.")
		return
	if str(base_state.get("viewport_size", "")) != "640x320":
		_fail("Engine visualizer viewport should stay 640x320.")
		return
	if not is_equal_approx(float(base_state.get("auto_rotate_deg_per_sec", 0.0)), 6.0):
		_fail("Engine visualizer should auto-rotate at 6 degrees per second.")
		return
	if str(base_state.get("shader", "")) != "holographic_fresnel":
		_fail("Engine visualizer should use the holographic fresnel shader.")
		return
	if not is_equal_approx(float(base_state.get("fresnel_power", 0.0)), 1.8):
		_fail("Holographic fresnel should stay softened at 1.8 power.")
		return
	if str(base_state.get("msaa_3d", "")) != "8x" or str(base_state.get("screen_space_aa", "")) != "fxaa":
		_fail("Engine visualizer should keep MSAA 8x plus FXAA.")
		return
	if int(base_state.get("min_cylinder_segments", 0)) < 32 or int(base_state.get("min_sphere_segments", 0)) < 24:
		_fail("Engine visualizer mesh resolution should keep smooth cylinder/sphere minimums.")
		return
	if bool(base_state.get("bounding_box", true)):
		_fail("Engine visualizer should not render the old enclosing bounding box.")
		return
	if not bool(base_state.get("floor_reflection", false)):
		_fail("Engine visualizer should keep a low-opacity floor reflection.")
		return
	if not _assert_zoom_input(base_state):
		return

	var tuned: Dictionary = game_data.calculate_engine_setup("inline_4", "single_turbo", "aluminum", {
		"compression": 14.0,
		"boost": 3.0,
		"fuel_map": 10.0,
		"ignition_timing": 6.0
	})
	if tuned.has("error"):
		_fail("Could not build tuned visual setup: %s" % tuned.get("error", ""))
		return

	_visualizer.set_setup(tuned)
	await process_frame
	var tuned_state: Dictionary = _visualizer.get_visual_state()
	if not _assert_valid_state(tuned_state, "tuned"):
		return
	if not bool(tuned_state.get("has_forced_induction", false)):
		_fail("Turbo visual should report forced induction.")
		return
	if float(tuned_state.get("intake_scale", 0.0)) <= float(base_state.get("intake_scale", 0.0)):
		_fail("Boosted setup should enlarge the intake visual.")
		return
	if float(tuned_state.get("chamber_scale", 0.0)) <= float(base_state.get("chamber_scale", 0.0)):
		_fail("Higher compression should enlarge the chamber visual.")
		return
	if float(tuned_state.get("fuel_scale", 0.0)) <= float(base_state.get("fuel_scale", 0.0)):
		_fail("Richer fuel map should enlarge the fuel rail visual.")
		return

	var v8: Dictionary = game_data.calculate_engine_setup("v8", "twin_turbo", "titanium", {
		"compression": 12.5,
		"boost": 2.0,
		"fuel_map": 4.0
	})
	_visualizer.set_setup(v8)
	await process_frame
	var v8_state: Dictionary = _visualizer.get_visual_state()
	if int(v8_state.get("cylinder_count", 0)) != 8 or int(v8_state.get("piston_nodes", 0)) != 8:
		_fail("V8 visual should expose 8 cylinders and 8 moving piston nodes.")
		return
	if int(v8_state.get("visual_nodes", 0)) < 175:
		_fail("V8 visual should keep the detailed model pass. Nodes=%s" % int(v8_state.get("visual_nodes", 0)))
		return
	if str(v8_state.get("material_color", "")) == str(base_state.get("material_color", "")):
		_fail("Titanium visual should use a different material tint than Aluminum.")
		return

	var ceramic: Dictionary = game_data.calculate_engine_setup("v8", "na", "ceramic", {
		"compression": 10.5,
		"boost": 0.0,
		"fuel_map": 0.0
	})
	_visualizer.set_setup(ceramic)
	await process_frame
	var ceramic_state: Dictionary = _visualizer.get_visual_state()
	if str(ceramic_state.get("material_color", "")) == str(v8_state.get("material_color", "")):
		_fail("Ceramic visual should use a different material tint than Titanium.")
		return

	print("PHASE_4_ENGINE_VISUALIZER_OK base_intake=%s tuned_intake=%s chamber=%s fuel=%s v8_nodes=%s" % [
		base_state.get("intake_scale", 0.0),
		tuned_state.get("intake_scale", 0.0),
		tuned_state.get("chamber_scale", 0.0),
		tuned_state.get("fuel_scale", 0.0),
		v8_state.get("visual_nodes", 0)
	])
	_restore()
	quit(0)

func _assert_zoom_input(base_state: Dictionary) -> bool:
	var before := float(base_state.get("camera_zoom_z", 0.0))
	var min_zoom := float(base_state.get("camera_zoom_min", 0.0))
	var max_zoom := float(base_state.get("camera_zoom_max", 0.0))
	if not is_equal_approx(min_zoom, 2.0) or not is_equal_approx(max_zoom, 8.0):
		_fail("Camera zoom should clamp between 2.0 and 8.0.")
		return false

	var zoom_in := InputEventMouseButton.new()
	zoom_in.button_index = MOUSE_BUTTON_WHEEL_UP
	zoom_in.pressed = true
	_visualizer._on_viewport_gui_input(zoom_in)
	var after_in := float(_visualizer.get_visual_state().get("camera_zoom_z", 0.0))
	if after_in >= before:
		_fail("Mouse wheel up should move camera closer on Z.")
		return false

	var zoom_out := InputEventMouseButton.new()
	zoom_out.button_index = MOUSE_BUTTON_WHEEL_DOWN
	zoom_out.pressed = true
	_visualizer._on_viewport_gui_input(zoom_out)
	var after_out := float(_visualizer.get_visual_state().get("camera_zoom_z", 0.0))
	if after_out <= after_in:
		_fail("Mouse wheel down should move camera farther on Z.")
		return false
	return true

func _assert_valid_state(state: Dictionary, label: String) -> bool:
	if state.is_empty() or not bool(state.get("valid", false)):
		_fail("%s visual state should be valid." % label)
		return false
	return true

func _restore() -> void:
	if is_instance_valid(_visualizer):
		_visualizer.free()
		_visualizer = null

func _fail(message: String) -> void:
	_restore()
	push_error(message)
	quit(1)
