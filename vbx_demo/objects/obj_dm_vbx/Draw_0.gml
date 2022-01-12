/// @desc

gpu_push_state();

// GPU State
gpu_set_cullmode(demo.cullmode);	// Don't draw tris facing away from camera
gpu_set_ztestenable(true);	// Enable depth checking per pixel
gpu_set_zwriteenable(true);	// Enable depth writing per pixel

shader_set(shd_model);

// Set Uniforms
drawmatrix = FetchDrawMatrix();

shader_set_uniform_f_array(u_shd_model_drawmatrix, drawmatrix);
shader_set_uniform_f_array(u_shd_model_light, obj_modeltest.lightdata);

matrix_set(matrix_world, matrix_build(
	obj_modeltest.modelposition[0], 
	obj_modeltest.modelposition[1], 
	obj_modeltest.modelposition[2], 
	0, 0, -obj_modeltest.modelzrot, 1, 1, 1));

// Draw Meshes
var n = vbx.vbcount;
var _primitivetype = demo.wireframe? pr_linelist: pr_trianglelist;

for (var i = 0; i < n; i++)
{
	if ( meshvisible[i] )
	{
		drawmatrix[3] = string_pos("skin", vbx.vbnames[i])? skinsss: sss;
		shader_set_uniform_f_array(u_shd_model_drawmatrix, drawmatrix);
		
		if ( demo.usetextures )
		{
			vbx.SubmitVBIndex(i, _primitivetype, meshtexture[i]);
		}
		else 
		{
			vbx.SubmitVBIndex(i, _primitivetype, -1);
		}
	}
}

// Mesh Flash
var zfunc = gpu_get_zfunc();
gpu_set_zfunc(cmpfunc_always);
shader_set_uniform_f_array(u_shd_model_drawmatrix, 
	BuildDrawMatrix(1, 1, 1, 0, 0, 0, c_white, 1));
for (var i = 0; i < n; i++)
{
	if ( meshvisible[i] && BoolStep(meshflash[i], 4) )
	{
		vbx.SubmitVBIndex(i, _primitivetype, -1);
	}
}
gpu_set_zfunc(zfunc);

// Restore State
shader_reset();
gpu_pop_state();
