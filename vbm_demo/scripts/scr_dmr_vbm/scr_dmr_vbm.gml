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
	vb = [];	// Vertex buffers
	vbmap = {};	// {vbname: vertex_buffer} for each vb
	vbnames = [];	// Names corresponding to buffers
	vbnamemap = {};	// Names to indices
	vbcount = 0;
	
	bone_parentindices = [];	// Parent transform corresponding to each bone
	bone_localmatricies = [];	// Local transform corresponding to each bone
	bone_inversematricies = [];	// Inverse transform corresponding to each bone
	bonemap = {};	// {bonename: index} for each bone
	bonenames = [];
	bonecount = 0;
	
	vbformat = -1;	// Vertex Buffer Format created in OpenVBM() (Don't touch!)
	
	// Returns vertex buffer with given name. -1 if not found
	static FindVB = function(_name)
	{
		var i = variable_struct_get(vbmap, _name);
		return is_undefined(i)? -1: i;
	}
	
	// Returns index of vb with given name. -1 if not found
	static FindVBIndex = function(_name)
	{
		var i = 0; repeat(vbcount)
		{
			if vbnames[i] == _name {return i;}
			i++;
		}
		return -1;
	}
	
	// Returns index if vb contains given name. -1 if not found
	static FindVBIndex_Contains = function(_name)
	{
		var i = 0; repeat(vbcount)
		{
			if string_pos(_name, vbnames[i]) {return i;}
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
	
	// Submits vertex buffer using index
	static SubmitVBIndex = function(vbindex, prim=pr_trianglelist, texture=-1)
	{
		if (vbcount > 0)
		{
			// Positive number, normal index
			if (vbindex >= 0 && vbindex < vbcount)
			{
				vertex_submit(vb[vbindex], prim, texture);
			}
			// Negative number, start from end of list
			else if (vbindex < 0 && (vbcount+vbindex) < vbcount)
			{
				vertex_submit(vb[vbcount+vbindex], prim, texture);
			}
		}
	}
	
	// Submits vertex buffer using name
	static SubmitVBKey = function(vbname, prim=pr_trianglelist, texture=-1)
	{
		if (vbcount > 0)
		{
			// Name exists
			if ( variable_struct_exists(vbmap, vbname) )
			{
				vertex_submit(vbmap[$ vbname], prim, texture);
			}
		}
	}
	
	static AddVB = function(vb, vbname)
	{
		vb[vbcount] = vb;
		vbmap[$ vbname] = vb;
		vbnames[vbcount] = vbname;
		vbnamemap[$ vbname] = vbcount;
		vbcount += 1;	
	}
}

// Removes allocated memory from vbm
function VBMFree(vbm)
{
	var n = vbm.vbcount;
	var vbuffers = vbm.vb;
	for (var i = 0; i < n; i++)
	{
		vertex_delete_buffer(vbuffers[i]);
	}
	
	if vbm.vbformat > -1
	{
		vertex_format_delete(vbm.vbformat);	
	}
}

// Returns vertex buffer from file (.vb)
function OpenVertexBuffer(path, format, freeze=true)
{
	var bzipped = buffer_load(path);
	var b = bzipped;
	
	// error reading file
	if bzipped < 0
	{
		show_debug_message("OpenVertexBuffer(): Error loading vertex buffer from \"" + path + "\"");
		return -1;
	}
	
	// Check for compression
	if (buffer_peek(bzipped, 0, buffer_u8) == 0x78)
	{
		var b = buffer_decompress(bzipped);
		if b < 0 {b = bzipped;} else {buffer_delete(bzipped);}
	}
	
	var vb = vertex_create_buffer_from_buffer(b, format);
	
	if freeze {vertex_freeze(vb);}
	
	return vb;
}

// Runs appropriate version function and returns vbm struct from file (.vbm)
// Returns true on success, false for error
function OpenVBM(outvbm, path, format=-1, freeze=true)
{
	if (filename_ext(path) == "")
	{
		path = filename_change_ext(path, ".vbm");	
	}
	
	var bzipped = buffer_load(path);
	
	if (bzipped < 0)
	{
		show_debug_message("OpenVBM(): Error loading vbm data from \"" + path + "\"");
		return outvbm;
	}
	
	var b = buffer_decompress(bzipped);
	if (b < 0) {b = bzipped;} else {buffer_delete(bzipped);}
	
	var header;
	
	// Header
	header = buffer_peek(b, 0, buffer_u32);
	
	// Not a vbm file
	if ( (header & 0x00FFFFFF) != VBMHEADERCODE )
	{
		var noformatgiven = format < 0;
		
		// Maybe it's a vertex buffer?
		if ( !noformatgiven )
		{
			var vb = vertex_create_buffer_from_buffer(b, format);
			if ( vb < 0 )
			{
				show_debug_message("OpenVBM(): data is normal vb? \"" + path + "\"");
				return -1;
			}
			
			var name = filename_name(path);
			outvbm.AddVB(vb, name);
			return outvbm;
		}
		
		show_debug_message("OpenVBM(): header is invalid \"" + path + "\"");
		return outvbm;
	}
	
	switch(header & 0xFF)
	{
		default:
		
		// Version 1
		case(1): 
			return __VBMOpen_v1(outvbm, b, format, freeze);
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
function __VBMOpen_v1(outvbm, b, format, freeze)
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
		vbnames[vbcount]
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
	if noformatgiven
	{
		format = GetVBMFormat(b, buffer_tell(b));
	}
	
	buffer_seek(b, buffer_seek_relative, buffer_read(b, buffer_u8)*2);
	
	#region // Vertex Buffers ==================================================
	
	vbcount = buffer_read(b, buffer_u32);
	outvbm.vbcount = vbcount;
	array_resize(outvbm.vbnames, vbcount);
	
	// VB Names ------------------------------------------------------------
	for (var i = 0; i < vbcount; i++) 
	{
		name = "";
		namelength = buffer_read(b, buffer_u8);
		repeat(namelength)
		{
			name += chr(buffer_read(b, buffer_u8));
		}
		outvbm.vbnames[i] = name;
		outvbm.vbnamemap[$ name] = i;
	}
	
	// VB Data -------------------------------------------------------------
	for (var i = 0; i < vbcount; i++)
	{
		var vbuffersize = buffer_read(b, buffer_u32);
		var numvertices = buffer_read(b, buffer_u32);
		
		// Create vb
		vb = vertex_create_buffer_from_buffer_ext(b, format, buffer_tell(b), numvertices);
		
		if freeze {vertex_freeze(vb);}
		outvbm.vb[i] = vb;
		outvbm.vbmap[$ outvbm.vbnames[i]] = vb;
		
		// move to next vb
		buffer_seek(b, buffer_seek_relative, vbuffersize);
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
		outvbm.vbformat = format;
		
		// Apparently formats need to stay in memory...
		//vertex_format_delete(format);
	}
	
	return outvbm;
}

