extends SceneTree

const POWER_TORQUE_RPM_DIVISOR := 7121.0
const POWER_TOLERANCE_HP := 1.5
const TORQUE_EPSILON_NM := 1.0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var game_data = root.get_node("/root/GameData")
	var configs := {
		"v8_na_standard": {
			"name": "V8 NA Standard",
			"setup": game_data.calculate_engine_setup("v8", "na", "aluminum")
		},
		"rotary_tt_titanium": {
			"name": "Rotary Twin Turbo Titanium",
			"setup": game_data.calculate_engine_setup("rotary", "twin_turbo", "titanium")
		},
		"inline4_sc_aluminum": {
			"name": "Inline-4 Supercharger Aluminum",
			"setup": game_data.calculate_engine_setup("inline_4", "supercharger", "aluminum")
		},
		"v8_tt_aluminum": {
			"name": "V8 Twin Turbo Aluminum",
			"setup": game_data.calculate_engine_setup("v8", "twin_turbo", "aluminum")
		},
		"rotary_na_aluminum": {
			"name": "Rotary NA Aluminum",
			"setup": game_data.calculate_engine_setup("rotary", "na", "aluminum")
		}
	}

	for key in configs.keys():
		var item: Dictionary = configs[key]
		var setup: Dictionary = item.get("setup", {})
		if setup.has("error"):
			_fail("%s failed: %s" % [item.get("name", key), setup.get("error", "")])
			return

		var consistency_error := _curve_consistency_error(str(item.get("name", key)), setup)
		if consistency_error != "":
			_fail(consistency_error)
			return

	var v8: Dictionary = configs["v8_na_standard"]["setup"]
	var rotary: Dictionary = configs["rotary_tt_titanium"]["setup"]
	var inline4: Dictionary = configs["inline4_sc_aluminum"]["setup"]
	var max_power := maxf(float(rotary.get("peak_power_hp", 0.0)), maxf(float(v8.get("peak_power_hp", 0.0)), float(inline4.get("peak_power_hp", 0.0))))

	var v8_rotary_distance := _shared_curve_distance(v8, rotary, max_power)
	var v8_inline_distance := _shared_curve_distance(v8, inline4, max_power)
	var rotary_inline_distance := _shared_curve_distance(rotary, inline4, max_power)

	if float(rotary.get("peak_power_hp", 0.0)) < float(v8.get("peak_power_hp", 0.0)) * 1.25:
		_fail("Rotary TT should clearly exceed V8 NA peak power.")
		return
	if float(v8.get("peak_power_hp", 0.0)) < float(inline4.get("peak_power_hp", 0.0)) * 1.2:
		_fail("V8 NA should clearly exceed Inline-4 SC peak power.")
		return
	if abs(_peak_power_rpm(rotary) - _peak_power_rpm(v8)) < 2500:
		_fail("Rotary TT and V8 NA peak RPM are too close.")
		return
	if minf(v8_rotary_distance, minf(v8_inline_distance, rotary_inline_distance)) < 0.09:
		_fail("Power curves are too close on shared scale.")
		return

	print("CURVE_DIFFERENTIATION_SMOKE_OK consistency=5 configs v8=%shp/%sNm@%srpm rotary=%shp/%sNm@%srpm inline4=%shp/%sNm@%srpm distances=%0.3f/%0.3f/%0.3f" % [
		v8.get("peak_power_hp", "?"),
		v8.get("torque_nm", "?"),
		_peak_power_rpm(v8),
		rotary.get("peak_power_hp", "?"),
		rotary.get("torque_nm", "?"),
		_peak_power_rpm(rotary),
		inline4.get("peak_power_hp", "?"),
		inline4.get("torque_nm", "?"),
		_peak_power_rpm(inline4),
		v8_rotary_distance,
		v8_inline_distance,
		rotary_inline_distance
	])
	quit(0)

func _curve_consistency_error(config_name: String, setup: Dictionary) -> String:
	var peak_power_rpm := _peak_power_rpm(setup)
	var torque_at_peak := _sample_torque(setup, peak_power_rpm)
	var peak_torque_reported := float(setup.get("torque_nm", 0.0))
	var peak_power_reported := float(setup.get("peak_power_hp", 0.0))
	var calculated_power := torque_at_peak * float(peak_power_rpm) / POWER_TORQUE_RPM_DIVISOR

	if torque_at_peak > peak_torque_reported + TORQUE_EPSILON_NM:
		return "%s: torque at peak power (%0.1f Nm) > reported peak torque (%0.1f Nm)." % [config_name, torque_at_peak, peak_torque_reported]
	if absf(calculated_power - peak_power_reported) > POWER_TOLERANCE_HP:
		return "%s: P/T/RPM mismatch. %0.1f Nm * %s rpm / %0.1f = %0.1f hp, reported %0.1f hp." % [config_name, torque_at_peak, peak_power_rpm, POWER_TORQUE_RPM_DIVISOR, calculated_power, peak_power_reported]

	return ""

func _shared_curve_distance(a_setup: Dictionary, b_setup: Dictionary, max_power: float) -> float:
	var a_curves: Dictionary = a_setup.get("curves", {})
	var b_curves: Dictionary = b_setup.get("curves", {})
	var a_points: Array = a_curves.get("power", [])
	var b_points: Array = b_curves.get("power", [])
	var count := mini(a_points.size(), b_points.size())
	if count <= 0:
		return 0.0

	var total := 0.0
	for index in range(count):
		var a: Dictionary = a_points[index]
		var b: Dictionary = b_points[index]
		total += absf(float(a.get("value", 0.0)) - float(b.get("value", 0.0))) / maxf(max_power, 1.0)
	return total / float(count)

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

func _sample_torque(setup: Dictionary, target_rpm: int) -> float:
	var curves: Dictionary = setup.get("curves", {})
	var points: Array = curves.get("torque", [])
	var best_value := 0.0
	var best_distance := INF
	for item in points:
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var point: Dictionary = item
		var rpm := int(point.get("rpm", 0))
		var distance := absf(float(rpm - target_rpm))
		if distance < best_distance:
			best_distance = distance
			best_value = float(point.get("value", 0.0))
	return best_value

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
