extends Node
## Autoload "Sfx": a tiny procedural sound kit, so the project needs no audio
## files. Sounds are synthesised once at startup and played from a small pool.
## Volume comes from autoload/juice_settings.tres.

const RATE := 22050
const VOICES := 10

var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_played := {}


func _ready() -> void:
	#                     dur   f_start f_end  wobble noise decay
	_sounds["boing"] = _tone(0.28, 140.0, 260.0, 0.3, 0.0, 5.0)
	_sounds["push"] = _tone(0.22, 220.0, 70.0, 0.0, 0.35, 6.0)
	_sounds["wall"] = _tone(0.12, 120.0, 60.0, 0.0, 0.3, 7.0)
	_sounds["pop"] = _tone(0.09, 600.0, 1100.0, 0.0, 0.0, 4.0)
	_sounds["out"] = _tone(0.6, 400.0, 80.0, 0.15, 0.05, 2.5)
	_sounds["zap"] = _tone(0.4, 1600.0, 90.0, 0.0, 0.3, 3.5)
	_sounds["charge"] = _tone(0.9, 180.0, 700.0, 0.05, 0.0, 0.8)
	_sounds["bumper"] = _tone(0.22, 700.0, 1400.0, 0.0, 0.0, 5.0)
	_sounds["dash"] = _tone(0.18, 260.0, 900.0, 0.0, 0.6, 5.0)
	_sounds["deny"] = _tone(0.12, 150.0, 110.0, 0.0, 0.15, 6.0)
	_sounds["slash"] = _tone(0.09, 2200.0, 500.0, 0.0, 0.85, 4.0)
	_sounds["slash_hit"] = _tone(0.16, 190.0, 55.0, 0.0, 0.45, 6.0)
	_sounds["spit"] = _tone(0.1, 380.0, 820.0, 0.25, 0.15, 6.0)
	_sounds["shield"] = _tone(0.2, 600.0, 1500.0, 0.06, 0.1, 4.0)
	_sounds["shield_down"] = _tone(0.1, 900.0, 400.0, 0.0, 0.3, 6.0)
	_sounds["clang"] = _tone(0.3, 2600.0, 2400.0, 0.12, 0.15, 7.0)
	_sounds["reflect"] = _tone(0.35, 1700.0, 2300.0, 0.08, 0.05, 6.0)
	_sounds["warn"] = _tone(0.08, 880.0, 880.0, 0.0, 0.0, 3.0)
	_sounds["burst"] = _tone(0.18, 1300.0, 180.0, 0.0, 0.5, 6.0)
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


## Play a sound. Repeats of the same sound within `min_gap` seconds are dropped
## so a pile-up doesn't turn into a buzz.
func play(sound: String, pitch: float = 1.0, volume_db: float = 0.0, min_gap: float = 0.03) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(sound, -1.0)) < min_gap:
		return
	_last_played[sound] = now
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _sounds[sound]
	p.pitch_scale = clampf(pitch, 0.3, 3.0)
	p.volume_db = Juice.settings.sfx_volume_db + volume_db
	p.play()


func _tone(dur: float, f0: float, f1: float, wobble: float, noise: float, decay: float) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / n
		var f := lerpf(f0, f1, t) * (1.0 + wobble * sin(t * dur * TAU * 18.0) * (1.0 - t))
		phase += TAU * f / RATE
		var env := exp(-decay * t) * minf(t * 60.0, 1.0)  # tiny attack avoids clicks
		var s := sin(phase) * (1.0 - noise) + randf_range(-1.0, 1.0) * noise
		bytes.encode_s16(i * 2, int(clampf(s * env, -1.0, 1.0) * 20000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w
