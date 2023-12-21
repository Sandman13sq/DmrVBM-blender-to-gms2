/*
	VBM definition and functions.
	By Dreamer13sq
*/

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

#macro VBMHEADERCODE 0x004D4256

// Max number of bones for pose matrix array
#macro VBM_MATPOSEMAX 128

#macro VBM_MAT4ARRAYFLAT global.g_mat4identityflat
#macro VBM_MAT4ARRAY2D global.g_mat4identity2d

VBM_MAT4ARRAYFLAT = array_create(16*VBM_MATPOSEMAX);
VBM_MAT4ARRAY2D = array_create(VBM_MATPOSEMAX);

for (var i = 0; i < VBM_MATPOSEMAX; i++)
{
	array_copy(VBM_MAT4ARRAYFLAT, i*16, matrix_build_identity(), 0, 16);
	VBM_MAT4ARRAY2D[i] = matrix_build_identity();
}

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
#macro VBM_ATTRIBUTE_VERTEXGROUP 13
#macro VBM_ATTRIBUTE_PAD 14
#macro VBM_ATTRIBUTE_PADBYTES 15

#macro VBM_IMPORTFLAG_FREEZE (1<<0)
#macro VBM_IMPORTFLAG_MERGE (1<<1)
#macro VBM_IMPORTFLAG_SAVETRIANGLES (1<<2)

// ======================================================================================================

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
	animator = 0;
	
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
	function BoneNameGet(_index) {return bonenames[_index];}
	function BoneIndexGet(_name) {return bonemap[$ _name];}
	
	// Animations
	function Animations() {return animations;}
	function AnimationNames() {return animationnames;}
	function AnimationCount() {return animationcount;}
	function AnimationGet(_animationindex) {return animations[_animationindex];}
	function AnimationFind(_animationname) {return variable_struct_get(animationmap, _animationname);}
	
	function Animator()
	{
		if (!animator) 
		{
			animator = new VBM_Animator();
			animator.ReadTransforms(self);
		}
		return animator;
	}
	
	// Methods -------------------------------------------------------------------
	
	static toString = function()
	{
		return "VBM_Model: {" +string(meshcount)+" meshes, " + string(bonecount) + " bones, " + string(animationcount) + " animations" + "}";
	}
	
	static Open = function(path, format=-1, freeze=true)
	{
		OpenVBM(path, self, freeze);
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
	
	// Returns index of vb with given name. -1 if not found
	static GetMesh = function(_index) {return meshes[_index];}
	
	// Returns mesh with given name. -1 if not found
	static FindMesh = function(_name)
	{
		return variable_struct_exists(meshmap, _name)? meshmap[$ _name]: -1;
	}
	
	// Returns bone index from given name. -1 if not found
	static FindBone = function(_name)
	{
		return variable_struct_exists(bonemap, _name)? meshmap[$ _name]: -1;
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
	}
	
	// Submits vertex buffer using name
	static SubmitName = function(_vbname, _primitive_type=pr_trianglelist, _texture=-1)
	{
		if (variable_struct_exists(meshmap, _vbname))
		{
			meshmap[$ _vbname].Submit(_primitive_type, _texture);
		}
	}
	
	// Pre-calculate transformations
	function OptimizeAnimations()
	{
		for (var i = 0; i < animationcount; i++)
		{
			animations[i].BakeToLocal(bonenames);
		}
		
		return self;
	}
}

function VBM_Mesh() constructor
{
	name = "";
	materialname = "";	// Optional. Can be used as a shader key
	texture = -1;
	
	vertexbuffer = -1;
	rawbuffer = -1;
	vertexformat = -1; // Vertex Buffer Format created in OpenVBM() (Don't touch!)
	
	visible = true;
	edges = false;
	
	boundsmin = [0,0,0];
	boundsmax = [0,0,0];
	
	function Free()
	{
		if (vertexbuffer != -1) {vertex_delete_buffer(vertexbuffer);}
		if (rawbuffer != -1) {buffer_delete(rawbuffer);}
		if (vertexformat != -1) {vertex_format_delete(vertexformat);}
		
		vertexbuffer = -1;
		rawbuffer = -1;
		vertexformat = -1;
	}
	
	function Submit(_primitive_type=-1, _texture=-1)
	{
		if (_primitive_type == -1) {_primitive_type = edges? pr_linelist: pr_trianglelist;}
		if (_texture == -1) {_texture = texture;}
		vertex_submit(vertexbuffer, _primitive_type, _texture);
	}
}

function VBM_Animation() constructor
{
	name = "";	// Animation name
	
	framespersecond = 60;
	duration = 1;
	size = 0;	// Number of curves
	curvearray = [];	// Array of channels[]
	curvenames = [];	// Curve names
	curvemap = {};	// {curvename: curvechannels}
	
	isbakedlocal = false;
	evaluatedlocalmap = {}
	evaluatedlocal = [];	// Matrices relative to bone. Intermediate pose
	
	// Animation curves match the order of bones that they were exported with. Non-bone curves follow
	// [loc, quat, sca, loc, quat, sca, ...]
	/*
		curve:
			channels[]
				positions[]
				values[]
				interpolations[]
	*/
	
	Mat4 = matrix_build_identity;
	
	function toString() {return "VBM_Animation: {" + name + "}";}
	
	function Clear()
	{
		array_resize(curvearray, 0);
		array_resize(curvename, 0);
		curvemap = {};
		size = 0;
		
		isbakedlocal = false;
		evaluatedlocalmap = {};
		array_resize(evaluatedlocal, 0);
	}
	
	function Free()
	{
		Clear();
	}
	
	function CurveExists(_curvename) {return variable_struct_exists(curvemap, _curvename);}
	function ChannelExists(_curvename, _channel_index) 
	{
		return variable_struct_exists(curvemap, _curvename) && _channel_index <= array_length(curvemap[$ _curvename]);
	}
	
	function EvaluateValue(_curvename, _channel_index, _pos, _default_value=0) constructor
	{
		// Check curve exists
		if ( !variable_struct_exists(curvemap, _curvename) ) {return _default_value;}
		
		var _channels = curvemap[$ _curvename];
		
		if ( _channel_index >= array_length(_channels) ) {return _default_value;}
		
		var _channel = _channels[_channel_index];
		var _positions = _channel[0];
		var _values = _channel[1];
		
		var n = array_length(_values);
		
		if (n == 0) {return _default_value;}
		if (n == 1) {return _values[0];}
		
		var i, iprev;
		i = clamp(_pos * n, 0, n-1);
		while ((i > 0) && _pos < _positions[i]) {i -= 1;}
		while ((i < n-1) && _pos >= _positions[i]) {i += 1;}
		iprev = max(0, i-1);
		
		return lerp(
			_values[iprev],
			_values[i],
			(_pos-_positions[iprev]) / max(0.001, _positions[i]-_positions[iprev])
		);
	}
	
	function EvaluateVector(_curvename, _pos, _default_value=[])
	{
		var n = array_length(curvemap[$ _curvename][0]);
		var i = 0; repeat(i)
		{
			_default_value[i] = EvaluateValue(_curvename, i, _pos, _default_value[i]);
			i += 1;
		}
		
		return _default_value;
	}
	
	function EvaluateAll(_outdict, _pos)
	{
		var _curve;
		var _channels;
		var _channel;
		var _positions;
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
	
	function EvaluatePoseLocal(_pos, _outmat4array, _bonenames)
	{
		var _curveindex;
		var _curvename;
		var _curve;
		var _channels;
		var _loc = [0,0,0];
		var _quat = [1,0,0,0.0001];
		var _mat4;
		
		var q_length, q_hyp_sqr, q_c, q_s, q_omc;
		var _matscale = matrix_build_identity();
		
		var n = array_length(_bonenames);
		var b;
		var _bonename;
		
		var i = 0;
		repeat(n)
		{
			_bonename = _bonenames[i];
			_mat4 = _outmat4array[@ i];
			
			// Rotation ----------------------------------------------------------
			_curvename = _bonename + ".rotation_quaternion";
			
			if ( variable_struct_exists(curvemap, _curvename) )
			{
				_quat[0] = EvaluateValue(_curvename, 0, _pos, 1);
				_quat[1] = EvaluateValue(_curvename, 1, _pos, 0);
				_quat[2] = EvaluateValue(_curvename, 2, _pos, 0);
				_quat[3] = EvaluateValue(_curvename, 3, _pos, 0);
				
				// Quat to Mat4. Small value is added for zero rotation
				q_length = sqrt(_quat[1]*_quat[1] + _quat[2]*_quat[2] + _quat[3]*_quat[3]) + 0.00000000001;	
				q_hyp_sqr = q_length*q_length + _quat[0]*_quat[0];
				// Calculate trig coefficients
				q_c   = 2*_quat[0]*_quat[0]/ q_hyp_sqr - 1;
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
			
			// Scale -------------------------------------------------------------
			_curvename = _bonename + ".scale";
			
			if ( variable_struct_exists(curvemap, _curvename) )
			{
				_matscale[ 0] = EvaluateValue(_curvename, 0, _pos, 1);
				_matscale[ 5] = EvaluateValue(_curvename, 1, _pos, 1);
				_matscale[10] = EvaluateValue(_curvename, 2, _pos, 1);
			
				array_copy( _mat4, 0, matrix_multiply(_matscale, _mat4), 0, 16);
			}
			
			// Location ----------------------------------------------------------
			_curvename = _bonename + ".location";
			
			if ( variable_struct_exists(curvemap, _curvename) )
			{
				_loc[0] = EvaluateValue(_curvename, 0, _pos, 0);
				_loc[1] = EvaluateValue(_curvename, 1, _pos, 0);
				_loc[2] = EvaluateValue(_curvename, 2, _pos, 0);
				
				array_copy(_mat4, 12, _loc, 0, 3);
			}
			
			i += 1;
		}
		
		return _outmat4array;
	}
	
	function EvaluatePose(_pos, _outmat4array, _bonenames, _force_evaluate=false)
	{
		if ( !_force_evaluate && isbakedlocal )
		{
			var n = array_length(_bonenames);
			var i = 0;
			repeat(n)
			{
				array_copy(
					_outmat4array[@ i],
					0,
					evaluatedlocal[clamp(round(_pos*duration), 0, duration-1)][i],
					0,
					16
				);
				i += 1;
			}
		}
		else
		{
			EvaluatePoseLocal(_pos, _outmat4array, _bonenames);
		}
	}
	
	function BakeToLocal(_bonenames, _targetfps=0)
	{
		if (_targetfps == 0) {_targetfps = game_get_speed(gamespeed_fps);}
		
		var _numframes = duration * (_targetfps / framespersecond);
		
		evaluatedlocal = array_create(_numframes);
		for (var f = 0; f <= _numframes; f++)
		{
			evaluatedlocal[@ f] = [
				Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),
				Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),
				Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),
				Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),
				Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),
				Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),
				Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),
				Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4()
			];
			
			EvaluatePoseLocal(f/_numframes, evaluatedlocal[@ f], _bonenames);
		}
		
		isbakedlocal = true;
		return self;
	}
}

function VBM_Animator() constructor
{
	animation = 0;
	animationspeed = 1;
	animationelapsed = 0;
	animationposition = 0;
	animationpositionlast = 0;
	animationduration = 1;
	animationloop = true;
	
	evaluationposition = 0;
	evaluationpositionlast = 0;
	
	animationpool = {}
	curveoutput = {};
	
	pausefield = 0;	// Bit field. If not zero, animation is paused
	forcelocalposes = false;	// Prevents evaluated animations from being used when true
	
	// Matrix size = 128
	static Mat4 = matrix_build_identity;
	
	vbm = -1;
	bonenames = array_create(VBM_MATPOSEMAX);
	boneindexmap = {};
	boneparentindices = array_create(VBM_MATPOSEMAX);
	bonecount = 0;
	
	posefinal = [
		1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1, 1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1, 1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1, 1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,
		1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1, 1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1, 1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1, 1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,
		1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1, 1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1, 1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1, 1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,
		1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1, 1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1, 1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1, 1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,
		
		1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1, 1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1, 1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1, 1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,
		1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1, 1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1, 1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1, 1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,
		1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1, 1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1, 1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1, 1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,
		1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1, 1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1, 1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1, 1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,
		
		1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1, 1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1, 1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1, 1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,
		1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1, 1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1, 1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1, 1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,
		1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1, 1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1, 1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1, 1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,
		1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1, 1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1, 1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1, 1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,
		
		1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1, 1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1, 1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1, 1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,
		1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1, 1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1, 1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1, 1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,
		1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1, 1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1, 1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1, 1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1,
		1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1, 1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1, 1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1, 1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1
	];
	
	poseintermediate = [
		Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),
		Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),
		Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),
		Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),
		Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),
		Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),
		Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),
		Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),
	];
	
	bonematlocal = [
		Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),
		Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),
		Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),
		Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),
		Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),
		Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),
		Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),
		Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),
	];
	
	bonematinverse = [
		Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),
		Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),
		Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),
		Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),
		Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),
		Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),
		Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),
		Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),
	];
	
	localbonetransform = [
		Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),
		Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),
		Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),
		Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),
		Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),
		Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),
		Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),
		Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),Mat4(),
	];
	
	function toString() 
	{
		return "VBM_Animator: {" + 
			string(animation) + ", " + 
			string(evaluationposition) + " = " + string(animationelapsed) + "/" + string(animationduration) + "s" + 
			"}";
	}
	
	function ActiveAnimation() {return animation;}
	function ActiveAnimationName() {return animation? animation.name: "";}
	
	function Pause(_bitindex=0) {pausefield |= (1 << _bitindex);}
	function PauseToggle(_bitindex=0) {pausefield ^= (1 << _bitindex);}
	
	function PlayAnimation(_animation, _loop=true)
	{
		if (animation != _animation)
		{
			animation = _animation;
			
			if (animation)
			{
				animationduration = animation.duration;
				animationloop = _loop;
				animationposition = 0;
				animationelapsed = 0;
				evaluationposition = 0;
				evaluationpositionlast = -1;
			}
		}
	}
	
	function ReadTransforms(_vbm)
	{
		boneparentindices = _vbm.BoneParentIndices();
		bonematlocal = _vbm.BoneLocalMatrices();
		bonematinverse = _vbm.BoneInverseMatrices();
		bonecount = _vbm.bonecount;
		
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
	
	function OutputPosePacked()
	{
		var m = posefinal;
		return [
			m[ 0], m[ 4], m[ 8], m[ 0], 
		];
	}
	
	function Update(deltasec)
	{
		if (pausefield == 0)
		{
			animationelapsed += deltasec * animationspeed;
		}
		
		if (animation)
		{
			animationposition = animationelapsed / animationduration;
			evaluationposition = animationloop? (animationposition mod 1.0): clamp(animationposition, 0.0, 1.0);
			
			if (evaluationpositionlast != evaluationposition)
			{
				animation.EvaluatePose(evaluationposition, poseintermediate, bonenames, forcelocalposes);
				
				CalculateAnimationPose(
					boneparentindices,
					bonematlocal,
					bonematinverse,
					poseintermediate,
					posefinal,
					localbonetransform
				);
				
				evaluationpositionlast = evaluationposition;
			}
			
			
			// Update Visibility
			if (vbm != -1)
			{
				var n = vbm.meshcount;
				var _mesh;
				
				for (var m = 0; m < n; m++)
				{
					_mesh = vbm.meshes[m];
					_mesh.visible = animation.EvaluateValue(_mesh.name, 0, evaluationposition, _mesh.visible);
				}
			}
		}
	}
	
	function GetMatrixLocal(_index) {return poseintermediate[_index];}
	function FindMatrixLocal(_name) 
	{
		return variable_struct_exists(boneindexmap, _name)? 
			poseintermediate[boneindexmap[$ _name]]: 
			undefined;
	}
	
	function CalculateAnimationPose(
		bone_parentindices, bone_localmatricies, bone_inversemodelmatrices, posedata, 
		outposetransform, outbonetransform)
	{
		var i;
		var m;
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

// ======================================================================================================

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
		(_header & 0x0178) == 0x0178 ||
		(_header & 0x9C78) == 0x9C78 ||
		(_header & 0xDA78) == 0xDA78
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

// Returns vbm format from buffer
function GetVBMFormat(b, offset)
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
		
		switch(attributetype)
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

// Returns vbm struct from file (.vbm)
function __VBMOpen_v2(_outvbm, b, _userflags)
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
	
	var _version;
	var _format;
	var _flag;
	var _mesh;
	var _vbcount;
	var _vbcountoffset;
	var _bonecount;
	var appendcount;
	var _namelength;
	var _name;
	var _mat4;
	var _vb;
	var _targetindices;
	var _targetmats;
	var i, j;
	
	var _vbuffersize;
	var _numvertices;
	
	var _freeze = (_userflags & VBM_IMPORTFLAG_FREEZE) != 0;
	var _merge = (_userflags & VBM_IMPORTFLAG_MERGE) != 0;
	
	// Header
	_version = buffer_read(b, buffer_u32) >> 24;
	
	_flag = buffer_read(b, buffer_u8);
	
	// Jumps
	var jumpvbuffers = buffer_read(b, buffer_u32);
	var jumpskeleton = buffer_read(b, buffer_u32);
	var jumpanimations = buffer_read(b, buffer_u32);
	
	#region // Vertex Buffers ==================================================
	
	_vbcount = buffer_read(b, buffer_u32);
	_vbcountoffset = _outvbm.meshcount;
	_outvbm.meshcount += _vbcount;
	array_resize(_outvbm.meshnames, _outvbm.meshcount);
	
	// Vertex Format
	_format = GetVBMFormat(b, buffer_tell(b));
	buffer_seek(b, buffer_seek_relative, buffer_read(b, buffer_u8)*2);
	
	// VB Names ------------------------------------------------------------
	for (var i = 0; i < _vbcount; i++) 
	{
		_name = "";
		_namelength = buffer_read(b, buffer_u8);
		repeat(_namelength) {_name += chr(buffer_read(b, buffer_u8));}
		_outvbm.meshnames[_vbcountoffset + i] = _name;
		_outvbm.meshnamemap[$ _name] = _vbcountoffset + i;
	}
	
	// VB Data -------------------------------------------------------------
	for (var i = 0; i < _vbcount; i++)
	{
		_vbuffersize = buffer_read(b, buffer_u32);
		_numvertices = buffer_read(b, buffer_u32);
		
		// Create _vb
		_vb = vertex_create_buffer_from_buffer_ext(b, _format, buffer_tell(b), _numvertices);
		if _freeze {vertex_freeze(_vb);}
		
		_mesh = new VBM_Mesh();
		_mesh.vertexbuffer = _vb;
		_mesh.vertexformat = _format;
		
		_outvbm.meshes[_vbcountoffset + i] = _mesh;
		_outvbm.meshmap[$ _outvbm.meshnames[_vbcountoffset + i]] = _mesh;
		_mesh.name = _outvbm.meshnames[_vbcountoffset + i]
		
		// move to next _vb
		buffer_seek(b, buffer_seek_relative, _vbuffersize);
	}
	
	#endregion -------------------------------------------------------------
	
	#region // Skeleton ===========================================================
	
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
	
	var _numanimations;
	var _animation;
	var _animationnames;
	var _numcurves;
	var _curve;
	var _numchannels;
	var _channel;
	var _numframes;
	var _channelvalues;
	
	_numanimations = buffer_read(b, buffer_u32);
	_outvbm.animationcount = _numanimations;
	array_resize(_outvbm.animations, _numanimations);
	
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
		_animation.markercount = buffer_read(b, buffer_u32);
		
		_animation.size = _numcurves;
		
		// Curves
		array_resize(_animation.curvearray, _numcurves);
		array_resize(_animation.curvenames, _numcurves);
		
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
					array_create(_numframes)	// Interpolation Modes
				];
				
				for (var j = 0; j < _numframes; j++) {_channel[0][j] = buffer_read(b, buffer_f32);}
				for (var j = 0; j < _numframes; j++) {_channel[1][j] = buffer_read(b, buffer_f32);}
				for (var j = 0; j < _numframes; j++) {_channel[2][j] = buffer_read(b, buffer_u8);}
				
				_curve[c] = _channel;
			}
			
			_animation.curvearray[t] = _curve;
			_animation.curvemap[$ _name] = _curve;
			_animation.curvenames[t] = _name;
		}
		
		_outvbm.animations[i] = _animation;
		_outvbm.animationmap[$ _animation.name] = _animation;
	}
	
	#endregion -------------------------------------------------------------
	
	buffer_delete(b);
	
	// Keep Temporary format
	_outvbm.vertexformat = _format;
	
	return _outvbm;
}

