/// @desc

event_inherited();

// Vertex Format: [pos3f, color4B, uv2f]
vertex_format_begin();
vertex_format_add_position_3d();
vertex_format_add_color();
vertex_format_add_texcoord();
vbf = vertex_format_end();

vb = OpenVertexBuffer(DIRPATH + "curly_simple.vb", vbf);

// Control Variables
alpha = 1;

use_gm_default_shader = false;

// Uniforms
var _shd;
_shd = shd_simple;
u_shd_simple_drawmatrix = shader_get_uniform(_shd, "u_drawmatrix");
u_shd_simple_light = shader_get_uniform(_shd, "u_light");

event_user(1);
