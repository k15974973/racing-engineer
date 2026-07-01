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

	print("PHASE_4_ENGINE_VISUALIZER_OK base_intake=%s tuned_intake=%s chamber=%s fuel=%s" % [
		base_state.get("intake_scale", 0.0),
		tuned_state.get("intake_scale", 0.0),
		tuned_state.get("chamber_scale", 0.0),
		tuned_state.get("fuel_scale", 0.0)
	])
	_restore()
	quit(0)

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
