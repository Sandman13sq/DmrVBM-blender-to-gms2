/// @desc

function __LayoutSuper() constructor
{
	static elcount = 0;
	elindex = elcount++;
	children = [];
	childrencount = 0;
	
	x1 = 0;
	y1 = 0;
	x2 = 0;
	y2 = 0;
	xc = 0;
	yc = 0;
	w = 0;
	h = 0;
	b = 2;
	
	label = "";
	idname = "";
	
	#region // Elements =======================================================
	
	function ReplaceElement(idname, el_function)
	{
		for (var i = 0; i < childrencount; i++)
		{
			if children[i].idname == idname
			{
				children[i].Clean();
				delete children[i];
				children[i] = new el_type();
			}
		}
	}
	
	function Row()
	{
		var el = new LayoutElement_Row(root, self);
		array_push(children, el);
		childrencount++;
		return el;	
	}
	
	function Column()
	{
		var el = new LayoutElement_Column(root, self);
		array_push(children, el);
		childrencount++;
		return el;	
	}
	
	function Box()
	{
		var el = new LayoutElement_Box(root, self);
		array_push(children, el);
		childrencount++;
		return el;	
	}
	
	function Dropdown()
	{
		var el = new LayoutElement_Dropdown(root, self);
		array_push(children, el);
		childrencount++;
		return el;	
	}
	
	function Button()
	{
		var el = new LayoutElement_Button(root, self);
		array_push(children, el);
		childrencount++;
		return el;		
	}
	
	function Bool()
	{
		var el = new LayoutElement_Bool(root, self);
		array_push(children, el);
		childrencount++;
		return el;		
	}
	
	function Real()
	{
		var el = new LayoutElement_Real(root, self);
		array_push(children, el);
		childrencount++;
		return el;		
	}
	
	function List()
	{
		var el = new LayoutElement_List(root, self);
		array_push(children, el);
		childrencount++;
		return el;		
	}
	
	#endregion -----------------------------------------------------
	
	#region // Utility ======================================================
	
	function Label(_label)
	{
		label = string(_label);	
		return self;
	}
	
	function Operator(_op)
	{
		op = _op;
		return self;
	}
	
	function Value(_value, runop=true)
	{
		value = _value;
		if runop
		{
			if op {op(self);}
		}
		return self;
	}
	
	function Toggle(runop=true)
	{
		Value(!value, runop);
	}
	
	function IsMouseOver()
	{
		return point_in_rectangle(common.mx, common.my, x1, y1, x2, y2);
	}
	
	function IsMouseOver2(_x1, _y1, _x2, _y2)
	{
		return point_in_rectangle(common.mx, common.my, _x1, _y1, _x2, _y2);
	}
	
	function IsMouseOverExt(x, y, w, h)
	{
		return point_in_rectangle(common.mx, common.my, x, y, x+w, y+h);
	}
	
	#endregion
	
	#region Drawing ----------------------------------------------
	
	function SetTextScale(_scale)
	{
		common.textscale = _scale;
		return self;
	}
	
	function SetUIScale(_scale)
	{
		common.uiscale = _scale;
		return self;
	}
	
	function SetIDName(_idname)
	{
		idname = _idname;
		root.elementmap[$ _idname] = self;
		return self;
	}
	
	function DrawRectWH(x, y, w, h, color, alpha=1)
	{
		draw_sprite_stretched_ext(spr_layoutbox, 0, x, y, w, h, c_white, alpha);
		draw_sprite_stretched_ext(spr_layoutbox, 1, x, y, w, h, color, alpha);
	}
	
	function DrawText(x, y, text, color = c_white)
	{
		draw_text_ext_transformed_color(
			x, y, text, 16, 3000, 
			common.textscale, common.textscale, 
			0, color, color, color, color, 1);	
	}
	
	function DrawTextYCenter(x, text, color = c_white)
	{
		var yy = yc - common.textheightdiv2;
		draw_text_ext_transformed_color(
			x, yy, text, 16, 3000, 
			common.textscale, common.textscale, 
			0, color, color, color, color, 1);	
	}
	
	#endregion
	
	function Clear()
	{
		for (var i = 0; i < childrencount; i++)
		{
			children[i].Clear();
			delete children[i];
		}
	}
	
	function toString()
	{
		return string([x1, y1, x2, y2]);
	}
}

function Layout() : __LayoutSuper() constructor
{
	root = self;
	parent = 0;
	children = [];
	childrencount = 0;
	
	op = 0;
	active = 0;
	highlight = 0;
	b = 4;
	
	common = {
		c_base : 0x342022,
		c_highlight : 0x743f3f,
		c_active : 0x846c66,
		
		textscale : 1,
		uiscale : 1,
		
		celltext : 1,
		cellui : 1,
		cellmax : 1, // Max of textscale and uiscale
		
		buttonheight : 16,
		textheight : 16,
		textheightdiv2 : 8,
		active : 0,
		
		lastpress : 255,
		mouseonpress_x : 0,
		mouseonpress_y : 0,
		doubleclick : 0,
		doubleclicktime : 20,
		clickpressed : 0,
		clickheld : 0,
		clickreleased : 0,
		
		mx : 0,
		my : 0,
	};
	
	elementmap = {};
	
	// Setup ======================================
	
	var _fnt = draw_get_font();
	draw_set_font(0);
	common.textheight = string_height("M");
	draw_set_font(_fnt);
	
	function SetPosXY(_x1, _y1, _x2, _y2)
	{
		x1 = _x1;
		y1 = _y1;
		x2 = _x2;
		y2 = _y2;
		w = x2-x1;
		h = y2-y1;
		return self;	
	}
	
	function SetButtonHeight(_height)
	{
		common.buttonheight = _height;
		return self;
	}
	
	function Update()
	{
		// Common
		common.active = 0;
		common.doubleclick = 0;
		common.mx = window_mouse_get_x();
		common.my = window_mouse_get_y();
		
		if common.lastpress < 255
		{
			common.lastpress++;	
		}
		
		if mouse_check_button_pressed(mb_left)
		{
			if common.lastpress < common.doubleclicktime
			&& point_distance(common.mx, common.my, mouseonpress_x, mouseonpress_y) <= 4
			{
				common.doubleclick = 1;
			}
			
			mouseonpress_x = common.mx;
			mouseonpress_y = common.my;
			
			common.lastpress = 0;
		}
		
		common.celltext = common.textscale*common.textheight;
		common.cellui = common.uiscale*common.buttonheight;
		common.cellmax = max(common.celltext, common.cellui);
		common.textheightdiv2 = common.textheight*0.5*common.textscale;
		
		// Elements
		var yy = y1;
		if label != "" {yy += common.celltext;}
		
		y2 = yy;
		
		var offset;
		for (var i = 0; i < childrencount; i++)
		{
			offset = children[i].UpdatePos(x1+b, yy+b, x2-b, y2-b);	
			yy += offset[1]+1;
			y2 += offset[1]+1;
		}
		
		h = y2-y1+b*2;
		
		var lastheld = common.clickheld;
		if point_in_rectangle(common.mx, common.my, x1, y1, x2, y2)
		{
			common.clickheld = mouse_check_button(mb_left);
			common.clickpressed = ~lastheld & common.clickheld;
		}
		else
		{
			common.clickheld = 0;
			common.clickpressed = 0;
		}
		common.clickreleased = lastheld & ~common.clickheld;
		
		for (var i = 0; i < childrencount; i++)
		{
			children[i].Update();	
		}
	}
	
	function Draw()
	{
		DrawRectWH(x1, y1, w, h, 0);
		for (var i = 0; i < childrencount; i++)
		{
			children[i].Draw();	
		}
		
		if label != ""
		{
			draw_set_halign(0);
			draw_set_valign(0);
			DrawText(x1+2, y1, label);	
		}
		
		//DrawText(200, 200, common.lastpress);
	}
	
	function FindElement(_idname)
	{
		return variable_struct_get(root.elementmap, _idname);
	}
}

#region // Panels ===========================================================

function LayoutElement(_root, _parent) : __LayoutSuper() constructor
{
	root = _root;
	parent = _parent;
	children = [];
	childrencount = 0;
	common = root.common;
	
	op = 0; // Function to call
	active = 0;
	
	x1 = 0; // Following are unit values [0.0-1.0]
	y1 = 0;
	x2 = 0;
	y2 = 0;
	w = 0;
	h = 0;
	b = 4; // Border
	label = "";
	value = 0;
	
	// Called right before update
	function UpdatePos()
	{
		var offset;
		for (var i = 0; i < childrencount; i++)
		{
			offset = children[i].UpdatePos(x1, y1, x2, 2000);
		}
		
		x1 = _x1;
		y1 = _y1;
		x2 = _x2;
		y2 = _y2;
		w = x2-x1;
		h = y2-y1;
		
		return [w, h];
	}
	
	function Update()
	{
		for (var i = 0; i < childrencount; i++)
		{
			children[i].Update();	
		}
	}
	
	function Draw()
	{
		for (var i = 0; i < childrencount; i++)
		{
			children[i].Draw();	
		}
	}
	
}

function LayoutElement_Column(_root, _parent) : LayoutElement(_root, _parent) constructor
{
	b = 4;
	function UpdatePos(_x1, _y1, _x2, _y2)
	{
		var hsep = common.buttonheight;
		
		x1 = _x1;
		y1 = _y1;
		x2 = _x2;
		y2 = y1;
		w = x2-x1;
		h = 0;
		
		var offset;
		var yy = y1;
		
		if label != ""
		{
			yy += common.celltext;
			h += common.celltext;
		}
		
		for (var i = 0; i < childrencount; i++)
		{
			offset = children[i].UpdatePos(x1, yy, x2, yy+hsep);
			yy += offset[1]+1;
			y2 += offset[1]+1;
			h += offset[1]+1;
		}
		
		xc = lerp(x1, x2, 0.5);
		yc = lerp(y1, y2, 0.5);
		
		return [w, h];
	}
	
	function Draw()
	{
		if label != ""
		{
			draw_set_halign(1);
			draw_set_valign(0);
			DrawText(xc, y1 + 4, label);
		}
		
		for (var i = 0; i < childrencount; i++)
		{
			children[i].Draw();	
		}
	}
}

function LayoutElement_Box(_root, _parent) : LayoutElement(_root, _parent) constructor
{
	b = 4;
	function UpdatePos(_x1, _y1, _x2, _y2)
	{
		var hsep = common.cellmax;
		
		x1 = _x1;
		y1 = _y1;
		x2 = _x2;
		y2 = y1;
		w = x2-x1;
		h = b*2;
		
		var offset;
		var yy = y1+b;
		
		if label != ""
		{
			yy += common.celltext;
			h += common.celltext;
		}
		
		for (var i = 0; i < childrencount; i++)
		{
			offset = children[i].UpdatePos(x1+b, yy, x2-b, yy+hsep);
			yy += offset[1]+1;
			y2 += offset[1]+1;
			h += offset[1]+1;
		}
		
		xc = lerp(x1, x2, 0.5);
		yc = lerp(y1, y2, 0.5);
		
		return [w, h];
	}
	
	function Draw()
	{
		DrawRectWH(x1, y1, w, h, c_black, 1);
		
		if label != ""
		{
			draw_set_halign(1);
			draw_set_valign(0);
			DrawText(xc, y1, label);
		}
		
		for (var i = 0; i < childrencount; i++)
		{
			children[i].Draw();	
		}
	}
}

function LayoutElement_Row(_root, _parent) : LayoutElement(_root, _parent) constructor
{
	b = 4;
	function UpdatePos(_x1, _y1, _x2, _y2)
	{
		var hsep = common.cellmax;
		
		x1 = _x1;
		y1 = _y1;
		x2 = _x2;
		y2 = y1;
		w = x2-x1;
		h = 0;
		
		if childrencount > 0
		{
			var wb = 1;
			var ww = (w-wb*(childrencount-1)) / childrencount;
			
			var offset;
			var xx = x1;
			var yy = y1;
			h += hsep;
			
			for (var i = 0; i < childrencount; i++)
			{
				offset = children[i].UpdatePos(xx, yy, xx+ww, yy+hsep);
				xx += ww+wb;
				h = max(h, offset[1]);
			}
		}
		
		xc = lerp(x1, x2, 0.5);
		yc = lerp(y1, y2, 0.5);
		
		return [w, h];
	}
}

function LayoutElement_Dropdown(_root, _parent) : LayoutElement(_root, _parent) constructor
{
	b = 4;
	
	function UpdatePos(_x1, _y1, _x2, _y2)
	{
		var hsep = common.cellmax;
		x1 = _x1;
		y1 = _y1;
		x2 = _x2;
		y2 = y1;
		w = x2-x1;
		h = common.cellmax;
		
		if active
		{
			var offset;
			var yy = common.cellmax+y1+b;
			for (var i = 0; i < childrencount; i++)
			{
				offset = children[i].UpdatePos(x1+b, yy, x2-b, yy+hsep);
				yy += offset[1]+1;
				y2 += offset[1]+1;
				h += offset[1]+1;
			}
			
			h += b*2;
		}
		
		xc = lerp(x1, x2, 0.5);
		yc = lerp(y1, y2, 0.5);
		
		return [w, h];
	}
	
	function Update()
	{
		color = common.c_base;
		
		if IsMouseOverExt(x1, y1, w, active? common.cellmax: h)
		{
			color = common.c_highlight;
			if common.clickheld
				{color = common.c_active;}
			if common.clickreleased
				{active ^= 1;}
		}
		
		if active
		{
			var i = 0; repeat(childrencount)
			{
				children[i].Update();
				i++;
			}
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
			var i = 0; repeat(childrencount)
			{
				children[i].Draw();
				i++;
			}
		}
	}
}

#endregion

#region // Interactables ===========================================================

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
		if IsMouseOver()
		{
			common.active = self;
			
			color = common.c_highlight;	
			
			if common.clickheld
				{color = common.c_active;}
			
			if common.clickreleased
			{
				if toggle_on_click
				{
					value ^= 1;
				}
				if op {op(self);}
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
	
	function Value(_value, runop=true)
	{
		value = bool(_value);
		if runop && op {op(self);}
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
				value ^= 1;
				if op {op(self);}
			}
		}
		else
		{
			color = common.c_base;	
		}
	}
	
	function Draw()
	{
		var _cm = common.cellmax;
		DrawRectWH(x1, y1, _cm, _cm, color);
		
		if value
		{
			var _s = 4, _ss = _s*2;
			DrawRectWH(x1+_s, y1+_s, _cm-_ss, _cm-_ss, c_white);
		}
		
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
	
	operator_on_change = 0;
	
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
		
		var mbheld = common.clickheld;
		var mbpressed = common.clickpressed;
		var mbreleased = common.clickreleased;
		
		if IsMouseOver() && !active
		{
			var xx = [x1, x1+16, x2-16, x2];
			
			// Decrement
			if IsMouseOver2(xx[0], y1, xx[1], y2)
			{
				color[0] = common.c_highlight;
				if mbheld {color[0] = common.c_active;}
				if mbreleased
				{
					value = max(valuemin, value-1);
					if op {op(self);}
				}
			}
			// Increment
			else if IsMouseOver2(xx[2], y1, xx[3], y2)
			{
				color[2] = common.c_highlight;
				if mbheld {color[2] = common.c_active;}
				if mbreleased 
				{
					value = min(valuemax, value+1);
					if op {op(self);}
				}
			}
			// Middle
			else if IsMouseOver2(xx[1], y1, xx[2], y2)
			{
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
						if op {op(self);}
						window_set_cursor(cr_arrow);
					}
					
					var lev = mouse_wheel_up()-mouse_wheel_down();
					if lev != 0
					{
						value = clamp(value+lev*valuestep, valuemin, valuemax);
							
						if operator_on_change
						{
							if op {op(self);}
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
						if op {op(self);}
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
							
					if operator_on_change
					{
						if op {op(self);}
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
					if op {op(self);}
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
				DrawTextYCenter(x1+18, label + ": ");
				draw_set_halign(2);
				DrawTextYCenter(x2-18, v);
			}
			else
			{
				draw_set_halign(1);
				DrawText(xc, y1, v);
			}
		}
		
		// Inc / Dec
		draw_set_halign(1);
		draw_set_valign(0);
		
		DrawRectWH(x1, y1, 16, h, color[0]);
		DrawTextYCenter(x1+8, "-");
		
		DrawRectWH(x2-16, y1, 16, h, color[2]);
		DrawTextYCenter(x2-8, "+");
	}
}

function LayoutElement_List(_root, _parent) : LayoutElement(_root, _parent) constructor
{
	color = common.c_base;
	toggle_on_click = false;
	
	list = [0, 1, 2, 3, 4, 5];
	size = 0;
	itemsperpage = 6;
	indexover = -1;
	offset = 0;
	
	static drawitem_default = function(button, x, y, value, index)
	{
		draw_set_halign(0);
		draw_set_valign(0);
		DrawText(x + 4, y, "Item[" + string(index) + "]: " + string(value),
			
			);
	}
	drawitem_function = drawitem_default;
	
	function UpdatePos(_x1, _y1, _x2, _y2)
	{
		x1 = _x1;
		y1 = _y1;
		x2 = _x2;
		y2 = _y2;
		w = x2-x1;
		
		var n = array_length(list);
		//itemsperpage = h div common.cellmax;
		if n <= itemsperpage {offset = 0;}
		
		h = common.cellmax * itemsperpage;
		y2 = y1 + h;
		
		xc = lerp(x1, x2, 0.5);
		yc = lerp(y1, y2, 0.5);
		
		return [w, h];
	}
	
	function Update()
	{
		if IsMouseOver()
		{
			
			
			color = common.c_highlight;	
			
			if common.clickheld
				{color = common.c_active;}
			
			if common.clickreleased
			{
				if op {op(self, index, list);}
			}
		}
		else
		{
			color = common.c_base;	
			indexover = -1;
		}
	}
	
	function Draw()
	{
		DrawRectWH(x1, y1, w, h, color);
		
		var n = array_length(list);
		var yy = y1;
		var xx1 = x1 + 4, xx2 = x2 - 4;
		for (var i = 0; i < n; i++)
		{
			drawitem_default(self, x1, yy, list[i], i);
			yy += common.cellmax;
			
			if i < n-1
			{
				draw_line_color(xx1, yy, xx2, yy, c_white, c_white);
			}
		}
		
		if label != ""
		{
			draw_set_halign(1);
			draw_set_valign(0);
			DrawTextYCenter(xc, label);
		}
	}
}


#endregion

