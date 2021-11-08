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
	
	function GetControl()
	{
		if !is_undefined(control_src)
		{
			if variable_struct_exists(control_src, control_var)
			{
				return control_index >= 0?
					(variable_struct_get(control_src, control_var)[control_index]):
					(variable_struct_get(control_src, control_var));
			}
		}
		
		return value;
	}
	
	function DefineControl(_source, _varname, _varindex = -1)
	{
		control_src = _source;
		control_var = _varname;
		control_index = _varindex;
		return self;
	}
	
	function UpdateControl(_value)
	{
		if !is_undefined(control_src)
		{
			if variable_struct_exists(control_src, control_var)
			{
				// Variable
				if control_index < 0
					{variable_struct_set(control_src, control_var, _value);}
				// Array
				else
					{variable_struct_get(control_src, control_var)[@ control_index] = _value;}
			}
		}
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
		
		tooltip_name : "",
		tooltip_text : "",
		tooltip_wait : 0,
		tooltip_waittime : 600000,
		tooltip_target : 0,
		tooltip_lasttarget : 0,
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
		
		var _mx = window_mouse_get_x();
		var _my = window_mouse_get_y();
		
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
		
		// Positioning
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
		
		// Clicking Vars
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
	}
	
	function Draw()
	{
		DrawRectWH(x1, y1, w, h, 0);
		
		// Draw Label
		if label != ""
		{
			draw_set_halign(0);
			draw_set_valign(0);
			DrawText(x1+2, y1, label);	
		}
		
		// Draw Children
		for (var i = 0; i < childrencount; i++)
		{
			children[i].Draw();	
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
			
			var xx = common.mx;
			var yy = common.my+6;
			var ww = string_width(_s)+8;
			var hh = string_height(_s)+4;
			
			if xx+ww >= window_get_width() {xx -= ww;}
			
			draw_set_halign(0);
			draw_set_valign(0);
			DrawRectWH(xx, yy, ww, hh, 0, 0.8);
			DrawText(xx+4, yy+2, _s, c_white);
		}
		
		//DrawText(200, 200, common.lastpress);
	}
	
	function FindElement(_idname)
	{
		return variable_struct_get(root.elementmap, _idname);
	}
}
