extends Node
## Front end (Nov 19 2026): plays the Project Zero intro video between New Game and P.1.
##
## Web: the video is NOT in the .pck. It is a 720p MP4 next to the page (or any URL in data/intro_video.json) shown in
## an HTML <video> overlay over the Godot canvas, the same way arcade_overlay.gd shows arcade games. Godot only plays
## Theora (.ogv), and a 90 s 1080p clip in the pack would eat most of the pack headroom.
## Native: an optional .ogv (native_ogv paths) in a VideoStreamPlayer; without one the intro is skipped.
## Headless (tests): skipped at once.
##
## Skip: hold any key, mouse button, touch or pad button for skip.hold_s (1 s). Once the intro has been watched to the
## end on this device, later New Games skip on a single press (skip.hold_s_after_seen). If no source loads, a short
## "intro in production" card shows instead (missing_card_s), skippable the same way.
## finished(reason) reasons: ended, skipped, missing, unavailable, url_skip.

signal finished(reason: String)

const CONFIG := "res://data/intro_video.json"

var config := {}
var state := "idle"           # idle / playing / done
var reason := ""
var hold_s := 1.0
var sources: Array = []
var _web := false
var _video: VideoStreamPlayer
var _layer: CanvasLayer
var _held := 0.0
var _hint: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_web = OS.has_feature("web")
	var d = JSON.parse_string(FileAccess.get_file_as_string(CONFIG)) if FileAccess.file_exists(CONFIG) else null
	config = d if typeof(d) == TYPE_DICTIONARY else {}

## seen: the player has watched it to the end before on this device (single-press skip).
func play(seen := false) -> void:
	if state == "playing":
		return
	state = "playing"
	reason = ""
	var skip: Dictionary = config.get("skip", {})
	hold_s = float(skip.get("hold_s_after_seen", 0.0)) if seen else float(skip.get("hold_s", 1.0))
	sources = (config.get("web", {}).get("sources", []) as Array).duplicate()
	if _web:
		var q := str(JavaScriptBridge.eval("new URLSearchParams(window.location.search).get('intro')||''", true))
		if q == "skip" or q == "0":
			_finish("url_skip")
			return
		if q != "":
			sources = [q]
		JavaScriptBridge.eval(_overlay_js(), true)
		return
	if DisplayServer.get_name() == "headless":
		_finish("unavailable")
		return
	for p in config.get("native_ogv", []):
		if ResourceLoader.exists(str(p)) or FileAccess.file_exists(str(p)):
			_play_native(str(p))
			return
	_finish("unavailable")

func skip() -> void:
	if state != "playing":
		return
	if _web:
		JavaScriptBridge.eval("window.PZ_INTRO_SKIP&&window.PZ_INTRO_SKIP();", true)
	else:
		_finish("skipped")

func _process(delta: float) -> void:
	if state != "playing":
		return
	if _web:
		var r := str(JavaScriptBridge.eval("(window.PZ_INTRO&&window.PZ_INTRO.state==='done')?window.PZ_INTRO.reason:''", true))
		if r != "":
			_finish(r)
		return
	if _video == null:
		return
	var holding := Input.is_anything_pressed()
	_held = _held + delta if holding else maxf(0.0, _held - delta * 2.0)
	if _hint != null:
		_hint.text = ("HOLD TO SKIP  " + "|".repeat(int(clampf(_held / maxf(hold_s, 0.01), 0.0, 1.0) * 10.0))) if hold_s > 0.0 else "PRESS ANY KEY TO SKIP"
	if holding and _held >= hold_s:
		_finish("skipped")
	elif not _video.is_playing():
		_finish("ended")

func _play_native(path: String) -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 120
	add_child(_layer)
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(bg)
	_video = VideoStreamPlayer.new()
	_video.set_anchors_preset(Control.PRESET_FULL_RECT)
	_video.expand = true
	var stream := VideoStreamTheora.new()
	stream.file = path
	_video.stream = stream
	_layer.add_child(_video)
	_hint = Label.new()
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.offset_left = -360
	_hint.offset_top = -48
	_hint.add_theme_color_override("font_color", Color("c6ff3d"))
	_layer.add_child(_hint)
	_video.play()

func _finish(r: String) -> void:
	if state == "done":
		return
	state = "done"
	reason = r
	if _layer != null:
		_layer.queue_free()
		_layer = null
		_video = null
	finished.emit(r)

func _overlay_js() -> String:
	var cfg := {
		"sources": sources,
		"hold_ms": int(hold_s * 1000.0),
		"card_ms": int(float(config.get("missing_card_s", 4.0)) * 1000.0),
	}
	return """
(function(cfg){
  var old = document.getElementById('pz-intro'); if (old) old.remove();
  if (document.pointerLockElement) document.exitPointerLock();
  var st = {state: 'loading', reason: '', src: '', t: 0, dur: 0, muted: false, hold: 0, tried: []};
  window.PZ_INTRO = st;
  var o = document.createElement('div'); o.id = 'pz-intro';
  o.setAttribute('role', 'dialog'); o.setAttribute('aria-label', 'Project Zero intro video');
  o.style.cssText = 'position:fixed;inset:0;z-index:2147483000;background:#000;display:flex;align-items:center;justify-content:center;font:14px/1.3 monospace;color:#efeadb;user-select:none;touch-action:none';
  var v = document.createElement('video'); v.setAttribute('playsinline', ''); v.playsInline = true; v.preload = 'auto';
  v.style.cssText = 'width:100%%;height:100%%;object-fit:contain;background:#000';
  var card = document.createElement('div');
  card.style.cssText = 'display:none;flex-direction:column;align-items:center;gap:14px;text-align:center;padding:24px';
  card.innerHTML = '<div style="color:#c6ff3d;font:900 34px/1 Impact,Arial Black,sans-serif;letter-spacing:.04em">PROJECT ZERO</div><div style="font-size:15px;letter-spacing:.12em">INTRO VIDEO IN PRODUCTION</div><div style="color:#aaa592;font-size:12px">Glitchport. Heat dome day 9. A kid on a roof. A camera that watches back.</div>';
  var hint = document.createElement('div');
  hint.style.cssText = 'position:absolute;right:18px;bottom:16px;display:flex;align-items:center;gap:10px;padding:6px 10px;background:rgba(13,13,11,.72);border:1px solid #3a3a31;color:#efeadb;font-size:12px;letter-spacing:.08em';
  var ring = document.createElement('span');
  ring.style.cssText = 'width:18px;height:18px;border-radius:50%%;background:conic-gradient(#c6ff3d 0deg,#3a3a31 0deg)';
  var label = document.createElement('span');
  label.textContent = cfg.hold_ms > 0 ? 'HOLD ANY KEY TO SKIP' : 'PRESS ANY KEY TO SKIP';
  hint.appendChild(ring); hint.appendChild(label);
  var sound = document.createElement('button'); sound.type = 'button'; sound.textContent = '\\u{1F507} CLICK FOR SOUND';
  sound.style.cssText = 'display:none;position:absolute;left:18px;bottom:16px;font:inherit;font-size:12px;padding:6px 10px;background:#c6ff3d;color:#0d0d0b;border:0;cursor:pointer';
  o.appendChild(v); o.appendChild(card); o.appendChild(hint); o.appendChild(sound);
  document.body.appendChild(o);
  var i = 0, held = 0, holding = 0, last = performance.now(), raf = 0, cardTimer = 0;
  function next() {
    if (i >= cfg.sources.length) { missing(); return; }
    var s = cfg.sources[i++]; st.src = s; st.tried.push(s);
    try { v.src = new URL(s, window.location.href).href; } catch (e) { next(); return; }
    var p = v.play();
    if (p && p.catch) p.catch(function (err) {
      if (err && err.name === 'NotAllowedError') { v.muted = true; st.muted = true; sound.style.display = 'block'; v.play().catch(function () {}); }
    });
  }
  function missing() { st.state = 'card'; v.style.display = 'none'; card.style.display = 'flex'; cardTimer = setTimeout(function () { done('missing'); }, cfg.card_ms); }
  function done(r) {
    if (st.state === 'done') return;
    st.state = 'done'; st.reason = r;
    clearTimeout(cardTimer); cancelAnimationFrame(raf);
    window.removeEventListener('keydown', kd, true); window.removeEventListener('keyup', ku, true);
    try { v.pause(); v.removeAttribute('src'); v.load(); } catch (e) {}
    o.remove();
    var c = document.querySelector('canvas'); if (c) c.focus();
  }
  window.PZ_INTRO_SKIP = function () { done('skipped'); };
  v.addEventListener('error', function () { if (st.state !== 'done' && st.state !== 'card') next(); });
  v.addEventListener('ended', function () { done('ended'); });
  v.addEventListener('playing', function () { if (st.state === 'loading') st.state = 'playing'; });
  v.addEventListener('timeupdate', function () { st.t = v.currentTime; st.dur = v.duration || 0; });
  function press() { if (cfg.hold_ms <= 0) { done('skipped'); return; } holding++; }
  function release() { holding = Math.max(0, holding - 1); }
  var downKeys = {};
  function kd(e) { e.preventDefault(); e.stopImmediatePropagation(); if (e.repeat || downKeys[e.code]) return; downKeys[e.code] = 1; press(); }
  function ku(e) { e.preventDefault(); e.stopImmediatePropagation(); if (downKeys[e.code]) { delete downKeys[e.code]; release(); } }
  window.addEventListener('keydown', kd, true); window.addEventListener('keyup', ku, true);
  o.addEventListener('pointerdown', function (e) { if (e.target === sound) return; e.preventDefault(); press(); });
  o.addEventListener('pointerup', release); o.addEventListener('pointercancel', release); o.addEventListener('pointerleave', function () { holding = 0; });
  sound.addEventListener('pointerdown', function (e) { e.stopPropagation(); });
  sound.addEventListener('click', function (e) { e.stopPropagation(); v.muted = false; st.muted = false; sound.style.display = 'none'; v.play().catch(function () {}); });
  var padWas = false;
  function tick(now) {
    var dt = Math.min(0.1, (now - last) / 1000); last = now;
    var pad = false;
    try { var pads = navigator.getGamepads ? navigator.getGamepads() : []; for (var k = 0; k < pads.length; k++) { var g = pads[k]; if (!g) continue; for (var b = 0; b < g.buttons.length; b++) if (g.buttons[b].pressed) pad = true; } } catch (e) {}
    if (pad && !padWas) press(); if (!pad && padWas) release(); padWas = pad;
    if (st.state === 'done') return;
    held = holding > 0 ? held + dt : Math.max(0, held - dt * 2);
    st.hold = held;
    var f = cfg.hold_ms > 0 ? Math.min(1, held * 1000 / cfg.hold_ms) : 0;
    ring.style.background = 'conic-gradient(#c6ff3d ' + (f * 360) + 'deg,#3a3a31 0deg)';
    if (cfg.hold_ms > 0 && held * 1000 >= cfg.hold_ms) { done('skipped'); return; }
    raf = requestAnimationFrame(tick);
  }
  raf = requestAnimationFrame(tick);
  next();
})(%s);
""" % JSON.stringify(cfg)
