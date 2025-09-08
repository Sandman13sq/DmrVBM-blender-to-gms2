/// @desc Info
var _color;
var xx = 16, yy = 100, hh = 16;

// Info
draw_text(xx, yy, "\"-\"/\"+\": Navigate Animation"); yy += hh;
draw_text(xx, yy, "\"B\": Refresh Benchmark"); yy += hh;
draw_text(xx, yy, "\"E\": Toggle Easy Eval"); yy += hh;

// Benchmark ----------------------------------------------
xx = room_width - 200;
yy = 100;
hh = 16;

// Bar
var _bw = 160, _amt, _sum = 0;
for (var i = 1; i < array_length(benchmark); i++) {
	_color = benchmark_color[i];
	_amt = benchmark[i][1] / benchmark[0][1];
	draw_rectangle_color(
		xx+_bw*(_sum), 
		yy, 
		xx+_bw*(_sum+_amt),
		yy+hh-4, 
		_color,_color,_color,_color, 
		0
	);
	_sum += _amt;
}
yy += hh;

// Amounts
for (var i = 0; i < array_length(benchmark); i++) {
	_color = benchmark_color[i];
	draw_text(xx, yy, benchmark_name[i] + ": ");
	draw_text(xx+100, yy, string_format(benchmark[i][1], 4, 2));
	draw_text_color(xx-4, yy, "||", _color, _color, _color, _color, 1.0);
	yy += hh;
}

// Progress
draw_healthbar(
	xx, yy, xx+160, yy+10, 
	100*VBM_ModelAnimation_EvaluateFramePosition(animation, animation_frame), 
	0x88332200,0x887777FF,0x887777FF,0,1,1
);

// Keyframes
var _anim = animation_blink;
var n = VBM_ModelAnimation_GetBoneCurveCount(_anim);
var cstart = 0;
var cend = min(n, cstart+8);
var x1 = room_width * (0.01);
var x2 = room_width * (0.98);
var _x, b, c;
xx = x1;

hh = 12;
yy = room_height - hh*(cend-cstart);

for (b = cstart; b < cend; b++) {
	var _numchannels = VBM_ModelAnimation_GetCurveSize(_anim, b);
	var _netkeyframes = 0;
	
	draw_set_alpha(0.3);
	draw_rectangle_color(
		x1, yy, lerp(x1, x2, VBM_ModelAnimation_EvaluateFramePosition(_anim, animation_frame)), yy+hh-2,
		0xFF7777FF, 0xFF7777FF, 0xFF7777FF, 0xFF7777FF, 0
	);
	draw_set_alpha(1.0);
	
	for (c = 0; c < _numchannels; c++) {
		var _channel = VBM_ModelAnimation_GetCurveChannel(_anim, b, c);
		var _numkeyframes = array_length(_channel.points);
		_netkeyframes += _numkeyframes;
		for ( var k = 0; k < _numkeyframes; k++ ) {
			_x = lerp(x1, x2, _channel.points[k].posx);
			draw_rectangle(_x, yy, _x, yy+hh-2, 0);
		}
	}
	
	draw_text(x1+2, yy, VBM_ModelAnimation_GetCurveName(_anim, b));
	draw_text(x2+2, yy, _netkeyframes);
	yy += hh;
}
draw_set_halign(0);

