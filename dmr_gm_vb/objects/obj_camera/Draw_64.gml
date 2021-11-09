/// @desc Debug

draw_set_halign(0);
draw_set_valign(0);

drawfext(16, 200,
	"middlelock: %s", middlelock,
	"cameralocation: %s", [viewlocation],
	"location: %s", [obj_modeltest.modelposition],
	"viewdirection: %s", viewdirection,
	"viewpitch: %s", viewpitch,
	"forward: %s", string(viewforward),
	"right: %s", string(viewright),
	"fps: %s", string(fps),
	"fpsreal: %s", string(fps_real),
	);
