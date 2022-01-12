/// @desc

event_user(0);

DIRPATH = "D:/GitHub/DmrVBX/vbx_demo/datafiles/"

Structor_VBFormat(1);

enum ModelType
{
	simple, normal, vbx, normalmap, rigged, complete
}

camera = instance_create_depth(0, 0, 0, obj_camera);

// Vars ==============================================================

modelposition = [0,0,0];
modelzrot = 0;

wireframe = false;
usetextures = true;
usenormalmap = true;
drawnormal = false;
cullmode = cull_clockwise;

colorfill = [0, 1, 0.5, 0];
colorblend = [0.5, 1.0, 0.5, 0];

zrotanchor = 0;
mouseanchor = [0,0];
mouselock = 0;

lightdata = [-16, 128, 64, 1];

// Models =============================================================

vertex_format_begin();
vertex_format_add_position_3d();
vertex_format_add_color();
vertex_format_add_texcoord();
vbf_basic = vertex_format_end();

vertex_format_begin();
vertex_format_add_position_3d();
vertex_format_add_normal();
vertex_format_add_color();
vertex_format_add_texcoord();
vbf_model = vertex_format_end();

vb_world = OpenVertexBuffer(DIRPATH+"world.vb", vbf_model);
vb_ball = OpenVertexBuffer(DIRPATH+"ball.vb", vbf_basic);
vb_grid = CreateGridVB(128, 1);

drawworld = true;
drawcamerapos = false;
drawgrid = true;

u_shd_model_light = shader_get_uniform(shd_model, "u_light");
u_shd_model_drawmatrix = shader_get_uniform(shd_model, "u_drawmatrix");

// Demos ==============================================================

modelobj = array_create(8, obj_dm_simple);
modelobj[ModelType.simple]	= instance_create_depth(0,0,0, obj_dm_simple);
modelobj[ModelType.normal]	= instance_create_depth(0,0,0, obj_dm_normal);
modelobj[ModelType.vbx]	= instance_create_depth(0,0,0, obj_dm_vbx);
modelobj[ModelType.normalmap]	= instance_create_depth(0,0,0, obj_dm_vbx_normalmap);
modelobj[ModelType.rigged]	= instance_create_depth(0,0,0, obj_dm_vbx_rigged);
modelobj[ModelType.complete]	= instance_create_depth(0,0,0, obj_dm_vbx_complete);
modelmode = ModelType.rigged;

instance_deactivate_object(obj_demomodel);
instance_activate_object(modelobj[modelmode]);
modelactive = modelobj[modelmode];

// Layout
event_user(1);
