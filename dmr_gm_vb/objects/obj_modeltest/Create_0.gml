/// @desc

vertex_format_begin();
vertex_format_add_position_3d();
vertex_format_add_normal();
vertex_format_add_color();
vertex_format_add_texcoord();
vbf_model = vertex_format_end();

vb = OpenVB(vbf_model, "curly.vb");
vbx = 0;

zfar = 1000;
znear = 1;
matproj = matrix_build_projection_perspective_fov(50, 480/270, znear, zfar);
matview = matrix_build_lookat(4, -32, 14, 0, 0, 10, 0, 0, -1);
