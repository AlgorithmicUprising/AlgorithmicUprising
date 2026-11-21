extends RefCounted
## Front end (Nov 19 2026): where saves live. Saves are keyed by account, then by the player's chosen character name.
##
##   user://pz_saves/<account key>/<character key>/auto.json     autosave (mission checkpoints, completion, quit)
##   user://pz_saves/<account key>/<character key>/manual.json   manual save (pause menu, Save)
##
## Slot design: one character = one save identity. Each character has an autosave and one manual save, so a bad
## autosave (saved right before a bail-fest, say) never eats the save the player chose to keep. "Slots" are the
## characters themselves (up to MAX_CHARACTERS per account), which is what the user asked for: saves happen under the
## chosen character name. On the web build user:// is IndexedDB, so it survives a page reload.
##
## The account key is "guest" until the site hands the game a signed-in player (see account_bridge.gd). Nothing here
## talks to a server: every save is local to this browser or this machine.

const SaveScript = preload("res://contracts/save_record.gd")

const ROOT := "user://pz_saves"
const LEGACY := "user://au-open-world-save-v1.json"   # M0/M1 free-roam + story save (v1/v2), before the front end
const MAX_CHARACTERS := 12
const DEFAULT_NAME := "Fony"
const NAME_MAX := 16
const KINDS := ["auto", "manual"]

var root := ROOT
var legacy := LEGACY

func _init(base := ROOT) -> void:
	root = base

## Trims and validates a character name. Empty -> the default (Fony, a placeholder). Letters, digits, spaces and
## - ' . only; at most NAME_MAX characters. Returns "" when nothing usable is left.
static func clean_name(raw: String) -> String:
	var s := raw.strip_edges()
	if s == "":
		return DEFAULT_NAME
	var out := ""
	for i in s.length():
		var c := s.substr(i, 1)
		var code := c.unicode_at(0)
		var ok := (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122) \
			or c == " " or c == "-" or c == "'" or c == "." or (code >= 192 and code <= 591)
		if ok:
			out += c
	while "  " in out:
		out = out.replace("  ", " ")
	return out.strip_edges().substr(0, NAME_MAX).strip_edges()

## Folder-safe key for a name or an account: lowercase a-z 0-9 and -, so "Fony" and "fony" are the same character.
static func key_of(text: String) -> String:
	var s := text.strip_edges().to_lower()
	var out := ""
	for i in s.length():
		var c := s.substr(i, 1)
		var code := c.unicode_at(0)
		if (code >= 48 and code <= 57) or (code >= 97 and code <= 122):
			out += c
		elif c == " " or c == "-" or c == "_" or c == "." or c == "'":
			if not out.ends_with("-"):
				out += "-"
		else:
			out += "u%x" % code
	out = out.trim_prefix("-").trim_suffix("-")
	return out.substr(0, 48) if out != "" else "x"

func account_dir(account: String) -> String:
	return root.path_join(key_of(account if account != "" else "guest"))

func character_dir(account: String, character: String) -> String:
	return account_dir(account).path_join(key_of(character))

func path_for(account: String, character: String, kind := "auto") -> String:
	return character_dir(account, character).path_join(("manual" if kind == "manual" else "auto") + ".json")

func exists(account: String, character: String) -> bool:
	for k in KINDS:
		if FileAccess.file_exists(path_for(account, character, k)):
			return true
	return false

func any(account: String) -> bool:
	return not list(account).is_empty()

## Writes a save record (contracts/save_record.gd) to a slot. Creates the folders.
func write(account: String, character: String, kind: String, record) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(character_dir(account, character))
	return record.save_user(path_for(account, character, kind))

func read(account: String, character: String, kind := "auto") -> Dictionary:
	var path := path_for(account, character, kind)
	if not FileAccess.file_exists(path):
		return {"ok": false, "reason": "missing"}
	var rec = SaveScript.new()
	var r: Dictionary = rec.load_user(path)
	if not bool(r.get("ok", false)):
		return r
	return {"ok": true, "record": rec, "path": path}

## Removes a character's saves (New Game over an existing character, after the player confirms).
func erase(account: String, character: String) -> void:
	for k in KINDS:
		var p := path_for(account, character, k)
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	DirAccess.remove_absolute(character_dir(account, character))

## Every character with a save, newest first: [{character, key, auto: summary|null, manual: summary|null, latest}].
func list(account: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(account_dir(account))
	if dir == null:
		return out
	for sub in dir.get_directories():
		var entry := {"key": sub, "character": "", "auto": null, "manual": null, "latest": 0}
		for k in KINDS:
			var p := account_dir(account).path_join(sub).path_join(k + ".json")
			if not FileAccess.file_exists(p):
				continue
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(p))
			if typeof(parsed) != TYPE_DICTIONARY:
				continue
			var sm: Dictionary = SaveScript.summary_of(parsed)
			entry[k] = sm
			if entry.character == "" and sm.character != "":
				entry.character = sm.character
			entry.latest = maxi(int(entry.latest), int(sm.saved_unix))
		if entry.auto == null and entry.manual == null:
			continue
		if entry.character == "":
			entry.character = sub
		out.append(entry)
	out.sort_custom(func(a, b): return int(a.latest) > int(b.latest))
	return out

## One-time import of the pre-front-end save (au-open-world-save-v1.json, save v1/v2) as the default character
## (Fony) under the guest account, so M0/M1 progress shows up in Load Game. The old file is left where it is.
## Only runs when that account has no characters yet. Returns true when it imported.
func migrate_legacy(account := "guest", from := "") -> bool:
	var src := from if from != "" else legacy
	if not FileAccess.file_exists(src) or any(account):
		return false
	var rec = SaveScript.new()
	if not bool(rec.load_user(src).get("ok", false)):
		return false
	rec.meta["character"] = DEFAULT_NAME
	rec.meta["account"] = account
	rec.meta["kind"] = "auto"
	rec.meta["saved_unix"] = int(FileAccess.get_modified_time(src))
	rec.meta["created_unix"] = rec.meta["saved_unix"]
	rec.meta["migrated_from"] = rec.migrated_from
	rec.meta["imported_from"] = src
	if rec.story.get("current", "") == "":
		for id in rec.story.missions:
			if str(rec.story.missions[id].get("state", "")) == "active":
				rec.story["current"] = id
	return bool(write(account, DEFAULT_NAME, "auto", rec).get("ok", false))
