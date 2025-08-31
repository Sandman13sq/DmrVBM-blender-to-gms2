/// @description Background Shader

var w = surface_get_width(application_surface);
var h = surface_get_height(application_surface);
var s = max(w, h);

var colors = [
	.25, .20, .30, 1.0,
	.15, .20, .30, 1.0,
];

shader_set(shd_stinkyghost);

var handle;
handle = shader_get_uniform(shd_stinkyghost, "u_time");
shader_set_uniform_f(handle, current_time / 1000.0);
handle = shader_get_uniform(shd_stinkyghost, "u_color");
shader_set_uniform_f_array(handle, colors);

draw_sprite_stretched(spr_stinkyghost, 0, 0, 0, s, s);

shader_reset();
