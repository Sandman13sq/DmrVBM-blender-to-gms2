/// Functions for debugging

function updatef(_str, _value)
{
	_chr = string_char_at( _str, string_pos("%", _str) + 1);
	
	switch(_chr)
	{
		// Unknown Letter
		default:
			return string_replace(_str, "%" + _chr, "");
				
		// String
		case("s"):
			return string_replace(_str, "%s", string(_value));
				
		// Integer
		case("d"):
			return string_replace(_str, "%d", string( floor(_value) ));
				
		// Boolean
		case("b"):
			return string_replace(_str, "%b", _value? "True": "False");
				
		// Float w/ 4 places
		case("f"):
			return string_replace(_str, "%f", string_format(_value, 1, 4));
			
		// Float w/ 8 places
		case("F"):
			return string_replace(_str, "%F", string_format(_value, 1, 8));
		
		// Percent
		case("%"):
			return string_replace(_str, "%%", "%");
	}
	
	return _str;
}

// Sends string to console
/// @arg str,str,...
function cout()
{
	if keyboard_check_direct(vk_shift) {return;}
	
	var _str = "";
	for (var i = 0; i < argument_count; i++)
	{
		_str += string(argument[i]);
	}
	
	show_debug_message(_str);
}

/// @arg string_with_%s,value,value,...
function stringf()
{
	var _str = string(argument[0]), i = 1;
		
	// While %'s exist in string...
	while ( string_count("%", _str) && i < argument_count )
	{
		_str = updatef(_str, argument[i]);
		i++;
	}
	
	return _str;
}


/// @arg string_with_%s,value,value,...
function printf()
{
	var _str = string(argument[0]), i = 1;
		
	// While %'s exist in string...
	while ( string_count("%", _str) && i < argument_count )
	{
		_str = updatef(_str, argument[i]);
		i++;
	}
	
	show_debug_message(_str);
}

/// @arg x,y,string_with_%s,value,value,...
function drawf()
{
	var _str = string(argument[2]), i = 3;
		
	// While %'s exist in string...
	while ( string_count("%", _str) && i < argument_count )
	{
		_str = updatef(_str, argument[i]);
		i++;
	}
	
	draw_text(argument[0], argument[1], _str);
}

/// @arg x,y,string_with_%s,values[],string_with_%s,values[],...
function drawfext()
{
	var _str, _out = "", _l, _arr, j;
	
	for (var i = 2; i < argument_count; i += 2)
	{
		_str = string(argument[i]);
		_arr = argument[i + 1];
		
		// Value
		if !is_array(_arr)
		{
			_out += updatef(_str, _arr) + "\n";
		}
		// Array
		else
		{
			_l = array_length(_arr);
			j = 0;
			
			// While %'s exist in string...
			while ( string_count("%", _str) && j < _l )
			{
				_str = updatef(_str, _arr[j]);
				i++;
			}
			
			_out += _str + "\n";
		}
	}
	
	draw_text(argument[0], argument[1], _out);
}

/// @arg x,y,string_with_%s,values[],string_with_%s,values[],...
function drawfextd()
{
	var _str, _out = "", _l, _arr;
	
	var _drawmodev = draw_get_valign();
	draw_set_valign(2);
	
	for (var i = 2; i < argument_count; i += 2)
	{
		_str = string(argument[i]);
		_arr = argument[i + 1];
		
		// Value
		if !is_array(_arr)
		{
			_out += updatef(_str, _arr) + "\n";
		}
		// Array
		else
		{
			_l = array_length(_arr);
			j = 0;
			
			// While %'s exist in string...
			while ( string_count("%", _str) && j < _l )
			{
				_str = updatef(_str, _arr[j]);
				i++;
			}
			
			_out += _str + "\n";
		}
	}
	
	draw_text(argument[0], argument[1], _out);
	draw_set_valign(_drawmodev);
}

// Opens popup with string
/// @arg str,str,...
function msg()
{
	if keyboard_check_direct(vk_shift) {return;}
	
	var _str = "";
	for (var i = 0; i < argument_count; i++)
	{
		_str += string(argument[i]);
	}
	
	show_message(_str);
}

///
function msgMap(ds_map)
{
	var _key = ds_map_find_first(ds_map), _val, _str = "";
	while ds_map_exists(ds_map, _key)
	{
		_val = ds_map[? _key];
		
		// Go to next element in map
		_key = ds_map_find_next(ds_map, _key);
		
		// Code
		_str += string(_key) + ": " + string(_val) + "\n";
	}
	
	show_message(_str);
}

// Opens popup with string
/// @arg string_with_%s,value,value,...
function msgf()
{
	if keyboard_check_direct(vk_shift) {return;}
	
	var _str = string(argument[0]), i = 1;
		
	// While %'s exist in string...
	while ( string_count("%", _str) && i < argument_count )
	{
		_str = updatef(_str, argument[i]);
		i++;
	}
	
	show_message(_str);
}
