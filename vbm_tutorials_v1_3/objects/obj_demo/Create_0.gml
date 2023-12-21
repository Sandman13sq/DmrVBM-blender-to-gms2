/// @description 

tutorials = [
	0,
	obj_tutorial1_triangle,
	obj_tutorial2_loadingVB,
	obj_tutorial3_shaders,
	obj_tutorial4_VBManimation,
	obj_tutorial1_triangle
];

tutorialindex = 1;
tutorialinst = instance_create_depth(0, 0, 0, tutorials[tutorialindex]);

windowres = [0,0];

show_debug_overlay(true);
