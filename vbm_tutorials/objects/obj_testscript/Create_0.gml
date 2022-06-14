/// @desc 

time = 0;
report = "";

function Report(s) {report += s+"\n";}

function DrawModelDesc(text)
{
	var shd = shader_current();
	shader_reset();
	gpu_push_state();
	gpu_set_cullmode(cull_noculling);
	gpu_set_ztestenable(0);
	gpu_set_zfunc(cmpfunc_always);
	var m = matrix_multiply(Mat4Translate(-10, 2, 0), matrix_get(matrix_world));
	matrix_set(matrix_world, m);
	draw_text_transformed(10,0, text, .1, .1, 0);
	gpu_pop_state();
	shader_set(shd);
}

x = 10; 
y = 20;

// Camera ----------------------------------------------------------------------
fieldofview = 50;
znear = 5;
zfar = 1000;

viewlocation = [0,0,10];
viewforward = [0,-1,0];
viewright = [1,0,0];
viewup = [0,0,1];
viewdistance = 24;
viewzrot = 0;
viewxrot = 10;

matproj = matrix_build_identity();
matview = matrix_build_identity();
mattran = matrix_build_identity();
matpose = Mat4ArrayFlat(VBM_MATPOSEMAX);	// Flat array of matrices to pass into the shader
matpose2 = Mat4ArrayFlat(VBM_MATPOSEMAX);	// Flat array of matrices to pass into the shader

middledown = 0;
middlelast = 0;
mouseanchor = [0,0];
viewzrotanchor = 0;
viewxrotanchor = 0;
viewlocationanchor = [0,0,0];

viewlocation[0] += x;
viewlocation[1] += y;
mode = 0;

// Vertex Formats -------------------------------------------------------------
vertex_format_begin();
vertex_format_add_position_3d();
vertex_format_add_color();
vertex_format_add_texcoord();
vbf_simple = vertex_format_end();

vertex_format_begin();
vertex_format_add_position_3d();
vertex_format_add_normal();
vertex_format_add_color();
vertex_format_add_texcoord();
vbf_normal = vertex_format_end();

vertex_format_begin();
vertex_format_add_position_3d();
vertex_format_add_normal();
vertex_format_add_color();
vertex_format_add_texcoord();
vertex_format_add_custom(vertex_type_float4, vertex_usage_texcoord); // Bone Indices
vertex_format_add_custom(vertex_type_float4, vertex_usage_texcoord); // Bone Weights
vbf_rigged = vertex_format_end();

// Shader Uniforms -------------------------------------------------------------
u_normal_lightpos = shader_get_uniform(shd_normal, "u_lightpos");
u_style_lightpos = shader_get_uniform(shd_style, "u_lightpos");
u_rigged_lightpos = shader_get_uniform(shd_rigged, "u_lightpos");
u_rigged_matpose = shader_get_uniform(shd_rigged, "u_matpose");	// Handler for pose matrix array
u_complete_lightpos = shader_get_uniform(shd_complete, "u_lightpos");
u_complete_matpose = shader_get_uniform(shd_complete, "u_matpose");	// Handler for pose matrix array
u_complete_normalmap = shader_get_sampler_index(shd_complete, "u_normalmap");

// VBs =========================================================================

var dir = "D:/GitHub/DmrVBM/vbm_tutorials/datafiles/";
if (!directory_exists(dir)) {dir = "";}

show_debug_message("TEST START =====================================================");

Report("== OpenVertexBuffer() ==");

// Invalid path
time = get_timer();
vb_wrongpath = OpenVertexBuffer(dir+"test/???.vb", vbf_simple);
time = get_timer()-time;
Report("Invalid VB path: "+string(time)+"ms, return: "+string(vb_wrongpath));

// Wrong File Type
time = get_timer();
vb_notcurly = OpenVertexBuffer(dir+"test/notcurly.png", vbf_simple);
time = get_timer()-time;
Report("Wrong File Type: "+string(time)+"ms, return: "+string(vb_notcurly));

// Uncompressed buffer
time = get_timer();
vb_curly_nocompression = OpenVertexBuffer(dir+"test/curly_comp0.vb", vbf_simple);
time = get_timer()-time;
Report("Non-Compressed VB: "+string(time)+"ms, return: "+string(vb_curly_nocompression));

// Compressed buffer
time = get_timer();
vb_curly_fullcompression = OpenVertexBuffer(dir+"test/curly_comp9.vb", vbf_simple);
time = get_timer()-time;
Report("Compressed VB: "+string(time)+"ms, return: "+string(vb_curly_fullcompression));

// Wrong Format
time = get_timer();
vb_curly_floatcolors = OpenVertexBuffer(dir+"test/curly_floatcolors.vb", vbf_simple);
time = get_timer()-time;
Report("Wrong Format VB: "+string(time)+"ms, return: "+string(vb_curly_floatcolors));

// Edges Only
time = get_timer();
vb_curly_edgesonly = OpenVertexBuffer(dir+"test/curly_edgesonly.vb", vbf_simple);
time = get_timer()-time;
Report("Edges Only VB: "+string(time)+"ms, return: "+string(vb_curly_edgesonly));

// Scaled
time = get_timer();
vb_curly_scaled = OpenVertexBuffer(dir+"test/curly_scaled.vb", vbf_normal);
time = get_timer()-time;
Report("Scaled VB: "+string(time)+"ms, return: "+string(vb_curly_scaled));

// Instancing
time = get_timer();
vb_instanced = OpenVertexBuffer(dir+"test/instanced.vb", vbf_normal);
time = get_timer()-time;
Report("Instanced VB: "+string(time)+"ms, return: "+string(vb_instanced));

vb_world = new VBMData();

// VBMs -------------------------------------------------------------------------

Report("\n== VBMs() ==");

// Invalid path
time = get_timer();
vbm_wrongpath = new VBMData();
vbm_wrongpath.Open(dir+"test/???.vbm");
time = get_timer()-time;
Report("Invalid VBM path: "+string(time)+"ms, return: "+string(vbm_wrongpath));

// Wrong file type
time = get_timer();
vbm_wrongfiletype = new VBMData();
vbm_wrongfiletype.Open(dir+"test/notcurly.png");
time = get_timer()-time;
Report("Wrong Filetype: "+string(time)+"ms, return: "+string(vbm_wrongfiletype));

// Uncompressed
time = get_timer();
vbm_curly_uncompressed = new VBMData();
vbm_curly_uncompressed.Open(dir+"test/curly_uncompressed.vbm");
time = get_timer()-time;
Report("Uncompressed: "+string(time)+"ms, return: "+string(vbm_curly_uncompressed));

// Compressed
time = get_timer();
vbm_curly_compressed = new VBMData();
vbm_curly_compressed.Open(dir+"test/curly_compressed.vbm");
time = get_timer()-time;
Report("Compressed: "+string(time)+"ms, return: "+string(vbm_curly_compressed));

// Vertex Buffer, no format given (Not VBM)
time = get_timer();
vbm_curly_vb = new VBMData();
vbm_curly_vb.Open(dir+"test/curly_comp0.vb");
time = get_timer()-time;
Report("Vertex Buffer, No Format Given (Not VBM): "+string(time)+"ms, return: "+string(vbm_curly_vb));

// Format Given
time = get_timer();
vbm_curly_vb.Open(dir+"test/curly_vb.vbm", vbf_normal);
time = get_timer()-time;
Report("Vertex Buffer (Not VBM): "+string(time)+"ms, return: "+string(vbm_curly_vb));

// Export List
time = get_timer();
vbm_curly_exportlist = new VBMData();
vbm_curly_exportlist.Open(dir+"test/curly_exportlist.vbm", vbf_rigged, true, true);
time = get_timer()-time;
Report("Export List: "+string(time)+"ms, return: "+string(vbm_curly_exportlist));

// Tangents
time = get_timer();
vbm_curly_complete = new VBMData();
vbm_curly_complete.Open(dir+"test/curly_complete.vbm");
time = get_timer()-time;
Report("Complete: "+string(time)+"ms, return: "+string(vbm_curly_complete));

// Instanced
time = get_timer();
vbm_instanced = new VBMData();
vbm_instanced.Open(dir+"test/instanced.vbm");
time = get_timer()-time;
Report("Instanced: "+string(time)+"ms, return: "+string(vbm_instanced));

normalmap = sprite_add(dir+"test/curly-def-normal.png", 1, 0, 0, 0, 0);

// TRKs -------------------------------------------------------------------------
trk_poses = new TRKData();
OpenTRK(trk_poses, dir+"test/poses-all.trk");

trk_gun = new TRKData();
OpenTRK(trk_gun, dir+"test/hip.trk");

poseindex = 0;
playbackactive = true;
playbackposition = 0;

localpose = Mat4Array(VBM_MATPOSEMAX);
matpose = trk_poses.framematrices[poseindex];

lightpos = [80, 320, 480];
lightpos = [2000, 4000, 3000];

show_debug_message("TEST END =====================================================");
