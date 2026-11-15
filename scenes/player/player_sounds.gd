class_name PlayerSounds
extends Node
## Звуки игрока: шаги, прыжок и приземление, падение тела. Только слушает сигналы
## контроллера, поэтому у чужих игроков по сети будет работать так же.

var _player: PlayerController


func setup(player: PlayerController) -> void:
	_player = player
	player.footstep.connect(_on_footstep)
	player.landed.connect(_on_landed)
	player.knocked_down.connect(_on_knocked_down)


func _feet() -> Vector3:
	return _player.global_position + Vector3.UP * 0.05


func _on_footstep(speed: float) -> void:
	if speed < 0.5:
		return
	# вприсядку шаги почти не слышны, бегом — громкие (пригодится для сторожа)
	var k: float = clampf(speed / _player.feel.sprint_speed, 0.0, 1.0)
	var volume: float = lerpf(-24.0, -9.0, k)
	if _player.crouching:
		volume -= 8.0
	Audio.play_at(&"step_dirt", _feet(), volume, lerpf(0.92, 1.08, k))


func _on_landed(impact: float) -> void:
	Audio.play_at(&"land", _feet(), lerpf(-16.0, -3.0, clampf(impact / 12.0, 0.0, 1.0)))


func _on_knocked_down(_impact: float) -> void:
	Audio.play_at(&"body_fall", _feet(), -2.0)
