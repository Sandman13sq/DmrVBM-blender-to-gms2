/// @desc 

z = 0;
zrot = 0;

// vbx struct. Model + Bone data
vbx_model = LoadVBX("curly.vbx", RENDERING.vbformat.rigged);
vbx_normal = LoadVBX("curly_nor.vbx", RENDERING.vbformat.normal);
vbx_wireframe = LoadVBX("curly_wire.vbx", RENDERING.vbformat.rigged);

// 2D array of matrices. Holds relative transforms for bones
inpose = array_create(DMRVBX_MATPOSEMAX);
for (var i = DMRVBX_MATPOSEMAX-1; i >= 0; i--) 
	{inpose[i] = matrix_build_identity();}

// 1D flat array of matrices. Holds final transforms for bones
matpose = array_create(DMRVBX_MATPOSEMAX*16);

// track data struct. Holds decomposed transforms in tracks for each bone 
trackdata = LoadAniTrack("curly.trk");
posemats = [];
LoadPoses("curly.pse", posemats);

mattran = matrix_build(x,y,z, 0,0,zrot, 1,1,1);

// Animation Vars =====================================================

trackpos = 0; // Position in animation
trackposspeed = (trackdata.framespersecond/game_get_speed(gamespeed_fps))/trackdata.length;
isplaying = false;

keymode = 0;
vbmode = 1;
interpolationtype = AniTrack_Intrpl.linear;

var _vbx = vbx_model;
// Generate relative bone matrices for position in animation
EvaluateAnimationTracks(trackpos, interpolationtype, 0, trackdata, inpose);
// Convert relative bone matrices to model-space matrices
CalculateAnimationPose(
	_vbx.bone_parentindices,		// index of bone's parent
	_vbx.bone_localmatricies,	// matrix of bone relative to parent
	_vbx.bone_inversematricies,	// matrix of bone relative to model origin
	inpose,	// relative transforms
	matpose	// flat array of matrices to write data to
	);

drawmatrix = BuildDrawMatrix(1, 0, 1, 0); // Shader uniforms sent as one array
meshvisible = ~0;	// Bit Field
poseindex = 0;

wireframecolors = array_create(32);
for (var i = 0; i < array_length(wireframecolors); i++)
{
	wireframecolors[i] = make_color_hsv(irandom(255), irandom(255), 255);
}


