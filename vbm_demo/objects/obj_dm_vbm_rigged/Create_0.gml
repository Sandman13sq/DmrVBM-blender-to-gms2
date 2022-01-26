/// @desc

event_inherited();

// Vertex Format: [pos3f, normal3f, color4B, uv2f, bone4f, weight4f] ==========
vertex_format_begin();
vertex_format_add_position_3d();
vertex_format_add_normal();
vertex_format_add_color();
vertex_format_add_texcoord();
vertex_format_add_custom(vertex_type_float4, vertex_usage_texcoord); // Bone Indices
vertex_format_add_custom(vertex_type_float4, vertex_usage_texcoord); // Bone Weights
vbf = vertex_format_end();

vbm = new VBMData();
OpenVBM(vbm, DIRPATH+"model/" + "curly_rigged.vbm", vbf);

// Animation Vars =====================================================
// 2D array of matrices. Holds relative transforms for bones
posetransform = Mat4Array(DMRVBM_MATPOSEMAX, matrix_build_identity());
// 1D flat array of matrices. Holds final transforms for bones
matpose = Mat4ArrayFlat(DMRVBM_MATPOSEMAX, matrix_build_identity());

trkanims = []
trknames = []
trkcount = FetchPoseFiles(DIRPATH+"animation/", trkanims, trknames);
trkindex = 0;
trkactive = 0;
trktimestep = 0;
trkposition = 0.0;
trkposlength = 0.0;
trkmarkerindex = 0;
playbackspeed = 1.0;
isplaying = false;

posemode = 0; // 0 = Poses, 1 = Animation
keymode = 0;
vbmode = 1;

wireframe = 0;
interpolationtype = TRK_Intrpl.linear;
trkexectime = 0;

// Control Variables ========================================================
meshselect = 0;
meshvisible = array_create(32, 1);
meshflash = array_create(32, 0);
meshtexture = array_create(32, -1);

skinsss = 0.0;

LoadDiffuseTextures();

drawmatrix = BuildDrawMatrix();

if vbm.FindVBIndex("curly_gun_mod") != -1
	{meshvisible[vbm.FindVBIndex("curly_gun_mod")] = 0;}
if vbm.FindVBIndex("curly_school") != -1
	{meshvisible[vbm.FindVBIndex("curly_school")] = 0;}

// Uniforms ========================================================
var _shd;
_shd = shd_rigged;
u_shd_rigged_drawmatrix = shader_get_uniform(_shd, "u_drawmatrix");
u_shd_rigged_light = shader_get_uniform(_shd, "u_light");
u_shd_rigged_matpose = shader_get_uniform(_shd, "u_matpose");

event_user(1);

OP_ActionSelect(trkindex);