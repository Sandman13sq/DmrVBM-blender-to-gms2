/// @desc

show_debug_overlay(1);
event_user(0);

//display_set_gui_size(room_width, room_height);
display_set_gui_maximize(1, 1);
draw_set_font(fnt_default);

RENDERING = new Rendering();
RENDERING.DefineUniform("u_drawmatrix");
RENDERING.DefineUniform("u_camera");
RENDERING.DefineUniform("u_matpose");

room_goto(rm_modeltest);

// Sets all matrices in flat array to matrix "m"
function Tmat(flatarray, m)
{
	var n = array_length(flatarray) div 16;
	
	if n > 0
	{
		// Set first entry
		array_copy(flatarray, 0, m, 0, 16);
	
		if n > 1
		{
			var nn = 1; // Number of copied matrices
			
			// iterations = log2(n)
			// leftover = n - 2^log2(n)
			
			// Copy section of copied matrices to index of non-copied position
			/*
				10000000 (Start with first matrix copied)
				11000000 (Copy values [0-1] to index 2)
				11110000 (Copy values [0-2] to index 4)
				11111111 (Copy values [0-4] to index 8)
				[0-8] to 16, [0-16] to 32, [0-32] to 64, and so on...
			*/
			repeat( log2(n) ) //while (nn*2 <= n)
			{
				array_copy(flatarray, nn*16, flatarray, 0, nn*16);
				nn *= 2;
			}
			
			if nn < n
			{
				array_copy(flatarray, (n-nn)*16, flatarray, 0, nn*16);
			}
		}
	}
}

test = function(n)
{
	var a;
	
	a = array_create(16 * n, 0);
	Tmat(a, [1,2,3,4,1,2,3,4,1,2,3,4,1,2,3,4]);

	var s = "";
	for (var i = 0; i < array_length(a); i += 16)
	{
		s += string(a[i]) + " ";
	}
	
	s += "\nn = " + string(n) + ", " + string(n*16) + ", " + string(array_length(a));
	msg(s);
}


/*
		x
		xx
		xxxx
		xxxxxxxx
		
		y
		yy
		yyyyy
		yyyyyyyyyyy
		
		f(x) = 2*f(x-1) + 1
		f(0) = 0;
		f(1) = 1;
	*/