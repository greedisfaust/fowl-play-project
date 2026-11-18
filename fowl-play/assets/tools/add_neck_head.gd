@tool
extends EditorScript
## Run once from Godot's Script editor with player_rig.tscn active.
## Adds bones only. Does not attach meshes, generate physics, or save the scene.

const TARGET_SCENE: String = "res://ragdoll/player_rig.tscn"

func _run() -> void:
	var scene: Node = EditorInterface.get_edited_scene_root()
	if scene == null or scene.scene_file_path != TARGET_SCENE:
		push_warning("Neck/head: open player_rig.tscn as the active scene. Nothing changed.")
		return
	var skeleton: Skeleton3D = scene.get_node_or_null("Skeleton3D") as Skeleton3D
	if skeleton == null or skeleton.get_bone_count() != 3:
		push_warning("Neck/head: expected only the three torso bones. Nothing changed.")
		return
	var expected_names: Array[String] = ["Hips", "Spine", "Chest"]
	for index: int in expected_names.size():
		if skeleton.get_bone_name(index) != expected_names[index] or skeleton.get_bone_parent(index) != index - 1:
			push_warning("Neck/head: torso hierarchy differs from the planned chain. Nothing changed.")
			return
	var history: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	history.create_action("Add neck and head bones", UndoRedo.MERGE_DISABLE, skeleton)
	# Skeleton3D has no remove-one-bone API. Undo rebuilds the original bone data
	# on the SAME skeleton; attachment nodes and mesh resources are untouched.
	# Snapshot all stored bone properties, including custom metadata and poses.
	history.add_undo_method(skeleton, "clear_bones")
	for bone_name: String in expected_names:
		history.add_undo_method(skeleton, "add_bone", bone_name)
	for property: Dictionary in skeleton.get_property_list():
		var property_name: String = str(property["name"])
		if property_name.begins_with("bones/") and int(property["usage"]) & PROPERTY_USAGE_STORAGE:
			history.add_undo_property(skeleton, property_name, skeleton.get(property_name))
	var names: Array[String] = ["Neck", "Head"]
	var offsets: Array[Vector3] = [Vector3(0, 0.19, 0), Vector3(0, 0.06, 0)]
	for index: int in names.size():
		var bone_index: int = 3 + index
		history.add_do_method(skeleton, "add_bone", names[index])
		history.add_do_method(skeleton, "set_bone_parent", bone_index, bone_index - 1)
		history.add_do_method(skeleton, "set_bone_rest", bone_index, Transform3D(Basis.IDENTITY, offsets[index]))
		history.add_do_method(skeleton, "set_bone_pose_position", bone_index, offsets[index])
	history.commit_action()
	EditorInterface.mark_scene_as_unsaved()
	EditorInterface.edit_node(skeleton)
