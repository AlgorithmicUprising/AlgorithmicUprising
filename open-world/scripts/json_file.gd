extends RefCounted

static func read(path: String):
	if FileAccess.file_exists(path):
		var text := FileAccess.get_file_as_string(path)
		if text.strip_edges() != "":
			return JSON.parse_string(text)
	if ResourceLoader.exists(path):
		var resource = load(path)
		if resource is JSON:
			return resource.data
	return null
