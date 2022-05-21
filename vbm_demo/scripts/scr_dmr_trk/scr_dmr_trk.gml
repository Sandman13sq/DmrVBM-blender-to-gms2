/*
	Track data struct for animation playback
*/

#macro TRKHEADERCODE 0x004b5254

enum TRK_Intrpl
{
	constant = 0,
	linear = 1,
	smooth = 2,
}

function TRKData() constructor
{
	matrixspace = 0; // 0 = None, 1 = Local, 2 = Pose, 3 = World, 4 = Evaluated
	framematrices = []; // Array of flat matrix arrays for each frame
	
	trackspace = 0; // 0 = None, 1 = Local, 2 = Pose, 3 = World
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
	
	var bzipped = buffer_load(path);
	
	if bzipped < 0
	{
		show_debug_message("OpenTRK(): Error loading track data from \"" + path + "\"");
		return -1;
	}
	
	var b = buffer_decompress(bzipped);
	if b < 0 {b = bzipped;} else {buffer_delete(bzipped);}
	
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
	var m;
	
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
		repeat(numframes)
		{
			matarray = array_create(n);
			
			i = 0;
			repeat(n)
			{
				matarray[i++] = buffer_read(b, buffer_f32);
			}
			
			/*
			matarray = array_create(numtracks);
			for (trackindex = 0; trackindex < numtracks; trackindex++)
			{
				m = matrix_build_identity();
				for (var i = 0; i < 16; i++)
				{
					m[i] = buffer_read(b, buffer_f32);
				}
				matarray[@ trackindex] = m;
			}
			*/
			
			outtrk.framematrices[@ f++] = matarray;
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
					trackframes[f++] = buffer_read(b, buffer_f32);
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
						vector[v++] = buffer_read(b, buffer_f32);
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
		outtrk.markerpositions[i] = buffer_read(b, buffer_f32);
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
	var posnext, poscurr;
	var findexcurr, findexnext, findexmax, blendamt;
	var veccurr, vecnext;
	var quat = [0.0, 0.0, 0.0, 1.0];
	
	var possearchstart;
	var ttype;
	
	// Quat Slerp
	var q1_0, q1_1, q1_2, q1_3,
		q2_0, q2_1, q2_2, q2_3,
		cosHalfTheta, reverse_q1, halfTheta, sinHalfTheta,
		ratioA, ratioB;
	// Quat to Mat4
	var q_length, q_hyp_sqr,
		q_c, q_s, q_omc;
	
	if pos < 0.5 {possearchstart = 0;}
	else {possearchstart = 1.0;}
	
	var mm = matrix_build_identity();
	
	var _lastepsilon = math_get_epsilon();
	math_set_epsilon(0.00000000000000001);
	
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
				veccurr = trackvectors[0];
				switch(ttype)
				{
					case(0): // Transform
						array_copy(outposematrix, 12, veccurr, 12, 3);
						break;
					
					case(2): // Scale
						array_copy(
							outposematrix, 
							0,
							matrix_multiply(
								matrix_build(0,0,0, 0,0,0,
									veccurr[0],
									veccurr[1],
									veccurr[2]
									),
								outposematrix),
							0, 16
							);
						break;
				
					case(1): // Quaternion
						//QuatToMat4_r( veccurr, outposematrix );
						// Quaternion to Mat4 ===================================================
						q1_0 = veccurr[0]; q1_1 = veccurr[1]; q1_2 = veccurr[2]; q1_3 = veccurr[3];
						//q_length = sqrt(q1_1*q1_1 + q1_2*q1_2 + q1_3*q1_3);
						q_length = point_distance_3d(0,0,0, q1_1, q1_2, q1_3);
						if q_length == 0
						{
							outposematrix[@ 0] = 1; outposematrix[@ 1] = 0; outposematrix[@ 2] = 0; //out[@ 3] = 0;
							outposematrix[@ 4] = 0; outposematrix[@ 5] = 1; outposematrix[@ 6] = 0; //out[@ 7] = 0;
							outposematrix[@ 8] = 0; outposematrix[@ 9] = 0; outposematrix[@10] = 1; //out[@11] = 0;
						}
						else
						{
							q_hyp_sqr = q_length*q_length + q1_0*q1_0;
							//Calculate trig coefficients
							q_c   = 2*q1_0*q1_0 / q_hyp_sqr - 1;
							q_s   = 2*q_length*q1_0*q_hyp_sqr;
							q_omc = 1 - q_c;
							//Normalize the input vector
							q1_1 /= q_length; q1_2 /= q_length; q1_3 /= q_length;
							//Build matrix
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
					while (pos <= trackframes[findexcurr] && findexcurr > 0) {findexcurr--;}
					findexnext = min(findexcurr + 1, findexmax);
				}
				
				poscurr = trackframes[findexcurr];	// Position of keyframe that "pos" is ahead of
				posnext = trackframes[findexnext];	// Position of next keyframe
			
				// Find Blend amount (Map "pos" distance to [0-1] value)
				if poscurr >= posnext {blendamt = 1;} // Same frame
				else {blendamt = (pos - poscurr) / (posnext - poscurr);} // More than one unit difference
				
				blendamt = clamp(blendamt, 0.0, 1.0);
				
				// Apply Interpolation
				switch(interpolationtype)
				{
					case(TRK_Intrpl.constant): blendamt = blendamt >= 0.99; break;
					//case(TRK_Intrpl.linear): blendamt = blendamt; break;
					case(TRK_Intrpl.smooth): blendamt = 0.5*(1-cos(pi*blendamt)); break;
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
					
					case(2): // Scale
						mm = matrix_multiply(
							matrix_build(0,0,0, 0,0,0,
								lerp(veccurr[0], vecnext[0], blendamt),
								lerp(veccurr[1], vecnext[1], blendamt),
								lerp(veccurr[2], vecnext[2], blendamt)
								),
							outposematrix);
						array_copy(outposematrix, 0, mm, 0, 16);
						//outposematrix[@  0] = lerp(veccurr[0], vecnext[0], blendamt);
						//outposematrix[@  5] = lerp(veccurr[1], vecnext[1], blendamt);
						//outposematrix[@ 10] = lerp(veccurr[2], vecnext[2], blendamt);
						break;
					
					case(1): // Quaternion
						//QuatSlerp_r(veccurr, vecnext, blendamt, quat);
						// Quaternion Slerp =====================================================
						q1_0 = veccurr[0]; q1_1 = veccurr[1]; q1_2 = veccurr[2]; q1_3 = veccurr[3];
						q2_0 = vecnext[0]; q2_1 = vecnext[1]; q2_2 = vecnext[2]; q2_3 = vecnext[3];
						
						// Calculate angle between them.
						cosHalfTheta = q1_3 * q2_3 + q1_0 * q2_0 + q1_1 * q2_1 + q1_2 * q2_2;
						// if q1=q2 or q1=-q2 then theta = 0 and we can return q1
						if (abs(cosHalfTheta) >= 1.0)
						{
							quat[@ 3] = q1_3;
							quat[@ 0] = q1_0;
							quat[@ 1] = q1_1;
							quat[@ 2] = q1_2;
						}
						else
						{
							// Follow shortest path
							reverse_q1 = 0;
							if (cosHalfTheta < 0.0)
							{
								reverse_q1 = 1;
								cosHalfTheta = -cosHalfTheta;
							}
						
							// Calculate temporary values.
							halfTheta = arccos(cosHalfTheta);
							sinHalfTheta = sqrt(1.0 - cosHalfTheta*cosHalfTheta);
							// if theta = 180 degrees then result is not fully defined
							// we could rotate around any axis normal to q1 or q2
							if (abs(sinHalfTheta) < 0.000001)
							{
								if !reverse_q1
								{
									quat[@ 3] = (q1_3 * 0.5 + q2_3 * 0.5);
									quat[@ 0] = (q1_0 * 0.5 + q2_0 * 0.5);
									quat[@ 1] = (q1_1 * 0.5 + q2_1 * 0.5);
									quat[@ 2] = (q1_2 * 0.5 + q2_2 * 0.5);
								}
								else
								{
									quat[@ 3] = (q1_3 * 0.5 - q2_3 * 0.5);
									quat[@ 0] = (q1_0 * 0.5 - q2_0 * 0.5);
									quat[@ 1] = (q1_1 * 0.5 - q2_1 * 0.5);
									quat[@ 2] = (q1_2 * 0.5 - q2_2 * 0.5);
								}
							}
							else
							{
								ratioA = sin((1.0 - blendamt) * halfTheta) / sinHalfTheta;
								ratioB = sin(blendamt * halfTheta) / sinHalfTheta; 
								// calculate Quaternion.
								if !reverse_q1
								{
									quat[@ 3] = (q1_3 * ratioA + q2_3 * ratioB);
									quat[@ 0] = (q1_0 * ratioA + q2_0 * ratioB);
									quat[@ 1] = (q1_1 * ratioA + q2_1 * ratioB);
									quat[@ 2] = (q1_2 * ratioA + q2_2 * ratioB);
								}
								else
								{
									quat[@ 3] = (q1_3 * ratioA - q2_3 * ratioB);
									quat[@ 0] = (q1_0 * ratioA - q2_0 * ratioB);
									quat[@ 1] = (q1_1 * ratioA - q2_1 * ratioB);
									quat[@ 2] = (q1_2 * ratioA - q2_2 * ratioB);
								}
							}
						}
						//QuatToMat4_r( quat, outposematrix );
						// Quaternion to Mat4 ===================================================
						q1_0 = quat[0]; q1_1 = quat[1]; q1_2 = quat[2]; q1_3 = quat[3];
						//q_length = sqrt(q1_1*q1_1 + q1_2*q1_2 + q1_3*q1_3);
						q_length = point_distance_3d(0,0,0, q1_1, q1_2, q1_3)
						if q_length == 0
						{
							outposematrix[@ 0] = 1; outposematrix[@ 1] = 0; outposematrix[@ 2] = 0; //out[@ 3] = 0;
							outposematrix[@ 4] = 0; outposematrix[@ 5] = 1; outposematrix[@ 6] = 0; //out[@ 7] = 0;
							outposematrix[@ 8] = 0; outposematrix[@ 9] = 0; outposematrix[@10] = 1; //out[@11] = 0;
						}
						else
						{
							q_hyp_sqr = q_length*q_length + q1_0*q1_0;
							//Calculate trig coefficients
							q_c   = 2*q1_0*q1_0 / q_hyp_sqr - 1;
							q_s   = 2*q_length*q1_0*q_hyp_sqr;
							q_omc = 1 - q_c;
							//Normalise the input vector
							q1_1 /= q_length; q1_2 /= q_length; q1_3 /= q_length;
							//Build matrix
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
		m = matrix_multiply(bone_inversemodelmatrices[i], outbonetransform[i]);
		array_copy(outposetransform, (i++)*16, m, 0, 16);
	}
}

// Returns amount to move position in one frame
function TrackData_GetTimeStep(trkdata, framespersecond)
{
	return trkdata.positionstep*(trkdata.framespersecond/framespersecond);
}