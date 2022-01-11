/// @desc

// Inherit the parent event
event_inherited();

function OP_MeshVisibility(value, btn) 
{
	if value {obj_curly.meshvisible |= (1 << btn.meshindex);}
	else {obj_curly.meshvisible &= ~(1 << btn.meshindex);}
}
