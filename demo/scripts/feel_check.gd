extends Node3D

## On-device feel check for the workshop showcase.
##
## Settled by David on 2026-07-25 and therefore no longer switchable here:
## hand conditioning is ON (the resolver default) and throw_peak_bias is 0.80
## (the XRGrabInteractable default). Both are now plain defaults in the suite,
## so this scene no longer overrides them -- what you feel here is what every
## scene gets.
##
## Still open, so still switchable: whether the microgesture recognizers do
## better on conditioned or raw joints. Their thresholds were tuned against
## raw, and conditioning trades 18-28 ms of lag for a smoother signal, so it
## is a genuine on-device question rather than a settled default.

var _gesture_label: Label3D
var _mode_label: Label3D
var _micro_source_label: Label3D
var _arbiter: XRInteractionArbiter

## Microgesture telemetry (tier 2 of the hardening): successes AND discarded
## attempts, counted per direction, because reasons alone could not answer
## the first real on-device question ("swiping right seems more reliable than
## swiping left"). This is the measurement that decides whether the dead band
## gets narrowed -- a per-direction miss RATE instead of a feeling. Visual
## only: bare hands have no haptic actuator, so the buzz the design sketch
## imagined is physically impossible here -- the label flashes instead.
##
## This panel is the session's FOCUS, so it sits front and center at full
## size while the A/B dials shrink to captions above their buttons -- their
## big multi-line labels were covering exactly the numbers being read
## (David: "other debug text covers the one we are trying to focus on").
var _reject_label: Label3D
var _reject_counts := {}
## attempted-direction name -> count, rejections only.
var _reject_by_direction := {}
## gesture name -> count, successes, both hands merged (the mux already
## picked the authoritative source).
var _ok_counts := {}
var _reject_last := "none yet"
var _reject_flash := 0.0

func _ready() -> void:
	# The A/B dials: compact captions directly above their buttons, small
	# enough that nothing overlaps the telemetry panel.
	_gesture_label = _make_label(Vector3(-0.55, 1.12, -0.55), 30)
	_make_button(Vector3(-0.55, 1.0, -0.55), _on_toggle_gesture_source)

	# Which microgesture DETECTOR drives locomotion, session-wide: PORTABLE
	# is the joint recognizer -- the code path WebXR, Galaxy XR and Link
	# actually run -- and is the default, because testing on a Quest with the
	# platform extension active measures Meta's recognizer, not ours.
	# PLATFORM is the runtime detector (Quest-only), the parity reference.
	_micro_source_label = _make_label(Vector3(-0.9, 1.12, -0.55), 30)
	_make_button(Vector3(-0.9, 1.0, -0.55), _on_toggle_micro_source)

	# The arbiter is opt-in, so the earn-in scene creates its own rather than
	# relying on the rig prefab carrying one.
	_arbiter = XRInteractionArbiter.new()
	add_child(_arbiter)
	_mode_label = _make_label(Vector3(0.9, 1.12, -0.55), 30)
	_make_button(Vector3(0.9, 1.0, -0.55), _on_toggle_arbiter)

	# The telemetry panel: front and center, the thing this bench measures.
	_reject_label = _make_label(Vector3(0.0, 1.45, -0.55))
	_reject_label.text = "MICROGESTURES\n(fumble a swipe to test the counter)"
	_reject_label.modulate = Color(1.0, 0.8, 0.4)
	# Deferred: the locomotion driver lives elsewhere in the scene tree and
	# may _ready after this node does.
	_connect_rejection_feeds.call_deferred()
	_refresh()

func _process(delta: float) -> void:
	# The live mode is the point of the label: the state machine should be
	# legible in the headset rather than inferred from what the ray is doing.
	if _mode_label != null:
		_mode_label.text = "ARBITER %s  L:%s R:%s" % [
			"ON" if _arbiter.enabled else "OFF",
			_mode_name(_arbiter.mode_for(0)),
			_mode_name(_arbiter.mode_for(1))]
	_poll_adaptive_state(delta)
	# A rejection flashes the counter red for a beat -- the visual stand-in
	# for the haptic feedback bare hands cannot receive.
	if _reject_flash > 0.0:
		_reject_flash = maxf(_reject_flash - delta, 0.0)
		if _reject_flash <= 0.0 and _reject_label != null:
			_reject_label.modulate = Color(1.0, 0.8, 0.4)

func _mode_name(mode: int) -> String:
	match mode:
		XRInteractionArbiter.Mode.NEAR: return "NEAR"
		XRInteractionArbiter.Mode.FAR: return "FAR"
		XRInteractionArbiter.Mode.TELEPORT: return "TELE"
		_: return "-"

func _on_toggle_arbiter() -> void:
	_arbiter.enabled = not _arbiter.enabled
	_refresh()

func _make_label(where: Vector3, font_size := 56) -> Label3D:
	var label := Label3D.new()
	label.font_size = font_size
	label.outline_size = 16
	label.pixel_size = 0.002
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.no_depth_test = true
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = where
	add_child(label)
	return label

func _make_button(where: Vector3, on_press: Callable) -> void:
	var button := XRPokeButton.new()
	button.position = where
	add_child(button)
	button.pressed.connect(on_press)

func _on_toggle_gesture_source() -> void:
	for runtime in _all_gesture_runtimes(self):
		runtime.set_use_conditioned_hands(not runtime.use_conditioned_hands)
	_refresh()

func _micro_platform_active() -> bool:
	if XRMicrogestureLocomotionDriver.session_platform_override >= 0:
		return XRMicrogestureLocomotionDriver.session_platform_override == 1
	# No override yet: the default is the driver export's default, PORTABLE.
	return false

func _on_toggle_micro_source() -> void:
	XRMicrogestureLocomotionDriver.session_platform_override = 0 if _micro_platform_active() else 1
	_refresh()

func _connect_rejection_feeds() -> void:
	var drivers: Array = []
	_collect_drivers(get_tree().root, drivers)
	for driver in drivers:
		if driver.has_signal("source_gesture_rejected"):
			driver.source_gesture_rejected.connect(_on_gesture_rejected)
		if driver.has_signal("source_gesture_performed"):
			driver.source_gesture_performed.connect(_on_gesture_performed)
	# Raw contact probe: where the thumb actually RESTS and TRAVELS along the
	# index (0 = base, 1 = tip), logged only while in/near contact and only on
	# meaningful movement. This is the ground truth for the arming-zone
	# question -- OUT_OF_START_ZONE counts say attempts died at the gate; this
	# says WHERE the thumb was when they did.
	for runtime in _all_gesture_runtimes(get_tree().root):
		runtime.hand_features_updated.connect(_on_contact_probe)
	# The recognizer's OWN view of the contact gate: the adaptive envelope's
	# effective thresholds and observed span, per hand. Polled and
	# change-gated in _process -- span -1 means the envelope does not yet
	# trust its samples and the authored thresholds are in force, which is
	# itself a finding: the gate is then a fixed value sitting wherever it
	# sits relative to THIS hand's press range.
	if not drivers.is_empty():
		_recognizer_ref = drivers[0].get_node_or_null("ThumbRecognizer")
	if drivers.is_empty():
		_reject_label.text = "MICROGESTURES: no driver in scene"
		_reject_label.modulate = Color(0.6, 0.6, 0.6)
	print("feel_check: telemetry feeds connected: %d driver(s)" % drivers.size())

func _collect_drivers(root: Node, found: Array) -> void:
	if root is XRMicrogestureLocomotionDriver:
		found.append(root)
	for child in root.get_children():
		_collect_drivers(child, found)

## Last logged [side_distance, contact_position] per hand, for change-gating.
var _probe_last := {}
var _recognizer_ref: Node
var _adaptive_last := {}
var _adaptive_poll := 0.0

func _poll_adaptive_state(delta: float) -> void:
	_adaptive_poll += delta
	if _adaptive_poll < 1.0 or _recognizer_ref == null or not is_instance_valid(_recognizer_ref):
		return
	_adaptive_poll = 0.0
	for hand in [0, 1]:
		var contact: float = _recognizer_ref.effective_contact_threshold(hand)
		var release: float = _recognizer_ref.effective_release_threshold(hand)
		var span: float = _recognizer_ref.contact_span(hand)
		var last: Array = _adaptive_last.get(hand, [INF, INF, INF])
		if absf(contact - float(last[0])) < 0.01 and absf(release - float(last[1])) < 0.01 \
				and absf(span - float(last[2])) < 0.01:
			continue
		_adaptive_last[hand] = [contact, release, span]
		print("feel_check: adaptive hand=%d contact=%.2f release=%.2f span=%.2f" % [hand, contact, release, span])

func _on_contact_probe(hand: int, features) -> void:
	if features == null or not features.valid:
		return
	var side: float = features.thumb_index_side_distance
	var position: float = features.thumb_index_contact_position
	# Only in/near contact (the arming question lives there), and only on
	# real movement -- an unconditional per-frame print flooded a session log
	# with 91k lines once before in this project.
	# 1.0, raised from 0.6: the tighter cap truncated the very distribution
	# being measured -- the near-contact analysis concluded "span too narrow"
	# from data the probe itself had clipped.
	if side > 1.0:
		_probe_last.erase(hand)
		return
	var last: Array = _probe_last.get(hand, [INF, INF])
	if absf(side - float(last[0])) < 0.05 and absf(position - float(last[1])) < 0.05:
		return
	_probe_last[hand] = [side, position]
	print("feel_check: contact hand=%d side=%.2f pos=%.2f" % [hand, side, position])

func _gesture_key(gesture: int) -> String:
	var keys := XRMicrogestureSource.Gesture.keys()
	return keys[gesture] if gesture >= 0 and gesture < keys.size() else "?"

func _on_gesture_performed(gesture: int, hand: int) -> void:
	var key := _gesture_key(gesture)
	_ok_counts[key] = int(_ok_counts.get(key, 0)) + 1
	_update_telemetry_label()
	print("feel_check: performed hand=%d gesture=%s ok=%s" % [hand, key, _ok_counts])

func _on_gesture_rejected(hand: int, reason: int, attempted: int) -> void:
	var keys := XRMicrogestureSource.RejectReason.keys()
	var reason_name: String = keys[reason] if reason >= 0 and reason < keys.size() else "UNKNOWN"
	_reject_counts[reason_name] = int(_reject_counts.get(reason_name, 0)) + 1
	var direction := _gesture_key(attempted)
	if attempted >= 0:
		_reject_by_direction[direction] = int(_reject_by_direction.get(direction, 0)) + 1
	_reject_last = "%s %s%s" % ["L" if hand == 0 else "R", reason_name,
			"" if attempted < 0 else " (" + direction + ")"]
	_reject_flash = 0.35
	_reject_label.modulate = Color(1.0, 0.35, 0.3)
	_update_telemetry_label()
	# Also to stdout, change-per-event by nature, so a session log carries the
	# same counts the label shows -- the tuning evidence survives the session.
	print("feel_check: rejected hand=%d reason=%s attempted=%s counts=%s by_direction=%s" % [
			hand, reason_name, direction, _reject_counts, _reject_by_direction])

func _update_telemetry_label() -> void:
	# The per-direction line is the headline: OK vs rejected, LEFT vs RIGHT,
	# is the reliability asymmetry read directly.
	var lines := ["OK   L:%d  R:%d  TAP:%d" % [
			int(_ok_counts.get("LEFT", 0)), int(_ok_counts.get("RIGHT", 0)),
			int(_ok_counts.get("TAP", 0))]]
	lines.append("MISS L:%d  R:%d" % [
			int(_reject_by_direction.get("LEFT", 0)),
			int(_reject_by_direction.get("RIGHT", 0))])
	for key in _reject_counts:
		lines.append("%s: %d" % [key, _reject_counts[key]])
	lines.append("last: %s" % _reject_last)
	_reject_label.text = "\n".join(lines)

func _all_gesture_runtimes(root: Node) -> Array:
	var found: Array = []
	if root is XRGestureRuntime:
		found.append(root)
	for child in root.get_children():
		found.append_array(_all_gesture_runtimes(child))
	return found

func _refresh() -> void:
	var runtimes := _all_gesture_runtimes(self)
	if runtimes.is_empty():
		_gesture_label.text = "GESTURES: no runtime in scene"
		_gesture_label.modulate = Color(0.6, 0.6, 0.6)
		print("feel_check: no XRGestureRuntime in scene")
		return
	var on: bool = runtimes[0].use_conditioned_hands
	_gesture_label.text = "INPUT: %s" % ("CONDITIONED" if on else "RAW")
	_gesture_label.modulate = Color(0.3, 1.0, 0.5) if on else Color(1.0, 0.55, 0.3)
	if _micro_source_label != null:
		var platform := _micro_platform_active()
		_micro_source_label.text = "DETECTOR: %s" % ("PLATFORM" if platform else "PORTABLE")
		_micro_source_label.modulate = Color(0.4, 0.7, 1.0) if platform else Color(0.3, 1.0, 0.5)
		print("feel_check: micro_detector=%s" % ("PLATFORM" if platform else "PORTABLE"))
	if _mode_label != null:
		_mode_label.modulate = Color(0.3, 1.0, 0.5) if _arbiter.enabled else Color(1.0, 0.55, 0.3)
	print("feel_check: microgesture_input=%s arbiter=%s" % [
		"CONDITIONED" if on else "RAW", "ON" if _arbiter.enabled else "OFF"])
