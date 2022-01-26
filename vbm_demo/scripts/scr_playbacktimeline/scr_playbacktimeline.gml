/// @desc

function PlaybackTimeline(_trackdata) constructor
{
	surf = -1;
	trackdata = _trackdata;
	keyframes = array_create(200);
	
	x1 = 0;
	y1 = 0;
	x2 = 0;
	y2 = 0;
	w = 0;
	h = 0;
	
	hsep = 14;
	border = 4;
	drawx = 128;
	drawy = hsep;
	drawwidth = 1024;
	drawheight = hsep*200;
	pos = 0;
	
	frameindices = [];
	points = [];
	pointmap = ds_map_create();
	
	
	
	surfyoffset = 0;
	active = false;
	middleactive = 0;
	middleanchor = 0;
	
	function IsMouseOver()
	{
		return point_in_rectangle(
			window_mouse_get_x(),
			window_mouse_get_y(),
			x1, y1, x2, y2
			)
	}
	
	function UpdatePos(_x1, _y1, _x2, _y2)
	{
		x1 = _x1;
		y1 = _y1;
		x2 = _x2;
		y2 = _y2;
		w = x2-x1;
		h = y2-y1;
		
		drawwidth = w-16;
		
		return self;
	}
	
	function UpdateTimeline(_pos)
	{
		var tracklength = trackdata.duration;
		var tracks = trackdata.tracks;
		var transformtracks;
		var numtracks = array_length(tracks);
		var keyframes;
		var numkeyframes;
		points = array_create(numtracks);
		
		pos = _pos;
		
		if IsMouseOver()
		{
			if mouse_check_button_pressed(mb_left)
			{
				active = true;
			}
			else if mouse_check_button_pressed(mb_middle)
			{
				middleactive = true;
				middleanchor = -(window_mouse_get_y() - (y1+border)) - surfyoffset;
			}
			
			var _lev = mouse_wheel_down() - mouse_wheel_up();
			if _lev != 0
			{
				surfyoffset = clamp(surfyoffset + _lev*hsep, 0, drawheight - h);
			}
			
		}
		
		// Scroll playback
		if active
		{
			if !mouse_check_button(mb_left) {active = false;}
			else
			{
				var _mx = window_mouse_get_x() - (x1+border+drawx);
				pos = round(tracklength * _mx / ((drawwidth-8)-drawx)) / tracklength;
			}
		}
		
		// Set up frame indices
		frameindices = [];
		
		if tracklength <= 1.0
		{
			for (var f = 0; f <= tracklength; f += 0.1)
			{
				frameindices[f] = f;
			}
		}
		else
		{
			for (var p = 0; p <= 1; p += (1/10))
			{
				array_push(frameindices, round(p * tracklength));
			}
			
		}
		
		return pos;
	}
	
	function Draw()
	{
		var _ww = 1 << ceil(log2(drawwidth)+1);
		var _hh = 1 << ceil(log2(drawheight));
		
		if !surface_exists(surf)
		{
			surf = surface_create(_ww, _hh);	
		}
		
		if surface_get_width(surf) < _ww
		|| surface_get_width(surf) < _hh
		{
			surface_resize(surf, _ww, _hh);
		}
		
		// Draw on surface
		surface_set_target(surf)
		{
			draw_clear(0);
			
			
		}
		surface_reset_target();
		
		// Draw Surface
		draw_sprite_stretched_ext(spr_layoutbox, 1, x1, y1, w, h, 0, 1);
		draw_sprite_stretched_ext(spr_layoutbox, 0, x1, y1, w, h, c_white, 1);
		draw_surface_part(surf, 0, surfyoffset, w-border*2, h-border*2, x1+border, y1+border);
		
	}
}
