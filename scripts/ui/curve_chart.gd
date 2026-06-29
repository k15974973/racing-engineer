extends Control

var _power_points: Array = []
var _torque_points: Array = []

func _init() -> void:
	custom_minimum_size = Vector2(0, 180)

func set_curve_data(curves: Dictionary) -> void:
	_power_points = curves.get("power", [])
	_torque_points = curves.get("torque", [])
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

	_draw_series(plot, _torque_points, Color.html("#0F6E56"))
	_draw_series(plot, _power_points, Color.html("#534AB7"))

func _draw_series(plot: Rect2, points: Array, color: Color) -> void:
	if points.size() < 2:
		return

	var previous := _point_to_chart(plot, points[0], 0, points.size())
	for index in range(1, points.size()):
		var current := _point_to_chart(plot, points[index], index, points.size())
		draw_line(previous, current, color, 2.0, true)
		previous = current

func _point_to_chart(plot: Rect2, point: Dictionary, index: int, count: int) -> Vector2:
	var x := plot.position.x + plot.size.x * float(index) / maxf(float(count - 1), 1.0)
	var norm := clampf(float(point.get("norm", 0.0)), 0.0, 1.0)
	var y := plot.position.y + plot.size.y * (1.0 - norm)
	return Vector2(x, y)
