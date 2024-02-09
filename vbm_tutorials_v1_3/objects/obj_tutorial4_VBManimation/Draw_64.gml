/// @desc Draw mesh visiblity

var xx, yy;
var ww = display_get_gui_width();
var hh = display_get_gui_height();
var _color;

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
draw_text(16, i*20, "Press </> to navigate meshes"); i++;
draw_text(16, i*20, "Press ? to toggle mesh visibility"); i++;

draw_text(16, i*20, "Animation Mode: " + (
	(!animator.Layer(0).forcelocalposes && animator.Layer(0).ActiveAnimation().isbakedlocal)? "Local": "Evaluated")); i++;
draw_text(16, i*20, "Animation Speed: " + string(playbackspeed)); i++;
draw_text(16, i*20, "Animation Elapsed: " + string(animator.Layer(0).animationelapsed)); i++;
draw_text(16, i*20, "Animation Position: " + string(animator.Layer(0).animationposition)); i++;

// Draw Model Info
xx = ww-8;
yy = 40;
_color = c_white;

draw_set_halign(fa_right);
draw_text(xx, yy, vbm_treat);

yy += 40;
for (var i = 0; i < vbm_treat.meshcount; i++)
{
	if ( i == meshselect )
	{
		draw_rectangle_color(xx-128, yy, xx, yy+20, _color,_color,_color,_color, true);
	}
	
	draw_text(xx, yy, vbm_treat.MeshGet(i).name + (vbm_treat.MeshGet(i).visible? "  [O]": "  [ ]"));
	yy += 20;
}

// Draw Layers
yy = hh-48;

draw_set_halign(fa_left);
for (var i = animator.layercount-1; i >= 0; i--)
{
	_color = (c_green + i*131313) % 0xFFFFFF
	
	draw_healthbar(16, yy, ww/2, yy + 20,
		(animator.Layer(i).Position())*100, c_black, _color, _color, 0, true, true);
	draw_text(20, yy, string(animator.Layer(i)));
	yy -= 20;
}

