/// @desc

function LayoutElement_Text(_root, _parent) : LayoutElement(_root, _parent) constructor
{
	textheight = common.cellmax;
	
	function UpdatePos(_x1, _y1, _x2, _y2)
	{
		x1 = _x1;
		y1 = _y1;
		x2 = _x2;
		y2 = y1 + textheight;
		w = x2-x1;
		h = y2-y1;
		
		xc = lerp(x1, x2, 0.5);
		yc = lerp(y1, y2, 0.5);
		
		return [w, h];
	}
	
	function Update()
	{
		
	}
	
	function Draw()
	{
		if label != ""
		{
			textheight = string_height(label);
			draw_set_halign(1);
			draw_set_valign(0);
			DrawTextYCenter(xc, label);
		}
		else
		{
			textheight = 0;	
		}
	}
}

function LayoutElement_Button(_root, _parent) : LayoutElement(_root, _parent) constructor
{
	color = common.c_base;
	toggle_on_click = false;
	valuedefault = value;
	
	function UpdatePos(_x1, _y1, _x2, _y2)
	{
		x1 = _x1;
		y1 = _y1;
		x2 = _x2;
		y2 = y1 + common.cellmax;
		w = x2-x1;
		h = y2-y1;
		
		xc = lerp(x1, x2, 0.5);
		yc = lerp(y1, y2, 0.5);
		
		return [w, h];
	}
	
	function Update()
	{
		value = GetControl();
		ClickUpdate();
		
		if IsMouseOver()
		{
			common.active = self;
			
			color = common.c_highlight;	
			
			// When mouse is held
			if clickhold
				{color = common.c_active;}
			
			// When mouse is released
			if clickrelease
			{
				if toggle_on_click
				{
					value ^= 1;
				}
				UpdateControl(value);
				
				if op {op(value, self);}
			}
			
			// Default Value
			if keyboard_check_pressed(vk_backspace)
			{
				value = valuedefault;
				UpdateControl(value);
				if op {op(value, self);}
			}
			
			UpdateTooltip();
		}
		else
		{
			color = common.c_base;	
		}
	}
	
	function Draw()
	{
		DrawRectWH(x1, y1, w, h, color);
		
		if label != ""
		{
			draw_set_halign(1);
			draw_set_valign(0);
			DrawTextYCenter(xc, label);
		}
	}
}

function LayoutElement_Bool(_root, _parent) : LayoutElement(_root, _parent) constructor
{
	color = common.c_base;
	ismouseover = false;
	valuedefault = value;
	
	function Value(_value, runop=true)
	{
		value = bool(_value);
		if runop && op {op(value, self);}
		return self;
	}
	
	function Toggle(runop=true)
	{
		Value(!value, runop);
	}
	
	function UpdatePos(_x1, _y1, _x2, _y2)
	{
		x1 = _x1;
		y1 = _y1;
		x2 = _x2;
		y2 = y1 + common.cellmax;
		w = x2-x1;
		h = y2-y1;
		
		xc = lerp(x1, x2, 0.5);
		yc = lerp(y1, y2, 0.5);
		
		return [w, h];
	}
	
	function Update()
	{
		value = GetControl();
		ClickUpdate();
		
		if IsMouseOver()
		{
			common.active = self;
			
			color = common.c_highlight;	
			
			if clickhold
				{color = common.c_active;}
			
			if clickrelease
			{
				value ^= 1; // Toggle boolean
				UpdateControl(value);
				if op {op(value, self);}
			}
			
			ismouseover = true;
			
			// Default Value
			if keyboard_check_pressed(vk_backspace)
			{
				value = valuedefault;
				UpdateControl(value);
				if op {op(value, self);}
			}
			
			UpdateTooltip();
		}
		else
		{
			color = common.c_base;
			ismouseover = false;
		}
	}
	
	function Draw()
	{
		// Draw back highlight
		if ismouseover
		{
			DrawFillXY(x1+2, y1+2, x2-2, y2-2, color, 0);	
		}
		
		// Draw "checkbox"
		var _cm = common.cellmax;
		DrawRectWH(x1, y1, _cm, _cm, color);
		
		// Draw "on" state
		if value
		{
			var _s = 4, _ss = _s*2;
			DrawRectWH(x1+_s, y1+_s, _cm-_ss, _cm-_ss, c_white);
		}
		
		// Draw Label after checkbox
		if label != ""
		{
			draw_set_halign(0);
			draw_set_valign(0);
			DrawTextYCenter(x1+_cm+3, label);
		}
	}
}

function LayoutElement_Real(_root, _parent) : LayoutElement_Button(_root, _parent) constructor
{
	color = [0, 0, 0];
	value = 0;
	valuedefault = value;
	valuestep = 3/100;
	valuemin = -infinity;
	valuemax = infinity;
	valueanchor = 0;
	mouseanchor = [0, 0];
	typing = 0;
	clearonkey = false;
	
	valueprecision = 2;	// Number of decimal places to display
	operator_on_change = false;	// Call operator when value is updated
	draw_increments = true;	// Draw plus and minus signs
	
	function SetBounds(_min, _max, _step = valuestep)
	{
		valuemin = _min;
		valuemax = _max;
		valuestep = _step;
		return self;
	}
	
	function SetStep(_step)
	{
		valuestep = _step;
		return self;
	}
	
	function Update()
	{
		color[0] = common.c_base;
		color[1] = common.c_base;
		color[2] = common.c_base;
		
		value = GetControl();
		ClickUpdate();
		
		var mbheld = clickhold;
		var mbpressed = clickpress;
		var mbreleased = clickrelease;
		
		// Drag Value
		if active
		{
			if clickhold
			{
				common.cursorsprite = cr_none;
				color[1] = common.c_active;
				common.active = self;
				
				//var d = window_mouse_get_x()-window_get_width()/2;
				//window_mouse_set(window_get_width()/2, window_get_height()/2);
				
				var d = window_mouse_get_x()-mouseanchor[0];
				window_mouse_set(mouseanchor[0], mouseanchor[1]);
				
				// Mouse movement is high enough
				if abs(d) >= ((valuestep >= 1)? 2: 1)
				{
					var _add;
					
					// Fractional Drag
					if keyboard_check(vk_control)
					{
						var _steps = (valuestep > 1)? 1: (valuemax-valuemin)/10;
						_add = sign(d)*_steps;
						
						value = floor(value/_steps)*_steps;
 					}
					// Normal Drag
					else
					{
						var sh = keyboard_check(vk_shift)? 0.1: 1;
						_add = d*valuestep*sh;
					}
					
					// Clamp only if value is already within bounds
					if d > 0
					if value <= valuemax {value = min(value+_add, valuemax);} else {value += _add;}
					else if d < 0
					if value >= valuemin {value = max(value+_add, valuemin);} else {value += _add;}
					
					UpdateControl(value);
							
					if operator_on_change
					{
						if op {op(value, self);}
					}
				}
			}
			else
			{
				active = false;
				window_mouse_set(mouseanchor[0], mouseanchor[1]);
				window_set_cursor(cr_arrow);
				
				if operator_on_change
				{
					if op {op(value, self);}
				}
			}
			
		}
		
		// Basic Controls
		if IsMouseOver() && !active
		{
			UpdateTooltip();
			
			// Lock layout scrolling
			var xx = [x1, x1+16, x2-16, x2];
			if !draw_increments {xx[1] = x1; xx[2] = x2;}
			
			// Decrement
			if draw_increments && IsMouseOverXY(xx[0], y1, xx[1], y2)
			{
				color[0] = common.c_highlight;
				if mbheld {color[0] = common.c_active;}
				if mbreleased
				{
					value = max(valuemin, value-valuestep);
					UpdateControl(value);
					if op {op(value, self);}
				}
			}
			// Increment
			else if draw_increments && IsMouseOverXY(xx[2], y1, xx[3], y2)
			{
				color[2] = common.c_highlight;
				if mbheld {color[2] = common.c_active;}
				if mbreleased 
				{
					value = min(valuemax, value+valuestep);
					UpdateControl(value);
					if op {op(value, self);}
				}
			}
			// Middle
			else if IsMouseOverXY(xx[1], y1, xx[2], y2)
			{
				common.scrolllock = true;
				color[1] = common.c_highlight;
				
				if common.doubleclick
				|| (mbreleased && common.lastpress <= 10)
				{
					typing = 1;
					clearonkey = true;
					keyboard_string = string(value);
				}
				
				if !typing
				{
					if mbpressed
					{
						valueanchor = value;
						active = true;
					
						mouseanchor[0] = window_mouse_get_x();
						mouseanchor[1] = window_mouse_get_y();
						window_mouse_set(mouseanchor[0], mouseanchor[1]);
					}
					
					if mbreleased
					{
						if op {op(value, self);}
					}
					
					var d = mouse_wheel_up()-mouse_wheel_down();
					if d != 0
					{
						var _add = d*valuestep*2;
						
						// Clamp only if value is already within bounds
						if d > 0
						if value <= valuemax {value = min(value+_add, valuemax);} else {value += _add;}
						else if d < 0
						if value >= valuemin {value = max(value+_add, valuemin);} else {value += _add;}
						
						UpdateControl(value);
							
						if operator_on_change
						{
							if op {op(value, self);}
						}
					}
					
					// Default Value
					if keyboard_check_pressed(vk_backspace)
					{
						value = valuedefault;
						UpdateControl(value);
						if op {op(value, self);}
					}
					
					common.cursorsprite = cr_size_we;
				}
			}
		}
		
		// Typing Value
		if typing
		{
			if keyboard_check_pressed(vk_escape)
			{
				typing = false;
				valueanchor = value;
			}
			else if keyboard_check_pressed(vk_enter)
			{
				typing = false;
				if string_digits(keyboard_string) != ""
				{
					var err;
					var _lastval = value;
					try
					{
						value = real(keyboard_string);
					}
					catch(err)
					{
						value = _lastval;
						show_debug_message(err);
					}
					UpdateControl(value);
					if op {op(value, self);}
				}
			}
			else if keyboard_check_pressed(vk_anykey)
			{
				switch(keyboard_lastkey)
				{
					default:
						if clearonkey 
						{
							if ord(keyboard_lastchar) >= 32
							{
								keyboard_string = keyboard_lastchar;
							}
							
							clearonkey = false;
						}
						break;
					
					case(vk_right):
					case(vk_left):
					case(vk_up):
					case(vk_down):
						clearonkey = false;
						break;
					
				}
				
			}
			
			if mouse_check_button_pressed(mb_left)
			&& !IsMouseOver()
			{
				typing = false;	
				valueanchor = value;
				active = false;
			}	
		}
	}
	
	function Draw()
	{
		DrawRectWH(x1, y1, w, h, color[1]);
		
		var v;
		
		// Typing pipe
		if typing
		{
			v = string(keyboard_string);
			
			if (current_time/500) mod 2 
			{v += "|";} else {v += " ";}
			
			draw_set_halign(0);
			draw_set_valign(0);
			DrawTextYCenter(x1+18, v);
		}
		// Display
		else
		{
			v = string_format(value, 0, valueprecision);
			
			draw_set_valign(0);
			if label != ""
			{
				draw_set_halign(0);
				DrawTextYCenter(x1+(18*draw_increments), label + ": ");
				draw_set_halign(2);
				DrawTextYCenter(x2-(18*draw_increments), v);
			}
			else
			{
				draw_set_halign(1);
				DrawText(xc, y1, v);
			}
		}
		
		// Inc / Dec
		if draw_increments
		{
			draw_set_halign(1);
			draw_set_valign(0);
		
			DrawRectWH(x1, y1, 16, h, color[0]);
			DrawTextYCenter(x1+8, "-");
		
			DrawRectWH(x2-16, y1, 16, h, color[2]);
			DrawTextYCenter(x2-8, "+");
		}
	}
}

function LayoutElement_List(_root, _parent) : LayoutElement(_root, _parent) constructor
{
	color = common.c_base;
	toggle_on_click = false;
	valuedefault = value;
	
	items = [];
	itemcount = 0;	// Updated in UpdatePos()
	itemsperpage = 6;
	itemindex = 0;
	itemoffset = 0;
	
	itemsdisplay = [];
	itemsdisplayindex = 0;
	itemsdisplaycount = 0;
	
	itemhighlight = 0;
	scrollhighlight = false;
	scrollactive = false;
	
	extendhighlight = false;
	extendactive = false;
	extendanchor = 0;
	
	static drawitem_default = function(x, y, value, index, textcolor, button)
	{
		draw_set_halign(0);
		draw_set_valign(0);
		
		//DrawText(x + 4, y, "[" + string(index) + "]: " + string(value), _color);
		DrawText(x + 4, y, string(value), textcolor);
	}
	drawitem_function = drawitem_default;
	
	function ValueGetIndex(_value)
	{
		for (var i = 0; i < itemcount; i++)
		{
			if items[i][0] == _value {return i;}
		}
		return -1;
	}
	
	function SetItemDrawFunction(_function)
	{
		drawitem_function = _function;
		return self;
	}
	
	function DefineListItem(_value, _name, _desc)
	{
		array_push(items, [_value, _name, _desc]);
		itemcount = array_length(items);
		itemindex = clamp(itemindex, 0, itemcount-1);
		value = items[itemindex][0];
		return self;
	}
	
	function DefineListItems(_itemlist)
	{
		var n, e;
		n = array_length(_itemlist);
		
		array_resize(items, n);
		itemcount = n;
		
		for (var i = 0; i < n; i++)
		{
			e = _itemlist[i];
			while (array_length(e) < 3) {e[array_length(e)] = undefined;}
			items[i] = e;
		}
		
		itemindex = clamp(itemindex, 0, itemcount-1);
		value = items[itemindex][0];
		
		return self;
	}
	
	function ClearListItems()
	{
		array_resize(items, 0);
		itemcount = 0;
		itemindex = 0;
		itemhighlight = -1;
	}
	
	function UpdatePos(_x1, _y1, _x2, _y2)
	{
		x1 = _x1;
		y1 = _y1;
		x2 = _x2;
		y2 = _y2;
		w = x2-x1;
		
		var n = array_length(items);
		itemcount = n;
		if n <= itemsperpage {itemoffset = 0;}
		
		h = common.cellmax * itemsperpage + common.extendy + b;
		
		if label != "" {h += common.cellmax;}
		
		y2 = y1 + h;
		
		xc = lerp(x1, x2, 0.5);
		yc = lerp(y1, y2, 0.5);
		
		return [w, h];
	}
	
	function Update()
	{
		scrollhighlight = false;
		
		var _y1 = y1+(label!="")*common.cellmax;
		var _showscroll = itemcount > itemsperpage;
		var _displayh = y2-_y1;
		
		// Sync Control
		var ctrl = GetControl();
		if ctrl != value
		{
			itemindex = ValueGetIndex(ctrl);
			if itemindex != -1
			{
				value = ctrl;
				if op {op(value, self);}
			}
		}
		
		ClickUpdate();
		
		if itemcount > 0
		{
			if IsMouseOverXY(x1, _y1, _showscroll? x2-common.scrollx: x2, y2-common.extendy-b)
			&& !scrollactive
			&& !extendactive
			{
				// Lock layout scrolling
				if _showscroll
				{
					common.scrolllock = true;
				}
			
				// Index of item that mouse is over
				itemhighlight = clamp(floor((common.my-_y1) / common.cellmax)+itemoffset, 0, itemcount-1);
				
				// On mouse click
				if clickpress
				{
					itemindex = itemhighlight;
					value = items[itemindex][0];
					if op {op(value, self, items);}
				}
			
				// Mouse Wheel
				var lev = mouse_wheel_down()-mouse_wheel_up();
				if lev != 0
				{
					// Scroll item list
					if !keyboard_check(vk_control)
					{
						if _showscroll
						{
							var _lev = mouse_wheel_down()-mouse_wheel_up();
							if _lev != 0
							{
								itemoffset = clamp(itemoffset+_lev, 0, itemcount-itemsperpage);	
							}
						}
					}
					// Move between items
					else
					{
						itemindex = itemindex+lev;
						itemindex = clamp(itemindex, 0, itemcount-1);
						
						value = items[itemindex][0];
						UpdateControl(value);
						if op {op(value, self);}
						
						// Push itemoffset so that index is in view
						if itemcount > itemsperpage
						{
							if itemindex < itemoffset+1 
								{itemoffset = max(0, itemindex-1);}
							else if itemindex+2 > itemoffset+itemsperpage
								{itemoffset = max(0, min(itemindex-itemsperpage+2, itemcount-itemsperpage));}
						}
					}
				}
				
				// Default Value
				if keyboard_check_pressed(vk_backspace)
				{
					value = valuedefault;
					UpdateControl(value);
					if op {op(value, self);}
				}
			}
			else if _showscroll && !extendactive
			if IsMouseOverXY(x1+common.scrollx, _y1, x2, y2-common.extendy)
			{
				scrollhighlight = true;
				
				if clickpress
				{
					scrollactive = true;
					scrolloffset = (itemoffset/itemcount) * _displayh - (common.my-_y1);
				}
			}
		}
		else
		{
			color = common.c_base;	
			itemhighlight = -1;
		}
		
		// Scrolling via mouse
		if !clickhold {scrollactive = false;}
		if scrollactive
		{
			scrollhighlight = true;
			itemoffset = ( (common.my-_y1)+scrolloffset ) / (_displayh) * itemcount;
			itemoffset = clamp(round(itemoffset), 0, itemcount-itemsperpage);
		}
		
		// Extender
		if IsMouseOverXY(x1, y2-common.extendy-b, x2, y2)
		{
			extendhighlight = true;
			common.cursorsprite = cr_size_ns;
			
			if clickpress
			{
				extendactive = true;
			}
		}
		else
		{
			extendhighlight = false;	
		}
		
		if extendactive
		{
			if clickhold
			{
				extendhighlight = true;
				itemsperpage = floor((common.my-_y1) / common.cellmax);
				itemsperpage = max(itemsperpage, 1);
				common.cursorsprite = cr_size_ns;
				
				// Push itemoffset so that index is in view
				if itemcount > itemsperpage
				{
					if itemindex < itemoffset+1 
						{itemoffset = max(0, itemindex-1);}
					else if itemindex+2 > itemoffset+itemsperpage
						{itemoffset = max(0, min(itemindex-itemsperpage+2, itemcount-itemsperpage));}
					
					itemoffset = max(0, min(itemoffset, itemcount-itemsperpage));
				}	
			}
			else
			{
				extendactive = false;	
			}
		}
		
		label = [itemindex, itemhighlight];
	}
	
	function Draw()
	{
		var _cs = common.cellmax;
		
		var _itemysep = _cs;
		var yy = y1 + _cs*(label != "");
		var _xx1 = x1+1, _xx2 = x2-2;
		var _linex1 = x1+4, _linex2 = x2-4-common.scrollx;
		var _color;
		var _chigh = common.c_highlight;
		var _texty = (_itemysep-common.celltext)/2;
		
		// Draw Items
		var _start = max(itemoffset, 0), _end = min(itemoffset+itemsperpage, itemcount);
		for (var i = _start; i < _end; i++)
		{
			// Active item
			if itemindex == i
			{
				DrawFillXY(_xx1, yy+2, _xx2, yy+_itemysep-2, c_white, 0.5);
			}
			
			// Text Color
			if itemhighlight == i || itemindex == i {_color = c_white;}
			else {_color = c_ltgray;}
			
			// Item Text
			drawitem_default(_xx1, yy+_texty, items[i][1], i, _color, self);
			yy += _itemysep;
			
			// Item Separator
			if i < _end-1
			{
				draw_line_color(_linex1, yy, _linex2, yy, 
					common.c_base, common.c_base);
			}
		}
		
		// Draw Label
		if label != ""
		{
			draw_set_halign(1);
			draw_set_valign(0);
			DrawText(xc, y1, label);
		}
		
		// Draw Scrollbar
		if itemcount > itemsperpage
		{
			DrawScrollBar(
				y1 + _cs*(label != ""), 
				y2-4, 
				itemoffset/(itemcount-itemsperpage),
				itemsperpage/itemcount
				);
		}
		
		// Draw Extender
		var _col = extendactive? c_white: (extendhighlight? common.c_active: common.c_highlight);
		DrawFillXY(
			lerp(x1, x2, 0.4), y2-common.extendy+1-b,
			lerp(x1, x2, 0.6), y2-1-b,
			_col, 1
			);
	}
}

function LayoutElement_Enum(_root, _parent) : LayoutElement(_root, _parent) constructor
{
	color = common.c_base;
	valuedefault = value;
	
	items = [];	// <value, name, description>
	itemcount = 0;
	itemindex = 0;
	itemhighlight = 0;
	
	function Value(_value, runop=true)
	{
		for (var i = 0; i < itemcount; i++)
		{
			if value == items[i][0]
			{
				itemindex = i;
				value = items[itemindex][0];
				if runop && op {op(value, self);}
				return self;
			}
		}
		
		show_debug_message("ERROR: No enum entry with value \""+string(value)+"\" exists!");
		itemindex = clamp(itemindex, 0, itemcount-1);
		value = items[itemindex][0];
		return self;
	}
	
	function DefineListItem(_value, _name, _desc)
	{
		array_push(items, [_value, _name, _desc]);
		itemcount = array_length(items);
		itemindex = clamp(itemindex, 0, itemcount-1);
		value = items[itemindex][0];
		return self;
	}
	
	function DefineListItems(_enumlist)
	{
		var n, e;
		n = array_length(_enumlist);
		
		array_resize(items, n);
		itemcount = n;
		
		for (var i = 0; i < n; i++)
		{
			e = _enumlist[i];
			while (array_length(e) < 3) {e[array_length(e)] = undefined;}
			items[i] = e;
		}
		
		itemindex = clamp(itemindex, 0, itemcount-1);
		value = items[itemindex][0];
		
		return self;
	}
	
	function UpdatePos(_x1, _y1, _x2, _y2)
	{
		x1 = _x1;
		y1 = _y1;
		x2 = _x2;
		y2 = y1 + common.cellmax;
		
		if active
		{
			y2 += common.cellmax * itemcount;	
		}
		
		w = x2-x1;
		h = y2-y1;
		
		xc = lerp(x1, x2, 0.5);
		yc = lerp(y1, y2, 0.5);
		
		return [w, h];
	}
	
	function Update()
	{
		// Sync Control
		var ctrl = GetControl();
		if ctrl != value
		{
			for (var i = 0; i < itemcount; i++)
			{
				if items[i][0] == ctrl
				{
					value = items[i][0];
					itemindex = i;
					break;
				}
			}
		}
		
		ClickUpdate();
		
		// Mouse Controls
		if IsMouseOver()
		{
			common.active = self;
			color = common.c_highlight;
			
			if !active
			{
				if clickrelease
				{
					// Open dropdown
					active = true;
				}
				
				// Mouse Wheel
				if keyboard_check(vk_control)
				{
					common.scrolllock = true;
					
					var lev = mouse_wheel_down()-mouse_wheel_up();
					if lev != 0
					{
						itemindex = itemindex+lev;
						if (itemindex < 0) {itemindex = itemcount + itemindex;}
						itemindex = clamp(itemindex, 0, itemcount-1);
					
						value = items[itemindex][0];
						UpdateControl(value);
						if op {op(value, self);}
					}
				}
				
				UpdateTooltip();
			}
			else
			{
				if IsMouseOverXY(x1, y1+common.cellmax, x2, y2)
				{
					itemhighlight = clamp(floor((common.my-y1-common.cellmax)/common.cellmax), 0, itemcount-1);
					
					UpdateTooltip(label, items[itemhighlight][2]);
					
					if clickrelease
					{
						itemindex = itemhighlight;
						value = items[itemindex][0];
						UpdateControl(value);
						if op {op(value, self);}
						active = false;
					}
				}
				else
				{
					UpdateTooltip();	
				}
			}
		}
		else
		{
			color = common.c_base;
			active = false;
		}
		
	}
	
	function Draw()
	{
		draw_set_halign(0);
		draw_set_valign(0);
		
		// Draw enum elements
		if active
		{
			var e;
			var hh = common.cellmax;
			var yy = y1+hh;
			
			var _chigh = common.c_highlight;
			
			DrawRectWH(x1, y1, w, h, 0);
			for (var i = 0; i < itemcount; i++)
			{
				// Active item
				if itemindex == i
				{
					DrawFillXY(x1+1, yy+1, x2-2, yy+common.cellmax, c_white, 0.5);
				}
				
				e = items[i];
				DrawText(x1+5, yy, e[1], (itemhighlight==i)? c_white: c_ltgray);
				yy += hh;
			}
		}
		
		DrawRectWH(x1, y1, w, common.cellmax, color);
		
		// Draw Label
		if label != ""
		{
			DrawText(x1+3, y1, string(label)+":");
			draw_set_halign(2);
			DrawText(x2-3, y1, items[itemindex][1]);
		}
		else
		{
			DrawText(x1+3, y1, items[itemindex][1]);
		}
	}
}

function LayoutElement_Dropdown(_root, _parent) : LayoutElement(_root, _parent) constructor
{
	b = 4;
	color = common.c_base;
	usesscroll = true;
	surf = -1;
	surfyoffset = 0;
	surfyoffset_target = 0;
	contentheight = 0;
	surfheight = 160;
	scrollhighlight = false;
	
	function UpdatePos(_x1, _y1, _x2, _y2)
	{
		var hsep = common.cellmax;
		
		x1 = _x1;
		y1 = _y1;
		x2 = _x2;
		y2 = y1;
		w = x2-x1;
		
		if active
		{
			var yy = -surfyoffset+b;
			var _xx2 = w-b;
			var _yy2 = h-b;
			
			// Scrollbar offset
			if contentheight > h {_xx2 -= common.scrollx;}
			contentheight = b;
			
			var offset;
			for (var i = 0; i < childrencount; i++)
			{
				offset = children[i].UpdatePos(b, yy, _xx2, _yy2);	
				yy += offset[1]+1;
				contentheight += offset[1]+1;
			}
			
			surfheight = contentheight+b;
			h = surfheight+hsep;
		}
		else
		{
			h = hsep;	
		}
		
		// Smooth scroll into position
		if surfyoffset_target != surfyoffset
		{
			surfyoffset += (surfyoffset_target-surfyoffset)/(delta_time/3000);
			if abs(surfyoffset_target-surfyoffset) < 0.2
			{
				surfyoffset = surfyoffset_target;
			}
		}
		
		y2 = y1+h;
		
		xc = lerp(x1, x2, 0.5);
		yc = lerp(y1, y2, 0.5);
		
		return [w, h];
	}
	
	function Update()
	{
		ClickUpdate();
		
		var _cs = common.cellmax;
		
		color = common.c_base;
		scrollhighlight = false;
		
		// Toggle Expand
		if IsMouseOverExt(x1, y1, w, active? _cs: h)
		{
			color = common.c_highlight;
			if clickhold
				{color = common.c_active;}
			if clickrelease
				{active ^= 1;}
		}
		
		// Update Children
		if active
		{
			var _oldmy = common.my;
			common.my -= y1+_cs;
			
			if IsMouseOverExt(0, 0, w, h-_cs)
			{
				// Scroll
				var _spd = 16;
				var _lev = mouse_wheel_down()-mouse_wheel_up();
				if _lev != 0
				{
					surfyoffset_target += _spd*_lev;
				}
				
				// Clamp Scroll Offset
				surfyoffset_target = max(0, min(surfyoffset_target, contentheight-h+_cs+b));
				common.scrolllock = true;
				
				if common.mx > x2 - common.scrollx
				{
					scrollhighlight = true;	
				}
				else
				{
					scrollhighlight = false;	
				}
			}
			
			var i = 0; repeat(childrencount)
			{
				children[i].Update();
				i++;
			}
			common.my = _oldmy;
		}
	}
	
	function Draw()
	{
		DrawRectWH(x1, y1, w, h, color);
		
		if label != ""
		{
			draw_set_halign(0);
			draw_set_valign(0);
			DrawText(x1+4, y1, label);
		}
		
		draw_set_halign(2);
		draw_set_valign(0);
		DrawText(x2-4, y1, active? "-": "+");
		
		if active
		{
			// Update surface
			var _w = 1 << ceil(log2(w)); // Use highest power of 2
			var _h = 1 << ceil(log2(contentheight));
		
			if !surface_exists(surf)
			{
				surf = surface_create(_w, _h);
			}
			else if surface_get_width(surf) < _w || surface_get_height(surf) < _h
			{
				surface_resize(surf, _w, _h);	
			}
		
			// Surface Start ----------------------------------------------------
			surface_set_target(surf);
		
			draw_clear_alpha(0, 0);
			
			// Draw Children
			for (var i = 0; i < childrencount; i++)
			{
				children[i].Draw();	
			}
		
			surface_reset_target(); // It pops the active surface, DOESN'T return to application surface
			// Surface End -----------------------------------------------------
			
			draw_surface_part(surf, 0, 0, w, surfheight-b, x1, y1+common.cellmax);
			
			// Draw Scrollbar
			if contentheight > h
			{
				DrawScrollBar(
					y1+common.cellmax, 
					y2-4, 
					-surfyoffset/(h-contentheight-common.cellmax),
					h/contentheight
					);
			}
		}
	}
}
