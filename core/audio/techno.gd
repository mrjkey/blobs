class_name Techno
extends Node
## A 4-bar techno loop synthesised in code (no audio files): four-on-the-floor
## kick, claps, hats, a rolling bass line and a low pad. It renders on a worker
## thread at startup, then loops. Also the beat clock: anything that pulses to
## the music finds this node in group "music" and calls beat() / kick_env().

const RATE := 22050
const BARS := 4
const ROOTS := [55.0, 55.0, 43.65, 49.0]  # bass note per bar: A1 A1 F1 G1

@export var bpm := 128.0 # read when the scene starts
@export var volume_db := -9.0:
	set(v):
		volume_db = v
		if is_node_ready():
			_player.volume_db = v

var beat_len := 0.5
var loop_len := 8.0

var _thread: Thread
var _start_usec := 0

@onready var _player: AudioStreamPlayer = $Player


func _enter_tree() -> void:
	add_to_group("music")


func _ready() -> void:
	beat_len = 60.0 / bpm
	loop_len = beat_len * 4.0 * BARS
	_start_usec = Time.get_ticks_usec()
	_player.volume_db = volume_db
	_thread = Thread.new()
	_thread.start(_render)


func _process(_delta: float) -> void:
	if _thread != null and not _thread.is_alive():
		var bytes: PackedByteArray = _thread.wait_to_finish()
		_thread = null
		var w := AudioStreamWAV.new()
		w.format = AudioStreamWAV.FORMAT_16_BITS
		w.mix_rate = RATE
		w.stereo = false
		w.data = bytes
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = bytes.size() / 2
		_player.stream = w
		# Join in at the right spot so the beat clock and the audio agree.
		_player.play(fmod(_elapsed(), loop_len))


func _exit_tree() -> void:
	if _thread != null:
		_thread.wait_to_finish()


func _elapsed() -> float:
	return (Time.get_ticks_usec() - _start_usec) / 1000000.0


## Beats since the scene started (keeps counting across loops).
func beat() -> float:
	return (_elapsed() - AudioServer.get_output_latency()) / beat_len


## 1.0 right on each kick, decaying to ~0 before the next one.
func kick_env() -> float:
	var b := beat()
	return exp(-(b - floorf(b)) * 5.0) if b >= 0.0 else 0.0


# --- Synthesis (runs on the worker thread) -----------------------------------

func _render() -> PackedByteArray:
	var spb := beat_len * RATE  # samples per beat
	var total := int(round(spb * 4.0 * BARS))
	var mix := PackedFloat32Array()
	mix.resize(total)

	var kick := _kick()
	var hat := _noise_hit(0.025, 0.7)
	var open_hat := _noise_hit(0.11, 0.6)
	var clap := _clap()
	for b in 4 * BARS:
		var s0 := int(b * spb)
		_add(mix, kick, s0, 1.0)
		_add(mix, open_hat, int((b + 0.5) * spb), 0.22)
		_add(mix, hat, int((b + 0.25) * spb), 0.07)
		_add(mix, hat, int((b + 0.75) * spb), 0.1)
		if b % 2 == 1:
			_add(mix, clap, s0, 0.5)

	# Rolling bass on the three 16ths between kicks, plus a slow pad.
	var bass_phase := 0.0
	var bass_lp := 0.0
	var pad_phase := [0.0, 0.0, 0.0, 0.0]
	var pad_lp := 0.0
	var pad_mult := [2.0, 2.01, 3.0, 4.0]  # octave + slightly detuned octave, fifth, two octaves
	for i in total:
		var beat_pos := i / spb
		var bar := int(beat_pos / 4.0) % BARS
		var root: float = ROOTS[bar]
		var sixteenth := beat_pos * 4.0
		var step := int(sixteenth) % 4
		var step_t := (sixteenth - floorf(sixteenth)) * beat_len * 0.25

		var bass_in := 0.0
		var env := 0.0
		if step != 0:
			bass_phase = fmod(bass_phase + root / RATE, 1.0)
			env = exp(-step_t * 14.0)
			bass_in = bass_phase * 2.0 - 1.0
		bass_lp += (bass_in - bass_lp) * (0.04 + 0.3 * env)
		var bass := bass_lp * (0.25 + 0.75 * env)

		var pad := 0.0
		for k in 4:
			pad_phase[k] = fmod(pad_phase[k] + root * pad_mult[k] / RATE, 1.0)
			pad += pad_phase[k] * 2.0 - 1.0
		var sweep := 0.02 + 0.03 * (0.5 + 0.5 * sin(beat_pos * PI / 8.0))
		pad_lp += (pad - pad_lp) * sweep

		mix[i] += bass * 0.55 + pad_lp * 0.06

	var bytes := PackedByteArray()
	bytes.resize(total * 2)
	for i in total:
		var x := mix[i] * 0.8
		x = x / (1.0 + absf(x))  # soft clip
		bytes.encode_s16(i * 2, int(x * 30000.0))
	return bytes


func _add(mix: PackedFloat32Array, sample: PackedFloat32Array, at: int, gain: float) -> void:
	var n := mini(sample.size(), mix.size() - at)
	for j in n:
		mix[at + j] += sample[j] * gain


func _kick() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var n := int(RATE * 0.35)
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 45.0 + 110.0 * exp(-t * 35.0)  # pitch drop = the "thump"
		phase += TAU * f / RATE
		var click := exp(-t * 400.0) * 0.4
		out[i] = (sin(phase) * exp(-t * 9.0) + click) * 1.1
	return out


func _noise_hit(length: float, brightness: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var n := int(RATE * length * 3.0)
	out.resize(n)
	var prev := 0.0
	for i in n:
		var t := float(i) / RATE
		var white := randf_range(-1.0, 1.0)
		var hp := white - prev * brightness  # crude high-pass = sizzle
		prev = white
		out[i] = hp * exp(-t / length * 2.5)
	return out


func _clap() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var n := int(RATE * 0.25)
	out.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		# Three quick bursts then a tail, like hands slightly out of sync.
		var env := 0.0
		for d: float in [0.0, 0.011, 0.022]:
			if t >= d:
				env = maxf(env, exp(-(t - d) * 90.0))
		env = maxf(env, exp(-t * 18.0) * 0.5)
		var white := randf_range(-1.0, 1.0)
		lp += (white - lp) * 0.5
		out[i] = (white - lp) * env
	return out
