extends RefCounted

const EXTENSIONS := [".mp3", ".wav", ".ogg", ".flac", ".aac", ".m4a", ".opus", ".mid", ".midi", ".webm", ".mp4"]
const POLICY_KEYS := ["source", "world", "arcade", "changed_arrangement", "extra_singer", "repo_ban", "processing_ban", "assets_ban", "playback"]

var document := {}

func load_text(text: String) -> Dictionary:
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "reason": "not_object"}
	var problems := validate(parsed)
	if problems.size() > 0:
		return {"ok": false, "reason": "invalid", "problems": problems}
	document = parsed
	return {"ok": true}

func validate(doc: Dictionary) -> PackedStringArray:
	var problems: PackedStringArray = []
	if str(doc.get("contract", "")) != "au.song_catalog":
		problems.append("contract")
	if int(doc.get("contract_version", -1)) != 1:
		problems.append("version")
	var policy = doc.get("policy", null)
	if typeof(policy) != TYPE_DICTIONARY:
		problems.append("policy")
	else:
		for key in POLICY_KEYS:
			if not policy.has(key) or str(policy[key]).strip_edges().is_empty():
				problems.append("policy:" + key)
	var blob := JSON.stringify(doc)
	var lower := blob.to_lower()
	if "drive.google.com" in lower or "docs.google.com" in lower:
		problems.append("drive_link")
	if "ya29." in blob or "private_key" in lower or "aiza" in lower:
		problems.append("secret_pattern")
	for ext in EXTENSIONS:
		if ext in lower:
			problems.append("extension:" + ext)
	var songs = doc.get("songs", [])
	if typeof(songs) != TYPE_ARRAY or songs.is_empty():
		problems.append("songs")
	else:
		for song in songs:
			if typeof(song) != TYPE_DICTIONARY:
				problems.append("song_type")
				continue
			if song.get("enabled", false) == true:
				var media = song.get("media", null)
				if typeof(media) != TYPE_DICTIONARY or media.get("cleared", false) != true or str(media.get("delivery", "")) != "external":
					problems.append("enabled_without_cleared_external_media")
				elif typeof(media) == TYPE_DICTIONARY:
					for forbidden in ["path", "uri", "file", "drive_id", "local_path", "master"]:
						if media.has(forbidden):
							problems.append("media_locator")
	return problems

func get_song(id: String) -> Dictionary:
	for song in document.get("songs", []):
		if str(song.get("id", "")) == id:
			return (song as Dictionary).duplicate(true)
	return {}

func request_playback(id: String) -> Dictionary:
	var song := get_song(id)
	if song.is_empty():
		return {"ok": false, "played": false, "reason": "missing"}
	if song.get("enabled", false) != true:
		return {"ok": false, "played": false, "reason": "disabled"}
	return {"ok": false, "played": false, "reason": "loader_not_in_this_pass"}
