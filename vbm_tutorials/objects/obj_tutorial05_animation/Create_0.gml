/// @desc Camera Setup

// Camera ----------------------------------------------
cameraposition = [2, -24, 12];
cameralookat = [0, 0, 8];

width = window_get_width();
height = window_get_height();

fieldofview = 50;
znear = 1;
zfar = 100;

matproj = matrix_build_projection_perspective_fov(
	fieldofview, window_get_width()/window_get_height(), znear, zfar);
matview = matrix_build_lookat(
	cameraposition[0], -cameraposition[1], cameraposition[2], 
	cameralookat[0], -cameralookat[1], cameralookat[2], 
	0, 0, 1);
mattran = matrix_build_identity();

// Vertex format ---------------------------------------
vertex_format_begin();
vertex_format_add_position_3d();
vertex_format_add_color();
vertex_format_add_texcoord();
vbf_simple = vertex_format_end();

vertex_format_begin();
vertex_format_add_position_3d();
vertex_format_add_normal();
vertex_format_add_color();
vertex_format_add_texcoord();
vertex_format_add_custom(vertex_type_float4, vertex_usage_texcoord); // Bone Indices
vertex_format_add_custom(vertex_type_float4, vertex_usage_texcoord); // Bone Weights
vbf_rigged = vertex_format_end();

// Load Vertex Buffers ---------------------------------
vb_grid = OpenVertexBuffer("grid.vb", vbf_simple);
vb_axis = OpenVertexBuffer("axis.vb", vbf_simple);

// Shader Uniforms
u_matpose = shader_get_uniform(shd_rigged, "u_matpose");

// Open VBM
vbm_curly = new VBMData();
OpenVBM(vbm_curly, "curly_rigged.vbm", vbf_rigged);

// Open TRK
trk = new TRKData();
OpenTRK(trk, "wave.trk");

// Model Controls
zrot = 0;
meshindex = 0;
meshvisible = ~0; // Bit field of all 1's
playbackposition = 0;
playbackduration = trk.duration;
playbackspeed = TrackData_GetTimeStep(trk, game_get_speed(gamespeed_fps));
playbackmode = 0; // 0 = Matrices, 1 = Tracks
localpose = Mat4Array(DMRVBM_MATPOSEMAX);
matpose = Mat4ArrayFlat(DMRVBM_MATPOSEMAX);


