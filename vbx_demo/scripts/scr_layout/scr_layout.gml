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
	description = "";
	idname = "";
	interactable = true;
	
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
	
	function Text(_label="")
	{
		var el = new LayoutElement_Text(root, self);
		el.Label(_label);
		
		array_push(children, el);
		childrencount++;
		
		return el;	
	}
	
	function Row(_label="")
	{
		var el = new LayoutElement_Row(root, self);
		el.Label(_label);
		
		array_push(children, el);
		childrencount++;
		return el;	
	}
	
	function Column(_label="")
	{
		var el = new LayoutElement_Column(root, self);
		el.Label(_label);
		
		array_push(children, el);
		childrencount++;
		return el;	
	}
	
	function Box(_label="")
	{
		var el = new LayoutElement_Box(root, self);
		el.Label(_label);
		
		array_push(children, el);
		childrencount++;
		return el;	
	}
	
	function Dropdown(_label="")
	{
		var el = new LayoutElement_Dropdown(root, self);
		el.Label(_label);
		
		array_push(children, el);
		childrencount++;
		return el;	
	}
	
	function Button(_label="")
	{
		var el = new LayoutElement_Button(root, self);
		el.Label(_label);
		
		array_push(children, el);
		childrencount++;
		return el;		
	}
	
	function Bool(_label="")
	{
		var el = new LayoutElement_Bool(root, self);
		el.Label(_label);
		
		array_push(children, el);
		childrencount++;
		return el;		
	}
	
	function Real(_label="")
	{
		var el = new LayoutElement_Real(root, self);
		el.Label(_label);
		
		array_push(children, el);
		childrencount++;
		return el;		
	}
	
	function Enum(_label="")
	{
		var el = new LayoutElement_Enum(root, self);
		el.Label(_label);
		
		array_push(children, el);
		childrencount++;
		return el;		
	}
	
	function List(_label="")
	{
		var el = new LayoutElement_List(root, self);
		el.Label(_label);
		
		array_push(children, el);
		childrencount++;
		return el;		
	}
	
	#endregion -----------------------------------------------------
	
	#region // Utility ======================================================
	
	function SetIDName(_idname)
	{
		idname = _idname;
		root.elementmap[$ _idname] = self;
		return self;
	}
	
	function Label(_label)
	{
		label = string(_label);	
		return self;
	}
	
	function Description(_desc)
	{
		description = string(_desc);	
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
			if op {op(value, self);}
		}
		return self;
	}
	
	function SetDefault(_default_value)
	{
		valuedefault = _default_value;
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
	
	function IsMouseOverXY(_x1, _y1, _x2=x2, _y2=y2)
	{
		return point_in_rectangle(common.mx, common.my, _x1, _y1, _x2, _y2);
	}
	
	function IsMouseOverExt(x, y, w, h)
	{
		return point_in_rectangle(common.mx, common.my, x, y, x+w, y+h);
	}
	
	function DefineControl(_source, _varpatharray, _varindex = -1)
	{
		control_src = _source;
		if is_array(_varpatharray)
		{
			array_copy(control_path, 0, _varpatharray, 0, array_length(_varpatharray));	
		}
		else
		{
			array_resize(control_path, 1);
			control_path[0] = _varpatharray;
		}
		control_index = _varindex;
		return self;
	}
	
	function GetControl()
	{
		// Source exists
		if !is_undefined(control_src)
		{
			var n = array_length(control_path);
			var _current = control_src;
			
			// For each path step
			for (var i = 0; i < n; i++)
			{
				if variable_struct_exists(_current, control_path[i])
				{
					_current = _current[$ control_path[i]];
				}
				else
				{
					break;	
				}
			}
			
			// Path result is array and index is given
			if control_index >= 0 && is_array(_current)
			{
				return _current[control_index];
			}
			// Path result is not an array
			else
			{
				return _current;	
			}
		}
		
		return value;
	}
	
	function UpdateControl(_value)
	{
		// Source exists
		if !is_undefined(control_src)
		{
			var n = array_length(control_path);
			
			// One key
			if n == 1
			{
				if control_index >= 0
				{
					control_src[$ control_path[0]][@ control_index] = _value;	
				}
				else
				{
					control_src[$ control_path[0]] = _value;	
				}
			}
			// More than one key
			else if n > 1
			{
				var _current = control_src;
				var _lastcurrent = _current;
				var i = 0;
			
				// For each path step
				for (i = 0; i < n; i++)
				{
					if variable_struct_exists(_current, control_path[i])
					{
						_lastcurrent = _current;
						_current = _current[$ control_path[i]];
					}
					else
					{
						break;	
					}
				}
			
				// Path result is array and index is given
				if control_index >= 0 && is_array(_current)
				{
					_current[@ control_index] = _value;
				}
				// Path result is not an array
				else
				{
					_lastcurrent[$ control_path[i-1]] = _value;
				}
			}
		}
	}
	
	function UpdateTooltip(_label=label, _desc=description)
	{
		common.tooltip_name = _label;
		common.tooltip_text = _desc;
		common.tooltip_target = self;	
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
	
	function DrawRectWH(x, y, w, h, color, alpha=1)
	{
		if interactable
		{
			draw_sprite_stretched_ext(spr_layoutbox, 0, x, y, w, h, c_white, alpha);
			draw_sprite_stretched_ext(spr_layoutbox, 1, x, y, w, h, color, alpha);
		}
		else
		{
			draw_sprite_stretched_ext(spr_layoutbox, 0, x, y, w, h, c_gray, alpha);
			draw_sprite_stretched_ext(spr_layoutbox, 1, x, y, w, h, c_dkgray, alpha);
		}
	}
	
	function DrawRectXY(x1, y1, x2, y2, color, alpha=1)
	{
		DrawRectWH(x1, y1, x2-x1, y2-y1, color, alpha);
	}
	
	function DrawFillXY(x1, y1, x2, y2, color, alpha=1)
	{
		draw_primitive_begin(pr_trianglelist);
		
		draw_vertex_color(x1, y1, color, alpha);
		draw_vertex_color(x1, y2, color, alpha);
		draw_vertex_color(x2, y2, color, alpha);
		
		draw_vertex_color(x2, y2, color, alpha);
		draw_vertex_color(x2, y1, color, alpha);
		draw_vertex_color(x1, y1, color, alpha);
		
		draw_primitive_end();
	}
	
	function DrawText(x, y, text, color = c_white)
	{
		if !interactable {color = c_gray;}
		
		draw_text_ext_transformed_color(
			x, y, text, 16, 3000, 
			common.textscale, common.textscale, 
			0, color, color, color, color, 1);
	}
	
	function DrawTextYCenter(x, text, color = c_white)
	{
		if !interactable {color = c_gray;}
		
		var yy = yc - common.textheightdiv2;
		draw_text_ext_transformed_color(
			x, yy, text, 16, 3000, 
			common.textscale, common.textscale, 
			0, color, color, color, color, 1);	
	}
	
	function DrawScrollBar(_yy1, _yy2, _amt, _baramt)
	{
		var hh = (_yy2-_yy1) * _baramt;
		var ww = common.scrollx-2;
		var xx = x2-common.scrollx;
			
		DrawRectXY(xx, _yy1, xx+ww, _yy2, c_black);
		DrawRectWH(
			xx, 
			lerp(_yy1, _yy2-hh, _amt),
			ww, hh, scrollhighlight? c_white: common.c_active
			);	
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
	contentheight = 0;
	
	surf = -1;
	surfyoffset = 0;
	surfyoffset_target = 0;
	scrollhighlight = false;
	scrolloffset = 0;
	
	common = {
		c_base : 0x342022,
		c_highlight : 0x743f3f,
		c_active : 0x846c66,
		
		textscale : 1,
		uiscale : 1,
		
		celltext : 1,
		cellui : 1,
		cellmax : 1, // Max of textscale and uiscale
		
		buttonheight : 24,
		textheight : 16,
		textheightdiv2 : 8,
		active : 0,
		
		lastpress : 255,
		mouseonpress_x : 0,
		mouseonpress_y : 0,
		doubleclick : 0,
		doubleclicktime : 20,
		
		cursorsprite : cr_arrow,
		
		mx : 0,
		my : 0,
		
		tooltip_name : "",
		tooltip_text : "",
		tooltip_wait : 0,
		tooltip_waittime : 600000,
		tooltip_target : 0,
		tooltip_lasttarget : 0,
		
		scrolllock : 0, // Set to zero at start of update
		scrollx : 10,
		
		extendy : 4,
	};
	
	elementmap = {};
	
	// Setup ======================================
	
	var _fnt = draw_get_font();
	draw_set_font(0);
	common.textheight = string_height("Mplq|,_");
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
	
	function SetPosWH(_x, _y, _w, _h)
	{
		x1 = _x;
		y1 = _y;
		w = _w;
		h = _h;
		x2 = _x+_w;
		y2 = _y+_h;
		
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
		common.scrolllock = 0;
		
		var _lastcursor = common.cursorsprite;
		common.cursorsprite = cr_arrow;
		
		var _mx = window_mouse_get_x()-x1;
		var _my = window_mouse_get_y()-y1;
		var _ystart = (label!="")*common.cellmax;
		var _displayh = h-(label!="")*common.cellmax;
		
		common.tooltip_text = "";
		common.tooltip_name = "";
		if common.mx == _mx && common.my == _my
		{
			common.tooltip_wait = max(common.tooltip_wait-delta_time, 0);
		}
		else if common.tooltip_lasttarget != common.tooltip_target
		|| !common.tooltip_lasttarget
		{
			common.tooltip_wait = common.tooltip_waittime;	
		}
		
		common.tooltip_lasttarget = common.tooltip_target;
		common.tooltip_target = noone;
		
		common.mx = _mx;
		common.my = _my;
		
		if label != "" {common.my -= common.celltext;}
		
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
			
			mouseonpress_x = _mx;
			mouseonpress_y = _my;
			
			common.lastpress = 0;
		}
		
		common.celltext = common.textscale*common.textheight;
		common.cellui = common.uiscale*common.buttonheight;
		common.cellmax = max(common.celltext, common.cellui);
		common.textheightdiv2 = common.textheight*0.5*common.textscale;
		
		// Positioning
		var yy = -surfyoffset+b;
		var _xx2 = w-b;
		var _yy2 = h-b;
		var _lastcontentheight = contentheight;
		
		if contentheight > h {_xx2 -= common.scrollx;}
		contentheight = b;
		
		if label != "" {contentheight += common.cellmax;}
		
		var offset;
		for (var i = 0; i < childrencount; i++)
		{
			offset = children[i].UpdatePos(b, yy, _xx2, _yy2);	
			yy += offset[1]+1;
			contentheight += offset[1]+1;
		}
		
		// Clicking Vars
		var _ismouseover = false;
		if point_in_rectangle(
			window_mouse_get_x(), window_mouse_get_y(), 
			x1, y1, x2, y2)
		{
			_ismouseover = true;
		}
		
		// Update Children
		var c;
		for (var i = 0; i < childrencount; i++)
		{
			c = children[i];
			if c.interactable
			{
				children[i].Update();
			}
		}
		
		// Scroll
		scrollhighlight = false;
		
		if !common.scrolllock && _ismouseover
		{
			var _spd = 16;
			var _lev = mouse_wheel_down()-mouse_wheel_up();
			if _lev != 0
			{
				surfyoffset_target += _spd*_lev;	
			}
			
			if common.mx >= w-common.scrollx
			{
				var _ystart = y1+common.cellmax*(label!="");
				scrollhighlight = true;
				
				if mouse_check_button_pressed(mb_left)
				{
					scrollactive = true;
					scrolloffset = (surfyoffset_target/contentheight) * _displayh - (common.my-_ystart);
				}
			}
		}
		
		// Scrolling via mouse
		if !mouse_check_button(mb_left) {scrollactive = false;}
		if scrollactive
		{
			scrollhighlight = true;
			surfyoffset_target = ( (common.my-_ystart)+scrolloffset ) / _displayh * contentheight;
		}
		
		if _lastcontentheight != contentheight
		{
			//surfyoffset_target += contentheight-_lastcontentheight;
		}
		
		// Clamp offset
		surfyoffset_target = max(0, min(surfyoffset_target, contentheight-h));
		
		// Smooth scroll into position
		if surfyoffset_target != surfyoffset
		{
			surfyoffset += (surfyoffset_target-surfyoffset)/(delta_time/3000);
			if abs(surfyoffset_target-surfyoffset) < 0.2
			{
				surfyoffset = surfyoffset_target;
			}
		}
		
		if _lastcursor != common.cursorsprite
		{
			window_set_cursor(common.cursorsprite);
		}
		
		return _ismouseover;
	}
	
	function Draw()
	{
		// Update surface
		var _w = 1 << ceil(log2(w)); // Use highest power of 2
		var _h = 1 << ceil(log2(contentheight));
		
		if !surface_exists(surf)
		{
			surf = surface_create(_w, _h);
		}
		else if surface_get_width(surf) < _w
		|| surface_get_height(surf) < _h
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
		
		surface_reset_target();
		// Surface End -----------------------------------------------------
		
		DrawRectWH(x1, y1, w, h, 0);
		
		// Draw Label
		if label != ""
		{
			draw_set_halign(0);
			draw_set_valign(0);
			DrawText(x1+2, y1, label);
		}
		
		var _cs = common.celltext;
		if label != "" 
		{
			draw_surface_part(surf, 0, 0, w, h-_cs-b, x1, y1+_cs);
		}
		else 
		{
			draw_surface_part(surf, 0, 0, w, h-b, x1, y1);
		}
		
		// Draw Scrollbar
		if contentheight > h
		{
			DrawScrollBar(
				y1 + common.cellmax*(label != ""), 
				y2-4, 
				-surfyoffset/(h-contentheight),
				(h/contentheight)
				);
		}
		
		// Draw Tooltip
		if common.tooltip_wait == 0
		if common.tooltip_target
		{
			var _s = "";
			
			if common.tooltip_name != "" {_s += common.tooltip_name;}
			if common.tooltip_text != "" 
			{
				if _s != "" {_s += "\n";}
				_s += common.tooltip_text;
			}
			
			var xx = window_mouse_get_x()+8;
			var yy = window_mouse_get_y()+8;
			var ww = string_width(_s)+8;
			var hh = string_height(_s)+4;
			
			if xx+ww >= window_get_width() {xx -= ww;}
			
			draw_set_halign(0);
			draw_set_valign(0);
			DrawRectWH(xx, yy, ww, hh, 0, 0.8);
			DrawText(xx+4, yy+2, _s, c_white);
		}
		
	}
	
	function FindElement(_idname)
	{
		return variable_struct_get(root.elementmap, _idname);
	}
	
}
