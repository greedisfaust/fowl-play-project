## Selective same-ragdoll contacts. Connected bones remain collision-exempt.
extends RefCounted

const CONTACT_PAIRS: Array = [
	# Existing torso/limb contacts.
	["Chest", "Forearm_L"], ["Chest", "Forearm_R"],
	["Hips", "Forearm_L"], ["Hips", "Forearm_R"],
	["Chest", "Thigh_L"], ["Chest", "Thigh_R"],
	["Chest", "Shin_L"], ["Chest", "Shin_R"],
	["Hips", "Shin_L"], ["Hips", "Shin_R"],
	# Opposite-side arm contacts: stop arms and forearms passing through each other.
	["UpperArm_L", "UpperArm_R"],
	["UpperArm_L", "Forearm_R"], ["Forearm_L", "UpperArm_R"],
	["Forearm_L", "Forearm_R"],
	# Opposite-side leg contacts: stop thighs and shins interpenetrating.
	["Thigh_L", "Thigh_R"],
	["Thigh_L", "Shin_R"], ["Shin_L", "Thigh_R"],
	["Shin_L", "Shin_R"],
]

static func configure(bones: Array[PhysicalBone3D]) -> int:
	var by_name: Dictionary = {}
	for bone: PhysicalBone3D in bones:
		by_name[bone.bone_name] = bone
	for first_index: int in range(bones.size()):
		for second_index: int in range(first_index + 1, bones.size()):
			bones[first_index].add_collision_exception_with(bones[second_index])
	var enabled: int = 0
	for pair: Array in CONTACT_PAIRS:
		var first: PhysicalBone3D = by_name.get(StringName(pair[0])) as PhysicalBone3D
		var second: PhysicalBone3D = by_name.get(StringName(pair[1])) as PhysicalBone3D
		if first == null or second == null:
			continue
		first.remove_collision_exception_with(second)
		second.remove_collision_exception_with(first)
		enabled += 1
	return enabled
