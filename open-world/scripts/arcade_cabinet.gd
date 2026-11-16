extends StaticBody3D
## Arcade Phase 2 (LOCAL): a playable cabinet in the interior. Interact (E / pad X) opens the existing
## Punk Arcade game for this cabinet through arcade_overlay.gd. Visuals are batched by arcade_interior.gd;
## this node only carries collision, the prompt and the link.

var game_id := ""
var title := ""
var path := ""        # relative to the Pages root
var overlay: Node
var uses := 0

func _ready() -> void:
	add_to_group("interactable")
	collision_layer = 1
	collision_mask = 1

func prompt() -> String:
	if overlay == null or overlay.is_open():
		return ""
	return "Play " + title

func interact(flow: Node) -> void:
	if overlay == null or overlay.is_open():
		return
	if flow != null:
		if "boundary" in flow and flow.boundary.phase != "world":
			return
		if flow.get("dialogue_open") or flow.get("paused"):
			return
	var who: Node = flow.player if flow != null and "player" in flow else null
	if overlay.open_game(game_id, title, path, who):
		uses += 1
