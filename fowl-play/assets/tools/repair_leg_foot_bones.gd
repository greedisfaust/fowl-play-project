@tool
extends EditorScript
## Run once from Godot's Script editor with player_rig.tscn active.
## Moves the existing Foot_L/R bones from the knee pivots to the ankle pivots.

const TARGET_SCENE: String = "res://ragdoll/player_rig.tscn"

func _run() -> void:
	var scene: Node = EditorInterface.get_edited_scene_root()
	if scene == null or scene.scene_file_path != TARGET_SCENE:
		push_warning("Foot repair: open player_rig.tscn as the active scene. Nothing changed.")
		return
	var skeleton: Skeleton3D = scene.get_node_or_null("Skeleton3D") as Skeleton3D
	if skeleton == null or skeleton.get_bone_count() != 17:
		push_warning("Foot repair: expected the completed seventeen-bone skeleton. Nothing changed.")
		return
	var expected_names: Array[String] = [
		"Hips", "Spine", "Chest", "Neck", "Head",
		"UpperArm_L", "Forearm_L", "Hand_L",
		"UpperArm_R", "Forearm_R", "Hand_R",
		"Thigh_L", "Shin_L", "Foot_L",
		"Thigh_R", "Shin_R", "Foot_R",
	]
	for index: int in expected_names.size():
		if skeleton.get_bone_name(index) != expected_names[index]:
			push_warning("Foot repair: bone hierarchy differs from the planned rig. Nothing changed.")
			return
	var history: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	history.create_action("Repair foot bone pivots", UndoRedo.MERGE_DISABLE, skeleton)
	for bone_index: int in [13, 16]:
		history.add_undo_property(skeleton, "bones/%d/rest" % bone_index, skeleton.get("bones/%d/rest" % bone_index))
		history.add_undo_property(skeleton, "bones/%d/position" % bone_index, skeleton.get("bones/%d/position" % bone_index))
		var pose_position: Vector3 = skeleton.get_bone_pose_position(bone_index)
		history.add_undo_method(skeleton, "set_bone_pose_position", bone_index, pose_position)
		var ankle_offset: Vector3 = Vector3(0, -0.42, 0.02)
		history.add_do_method(skeleton, "set_bone_rest", bone_index,
			Transform3D(Basis.IDENTITY, ankle_offset))
		history.add_do_method(skeleton, "set_bone_pose_position", bone_index, ankle_offset)
	history.commit_action()
	EditorInterface.mark_scene_as_unsaved()
	EditorInterface.edit_node(skeleton)
