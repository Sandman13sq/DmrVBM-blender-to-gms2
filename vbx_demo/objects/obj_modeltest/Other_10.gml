/// @desc Demo Methods

function CreateGridVB(cellcount, cellsize)
{
	// static = lambda ???
	static MakeVert = function(vb,x,y,col)
	{
		vertex_position_3d(vb, x, y, 0); 
		vertex_color(vb, col, 1);
		vertex_texcoord(vb, 0, 0);
	}
	
	// Set up colors: [Grid lines, X axis, Y axis]
	var colbase = [c_dkgray, c_maroon, c_green];
	var col = [ [0,0,0], [0,0,0], [0,0,0] ];
	
	var colgrid = c_dkgray;
	var colx = [c_red, merge_color(0, c_red, 0.5)];
	var coly = [c_lime, merge_color(0, c_lime, 0.5)];
	
	// Make Grid
	var width = cellsize * cellcount;
	
	var out = vertex_create_buffer();
	vertex_begin(out, vbf_basic);
	for (var i = -cellcount; i <= cellcount; i++)
	{
		if i == 0 {continue;}
		
		MakeVert(out, i*cellsize, width, colgrid);
		MakeVert(out, i * cellsize, -width, colgrid);
		
		MakeVert(out, width, i * cellsize, colgrid);
		MakeVert(out, -width, i * cellsize, colgrid);
	}
	
	// +x
	MakeVert(out, 0, 0, colx[0]);
	MakeVert(out, width, 0, colx[0]);
	MakeVert(out, 0, 0, colx[1]);
	MakeVert(out, -width, 0, colx[1]);
	
	MakeVert(out, 0, 0, coly[0]);
	MakeVert(out, 0, width, coly[0]);
	MakeVert(out, 0, 0, coly[1]);
	MakeVert(out, 0, -width, coly[1]);
	
	vertex_end(out);
	vertex_freeze(out);
	
	return out;
}

function ResetModelPosition()
{
	modelposition[0] = 0;
	modelposition[1] = 0;
	modelposition[2] = 0;
	modelzrot = 0;
}

function ParseIniInput(inikey, _default)
{
	var s = string_upper(ini_read_string("input", inikey, _default));
	
	if string_pos("RIGHT", s) {return vk_right;}
	if string_pos("UP", s) {return vk_up;}
	if string_pos("LEFT", s) {return vk_left;}
	if string_pos("DOWN", s) {return vk_down;}
	if string_pos("SPACE", s) {return vk_space;}
	
	if string_pos("F1", s) {return vk_f1;}
	if string_pos("F2", s) {return vk_f2;}
	if string_pos("F3", s) {return vk_f3;}
	if string_pos("F4", s) {return vk_f4;}
	if string_pos("F5", s) {return vk_f5;}
	if string_pos("F6", s) {return vk_f6;}
	if string_pos("F7", s) {return vk_f7;}
	if string_pos("F8", s) {return vk_f8;}
	if string_pos("F9", s) {return vk_f9;}
	if string_pos("F10", s) {return vk_f10;}
	if string_pos("F11", s) {return vk_f11;}
	if string_pos("F12", s) {return vk_f12;}
	
	return ord(s);
}

function LoadSettings()
{
	ini = ini_open("settings.ini");
	
	key_right = ParseIniInput("right", "D");
	key_left = ParseIniInput("left", "A");
	key_up = ParseIniInput("up", "W");
	key_down = ParseIniInput("down", "S");
	key_rotateright = ParseIniInput("turnright", "E");
	key_rotateleft = ParseIniInput("turnleft", "Q");
	key_playback = ParseIniInput("playback", "space");
	key_posenext = ParseIniInput("posenext", "X");
	key_poseprev = ParseIniInput("poseprev", "Z");
	key_fullscreen = ParseIniInput("fullscreen", "f4");
	key_gui = ParseIniInput("display", "H");
	
	ini_close();
	
	var wasdstring = (
		key_right == ord("D") &&
		key_left == ord("A") &&
		key_up == ord("W") &&
		key_down == ord("S")
	)? "WASD": "<User Defined>";
	
	var camerarotatestring = (
		key_rotateright == ord("E") &&
		key_rotateleft == ord("Q")
	)? "Q E": "<User Defined>";
	
	var playbackstring = key_playback == vk_space? "Space": "<User Defined>";
	var posenextstring = key_posenext == ord("X")? "X": "<User Defined>";
	var poseprevstring = key_poseprev == ord("Z")? "Z": "<User Defined>";
	
	var fullscreenstring = key_fullscreen == vk_f4? "F4": "<User Defined>";
	var guistring = key_gui == ord("H")? "H": "<User Defined>";
	
	controlsstring = (
		"== Controls ==" +"\n"+
		"*Hold Alt to simulate MMB*" + "\n\n" +
		"Rotate Model = LMB Drag" +"\n"+
		"Rotate Camera = MMB Drag" +"\n"+
		"Move Camera = Shift + MMB Drag" +"\n"+
		"\n"+
		wasdstring + "/Arrow Keys = Move Camera" +"\n"+
		"Shift + " + wasdstring + "/Arrow Keys = Move Model" +"\n"+
		camerarotatestring + " = Rotate Camera" +"\n"+
		"Shift + " + camerarotatestring + " = Rotate Model" +"\n"+
		"\n"+
		posenextstring + " = Next Pose" +"\n"+
		poseprevstring + " = Previous Pose" +"\n"+
		playbackstring + " = Toggle Animation Playback" +"\n"+
		"\n"+
		fullscreenstring + " = Toggle Fullscreen" +"\n"+
		guistring + " = Toggle GUI" +"\n"+
		""
	);
}

// Operators =================================================

function OP_ModelMode(value, btn)
{
	with obj_modeltest
	{
		modelmode = value;
		modelactive = modelobj[value];
		instance_deactivate_object(obj_demomodel);
		instance_activate_object(modelactive);
		modelactive.reactivated = 1;
	}
}

function OP_ToggleOrbit(value, btn)
{
	btn.root.FindElement("orbitspeed").interactable = value;
}

