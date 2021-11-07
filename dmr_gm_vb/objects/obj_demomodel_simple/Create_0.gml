/// @desc

event_inherited();

// Vertex Format: [pos3f, color4B, uv2f]
vertex_format_begin();
vertex_format_add_position_3d();
vertex_format_add_color();
vertex_format_add_texcoord();
vbf = vertex_format_end();

vb = LoadVertexBuffer("curly_simple.vb", vbf);

// Control Variables
alpha = 1;

colorfill = [0, 1, 0.5, 0];
colorblend = [1, 1, 1, 0];

wireframe = false;
cullmode = cull_clockwise;
drawmatrix = BuildDrawMatrix(alpha, 0, 0, 0,
	ArrayToRGB(colorblend), colorblend[3],
	ArrayToRGB(colorfill), colorfill[3],
	);

use_gm_default_shader = false;

// Uniforms
var _shd;
_shd = shd_simple;
u_shd_model_drawmatrix = shader_get_uniform(_shd, "u_drawmatrix");

event_user(1);
