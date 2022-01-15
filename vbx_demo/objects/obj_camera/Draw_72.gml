/// @desc Clear Screen

draw_clear(clearcolor);
var xx = current_time/100
draw_sprite_tiled_ext(spr_starbk, 0, xx, -xx, 1, 1, 0x110808, 1);
draw_sprite_tiled_ext(spr_starbk, 1, xx, -xx, 1, 1, 0x311012, 1);

matrix_set(matrix_projection, matproj);
matrix_set(matrix_view, matview);
matrix_set(matrix_world, matrix_build_identity());
