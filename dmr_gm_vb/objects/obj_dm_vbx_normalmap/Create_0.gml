/// @desc

event_inherited();

// Vertex Format: [pos3f, normal3f, color4B, uv2f]
vertex_format_begin();
vertex_format_add_position_3d();
vertex_format_add_normal();
vertex_format_add_custom(vertex_type_float3, vertex_usage_texcoord); // Tangent
vertex_format_add_custom(vertex_type_float3, vertex_usage_texcoord); // Bitangent
vertex_format_add_color();
vertex_format_add_texcoord();
vbf = vertex_format_end();

vbx = LoadVBX("curly_tanbitan.vbx", vbf);

// Control Variables
meshvisible = array_create(32, 1);
meshnormalmap = array_create(32, -1);
meshtexture = array_create(32, -1);

drawmatrix = BuildDrawMatrix();

LoadDiffuseTextures();
LoadNormalTextures();

// Uniforms
var _shd;
_shd = shd_normalmap;
u_shd_normalmap_drawmatrix = shader_get_uniform(_shd, "u_drawmatrix");
u_shd_normalmap_light = shader_get_uniform(_shd, "u_light");
u_shd_normalmap_texnormal = shader_get_sampler_index(_shd, "u_texnormal");

event_user(1);
