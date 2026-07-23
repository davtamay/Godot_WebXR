class_name SceneStreamer
extends Node

## Streams a content bundle (a .pck) over HTTP, mounts it with
## ProjectSettings.load_resource_pack(), then switches to a scene inside it —
## Godot's analog of Unity AssetBundles / Addressables. Bundles cache to user://
## (persistent IDBFS on web), so a second visit skips the download.
##
## Usage:
##   streamer.open("res://path/scene.tscn")                       # already in base pck
##   streamer.open("res://path/scene.tscn", "bundle.pck", "bundle.pck")  # stream first

signal status(text: String)

## Give up if the download makes no forward progress for this long. Turns a silent
## hang (dropped connection, wedged fetch) into a visible, actionable failure
## instead of an eternal "Downloading…".
const STALL_TIMEOUT := 20.0

var _http: HTTPRequest
var _scene := ""
var _cache := ""
var _downloading := false
var _last_bytes := 0
var _stall := 0.0

func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)

func open(scene_path: String, pck_url := "", cache_name := "") -> void:
	_scene = scene_path
	if pck_url.is_empty():
		_change_scene_deferred()
		return
	_cache = "user://" + cache_name
	if FileAccess.file_exists(_cache) and ProjectSettings.load_resource_pack(_cache):
		status.emit("cached — loading…")
		_change_scene_deferred()
		return
	status.emit("Connecting…")
	# Download to memory, then write+flush ourselves. HTTPRequest.download_file
	# to user:// is not reliably readable by load_resource_pack on web.
	_http.body_size_limit = -1
	var err := _http.request(_resolve_url(pck_url))
	if err != OK:
		status.emit("request error %d" % err)
		return
	_downloading = true
	_last_bytes = 0
	_stall = 0.0

## Poll live download progress so the UI shows bytes moving (a big bundle on a
## phone-class browser is slow, not hung) and so we can abort a true stall.
func _process(delta: float) -> void:
	if not _downloading:
		return
	var got := _http.get_downloaded_bytes()
	var total := _http.get_body_size()  # -1 until Content-Length is seen
	if got > _last_bytes:
		_last_bytes = got
		_stall = 0.0
	else:
		_stall += delta
		if _stall >= STALL_TIMEOUT:
			_downloading = false
			_http.cancel_request()
			status.emit("download stalled at %.1f MB — check the connection and retry" % (got / 1048576.0))
			return
	if total > 0:
		status.emit("Downloading… %.1f / %.1f MB (%d%%)" % [
			got / 1048576.0, total / 1048576.0, int(100.0 * got / total)])
	else:
		status.emit("Downloading… %.1f MB" % (got / 1048576.0))

## Resolve a relative bundle name against the page URL on web, so the fetch works
## regardless of host/port.
func _resolve_url(url: String) -> String:
	if url.begins_with("http"):
		return url
	if OS.has_feature("web") and Engine.has_singleton("JavaScriptBridge"):
		var js = Engine.get_singleton("JavaScriptBridge")
		var base = str(js.eval("window.location.href.replace(/[^/]*$/, '')", true))
		if base != "":
			return base + url
	return url

func _on_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_downloading = false
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		status.emit("download failed (result %d, http %d)" % [result, code])
		return
	var f := FileAccess.open(_cache, FileAccess.WRITE)
	if f == null:
		status.emit("cannot write %s (err %d)" % [_cache, FileAccess.get_open_error()])
		return
	f.store_buffer(body)
	f.close()   # synchronous flush before we mount
	status.emit("downloaded %d bytes — mounting…" % body.size())
	if ProjectSettings.load_resource_pack(_cache):
		_change_scene_deferred()
	else:
		status.emit("mount failed (wrote %d bytes to %s)" % [body.size(), _cache])


## A launcher button can call open() while Viewport is still dispatching its
## input event. Changing the scene immediately frees that Viewport mid-dispatch,
## which produces !is_inside_tree() errors in web builds. Defer the hand-off to
## the next idle step so mouse, controller-ray, and hand-ray clicks finish cleanly.
## XRSceneRouter also overlaps the incoming/outgoing XR owners, preventing the
## native compositor from flashing the previous launcher frame.
func _change_scene_deferred() -> void:
	XRSceneRouter.change_scene_to_file(_scene)
