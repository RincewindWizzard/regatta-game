class_name Sfx
extends Node
## Soundeffekte und Musik. Die Klänge liegen als .ogg in res://audio/ und werden mit
## tools/make_audio.py erzeugt. Jede Datei kann durch eine echte Aufnahme gleichen
## Namens ersetzt werden.
##
## Einmalige Effekte: Sfx.play("bell")
## Schleifen:         Sfx.make_loop_player("water_loop") -> AudioStreamPlayer
## Musik:             läuft automatisch; Lautstärke über MUSIC_DB, M schaltet stumm

const AUDIO_DIR := "res://audio/"
const MUSIC_DB := -8.0
const SFX_DB := -10.0     ## einmalige Effekte (Glocke, Horn, Wende ...)
const LOOP_DB := -12.0    ## Dauergeräusche (Wind, Wasser, Segel, Motor)

static var instance: Sfx
static var _cache := {}

var music: AudioStreamPlayer


func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	music = AudioStreamPlayer.new()
	music.stream = stream("music_loop")
	music.volume_db = -40.0
	add_child(music)
	if music.stream:
		music.play()
		create_tween().tween_property(music, "volume_db", MUSIC_DB, 3.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_M:
		toggle_music()


static func toggle_music() -> void:
	if instance and instance.music:
		instance.music.stream_paused = not instance.music.stream_paused


static func music_on() -> bool:
	return instance != null and instance.music != null and not instance.music.stream_paused


## Einmalig anlegen und über Szenenwechsel hinweg behalten (Musik läuft weiter)
static func ensure(tree: SceneTree) -> void:
	if instance == null or not is_instance_valid(instance):
		var s := Sfx.new()
		s.name = "Sfx"
		instance = s
		tree.root.add_child.call_deferred(s)


## Nur lokal abspielen (z. B. Ereignisse, die der Client selbst aus dem Zustand erkennt)
static func play_local(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	_play(sound, volume_db, pitch)


static func play(sound: String, volume_db := 0.0, pitch := 1.0) -> void:
	if instance == null:
		return
	if sound == "starter":
		# Anlasser erkennen Clients selbst am Motorzustand
		_play(sound, volume_db, pitch)
		return
	# im Netzwerkrennen hören die Mitsegler die Ereignisse des Hosts mit
	var net := instance.get_node_or_null("/root/Net")
	if net and net.is_host_racing():
		net.send_event("sfx", [sound, volume_db, pitch])
	_play(sound, volume_db, pitch)


static func _play(sound: String, volume_db: float, pitch: float) -> void:
	if instance == null:
		return
	var s := stream(sound)
	if s == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = volume_db + SFX_DB
	p.pitch_scale = pitch
	instance.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


static func make_loop_player(sound: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream(sound)
	p.volume_db = -80.0
	p.autoplay = p.stream != null
	return p


static func stream(sound: String) -> AudioStream:
	if _cache.has(sound):
		return _cache[sound]
	var path := AUDIO_DIR + sound + ".ogg"
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path)
		if s is AudioStreamOggVorbis:
			s.loop = sound.ends_with("_loop")
	_cache[sound] = s
	return s
