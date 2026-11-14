extends SceneTree
func _initialize() -> void:
 var node: Control = Control.new()
 node.name = "MarsNotebook"
 node.set_script(load("res://scripts/main.gd"))
 node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var packed: PackedScene = PackedScene.new()
 assert(packed.pack(node) == OK)
 var check: Node = packed.instantiate()
 assert(check.name == node.name)
 check.free()
 assert(ResourceSaver.save(packed, "res://scenes/main.tscn") == OK)
 node.free()
 quit()
