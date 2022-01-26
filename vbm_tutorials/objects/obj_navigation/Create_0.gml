/// @desc 

show_debug_overlay(true);

fnt_dmr = font_add_sprite(spr_dmrfont, ord(" "), true, 1);
draw_set_font(fnt_dmr);

tutorialobjects = [
	0,
	obj_tutorial01_triangle,
	obj_tutorial02_loadingVB,
	obj_tutorial03_shaders,
	obj_tutorial04_loadingVBM,
	obj_tutorial05_animation,
];

tutorialnames = [
	"",
	"Tutorial 1: Basic Triangle",
	"Tutorial 2: Loading Vertex Buffer",
	"Tutorial 3: Using Shaders",
	"Tutorial 4: Loading VBM",
	"Tutorial 5: Animation",
	""
];

tutorialindex = 5;
tutorialactive = instance_create_depth(0, 0, 0, tutorialobjects[tutorialindex]);

lastfullscreen = window_get_fullscreen();
lastwindowsize = [0, 0];

function ChangeTutorial(index)
{
	if (index > 0 && index < array_length(tutorialobjects))
	{
		if (tutorialactive)
		{
			instance_destroy(tutorialactive);
			tutorialactive = noone;
		}
		
		tutorialindex = index;
		tutorialactive = instance_create_depth(0, 0, 0, tutorialobjects[tutorialindex]);
	}
}
