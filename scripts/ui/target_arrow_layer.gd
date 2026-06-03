extends Control
class_name TargetArrowLayer

const VALID_COLOR := Color(1.0, 0.45, 0.72, 0.95)
const INVALID_COLOR := Color(0.45, 0.48, 0.58, 0.72)
const LINE_WIDTH := 8.0
const HEAD_LENGTH := 34.0
const HEAD_ANGLE := 0.62

var active := false
var start_position := Vector2.ZERO
var end_position := Vector2.ZERO
var target_valid := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func show_arrow(from_position: Vector2, to_position: Vector2, is_valid_target: bool) -> void:
	active = true
	visible = true
	start_position = from_position
	end_position = to_position
	target_valid = is_valid_target
	queue_redraw()

func hide_arrow() -> void:
	active = false
	visible = false
	queue_redraw()

func _draw() -> void:
	if not active:
		return
	var color := VALID_COLOR if target_valid else INVALID_COLOR
	var points := _curve_points(start_position, end_position)
	if points.size() < 2:
		return
	draw_polyline(points, color, LINE_WIDTH, true)
	_draw_arrow_head(points[points.size() - 2], points[points.size() - 1], color)

func _curve_points(from_position: Vector2, to_position: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	var distance := from_position.distance_to(to_position)
	var control := (from_position + to_position) * 0.5 + Vector2(0.0, -min(180.0, distance * 0.35))
	for i in range(25):
		var t := float(i) / 24.0
		var a := from_position.lerp(control, t)
		var b := control.lerp(to_position, t)
		result.append(a.lerp(b, t))
	return result

func _draw_arrow_head(previous: Vector2, tip: Vector2, color: Color) -> void:
	var direction := (tip - previous).normalized()
	if direction == Vector2.ZERO:
		return
	var left := tip - direction.rotated(HEAD_ANGLE) * HEAD_LENGTH
	var right := tip - direction.rotated(-HEAD_ANGLE) * HEAD_LENGTH
	draw_line(tip, left, color, LINE_WIDTH, true)
	draw_line(tip, right, color, LINE_WIDTH, true)
