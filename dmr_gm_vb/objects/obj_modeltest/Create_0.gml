/// @desc

event_user(0);

Structor_VBFormat(1);

enum ModelType
{
	simple, normal, vbx, normalmap, rigged, full
}

camera = instance_create_depth(0, 0, 0, obj_camera);

// Demos ==============================================================

modelobj = array_create(8, obj_dm_simple);
modelobj[ModelType.simple]	= instance_create_depth(0,0,0, obj_dm_simple);
modelobj[ModelType.normal]	= instance_create_depth(0,0,0, obj_dm_normal);
modelobj[ModelType.vbx]	= instance_create_depth(0,0,0, obj_dm_vbx);
modelobj[ModelType.normalmap]	= instance_create_depth(0,0,0, obj_dm_vbx_normalmap);
modelobj[ModelType.rigged]	= instance_create_depth(0,0,0, obj_dm_vbx_rigged);
//modelobj[ModelType.full]	= obj_demomodel_full;
modelmode = ModelType.normalmap;

instance_deactivate_object(obj_demomodel);
instance_activate_object(modelobj[modelmode]);
modelactive = modelobj[modelmode];

// Vars ==============================================================

modelposition = [0,0,0];
modelzrot = 0;

wireframe = false;
usetextures = true;
drawnormal = false;
cullmode = cull_clockwise;

colorfill = [0, 1, 0.5, 0];
colorblend = [0.5, 1.0, 0.5, 0];

zrotanchor = 0;
mouseanchor = [0,0];
mouselock = 0;

lightdata = [-16,-128,64, 1];

vb_world = LoadVertexBuffer("world.vb", RENDERING.vbformat.model);
vb_ball = LoadVertexBuffer("ball.vb", RENDERING.vbformat.basic);
vb_grid = CreateGridVB(128, 1);

drawworld = true;
drawcamerapos = false;
drawgrid = true;

u_shd_model_drawmatrix = shader_get_uniform(shd_model, "u_drawmatrix");

// Layout
event_user(1);
