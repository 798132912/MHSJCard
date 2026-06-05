extends Button
class_name CardView

signal play_drag_started(hand_index: int, mouse_global_position: Vector2)
signal play_drag_updated(hand_index: int, mouse_global_position: Vector2)
signal play_drag_released(hand_index: int, mouse_global_position: Vector2)

@onready var frame_texture: TextureRect = $FrameTexture
@onready var cost_badge: TextureRect = $CostBadge
@onready var cost_label: Label = $CostBadge/CostLabel
@onready var art_texture: TextureRect = $ArtTexture
@onready var name_label: Label = $NameLabel
@onready var description_label: Label = $DescriptionLabel
@onready var type_badge: TextureRect = $TypeBadge
@onready var type_label: Label = $TypeBadge/TypeLabel
@onready var state_overlay: ColorRect = $StateOverlay

var _hand_index := -1
var _is_pending_play := false
var _can_play := false
var _is_dragging := false
var _base_scale := Vector2.ONE
var _scale_tween: Tween
const HOVER_SCALE := 1.12
const HOVER_TWEEN_TIME := 0.08

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	pivot_offset = custom_minimum_size * 0.5

func setup(card_data: Dictionary, display_data: Dictionary, hand_index: int, can_play: bool, is_pending_play: bool = false) -> void:
	_hand_index = hand_index
	_is_pending_play = is_pending_play
	_can_play = can_play
	disabled = false
	modulate = Color(1, 1, 1, 1) if can_play else Color(0.72, 0.72, 0.72, 1)
	state_overlay.visible = not can_play

	name_label.text = str(card_data.get("name", "未知卡牌"))
	cost_label.text = str(card_data.get("cost", 0))
	description_label.text = str(card_data.get("description", ""))
	type_label.text = str(display_data.get("type_name", ""))

	_set_texture(frame_texture, str(display_data.get("frame_path", "")))
	_set_texture(cost_badge, str(display_data.get("cost_badge_path", "")))
	_set_texture(type_badge, str(display_data.get("type_badge_path", "")))
	_set_texture(art_texture, str(display_data.get("art_path", "")))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _can_play and _hand_index >= 0:
				_is_dragging = true
				play_drag_started.emit(_hand_index, event.global_position)
				accept_event()

func _input(event: InputEvent) -> void:
	if not _is_dragging:
		return
	if event is InputEventMouseMotion:
		play_drag_updated.emit(_hand_index, event.global_position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_is_dragging = false
		play_drag_released.emit(_hand_index, event.global_position)
		_tween_scale(_base_scale)

func _on_mouse_entered() -> void:
	_tween_scale(_base_scale * HOVER_SCALE)

func _on_mouse_exited() -> void:
	if not _is_dragging:
		_tween_scale(_base_scale)

func _tween_scale(target_scale: Vector2) -> void:
	if _scale_tween != null:
		_scale_tween.kill()
	_scale_tween = create_tween()
	_scale_tween.tween_property(self, "scale", target_scale, HOVER_TWEEN_TIME)

func _set_texture(texture_rect: TextureRect, path: String) -> void:
	if path != "" and ResourceLoader.exists(path):
		texture_rect.texture = load(path)
		texture_rect.visible = true
	else:
		texture_rect.texture = null
		texture_rect.visible = false
