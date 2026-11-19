extends RefCounted
## Front end (Nov 19 2026): the protagonist's display name is data, not code. "Fony" is a placeholder default; the
## player picks a character name on New Game and that name is what the HUD, the story lines and (later) the phone
## thread show. Story data writes {name} (or {NAME} for capitals) where the protagonist's name goes, and the speaker
## tag FONY (and TEXT FONY / TYPING FONY in P.1 v2) is the protagonist slot, shown as the chosen name.
##
## Not swappable (flagged for the user): anything baked into rendered media or recorded audio. Today that is the intro
## video (shot list v2: the CLEARANCE push alert "DEPENDENT: SPROCK, F.", the phone lock screen and any caption that
## names Fony) and any future voiced line that says his name. Those keep "Fony"/"Sprock" unless re-rendered.

const DEFAULT_NAME := "Fony"
const SLOT_SPEAKERS := ["FONY", "TEXT FONY", "TYPING FONY"]

static func current(tree: SceneTree) -> String:
	if tree == null:
		return DEFAULT_NAME
	var s = tree.root.get_node_or_null("GameSession")
	if s != null and s.has_method("player_name"):
		return s.player_name()
	return DEFAULT_NAME

## Speaker tag shown on screen for a story speaker key.
static func speaker(key: String, name: String) -> String:
	if not SLOT_SPEAKERS.has(key):
		return key
	return key.replace("FONY", name.to_upper())

static func text(line: String, name: String) -> String:
	return line.replace("{name}", name).replace("{NAME}", name.to_upper())

## [[speaker, text, ...], ...] -> the same with the protagonist slot filled in.
static func lines(rows: Array, name: String) -> Array:
	var out: Array = []
	for r in rows:
		if typeof(r) == TYPE_ARRAY and r.size() >= 2:
			var copy: Array = r.duplicate()
			copy[0] = speaker(str(r[0]), name)
			copy[1] = text(str(r[1]), name)
			out.append(copy)
	return out
