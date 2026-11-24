extends Node
## The province's ambient score, synthesized in code.
##
## Like the combat voices, the score ships as no audio file: a twelve-second
## loop is built once from a slow drone and a pentatonic bell figure. The loop
## is deterministic, so two builds are byte-identical and the headless suite can
## inspect it without a sound card. The title screen and the run share this
## autoload, so the music survives a scene change instead of restarting.

const RATE := 22050
const LOOP_SECONDS := 12.0
## A minor pentatonic, one bell every three seconds.
const NOTES: Array[float] = [220.0, 261.63, 293.66, 329.63, 392.0]
const SILENT_DB := -80.0

## Whether the player wants music. The score is never required to play.
var enabled := true
## Percent of the authored level, 0..100. Shared with the interface volume.
var volume := 100
var playing := false
var stream_built := false
## How many streams this session has built, for tests and telemetry.
var builds := 0

var _stream: AudioStreamWAV
var _player: AudioStreamPlayer


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "Score"
	_player.bus = "Master"
	_player.volume_db = SILENT_DB
	add_child(_player)


## Reads the player's options. Called by the title screen and by the run after
## every settings change, rather than by the options model itself, so the model
## stays testable without a scene.
func refresh() -> void:
	if Options == null:
		return
	set_enabled(Options.get_bool("music"))
	set_volume(Options.get_int("volume"))


func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled:
		playing = false
		if _player != null:
			_player.stop()
		return
	_ensure_stream()
	if _player != null and _stream != null and DisplayServer.get_name() != "headless":
		_player.stream = _stream
		if not _player.playing:
			_player.play()
		playing = _player.playing


func is_enabled() -> bool:
	return enabled


## Applies the same 0..100 volume the combat voices use. Zero is silence.
func set_volume(percent: int) -> void:
	volume = clampi(percent, 0, 100)
	if _player == null:
		return
	_player.volume_db = SILENT_DB if volume <= 0 else linear_to_db(float(volume) / 100.0) - 10.0


func _ensure_stream() -> void:
	if stream_built:
		return
	# A headless run has no output device; building half a megabyte of samples
	# for a device that cannot play them only slows the suite down.
	if DisplayServer.get_name() == "headless":
		return
	_stream = build_loop()
	stream_built = true
	builds += 1


static func sample_count() -> int:
	return int(LOOP_SECONDS * float(RATE))


## Builds the loop. A pure function: no RNG, no engine time, so a test can
## compare two builds and the score cannot drift between sessions.
static func build_loop() -> AudioStreamWAV:
	var count := sample_count()
	var data := PackedByteArray()
	data.resize(count * 2)
	# Frequencies are chosen so the drone completes whole cycles in the loop:
	# 110 Hz × 12 s = 1320 cycles, 165 Hz × 12 s = 1980, 220 Hz × 12 s = 2640.
	var drone_root := 110.0
	var drone_fifth := 165.0
	var drone_third := 220.0
	for i in count:
		var t := float(i) / float(RATE)
		var value := sin(TAU * drone_root * t) * 0.055
		value += sin(TAU * drone_fifth * t + 0.35) * 0.032
		value += sin(TAU * drone_third * t + 0.90) * 0.018
		# One bell every three seconds; the last has decayed before the seam.
		var slot := int(t / 3.0)
		var local := t - float(slot) * 3.0
		var note: float = NOTES[slot % NOTES.size()]
		var envelope := exp(-2.6 * local)
		value += (sin(TAU * note * t) * 0.050 + sin(TAU * note * 2.0 * t) * 0.014) * envelope
		# One slow swell per loop, so the join is a breath rather than a cut.
		var swell := 0.78 + 0.22 * sin(TAU * t / LOOP_SECONDS)
		value = clampf(value * swell, -1.0, 1.0)
		data.encode_s16(i * 2, int(value * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = count
	return stream
