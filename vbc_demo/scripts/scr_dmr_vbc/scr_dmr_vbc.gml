/*
	VBC class definition and functions.
	By Dreamer13sq
*/

#macro VBCHEADERCODE 0x00434256

#macro DMRVBC_MATPOSEMAX 200
#macro DMRVBC_MAT4ARRAYFLAT global.g_mat4identityflat
#macro DMRVBC_MAT4ARRAY2D global.g_mat4identity2d

DMRVBC_MAT4ARRAYFLAT = array_create(16*DMRVBC_MATPOSEMAX);
DMRVBC_MAT4ARRAY2D = array_create(DMRVBC_MATPOSEMAX);

for (var i = 0; i < DMRVBC_MATPOSEMAX; i++)
{
	array_copy(DMRVBC_MAT4ARRAYFLAT, i*16, matrix_build_identity(), 0, 16);
	DMRVBC_MAT4ARRAY2D[i] = matrix_build_identity();
}

enum VBC_AttributeType
{
	_other = 0,
	
	position3d = 1,
	uv = 2,
	normal = 3,
	color = 4,
	colorbytes = 5,
	
	weight = 6,
	weightindex = 7,
	tangent = 8,
	bitangent = 9,
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

function VBCData() constructor 
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
	
	vbformat = -1;	// Vertex Buffer Format created in OpenVBC() (Don't touch!)
	
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

// Removes allocated memory from vbc
function VBCFree(vbc)
{
	var n = vbc.vbcount;
	var vbuffers = vbc.vb;
	for (var i = 0; i < n; i++)
	{
		vertex_delete_buffer(vbuffers[i]);
	}
	
	if vbc.vbformat > -1
	{
		vertex_format_delete(vbc.vbformat);	
	}
}

// Returns vertex buffer from file (.vb)
function OpenVertexBuffer(path, format, freeze=true)
{
	var bzipped = buffer_load(path);
	
	// error reading file
	if bzipped < 0
	{
		show_debug_message("OpenVertexBuffer(): Error loading vertex buffer from \"" + path + "\"");
		return -1;
	}
	
	var b = buffer_decompress(bzipped);
	if b < 0 {b = bzipped;} else {buffer_delete(bzipped);}
	
	var vb = vertex_create_buffer_from_buffer(b, format);
	
	if freeze {vertex_freeze(vb);}
	
	return vb;
}

// Runs appropriate version function and returns vbc struct from file (.vbc)
function OpenVBC(path, format=-1, freeze=true)
{
	if filename_ext(path) == ""
	{
		path = filename_change_ext(path, ".vbc");	
	}
	
	var bzipped = buffer_load(path);
	
	if bzipped < 0
	{
		show_debug_message("OpenVBC(): Error loading vbc data from \"" + path + "\"");
		return -1;
	}
	
	var b = buffer_decompress(bzipped);
	if b < 0 {b = bzipped;} else {buffer_delete(bzipped);}
	
	var header;
	
	// Header
	header = buffer_peek(b, 0, buffer_u32);
	
	// Not a vbc file
	if ( (header & 0x00FFFFFF) != VBCHEADERCODE )
	{
		var vbc = new VBCData();
		var noformatgiven = format < 0;
		
		// Maybe it's a vertex buffer?
		if ( !noformatgiven )
		{
			var vb = vertex_create_buffer_from_buffer(b, format);
			if ( vb < 0 )
			{
				show_debug_message("OpenVBC(): data is normal vb? \"" + path + "\"");
				return -1;
			}
			
			var name = filename_name(path);
			vbc.AddVB(vb, name);
			return vbc;
		}
		
		show_debug_message("OpenVBC(): header is invalid \"" + path + "\"");
		return vbc;
	}
	
	switch(header & 0xFF)
	{
		default:
		
		// Version 1
		case(1): 
			return __VBCOpen_v1(b, format, freeze);
	}
	
	return -1;
}

// Returns true if buffer contains vbc header
function BufferIsVBC(b, offset=0)
{
	if ( buffer_get_size(b) >= offset+4 )
	{
		var header = "";
		for (var i = 0; i < 3; i++)
		{
			header += chr( buffer_peek(b, offset+i, buffer_u8) );
		}
		if header == "VBC" {return true;}
	}
	
	return false;
}

// Returns vbc format from buffer
function GetVBCFormat(b, offset)
{
	var numattributes = buffer_peek(b, offset, buffer_u8);
	offset += 1;
	
	//printf("Attribute Count: %s", numattributes);
	
	vertex_format_begin();
	
	var attributetype;
	var attributesize;
	
	repeat(numattributes)
	{
		attributetype = buffer_peek(b, offset, buffer_u8);
		offset += 1;
		attributesize = buffer_peek(b, offset, buffer_u8);
		offset += 1;
			
		//printf("AttribType: %s %s", attributetype, attributesize);
			
		switch(attributetype)
		{
			// Native types
			case(VBC_AttributeType.position3d):
				vertex_format_add_position_3d(); break;
			case(VBC_AttributeType.uv):
				vertex_format_add_texcoord(); break;
			case(VBC_AttributeType.normal):
				vertex_format_add_normal(); break;
			case(VBC_AttributeType.colorbytes):
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

// Returns vbc struct from file (.vbc)
function __VBCOpen_v1(b, format, freeze)
{
	/* File spec:
		
	
	*/
	
	var outvbc = new VBCData();
	
	var flag;
	var floattype;
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
	
	// Float Type
	switch(flag & 3)
	{
		default:
		case(0): floattype = buffer_f32; break;
		case(1): floattype = buffer_f64; break;
		case(2): floattype = buffer_f16; break;
	}
	
	// Vertex Format
	if noformatgiven
	{
		format = GetVBCFormat(b, buffer_tell(b));
	}
	
	buffer_seek(b, buffer_seek_relative, buffer_read(b, buffer_u8)*2);
	
	#region // Vertex Buffers ==============================================
	
	vbcount = buffer_read(b, buffer_u16);
	outvbc.vbcount = vbcount;
	array_resize(outvbc.vbnames, vbcount);
	
	for (var i = 0; i < vbcount; i++) // VB Names
	{
		name = "";
		namelength = buffer_read(b, buffer_u8);
		repeat(namelength)
		{
			name += chr(buffer_read(b, buffer_u8));
		}
		outvbc.vbnames[i] = name;
		outvbc.vbnamemap[$ name] = i;
	}
	
	for (var i = 0; i < vbcount; i++) // VB Data
	{
		var vbuffersize = buffer_read(b, buffer_u32);
		var numvertices = buffer_read(b, buffer_u32);
		
		// Create vb
		vb = vertex_create_buffer_from_buffer_ext(b, format, buffer_tell(b), numvertices);
		
		if freeze {vertex_freeze(vb);}
		outvbc.vb[i] = vb;
		outvbc.vbmap[$ outvbc.vbnames[i]] = vb;
		
		// move to next vb
		buffer_seek(b, buffer_seek_relative, vbuffersize);
	}
	
	#endregion -------------------------------------------------------------
	
	#region // Bones ======================================================
	
	bonecount = buffer_read(b, buffer_u16);
	outvbc.bonecount = bonecount;
	array_resize(outvbc.bonenames, bonecount);
	array_resize(outvbc.bone_parentindices, bonecount);
	array_resize(outvbc.bone_localmatricies, bonecount);
	array_resize(outvbc.bone_inversematricies, bonecount);
	
	// Bone Names
	for (var i = 0; i < bonecount; i++) 
	{
		name = "";
		namelength = buffer_read(b, buffer_u8);
		repeat(namelength)
		{
			name += chr(buffer_read(b, buffer_u8));
		}
		outvbc.bonenames[i] = name;
		outvbc.bonemap[$ name] = i;
		//printf("[%s] %s", i, name)
	}
	
	// Parent Indices
	targetmats = outvbc.bone_parentindices;
	i = 0; repeat(bonecount)
	{
		targetmats[@ i++] = buffer_read(b, buffer_u16);
	}
	
	// Local Matrices
	targetmats = outvbc.bone_localmatricies;
	i = 0; repeat(bonecount)
	{
		mat = array_create(16);
		j = 0; repeat(16)
		{
			mat[j++] = buffer_read(b, floattype);
		}
		targetmats[@ i++] = mat;
	}
	
	// Inverse Model Matrices
	targetmats = outvbc.bone_inversematricies;
	i = 0; repeat(bonecount)
	{
		mat = array_create(16);
		j = 0; repeat(16)
		{
			mat[j++] = buffer_read(b, floattype);
		}
		targetmats[@ i++] = mat;
	}
	
	#endregion -------------------------------------------------------------
	
	buffer_delete(b);
	
	// Keep Temporary format
	if noformatgiven
	{
		outvbc.vbformat = format;
		
		// Apparently formats need to stay in memory...
		//vertex_format_delete(format);
	}
	
	return outvbc;
}

