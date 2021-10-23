/// @desc

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
	vertex_begin(out, vbf_default);
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
	
	// Forward
	cameraforward[0] = dcos(cameradirection) * dcos(camerapitch);
	cameraforward[1] = -dsin(cameradirection) * dcos(camerapitch);
	cameraforward[2] = -dsin(camerapitch);
	d = point_distance_3d(0,0,0, cameraforward[0], cameraforward[1], cameraforward[2]);
	cameraforward[0] /= d;
	cameraforward[1] /= d;
	cameraforward[2] /= d;
	
	// Right
	cameraright[0] = dcos(cameradirection+90) * dcos(camerapitch);
	cameraright[1] = -dsin(cameradirection+90) * dcos(camerapitch);
	cameraright[2] = -dsin(camerapitch);
	d = point_distance_3d(0,0,0, cameraright[0], cameraright[1], cameraright[2]);
	cameraright[0] /= d;
	cameraright[1] /= d;
	cameraright[2] /= d;
	
	// Up
	cameraup[0] = dcos(cameradirection) * dcos(camerapitch-90);
	cameraup[1] = -dsin(cameradirection) * dcos(camerapitch-90);
	cameraup[2] = -dsin(camerapitch-90);
	d = point_distance_3d(0,0,0, cameraup[0], cameraup[1], cameraup[2]);
	cameraup[0] /= d;
	cameraup[1] /= d;
	cameraup[2] /= d;
	
	// View Matrix
	d = cameradist;
	matview = matrix_build_lookat(
		camerapos[0]-cameraforward[0]*d, camerapos[1]-cameraforward[1]*d, camerapos[2]-cameraforward[2]*d, 
		camerapos[0], camerapos[1], camerapos[2], 
		cameraup[0], cameraup[1], cameraup[2]);
	// Correct Yflip
	matview = matrix_multiply(matrix_build(0,0,0,0,0,0,1,-1,1), matview);

}