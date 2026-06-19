class_name AudioManager
extends Node

## Loads the synthesised SFX/BGM and plays them in response to gameplay signals. A small
## pool of AudioStreamPlayers lets several effects overlap. BGM loops by replaying on the
## `finished` signal. Safe in headless mode (the dummy audio driver makes play() a no-op).

const SFX := ["hit", "block", "whoosh", "jump", "ko", "fire", "rising", "spin", "super"]
const POOL_SIZE := 8

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _bgm: AudioStreamPlayer

func _ready() -> void:
	for name in SFX:
		_streams[name] = load("res://assets/audio/%s.wav" % name)
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_bgm = AudioStreamPlayer.new()
	_bgm.stream = load("res://assets/audio/bgm.wav")
	_bgm.volume_db = -10.0
	_bgm.finished.connect(func(): _bgm.play())
	add_child(_bgm)

func play(name: String, volume_db: float = 0.0) -> void:
	var stream = _streams.get(name)
	if stream == null:
		return
	var p := _free_player()
	p.stream = stream
	p.volume_db = volume_db
	p.play()

func start_bgm() -> void:
	_bgm.play()

func _free_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	return _players[0]

# --- wiring ----------------------------------------------------------------

func wire_fighter(f: Fighter) -> void:
	f.move_started.connect(func(m): play(m.sfx if m.sfx != "" else "whoosh", -4.0))
	f.contact.connect(func(blocked, _m): play("block" if blocked else "hit"))
	f.jumped.connect(func(): play("jump", -7.0))

func wire_arena(arena: Arena) -> void:
	arena.ko.connect(func(_side): play("ko"))
