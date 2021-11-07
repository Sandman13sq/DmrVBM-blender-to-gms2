/// @desc Demo Methods

function CreateGridVB(cellcount, cellsize)
{
	// static = lambda ???
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
	var colx = [c_red, merge_color(0, c_red, 0.5)];
	var coly = [c_lime, merge_color(0, c_lime, 0.5)];
	
	// Make Grid
	var width = cellsize * cellcount;
	
	var out = vertex_create_buffer();
	vertex_begin(out, vbf.basic);
	for (var i = -cellcount; i <= cellcount; i++)
	{
		if i == 0 {continue;}
		
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

function UpdateActiveVBX()
{
	meshindex = layout_meshselect.value;
	meshdataactive = curly.meshdata[meshindex];
	
	layout_model.FindElement("meshvisible")
		.Value((curly.meshvisible & (1 << meshindex)) != 0, false);
	
	layout_model.FindElement("meshemission").Value(meshdataactive.emission, false);
	layout_model.FindElement("meshshine").Value(meshdataactive.shine, false);
	layout_model.FindElement("meshsss").Value(meshdataactive.sss, false);
}

function ResetModelPosition()
{
	modelposition[0] = 0;
	modelposition[1] = 0;
	modelposition[2] = 0;
	modelzrot = 0;
}
