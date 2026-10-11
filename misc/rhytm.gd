extends Node2D

@export var timeline_path: String = "res://data/test_timeline.json"
@export var audio_path: String = "res://audio/test.wav"

var timeline: Array = []
var frame_duration: float = 0.0
var last_frame: int = -1

@onready var music: AudioStreamPlayer = $Music


func _ready() -> void:
	seed(42)
	timeline = load_timeline(timeline_path)
	frame_duration = timeline[1]["t"] - timeline[0]["t"]
	music.stream = load(audio_path)
	music.play()


func load_timeline(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(file.get_as_text())


func current_frame() -> int:
	var t := music.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()
	return clampi(int(t / frame_duration), 0, timeline.size() - 1)


func _process(_delta: float) -> void:
	var i := current_frame()
	if i == last_frame:
		return
	last_frame = i
	var f: Dictionary = timeline[i]
	if f["onset"]:
		spawn_block(f)


func spawn_block(f: Dictionary) -> void:
	var area := get_viewport_rect().size
	var side := lerpf(30.0, 160.0, f["bass"])
	var block := ColorRect.new()
	block.size = Vector2(side, side)
	block.pivot_offset = block.size / 2.0
	block.position = Vector2(randf_range(0.0, area.x - side), randf_range(0.0, area.y - side))
	block.color = Color.from_hsv(lerpf(0.6, 0.0, f["centroid"]), 0.8, 1.0, 0.9)
	add_child(block)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(block, "modulate:a", 0.0, 0.8)
	tween.tween_property(block, "scale", Vector2(1.5, 1.5), 0.8)
	tween.chain().tween_callback(block.queue_free)
