extends Node
## Arcade Phase 2 (LOCAL): plays an existing Punk Arcade game in an HTML overlay over the Godot canvas.
## Web: an <iframe> to the game's existing embed page on the same Pages origin (../games/<id>/demo/embed.html),
## with a BACK TO THE ARCADE button that returns to the room (Esc inside the game stays the game's own pause key). The game code is not touched; we only link to it.
## Desktop/editor: opens the live Pages URL in the system browser. Headless (tests): records the request only.
## Player input is held while the overlay is up and handed back when it closes.

const PAGES_BASE := "https://algorithmicuprising.github.io/AlgorithmicUprising/"

signal opened(game_id: String)
signal closed(game_id: String)

var state := "closed"   # closed / open
var game_id := ""
var last_path := ""
var last_title := ""
var opens := 0
var closes := 0
var player: Node
## Front end (Nov 19 2026): the start screen's Uprising Arcade console reuses this overlay with its own back label.
var back_label := "BACK TO THE ARCADE"
var _web := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_web = OS.has_feature("web")

func is_open() -> bool:
	return state == "open"

## path is relative to the Pages root, e.g. "games/grind-the-terms/demo/embed.html".
func open_game(id: String, title: String, path: String, who: Node) -> bool:
	if state == "open":
		return false
	state = "open"
	game_id = id
	last_path = path
	last_title = title
	opens += 1
	player = who
	if player != null:
		if "input_enabled" in player:
			player.input_enabled = false
		if "velocity" in player:
			player.velocity = Vector3.ZERO
	opened.emit(id)
	if _web:
		JavaScriptBridge.eval(_open_js(title, path), true)
	elif DisplayServer.get_name() != "headless":
		OS.shell_open(PAGES_BASE + path)
		close()
	return true

func close() -> void:
	if state != "open":
		return
	state = "closed"
	closes += 1
	if _web:
		JavaScriptBridge.eval("window.AU_ARCADE_CLOSE&&window.AU_ARCADE_CLOSE(true);", true)
	if player != null and "input_enabled" in player:
		player.input_enabled = true
	closed.emit(game_id)

func _process(_delta: float) -> void:
	if not _web or state != "open":
		return
	var flag = JavaScriptBridge.eval("(window.AU_ARCADE_OVERLAY&&window.AU_ARCADE_OVERLAY.open)?1:0", true)
	if int(flag) == 0:
		close()

func _open_js(title: String, path: String) -> String:
	var t := JSON.stringify(title)
	var p := JSON.stringify(path)
	var back := JSON.stringify("\u2715 " + back_label)
	return """
(function(){
  var title=%s, path=%s, back=%s;
  var old=document.getElementById('au-arcade-overlay'); if(old) old.remove();
  if(document.pointerLockElement) document.exitPointerLock();
  var base=new URL('../', window.location.href);
  var src=new URL(path, base).href;
  var o=document.createElement('div'); o.id='au-arcade-overlay';
  o.setAttribute('role','dialog'); o.setAttribute('aria-label',title);
  o.style.cssText='position:fixed;inset:0;z-index:2147483000;background:rgba(8,6,12,.94);display:flex;flex-direction:column;font:14px/1.2 monospace;color:#f7f1e8';
  var bar=document.createElement('div');
  bar.style.cssText='display:flex;align-items:center;gap:12px;padding:8px 12px;background:#121310;border-bottom:3px solid #dbff00';
  var h=document.createElement('strong'); h.textContent='\\u00d8 '+title; h.style.cssText='color:#dbff00;letter-spacing:.06em;flex:1;white-space:nowrap;overflow:hidden;text-overflow:ellipsis';
  var b=document.createElement('button'); b.type='button'; b.textContent=back;
  b.style.cssText='font:inherit;font-weight:bold;padding:8px 14px;background:#ff3d7f;color:#121310;border:0;border-radius:4px;cursor:pointer;min-height:40px';
  var f=document.createElement('iframe'); f.src=src; f.title=title;
  f.setAttribute('allow','autoplay; fullscreen; gamepad; clipboard-write');
  f.style.cssText='flex:1;width:100%%;border:0;background:#101017';
  bar.appendChild(h); bar.appendChild(b); o.appendChild(bar); o.appendChild(f);
  document.body.appendChild(o);
  window.AU_ARCADE_OVERLAY={open:true, src:src};
  function esc(e){ if(e.key==='Escape'){ e.preventDefault(); window.AU_ARCADE_CLOSE(); } }
  window.AU_ARCADE_CLOSE=function(fromGodot){
    var n=document.getElementById('au-arcade-overlay'); if(n) n.remove();
    document.removeEventListener('keydown', esc, true);
    window.AU_ARCADE_OVERLAY={open:false};
    var c=document.querySelector('canvas'); if(c){ c.focus(); }
  };
  b.addEventListener('click', function(){ window.AU_ARCADE_CLOSE(); });
  document.addEventListener('keydown', esc, true);
  f.addEventListener('load', function(){
    try { f.contentWindow.focus(); } catch(e) {}
  });
})();
""" % [t, p, back]
