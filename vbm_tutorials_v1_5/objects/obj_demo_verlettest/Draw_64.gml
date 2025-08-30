/// @desc Draw Info

var xx = 16, yy = 100, ysep = 16;

draw_text(xx,yy, "Time Factor: " + string(time_factor)); yy += ysep;
yy += ysep;
draw_text(xx,yy, "Limit: " + string([limit, lerp(0, 1, limit*2.0-1.0)])); yy += ysep;
draw_text(xx,yy, "Dot P: " + string([dot_result, dot_result*0.5+0.5, (dot_result*0.5+0.5)<limit])); yy += ysep;
draw_text(xx,yy, "Dot X: " + string([dot_cross, dot_cross*0.5+0.5])); yy += ysep;
draw_text(xx,yy, "F = " + string([fx,fy,fz])); yy += ysep;
draw_text(xx,yy, "D = " + string([dx,dy,dz])); yy += ysep;
draw_text(xx,yy, "P = " + string([px,py,pz])); yy += ysep;
draw_text(xx,yy, "L = " + string([lx,ly,lz])); yy += ysep;

