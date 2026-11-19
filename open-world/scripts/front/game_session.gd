extends Node
## Front end (Nov 19 2026), autoload "GameSession": what the start screen hands to the park scene.
##
##   intent "new"   New Game: a fresh save for `character`; the intro video has already played (or was skipped).
##   intent "load"  Load Game: restore `character`'s `load_kind` save (auto or manual).
##   intent ""      no front end (dev shortcuts ?story=p1 / ?play=free / --story=p1, tests): the park behaves exactly
##                  as it did before the front end, on the legacy save file.
##
## It also owns the player account adapter (account_bridge.gd), the save slots (save_slots.gd), play time and the
## device prefs (intro seen once on this device).

const Slots = preload("res://scripts/front/save_slots.gd")
const Bridge = preload("res://scripts/front/account_bridge.gd")
const SaveScript = preload("res://contracts/save_record.gd")

const PREFS := "user://pz_prefs.json"
const TITLE_SCENE := "res://scenes/start_screen.tscn"
const PARK_SCENE := "res://scenes/main.tscn"

signal saved(kind: String, path: String)

var slots = Slots.new()
var account: Node
var character := ""
var intent := ""
var load_kind := "auto"
var play_time := 0.0              # seconds, for the current character (restored from the save on load)
var created_unix := 0
var open_on_title := ""           # "load" when the pause menu sent the player to Load Game
var prefs := {"intro_seen": false, "intro_plays": 0}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	account = Bridge.new()
	account.name = "Account"
	add_child(account)
	_load_prefs()

func account_key() -> String:
	return account.account_key() if account != null else "guest"

func player_name() -> String:
	return character if character != "" else Slots.DEFAULT_NAME

## True while a character chosen on the start screen is being played (the pause menu shows Save / Load / Quit).
func has_character() -> bool:
	return character != ""

func begin_new(who: String) -> void:
	character = Slots.clean_name(who)
	intent = "new"
	load_kind = "auto"
	play_time = 0.0
	created_unix = int(Time.get_unix_time_from_system())

func begin_load(who: String, kind := "auto") -> void:
	character = who
	intent = "load"
	load_kind = "manual" if kind == "manual" else "auto"

## Called by the park once it has acted on the intent, so a scene reload does not repeat it.
func take_intent() -> String:
	var i := intent
	intent = ""
	return i

func clear() -> void:
	character = ""
	intent = ""
	play_time = 0.0
	created_unix = 0

func auto_path() -> String:
	return slots.path_for(account_key(), character, "auto")

## Fills the v3 meta block before a write.
func stamp(record, kind := "auto") -> void:
	record.meta["character"] = character
	record.meta["account"] = account_key()
	record.meta["kind"] = kind
	record.meta["saved_unix"] = int(Time.get_unix_time_from_system())
	record.meta["created_unix"] = created_unix if created_unix > 0 else int(record.meta.get("created_unix", 0))
	record.meta["play_time_s"] = snappedf(play_time, 0.1)
	record.meta["build"] = str(ProjectSettings.get_setting("application/config/version", ""))

## Manual save (pause menu). The autosave is written too, so Continue and the manual slot agree right after.
func save_manual(record) -> Dictionary:
	if not has_character():
		return {"ok": false, "reason": "no_character"}
	stamp(record, "manual")
	var r: Dictionary = slots.write(account_key(), character, "manual", record)
	if bool(r.get("ok", false)):
		account.offer_save(character, "manual", record.to_dict())
		saved.emit("manual", slots.path_for(account_key(), character, "manual"))
	return r

func note_autosave(record) -> void:
	if has_character():
		account.offer_save(character, "auto", record.to_dict())
		saved.emit("auto", auto_path())

func intro_seen() -> bool:
	return bool(prefs.get("intro_seen", false))

func mark_intro(finished_fully: bool) -> void:
	prefs["intro_plays"] = int(prefs.get("intro_plays", 0)) + 1
	if finished_fully:
		prefs["intro_seen"] = true
	_save_prefs()

func _load_prefs() -> void:
	if not FileAccess.file_exists(PREFS):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(PREFS))
	if typeof(d) == TYPE_DICTIONARY:
		prefs["intro_seen"] = bool(d.get("intro_seen", false))
		prefs["intro_plays"] = maxi(0, int(d.get("intro_plays", 0)))

func _save_prefs() -> void:
	var f := FileAccess.open(PREFS, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(prefs))
