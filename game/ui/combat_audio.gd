class_name CombatAudio
extends Node
## Turns combat signals into sound.
##
## `Sfx` builds the waveforms; this node owns a small pool of players and decides
## which sound a signal deserves. Every trigger comes from the bus, so no combat
## code knows audio exists and the node can be removed without changing a rule.
## A headless run has no output device, so the suite can only assert that a
## stream was built and dispatched — never that it was heard.

const VOICES := 8

## Muted audio still counts dispatches, so a test can check routing.
var muted := false
## How many sounds were dispatched, for tests and telemetry.
var played := 0
var streams: Dictionary = {}

var _players: Array[AudioStreamPlayer] = []
var _cursor := 0


func _ready() -> void:
	for kind in Sfx.kinds():
		streams[kind] = Sfx.build(kind)
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		player.volume_db = -6.0
		add_child(player)
		_players.append(player)
	Bus.hit_landed.connect(_on_hit_landed)
	Bus.enemy_died.connect(_on_enemy_died)
	Bus.swing_made.connect(_on_swing)
	Bus.technique_cast.connect(_on_technique)
	Bus.guard_met.connect(_on_guard)


func set_muted(value: bool) -> void:
	muted = value
	if muted:
		for player in _players:
			player.stop()


func is_muted() -> bool:
	return muted


## Dispatches one sound. Returns false when muted or when the kind is unknown.
## Pitch varies deterministically so repeated blows do not sound identical.
func play(kind: String) -> bool:
	if not streams.has(kind):
		return false
	played += 1
	if muted or _players.is_empty():
		return false
	var player := _players[_cursor % _players.size()]
	_cursor += 1
	player.stream = streams[kind]
	player.pitch_scale = 1.0 + float((played % 5) - 2) * 0.03
	player.play()
	return true


func _on_hit_landed(target: Node, _amount: float, critical: bool, _tint: String) -> void:
	if target == Game.player:
		play("hurt")
	elif critical:
		play("crit")
	else:
		play("hit")


func _on_enemy_died(_at: Vector2, _ilvl: int) -> void:
	play("death")


func _on_swing(_heavy: bool) -> void:
	play("swing")


func _on_technique(_id: String, _kind: String) -> void:
	play("art")


func _on_guard(kind: String) -> void:
	play("parry" if kind == "parry" else "guard")
