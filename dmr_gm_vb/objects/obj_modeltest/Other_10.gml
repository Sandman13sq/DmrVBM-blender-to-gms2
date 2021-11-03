/// @desc Demo Methods

function CreateGridVB(cellcount, cellsize)
{
	static MakeVert = function(vb,x,y,col)
	{
		vertex_position_3d(vb, x, y, 0); 
		vertex_color(vb, col, 1);
		vertex_texcoord(vb, 0, 0);
	}
	
	// Set up colors: [Grid lines, X axis, Y axis]
	var colbase = [c_dkgray, c_maroon, c_green];
	var col = [ [0,0,0], [0,0,0], [0,0,0] ];
	
	var colgrid = c_dkgray;
	var colx = [c_red, merge_color(0, c_red, 0.2)];
	var coly = [c_lime, merge_color(0, c_lime, 0.2)];
	
	// Make Grid
	var width = cellsize * cellcount;
	
	var out = vertex_create_buffer();
	vertex_begin(out, vbf.basic);
	for (var i = -cellcount; i <= cellcount; i++)
	{
		MakeVert(out, i*cellsize, width, colgrid);
		MakeVert(out, i * cellsize, -width, colgrid);
		MakeVert(out, width, i * cellsize, colgrid);
		MakeVert(out, -width, i * cellsize, colgrid);
	}
	
	// +x
	MakeVert(out, 0, 0, colx[0]);
	MakeVert(out, width, 0, colx[0]);
	MakeVert(out, 0, 0, colx[1]);
	MakeVert(out, -width, 0, colx[1]);
	
	MakeVert(out, 0, 0, coly[0]);
	MakeVert(out, 0, width, coly[0]);
	MakeVert(out, 0, 0, coly[1]);
	MakeVert(out, 0, -width, coly[1]);
	
	vertex_end(out);
	vertex_freeze(out);
	
	return out;
}

function UpdateView()
{
	var d;
	var loc = camera.location;
	var fwrd = camera.viewforward;
	var rght = camera.viewright;
	var up = camera.viewup;
	var dir = camera.viewdirection;
	var pitch = camera.viewpitch;
	
	// Forward
	fwrd[@ 0] = dcos(dir) * dcos(pitch);
	fwrd[@ 1] = -dsin(dir) * dcos(pitch);
	fwrd[@ 2] = -dsin(pitch);
	d = point_distance_3d(0,0,0, fwrd[0], fwrd[1], fwrd[2]);
	fwrd[@ 0] /= d;
	fwrd[@ 1] /= d;
	fwrd[@ 2] /= d;
	
	// Right
	rght[@ 0] = dcos(dir+90) * dcos(pitch);
	rght[@ 1] = -dsin(dir+90) * dcos(pitch);
	rght[@ 2] = -dsin(pitch);
	d = point_distance_3d(0,0,0, rght[0], rght[1], rght[2]);
	rght[@ 0] /= d;
	rght[@ 1] /= d;
	rght[@ 2] /= d;
	
	// Up
	up[@ 0] = dcos(dir) * dcos(pitch-90);
	up[@ 1] = -dsin(dir) * dcos(pitch-90);
	up[@ 2] = -dsin(pitch-90);
	d = point_distance_3d(0,0,0, up[0], up[1], up[2]);
	up[@ 0] /= d;
	up[@ 1] /= d;
	up[@ 2] /= d;
	
	// View Matrix
	d = camera.viewdistance;
	camera.matview = matrix_build_lookat(
		loc[0]-fwrd[0]*d, loc[1]-fwrd[1]*d, loc[2]-fwrd[2]*d, 
		loc[0], loc[1], loc[2], 
		up[0], up[1], up[2]);
	// Correct Yflip
	camera.matview = matrix_multiply(matrix_build(0,0,0,0,0,0,1,-1,1), camera.matview);

}