/// @desc General math helper functions

// Returns value stepped towards target
function Approach(value, target, step)
{
	if value < target {return min(value + step, target);}
	else if value > target {return max(value - step, target);}
	else return target;
}

// Returns 1 if value evaluates to true, -1 if false
function Polarize(value)
{
	return value? 1: -1;
}

// Returns 0 or 1 based on value's position in interval
function BoolStep(value, step)
{
	return (value div step) mod 2;
}

// Returns -1, 0, or 1 based on given values
// -1 if negative only, 1 if positive only, 0 if none or both
function Lev(positive_bool, negative_bool)
{
	return bool(positive_bool) - bool(negative_bool);
}

function Modulo(x, y)
{
	if x < 0 {x = y+x;} 
	if x == y {x -= y;}
	return max(0, x) mod y;
}