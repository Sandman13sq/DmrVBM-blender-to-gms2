/// @desc 

event_inherited();

if (keyboard_check(vk_add) || keyboard_check(187)) {transitionblend = min(1.0, transitionblend+0.02);}
if (keyboard_check(vk_subtract) || keyboard_check(189)) {transitionblend = max(0.0, transitionblend-0.02);}

// Switch between matrices and track evaluation
if (keyboard_check_pressed(vk_space)) {playbackmode ^= 1;}

// Change animation
if (keyboard_check_pressed(ord("Z"))) 
{
	animationindex = (animationindex+1) mod array_length(animationkeys);
	trkanimator.SetAnimationKey(animationkeys[animationindex]);
}

// Progress Playback
trkanimator.UpdateAnimation(1);

mattran = Mat4Rotate(0, 0, trkanimator.CurveValue("spin", 0));

