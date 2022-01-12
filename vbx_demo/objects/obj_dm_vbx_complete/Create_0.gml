/// @desc

event_inherited();

// Vertex Format: [pos3f, normal3f, color4B, uv2f, bone4f, weight4f] ==========
vertex_format_begin();
vertex_format_add_position_3d();
vertex_format_add_normal();
vertex_format_add_custom(vertex_type_float3, vertex_usage_texcoord); // Tangent
vertex_format_add_custom(vertex_type_float3, vertex_usage_texcoord); // Bitangent
vertex_format_add_color();
vertex_format_add_texcoord();
vertex_format_add_custom(vertex_type_float4, vertex_usage_texcoord); // Bone Indices
vertex_format_add_custom(vertex_type_float4, vertex_usage_texcoord); // Bone Weights
vbf = vertex_format_end();

vbx = OpenVBX("curly_complete.vbx", vbf);
trackdata_anim = LoadAniTrack("curly_anim.trk");	// Animation
trackdata_poses = LoadAniTrack("curly_poses.trk");	// Poses with markers

// Animation Vars =====================================================
// 2D array of matrices. Holds relative transforms for bones
posetransform = Mat4Array(DMRVBX_MATPOSEMAX, matrix_build_identity());
// 1D flat array of matrices. Holds final transforms for bones
matpose = Mat4ArrayFlat(DMRVBX_MATPOSEMAX, matrix_build_identity());

trackpos = 0.0; // Position in animation
tracktimestep = TrackData_GetTimeStep(trackdata_anim, game_get_speed(gamespeed_fps));
playbackspeed = 1.0;
trackposlength = trackdata_anim.length;
isplaying = false;

posemode = 0; // 0 = Poses, 1 = Animation
poseindex = 0; // Index of pose in trackdata_poses
UpdatePose();

keymode = 0;
vbmode = 1;

wireframe = 0;
demo.usetextures = false;
interpolationtype = AniTrack_Intrpl.linear;

playbacktimeline = new PlaybackTimeline(trackdata_anim);

// Control Variables ========================================================
meshselect = 0;
meshvisible = array_create(32, 1);
meshflash = array_create(32, 0);
meshtexture = array_create(32, -1);
meshnormalmap = array_create(32, -1);

skinsss = 0.0;

LoadDiffuseTextures();
LoadNormalTextures();

drawmatrix = BuildDrawMatrix();

// Uniforms ========================================================
var _shd;
_shd = shd_complete;
u_shd_complete_drawmatrix = shader_get_uniform(_shd, "u_drawmatrix");
u_shd_complete_light = shader_get_uniform(_shd, "u_light");
u_shd_complete_matpose = shader_get_uniform(_shd, "u_matpose");
u_shd_complete_texnormal = shader_get_sampler_index(_shd, "u_texnormal");
u_shd_complete_mattex = shader_get_uniform(_shd, "u_mattex");

mattex_x = 0;
mattex_y = 0;
mattex_z = 0;
mattex = Mat4();

event_user(1);
