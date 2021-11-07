/// @desc

function LayoutElement(_root, _parent) : __LayoutSuper() constructor
{
	root = _root;
	parent = _parent;
	children = [];
	childrencount = 0;
	common = root.common;
	
	op = 0; // Function to call
	active = 0;
	
	control_src = noone; // Object to read variables from
	control_var = ""; // Variable name
	control_index = -1; // Array index (-1 for no array)
	
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
	color = common.c_base;
	
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
