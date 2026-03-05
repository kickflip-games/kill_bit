extends Node

const MUSIC                   = preload("res://sfx/music.mp3")
const SFX_PLAYER_SHOOTS       = preload("res://sfx/player_shoots.wav")
const SFX_PLAYER_TAKES_DAMAGE = preload("res://sfx/player_takes_damage.wav")
const SFX_PLAYER_DEATH        = preload("res://sfx/player_death.wav")
const SFX_PLAYER_HIT_ENEMY    = preload("res://sfx/player_hit_enemy.wav")
const SFX_ENEMY_TAKES_DAMAGE  = preload("res://sfx/enemy_takes_damage.wav")
const SFX_ENEMY_DEATHS        = [preload("res://sfx/enemy_death.wav"), preload("res://sfx/enemy_death2.wav")]
const SFX_ENEMY_SHOOTS        = preload("res://sfx/enemy_shoots.wav")
const SFX_BULLET_ENV          = preload("res://sfx/bullet_hits_environment.wav")
const SFX_PAUSE               = preload("res://sfx/pause.wav")
const SFX_UNPAUSE             = preload("res://sfx/unpause.wav")
const SFX_PICKUP              = preload("res://sfx/player_pickups_item.wav")
const SFX_WIN                 = preload("res://sfx/win.wav")

@onready var music_player: AudioStreamPlayer = $MusicPlayer

func _ready() -> void:
	music_player.stream = MUSIC
	music_player.stream.loop = true
	music_player.play()

func play_sfx(stream: AudioStream) -> void:
	var sfx := AudioStreamPlayer.new()
	add_child(sfx)
	sfx.stream = stream
	sfx.play()
	sfx.finished.connect(sfx.queue_free)

func play_enemy_death() -> void:
	play_sfx(SFX_ENEMY_DEATHS[randi() % SFX_ENEMY_DEATHS.size()])
