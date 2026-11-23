class_name Sfx
extends RefCounted
## Combat sound, synthesized in code.
##
## The project ships no audio assets — the same choice as its code-drawn art.
## Each sound is a short 16-bit mono stream built from an envelope over a tiny
## deterministic noise generator and/or one or two sine partials. `build()` is a
## pure function of the kind, so two runs produce byte-identical streams and the
## headless suite can check a waveform without a sound card.

const RATE := 22050
const MAX_AMPLITUDE := 32767.0

## duration in seconds, wave shape, frequency sweep, exponential decay, gain.
const SPECS := {
	"swing": {"duration": 0.14, "wave": "noise", "freq": 900.0, "end_freq": 300.0, "decay": 20.0, "gain": 0.30},
	"hit": {"duration": 0.18, "wave": "mixed", "freq": 170.0, "end_freq": 70.0, "decay": 13.0, "gain": 0.55},
	"crit": {"duration": 0.24, "wave": "mixed", "freq": 340.0, "end_freq": 120.0, "decay": 9.0, "gain": 0.60},
	"guard": {"duration": 0.16, "wave": "tone", "freq": 240.0, "end_freq": 240.0, "decay": 16.0, "gain": 0.38},
	"parry": {"duration": 0.32, "wave": "tone", "freq": 780.0, "end_freq": 780.0, "decay": 7.0, "gain": 0.42},
	"hurt": {"duration": 0.30, "wave": "sweep", "freq": 200.0, "end_freq": 65.0, "decay": 8.0, "gain": 0.50},
	"death": {"duration": 0.70, "wave": "sweep", "freq": 220.0, "end_freq": 45.0, "decay": 4.0, "gain": 0.48},
	"art": {"duration": 0.40, "wave": "sweep", "freq": 420.0, "end_freq": 900.0, "decay": 6.0, "gain": 0.30},
}


static func kinds() -> Array[String]:
	var out: Array[String] = []
	for key in SPECS.keys():
		out.append(String(key))
	return out


static func spec(kind: String) -> Dictionary:
	var found: Variant = SPECS.get(kind, {})
	return found if typeof(found) == TYPE_DICTIONARY else {}


static func duration(kind: String) -> float:
	return float(spec(kind).get("duration", 0.0))


static func sample_count(kind: String) -> int:
	var seconds := duration(kind)
	if seconds <= 0.0:
		return 0
	return maxi(1, int(seconds * RATE))


## Builds the stream for `kind`. An unknown kind yields the smallest silent
## stream rather than an error, so a bad audio call can never crash a fight.
static func build(kind: String) -> AudioStreamWAV:
	var data := PackedByteArray()
	var spec_data := spec(kind)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	if spec_data.is_empty():
		stream.data = data
		return stream

	var count := sample_count(kind)
	var seconds := maxf(0.001, duration(kind))
	var wave := String(spec_data.get("wave", "noise"))
	var start_freq := float(spec_data.get("freq", 220.0))
	var end_freq := float(spec_data.get("end_freq", start_freq))
	var decay := float(spec_data.get("decay", 10.0))
	var gain := clampf(float(spec_data.get("gain", 0.4)), 0.0, 1.0)
	data.resize(count * 2)
	# A tiny deterministic noise source, so the same kind always sounds the same
	# and tests can compare two builds byte for byte.
	var state := absi(hash(kind)) | 1
	var phase := 0.0
	for i in count:
		var t := float(i) / float(RATE)
		var progress := clampf(t / seconds, 0.0, 1.0)
		var envelope := exp(-decay * t)
		state = (state * 1103515245 + 12345) & 0x7fffffff
		var noise := clampf(float(state) / 1073741823.0 - 1.0, -1.0, 1.0)
		var freq := lerpf(start_freq, end_freq, progress)
		phase += TAU * freq / float(RATE)
		var value := 0.0
		match wave:
			"noise":
				value = noise
			"sweep":
				value = sin(phase)
			"tone":
				value = sin(phase) + 0.35 * sin(phase * 2.0)
			_:
				value = sin(phase) * 0.72 + noise * 0.5
		value = clampf(value * gain * envelope, -1.0, 1.0)
		data.encode_s16(i * 2, int(value * MAX_AMPLITUDE))
	stream.data = data
	return stream
