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
var _probe := XRTrackerHandPoseSource.new()
var _probe_frame := XRHandFrame.new()

func _ready() -> void:
	_label = Label3D.new()
	_label.font_size = 96
	_label.outline_size = 24
	_label.pixel_size = 0.002
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.no_depth_test = true
	add_child(_label)
	_label.position = Vector3(0.0, 1.6, -1.6)

func _process(_delta: float) -> void:
	# Chase the ACTIVE camera every frame instead of parenting at _ready: the
	# XR rig builds its camera at runtime and Link recentres the space, so a
	# label pinned at startup can end up behind the user -- in passthrough,
	# with no sky or environment to orient by, that reads as "nothing starts".
	var camera := get_viewport().get_camera_3d()
	if camera == null or _label == null:
		return
	var xf := camera.global_transform
	_label.global_position = xf.origin + xf.basis * Vector3(0.0, 0.0, -1.6)
	_label.global_basis = xf.basis

	for hand in range(2):
		var recorder := XRHandTraceRecorder.new()
		recorder.hand = hand
		add_child(recorder)
		_recorders.append(recorder)

	_run_session()

func _run_session() -> void:
	await _say("HAND TRACE CAPTURE\n\n3 segments, ~1 minute total.\nKeep your hands tracked as hands\n(put controllers down).", Color.WHITE, 6.0)
	for segment in _SEGMENTS:
		# Never record an empty room: a session once auto-ran to completion
		# while nobody was looking into the headset yet. Gate every segment
		# on both hands actually tracking.
		await _wait_for_hands()
		for tick in range(_COUNTDOWN, 0, -1):
			await _say("%s\n\nstarting in %d" % [segment["text"], tick], Color.YELLOW, 1.0)
		for recorder in _recorders:
			recorder.start()
		await _say("%s\n\nRECORDING" % segment["text"], Color.RED, segment["secs"])
		for hand in range(2):
			var side := "left" if hand == 0 else "right"
			var path := "user://hand_traces/%s_%s.res" % [segment["kind"], side]
			var err: Error = _recorders[hand].stop_and_save(path)
			if err != OK and FileAccess.file_exists(path):
				# Never let a stale trace from an earlier run pose as this
				# segment: a failed save must leave NO file at the path.
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
				print("trace_capture: removed stale %s after failed save" % path)
			print("trace_capture: %s -> %s (%d frames, %s)" % [
				path, error_string(err), _recorders[hand].frame_count(), side])
	await _say("DONE\n\nAll traces saved.\nYou can take the headset off.", Color.GREEN, 3600.0)

## Blocks until BOTH hands are tracking as hands (raw path, one probe per
## rendered frame). The prompt names whichever hand is still missing.
func _wait_for_hands() -> void:
	var announced := ""
	while true:
		var left := _probe.capture(0, Time.get_ticks_usec(), _probe_frame)
		var right := _probe.capture(1, Time.get_ticks_usec(), _probe_frame)
		if left and right:
			return
		var missing := "BOTH HANDS"
		if left and not right:
			missing = "RIGHT HAND"
		elif right and not left:
			missing = "LEFT HAND"
		var text := "SHOW %s\n\nHold your hands up in view\n(controllers down)\nCapture starts when both track." % missing
		if text != announced:
			announced = text
			print("trace_capture: waiting -- %s missing" % missing)
		_label.text = text
		_label.modulate = Color.CYAN
		await get_tree().process_frame

func _say(text: String, color: Color, hold_secs: float) -> void:
	_label.text = text
	_label.modulate = color
	print("trace_capture: %s" % text.replace("\n", " | "))
	await get_tree().create_timer(hold_secs).timeout
