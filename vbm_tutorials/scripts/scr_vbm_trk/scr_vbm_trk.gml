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

enum TRK_TrackTransformType
{
	none = 0,
	location = 1,
	quaternion = 2,
	scale = 3,
	euler = 4,
}

enum TRK_CurveInterpolation
{
	constant = 0,
	linear = 1,
	bezier = 2,
}

// =================================================================================
#region // Structs
// =================================================================================

function TRKData() constructor
{
	matrixspace = TRK_Space.none; // 0 = None, 1 = Local, 2 = Pose, 3 = World, 4 = Evaluated
	
	trackspace = TRK_Space.none; // 0 = None, 1 = Local, 2 = Pose, 3 = World
	transformtracks = []; // array of 3 "TRKData_TrackTransform"s, one for each transform type; for each track
	tracknames = [];	// (bone) names for each track
	trackmap = {}; // {trackname: track} for each track
	trackindices = {};	// {trackname: index} for each track
	trackcount = 0;
	
	poses = new TRKData_TrackPose();	// Contains local-space transforms of each bone
	evaluations = new TRKData_TrackEvaluated(); // Contains final transforms of each bone
	
	curvegroups = [];	// array of array of TRKData_FCurve for Non-bone curves
	curvenames = [];	// Names for each curve
	curvemap = {}; // {curvename: curve group} for each curve
	curveindices = {};	// {curvename: index} for each curve
	curvecount = 0;
	
	markerpositions = []; // Frame positions in animation
	markermap = {};	// {markername: framepos} for each marker
	markernames = []; // names for markers
	markercount = 0;
	
	positionrange = [0, 1];
	positionstep = 1.0
	
	framespersecond = 60;	// Native fps value that animation was exported in
	duration = 0;	// Length in frames of animation
	flag = 0;
	
	isbaked = 0;	// 1 = Pose Baked, 2 = Evaluated Baked
	
	// Accessors -------------------------------------------------------------------
	
	static Flags = function() {return flag;}
	static Duration = function() {return duration;}
	static PositionStep = function() {return positionstep;}
	static CalculateTimeStep = function(fps) {return (framespersecond/fps)/duration;}
	
	static MatrixSpace = function() {return matrixspace;}
	static TrackSpace = function() {return trackspace;}
	
	static GetPoseData = function() {return poses;}
	static GetEvaluatedData = function() {return evaluatedmatrices;}
	
	static TransformTracks = function() {return transformtracks;}
	static TrackCount = function() {return trackcount;}
	static TrackNames = function() {return tracknames;}
	static GetTrack = function(index) {return transformtracks[index];}
	static GetTrackName = function(index) {return tracknames[index];}
	
	static MarkerCount = function() {return markercount;}
	static MarkerPositions = function() {return markerpositions;}
	static MarkerNames = function() {return markernames;}
	static MarkerExists = function(key) {return variable_struct_exists(markermap, key);}
	static GetMarkerPositionIndex = function(index) {return markerpositions[index];}
	static GetMarkerPositionKey = function(key) {return markermap[$ key];}
	static GetMarkerName = function(index) {return markernames[index];}
	
	// Methods -------------------------------------------------------------------
	
	// Used when struct is given to string() function
	static toString = function()
	{
		return "TRKData: {" + 
			"Duration: " + string(duration) + ", " +
			"Tracks: " + string(trackcount) + ", " +
			"Poses: " + string(poses.count) + ", " +
			"Evaluations: " + string(evaluations.count) + ", " +
			"FCurves: " + string(curvecount) + ", " +
			"Markers: " + string(markercount) + "}";
	}
	
	// Returns new trk with data
	static CopyFromOther = function(othertrk)
	{
		Clear();
		
		matrixspace = othertrk.matrixspace;
		trackspace = othertrk.trackspace;
		
		positionstep = othertrk.positionstep;
		framespersecond = othertrk.framespersecond;
		duration = othertrk.duration;
		flag = othertrk.flag;
		isbaked = othertrk.isbaked;
		
		// Tracks
		trackcount = othertrk.trackcount;
		array_resize(transformtracks, trackcount);
		array_resize(tracknames, trackcount);
		
		for (var i = 0; i < trackcount; i++)
		{
			transformtracks[i] = [
				othertrk.transformtracks[i][0].Duplicate(),
				othertrk.transformtracks[i][1].Duplicate(),
				othertrk.transformtracks[i][2].Duplicate()
			];
			
			tracknames[i] = othertrk.tracknames[i];
			trackmap[$ tracknames[i]] = transformtracks[i];
			trackindices[$ tracknames[i]] = i;
		}
		
		poses = othertrk.poses.Duplicate();
		evaluations = othertrk.evaluations.Duplicate();
		
		// Curves
		curvecount = othertrk.curvecount;
		
		var group;
		
		for (var i = 0; i < curvecount; i++)
		{
			group = other.curvegroups[i];
			var n = array_length(group)
			
			curvegroups[i] = array_create(n);
			
			for (var j = 0; j < n; j++)
			{
				curvegroups[i][j] = group[j].Duplicate();
			}
			
			curvenames[i] = othertrk.curvenames[i];
			curvemap[$ curvenames[i]] = curvegroups[i];
			curveindices[$ tracknames[i]] = i;
		}
		
		// Markers
		markercount = othertrk.markercount;
		
		for (var i = 0; i < markercount; i++)
		{
			markerpositions[i] = othertrk.markerpositions[i];
			markernames[i] = othertrk.markernames[i];
			markermap[$ markernames[i]] = markerpositions[i];
		}
		
		return self;
	}
	
	static Duplicate = function()
	{
		var othertrk = new TRKData();
		othertrk.CopyFromOther(self);
		return othertrk;
	}
	
	// Removes all data from TRKData
	static Clear = function()
	{
		ClearTracks();
		ClearPoses();
		ClearEvaluations();
		ClearCurves();
		ClearMarkers();
		
		duration = 0;
		
		return self;
	}
	
	static ClearTracks = function()
	{
		array_resize(transformtracks, 0);
		array_resize(tracknames, 0);
		trackmap = {};
		trackindices = {};
		trackcount = 0;
		
		return self;
	}
	
	static ClearPoses = function()
	{
		delete poses;
		poses = new TRKData_TrackPose();
		
		return self;
	}
	
	static ClearEvaluations = function()
	{
		delete evaluations;
		evaluations = new TRKData_TrackPose();
		
		return self;
	}
	
	static ClearCurves = function()
	{
		array_resize(curvegroups, 0);
		array_resize(curvenames, 0);
		curvemap = {};
		curveindices = {};
		curvecount = 0;
		
		return self;
	}
	
	static ClearMarkers = function()
	{
		array_resize(markerpositions, 0);
		array_resize(markernames, 0);
		markermap = {};
		markercount = 0;
		
		return self;
	}
	
	// Reads TRK data from file
	static Open = function(path)
	{
		OpenTRK(self, path);
		return self;
	}
	
	// Calculates local and/or evaluated matrices for animation using tracks
	static BakeToMatrices = function(
		bonenames, 
		parentindices, 
		localtransforms, 
		inversetransforms,
		frame_step=1,	// Step : Frame ratio. 2 = "duration" / 2 frames, 0.5 = "duration" x 2 frames
		compare_thresh=0.01, 
		to_local=true, 
		to_evaluated=true
		)
	{
		var numframes = duration;
		
		// Bake to local-space transforms
		if ( isbaked < 1 && (to_local || to_evaluated) )
		{
			var lastpose = Mat4Array(200);
			var temppose = Mat4Array(200);
			var d = compare_thresh;
			var frame = 0;
			
			poses.InitializeArrays(0, trackcount);
			
			frame = 0;
			repeat(max(numframes / frame_step))
			{
				EvaluateAnimationTracks(
					self,
					frame/(duration-1),
					TRK_Intrpl.linear, 
					0,
					temppose
					);
				
				// Crude matrix distance testing
				for (var i = 0; i < poses.posesize; i++)
				{
					d += (
						abs(temppose[i][ 0] - lastpose[i][ 0]) +
						abs(temppose[i][ 1] - lastpose[i][ 1]) +
						abs(temppose[i][ 2] - lastpose[i][ 2]) +
						abs(temppose[i][ 4] - lastpose[i][ 4]) +
						abs(temppose[i][ 5] - lastpose[i][ 5]) +
						abs(temppose[i][ 6] - lastpose[i][ 6]) +
						abs(temppose[i][ 8] - lastpose[i][ 8]) +
						abs(temppose[i][ 9] - lastpose[i][ 9]) +
						abs(temppose[i][10] - lastpose[i][10]) +
						abs(temppose[i][12] - lastpose[i][12]) +
						abs(temppose[i][13] - lastpose[i][13]) +
						abs(temppose[i][14] - lastpose[i][14]) +
						abs(temppose[i][15] - lastpose[i][15])
					);
				}
				
				if ( d >= compare_thresh )
				{
					poses.count += 1;
					array_push(poses.framepositions, frame/duration);
					array_push(poses.frametransforms, temppose);
					
					lastpose = temppose;
					temppose = Mat4Array(200);
					
					d = 0;
				}
				
				frame += frame_step;
			}
			
			isbaked = 1;
		}
		
		// Bake to evaluated/final transforms
		if ( isbaked < 2 || to_evaluated )
		{
			evaluations.InitializeArrays(poses.count, trackcount);
			array_copy(evaluations.framepositions, 0, poses.framepositions, 0, poses.count);
			
			var f = 0;
			repeat(poses.count)
			{
				CalculateAnimationPose(
					parentindices, 
					localtransforms, 
					inversetransforms, 
					poses.frametransforms[f],
					evaluations.framematrices[f]
					);
						
				f++;
			}
			
			isbaked = 2;
		}
	}
	
	// Returns pose transforms matching position
	static FindPoseByPosition = function(pos)
	{
		var n = poses.count;
		var framepositions = poses.framepositions;
		var i = 0;
		
		while ( pos > framepositions[i+1] && i < (n-2) ) {i++;}
		
		return poses.frametransforms[i];
	}
	
	// Returns pose transforms matching marker position, default_position if not found
	static FindPoseByMarker = function(markername, default_position=undefined)
	{
		return MarkerExists(markername)? FindPoseByPosition(markerpositions[$ markername]): default_position;
	}
	
	// Returns evaluation matrices matching position
	static FindEvaluationByPosition = function(pos)
	{
		var n = evaluations.count;
		var framepositions = evaluations.framepositions;
		var i = 0;
		
		while ( pos > framepositions[i+1] && i < (n-2) ) {i++;}
		
		return evaluations.framematrices[i];
	}
	
	// Returns evaluation matrices matching marker position, default_position if not found
	static FindEvaluationByMarker = function(markername, default_position=undefined)
	{
		return MarkerExists(markername)? FindEvaluationByPosition(markerpositions[$ markername]): default_position;
	}
	
	// Returns value from curves if exists, else default_value
	static EvaluateFCurveValue = function(curvename, default_value=undefined, index=0)
	{
		return CurveExists(curvename)?
			curvemap[$ curvename][index]:
			default_value;
	}
	
	// Returns vector from curves if exists, else default_vector
	static EvaluateFCurveVector = function(curvename, default_vector=undefined)
	{
		return variable_struct_exists(outcurves, curvename)? outcurves[$ curvename]: default_vector;
	}
	
}

/*
	Contains keyframes and values for transforms for one type of transform:
	Location, Quaternion Rotation, Euler Rotation, or Scale.
	Keyframe positions are in range [0, 1]
	"frame" and "vectors" arrays both have the same size of "count"
	Each element in "vectors" have size "vectorsize"
*/
function TRKData_TrackTransform() constructor
{
	count = 0;
	transformtype = TRK_TrackTransformType.none;	// loc, quat, euler, or scale
	vectorsize = 0;	// Size of each element in "vectors" array. 3 for loc, 4 for quat, 3, for euler, 3 for scale
	frames = [];	// Keyframe for each vector of size <count> [ frame, frame, ... ]
	vectors = [];	// Transform of size <count> [ value[vectorsize], value[vectorsize], ... ]
	
	static Duplicate = function()
	{
		var f;
		var out = new TRKData_TrackTransform();
		
		out.count = count;
		out.transformtype = transformtype;
		out.vectorsize = vectorsize;
		
		array_resize(out.frames, count);
		array_resize(out.vectors, count);
		
		f = 0;
		repeat(count)
		{
			out.framepositions[f] = framepositions[f];
			out.vectors[f] = array_create(vectorsize);
			array_copy(out.vectors[f], 0, vectors[f], 0, vectorsize);
			
			f++;
		}
		
		return out;
	}
}

/*
	Contains keyframes and values for property curves.
	Keyframe positions are in range [0, 1]
	"frame" and "values" arrays both have the same size of "count"
*/
function TRKData_FCurve() constructor
{
	array_index = -1;
	propertyname = "";
	framepositions = [];
	frameinterpolations = [];
	values = [];
	count = 0;
	
	static Add = function(position, value, interpolation)
	{
		framepositions[count] = position;
		values[count] = value;
		frameinterpolations[count] = interpolation;
		count++;
		
		return self;
	}
	
	static SetData = function(n, positionarray, valuearray, interpolationarray)
	{
		count = n;
		
		array_resize(framepositions, n);
		array_resize(values, n);
		array_resize(frameinterpolations, n);
		
		array_copy(framepositions, 0, positionarray, 0, n);
		array_copy(values, 0, valuearray, 0, n);
		array_copy(frameinterpolations, 0, interpolationarray, 0, n);
		
		return self;
	}
	
	static Duplicate = function()
	{
		var out  = new TRKData_FCurve();
		var f;
		
		out.count = count;
		out.array_index = array_index;
		out.propertyname = propertyname;
		
		array_resize(out.framepositions, count);
		array_resize(out.vectors, count);
		
		f = 0;
		repeat(count)
		{
			out.framepositions[f] = framepositions[f];
			out.values[f] = values[f];
			
			f++;
		}
		
		return out;
	}
	
	static Evaluate = function(pos, default_value=undefined)
	{
		if ( count == 0 ) {return default_value;}
		if ( count == 1 ) {return values[0];}
		
		var positions = framepositions;
		var n = count;
		var iprev = 0, inext = 1;
		var amt;
		
		while ( pos > positions[inext] && inext < (n-1) ) {iprev++; inext++;}
		amt = (pos-positions[iprev]) / (positions[inext]-positions[iprev]);
		
		switch(frameinterpolations[iprev])
		{
			case(TRK_CurveInterpolation.constant): return values[iprev];
			default:
			case(TRK_CurveInterpolation.linear): return lerp(values[iprev], values[inext], amt);
			case(TRK_CurveInterpolation.bezier): return lerp(values[iprev], values[inext], amt);	// Not supported
		}
		
		return values[0];
	}
}

/*
	Contains keyframes and corresponding matrix arrays for local transforms.
	Keyframe positions are in range [0, 1]
	"frame" and "matrices" arrays both have the same size of "count"
*/
function TRKData_TrackPose() constructor
{
	count = 0;
	framepositions = [];	// Array of keyframe positions: [frame, frame, ...]
	frametransforms = [];	// Array of matrix arrays for each frame: [ mat4[posesize], mat4[posesize], ... ]
	posesize = 200;	// Number of matrices for each element in "poses"
	
	// Init
	static InitializeArrays = function(n, elementsize=0)
	{
		if (elementsize <= 0) {elementsize = posesize;}
		
		count = n;
		posesize = elementsize;
		framepositions = array_create(count);
		frametransforms = array_create(count);
		
		for (var f = 0; f < count; f++)
		{
			for (var m = 0; m < posesize; m++)
			{
				frametransforms[f][m] = matrix_build_identity();
			}
		}
		
		return self;
	}
	
	static Duplicate = function()
	{
		var f, m;
		var out = new TRKData_TrackPose();
		
		out.count = count;
		out.posesize = posesize;
		
		array_resize(out.framepositions, count);
		array_resize(out.frametransforms, count);
		
		f = 0;
		repeat(count)
		{
			out.framepositions[f] = framepositions[f];
			out.frametransforms[f] = array_create(posesize);
			
			m = 0;
			repeat(posesize)
			{
				out.frametransforms[f][m] = matrix_build_identity();
				array_copy(out.frametransforms[f][m], 0, frametransforms[f][m], 0, 16);
				m++;
			}
			
			f++;
		}
		
		return out;
	}
}

/*
	Contains keyframes and matrix arrays for transforms.
	Keyframe positions are in range [0, 1]
	"frame" and "matrices" arrays both have the same size of "count"
*/
function TRKData_TrackEvaluated() constructor
{
	count = 0;
	framepositions = [];
	framematrices = [];
	matrixcount = 200;	// Number of matrices per frame. Values = ("matrixcount" * 16)
	
	// Init
	static InitializeArrays = function(n, elementsize=0)
	{
		if (elementsize <= 0) {elementsize = matrixcount;}
		
		count = n;
		matrixcount = elementsize;
		array_resize(framepositions, count);
		array_resize(framematrices, count);
		
		for (var f = 0; f < count; f++)
		{
			framematrices[f] = array_create(matrixcount * 16);
		}
		
		return self;
	}
	
	static Duplicate = function()
	{
		var f;
		var out = new TRKData_TrackEvaluated();
		
		out.count = count;
		out.matrixcount = matrixcount;
		
		array_resize(out.framepositions, count);
		array_resize(out.framematrices, count);
		
		f = 0;
		repeat(count)
		{
			out.framepositions[f] = framepositions[f];
			out.framematrices[f] = array_create(matrixcount*16);
			array_copy(out.framematrices[f], 0, framematrices[f], 0, matrixcount*16);
			f++;
		}
		
		return out;
	}
}

#endregion // ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

// =================================================================================
#region // Functions
// =================================================================================

// Removes allocated memory from trk struct. (None yet)
function TRKFree(trk) constructor
{
	trk.Clear();
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
		( _header == 0x0178 ) ||
		( _header == 0x9C78 ) ||
		( _header == 0xDA78 )
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
		
		// Version 4 (Interpolation)
		case(4):
		// Version 3 (FCurves)
		case(3): 
		// Version 2 (Sparse Matrices)
		case(2): 
		// Version 1
		case(1):
			return __TRKOpen_v1(b, outtrk);
	}
	
	return -1;
}

// Populates struct with {fname: TRKData}
function OpenTRKDirectory(dir, outtrkstruct={})
{
	var _lastchar = string_char_at(dir, string_length(dir));
	if ( _lastchar != "/" && _lastchar != "\\" )
	{
		dir += "\\";
	}
	
	var err;
	try
	{
		var trk;
		var fname = file_find_first(dir + "*.trk", 0);
	
		while (fname != "")
		{
			trk = new TRKData();
			trk.Open(dir+fname);
			
			variable_struct_set(outtrkstruct, filename_change_ext(fname, ""), trk);
			
			fname = file_find_next();
		}
	}
	catch (err)
	{
		show_debug_message(err);
	}
	
	file_find_close();
	
	return outtrkstruct;
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
	var version = (buffer_read(b, buffer_u32) >> 24) & 0xFF;
	
	// Flag
	flag = buffer_read(b, buffer_u8);
	outtrk.flag = flag;
	// Animation Original FPS
	outtrk.framespersecond = buffer_read(b, buffer_f32);
	// Frame Count (old. Use duration)
	if ( version < 4 )
	{
		buffer_read(b, buffer_u32);
	}
	// Track/Bone Count
	outtrk.trackcount = buffer_read(b, buffer_u32);
	// Non-Bone Curve Count
	if (version >= 3)
	{
		outtrk.curvecount = buffer_read(b, buffer_u32);
	}
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
	var curvegroup;
	var curve;
	var curveframes;
	var curvevalues;
	var curveinterpolations;
	
	var i, v, f, n;
	
	var numtracks = outtrk.trackcount;
	
	array_resize(outtrk.transformtracks, numtracks);
	array_resize(outtrk.tracknames, numtracks);
	
	// Track Names ---------------------------------------------------------------------
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
	
	// Read Matrices -------------------------------------------------------------------
	outtrk.matrixspace = buffer_read(b, buffer_u8);
	
	if (outtrk.matrixspace > 0)
	{
		numframes = outtrk.duration;
		n = numtracks*16;
		array_resize(outtrk.evaluatedmatrices, numframes);
		
		f = 0;
		
		// Compressed Matrices
		if ( flag & (1 << 1) )
		{
			var mpos;
			
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
				
				outtrk.evaluatedmatrices[@ f++] = matarray;
			}
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
			
				outtrk.evaluatedmatrices[@ f++] = matarray;
			}
		}
	}
	
	// Read tracks ---------------------------------------------------------------------
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
			
				track = new TRKData_TrackTransform();
				trackframes = array_create(numframes);
				trackvectors = array_create(numframes);
				track.vectorsize = vectorsize;
				
				if (transformindex == 0) {track.transformtype = TRK_TrackTransformType.location;}
				else if (transformindex == 1) {track.transformtype = TRK_TrackTransformType.quaternion;}
				else if (transformindex == 2) {track.transformtype = TRK_TrackTransformType.scale;}
				
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
				track.framepositions = trackframes;
				track.vectors = trackvectors;
				transformtracks[transformindex++] = track;
			}
			
			name = outtrk.tracknames[trackindex];
			
			outtrk.transformtracks[trackindex] = transformtracks;
			outtrk.trackmap[$ name] = transformtracks;
			
			trackindex++;
		}
	}
	
	// Read Curves ---------------------------------------------------------------------
	
	// Curve Names
	var numcurves = outtrk.curvecount;
	var namelist = array_create(numcurves);
	
	trackindex = 0;
	repeat(numcurves)
	{
		name = "";
		namelength = buffer_read(b, buffer_u8);
		repeat(namelength)
		{
			name += chr( buffer_read(b, buffer_u8) );
		}
		namelist[trackindex] = name;
		trackindex++;
	}
	
	// Curve Data
	trackindex = 0;
	repeat(numcurves)
	{
		// Values
		vectorsize = buffer_read(b, buffer_u8);
		curvegroup = array_create(vectorsize);
		transformindex = 0;
		
		name = namelist[trackindex];
		
		repeat(vectorsize)
		{
			curve = new TRKData_FCurve();
			curve.propertyname = name;
			curve.array_index = buffer_read(b, buffer_u32);
			
			numframes = buffer_read(b, buffer_u32); // Frame Count
			
			curveframes = array_create(numframes);
			curvevalues = array_create(numframes);
			curveinterpolations = array_create(numframes);
			
			// Frame Positions
			f = 0;
			repeat(numframes)
			{
				curveframes[f++] = buffer_read(b, float_type);
			}
			
			// Frame Values
			f = 0;
			repeat(numframes)
			{
				curvevalues[f++] = buffer_read(b, float_type);
			}
			
			// Frame Interpolations
			if (version >= 4)
			{
				f = 0;
				repeat(numframes)
				{
					curveinterpolations[f++] = buffer_read(b, buffer_u8);
				}
			}
			
			curve.SetData(numframes, curveframes, curvevalues, curveinterpolations);
			curvegroup[transformindex++] = curve;
		}
		
		outtrk.curvenames[trackindex] = name;
		outtrk.curveindices[$ name] = trackindex;
		outtrk.curvegroups[trackindex] = curvegroup;
		outtrk.curvemap[$ name] = curvegroup;
			
		trackindex++;
	}
	
	// Markers ---------------------------------------------------------------------
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

#endregion // ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

