/// @desc

event_user(0);

#region VBF Setup

vertex_format_begin();
vertex_format_add_position_3d();
vertex_format_add_color();
vertex_format_add_texcoord();
vbf_default = vertex_format_end();

vertex_format_begin();
vertex_format_add_position_3d();
vertex_format_add_normal();
vertex_format_add_color();
vertex_format_add_texcoord();
vbf_model = vertex_format_end();

vertex_format_begin();
vertex_format_add_position_3d();
vertex_format_add_normal();
vertex_format_add_color();
vertex_format_add_texcoord();
vertex_format_add_custom(vertex_type_float4, vertex_usage_texcoord); // Bone Indices
vertex_format_add_custom(vertex_type_float4, vertex_usage_texcoord); // Bone Weights
vbf_rigged = vertex_format_end();

vertex_format_begin();
vertex_format_add_position_3d();
vertex_format_add_normal();
vertex_format_add_custom(vertex_type_float3, vertex_usage_texcoord); // Tangent
vertex_format_add_custom(vertex_type_float3, vertex_usage_texcoord); // Bitangent
vertex_format_add_color();
vertex_format_add_texcoord();
vertex_format_add_custom(vertex_type_float4, vertex_usage_texcoord); // Bone Indices
vertex_format_add_custom(vertex_type_float4, vertex_usage_texcoord); // Bone Weights
vbf_full = vertex_format_end();

#endregion

x = 0;
y = 0;
z = 0;

camera = [
	4, 28, 10,	// x, y, z
	0, 0, 0,	// fwrd
];

mouselook = new MouseLook();

vb = LoadVertexBuffer("curly.vb", vbf_model);
vb_grid = CreateGridVB(40, 16);
vbx = LoadVBX("curly.vbx", vbf_rigged);

vbmode = 1;

zfar = 1000;
znear = 5;
matproj = matrix_build_projection_perspective_fov(50, 480/270, znear, zfar);
matview = matrix_build_lookat(camera[0], camera[1], camera[2], 0, 0, 10, 0, 0, 1);
matview = matrix_multiply(matrix_build(0,0,0,0,0,0,1,-1,1), matview);
mattran = matrix_build(0,0,0, 0,0,0, 1,1,1);
drawmatrix = BuildDrawMatrix(1);

for (var i = 200-1; i >= 0; i--) 
	{inpose[i] = matrix_build_identity();}
matpose = array_create(200*16);
trackdata = LoadAniTrack("curly.trk");
trackposindex = 0;
trackpos = 0;
trackposspeed = (trackdata.framespersecond/game_get_speed(gamespeed_fps))/trackdata.length;
isplaying = 1;

printf(trackdata.markerpositions);

execinfo = "";

for (var i = 0; i < 200*16; i += 16)
{
	array_copy(matpose, i, inpose[0], 0, 16);
}

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

zrot = 0;
