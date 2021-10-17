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

enum AniTrack_Intrpl
{
	constant = 0,
	linear = 1,
	smooth = 2,
}

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

function AniTrackData() constructor
{
	tracks = []; // array of AniTrackData_Track
	tracknames = [];
	trackmap = {}; // {trackname: track} for each track
	trackcount = 0;
	
	markerpositions = []; // Frame positions in animation
	markermap = {};	// {markername: framepos} for each marker
	markernames = [];
	markercount = 0;
	
	framespersecond = 1;
	length = 0;
}

function AniTrackData_Track() constructor
{
	frames = [];
	vectors = [];
	count = 0;
}

// Returns vertex buffer from file (.vb)
function LoadVertexBuffer(path, format, freeze = 1)
{
	var b = buffer_load(path);
	
	if b == -1
	{
		show_debug_message("LoadVertexBuffer(): Error loading vertex buffer from \"" + path + "\"");
		return -1;
	}
	
	var bdecompressed = buffer_decompress(b);
	var out = -1;
	
	// Not compressed
	if bdecompressed < 0
	{
		out = vertex_create_buffer_from_buffer(b, format);
	}
	// Compressed
	else
	{
		out = vertex_create_buffer_from_buffer(bdecompressed, format);
		buffer_delete(bdecompressed);
	}
	
	buffer_delete(b);
	
	if freeze {vertex_freeze(out);}
	
	return out;
}

// Returns vbx struct from file (.vbx)
function LoadVertexBufferExt(path, format, freeze = 1)
{
	var b = buffer_load(path);
	
	if b == -1
	{
		show_debug_message("LoadVertexBuffer(): Error loading vertex buffer from \"" + path + "\"");
		return -1;
	}
	
	var bdecompressed = buffer_decompress(b);
	if bdecompressed >= 0
	{
		buffer_delete(b);
		b = bdecompressed;
	}
	
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
	
	// Header
	buffer_read(b, buffer_u32);
	flag = buffer_read(b, buffer_u8);
	
	// Float Type
	switch(flag & 3)
	{
		default:
		case(0): floattype = buffer_f32; printf("Floattype: 32"); break;
		case(1): floattype = buffer_f64; printf("Floattype: 64"); break;
		case(2): floattype = buffer_f16; printf("Floattype: 16"); break;
	}
	
	// Bones -----------------------------------------------------
	bonecount = buffer_read(b, buffer_u16);
	out.bonecount = bonecount;
	array_resize(out.bonenames, bonecount);
	array_resize(out.bone_parentindices, bonecount);
	array_resize(out.bone_localmatricies, bonecount);
	array_resize(out.bone_inversematricies, bonecount);
	
	for (var i = 0; i < bonecount; i++) // Bone Names
	{
		name = "";
		namelength = buffer_read(b, buffer_u8);
		for (var c = 0; c < namelength; c++)
		{
			name += chr(buffer_read(b, buffer_u8));
		}
		out.bonenames[i] = name;
		out.bonemap[$ name] = i;
	}
	
	for (var i = 0; i < bonecount; i++) // Parent Indices
	{
		out.bone_parentindices[i] = buffer_read(b, buffer_u16);
	}
	
	for (var i = 0; i < bonecount; i++) // Local Matrices
	{
		mat = array_create(16);
		for (var j = 0; j < 16; j++)
		{
			mat[j] = buffer_read(b, floattype);
		}
		out.bone_localmatricies[i] = mat;
	}
	
	for (var i = 0; i < bonecount; i++) // Inverse Model Matrices
	{
		mat = array_create(16);
		for (var j = 0; j < 16; j++)
		{
			mat[j] = buffer_read(b, floattype);
		}
		out.bone_inversematricies[i] = mat;
	}
	
	// Vertex Buffers -----------------------------------------------------
	vbcount = buffer_read(b, buffer_u16);
	out.vbcount = vbcount;
	array_resize(out.vbnames, vbcount);
	
	for (var i = 0; i < vbcount; i++) // VB Names
	{
		name = "";
		namelength = buffer_read(b, buffer_u8);
		for (var c = 0; c < namelength; c++)
		{
			name += chr(buffer_read(b, buffer_u8));
		}
		out.vbnames[i] = name;
	}
	
	for (var i = 0; i < vbcount; i++) // VB Data
	{
		printf("buffer_tell(): %d", buffer_tell(b));
		
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
		
		vb = vertex_create_buffer_from_buffer(vbbuffer, format);
		buffer_delete(vbbuffer);
		
		if freeze {vertex_freeze(vb);}
		out.vb[i] = vb;
		out.vbmap[$ out.vbnames[i]] = vb;
		
		printf("\"%s\" csize: %d (%d)", out.vbnames[i], compressedsize, vertex_get_number(vb));
		
		buffer_seek(b, buffer_seek_relative, compressedsize);
	}
	
	buffer_delete(b);
	
	return out;
}

// Returns animation struct from file (.ani)
function LoadAniTrack(_path)
{
	var bcompressed = buffer_load(_path);
	if bcompressed == -1
	{
		printf("LoadAnimation(): Error loading file \"%s\"", _path);
		return 0;
	}
	var b = buffer_decompress(bcompressed);
	buffer_delete(bcompressed);
		
	/*
		bonecount
		maxframe
		tracks[bonecount]
			trackname
			transforms[10]
				pair[2]
					frame
					value
	*/
		
	printf("Reading animation from \"%s\"...", _path);
		
	var out = new AniTrackData();
	var flag;
	
	var namelength;
	var name;
	
	// Header
	buffer_read(b, buffer_u32);
	
	// Flag
	flag = buffer_read(b, buffer_u8);
	// Animation Original FPS
	out.framespersecond = buffer_read(b, buffer_f32);
	// Animation Length
	out.length = buffer_read(b, buffer_u16);
	
	// Transforms -------------------------------------------------
	
	var transformtracks;
	var track;
	var trackframes;
	var trackvectors;
	var numframes;
	var name;
	var vector;
	var vectorsize;
	
	var numtracks = buffer_read(b, buffer_u16);
	out.trackcount = numtracks;
	
	printf(numtracks);
	
	array_resize(out.tracks, numtracks);
	array_resize(out.tracknames, numtracks);
	
	// Track Names
	for (var trackindex = 0; trackindex < numtracks; trackindex++)
	{
		name = "";
		namelength = buffer_read(b, buffer_u8);
		for (var c = 0; c < namelength; c++)
		{
			name += chr( buffer_read(b, buffer_u8) );
		}
		out.tracknames[trackindex] = name;
	}
		
	// Read tracks
	for (var trackindex = 0; trackindex < numtracks; trackindex++)
	{		
		transformtracks = array_create(3); // [location<3>, quaternion<4>, scale<3>]
		
		// For each transform vector [location<3>, quaternion<4>, scale<3>]
		for (var transformindex = 0; transformindex < 3; transformindex++)
		{
			vectorsize = (transformindex == 1)? 4:3; // 4 for quats, 3 for location and scale
			
			numframes = buffer_read(b, buffer_u16); // Frame Count
			
			track = new AniTrackData_Track();
			trackframes = array_create(numframes);
			trackvectors = array_create(numframes);
			
			// Frame Positions
			for (var f = 0; f < numframes; f++)
			{
				trackframes[f] = buffer_read(b, buffer_f32);
			}
			
			// Frame Vectors
			for (var f = 0; f < numframes; f++)
			{
				vector = array_create(vectorsize);
						
				for (var v = 0; v < vectorsize; v++)
				{
					vector[v] = buffer_read(b, buffer_f32);
				}
				
				trackvectors[f] = vector; // Vector
			}
			
			track.count = numframes;
			track.frames = trackframes;
			track.vectors = trackvectors;
			transformtracks[transformindex] = track;
		}
		
		out.tracks[trackindex] = transformtracks;
		out.trackmap[$ out.tracknames[trackindex] ] = transformtracks;
	}
	
	// Markers -----------------------------------------------------
	var nummarkers = buffer_read(b, buffer_u16);
	out.markercount = nummarkers;
	
	array_resize(out.markerpositions, nummarkers);
	array_resize(out.markernames, nummarkers);
	
	for (var i = 0; i < nummarkers; i++) // Marker Names
	{
		name = "";
		namelength = buffer_read(b, buffer_u8);
		for (var c = 0; c < namelength; c++)
		{
			name += chr( buffer_read(b, buffer_u8) );
		}
		out.markernames[i] = name;
	}
	
	for (var i = 0; i < nummarkers; i++) // Marker Frames
	{
		out.markerpositions[i] = buffer_read(b, buffer_f32);
		out.markermap[$ out.markernames[i] ] = out.markerpositions[i];
	}
		
	buffer_delete(b);
		
	printf("Returning Animation...");
	
	return out;
}

// Evaluates animation at given position and fills "outpose" with evaluated matrices
function EvaluateAnimationTracks(pos, bonekeys, trackdata, outpose)
{
	// ~16% of original time / ~625% speed increase with the YYC compiler
	
	var n = array_length(bonekeys);
	var trackmap = trackdata.trackmap;
	var bonename, outposematrix;
	var track, trackframes, trackvectors;
	var transformtracks;
	var posnext, poscurr;
	var findexcurr, findexnext, findexmax, blendamt;
	var veccurr, vecnext;
	var interpolationtype = AniTrack_Intrpl.smooth;
	var quat = Quat();
	
	var possearchstart;
	//var search_l, search_r, search_m;
	
	//pos = clamp(pos, 0, 1);
	
	if pos < 0.5 {possearchstart = 0;}
	else {possearchstart = trackdata.length;}
	
	interpolationtype = intrpltype;
	
	for (var b = 0; b < n; b++)
	{
		bonename = bonekeys[b];
		
		// Skip if no track has bone's name
		if !variable_struct_exists(trackmap, bonename) {continue;}
		transformtracks = variable_struct_get(trackmap, bonename); // [frames[], vectors[]]
		outposematrix = outpose[@ b]; // Target Bone Matrix
		
		// For each transform (location, scale, rotation)
		for (var ttype = 0; ttype < 3; ttype++)
		{
			//if ttype != 2 {continue;}
			if ttype == 1 {continue;}
			
			track = transformtracks[ttype > 0? (3-ttype): 0]; // AniTrackData_Track
			trackframes = track.frames;
			trackvectors = track.vectors;
			findexmax = track.count - 1;
			
			// Single Keyframe
			if (findexmax == 0)
			{
				veccurr = trackvectors[0];
				switch(ttype)
				{
					case(0): // Transform
						outposematrix[@ 12] = veccurr[0];
						outposematrix[@ 13] = veccurr[1];
						outposematrix[@ 14] = veccurr[2];
						break;
					
					case(1): // Scale
						outposematrix[@  0] = veccurr[0];
						outposematrix[@  5] = veccurr[1];
						outposematrix[@ 10] = veccurr[2];
						break;
				
					case(2): // Quaternion
						QuatToMat4_r( veccurr, outposematrix );
						break;
				}
			}
			// Multiple Keyframes
			else if (findexmax > 0)
			{
				/*
				// Find two frames that the position sits between
				if (possearchstart == 0) // Search starting from beginning moving forwards
				{
					findexnext = 0;
					while (pos >= trackframes[findexnext] && findexnext < findexmax) {findexnext++;}
					findexcurr = max(findexnext - 1, 0);
				}
				else // Search starting from end moving backwards
				{
					findexcurr = findexmax;
					while (pos < trackframes[findexcurr] && findexcurr > 0) {findexcurr--;}
					findexnext = min(findexcurr + 1, findexmax);
				}
				*/
				
				// Guess initial position
				findexcurr = clamp( floor(pos*findexmax), 0, findexmax);
				possearchstart = trackframes[findexcurr];
				if (possearchstart < pos) // Search starting from beginning moving forwards
				{
					findexnext = findexcurr;
					while (pos >= trackframes[findexnext] && findexnext < findexmax) {findexnext++;}
					findexcurr = max(findexnext - 1, 0);
				}
				else // Search starting from end moving backwards
				{
					//findexcurr = findexcurr;
					while (pos < trackframes[findexcurr] && findexcurr > 0) {findexcurr--;}
					findexnext = min(findexcurr + 1, findexmax);
				}
				
				poscurr = trackframes[findexcurr];	// Position of keyframe that "pos" is ahead of
				posnext = trackframes[findexnext];	// Position of next keyframe
			
				// Find Blend amount (Map pos distance to [0-1] value)
				if poscurr == posnext {blendamt = 1;} // Same frame
				//else if posnext == poscurr+1 {blendamt = pos - poscurr;} // One unit difference
				else {blendamt = (pos - poscurr) / (posnext - poscurr);} // More than one unit difference
				
				// Apply Interpolation
				switch(interpolationtype)
				{
					case(AniTrack_Intrpl.constant): blendamt = 0; break;
					case(AniTrack_Intrpl.linear): blendamt = blendamt; break;
					case(AniTrack_Intrpl.smooth): blendamt = 0.5*(1-cos(pi*blendamt)); break;
				}
				
				// Apply Transform
				veccurr = trackvectors[findexcurr];
				vecnext = trackvectors[findexnext];
				
				switch(ttype)
				{
					case(0): // Transform
						outposematrix[@ 12] = lerp(veccurr[0], vecnext[0], blendamt);
						outposematrix[@ 13] = lerp(veccurr[1], vecnext[1], blendamt);
						outposematrix[@ 14] = lerp(veccurr[2], vecnext[2], blendamt);
						break;
					
					case(1): // Scale
						outposematrix[@  0] = lerp(veccurr[0], vecnext[0], blendamt);
						outposematrix[@  5] = lerp(veccurr[1], vecnext[1], blendamt);
						outposematrix[@ 10] = lerp(veccurr[2], vecnext[2], blendamt);
						break;
					
					case(2): // Quaternion
						QuatSlerp_r(veccurr, vecnext, blendamt, quat);
						QuatToMat4_r( quat, outposematrix );
						break;
				}
				
				//continue;
				
				if bonekeys[b] == "arm_l" && ttype == 2
				{
					execinfo = "";
					execinfo += stringf("Current Pos: %F", pos) + "\n";
					execinfo += stringf("Pos: [%F, %F]", poscurr, posnext) + "\n";
					execinfo += stringf("Frame: [%d, %d]", findexcurr, findexnext) + "\n";
					execinfo += stringf("Blend Amount: %F", blendamt) + "\n";
					execinfo += stringf("Quat: %s", quat) + "\n";
				}
			}
		}
	}
	
	return outpose;
}

// Fills outtransform with calculated animation pose
// bones = Array of VBXBone()
// posedata = Array of 4x4 matrices. 2D
// outposetransform = Flat Array of matrices in localspace, size = len(posedata) * 16, give to shader
// outbonetransform = Array of bone matrices in modelspace
function CalculateAnimationPose(
	bone_parentindices, bone_localmatricies, bone_inversemodelmatrix, posedata, 
	outposetransform, outbonetransform = [])
{
	var n = min( array_length(bone_parentindices), array_length(posedata));
	
	var localtransform = array_create(n);	// Parent -> Bone
	//var outbonetransform = array_create(n);	// Origin -> Bone
	array_resize(outbonetransform, n);
	
	// Calculate animation for specific bone
	for (var i = 0; i < n; i++)
	{
		localtransform[i] = matrix_multiply(
			posedata[i], bone_localmatricies[i]);
	}
	
	// Set the model transform of bone using parent transform
	// Only works if the parents preceed their children in array
	
	outbonetransform[@ 0] = localtransform[0]; // Edge case for root bone
	
	for (var i = 1; i < n; i++)
	{
		outbonetransform[@ i] = matrix_multiply(
			localtransform[i], outbonetransform[ bone_parentindices[i] ]);
	}
	
	// Compute final matrix for bone
	var m;
	for (var i = 0; i < n; i++)
	{
		m = matrix_multiply(bone_inversemodelmatrix[i], outbonetransform[i]);
		array_copy(outposetransform, i*16, m, 0, 16);
	}
}
