/// @description Insert description here
// You can write your code in this editor

var w = surface_get_width(application_surface);
var h = surface_get_height(application_surface);
var s = max(w, h);

shader_set(shd_background);

var handle = shader_get_uniform(shd_background, "u_offset");
shader_set_uniform_f(handle, (current_time / 20000.0) mod 100000.0);

draw_primitive_begin(pr_trianglelist);

draw_vertex_texture_color(0,0, 0,0, c_white, 1);
draw_vertex_texture_color(0,s, 0,1, c_white, 1);
draw_vertex_texture_color(s,0, 1,0, c_white, 1);

draw_vertex_texture_color(s,0, 1,0, c_white, 1);
draw_vertex_texture_color(0,s, 0,1, c_white, 1);
draw_vertex_texture_color(s,s, 1,1, c_white, 1);

draw_primitive_end();

shader_reset();
