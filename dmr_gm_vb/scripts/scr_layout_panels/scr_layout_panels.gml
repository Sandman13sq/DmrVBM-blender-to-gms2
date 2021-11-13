/// @desc

function LayoutElement(_root, _parent) : __LayoutSuper() constructor
{
	root = _root;
	parent = _parent;
	common = root.common;
	
	op = 0; // Function to call
	active = false;
	
	control_src = noone; // Object to read variables from
	control_path = []; // Variable name
	control_index = -1; // Array index (-1 for no array)
	
	x1 = 0; // Following are unit values [0.0-1.0]
	y1 = 0;
	x2 = 0;
	y2 = 0;
	w = 0;
	h = 0;
	b = 4; // Border
	
	xscale = 1.0;
	yscale = 1.0;
	
	label = "";
	value = 0;
	valuedefault = 0;
	usesscroll = false; // When true, prevents scrolling layout via mouse wheel
	
	clickpress = 0;
	clickhold = 0;
	clickrelease = 0;
	
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
	
	function ClickUpdate()
	{
		clickpress = false;
		clickrelease = false;
		
		if IsMouseOver()
		{
			if mouse_check_button_pressed(mb_left)
			{
				clickpress = true;
				clickhold = true;
			}
			
			if clickhold
			{
				// Release can only be true if mb was held previously
				if mouse_check_button_released(mb_left)
				{
					clickrelease = true;
				}
				
				if !mouse_check_button(mb_left)
				{
					clickhold = false;
				}
			}
		}
		else if !mouse_check_button(mb_left)
		{
			clickhold = false;
		}
	}
	
	// Called in draw event
	function Draw()
	{
		var c;
		for (var i = 0; i < childrencount; i++)
		{
			c = children[i];
			if c.interactable
			{
				children[i].Draw();
			}
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
			yy += common.celltext+2;
			h += common.celltext+2;
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
