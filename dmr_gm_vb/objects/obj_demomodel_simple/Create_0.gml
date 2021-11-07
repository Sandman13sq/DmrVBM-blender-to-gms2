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
emission = 0;
shine = 1;
sss = 0;
drawmatrix = BuildDrawMatrix(alpha, emission, shine, sss);

wireframe = false;
cullmode = cull_clockwise;

// Uniforms
var _shd;
_shd = shd_simple;
u_shd_model_drawmatrix = shader_get_uniform(_shd, "u_drawmatrix");

event_user(1);
