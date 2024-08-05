/// @description Insert description here
// You can write your code in this editor

tutorials = [
	0,
	obj_tutorial1_triangle,
	obj_tutorial2_loadModel,
	obj_tutorial3_shaders,
	obj_tutorial4_animation,
	obj_tutorial5_animator,
];

tutorial_index = 1;
tutorial_inst = instance_create_depth(0,0,0, tutorials[tutorial_index]);

show_debug_overlay(true);

dmrfont = font_add_sprite(spr_dmrfont, 0x20, true, 1);
