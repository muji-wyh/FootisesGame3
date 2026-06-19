class_name InputController
extends RefCounted

## Base class for anything that drives a fighter. A controller's only job is to
## produce one InputFrame per simulation tick. PlayerController reads the keyboard/
## gamepad; CpuController synthesises inputs from AI logic. This symmetry means the
## CPU is "just another controller", so the fighter/combat code never special-cases it.

## Override in subclasses. `self_fighter` and `opponent` are Fighter nodes (typed
## loosely to avoid a cyclic class dependency).
func poll(_self_fighter: Object, _opponent: Object) -> InputFrame:
	return InputFrame.new()
