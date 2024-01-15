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
	(!animator.Layer(0).forcelocalposes && animator.Layer(0).ActiveAnimation().isbakedlocal)? "Local": "Evaluated")); i++;
draw_text(16, i*20, "Animation Speed: " + string(playbackspeed)); i++;
draw_text(16, i*20, "Animation Elapsed: " + string(animator.Layer(0).animationelapsed)); i++;
draw_text(16, i*20, "Animation Position: " + string(animator.Layer(0).animationposition)); i++;

// Draw Layers
var ww = display_get_gui_width();
var hh = display_get_gui_height();
var yy = hh-48;
var _color;

for (var i = animator.layercount-1; i >= 0; i--)
{
	_color = (c_green + i*131313) % 0xFFFFFF
	
	draw_healthbar(16, yy, ww/2, yy + 20,
		(animator.Layer(i).Position())*100, c_black, _color, _color, 0, true, true);
	draw_text(20, yy, string(animator.Layer(i)));
	yy -= 20;
}

draw_text(16, yy, vbm_treat);
