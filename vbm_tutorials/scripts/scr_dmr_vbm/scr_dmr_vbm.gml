/*
	VBM definition and functions.
	By Dreamer13sq
*/

#macro VBMHEADERCODE 0x004D4256

// Max number of bones for pose matrix array
#macro VBM_MATPOSEMAX 200

#macro VBM_MAT4ARRAYFLAT global.g_mat4identityflat
#macro VBM_MAT4ARRAY2D global.g_mat4identity2d

VBM_MAT4ARRAYFLAT = array_create(16*VBM_MATPOSEMAX);
VBM_MAT4ARRAY2D = array_create(VBM_MATPOSEMAX);

for (var i = 0; i < VBM_MATPOSEMAX; i++)
{
	array_copy(VBM_MAT4ARRAYFLAT, i*16, matrix_build_identity(), 0, 16);
	VBM_MAT4ARRAY2D[i] = matrix_build_identity();
}

enum VBM_AttributeType
{
	_other = 0,
	
	position3d = 1,
	uv = 2,
	normal = 3,
	color = 4,
	colorbytes = 5,
	
	weight = 6,
	weightbytes = 7,
	bone = 8,
	bonebytes = 9,
	tangent = 10,
	bitangent = 11,
	vertexgroup = 12,
}

/*
	GM mat index ref:
	[
		 0,  4,  8, 12,	| (x)
		 1,  5,  9, 13,	| (y)
		 2,  6, 10, 14,	| (z)
		 3,  7, 11, 15	|
		----------------
		(0) (0) (0)     
	]
*/

function VBMData() constructor 
{
	vertexbuffers = [];	// Vertex buffers
	vertexbuffermap = {};	// {vbname: vertex_buffer} for each vb
	vertexbuffernames = [];	// Names corresponding to buffers
	vertexbuffernamemap = {};	// Names to indices
	vertexbuffercount = 0;
	
	bone_parentindices = [];	// Parent transform corresponding to each bone
	bone_localmatricies = [];	// Local transform corresponding to each bone
	bone_inversematricies = [];	// Inverse transform corresponding to each bone
	bonemap = {};	// {bonename: index} for each bone
	bonenames = [];
	bonecount = 0;
	
	vertexformat = -1;	// Vertex Buffer Format created in OpenVBM() (Don't touch!)
	
	// Accessors -------------------------------------------------------------------
	
	static Count = function() {return vertexbuffercount;}
	static Names = function() {return vertexbuffernames;}
	static GetVertexBuffer = function(index) {return vertexbuffers[index];}
	static GetName = function(index) {return vertexbuffernames[index];}
	
	static BoneCount = function() {return bonecount;}
	static BoneNames = function() {return bonenames;}
	static BoneParentIndices = function() {return bone_parentindices;}
	static BoneLocalMatrices = function() {return bone_localmatricies;}
	static BoneInverseMatrices = function() {return bone_inversematricies;}
	static GetBoneName = function(index) {return bonenames[index];}
	
	static Format = function() {return vertexformat;}
	
	// Methods -------------------------------------------------------------------
	
	static toString = function()
	{
		return "VBMData: {" +string(vertexbuffercount)+" vbs, " + string(bonecount) + " bones" + "}";
	}
	
	static Open = function(path, format=-1, freeze=true)
	{
		OpenVBM(self, path, format, freeze);
		return self;
	}
	
	// Removes all dynamic data from struct
	static Clear = function()
	{
		ClearVertexBuffers();
		ClearBones();
		
		// Delete format
		if vertexformat > -1
		{
			vertex_format_delete(vertexformat);	
		}
	}
	
	// Removes vertex buffer data
	static ClearVertexBuffers = function()
	{
		// Free buffers
		for (var i = 0; i < vertexbuffercount; i++)
		{
			vertex_delete_buffer(vertexbuffers[i]);
		}
		
		array_resize(vertexbuffers, 0);
		array_resize(vertexbuffernames, 0);
		
		vertexbuffermap = {};
		vertexbuffernamemap = {};
		vertexbuffercount = 0;
	}
	
	// Removes bone data
	static ClearBones = function()
	{
		array_resize(bone_parentindices, 0);
		array_resize(bone_localmatricies, 0);
		array_resize(bone_inversematricies, 0);
		array_resize(bonenames, 0);
		
		bonemap = {};
		bonecount = 0;
	}
	
	// Returns vertex buffer with given name. -1 if not found
	static FindVB = function(_name)
	{
		var i = variable_struct_get(vertexbuffermap, _name);
		return is_undefined(i)? -1: i;
	}
	
	// Returns index of vb with given name. -1 if not found
	static FindVBIndex = function(_name)
	{
		var i = 0; repeat(vertexbuffercount)
		{
			if vertexbuffernames[i] == _name {return i;}
			i++;
		}
		return -1;
	}
	
	// Returns index if vb contains given name. -1 if not found
	static FindVBIndex_Contains = function(_name)
	{
		var i = 0; repeat(vertexbuffercount)
		{
			if string_pos(_name, vertexbuffernames[i]) {return i;}
			i++;
		}
		return -1;
	}
	
	// Returns bone index from given name. -1 if not found
	static FindBone = function(_name)
	{
		var i = variable_struct_get(bonemap, _name);
		return is_undefined(i)? -1: i;
	}
	
	// Submits all vertex buffers
	static Submit = function(prim=pr_trianglelist, texture=-1)
	{
		var i = 0;
		repeat(vertexbuffercount)
		{
			vertex_submit(vertexbuffers[i++], prim, texture);
		}
	}
	
	// Submits vertex buffer using index
	static SubmitVBIndex = function(vbindex, prim=pr_trianglelist, texture=-1)
	{
		if (vertexbuffercount > 0)
		{
			// Positive number, normal index
			if (vbindex >= 0 && vbindex < vertexbuffercount)
			{
				vertex_submit(vertexbuffers[vbindex], prim, texture);
			}
			// Negative number, start from end of list
			else if (vbindex < 0 && (vertexbuffercount+vbindex) < vertexbuffercount)
			{
				vertex_submit(vertexbuffers[vertexbuffercount+vbindex], prim, texture);
			}
		}
	}
	
	// Submits vertex buffer using name
	static SubmitVBKey = function(vbname, prim=pr_trianglelist, texture=-1)
	{
		if (vertexbuffercount > 0)
		{
			// Name exists
			if ( variable_struct_exists(vertexbuffermap, vbname) )
			{
				vertex_submit(vertexbuffermap[$ vbname], prim, texture);
			}
		}
	}
	
	static AddVB = function(vb, vbname)
	{
		vertexbuffers[vertexbuffercount] = vb;
		vertexbuffermap[$ vbname] = vb;
		vertexbuffernames[vertexbuffercount] = vbname;
		vertexbuffernamemap[$ vbname] = vertexbuffercount;
		vertexbuffercount += 1;	
	}
	
}

// Removes allocated memory from vbm
function VBMFree(vbm)
{
	vbm.Clear();
}

// Returns vertex buffer from file (.vb)
function OpenVertexBuffer(path, format, freeze=true)
{
	var bzipped = buffer_load(path);
	var b = bzipped;
	
	// File doesn't exist
	if ( !file_exists(path) )
	{
		show_debug_message("OpenVertexBuffer(): File does not exist. \"" + path + "\"");
		return -1;
	}
	
	// error reading file
	if (bzipped < 0)
	{
		show_debug_message("OpenVertexBuffer(): Error loading vertex buffer from \"" + path + "\"");
		return -1;
	}
	
	// Check for compression headers
	var _header = buffer_peek(bzipped, 0, buffer_u8) | (buffer_peek(bzipped, 1, buffer_u8) << 8);
	if (
		(_header & 0x0178) == 0x0178 ||
		(_header & 0x9C78) == 0x9C78 ||
		(_header & 0xDA78) == 0xDA78
		)
	{
		var b = buffer_decompress(bzipped);
		buffer_delete(bzipped);
	}
	
	var vb = vertex_create_buffer_from_buffer(b, format);
	
	// Freeze buffer to improve performance
	if (freeze) {vertex_freeze(vb);}
	
	buffer_delete(b);
	
	return vb;
}

// Runs appropriate version function and returns vbm struct from file (.vbm)
// Returns true on success, false for error
function OpenVBM(outvbm, path, format=-1, freeze=true, merge=false)
{
	if (filename_ext(path) == "")
	{
		path = filename_change_ext(path, ".vbm");	
	}
	
	// File doesn't exist
	if ( !file_exists(path) )
	{
		show_debug_message("OpenVBM(): File does not exist. \"" + path + "\"");
		return -1;
	}
	
	var bzipped = buffer_load(path);
	var b = bzipped;
	
	// error reading file
	if (bzipped < 0)
	{
		show_debug_message("OpenVBM(): Error loading vbm data from \"" + path + "\"");
		return -1;
	}
	
	// Check for compression headers
	var _header = buffer_peek(bzipped, 0, buffer_u8) | (buffer_peek(bzipped, 1, buffer_u8) << 8);
	if (
		(_header & 0x0178) == 0x0178 ||
		(_header & 0x9C78) == 0x9C78 ||
		(_header & 0xDA78) == 0xDA78
		)
	{
		var b = buffer_decompress(bzipped);
		buffer_delete(bzipped);
	}
	
	var vbmheader;
	
	// Header
	vbmheader = buffer_peek(b, 0, buffer_u32);
	
	// Not a vbm file
	if ( (vbmheader & 0x00FFFFFF) != VBMHEADERCODE )
	{
		var noformatgiven = format < 0;
		
		// Maybe it's a vertex buffer?
		if ( !noformatgiven )
		{
			var vb = vertex_create_buffer_from_buffer(b, format);
			
			if ( vb >= 0 )
			{
				if (freeze) {vertex_freeze(vb);}
				var name = filename_name(path);
				outvbm.AddVB(vb, name);
				return outvbm;
			}
		}
		
		show_debug_message("OpenVBM(): header is invalid \"" + path + "\"");
		return outvbm;
	}
	
	switch(vbmheader & 0xFF)
	{
		default:
		
		// Version 1
		case(1): 
			return __VBMOpen_v1(outvbm, b, format, freeze, merge);
	}
	
	return outvbm;
}

// Returns true if buffer contains vbm header
function BufferIsVBM(b, offset=0)
{
	if ( buffer_get_size(b) >= offset+4 )
	{
		var header = "";
		for (var i = 0; i < 3; i++)
		{
			header += chr( buffer_peek(b, offset+i, buffer_u8) );
		}
		if header == "VBM" {return true;}
	}
	
	return false;
}

// Returns vbm format from buffer
function GetVBMFormat(b, offset)
{
	var numattributes = buffer_peek(b, offset, buffer_u8);
	offset += 1;
	
	vertex_format_begin();
	
	var attributetype;
	var attributesize;
	
	repeat(numattributes)
	{
		attributetype = buffer_peek(b, offset, buffer_u8);
		offset += 1;
		attributesize = buffer_peek(b, offset, buffer_u8);
		offset += 1;
		
		switch(attributetype)
		{
			// Native types
			case(VBM_AttributeType.position3d):
				vertex_format_add_position_3d(); break;
			case(VBM_AttributeType.uv):
				vertex_format_add_texcoord(); break;
			case(VBM_AttributeType.normal):
				vertex_format_add_normal(); break;
			case(VBM_AttributeType.colorbytes):
			case(VBM_AttributeType.bonebytes):
			case(VBM_AttributeType.weightbytes):
				vertex_format_add_color(); break;
			
			// Non native types
			default:
				switch(attributesize)
				{
					case(1): vertex_format_add_custom(vertex_type_float1, vertex_usage_texcoord); break;
					case(2): vertex_format_add_custom(vertex_type_float2, vertex_usage_texcoord); break;
					case(3): vertex_format_add_custom(vertex_type_float3, vertex_usage_texcoord); break;
					case(4): vertex_format_add_custom(vertex_type_float4, vertex_usage_texcoord); break;
				}
				break;
		}
	}
		
	return vertex_format_end();
}

// Returns vbm struct from file (.vbm)
function __VBMOpen_v1(outvbm, b, format, freeze, merge)
{
	/* Vertex Buffer Collection v1 File spec:
		'VBM' (3B)
		VBM version = 1 (1B)
    
		flags (1B)

		formatlength (1B)
		formatentry[formatlength]
		    attributetype (1B)
		    attributefloatsize (1B)

		vbcount (1I)
		vertexbuffernames[vbcount]
		    namelength (1B)
		    namechars[namelength]
		        char (1B)
		vbdata[vbcount]
		    vbcompressedsize (1L)
		    vbcompresseddata (vbcompressedsize B)

		bonecount (1I)
		bonenames[bonecount]
		    namelength (1B)
		    namechars[namelength]
		        char (1B)
		parentindices[bonecount] 
		    parentindex (1I)
		localmatrices[bonecount]
		    mat4 (16f)
		inversemodelmatrices[bonecount]
		    mat4 (16f)
	*/
	
	var flag;
	var bonecount;
	var vbcount;
	var appendcount;
	var namelength;
	var name;
	var mat;
	var vb;
	var targetmats;
	var i, j;
	var noformatgiven = format < 0;
	
	// Header
	buffer_read(b, buffer_u32);
	
	flag = buffer_read(b, buffer_u8);
	
	// Vertex Format
	if (noformatgiven)
	{
		format = GetVBMFormat(b, buffer_tell(b));
	}
	
	buffer_seek(b, buffer_seek_relative, buffer_read(b, buffer_u8)*2);
	
	#region // Vertex Buffers ==================================================
	
	vbcount = buffer_read(b, buffer_u32);
	
	if (merge)
	{
		appendcount = 1;
	}
	else
	{
		appendcount = vbcount;
	}
	
	outvbm.vertexbuffercount += appendcount;
	array_resize(outvbm.vertexbuffernames, outvbm.vertexbuffercount);
	
	// VB Names ------------------------------------------------------------
	for (var i = 0; i < appendcount; i++) 
	{
		name = "";
		namelength = buffer_read(b, buffer_u8);
		repeat(namelength)
		{
			name += chr(buffer_read(b, buffer_u8));
		}
		outvbm.vertexbuffernames[i] = name;
		outvbm.vertexbuffernamemap[$ name] = i;
	}
	
	// Skip rest of names if merge is true
	repeat(vbcount-appendcount)
	{
		name = "";
		namelength = buffer_read(b, buffer_u8);
		repeat(namelength)
		{
			name += chr(buffer_read(b, buffer_u8));
		}
	}
	
	// VB Data -------------------------------------------------------------
	if (!merge)
	{
		for (var i = 0; i < vbcount; i++)
		{
			var vbuffersize = buffer_read(b, buffer_u32);
			var numvertices = buffer_read(b, buffer_u32);
		
			// Create vb
			vb = vertex_create_buffer_from_buffer_ext(b, format, buffer_tell(b), numvertices);
		
			if freeze {vertex_freeze(vb);}
			outvbm.vertexbuffers[i] = vb;
			outvbm.vertexbuffermap[$ outvbm.vertexbuffernames[i]] = vb;
		
			// move to next vb
			buffer_seek(b, buffer_seek_relative, vbuffersize);
		}
	}
	// Merge VBs
	else
	{
		var bb = buffer_create(0, buffer_grow, 1);
		
		for (var i = 0; i < vbcount; i++)
		{
			var vbuffersize = buffer_read(b, buffer_u32);
			var numvertices = buffer_read(b, buffer_u32);
			
			// Copy vb data
			buffer_resize(bb, buffer_get_size(bb)+vbuffersize);
			buffer_copy(b, buffer_tell(b), vbuffersize, bb, buffer_get_size(bb)-vbuffersize);
			
			// move to next vb
			buffer_seek(b, buffer_seek_relative, vbuffersize);
		}
		
		vb = vertex_create_buffer_from_buffer(bb, format);
		
		outvbm.vertexbuffers[0] = vb;
		outvbm.vertexbuffermap[$ outvbm.vertexbuffernames[0]] = vb;
		
		if freeze {vertex_freeze(vb);}
		
		buffer_delete(bb);
	}
	
	#endregion -------------------------------------------------------------
	
	#region // Bones ===========================================================
	
	bonecount = buffer_read(b, buffer_u32);
	outvbm.bonecount = bonecount;
	array_resize(outvbm.bonenames, bonecount);
	array_resize(outvbm.bone_parentindices, bonecount);
	array_resize(outvbm.bone_localmatricies, bonecount);
	array_resize(outvbm.bone_inversematricies, bonecount);
	
	// Bone Names ----------------------------------------------------------
	for (var i = 0; i < bonecount; i++) 
	{
		name = "";
		namelength = buffer_read(b, buffer_u8);
		repeat(namelength)
		{
			name += chr(buffer_read(b, buffer_u8));
		}
		outvbm.bonenames[i] = name;
		outvbm.bonemap[$ name] = i;
	}
	
	// Parent Indices ------------------------------------------------------
	targetmats = outvbm.bone_parentindices;
	i = 0; repeat(bonecount)
	{
		targetmats[@ i++] = buffer_read(b, buffer_u32);
	}
	
	// Local Matrices ------------------------------------------------------
	targetmats = outvbm.bone_localmatricies;
	i = 0; repeat(bonecount)
	{
		mat = array_create(16);
		j = 0; repeat(16)
		{
			mat[j++] = buffer_read(b, buffer_f32);
		}
		targetmats[@ i++] = mat;
	}
	
	// Inverse Model Matrices ----------------------------------------------
	targetmats = outvbm.bone_inversematricies;
	i = 0; repeat(bonecount)
	{
		mat = array_create(16);
		j = 0; repeat(16)
		{
			mat[j++] = buffer_read(b, buffer_f32);
		}
		targetmats[@ i++] = mat;
	}
	
	#endregion -------------------------------------------------------------
	
	buffer_delete(b);
	
	// Keep Temporary format
	if (noformatgiven)
	{
		outvbm.vertexformat = format;
		
		// Apparently formats need to stay in memory...
		//vertex_format_delete(format);
	}
	
	return outvbm;
}

