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
	
	trackysep = 16;
	drawwidth = 1024;
	drawheight = trackysep*200;
	pos = 0;
	
	frameindices = [];
	points = [];
	pointmap = ds_map_create();
	
	hsep = 14;
	drawx = 128;
	drawy = hsep;
	border = 4;
	
	surfyoffset = 0;
	
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
		return self;
	}
	
	function UpdateTimeline(_pos)
	{
		pos = _pos;
		
		var tracks = trackdata.tracks;
		var transformtracks;
		var numtracks = array_length(tracks);
		var keyframes;
		var numkeyframes;
		points = array_create(numtracks);
		
		for (var t = 0; t < numtracks; t++)
		{
			points[t] = [];
			
			for (var tt = 0; tt < 3; tt++)
			{
				keyframes = tracks[t][tt].frames;	
				numkeyframes = array_length(keyframes);
				
				for (var k = 0; k < numkeyframes; k++)
				{
					array_push(points[t], keyframes[k]);	
				}
			}
		}
		
		surfyoffset += 0.1;
		
		// Set up frame indices
		frameindices = [];
		var tracklength = trackdata.length;
		
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
		
		if IsMouseOver()
		{
			return true;
		}
		
		return false;
	}
	
	function Draw()
	{
		if !surface_exists(surf)
		{
			surf = surface_create(
				1 << ceil(log2(drawwidth)+1), 
				1 << ceil(log2(drawheight))
				);	
		}
		
		// Draw on surface
		surface_set_target(surf)
		{
			draw_clear(0);
			
			var yy;
			var keyframes;
			var numtracks = array_length(points);
			var numkeyframes;
			var _x1 = drawx, _x2 = drawwidth-8;
			var tracklength = trackdata.length;
			
			draw_line_color(_x2, 0, _x2, drawheight, 0x222222, 0x222222);
			
			draw_set_halign(0);
			draw_set_valign(0);
			
			// For each track (bone)
			yy = drawy;
			for (var t = 0; t < numtracks; t++)
			{
				draw_rectangle_color(
					_x1, yy+2, _x2, yy+hsep-2,
					0x222222, 0x222222, 0x222222, 0x222222, 0
					);
				yy += hsep;
			}
			
			// Draw frame lines
			for (var f = 0; f <= tracklength; f++)
			{
				draw_line_color(
					lerp(_x1, _x2, f/tracklength), 0, 
					lerp(_x1, _x2, f/tracklength), drawheight, 
					0x333333, 0x333333);	
			}
			
			// For each track (bone)
			yy = drawy;
			for (var t = 0; t < numtracks; t++)
			{
				keyframes = points[t];
				numkeyframes = array_length(keyframes);
				
				// For each keyframe
				for (var f = 0; f < numkeyframes; f++)
				{
					draw_circle_color(
						lerp(_x1, _x2, keyframes[f]),
						yy+hsep/2, 4, c_blue, c_white, 0
						);
				}
				
				draw_text(2, yy, trackdata.tracknames[t]);
				yy += hsep;
			}
			
			// Marker Line
			draw_line_width_color(
				lerp(_x1, _x2, pos), 0, 
				lerp(_x1, _x2, pos), drawheight, 
				2, c_white, c_white);
			
			// Draw Frames
			var frameindexcount = array_length(frameindices);
			yy = surfyoffset-4;
			draw_rectangle_color(_x1-4, yy, _x2+4, yy+hsep,
				0, 0, 0, 0, 0);
			
			draw_set_halign(1);
			for (var f = 0; f < frameindexcount; f++)
			{
				draw_text(
					lerp(_x1, _x2, frameindices[f]/tracklength), 
					yy, frameindices[f]);	
			}
		}
		surface_reset_target();
		
		// Draw Surface
		draw_sprite_stretched_ext(spr_layoutbox, 1, x1, y1, w, h, 0, 1);
		draw_sprite_stretched_ext(spr_layoutbox, 0, x1, y1, w, h, c_white, 1);
		draw_surface_part(surf, 0, surfyoffset, w-border*2, h-border*2, x1+border, y1+border);
		
	}
}
