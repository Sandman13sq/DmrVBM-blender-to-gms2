/// @desc

event_inherited();

// Vertex Format: [pos3f, normal3f, color4B, uv2f]
vertex_format_begin();
vertex_format_add_position_3d();
vertex_format_add_normal();
vertex_format_add_color();
vertex_format_add_texcoord();
vbf = vertex_format_end();

vb = LoadVertexBuffer("curly_normal.vb", vbf);

// Control Variables
alpha = 1;
emission = 0;
shine = 1;
sss = 0;

colorfill = [0, 1, 0.5, 0];
colorblend = [0.5, 1.0, 0.5, 0];

wireframe = false;
cullmode = cull_clockwise;
drawmatrix = BuildDrawMatrix(alpha, emission, shine, sss,
	ArrayToRGB(colorblend), colorblend[3],
	ArrayToRGB(colorfill), colorfill[3],
	);

// Uniforms
var _shd;
_shd = shd_model;
u_shd_model_drawmatrix = shader_get_uniform(_shd, "u_drawmatrix");
u_shd_model_light = shader_get_uniform(_shd, "u_light");

event_user(1);
