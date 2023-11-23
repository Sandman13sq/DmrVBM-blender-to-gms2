/// @desc Draw mesh visiblity

draw_set_halign(0);
draw_set_valign(0);

draw_text(16, 16, "Use the arrow keys to move camera");
draw_text(16, 32, "Hold SHIFT and use arrow keys to rotate model");
draw_text(16, 64, "Camera Position: " + string(viewposition));
draw_text(16, 80, "Camera Rotation: " + string(viewzrot));
draw_text(16, 112, "Model Z Rotation: " + string(zrot));
draw_text(16, 138, "Use +/- to change mesh index, SPACE to toggle visibility");

var _name, _color;
for (var i = 0; i < vbm_starcie.Count(); i++)
{
	_name = vbm_starcie.GetName(i);
	_color = (meshvisible & (1<<i))? c_white: c_gray;
	
	draw_text_color(16, 128+i*16, 
		( (meshvisible & (1<<i))? "O ": "X " ) + 
		( (i==meshindex)? ("["+_name+"]"): (" "+_name) ),
		_color, _color, _color, _color, 1
		);
}
