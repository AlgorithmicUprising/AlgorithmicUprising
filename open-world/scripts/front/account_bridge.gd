extends Node
## Front end (Nov 19 2026): a thin adapter to the Algorithmic Uprising player account, the same account the Punk
## Arcade uses. Nothing here invents a second account system.
##
## How the arcade does it (read from the repo and the live site, not changed): the arcade games under arcade/ have no
## accounts. Each game page runs inside the site's ZERO GAME THING 2000 console (algorithmicuprising.com/arcade/),
## and arcade/demo/embed-bridge.js posts {source: "punk-arcade", type: "game:save-score", ...} to the parent page,
## only when the parent origin is one of the arcade hosts below. The SITE owns the account: email sign-in link
## (/api/player/email-link), a session cookie on algorithmicuprising.com, scores at /api/arcade/scores, guest play.
##
## Project Zero runs on github.io inside algorithmicuprising.com/play/project-zero/, so it cannot read that cookie or
## call those APIs (cross-origin, no CORS). The same shape as the arcade is used instead: ask the parent page.
##   game -> parent  {source: "project-zero", type: "pz:hello", v: 1, want: ["account"]}
##   parent -> game  {source: "au-site", type: "pz:account", v: 1, player: {id, handle} | null, capabilities: [...]}
##   game -> parent  {source: "project-zero", type: "pz:save", v: 1, character, kind, save}   (only if the parent
##                   listed "pz-saves" in capabilities)
## The live site does not answer pz:hello yet (proposed change, FR for the site), so today every player is a guest
## and saves stay in this browser (user:// = IndexedDB). When the site answers, saves move under that account's key
## with no change on this side. Native and headless builds are always guest.

signal changed(state: String)

## Same allowlist as arcade/demo/embed-bridge.js (arcadeHosts). Keep them in step.
const HOSTS := ["https://algorithmicuprising.com", "https://www.algorithmicuprising.com", "https://algorithmic-uprising.free-grass-2381.chatgpt.site"]
const ACCOUNT_URL := "https://algorithmicuprising.com/account/?from=arcade"
const ASK_TIMEOUT_MS := 1500

var state := "guest"          # guest / asking / signed-in
var player := {}              # {id, handle} when signed in
var capabilities: Array = []
var host := ""
var _web := false
var _rev := -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_web = OS.has_feature("web")
	if _web:
		JavaScriptBridge.eval(_hello_js(), true)
		_poll()

func _process(_delta: float) -> void:
	if _web and Engine.get_process_frames() % 15 == 0:
		_poll()

func account_key() -> String:
	return "au-" + str(player.get("id", "")) if state == "signed-in" and str(player.get("id", "")) != "" else "guest"

func label() -> String:
	if state == "signed-in":
		var h := str(player.get("handle", ""))
		return h.to_upper() if h != "" else "SIGNED IN"
	return "GUEST"

func can_sync_saves() -> bool:
	return state == "signed-in" and capabilities.has("pz-saves")

## Opens the site's Player Account page (the arcade's own sign-in), in a new tab on the web build.
func open_sign_in() -> String:
	var url := (host if host != "" else "https://algorithmicuprising.com") + "/account/?from=arcade"
	if _web:
		JavaScriptBridge.eval("window.open(%s,'_blank','noopener');" % JSON.stringify(url), true)
	elif DisplayServer.get_name() != "headless":
		OS.shell_open(url)
	return url

## Mirrors a save to the site when it has said it stores them (capability "pz-saves"). Local save always happens first.
func offer_save(character: String, kind: String, data: Dictionary) -> bool:
	if not _web or not can_sync_saves():
		return false
	JavaScriptBridge.eval("window.PZ_ACCOUNT_SEND&&window.PZ_ACCOUNT_SEND(%s);" % JSON.stringify({"source": "project-zero", "type": "pz:save", "v": 1, "character": character, "kind": kind, "save": data}), true)
	return true

## Tests and the parent-less case: apply an account message the way the JS listener would.
func apply_message(msg: Dictionary) -> bool:
	if str(msg.get("source", "")) != "au-site" or str(msg.get("type", "")) != "pz:account" or int(msg.get("v", 0)) != 1:
		return false
	var p = msg.get("player", null)
	if typeof(p) == TYPE_DICTIONARY and str(p.get("id", "")) != "" and str(p.get("id", "")).length() <= 128:
		player = {"id": str(p.id), "handle": str(p.get("handle", "")).substr(0, 32)}
		state = "signed-in"
	else:
		player = {}
		state = "guest"
	capabilities = (msg.get("capabilities", []) as Array).slice(0, 8) if typeof(msg.get("capabilities", [])) == TYPE_ARRAY else []
	changed.emit(state)
	return true

func _poll() -> void:
	var raw = JavaScriptBridge.eval("JSON.stringify(window.PZ_ACCOUNT||null)", true)
	var d = JSON.parse_string(str(raw)) if raw != null else null
	if typeof(d) != TYPE_DICTIONARY or int(d.get("rev", 0)) == _rev:
		return
	_rev = int(d.get("rev", 0))
	host = str(d.get("host", ""))
	var before := state
	if str(d.get("state", "")) == "signed-in" and typeof(d.get("player", null)) == TYPE_DICTIONARY:
		player = d.player
		state = "signed-in"
	else:
		player = {}
		state = "asking" if str(d.get("state", "")) == "asking" else "guest"
	capabilities = d.get("caps", []) if typeof(d.get("caps", [])) == TYPE_ARRAY else []
	if before != state:
		changed.emit(state)

func _hello_js() -> String:
	return """
(function(){
  if (window.PZ_ACCOUNT) return;
  var hosts = %s;
  var origin = ''; try { origin = new URL(document.referrer).origin; } catch (e) {}
  var st = {state: 'guest', host: hosts.indexOf(origin) >= 0 ? origin : '', player: null, caps: [], rev: 1};
  window.PZ_ACCOUNT = st;
  window.PZ_ACCOUNT_SEND = function (msg) { if (st.host && window.parent !== window) window.parent.postMessage(msg, st.host); };
  if (window.parent === window || !st.host) return;
  st.state = 'asking'; st.rev++;
  window.addEventListener('message', function (e) {
    if (e.origin !== st.host || e.source !== window.parent) return;
    var d = e.data || {};
    if (d.source !== 'au-site' || d.type !== 'pz:account' || d.v !== 1) return;
    var p = d.player;
    if (p && typeof p.id === 'string' && p.id && p.id.length <= 128) {
      st.player = {id: p.id, handle: String(p.handle || '').slice(0, 32)}; st.state = 'signed-in';
    } else { st.player = null; st.state = 'guest'; }
    st.caps = Array.isArray(d.capabilities) ? d.capabilities.slice(0, 8).map(String) : [];
    st.rev++;
  });
  window.parent.postMessage({source: 'project-zero', type: 'pz:hello', v: 1, want: ['account']}, st.host);
  setTimeout(function () { if (st.state === 'asking') { st.state = 'guest'; st.rev++; } }, %d);
})();
""" % [JSON.stringify(HOSTS), ASK_TIMEOUT_MS]
