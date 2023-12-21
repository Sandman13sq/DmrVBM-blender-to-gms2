/// @desc Draw mesh visiblity

draw_set_halign(0);
draw_set_valign(0);

var i = 5;
draw_text(16, i*20, "Use the arrow keys to move camera"); i++;
draw_text(16, i*20, "Hold SHIFT and use arrow keys to rotate model"); i++;
draw_text(16, i*20, "Camera Position: " + string(viewposition)); i++;
draw_text(16, i*20, "Z Rotation: " + string(zrot)); i++;
draw_text(16, i*20, "Press Z to move to next animation"); i++;
draw_text(16, i*20, "Press X to switch animation modes"); i++;
draw_text(16, i*20, "Press SPACE to Play/Pause Layer 0"); i++;
draw_text(16, i*20, "Press +/- to change animation speed"); i++;

draw_text(16, i*20, "Animation Mode: " + (
	(!vbm_treat.Animator().forcelocalposes && vbm_treat.Animator().ActiveAnimation().isbakedlocal)? "Local": "Evaluated")); i++;
draw_text(16, i*20, "Animation Speed: " + string(playbackspeed)); i++;
draw_text(16, i*20, "Animation Elapsed: " + string(vbm_treat.Animator().animationelapsed)); i++;
draw_text(16, i*20, "Animation Position: " + string(vbm_treat.Animator().animationposition)); i++;

var ww = display_get_gui_width();
var hh = display_get_gui_height();

draw_healthbar(16, hh-50, ww/2, hh-31,
	(vbm_treat.Animator().animationposition mod 1.0)*100, c_black, c_green, c_green, 0, true, true);
draw_text(20, hh-48, string(vbm_treat.Animator()));

