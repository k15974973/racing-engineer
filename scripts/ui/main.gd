extends Control

const VIEW_ENGINE_BUILDER := "engine_builder"
const VIEW_RACE_SIM := "race_sim"
const VIEW_ANALYSIS := "analysis"
const VIEW_ROADMAP := "roadmap"
const VIEW_DEBUG := "debug"
const CurveChart := preload("res://scripts/ui/curve_chart.gd")
const TEST_BENCH_DURATION := 30.0
const SAVED_SETUPS_PATH := "user://saved_setups.json"
const SAVED_SETUPS_VERSION := 1
const RACE_HISTORY_PATH := "user://race_history.json"
const RACE_HISTORY_VERSION := 1

var _content: PanelContainer
var _nav_buttons: Dictionary = {}
var _builder_results: VBoxContainer
var _tuning_value_labels: Dictionary = {}
var _bench_progress: ProgressBar
var _bench_rpm_bar: ProgressBar
var _bench_boost_bar: ProgressBar
var _bench_heat_bar: ProgressBar
var _bench_reliability_bar: ProgressBar
var _bench_time_label: Label
var _bench_rpm_label: Label
var _bench_boost_label: Label
var _bench_heat_label: Label
var _bench_reliability_label: Label
var _bench_status_label: Label
var _bench_toggle_button: Button
var _setup_name_edit: LineEdit
var _current_view := VIEW_ENGINE_BUILDER
var _builder_selection := {
	"block": "",
	"induction": "",
	"material": ""
}
var _builder_tuning := {
	"compression": 10.5,
	"boost": 0.0,
	"valve_timing": 0.0,
	"fuel_map": 0.0,
	"ignition_timing": 0.0
}
var _bench_running := false
var _bench_elapsed := 0.0
var _pending_setup_name := ""
var _saved_setup_counter := 1
var _saved_setups: Array = []
var _race_track_id := ""
var _race_result: Dictionary = {}
var _race_decisions: Dictionary = {}
var _race_history_counter := 1
var _race_history: Array = []

func _ready() -> void:
	_load_saved_setups()
	_load_race_history()
	_build_shell()
	_show_view(VIEW_ENGINE_BUILDER)

func _process(delta: float) -> void:
	if not _bench_running:
		return

	_bench_elapsed = minf(_bench_elapsed + delta, TEST_BENCH_DURATION)
	_update_bench_display()

	if _bench_elapsed >= TEST_BENCH_DURATION:
		_bench_running = false
		_update_bench_display()

func _build_shell() -> void:
	var background := ColorRect.new()
	background.color = Color.html("#F3F4F6")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 2)
	root.add_child(header)

	header.add_child(_label("Racing Engineer", 24, Color.html("#111827")))
	header.add_child(_body_text("Phase 1 start: data-driven engine builder controls, projected setup stats, and smoke-test view."))

	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 8)
	root.add_child(nav)

	_add_nav_button(nav, VIEW_ENGINE_BUILDER, "Engine Builder")
	_add_nav_button(nav, VIEW_RACE_SIM, "Race Sim")
	_add_nav_button(nav, VIEW_ANALYSIS, "Analysis")
	_add_nav_button(nav, VIEW_ROADMAP, "Roadmap")
	_add_nav_button(nav, VIEW_DEBUG, "Data Smoke Test")

	_content = PanelContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_stylebox_override("panel", _panel_style(Color.html("#FFFFFF"), Color.html("#E5E7EB")))
	root.add_child(_content)

func _add_nav_button(nav: HBoxContainer, view_id: String, text: String) -> void:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_show_view.bind(view_id))
	nav.add_child(button)
	_nav_buttons[view_id] = button

func _show_view(view_id: String) -> void:
	_current_view = view_id
	for id in _nav_buttons.keys():
		_nav_buttons[id].button_pressed = id == view_id

	_clear_content()

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 18)
	_content.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	match view_id:
		VIEW_ENGINE_BUILDER:
			_render_engine_builder(layout)
		VIEW_RACE_SIM:
			_render_race_sim(layout)
		VIEW_ANALYSIS:
			_render_analysis(layout)
		VIEW_ROADMAP:
			_render_roadmap(layout)
		VIEW_DEBUG:
			_render_debug(layout)

func _clear_content() -> void:
	if _content == null:
		return

	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()

func _render_engine_builder(layout: VBoxContainer) -> void:
	_ensure_builder_selection()

	layout.add_child(_section_title("Engine Builder"))
	layout.add_child(_body_text("Choose a block, induction system, and material. The projected setup updates from the same structured data that future tuning and race simulation will use."))

	var builder := HBoxContainer.new()
	builder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	builder.add_theme_constant_override("separation", 12)
	layout.add_child(builder)

	var controls := VBoxContainer.new()
	controls.custom_minimum_size = Vector2(420, 0)
	controls.size_flags_vertical = Control.SIZE_EXPAND_FILL
	controls.add_theme_constant_override("separation", 10)
	builder.add_child(controls)

	_tuning_value_labels.clear()
	controls.add_child(_builder_choice_panel("Block", GameData.blocks, "block"))
	controls.add_child(_builder_choice_panel("Induction", GameData.inductions, "induction"))
	controls.add_child(_builder_choice_panel("Material", GameData.materials, "material"))
	controls.add_child(_builder_tuning_panel())
	controls.add_child(_setup_save_panel())

	var results := VBoxContainer.new()
	_builder_results = results
	results.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	results.size_flags_vertical = Control.SIZE_EXPAND_FILL
	results.add_theme_constant_override("separation", 10)
	builder.add_child(results)

	_refresh_builder_results()

func _ensure_builder_selection() -> void:
	var defaults := GameData.get_default_builder_selection()
	for key in _builder_selection.keys():
		var selected_id := str(_builder_selection[key])
		var collection_name := _builder_collection_name(key)
		if selected_id == "" or GameData.get_record_by_id(collection_name, selected_id).is_empty():
			_builder_selection[key] = defaults.get(key, "")

func _builder_choice_panel(title: String, records: Array, key: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color.html("#F9FAFB"), Color.html("#E5E7EB")))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)

	stack.add_child(_label(title, 16, Color.html("#111827")))

	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var selected_index := 0
	for index in range(records.size()):
		var item: Variant = records[index]
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var record: Dictionary = item
		var record_id := str(record.get("id", ""))
		option.add_item(str(record.get("name", "Unnamed")))
		option.set_item_metadata(option.get_item_count() - 1, record_id)
		if record_id == str(_builder_selection[key]):
			selected_index = option.get_item_count() - 1

	if option.get_item_count() > 0:
		option.select(selected_index)
	option.item_selected.connect(_on_builder_choice_selected.bind(key, option))
	stack.add_child(option)

	var selected_record := GameData.get_record_by_id(_builder_collection_name(key), str(_builder_selection[key]))
	stack.add_child(_body_text(_format_choice_detail(key, selected_record)))

	return panel

func _builder_summary_panel() -> PanelContainer:
	var setup := _current_setup()
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color.html("#FFFFFF"), Color.html("#D1D5DB")))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	margin.add_child(stack)

	stack.add_child(_label("Projected Setup", 18, Color.html("#111827")))

	if setup.has("error"):
		stack.add_child(_status(str(setup["error"]), false))
		return panel

	var title := "%s + %s + %s" % [setup["block"].get("name", "Block"), setup["induction"].get("name", "Induction"), setup["material"].get("name", "Material")]
	stack.add_child(_body_text(title))
	stack.add_child(_body_text(str(setup["curve_summary"])))
	stack.add_child(_curve_card(setup))

	stack.add_child(_metric_row("Peak power", "%s hp" % setup["peak_power_hp"]))
	stack.add_child(_metric_row("Torque", "%s Nm" % setup["torque_nm"]))
	stack.add_child(_metric_row("Mass", "%s kg" % setup["mass_kg"]))
	stack.add_child(_metric_row("RPM range", "%s-%s rpm" % [setup["rpm_min"], setup["rpm_max"]]))

	stack.add_child(_meter_row("Heat load", float(setup["heat_score"]), 160.0, false))
	stack.add_child(_meter_row("Reliability", float(setup["reliability_score"]), 120.0, true))
	stack.add_child(_meter_row("Throttle response", float(setup["response_score"]), 120.0, true))
	stack.add_child(_meter_row("Push margin", float(setup["push_margin"]), 120.0, true))

	var safe := float(setup["push_margin"]) >= 55.0
	stack.add_child(_status(str(setup["warning"]), safe))
	return panel

func _curve_card(setup: Dictionary) -> PanelContainer:
	var curves: Dictionary = setup.get("curves", {})
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color.html("#F9FAFB"), Color.html("#E5E7EB")))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)

	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", 12)
	stack.add_child(legend)
	legend.add_child(_legend_item("Power", Color.html("#534AB7"), "%s hp max" % curves.get("max_power", setup["peak_power_hp"])))
	legend.add_child(_legend_item("Torque", Color.html("#0F6E56"), "%s Nm max" % curves.get("max_torque", setup["torque_nm"])))

	var chart := CurveChart.new()
	chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chart.set_curve_data(curves)
	stack.add_child(chart)
	return panel

func _test_bench_preview_panel() -> PanelContainer:
	var setup := _current_setup()
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color.html("#F9FAFB"), Color.html("#E5E7EB")))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)

	stack.add_child(_label("Test Bench", 16, Color.html("#111827")))
	if setup.has("error"):
		stack.add_child(_body_text("Waiting for valid setup data."))
		return panel

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	stack.add_child(controls)

	var start_button := Button.new()
	_bench_toggle_button = start_button
	start_button.text = "Pause" if _bench_running else "Start"
	start_button.pressed.connect(_toggle_test_bench)
	controls.add_child(start_button)

	var reset_button := Button.new()
	reset_button.text = "Reset"
	reset_button.pressed.connect(_reset_test_bench)
	controls.add_child(reset_button)

	_bench_time_label = _label("", 12, Color.html("#374151"))
	_bench_time_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bench_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	controls.add_child(_bench_time_label)

	_bench_progress = ProgressBar.new()
	_bench_progress.max_value = TEST_BENCH_DURATION
	_bench_progress.show_percentage = false
	_bench_progress.custom_minimum_size = Vector2(0, 10)
	stack.add_child(_bench_progress)

	_bench_rpm_label = _body_text("")
	_bench_rpm_bar = _bench_bar(float(setup["rpm_max"]))
	stack.add_child(_bench_metric("RPM", _bench_rpm_label, _bench_rpm_bar))

	_bench_boost_label = _body_text("")
	_bench_boost_bar = _bench_bar(3.0)
	stack.add_child(_bench_metric("Boost", _bench_boost_label, _bench_boost_bar))

	_bench_heat_label = _body_text("")
	_bench_heat_bar = _bench_bar(180.0)
	stack.add_child(_bench_metric("Heat", _bench_heat_label, _bench_heat_bar))

	_bench_reliability_label = _body_text("")
	_bench_reliability_bar = _bench_bar(120.0)
	stack.add_child(_bench_metric("Reliability", _bench_reliability_label, _bench_reliability_bar))

	_bench_status_label = _status("", true)
	stack.add_child(_bench_status_label)
	_update_bench_display()
	return panel

func _bench_metric(name: String, value_label: Label, bar: ProgressBar) -> VBoxContainer:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	stack.add_child(row)

	var name_label := _body_text(name)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)

	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)

	stack.add_child(bar)
	return stack

func _bench_bar(max_value: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = max_value
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 9)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return bar

func _toggle_test_bench() -> void:
	if _bench_elapsed >= TEST_BENCH_DURATION:
		_bench_elapsed = 0.0

	_bench_running = not _bench_running
	_update_bench_display()

func _reset_test_bench() -> void:
	_bench_running = false
	_bench_elapsed = 0.0
	_update_bench_display()

func _update_bench_display() -> void:
	if _bench_progress == null or not is_instance_valid(_bench_progress):
		return

	var setup := _current_setup()
	var frame := GameData.calculate_test_bench_frame(setup, _bench_elapsed, TEST_BENCH_DURATION)
	if frame.has("error"):
		return

	_bench_progress.max_value = TEST_BENCH_DURATION
	_bench_progress.value = float(frame["elapsed"])
	_bench_time_label.text = "%0.1fs / %0.0fs" % [float(frame["elapsed"]), TEST_BENCH_DURATION]
	_bench_rpm_label.text = "%s rpm" % frame["rpm"]
	_bench_boost_label.text = "%0.2f bar" % float(frame["boost"])
	_bench_heat_label.text = "%0.1f / 180" % float(frame["heat"])
	_bench_reliability_label.text = "%0.1f / 120" % float(frame["reliability"])
	_bench_status_label.text = str(frame["status"])

	_bench_rpm_bar.value = float(frame["rpm"])
	_bench_boost_bar.value = float(frame["boost"])
	_bench_heat_bar.value = float(frame["heat"])
	_bench_reliability_bar.value = float(frame["reliability"])

	_set_bar_fill(_bench_progress, Color.html("#534AB7"))
	_set_bar_fill(_bench_rpm_bar, Color.html("#374151"))
	_set_bar_fill(_bench_boost_bar, Color.html("#185FA5"))
	_set_bar_fill(_bench_heat_bar, Color.html("#9F1239") if float(frame["heat"]) >= 115.0 else Color.html("#993C1D"))
	_set_bar_fill(_bench_reliability_bar, Color.html("#9F1239") if float(frame["reliability"]) < 45.0 else Color.html("#0F6E56"))

	if _bench_toggle_button != null and is_instance_valid(_bench_toggle_button):
		_bench_toggle_button.text = "Pause" if _bench_running else "Start"

	var status_color := Color.html("#065F46")
	if bool(frame["critical"]):
		status_color = Color.html("#9F1239")
	elif float(frame["heat"]) >= 115.0:
		status_color = Color.html("#92400E")
	_bench_status_label.add_theme_color_override("font_color", status_color)

func _set_bar_fill(bar: ProgressBar, color: Color) -> void:
	if bar == null or not is_instance_valid(bar):
		return

	bar.add_theme_stylebox_override("fill", _panel_style(color, color))

func _builder_tuning_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color.html("#FFFFFF"), Color.html("#D1D5DB")))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	margin.add_child(stack)

	stack.add_child(_label("Parameter Tuning", 16, Color.html("#111827")))
	stack.add_child(_tuning_slider("Compression", "compression", 8.0, 14.0, 0.1, ":1"))
	stack.add_child(_tuning_slider("Boost pressure", "boost", 0.0, 3.0, 0.1, " bar"))
	stack.add_child(_tuning_slider("Valve timing", "valve_timing", -10.0, 10.0, 1.0, " deg"))
	stack.add_child(_tuning_slider("Fuel map", "fuel_map", -10.0, 10.0, 1.0, ""))
	stack.add_child(_tuning_slider("Ignition timing", "ignition_timing", -8.0, 8.0, 1.0, " deg"))
	return panel

func _setup_save_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color.html("#F9FAFB"), Color.html("#E5E7EB")))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)

	stack.add_child(_label("Saved Setups", 16, Color.html("#111827")))

	_setup_name_edit = LineEdit.new()
	_setup_name_edit.placeholder_text = "Setup name"
	_setup_name_edit.text = _pending_setup_name
	_setup_name_edit.text_changed.connect(_on_setup_name_changed)
	stack.add_child(_setup_name_edit)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	stack.add_child(actions)

	var save_button := Button.new()
	save_button.text = "Save Current"
	save_button.pressed.connect(_save_current_setup)
	actions.add_child(save_button)

	var clear_button := Button.new()
	clear_button.text = "Clear"
	clear_button.pressed.connect(_clear_saved_setups)
	actions.add_child(clear_button)

	stack.add_child(_body_text("%s saved setup(s). Stored in user data." % _saved_setups.size()))
	return panel

func _setup_comparison_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color.html("#FFFFFF"), Color.html("#D1D5DB")))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	margin.add_child(stack)

	stack.add_child(_label("Setup Comparison", 18, Color.html("#111827")))
	if _saved_setups.is_empty():
		stack.add_child(_body_text("No saved setups yet. Save the current build to compare engine versions side by side."))
		return panel

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 170)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(scroll)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	scroll.add_child(row)

	for index in range(_saved_setups.size()):
		row.add_child(_saved_setup_card(index))

	return panel

func _saved_setup_card(index: int) -> PanelContainer:
	var saved: Dictionary = _saved_setups[index]
	var setup: Dictionary = saved.get("setup", {})
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 0)
	panel.add_theme_stylebox_override("panel", _panel_style(Color.html("#F9FAFB"), Color.html("#E5E7EB")))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 7)
	margin.add_child(stack)

	stack.add_child(_label(str(saved.get("name", "Setup")), 15, Color.html("#111827")))
	if setup.has("error"):
		stack.add_child(_status(str(setup["error"]), false))
		return panel

	var identity := "%s / %s / %s" % [setup["block"].get("name", "Block"), setup["induction"].get("name", "Induction"), setup["material"].get("name", "Material")]
	stack.add_child(_body_text(identity))
	stack.add_child(_metric_row("Power", "%s hp" % setup["peak_power_hp"]))
	stack.add_child(_metric_row("Torque", "%s Nm" % setup["torque_nm"]))
	stack.add_child(_metric_row("Heat", "%s / 160" % setup["heat_score"]))
	stack.add_child(_metric_row("Reliability", "%s / 120" % setup["reliability_score"]))
	stack.add_child(_metric_row("Push", "%s / 120" % setup["push_margin"]))

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	stack.add_child(actions)

	var load_button := Button.new()
	load_button.text = "Load"
	load_button.pressed.connect(_load_saved_setup.bind(index))
	actions.add_child(load_button)

	var delete_button := Button.new()
	delete_button.text = "Delete"
	delete_button.pressed.connect(_delete_saved_setup.bind(index))
	actions.add_child(delete_button)
	return panel

func _save_current_setup() -> void:
	var setup := _current_setup()
	if setup.has("error"):
		return

	var name := _pending_setup_name.strip_edges()
	if name == "":
		name = "Setup %d" % _saved_setup_counter
	_saved_setup_counter += 1

	_saved_setups.append({
		"name": name,
		"selection": _builder_selection.duplicate(true),
		"tuning": _builder_tuning.duplicate(true),
		"setup": setup.duplicate(true)
	})
	_write_saved_setups()
	_pending_setup_name = ""
	if _setup_name_edit != null and is_instance_valid(_setup_name_edit):
		_setup_name_edit.text = ""
	_show_view(VIEW_ENGINE_BUILDER)

func _load_saved_setup(index: int) -> void:
	if index < 0 or index >= _saved_setups.size():
		return

	var saved: Dictionary = _saved_setups[index]
	_builder_selection = saved.get("selection", _builder_selection).duplicate(true)
	_builder_tuning = saved.get("tuning", _builder_tuning).duplicate(true)
	_reset_race_result()
	_reset_test_bench()
	_show_view(VIEW_ENGINE_BUILDER)

func _delete_saved_setup(index: int) -> void:
	if index < 0 or index >= _saved_setups.size():
		return

	_saved_setups.remove_at(index)
	_write_saved_setups()
	_show_view(VIEW_ENGINE_BUILDER)

func _clear_saved_setups() -> void:
	_saved_setups.clear()
	_write_saved_setups()
	_show_view(VIEW_ENGINE_BUILDER)

func _on_setup_name_changed(text: String) -> void:
	_pending_setup_name = text

func _load_saved_setups() -> void:
	_saved_setups.clear()
	if not FileAccess.file_exists(SAVED_SETUPS_PATH):
		return

	var text := FileAccess.get_file_as_string(SAVED_SETUPS_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return

	var data: Dictionary = parsed
	if int(data.get("version", 0)) != SAVED_SETUPS_VERSION:
		return

	var records: Variant = data.get("setups", [])
	if typeof(records) != TYPE_ARRAY:
		return

	for item in records:
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var saved := _deserialize_saved_setup(item)
		if saved.is_empty():
			continue

		_saved_setups.append(saved)

	_saved_setup_counter = max(_saved_setup_counter, _saved_setups.size() + 1)

func _write_saved_setups() -> void:
	var records: Array = []
	for saved in _saved_setups:
		if typeof(saved) != TYPE_DICTIONARY:
			continue
		records.append(_serialize_saved_setup(saved))

	var payload := {
		"version": SAVED_SETUPS_VERSION,
		"setups": records
	}

	var file := FileAccess.open(SAVED_SETUPS_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write saved setups to %s" % SAVED_SETUPS_PATH)
		return

	file.store_string(JSON.stringify(payload, "\t"))

func _serialize_saved_setup(saved: Dictionary) -> Dictionary:
	return {
		"name": str(saved.get("name", "Setup")),
		"selection": saved.get("selection", {}).duplicate(true),
		"tuning": saved.get("tuning", {}).duplicate(true)
	}

func _deserialize_saved_setup(raw: Dictionary) -> Dictionary:
	var selection: Dictionary = raw.get("selection", {})
	var tuning: Dictionary = raw.get("tuning", {})
	if selection.is_empty() or tuning.is_empty():
		return {}

	var block_id := str(selection.get("block", ""))
	var induction_id := str(selection.get("induction", ""))
	var material_id := str(selection.get("material", ""))
	if block_id == "" or induction_id == "" or material_id == "":
		return {}

	var setup := GameData.calculate_engine_setup(block_id, induction_id, material_id, tuning)
	if setup.has("error"):
		return {}

	return {
		"name": str(raw.get("name", "Setup")),
		"selection": selection.duplicate(true),
		"tuning": tuning.duplicate(true),
		"setup": setup
	}

func _save_current_race() -> void:
	if _race_result.is_empty() or _race_result.has("error"):
		return

	var name := "Race %d" % _race_history_counter
	_race_history_counter += 1
	_race_history.append({
		"name": name,
		"selection": _builder_selection.duplicate(true),
		"tuning": _builder_tuning.duplicate(true),
		"track_id": _race_track_id,
		"decisions": _race_decisions.duplicate(true),
		"result": _race_result.duplicate(true)
	})
	_write_race_history()
	_show_view(VIEW_RACE_SIM)

func _load_race_history_entry(index: int) -> void:
	if index < 0 or index >= _race_history.size():
		return

	var record: Dictionary = _race_history[index]
	_builder_selection = record.get("selection", _builder_selection).duplicate(true)
	_builder_tuning = record.get("tuning", _builder_tuning).duplicate(true)
	_race_track_id = str(record.get("track_id", _race_track_id))
	_race_decisions = record.get("decisions", {}).duplicate(true)
	_race_result = GameData.calculate_race_result(_current_setup(), _race_track_id, _race_decisions)
	_reset_test_bench()
	_show_view(VIEW_RACE_SIM)

func _delete_race_history_entry(index: int) -> void:
	if index < 0 or index >= _race_history.size():
		return

	_race_history.remove_at(index)
	_write_race_history()
	_show_view(VIEW_RACE_SIM)

func _clear_race_history() -> void:
	_race_history.clear()
	_write_race_history()
	_show_view(VIEW_RACE_SIM)

func _load_race_history() -> void:
	_race_history.clear()
	if not FileAccess.file_exists(RACE_HISTORY_PATH):
		return

	var text := FileAccess.get_file_as_string(RACE_HISTORY_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return

	var data: Dictionary = parsed
	if int(data.get("version", 0)) != RACE_HISTORY_VERSION:
		return

	var records: Variant = data.get("races", [])
	if typeof(records) != TYPE_ARRAY:
		return

	for item in records:
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var record := _deserialize_race_history_entry(item)
		if record.is_empty():
			continue

		_race_history.append(record)

	_race_history_counter = max(_race_history_counter, _race_history.size() + 1)

func _write_race_history() -> void:
	var records: Array = []
	for record in _race_history:
		if typeof(record) != TYPE_DICTIONARY:
			continue
		records.append(_serialize_race_history_entry(record))

	var payload := {
		"version": RACE_HISTORY_VERSION,
		"races": records
	}

	var file := FileAccess.open(RACE_HISTORY_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write race history to %s" % RACE_HISTORY_PATH)
		return

	file.store_string(JSON.stringify(payload, "\t"))

func _serialize_race_history_entry(record: Dictionary) -> Dictionary:
	return {
		"name": str(record.get("name", "Race")),
		"selection": record.get("selection", {}).duplicate(true),
		"tuning": record.get("tuning", {}).duplicate(true),
		"track_id": str(record.get("track_id", "")),
		"decisions": record.get("decisions", {}).duplicate(true)
	}

func _deserialize_race_history_entry(raw: Dictionary) -> Dictionary:
	var selection: Dictionary = raw.get("selection", {})
	var tuning: Dictionary = raw.get("tuning", {})
	var track_id := str(raw.get("track_id", ""))
	var decisions: Dictionary = raw.get("decisions", {})
	if selection.is_empty() or tuning.is_empty() or track_id == "":
		return {}

	var setup := GameData.calculate_engine_setup(str(selection.get("block", "")), str(selection.get("induction", "")), str(selection.get("material", "")), tuning)
	var result := GameData.calculate_race_result(setup, track_id, decisions)
	if result.has("error"):
		return {}

	return {
		"name": str(raw.get("name", "Race")),
		"selection": selection.duplicate(true),
		"tuning": tuning.duplicate(true),
		"track_id": track_id,
		"decisions": decisions.duplicate(true),
		"result": result
	}

func _tuning_slider(label_text: String, key: String, min_value: float, max_value: float, step: float, unit: String) -> VBoxContainer:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	stack.add_child(row)

	var label := _body_text(label_text)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var value_label := _label(_tuning_value_text(key, unit), 12, Color.html("#111827"))
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	_tuning_value_labels[key] = {"label": value_label, "unit": unit}

	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = float(_builder_tuning.get(key, min_value))
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(_on_builder_tuning_changed.bind(key))
	stack.add_child(slider)
	return stack

func _current_setup() -> Dictionary:
	return GameData.calculate_engine_setup(str(_builder_selection["block"]), str(_builder_selection["induction"]), str(_builder_selection["material"]), _builder_tuning)

func _refresh_builder_results() -> void:
	if _builder_results == null:
		return

	for child in _builder_results.get_children():
		_builder_results.remove_child(child)
		child.queue_free()

	_builder_results.add_child(_builder_summary_panel())
	_builder_results.add_child(_test_bench_preview_panel())
	_builder_results.add_child(_setup_comparison_panel())

func _builder_collection_name(key: String) -> String:
	match key:
		"block":
			return "blocks"
		"induction":
			return "inductions"
		"material":
			return "materials"
		_:
			return ""

func _on_builder_choice_selected(index: int, key: String, option: OptionButton) -> void:
	_builder_selection[key] = str(option.get_item_metadata(index))
	_reset_race_result()
	_reset_test_bench()
	_show_view(VIEW_ENGINE_BUILDER)

func _on_builder_tuning_changed(value: float, key: String) -> void:
	_builder_tuning[key] = snappedf(value, _tuning_step(key))
	if _tuning_value_labels.has(key):
		var entry: Dictionary = _tuning_value_labels[key]
		var label: Label = entry["label"]
		label.text = _tuning_value_text(key, str(entry["unit"]))
	_reset_race_result()
	_reset_test_bench()
	_refresh_builder_results()

func _tuning_step(key: String) -> float:
	return 0.1 if key == "compression" or key == "boost" else 1.0

func _tuning_value_text(key: String, unit: String) -> String:
	var value := float(_builder_tuning.get(key, 0.0))
	if key == "compression":
		return "%0.1f%s" % [value, unit]
	if key == "boost":
		return "%0.1f%s" % [value, unit]
	if key == "fuel_map":
		return "%+0.0f" % value
	return "%+0.0f%s" % [value, unit]

func _format_choice_detail(key: String, record: Dictionary) -> String:
	if record.is_empty():
		return "No data loaded."

	match key:
		"block":
			var rpm_range: Array = record.get("rpm_range", [])
			var rpm := "%s-%s rpm" % [rpm_range[0], rpm_range[1]] if rpm_range.size() >= 2 else "RPM TBD"
			var stats := "Mass: %s kg | Heat: %s | Reliability: %s" % [record.get("mass", "?"), record.get("heat_factor", "?"), record.get("reliability_factor", "?")]
			return "%s\n%s\n%s" % [record.get("torque_profile", ""), stats, rpm]
		"induction":
			return "Power x%s | Lag %s | Heat x%s | Reliability x%s" % [record.get("power_mult", "?"), record.get("lag", "?"), record.get("heat_mult", "?"), record.get("reliability_mult", "?")]
		"material":
			return "Mass x%s | Max heat x%s | Durability x%s" % [record.get("mass_mult", "?"), record.get("max_heat_mult", "?"), record.get("durability_mult", "?")]
		_:
			return str(record)

func _legend_item(name: String, color: Color, value: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var swatch := ColorRect.new()
	swatch.color = color
	swatch.custom_minimum_size = Vector2(12, 12)
	row.add_child(swatch)

	row.add_child(_label("%s: %s" % [name, value], 12, Color.html("#374151")))
	return row

func _metric_row(name: String, value: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var label := _body_text(name)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var amount := _label(value, 13, Color.html("#111827"))
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(amount)
	return row

func _meter_row(name: String, value: float, max_value: float, higher_is_good: bool) -> VBoxContainer:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)

	stack.add_child(_metric_row(name, "%s/%s" % [snappedf(value, 0.1), int(max_value)]))

	var bar := ProgressBar.new()
	bar.max_value = max_value
	bar.value = clampf(value, 0.0, max_value)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	var fill := Color.html("#0F6E56") if higher_is_good else Color.html("#993C1D")
	if higher_is_good and value < max_value * 0.45:
		fill = Color.html("#9F1239")
	elif not higher_is_good and value > max_value * 0.72:
		fill = Color.html("#9F1239")
	bar.add_theme_stylebox_override("fill", _panel_style(fill, fill))
	stack.add_child(bar)

	return stack

func _render_race_sim(layout: VBoxContainer) -> void:
	_ensure_builder_selection()
	_ensure_race_track()

	layout.add_child(_section_title("Race Sim"))
	layout.add_child(_body_text("Run the current Engine Builder setup against a track profile. This prototype calculates projected lap time, sector fit, and tactical window pressure."))

	var race := HBoxContainer.new()
	race.size_flags_vertical = Control.SIZE_EXPAND_FILL
	race.add_theme_constant_override("separation", 12)
	layout.add_child(race)

	var controls := VBoxContainer.new()
	controls.custom_minimum_size = Vector2(420, 0)
	controls.add_theme_constant_override("separation", 10)
	race.add_child(controls)

	controls.add_child(_race_track_panel())
	controls.add_child(_race_setup_panel())

	var results := VBoxContainer.new()
	results.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	results.add_theme_constant_override("separation", 10)
	race.add_child(results)
	results.add_child(_race_result_panel())
	results.add_child(_race_history_panel())

func _ensure_race_track() -> void:
	if _race_track_id == "" or GameData.get_record_by_id("tracks", _race_track_id).is_empty():
		_race_track_id = GameData.get_default_track_id()

func _race_track_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color.html("#F9FAFB"), Color.html("#E5E7EB")))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)
	stack.add_child(_label("Track", 16, Color.html("#111827")))

	var option := OptionButton.new()
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var selected_index := 0
	for index in range(GameData.tracks.size()):
		var track: Dictionary = GameData.tracks[index]
		var track_id := str(track.get("id", ""))
		option.add_item(str(track.get("name", "Track")))
		option.set_item_metadata(option.get_item_count() - 1, track_id)
		if track_id == _race_track_id:
			selected_index = option.get_item_count() - 1

	if option.get_item_count() > 0:
		option.select(selected_index)
	option.item_selected.connect(_on_race_track_selected.bind(option))
	stack.add_child(option)

	var track := GameData.get_record_by_id("tracks", _race_track_id)
	stack.add_child(_body_text(str(track.get("description", ""))))
	stack.add_child(_metric_row("Laps", str(track.get("laps", "?"))))
	stack.add_child(_metric_row("Length", "%s km" % track.get("length_km", "?")))
	stack.add_child(_metric_row("Base lap", "%ss" % track.get("base_lap_time", "?")))

	var run_button := Button.new()
	run_button.text = "Run Race"
	run_button.pressed.connect(_run_race_sim)
	stack.add_child(run_button)
	return panel

func _race_setup_panel() -> PanelContainer:
	var setup := _current_setup()
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color.html("#FFFFFF"), Color.html("#D1D5DB")))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)
	stack.add_child(_label("Current Setup", 16, Color.html("#111827")))

	if setup.has("error"):
		stack.add_child(_status(str(setup["error"]), false))
		return panel

	var identity := "%s / %s / %s" % [setup["block"].get("name", "Block"), setup["induction"].get("name", "Induction"), setup["material"].get("name", "Material")]
	stack.add_child(_body_text(identity))
	stack.add_child(_metric_row("Power", "%s hp" % setup["peak_power_hp"]))
	stack.add_child(_metric_row("Torque", "%s Nm" % setup["torque_nm"]))
	stack.add_child(_metric_row("Heat", "%s / 160" % setup["heat_score"]))
	stack.add_child(_metric_row("Reliability", "%s / 120" % setup["reliability_score"]))
	return panel

func _race_result_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color.html("#FFFFFF"), Color.html("#D1D5DB")))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	margin.add_child(stack)
	stack.add_child(_label("Race Result", 18, Color.html("#111827")))

	if _race_result.is_empty():
		stack.add_child(_body_text("No race run yet. Choose a track and run the current setup."))
		return panel

	if _race_result.has("error"):
		stack.add_child(_status(str(_race_result["error"]), false))
		return panel

	var track: Dictionary = _race_result["track"]
	stack.add_child(_body_text("%s - %s lap(s)" % [track.get("name", "Track"), _race_result["laps"]]))
	stack.add_child(_metric_row("Projected lap", "%ss" % _race_result["lap_time"]))
	stack.add_child(_metric_row("Total time", "%ss" % _race_result["total_time"]))
	stack.add_child(_metric_row("Delta vs base", "%+0.2fs" % float(_race_result["delta_vs_base"])))
	stack.add_child(_metric_row("Final heat", "%s / 180" % _race_result["effective_heat"]))
	stack.add_child(_metric_row("Final reliability", "%s / 120" % _race_result["effective_reliability"]))
	stack.add_child(_meter_row("Track fit", float(_race_result["fit_score"]), 130.0, true))
	stack.add_child(_status(str(_race_result["summary"]), float(_race_result["fit_score"]) >= 70.0))

	stack.add_child(_label("Sector Fit", 16, Color.html("#111827")))
	for sector in _race_result["sectors"]:
		var text := "%s - rating %s, weight %s\n%s" % [sector.get("name", "Sector"), sector.get("rating", "?"), sector.get("bias", "?"), sector.get("note", "")]
		stack.add_child(_info_card(text))

	stack.add_child(_label("Tactical Windows", 16, Color.html("#111827")))
	for window in _race_result["windows"]:
		stack.add_child(_race_window_panel(window))

	var effects: Dictionary = _race_result.get("decision_effects", {})
	stack.add_child(_label("Decision Effects", 16, Color.html("#111827")))
	stack.add_child(_metric_row("Time", "%+0.2fs" % float(effects.get("time_delta", 0.0))))
	stack.add_child(_metric_row("Heat", "%+0.1f" % float(effects.get("heat_delta", 0.0))))
	stack.add_child(_metric_row("Reliability", "%+0.1f" % float(effects.get("reliability_delta", 0.0))))

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	stack.add_child(actions)

	var save_button := Button.new()
	save_button.text = "Save Race"
	save_button.pressed.connect(_save_current_race)
	actions.add_child(save_button)
	return panel

func _race_history_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color.html("#F9FAFB"), Color.html("#E5E7EB")))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	margin.add_child(stack)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	stack.add_child(header)
	var title := _label("Race History", 18, Color.html("#111827"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var clear_button := Button.new()
	clear_button.text = "Clear History"
	clear_button.pressed.connect(_clear_race_history)
	header.add_child(clear_button)

	if _race_history.is_empty():
		stack.add_child(_body_text("No saved races yet. Run a race and save it to compare later."))
		return panel

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 160)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(scroll)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	scroll.add_child(row)

	for index in range(_race_history.size()):
		row.add_child(_race_history_card(index))

	return panel

func _race_history_card(index: int) -> PanelContainer:
	var record: Dictionary = _race_history[index]
	var result: Dictionary = record.get("result", {})
	var track: Dictionary = result.get("track", {})
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(230, 0)
	panel.add_theme_stylebox_override("panel", _panel_style(Color.html("#FFFFFF"), Color.html("#D1D5DB")))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 7)
	margin.add_child(stack)

	stack.add_child(_label(str(record.get("name", "Race")), 15, Color.html("#111827")))
	stack.add_child(_body_text(str(track.get("name", "Track"))))
	stack.add_child(_metric_row("Lap", "%ss" % result.get("lap_time", "?")))
	stack.add_child(_metric_row("Total", "%ss" % result.get("total_time", "?")))
	stack.add_child(_metric_row("Fit", "%s / 130" % result.get("fit_score", "?")))

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	stack.add_child(actions)

	var load_button := Button.new()
	load_button.text = "Load"
	load_button.pressed.connect(_load_race_history_entry.bind(index))
	actions.add_child(load_button)

	var delete_button := Button.new()
	delete_button.text = "Delete"
	delete_button.pressed.connect(_delete_race_history_entry.bind(index))
	actions.add_child(delete_button)
	return panel

func _race_window_panel(window: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color.html("#F9FAFB"), Color.html("#E5E7EB")))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)

	var window_type := str(window.get("type", "Window"))
	var choices: Array = window.get("choices", [])
	var selected_id := str(_race_decisions.get(window_type, _default_race_choice_id(choices)))
	stack.add_child(_label(window_type, 15, Color.html("#111827")))
	stack.add_child(_body_text("Trigger: %s" % window.get("trigger", "")))

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	stack.add_child(actions)

	for choice in choices:
		if typeof(choice) != TYPE_DICTIONARY:
			continue

		var choice_id := str(choice.get("id", ""))
		var button := Button.new()
		button.text = str(choice.get("label", choice_id))
		button.toggle_mode = true
		button.button_pressed = choice_id == selected_id
		button.pressed.connect(_on_race_window_choice.bind(window_type, choice_id))
		actions.add_child(button)

	var selected_choice := _find_ui_choice(choices, selected_id)
	if not selected_choice.is_empty():
		stack.add_child(_body_text(_choice_effect_text(selected_choice)))

	return panel

func _choice_effect_text(choice: Dictionary) -> String:
	return "%s | Time %+0.2fs | Heat %+0.1f | Reliability %+0.1f" % [
		choice.get("note", ""),
		float(choice.get("time_delta", 0.0)),
		float(choice.get("heat_delta", 0.0)),
		float(choice.get("reliability_delta", 0.0))
	]

func _default_race_choice_id(choices: Array) -> String:
	if choices.is_empty():
		return ""
	if choices.size() >= 2:
		var middle: Dictionary = choices[1]
		return str(middle.get("id", ""))
	var first: Dictionary = choices[0]
	return str(first.get("id", ""))

func _find_ui_choice(choices: Array, choice_id: String) -> Dictionary:
	for item in choices:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var choice: Dictionary = item
		if str(choice.get("id", "")) == choice_id:
			return choice
	return {}

func _on_race_track_selected(index: int, option: OptionButton) -> void:
	_race_track_id = str(option.get_item_metadata(index))
	_race_result.clear()
	_race_decisions.clear()
	_show_view(VIEW_RACE_SIM)

func _run_race_sim() -> void:
	_ensure_builder_selection()
	_ensure_race_track()
	_race_result = GameData.calculate_race_result(_current_setup(), _race_track_id, _race_decisions)
	_show_view(VIEW_RACE_SIM)

func _on_race_window_choice(window_type: String, choice_id: String) -> void:
	_race_decisions[window_type] = choice_id
	_run_race_sim()

func _reset_race_result() -> void:
	_race_result.clear()
	_race_decisions.clear()

func _render_analysis(layout: VBoxContainer) -> void:
	layout.add_child(_section_title("Analysis"))
	var analysis := GameData.analyze_race_result(_race_result, _race_history)
	if analysis.has("error"):
		layout.add_child(_body_text(str(analysis["error"])))
		var button := Button.new()
		button.text = "Go To Race Sim"
		button.pressed.connect(_show_view.bind(VIEW_RACE_SIM))
		layout.add_child(button)
		return

	layout.add_child(_analysis_header_panel(analysis))

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 12)
	layout.add_child(columns)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	columns.add_child(left)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	columns.add_child(right)

	left.add_child(_analysis_scorecard_panel(analysis))
	left.add_child(_analysis_findings_panel(analysis))
	right.add_child(_analysis_suggestions_panel(analysis))
	right.add_child(_analysis_history_comparison_panel(analysis))
	right.add_child(_analysis_decisions_panel(_race_result))

func _analysis_header_panel(analysis: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color.html("#FFFFFF"), Color.html("#D1D5DB")))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)

	var track: Dictionary = analysis.get("track", {})
	var setup: Dictionary = analysis.get("setup", {})
	var block: Dictionary = setup.get("block", {})
	var induction: Dictionary = setup.get("induction", {})
	var material: Dictionary = setup.get("material", {})
	var identity := "%s / %s / %s" % [block.get("name", "Block"), induction.get("name", "Induction"), material.get("name", "Material")]
	stack.add_child(_label("Grade %s - %s" % [analysis.get("grade", "?"), analysis.get("headline", "")], 18, Color.html("#111827")))
	stack.add_child(_body_text("%s on %s" % [identity, track.get("name", "Track")]))
	return panel

func _analysis_scorecard_panel(analysis: Dictionary) -> PanelContainer:
	var scorecard: Dictionary = analysis.get("scorecard", {})
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color.html("#F9FAFB"), Color.html("#E5E7EB")))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)
	stack.add_child(_label("Scorecard", 16, Color.html("#111827")))
	stack.add_child(_metric_row("Lap delta", "%+0.2fs" % float(scorecard.get("lap_delta", 0.0))))
	stack.add_child(_meter_row("Track fit", float(scorecard.get("track_fit", 0.0)), 130.0, true))
	stack.add_child(_meter_row("Power", float(scorecard.get("power", 0.0)), 130.0, true))
	stack.add_child(_meter_row("Technical", float(scorecard.get("technical", 0.0)), 130.0, true))
	stack.add_child(_meter_row("Endurance", float(scorecard.get("endurance", 0.0)), 130.0, true))
	stack.add_child(_metric_row("Final heat", "%s / 180" % scorecard.get("heat", "?")))
	stack.add_child(_metric_row("Final reliability", "%s / 120" % scorecard.get("reliability", "?")))
	return panel

func _analysis_findings_panel(analysis: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color.html("#FFFFFF"), Color.html("#D1D5DB")))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)
	stack.add_child(_label("Findings", 16, Color.html("#111827")))

	for item in analysis.get("findings", []):
		var finding: Dictionary = item
		stack.add_child(_analysis_finding_card(finding))

	return panel

func _analysis_finding_card(finding: Dictionary) -> PanelContainer:
	var severity := str(finding.get("severity", "info"))
	var color := Color.html("#1E40AF")
	if severity == "good":
		color = Color.html("#065F46")
	elif severity == "warn":
		color = Color.html("#92400E")
	elif severity == "bad":
		color = Color.html("#9F1239")

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color.html("#F9FAFB"), Color.html("#E5E7EB")))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	margin.add_child(stack)
	stack.add_child(_label(str(finding.get("title", "Finding")), 14, color))
	stack.add_child(_body_text(str(finding.get("body", ""))))
	return panel

func _analysis_suggestions_panel(analysis: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color.html("#F9FAFB"), Color.html("#E5E7EB")))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)
	stack.add_child(_label("Rebuild Direction", 16, Color.html("#111827")))
	for suggestion in analysis.get("suggestions", []):
		stack.add_child(_body_text("- %s" % suggestion))
	return panel

func _analysis_history_comparison_panel(analysis: Dictionary) -> PanelContainer:
	var comparison: Dictionary = analysis.get("comparison", {})
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color.html("#F9FAFB"), Color.html("#E5E7EB")))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)
	stack.add_child(_label("History Comparison", 16, Color.html("#111827")))

	if comparison.is_empty():
		stack.add_child(_body_text("No saved race on this track yet. Save race results to unlock trend comparison."))
		return panel

	stack.add_child(_body_text(str(comparison.get("summary", ""))))
	stack.add_child(_metric_row("Current total", "%ss" % comparison.get("current_total_time", "?")))
	stack.add_child(_metric_row("Best saved", "%ss" % comparison.get("best_total_time", "?")))
	stack.add_child(_metric_row("Delta", "%+0.2fs" % float(comparison.get("delta_to_best", 0.0))))
	return panel

func _analysis_decisions_panel(race_result: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color.html("#FFFFFF"), Color.html("#D1D5DB")))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)
	stack.add_child(_label("Tactical Review", 16, Color.html("#111827")))

	var effects: Dictionary = race_result.get("decision_effects", {})
	stack.add_child(_metric_row("Time", "%+0.2fs" % float(effects.get("time_delta", 0.0))))
	stack.add_child(_metric_row("Heat", "%+0.1f" % float(effects.get("heat_delta", 0.0))))
	stack.add_child(_metric_row("Reliability", "%+0.1f" % float(effects.get("reliability_delta", 0.0))))

	for item in effects.get("log", []):
		var decision: Dictionary = item
		var text := "%s - %s\n%s" % [decision.get("window", "Window"), decision.get("choice", "Choice"), decision.get("note", "")]
		stack.add_child(_info_card(text))

	return panel

func _render_roadmap(layout: VBoxContainer) -> void:
	layout.add_child(_section_title("Roadmap"))
	layout.add_child(_body_text("Six near-term phases are in scope. Real-time PvP stays deferred until the async online layer has real players and useful data."))

	for phase in GameData.roadmap_phases:
		var text := "Phase %s - %s (%s)\n%s\nDeliverable: %s" % [phase.get("id", "?"), phase.get("name", "Unnamed"), phase.get("duration", "TBD"), phase.get("goal", ""), phase.get("deliverable", "")]
		layout.add_child(_info_card(text))

	layout.add_child(_info_card("Future - Real-time PvP\nDeferred until after launch. Requires player base, server authority, synchronized tactical windows, and anti-exploit validation."))

func _render_debug(layout: VBoxContainer) -> void:
	layout.add_child(_section_title("Data Smoke Test"))

	var summary := GameData.get_summary()
	var errors = summary["errors"]
	layout.add_child(_body_text("Loaded blocks: %s | inductions: %s | materials: %s | tracks: %s | roadmap phases: %s" % [summary["blocks"], summary["inductions"], summary["materials"], summary["tracks"], summary["roadmap_phases"]]))
	layout.add_child(_body_text("Saved setup file: %s" % ProjectSettings.globalize_path(SAVED_SETUPS_PATH)))
	layout.add_child(_body_text("Race history file: %s" % ProjectSettings.globalize_path(RACE_HISTORY_PATH)))

	if errors.is_empty():
		layout.add_child(_status("PASS: GameData loaded every Part 1 data collection without validation errors.", true))
	else:
		layout.add_child(_status("FAIL: GameData found validation errors.", false))
		layout.add_child(_bullet_list(errors))

	layout.add_child(_body_text("Use this screen as the quick manual check before starting Phase 1 builder interactions."))

func _data_column(title: String, records: Array, detail_key: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color.html("#F9FAFB"), Color.html("#E5E7EB")))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	margin.add_child(list)

	list.add_child(_label(title, 16, Color.html("#111827")))

	for record in records:
		var detail := str(record.get(detail_key, ""))
		list.add_child(_body_text("%s\n%s" % [record.get("name", "Unnamed"), detail]))

	return panel

func _section_title(text: String) -> Label:
	return _label(text, 20, Color.html("#111827"))

func _body_text(text: String) -> Label:
	var label := _label(text, 13, Color.html("#374151"))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _bullet_list(items: Array) -> VBoxContainer:
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	for item in items:
		list.add_child(_body_text("- %s" % item))
	return list

func _info_card(text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color.html("#F9FAFB"), Color.html("#E5E7EB")))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	margin.add_child(_body_text(text))
	return panel

func _status(text: String, ok: bool) -> Label:
	var color := Color.html("#065F46") if ok else Color.html("#9F1239")
	return _label(text, 14, color)

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _panel_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style
