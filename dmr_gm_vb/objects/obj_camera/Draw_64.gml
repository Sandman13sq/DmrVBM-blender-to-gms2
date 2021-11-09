/// @desc Debug

draw_set_halign(0);
draw_set_valign(0);

drawfext(16, 250,
	"vertex_usage_position: %s", vertex_usage_position,
	"vertex_usage_color: %s", vertex_usage_color,
	"vertex_usage_normal: %s", vertex_usage_normal,
	"vertex_usage_texcoord: %s", vertex_usage_texcoord,
	"vertex_usage_blendweight: %s", vertex_usage_blendweight,
	"vertex_usage_blendindices: %s", vertex_usage_blendindices,
	"vertex_usage_depth: %s", vertex_usage_depth,
	"vertex_usage_tangent: %s", vertex_usage_tangent,
	"vertex_usage_binormal: %s", vertex_usage_binormal,
	"vertex_usage_fog: %s", vertex_usage_fog,
	"vertex_usage_sample: %s", vertex_usage_sample,
	);

return;
drawfext(16, 200,
	"middlelock: %s", middlelock,
	"cameralocation: %s", [viewlocation],
	"location: %s", [obj_modeltest.modelposition],
	"viewdirection: %s", viewdirection,
	"viewpitch: %s", viewpitch,
	"forward: %s", string(viewforward),
	"right: %s", string(viewright),
	"fps: %s", string(fps),
	"fpsreal: %s", string(fps_real),
	);
