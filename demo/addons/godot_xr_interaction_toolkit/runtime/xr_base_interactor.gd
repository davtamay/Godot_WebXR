class_name XRBaseInteractor
extends Node3D

const XRInputAdapter := preload("res://addons/godot_xr_interaction_toolkit/runtime/input/xr_input_adapter.gd")
const XRInteractionManager := preload("res://addons/godot_xr_interaction_toolkit/runtime/xr_interaction_manager.gd")

## Base interactor: wires an XRInputAdapter's select events to manager-arbitrated
## selection and owns hover-transition bookkeeping. Subclasses compute what is
## hovered and call _set_hovered().

signal hover_entered(interactable)
signal hover_exited(interactable)
signal select_entered(interactable)
signal select_exited(interactable)

@export var input_adapter_path: NodePath
@export var hand: XRInputAdapter.Hand = XRInputAdapter.Hand.LEFT
@export_flags("Layer 1", "Layer 2", "Layer 3", "Layer 4", "Layer 5", "Layer 6", "Layer 7", "Layer 8") var interaction_layers := 1

var _manager: Node
var _adapter: Node
var _hovered: Node
var _selected: Node

func _notification(what: int) -> void:
    if what == NOTIFICATION_PARENTED:
        _resolve_manager()

func _enter_tree() -> void:
    _resolve_manager()

func _resolve_manager() -> void:
    _manager = XRInteractionManager.find(self)
    if _manager == null:
        push_warning("%s: no XRInteractionManager in the scene tree." % name)

func _ready() -> void:
    var adapter := get_node_or_null(input_adapter_path)
    if adapter:
        set_input_adapter(adapter)

func _exit_tree() -> void:
    if _selected and _manager:
        _manager.request_deselect(self)

func set_input_adapter(adapter: Node) -> void:
    if _adapter:
        if _adapter.select_started.is_connected(_on_adapter_select_started):
            _adapter.select_started.disconnect(_on_adapter_select_started)
        if _adapter.select_ended.is_connected(_on_adapter_select_ended):
            _adapter.select_ended.disconnect(_on_adapter_select_ended)

    _adapter = adapter
    if _adapter:
        if not _adapter.select_started.is_connected(_on_adapter_select_started):
            _adapter.select_started.connect(_on_adapter_select_started)
        if not _adapter.select_ended.is_connected(_on_adapter_select_ended):
            _adapter.select_ended.connect(_on_adapter_select_ended)

func get_hovered() -> Node:
    return _hovered

func get_selected() -> Node:
    return _selected

## Global-space pose grabbed objects follow. Base: this node's transform.
func get_attach_pose() -> Transform3D:
    return global_transform

func _on_adapter_select_started(event_hand: int) -> void:
    if event_hand != hand:
        return
    _try_select()

func _on_adapter_select_ended(event_hand: int) -> void:
    if event_hand != hand:
        return
    _release_select()

func _try_select() -> void:
    if _manager == null:
        _resolve_manager()
    if _selected or _hovered == null or _manager == null:
        return
    _manager.request_select(self, _hovered)

func _release_select() -> void:
    if _selected == null or _manager == null:
        return
    _manager.request_deselect(self)

func _set_hovered(interactable) -> void:
    if interactable == _hovered:
        return
    if _hovered:
        _hovered._notify_hover_exited(self)
        hover_exited.emit(_hovered)
    _hovered = interactable
    if _hovered:
        _hovered._notify_hover_entered(self)
        hover_entered.emit(_hovered)

func _notify_select_granted(interactable) -> void:
    _selected = interactable
    select_entered.emit(interactable)

func _notify_select_released(interactable) -> void:
    _selected = null
    select_exited.emit(interactable)
