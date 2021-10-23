/// @desc 

layout_model.Draw();

var s = [];

draw_set_halign(0);
draw_set_valign(0);

frametime = get_timer()-frametime;
array_push(s,
	camerapos,
	[x, y, z],
	stringf("Trackpos: %s", trackpos),
	stringf("Posemat: %s", poseindex),
	stringf("Parsemode: %s", keymode? "name": "index"),
	stringf("DeltaTime: %.4fms", frametime*0.001),
	stringf("EvaluationTime: %.4fms", exectime[0]*0.001),
	stringf("CalcuationTime: %.4fms", exectime[1]*0.001),
	);
frametime = get_timer();

var xx = 16, yy = window_get_height()-160;
for (var i = 0; i < array_length(s); i++) 
	{draw_text(xx, yy, s[i]); yy += 16;}

draw_text(300, 16, execinfo);