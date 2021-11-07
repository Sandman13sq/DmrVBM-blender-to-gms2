/// @desc

gpu_push_state();

// GPU State
gpu_set_cullmode(cullmode);	// Don't draw tris facing away from camera
gpu_set_ztestenable(1);	// Enable depth checking per pixel
gpu_set_zwriteenable(1);	// Enable depth writing per pixel

shader_set(shd_simple);

// Set Uniforms
drawmatrix = BuildDrawMatrix(alpha, emission, shine, sss);

shader_set_uniform_f_array(u_shd_model_drawmatrix, drawmatrix);

vertex_submit(vb, wireframe? pr_linelist: pr_trianglelist, -1);

shader_reset();

gpu_pop_state();
