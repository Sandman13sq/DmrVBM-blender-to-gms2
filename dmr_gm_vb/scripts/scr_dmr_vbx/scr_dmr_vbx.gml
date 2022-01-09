/*
	VBX class definition and functions.
	By Dreamer13sq
*/

#macro DMRVBX_MATPOSEMAX 200
#macro DMRVBX_MAT4ARRAYFLAT global.g_mat4identityflat
#macro DMRVBX_MAT4ARRAY2D global.g_mat4identity2d

DMRVBX_MAT4ARRAYFLAT = array_create(16*DMRVBX_MATPOSEMAX);
DMRVBX_MAT4ARRAY2D = array_create(DMRVBX_MATPOSEMAX);

for (var i = 0; i < DMRVBX_MATPOSEMAX; i++)
{
	array_copy(DMRVBX_MAT4ARRAYFLAT, i*16, matrix_build_identity(), 0, 16);
	DMRVBX_MAT4ARRAY2D[i] = matrix_build_identity();
}

#macro VBXHEADERCODE 0x00584256

enum VBX_AttributeType
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

function VBXData() constructor 
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
	
	vbformat = -1;	// Vertex Buffer Format created in OpenVBX() (Don't touch!)
	
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
	
	// Returns VBXBone struct with given name. -1 if not found
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

// Removes allocated memory from vbx
function VBXFree(vbx)
{
	var n = vbx.vbcount;
	var vbuffers = vbx.vb;
	for (var i = 0; i < n; i++)
	{
		vertex_delete_buffer(vbuffers[i]);
	}
	
	if vbx.vbformat > -1
	{
		vertex_format_delete(vbx.vbformat);	
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

// Returns vbx struct from file (.vbx)
function OpenVBX(path, format=-1, freeze=true)
{
	if filename_ext(path) == ""
	{
		path = filename_change_ext(path, ".vbx");	
	}
	
	var bzipped = buffer_load(path);
	
	if bzipped < 0
	{
		show_debug_message("OpenVBX(): Error loading vbx data from \"" + path + "\"");
		return -1;
	}
	
	var b = buffer_decompress(bzipped);
	if b < 0 {b = bzipped;} else {buffer_delete(bzipped);}
	
	var vbx = new VBXData();
	
	var header;
	var flag;
	var floattype;
	var bonecount;
	var vbcount;
	var namelength;
	var name;
	var mat;
	var vb;
	var compressedsize;
	var vbcompressed;
	var vbbuffer;
	var targetmats;
	var i, j, c;
	var noformatgiven = format < 0;
	
	// Header
	header = buffer_read(b, buffer_u32);
	
	// Not a vbx file
	if ( (header & 0x00FFFFFF) != VBXHEADERCODE )
	{
		// Maybe it's a vertex buffer?
		if ( !noformatgiven )
		{
			vb = vertex_create_buffer_from_buffer(b, format);
			if ( vb < 0 )
			{
				show_debug_message("OpenVBX(): vbx data is invalid (vb) \"" + path + "\"");
				return -1;
			}
			
			name = filename_name(path);
			vbx.AddVB(vb, name);
			
			return vbx;
		}
		
		show_debug_message("OpenVBX(): vbx data is invalid \"" + path + "\"");
		return vbx;
	}
	
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
		format = GetVBXFormat(b, buffer_tell(b));
	}
	
	buffer_seek(b, buffer_seek_relative, buffer_read(b, buffer_u8)*2);
	
	#region // Vertex Buffers ==============================================
	
	vbcount = buffer_read(b, buffer_u16);
	vbx.vbcount = vbcount;
	array_resize(vbx.vbnames, vbcount);
	
	for (var i = 0; i < vbcount; i++) // VB Names
	{
		name = "";
		namelength = buffer_read(b, buffer_u8);
		repeat(namelength)
		{
			name += chr(buffer_read(b, buffer_u8));
		}
		vbx.vbnames[i] = name;
		vbx.vbnamemap[$ name] = i;
	}
	
	for (var i = 0; i < vbcount; i++) // VB Data
	{
		var vbuffersize = buffer_read(b, buffer_u32);
		var numvertices = buffer_read(b, buffer_u32);
		
		// Create vb
		vb = vertex_create_buffer_from_buffer_ext(b, format, buffer_tell(b), numvertices);
		
		if freeze {vertex_freeze(vb);}
		vbx.vb[i] = vb;
		vbx.vbmap[$ vbx.vbnames[i]] = vb;
		
		// move to next compressed vb
		buffer_seek(b, buffer_seek_relative, vbuffersize);
	}
	
	#endregion -------------------------------------------------------------
	
	#region // Bones ======================================================
	
	bonecount = buffer_read(b, buffer_u16);
	vbx.bonecount = bonecount;
	array_resize(vbx.bonenames, bonecount);
	array_resize(vbx.bone_parentindices, bonecount);
	array_resize(vbx.bone_localmatricies, bonecount);
	array_resize(vbx.bone_inversematricies, bonecount);
	
	// Bone Names
	for (var i = 0; i < bonecount; i++) 
	{
		name = "";
		namelength = buffer_read(b, buffer_u8);
		repeat(namelength)
		{
			name += chr(buffer_read(b, buffer_u8));
		}
		vbx.bonenames[i] = name;
		vbx.bonemap[$ name] = i;
		//printf("[%s] %s", i, name)
	}
	
	// Parent Indices
	targetmats = vbx.bone_parentindices;
	i = 0; repeat(bonecount)
	{
		targetmats[@ i++] = buffer_read(b, buffer_u16);
	}
	
	// Local Matrices
	targetmats = vbx.bone_localmatricies;
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
	targetmats = vbx.bone_inversematricies;
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
		vbx.vbformat = format;
		
		// Apparently formats need to stay in memory...
		//vertex_format_delete(format);
	}
	
	return vbx;
}

// Returns true if buffer contains vbx header
function BufferIsVBX(b, offset=0)
{
	if ( buffer_get_size(b) >= offset+4 )
	{
		var header = "";
		for (var i = 0; i < 3; i++)
		{
			header += chr( buffer_peek(b, offset+i, buffer_u8) );
		}
		if header == "VBX" {return true;}
	}
	
	return false;
}

// Returns vbx format from buffer
function GetVBXFormat(b, offset)
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
			case(VBX_AttributeType.position3d):
				vertex_format_add_position_3d(); break;
			case(VBX_AttributeType.uv):
				vertex_format_add_texcoord(); break;
			case(VBX_AttributeType.normal):
				vertex_format_add_normal(); break;
			case(VBX_AttributeType.colorbytes):
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
