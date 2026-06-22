class_name AudioManager
extends Node

## Loads the synthesised SFX/BGM and plays them in response to gameplay signals. A small
## pool of AudioStreamPlayers lets several effects overlap. BGM loops by replaying on the
## `finished` signal. Safe in headless mode (the dummy audio driver makes play() a no-op).

const SFX := ["hit", "block", "whoosh", "jump", "ko", "fire", "rising", "spin", "super", "hit_heavy", "counter"]
const POOL_SIZE := 8

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _bgm: AudioStreamPlayer
var _initialized: bool = false

func _ready() -> void:
	_ensure_initialized()

func _ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true
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
	_ensure_initialized()
	var stream = _streams.get(name)
	if stream == null:
		return
	var p := _free_player()
	p.stream = stream
	p.volume_db = volume_db
	if p.is_inside_tree():
		p.play()

func start_bgm() -> void:
	_ensure_initialized()
	if _bgm.is_inside_tree():
		_bgm.play()

func _free_player() -> AudioStreamPlayer:
	_ensure_initialized()
	for p in _players:
		if not p.playing:
			return p
	return _players[0]

# --- wiring ----------------------------------------------------------------

func wire_fighter(f: Fighter) -> void:
	f.move_started.connect(func(m): play(m.sfx if m.sfx != "" else "whoosh", -4.0))
	f.contact.connect(func(blocked, _m): _on_contact(f, blocked))
	f.jumped.connect(func(): play("jump", -7.0))

## Pick the impact SFX by outcome: block click, counter sting, heavy thump, or light hit.
## Reads the victim (the attacker's opponent), whose hit context was just set on connect.
func _on_contact(attacker: Fighter, blocked: bool) -> void:
	if blocked:
		play("block")
		return
	var vic: Fighter = attacker.opponent
	if vic != null and vic.last_counter != GameConst.Counter.NONE:
		play("counter", 1.0)
		play("hit_heavy" if vic.hit_strength >= 2 else "hit")
	elif vic != null and vic.hit_strength >= 2:
		play("hit_heavy")
	else:
		play("hit")

func wire_arena(arena: Arena) -> void:
	arena.ko.connect(func(_side): play("ko"))
