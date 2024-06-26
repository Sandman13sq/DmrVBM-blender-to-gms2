/*
	VBM definition and functions.
	By Sandman13sq
	
	Updates found on GitHub Repository: 
	https://github.com/Sandman13sq/DmrVBM-blender-to-gms2
	
	More information on GitHub Wiki:
	https://github.com/Sandman13sq/DmrVBM-blender-to-gms2/wiki
	
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

// Header code at start of VBM files = 'VBMX' where X = version
#macro VBMHEADERCODE 0x004D4256

// Max number of bones for pose matrix array
#macro VBM_MATPOSEMAX global.g_VBM_MatPoseMax
VBM_MATPOSEMAX = 128;	// <- Change at start of game as you wish

#macro VBM_ATTRIBUTE_OTHER 0
#macro VBM_ATTRIBUTE_POSITION 1
#macro VBM_ATTRIBUTE_UV 2
#macro VBM_ATTRIBUTE_UVBYTES 3
#macro VBM_ATTRIBUTE_NORMAL 4
#macro VBM_ATTRIBUTE_TANGENT 5
#macro VBM_ATTRIBUTE_BITANGENT 6
#macro VBM_ATTRIBUTE_COLOR 7
#macro VBM_ATTRIBUTE_COLORBYTES 8
#macro VBM_ATTRIBUTE_BONE 9
#macro VBM_ATTRIBUTE_BONEBYTES 10
#macro VBM_ATTRIBUTE_WEIGHT 11
#macro VBM_ATTRIBUTE_WEIGHTBYTES 12
#macro VBM_ATTRIBUTE_GROUP 13
#macro VBM_ATTRIBUTE_GROUPBYTES 14
#macro VBM_ATTRIBUTE_PAD 15
#macro VBM_ATTRIBUTE_PADBYTES 16

#macro VBM_IMPORTFLAG_FREEZE (1<<0)
#macro VBM_IMPORTFLAG_MERGE (1<<1)
#macro VBM_IMPORTFLAG_SAVETRIANGLES (1<<2)
#macro VBM_ATTBYTEFLAG 128

enum VBM_AnimCurveArray
{
	positions,
	values,
	interpolations,
	numkeyframes
}

#region // Fast Quaternion Constants. Used in VBM_Animation.EvaluateIntermediate()

/*
	Sourced from this paper by David Eberly, licensed under CC 4.0.
	Paper: https://www.geometrictools.com/Documentation/FastAndAccurateSlerp.pdf
	CC License: https://creativecommons.org/licenses/by/4.0/
*/

#macro QUATSLERP_MU 1.85298109240830
#macro QUATSLERP_U0 1.0/(1*3)
#macro QUATSLERP_U1 1.0/(2*5)
#macro QUATSLERP_U2 1.0/(3*7)
#macro QUATSLERP_U3 1.0/(4*9)
#macro QUATSLERP_U4 1.0/(5*11)
#macro QUATSLERP_U5 1.0/(6*13)
#macro QUATSLERP_U6 1.0/(7*15)
#macro QUATSLERP_U7 QUATSLERP_MU/(8*17)
#macro QUATSLERP_V0 1.0/(3)
#macro QUATSLERP_V1 2.0/(5)
#macro QUATSLERP_V2 3.0/(7)
#macro QUATSLERP_V3 4.0/(9)
#macro QUATSLERP_V4 5.0/(11)
#macro QUATSLERP_V5 6.0/(13)
#macro QUATSLERP_V6 7.0/(15)
#macro QUATSLERP_V7 QUATSLERP_MU/(8.0*17)

#endregion --------------------------------------------------------

// ======================================================================================================

// Contains array of VBM_Mesh, VBM_Animations, and bone data. Created and returned when calling OpenVBM().
function VBM_Model() constructor 
{
	// Meshes
	meshes = [];	// Vertex buffers
	meshmap = {};	// {meshname: VBM_Mesh} for each mesh
	meshnames = [];	// Names corresponding to meshes
	meshnamemap = {};	// Names to indices
	meshcount = 0;
	
	// Skeleton
	bone_parentindices = [];	// Parent transform corresponding to each bone
	bone_localmatricies = [];	// Local transform corresponding to each bone
	bone_inversematricies = [];	// Inverse transform corresponding to each bone
	bonemap = {};	// {bonename: index} for each bone
	bonenames = [];
	bonecount = 0;
	
	// Animations
	animations = [];	// Array of VBM_Animation
	animationnames = [];
	animationmap = {}	// {name: VBM_Animation} for each animation
	animationcount = 0;
	
	// Accessors -------------------------------------------------------------------
	
	// Meshes
	function MeshCount() {return meshcount;}
	function MeshNames() {return meshnames;}
	function MeshFind(_vbname) {return variable_struct_get(meshmap, _vbname);}
	function MeshGet(_index) {return meshes[_index];}
	function MeshNameGet(_index) {return meshnames[_index];}
	
	// Skeleton
	function BoneCount() {return bonecount;}
	function BoneNames() {return bonenames;}
	function BoneParentIndices() {return bone_parentindices;}
	function BoneLocalMatrices() {return bone_localmatricies;}
	function BoneInverseMatrices() {return bone_inversematricies;}
	function BoneGet(_index) {return bonenames[_index];}
	function BoneFind(_name) {return bonemap[$ _name];}
	
	// Animations
	function Animations() {return animations;}
	function AnimationNames() {return animationnames;}
	function AnimationCount() {return animationcount;}
	function AnimationGet(_animationindex) {return animations[_animationindex];}
	function AnimationFind(_animationname) {return variable_struct_get(animationmap, _animationname);}
	
	// Methods ==============================================================================
	
	static toString = function()
	{
		return "VBM_Model: {" +string(meshcount)+" meshes, " + string(bonecount) + " bones, " + string(animationcount) + " animations" + "}";
	}
	
	// Data --------------------------------------------------------------------
	
	function Duplicate()
	{
		var _out = new VBM_Model();
		
		// Meshes
		_out.meshcount = meshcount;
		array_resize(_out.meshnames, meshcount);
		array_resize(_out.meshes, meshcount);
		
		for (var i = 0; i < meshcount; i++)
		{
			_out.meshnames[i] = meshnames[i];
			_out.meshes[i] = meshes[i].Duplicate();
			_out.meshmap[$ meshnames[i]] = _out.meshes[i];
			_out.meshnamemap[$ meshnames[i]] = i;
		}
		
		// Skeleton
		_out.bonecount = bonecount;
		array_resize(_out.bonenames, bonecount);
		array_resize(_out.bone_parentindices, bonecount);
		array_resize(_out.bone_localmatricies, bonecount);
		array_resize(_out.bone_inversematricies, bonecount);
		
		array_copy(_out.bonenames, 0, bonenames, 0, bonecount);
		array_copy(_out.bone_parentindices, 0, bone_parentindices, 0, bonecount);
		
		for (var i = 0; i < bonecount; i++)
		{
			_out.bone_localmatricies[i] = matrix_build_identity();
			array_copy(_out.bone_localmatricies[i], 0, bone_localmatricies[i], 0, 16);
			
			_out.bone_inversematricies[i] = matrix_build_identity();
			array_copy(_out.bone_inversematricies[i], 0, bone_inversematricies[i], 0, 16);
			
			_out.bonemap[$ bonenames[i]] = i;
		}
		
		// Animations
		_out.animationcount = animationcount;
		array_resize(_out.animations, animationcount);
		array_resize(_out.animationnames, animationcount);
		array_copy(_out.animationnames, 0, animationnames, 0, animationcount);
		
		for (var i = 0; i < animationcount; i++)
		{
			_out.animations[i] = animations[i].Duplicate();
			_out.animationmap[$ animationnames[i]] = _out.animations[i];
		}
		
		return _out;
	}
	
	static Open = function(_path, _flags=0)
	{
		OpenVBM(_path, self, _flags);
		return self;
	}
	
	// Removes all dynamic data from struct
	static Clear = function()
	{
		ClearMeshes();
		ClearBones();
		ClearAnimations();
	}
	
	// Clear Meshes
	static ClearMeshes = function()
	{
		for (var i = 0; i < meshcount; i++) {meshes[i].Free();}
		
		array_resize(meshes, 0);
		array_resize(meshnames, 0);
		meshmap = {};
		meshnamemap = {};
		meshcount = 0;
	}
	
	// Removes bone data
	static ClearBones = function()
	{
		array_resize(bonenames, 0);
		array_resize(bone_parentindices, 0);
		array_resize(bone_localmatricies, 0);
		array_resize(bone_inversematricies, 0);
		bonemap = {};
		bonecount = 0;
	}
	
	// Removes animation data
	static ClearAnimations = function()
	{
		array_resize(animations, 0);
		animationmap = {};
		animationcount = 0;
		animator = 0;
	}
	
	// Meshes -----------------------------------------------------------------------
	
	// Freezes all mesh vertex buffers
	function Freeze()
	{
		for (var i = 0; i < meshcount; i++) {meshes[i].Freeze();} return self;
	}
	
	
	// Submits all vertex buffers
	function Submit(_primitive_type=pr_trianglelist, _texture=-1)
	{
		var i = 0;
		repeat(meshcount)
		{
			if (meshes[i].visible)
			{
				meshes[i].Submit(_primitive_type, _texture);
			}
			i += 1;
		}
		return self;
	}
	
	// Submits vertex buffer using index
	function SubmitIndex(_index, _primitive_type=pr_trianglelist, _texture=-1)
	{
		if ( meshcount > 0 )
		{
			if (_index >= 0 && _index < meshcount)
			{
				meshes[_index].Submit(_primitive_type, _texture);
			}
		}
		return self;
	}
	
	// Submits vertex buffer using name
	static SubmitName = function(_vbname, _primitive_type=pr_trianglelist, _texture=-1)
	{
		var i = 0;
		repeat(meshcount)
		{
			if (meshes[i].name == _vbname)
			{
				meshes[i].Submit(_primitive_type, _texture);
			}
			i += 1;
		}
		return self;
	}
	
	// Mesh Visibility -------------------------------------------------------------------
	function VisibleSet(_isvisible)
	{
		for (var i = 0; i < meshcount; i++)
		{
			meshes[i].visible = _isvisible;
		}
		return self;
	}
	
	function VisibleSetIndex(_meshindex, _isvisible)
	{
		if ( _meshindex >= 0 && _meshindex < meshcount ) 
			{meshes[_meshindex].visible = _isvisible;}
		return self;
	}
	
	function VisibleSetName(_meshname, _isvisible)
	{
		for (var i = 0; i < meshcount; i++)
		{
			if ( meshes[i].name == _meshname ) {meshes[i].visible = _isvisible;}
		}
		return self;
	}
	
	function VisibleSetPattern(_patternstring, _isvisible)
	{
		var _numchars = string_length(_patternstring);
		for (var i = 0; i < meshcount; i++)
		{
			if ( string_copy(_patternstring, 1, _numchars) == _patternstring ) 
			{
				meshes[i].visible = _isvisible;
			}
		}
		return self;
	}
	
	function VisibleToggleIndex(_meshindex)
	{
		if ( _meshindex >= 0 && _meshindex < meshcount ) 
			{meshes[_meshindex].visible = !meshes[_meshindex].visible;}
		return self;
	}
	
	function VisibleToggleName(_meshname, _prioritize_on=false)
	{
		var _visible;
		
		// Set meshes to visible if any are not
		if ( _prioritize_on )
		{
			_visible = false;
			for (var i = 0; i < meshcount; i++) 
			{
				if ( meshes[i].name == _meshname && !meshes[i].visible ) 
				{
					_visible = true; 
					break;
				}
			}
		}
		// Set meshes to not visible if any already are
		else
		{
			_visible = true;
			for (var i = 0; i < meshcount; i++) 
			{
				if ( meshes[i].name == _meshname && meshes[i].visible ) 
				{
					_visible = false; 
					break;
				}
			}
		}
		
		for (var i = 0; i < meshcount; i++)
		{
			if ( meshes[i].name == _meshname )
			{
				meshes[i].visible = _visible;
			}
		}
		return self;
	}
	
	// Animations ----------------------------------------------------------
	
	// Pre-calculate transformations
	function BakeAnimations()
	{
		for (var i = 0; i < animationcount; i++)
		{
			animations[i].BakeToIntermediate(bonenames);
		}
		
		return self;
	}
	
	// Creates, stores, and returns new animator
	function CreateAnimator(_numlayers=1)
	{
		animator = new VBM_Animator();
		animator.ReadTransforms(self);
		animator.LayerInitialize(_numlayers);
		animator.AnimationAddArray(animations);
		
		return animator;
	}
	
}

// Holds vertex buffer and related data (format, formatcode, materialname, texture, etc.)
function VBM_Mesh() constructor
{
	name = "";
	materialname = "";	// Optional. Can be used as a shader key
	texture = -1;
	color = c_white;
	
	vertexbuffer = -1;
	rawbuffer = -1;
	vertexformat = -1; // Vertex Buffer Format created in OpenVBM() (Don't touch!)
	formatcode = [];
	
	visible = true;
	edges = false;
	
	// Methods ======================================================================
	
	function toString()
	{
		return "{VBM_Mesh " + name + ", Mtl: " + materialname + ", Tex: " + string(texture) + "}";
	}
	
	function Free()
	{
		if (vertexbuffer != -1) {vertex_delete_buffer(vertexbuffer);}
		if (rawbuffer != -1) {buffer_delete(rawbuffer);}
		if (vertexformat != -1) {vertex_format_delete(vertexformat);}
		
		vertexbuffer = -1;
		rawbuffer = -1;
		vertexformat = -1;
	}
	
	function Duplicate()
	{
		var _out = new VBM_Mesh();
		var n;
		
		_out.name = name;
		_out.materialname = materialname;
		_out.texture = texture;
		_out.edges = edges;
		
		// Format
		n = array_length(formatcode);
		array_resize(_out.formatcode, n);
		for (var i = 0; i < n; i++)
		{
			_out.formatcode[i] = [formatcode[i][0], formatcode[i][1]];
		}
		
		_out.vertexformat = VBMParseFormat(_out.formatcode);
		
		// Buffers
		_out.rawbuffer = buffer_create(buffer_get_size(rawbuffer), buffer_fast, 1);
		buffer_copy(rawbuffer, 0, buffer_get_size(rawbuffer), _out.rawbuffer, 0);
		_out.vertexbuffer = vertex_create_buffer_from_buffer(_out.rawbuffer, _out.vertexformat);
		
		return _out;
	}
	
	// --------------------------------------------------------------------------
	
	function Submit(_primitive_type=-1, _texture=-1)
	{
		if (_primitive_type == -1) {_primitive_type = edges? pr_linelist: pr_trianglelist;}
		if (_texture == -1) {_texture = texture;}
		vertex_submit(vertexbuffer, _primitive_type, _texture);
	}
	
	function Freeze()
	{
		if (vertexbuffer) {vertex_freeze(vertexbuffer);}
	}
	
	function VisibleSet(_isvisible) {visible = bool(visible);}
	function VisibleToggle() {visible = !visible;}
}

// Holds curves for animation data
function VBM_Animation() constructor
{
	name = "";	// Animation name
	
	framespersecond = 60;
	duration = 1;	// In frames
	size = 0;	// Number of curves
	curvearray = [];	// Array of channels[]
	curvenames = [];	// Curve names
	curvesize = [];	// Number of channels for curve at index
	curvesizemap = {};	// Number of channels for curve with given name
	curvemap = {};	// {curvename: curvechannels}
	
	markercount = 0;
	markerpositions = [];
	markernames = [];
	markermap = {};
	
	isbakedlocal = false;
	evaluatedlocal = [];	// Frame matrices relative to bone. Intermediate pose
	
	bakedelayframe = -1;
	
	// Animation curves match the order of bones that they were exported with. Non-bone curves follow
	// [loc, quat, sca, loc, quat, sca, ...]
	/*
		curve:
			channels[]
				positions[]
				values[]
				interpolations[]
	*/
	
	// ==============================================================================
	
	Mat4 = matrix_build_identity;
	
	function toString() {return "VBM_Animation: {" + name + "}";}
	
	// Clears data from struct
	function Clear()
	{
		array_resize(curvearray, 0);
		array_resize(curvenames, 0);
		curvemap = {};
		size = 0;
		
		isbakedlocal = false;
		array_resize(evaluatedlocal, 0);
	}
	
	// Removes dynamic data from struct
	function Free()
	{
		Clear();
	}
	
	// Returns copy of struct data in new struct
	function Duplicate()
	{
		var _out = new VBM_Animation();
		var _curve1, _curve2;
		var _channel1, _channel2;
		var _numchannels;
		var _numkeyframes;
		
		_out.name = name;
		_out.framespersecond = framespersecond;
		_out.duration = duration;
		_out.size = size;
		_out.isbakedlocal = isbakedlocal;
		
		array_resize(_out.curvearray, size);
		array_resize(_out.curvenames, size);
		array_resize(_out.curvesize, size);
		
		array_copy(_out.curvenames, 0, curvenames, 0, size);
		array_copy(_out.curvesize, 0, curvesize, 0, size);
		
		// Copy curves
		for (var i = 0; i < size; i++)
		{
			_curve1 = curvearray[i];
			_numchannels = array_length(_curve1);
			_curve2 = array_create(_numchannels);
			
			for (var c = 0; c < _numchannels; c++)
			{
				_channel1 = _curve1[c];
				_numkeyframes = _channel1[VBM_AnimCurveArray.numkeyframes];
				
				_channel2 = [ // [positions, values, interpolations, numkeyframes]
					array_create(_numkeyframes),
					array_create(_numkeyframes), 
					array_create(_numkeyframes),
					_channel1[3]
				];
				
				array_resize(_channel2[VBM_AnimCurveArray.positions], _numkeyframes);				
				array_copy(_channel2[VBM_AnimCurveArray.positions], 0, _channel1[VBM_AnimCurveArray.positions], 0, _numkeyframes);
				
				array_resize(_channel2[VBM_AnimCurveArray.values], _numkeyframes);				
				array_copy(_channel2[VBM_AnimCurveArray.values], 0, _channel1[VBM_AnimCurveArray.values], 0, _numkeyframes);
				
				array_resize(_channel2[VBM_AnimCurveArray.interpolations], _numkeyframes);				
				array_copy(_channel2[VBM_AnimCurveArray.interpolations], 0, _channel1[VBM_AnimCurveArray.interpolations], 0, _numkeyframes);
				
				_curve2[c] = _channel2;
			}
			
			_out.curvearray[i] = _curve2;
			_out.curvemap[$ curvenames[i]] = _curve2;
			_out.curvesizemap[$ curvenames[i]] = _out.curvesizemap[$ curvenames[i]];
		}
		
		// Copy Baked
		if (isbakedlocal)
		{
			var _n = array_length(evaluatedlocal);
			var b = 0;
			var _bonecount = VBM_MATPOSEMAX;
			var _frame, _srcframe;
			var i;
			
			array_resize(_out.evaluatedlocal, _n);
			for (var f = 0; f < _n; f++)
			{
				_srcframe = _out.evaluatedlocal[f];
				
				i = 0;
				_frame = array_create(_bonecount);
				repeat(_bonecount) {_frame[i] = Mat4(); i++;}
				
				b = 0;
				repeat(_bonecount)
				{
					array_copy(_frame[b], 0, _srcframe[b], 0, 16);
					b++;
				}
				
				_out.evaluatedlocal[f] = _frame;
			}
		}
		
		return _out;
	}
	
	// ---------------------------------------------------------------------------------------
	
	// Returns true if curve path exists
	function CurveExists(_curvename) {return variable_struct_exists(curvemap, _curvename);}
	function ChannelExists(_curvename, _channel_index) 
	{
		return variable_struct_exists(curvemap, _curvename) && _channel_index <= array_length(curvemap[$ _curvename]);
	}
	
	// Returns single value from curve path
	function EvaluateValue(_curvename, _channel_index, _pos, _default_value=0) constructor
	{
		// Check curve exists
		if ( !variable_struct_exists(curvemap, _curvename) ) {return _default_value;}
		
		// Check size
		if ( _channel_index >= curvesizemap[$ _curvename] ) {return _default_value;}
		
		// Set up values
		var _channels = curvemap[$ _curvename];
		var _positions = _channels[_channel_index][VBM_AnimCurveArray.positions];
		var _values = _channels[_channel_index][VBM_AnimCurveArray.values];
		var n = _channels[_channel_index][VBM_AnimCurveArray.numkeyframes];
		
		// Fast checks
		if (n == 0) {return _default_value;}
		if (n == 1) {return _values[0];}
		if (n == 2)
		{
			return lerp(
				_values[0],
				_values[1],
				(_pos-_positions[0]) / (_positions[1]-_positions[0] + 0.00000000001)	// Small value to avoid max(0, x)
			);
		}
		
		// Interpolate using prev and next frame
		var i, iprev;
		i = clamp(_pos * n, 0, n-1);
		while ((i > 0) && _pos < _positions[i]) {i -= 1;}
		while ((i < n-1) && _pos >= _positions[i]) {i += 1;}
		iprev = max(0, i-1);
		
		// All positions have a tiny offset added per index to prevent divisions by 0 without needing to use max()
		return lerp(
			_values[iprev],
			_values[i],
			(_pos-_positions[iprev]) / (_positions[i]-_positions[iprev] + 0.00000000001)	// Small value to avoid max(0, x)
		);
	}
	
	// Returns vector from curve path
	function EvaluateVector(_curvename, _pos, _default_value=[])
	{
		var i = 0; repeat(i)
		{
			_default_value[i] = EvaluateValue(_curvename, i, _pos, _default_value[i]);
			i += 1;
		}
		
		return _default_value;
	}
	
	// Populates struct variable with evaluated curves
	function EvaluateSelectValue(_outdict, _pos, _curvenames)
	{
		var n = array_length(_curvenames);
		var _name;
		for (var i = 0; i < n; i++)
		{
			_name = _curvenames[i];
			if ( ChannelExists(_name, 0) )
			{
				_outdict[$ _name] = EvaluateValue(_name, 0, _pos, _outdict[$ _name]);
			}
		}
		
		return _outdict;
	}
	
	// Populates struct variable with evaluated curves
	function EvaluateSelectVector(_outdict, _pos, _curvenames)
	{
		var n = array_length(_curvenames);
		var _name;
		for (var i = 0; i < n; i++)
		{
			_name = _curvenames[i];
			if ( CurveExists(_name) )
			{
				_outdict[$ _name] = EvaluateVector(_name, _pos, _outdict[$ _name]);
			}
		}
		
		return _outdict;
	}
	
	// Populates struct variable with evaluated curves
	function EvaluateAll(_outdict, _pos)
	{
		var _curvename;
		
		for (var i = 0; i < size; i++)
		{
			_curvename = curvenames[i];
			
			_outdict[$ _curvename] = EvaluateVector(_curvename, _pos, 
				variable_struct_exists(_outdict, _curvename)? _outdict[$ _curvename]: array_create(4)
				);
		}
		
		return _outdict;
	}
	
	// Populates matrix array with calculated transforms from curves
	function EvaluatePoseIntermediate(
		_pos, 
		_outmat4array, 
		_bonenames, 
		_activetransforms=0, 
		_lasttransforms=0, 
		_lastblend=1.0
	)
	{
		var _curvename;
		var _loc = [0,0,0];
		var _quat = [1,0,0,0.0001];
		var _quatlast = [1,0,0,0.0001];
		var _euler = [0,0,0];
		var _mat4;
		
		var q_length, q_hyp_sqr, q_c, q_s, q_omc;
		var _matscale = matrix_build_identity();
		
		// Quat Slerp
		var xml, d, sqrD, sqrT, f0, f1;
		
		var n = array_length(_bonenames);
		var _bonename;
		
		var i = 0;
		repeat(n)
		{
			_bonename = _bonenames[i];
			_mat4 = _outmat4array[@ i];
			
			// Rotation Quaternion ----------------------------------------------------------
			_curvename = _bonename + ".rotation_quaternion";
			
			if ( variable_struct_exists(curvemap, _curvename) )
			{
				_quat[0] = EvaluateValue(_curvename, 0, _pos, 1);
				_quat[1] = EvaluateValue(_curvename, 1, _pos, 0);
				_quat[2] = EvaluateValue(_curvename, 2, _pos, 0);
				_quat[3] = EvaluateValue(_curvename, 3, _pos, 0);
				
				// Blend last transforms
				if ( _lastblend < 1 && _lasttransforms != 0 )
				{
					_quatlast = _lasttransforms[i][1];
					
					// Fast Quaternion Slerp =====================================================
					/*
						Sourced from this paper by David Eberly, licensed under CC 4.0.
						Paper: https://www.geometrictools.com/Documentation/FastAndAccurateSlerp.pdf
						CC License: https://creativecommons.org/licenses/by/4.0/
					*/
					
					xml = (_quat[0]*_quatlast[0] + _quat[1]*_quatlast[1] + _quat[2]*_quatlast[2] + _quat[3]*_quatlast[3])-1.0;
					
					if ( xml != 0 )
					{
						d = 1.0-_lastblend; 
						sqrT = _lastblend*_lastblend;
						sqrD = d*d;
						
						f0 = _lastblend * (
							1+((QUATSLERP_U0 * sqrT - QUATSLERP_V0) * xml)*(
							1+((QUATSLERP_U1 * sqrT - QUATSLERP_V1) * xml)*(
							1+((QUATSLERP_U2 * sqrT - QUATSLERP_V2) * xml)*(
							1+((QUATSLERP_U3 * sqrT - QUATSLERP_V3) * xml)*(
							1+((QUATSLERP_U4 * sqrT - QUATSLERP_V4) * xml)*(
							1+((QUATSLERP_U5 * sqrT - QUATSLERP_V5) * xml)*(
							1+((QUATSLERP_U6 * sqrT - QUATSLERP_V6) * xml)*(
							1+((QUATSLERP_U7 * sqrT - QUATSLERP_V7) * xml)
							))))))));
						
						f1 = d * (
							1+((QUATSLERP_U0 * sqrD - QUATSLERP_V0) * xml)*(
							1+((QUATSLERP_U1 * sqrD - QUATSLERP_V1) * xml)*(
							1+((QUATSLERP_U2 * sqrD - QUATSLERP_V2) * xml)*(
							1+((QUATSLERP_U3 * sqrD - QUATSLERP_V3) * xml)*(
							1+((QUATSLERP_U4 * sqrD - QUATSLERP_V4) * xml)*(
							1+((QUATSLERP_U5 * sqrD - QUATSLERP_V5) * xml)*(
							1+((QUATSLERP_U6 * sqrD - QUATSLERP_V6) * xml)*(
							1+((QUATSLERP_U7 * sqrD - QUATSLERP_V7) * xml)
							))))))));
						
						_quat[0] = f0 * _quat[0] + f1 * _quatlast[0];
						_quat[1] = f0 * _quat[1] + f1 * _quatlast[1];
						_quat[2] = f0 * _quat[2] + f1 * _quatlast[2];
						_quat[3] = f0 * _quat[3] + f1 * _quatlast[3];
					}
					
					/*
					// "Long" Quaternion slerp
					// Source: https://www.euclideanspace.com/maths/algebra/realNormedAlgebra/quaternions/slerp/index.htm
					var cosHalfTheta = _quat[0]*_quatlast[0] + _quat[1]*_quatlast[1] + _quat[2]*_quatlast[2] + _quat[3]*_quatlast[3];
					
					if ( abs(cosHalfTheta) < 1.0 )
					{
						var halfTheta = arccos(cosHalfTheta);
						var sinHalfTheta = sqrt(1.0-cosHalfTheta*cosHalfTheta);
						
						if ( abs(sinHalfTheta) < 0.001 )
						{
							_quat[0] = _quatlast[0] * 0.5 + _quat[0] * 0.5;
							_quat[1] = _quatlast[1] * 0.5 + _quat[1] * 0.5;
							_quat[2] = _quatlast[2] * 0.5 + _quat[2] * 0.5;
							_quat[3] = _quatlast[3] * 0.5 + _quat[3] * 0.5;
						}
						else
						{
							var ratioA = sin((1-_lastblend)*halfTheta) / sinHalfTheta;
							var ratioB = sin(_lastblend*halfTheta) / sinHalfTheta;
							
							_quat[0] = _quatlast[0] * ratioA + _quat[0] * ratioB;
							_quat[1] = _quatlast[1] * ratioA + _quat[1] * ratioB;
							_quat[2] = _quatlast[2] * ratioA + _quat[2] * ratioB;
							_quat[3] = _quatlast[3] * ratioA + _quat[3] * ratioB;
						}
					}
					*/
					
				}
				
				// Save transforms
				if ( _activetransforms != 0 )
				{
					// Normalize vector
					q_length = sqrt(_quat[0]*_quat[0] + _quat[1]*_quat[1] + _quat[2]*_quat[2] + _quat[3]*_quat[3]);	
					_quat[0] /= q_length; _quat[1] /= q_length; _quat[2] /= q_length; _quat[3] /= q_length;
					
					_activetransforms[@i][@1][@0] = _quat[0];
					_activetransforms[@i][@1][@1] = _quat[1];
					_activetransforms[@i][@1][@2] = _quat[2];
					_activetransforms[@i][@1][@3] = _quat[3];
				}
				
				// Quat to Mat4. Small value is added for zero rotation
				// TODO: Find the site this was sourced from and give credit
				q_length = sqrt(_quat[1]*_quat[1] + _quat[2]*_quat[2] + _quat[3]*_quat[3]) + 0.00000000001;	
				q_hyp_sqr = q_length*q_length + _quat[0]*_quat[0];
				// Calculate trig coefficients
				q_c   = 2*_quat[0]*_quat[0]/q_hyp_sqr - 1;
				q_s   = 2*q_length*_quat[0]*q_hyp_sqr;
				q_omc = 1 - q_c;
				// Normalize the input vector
				_quat[1] /= q_length; _quat[2] /= q_length; _quat[3] /= q_length;
				// Build matrix
				_mat4[@ 0] = q_omc*_quat[1]*_quat[1] + q_c;
				_mat4[@ 1] = q_omc*_quat[1]*_quat[2] + q_s*_quat[3];
				_mat4[@ 2] = q_omc*_quat[1]*_quat[3] - q_s*_quat[2];
				_mat4[@ 4] = q_omc*_quat[1]*_quat[2] - q_s*_quat[3];
				_mat4[@ 5] = q_omc*_quat[2]*_quat[2] + q_c;
				_mat4[@ 6] = q_omc*_quat[2]*_quat[3] + q_s*_quat[1];
				_mat4[@ 8] = q_omc*_quat[1]*_quat[3] + q_s*_quat[2];
				_mat4[@ 9] = q_omc*_quat[2]*_quat[3] - q_s*_quat[1];
				_mat4[@10] = q_omc*_quat[3]*_quat[3] + q_c;
			}
			
			// Rotation Euler ----------------------------------------------------------
			_curvename = _bonename + ".rotation_euler";
			
			if ( variable_struct_exists(curvemap, _curvename) )
			{
				_euler[0] = EvaluateValue(_curvename, 0, _pos, 0);
				_euler[1] = EvaluateValue(_curvename, 1, _pos, 0);
				_euler[2] = EvaluateValue(_curvename, 2, _pos, 0);
			}
			
			// Scale -------------------------------------------------------------
			_curvename = _bonename + ".scale";
			
			if ( variable_struct_exists(curvemap, _curvename) )
			{
				// Blend last transforms
				if ( _lastblend < 1 && _lasttransforms != 0 )
				{
					_matscale[ 0] = lerp(_lasttransforms[i][2][0], EvaluateValue(_curvename, 0, _pos, 1), _lastblend);
					_matscale[ 5] = lerp(_lasttransforms[i][2][1], EvaluateValue(_curvename, 1, _pos, 1), _lastblend );
					_matscale[10] = lerp(_lasttransforms[i][2][2], EvaluateValue(_curvename, 2, _pos, 1), _lastblend );
				}
				// Straight copy
				else
				{
					_matscale[ 0] = EvaluateValue(_curvename, 0, _pos, 1);
					_matscale[ 5] = EvaluateValue(_curvename, 1, _pos, 1);
					_matscale[10] = EvaluateValue(_curvename, 2, _pos, 1);
				}
				
				// Write to matrix
				array_copy( _mat4, 0, matrix_multiply(_matscale, _mat4), 0, 16);
				
				// Save transforms
				if ( _activetransforms != 0 )
				{
					_activetransforms[@i][@2][@0] = _matscale[ 0];
					_activetransforms[@i][@2][@1] = _matscale[ 5];
					_activetransforms[@i][@2][@2] = _matscale[10];
				}
			}
			
			// Location ----------------------------------------------------------
			_curvename = _bonename + ".location";
			
			if ( variable_struct_exists(curvemap, _curvename) )
			{
				// Blend last transforms
				if ( _lastblend < 1 && _lasttransforms != 0 )
				{
					_loc[0] = lerp(_lasttransforms[i][0][0], EvaluateValue(_curvename, 0, _pos, 0), _lastblend);
					_loc[1] = lerp(_lasttransforms[i][0][1], EvaluateValue(_curvename, 1, _pos, 0), _lastblend);
					_loc[2] = lerp(_lasttransforms[i][0][2], EvaluateValue(_curvename, 2, _pos, 0), _lastblend);
				}
				// Straight copy
				else
				{
					_loc[0] = EvaluateValue(_curvename, 0, _pos, 0);
					_loc[1] = EvaluateValue(_curvename, 1, _pos, 0);
					_loc[2] = EvaluateValue(_curvename, 2, _pos, 0);
				}
				
				// Write to matrix
				array_copy(_mat4, 12, _loc, 0, 3);
				
				// Save transforms
				if ( _activetransforms != 0 )
				{
					_activetransforms[@i][@0][@0] = _loc[0];
					_activetransforms[@i][@0][@1] = _loc[1];
					_activetransforms[@i][@0][@2] = _loc[2];
				}
			}
			
			i += 1;
		}
		
		return _outmat4array;
	}
	
	// Populates matrix array with transforms from curves. Uses pre-baked values if baked beforehand
	function EvaluatePose(
		_pos, 
		_outmat4array, 
		_bonenames, 
		_force_evaluate=false, 
		_activetransforms=0, 
		_lasttransforms=0, 
		_lastblend=1.0)
	{
		// Use baked values
		if ( !_force_evaluate && isbakedlocal )
		{
			var n = array_length(_bonenames);
			var i = 0;
			var _bonename;
			repeat(n)
			{
				_bonename = _bonenames[i];
				if (
					CurveExists(_bonename+".location") ||
					CurveExists(_bonename+".rotation_quaternion") ||
					CurveExists(_bonename+".scale")
				)
				{
					array_copy(
						_outmat4array[@ i],
						0,
						evaluatedlocal[clamp(round(_pos*duration), 0, duration-1)][i],
						0,
						16
					);
				}
				i += 1;
			}
		}
		// Calculate values at runtime
		else
		{
			EvaluatePoseIntermediate(_pos, _outmat4array, _bonenames, _activetransforms, _lasttransforms, _lastblend);
		}
	}
	
	// ----------------------------------------------------------------------------
	
	// Evaluate and save values for faster updating
	function BakeToIntermediate(_bonenames, _targetfps=0)
	{
		if (_targetfps == 0) {_targetfps = game_get_speed(gamespeed_fps);}
		
		var _numframes = duration * (_targetfps / framespersecond);
		
		array_resize(evaluatedlocal, _numframes);
		
		var f = 0;
		var i = 0;
		var _mat4array;
		repeat(_numframes)
		{
			_mat4array = array_create(VBM_MATPOSEMAX);
			i = 0;
			repeat(VBM_MATPOSEMAX) {_mat4array[i] = Mat4(); i++;}
			EvaluatePoseIntermediate(f/_numframes, _mat4array, _bonenames);
			evaluatedlocal[@ f] = _mat4array;
			f++;
		}
		
		isbakedlocal = true;
		return self;
	}
}

// Processes a sequence of animation layers to compose one final array of matrix values
function VBM_Animator() constructor
{
	layers = [];
	layercount = 0;
	
	animationpool = {};
	animations = [];
	animationcount = 0;
	
	pausefield = 0;	// Bit field. If not zero, animation is paused
	
	// Matrix size = 128
	static Mat4 = matrix_build_identity;
	
	vbm = -1;
	bonenames = array_create(VBM_MATPOSEMAX);
	boneindexmap = {};
	boneparentindices = array_create(VBM_MATPOSEMAX);
	bonecount = 0;
	
	posefinal = array_create(VBM_MATPOSEMAX*16);
	poseintermediate = array_create(VBM_MATPOSEMAX);
	bonematlocal = array_create(VBM_MATPOSEMAX);
	bonematinverse = array_create(VBM_MATPOSEMAX);
	localbonetransform = array_create(VBM_MATPOSEMAX);
	
	blendamt = 0;
	
	function Initialize()
	{
		var n = VBM_MATPOSEMAX;
		var i = 0;
		
		// Copy identity matrix to posefinal variable
		var _mat4 = matrix_build_identity();
		
		array_copy(posefinal, 0, _mat4, 0, 16);
		while ( (1<<i) < n )
		{
			array_copy(posefinal, (1<<i)*16, posefinal, 0, (1<<i)*16);
			i += 1;
		}
		array_resize(posefinal, n*16);
		
		// Fill arrays with matrices
		i = 0;
		array_resize(poseintermediate, VBM_MATPOSEMAX);
		array_resize(bonematlocal, VBM_MATPOSEMAX);
		array_resize(bonematinverse, VBM_MATPOSEMAX);
		array_resize(localbonetransform, VBM_MATPOSEMAX);
		
		repeat(VBM_MATPOSEMAX)
		{
			poseintermediate[i] = Mat4();
			bonematlocal[i] = Mat4();
			bonematinverse[i] = Mat4();
			localbonetransform[i] = Mat4();
			i += 1;
		}
	}
	
	Initialize();
	
	// ===========================================================================
	
	function toString()
	{
		var s = "{ ";
		for (var i = 0; i < layercount; i++)
		{
			s += string(layers[i]);
		}
		s += " }";
		return s;
	}
	
	function LayerInitialize(_count)
	{
		layercount = _count;
		array_resize(layers, layercount);
		
		for (var i = 0; i < _count; i++)
		{
			layers[i] = new VBM_Animator_Layer(self);
			layers[i].index = i;
		}
		
		return self;
	}
	
	function Layer(_index=0)
	{
		return (_index >= 0 && _index < layercount)? layers[_index]: undefined;
	}
	
	// -------------------------------------------------------------------------------------
	
	function AnimationCount() {return animationcount;}
	function AnimationOver(_layerindex=0) {return layers[0].animationposition >= 1.0;}
	
	// Pre-calculate transformations
	function BakeAnimations(_bonenames=0)
	{
		if (_bonenames == 0)
		{
			_bonenames = bonenames;
		}
		
		for (var i = 0; i < animationcount; i++)
		{
			animations[i].BakeToIntermediate(_bonenames);
		}
		
		return self;
	}
	
	function ReadTransforms(_vbm)
	{
		bonecount = _vbm.bonecount;
		
		array_resize(boneparentindices, bonecount);
		array_copy(boneparentindices, 0, _vbm.BoneParentIndices(), 0, bonecount);
		bonematlocal = _vbm.BoneLocalMatrices();
		bonematinverse = _vbm.BoneInverseMatrices();
		
		array_resize(bonenames, bonecount);
		array_copy(bonenames, 0, _vbm.bonenames, 0, bonecount);
		
		boneindexmap = {}
		for (var i = 0; i < bonecount; i += 1)
		{
			boneindexmap[$ bonenames[i]] = i;
		}
		
		vbm = _vbm;
		return self;
	}
	
	function LocalPose() {return poseintermediate;}	// Array of local space matrices
	function OutputPose() {return posefinal;}	// Flat array of final pose matrices
	function OutputMatrix(_index)
	{
		var m = matrix_build_identity();
		array_copy(m, 0, posefinal, _index*16, 16);
		return m;
	}
	function OutputMatrixNamed(_name)
	{
		return variable_struct_exists(boneindexmap, _name)? OutputMatrix(boneindexmap[$ _name]): undefined;
	}
	
	
	function GetMatrixIntermediate(_index) {return poseintermediate[_index];}
	function FindMatriIntermediate(_name) 
	{
		return variable_struct_exists(boneindexmap, _name)? 
			poseintermediate[boneindexmap[$ _name]]: 
			undefined;
	}
	
	function MatrixSetIntermediate(_index, _mat4)
	{
		array_copy(poseintermediate[_index], 0, _mat4, 0, 16);
	}
	
	// ------------------------------------------------------------------------
	
	function AnimationAdd(_animation)
	{
		return AnimationDefine(_animation.name, _animation);
	}
	
	function AnimationAddArray(_animations)
	{
		var n = array_length(_animations);
		for (var i = 0; i < n; i++)
		{
			AnimationAdd(_animations[i]);
		}
	}
	
	function AnimationAddVBM(_vbm)
	{
		return AnimationAddArray(_vbm.animations)
	}
	
	function AnimationDefine(_key, _animation)
	{
		animationpool[$ _key] = _animation;
		array_push(animations, _animation);
		animationcount += 1;
		
		for (var i = 0; i < layercount; i++)
		{
			layers[i].AnimationDefine(_key, _animation);
		}
		
		return _key;
	}
	
	// ------------------------------------------------------------------------
	
	function Pause(_bitindex=0) {pausefield |= (1 << _bitindex);}
	function PauseToggle(_bitindex=0) {pausefield ^= (1 << _bitindex);}
	
	function EvaluateValue(_curvename, _channel_index, _pos, _default_value)
	{
		return animation?
			animation.EvaluateValue(_curvename, _channel_index, _pos, _default_value):
			_default_value;
	}
	
	function EvaluateVector(_curvename, _pos, _default_value)
	{
		return animation?
			animation.EvaluateValue(_curvename, _pos, _default_value):
			_default_value;
	}
	
	// ------------------------------------------------------------------------
	
	// Plays animation via key
	function PlayAnimation(_animationkey, _loop=-1, _blendframes=0)
	{
		for (var i = 0; i < layercount; i++)
		{
			layers[i].PlayAnimation(_animationkey, _loop, _blendframes);
		}
		return self;
	}
	
	// Set animation struct to play
	function SetAnimation(_animation, _loop=-1, _blendframes=0)
	{
		for (var i = 0; i < layercount; i++)
		{
			layers[i].SetAnimation(_animation, _loop, _blendframes);
		}
		return self;
	}
	
	
	// Sets frame position
	function SetPosition(_frame)
	{
		for (var i = 0; i < layercount; i++)
		{
			layers[i].SetPosition(_frame);
		}
		return self;
	}
	
	// Sets blend time for layers
	function SetBlend(_blendframes)
	{
		for (var i = 0; i < layercount; i++)
		{
			layers[i].SetBlend(_blendframes);
		}
		return self;
	}
	
	// Process all layers
	function Update(ts, _process_output=true, _process_intermediate=true)
	{
		if (pausefield == 0)
		{
			for (var i = 0; i < layercount; i++)
			{
				if (layers[i].enabled)
				{
					layers[i].Update(ts, _process_output, _process_intermediate);
				}
			}
		}
		
		if (_process_output)
		{
			if (bonecount > 0)
			{	
				CalculateAnimationPose(
					boneparentindices,
					bonematlocal,
					bonematinverse,
					poseintermediate,
					posefinal,
					localbonetransform
				);
			}
		}
	}
	
	function CalculateAnimationPose(
		bone_parentindices, bone_localmatricies, bone_inversemodelmatrices, posedata, 
		outposetransform, outbonetransform)
	{
		var i;
		var n = min( array_length(bone_parentindices), array_length(posedata));
		var localtransform = array_create(n);	// Parent -> Bone
		array_resize(outbonetransform, n);	// Origin -> Bone
		
		// Calculate animation for specific bone
		i = 0; repeat(n) {localtransform[i++] = matrix_multiply(posedata[i], bone_localmatricies[i]);}
	
		// Set the model transform of bone using parent transform
		// Only works if the parents preceed their children in array
		outbonetransform[@ 0] = localtransform[0]; // Edge case for root bone
		i = 1; repeat(n-1)
		{
			outbonetransform[@ i++] = matrix_multiply(localtransform[i], outbonetransform[ bone_parentindices[i] ]);
		}
		
		// Compute final matrix for bone
		i = 0; repeat(n)
		{
			array_copy(outposetransform, (i++)*16, matrix_multiply(bone_inversemodelmatrices[i], outbonetransform[i]), 0, 16);
		}
	}
}

// Stored in Animator. Calculates animation poses
function VBM_Animator_Layer(_root) constructor
{
	index = 0;
	enabled = true;
	pausefield = 0;	// Bit field. If not zero, animation is paused
	
	animator = _root;	// Root animator
	
	animation = 0;
	animationspeed = 1;
	animationelapsed = 0;
	animationposition = 0;
	animationduration = 1;
	animationfps = 60;
	animationloop = true;
	
	evaluationposition = 0;
	evaluationpositionlast = 0;
	
	animationpool = {}
	animations = [];
	animationcount = 0;
	
	forcelocalposes = false;	// Prevents evaluated animations from being used when true
	
	activetransforms = array_create(VBM_MATPOSEMAX);
	lasttransforms = array_create(VBM_MATPOSEMAX);
	animationblendframes = 0;
	animationblendframesstep = 0;
	animationblendframessteplast = 0;
	
	benchmark = [0, 0, 0, 0];
	
	// ==================================================================================
	
	function toString() 
	{
		return "VBM_Animator_Layer: {" + 
			string(index) + ", " + 
			string(animation) + ", " + 
			string_format(evaluationposition, 1, 2) + " = " + 
			string_format(animationelapsed, 1, 2) + "/" + 
			string_format(animationduration, 1, 2) + "f" + 
			"}";
	}
	
	function Initialize()
	{
		for (var i = 0; i < VBM_MATPOSEMAX; i++)
		{
			activetransforms[i] = [[0,0,0], [1,0,0,0.00001], [1,1,1]];	// [Location Quat Scale]
			lasttransforms[i] = [[0,0,0], [1,0,0,0.00001], [1,1,1]];	// [Location Quat Scale]
		}
	}
	
	function AnimationCount() {return animationcount;}
	function ActiveAnimation() {return animation;}
	function ActiveAnimationName() {return animation? animation.name: "";}
	function ActiveAnimationDuration() {return animation? animation.duration: animationduration;}
	
	function Pause(_bitindex=0) {pausefield |= (1 << _bitindex);}
	function PauseToggle(_bitindex=0) {pausefield ^= (1 << _bitindex);}
	
	function Position() {return evaluationposition;}
	function Elapsed() {return animationelapsed;}
	
	// ------------------------------------------------------------------------
	
	function AnimationAdd(_animation)
	{
		return AnimationDefine(_animation.name, _animation);
	}
	
	function AnimationDefine(_key, _animation)
	{
		animationpool[$ _key] = _animation;
		array_push(animations, _animation);
		animationcount += 1;
		
		return self;
	}
	
	// ------------------------------------------------------------------------
	
	// Sets position
	function SetPosition(_pos)
	{
		animationelapsed = _pos * animationduration;
		return self;
	}
	
	// Sets position to frame
	function SetPositionFrame(_frame)
	{
		animationelapsed = _frame / animationduration;
		return self;
	}
	
	// Sets position to time in seconds
	function SetPositionSec(_pos_seconds)
	{
		animationelapsed = _pos_seconds / animationfps;
		return self;
	}
	
	// Sets time to blend into next animation
	function SetBlend(_blendframes)
	{
		animationblendframes = _blendframes;
		return self;
	}
	
	// Plays animation via name
	function PlayAnimation(_animationkey, _loop=true, _blendframes=0)
	{
		SetAnimation(animationpool[$ _animationkey], _loop, _blendframes);
		return self;
	}
	
	// Set animation struct
	function SetAnimation(_animation, _loop=true, _blendframes=0)
	{
		if (animation != _animation)
		{
			animation = _animation;
			
			if (animation)
			{
				// Update variables
				animationduration = animation.duration;
				animationloop = _loop != 0;
				animationposition = 0;
				animationelapsed = 0;
				animationfps = animation.framespersecond;
				evaluationposition = 0;
				evaluationpositionlast = -1;
				
				// Blend variables
				animationblendframes = _blendframes;
				animationblendframesstep = 0;
				animationblendframessteplast = -1;
				lasttransforms = activetransforms;
				activetransforms = array_create(VBM_MATPOSEMAX);
				var i = 0; 
				repeat(VBM_MATPOSEMAX)
				{
					activetransforms[i] = [ [0,0,0], [1,0,0,0.00001], [1,1,1] ];
					i++;
				}
			}
		}
		return self;
	}
	
	// Calculate transforms and curves
	function Update(_deltaframe, _process_intermediate=true, _process_output=true)
	{
		var t;
		
		if (pausefield == 0)
		{
			animationelapsed += _deltaframe * animationspeed;
			
			if (animationblendframesstep < animationblendframes)
			{
				animationblendframesstep = min(animationblendframesstep+_deltaframe*animationspeed, animationblendframes);
			}
		}
		
		if (animation)
		{
			animationposition = animationelapsed / (animationduration);
			evaluationposition = animationloop? (animationposition mod 1.0): clamp(animationposition, 0.0, 1.0);
			
			// Update Bone Transforms
			if (_process_intermediate)
			{
				if (
					(evaluationpositionlast != evaluationposition) ||
					(animationblendframessteplast < animationblendframesstep)
				)
				{
					t = get_timer();
					animation.EvaluatePose(
						evaluationposition, 
						animator.poseintermediate, 
						animator.bonenames, 
						forcelocalposes,
						activetransforms,
						lasttransforms,
						(animationblendframes > 0)? (animationblendframesstep/animationblendframes): 1
						);
					benchmark[0] = get_timer()-t;
					evaluationpositionlast = evaluationposition;
					animationblendframessteplast = animationblendframesstep;
				}
			}
			
			// Update Visibility
			if (_process_output)
			{
				if (animator.vbm != -1)
				{
					var _vbm = animator.vbm;
					var n = _vbm.meshcount;
					var _mesh;
				
					for (var m = 0; m < n; m++)
					{
						_mesh = _vbm.meshes[m];
						_mesh.visible = animation.EvaluateValue(_mesh.name, 0, evaluationposition, _mesh.visible);
					}
				}
			}
		}
	}
	
	Initialize();
}

// ======================================================================================================

// Removes allocated memory from vbm
function VBMFree(vbm)
{
	vbm.Clear();
}

// Creates and returns vertex format from code
function VBMParseFormat(_formatcode)
{
	var _numattributes = array_length(_formatcode);
	
	vertex_format_begin();
	
	var attributetype;
	var attributesize;
	var bytesum = 0;
	
	for (var i = 0; i < _numattributes; i++)
	{
		attributetype = _formatcode[i][0];
		attributesize = _formatcode[i][1];
		
		switch(attributetype & 0x7F) // Ignore byte flag
		{
			// Native types
			case(VBM_ATTRIBUTE_POSITION):
				if (attributesize == 3) {vertex_format_add_position_3d();}
				else {vertex_format_add_position();}
				break;
			case(VBM_ATTRIBUTE_UV):
				vertex_format_add_texcoord(); break;
			case(VBM_ATTRIBUTE_NORMAL):
				vertex_format_add_normal(); break;
			// Byte Attributes. Merged into Groups of 4
			case(VBM_ATTRIBUTE_COLORBYTES):
			case(VBM_ATTRIBUTE_BONEBYTES):
			case(VBM_ATTRIBUTE_WEIGHTBYTES):
			case(VBM_ATTRIBUTE_UVBYTES):
			case(VBM_ATTRIBUTE_GROUPBYTES):
			case(VBM_ATTRIBUTE_PADBYTES):
				// Add attribute if this attribute's size yields a byte sum of 4
				// Ex: 2 Bone Bytes + 2 Weight Bytes = Add attribute
				// Ex: 3 Color Bytes + 1 Padding Byte = Add attribute
				if ( ((bytesum + attributesize) div 4) > bytesum div 4 )
				{
					//vertex_format_add_custom(vertex_type_ubyte4, vertex_usage_texcoord);
					vertex_format_add_color();
				}
				
				bytesum += attributesize;
				break;
			
			// Non native types
			default:
				// Float Attribute
				if (attributetype & (VBM_ATTBYTEFLAG) == 0)
				{
					switch(attributesize)
					{
						case(1): vertex_format_add_custom(vertex_type_float1, vertex_usage_texcoord); break;
						case(2): vertex_format_add_custom(vertex_type_float2, vertex_usage_texcoord); break;
						case(3): vertex_format_add_custom(vertex_type_float3, vertex_usage_texcoord); break;
						case(4): vertex_format_add_custom(vertex_type_float4, vertex_usage_texcoord); break;
					}
				}
				// Byte Attribute
				else
				{
					if ( ((bytesum + attributesize) div 4) > bytesum div 4 )
					{
						//vertex_format_add_custom(vertex_type_ubyte4, vertex_usage_texcoord);
						vertex_format_add_color();
					}
				
					bytesum += attributesize;
				}
				break;
		}
	}
		
	return vertex_format_end();
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
function OpenVBM(
	_path, 
	_outvbm=undefined,
	_flags=VBM_IMPORTFLAG_FREEZE
	)
{
	if (!_outvbm) {_outvbm = new VBM_Model();}
	
	if (filename_ext(_path) == "") {_path = filename_change_ext(_path, ".vbm");}
	
	// File doesn't exist
	if ( !file_exists(_path) )
	{
		show_debug_message("OpenVBM(): File does not exist. \"" + _path + "\"");
		return -1;
	}
	
	var _bzipped = buffer_load(_path);
	var _b = _bzipped;
	
	// error reading file
	if (_bzipped < 0)
	{
		show_debug_message("OpenVBM(): Error loading vbm data from \"" + _path + "\"");
		return -1;
	}
	
	// Check for compression headers
	var _header = buffer_peek(_bzipped, 0, buffer_u8) | (buffer_peek(_bzipped, 1, buffer_u8) << 8);
	if (
		( _header == 0x0178 ) ||
		( _header == 0x9C78 ) ||
		( _header == 0xDA78 )
		)
	{
		_b = buffer_decompress(_bzipped);
		buffer_delete(_bzipped);
	}
	
	var _vbmheader;
	
	// Header
	_vbmheader = buffer_peek(_b, 0, buffer_u32);
	
	// Not a vbm file
	if ( (_vbmheader & 0x00FFFFFF) != VBMHEADERCODE )
	{
		show_debug_message("OpenVBM(): header is invalid \"" + _path + "\"");
		return _outvbm;
	}
	
	switch(_vbmheader & 0xFF)
	{
		default:
		
		// Version 3 (Mesh + Skeleton + Animations)
		case(3): 
			return __VBMOpen_v2(_outvbm, _b, _flags);
	}
	
	return _outvbm;
}

// Returns vbm struct from file (.vbm)
function __VBMOpen_v2(_outvbm, b, _userflags)
{
	var _version;
	var _format;
	var _formatlength;
	var _formatcode;
	var _formatattribtype;
	var _formatattribsize;
	var _flag;
	var _mesh;
	var _vbcount;
	var _vbcountoffset;
	var _bonecount;
	var _namelength;
	var _name;
	var _mat4;
	var _vb;
	var _vbraw;
	var _targetindices;
	var _targetmats;
	var i, j;
	
	var _vbuffersize;
	var _numvertices;
	
	var _flagsmesh;
	var _flagsskeleton;
	var _flagsanimation;
	
	var _freeze = (_userflags & VBM_IMPORTFLAG_FREEZE) != 0;
	//var _merge = (_userflags & VBM_IMPORTFLAG_MERGE) != 0;
	
	// Header
	_version = buffer_read(b, buffer_u32) >> 24;
	
	_flag = buffer_read(b, buffer_u8);
	
	// Jumps
	var jumpvbuffers = buffer_read(b, buffer_u32);
	var jumpskeleton = buffer_read(b, buffer_u32);
	var jumpanimations = buffer_read(b, buffer_u32);
	
	#region // Vertex Buffers ==================================================
	
	buffer_seek(b, buffer_seek_start, jumpvbuffers);
	
	_flagsmesh = buffer_read(b, buffer_u32);
	_vbcount = buffer_read(b, buffer_u32);
	_vbcountoffset = _outvbm.meshcount;
	_outvbm.meshcount += _vbcount;
	array_resize(_outvbm.meshnames, _outvbm.meshcount);
	
	// VB Data -------------------------------------------------------------
	for (var _vbindex = 0; _vbindex < _vbcount; _vbindex++)
	{
		// Mesh Name
		_name = "";
		_namelength = buffer_read(b, buffer_u8);
		repeat(_namelength) {_name += chr(buffer_read(b, buffer_u8));}
		if (_name == "") {_name = string(_vbindex);}
		_outvbm.meshnames[_vbcountoffset + _vbindex] = _name;
		_outvbm.meshnamemap[$ _name] = _vbcountoffset + _vbindex;
		
		// Vertex Format
		_formatlength = buffer_read(b, buffer_u8);
		_formatcode = array_create(_formatlength);
	
		for (var i = 0; i < _formatlength; i++)
		{
			_formatattribtype = buffer_read(b, buffer_u8);
			_formatattribsize = buffer_read(b, buffer_u8);
			_formatcode[i] = [_formatattribtype, _formatattribsize];
		}
		
		_format = VBMParseFormat(_formatcode);
		
		// Create buffer
		_vbuffersize = buffer_read(b, buffer_u32);
		_numvertices = buffer_read(b, buffer_u32);
		
		_vbraw = buffer_create(_vbuffersize, buffer_fast, 1);
		buffer_copy(b, buffer_tell(b), _vbuffersize, _vbraw, 0);
		
		_vb = vertex_create_buffer_from_buffer(_vbraw, _format);
		if _freeze {vertex_freeze(_vb);}
		
		_mesh = new VBM_Mesh();
		_mesh.rawbuffer = _vbraw;
		_mesh.vertexbuffer = _vb;
		_mesh.vertexformat = _format;
		_mesh.formatcode = _formatcode;
		
		_outvbm.meshes[_vbcountoffset + _vbindex] = _mesh;
		_outvbm.meshmap[$ _name] = _mesh;
		_mesh.name = _name;
		
		// move to next _vb
		buffer_seek(b, buffer_seek_relative, _vbuffersize);
	}
	
	// Material Names
	if ( (_flagsmesh & (1<<0)) != 0 )
	{
		for (var _vbindex = 0; _vbindex < _vbcount; _vbindex++)
		{
			_name = "";
			_namelength = buffer_read(b, buffer_u8);
			repeat(_namelength) {_name += chr(buffer_read(b, buffer_u8));}
			
			_outvbm.meshes[_vbcountoffset + _vbindex].materialname = _name;
		}
	}
	
	#endregion -------------------------------------------------------------
	
	#region // Skeleton ===========================================================
	
	buffer_seek(b, buffer_seek_start, jumpskeleton);
	
	_flagsskeleton = buffer_read(b, buffer_u32);
	
	_bonecount = buffer_read(b, buffer_u32);
	_outvbm.bonecount = _bonecount;
	array_resize(_outvbm.bonenames, _bonecount);
	array_resize(_outvbm.bone_parentindices, _bonecount);
	array_resize(_outvbm.bone_localmatricies, _bonecount);
	array_resize(_outvbm.bone_inversematricies, _bonecount);
	
	// Bone Names
	for (var i = 0; i < _bonecount; i++) 
	{
		_name = "";
		_namelength = buffer_read(b, buffer_u8);
		repeat(_namelength) {_name += chr(buffer_read(b, buffer_u8));}
		if (_name == "") {_name = "<ZERO>";}
		_outvbm.bonenames[i] = _name;
		_outvbm.bonemap[$ _name] = i;
	}
	
	// Parent Indices
	_targetindices = _outvbm.bone_parentindices;
	i = 0; repeat(_bonecount)
	{
		_targetindices[@ i++] = buffer_read(b, buffer_u32);
	}
	
	// Local Matrices 
	_targetmats = _outvbm.bone_localmatricies;
	i = 0; repeat(_bonecount)
	{
		_mat4 = array_create(16);
		j = 0; repeat(16) {_mat4[j++] = buffer_read(b, buffer_f32);}
		_targetmats[@ i++] = _mat4;
	}
	// Inverse Model Matrices
	_targetmats = _outvbm.bone_inversematricies;
	i = 0; repeat(_bonecount)
	{
		_mat4 = array_create(16);
		j = 0; repeat(16) {_mat4[j++] = buffer_read(b, buffer_f32);}
		_targetmats[@ i++] = _mat4;
	}
	
	#endregion -------------------------------------------------------------
	
	#region // Animations ===========================================================
	
	buffer_seek(b, buffer_seek_start, jumpanimations);
	
	_flagsanimation = buffer_read(b, buffer_u32);
	
	var _numanimations;
	var _animation;
	var _numcurves;
	var _curve;
	var _numchannels;
	var _channel;
	var _numframes;
	var _nummarkers;
	var _markerframe;
	var _positionoffset;	// Very small addend to prevent divisions by 0
	
	_numanimations = buffer_read(b, buffer_u32);
	_outvbm.animationcount = _numanimations;
	array_resize(_outvbm.animations, _numanimations);
	array_resize(_outvbm.animationnames, _numanimations);
	
	// Animations
	for (var i = 0; i < _numanimations; i++)
	{
		_animation = new VBM_Animation();
		
		// Animation Name
		_name = "";
		_namelength = buffer_read(b, buffer_u8);
		repeat(_namelength) {_name += chr(buffer_read(b, buffer_u8));}
		_animation.name = _name;
		
		// Animation Meta
		_animation.framespersecond = buffer_read(b, buffer_f32);
		_animation.duration = buffer_read(b, buffer_f32);
		_numcurves = buffer_read(b, buffer_u32);
		
		_animation.size = _numcurves;
		
		// Curves
		array_resize(_animation.curvearray, _numcurves);
		array_resize(_animation.curvenames, _numcurves);
		array_resize(_animation.curvesize, _numcurves);	// Number of channels
		
		for (var t = 0; t < _numcurves; t++)
		{
			_name = "";
			_namelength = buffer_read(b, buffer_u8);
			repeat(_namelength) {_name += chr(buffer_read(b, buffer_u8));}
			
			_numchannels = buffer_read(b, buffer_u32);
			_curve = array_create(_numchannels);
			
			for (var c = 0; c < _numchannels; c++)
			{
				_numframes = buffer_read(b, buffer_u32);
				_channel = [
					array_create(_numframes),	// Positions
					array_create(_numframes),	// Keyframes
					array_create(_numframes),	// Interpolation Modes
					_numframes	// Number of keyframes
				];
				_positionoffset = 0;
				for (var j = 0; j < _numframes; j++) {_channel[0][j] = buffer_read(b, buffer_f32)+_positionoffset;}
				for (var j = 0; j < _numframes; j++) {_channel[1][j] = buffer_read(b, buffer_f32);}
				for (var j = 0; j < _numframes; j++) {_channel[2][j] = buffer_read(b, buffer_u8);}
				
				_curve[c] = _channel;
			}
			
			_animation.curvearray[t] = _curve;
			_animation.curvemap[$ _name] = _curve;
			_animation.curvenames[t] = _name;
			_animation.curvesize[t] = _numchannels;
			_animation.curvesizemap[$ _name] = _numchannels;
		}
		
		// Markers
		_nummarkers = buffer_read(b, buffer_u32);
		_animation.markercount = _nummarkers;
		array_resize(_animation.markernames, _nummarkers);
		array_resize(_animation.markerpositions, _nummarkers);
		
		for (var t = 0; t < _nummarkers; t++)
		{
			_name = "";
			_namelength = buffer_read(b, buffer_u8);
			repeat(_namelength) {_name += chr(buffer_read(b, buffer_u8));}
			
			_markerframe = buffer_read(b, buffer_s32);
			
			_animation.markernames[t] = _name;
			_animation.markerpositions[t] = _markerframe;
			_animation.markermap[$ _name] = _markerframe;
		}
		
		_outvbm.animations[i] = _animation;
		_outvbm.animationmap[$ _animation.name] = _animation;
		_outvbm.animationnames[i] = _animation.name;
	}
	
	#endregion -------------------------------------------------------------
	
	buffer_delete(b);
	
	return _outvbm;
}

