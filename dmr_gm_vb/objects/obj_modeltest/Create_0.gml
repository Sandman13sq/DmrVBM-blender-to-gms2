/// @desc

event_user(0);

#region VBF Setup

vertex_format_begin();
vertex_format_add_position_3d();
vertex_format_add_normal();
vertex_format_add_color();
vertex_format_add_texcoord();
vbf_model = vertex_format_end();

vertex_format_begin();
vertex_format_add_position_3d();
vertex_format_add_color();
vertex_format_add_texcoord();
vbf_default = vertex_format_end();

#endregion

x = 0;
y = 0;
z = 0;

camera = [
	4, 28, 10,	// x, y, z
	0, 0, 0,	// fwrd
];

vb = OpenVB(vbf_model, "curly.vb");
vb_grid = CreateGridVB(40, 16);
vbx = LoadVertexBufferExt("curly.vbx", vbf_model);

vbmode = 1;

zfar = 1000;
znear = 1;
matproj = matrix_build_projection_perspective_fov(50, 480/270, znear, zfar);
matview = matrix_build_lookat(camera[0], camera[1], camera[2], 0, 0, 10, 0, 0, 1);
mattran = matrix_build(0,0,0, 0,0,0, 1,1,1);
drawmatrix = BuildDrawMatrix(1);

u_drawmatrix = shader_get_uniform(shd_model, "u_drawmatrix");
u_camera = shader_get_uniform(shd_model, "u_camera");

zrot = 0;
