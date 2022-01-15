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

vbx = OpenVBX("curly_tangent.vbx", vbf);

// Control Variables
meshselect = 0;
meshvisible = array_create(32, 1);
meshflash = array_create(32, -1);
meshnormalmap = array_create(32, -1);
meshtexture = array_create(32, -1);

skinsss = 0.0;

drawmatrix = BuildDrawMatrix();

LoadDiffuseTextures();
LoadNormalTextures();

if vbx.FindVBIndex("curly_gun_mod") != -1
	{meshvisible[vbx.FindVBIndex("curly_gun_mod")] = 0;}

// Uniforms
var _shd;
_shd = shd_normalmap;
u_shd_normalmap_drawmatrix = shader_get_uniform(_shd, "u_drawmatrix");
u_shd_normalmap_light = shader_get_uniform(_shd, "u_light");
u_shd_normalmap_texnormal = shader_get_sampler_index(_shd, "u_texnormal");

event_user(1);
