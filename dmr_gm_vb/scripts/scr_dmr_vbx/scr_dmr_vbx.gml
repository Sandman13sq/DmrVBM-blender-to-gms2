/*
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

/*
	GM mat ref:
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
}

function VBXFree(vbx)
{
	var n = vbx.vbcount;
	for (var i = 0; i < n; i++)
	{
		vertex_delete_buffer(vbx.vb[i]);
	}
	delete vbx;
}


// Returns vertex buffer from file (.vb)
function LoadVertexBuffer(path, format, freeze = 1)
{
	var bzipped = buffer_load(path);
	
	// error reading file
	if bzipped < 0
	{
		show_debug_message("LoadVertexBuffer(): Error loading vertex buffer from \"" + path + "\"");
		return -1;
	}
	
	var b = buffer_decompress(bzipped);
	if b < 0 {b = bzipped;} else {buffer_delete(bzipped);}
	
	var vb = vertex_create_buffer_from_buffer(b, format);
	
	if freeze {vertex_freeze(vb);}
	
	return vb;
}

// Returns vbx struct from file (.vbx)
function LoadVBX(path, format, freeze = 1)
{
	var bzipped = buffer_load(path);
	
	if bzipped < 0
	{
		show_debug_message("LoadVBX(): Error loading vbx data from \"" + path + "\"");
		return -1;
	}
	
	var b = buffer_decompress(bzipped);
	if b < 0 {b = bzipped;} else {buffer_delete(bzipped);}
	
	var out = new VBXData();
	
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
	
	#region // Bones ======================================================
	
	bonecount = buffer_read(b, buffer_u16);
	out.bonecount = bonecount;
	array_resize(out.bonenames, bonecount);
	array_resize(out.bone_parentindices, bonecount);
	array_resize(out.bone_localmatricies, bonecount);
	array_resize(out.bone_inversematricies, bonecount);
	
	// Bone Names
	for (var i = 0; i < bonecount; i++) 
	{
		name = "";
		namelength = buffer_read(b, buffer_u8);
		repeat(namelength)
		{
			name += chr(buffer_read(b, buffer_u8));
		}
		out.bonenames[i] = name;
		out.bonemap[$ name] = i;
	}
	
	// Parent Indices
	targetmats = out.bone_parentindices;
	i = 0; repeat(bonecount)
	{
		targetmats[@ i++] = buffer_read(b, buffer_u16);
	}
	
	// Local Matrices
	targetmats = out.bone_localmatricies;
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
	targetmats = out.bone_inversematricies;
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
	
	#region // Vertex Buffers ==============================================
	
	vbcount = buffer_read(b, buffer_u16);
	out.vbcount = vbcount;
	array_resize(out.vbnames, vbcount);
	
	for (var i = 0; i < vbcount; i++) // VB Names
	{
		name = "";
		namelength = buffer_read(b, buffer_u8);
		repeat(namelength)
		{
			name += chr(buffer_read(b, buffer_u8));
		}
		out.vbnames[i] = name;
		out.vbnamemap[$ name] = i;
	}
	
	for (var i = 0; i < vbcount; i++) // VB Data
	{
		compressedsize = buffer_read(b, buffer_u32);
		vbcompressed = buffer_create(compressedsize, buffer_grow, 1);
		buffer_copy(b, buffer_tell(b), compressedsize, vbcompressed, 0);
		vbbuffer = buffer_decompress(vbcompressed);
		
		if vbbuffer >= 0 // Was Compressed
		{
			buffer_delete(vbcompressed);
		}
		
		// Convert to 32 bit float
		if floattype != buffer_f32
		{
			var floatsize = (floattype == buffer_f16)? 2: 8;
			var numfloats = buffer_get_size(vbbuffer) / floatsize;
			var convertedbuffer = buffer_create( numfloats * 4, buffer_fixed, 4);
			
			for (var f = 0; f < numfloats; f++)
			{
				buffer_write(convertedbuffer, buffer_f32, buffer_read(vbbuffer, floattype));
			}
			buffer_delete(vbbuffer);
			vbbuffer = convertedbuffer;
		}
		
		// Create vb
		vb = vertex_create_buffer_from_buffer(vbbuffer, format);
		buffer_delete(vbbuffer);
		
		if freeze {vertex_freeze(vb);}
		out.vb[i] = vb;
		out.vbmap[$ out.vbnames[i]] = vb;
		
		// move to next compressed vb
		buffer_seek(b, buffer_seek_relative, compressedsize);
	}
	
	#endregion -------------------------------------------------------------
	
	buffer_delete(b);
	
	return out;
}

// Loads flattened matrix array
function LoadPoses(path, outarray, offset=0)
{
	var bzipped = buffer_load(path);
	
	if bzipped < 0
	{
		show_debug_message("LoadPoses(): Error loading pose data from \"" + path + "\"");
		return -1;
	}
	
	var b = buffer_decompress(bzipped);
	if b < 0 {b = bzipped;} else {buffer_delete(bzipped);}
	
	var bonecount = buffer_read(b, buffer_u32);
	var posecount = buffer_read(b, buffer_u32);
	var matrixcount = bonecount*16;
	var pindex, mindex;
	
	var posedata = array_create(posecount);
	var matrixdata;
	
	// For each pose
	pindex = 0; repeat(posecount)
	{
		matrixdata = array_create(matrixcount);
		posedata[@ pindex++] = matrixdata;
		
		// For each bone
		mindex = 0; repeat(matrixcount)
		{
			matrixdata[@ mindex++] = buffer_read(b, buffer_f32);
		}
	}
	
	
	
	buffer_delete(b);
	
	array_copy(outarray, offset, posedata, 0, posecount);
	
	return posedata;
}