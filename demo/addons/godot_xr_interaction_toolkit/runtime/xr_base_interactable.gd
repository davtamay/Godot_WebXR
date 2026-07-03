class_name XRBaseInteractable
extends Node3D

const XRInteractionLayerMask := preload("res://addons/godot_xr_interaction_toolkit/runtime/xr_interaction_layers.gd")
const XRInteractionManager := preload("res://addons/godot_xr_interaction_toolkit/runtime/xr_interaction_manager.gd")

## Base interactable: registers its colliders with the XRInteractionManager
## and tracks hover/select state. Emits signals only; visual affordances are
## the consuming scene's responsibility.

signal hover_entered(interactor)
signal hover_exited(interactor)
signal select_entered(interactor)
signal select_exited(interactor)

@export_flags("Layer 1", "Layer 2", "Layer 3", "Layer 4", "Layer 5", "Layer 6", "Layer 7", "Layer 8") var interaction_layers := 1
## Colliders to register. Empty = auto-collect all CollisionObject3D descendants.
@export var collider_paths: Array[NodePath] = []

var _hovering_interactors: Array[Node] = []
var _selecting_interactor: Node
var _registered_manager: Node

func _notification(what: int) -> void:
    if what == NOTIFICATION_PARENTED:
        _register_with_manager()
    elif what == NOTIFICATION_UNPARENTED:
        _unregister_from_manager()

func _enter_tree() -> void:
    _register_with_manager()

func _exit_tree() -> void:
    _unregister_from_manager()

func _unregister_from_manager() -> void:
    if _registered_manager:
        _registered_manager.unregister_interactable(self)
        _registered_manager = null

func _register_with_manager() -> void:
    var manager = XRInteractionManager.find(self)
    if manager == null:
        push_warning("%s: no XRInteractionManager in the scene tree." % name)
        return
    if manager == _registered_manager:
        return
    if _registered_manager:
        _registered_manager.unregister_interactable(self)
    _registered_manager = manager
    _registered_manager.register_interactable(self)

func get_colliders() -> Array[CollisionObject3D]:
    var colliders: Array[CollisionObject3D] = []
    if collider_paths.is_empty():
        _collect_colliders(self, colliders)
    else:
        for path in collider_paths:
            var collider := get_node_or_null(path) as CollisionObject3D
            if collider:
                colliders.append(collider)
    return colliders

func is_hovered() -> bool:
    return not _hovering_interactors.is_empty()

func is_selected() -> bool:
    return _selecting_interactor != null

func get_selecting_interactor() -> Node:
    return _selecting_interactor

func can_hover(interactor) -> bool:
    return interactor != null and XRInteractionLayerMask.overlaps(interaction_layers, interactor.interaction_layers)

func can_select(interactor) -> bool:
    return _selecting_interactor == null and can_hover(interactor)

func _notify_hover_entered(interactor) -> void:
    if _hovering_interactors.has(interactor):
        return
    _hovering_interactors.append(interactor)
    hover_entered.emit(interactor)

func _notify_hover_exited(interactor) -> void:
    if not _hovering_interactors.has(interactor):
        return
    _hovering_interactors.erase(interactor)
    hover_exited.emit(interactor)

func _notify_select_entered(interactor) -> void:
    _selecting_interactor = interactor
    select_entered.emit(interactor)

func _notify_select_exited(interactor) -> void:
    _selecting_interactor = null
    select_exited.emit(interactor)

func _collect_colliders(node: Node, out: Array[CollisionObject3D]) -> void:
    if node is CollisionObject3D:
        out.append(node)
    for child in node.get_children():
        _collect_colliders(child, out)
