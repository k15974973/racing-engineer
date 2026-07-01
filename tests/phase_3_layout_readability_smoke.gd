extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/Main.tscn"
const VIEW_ENGINE_BUILDER := "engine_builder"
const VIEW_RACE_SIM := "race_sim"
const BUILDER_SHOT := "user://phase_3_engine_builder_readability.png"
const BUILDER_MID_SHOT := "user://phase_3_engine_builder_mid_readability.png"
const BUILDER_BOTTOM_SHOT := "user://phase_3_engine_builder_bottom_readability.png"
const RACE_SHOT := "user://phase_3_race_sim_readability.png"

var _main: Control
var _builder_screenshot := "skipped"
var _builder_mid_screenshot := "skipped"
var _builder_bottom_screenshot := "skipped"
var _race_screenshot := "skipped"

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var main_scene: PackedScene = load(MAIN_SCENE_PATH)
	if main_scene == null:
		_fail("Could not load Main scene.")
		return

	_main = main_scene.instantiate()
	root.add_child(_main)
	await process_frame
	await process_frame

	_main._show_view(VIEW_ENGINE_BUILDER)
	await process_frame
	await process_frame
	if not _assert_builder_labels():
		return
	if not _assert_builder_scroll():
		return
	if not _save_screenshot(BUILDER_SHOT):
		return
	if not _scroll_builder_to_ratio(0.32):
		return
	await process_frame
	await process_frame
	if not _save_screenshot(BUILDER_MID_SHOT):
		return
	if not _scroll_builder_to_bottom():
		return
	await process_frame
	await process_frame
	if not _save_screenshot(BUILDER_BOTTOM_SHOT):
		return

	_main._show_view(VIEW_RACE_SIM)
	_main._run_race_sim()
	await process_frame
	await process_frame
	if not _assert_race_labels():
		return
	if not _save_screenshot(RACE_SHOT):
		return

	_restore()
	print("PHASE_3_LAYOUT_READABILITY_OK builder=%s builder_mid=%s builder_bottom=%s race=%s" % [_builder_screenshot, _builder_mid_screenshot, _builder_bottom_screenshot, _race_screenshot])
	quit(0)

func _assert_builder_labels() -> bool:
	var power_labels := _find_labels_containing(_main, "Power:")
	var found_power_legend := false
	for label in power_labels:
		if label.text.find("hp max") == -1:
			continue
		found_power_legend = true
		if not _assert_single_line_label(label, "builder power legend"):
			return false

	var torque_labels := _find_labels_containing(_main, "Torque:")
	var found_torque_legend := false
	for label in torque_labels:
		if label.text.find("Nm max") == -1:
			continue
		found_torque_legend = true
		if not _assert_single_line_label(label, "builder torque legend"):
			return false

	if not found_power_legend:
		_fail("Could not find builder Power legend label.")
		return false
	if not found_torque_legend:
		_fail("Could not find builder Torque legend label.")
		return false
	return true

func _assert_builder_scroll() -> bool:
	var scroll := _content_scroll()
	if scroll == null:
		_fail("Main content should be wrapped in a ScrollContainer.")
		return false
	var bar := scroll.get_v_scroll_bar()
	if bar.max_value <= 0.0:
		_fail("Builder content should expose vertical scroll for below-fold panels.")
		return false
	if _find_label_exact(_main, "3") == null or _find_label_exact(_main, "Material") == null or _find_label_exact(_main, "Test Bench") == null:
		_fail("Builder scroll content should include Material and Test Bench sections.")
		return false
	for item in [
		{"label": _main._bench_rpm_label, "name": "bench rpm value"},
		{"label": _main._bench_boost_label, "name": "bench boost value"},
		{"label": _main._bench_heat_label, "name": "bench heat value"},
		{"label": _main._bench_reliability_label, "name": "bench reliability value"}
	]:
		var label: Label = item.get("label", null)
		if label == null:
			_fail("%s is missing." % item.get("name", "bench value"))
			return false
		if not _assert_single_line_label(label, str(item.get("name", "bench value"))):
			return false
	return true

func _scroll_builder_to_bottom() -> bool:
	return _scroll_builder_to_ratio(1.0)

func _scroll_builder_to_ratio(ratio: float) -> bool:
	var scroll := _content_scroll()
	if scroll == null:
		_fail("Cannot scroll builder because content ScrollContainer is missing.")
		return false
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value * clampf(ratio, 0.0, 1.0))
	return true

func _assert_race_labels() -> bool:
	for text in ["Laps", "Length", "Base lap", "Par time"]:
		var label := _find_label_exact(_main, text)
		if label == null:
			_fail("Could not find race stat label %s." % text)
			return false
		if not _assert_single_line_label(label, "race stat %s" % text):
			return false
	return true

func _assert_single_line_label(label: Label, label_name: String) -> bool:
	if label.autowrap_mode != TextServer.AUTOWRAP_OFF:
		_fail("%s should disable autowrap." % label_name)
		return false
	if label.size.y > 26.0:
		_fail("%s appears wrapped vertically. text=%s size=%s" % [label_name, label.text, label.size])
		return false
	if label.size.x < 20.0:
		_fail("%s has collapsed width. text=%s size=%s" % [label_name, label.text, label.size])
		return false
	return true

func _save_screenshot(path: String) -> bool:
	if DisplayServer.get_name() == "headless":
		return true
	var image := root.get_texture().get_image()
	if image == null:
		return true
	var error := image.save_png(path)
	if error != OK:
		_fail("Could not save screenshot %s error=%s" % [path, error])
		return false
	if path == BUILDER_SHOT:
		_builder_screenshot = ProjectSettings.globalize_path(path)
	elif path == BUILDER_MID_SHOT:
		_builder_mid_screenshot = ProjectSettings.globalize_path(path)
	elif path == BUILDER_BOTTOM_SHOT:
		_builder_bottom_screenshot = ProjectSettings.globalize_path(path)
	else:
		_race_screenshot = ProjectSettings.globalize_path(path)
	return true

func _content_scroll() -> ScrollContainer:
	if _main == null or _main._content == null:
		return null
	for child in _main._content.get_children():
		if child is ScrollContainer:
			return child as ScrollContainer
	return null

func _find_label_exact(node: Node, text: String) -> Label:
	if node is Label and (node as Label).text == text:
		return node as Label
	for child in node.get_children():
		var result := _find_label_exact(child, text)
		if result != null:
			return result
	return null

func _find_labels_containing(node: Node, text: String) -> Array:
	var result: Array = []
	if node is Label and (node as Label).text.find(text) != -1:
		result.append(node as Label)
	for child in node.get_children():
		result.append_array(_find_labels_containing(child, text))
	return result

func _restore() -> void:
	if is_instance_valid(_main):
		_main.queue_free()
		_main = null

func _fail(message: String) -> void:
	_restore()
	push_error(message)
	quit(1)
