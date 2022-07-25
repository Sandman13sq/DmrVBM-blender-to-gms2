/*
	Track data struct for animation playback
*/

#macro TRKHEADERCODE 0x004b5254

#region // Fast Quaternion Constants. Used in EvaluateAnimationTracks()

/*
	Sourced from this paper by David Eberly, licensed under CC 4.0.
	Paper: https://www.geometrictools.com/Documentation/FastAndAccurateSlerp.pdf
	CC License: https://creativecommons.org/licenses/by/4.0/
*/

#macro QUATSLERP_MU 1.85298109240830
#macro QUATSLERP_U0 1/(1*3)
#macro QUATSLERP_U1 1/(2*5)
#macro QUATSLERP_U2 1/(3*7)
#macro QUATSLERP_U3 1/(4*9)
#macro QUATSLERP_U4 1/(5*11)
#macro QUATSLERP_U5 1/(6*13)
#macro QUATSLERP_U6 1/(7*15)
#macro QUATSLERP_U7 QUATSLERP_MU/(8*17)
#macro QUATSLERP_V0 1/(3)
#macro QUATSLERP_V1 2/(5)
#macro QUATSLERP_V2 3/(7)
#macro QUATSLERP_V3 4/(9)
#macro QUATSLERP_V4 5/(11)
#macro QUATSLERP_V5 6/(13)
#macro QUATSLERP_V6 7/(15)
#macro QUATSLERP_V7 QUATSLERP_MU/(8*17)

#endregion --------------------------------------------------------

enum TRK_Intrpl
{
	constant = 0,
	linear = 1,
	smooth = 2,
}

enum TRK_Space
{
	none = 0,
	local = 1,
	pose = 2,
	world = 3,
	evaluated = 4
}

function TRKData() constructor
{
	matrixspace = TRK_Space.none; // 0 = None, 1 = Local, 2 = Pose, 3 = World, 4 = Evaluated
	framematrices = []; // Array of flat matrix arrays for each frame
	
	trackspace = TRK_Space.none; // 0 = None, 1 = Local, 2 = Pose, 3 = World
	tracks = []; // array of TRKData_Track
	tracknames = [];	// (bone) names for each track
	trackmap = {}; // {trackname: track} for each track
	trackindices = {};	// {trackname: index} for each track
	trackcount = 0;
	
	markerpositions = []; // Frame positions in animation
	markermap = {};	// {markername: framepos} for each marker
	markernames = []; // names for markers
	markercount = 0;
	
	positionrange = [0, 1];
	positionstep = 1.0
	
	framecount = 0;
	framespersecond = 1;
	duration = 0;
	flag = 0;
	
	// Accessors -------------------------------------------------------------------
	
	static Flags = function() {return flag;}
	static Duration = function() {return duration;}
	static PositionStep = function() {return positionstep;}
	
	static CalculateTimeStep = function(fps) {return (framespersecond/fps)/duration;}
	
	static MatrixSpace = function() {return matrixspace;}
	static TrackSpace = function() {return trackspace;}
	
	static FrameCount = function() {return framecount;}
	static FrameMatrices = function() {return framematrices;}
	static GetFrameMatrices = function(index) {return framematrices[index];}
	static GetFrameMatricesByPosition = function(pos) 
		{return framematrices[clamp(round(pos*framecount), 0, framecount-1)];}
	static GetFrameMatricesByMarker = function(marker_index) 
		{return framematrices[round(markerpositions[clamp(marker_index, 0, markercount-1)]*(framecount-1))];}
	
	static Tracks = function() {return tracks;}
	static TrackCount = function() {return trackcount;}
	static TrackNames = function() {return tracknames;}
	static GetTrack = function(index) {return tracks[index];}
	static GetTrackName = function(index) {return tracknames[index];}
	
	static MarkerCount = function() {return markercount;}
	static MarkerPositions = function() {return markerpositions;}
	static MarkerNames = function() {return markernames;}
	static GetMarkerPosition = function(index) {return markerpositions[index];}
	static GetMarkerName = function(index) {return markernames[index];}
	
	// Methods -------------------------------------------------------------------
	
	static toString = function()
	{
		return "TRKData: {" + 
			"Duration: " + string(duration) + ", " +
			"Frames: " + string(framecount) + ", " +
			"Tracks: " + string(trackcount) + ", " +
			"Markers: " + string(markercount) + "}";
	}
	
	// Returns trk with same data
	static Copy = function()
	{
		var trk = new TRKData();
		
		var i, j, k;
		
		trk.framecount = framecount;
		trk.trackcount = trackcount;
		trk.markercount = markercount;
		trk.framespersecond = framespersecond;
		trk.duration = duration;
		trk.flag = flag;
		trk.positionrange = [positionrange[0], positionrange[1]];
		trk.positionstep = positionstep;
		
		trk.matrixspace = matrixspace;
		trk.trackspace = trackspace;
		
		// Frame Matrices
		array_resize(trk.framematrices, framecount);
		i = 0;
		repeat(framecount)
		{
			trk.framematrices[@ i] = array_create(trackcount*16);
			array_copy(trk.framematrices[@ i], 0, framematrices[i], 0, trackcount*16);
			i++;
		}
		
		// Tracks
		array_resize(trk.tracks, trackcount);
		i = 0;
		repeat(framecount)
		{
			trk.framematrices[@ i] = array_create(trackcount*16);
			array_copy(trk.framematrices[@ i], 0, framematrices[i], 0, trackcount*16);
			i++;
		}
	}
	
	// Reads TRK data from file
	static Open = function(path)
	{
		OpenTRK(self, path);
		return self;
	}
	
	// Returns array of flat matrices with indices mapped to bone names
	function FitFrameMatrices(bonenames)
	{
		
	}

}

function TRKData_Track() constructor
{
	frames = [];
	vectors = [];
	count = 0;
}

// Removes allocated memory from trk struct (None yet)
function TRKFree(trk) constructor
{
	
}

// Returns animation struct from file (.trk)
function OpenTRK(outtrk, path)
{
	if filename_ext(path) == ""
	{
		path = filename_change_ext(path, ".trk");	
	}
	
	// File doesn't exist
	if ( !file_exists(path) )
	{
		show_debug_message("OpenTRK(): File does not exist. \"" + path + "\"");
		return -1;
	}
	
	var bzipped = buffer_load(path);
	var b = bzipped;
	
	// error reading file
	if bzipped < 0
	{
		show_debug_message("OpenTRK(): Error loading track data from \"" + path + "\"");
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
		b = buffer_decompress(bzipped);
		buffer_delete(bzipped);
	}
	
	var header;
	
	// Header
	header = buffer_peek(b, 0, buffer_u32);
	
	// Not a trk file
	if ( (header & 0x00FFFFFF) != TRKHEADERCODE )
	{
		show_debug_message("OpenTRK(): header is invalid \"" + path + "\"");
		return new VBMData();
	}
	
	switch(header & 0xFF)
	{
		default:
		
		// Version 2 (Sparse Matrices)
		case(2): 
		// Version 1
		case(1): 
			return __TRKOpen_v1(b, outtrk);
	}
	
	return -1;
}

function __TRKOpen_v1(b, outtrk)
{
	/* File spec:
	
    'TRK' (3B)
    TRK Version (1B)
    
    flags (1B)
    
    fps (1f)
    framecount (1I)
    numtracks (1I)
    duration (1f)
    positionstep (1f)
    
    tracknames[numtracks]
        namelength (1B)
        namechars[namelength]
            char (1B)
    
    matrixspace (1B)
        0 = No Matrices
        1 = LOCAL
        2 = POSE
        3 = WORLD
        4 = EVALUATED
    matrixdata[framecount]
        framematrices[numtracks]
            mat4 (16f)
    
    trackspace (1B)
        0 = No Tracks
        1 = LOCAL
        2 = POSE
        3 = WORLD
    trackdata[numtracks]
        numframes (1I)
        framepositions[numframes]
            position (1f)
        framevectors[numframes]
            vector[3]
                value (1f)
    
    nummarkers (1I)
    markernames[nummarkers]
        namelength (1B)
        namechars[namelength]
            char (1B)
    markerpositions[nummarkers]
        position (1f)
	
	*/
	
	var flag;
	
	var namelength;
	var name;
	
	// Header
	buffer_read(b, buffer_u32);
	
	// Flag
	flag = buffer_read(b, buffer_u8);
	outtrk.flag = flag;
	// Animation Original FPS
	outtrk.framespersecond = buffer_read(b, buffer_f32);
	// Frame Count
	outtrk.framecount = buffer_read(b, buffer_u32);
	// Track/Bone Count
	outtrk.trackcount = buffer_read(b, buffer_u32);
	// Duration
	outtrk.duration = buffer_read(b, buffer_f32);
	// Position Step
	outtrk.positionstep = buffer_read(b, buffer_f32);
	
	var float_type = buffer_f32;
	if ( flag & (1<<2) ) {float_type = buffer_f16;}
	else if ( flag & (1<<3) ) {float_type = buffer_f64;}
	
	// Transforms -------------------------------------------------
	
	var transformtracks;
	var track;
	var trackframes;
	var trackvectors;
	var numframes;
	var name;
	var vector;
	var vectorsize;
	var trackindex;
	var transformindex;
	var matarray;
	
	var i, v, f, n;
	
	var numtracks = outtrk.trackcount;
	
	array_resize(outtrk.tracks, numtracks);
	array_resize(outtrk.tracknames, numtracks);
	
	// Track Names
	trackindex = 0;
	repeat(numtracks)
	{
		name = "";
		namelength = buffer_read(b, buffer_u8);
		repeat(namelength)
		{
			name += chr( buffer_read(b, buffer_u8) );
		}
		outtrk.tracknames[trackindex] = name;
		outtrk.trackindices[$ name] = trackindex;
		trackindex++;
	}
	
	// Read Matrices
	outtrk.matrixspace = buffer_read(b, buffer_u8);
	if (outtrk.matrixspace > 0)
	{
		numframes = outtrk.framecount;
		n = numtracks*16;
		array_resize(outtrk.framematrices, numframes);
		
		f = 0;
		
		// Compressed Matrices
		if ( flag & (1 << 1) )
		{
			var mpos;
			printf("> Reading Compressed Matrices")
			// For each frame...
			repeat(numframes)
			{
				matarray = array_create(n);
				
				i = 0;
				// For each bone...
				repeat(numtracks)
				{
					repeat( buffer_peek(b, buffer_tell(b), buffer_u8) >> 4 )
					{
						mpos = buffer_read(b, buffer_u8) & 0xF;
						matarray[i+mpos] = buffer_read(b, float_type);
					}
					
					i += 16;
				}
				
				outtrk.framematrices[@ f++] = matarray;
			}
			printf("> Reading Complete")
		}
		// Uncompressed Matrices
		else
		{
			// For each frame...
			repeat(numframes)
			{
				matarray = array_create(n);
				
				// For each value in all matrices for frame
				i = 0;
				repeat(n)
				{
					matarray[i++] = buffer_read(b, float_type);
				}
			
				outtrk.framematrices[@ f++] = matarray;
			}
		}
	}
	
	// Read tracks
	outtrk.trackspace = buffer_read(b, buffer_u8);
	
	if (outtrk.trackspace > 0)
	{
		trackindex = 0;
		repeat(numtracks)
		{
			transformtracks = array_create(3); // [location<3>, quaternion<4>, scale<3>]
		
			// For each transform vector [location<3>, quaternion<4>, scale<3>]
			transformindex = 0;
			repeat(3)
			{
				vectorsize = (transformindex == 1)? 4:3; // 4 for quats, 3 for location and scale
			
				numframes = buffer_read(b, buffer_u32); // Frame Count
			
				track = new TRKData_Track();
				trackframes = array_create(numframes);
				trackvectors = array_create(numframes);
			
				// Frame Positions
				f = 0;
				repeat(numframes)
				{
					trackframes[f++] = buffer_read(b, float_type);
				}
			
				if numframes > 0
				{
					outtrk.positionrange[0] = min(outtrk.positionrange[0], trackframes[0]);
					outtrk.positionrange[1] = max(outtrk.positionrange[1], trackframes[numframes-1]);
				}
			
				// Frame Vectors
				f = 0;
				repeat(numframes)
				{
					vector = array_create(vectorsize);
					
					v = 0;
					repeat(vectorsize)
					{
						vector[v++] = buffer_read(b, float_type);
					}
				
					trackvectors[f++] = vector; // Vector
				}
			
				track.count = numframes;
				track.frames = trackframes;
				track.vectors = trackvectors;
				transformtracks[transformindex++] = track;
			}
			
			name = outtrk.tracknames[trackindex++];
			
			outtrk.tracks[trackindex] = transformtracks;
			outtrk.trackmap[$ name] = transformtracks;
		}
	}
	
	// Markers -----------------------------------------------------
	var nummarkers = buffer_read(b, buffer_u32);
	outtrk.markercount = nummarkers;
	
	array_resize(outtrk.markerpositions, nummarkers);
	array_resize(outtrk.markernames, nummarkers);
	
	// Marker Names
	i = 0;
	repeat(nummarkers)
	{
		name = "";
		namelength = buffer_read(b, buffer_u8);
		repeat(namelength)
		{
			name += chr( buffer_read(b, buffer_u8) );
		}
		
		outtrk.markernames[i++] = name;
	}
	
	// Marker Frames
	i = 0;
	repeat(nummarkers)
	{
		outtrk.markerpositions[i] = buffer_read(b, float_type);
		outtrk.markermap[$ outtrk.markernames[i] ] = outtrk.markerpositions[i];
		i++;
	}
	
	buffer_delete(b);
	
	return 1;
}

// Evaluates animation at given position and fills "outpose" with evaluated matrices
// Set "bonekeys" to 0 to use indices instead of bone names
function EvaluateAnimationTracks(
	trackdata,	// TRK struct for animation
	pos,	// 0-1 Value for animation position
	interpolationtype,	// Interpolation method for blending keyframes
	bonekeys,	// Bone names to map tracks to bones. 0 for track indices
	outpose
	)
{
	// ~16% of original time / ~625% speed increase with the YYC compiler
	
	var tracklist, tracklistmax;
	var b, bonename, outposematrix;
	var t, track, trackframes, trackvectors;
	var transformtracks;
	var posnext, posprev;
	var findexprev, findexnext, findexmax, blendamt;
	var vecprev, vecnext;
	
	var possearchstart;
	var ttype;
	
	// Quat Slerp
	var q1_0, q1_1, q1_2, q1_3,
		q2_0, q2_1, q2_2, q2_3,
		qOut0, qOut1, qOut2, qOut3,
		bT0, bT1, bT2, bT3, bT4, bT5, bT6, bT7,
		bD0, bD1, bD2, bD3, bD4, bD5, bD6, bD7,
		xml, d, sqrD, sqrT, f0, f1;
	// Quat to Mat4
	var q_length, q_hyp_sqr,
		q_c, q_s, q_omc;
	
	var mm = matrix_build_identity();
	var mmscale = array_create(16);
	mmscale[15] = 1;
	
	var _lastepsilon = math_get_epsilon();
	math_set_epsilon(0.000000000000001);
	
	// Map tracks
	if bonekeys == 0 // Bone Indices
	{
		tracklist = trackdata.tracks;
		tracklistmax = array_length(tracklist);
	}
	else // Bone Names
	{
		var trackmap = trackdata.trackmap;
		tracklistmax = array_length(bonekeys);
		tracklist = array_create(tracklistmax, 0);
		
		b = 0; repeat(tracklistmax)
		{
			bonename = bonekeys[b]; 
			
			// Matching bone name
			if variable_struct_exists(trackmap, bonename)
			{
				tracklist[b] = trackmap[$ bonename];
			}
			
			b++;
		}
	}
	
	// For each track
	t = 0; repeat(tracklistmax)
	{
		transformtracks = tracklist[t]; // [frames[], vectors[]]
		
		if transformtracks == 0 {t++; continue;}
		
		outposematrix = outpose[@ t]; // Target Bone Matrix
		t++;
		
		// For each transform (location, scale, rotation)
		// Performs in this order: Translation, Rotation, Scale
		ttype = 0;
		repeat(3)
		{
			track = transformtracks[ttype]; // TRKData_Track
			trackframes = track.frames;
			trackvectors = track.vectors;
			findexmax = track.count - 1;
			
			// Single Keyframe
			if (findexmax == 0)
			{
				vecprev = trackvectors[0];
				switch(ttype)
				{
					case(0): // Transform
						// Only copy to the location values (indices 12 to 15)
						array_copy(outposematrix, 12, vecprev, 12, 3);
						break;
					
					case(2): // Scale
						// Update the diagonal values of the temporary scale matrix
						mmscale[0] = vecprev[0];
						mmscale[5] = vecprev[1];
						mmscale[10] = vecprev[2];
						array_copy( outposematrix, 0, matrix_multiply(mmscale, outposematrix), 0, 16);
						break;
				
					case(1): // Quaternion
						// Quaternion to Mat4 ===================================================
						q1_0 = vecprev[0]; q1_1 = vecprev[1]; q1_2 = vecprev[2]; q1_3 = vecprev[3];
						q_length = sqrt(q1_1*q1_1 + q1_2*q1_2 + q1_3*q1_3);
						
						if (q_length == 0)
						{
							outposematrix[@ 0] = 1; outposematrix[@ 1] = 0; outposematrix[@ 2] = 0; //out[@ 3] = 0;
							outposematrix[@ 4] = 0; outposematrix[@ 5] = 1; outposematrix[@ 6] = 0; //out[@ 7] = 0;
							outposematrix[@ 8] = 0; outposematrix[@ 9] = 0; outposematrix[@10] = 1; //out[@11] = 0;
						}
						else
						{
							q_hyp_sqr = q_length*q_length + q1_0*q1_0;
							// Calculate trig coefficients
							q_c   = 2*q1_0*q1_0 / q_hyp_sqr - 1;
							q_s   = 2*q_length*q1_0*q_hyp_sqr;
							q_omc = 1 - q_c;
							// Normalize the input vector
							q1_1 /= q_length; q1_2 /= q_length; q1_3 /= q_length;
							// Build matrix
							outposematrix[@ 0] = q_omc*q1_1*q1_1 + q_c;
							outposematrix[@ 1] = q_omc*q1_1*q1_2 + q_s*q1_3;
							outposematrix[@ 2] = q_omc*q1_1*q1_3 - q_s*q1_2;
							outposematrix[@ 4] = q_omc*q1_1*q1_2 - q_s*q1_3;
							outposematrix[@ 5] = q_omc*q1_2*q1_2 + q_c;
							outposematrix[@ 6] = q_omc*q1_2*q1_3 + q_s*q1_1;
							outposematrix[@ 8] = q_omc*q1_1*q1_3 + q_s*q1_2;
							outposematrix[@ 9] = q_omc*q1_2*q1_3 - q_s*q1_1;
							outposematrix[@10] = q_omc*q1_3*q1_3 + q_c;
						}
						break;
				}
			}
			// Multiple Keyframes
			else if (findexmax > 0)
			{
				// Guess initial position
				findexprev = clamp( floor(pos*findexmax), 0, findexmax);
				possearchstart = trackframes[findexprev];
				
				if (possearchstart < pos) // Search starting from beginning moving forwards
				{
					findexnext = findexprev;
					while (pos >= trackframes[findexnext] && findexnext < findexmax) {findexnext++;}
					findexprev = max(findexnext - 1, 0);
				}
				else // Search starting from end moving backwards
				{
					while (pos <= trackframes[findexprev] && findexprev > 0) {findexprev--;}
					findexnext = min(findexprev + 1, findexmax);
				}
				
				posprev = trackframes[findexprev];	// Position of keyframe that "pos" is ahead of
				posnext = trackframes[findexnext];	// Position of next keyframe
			
				// Find Blend amount (Map "pos" distance to [0-1] value)
				blendamt = (pos - posprev) / (posnext - posprev); // More than one unit difference
				blendamt = clamp(blendamt, 0.0, 1.0);
				
				// Apply Interpolation
				if (interpolationtype == TRK_Intrpl.constant) {blendamt = blendamt >= 0.99;}
				else if (interpolationtype == TRK_Intrpl.smooth) {blendamt = 0.5*(1-cos(pi*blendamt));}
				
				// Apply Transform
				vecprev = trackvectors[findexprev];
				vecnext = trackvectors[findexnext];
				
				switch(ttype)
				{
					case(0): // Transform
						// Only copy to the location values (indices 12 to 15)
						outposematrix[@ 12] = lerp(vecprev[0], vecnext[0], blendamt);
						outposematrix[@ 13] = lerp(vecprev[1], vecnext[1], blendamt);
						outposematrix[@ 14] = lerp(vecprev[2], vecnext[2], blendamt);
						break;
					
					case(2): // Scale
						// Update the diagonal values of the temporary scale matrix
						mmscale[0] = lerp(vecprev[0], vecnext[0], blendamt);
						mmscale[5] = lerp(vecprev[1], vecnext[1], blendamt);
						mmscale[10] = lerp(vecprev[2], vecnext[2], blendamt);
						mm = matrix_multiply(mmscale, outposematrix);
						array_copy(outposematrix, 0, mm, 0, 16);
						break;
					
					case(1): // Quaternion
						// Fast Quaternion Slerp =====================================================
						/*
							Sourced from this paper by David Eberly, licensed under CC 4.0.
							Paper: https://www.geometrictools.com/Documentation/FastAndAccurateSlerp.pdf
							CC License: https://creativecommons.org/licenses/by/4.0/
						*/
						
						q1_0 = vecprev[0]; q1_1 = vecprev[1]; q1_2 = vecprev[2]; q1_3 = vecprev[3];
						q2_0 = vecnext[0]; q2_1 = vecnext[1]; q2_2 = vecnext[2]; q2_3 = vecnext[3];
						
						xml = (q1_0*q2_0 + q1_1*q2_1 + q1_2*q2_2 + q1_3*q2_3)-1;
						d = 1-blendamt; 
						sqrT = sqr(blendamt);
						sqrD = sqr(d);
						
						bT7 = (QUATSLERP_U7 * sqrT - QUATSLERP_V7) * xml;
						bT6 = (QUATSLERP_U6 * sqrT - QUATSLERP_V6) * xml;
						bT5 = (QUATSLERP_U5 * sqrT - QUATSLERP_V5) * xml;
						bT4 = (QUATSLERP_U4 * sqrT - QUATSLERP_V4) * xml;
						bT3 = (QUATSLERP_U3 * sqrT - QUATSLERP_V3) * xml;
						bT2 = (QUATSLERP_U2 * sqrT - QUATSLERP_V2) * xml;
						bT1 = (QUATSLERP_U1 * sqrT - QUATSLERP_V1) * xml;
						bT0 = (QUATSLERP_U0 * sqrT - QUATSLERP_V0) * xml;
						bD7 = (QUATSLERP_U7 * sqrD - QUATSLERP_V7) * xml;
						bD6 = (QUATSLERP_U6 * sqrD - QUATSLERP_V6) * xml;
						bD5 = (QUATSLERP_U5 * sqrD - QUATSLERP_V5) * xml;
						bD4 = (QUATSLERP_U4 * sqrD - QUATSLERP_V4) * xml;
						bD3 = (QUATSLERP_U3 * sqrD - QUATSLERP_V3) * xml;
						bD2 = (QUATSLERP_U2 * sqrD - QUATSLERP_V2) * xml;
						bD1 = (QUATSLERP_U1 * sqrD - QUATSLERP_V1) * xml;
						bD0 = (QUATSLERP_U0 * sqrD - QUATSLERP_V0) * xml;
						
						f0 = blendamt * (1+bT0*(1+bT1*(1+bT2*(1+bT3*(1+bT4*(1+bT5*(1+bT6*1+bT7)))))));
						f1 = d *		(1+bD0*(1+bD1*(1+bD2*(1+bD3*(1+bD4*(1+bD5*(1+bD6*1+bD7)))))));
						
						qOut0 = f0 * q1_0 + f1 * q2_0;
						qOut1 = f0 * q1_1 + f1 * q2_1;
						qOut2 = f0 * q1_2 + f1 * q2_2;
						qOut3 = f0 * q1_3 + f1 * q2_3;
						
						// Quaternion to Mat4 ===================================================
						q_length = sqrt(qOut1*qOut1 + qOut2*qOut2 + qOut3*qOut3);
						
						if (q_length == 0)
						{
							outposematrix[@ 0] = 1; outposematrix[@ 1] = 0; outposematrix[@ 2] = 0; //out[@ 3] = 0;
							outposematrix[@ 4] = 0; outposematrix[@ 5] = 1; outposematrix[@ 6] = 0; //out[@ 7] = 0;
							outposematrix[@ 8] = 0; outposematrix[@ 9] = 0; outposematrix[@10] = 1; //out[@11] = 0;
						}
						else
						{
							q_hyp_sqr = q_length*q_length + qOut0*qOut0;
							// Calculate trig coefficients
							q_c   = 2*qOut0*qOut0 / q_hyp_sqr - 1;
							q_s   = 2*q_length*qOut0*q_hyp_sqr;
							q_omc = 1 - q_c;
							// Normalize the input vector
							qOut1 /= q_length; qOut2 /= q_length; qOut3 /= q_length;
							// Build matrix
							outposematrix[@ 0] = q_omc*qOut1*qOut1 + q_c;
							outposematrix[@ 1] = q_omc*qOut1*qOut2 + q_s*qOut3;
							outposematrix[@ 2] = q_omc*qOut1*qOut3 - q_s*qOut2;
							outposematrix[@ 4] = q_omc*qOut1*qOut2 - q_s*qOut3;
							outposematrix[@ 5] = q_omc*qOut2*qOut2 + q_c;
							outposematrix[@ 6] = q_omc*qOut2*qOut3 + q_s*qOut1;
							outposematrix[@ 8] = q_omc*qOut1*qOut3 + q_s*qOut2;
							outposematrix[@ 9] = q_omc*qOut2*qOut3 - q_s*qOut1;
							outposematrix[@10] = q_omc*qOut3*qOut3 + q_c;
						}
						
						break;
				}
			}
			
			ttype++;
		}
	}
	
	math_set_epsilon(_lastepsilon);
	
	return outpose;
}

// Fills outtransform with calculated animation pose
// bone_parentindices = Array of parent index for bone at current index
// bone_localmatricies = Array of local 4x4 matrices for bones
// bone_inversemodelmatrices = Array of inverse 4x4 matrices for bones
// posedata = Array of 4x4 matrices. 2D
// outposetransform = Flat Array of matrices in localspace, size = len(posedata) * 16, give to shader
// outbonetransform = Array of bone matrices in modelspace
function CalculateAnimationPose(
	bone_parentindices, bone_localmatricies, bone_inversemodelmatrices, posedata, 
	outposetransform, outbonetransform = [])
{
	var n = min( array_length(bone_parentindices), array_length(posedata));
	var i;
	var m;
	var localtransform = array_create(n);	// Parent -> Bone
	//var outbonetransform = array_create(n);	// Origin -> Bone
	array_resize(outbonetransform, n);
	
	// Calculate animation for specific bone
	i = 0; repeat(n)
	{
		localtransform[i++] = matrix_multiply(
			posedata[i], bone_localmatricies[i]);
	}
	
	// Set the model transform of bone using parent transform
	// Only works if the parents preceed their children in array
	
	outbonetransform[@ 0] = localtransform[0]; // Edge case for root bone
	
	i = 1; repeat(n-1)
	{
		outbonetransform[@ i++] = matrix_multiply(
			localtransform[i], outbonetransform[ bone_parentindices[i] ]);
	}
	
	// Compute final matrix for bone
	i = 0; repeat(n)
	{
		array_copy(outposetransform, (i++)*16, matrix_multiply(bone_inversemodelmatrices[i], outbonetransform[i]), 0, 16);
	}
}

// Returns amount to move position in one frame
function TrackData_GetTimeStep(trkdata, framespersecond)
{
	return trkdata.positionstep*(trkdata.framespersecond/framespersecond);
}
