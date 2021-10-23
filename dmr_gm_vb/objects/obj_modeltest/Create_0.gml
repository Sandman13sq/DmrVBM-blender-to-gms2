/// @desc

event_user(0);

Structor_VBFormat(1);

// Controls ==========================================================

x = 0;
y = 0;
z = 0;

vbmode = 1;
keymode = 1;
wireframe = 0;
zrot = 0;
poseindex = 0;

vbxvisible = ~0; // Bit field
dm_emission = 0;
dm_shine = 1;
dm_sss = 0;

mouseanchor = [0, 0];
cameraanchor = [0,0,0];
rotationanchor = [0, 0];
middlemode = 0;
middlelock = 0;

// Camera ==============================================================

camerapos = [0,0,7];
cameraforward = [0,1,0];
cameraright = [1,0,0];
cameraup = [0,0,1];

cameradist = 32;
cameradirection = 110;
camerapitch = 15;

camerawidth = 0;
cameraheight = 0;

zfar = 1000;
znear = 1;
fieldofview = 50;
matproj = matrix_build_projection_perspective_fov(fieldofview, camerawidth/cameraheight, znear, zfar);
matview = matrix_build_identity();
mattran = matrix_build(0,0,0, 0,0,0, 1,1,1);

UpdateView(); // Matrices are set here

bkcolor = 0x201010;

// VBX Vars ===========================================================

// vbx struct. Model + Bone data
vbx = LoadVBX("curly.vbx", vbf.rigged);
vbx_nm = LoadVBX("curly_nor.vbx", vbf.normal);
vbx_wireframe = LoadVBX("curly_l.vbx", vbf.rigged);
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

vb = LoadVertexBuffer("curly.vb", vbf.model);
vb_grid = CreateGridVB(40, 16);

vb_world = LoadVertexBuffer("world.vb", vbf.model);

// Animation Vars =====================================================

trackpos = 0; // Position in animation
trackposspeed = 0.1*(trackdata.framespersecond/game_get_speed(gamespeed_fps))/trackdata.length;
isplaying = 0;

// Generate relative bone matrices for position in animation
EvaluateAnimationTracks(trackpos, 0, 0, trackdata, inpose);
// Convert relative bone matrices to model-space matrices
CalculateAnimationPose(
	vbx.bone_parentindices,		// index of bone's parent
	vbx.bone_localmatricies,	// matrix of bone relative to parent
	vbx.bone_inversematricies,	// matrix of bone relative to model origin
	inpose,	// relative transforms
	matpose	// flat array of matrices to write data to
	);

// Shaders ============================================================

var shd;
shd = shd_model;
uniformset[0] = {
	u_drawmatrix : shader_get_uniform(shd, "u_drawmatrix"),
	u_camera : shader_get_uniform(shd, "u_camera"),
}

shd = shd_modelrigged;
uniformset[1] = {
	u_drawmatrix : shader_get_uniform(shd, "u_drawmatrix"),
	u_camera : shader_get_uniform(shd, "u_camera"),
	u_matpose : shader_get_uniform(shd, "u_matpose"),
}

shd = shd_normalmap;
uniformset[2] = {
	u_drawmatrix : shader_get_uniform(shd, "u_drawmatrix"),
	u_camera : shader_get_uniform(shd, "u_camera"),
	u_matpose : shader_get_uniform(shd, "u_matpose"),
}

drawmatrix = BuildDrawMatrix(1, 0, 1, 0); // Shader uniforms sent as one array

// Layout
event_user(1);

// etc. =============================================================

wireframecolors = array_create(32);
for (var i = 0; i < array_length(wireframecolors); i++)
{
	wireframecolors[i] = make_color_hsv(irandom(255), irandom(255), 255);
}

printf(trackdata.markerpositions);
printf(trackposspeed);

execinfo = "";
exectime = [0, 0];
frametime = 0;
