extends Node2D

@export var timeline_path: String = "res://data/click_timeline.json"
@export var audio_path: String = "res://audio/click.wav"
@export var click_interval: float = 0.5
@export var speed: float = 1000.0

var timeline: Array = []
var onset_times: Array[float] = []
var frame_duration: float = 0.0
var last_frame: int = -1
var offset: float = 0.0
var analysis_bias: float = 0.0
var pulse: float = 0.0
var tap_times: Array[float] = []
var tap_deltas: Array[float] = []

@onready var music: AudioStreamPlayer = $Music
@onready var info: Label = $Info


func _ready() -> void:
	var file := FileAccess.open(timeline_path, FileAccess.READ)
	timeline = JSON.parse_string(file.get_as_text())
	frame_duration = timeline[1]["t"] - timeline[0]["t"]
	var sum := 0.0
	for f in timeline:
		if f["onset"]:
			var t: float = f["t"]
			onset_times.append(t)
			sum += t - roundf(t / click_interval) * click_interval
	analysis_bias = sum / maxf(onset_times.size(), 1)
	offset = analysis_bias
	music.stream = load(audio_path)
	music.play()


func audio_time() -> float:
	return music.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()


func _process(delta: float) -> void:
	var vt := audio_time() + offset
	var i := clampi(int(vt / frame_duration), 0, timeline.size() - 1)
	for k in range(last_frame + 1, i + 1):
		if timeline[k]["onset"]:
			pulse = 1.0
	last_frame = i
	pulse = move_toward(pulse, 0.0, delta * 4.0)
	update_info()
	queue_redraw()


func _draw() -> void:
	var view := get_viewport_rect().size
	var hit := Vector2(view.x * 0.25, view.y * 0.5)
	var at := audio_time()
	var vt := at + offset
	draw_line(Vector2(hit.x, 0.0), Vector2(hit.x, view.y), Color(1, 1, 1, 0.5), 2.0)
	draw_circle(hit, 30.0 + 50.0 * pulse, Color(1, 1, 1, 0.15 + 0.85 * pulse))
	for t in onset_times:
		var x := hit.x + (t - vt) * speed
		if x > -20.0 and x < view.x + 20.0:
			draw_rect(Rect2(x - 4.0, hit.y - 100.0, 8.0, 100.0), Color.CYAN)
	var k0 := int(floorf(at / click_interval))
	for k in range(k0 - 1, k0 + 4):
		if k < 1:
			continue
		var x := hit.x + (float(k) * click_interval - at) * speed
		draw_rect(Rect2(x - 1.5, hit.y, 3.0, 100.0), Color.LIME_GREEN)
	for tt in tap_times:
		var x := hit.x + (tt - at) * speed
		if x > -20.0:
			draw_rect(Rect2(x - 2.0, hit.y - 30.0, 4.0, 60.0), Color.ORANGE)


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var step := 0.05 if event.shift_pressed else 0.01
	match event.keycode:
		KEY_RIGHT:
			offset += step
		KEY_LEFT:
			offset -= step
		KEY_B:
			offset = analysis_bias
		KEY_SPACE:
			var t := audio_time()
			tap_times.append(t)
			tap_deltas.append(t - roundf(t / click_interval) * click_interval)
		KEY_R:
			tap_times.clear()
			tap_deltas.clear()


func update_info() -> void:
	var tap_text := "-"
	if tap_deltas.size() > 0:
		var s := 0.0
		for d in tap_deltas:
			s += d
		tap_text = "%+.0f ms (n=%d)" % [s / tap_deltas.size() * 1000.0, tap_deltas.size()]
	info.text = "Offset: %+d ms  [LEFT/RIGHT: 10 ms, +SHIFT: 50 ms, B: reset]\nSystem latency (offset - bias): %+d ms\nTap mean: %s  [SPACE: tap, R: reset]" % [
		roundi(offset * 1000.0),
		roundi((offset - analysis_bias) * 1000.0),
		tap_text,
	]
