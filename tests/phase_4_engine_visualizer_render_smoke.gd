extends SceneTree

const EngineVisualizer3D := preload("res://scripts/ui/engine_visualizer_3d.gd")
const OUTPUT_PATH := "res://work/engine_visualizer_render.png"

var _visualizer: Control

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var game_data = root.get_node("/root/GameData")
	var setup: Dictionary = game_data.calculate_engine_setup("v8", "twin_turbo", "titanium", {
		"compression": 12.8,
		"boost": 2.3,
		"fuel_map": 5.0,
		"ignition_timing": 4.0
	})
	if setup.has("error"):
		_fail("Could not build render visual setup: %s" % setup.get("error", ""))
		return

	_visualizer = EngineVisualizer3D.new()
	root.add_child(_visualizer)
	_visualizer.set_setup(setup)
	await process_frame
	await process_frame
	await process_frame

	var image: Image = _visualizer.get_render_image()
	if image == null or image.is_empty():
		print("PHASE_4_ENGINE_VISUALIZER_RENDER_SKIPPED display=%s texture_unavailable=true" % DisplayServer.get_name())
		_restore()
		quit(0)
		return

	var lit_pixels := _count_lit_pixels(image)
	if lit_pixels < 1200:
		_fail("Visualizer render appears blank. Lit pixels=%s" % lit_pixels)
		return

	var save_error := image.save_png(OUTPUT_PATH)
	if save_error != OK:
		_fail("Could not save visualizer render image. Error=%s" % save_error)
		return

	print("PHASE_4_ENGINE_VISUALIZER_RENDER_OK lit_pixels=%s path=%s" % [lit_pixels, ProjectSettings.globalize_path(OUTPUT_PATH)])
	_restore()
	quit(0)

func _count_lit_pixels(image: Image) -> int:
	var count := 0
	var width := image.get_width()
	var height := image.get_height()
	for y in range(0, height, 4):
		for x in range(0, width, 4):
			var color := image.get_pixel(x, y)
			if color.r + color.g + color.b > 0.18:
				count += 1
	return count

func _restore() -> void:
	if is_instance_valid(_visualizer):
		_visualizer.free()
		_visualizer = null

func _fail(message: String) -> void:
	_restore()
	push_error(message)
	quit(1)
