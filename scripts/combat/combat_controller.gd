extends RefCounted

class_name CombatController

const PHASE_SETUP := "setup"
const PHASE_PLAYER := "player"
const PHASE_ENEMY := "enemy"
const PHASE_VICTORY := "victory"
const PHASE_DEFEAT := "defeat"

var phase := PHASE_SETUP
var turn_count := 0

func reset() -> void:
	phase = PHASE_SETUP
	turn_count = 0

func start_combat() -> void:
	turn_count = 0
	phase = PHASE_PLAYER

func start_player_turn() -> int:
	turn_count += 1
	phase = PHASE_PLAYER
	return turn_count

func start_enemy_turn() -> void:
	phase = PHASE_ENEMY

func set_victory() -> void:
	phase = PHASE_VICTORY

func set_defeat() -> void:
	phase = PHASE_DEFEAT

func is_player_phase() -> bool:
	return phase == PHASE_PLAYER

func is_combat_over() -> bool:
	return phase == PHASE_VICTORY or phase == PHASE_DEFEAT

func phase_text() -> String:
	match phase:
		PHASE_PLAYER:
			return "玩家回合"
		PHASE_ENEMY:
			return "敌人回合"
		PHASE_VICTORY:
			return "战斗胜利"
		PHASE_DEFEAT:
			return "战斗失败"
		_:
			return "准备中"
