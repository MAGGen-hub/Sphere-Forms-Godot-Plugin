@tool
@icon("OctaSphereMesh.svg")
## Class representing a spherical non-[PrimitiveMesh].
##
## Class that creates a [SphereMesh] with poligon coverage based on subdivided Octahedron.
class_name OctaSphereMesh extends ArrayMesh
#region ToolInterface
## Radius of octasphere.
@export_range(0.001,100,0.001,"or_greater") var radius := 0.5:
	set(value):
		if not radius == value:
			radius = value
			## Dunamic vertex updator
			# add_surface_from_arrays() function resets the surface and force
			# Inspector panel to update and that makes imposible to edit
			# properties with sliders comfortably.
			# This litle trick allow user to edit Icosphere as easy as default
			# godot UV-Sphere, without resetng mouse focus each property change. 
			surface_update_vertex_region(0,0,apply_size().to_byte_array())
			emit_changed()

## Full heigth of the octasphere
@export_range(0.001,100,0.001,"or_greater") var heigth := 1.0:
	set(value):
		if not heigth == value:
			heigth = value
			## Dunamic vertex updator
			# add_surface_from_arrays() function resets the surface and force
			# Inspector panel to update and that makes imposible to edit
			# properties with sliders comfortably.
			# This litle trick allow user to edit Icosphere as easy as default
			# godot UV-Sphere, without resetng mouse focus each property change. 
			surface_update_vertex_region(0,0,apply_size().to_byte_array())
			emit_changed()

# To understand how Square UV mode works.
# Open "addons/icosphere/demo/demo.tscn"
## Sets UV map type. By default Octasphere has default godot sphere UV map. [br][br]
## [b]Sphere:[/b] Default godot sphere UV map. [br][br]
## [b]Plane:[/b] Special UV map designed to minimize texture distortion that default UV-Sphere has.[br][br]
## [b]UVW:[/b] No UV map, optimised vertexs cout, faster calculations. Good for custom UVW shaders.
@export_enum("Sphere","Plane","UVW") var _uv_type = 0:
	set(value):
		_uv_type=value
		update_mesh()
		
# Icosaedron has 30 core edges.
# Icosphere by defalt is equal to Icosaedron.
# This parameter controls the number of edges into which Icosaedron core edge must be splited.
# Can be used for LOD control.
## Usualy meshes like Octasphere has "subdivisions" parameter that splits octahedron triangle into 2^(subdivisions+1) triangles.[br][br]
## This parameter allow you to split octahedron triangle into edge_count^2 triangles for better "customization".
@export_range(1,96,1,"or_greater") var edge_count : int = 16:
	set(value):
		if not value == edge_count:
			edge_count = value
			update_mesh()
#endregion

#region FormSketch
# Can be usefull to understand how my mesh works.
# Numbers == Vertices
#                        1                                                      
#           /\    /\    /\    /\    #repeat                         
#          /  \  /  \  /  \  /  \                                  
#         /    \/    \/    \/    \                                     
#        2\   3/\   4/\   5/\   2/  #repeat                          
#          \  /  \  /  \  /  \  /                                         
#           \/    \/    \/    \/                                          
#                    0                                                          
#endregion

#region Constants
# base vertices
const core_vertices : PackedVector3Array = [
	Vector3(0,-1,0) , Vector3(0,1,0)   , #0 ,1
	Vector3(-1,0,0) , Vector3(0,0,1)  , #2 ,3
	Vector3(1,0,0)  , Vector3(0,0,-1)  , #4 ,5 
	Vector3(-1,0,0) , #Vector3(0,0,1), #2
]
# base triangles
const core_triangles: PackedVector3Array = [
	Vector3(0,2,3),Vector3(1,3,2),Vector3(0,3,4),Vector3(1,4,3),
	Vector3(0,4,5),Vector3(1,5,4),Vector3(0,5,2),Vector3(1,2,5),
]
# UV coords for Square_UV mode
const square_uvs : Array = [
	Vector2(0.25,1)  , #0
	Vector2(0,0)    , #1
	Vector2(0,1)    , #2
	Vector2(0.25,0), #3
]
#endregion

#region MeshBuild
# Changable variables
## Important array with mesh vertices. Required to edit heigth/radius of mesh without performance issues.[br][br]
## [b]Note:[/b] Changing this outside of script may produce unpredicted behaviour!
var vertices : PackedVector3Array = []
## Array with faces/poligons of mesh.[br][br]
## [b]Note:[/b] Resets after mesh generation.
var triangles: PackedVector3Array = []
## Array with UV coordinates.[br][br]
## [b]Note:[/b] Resets after mesh generation.
var uvs      : PackedVector2Array = []
## Contains vertices that was generated before, to prevent vertices doubling.[br][br]
## [b]Note:[/b] Resets after mesh generation.
var lookup   : Dictionary         = {block = true}

## Mesh update on launch.
func _init(make:={}):
	if make.size()>0:
		_uv_type = make.get("uv_type",_uv_type);
		edge_count = make.get("edge_count",edge_count)
		#clean_up_triangles = make.get("clean_up_triangles",clean_up_triangles)
		heigth = make.get("height",heigth)
		radius = make.get("radius",radius)
		lookup = {}
		update_mesh(make.get("arrays",[]))
	else:
		lookup = {}
		update_mesh()

## Method that scales vertices of mesh.
func apply_size():
	var new_vertices : PackedVector3Array = []
	for i in vertices.size():
		new_vertices.push_back(Vector3(vertices[i].x * radius,vertices[i].y * heigth*0.5,vertices[i].z * radius))
	return new_vertices

## Mesh update function.
## Launches after any property change.
##
func update_mesh(arrays:=[]):
	if lookup.has("block"): return #update blockirator
	## Save materials
	vertices=[] ##reset vertices
	var materials = []
	for i in get_surface_count(): 
		materials.append(surface_get_material(i))
	## Initialize base values
	clear_surfaces()
	if _uv_type==1:
		## Square UV mode
		var offset=Vector3.ONE*4
		for i in 4: # Five separate segments
			vertices.append_array([core_vertices[0],  core_vertices[1],
								   core_vertices[2+i],core_vertices[3+i],])
			triangles.append_array([core_triangles[0]+offset*i,core_triangles[1]+offset*i])
			# Square type UV preparation
			uvs.append_array(square_uvs.duplicate().map(func(x):x.x = x.x+1/4.*i;return x))
		# Surface divider
		if edge_count>1:
			triangles=subdivide(edge_count-1)
	else:
		## Sphere UV mode
		vertices = core_vertices.duplicate()
		vertices.resize(6)# required to remove last two (unneeded for sphere_uv mode) core_vertices
		triangles = core_triangles.duplicate()
		# Surface divider
		if edge_count>1:
			triangles=subdivide(edge_count-1)
		# Full Sphere type UV build
		if _uv_type==0:
			for vertice in vertices:
				uvs.push_back(gen_uv(vertice))
			# UV fixers
			fix_zipper()
			fix_poles()
	## Convert tiangles to PoolIntArray
	var triangles_pi : PackedInt32Array = []
	for triangle in triangles:
		triangles_pi.push_back(triangle[0])
		triangles_pi.push_back(triangle[1])
		triangles_pi.push_back(triangle[2])
	## Initialize the ArrayMesh.
	#var arrays = []
	arrays.resize(ArrayMesh.ARRAY_MAX)
	arrays[ArrayMesh.ARRAY_VERTEX] = apply_size()# Auto scale vertices
	arrays[ArrayMesh.ARRAY_INDEX] = triangles_pi
	if _uv_type != 2: ##Disable UV mapping for custom UVW mode
		arrays[ArrayMesh.ARRAY_TEX_UV]= uvs.duplicate()
	arrays[ArrayMesh.ARRAY_NORMAL]= vertices.duplicate() #normals here are equal to vertices
	## Create the Mesh
	add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	## Regen materials
	for i in materials.size():
		surface_set_material(i,materials[i])
	## Memory Cleanup
	triangles = []
	uvs = []
	lookup = {}
	emit_changed()

## This method required to prevent vertices dublication
## Good for mesh optimisation
##
func lookup_for_array(first:int,second:int,divs:int):
	var key = [first,second]# keys
	var inv_key = [second,first]
	# array generator
	if not (lookup.has(key) or lookup.has(inv_key)):
		var array = []# array with vertices ids
		array.push_back(first)# first vertice
		for j in divs:
			array.push_back(vertices.size())# middle vertices
			vertices.push_back((vertices[first]*(divs+1-(j+1)) + vertices[second]*(j+1)).normalized())
			if _uv_type==1:# UV generator(subdivider) for Square_UV mode
				uvs.push_back((uvs[first]*(divs+1-(j+1)) + uvs[second]*(j+1))/(divs+1))
		array.push_back(second)# last vertice
		lookup[key]=array # upload in lookup array
	# array provider
	if lookup.has(key): return lookup[key]# default array
	if lookup.has(inv_key):# inversed array
		var temp = lookup[inv_key].duplicate()
		temp.reverse()
		return temp 
	#assert(false,"Lookup error! Array not found!")# was required for debuging...

## Better core triangle subdivider method.
## As described before default subdivide() method uses next formula: triangles=2^(divs+1)
## But this method has next formula: triangls = divs^2
## And that formula allows you to create much more different Octaspheres than with default one.
##
func subdivide(divs:int):
	lookup = {}
	var new_triangles : PackedVector3Array = []
	for triangle in triangles: # for each triangle in array
		# base two edges that used for generation 
		var arr_1_2 = lookup_for_array(triangle[0],triangle[1],divs)
		var arr_1_3 = lookup_for_array(triangle[0],triangle[2],divs)
		for j in divs+1:# upload midle points and triangles into array(+1 for last triangles "string")
			var point_arr=lookup_for_array(arr_1_2[j+1],arr_1_3[j+1],j)
			var old_arr=lookup_for_array(arr_1_2[j],arr_1_3[j],j-1) if j>0 else [arr_1_3[j]]
			for k in j:# works only if vertices "string" has middle points
				new_triangles.push_back(Vector3(old_arr[k],point_arr[k],point_arr[k+1]))
				new_triangles.push_back(Vector3(old_arr[k],point_arr[k+1],old_arr[k+1]))
			# last triangle in triangles "string"
			new_triangles.push_back(Vector3(old_arr[old_arr.size()-1],point_arr[point_arr.size()-2],point_arr[point_arr.size()-1]))
	return new_triangles

## Generates base UV coords of UV-Sphere
func gen_uv(vertice):
	# Base formula. Was changed to make Octasphere behaviour simular to default godot sphere behaviour
	#return Vector2(0.5+atan2(vertice.z,vertice.x)/(2 * PI),0.5-asin(vertice.y)/PI)
	return Vector2(0.5-atan2(vertice.z,vertice.x)/(2 * PI),0.5-asin(vertice.y)/PI)

## Required to fix zipper artefact that appear on the end of UV map.
## 
func fix_zipper():
	var warped = []
	var checkedVert = {}
	## find zipper
	for i in triangles.size():
		var triangle = triangles[i]
		var coordA = gen_uv(vertices[triangle[0]])
		var coordB = gen_uv(vertices[triangle[1]])
		var coordC = gen_uv(vertices[triangle[2]])
		var a = coordB - coordA
		var b = coordC - coordA
		var texNormal = Vector3(a.x,a.y,0).cross(Vector3(b.x,b.y,0))
		#if texNormal.z > 0: #изменено для большей похожести на godot UV-sphere
		if texNormal.z < 0: 
			warped.push_back(i)
	## fix zipper
	for i in warped.size():
		var triangle = triangles[warped[i]]
		var coordA = gen_uv(vertices[triangle[0]]).x
		var coordB = gen_uv(vertices[triangle[1]]).x
		var coordC = gen_uv(vertices[triangle[2]]).x
		if coordA < 0.25:
			var new = triangle[0]
			if not checkedVert.has(new):
				var idx = vertices.size()
				checkedVert[new]= idx
				vertices.push_back(vertices[new]);#copy
				var n_uv=uvs[new]
				n_uv.x+=1.
				uvs.push_back(n_uv)#create new uv
				new = idx
			else: 
				new = checkedVert[new]
			triangles[warped[i]][0]=new
		if coordB < 0.25:
			var new = triangle[1]
			if not checkedVert.has(new):
				var idx = vertices.size()
				checkedVert[new]= idx
				vertices.push_back(vertices[new]);#copy
				var n_uv=uvs[new]
				n_uv.x+=1.
				uvs.push_back(n_uv)#create new uv
				new = idx
			else: 
				new = checkedVert[new]
			triangles[warped[i]][1]=new
		if coordC < 0.25:
			var new = triangle[2]
			if not checkedVert.has(new):
				var idx = vertices.size()
				checkedVert[new]= idx
				vertices.push_back(vertices[new]);#copy
				var n_uv=uvs[new]
				n_uv.x+=1.
				uvs.push_back(n_uv)#create new uv
				new = idx
			else: 
				new = checkedVert[new]
			triangles[warped[i]][2]=new

## Required to fix "zipper" at north and south poles
func fix_poles():
	for i in triangles.size():
		if triangles[i][0]==1:
			vertices.push_back(vertices[triangles[i][0]])
			var n_uv=uvs[triangles[i][0]]
			# Base formula. For some reason can't work in this situation
			#n_uv.x = (gen_uv(vertices[triangles[i][2]]).x + gen_uv(vertices[triangles[i][1]]).x)/2.0
			n_uv.x = gen_uv(vertices[triangles[i][2]]).x+0.09 # my working solution.
			# 0.09 was found experimentally
			uvs.push_back(n_uv)
			triangles[i][0]=vertices.size()-1
		if triangles[i][0]==0:
			vertices.push_back(vertices[triangles[i][0]])
			var n_uv=uvs[triangles[i][0]]
			n_uv.x = gen_uv(vertices[triangles[i][1]]).x+0.09# another angle
			uvs.push_back(n_uv)
			triangles[i][0]=vertices.size()-1
#endregion
