/// @desc Various constants

// Enum for virtual keys
enum VKey
{
	space = 32,
	
	_0 = 48, _1, _2, _3, _4, _5, _6, _7, _8, _9,
	
	at = 64,
	A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R, S, T, U, V, W, X, Y, Z,
	a = VKey.A, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z,
	
	bracketOpen = 219,	// [ {
	bracketClose = 221,	// ] }
	
	colon = 186, // :
	quote = 222, // "
	
	lessThan = 188, // <
	greaterThan = 190, // >
	
	plus = 187, equals = VKey.plus, // + =
	minus = 189, underscore = VKey.minus, // - _
	
	tilde = 192, grave = VKey.tilde,
	pipe = 220,
	
	left = vk_left, up = vk_up, right = vk_right, down = vk_down,
}

