/// @description Initialize Tutorials

tutorials = [
	0,
	obj_tutorial1_triangle,
	obj_tutorial2_loadmodel,
	obj_tutorial3_shaders,
	obj_tutorial4_animation,
	//obj_tutorial5_prism,
];

demos = [
	0,
	obj_demo_benchmark,
	obj_demo_verlettest,
];

tutorial_index = 1;
tutorial_inst = instance_create_depth(0,0,0, tutorials[tutorial_index]);
demo_mode = 0;

show_debug_overlay(true);
dmrfont = font_add_sprite(spr_dreamfont, 0x20, true, 0);

