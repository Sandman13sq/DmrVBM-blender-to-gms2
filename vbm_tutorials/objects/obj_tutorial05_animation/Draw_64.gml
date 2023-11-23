/// @desc Draw mesh visiblity

draw_set_halign(0);
draw_set_valign(0);

draw_text(16, 16, "Use the arrow keys to move camera");
draw_text(16, 32, "Hold SHIFT and use arrow keys to rotate model");
draw_text(16, 64, "Camera Position: " + string(viewposition));
draw_text(16, 80, "Z Rotation: " + string(zrot));
draw_text(16, 112, "Press Z to move to next animation");
draw_text(16, 128, "Press X to switch animation modes");
draw_text(16, 144, "Press SPACE to Play/Pause Layer 0");
draw_text(16, 160, "Press +/- to change animation speed");
draw_text(16, 176, "Animation Mode: " + (playbackmode==0? "Evaluated": (playbackmode==1? "Pose": "Track")));
draw_text(16, 192, "Animation Speed: " + string(playbackspeed));
draw_text(16, 208, "Animation Position: " + string(trkanimator.Layer(0).animationposition));
draw_text(16, 224, "Animation Frame: " + string(trkanimator.Layer(0).animationframe));

var ww = display_get_gui_width();
var hh = display_get_gui_height();

draw_healthbar(16, hh-50, ww/2, hh-31, 
	trkanimator.Layer(0).animationposition*100, c_black, c_green, c_green, 0, true, true);
draw_text(20, hh-48, string(trkanimator.Layer(0).animationkey));
draw_text(100, hh-48, string(trkanimator));

draw_healthbar(16, hh-30, ww/2, hh-11, 
	trkanimator.Layer(1).animationposition*100, c_black, c_teal, c_teal, 0, true, true);
draw_text(20, hh-28, string(trkanimator.Layer(1).animationkey));
draw_text(100, hh-28, string(trkanimator));
