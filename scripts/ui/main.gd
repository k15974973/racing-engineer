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
const PROGRESSION_PATH := "user://progression.json"
const PROGRESSION_VERSION := 1
const GARAGE_STATE_PATH := "user://garage_state.json"
const GARAGE_STATE_VERSION := 1
const GARAGE_MAX_DAMAGE := 100.0
const GARAGE_STARTING_CREDITS := 2500
const GARAGE_REPAIR_COST_PER_DAMAGE := 42
const GARAGE_BUDGET_REPAIR_CREDITS := 650
const GARAGE_PART_KEYS := ["block", "induction", "material"]
const COMPARISON_LIMIT := 3
const COMPARISON_COLORS := ["#534AB7", "#0F6E56", "#B45309"]
const PROGRESSION_STARTER_UNLOCKS := {
	"blocks": ["v4", "v6", "inline_4"],
	"inductions": ["na", "single_turbo"],
	"materials": ["aluminum"]
}
const PROGRESSION_RULES := [
	{
		"id": "power_ring_clean",
		"title": "Power Ring Clean Finish",
		"description": "Fit 74+, heat 125 or lower, reliability 55+ on Power Ring.",
		"track_id": "power_ring",
		"fit_min": 74.0,
		"heat_max": 125.0,
		"reliability_min": 55.0,
		"unlocks": {"materials": ["titanium"]}
	},
	{
		"id": "technical_loop_clean",
		"title": "Technical Loop Clean Finish",
		"description": "Fit 74+, heat 125 or lower, reliability 55+ on Technical Loop.",
		"track_id": "technical_loop",
		"fit_min": 74.0,
		"heat_max": 125.0,
		"reliability_min": 55.0,
		"unlocks": {"blocks": ["boxer_4"]}
	},
	{
		"id": "b_class_fit",
		"title": "B-Class Track Fit",
		"description": "Fit 86+, heat 126 or lower, reliability 55+ on any track.",
		"fit_min": 86.0,
		"heat_max": 126.0,
		"reliability_min": 55.0,
		"unlocks": {"inductions": ["twin_turbo"]}
	},
	{
		"id": "cool_fast_package",
		"title": "Cool Fast Package",
		"description": "Beat baseline lap time while keeping heat 105 or lower and reliability 70+.",
		"lap_delta_max": 0.0,
		"heat_max": 105.0,
		"reliability_min": 70.0,
		"unlocks": {"inductions": ["supercharger"]}
	},
	{
		"id": "heavy_power_brief",
		"title": "Heavy Power Brief",
		"description": "Reach 390 hp with fit 80+ and reliability 50+.",
		"power_min": 390.0,
		"fit_min": 80.0,
		"reliability_min": 50.0,
		"unlocks": {"blocks": ["v8"]}
	},
	{
		"id": "thermal_mastery",
		"title": "Thermal Mastery",
		"description": "Fit 82+, heat 95 or lower, reliability 75+.",
		"fit_min": 82.0,
		"heat_max": 95.0,
		"reliability_min": 75.0,
		"unlocks": {"materials": ["ceramic"]}
	},
	{
		"id": "experimental_license",
		"title": "Experimental License",
		"description": "Save three clean races to unlock the risky final parts.",
		"clean_races": 3,
		"unlocks": {"blocks": ["rotary"], "inductions": ["compound"]}
	}
]

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
var _progression: Dictionary = {}
var _garage_state: Dictionary = {}
var _last_unlocks: Array = []
var _last_damage_report: Dictionary = {}
var _last_reward_report: Dictionary = {}
var _race_committed := false
var _timeline_focus_index := 0

func _ready() -> void:
	_load_progression()
	_load_garage_state()
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
	header.add_child(_body_text("Engine Builder prototype with future-phase race, analysis, and garage systems clearly separated in docs."))

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
	controls.add_child(_garage_status_panel())
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
	var defaults: Dictionary = GameData.get_default_builder_selection()
	for key in _builder_selection.keys():
		var selected_id := str(_builder_selection[key])
		var collection_name := _builder_collection_name(key)
		if selected_id == "" or GameData.get_record_by_id(collection_name, selected_id).is_empty():
			_builder_selection[key] = str(defaults.get(key, ""))

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

	var choices := GridContainer.new()
	choices.columns = 2
	choices.add_theme_constant_override("h_separation", 6)
	choices.add_theme_constant_override("v_separation", 6)
	stack.add_child(choices)

	for index in range(records.size()):
		var item: Variant = records[index]
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var record: Dictionary = item
		var record_id := str(record.get("id", ""))
		var selected := record_id == str(_builder_selection[key])
		choices.add_child(_slot_choice_button(str(record.get("name", "Unnamed")), record_id, key, selected))

	var selected_record: Dictionary = GameData.get_record_by_id(_builder_collection_name(key), str(_builder_selection[key]))
	stack.add_child(_selected_slot_panel(key, selected_record))

	return panel

func _slot_choice_button(text: String, record_id: String, key: String, selected: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.tooltip_text = "Selected" if selected else "Select %s" % text
	button.pressed.connect(_on_builder_choice_selected.bind(record_id, key))

	var normal_bg := Color.html("#111827") if selected else Color.html("#FFFFFF")
	var normal_border := Color.html("#111827") if selected else Color.html("#D1D5DB")
	var hover_bg := Color.html("#1F2937") if selected else Color.html("#EEF2FF")
	var hover_border := Color.html("#1F2937") if selected else Color.html("#534AB7")
	button.add_theme_stylebox_override("normal", _panel_style(normal_bg, normal_border))
	button.add_theme_stylebox_override("hover", _panel_style(hover_bg, hover_border))
	button.add_theme_stylebox_override("pressed", _panel_style(Color.html("#374151"), Color.html("#111827")))
	button.add_theme_color_override("font_color", Color.html("#FFFFFF") if selected else Color.html("#111827"))
	button.add_theme_color_override("font_hover_color", Color.html("#FFFFFF") if selected else Color.html("#111827"))
	return button

func _selected_slot_panel(key: String, record: Dictionary) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color.html("#EEF2FF"), Color.html("#534AB7")))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 7)
	margin.add_child(stack)

	if record.is_empty():
		stack.add_child(_status("Select Block, Induction, and Material to view the curve.", false))
		return panel

	stack.add_child(_label("Selected: %s" % record.get("name", "Unnamed"), 14, Color.html("#111827")))
	stack.add_child(_body_text(_format_choice_detail(key, record)))
	for metric in _selector_metrics(key, record):
		stack.add_child(_selector_metric_bar(metric))
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
		if setup.has("errors"):
			stack.add_child(_bullet_list(setup.get("errors", [])))
		stack.add_child(_body_text("Select Block, Induction, and Material to view the curve."))
		return panel

	var title := "%s + %s + %s" % [setup["block"].get("name", "Block"), setup["induction"].get("name", "Induction"), setup["material"].get("name", "Material")]
	stack.add_child(_body_text(title))
	stack.add_child(_body_text(str(setup["curve_summary"])))
	stack.add_child(_curve_card(setup))

	stack.add_child(_metric_row("Peak power", "%s hp" % setup["peak_power_hp"]))
	stack.add_child(_metric_row("Torque", "%s Nm" % setup["torque_nm"]))
	stack.add_child(_metric_row("Mass", "%s kg" % setup["mass_kg"]))
	stack.add_child(_metric_row("RPM range", "%s-%s rpm" % [setup["rpm_min"], setup["rpm_max"]]))

	stack.add_child(_meter_row("Engine health", float(setup.get("engine_health_score", 100.0)), 120.0, true))
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
		var controls := HBoxContainer.new()
		controls.add_theme_constant_override("separation", 8)
		stack.add_child(controls)

		var start_button := Button.new()
		_bench_toggle_button = start_button
		start_button.text = "Start"
		start_button.disabled = true
		start_button.tooltip_text = str(setup["error"])
		controls.add_child(start_button)

		var reset_button := Button.new()
		reset_button.text = "Reset"
		reset_button.disabled = true
		reset_button.tooltip_text = str(setup["error"])
		controls.add_child(reset_button)

		stack.add_child(_status(str(setup["error"]), false))
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
	var setup := _current_setup()
	if setup.has("error"):
		_bench_running = false
		return

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

	var entries := _comparison_entries()
	if entries.size() < 2:
		stack.add_child(_body_text("Save at least one valid setup to overlay power curves. Comparison is limited to the current setup plus two saved configs."))
		if _saved_setups.is_empty():
			return panel
		stack.add_child(_label("Saved Library", 15, Color.html("#111827")))
		stack.add_child(_saved_setup_strip())
		return panel

	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", 12)
	stack.add_child(legend)
	for entry in entries:
		var item: Dictionary = entry
		legend.add_child(_legend_item(str(item.get("label", "Setup")), item.get("color", Color.html("#534AB7")), "%s hp" % item.get("peak_power", "?")))

	var chart := CurveChart.new()
	chart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chart.set_power_overlay(entries)
	stack.add_child(chart)

	stack.add_child(_comparison_diff_block(entries))
	if _saved_setups.size() > COMPARISON_LIMIT - 1:
		stack.add_child(_body_text("Showing current setup plus the first two saved setups. Keep overlays to three configs to avoid graph noise."))

	stack.add_child(_label("Saved Library", 15, Color.html("#111827")))
	stack.add_child(_saved_setup_strip())
	return panel

func _saved_setup_strip() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 170)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	scroll.add_child(row)

	for index in range(_saved_setups.size()):
		row.add_child(_saved_setup_card(index))
	return scroll

func _comparison_entries() -> Array:
	var entries: Array = []
	var current_setup := _current_base_setup()
	if not current_setup.has("error"):
		entries.append(_comparison_entry("Current", current_setup, 0))

	for index in range(_saved_setups.size()):
		if entries.size() >= COMPARISON_LIMIT:
			break

		var saved: Dictionary = _saved_setups[index]
		var setup: Dictionary = saved.get("setup", {})
		if setup.has("error") or setup.is_empty():
			continue

		entries.append(_comparison_entry(str(saved.get("name", "Setup")), setup, entries.size()))

	return entries

func _comparison_entry(label: String, setup: Dictionary, index: int) -> Dictionary:
	var color_index := index % COMPARISON_COLORS.size()
	return {
		"label": label,
		"setup": setup,
		"color": Color.html(str(COMPARISON_COLORS[color_index])),
		"peak_power": setup.get("peak_power_hp", "?")
	}

func _comparison_diff_block(entries: Array) -> VBoxContainer:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 5)
	stack.add_child(_label("Stat Diff vs Baseline", 15, Color.html("#111827")))

	var baseline_entry: Dictionary = entries[0]
	var baseline: Dictionary = baseline_entry.get("setup", {})
	for entry_item in entries:
		if typeof(entry_item) != TYPE_DICTIONARY:
			continue

		var entry: Dictionary = entry_item
		var setup: Dictionary = entry.get("setup", {})
		var text := "%s | Power %s | Torque %s | Peak RPM %s | Mass %s" % [
			entry.get("label", "Setup"),
			_value_with_delta(float(setup.get("peak_power_hp", 0.0)), float(baseline.get("peak_power_hp", 0.0)), " hp"),
			_value_with_delta(float(setup.get("torque_nm", 0.0)), float(baseline.get("torque_nm", 0.0)), " Nm"),
			_value_with_delta(float(_peak_power_rpm(setup)), float(_peak_power_rpm(baseline)), " rpm"),
			_value_with_delta(float(setup.get("mass_kg", 0.0)), float(baseline.get("mass_kg", 0.0)), " kg")
		]
		stack.add_child(_body_text(text))

	return stack

func _value_with_delta(value: float, baseline: float, suffix: String) -> String:
	var absolute := "%0.0f%s" % [value, suffix]
	if absf(baseline) <= 0.001 or is_equal_approx(value, baseline):
		return "%s (base)" % absolute

	var delta := (value - baseline) / baseline * 100.0
	return "%s (%+0.0f%%)" % [absolute, delta]

func _peak_power_rpm(setup: Dictionary) -> int:
	var curves: Dictionary = setup.get("curves", {})
	var points: Array = curves.get("power", [])
	var best_rpm := int(setup.get("rpm_max", 0))
	var best_value := -INF
	for item in points:
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var point: Dictionary = item
		var value := float(point.get("value", 0.0))
		if value > best_value:
			best_value = value
			best_rpm = int(point.get("rpm", best_rpm))
	return best_rpm

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
	stack.add_child(_metric_row("Health", "%s / 120" % setup.get("engine_health_score", "?")))
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
	var setup := _current_base_setup()
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

func _load_progression() -> void:
	_progression = _default_progression()
	if not FileAccess.file_exists(PROGRESSION_PATH):
		_write_progression()
		return

	var text := FileAccess.get_file_as_string(PROGRESSION_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_write_progression()
		return

	var data: Dictionary = parsed
	if int(data.get("version", 0)) != PROGRESSION_VERSION:
		_write_progression()
		return

	_progression = _normalized_progression(data)
	_write_progression()

func _write_progression() -> void:
	var file := FileAccess.open(PROGRESSION_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write progression to %s" % PROGRESSION_PATH)
		return

	file.store_string(JSON.stringify(_progression, "\t"))

func _default_progression() -> Dictionary:
	return {
		"version": PROGRESSION_VERSION,
		"unlocked": PROGRESSION_STARTER_UNLOCKS.duplicate(true),
		"completed_rules": [],
		"clean_race_count": 0,
		"last_message": "Progression prototype loaded. Builder options stay open."
	}

func _normalized_progression(data: Dictionary) -> Dictionary:
	var normalized := _default_progression()
	var raw_unlocked: Dictionary = data.get("unlocked", {})
	var unlocked: Dictionary = normalized["unlocked"]
	for collection_name in unlocked.keys():
		var ids: Array = unlocked[collection_name]
		var raw_ids: Variant = raw_unlocked.get(collection_name, [])
		if typeof(raw_ids) == TYPE_ARRAY:
			for raw_id in raw_ids:
				var part_id := str(raw_id)
				if not ids.has(part_id):
					ids.append(part_id)
		unlocked[collection_name] = ids

	normalized["completed_rules"] = _string_array(data.get("completed_rules", []))
	normalized["clean_race_count"] = max(0, int(data.get("clean_race_count", 0)))
	normalized["last_message"] = str(data.get("last_message", normalized["last_message"]))
	return normalized

func _string_array(raw: Variant) -> Array:
	var result: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return result

	for item in raw:
		result.append(str(item))
	return result

func _apply_progression_after_race(count_clean_race: bool) -> Array:
	if _race_result.is_empty() or _race_result.has("error"):
		_last_unlocks.clear()
		return []

	var changed := false
	var messages: Array = []
	if count_clean_race and _is_clean_race_result(_race_result):
		_progression["clean_race_count"] = int(_progression.get("clean_race_count", 0)) + 1
		changed = true
		messages.append("Clean race saved %d/3." % int(_progression.get("clean_race_count", 0)))

	var completed: Array = _progression.get("completed_rules", [])
	for item in PROGRESSION_RULES:
		var rule: Dictionary = item
		var rule_id := str(rule.get("id", ""))
		if rule_id == "" or completed.has(rule_id):
			continue

		if not _progression_rule_met(rule, _race_result):
			continue

		var unlocked_parts := _unlock_parts(rule.get("unlocks", {}))
		completed.append(rule_id)
		changed = true
		if unlocked_parts.is_empty():
			messages.append("%s complete." % rule.get("title", "Progression"))
		else:
			messages.append("%s unlocked %s." % [rule.get("title", "Progression"), _join_strings(unlocked_parts, ", ")])

	_progression["completed_rules"] = completed
	_last_unlocks = messages
	if not messages.is_empty():
		_progression["last_message"] = _join_strings(messages, " ")

	if changed:
		_write_progression()

	return messages

func _progression_rule_met(rule: Dictionary, race_result: Dictionary) -> bool:
	var track: Dictionary = race_result.get("track", {})
	var setup: Dictionary = race_result.get("setup", {})
	if rule.has("track_id") and str(track.get("id", "")) != str(rule.get("track_id", "")):
		return false
	if rule.has("fit_min") and float(race_result.get("fit_score", 0.0)) < float(rule.get("fit_min", 0.0)):
		return false
	if rule.has("heat_max") and float(race_result.get("effective_heat", 999.0)) > float(rule.get("heat_max", 999.0)):
		return false
	if rule.has("reliability_min") and float(race_result.get("effective_reliability", 0.0)) < float(rule.get("reliability_min", 0.0)):
		return false
	if rule.has("lap_delta_max") and float(race_result.get("delta_vs_base", 999.0)) > float(rule.get("lap_delta_max", 999.0)):
		return false
	if rule.has("power_min") and float(setup.get("peak_power_hp", 0.0)) < float(rule.get("power_min", 0.0)):
		return false
	if rule.has("clean_races") and int(_progression.get("clean_race_count", 0)) < int(rule.get("clean_races", 0)):
		return false
	return true

func _is_clean_race_result(race_result: Dictionary) -> bool:
	return float(race_result.get("fit_score", 0.0)) >= 74.0 and float(race_result.get("effective_heat", 999.0)) <= 125.0 and float(race_result.get("effective_reliability", 0.0)) >= 55.0

func _unlock_parts(unlocks: Dictionary) -> Array:
	var unlocked_parts: Array = []
	var unlocked: Dictionary = _progression.get("unlocked", {})
	for collection_name in unlocks.keys():
		var ids: Array = unlocked.get(collection_name, [])
		var raw_part_ids: Variant = unlocks.get(collection_name, [])
		if typeof(raw_part_ids) != TYPE_ARRAY:
			continue

		for raw_part_id in raw_part_ids:
			var part_id := str(raw_part_id)
			if ids.has(part_id):
				continue
			if GameData.get_record_by_id(collection_name, part_id).is_empty():
				continue

			ids.append(part_id)
			unlocked_parts.append(_part_display_name(collection_name, part_id))
		unlocked[collection_name] = ids

	_progression["unlocked"] = unlocked
	return unlocked_parts

func _part_display_name(collection_name: String, part_id: String) -> String:
	var record := GameData.get_record_by_id(collection_name, part_id)
	if record.is_empty():
		return part_id
	return str(record.get("name", part_id))

func _join_strings(items: Array, delimiter: String) -> String:
	var text := ""
	for index in range(items.size()):
		if index > 0:
			text += delimiter
		text += str(items[index])
	return text

func _load_garage_state() -> void:
	_garage_state = _default_garage_state()
	if not FileAccess.file_exists(GARAGE_STATE_PATH):
		_write_garage_state()
		return

	var text := FileAccess.get_file_as_string(GARAGE_STATE_PATH)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		_write_garage_state()
		return

	var data: Dictionary = parsed
	if int(data.get("version", 0)) != GARAGE_STATE_VERSION:
		_write_garage_state()
		return

	_garage_state = _normalized_garage_state(data)
	_write_garage_state()

func _write_garage_state() -> void:
	var file := FileAccess.open(GARAGE_STATE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write garage state to %s" % GARAGE_STATE_PATH)
		return

	file.store_string(JSON.stringify(_garage_state, "\t"))

func _default_garage_state() -> Dictionary:
	return {
		"version": GARAGE_STATE_VERSION,
		"damage": 0.0,
		"part_damage": {
			"block": 0.0,
			"induction": 0.0,
			"material": 0.0
		},
		"credits": GARAGE_STARTING_CREDITS,
		"total_earned": 0,
		"total_spent": 0,
		"incident_count": 0,
		"service_count": 0,
		"failure_event_count": 0,
		"failure_events": [],
		"last_message": "Garage ready."
	}

func _normalized_garage_state(data: Dictionary) -> Dictionary:
	var normalized := _default_garage_state()
	normalized["damage"] = snappedf(clampf(float(data.get("damage", 0.0)), 0.0, GARAGE_MAX_DAMAGE), 0.1)
	normalized["part_damage"] = _normalized_part_damage(data.get("part_damage", {}))
	normalized["credits"] = max(0, int(data.get("credits", GARAGE_STARTING_CREDITS)))
	normalized["total_earned"] = max(0, int(data.get("total_earned", 0)))
	normalized["total_spent"] = max(0, int(data.get("total_spent", 0)))
	normalized["incident_count"] = max(0, int(data.get("incident_count", 0)))
	normalized["service_count"] = max(0, int(data.get("service_count", 0)))
	normalized["failure_event_count"] = max(0, int(data.get("failure_event_count", 0)))
	normalized["failure_events"] = _normalized_failure_events(data.get("failure_events", []))
	normalized["last_message"] = str(data.get("last_message", normalized["last_message"]))
	return normalized

func _normalized_part_damage(raw: Variant) -> Dictionary:
	var result := {
		"block": 0.0,
		"induction": 0.0,
		"material": 0.0
	}
	if typeof(raw) != TYPE_DICTIONARY:
		return result

	var raw_dict: Dictionary = raw
	for key in GARAGE_PART_KEYS:
		result[key] = snappedf(clampf(float(raw_dict.get(key, 0.0)), 0.0, GARAGE_MAX_DAMAGE), 0.1)
	return result

func _normalized_failure_events(raw: Variant) -> Array:
	var result: Array = []
	if typeof(raw) != TYPE_ARRAY:
		return result

	for item in raw:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = item
		result.append({
			"id": str(event.get("id", "")),
			"part": str(event.get("part", "")),
			"severity": str(event.get("severity", "minor")),
			"title": str(event.get("title", "Service Event")),
			"body": str(event.get("body", "")),
			"wear_before": snappedf(float(event.get("wear_before", 0.0)), 0.1),
			"wear_after": snappedf(float(event.get("wear_after", 0.0)), 0.1),
			"applied": bool(event.get("applied", false))
		})

	return result.slice(maxi(result.size() - 8, 0), result.size())

func _garage_damage() -> float:
	return clampf(float(_garage_state.get("damage", 0.0)), 0.0, GARAGE_MAX_DAMAGE)

func _garage_part_damage(key: String) -> float:
	var part_damage: Dictionary = _garage_state.get("part_damage", {})
	return clampf(float(part_damage.get(key, 0.0)), 0.0, GARAGE_MAX_DAMAGE)

func _garage_part_damage_label(key: String) -> String:
	match key:
		"block":
			return "Block condition"
		"induction":
			return "Induction condition"
		"material":
			return "Material condition"
		_:
			return "%s condition" % key.capitalize()

func _garage_slot_condition(key: String) -> float:
	return snappedf(clampf(100.0 - _garage_part_damage(key), 0.0, 100.0), 0.1)

func _garage_condition() -> float:
	return snappedf(clampf(100.0 - _garage_damage(), 0.0, 100.0), 0.1)

func _garage_condition_text() -> String:
	var condition := _garage_condition()
	if condition < 45.0:
		return "Critical service required."
	if condition < 70.0:
		return "Worn: performance is degraded."
	if condition < 92.0:
		return "Light wear: service soon."
	return "Ready."

func _garage_credits() -> int:
	return max(0, int(_garage_state.get("credits", GARAGE_STARTING_CREDITS)))

func _full_repair_cost() -> int:
	return int(ceil((_garage_damage() + _garage_total_part_damage() * 0.45) * float(GARAGE_REPAIR_COST_PER_DAMAGE)))

func _budget_repair_amount() -> float:
	var budget := mini(_garage_credits(), GARAGE_BUDGET_REPAIR_CREDITS)
	return snappedf(clampf(float(budget) / float(GARAGE_REPAIR_COST_PER_DAMAGE), 0.0, _garage_damage()), 0.1)

func _garage_total_part_damage() -> float:
	var total := 0.0
	for key in GARAGE_PART_KEYS:
		total += _garage_part_damage(key)
	return snappedf(total, 0.1)

func _race_reward_estimate(race_result: Dictionary, damage_report: Dictionary) -> Dictionary:
	if race_result.is_empty() or race_result.has("error"):
		return {}

	var fit := float(race_result.get("fit_score", 0.0))
	var delta := float(race_result.get("delta_vs_base", 0.0))
	var heat := float(race_result.get("effective_heat", 100.0))
	var reliability := float(race_result.get("effective_reliability", 100.0))
	var damage := float(damage_report.get("damage", 0.0))
	var base := 420
	var fit_bonus := int(round(fit * 5.0))
	var pace_bonus := int(round(maxf(0.0, -delta) * 36.0))
	var clean_bonus := 180 if _is_clean_race_result(race_result) else 0
	var risk_penalty := int(round(damage * 8.0 + maxf(0.0, heat - 125.0) * 3.0 + maxf(0.0, 55.0 - reliability) * 4.0))
	var payout := clampi(base + fit_bonus + pace_bonus + clean_bonus - risk_penalty, 160, 1400)
	var summary := "Earned %d credits." % payout
	if clean_bonus > 0:
		summary = "Clean run payout: %d credits." % payout
	elif damage >= 20.0:
		summary = "Risky run payout reduced to %d credits." % payout

	return {
		"credits": payout,
		"base": base,
		"fit_bonus": fit_bonus,
		"pace_bonus": pace_bonus,
		"clean_bonus": clean_bonus,
		"risk_penalty": risk_penalty,
		"summary": summary,
		"applied": false
	}

func _service_recommendations() -> Array:
	var recommendations: Array = []
	if _garage_damage() >= 70.0:
		recommendations.append({
			"severity": "critical",
			"title": "Full service required",
			"body": "Global condition is below safe race range. Repair before another push-heavy run."
		})
	elif _garage_damage() >= 35.0:
		recommendations.append({
			"severity": "warn",
			"title": "General wear service",
			"body": "Garage damage is stacking. Budget repair can recover enough condition for testing."
		})

	for key in GARAGE_PART_KEYS:
		var wear := _garage_part_damage(key)
		if wear >= 85.0:
			recommendations.append(_part_service_recommendation(key, "critical", wear))
		elif wear >= 65.0:
			recommendations.append(_part_service_recommendation(key, "warn", wear))
		elif wear >= 40.0:
			recommendations.append(_part_service_recommendation(key, "info", wear))

	if recommendations.is_empty():
		recommendations.append({
			"severity": "good",
			"title": "No service priority",
			"body": "Wear is inside the prototype safe range."
		})
	return recommendations

func _part_service_recommendation(key: String, severity: String, wear: float) -> Dictionary:
	var body := ""
	match key:
		"block":
			body = "Reduce compression or avoid repeated low-reliability runs. Block wear is cutting torque and durability."
		"induction":
			body = "Reduce boost or avoid repeated push windows. Induction wear is cutting response and peak output."
		"material":
			body = "Reduce heat load or use cooling decisions. Material wear is raising heat and lowering margin."
		_:
			body = "Service this slot group before another high-risk run."
	return {
		"severity": severity,
			"title": "%s at %0.1f/100" % [_garage_part_damage_label(key), _garage_slot_condition(key)],
			"body": body
	}

func _apply_race_reward(reward: Dictionary) -> Dictionary:
	if reward.is_empty():
		return {}

	var applied := reward.duplicate(true)
	var credits := int(applied.get("credits", 0))
	if credits > 0:
		_garage_state["credits"] = _garage_credits() + credits
		_garage_state["total_earned"] = int(_garage_state.get("total_earned", 0)) + credits
		applied["applied"] = true
	return applied

func _apply_garage_penalty_to_setup(base_setup: Dictionary) -> Dictionary:
	if base_setup.has("error"):
		return base_setup

	var damage := _garage_damage()
	var block_wear := _garage_part_damage("block")
	var induction_wear := _garage_part_damage("induction")
	var material_wear := _garage_part_damage("material")
	if damage <= 0.0 and block_wear <= 0.0 and induction_wear <= 0.0 and material_wear <= 0.0:
		return base_setup

	var setup := base_setup.duplicate(true)
	var power_mult := clampf(1.0 - damage * 0.0014 - block_wear * 0.0015 - induction_wear * 0.0022, 0.72, 1.0)
	var torque_mult := clampf(1.0 - damage * 0.0011 - block_wear * 0.0018 - induction_wear * 0.0012, 0.78, 1.0)
	var heat_add := damage * 0.22 + material_wear * 0.42 + induction_wear * 0.2
	var reliability_sub := damage * 0.32 + block_wear * 0.55 + material_wear * 0.18
	var response_sub := damage * 0.12 + induction_wear * 0.32
	var push_sub := damage * 0.38 + block_wear * 0.42 + induction_wear * 0.24 + material_wear * 0.28

	setup["peak_power_hp"] = int(round(float(setup.get("peak_power_hp", 0.0)) * power_mult))
	setup["torque_nm"] = int(round(float(setup.get("torque_nm", 0.0)) * torque_mult))
	setup["heat_score"] = snappedf(clampf(float(setup.get("heat_score", 0.0)) + heat_add, 0.0, 180.0), 0.1)
	setup["reliability_score"] = snappedf(clampf(float(setup.get("reliability_score", 0.0)) - reliability_sub, 0.0, 120.0), 0.1)
	setup["response_score"] = snappedf(clampf(float(setup.get("response_score", 0.0)) - response_sub, 0.0, 120.0), 0.1)
	setup["push_margin"] = snappedf(clampf(float(setup.get("push_margin", 0.0)) - push_sub, 0.0, 120.0), 0.1)
	setup["garage_damage"] = snappedf(damage, 0.1)
	setup["garage_part_damage"] = _normalized_part_damage(_garage_state.get("part_damage", {}))
	setup["garage_condition"] = _garage_condition()
	setup["warning"] = "%s Garage wear: %0.1f damage, slot wear %0.1f." % [setup.get("warning", ""), damage, _garage_total_part_damage()]
	if setup.has("curves"):
		setup["curves"] = _degraded_curves(setup.get("curves", {}), power_mult, torque_mult)
	return setup

func _degraded_curves(curves: Dictionary, power_mult: float, torque_mult: float) -> Dictionary:
	var degraded := curves.duplicate(true)
	var power_points: Array = degraded.get("power", [])
	var torque_points: Array = degraded.get("torque", [])
	for point in power_points:
		if typeof(point) == TYPE_DICTIONARY:
			point["value"] = snappedf(float(point.get("value", 0.0)) * power_mult, 0.1)
	for point in torque_points:
		if typeof(point) == TYPE_DICTIONARY:
			point["value"] = snappedf(float(point.get("value", 0.0)) * torque_mult, 0.1)
	degraded["max_power"] = int(round(float(degraded.get("max_power", 0.0)) * power_mult))
	degraded["max_torque"] = int(round(float(degraded.get("max_torque", 0.0)) * torque_mult))
	return degraded

func _damage_estimate_for_race(race_result: Dictionary) -> Dictionary:
	if race_result.is_empty() or race_result.has("error"):
		return {}

	var heat := float(race_result.get("effective_heat", 100.0))
	var reliability := float(race_result.get("effective_reliability", 100.0))
	var effects: Dictionary = race_result.get("decision_effects", {})
	var heat_delta := maxf(0.0, float(effects.get("heat_delta", 0.0)))
	var reliability_delta := maxf(0.0, -float(effects.get("reliability_delta", 0.0)))
	var heat_damage := maxf(0.0, heat - 110.0) * 0.18 + maxf(0.0, heat - 125.0) * 0.35 + maxf(0.0, heat - 140.0) * 0.55
	var reliability_damage := maxf(0.0, 70.0 - reliability) * 0.15 + maxf(0.0, 55.0 - reliability) * 0.35 + maxf(0.0, 40.0 - reliability) * 0.6
	var tactical_damage := heat_delta * 0.08 + reliability_delta * 0.25
	var damage := clampf(heat_damage + reliability_damage + tactical_damage, 0.0, 45.0)
	if damage < 1.0:
		damage = 0.0
	damage = snappedf(damage, 0.1)

	var severity := "none"
	var summary := "No new service damage predicted."
	if damage >= 25.0:
		severity = "critical"
		summary = "Critical wear predicted: repair before another push run."
	elif damage >= 12.0:
		severity = "major"
		summary = "Major wear predicted from heat and reliability stress."
	elif damage > 0.0:
		severity = "minor"
		summary = "Minor wear predicted; service soon if stacking risky runs."
	var part_wear := _part_wear_estimate(race_result, damage, heat_damage, reliability_damage, tactical_damage)
	var part_damage_after := _projected_part_damage_after(part_wear)
	var failure_events := _failure_events_for_projected_wear(part_wear, part_damage_after)

	return {
		"damage": damage,
		"severity": severity,
		"summary": summary,
		"heat_component": snappedf(heat_damage, 0.1),
		"reliability_component": snappedf(reliability_damage, 0.1),
		"tactical_component": snappedf(tactical_damage, 0.1),
		"part_wear": part_wear,
		"part_damage_after": part_damage_after,
		"failure_events": failure_events,
		"condition_before": _garage_condition(),
		"condition_after": snappedf(clampf(_garage_condition() - damage, 0.0, 100.0), 0.1),
		"applied": false
	}

func _projected_part_damage_after(part_wear: Dictionary) -> Dictionary:
	var result := {}
	for key in GARAGE_PART_KEYS:
		result[key] = snappedf(clampf(_garage_part_damage(key) + float(part_wear.get(key, 0.0)), 0.0, GARAGE_MAX_DAMAGE), 0.1)
	return result

func _failure_events_for_projected_wear(part_wear: Dictionary, part_damage_after: Dictionary) -> Array:
	var events: Array = []
	for key in GARAGE_PART_KEYS:
		var wear_before := _garage_part_damage(key)
		var wear_after := float(part_damage_after.get(key, wear_before))
		var delta := float(part_wear.get(key, 0.0))
		if delta <= 0.0:
			continue

		var severity := ""
		if wear_before < 90.0 and wear_after >= 90.0:
			severity = "critical"
		elif wear_before < 70.0 and wear_after >= 70.0:
			severity = "major"
		elif wear_before < 45.0 and wear_after >= 45.0:
			severity = "minor"

		if severity == "":
			continue

		events.append(_part_failure_event(key, severity, wear_before, wear_after))
	return events

func _part_failure_event(key: String, severity: String, wear_before: float, wear_after: float) -> Dictionary:
	var title := ""
	var body := ""
	match key:
		"block":
			title = "Block service threshold crossed"
			body = "Block wear is high enough to threaten torque delivery and reliability."
		"induction":
			title = "Induction service threshold crossed"
			body = "Induction wear is high enough to threaten boost response and peak output."
		"material":
			title = "Material service threshold crossed"
			body = "Material wear is high enough to threaten heat control and durability margin."
		_:
			title = "Part service threshold crossed"
			body = "Wear has crossed a service threshold."
	return {
		"id": "%s_%s_%d" % [key, severity, Time.get_ticks_msec()],
		"part": key,
		"severity": severity,
		"title": title,
		"body": body,
		"wear_before": snappedf(wear_before, 0.1),
		"wear_after": snappedf(wear_after, 0.1),
		"applied": false
	}

func _part_wear_estimate(race_result: Dictionary, damage: float, heat_damage: float, reliability_damage: float, tactical_damage: float) -> Dictionary:
	var setup: Dictionary = race_result.get("setup", {})
	var block: Dictionary = setup.get("block", {})
	var induction: Dictionary = setup.get("induction", {})
	var material: Dictionary = setup.get("material", {})
	var block_reliability := maxf(float(block.get("reliability_factor", 1.0)), 0.25)
	var induction_reliability := maxf(float(induction.get("reliability_mult", 1.0)), 0.25)
	var material_durability := maxf(float(material.get("durability_mult", 1.0)), 0.25)
	var induction_lag := float(induction.get("lag", 0.0))
	var material_heat_ceiling := float(material.get("max_heat_mult", 1.0))
	var block_wear := (reliability_damage * 0.65 + heat_damage * 0.3 + damage * 0.08) / block_reliability
	var induction_wear := (tactical_damage * (0.75 + induction_lag * 0.35) + heat_damage * 0.18 + damage * 0.06) / induction_reliability
	var material_wear := (heat_damage * (0.62 / maxf(material_heat_ceiling, 0.6)) + reliability_damage * 0.18 + damage * 0.05) / material_durability
	return {
		"block": snappedf(clampf(block_wear, 0.0, 35.0), 0.1),
		"induction": snappedf(clampf(induction_wear, 0.0, 35.0), 0.1),
		"material": snappedf(clampf(material_wear, 0.0, 35.0), 0.1)
	}

func _current_damage_report() -> Dictionary:
	if _race_result.is_empty() or _race_result.has("error"):
		return {}
	if not _last_damage_report.is_empty():
		return _last_damage_report
	return _damage_estimate_for_race(_race_result)

func _current_reward_report() -> Dictionary:
	if _race_result.is_empty() or _race_result.has("error"):
		return {}
	if not _last_reward_report.is_empty():
		return _last_reward_report
	return _race_reward_estimate(_race_result, _current_damage_report())

func _apply_garage_damage_after_race(race_result: Dictionary) -> Dictionary:
	var report := _damage_estimate_for_race(race_result)
	if report.is_empty():
		return {}

	var damage := float(report.get("damage", 0.0))
	if damage > 0.0:
		_garage_state["damage"] = snappedf(clampf(_garage_damage() + damage, 0.0, GARAGE_MAX_DAMAGE), 0.1)
		_apply_part_wear(report.get("part_wear", {}))
		var applied_events := _record_failure_events(report.get("failure_events", []))
		report["failure_events"] = applied_events
		_garage_state["incident_count"] = int(_garage_state.get("incident_count", 0)) + 1
		if applied_events.is_empty():
			_garage_state["last_message"] = str(report.get("summary", "Garage wear recorded."))
		else:
			_garage_state["last_message"] = "%s %d service event(s) recorded." % [str(report.get("summary", "Garage wear recorded.")), applied_events.size()]
	else:
		_garage_state["last_message"] = "No new service damage from the saved race."

	report["condition_after"] = _garage_condition()
	report["applied"] = true
	_write_garage_state()
	return report

func _record_failure_events(raw_events: Variant) -> Array:
	var applied_events: Array = []
	if typeof(raw_events) != TYPE_ARRAY:
		return applied_events

	var history: Array = _garage_state.get("failure_events", [])
	for item in raw_events:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = item.duplicate(true)
		event["applied"] = true
		event["id"] = "service_%d" % (int(_garage_state.get("failure_event_count", 0)) + applied_events.size() + 1)
		applied_events.append(event)
		history.append(event)

	if applied_events.is_empty():
		return applied_events

	_garage_state["failure_event_count"] = int(_garage_state.get("failure_event_count", 0)) + applied_events.size()
	_garage_state["failure_events"] = _normalized_failure_events(history)
	return applied_events

func _apply_part_wear(raw_part_wear: Variant) -> void:
	if typeof(raw_part_wear) != TYPE_DICTIONARY:
		return

	var current := _normalized_part_damage(_garage_state.get("part_damage", {}))
	var part_wear: Dictionary = raw_part_wear
	for key in GARAGE_PART_KEYS:
		current[key] = snappedf(clampf(float(current.get(key, 0.0)) + float(part_wear.get(key, 0.0)), 0.0, GARAGE_MAX_DAMAGE), 0.1)
	_garage_state["part_damage"] = current

func _repair_garage() -> void:
	if _garage_damage() <= 0.0:
		return

	var cost := _full_repair_cost()
	if _garage_credits() < cost:
		_garage_state["last_message"] = "Need %d credits for full service." % cost
		_write_garage_state()
		_show_view(_current_view)
		return

	_apply_garage_repair(cost, _garage_damage(), "Full service complete for %d credits." % cost)

func _repair_garage_budget() -> void:
	if _garage_damage() <= 0.0 or _garage_credits() <= 0:
		return

	var spend := mini(mini(_garage_credits(), GARAGE_BUDGET_REPAIR_CREDITS), _full_repair_cost())
	var repair_amount := snappedf(clampf(float(spend) / float(GARAGE_REPAIR_COST_PER_DAMAGE), 0.0, _garage_damage()), 0.1)
	_apply_garage_repair(spend, repair_amount, "Budget repair removed %0.1f damage for %d credits." % [repair_amount, spend])

func _apply_garage_repair(cost: int, repair_amount: float, message: String) -> void:
	if cost <= 0 or repair_amount <= 0.0:
		return

	var old_damage := maxf(_garage_damage(), 0.01)
	var repair_ratio := clampf(repair_amount / old_damage, 0.0, 1.0)
	_garage_state["credits"] = maxi(0, _garage_credits() - cost)
	_garage_state["total_spent"] = int(_garage_state.get("total_spent", 0)) + cost
	_garage_state["damage"] = snappedf(clampf(_garage_damage() - repair_amount, 0.0, GARAGE_MAX_DAMAGE), 0.1)
	_reduce_part_wear(repair_ratio)
	_garage_state["service_count"] = int(_garage_state.get("service_count", 0)) + 1
	_garage_state["last_message"] = message
	_last_damage_report.clear()
	_last_reward_report.clear()
	_write_garage_state()
	_reset_race_result()
	_reset_test_bench()
	_show_view(_current_view)

func _reduce_part_wear(repair_ratio: float) -> void:
	var current := _normalized_part_damage(_garage_state.get("part_damage", {}))
	for key in GARAGE_PART_KEYS:
		current[key] = snappedf(clampf(float(current.get(key, 0.0)) * (1.0 - repair_ratio), 0.0, GARAGE_MAX_DAMAGE), 0.1)
	_garage_state["part_damage"] = current

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

	var damage_report := _current_damage_report()
	var reward_report := _current_reward_report()
	if not _race_committed:
		_apply_progression_after_race(true)
		damage_report = _apply_garage_damage_after_race(_race_result)
		_last_damage_report = damage_report.duplicate(true)
		reward_report = _apply_race_reward(_race_reward_estimate(_race_result, damage_report))
		_last_reward_report = reward_report.duplicate(true)
		_garage_state["last_message"] = "%s %s" % [str(reward_report.get("summary", "")), str(_garage_state.get("last_message", ""))]
		_write_garage_state()
		_race_committed = true

	var name := "Race %d" % _race_history_counter
	_race_history_counter += 1
	_race_history.append({
		"name": name,
		"selection": _builder_selection.duplicate(true),
		"tuning": _builder_tuning.duplicate(true),
		"track_id": _race_track_id,
		"decisions": _race_decisions.duplicate(true),
		"result": _race_result.duplicate(true),
		"garage_damage": damage_report.duplicate(true),
		"garage_reward": reward_report.duplicate(true)
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
	_last_damage_report = record.get("garage_damage", _damage_estimate_for_race(_race_result)).duplicate(true)
	_last_reward_report = record.get("garage_reward", _race_reward_estimate(_race_result, _last_damage_report)).duplicate(true)
	_race_committed = true
	_timeline_focus_index = 0
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
		"decisions": record.get("decisions", {}).duplicate(true),
		"garage_damage": record.get("garage_damage", {}).duplicate(true),
		"garage_reward": record.get("garage_reward", {}).duplicate(true)
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
		"result": result,
		"garage_damage": raw.get("garage_damage", {}).duplicate(true),
		"garage_reward": raw.get("garage_reward", {}).duplicate(true)
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
	var base_setup := _current_base_setup()
	return _apply_garage_penalty_to_setup(base_setup)

func _current_base_setup() -> Dictionary:
	var summary: Dictionary = GameData.get_summary()
	var errors: Array = summary.get("errors", [])
	if not errors.is_empty():
		return {
			"error": "Data contract validator failed. Fix the listed data file fields before running the builder.",
			"errors": errors
		}

	for key in _builder_selection.keys():
		var selected_id := str(_builder_selection[key])
		var collection_name := _builder_collection_name(key)
		if selected_id == "":
			return {"error": "Select Block, Induction, and Material to view the curve."}
		if GameData.get_record_by_id(collection_name, selected_id).is_empty():
			return {"error": "%s selection is missing from %s." % [selected_id, collection_name]}

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

func _on_builder_choice_selected(selected_id: String, key: String) -> void:
	_builder_selection[key] = selected_id
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
			return str(record.get("torque_profile", ""))
		"induction":
			return "Output, response, and reliability trade off through the bars below."
		"material":
			return "Material choice changes weight, heat ceiling, and durability margin."
		_:
			return str(record)

func _selector_metrics(key: String, record: Dictionary) -> Array:
	match key:
		"block":
			var rpm_range: Array = record.get("rpm_range", [0, 0])
			var rpm_min := float(rpm_range[0]) if rpm_range.size() > 0 else 0.0
			var rpm_max := float(rpm_range[1]) if rpm_range.size() > 1 else 0.0
			var rpm_span := rpm_max - rpm_min
			return [
				{"label": "RPM range", "value": _norm_range(rpm_span, 5600.0, 7600.0), "note": _tier_text(_norm_range(rpm_span, 5600.0, 7600.0))},
				{"label": "Shape", "value": _block_peakiness(record), "note": _shape_text(_block_peakiness(record))},
				{"label": "Reliability", "value": _norm_range(float(record.get("reliability_factor", 1.0)), 0.88, 1.08), "note": _tier_text(_norm_range(float(record.get("reliability_factor", 1.0)), 0.88, 1.08))}
			]
		"induction":
			var output := _norm_range(float(record.get("power_mult", 1.0)), 1.0, 1.46)
			var response := 1.0 - _norm_range(float(record.get("lag", 0.0)), 0.0, 0.4)
			var reliability := _norm_range(float(record.get("reliability_mult", 1.0)), 0.82, 1.08)
			return [
				{"label": "Output", "value": output, "note": _tier_text(output)},
				{"label": "Response", "value": response, "note": _tier_text(response)},
				{"label": "Reliability", "value": reliability, "note": _tier_text(reliability)}
			]
		"material":
			var weight := 1.0 - _norm_range(float(record.get("mass_mult", 1.0)), 0.82, 1.0)
			var heat := _norm_range(float(record.get("max_heat_mult", 1.0)), 1.0, 1.24)
			var durability := _norm_range(float(record.get("durability_mult", 1.0)), 0.82, 1.0)
			return [
				{"label": "Weight saving", "value": weight, "note": _tier_text(weight)},
				{"label": "Heat ceiling", "value": heat, "note": _tier_text(heat)},
				{"label": "Durability", "value": durability, "note": _tier_text(durability)}
			]
		_:
			return []

func _selector_metric_bar(metric: Dictionary) -> VBoxContainer:
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 3)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	stack.add_child(row)

	var label := _body_text(str(metric.get("label", "Metric")))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	row.add_child(_label(str(metric.get("note", "")), 12, Color.html("#111827")))

	var bar := ProgressBar.new()
	bar.max_value = 1.0
	bar.value = clampf(float(metric.get("value", 0.0)), 0.0, 1.0)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 8)
	_set_bar_fill(bar, _metric_bar_color(bar.value))
	stack.add_child(bar)
	return stack

func _norm_range(value: float, low: float, high: float) -> float:
	if is_equal_approx(low, high):
		return 0.0
	return clampf((value - low) / (high - low), 0.0, 1.0)

func _block_peakiness(record: Dictionary) -> float:
	var rpm_range: Array = record.get("rpm_range", [0, 0])
	var rpm_min := float(rpm_range[0]) if rpm_range.size() > 0 else 0.0
	var rpm_max := float(rpm_range[1]) if rpm_range.size() > 1 else 0.0
	var high_rpm := _norm_range(rpm_max, 7600.0, 10500.0)
	var late_start := _norm_range(rpm_min, 1400.0, 3200.0)
	return clampf(high_rpm * 0.72 + late_start * 0.28, 0.0, 1.0)

func _tier_text(value: float) -> String:
	if value >= 0.68:
		return "High"
	if value >= 0.36:
		return "Mid"
	return "Low"

func _shape_text(value: float) -> String:
	if value >= 0.68:
		return "Peaky"
	if value >= 0.36:
		return "Mixed"
	return "Flat"

func _metric_bar_color(value: float) -> Color:
	if value >= 0.68:
		return Color.html("#0F6E56")
	if value >= 0.36:
		return Color.html("#B45309")
	return Color.html("#9F1239")

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
	controls.add_child(_garage_status_panel())

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
	var best_record := _best_race_history_record_for_track(_race_track_id)
	if best_record.is_empty():
		stack.add_child(_body_text("No saved run on this track yet."))
	else:
		var best_result: Dictionary = best_record.get("result", {})
		stack.add_child(_metric_row("Best saved", "%s / %ss" % [best_record.get("name", "Race"), best_result.get("total_time", "?")]))

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
	if _garage_damage() > 0.0:
		stack.add_child(_status("Garage condition %s/100 is reducing current output." % _garage_condition(), _garage_condition() >= 70.0))
	if _garage_total_part_damage() > 0.0:
		stack.add_child(_body_text("Slot condition: block %0.1f | induction %0.1f | material %0.1f" % [_garage_slot_condition("block"), _garage_slot_condition("induction"), _garage_slot_condition("material")]))
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
	if not _last_unlocks.is_empty():
		stack.add_child(_status("Progression: %s" % _join_strings(_last_unlocks, " | "), true))
	stack.add_child(_race_best_comparison_panel(_race_result))

	var save_preview: Dictionary = _race_result.get("save_preview", {})
	if not save_preview.is_empty():
		stack.add_child(_label("Pre-Save Preview", 16, Color.html("#111827")))
		stack.add_child(_metric_row("Decision time", "%+0.2fs" % float(save_preview.get("decision_time_delta", 0.0))))
		stack.add_child(_metric_row("Decision heat", "%+0.1f" % float(save_preview.get("decision_heat_delta", 0.0))))
		stack.add_child(_metric_row("Decision reliability", "%+0.1f" % float(save_preview.get("decision_reliability_delta", 0.0))))
		stack.add_child(_metric_row("Save risk", str(save_preview.get("risk", "Stable"))))
		stack.add_child(_status(str(save_preview.get("summary", "")), str(save_preview.get("risk", "")) != "Critical"))

	var damage_report := _current_damage_report()
	if not damage_report.is_empty():
		stack.add_child(_label("Garage Impact", 16, Color.html("#111827")))
		stack.add_child(_metric_row("Projected damage", "+%s" % damage_report.get("damage", "0")))
		stack.add_child(_metric_row("Condition after save", "%s / 100" % damage_report.get("condition_after", _garage_condition())))
		stack.add_child(_body_text(str(damage_report.get("summary", ""))))
		var part_wear: Dictionary = damage_report.get("part_wear", {})
		if not part_wear.is_empty():
			stack.add_child(_metric_row("Block slot wear", "+%s" % part_wear.get("block", "0")))
			stack.add_child(_metric_row("Induction slot wear", "+%s" % part_wear.get("induction", "0")))
			stack.add_child(_metric_row("Material slot wear", "+%s" % part_wear.get("material", "0")))
		var failure_events: Array = damage_report.get("failure_events", [])
		if not failure_events.is_empty():
			stack.add_child(_label("Service Events", 16, Color.html("#111827")))
			for event in failure_events:
				if typeof(event) == TYPE_DICTIONARY:
					stack.add_child(_service_event_card(event))
		if bool(damage_report.get("applied", false)):
			stack.add_child(_status("Garage damage has been applied for this saved run.", true))
		else:
			stack.add_child(_body_text("Save Race applies this wear to the garage state."))

	var reward_report := _current_reward_report()
	if not reward_report.is_empty():
		stack.add_child(_label("Race Payout", 16, Color.html("#111827")))
		stack.add_child(_metric_row("Credits", "+%s" % reward_report.get("credits", "0")))
		stack.add_child(_metric_row("Risk penalty", "-%s" % reward_report.get("risk_penalty", "0")))
		stack.add_child(_body_text(str(reward_report.get("summary", ""))))
		if bool(reward_report.get("applied", false)):
			stack.add_child(_status("Payout has been added to garage credits.", true))
		else:
			stack.add_child(_body_text("Save Race adds this payout once."))

	stack.add_child(_label("Sector Fit", 16, Color.html("#111827")))
	for sector in _race_result["sectors"]:
		var text := "%s - rating %s, weight %s\n%s" % [sector.get("name", "Sector"), sector.get("rating", "?"), sector.get("bias", "?"), sector.get("note", "")]
		stack.add_child(_info_card(text))

	var timeline: Array = _race_result.get("timeline", [])
	if not timeline.is_empty():
		stack.add_child(_label("Race Timeline", 16, Color.html("#111827")))
		stack.add_child(_race_timeline_stepper(timeline))

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
	save_button.text = "Save Copy" if _race_committed else "Save Race"
	save_button.pressed.connect(_save_current_race)
	actions.add_child(save_button)
	return panel

func _race_best_comparison_panel(race_result: Dictionary) -> PanelContainer:
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
	stack.add_child(_label("Best Saved Comparison", 16, Color.html("#111827")))

	var track: Dictionary = race_result.get("track", {})
	var best_record := _best_race_history_record_for_track(str(track.get("id", "")))
	if best_record.is_empty():
		stack.add_child(_body_text("Save a race on this track to compare the current run before opening Analysis."))
		return panel

	var best_result: Dictionary = best_record.get("result", {})
	var current_total := float(race_result.get("total_time", 0.0))
	var best_total := float(best_result.get("total_time", 0.0))
	var delta := current_total - best_total
	stack.add_child(_metric_row("Best run", "%s / %ss" % [best_record.get("name", "Race"), best_result.get("total_time", "?")]))
	stack.add_child(_metric_row("Current run", "%ss" % race_result.get("total_time", "?")))
	stack.add_child(_metric_row("Delta", "%+0.2fs" % delta))
	stack.add_child(_status("Current run is faster than saved best." if delta < -0.01 else "Saved best is still faster or tied.", delta < -0.01))
	return panel

func _race_timeline_stepper(timeline: Array) -> PanelContainer:
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

	_clamp_timeline_focus()
	var index := clampi(_timeline_focus_index, 0, timeline.size() - 1)
	var event: Dictionary = timeline[index]

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	stack.add_child(controls)

	var previous := Button.new()
	previous.text = "Previous"
	previous.disabled = index <= 0
	previous.pressed.connect(_move_timeline_focus.bind(-1))
	controls.add_child(previous)

	var label := _label("Step %d/%d" % [index + 1, timeline.size()], 14, Color.html("#111827"))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.add_child(label)

	var next := Button.new()
	next.text = "Next"
	next.disabled = index >= timeline.size() - 1
	next.pressed.connect(_move_timeline_focus.bind(1))
	controls.add_child(next)

	stack.add_child(_race_timeline_card(event))
	return panel

func _race_timeline_card(event: Dictionary) -> PanelContainer:
	var text := "%s #%s - %s -> %s\nTime %+0.2fs (%+0.2fs cumulative) | Heat %s (%+0.1f) | Reliability %s (%+0.1f) | %s\n%s" % [
		event.get("marker", "Lap"),
		event.get("sequence", "?"),
		event.get("window", "Window"),
		event.get("choice", "Choice"),
		float(event.get("time_delta", 0.0)),
		float(event.get("cumulative_time_delta", 0.0)),
		event.get("projected_heat", "?"),
		float(event.get("heat_delta", 0.0)),
		event.get("projected_reliability", "?"),
		float(event.get("reliability_delta", 0.0)),
		event.get("risk", "Stable"),
		event.get("note", "")
	]
	return _info_card(text)

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
	var damage_report: Dictionary = record.get("garage_damage", {})
	if not damage_report.is_empty():
		stack.add_child(_metric_row("Wear", "+%s" % damage_report.get("damage", "0")))
		var part_wear: Dictionary = damage_report.get("part_wear", {})
		if not part_wear.is_empty():
			stack.add_child(_metric_row("Slot wear", "B%s I%s M%s" % [part_wear.get("block", "0"), part_wear.get("induction", "0"), part_wear.get("material", "0")]))
		var failure_events: Array = damage_report.get("failure_events", [])
		if not failure_events.is_empty():
			stack.add_child(_metric_row("Events", str(failure_events.size())))
	var reward_report: Dictionary = record.get("garage_reward", {})
	if not reward_report.is_empty():
		stack.add_child(_metric_row("Credits", "+%s" % reward_report.get("credits", "0")))

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
	_last_damage_report.clear()
	_last_reward_report.clear()
	_race_committed = false
	_timeline_focus_index = 0
	_show_view(VIEW_RACE_SIM)

func _run_race_sim() -> void:
	_ensure_builder_selection()
	_ensure_race_track()
	_race_result = GameData.calculate_race_result(_current_setup(), _race_track_id, _race_decisions)
	_clamp_timeline_focus()
	_last_damage_report = _damage_estimate_for_race(_race_result)
	_last_reward_report = _race_reward_estimate(_race_result, _last_damage_report)
	_race_committed = false
	_apply_progression_after_race(false)
	_show_view(VIEW_RACE_SIM)

func _on_race_window_choice(window_type: String, choice_id: String) -> void:
	_race_decisions[window_type] = choice_id
	_run_race_sim()

func _reset_race_result() -> void:
	_race_result.clear()
	_race_decisions.clear()
	_last_damage_report.clear()
	_last_reward_report.clear()
	_race_committed = false
	_timeline_focus_index = 0

func _move_timeline_focus(delta: int) -> void:
	var timeline: Array = _race_result.get("timeline", [])
	if timeline.is_empty():
		_timeline_focus_index = 0
		return

	_timeline_focus_index = clampi(_timeline_focus_index + delta, 0, timeline.size() - 1)
	_show_view(VIEW_RACE_SIM)

func _clamp_timeline_focus() -> void:
	var timeline: Array = _race_result.get("timeline", [])
	if timeline.is_empty():
		_timeline_focus_index = 0
		return

	_timeline_focus_index = clampi(_timeline_focus_index, 0, timeline.size() - 1)

func _best_race_history_record_for_track(track_id: String) -> Dictionary:
	if track_id == "":
		return {}

	var best_record: Dictionary = {}
	var best_total := INF
	for item in _race_history:
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var record: Dictionary = item
		var result: Dictionary = record.get("result", {})
		var track: Dictionary = result.get("track", {})
		var result_track_id := str(track.get("id", record.get("track_id", "")))
		if result_track_id != track_id:
			continue

		var total := float(result.get("total_time", INF))
		if total <= 0.0 or total >= best_total:
			continue

		best_total = total
		best_record = record
	return best_record

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
	right.add_child(_progression_panel())
	right.add_child(_garage_status_panel())
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

	var timeline: Array = race_result.get("timeline", [])
	if not timeline.is_empty():
		for item in timeline:
			if typeof(item) == TYPE_DICTIONARY:
				var event: Dictionary = item
				var text := "%s - %s / %s\nTime %+0.2fs, heat %+0.1f, reliability %+0.1f. Result: heat %s, reliability %s." % [
					event.get("marker", "Lap"),
					event.get("window", "Window"),
					event.get("choice", "Choice"),
					float(event.get("time_delta", 0.0)),
					float(event.get("heat_delta", 0.0)),
					float(event.get("reliability_delta", 0.0)),
					event.get("projected_heat", "?"),
					event.get("projected_reliability", "?")
				]
				stack.add_child(_info_card(text))
	else:
		for item in effects.get("log", []):
			var decision: Dictionary = item
			var text := "%s - %s\n%s" % [decision.get("window", "Window"), decision.get("choice", "Choice"), decision.get("note", "")]
			stack.add_child(_info_card(text))

	return panel

func _service_event_card(event: Dictionary) -> PanelContainer:
	var severity := str(event.get("severity", "minor"))
	var color := Color.html("#92400E")
	if severity == "critical":
		color = Color.html("#9F1239")
	elif severity == "major":
		color = Color.html("#B45309")

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style(Color.html("#FFFFFF"), Color.html("#D1D5DB")))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	margin.add_child(stack)
	stack.add_child(_label(str(event.get("title", "Service Event")), 14, color))
	stack.add_child(_body_text("%s Wear %s -> %s." % [event.get("body", ""), event.get("wear_before", "?"), event.get("wear_after", "?")]))
	return panel

func _garage_status_panel() -> PanelContainer:
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

	var condition := _garage_condition()
	var damage := _garage_damage()
	var full_cost := _full_repair_cost()
	var budget_amount := _budget_repair_amount()
	stack.add_child(_label("Garage Condition", 16, Color.html("#111827")))
	stack.add_child(_metric_row("Credits", str(_garage_credits())))
	stack.add_child(_meter_row("Condition", condition, 100.0, true))
	stack.add_child(_metric_row("Damage", "%s / 100" % snappedf(damage, 0.1)))
	stack.add_child(_metric_row("Slot wear total", "%s / 300" % _garage_total_part_damage()))
	for key in GARAGE_PART_KEYS:
		stack.add_child(_metric_row(_garage_part_damage_label(key), "%s / 100" % _garage_slot_condition(key)))
	stack.add_child(_metric_row("Full service cost", "%d credits" % full_cost))
	if budget_amount > 0.0 and damage > 0.0:
		stack.add_child(_metric_row("Budget repair", "%0.1f damage" % budget_amount))
	stack.add_child(_metric_row("Incidents", str(_garage_state.get("incident_count", 0))))
	stack.add_child(_metric_row("Services", str(_garage_state.get("service_count", 0))))
	stack.add_child(_metric_row("Earned", str(_garage_state.get("total_earned", 0))))
	stack.add_child(_metric_row("Spent", str(_garage_state.get("total_spent", 0))))
	stack.add_child(_status(_garage_condition_text(), condition >= 70.0))

	var last_message := str(_garage_state.get("last_message", ""))
	if last_message != "":
		stack.add_child(_body_text(last_message))

	var recommendations := _service_recommendations()
	if not recommendations.is_empty():
		stack.add_child(_label("Service Recommendations", 14, Color.html("#111827")))
		for item in recommendations.slice(0, min(recommendations.size(), 4)):
			if typeof(item) == TYPE_DICTIONARY:
				var recommendation: Dictionary = item
				stack.add_child(_body_text("%s\n%s" % [recommendation.get("title", "Recommendation"), recommendation.get("body", "")]))

	var failure_events: Array = _garage_state.get("failure_events", [])
	if not failure_events.is_empty():
		stack.add_child(_label("Recent Service Events", 14, Color.html("#111827")))
		for item in failure_events.slice(maxi(failure_events.size() - 3, 0), failure_events.size()):
			if typeof(item) == TYPE_DICTIONARY:
				stack.add_child(_service_event_card(item))

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	stack.add_child(actions)

	var repair_button := Button.new()
	repair_button.text = "Repair All"
	repair_button.disabled = damage <= 0.0 or _garage_credits() < full_cost
	repair_button.pressed.connect(_repair_garage)
	actions.add_child(repair_button)

	var budget_button := Button.new()
	budget_button.text = "Budget Repair"
	budget_button.disabled = damage <= 0.0 or _garage_credits() <= 0
	budget_button.pressed.connect(_repair_garage_budget)
	actions.add_child(budget_button)
	return panel

func _progression_panel() -> PanelContainer:
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
	stack.add_theme_constant_override("separation", 8)
	margin.add_child(stack)

	var completed_rules: Array = _progression.get("completed_rules", [])
	stack.add_child(_label("Progression", 16, Color.html("#111827")))
	stack.add_child(_body_text("Future-phase prototype only. Engine Builder keeps all block, induction, and material options open."))
	stack.add_child(_metric_row("Clean races", "%d/3" % mini(int(_progression.get("clean_race_count", 0)), 3)))
	stack.add_child(_metric_row("Rules complete", "%d/%d" % [completed_rules.size(), PROGRESSION_RULES.size()]))
	stack.add_child(_metric_row("Prototype unlocks", "%d/%d" % [_unlocked_part_count(), _total_part_count()]))

	var last_message := str(_progression.get("last_message", ""))
	if last_message != "":
		stack.add_child(_status(last_message, true))

	var next_rules := _next_progression_rules(3)
	if not next_rules.is_empty():
		stack.add_child(_label("Next Unlocks", 14, Color.html("#111827")))
		for rule in next_rules:
			var rule_text := "%s\n%s\nUnlocks: %s" % [rule.get("title", "Unlock"), rule.get("description", ""), _rule_unlock_names(rule)]
			stack.add_child(_body_text(rule_text))

	return panel

func _next_progression_rules(limit: int) -> Array:
	var completed_rules: Array = _progression.get("completed_rules", [])
	var next_rules: Array = []
	for item in PROGRESSION_RULES:
		var rule: Dictionary = item
		if completed_rules.has(str(rule.get("id", ""))):
			continue

		next_rules.append(rule)
		if next_rules.size() >= limit:
			break

	return next_rules

func _unlocked_part_count() -> int:
	var unlocked: Dictionary = _progression.get("unlocked", {})
	var count := 0
	for collection_name in ["blocks", "inductions", "materials"]:
		var ids: Array = unlocked.get(collection_name, [])
		for part_id in ids:
			if not GameData.get_record_by_id(collection_name, str(part_id)).is_empty():
				count += 1
	return count

func _total_part_count() -> int:
	return GameData.blocks.size() + GameData.inductions.size() + GameData.materials.size()

func _rule_unlock_names(rule: Dictionary) -> String:
	var names: Array = []
	var unlocks: Dictionary = rule.get("unlocks", {})
	for collection_name in unlocks.keys():
		var ids: Variant = unlocks.get(collection_name, [])
		if typeof(ids) != TYPE_ARRAY:
			continue

		for part_id in ids:
			names.append(_part_display_name(collection_name, str(part_id)))

	if names.is_empty():
		return "Progress marker"
	return _join_strings(names, ", ")

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
	layout.add_child(_data_contract_status_panel())
	layout.add_child(_body_text("Saved setup file: %s" % ProjectSettings.globalize_path(SAVED_SETUPS_PATH)))
	layout.add_child(_body_text("Race history file: %s" % ProjectSettings.globalize_path(RACE_HISTORY_PATH)))
	layout.add_child(_body_text("Progression file: %s" % ProjectSettings.globalize_path(PROGRESSION_PATH)))
	layout.add_child(_body_text("Garage state file: %s" % ProjectSettings.globalize_path(GARAGE_STATE_PATH)))
	layout.add_child(_progression_panel())
	layout.add_child(_garage_status_panel())

	if errors.is_empty():
		layout.add_child(_status("PASS: GameData loaded every Phase 1 data contract without validation errors.", true))
	else:
		layout.add_child(_status("FAIL: GameData found validation errors.", false))
		layout.add_child(_bullet_list(errors))

	layout.add_child(_body_text("Use this screen as the quick manual check before starting Phase 1 builder interactions."))

func _data_contract_status_panel() -> PanelContainer:
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
	stack.add_child(_label("Phase 1 Data Contracts", 16, Color.html("#111827")))

	var report := GameData.get_contract_report()
	for key in ["blocks", "inductions", "materials"]:
		var contract: Dictionary = report.get(key, {})
		if contract.is_empty():
			stack.add_child(_status("%s contract missing from GameData report." % key.capitalize(), false))
			continue

		var ok := bool(contract.get("ok", false))
		stack.add_child(_status("%s: %s record(s)" % [contract.get("label", key.capitalize()), contract.get("count", 0)], ok))
		stack.add_child(_body_text("Fields: %s" % contract.get("fields", "")))

	return panel

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
