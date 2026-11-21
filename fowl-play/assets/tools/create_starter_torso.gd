@tool
extends EditorScript
## One-time, user-approved editor action. Never attach this to a scene node.
## Run with the saved player_rig scene active; save the result manually.

const TARGET_SCENE: String = "res://ragdoll/player_rig.tscn"

func _run() -> void:
	var scene: Node = EditorInterface.get_edited_scene_root()
	if scene == null or scene.scene_file_path != TARGET_SCENE:
		push_warning("Starter torso: open player_rig.tscn as the active scene first. Nothing changed.")
		return
	var skeleton: Skeleton3D = scene.get_node_or_null("Skeleton3D") as Skeleton3D
	if skeleton == null or skeleton.get_bone_count() != 0:
		push_warning("Starter torso: requires an empty Skeleton3D child. Nothing changed.")
		return
	# Offsets are parent-relative. Global heights: 0.98, 1.12, 1.30 m.
	var names: Array[String] = ["Hips", "Spine", "Chest"]
	var offsets: Array[Vector3] = [Vector3(0, 0.98, 0), Vector3(0, 0.14, 0), Vector3(0, 0.18, 0)]
	var history: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	history.create_action("Create starter torso bones", UndoRedo.MERGE_DISABLE, skeleton)
	for index: int in names.size():
		history.add_do_method(skeleton, "add_bone", names[index])
		history.add_do_method(skeleton, "set_bone_parent", index, index - 1)
		history.add_do_method(skeleton, "set_bone_rest", index, Transform3D(Basis.IDENTITY, offsets[index]))
		history.add_do_method(skeleton, "set_bone_pose_position", index, offsets[index])
	# Safe because the action only accepts an initially empty skeleton.
	history.add_undo_method(skeleton, "clear_bones")
	history.commit_action()
	EditorInterface.mark_scene_as_unsaved()
	EditorInterface.edit_node(skeleton)
