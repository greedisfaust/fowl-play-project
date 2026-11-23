@tool
extends MeshInstance3D
## Generates a rounded rectangular keycap without requiring an external model.
## Attach this script directly to the existing KeyMesh MeshInstance3D.

@export var keycap_size: Vector3 = Vector3(0.12, 0.045, 0.12):
	set(value):
		keycap_size = Vector3(maxf(value.x, 0.001), maxf(value.y, 0.001), maxf(value.z, 0.001))
		_rebuild_mesh()

@export_range(0.0, 0.02, 0.0005, "suffix:m") var corner_radius: float = 0.004:
	set(value):
		corner_radius = maxf(value, 0.0)
		_rebuild_mesh()

@export_range(4, 64, 1) var bevel_segments: int = 32:
	set(value):
		bevel_segments = maxi(value, 2)
		_rebuild_mesh()

func _ready() -> void:
	_rebuild_mesh()

func _rebuild_mesh() -> void:
	if not is_inside_tree():
		return
	var half_size: Vector3 = keycap_size * 0.5
	var radius: float = minf(corner_radius, minf(half_size.x, minf(half_size.y, half_size.z)) * 0.95)
	var inner_half: Vector3 = half_size - Vector3.ONE * radius
	var surface_tool: SurfaceTool = SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	var face_normals: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]
	var face_u_axes: Array[Vector3] = [Vector3.UP, Vector3.UP, Vector3.BACK, Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT]
	var face_v_axes: Array[Vector3] = [Vector3.BACK, Vector3.FORWARD, Vector3.RIGHT, Vector3.BACK, Vector3.UP, Vector3.DOWN]

	for face_index: int in range(face_normals.size()):
		var normal: Vector3 = face_normals[face_index]
		var axis_u: Vector3 = face_u_axes[face_index]
		var axis_v: Vector3 = face_v_axes[face_index]
		var extent_u: float = half_size.dot(axis_u.abs())
		var extent_v: float = half_size.dot(axis_v.abs())
		for y_index: int in range(bevel_segments):
			for x_index: int in range(bevel_segments):
				var x0: float = -1.0 + 2.0 * float(x_index) / float(bevel_segments)
				var x1: float = -1.0 + 2.0 * float(x_index + 1) / float(bevel_segments)
				var y0: float = -1.0 + 2.0 * float(y_index) / float(bevel_segments)
				var y1: float = -1.0 + 2.0 * float(y_index + 1) / float(bevel_segments)
				var p00: Vector3 = _rounded_surface_point(normal, axis_u, axis_v, extent_u, extent_v, x0, y0, half_size)
				var p10: Vector3 = _rounded_surface_point(normal, axis_u, axis_v, extent_u, extent_v, x1, y0, half_size)
				var p11: Vector3 = _rounded_surface_point(normal, axis_u, axis_v, extent_u, extent_v, x1, y1, half_size)
				var p01: Vector3 = _rounded_surface_point(normal, axis_u, axis_v, extent_u, extent_v, x0, y1, half_size)
				# Godot treats clockwise triangles as front-facing. Keep the generated
				# surface winding aligned with the outward vertex normals so the
				# Interactable cull_front outline only draws the expanded silhouette.
				_add_vertex(surface_tool, p00, inner_half, radius, normal)
				_add_vertex(surface_tool, p11, inner_half, radius, normal)
				_add_vertex(surface_tool, p10, inner_half, radius, normal)
				_add_vertex(surface_tool, p00, inner_half, radius, normal)
				_add_vertex(surface_tool, p01, inner_half, radius, normal)
				_add_vertex(surface_tool, p11, inner_half, radius, normal)

	var existing_material: Material = null
	if mesh != null and mesh.get_surface_count() > 0:
		existing_material = mesh.surface_get_material(0)
	var generated_mesh: ArrayMesh = surface_tool.commit() as ArrayMesh
	if generated_mesh != null and existing_material != null:
		generated_mesh.surface_set_material(0, existing_material)
	mesh = generated_mesh

func _rounded_surface_point(
	normal: Vector3,
	axis_u: Vector3,
	axis_v: Vector3,
	extent_u: float,
	extent_v: float,
	u_value: float,
	v_value: float,
	half_size: Vector3
) -> Vector3:
	return normal * half_size.dot(normal.abs()) + axis_u * extent_u * u_value + axis_v * extent_v * v_value

func _add_vertex(surface_tool: SurfaceTool, point: Vector3, inner_half: Vector3, radius: float, fallback_normal: Vector3) -> void:
	var closest: Vector3 = Vector3(
		clampf(point.x, -inner_half.x, inner_half.x),
		clampf(point.y, -inner_half.y, inner_half.y),
		clampf(point.z, -inner_half.z, inner_half.z)
	)
	var normal: Vector3 = (point - closest).normalized()
	if normal.is_zero_approx():
		normal = fallback_normal
	surface_tool.set_normal(normal)
	surface_tool.add_vertex(closest + normal * radius)
