/*
*/

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
	vbcount = 0;
	
	bone_parentindices = [];	// Parent transform corresponding to each bone
	bone_localmatricies = [];	// Local transform corresponding to each bone
	bone_inversematricies = [];	// Inverse transform corresponding to each bone
	bonemap = {};	// {bonename: index} for each bone
	bonenames = [];
	bonecount = 0;
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
