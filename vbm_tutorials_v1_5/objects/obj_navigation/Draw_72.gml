/// @description Background Shader

var w = surface_get_width(application_surface);
var h = surface_get_height(application_surface);
var s = max(w, h);

var colors = [
	.20, .20, .25, 1.0,
	.30, .20, .30, 1.0,
];

shader_set(shd_background);

var handle;
handle = shader_get_uniform(shd_background, "u_time");
shader_set_uniform_f(handle, current_time / 1000.0);
handle = shader_get_uniform(shd_background, "u_color");
shader_set_uniform_f_array(handle, colors);

draw_primitive_begin(pr_trianglelist);

draw_vertex_texture_color(0,0, 0,0, c_white, 1);
draw_vertex_texture_color(0,s, 0,1, c_white, 1);
draw_vertex_texture_color(s,0, 1,0, c_white, 1);

draw_vertex_texture_color(s,0, 1,0, c_white, 1);
draw_vertex_texture_color(0,s, 0,1, c_white, 1);
draw_vertex_texture_color(s,s, 1,1, c_white, 1);

draw_primitive_end();

shader_reset();
