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

vbx = LoadVBX("curly_rigged.vbx", vbf);
trackdata = LoadAniTrack("curly_poses.trk");

// Animation Vars =====================================================
// 2D array of matrices. Holds relative transforms for bones
inpose = Mat4Array(DMRVBX_MATPOSEMAX, matrix_build_identity());
// 1D flat array of matrices. Holds final transforms for bones
matpose = Mat4ArrayFlat(DMRVBX_MATPOSEMAX, matrix_build_identity());

trackpos = 0; // Position in animation
trackposspeed = (trackdata.framespersecond/game_get_speed(gamespeed_fps))/trackdata.length;
isplaying = false;

keymode = 0;
vbmode = 1;
wireframe = 0;
interpolationtype = AniTrack_Intrpl.linear;
UpdatePose();

// Control Variables ========================================================
alpha = 1;
emission = 0;
shine = 1;
sss = 0;

meshvisible = array_create(128, 1);

colorfill = [0, 1, 0.5, 0];
colorblend = [0.5, 1.0, 0.5, 0];

wireframe = false;
cullmode = cull_clockwise;
drawmatrix = BuildDrawMatrix(alpha, emission, shine, sss,
	ArrayToRGB(colorblend), colorblend[3],
	ArrayToRGB(colorfill), colorfill[3],
	);

// Uniforms ========================================================
var _shd;
_shd = shd_modelrigged;
u_shd_model_drawmatrix = shader_get_uniform(_shd, "u_drawmatrix");
u_shd_model_matpose = shader_get_uniform(_shd, "u_matpose");

event_user(1);
