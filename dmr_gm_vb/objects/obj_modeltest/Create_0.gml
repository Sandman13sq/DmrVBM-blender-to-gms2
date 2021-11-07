/// @desc

event_user(0);

Structor_VBFormat(1);

enum ModelType
{
	simple, normal, vbx, normalmap, rigged, full
}

camera = instance_create_depth(0, 0, 0, obj_camera);

modelobj = array_create(8);
modelobj[ModelType.simple]	= instance_create_depth(0,0,0, obj_demomodel_simple);
modelobj[ModelType.normal]	= instance_create_depth(0,0,0, obj_demomodel_normal);
modelobj[ModelType.vbx]	= instance_create_depth(0,0,0, obj_demomodel_vbx);
//modelobj[ModelType.normalmap]	= obj_demomodel_normal;
//modelobj[ModelType.rigged]	= obj_demomodel_rigged;
//modelobj[ModelType.full]	= obj_demomodel_full;
modelmode = ModelType.vbx;

instance_deactivate_object(obj_demomodel);
instance_activate_object(modelobj[modelmode]);

// Camera ==============================================================

curly = instance_create_depth(0,0,0, obj_curly);

modelposition = [0,0,0];
modelzrot = 0;

meshindex = 0;
meshdataactive = curly.meshdata[meshindex];

vb_world = LoadVertexBuffer("world.vb", RENDERING.vbformat.model);
vb_ball = LoadVertexBuffer("ball.vb", RENDERING.vbformat.basic);
vb_grid = CreateGridVB(128, 1);

drawcamerapos = false;
drawgrid = true;

u_shd_model_drawmatrix = shader_get_uniform(shd_model, "u_drawmatrix");

// Layout
event_user(1);

UpdateActiveVBX();
