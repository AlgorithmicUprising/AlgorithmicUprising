extends RefCounted
## Front end (Nov 19 2026) headless tests: save v3 and migration from v1/v2, save slots keyed by account and character,
## the protagonist name, the account adapter, the start screen (menu navigation, New Game naming and confirmation,
## Load Game, Credits, Uprising Arcade), the intro hand-off, New Game / Load Game in the park, pause-menu save.
## Run from test_main.gd (full suite) or alone with AU_TEST_ONLY=front.

const SaveScript = preload("res://contracts/save_record.gd")
const Slots = preload("res://scripts/front/save_slots.gd")
const Protagonist = preload("res://scripts/front/protagonist.gd")
const Bridge = preload("res://scripts/front/account_bridge.gd")
const IntroPlayer = preload("res://scripts/front/intro_player.gd")

const ROOT := "user://pz_saves_test"
const LEGACY := "user://pz-test-legacy.json"

var t: Node
var gs: Node
var real_slots

func run(host: Node) -> void:
	t = host
	gs = t.get_node_or_null("/root/GameSession")
	ok(gs != null, "GameSession autoload is installed")
	if gs == null:
		return
	real_slots = gs.slots
	_wipe()
	gs.slots = Slots.new(ROOT)
	gs.slots.legacy = "user://pz-test-no-legacy.json"
	gs.clear()
	_save_v3()
	_migration()
	_slots()
	_protagonist()
	_account()
	await _intro()
	await _start_screen()
	await _park_new_game()
	await _park_load()
	await _park_pause_save()
	await _park_free_roam_load()
	gs.clear()
	gs.intent = ""
	gs.open_on_title = ""
	gs.slots = real_slots
	_wipe()

func ok(cond: bool, name: String) -> void:
	t.expect(cond, "front: " + name)

func frames(n: int) -> void:
	for _i in n:
		await t.get_tree().process_frame

func _wipe() -> void:
	var s = Slots.new(ROOT)
	for acct in ["guest", "au-u123"]:
		for e in s.list(acct):
			s.erase(acct, str(e.character))
		DirAccess.remove_absolute(s.account_dir(acct))
	DirAccess.remove_absolute(ROOT)
	if FileAccess.file_exists(LEGACY):
		DirAccess.remove_absolute(LEGACY)

# ------------------------------------------------------------------ save v3

func _save_v3() -> void:
	var s = SaveScript.new()
	ok(s.VERSION == 3 and s.READS == [1, 2, 3], "save v3, reads v1, v2 and v3")
	s.meta["character"] = "Jamie"
	s.meta["play_time_s"] = 125.5
	s.meta["saved_unix"] = 1795000000
	s.player = {"mode": "free", "district": "", "zone": "SKATE YARD", "pos": [1.5, 0.5, -3.25], "yaw": 0.75, "skating": false}
	s.settings = {"invert_y": false, "look_sensitivity": 0.004, "painted_sprite": true}
	s.set_mission("p1_practice_run", {"state": "active", "objective": "quarter", "checkpoint": "quarter", "done": ["push", "kick_up", "drop_on", "ollie"]})
	s.story["current"] = "p1_practice_run"
	s.mission("p1_practice_run")["zero_score"] = 4000
	var r = SaveScript.new()
	ok(bool(r.apply_json(JSON.stringify(s.to_dict())).get("ok")), "save v3 json round trip")
	ok(r.meta.character == "Jamie" and is_equal_approx(float(r.meta.play_time_s), 125.5) and r.player.zone == "SKATE YARD" and r.player.pos == [1.5, 0.5, -3.25] and r.player.skating == false, "v3 keeps character, play time, position and skating")
	ok(r.settings.invert_y == false and is_equal_approx(float(r.settings.look_sensitivity), 0.004) and r.story.current == "p1_practice_run" and r.mission("p1_practice_run").checkpoint == "quarter" and r.mission("p1_practice_run").zero_score == 4000, "v3 keeps settings, the mission in progress, its checkpoint and Zero Score")
	var bad = SaveScript.new()
	ok(bool(bad.apply_dict({"contract": "au.world_save", "contract_version": 3, "meetings": {}, "results": [], "settings": {"look_sensitivity": 99.0}, "player": {"mode": "boss", "pos": [1, 2]}}).get("ok")) and bad.settings.look_sensitivity == 0.008 and bad.player.mode == "free" and bad.player.pos == [], "v3 clamps settings and drops a malformed position")
	var sm: Dictionary = SaveScript.summary_of(s.to_dict())
	ok(sm.character == "Jamie" and sm.where == "p1_practice_run / quarter" and sm.saved_unix == 1795000000 and sm.version == 3, "save summary for the Load Game list")

func _migration() -> void:
	var v1 = SaveScript.new()
	ok(bool(v1.apply_dict({"contract": "au.world_save", "contract_version": 1, "meetings": {"zero": true}, "results": []}).get("ok")) and v1.migrated_from == 1 and v1.meta.get("migrated_from") == 1 and v1.player.is_empty() and v1.to_dict().contract_version == 3, "migration: v1 loads, empty v3 sections, written back as v3")
	var v2data := {"contract": "au.world_save", "contract_version": 2, "meetings": {"zero": false, "fony": true}, "results": [],
		"exploration": {"version": 1, "districts": {"test_district": {"visits": 2, "first_visit_unix": 10, "last_visit_unix": 20, "discovered": {"shortcuts": ["gap"]}}}},
		"story": {"version": 1, "missions": {"p1_practice_run": {"state": "done", "completions": 1, "best_score": 3600, "zero_score": 3500, "done": ["push"]}}, "flags": {"p1_voice_heard": true}, "day": 1, "time_of_day": "dawn", "signal": 0}}
	var v2 = SaveScript.new()
	ok(bool(v2.apply_dict(v2data).get("ok")) and v2.migrated_from == 2, "migration: a v2 save (M1) loads")
	ok(v2.mission("p1_practice_run").zero_score == 3500 and v2.mission("p1_practice_run").best_score == 3600 and v2.flag("p1_voice_heard") and v2.district_visits("test_district") == 2 and v2.met.fony, "migration: v2 keeps missions, Zero Score, best, flags, district visits and meetings")
	var back = SaveScript.new()
	ok(bool(back.apply_json(JSON.stringify(v2.to_dict())).get("ok")) and back.migrated_from == 0 and back.mission("p1_practice_run").zero_score == 3500, "migration: v2 written back as v3 reads as current")

# ------------------------------------------------------------------ slots

func _slots() -> void:
	ok(Slots.clean_name("") == "Fony" and Slots.clean_name("  Jamie  ") == "Jamie" and Slots.clean_name("<script>x") == "scriptx" and Slots.clean_name("A".repeat(40)).length() == 16, "character names: default Fony, trimmed, filtered, 16 max")
	ok(Slots.key_of("Fony") == Slots.key_of("fony") and Slots.key_of("Mary Jane") == "mary-jane" and not ("/" in Slots.key_of("../x")), "character keys are case-blind and path-safe")
	var s = Slots.new(ROOT)
	ok(not s.any("guest"), "slots: no saves to start with")
	var rec = SaveScript.new()
	rec.meta["character"] = "Jamie"
	rec.meta["saved_unix"] = 100
	ok(bool(s.write("guest", "Jamie", "auto", rec).get("ok")) and s.exists("guest", "jamie") and s.path_for("guest", "Jamie").begins_with(ROOT + "/guest/jamie/"), "slots: autosave under account / character")
	rec.meta["saved_unix"] = 200
	rec.meta["kind"] = "manual"
	s.write("guest", "Jamie", "manual", rec)
	var other = SaveScript.new()
	other.meta["character"] = "Fony"
	other.meta["saved_unix"] = 300
	s.write("guest", "Fony", "auto", other)
	s.write("au-u123", "Zed", "auto", other)
	var l: Array = s.list("guest")
	ok(l.size() == 2 and l[0].character == "Fony" and l[1].character == "Jamie" and l[1].auto != null and l[1].manual != null, "slots: Load Game lists this account's characters, newest first, with auto and manual")
	ok(s.list("au-u123").size() == 1 and s.list("au-u123")[0].character == "Fony", "slots: another account's saves stay separate")
	s.erase("guest", "Jamie")
	ok(not s.exists("guest", "Jamie") and s.list("guest").size() == 1, "slots: erase removes a character's saves")
	s.erase("guest", "Fony")
	s.erase("au-u123", "Zed")
	# legacy import: the M1 v2 file becomes the default character
	var legacy = SaveScript.new()
	legacy.set_mission("p1_practice_run", {"state": "active", "checkpoint": "ollie", "objective": "ollie"})
	legacy.save_user(LEGACY)
	var raw = JSON.parse_string(FileAccess.get_file_as_string(LEGACY))
	raw["contract_version"] = 2
	raw.erase("meta")
	raw.erase("player")
	raw.erase("settings")
	raw["story"].erase("current")
	var f := FileAccess.open(LEGACY, FileAccess.WRITE)
	f.store_string(JSON.stringify(raw))
	f.close()
	ok(s.migrate_legacy("guest", LEGACY) and s.exists("guest", "Fony"), "legacy: the pre-front-end save imports as Fony")
	var imp: Dictionary = s.read("guest", "Fony")
	ok(bool(imp.get("ok")) and imp.record.story.current == "p1_practice_run" and imp.record.meta.migrated_from == 2 and FileAccess.file_exists(LEGACY), "legacy: mission in progress kept, marked migrated from v2, old file left in place")
	ok(not s.migrate_legacy("guest", LEGACY), "legacy: imports once (not over existing characters)")
	s.erase("guest", "Fony")
	DirAccess.remove_absolute(LEGACY)

func _protagonist() -> void:
	ok(Protagonist.text("Pop. Easy. Five days, {name}.", "Jamie") == "Pop. Easy. Five days, Jamie." and Protagonist.speaker("FONY", "Jamie") == "JAMIE" and Protagonist.speaker("TEXT FONY", "Jamie") == "TEXT JAMIE" and Protagonist.speaker("VOICE (O.S.)", "Jamie") == "VOICE (O.S.)", "protagonist name fills {name} and the FONY speaker slot only")
	var p1 = JSON.parse_string(FileAccess.get_file_as_string("res://data/missions/p1_practice_run.json"))
	var flat := JSON.stringify(p1)
	ok("{name}" in flat and not ("Five days, Fony" in flat), "P.1 data uses {name} for the protagonist")
	ok(Protagonist.current(t.get_tree()) == "Fony", "no character chosen: the protagonist is Fony")

func _account() -> void:
	var b = Bridge.new()
	ok(b.account_key() == "guest" and b.label() == "GUEST" and not b.can_sync_saves(), "account: guest by default (the site does not answer yet)")
	ok(not b.apply_message({"source": "evil", "type": "pz:account", "v": 1, "player": {"id": "x"}}) and b.state == "guest", "account: ignores messages that are not from the site")
	ok(b.apply_message({"source": "au-site", "type": "pz:account", "v": 1, "player": {"id": "u123", "handle": "skater"}, "capabilities": ["pz-saves"]}) and b.account_key() == "au-u123" and b.label() == "SKATER" and b.can_sync_saves(), "account: a signed-in player keys saves under their account")
	ok(b.apply_message({"source": "au-site", "type": "pz:account", "v": 1, "player": null}) and b.account_key() == "guest", "account: signed out goes back to guest")
	ok(Bridge.HOSTS.has("https://algorithmicuprising.com") and Bridge.HOSTS.size() == 3, "account: the same three hosts as the arcade embed bridge")
	b.free()

func _intro() -> void:
	var ip = IntroPlayer.new()
	t.add_child(ip)
	var got: Array = []
	ip.finished.connect(func(r): got.append(r))
	ip.play()
	await frames(2)
	ok(got == ["unavailable"] and ip.state == "done", "intro: headless skips straight to the hand-off")
	var cfg: Dictionary = ip.config
	ok(cfg.get("id") == "pz_intro_v1" and (cfg.web.sources as Array).size() >= 1 and float(cfg.skip.hold_s) > 0.0 and float(cfg.skip.hold_s_after_seen) == 0.0, "intro: configurable sources, hold-to-skip, single press once seen")
	ok(not ResourceLoader.exists("res://media/intro/project-zero-intro.ogv"), "intro: no video inside the pack")
	ip.queue_free()
	await frames(1)

# ------------------------------------------------------------------ start screen

func _title() -> Control:
	var s = load("res://scenes/start_screen.tscn").instantiate()
	s.auto_change = false
	t.add_child(s)
	await frames(3)
	return s

func _press(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	await frames(2)
	e = e.duplicate()
	e.pressed = false
	Input.parse_input_event(e)
	await frames(2)

func _focus(s) -> String:
	var f = s.get_viewport().gui_get_focus_owner()
	return str(f.name) if f != null else ""

func _start_screen() -> void:
	var boot = load("res://scenes/boot.tscn").instantiate()
	ok(boot.next_scene == "res://scenes/start_screen.tscn", "boot hands off to the start screen")
	boot.free()
	load("res://scripts/front/start_screen.gd").reset_statics(false, true)
	var s = await _title()
	ok(s.title_state and not s.menu_row.visible and s.layers.has("plate") and s.layers.plate.texture != null and s.layers.title.texture != null, "start screen: the puppeteer art and title, PRESS START first")
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.physical_keycode = KEY_ENTER
	key.pressed = true
	Input.parse_input_event(key)
	await frames(2)
	key = key.duplicate()
	key.pressed = false
	Input.parse_input_event(key)
	await frames(2)
	ok(not s.title_state and s.menu_row.visible, "start screen: a press brings up the menu")
	var labels: Array = []
	for b in s.menu_row.get_children():
		labels.append(b.text)
	ok(labels == ["NEW GAME", "LOAD GAME", "UPRISING ARCADE", "CREDITS"], "menu: New Game, Load Game, Uprising Arcade, Credits")
	ok(_focus(s) == "Menu_new", "menu: New Game has focus")
	ok(not s.load_enabled() and s.menu_buttons.load.disabled, "menu: Load Game is greyed out with no saves")
	await _press("ui_right")
	ok(_focus(s) == "Menu_arcade", "menu: right skips the greyed-out Load Game")
	await _press("ui_right")
	ok(_focus(s) == "Menu_credits", "menu: right again reaches Credits")
	await _press("ui_left")
	await _press("ui_left")
	ok(_focus(s) == "Menu_new", "menu: left goes back to New Game")
	await _press("ui_down")
	ok(_focus(s) == "Account", "menu: down reaches the player account chip")
	ok("GUEST" in s.account_button.text and "SIGN IN" in s.account_button.text, "menu: shows the guest account and the arcade sign-in")
	await _press("ui_up")
	# Credits
	s.choose("credits")
	await frames(3)
	var credits := ""
	for sec in s.credits_text():
		credits += str(sec[0]) + "\n" + str(sec[1]) + "\n"
	var lic := " ".join(Engine.get_license_text().split(" ", false))
	ok(s.panel_kind == "credits" and "ZERO X GAME ENGINE" in credits and " ".join(credits.split(" ", false)).contains(lic) and "Godot Engine 4.7.2" in credits, "credits: Zero X Game Engine with Godot's version and full MIT license")
	ok("[credit TBD]" in credits and "Kenney" in credits and "Press Start 2P" in credits, "credits: AU placeholders, third-party notices")
	await _press("ui_cancel")
	ok(s.panel == null and _focus(s) == "Menu_credits", "credits: Esc / B goes back to the menu")
	# Uprising Arcade
	s.choose("arcade")
	await frames(3)
	var carts: Array = []
	for b in s.panel.find_children("Cart_*", "Button", true, false):
		carts.append(str(b.name))
	ok(s.panel_kind == "arcade" and carts.has("Cart_console") and carts.has("Cart_grind-the-terms") and carts.has("Cart_bars-per-watt") and carts.size() == 6, "arcade: the console plus the five arcade cartridges")
	s.open_cartridge("grind-the-terms", "Grind the Terms", "games/grind-the-terms/demo/embed.html")
	ok(s.overlay.opens == 1 and s.overlay.last_path == "games/grind-the-terms/demo/embed.html" and s.overlay.back_label == "BACK TO PROJECT ZERO", "arcade: a cartridge opens in the arcade overlay with a way back")
	s.overlay.close()
	await frames(1)
	ok(not s.overlay.is_open() and s.panel_kind == "arcade", "arcade: closing the game returns to the console")
	s.close_panel()
	# New Game, no saves: name -> intro -> park
	gs.clear()
	s.choose("new")
	await frames(3)
	ok(s.panel_kind == "name" and s.name_edit.text == "Fony", "new game: asks for a character name, default Fony")
	s.name_edit.text = "Jamie"
	s.confirm_name()
	await frames(3)
	ok(gs.character == "Jamie" and gs.intent == "new" and s.left_to == "res://scenes/main.tscn" and s.intro.state == "done", "new game: intro hand-off, then the park with intent new for Jamie")
	s.queue_free()
	await frames(2)
	# with a save for Jamie: confirmation
	var rec = SaveScript.new()
	rec.meta["character"] = "Jamie"
	rec.meta["saved_unix"] = int(Time.get_unix_time_from_system())
	gs.slots.write("guest", "Jamie", "auto", rec)
	gs.clear()
	s = await _title()
	ok(not s.title_state and s.load_enabled(), "start screen: menu straight away the second time; Load Game enabled with a save")
	s.choose("new")
	await frames(3)
	s.name_edit.text = "jamie"
	s.confirm_name()
	await frames(3)
	ok(s.panel_kind == "confirm" and s.left_to == "" and _focus(s) == "Cancel", "new game over an existing save asks first (Cancel focused)")
	s.panel.find_child("Cancel", true, false).emit_signal("pressed")
	await frames(3)
	ok(s.panel_kind == "name" and gs.slots.exists("guest", "Jamie"), "new game: Cancel keeps the save")
	s.name_edit.text = "Jamie"
	s.confirm_name()
	await frames(3)
	s.panel.find_child("StartOver", true, false).emit_signal("pressed")
	await frames(3)
	ok(not gs.slots.exists("guest", "Jamie") and gs.intent == "new" and s.left_to != "", "new game: Start Over erases the old save and starts")
	s.queue_free()
	await frames(2)
	# Load Game
	gs.slots.write("guest", "Jamie", "auto", rec)
	rec.meta["kind"] = "manual"
	gs.slots.write("guest", "Jamie", "manual", rec)
	gs.clear()
	s = await _title()
	s.choose("load")
	await frames(3)
	var rows: Array = []
	for b in s.panel.find_children("Save_*", "Button", true, false):
		rows.append(str(b.name))
	ok(s.panel_kind == "load" and rows == ["Save_jamie_auto", "Save_jamie_manual"] and _focus(s) == "Save_jamie_auto", "load game: lists the character's autosave and manual save")
	s.panel.find_child("Save_jamie_manual", true, false).emit_signal("pressed")
	await frames(2)
	ok(gs.intent == "load" and gs.character == "Jamie" and gs.load_kind == "manual" and s.left_to == "res://scenes/main.tscn", "load game: hands the chosen save to the park")
	s.queue_free()
	await frames(2)
	gs.slots.erase("guest", "Jamie")
	gs.clear()

# ------------------------------------------------------------------ the park

func _park() -> Node:
	var main = load("res://scenes/main.tscn").instantiate()
	t.add_child(main)
	await frames(4)
	return main

func _park_new_game() -> void:
	gs.begin_new("Jamie")
	var main = await _park()
	var story = main.get_node("Story")
	var path: String = gs.auto_path()
	ok(main.session_intent == "new" and story.active and story.runner.current_id() == "push", "park: New Game goes straight into P.1 (push)")
	ok(main.flow.save_path == path and FileAccess.file_exists(path), "park: New Game autosaves under the character")
	var disk = SaveScript.new()
	disk.load_user(path)
	ok(disk.meta.character == "Jamie" and disk.story.current == "p1_practice_run" and disk.flag("p1_intro_seen") and disk.mission("p1_practice_run").state == "active", "park: the autosave has the character, the mission in progress and the intro flag")
	story.queue.clear()
	story.talk_left = 0.0
	story.card_left = 0.0
	story._say_all([["FONY", "Pop. Easy. Five days, {name}."]])
	await frames(3)
	ok(story.spoken.has("FONY|Pop. Easy. Five days, Jamie.") and story.hud.speaker_label.text == "JAMIE", "park: story lines and the speaker tag use the chosen name")
	# reach the ollie checkpoint and the quarter checkpoint through the runner, then autosave happens
	for e in ["speed", "kick_up", "drop_on", "trick_land"]:
		story.runner.notify(e, {"speed": 9.0})
	await frames(2)
	disk = SaveScript.new()
	disk.load_user(path)
	ok(disk.mission("p1_practice_run").checkpoint == "quarter" and disk.player.mode == "story", "park: reaching a checkpoint autosaves it")
	ok(gs.play_time > 0.0, "park: play time counts")
	main.queue_free()
	await frames(3)

func _park_load() -> void:
	# continues from the save written above (Jamie, P.1 at the quarter-pipe checkpoint)
	gs.begin_load("Jamie", "auto")
	var main = await _park()
	var story = main.get_node("Story")
	ok(main.load_result.get("ok") == true and main.load_result.get("resumed") == "story", "load: the park restores the save")
	ok(story.active and story.runner.current_id() == "quarter" and story.runner.is_done("ollie"), "load: P.1 resumes at the quarter-pipe checkpoint")
	var q: Array = story.def.spawns.quarter
	ok(main.player.global_position.distance_to(Vector3(q[0], q[1], q[2])) < 1.5, "load: the player is at the checkpoint spawn")
	main.queue_free()
	await frames(3)

func _park_pause_save() -> void:
	gs.begin_load("Jamie", "auto")
	var main = await _park()
	main.flow.set_paused(true)
	await frames(1)
	ok(main.session_buttons.visible and main.session_buttons.get_node("SaveGame") != null and main.session_buttons.get_node("QuitToTitle") != null, "pause: Save, Load and Quit to title are in the pause menu")
	var r: Dictionary = main.save_manual()
	var mp: String = gs.slots.path_for("guest", "Jamie", "manual")
	var disk = SaveScript.new()
	disk.load_user(mp)
	ok(bool(r.get("ok")) and disk.meta.kind == "manual" and disk.meta.character == "Jamie" and disk.story.current == "p1_practice_run", "pause: Save writes the manual slot")
	main.flow.set_paused(false)
	main.quit_to_title()
	ok(main.left_to_title == "title" and not gs.has_character() and gs.open_on_title == "menu", "pause: Quit to title autosaves and leaves the character")
	main.queue_free()
	await frames(3)
	gs.open_on_title = ""

func _park_free_roam_load() -> void:
	var rec = SaveScript.new()
	rec.meta["character"] = "Zed"
	rec.player = {"mode": "free", "district": "", "zone": "SKATE YARD", "pos": [-30.0, 0.5, 6.0], "yaw": 1.2, "skating": false}
	rec.settings = {"painted_sprite": true}
	gs.slots.write("guest", "Zed", "auto", rec)
	gs.begin_load("Zed", "auto")
	var main = await _park()
	ok(main.load_result.get("resumed") == "free" and not main.story.active, "load: a free-roam save stays in free roam")
	var at: Vector3 = main.player.global_position
	ok(Vector2(at.x, at.z).distance_to(Vector2(-30.0, 6.0)) < 0.6 and not main.player.skating, "load: free roam restores the position and walking %s" % at)
	main.queue_free()
	await frames(3)
	gs.slots.erase("guest", "Zed")
	gs.slots.erase("guest", "Jamie")
