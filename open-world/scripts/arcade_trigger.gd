extends Node3D
## Arcade Phase 1 (LOCAL): an interact spot (E / pad X) that forwards to the Arcade door controller.

var door: Node
var kind := "enter"   # "enter" (outside the shutter) or "leave" (inside)

func _ready() -> void:
	add_to_group("interactable")

func prompt() -> String:
	if door == null or not door.can_use(kind):
		return ""
	return "Open the Arcade" if kind == "enter" else "Leave the Arcade"

func interact(flow: Node) -> void:
	if door == null:
		return
	if kind == "enter":
		door.enter(flow)
	else:
		door.leave(flow)
