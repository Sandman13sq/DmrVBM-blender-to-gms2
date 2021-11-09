/// @desc

function LayoutElement_Text(_root, _parent) : LayoutElement(_root, _parent) constructor
{
	function UpdatePos(_x1, _y1, _x2, _y2)
	{
		x1 = _x1;
		y1 = _y1;
		x2 = _x2;
		y2 = y1 + common.celltext;
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
			draw_set_halign(1);
			draw_set_valign(0);
			DrawTextYCenter(xc, label);
		}
	}
}

function LayoutElement_Button(_root, _parent) : LayoutElement(_root, _parent) constructor
{
	color = common.c_base;
	toggle_on_click = false;
	
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
		
		if IsMouseOver()
		{
			common.active = self;
			
			color = common.c_highlight;	
			
			// When mouse is held
			if common.clickheld
				{color = common.c_active;}
			
			// When mouse is released
			if common.clickreleased
			{
				if toggle_on_click
				{
					value ^= 1;
				}
				UpdateControl(value);
				
				if op {op(value, self);}
			}
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
		
		if IsMouseOver()
		{
			common.active = self;
			
			color = common.c_highlight;	
			
			if common.clickheld
			{
				color = common.c_active;
			}
			
			if common.clickreleased
			{
				value ^= 1; // Toggle boolean
				UpdateControl(value);
				if op {op(value, self);}
			}
			
			ismouseover = true;
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
			var c = color;
			draw_rectangle_color(x1+2, y1+2, x2-2, y2-2, c, c, c, c, 0);	
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
	valuestep = 1;
	valuemin = -infinity;
	valuemax = infinity;
	valueanchor = 0;
	valuedec = 2;
	mouseanchor = [0, 0];
	typing = 0;
	
	operator_on_change = false;
	draw_increments = true;
	
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
		
		var mbheld = common.clickheld;
		var mbpressed = common.clickpressed;
		var mbreleased = common.clickreleased;
		
		if IsMouseOver() && !active
		{
			// Lock layout scrolling
			var xx = [x1, x1+16, x2-16, x2];
			if !draw_increments {xx[1] = x1; xx[2] = x2;}
			
			// Decrement
			if draw_increments && IsMouseOver2(xx[0], y1, xx[1], y2)
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
			else if draw_increments && IsMouseOver2(xx[2], y1, xx[3], y2)
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
			else if IsMouseOver2(xx[1], y1, xx[2], y2)
			{
				common.scrolllock = true;
				color[1] = common.c_highlight;
				
				if common.doubleclick
				|| (mbreleased && common.lastpress <= 10)
				{
					typing = 1;
					valueanchor = string(value);
				}
				
				if !typing
				{
					if mbpressed
					{
						valueanchor = value;
						scroll = 0;
						active = 1;
					
						mouseanchor[0] = window_mouse_get_x();
						mouseanchor[1] = window_mouse_get_y();
						window_mouse_set(window_get_width()/2, window_get_height()/2);
					}
					
					if mbreleased
					{
						if op {op(value, self);}
						window_set_cursor(cr_arrow);
					}
					
					var lev = mouse_wheel_up()-mouse_wheel_down();
					if lev != 0
					{
						value = clamp(value+lev*valuestep, valuemin, valuemax);
						UpdateControl(value);
							
						if operator_on_change
						{
							if op {op(value, self);}
						}
					}
				}
			}
		}
		else
		{
			if typing
			{
				if keyboard_check_pressed(vk_escape)
				{
					typing = 0;
					valueanchor = value;
				}
				else if keyboard_check_pressed(vk_enter)
				{
					typing = 0;
					if string_digits(valueanchor) != ""
					{
						value = real(valueanchor);
						UpdateControl(value);
						if op {op(value, self);}
					}
				}
				else if keyboard_check_pressed(vk_backspace)
				{
					valueanchor = string_copy(valueanchor, 1, string_length(valueanchor)-1);
				}
				else if keyboard_check_pressed(vk_anykey)
				{
					var c = keyboard_lastchar;
					if keyboard_lastkey >= 0x20
					{
						valueanchor += c;
					}
				}
				
				if common.clickpressed
				{
					typing = 0;	
					valueanchor = value;
					active = 0;
				}	
			}
		}
		
		if active
		{
			if mouse_check_button(mb_left)
			{
				window_set_cursor(cr_none);
				color[1] = common.c_active;
				common.active = self;
				
				var d = window_mouse_get_x()-window_get_width()/2;
				window_mouse_set(window_get_width()/2, window_get_height()/2);
				
				if abs(d) >= ((valuestep >= 1)? 2: 1)
				{
					var sh = keyboard_check(vk_shift)? 0.1: 1;
					
					scroll += sign(d)*valuestep*sh;
					valueanchor += sign(d)*valuestep*sh;
					value = clamp(valueanchor, valuemin, valuemax);
					UpdateControl(value);
							
					if operator_on_change
					{
						if op {op(value, self);}
					}
				}
			}
			else
			{
				active = 0;
				window_mouse_set(mouseanchor[0], mouseanchor[1]);
				window_set_cursor(cr_arrow);
				
				if operator_on_change
				{
					if op {op(value, self);}
				}
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
			v = string(valueanchor);
			
			if (current_time/500) mod 2 
			{v += "|";} else {v += " ";}
			
			draw_set_halign(0);
			draw_set_valign(0);
			DrawTextYCenter(x1+18, v);
		}
		// Display
		else
		{
			v = string_format(value, 0, valuedec);
			
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
	
	items = [];
	itemcount = 0;	// Updated in UpdatePos()
	itemsperpage = 6;
	itemindex = 0;
	offset = 0;
	
	itemhighlight = 0;
	
	static drawitem_default = function(x, y, value, index, textcolor, button)
	{
		draw_set_halign(0);
		draw_set_valign(0);
		
		//DrawText(x + 4, y, "[" + string(index) + "]: " + string(value), _color);
		DrawText(x + 4, y, string(value), textcolor);
	}
	drawitem_function = drawitem_default;
	
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
		//itemsperpage = h div common.cellmax;
		itemcount = n;
		if n <= itemsperpage {offset = 0;}
		
		h = common.cellmax * itemsperpage;
		
		if label != "" {h += common.cellmax;}
		
		y2 = y1 + h;
		
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
		
		if IsMouseOver() && itemcount > 0
		{
			// Lock layout scrolling
			if itemcount > itemsperpage
			{
				common.scrolllock = true;
			}
			
			// Index of item that mouse is over
			itemhighlight = clamp(floor((common.my-y1-common.cellmax*(label != "")) / common.cellmax)+offset, 0, itemcount-1);
			
			// On mouse click
			if common.clickreleased
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
					if itemcount > itemsperpage
					{
						var _lev = mouse_wheel_down()-mouse_wheel_up();
						if _lev != 0
						{
							offset = clamp(offset+_lev, 0, itemcount-itemsperpage);	
						}
					}
				}
				// Move between items
				else
				{
					itemindex = itemindex+lev;
					if (itemindex < 0) {itemindex = itemcount + itemindex;}
					itemindex = itemindex mod itemcount;
					
					value = items[itemindex][0];
					UpdateControl(value);
					if op {op(value, self);}
					
					// Push offset so that index is in view
					if itemcount > itemsperpage
					{
						if itemindex < offset+1 
							{offset = max(0, itemindex-1);}
						if itemindex+2 > offset+itemsperpage
							{offset = clamp(itemindex-itemsperpage+2, 0, itemcount-itemsperpage);}
					}
				}
			}
		}
		else
		{
			color = common.c_base;	
			itemhighlight = -1;
		}
	}
	
	function Draw()
	{
		var _cs = common.cellmax;
		
		var _itemysep = _cs;
		var yy = y1 + _cs*(label != "");
		var _xx1 = x1+1, _xx2 = x2-2;
		var _linex1 = x1+4, _linex2 = x2-4-common.scrollx;
		var _recty1 = y1+4, _recty2 = y1+_cs-2;
		var _color;
		var _chigh = common.c_highlight;
		var _texty = (_itemysep-common.celltext)/2;
		
		// Draw Items
		var _start = offset, _end = min(offset+itemsperpage, itemcount);
		for (var i = _start; i < _end; i++)
		{
			// Active item
			if itemindex == i
			{
				draw_rectangle_color(_xx1, yy+2, _xx2, yy+_itemysep-2,
					_chigh, _chigh, _chigh, _chigh, 0);
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
				draw_line_color(_linex1, yy, _linex2, yy, c_white, c_white);
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
				offset/(itemcount-itemsperpage),
				itemsperpage/itemcount
				);
		}
	}
}

function LayoutElement_Enum(_root, _parent) : LayoutElement(_root, _parent) constructor
{
	color = common.c_base;
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
		
		if IsMouseOver()
		{
			// Lock layout scrolling
			common.scrolllock = true;
			
			common.active = self;
			color = common.c_highlight;	
			
			if !active
			{
				if common.clickreleased
				{
					// Open dropdown
					active = 1;
				}
				
				// Mouse Wheel
				var lev = mouse_wheel_down()-mouse_wheel_up();
				if lev != 0
				{
					itemindex = itemindex+lev;
					if (itemindex < 0) {itemindex = itemcount + itemindex;}
					itemindex = itemindex mod itemcount;
					
					value = items[itemindex][0];
					UpdateControl(value);
					if op {op(value, self);}
				}
				
				common.tooltip_name = label;
				common.tooltip_text = description;
				common.tooltip_target = self;
			}
			else
			{
				if IsMouseOver2(x1, y1+common.cellmax, x2, y2)
				{
					itemhighlight = clamp(floor((common.my-y1-common.cellmax)/common.cellmax), 0, itemcount-1);
					
					common.tooltip_name = label;
					common.tooltip_text = items[itemhighlight][2];
					common.tooltip_target = self;
					
					if common.clickreleased
					{
						itemindex = itemhighlight;
						value = items[itemindex][0];
						UpdateControl(value);
						if op {op(value, self);}
						active = 0;
					}
				}
			}
		}
		else
		{
			color = common.c_base;
			active = 0;
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
					draw_rectangle_color(x1+1, yy+1, x2-2, yy+common.cellmax,
						_chigh, _chigh, _chigh, _chigh, 0);
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
