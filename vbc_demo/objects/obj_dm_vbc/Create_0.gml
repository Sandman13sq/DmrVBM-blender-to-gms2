/// @desc

event_inherited();

// Vertex Format: [pos3f, normal3f, color4B, uv2f]
vertex_format_begin();
vertex_format_add_position_3d();
vertex_format_add_normal();
vertex_format_add_color();
vertex_format_add_texcoord();
vbf = vertex_format_end();

vbc = new VBCData();
OpenVBC(vbc, DIRPATH+"model/" + "curly.vbc", vbf);

// Control Variables
meshselect = 0;
meshvisible = array_create(32, 1);
meshflash = array_create(32, 0);
meshtexture = array_create(32, -1);

skinsss = 0.0;

drawmatrix = BuildDrawMatrix();

LoadDiffuseTextures();

if (vbc)
{
	if vbc.FindVBIndex("curly_gun_mod") != -1
		{meshvisible[vbc.FindVBIndex("curly_gun_mod")] = 0;}
	if vbc.FindVBIndex("curly_school") != -1
		{meshvisible[vbc.FindVBIndex("curly_school")] = 0;}
}

// Uniforms
var _shd;
_shd = shd_model;
u_shd_model_drawmatrix = shader_get_uniform(_shd, "u_drawmatrix");
u_shd_model_light = shader_get_uniform(_shd, "u_light");

event_user(1);
