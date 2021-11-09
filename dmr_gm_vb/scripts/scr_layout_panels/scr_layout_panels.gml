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
	usesscroll = false; // When true, prevents scrolling layout via mouse wheel
	
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
			h = surfheight+hsep;
			
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
		}
		else
		{
			h = hsep;	
		}
		
		// Smooth scroll into position
		var _d = (surfyoffset_target-surfyoffset)/3;
		if _d > 0 {surfyoffset = min(surfyoffset_target, surfyoffset+_d);}
		else if _d < 0 {surfyoffset = max(surfyoffset_target, surfyoffset+_d);}
		
		y2 = y1+h;
		
		xc = lerp(x1, x2, 0.5);
		yc = lerp(y1, y2, 0.5);
		
		return [w, h];
	}
	
	function Update()
	{
		var _cs = common.cellmax;
		
		color = common.c_base;
		
		// Toggle Expand
		if IsMouseOverExt(x1, y1, w, active? _cs: h)
		{
			color = common.c_highlight;
			if common.clickheld
				{color = common.c_active;}
			if common.clickreleased
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
			}
			else
			{
				common.my = -infinity;	
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
