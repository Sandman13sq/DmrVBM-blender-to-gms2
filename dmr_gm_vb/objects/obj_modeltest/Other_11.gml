/// @desc 

#region // Operators ======================================================

function OP_BindPose(button)
{
	with obj_curly
	CalculateAnimationPose(
		vbx_model.bone_parentindices,
		vbx_model.bone_localmatricies,
		vbx_model.bone_inversematricies,
		array_create(200, matrix_build_identity()),
		matpose
		);
}

function OP_MeshVisibility(button)
{
	var i = button.vbindex;
	with obj_curly
	meshvisible = button.value? (meshvisible | (1<<i)): (meshvisible & ~(1<<i));
}

function OP_TogglePlayback(button)
{
	button.Label(button.value? "Stop Animation": "Play Animation");
	with obj_curly
	isplaying = button.value;
}

function OP_DmShine(btn) {obj_curly.dm_shine = btn.value;}
function OP_DmEmission(btn) {obj_curly.dm_emission = btn.value;}
function OP_DmSSS(btn) {obj_curly.dm_sss = btn.value;}

function OP_FieldOvView(btn) {obj_curly.camera = btn.value;}

function OP_ReloadPoses(btn) {with obj_curly ReloadPoses();}

function OP_LoadVBX(btn) 
{
	var _fname = get_open_filename("*.vbx", "curly.vbx");
	if _fname != ""
	{
		var _vbx = LoadVBX(_fname, RENDERING.vbformat.rigged);
		if _vbx
		{
			VBXFree(obj_curly.vbx_model);
			obj_curly.vbx_model = _vbx;
		}
	}
}

#endregion

#region // Layout =============================================================

layout_model = new Layout()
	.SetPosXY(camera.width-200, 16, camera.width-16, 2)
layout_model.common.uiscale = 1;

layout_model.Button().Label("Open VBX").Operator(OP_LoadVBX);

var b = layout_model.Box();
b.Label("Model");

var el;
var _vbx = curly.vbx_model;
for (var i = 0; i < _vbx.vbcount; i++)
{
	el = b.Bool().Label(_vbx.vbnames[i]).Operator(OP_MeshVisibility);
	el.vbindex = i;
	el.Value(curly.meshvisible & (1<<i));
}

//b.List();

layout_model.Button().Label("Bind Pose").Operator(OP_BindPose);
layout_model.Button().SetIDName("toggleplayback")
	.Operator(OP_TogglePlayback).Value(curly.isplaying).toggle_on_click = 1;
layout_model.Button().Label("Reload Poses").Operator(OP_ReloadPoses);

var d = layout_model.Dropdown().Label("Shader Uniforms");
d.Real().Label("Shine").SetBounds(0, 1, 0.1)
	.Operator(OP_DmShine).Value(dm_shine).operator_on_change=true;
d.Real().Label("Fake SSS").SetBounds(0, 1, 0.1)
	.Operator(OP_DmSSS).Value(dm_sss).operator_on_change=true;
d.Real().Label("Emission").SetBounds(0, 1, 0.1)
	.Operator(OP_DmEmission).Value(dm_emission).operator_on_change=true;

#endregion
