extends Node3D

## Guided hand-trace capture for Task 10's baseline. Zero-button by design:
## put the headset on, follow the floating prompts, take it off when it says
## DONE. Records BOTH hands simultaneously per segment, raw (upstream of all
## conditioning), into user://hand_traces/{kind}_{left,right}.res -- which on
## a Quest Link session is %APPDATA%/Godot/app_userdata/<project>/hand_traces.

const _SEGMENTS := [
	{"kind": "rest", "secs": 12.0, "text": "REST\n\nHold BOTH hands still,\nchest height, in view"},
	{"kind": "motion", "secs": 12.0, "text": "MOTION\n\nSweep both hands briskly\nside to side"},
	{"kind": "dropout", "secs": 15.0, "text": "DROPOUT\n\nMove both hands behind your back,\nbring them back. Do it twice."},
]
const _COUNTDOWN := 5

var _label: Label3D
var _recorders := []

func _ready() -> void:
	_label = Label3D.new()
	_label.font_size = 96
	_label.outline_size = 24
	_label.pixel_size = 0.002
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var camera := _find_camera()
	if camera:
		camera.add_child(_label)
		_label.position = Vector3(0.0, 0.0, -1.6)
	else:
		add_child(_label)
		_label.position = Vector3(0.0, 1.6, -1.6)

	for hand in range(2):
		var recorder := XRHandTraceRecorder.new()
		recorder.hand = hand
		add_child(recorder)
		_recorders.append(recorder)

	_run_session()

func _run_session() -> void:
	await _say("HAND TRACE CAPTURE\n\n3 segments, ~1 minute total.\nKeep your hands tracked as hands\n(put controllers down).", Color.WHITE, 6.0)
	for segment in _SEGMENTS:
		for tick in range(_COUNTDOWN, 0, -1):
			await _say("%s\n\nstarting in %d" % [segment["text"], tick], Color.YELLOW, 1.0)
		for recorder in _recorders:
			recorder.start()
		await _say("%s\n\nRECORDING" % segment["text"], Color.RED, segment["secs"])
		for hand in range(2):
			var side := "left" if hand == 0 else "right"
			var path := "user://hand_traces/%s_%s.res" % [segment["kind"], side]
			var err: Error = _recorders[hand].stop_and_save(path)
			print("trace_capture: %s -> %s (%d frames, %s)" % [
				path, error_string(err), _recorders[hand].frame_count(), side])
	await _say("DONE\n\nAll traces saved.\nYou can take the headset off.", Color.GREEN, 3600.0)

func _say(text: String, color: Color, hold_secs: float) -> void:
	_label.text = text
	_label.modulate = color
	print("trace_capture: %s" % text.replace("\n", " | "))
	await get_tree().create_timer(hold_secs).timeout

func _find_camera() -> XRCamera3D:
	var found := find_children("*", "XRCamera3D", true, false)
	return found[0] as XRCamera3D if not found.is_empty() else null
