class_name CpuController
extends InputController

## AI controller. Fully implemented in Phase 5; for now it stands neutral so the
## project boots and Local 2P works. Because it is just an InputController, the
## fighter/combat code treats it identically to a human player.

var difficulty: int = 1

func _init(p_difficulty: int = 1) -> void:
	difficulty = p_difficulty

func poll(_self_fighter: Object, _opponent: Object) -> InputFrame:
	return InputFrame.new()
