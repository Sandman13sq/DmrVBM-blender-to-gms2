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