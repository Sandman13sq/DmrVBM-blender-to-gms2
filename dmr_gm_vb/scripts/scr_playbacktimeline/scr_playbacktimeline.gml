/// @desc

function PlaybackTimeline(src) constructor
{
	source = src;
	surf = -1;
	trackdata = -1;
	
	keyframes = array_create(200);
	
	x1 = 0;
	y1 = 0;
	x2 = 0;
	y2 = 0;
	w = 0;
	h = 0;
	
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
	
	function UpdateTimeline(pos)
	{
		
	}
	
	function Draw()
	{
		if !surface_exists(surf)
		{
			surf = surface_create(
				1024, 
				256
				);	
		}
		
		surface_set_target(surf)
		{
			
		}
		surface_reset_target();
	}
}