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
	uvbytes = 13,
	
	paddingfloats = 14,
	paddingbytes = 15,
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

// =================================================================================
#region // Structs
// =================================================================================

function VBMData() constructor 
{
	meshes = [];	// Array of VBMData_Mesh()
	meshnames = [];	// Array of names for corresponding meshes
	meshmap = {};	// {name: mesh} for each mesh
	meshindexmap = {}	// {name: meshindex} for each mesh
	meshcount = 0;
	
	bone_parentindices = [];	// Parent transform corresponding to each bone
	bone_localmatricies = [];	// Local transform corresponding to each bone
	bone_inversematricies = [];	// Inverse transform corresponding to each bone
	bonemap = {};	// {bonename: index} for each bone
	bonenames = [];
	bonecount = 0;
	
	vertexformat = -1;	// Vertex Buffer Format created in OpenVBM() (Don't touch!)
	formatcode = [];	// Set from OpenVBM()
	
	pendingfreeze = true;
	
	// Accessors -------------------------------------------------------------------
	
	static Count = function() {return meshcount;}
	static Names = function() {return meshnames;}
	static GetMesh = function(index) {return meshes[index];}
	static GetVertexBuffer = function(index) {return meshes[index].vertexbuffer;}
	static GetName = function(index) {return meshnames[index];}
	static NameExists = function(name) {return variable_struct_exists(meshmap, name);}
	
	static BoneCount = function() {return bonecount;}
	static BoneNames = function() {return bonenames;}
	static BoneParentIndices = function() {return bone_parentindices;}
	static BoneLocalMatrices = function() {return bone_localmatricies;}
	static BoneInverseMatrices = function() {return bone_inversematricies;}
	static GetBoneName = function(index) {return bonenames[index];}
	static GetBoneIndex = function(name) {return bonemap[$ name];}
	
	static Format = function() {return vertexformat;}
	static FormatString = function()
	{
		var out = "";
		var n = array_length(formatcode);
		var att;
		
		for (var i = 0; i < n; i++)
		{
			att = formatcode[i];
			switch(att[0])
			{
				default: out += "??? " + string(att[1]); break;
				
				case(VBM_AttributeType.position3d): out += "POS " + string(att[1]) + "f"; break;
				case(VBM_AttributeType.uv): out += "UVS " + string(att[1]) + "f"; break;
				case(VBM_AttributeType.normal): out += "NOR " + string(att[1]) + "f"; break;
				case(VBM_AttributeType.color): out += "COL " + string(att[1]) + "f"; break;
				case(VBM_AttributeType.colorbytes): out += "RGB " + string(att[1]) + "B"; break;
				
				case(VBM_AttributeType.weight): out += "WEI " + string(att[1]) + "f"; break;
				case(VBM_AttributeType.weightbytes): out += "WEB " + string(att[1]) + "B"; break;
				case(VBM_AttributeType.bone): out += "BON " + string(att[1]) + "f"; break;
				case(VBM_AttributeType.bonebytes): out += "BOB " + string(att[1]) + "B"; break;
				case(VBM_AttributeType.tangent): out += "TAN " + string(att[1]) + "f"; break;
				case(VBM_AttributeType.bitangent): out += "BIT " + string(att[1]) + "f"; break;
				case(VBM_AttributeType.vertexgroup): out += "VGR " + string(att[1]) + "f"; break;
				case(VBM_AttributeType.uvbytes): out += "UVB " + string(att[1]) + "B"; break;
				case(VBM_AttributeType.paddingfloats): out += "PAD " + string(att[1]) + "B"; break;
				case(VBM_AttributeType.paddingbytes): out += "PAB " + string(att[1]) + "B"; break;
			}
			
			if ( i < n-1 )
			{
				out += ", "
			}
		}
		
		return "{" + out + "}";
	}
	
	// Methods -------------------------------------------------------------------
	
	// Used when struct is given to string() function
	static toString = function()
	{
		return "VBMData: {" +string(meshcount)+" meshes, " + string(bonecount) + " bones" + "}";
	}
	
	// Copies values from other vbm
	static CopyFromOther = function(othervbm)
	{
		Clear();
		
		// Format
		if ( array_length(othervbm.formatcode) > 0 )
		{
			vertex_format_begin();
			
			var n = array_length(othervbm.formatcode);
			var bytesum = 0;
			
			for (var i = 0; i < n; i++)
			{
				formatcode[i] = [othervbm.formatcode[i][0], othervbm.formatcode[i][1]];
				bytesum = VBMAttributeTypeToFormat(formatcode[i][0], formatcode[i][1], bytesum);
			}
			
			vertexformat = vertex_format_end();
		}
		
		// Buffers
		var mesh;
		var name;
		
		for (var i = 0; i < othervbm.meshcount; i++)
		{
			name = othervbm.meshnames[i];
			
			mesh = othervbm.meshes[i].Duplicate();
			mesh.vertexformat = vertexformat;
			
			meshes[meshcount] = mesh;
			meshnames[meshcount] = name;
			meshmap[$ name] = meshes[meshcount];
			meshindexmap[$ name] = meshcount;
			
			meshcount += 1;
		}
		
		// Bones
		bonecount = othervbm.bonecount;
		bonemap = {};
		array_resize(bonenames, bonecount);
		array_resize(bone_parentindices, bonecount);
		array_resize(bone_localmatricies, bonecount);
		array_resize(bone_inversematricies, bonecount);
		
		array_copy(bone_parentindices, 0, othervbm.bone_parentindices, 0, array_length(bone_parentindices));
		
		for (var i = 0; i < bonecount; i++)
		{
			bonenames[i] = othervbm.bonenames[i];
			bonemap[$ bonenames[i]] = i;
			
			bone_localmatricies[i] = matrix_build_identity();
			array_copy(bone_localmatricies[i], 0, othervbm.bone_localmatricies[i], 0, 16);
			
			bone_inversematricies[i] = matrix_build_identity();
			array_copy(bone_inversematricies[i], 0, othervbm.bone_inversematricies[i], 0, 16);
		}
		
		return self;
	}
	
	// Returns duplicate of this vbm
	static Duplicate = function()
	{
		var outvbm = new VBMData();
		outvbm.CopyFromOther(self);
		
		return outvbm;
	}
	
	// Opens vbm from file
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
		for (var i = 0; i < meshcount; i++)
		{
			vertex_delete_buffer(meshes[i].vertexbuffer);
			buffer_delete(meshes[i].compressedbuffer);
			
			delete meshes[i];
		}
		
		array_resize(meshes, 0);
		array_resize(meshnames, 0);
		
		meshmap = {};
		meshindexmap = {};
		meshcount = 0;
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
		var i = 0; repeat(meshcount)
		{
			if ( meshnames[i] == _name ) {return i;}
			i++;
		}
		return -1;
	}
	
	// Returns index if vb contains given name. -1 if not found
	static FindVBIndex_Contains = function(_name)
	{
		var i = 0; repeat(meshcount)
		{
			if string_pos(_name, meshnames[i]) {return i;}
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
	
	// Freezes vertex buffers and re-composes compressed buffer
	static Freeze = function()
	{
		
	}
	
	// Submits all vertex buffers
	static Submit = function(prim=pr_trianglelist, texture=undefined)
	{
		var i = 0;
		repeat(meshcount)
		{
			meshes[i++].Submit(prim, texture);
		}
	}
	
	// Submits vertex buffer using index
	static SubmitVBIndex = function(vbindex, prim=pr_trianglelist, texture=undefined)
	{
		if (meshcount > 0)
		{
			// Positive number, normal index
			if (vbindex >= 0 && vbindex < meshcount)
			{
				meshes[vbindex].Submit(prim, texture);
			}
			// Negative number, start from end of list
			else if (vbindex < 0 && (meshcount+vbindex) < meshcount)
			{
				meshes[meshcount + vbindex].Submit(prim, texture);
			}
		}
	}
	
	// Submits vertex buffer using name
	static SubmitVBKey = function(name, prim=pr_trianglelist, texture=undefined)
	{
		if ( NameExists(name) ) { meshmap[$ name].Submit(prim, texture) }
	}
	
	// Adds vertex buffer to vbm
	static AddVB = function(vb, meshname)
	{
		meshes[meshcount] = new VBMData_Mesh();
		meshes[meshcount].SetVB(vb, meshname);
		meshes[meshcount].vertexformat = vertexformat;
		
		meshnames[meshcount] = meshname;
		meshmap[$ meshname] = meshname;
		meshindexmap[$ meshname] = meshcount;
		meshcount += 1;
		
		return self;
	}
	
	// Adds all vertex buffers from other vbm
	static AddVBM = function(othervbm)
	{
		var n = othervbm.meshcount;
		
		for (var i = 0; i < n; i++)
		{
			AddVB(othervbm.meshes[i], othervbm.meshnames[i]);
		}
		
		return self;
	}
	
}

function VBMData_Mesh() constructor
{
	name = "";
	vertexformat = -1;
	vertexbuffer = -1;	// Vertex buffer used in rendering
	compressedbuffer = -1;	// Compressed vertex buffer
	
	bounds = [ [0,0,0], [0,0,0] ];	// Min and max position of vertices
	
	isfrozen = 0;
	iscompressed = 0;
	
	pendingfreeze = true;
	pendingcompress = true;
	
	texture = -1;
	
	static CopyFromOther = function(othermesh)
	{
		var b, vb, vbcomp;
		
		if ( buffer_exists(compressedbuffer) ) {buffer_delete(compressedbuffer);}
		
		name = othermesh.name;
		texture = othermesh.texture;
		vertexformat = othermesh.vertexformat;
		
		vbcomp = othermesh.GetCompressedBuffer();
		
		pendingcompress = false;
		compressedbuffer = buffer_create(buffer_get_size(vbcomp), buffer_fast, 1);
		buffer_copy(othermesh.compressedbuffer, 0, buffer_get_size(compressedbuffer), compressedbuffer, 0);
		
		b = buffer_decompress(compressedbuffer);
		vertexbuffer = vertex_create_buffer_from_buffer(b, vertexformat);
		buffer_delete(b);
		
		return self;
	}
	
	static GetCompressedBuffer = function()
	{
		Compress();
		return compressedbuffer;
	}
	
	static Duplicate = function()
	{
		var out = new VBMData_Mesh();
		return out.CopyFromOther(self);
	}
	
	static SetVB = function(vb, _name="")
	{
		if (_name != "") {name = _name;}
		
		pendingfreeze = true;
		pendingcompress = true;
		
		vertexbuffer = vb;
		
		return self;
	}
	
	static Compress = function()
	{
		if ( pendingcompress )
		{
			pendingcompress = false;
			
			var vb = vertexbuffer;
			var vbbytes = vertex_get_buffer_size(vb);
			var b = buffer_create(vbbytes, buffer_fast, 1);
		
			buffer_copy_from_vertex_buffer(vb, 0, vertex_get_number(vb), b, buffer_tell(b));
			compressedbuffer = buffer_compress(b, 0, buffer_get_size(b));
			buffer_delete(b);
		}
		
		return self;
	}
	
	static Freeze = function()
	{
		if ( pendingfreeze )
		{
			Compress();
			
			pendingfreeze = false;
			
			var err;
			try {vertex_freeze(vertexbuffer);}
		}
		
		return self;
	}
	
	static Submit = function(prim=pr_trianglelist, _texture=undefined)
	{
		Freeze();
		vertex_submit(vertexbuffer, prim, (_texture==undefined)? texture: _texture);
	}
}

#endregion // ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

// =================================================================================
#region // Functions
// =================================================================================

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
		( _header == 0x0178 ) ||
		( _header == 0x9C78 ) ||
		( _header == 0xDA78 )
		)
	{
		b = buffer_decompress(bzipped);
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
		
		// Version 2 (Fixed Non-color byte data)
		case(2): 
		// Version 1
		case(1): 
			return __VBMOpen_v1(outvbm, b, format, freeze, merge);
	}
	
	return outvbm;
}

// Populates struct with {fname: VBMData}
function OpenVBMDirectory(dir, outvbmstruct={})
{
	var _lastchar = string_char_at(dir, string_length(dir));
	if ( _lastchar != "/" && _lastchar != "\\" )
	{
		dir += "\\";
	}
	
	var err;
	
	var vbm;
	var fname = file_find_first(dir + "*.vbm", 0);
	
	while (fname != "")
	{
		vbm = new VBMData();
		try
		{
			vbm.Open(dir+fname);
		}
		catch (err)
		{
			show_debug_message(err);
		}
		
		variable_struct_set(outvbmstruct, filename_change_ext(fname, ""), vbm);
			
		fname = file_find_next();
	}
	
	file_find_close();
	
	return outvbmstruct;
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

// Adds attribute to vertex format using type. Returns new bytesum
function VBMAttributeTypeToFormat(attribute_type, attribute_size, bytesum, version1=false)
{
	switch(attribute_type)
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
		case(VBM_AttributeType.uvbytes):
		case(VBM_AttributeType.paddingbytes):
			if ( ((bytesum + attribute_size) div 4) > bytesum div 4 ) || version1
			{
				vertex_format_add_color();
			}
				
			bytesum += attribute_size;
			break;
			
		// Non native types
		default:
			switch(attribute_size)
			{
				case(1): vertex_format_add_custom(vertex_type_float1, vertex_usage_texcoord); break;
				case(2): vertex_format_add_custom(vertex_type_float2, vertex_usage_texcoord); break;
				case(3): vertex_format_add_custom(vertex_type_float3, vertex_usage_texcoord); break;
				case(4): vertex_format_add_custom(vertex_type_float4, vertex_usage_texcoord); break;
			}
			break;
	}
	
	return bytesum;
}

// Returns vbm format from buffer
function GetVBMFormat(b, offset, version1=false, outputcode=[])
{
	var numattributes = buffer_peek(b, offset, buffer_u8);
	offset += 1;
	
	vertex_format_begin();
	
	var attributetype;
	var attributesize;
	
	var bytesum = 0;
	
	repeat(numattributes)
	{
		attributetype = buffer_peek(b, offset, buffer_u8);
		offset += 1;
		attributesize = buffer_peek(b, offset, buffer_u8);
		offset += 1;
		
		array_push(outputcode, [attributetype, attributesize]);
		bytesum = VBMAttributeTypeToFormat(attributetype, attributesize, bytesum, version1);
	}
		
	return vertex_format_end();
}

// Returns vbm struct from file (.vbm)
function __VBMOpen_v1(outvbm, b, format, freeze, merge)
{
	/* Vertex Buffer Collection v1 File spec:
		'VBM' (3B)
		VBM version (1B)
    
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
	
	var version;
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
	
	var namelist = [];
	
	// Header
	version = buffer_read(b, buffer_u32) >> 24;
	
	flag = buffer_read(b, buffer_u8);
	
	// Vertex Format
	if (noformatgiven)
	{
		format = GetVBMFormat(b, buffer_tell(b), version==1, outvbm.formatcode);
	}
	
	buffer_seek(b, buffer_seek_relative, buffer_read(b, buffer_u8)*2);
	
	// Keep Temporary format
	if (noformatgiven)
	{
		outvbm.vertexformat = format;
		
		// Apparently formats need to stay in memory...
		//vertex_format_delete(format);
	}
	
	#region // Vertex Buffers ==================================================
	
	vbcount = buffer_read(b, buffer_u32);
	array_resize(namelist, vbcount);
	
	if (merge)
	{
		appendcount = 1;
	}
	else
	{
		appendcount = vbcount;
	}
	
	// VB Names ------------------------------------------------------------
	for (var i = 0; i < appendcount; i++) 
	{
		name = "";
		namelength = buffer_read(b, buffer_u8);
		repeat(namelength)
		{
			name += chr(buffer_read(b, buffer_u8));
		}
		namelist[i] = name;
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
			
			outvbm.AddVB(vb, namelist[i]);
		
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
		
		outvbm.AddVB(vb, namelist[0]);
		
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
	
	return outvbm;
}

#endregion // ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

