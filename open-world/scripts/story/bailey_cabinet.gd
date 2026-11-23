extends Node3D
## 1.1B unlocks GRIND THE TERMS. This spot opens the existing Punk Arcade page
## (games/grind-the-terms). The game files are not touched. Until the flag is set, E does nothing.

const Overlay = preload("res://scripts/arcade_overlay.gd")

const GAME_ID := "grind-the-terms"
const TITLE := "Grind the Terms"
const PATH := "games/grind-the-terms/demo/embed.html"
const UNLOCK := "cabinet_grind_the_terms"

var overlay: Node

func _ready() -> void:
	add_to_group("interactable")

func unlocked(flow: Node = null) -> bool:
	if flow != null and flow.get("save") != null and flow.save.has_method("flag") and flow.save.flag(UNLOCK):
		return true
	var tree := get_tree()
	if tree == null:
		return false
	for n in tree.get_nodes_in_group("hq_flow"):
		var save = n.get("save")
		if save != null and save.has_method("flag") and save.flag(UNLOCK):
			return true
	return false

func prompt() -> String:
	if not unlocked() or (overlay != null and overlay.is_open()):
		return ""
	return "Play " + TITLE

func interact(flow: Node) -> void:
	if not unlocked(flow):
		return
	if overlay != null and is_instance_valid(overlay) and overlay.is_open():
		return
	if overlay == null or not is_instance_valid(overlay):
		overlay = Overlay.new()
		overlay.name = "BaileyOverlay"
		add_child(overlay)
	var who: Node = flow.player if flow != null and "player" in flow else null
	overlay.open_game(GAME_ID, TITLE, PATH, who)
