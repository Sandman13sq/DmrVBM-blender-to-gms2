/// @desc

gpu_push_state();

// GPU State
gpu_set_cullmode(demo.cullmode);	// Don't draw tris facing away from camera
gpu_set_ztestenable(true);	// Enable depth checking per pixel
gpu_set_zwriteenable(true);	// Enable depth writing per pixel

shader_set(shd_normalmap);

// Set Uniforms
drawmatrix = FetchDrawMatrix();

shader_set_uniform_f_array(u_shd_normalmap_drawmatrix, drawmatrix);
shader_set_uniform_f_array(u_shd_normalmap_light, obj_modeltest.lightdata);

matrix_set(matrix_world, matrix_build(
	obj_modeltest.modelposition[0], 
	obj_modeltest.modelposition[1], 
	obj_modeltest.modelposition[2], 
	0, 0, -obj_modeltest.modelzrot, 1, 1, 1));

// Draw Meshes
var n = vbc.vbcount;
var _primitivetype = demo.wireframe? pr_linelist: pr_trianglelist;

for (var i = 0; i < n; i++)
{
	if ( meshvisible[i] )
	{
		drawmatrix[3] = string_pos("skin", vbc.vbnames[i])? skinsss: rimstrength;
		shader_set_uniform_f_array(u_shd_normalmap_drawmatrix, drawmatrix);
		
		texture_set_stage(u_shd_normalmap_texnormal, demo.usenormalmap? meshnormalmap[i]: -1);
		
		if ( demo.drawnormal )
		{
			vbc.SubmitVBIndex(i, _primitivetype, meshnormalmap[i]);
		}
		else if ( demo.usetextures )
		{
			vbc.SubmitVBIndex(i, _primitivetype, meshtexture[i]);
		}
		else 
		{
			vbc.SubmitVBIndex(i, _primitivetype, -1);
		}
	}
}

// Mesh Flash
DrawMeshFlash(u_shd_normalmap_drawmatrix);

// Restore State
shader_reset();
gpu_pop_state();
