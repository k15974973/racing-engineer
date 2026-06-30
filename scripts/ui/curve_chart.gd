extends Control

var _series: Array = []
var _rpm_min := 0.0
var _rpm_max := 1.0
var _max_value := 1.0

func _init() -> void:
	custom_minimum_size = Vector2(0, 180)

func set_curve_data(curves: Dictionary) -> void:
	_series = [
		{"label": "Torque", "points": curves.get("torque", []), "color": Color.html("#0F6E56"), "width": 2.0},
		{"label": "Power", "points": curves.get("power", []), "color": Color.html("#534AB7"), "width": 2.0}
	]
	_recalculate_bounds()
	queue_redraw()

func set_power_overlay(entries: Array) -> void:
	_series.clear()
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue

		var item: Dictionary = entry
		var setup: Dictionary = item.get("setup", {})
		var curves: Dictionary = setup.get("curves", {})
		_series.append({
			"label": item.get("label", "Setup"),
			"points": curves.get("power", []),
			"color": item.get("color", Color.html("#534AB7")),
			"width": 2.4
		})

	_recalculate_bounds()
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	var chart_size := size
	if chart_size.x < 80.0 or chart_size.y < 80.0:
		return

	var plot := Rect2(Vector2(12, 12), chart_size - Vector2(24, 24))
	draw_rect(Rect2(Vector2.ZERO, chart_size), Color.html("#FFFFFF"), true)
	draw_rect(plot, Color.html("#E5E7EB"), false, 1.0)

	for index in range(1, 4):
		var x := plot.position.x + plot.size.x * float(index) / 4.0
		draw_line(Vector2(x, plot.position.y), Vector2(x, plot.position.y + plot.size.y), Color.html("#F3F4F6"), 1.0)

	for index in range(1, 4):
		var y := plot.position.y + plot.size.y * float(index) / 4.0
		draw_line(Vector2(plot.position.x, y), Vector2(plot.position.x + plot.size.x, y), Color.html("#F3F4F6"), 1.0)

	for item in _series:
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var series: Dictionary = item
		_draw_series(plot, series.get("points", []), series.get("color", Color.html("#534AB7")), float(series.get("width", 2.0)))

func _draw_series(plot: Rect2, points: Array, color: Color, width: float) -> void:
	if points.size() < 2:
		return

	var previous := _point_to_chart(plot, points[0])
	for index in range(1, points.size()):
		var current := _point_to_chart(plot, points[index])
		draw_line(previous, current, color, width, true)
		previous = current

func _point_to_chart(plot: Rect2, point: Dictionary) -> Vector2:
	var rpm_span := maxf(_rpm_max - _rpm_min, 1.0)
	var rpm_t := clampf((float(point.get("rpm", _rpm_min)) - _rpm_min) / rpm_span, 0.0, 1.0)
	var x := plot.position.x + plot.size.x * rpm_t
	var value_t := clampf(float(point.get("value", 0.0)) / maxf(_max_value, 1.0), 0.0, 1.0)
	var y := plot.position.y + plot.size.y * (1.0 - value_t)
	return Vector2(x, y)

func _recalculate_bounds() -> void:
	_rpm_min = INF
	_rpm_max = -INF
	_max_value = 1.0

	for item in _series:
		if typeof(item) != TYPE_DICTIONARY:
			continue

		var series: Dictionary = item
		var points: Array = series.get("points", [])
		for point_item in points:
			if typeof(point_item) != TYPE_DICTIONARY:
				continue

			var point: Dictionary = point_item
			var rpm := float(point.get("rpm", 0.0))
			var value := float(point.get("value", 0.0))
			_rpm_min = minf(_rpm_min, rpm)
			_rpm_max = maxf(_rpm_max, rpm)
			_max_value = maxf(_max_value, value)

	if _rpm_min == INF or _rpm_max == -INF:
		_rpm_min = 0.0
		_rpm_max = 1.0

	_max_value *= 1.08
