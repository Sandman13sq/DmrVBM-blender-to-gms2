/// @desc 

#region // Operators ======================================================

function OP_BindPose(button)
{
	with obj_modeltest
	CalculateAnimationPose(
		vbx.bone_parentindices,
		vbx.bone_localmatricies,
		vbx.bone_inversematricies,
		array_create(200, matrix_build_identity()),
		matpose
		);
}

function OP_MeshVisibility(button)
{
	var i = button.vbindex;
	with obj_modeltest
	vbxvisible = button.value? (vbxvisible | (1<<i)): (vbxvisible & ~(1<<i));
}

function OP_TogglePlayback(button)
{
	button.Label(button.value? "Stop Animation": "Play Animation");
	with obj_modeltest
	isplaying = button.value;
}

function OP_DmShine(btn) {obj_modeltest.dm_shine = btn.value;}
function OP_DmEmission(btn) {obj_modeltest.dm_emission = btn.value;}
function OP_DmSSS(btn) {obj_modeltest.dm_sss = btn.value;}

function OP_FieldOvView(btn) {obj_modeltest.camera = btn.value;}

function OP_LoadVBX(btn) 
{
	var _fname = get_open_filename("*.vbx", "curly.vbx");
	if _fname != ""
	{
		var _vbx = LoadVBX(_fname, obj_modeltest.vbf_rigged);
		if _vbx
		{
			VBXFree(obj_modeltest.vbx);
			obj_modeltest.vbx = _vbx;
		}
	}
}

#endregion

#region // Layout =============================================================

layout_model = new Layout()
	.SetPosXY(camerawidth-200, 16, camerawidth-16, 2)
layout_model.common.uiscale = 1;

layout_model.Button().Label("Open VBX").Operator(OP_LoadVBX);

var b = layout_model.Box();
b.Label("Model");

var el;
for (var i = 0; i < vbx.vbcount; i++)
{
	el = b.Bool().Label(vbx.vbnames[i]).Operator(OP_MeshVisibility);
	el.vbindex = i;
	el.Value(vbxvisible & (1<<i));
}

layout_model.Button().Label("Bind Pose").Operator(OP_BindPose);
layout_model.Button().SetIDName("toggleplayback")
	.Operator(OP_TogglePlayback).Value(isplaying).toggle_on_click = 1;

var d = layout_model.Dropdown().Label("Shader Uniforms");
d.Real().Label("Shine").SetBounds(0, 1, 0.1)
	.Operator(OP_DmShine).Value(dm_shine).operator_on_change=true;
d.Real().Label("Fake SSS").SetBounds(0, 1, 0.1)
	.Operator(OP_DmSSS).Value(dm_sss).operator_on_change=true;
d.Real().Label("Emission").SetBounds(0, 1, 0.1)
	.Operator(OP_DmEmission).Value(dm_emission).operator_on_change=true;

#endregion
