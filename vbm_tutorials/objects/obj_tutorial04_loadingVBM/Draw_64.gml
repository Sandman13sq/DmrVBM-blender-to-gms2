/// @desc Draw mesh visiblity

draw_set_halign(0);
draw_set_valign(0);

draw_text(16, 16, "Use the arrow keys to move camera");
draw_text(16, 32, "Hold SHIFT and use arrow keys to rotate model");
draw_text(16, 64, "Camera Position: " + string(viewposition));
draw_text(16, 80, "Z Rotation: " + string(zrot));
draw_text(16, 112, "Use +/- to change mesh index, SPACE to toggle visibility");

var _name;
for (var i = 0; i < vbm_kindle.Count(); i++)
{
	_name = vbm_kindle.GetName(i);
	draw_text(16, 128+i*16, (i==meshindex)? ("["+_name+"]"): (" "+_name));
}
