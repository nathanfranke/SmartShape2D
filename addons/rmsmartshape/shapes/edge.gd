tool
extends Reference
class_name SS2D_Edge

var quads: Array = []
var first_point_key: int = -1
var last_point_key: int = -1
var z_index: int = 0
# If final point is connected to first point
var wrap_around:bool = false

static func different_render(q1: SS2D_Quad, q2: SS2D_Quad) -> bool:
	"""
	Will return true if the 2 quads must be drawn in two calls
	"""
	if (
		q1.texture != q2.texture
		or q1.flip_texture != q2.flip_texture
		or q1.texture_normal != q2.texture_normal
	):
		return true
	return false

static func get_consecutive_quads_for_mesh(_quads: Array) -> Array:
	if _quads.empty():
		return []

	var quad_ranges = []
	var quad_range = []
	quad_range.push_back(_quads[0])
	for i in range(1, _quads.size(), 1):
		var quad_prev = _quads[i - 1]
		var quad = _quads[i]
		if different_render(quad, quad_prev):
			quad_ranges.push_back(quad_range)
			quad_range = [quad]
		else:
			quad_range.push_back(quad)

	quad_ranges.push_back(quad_range)
	return quad_ranges

static func generate_array_mesh_from_quad_sequence(_quads: Array, wrap_around:bool) -> ArrayMesh:
	"""
	Assumes each quad in the sequence is of the same render type
	same textures, values, etc...
	quads passed in as an argument should have been generated by get_consecutive_quads_for_mesh
	"""
	if _quads.empty():
		return ArrayMesh.new()

	var total_length: float = 0.0
	for q in _quads:
		total_length += q.get_length_average()
	if total_length == 0.0:
		#print("total length is 0? Quads: %s" % _quads)
		return ArrayMesh.new()

	var first_quad = _quads[0]
	var tex: Texture = first_quad.texture
	# The change in length required to apply to each quad
	# to make the textures begin and end at the start and end of each texture
	var change_in_length: float = -1.0
	if tex != null:
		# How many times the texture is repeated
		var texture_reps = round(total_length / tex.get_size().x)
		# Length required to display all the reps with the texture's full width
		var texture_full_length = texture_reps * tex.get_size().x
		# How much each quad's texture must be offset to make up the difference in full length vs total length
		change_in_length = (texture_full_length / total_length)
		
	if first_quad.fit_texture == SS2D_Material_Edge.FITMODE.CROP:
		change_in_length = 1.0

	var length_elapsed: float = 0.0
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for q in _quads:
		var section_length: float = q.get_length_average() * change_in_length
		var section_length_top: float = q.get_length_top() * change_in_length
		var section_length_bottom: float = q.get_length_bottom() * change_in_length
		var uv_a = Vector2(0, 0)
		var uv_b = Vector2(0, 1)
		var uv_c = Vector2(1, 1)
		var uv_d = Vector2(1, 0)
		if tex != null:
			uv_a.x = (length_elapsed) / tex.get_size().x
			uv_b.x = (length_elapsed) / tex.get_size().x
			uv_c.x = (length_elapsed + section_length) / tex.get_size().x
			uv_d.x = (length_elapsed + section_length) / tex.get_size().x
		if q.flip_texture:
			var t = uv_a
			uv_a = uv_b
			uv_b = t
			t = uv_c
			uv_c = uv_d
			uv_d = t

		# A
		_add_uv_to_surface_tool(st, uv_a)
		st.add_color(q.color)
		st.add_vertex(SS2D_Common_Functions.to_vector3(q.pt_a))

		# B
		_add_uv_to_surface_tool(st, uv_b)
		st.add_color(q.color)
		st.add_vertex(SS2D_Common_Functions.to_vector3(q.pt_b))

		# C
		_add_uv_to_surface_tool(st, uv_c)
		st.add_color(q.color)
		st.add_vertex(SS2D_Common_Functions.to_vector3(q.pt_c))

		# A
		_add_uv_to_surface_tool(st, uv_a)
		st.add_color(q.color)
		st.add_vertex(SS2D_Common_Functions.to_vector3(q.pt_a))

		# C
		_add_uv_to_surface_tool(st, uv_c)
		st.add_color(q.color)
		st.add_vertex(SS2D_Common_Functions.to_vector3(q.pt_c))

		# D
		_add_uv_to_surface_tool(st, uv_d)
		st.add_color(q.color)
		st.add_vertex(SS2D_Common_Functions.to_vector3(q.pt_d))

		length_elapsed += section_length

	st.index()
	st.generate_normals()
	return st.commit()


func get_meshes() -> Array:
	"""
	Returns an array of SS2D_Mesh
	# Get Arrays of consecutive quads with the same mesh data
	# For each array
	## Generate Mesh Data from the quad
	"""

	var consecutive_quad_arrays = get_consecutive_quads_for_mesh(quads)
	#print("Arrays: %s" % consecutive_quad_arrays.size())
	var meshes = []
	for consecutive_quads in consecutive_quad_arrays:
		if consecutive_quads.empty():
			continue
		var st: SurfaceTool = SurfaceTool.new()
		var array_mesh: ArrayMesh = generate_array_mesh_from_quad_sequence(consecutive_quads, wrap_around)
		var tex: Texture = consecutive_quads[0].texture
		var tex_normal: Texture = consecutive_quads[0].texture_normal
		var flip = consecutive_quads[0].flip_texture
		var transform = Transform2D()
		var mesh_data = SS2D_Mesh.new(tex, tex_normal, flip, transform, [array_mesh])
		meshes.push_back(mesh_data)

	return meshes


static func _add_uv_to_surface_tool(surface_tool: SurfaceTool, uv: Vector2):
	surface_tool.add_uv(uv)
	surface_tool.add_uv2(uv)
