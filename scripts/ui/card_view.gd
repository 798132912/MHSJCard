extends Button
class_name CardView

signal play_requested(hand_index: int)

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

func _ready() -> void:
	pressed.connect(_on_pressed)

func setup(card_data: Dictionary, display_data: Dictionary, hand_index: int, can_play: bool, is_pending_play: bool = false) -> void:
	_hand_index = hand_index
	_is_pending_play = is_pending_play
	disabled = not can_play
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

func _on_pressed() -> void:
	if _hand_index >= 0:
		play_requested.emit(_hand_index)

func _set_texture(texture_rect: TextureRect, path: String) -> void:
	if path != "" and ResourceLoader.exists(path):
		texture_rect.texture = load(path)
		texture_rect.visible = true
	else:
		texture_rect.texture = null
		texture_rect.visible = false
