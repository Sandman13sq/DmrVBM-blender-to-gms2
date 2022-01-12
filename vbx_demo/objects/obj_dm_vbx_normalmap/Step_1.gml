/// @desc Update Select Flash

// Inherit the parent event
event_inherited();

// Mesh Select Flash
var n = array_length(meshflash);
for (var i = 0; i < n; i++)
{
	meshflash[i] = max(0, meshflash[i]-1);
}
