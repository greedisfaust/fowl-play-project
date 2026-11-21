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

@export_range(2, 24, 1) var bevel_segments: int = 8:
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

	var faces: Array[Dictionary] = [
		{"normal": Vector3.RIGHT, "u": Vector3.UP, "v": Vector3.BACK},
		{"normal": Vector3.LEFT, "u": Vector3.BACK, "v": Vector3.UP},
		{"normal": Vector3.UP, "u": Vector3.BACK, "v": Vector3.RIGHT},
		{"normal": Vector3.DOWN, "u": Vector3.RIGHT, "v": Vector3.BACK},
		{"normal": Vector3.BACK, "u": Vector3.RIGHT, "v": Vector3.UP},
		{"normal": Vector3.FORWARD, "u": Vector3.UP, "v": Vector3.RIGHT},
	]

	for face: Dictionary in faces:
		var normal: Vector3 = face["normal"]
		var axis_u: Vector3 = face["u"]
		var axis_v: Vector3 = face["v"]
		var extent_u: float = half_size.dot(axis_u.abs())
		var extent_v: float = half_size.dot(axis_v.abs())
		for y_index: int in range(bevel_segments):
			for x_index: int in range(bevel_segments):
				var x0: float = -1.0 + 2.0 * float(x_index) / float(bevel_segments)
				var x1: float = -1.0 + 2.0 * float(x_index + 1) / float(bevel_segments)
				var y0: float = -1.0 + 2.0 * float(y_index) / float(bevel_segments)
				var y1: float = -1.0 + 2.0 * float(y_index + 1) / float(bevel_segments)
				var p00: Vector3 = _rounded_surface_point(normal, axis_u, axis_v, extent_u, extent_v, x0, y0, half_size, inner_half, radius)
				var p10: Vector3 = _rounded_surface_point(normal, axis_u, axis_v, extent_u, extent_v, x1, y0, half_size, inner_half, radius)
				var p11: Vector3 = _rounded_surface_point(normal, axis_u, axis_v, extent_u, extent_v, x1, y1, half_size, inner_half, radius)
				var p01: Vector3 = _rounded_surface_point(normal, axis_u, axis_v, extent_u, extent_v, x0, y1, half_size, inner_half, radius)
				_add_vertex(surface_tool, p00, inner_half, radius, normal)
				_add_vertex(surface_tool, p10, inner_half, radius, normal)
				_add_vertex(surface_tool, p11, inner_half, radius, normal)
				_add_vertex(surface_tool, p00, inner_half, radius, normal)
				_add_vertex(surface_tool, p11, inner_half, radius, normal)
				_add_vertex(surface_tool, p01, inner_half, radius, normal)

	mesh = surface_tool.commit()

func _rounded_surface_point(
	normal: Vector3,
	axis_u: Vector3,
	axis_v: Vector3,
	extent_u: float,
	extent_v: float,
	u_value: float,
	v_value: float,
	half_size: Vector3,
	_inner_half: Vector3,
	_radius: float
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
