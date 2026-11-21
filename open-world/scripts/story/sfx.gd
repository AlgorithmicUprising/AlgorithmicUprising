extends Node
## M1 (Nov 19 2026): story SFX, synthesized at start-up into AudioStreamWAV buffers. No audio files ship (the media scan
## in tests forbids them), no voice, no music. One player per cue on the single Master bus.

const RATE := 22050
## P.1 v2 / Act I prologue (Nov 19 2026): the phone (text_in, text_out, typing), SERA's three-tone emergency chime
## (alert), the welfare drone's soft chime (drone_chime), its hum and the net hatch, and a crowd-free stinger (sting).
const CUES := ["crt", "fony", "objective", "bank", "bail", "marquee", "prompt", "card", "text_in", "text_out", "typing", "alert", "drone_chime", "drone_hum", "net", "sting", "pickup", "breaker"]

var players := {}
var played: Array = []              # tests / probes: cue names in order (last 64)
var muted := false

func _ready() -> void:
	for cue in CUES:
		var p := AudioStreamPlayer.new()
		p.name = "Sfx_" + cue
		p.stream = make(cue)
		p.volume_db = -8.0
		add_child(p)
		players[cue] = p

func play(cue: String, pitch := 1.0) -> void:
	played.append(cue)
	if played.size() > 64:
		played.pop_front()
	if muted or not players.has(cue):
		return
	var p: AudioStreamPlayer = players[cue]
	p.pitch_scale = clampf(pitch, 0.5, 2.0)
	p.play()

static func make(cue: String) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(cue)
	var samples := PackedFloat32Array()
	match cue:
		"crt":
			# a static crackle with a mains hum under it: the voice from the dead CRT
			for i in int(RATE * 0.32):
				var t := float(i) / RATE
				var env := minf(1.0, t / 0.01) * exp(-t * 6.0)
				var crackle := (rng.randf() * 2.0 - 1.0) * (0.55 if rng.randf() < 0.3 else 0.18)
				samples.append(env * (crackle + 0.25 * sin(TAU * 60.0 * t) + 0.12 * sin(TAU * 15734.0 * t)))
		"fony":
			_tone(samples, 520.0, 0.05, 0.25)
		"objective":
			_tone(samples, 660.0, 0.09, 0.4)
			_tone(samples, 990.0, 0.16, 0.4)
		"bank":
			_tone(samples, 880.0, 0.07, 0.35)
		"bail":
			for i in int(RATE * 0.22):
				var t := float(i) / RATE
				samples.append(exp(-t * 18.0) * (0.6 * sin(TAU * 70.0 * t) + 0.3 * (rng.randf() * 2.0 - 1.0)))
		"marquee":
			# fluorescent tube sputtering on: buzz in bursts
			for i in int(RATE * 0.6):
				var t := float(i) / RATE
				var on := 1.0 if sin(TAU * 7.0 * t + 3.0 * sin(TAU * 2.0 * t)) > 0.2 else 0.0
				samples.append(on * 0.3 * signf(sin(TAU * 120.0 * t)) * exp(-t * 1.5))
		"prompt":
			_tone(samples, 1200.0, 0.03, 0.2)
		"card":
			for i in int(RATE * 0.25):
				var t := float(i) / RATE
				samples.append(exp(-t * 14.0) * 0.35 * (rng.randf() * 2.0 - 1.0))
		"text_in":
			# two short square-wave blips
			_square(samples, 1320.0, 0.045, 0.22)
			_silence(samples, 0.04)
			_square(samples, 1760.0, 0.05, 0.22)
		"text_out":
			_tone(samples, 990.0, 0.05, 0.16)
		"typing":
			for k in 3:
				_square(samples, 2400.0, 0.008, 0.06)
				_silence(samples, 0.07)
		"alert":
			# SERA's emergency chime: three harsh tones, every screen at once (louder than the morning chime)
			for hz in [880.0, 698.0, 1046.0]:
				_square(samples, hz, 0.22, 0.42)
				_silence(samples, 0.05)
		"drone_chime":
			# soft and friendly: a rising two-note sine
			_tone(samples, 784.0, 0.12, 0.18)
			_tone(samples, 1175.0, 0.22, 0.18)
		"drone_hum":
			for i in int(RATE * 0.9):
				var t := float(i) / RATE
				var env := minf(1.0, t / 0.15) * minf(1.0, (0.9 - t) / 0.2)
				samples.append(env * 0.16 * (sin(TAU * 196.0 * t) + 0.5 * sin(TAU * 392.0 * t + 0.4 * sin(TAU * 7.0 * t))))
		"net":
			for i in int(RATE * 0.35):
				var t := float(i) / RATE
				samples.append(exp(-t * 7.0) * 0.3 * (rng.randf() * 2.0 - 1.0) * (0.5 + 0.5 * sin(TAU * 40.0 * t)))
		"sting":
			_square(samples, 220.0, 0.12, 0.3)
			_square(samples, 207.6, 0.4, 0.3)
		"pickup":
			# P.3: a fuse in the hand, a small bright tick
			_tone(samples, 1568.0, 0.06, 0.16)
			_tone(samples, 2093.0, 0.08, 0.12)
		"breaker":
			# P.3: the breaker's clunk, then the roof starting to hum
			for i in int(RATE * 0.25):
				var t := float(i) / RATE
				samples.append(exp(-t * 18.0) * 0.5 * (rng.randf() * 2.0 - 1.0))
			for i in int(RATE * 0.9):
				var t := float(i) / RATE
				samples.append(minf(1.0, t / 0.5) * 0.14 * sin(TAU * 120.0 * t))
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav

static func _tone(samples: PackedFloat32Array, hz: float, length: float, amp: float) -> void:
	for i in int(RATE * length):
		var t := float(i) / RATE
		var env := minf(1.0, t / 0.004) * minf(1.0, (length - t) / 0.02)
		samples.append(env * amp * (signf(sin(TAU * hz * t)) * 0.4 + sin(TAU * hz * t) * 0.6))

static func _square(samples: PackedFloat32Array, hz: float, length: float, amp: float) -> void:
	for i in int(RATE * length):
		var t := float(i) / RATE
		var env := minf(1.0, t / 0.003) * minf(1.0, (length - t) / 0.01)
		samples.append(env * amp * signf(sin(TAU * hz * t)))

static func _silence(samples: PackedFloat32Array, length: float) -> void:
	for i in int(RATE * length):
		samples.append(0.0)
