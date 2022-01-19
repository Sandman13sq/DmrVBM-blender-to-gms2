/// @desc

for (var i = 0; i < worldcount; i++)
{
	vertex_delete_buffer(worldvbs[i]);
}

vertex_delete_buffer(vb_grid);
vertex_delete_buffer(vb_ball);
