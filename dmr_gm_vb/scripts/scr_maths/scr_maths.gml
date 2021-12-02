/// @desc General math helper functions

// Returns value stepped towards target
function Approach(value, target, step)
{
	if value < target {return min(value + step, target);}
	else if value > target {return max(value - step, target);}
	else return target;
}

// Returns value stepped towards target
function ApproachSmooth(value, target, modstep)
{
	return value + (target-value) / modstep;
}

// Returns value stepped towards target
function ApproachSmoothInv(value, target, modstep)
{
	var d = target - lerp(value, target, 1/modstep);
	return value + d/modstep;
}

// Returns 1 if value evaluates to true, -1 if false
function Polarize(value)
{
	return value? 1: -1;
}

// Returns 0 or 1 based on value's position in interval
function BoolStep(value, step)
{
	return value mod (2*step);
}

// Returns -1, 0, or 1 based on given values
// -1 if negative only, 1 if positive only, 0 if none or both
function Lev(positive_bool, negative_bool)
	{return bool(positive_bool) - bool(negative_bool);}

function LevKeyHeld(positive_key, negative_key)
	{return keyboard_check(positive_key) - keyboard_check(negative_key);}
function LevKeyPressed(positive_key, negative_key)
	{return keyboard_check_pressed(positive_key) - keyboard_check_pressed(negative_key);}
function LevKeyReleased(positive_key, negative_key)
	{return keyboard_check_released(positive_key) - keyboard_check_released(negative_key);}

// Returns modulo of number
function Modulo(x, y)
{
	while x < 0 {x += y;}
	return x mod y;
}

// Returns floored step of value
function Quantize(x, step) {return (step > 0)? (floor(x/step)*step) : (floor(x*step)/step);}
function QuantizeRound(x, step) {return (step > 0)? (round(x/step)*step) : (round(x*step)/step);}
function QuantizeCeil(x, step) {return (step > 0)? (ceil(x/step)*step) : (ceil(x*step)/step);}

function Intrpl_Circ(x1, x2, amt)
{
	return lerp(x1, x2, 1-sqrt(1-amt*amt))	
}

function ArrayNextPos(array, pos)
{
	var n = array_length(array);
	if n == 0 {return pos;}
	printf(array)
	for (var i = 0; i < n; i++)
	{
		printf(array[i]);
		if array[i] > pos {return array[i];}
	}
	return array[0];
}

function ArrayPrevPos(array, pos)
{
	var n = array_length(array);
	if n == 0 {return pos;}
	for (var i = n-1; i >= 0; i--)
	{
		if array[i] < pos {return array[i];}
	}
	return array[n-1];
}

function ArrayToRGB(_array, index=0)
{
	return make_color_rgb(255*_array[index], 255*_array[index+1], 255*_array[index+2])
}

function ArrayClear(_array, value)
{
	var n = array_length(_array);
	
	if n > 0
	{
		// Set first entry
		_array[@ 0] = value;
	
		if n > 1
		{
			var nn = 1; // Number of copied values
			
			// Fill up most of array
			repeat( log2(n) )
			{
				array_copy(_array, nn, _array, 0, nn);
				nn *= 2;
			}
			
			// Fill in leftoveer
			if nn < n
			{
				array_copy(_array, (n-nn), _array, 0, nn);
			}
		}
	}
	
	return _array;
}

function BuildDrawMatrix(alpha=1, emission=0, shine=1, sss=0, blendcol=0, blendamt=0, fillcol=0, fillamt=0)
{
	return [
		alpha, emission, shine, sss, 
		color_get_red(blendcol)*0.004, color_get_green(blendcol)*0.004, color_get_blue(blendcol)*0.004, blendamt,
		color_get_red(fillcol)*0.004, color_get_green(fillcol)*0.004, color_get_blue(fillcol)*0.004, fillamt,
		0,0,0,0
	];
}
