/// @desc Methods + Operators

// Inherit the parent event
event_inherited();

function OP_MeshSelect(value, btn)
{
	meshselect = value;
	layout.FindElement("meshvisible").DefineControl(self, "meshvisible", value);
	meshflash[meshselect] = demo.flashtime;
}

function OP_ToggleAllVisibility(value, btn)
{
	var n = array_length(meshvisible);
	for (var i = 0; i < n; i++)
	{
		if meshvisible[i]
		{
			ArrayClear(meshvisible, 0);
			return;
		}
	}
	
	ArrayClear(meshvisible, 1);
}
