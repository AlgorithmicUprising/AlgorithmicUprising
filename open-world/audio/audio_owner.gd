extends Node

const Catalog = preload("res://contracts/song_catalog.gd")
const JsonFile = preload("res://scripts/json_file.gd")

var catalog = Catalog.new()
var holder := ""
var ready_ok := false

func _ready() -> void:
	var parsed = JsonFile.read("res://data/song_catalog.json")
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Song catalog missing")
		return
	var loaded: Dictionary = catalog.load_text(JSON.stringify(parsed))
	ready_ok = bool(loaded.get("ok", false))
	if not ready_ok:
		push_error("Song catalog rejected: %s" % loaded)
		return
	holder = "world"

func claim(owner: String) -> bool:
	return holder == owner

func release(owner: String) -> void:
	if holder == owner:
		holder = ""

func handoff(from_owner: String, to_owner: String) -> bool:
	if holder != from_owner or to_owner.is_empty():
		return false
	holder = to_owner
	return true

func request_song(id: String) -> Dictionary:
	if not ready_ok:
		return {"ok": false, "played": false, "reason": "catalog"}
	return catalog.request_playback(id)
