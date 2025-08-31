/// @desc Info

var _color;
var xx = 16, yy = 100, hh = 16;

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

