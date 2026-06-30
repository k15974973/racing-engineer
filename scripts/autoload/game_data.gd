extends Node

const ENGINE_BLOCKS_PATH := "res://data/engine_blocks.json"
const INDUCTION_SYSTEMS_PATH := "res://data/induction_systems.json"
const MATERIALS_PATH := "res://data/materials.json"
const ROADMAP_PHASES_PATH := "res://data/roadmap_phases.json"
const TRACKS_PATH := "res://data/tracks.json"
const POWER_TORQUE_RPM_DIVISOR := 7121.0
const RACE_HEAT_PENALTY_RATE := 0.00036
const RACE_RELIABILITY_PENALTY_RATE := 0.0014

var blocks: Array = []
var inductions: Array = []
var materials: Array = []
var roadmap_phases: Array = []
var tracks: Array = []
var load_errors: Array[String] = []
var contract_report: Dictionary = {}

func _ready() -> void:
	reload()

func reload() -> bool:
	load_errors.clear()
	blocks = _load_array(ENGINE_BLOCKS_PATH, "engine blocks")
	inductions = _load_array(INDUCTION_SYSTEMS_PATH, "induction systems")
	materials = _load_array(MATERIALS_PATH, "materials")
	roadmap_phases = _load_array(ROADMAP_PHASES_PATH, "roadmap phases")
	tracks = _load_array(TRACKS_PATH, "tracks")
	validate_engine_data()
	return load_errors.is_empty()

func validate_engine_data() -> bool:
	contract_report.clear()
	var ok := true
	ok = _validate_engine_blocks() and ok
	ok = _validate_induction_systems() and ok
	ok = _validate_materials() and ok
	ok = _validate_records(roadmap_phases, ["id", "name", "duration", "goal", "deliverable"], "roadmap phase", ROADMAP_PHASES_PATH) and ok
	ok = _validate_tracks() and ok
	return ok

func get_summary() -> Dictionary:
	return {
		"blocks": blocks.size(),
		"inductions": inductions.size(),
		"materials": materials.size(),
		"roadmap_phases": roadmap_phases.size(),
		"tracks": tracks.size(),
		"errors": load_errors.duplicate()
	}

func get_contract_report() -> Dictionary:
	return contract_report.duplicate(true)

func get_collection(collection_name: String) -> Array:
	match collection_name:
		"blocks":
			return blocks
		"inductions":
			return inductions
		"materials":
			return materials
		"roadmap_phases":
			return roadmap_phases
		"tracks":
			return tracks
		_:
			return []

func get_record_by_id(collection_name: String, id: String) -> Dictionary:
	return _find_by_id(get_collection(collection_name), id)

func get_default_builder_selection() -> Dictionary:
	return {
		"block": _first_id(blocks),
		"induction": _first_id(inductions),
		"material": _first_id(materials)
	}

func get_default_track_id() -> String:
	return _first_id(tracks)

func calculate_engine_setup(block_id: String, induction_id: String, material_id: String, tuning: Dictionary = {}) -> Dictionary:
	var block := _find_or_first(blocks, block_id)
	var induction := _find_or_first(inductions, induction_id)
	var material := _find_or_first(materials, material_id)

	if block.is_empty() or induction.is_empty() or material.is_empty():
		return {"error": "Engine data is incomplete."}

	var rpm_range: Array = block.get("rpm_range", [0, 0])
	var rpm_min := int(rpm_range[0]) if rpm_range.size() > 0 else 0
	var rpm_max := int(rpm_range[1]) if rpm_range.size() > 1 else 0

	var mass_kg := float(block.get("mass", 0.0)) * float(material.get("mass_mult", 1.0))
	var rpm_factor := clampf(float(rpm_max) / 8500.0, 0.75, 1.28)
	var displacement_factor := clampf(float(block.get("mass", 150.0)) / 160.0, 0.72, 1.35)
	var power_mult := float(induction.get("power_mult", 1.0))
	var lag := float(induction.get("lag", 0.0))
	var setup_block_id := str(block.get("id", ""))
	var compression := clampf(float(tuning.get("compression", 10.5)), 8.0, 14.0)
	var boost := clampf(float(tuning.get("boost", 0.0)), 0.0, 3.0)
	var valve_timing := clampf(float(tuning.get("valve_timing", 0.0)), -10.0, 10.0)
	var fuel_map := clampf(float(tuning.get("fuel_map", 0.0)), -10.0, 10.0)
	var ignition_timing := clampf(float(tuning.get("ignition_timing", 0.0)), -8.0, 8.0)
	var boost_effect := 0.35 if str(induction.get("id", "")) == "na" else 1.0
	var tune_power_mult := 1.0
	tune_power_mult *= 1.0 + (compression - 10.5) * 0.025
	tune_power_mult *= 1.0 + boost * 0.085 * boost_effect
	tune_power_mult *= 1.0 + valve_timing * 0.006
	tune_power_mult *= 1.0 - absf(fuel_map) * 0.004
	tune_power_mult *= 1.0 + ignition_timing * 0.008 - maxf(0.0, ignition_timing - 4.0) * 0.012
	tune_power_mult = clampf(tune_power_mult, 0.72, 1.42)

	var tune_heat_mult := 1.0
	tune_heat_mult *= 1.0 + maxf(0.0, compression - 10.5) * 0.045
	tune_heat_mult *= 1.0 + boost * 0.11 * boost_effect
	tune_heat_mult *= 1.0 - fuel_map * 0.01
	tune_heat_mult *= 1.0 + maxf(0.0, ignition_timing) * 0.018
	tune_heat_mult = clampf(tune_heat_mult, 0.72, 1.68)

	var tune_reliability_mult := 1.0
	tune_reliability_mult *= 1.0 - maxf(0.0, compression - 11.0) * 0.035
	tune_reliability_mult *= 1.0 - boost * 0.045 * boost_effect
	tune_reliability_mult *= 1.0 - absf(ignition_timing) * 0.008
	tune_reliability_mult *= 1.0 + fuel_map * 0.006
	tune_reliability_mult = clampf(tune_reliability_mult, 0.62, 1.12)

	var base_torque_nm := int(round(285.0 * displacement_factor * _block_torque_bias(setup_block_id) * (0.72 + power_mult * 0.34) * (1.0 - lag * 0.06) * (1.0 + boost * 0.06 * boost_effect) * tune_power_mult))
	var heat_load := float(block.get("heat_factor", 1.0)) * float(induction.get("heat_mult", 1.0)) * tune_heat_mult / float(material.get("max_heat_mult", 1.0))
	var engine_health_score := clampf(100.0 * float(block.get("reliability_factor", 1.0)) * float(induction.get("reliability_mult", 1.0)) * float(material.get("durability_mult", 1.0)), 0.0, 120.0)
	var reliability_score := engine_health_score * tune_reliability_mult
	var heat_penalty := maxf(0.0, heat_load - 1.0) * 22.0
	reliability_score = clampf(reliability_score - heat_penalty, 0.0, 120.0)

	var response_score := clampf((1.0 - lag) * 100.0 * (155.0 / maxf(mass_kg, 1.0)) * (1.0 - maxf(0.0, valve_timing) * 0.008 + maxf(0.0, -valve_timing) * 0.006), 20.0, 115.0)
	var heat_score := clampf(heat_load * 100.0, 40.0, 160.0)
	var push_margin := clampf(reliability_score - maxf(0.0, heat_score - 100.0) * 0.35, 0.0, 120.0)
	var curves := _build_power_torque_curves(block, induction, rpm_min, rpm_max, base_torque_nm, tuning)
	var peak_power_hp := int(curves.get("max_power", 0))
	var torque_nm := int(curves.get("max_torque", 0))

	var warning := "Stable baseline."
	if push_margin < 45.0:
		warning = "High risk: keep push windows short."
	elif heat_score > 115.0:
		warning = "Heat-sensitive: cooling choices matter."
	elif response_score < 55.0:
		warning = "Laggy delivery: needs straights or careful timing."
	elif peak_power_hp > 420:
		warning = "Strong output: protect reliability margin."

	return {
		"block": block,
		"induction": induction,
		"material": material,
		"rpm_min": rpm_min,
		"rpm_max": rpm_max,
		"mass_kg": snappedf(mass_kg, 0.1),
		"peak_power_hp": peak_power_hp,
		"torque_nm": torque_nm,
		"engine_health_score": snappedf(engine_health_score, 0.1),
		"heat_score": snappedf(heat_score, 0.1),
		"reliability_score": snappedf(reliability_score, 0.1),
		"response_score": snappedf(response_score, 0.1),
		"push_margin": snappedf(push_margin, 0.1),
		"warning": warning,
		"curves": curves,
		"tuning": {
			"compression": snappedf(compression, 0.1),
			"boost": snappedf(boost, 0.1),
			"valve_timing": valve_timing,
			"fuel_map": fuel_map,
			"ignition_timing": ignition_timing
		},
		"curve_summary": "%s paired with %s creates %s." % [block.get("name", "Block"), induction.get("name", "induction"), block.get("torque_profile", "a neutral delivery")]
	}

func calculate_test_bench_frame(setup: Dictionary, elapsed: float, duration: float = 30.0) -> Dictionary:
	if setup.has("error"):
		return {"error": setup["error"]}

	var safe_duration := maxf(duration, 1.0)
	var progress := clampf(elapsed / safe_duration, 0.0, 1.0)
	var smooth_progress := _smooth01(progress)
	var ramp := clampf(progress / 0.22, 0.0, 1.0)
	var rpm_min := float(setup.get("rpm_min", 900))
	var rpm_max := float(setup.get("rpm_max", 7000))
	var idle_rpm := maxf(900.0, rpm_min * 0.52)
	var load_wave := sin(progress * PI * 6.0) * 0.035
	var rpm := lerpf(idle_rpm, rpm_max * 0.92, _smooth01(ramp)) * (1.0 + load_wave)

	var tuning: Dictionary = setup.get("tuning", {})
	var boost_target := float(tuning.get("boost", 0.0))
	var boost := boost_target * clampf(progress / 0.28, 0.0, 1.0) * (0.94 + sin(progress * PI * 4.0) * 0.04)

	var heat_target := float(setup.get("heat_score", 100.0))
	var heat := lerpf(42.0, heat_target, smooth_progress)
	heat += maxf(0.0, heat_target - 110.0) * progress * 0.2
	heat = clampf(heat, 20.0, 180.0)

	var reliability_start := float(setup.get("reliability_score", 100.0))
	var heat_debt := maxf(0.0, heat - 100.0)
	var reliability := reliability_start - heat_debt * progress * 0.16 - maxf(0.0, progress - 0.7) * 8.0
	reliability = clampf(reliability, 0.0, 120.0)

	var status := "Ramping to load."
	if progress >= 1.0:
		status = "Bench run complete."
	elif heat >= 135.0 or reliability < 35.0:
		status = "Critical: abort recommended."
	elif heat >= 115.0:
		status = "Hot: cooling margin is thin."
	elif progress > 0.24:
		status = "Holding peak neutral load."

	return {
		"progress": progress,
		"elapsed": minf(elapsed, safe_duration),
		"duration": safe_duration,
		"rpm": int(round(rpm)),
		"boost": snappedf(boost, 0.01),
		"heat": snappedf(heat, 0.1),
		"reliability": snappedf(reliability, 0.1),
		"status": status,
		"critical": heat >= 135.0 or reliability < 35.0,
		"complete": progress >= 1.0
	}

func calculate_race_result(setup: Dictionary, track_id: String, decisions: Dictionary = {}) -> Dictionary:
	if setup.has("error"):
		return {"error": setup["error"]}

	var track := _track_for_race(track_id)
	if track.is_empty():
		if tracks.is_empty():
			return {"error": "Track data is incomplete: %s." % TRACKS_PATH}
		return {"error": "Unknown track id '%s'. Check %s." % [track_id, TRACKS_PATH]}

	var power := float(setup.get("peak_power_hp", 0.0))
	var torque := float(setup.get("torque_nm", 0.0))
	var mass := maxf(float(setup.get("mass_kg", 160.0)), 1.0)
	var heat := float(setup.get("heat_score", 100.0))
	var reliability := float(setup.get("reliability_score", 100.0))
	var response := float(setup.get("response_score", 80.0))
	var push_margin := float(setup.get("push_margin", 80.0))
	var windows := _build_race_windows(setup, track)
	var decision_effects := _calculate_decision_effects(windows, decisions)
	var effective_heat := clampf(heat + float(decision_effects.get("heat_delta", 0.0)), 40.0, 180.0)
	var effective_reliability := clampf(reliability + float(decision_effects.get("reliability_delta", 0.0)), 0.0, 120.0)
	var timeline := _build_race_timeline(windows, decision_effects, heat, reliability, int(track.get("laps", 3)))

	var straight_bias := float(track.get("straight_bias", 0.4))
	var corner_bias := float(track.get("corner_bias", 0.4))
	var endurance_bias := float(track.get("endurance_bias", 0.2))
	var bias_total := maxf(straight_bias + corner_bias + endurance_bias, 0.01)

	var power_score := clampf((power / 430.0) * 55.0 + (torque / 520.0) * 25.0 + (155.0 / mass) * 20.0, 20.0, 130.0)
	var technical_score := clampf((response / 105.0) * 45.0 + (torque / 470.0) * 25.0 + (155.0 / mass) * 30.0, 20.0, 130.0)
	var endurance_score := clampf((effective_reliability / 105.0) * 55.0 + (push_margin / 105.0) * 35.0 + ((145.0 - effective_heat) / 80.0) * 10.0, 10.0, 130.0)
	var fit_score := (power_score * straight_bias + technical_score * corner_bias + endurance_score * endurance_bias) / bias_total

	var heat_penalty := maxf(0.0, effective_heat - 100.0) * float(track.get("heat_stress", 1.0)) * RACE_HEAT_PENALTY_RATE
	var reliability_penalty := maxf(0.0, 72.0 - effective_reliability) * endurance_bias * RACE_RELIABILITY_PENALTY_RATE
	var lap_modifier := clampf(1.17 - fit_score * 0.0032 + heat_penalty + reliability_penalty, 0.78, 1.32)
	var lap_time := float(track.get("base_lap_time", 90.0)) * lap_modifier
	var laps := int(track.get("laps", 3))
	var total_time := maxf(1.0, lap_time * float(laps) + float(decision_effects.get("time_delta", 0.0)))
	var final_lap_time := total_time / maxf(float(laps), 1.0)
	var delta_vs_base := final_lap_time - float(track.get("base_lap_time", 90.0))

	return {
		"track": track,
		"setup": setup,
		"laps": laps,
		"lap_time": snappedf(final_lap_time, 0.01),
		"total_time": snappedf(total_time, 0.01),
		"delta_vs_base": snappedf(delta_vs_base, 0.01),
		"fit_score": snappedf(fit_score, 0.1),
		"power_score": snappedf(power_score, 0.1),
		"technical_score": snappedf(technical_score, 0.1),
		"endurance_score": snappedf(endurance_score, 0.1),
		"effective_heat": snappedf(effective_heat, 0.1),
		"effective_reliability": snappedf(effective_reliability, 0.1),
		"decision_effects": decision_effects,
		"sectors": _build_race_sectors(power_score, technical_score, endurance_score, straight_bias, corner_bias, endurance_bias),
		"windows": windows,
		"timeline": timeline,
		"save_preview": _build_race_save_preview(effective_heat, effective_reliability, decision_effects, fit_score),
		"summary": _race_summary(fit_score, effective_heat, effective_reliability)
	}

func analyze_race_result(race_result: Dictionary, race_history: Array = []) -> Dictionary:
	if race_result.is_empty():
		return {"error": "Run a race before opening analysis."}
	if race_result.has("error"):
		return {"error": race_result["error"]}

	var setup: Dictionary = race_result.get("setup", {})
	var track: Dictionary = race_result.get("track", {})
	var findings: Array = []
	var suggestions: Array = []
	var score := float(race_result.get("fit_score", 0.0))
	var delta := float(race_result.get("delta_vs_base", 0.0))
	var heat := float(race_result.get("effective_heat", setup.get("heat_score", 100.0)))
	var reliability := float(race_result.get("effective_reliability", setup.get("reliability_score", 100.0)))
	var power_score := float(race_result.get("power_score", 0.0))
	var technical_score := float(race_result.get("technical_score", 0.0))
	var endurance_score := float(race_result.get("endurance_score", 0.0))

	findings.append({
		"title": "Lap delta",
		"body": "Projected lap is %+0.2fs versus the track baseline." % delta,
		"severity": "good" if delta <= 0.0 else "warn"
	})

	if power_score < 72.0 and float(track.get("straight_bias", 0.0)) >= 0.45:
		findings.append({
			"title": "Straight-line deficit",
			"body": "Power sector rating is %0.1f on a straight-heavy track." % power_score,
			"severity": "warn"
		})
		suggestions.append("Increase peak output: more boost, stronger induction, or a higher-power block.")

	if technical_score < 72.0 and float(track.get("corner_bias", 0.0)) >= 0.45:
		findings.append({
			"title": "Corner exit weakness",
			"body": "Technical rating is %0.1f; response or mass is limiting corner exits." % technical_score,
			"severity": "warn"
		})
		suggestions.append("Improve response: reduce lag, reduce mass, or use less aggressive high-RPM tuning.")

	if endurance_score < 72.0:
		findings.append({
			"title": "Endurance margin",
			"body": "Endurance rating is %0.1f; repeated push decisions will be risky." % endurance_score,
			"severity": "warn"
		})
		suggestions.append("Protect durability: lower boost/compression or choose a safer material.")

	if heat >= 122.0:
		findings.append({
			"title": "Thermal overload",
			"body": "Final heat reached %0.1f/180 after tactical decisions." % heat,
			"severity": "bad"
		})
		suggestions.append("Reduce thermal load or choose cooling decisions when heat windows appear.")
	elif heat <= 92.0 and delta > 0.0:
		findings.append({
			"title": "Unused thermal headroom",
			"body": "Final heat is only %0.1f/180; the setup may be too conservative." % heat,
			"severity": "info"
		})
		suggestions.append("Use more aggressive tuning or push decisions where reliability allows it.")

	if reliability < 55.0:
		findings.append({
			"title": "Reliability risk",
			"body": "Final reliability is %0.1f/120; failures should become a real risk later." % reliability,
			"severity": "bad"
		})
		suggestions.append("Back off repeated push decisions or improve durability before longer races.")

	var effects: Dictionary = race_result.get("decision_effects", {})
	var decision_log: Array = effects.get("log", [])
	for decision in decision_log:
		var time_delta := float(decision.get("time_delta", 0.0))
		if time_delta < -0.5:
			findings.append({
				"title": "%s decision gained time" % decision.get("window", "Window"),
				"body": "%s saved %0.2fs but changed heat by %+0.1f and reliability by %+0.1f." % [decision.get("choice", "Choice"), absf(time_delta), float(decision.get("heat_delta", 0.0)), float(decision.get("reliability_delta", 0.0))],
				"severity": "good"
			})
		elif time_delta > 0.5:
			findings.append({
				"title": "%s decision protected the car" % decision.get("window", "Window"),
				"body": "%s cost %0.2fs and changed reliability by %+0.1f." % [decision.get("choice", "Choice"), time_delta, float(decision.get("reliability_delta", 0.0))],
				"severity": "info"
			})

	if suggestions.is_empty():
		suggestions.append("Setup is coherent for this track. Next improvement should come from comparing saved variants.")

	var comparison := _race_history_comparison(race_result, race_history)
	if not comparison.is_empty():
		findings.append({
			"title": "History comparison",
			"body": comparison.get("summary", ""),
			"severity": "good" if float(comparison.get("delta_to_best", 0.0)) <= 0.0 else "info"
		})

	return {
		"grade": _analysis_grade(score, delta, heat, reliability),
		"headline": _analysis_headline(score, delta, heat, reliability),
		"track": track,
		"setup": setup,
		"findings": findings,
		"suggestions": _dedupe_strings(suggestions),
		"comparison": comparison,
		"scorecard": {
			"track_fit": snappedf(score, 0.1),
			"power": snappedf(power_score, 0.1),
			"technical": snappedf(technical_score, 0.1),
			"endurance": snappedf(endurance_score, 0.1),
			"heat": snappedf(heat, 0.1),
			"reliability": snappedf(reliability, 0.1),
			"lap_delta": snappedf(delta, 0.01)
		}
	}

func _race_history_comparison(race_result: Dictionary, race_history: Array) -> Dictionary:
	var track: Dictionary = race_result.get("track", {})
	var track_id := str(track.get("id", ""))
	if track_id == "" or race_history.is_empty():
		return {}

	var current_total := float(race_result.get("total_time", 0.0))
	var best_record: Dictionary = {}
	var best_total := INF
	for item in race_history:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var record: Dictionary = item
		var result: Dictionary = record.get("result", {})
		var history_track: Dictionary = result.get("track", {})
		if str(history_track.get("id", "")) != track_id:
			continue

		var total := float(result.get("total_time", INF))
		if total < best_total:
			best_total = total
			best_record = record

	if best_record.is_empty():
		return {}

	var delta_to_best := current_total - best_total
	var summary := "Current run is %+0.2fs versus saved best %s on this track." % [delta_to_best, best_record.get("name", "Race")]
	return {
		"best_name": best_record.get("name", "Race"),
		"best_total_time": snappedf(best_total, 0.01),
		"current_total_time": snappedf(current_total, 0.01),
		"delta_to_best": snappedf(delta_to_best, 0.01),
		"summary": summary
	}

func _build_race_sectors(power_score: float, technical_score: float, endurance_score: float, straight_bias: float, corner_bias: float, endurance_bias: float) -> Array:
	return [
		{
			"name": "Straights",
			"bias": snappedf(straight_bias, 0.01),
			"rating": snappedf(power_score, 0.1),
			"note": "Peak power and torque decide most of this sector."
		},
		{
			"name": "Corners",
			"bias": snappedf(corner_bias, 0.01),
			"rating": snappedf(technical_score, 0.1),
			"note": "Response, torque delivery, and mass decide corner exits."
		},
		{
			"name": "Endurance",
			"bias": snappedf(endurance_bias, 0.01),
			"rating": snappedf(endurance_score, 0.1),
			"note": "Reliability and push margin decide late-race consistency."
		}
	]

func _build_race_windows(setup: Dictionary, track: Dictionary) -> Array:
	var windows: Array = []
	var induction: Dictionary = setup.get("induction", {})
	var block: Dictionary = setup.get("block", {})
	var induction_id := str(induction.get("id", ""))
	var block_id := str(block.get("id", ""))
	var heat := float(setup.get("heat_score", 100.0))
	var straight_bias := float(track.get("straight_bias", 0.0))
	var corner_bias := float(track.get("corner_bias", 0.0))
	var heat_stress := float(track.get("heat_stress", 1.0))

	if induction_id in ["single_turbo", "twin_turbo", "compound", "supercharger"]:
		_append_race_window(windows, "Boost Spike", "Forced induction setup under full load.", "Push on straights; cut if heat is already above 115.")

	if heat >= 100.0 or heat_stress >= 0.95 or block_id in ["v8", "rotary"]:
		_append_race_window(windows, "High Temperature", "Thermal load is expected to stack during the run.", "Cool if push margin is below 55; otherwise stabilize.")

	if corner_bias >= 0.30:
		_append_race_window(windows, "Corner Map", "Technical sectors create corner-exit pressure.", "Use balanced or rich map for corner exit stability.")

	if straight_bias >= 0.30:
		_append_race_window(windows, "Straight Attack", "Straight sectors create safe attack windows.", "Attack if reliability is above 65 and heat is below 120.")

	var fallback_types := ["High Temperature", "Corner Map", "Straight Attack", "Stabilize"]
	for fallback_type in fallback_types:
		if windows.size() >= 3:
			break
		if _race_window_present(windows, fallback_type):
			continue
		_append_race_window(windows, fallback_type, _fallback_window_trigger(fallback_type), _fallback_window_choice(fallback_type))

	return windows.slice(0, min(windows.size(), 4))

func _append_race_window(windows: Array, window_type: String, trigger: String, choice: String) -> void:
	if _race_window_present(windows, window_type):
		return

	windows.append({
		"type": window_type,
		"trigger": trigger,
		"choice": choice,
		"choices": _window_choices(window_type)
	})

func _race_window_present(windows: Array, window_type: String) -> bool:
	for item in windows:
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var window: Dictionary = item
		if str(window.get("type", "")) == window_type:
			return true

	return false

func _fallback_window_trigger(window_type: String) -> String:
	match window_type:
		"Boost Spike":
			return "Short acceleration zone tests the current power delivery."
		"High Temperature":
			return "Race load creates a thermal management decision."
		"Corner Map":
			return "Mid-lap direction changes test response and exit stability."
		"Straight Attack":
			return "A clear straight offers a controlled attack decision."
		_:
			return "No dominant stress event."

func _fallback_window_choice(window_type: String) -> String:
	match window_type:
		"Boost Spike":
			return "Hold boost unless heat is already climbing."
		"High Temperature":
			return "Stabilize if reliability margin is already thin."
		"Corner Map":
			return "Balance exit drive against heat."
		"Straight Attack":
			return "Attack only if heat and reliability leave room."
		_:
			return "Hold baseline settings and protect consistency."

func _window_choices(window_type: String) -> Array:
	match window_type:
		"Boost Spike":
			return [
				{"id": "cut", "label": "Cut", "time_delta": 1.2, "heat_delta": -8.0, "reliability_delta": 4.0, "note": "Slower, but protects the engine."},
				{"id": "hold", "label": "Hold", "time_delta": 0.0, "heat_delta": 0.0, "reliability_delta": 0.0, "note": "Neutral boost target."},
				{"id": "push", "label": "Push", "time_delta": -1.6, "heat_delta": 12.0, "reliability_delta": -7.0, "note": "Fastest if thermal margin exists."}
			]
		"High Temperature":
			return [
				{"id": "cool", "label": "Cool", "time_delta": 1.0, "heat_delta": -14.0, "reliability_delta": 5.0, "note": "Sacrifice pace to recover heat."},
				{"id": "stabilize", "label": "Stabilize", "time_delta": 0.2, "heat_delta": -5.0, "reliability_delta": 2.0, "note": "Small pace cost, safer thermal slope."},
				{"id": "push", "label": "Push", "time_delta": -1.0, "heat_delta": 12.0, "reliability_delta": -8.0, "note": "Short-term gain, high thermal risk."}
			]
		"Corner Map":
			return [
				{"id": "lean", "label": "Lean", "time_delta": 0.5, "heat_delta": -4.0, "reliability_delta": 1.0, "note": "Cleaner heat, weaker exit."},
				{"id": "balanced", "label": "Balanced", "time_delta": 0.0, "heat_delta": 0.0, "reliability_delta": 0.0, "note": "Stable corner map."},
				{"id": "rich", "label": "Rich", "time_delta": -0.6, "heat_delta": 4.0, "reliability_delta": -1.0, "note": "Better exit drive, slightly hotter."}
			]
		"Straight Attack":
			return [
				{"id": "conserve", "label": "Conserve", "time_delta": 0.8, "heat_delta": -6.0, "reliability_delta": 4.0, "note": "Protects the engine on straights."},
				{"id": "full", "label": "Full", "time_delta": 0.0, "heat_delta": 0.0, "reliability_delta": 0.0, "note": "Baseline straight-line power."},
				{"id": "attack", "label": "Attack", "time_delta": -1.4, "heat_delta": 10.0, "reliability_delta": -6.0, "note": "Fast straight, costly heat."}
			]
		_:
			return [
				{"id": "conserve", "label": "Conserve", "time_delta": 0.5, "heat_delta": -4.0, "reliability_delta": 3.0, "note": "Low risk."},
				{"id": "hold", "label": "Hold", "time_delta": 0.0, "heat_delta": 0.0, "reliability_delta": 0.0, "note": "Baseline."},
				{"id": "push", "label": "Push", "time_delta": -0.8, "heat_delta": 6.0, "reliability_delta": -5.0, "note": "Small attack."}
			]

func _calculate_decision_effects(windows: Array, decisions: Dictionary) -> Dictionary:
	var time_delta := 0.0
	var heat_delta := 0.0
	var reliability_delta := 0.0
	var log: Array = []

	for index in range(windows.size()):
		var window: Dictionary = windows[index]
		var window_type := str(window.get("type", "Window"))
		var choices: Array = window.get("choices", [])
		var selected_id := str(decisions.get(window_type, _default_choice_id(choices)))
		var choice := _find_choice(choices, selected_id)
		if choice.is_empty():
			choice = _find_choice(choices, _default_choice_id(choices))
		if choice.is_empty():
			continue

		time_delta += float(choice.get("time_delta", 0.0))
		heat_delta += float(choice.get("heat_delta", 0.0))
		reliability_delta += float(choice.get("reliability_delta", 0.0))
		log.append({
			"index": index,
			"window": window_type,
			"choice_id": selected_id,
			"choice": choice.get("label", selected_id),
			"note": choice.get("note", ""),
			"time_delta": snappedf(float(choice.get("time_delta", 0.0)), 0.01),
			"heat_delta": snappedf(float(choice.get("heat_delta", 0.0)), 0.1),
			"reliability_delta": snappedf(float(choice.get("reliability_delta", 0.0)), 0.1)
		})

	return {
		"time_delta": snappedf(time_delta, 0.01),
		"heat_delta": snappedf(heat_delta, 0.1),
		"reliability_delta": snappedf(reliability_delta, 0.1),
		"log": log
	}

func _build_race_timeline(windows: Array, decision_effects: Dictionary, base_heat: float, base_reliability: float, laps: int) -> Array:
	var timeline: Array = []
	var log: Array = decision_effects.get("log", [])
	var heat_cursor := base_heat
	var reliability_cursor := base_reliability
	var cumulative_time_delta := 0.0
	var safe_laps := maxi(laps, 1)
	var window_count := maxi(windows.size(), 1)

	for index in range(windows.size()):
		var window: Dictionary = windows[index]
		var entry: Dictionary = {}
		if index < log.size() and typeof(log[index]) == TYPE_DICTIONARY:
			entry = log[index]

		var lap := clampi(int(floor(float(index) * float(safe_laps) / float(window_count))) + 1, 1, safe_laps)
		var time_delta := float(entry.get("time_delta", 0.0))
		var heat_delta := float(entry.get("heat_delta", 0.0))
		var reliability_delta := float(entry.get("reliability_delta", 0.0))
		cumulative_time_delta += time_delta
		heat_cursor = clampf(heat_cursor + heat_delta, 40.0, 180.0)
		reliability_cursor = clampf(reliability_cursor + reliability_delta, 0.0, 120.0)

		timeline.append({
			"index": index,
			"sequence": index + 1,
			"lap": lap,
			"marker": "Lap %d/%d" % [lap, safe_laps],
			"window": window.get("type", entry.get("window", "Window")),
			"choice": entry.get("choice", "Choice"),
			"choice_id": entry.get("choice_id", ""),
			"note": entry.get("note", ""),
			"time_delta": snappedf(time_delta, 0.01),
			"heat_delta": snappedf(heat_delta, 0.1),
			"reliability_delta": snappedf(reliability_delta, 0.1),
			"cumulative_time_delta": snappedf(cumulative_time_delta, 0.01),
			"projected_heat": snappedf(heat_cursor, 0.1),
			"projected_reliability": snappedf(reliability_cursor, 0.1),
			"risk": _race_timeline_risk(heat_cursor, reliability_cursor, heat_delta, reliability_delta)
		})

	return timeline

func _race_timeline_risk(heat: float, reliability: float, heat_delta: float, reliability_delta: float) -> String:
	if heat >= 135.0 or reliability < 45.0:
		return "Critical"
	if heat >= 120.0 or reliability < 62.0 or heat_delta >= 10.0 or reliability_delta <= -7.0:
		return "Risk"
	if heat_delta < 0.0 and reliability_delta > 0.0:
		return "Recovery"
	return "Stable"

func _build_race_save_preview(effective_heat: float, effective_reliability: float, decision_effects: Dictionary, fit_score: float) -> Dictionary:
	var risk := "Stable"
	if effective_heat >= 135.0 or effective_reliability < 45.0:
		risk = "Critical"
	elif effective_heat >= 120.0 or effective_reliability < 62.0:
		risk = "Risk"
	elif fit_score < 72.0:
		risk = "Low Fit"

	return {
		"final_heat": snappedf(effective_heat, 0.1),
		"final_reliability": snappedf(effective_reliability, 0.1),
		"decision_time_delta": decision_effects.get("time_delta", 0.0),
		"decision_heat_delta": decision_effects.get("heat_delta", 0.0),
		"decision_reliability_delta": decision_effects.get("reliability_delta", 0.0),
		"risk": risk,
		"summary": _race_save_preview_summary(risk, effective_heat, effective_reliability)
	}

func _race_save_preview_summary(risk: String, heat: float, reliability: float) -> String:
	match risk:
		"Critical":
			return "Saving this run will lock in a high-risk result: heat %0.1f, reliability %0.1f." % [heat, reliability]
		"Risk":
			return "Save is allowed, but the run carries visible heat or reliability risk."
		"Low Fit":
			return "Save is allowed, but the setup does not fit the track well yet."
		_:
			return "Save is clean enough for comparison and later analysis."

func _default_choice_id(choices: Array) -> String:
	if choices.is_empty():
		return ""
	if choices.size() >= 2:
		var middle: Dictionary = choices[1]
		return str(middle.get("id", ""))

	var first: Dictionary = choices[0]
	return str(first.get("id", ""))

func _find_choice(choices: Array, choice_id: String) -> Dictionary:
	for item in choices:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var choice: Dictionary = item
		if str(choice.get("id", "")) == choice_id:
			return choice
	return {}

func _race_summary(fit_score: float, heat: float, reliability: float) -> String:
	if fit_score >= 95.0 and heat < 115.0:
		return "Strong track fit. Race pace should be competitive."
	if heat >= 125.0:
		return "Thermal risk is the main limiter on this track."
	if reliability < 55.0:
		return "Reliability margin is weak. Avoid repeated push calls."
	if fit_score < 70.0:
		return "Poor track fit. Rebuild around this track profile."

	return "Usable setup with clear room for optimization."

func _analysis_grade(score: float, delta: float, heat: float, reliability: float) -> String:
	if heat >= 135.0 or reliability < 40.0:
		return "Risk"
	if score >= 98.0 and delta <= 0.0:
		return "A"
	if score >= 86.0:
		return "B"
	if score >= 72.0:
		return "C"
	return "D"

func _analysis_headline(score: float, delta: float, heat: float, reliability: float) -> String:
	if heat >= 135.0:
		return "Pace is being bought with too much heat."
	if reliability < 40.0:
		return "The setup is too fragile for repeated push decisions."
	if score >= 98.0 and delta <= 0.0:
		return "Strong match for the current track."
	if score < 72.0:
		return "The setup does not match this track profile."
	if delta > 0.0:
		return "Usable setup, but time is still being left on track."
	return "Competitive baseline with room to optimize."

func _dedupe_strings(items: Array) -> Array:
	var seen := {}
	var result: Array = []
	for item in items:
		var text := str(item)
		if seen.has(text):
			continue
		seen[text] = true
		result.append(text)
	return result

func _load_array(path: String, label: String) -> Array:
	if not FileAccess.file_exists(path):
		load_errors.append("%s file is missing: %s" % [label.capitalize(), path])
		return []

	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_ARRAY:
		load_errors.append("%s file must contain a JSON array: %s" % [label.capitalize(), path])
		return []

	return parsed

func _validate_records(records: Array, required_keys: Array, label: String, source_path: String = "") -> bool:
	var ok := true
	for index in range(records.size()):
		var record: Variant = records[index]
		if typeof(record) != TYPE_DICTIONARY:
			load_errors.append("%s must be a dictionary." % _record_location(label, index, source_path))
			ok = false
			continue

		for key in required_keys:
			if not record.has(key):
				load_errors.append("%s is missing required key '%s'." % [_record_location(label, index, source_path), key])
				ok = false

	return ok

func _validate_engine_blocks() -> bool:
	var fields := ["id", "name", "rpm_range", "torque_profile", "mass", "heat_factor", "reliability_factor"]
	var ok := _validate_records(blocks, fields, "engine block", ENGINE_BLOCKS_PATH)
	ok = _validate_unique_ids(blocks, "engine block", ENGINE_BLOCKS_PATH) and ok

	for index in range(blocks.size()):
		var record: Variant = blocks[index]
		if typeof(record) != TYPE_DICTIONARY:
			continue

		var block: Dictionary = record
		var label := _record_location("engine block", index, ENGINE_BLOCKS_PATH)
		ok = _validate_string_field(block, "id", label) and ok
		ok = _validate_string_field(block, "name", label) and ok
		ok = _validate_rpm_range(block, label) and ok
		ok = _validate_string_field(block, "torque_profile", label) and ok
		ok = _validate_number_field(block, "mass", label, 1.0) and ok
		ok = _validate_number_field(block, "heat_factor", label, 0.01) and ok
		ok = _validate_number_field(block, "reliability_factor", label, 0.01) and ok

	contract_report["blocks"] = _contract_entry("Block contract", blocks.size(), fields, ok)
	return ok

func _validate_induction_systems() -> bool:
	var fields := ["id", "name", "power_mult", "lag", "heat_mult", "reliability_mult"]
	var ok := _validate_records(inductions, fields, "induction system", INDUCTION_SYSTEMS_PATH)
	ok = _validate_unique_ids(inductions, "induction system", INDUCTION_SYSTEMS_PATH) and ok

	for index in range(inductions.size()):
		var record: Variant = inductions[index]
		if typeof(record) != TYPE_DICTIONARY:
			continue

		var induction: Dictionary = record
		var label := _record_location("induction system", index, INDUCTION_SYSTEMS_PATH)
		ok = _validate_string_field(induction, "id", label) and ok
		ok = _validate_string_field(induction, "name", label) and ok
		ok = _validate_number_field(induction, "power_mult", label, 0.01) and ok
		ok = _validate_number_field(induction, "lag", label, 0.0, 1.0) and ok
		ok = _validate_number_field(induction, "heat_mult", label, 0.01) and ok
		ok = _validate_number_field(induction, "reliability_mult", label, 0.01) and ok

	contract_report["inductions"] = _contract_entry("Induction contract", inductions.size(), fields, ok)
	return ok

func _validate_materials() -> bool:
	var fields := ["id", "name", "mass_mult", "max_heat_mult", "durability_mult"]
	var ok := _validate_records(materials, fields, "material", MATERIALS_PATH)
	ok = _validate_unique_ids(materials, "material", MATERIALS_PATH) and ok

	for index in range(materials.size()):
		var record: Variant = materials[index]
		if typeof(record) != TYPE_DICTIONARY:
			continue

		var material: Dictionary = record
		var label := _record_location("material", index, MATERIALS_PATH)
		ok = _validate_string_field(material, "id", label) and ok
		ok = _validate_string_field(material, "name", label) and ok
		ok = _validate_number_field(material, "mass_mult", label, 0.01) and ok
		ok = _validate_number_field(material, "max_heat_mult", label, 0.01) and ok
		ok = _validate_number_field(material, "durability_mult", label, 0.01) and ok

	contract_report["materials"] = _contract_entry("Material contract", materials.size(), fields, ok)
	return ok

func _validate_tracks() -> bool:
	var fields := ["id", "name", "laps", "length_km", "base_lap_time", "straight_bias", "corner_bias", "endurance_bias", "heat_stress", "description"]
	var ok := _validate_records(tracks, fields, "track", TRACKS_PATH)
	ok = _validate_unique_ids(tracks, "track", TRACKS_PATH) and ok

	for index in range(tracks.size()):
		var record: Variant = tracks[index]
		if typeof(record) != TYPE_DICTIONARY:
			continue

		var track: Dictionary = record
		var label := _record_location("track", index, TRACKS_PATH)
		ok = _validate_string_field(track, "id", label) and ok
		ok = _validate_string_field(track, "name", label) and ok
		ok = _validate_number_field(track, "laps", label, 1.0) and ok
		ok = _validate_number_field(track, "length_km", label, 0.1) and ok
		ok = _validate_number_field(track, "base_lap_time", label, 1.0) and ok
		ok = _validate_number_field(track, "straight_bias", label, 0.0, 1.0) and ok
		ok = _validate_number_field(track, "corner_bias", label, 0.0, 1.0) and ok
		ok = _validate_number_field(track, "endurance_bias", label, 0.0, 1.0) and ok
		ok = _validate_number_field(track, "heat_stress", label, 0.01) and ok
		ok = _validate_string_field(track, "description", label) and ok

		var bias_total := float(track.get("straight_bias", 0.0)) + float(track.get("corner_bias", 0.0)) + float(track.get("endurance_bias", 0.0))
		if bias_total <= 0.0:
			load_errors.append("%s track biases must total above 0." % label)
			ok = false

	contract_report["tracks"] = _contract_entry("Track contract", tracks.size(), fields, ok)
	return ok

func _contract_entry(label: String, count: int, fields: Array, ok: bool) -> Dictionary:
	return {
		"label": label,
		"count": count,
		"fields": ", ".join(fields),
		"ok": ok
	}

func _validate_unique_ids(records: Array, label: String, source_path: String = "") -> bool:
	var ok := true
	var seen := {}
	for index in range(records.size()):
		var record: Variant = records[index]
		if typeof(record) != TYPE_DICTIONARY:
			continue

		var id := str(record.get("id", ""))
		if id == "":
			continue
		if seen.has(id):
			load_errors.append("%s has duplicate id '%s'." % [_record_location(label, index, source_path), id])
			ok = false
			continue
		seen[id] = true

	return ok

func _record_location(label: String, index: int, source_path: String) -> String:
	var prefix := "%s " % source_path if source_path != "" else ""
	return "%s%s %d" % [prefix, label, index]

func _validate_string_field(record: Dictionary, key: String, label: String) -> bool:
	if not record.has(key):
		return false

	var value: Variant = record.get(key)
	if typeof(value) != TYPE_STRING or str(value).strip_edges() == "":
		load_errors.append("%s field '%s' must be a non-empty string." % [label, key])
		return false

	return true

func _validate_number_field(record: Dictionary, key: String, label: String, min_value: float, max_value: float = INF) -> bool:
	if not record.has(key):
		return false

	var value: Variant = record.get(key)
	if not _is_number(value):
		load_errors.append("%s field '%s' must be numeric." % [label, key])
		return false

	var number := float(value)
	if number < min_value or number > max_value:
		if max_value == INF:
			load_errors.append("%s field '%s' must be >= %s." % [label, key, min_value])
		else:
			load_errors.append("%s field '%s' must be between %s and %s." % [label, key, min_value, max_value])
		return false

	return true

func _validate_rpm_range(record: Dictionary, label: String) -> bool:
	if not record.has("rpm_range"):
		return false

	var value: Variant = record.get("rpm_range")
	if typeof(value) != TYPE_ARRAY:
		load_errors.append("%s field 'rpm_range' must be an array." % label)
		return false

	var rpm_range: Array = value
	if rpm_range.size() != 2 or not _is_number(rpm_range[0]) or not _is_number(rpm_range[1]):
		load_errors.append("%s field 'rpm_range' must contain two numeric values." % label)
		return false

	if float(rpm_range[0]) >= float(rpm_range[1]):
		load_errors.append("%s field 'rpm_range' must be ordered from low to high rpm." % label)
		return false

	return true

func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT

func _build_power_torque_curves(block: Dictionary, induction: Dictionary, rpm_min: int, rpm_max: int, peak_torque: int, tuning: Dictionary) -> Dictionary:
	var torque_points: Array = []
	var power_points: Array = []
	var samples := 18
	var max_torque := 1.0
	var max_power := 1.0
	var block_id := str(block.get("id", ""))
	var lag := float(induction.get("lag", 0.0))
	var induction_power_mult := float(induction.get("power_mult", 1.0))
	var boost := clampf(float(tuning.get("boost", 0.0)), 0.0, 3.0)
	var valve_timing := clampf(float(tuning.get("valve_timing", 0.0)), -10.0, 10.0)
	var fuel_map := clampf(float(tuning.get("fuel_map", 0.0)), -10.0, 10.0)

	for index in range(samples):
		var t := float(index) / float(samples - 1)
		var rpm := lerpf(float(rpm_min), float(rpm_max), t)
		var base_shape := _torque_shape(block_id, t)
		var spool := _spool_factor(lag, t)
		var induction_gain := _induction_curve_gain(induction_power_mult, lag, spool, t)
		var boost_gain := 1.0 + boost * 0.07 * spool
		var valve_shift := 1.0 + valve_timing * (t - 0.45) * 0.018
		var fuel_safety := 1.0 - absf(fuel_map) * 0.003
		var torque := float(peak_torque) * base_shape * induction_gain * boost_gain * valve_shift * fuel_safety
		var power := torque * rpm / POWER_TORQUE_RPM_DIVISOR

		max_torque = maxf(max_torque, torque)
		max_power = maxf(max_power, power)
		torque_points.append({"rpm": int(round(rpm)), "value": snappedf(torque, 0.1)})
		power_points.append({"rpm": int(round(rpm)), "value": snappedf(power, 0.1)})

	for point in torque_points:
		point["norm"] = snappedf(float(point["value"]) / max_torque, 0.001)

	for point in power_points:
		point["norm"] = snappedf(float(point["value"]) / max_power, 0.001)

	return {
		"torque": torque_points,
		"power": power_points,
		"max_torque": int(round(max_torque)),
		"max_power": int(round(max_power))
	}

func _block_torque_bias(block_id: String) -> float:
	match block_id:
		"v8":
			return 1.1
		"v6":
			return 1.0
		"rotary":
			return 0.98
		"boxer_4":
			return 0.94
		"inline_4":
			return 0.98
		"v4":
			return 0.9
		_:
			return 1.0

func _torque_shape(block_id: String, t: float) -> float:
	match block_id:
		"v8":
			return clampf(1.0 + sin(t * PI) * 0.16 - t * 0.2 - maxf(0.0, t - 0.62) * 0.34, 0.56, 1.08)
		"rotary":
			return clampf(0.42 + t * 0.72 + sin(t * PI) * 0.1, 0.38, 1.2)
		"inline_4":
			return clampf(0.52 + sin(t * PI) * 0.3 + t * 0.24 - maxf(0.0, t - 0.82) * 0.35, 0.44, 1.14)
		"boxer_4":
			return clampf(0.78 + sin(t * PI) * 0.22 - maxf(0.0, t - 0.74) * 0.28, 0.55, 1.04)
		"v4":
			return clampf(0.68 + sin(t * PI) * 0.3 + t * 0.04, 0.52, 1.05)
		_:
			return clampf(0.72 + sin(t * PI) * 0.28, 0.52, 1.04)

func _induction_curve_gain(power_mult: float, lag: float, spool: float, t: float) -> float:
	var boost_extra := maxf(0.0, power_mult - 1.0)
	if boost_extra <= 0.0:
		return 1.0
	if lag <= 0.05:
		return 1.0 + boost_extra * (0.38 + t * 0.18)

	var low_rpm_penalty := (1.0 - spool) * 0.28
	var high_rpm_gain := spool * 0.58
	return clampf(1.0 + boost_extra * (high_rpm_gain - low_rpm_penalty), 0.86, 1.28)

func _spool_factor(lag: float, t: float) -> float:
	if lag <= 0.03:
		return 1.0

	var threshold := clampf(0.18 + lag * 0.42, 0.18, 0.55)
	if t <= threshold:
		return clampf(t / threshold * (1.0 - lag * 0.45), 0.15, 0.85)

	return clampf(0.82 + (t - threshold) / maxf(1.0 - threshold, 0.01) * 0.22, 0.0, 1.04)

func _smooth01(value: float) -> float:
	var t := clampf(value, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

func _first_id(records: Array) -> String:
	if records.is_empty():
		return ""

	var first: Variant = records[0]
	if typeof(first) != TYPE_DICTIONARY:
		return ""

	return str(first.get("id", ""))

func _find_by_id(records: Array, id: String) -> Dictionary:
	for item in records:
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var record: Dictionary = item
		if str(record.get("id", "")) == id:
			return record

	return {}

func _track_for_race(track_id: String) -> Dictionary:
	if str(track_id).strip_edges() == "":
		return _find_or_first(tracks, "")

	return _find_by_id(tracks, track_id)

func _find_or_first(records: Array, id: String) -> Dictionary:
	var found := _find_by_id(records, id)
	if not found.is_empty():
		return found

	if records.is_empty() or typeof(records[0]) != TYPE_DICTIONARY:
		return {}

	return records[0]
