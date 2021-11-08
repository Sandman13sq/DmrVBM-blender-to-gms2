import bpy
import mathutils

classlist = [];


class DMR_SELECTBYVERTEXCOLOR(bpy.types.Operator):
    bl_label = "Select by Vertex Color"
    bl_idname = 'dmr.select_vertex_color'
    bl_description = 'Select similar vertices/faces by vertex color';
    bl_options = {'REGISTER', 'UNDO'};
    
    thresh : bpy.props.FloatProperty(
        name="Matching Threshold",
        soft_min=0.0,
        soft_max=1.0,
        default = 0.01
    );
    
    def execute(self, context):
        lastobjectmode = bpy.context.active_object.mode;
        bpy.ops.object.mode_set(mode = 'OBJECT'); # Update selected
        
        for obj in context.selected_objects:
            if obj.type != 'MESH':
                continue;
            
            mesh = obj.data;
            
            if not mesh.vertex_colors:
                self.report({'WARNING'}, 'No vertex color data found for "%s"' % obj.name);
                continue;
            
            vcolors = mesh.vertex_colors.active.data;
            loops = mesh.loops;
            vertexmode = 0;
            
            targetpolys = [poly for poly in mesh.polygons if poly.select];
            if targetpolys:
                targetloops = [l for p in targetpolys for l in loops[p.loop_start:p.loop_start + p.loop_total]];
                vertexmode = 0;
            else:
                targetloops = [l for l in loops if mesh.vertices[l.vertex_index].select];
                vertexmode = 1;
            
            if len(targetloops) > 0:
                netcolor = [0.0, 0.0, 0.0, 0.0];
                netcount = len(targetloops);
                thresh = self.thresh;
                thresh *= thresh;
                for l in targetloops:
                    color = vcolors[l.index].color;
                    netcolor[0] += color[0];
                    netcolor[1] += color[1];
                    netcolor[2] += color[2];
                    netcolor[3] += color[3];
                netcolor[0] /= netcount;
                netcolor[1] /= netcount;
                netcolor[2] /= netcount;
                netcolor[3] /= netcount;
                print('net: %s' % netcolor)
                nr = netcolor[0];
                ng = netcolor[1];
                nb = netcolor[2];
                na = netcolor[3];
                
                # Faces
                if vertexmode == 0:
                    for f in mesh.polygons:
                        c2 = [0]*4;
                        for l in f.loop_indices:
                            vc = vcolors[loops[l].index].color;
                            c2[0] += vc[0];
                            c2[1] += vc[1];
                            c2[2] += vc[2];
                            c2[3] += vc[3];
                        c2 = [x / len(f.loop_indices) for x in c2];
                        r = c2[0]-nr;
                        g = c2[1]-ng;
                        b = c2[2]-nb;
                        a = c2[3]-na;
                        r*=r; g*=g; b*=b; a*=a;
                        if (r<=thresh and g<=thresh and b<=thresh and a<=thresh):
                            f.select = 1;
                # Vertices
                else:
                    for l in [x for x in loops if x not in targetloops]:
                        c2 = vcolors[l.index].color;
                        r = c2[0]-nr;
                        g = c2[1]-ng;
                        b = c2[2]-nb;
                        a = c2[3]-na;
                        r*=r; g*=g; b*=b; a*=a;
                        if (r<=thresh and g<=thresh and b<=thresh and a<=thresh):
                            mesh.vertices[l.vertex_index].select = 1;
        
        bpy.ops.object.mode_set(mode = lastobjectmode); # Return to last mode
        return {'FINISHED'}
classlist.append(DMR_SELECTBYVERTEXCOLOR);

class DMR_SETVERTEXCOLOR(bpy.types.Operator):
    bl_label = "Set Vertex Color"
    bl_idname = 'dmr.set_vertex_color'
    bl_description = 'Sets vertex color for selected vertices/faces';
    bl_options = {'REGISTER', 'UNDO'};
    
    mixamount : bpy.props.FloatProperty(
        name="Mix Amount",
        soft_min=0.0,
        soft_max=1.0,
        default=1.0
    );
    
    def execute(self, context):
        lastobjectmode = bpy.context.active_object.mode;
        bpy.ops.object.mode_set(mode = 'OBJECT'); # Update selected
        
        for obj in [x for x in context.selected_objects] + [context.object]:
            if obj.type != 'MESH': 
                continue;
            
            mesh = obj.data;
            if not mesh.vertex_colors:
                mesh.vertex_colors.new();
            vcolors = mesh.vertex_colors.active.data;
            loops = mesh.loops;
            
            targetpolys = [poly for poly in mesh.polygons if poly.select];
            if targetpolys:
                targetloops = [l for p in targetpolys for l in loops[p.loop_start:p.loop_start + p.loop_total]]
            else:
                targetloops = [l for l in loops if mesh.vertices[l.vertex_index].select]
            
            amt = 1.0-self.mixamount;
            targetcolor = mathutils.Vector(bpy.context.scene.editmodecolor);
            for l in targetloops:
                vcolors[l.index].color = targetcolor.lerp(vcolors[l.index].color, amt);
        
        bpy.ops.object.mode_set(mode = lastobjectmode); # Return to last mode
        return {'FINISHED'}
classlist.append(DMR_SETVERTEXCOLOR);

class DMR_VC_ClearAlpha(bpy.types.Operator):
    bl_label = "Clear Alpha"
    bl_idname = 'dmr.vc_clear_alpha'
    bl_description = 'Sets vertex color alpha for selected vertices/faces';
    bl_options = {'REGISTER', 'UNDO'};
    
    clearvalue : bpy.props.FloatProperty(
        name="Clear Value",
        soft_min=0.0,
        soft_max=1.0
    );
    
    def execute(self, context):
        lastobjectmode = bpy.context.active_object.mode;
        bpy.ops.object.mode_set(mode = 'OBJECT'); # Update selected
        
        for obj in context.selected_objects:
            if obj.type != 'MESH': 
                continue;
            
            mesh = obj.data;
            if not mesh.vertex_colors:
                mesh.vertex_colors.new();
            vcolors = mesh.vertex_colors.active.data;
            loops = mesh.loops;
            
            targetpolys = [poly for poly in mesh.polygons if poly.select];
            if targetpolys:
                targetloops = [l for p in targetpolys for l in loops[p.loop_start:p.loop_start + p.loop_total]]
            else:
                targetloops = [l for l in loops if mesh.vertices[l.vertex_index].select]
            
            for l in targetloops:
                vcolors[l.index].color[3] = self.clearvalue;
        
        bpy.ops.object.mode_set(mode = lastobjectmode); # Return to last mode
        return {'FINISHED'}
classlist.append(DMR_VC_ClearAlpha);

# =============================================================================

class DMR_PICKVERTEXCOLOR(bpy.types.Operator):
    bl_label = "Pick Vertex Color"
    bl_idname = 'dmr.pick_vertex_color'
    bl_description = 'Gets vertex color from selected vertices/faces';
    bl_options = {'REGISTER', 'UNDO'};
    
    def execute(self, context):
        lastobjectmode = bpy.context.active_object.mode;
        bpy.ops.object.mode_set(mode = 'OBJECT'); # Update selected
        
        mesh = context.active_object.data;
        
        if not mesh.vertex_colors:
            self.report({'WARNING'}, 'No vertex color data found');
            bpy.ops.object.mode_set(mode = lastobjectmode); # Return to last mode
            return {'FINISHED'}
        
        vcolors = mesh.vertex_colors.active.data;
        loops = mesh.loops;
        
        targetpolys = [poly for poly in mesh.polygons if poly.select];
        if targetpolys:
            targetloops = [l for p in targetpolys for l in loops[p.loop_start:p.loop_start + p.loop_total]]
        else:
            targetloops = [l for l in loops if mesh.vertices[l.vertex_index].select]
        
        if len(targetloops) == 0:
            self.report({'WARNING'}, 'No vertices selected');
        else:
            netcolor = [0.0, 0.0, 0.0, 0.0];
            netcount = len(targetloops);
            for l in targetloops:
                color = vcolors[l.index].color;
                netcolor[0] += color[0];
                netcolor[1] += color[1];
                netcolor[2] += color[2];
                netcolor[3] += color[3];
            netcolor[0] /= netcount;
            netcolor[1] /= netcount;
            netcolor[2] /= netcount;
            netcolor[3] /= netcount;
            bpy.context.scene.editmodecolor = netcolor;
        
        bpy.ops.object.mode_set(mode = lastobjectmode); # Return to last mode
        return {'FINISHED'}
classlist.append(DMR_PICKVERTEXCOLOR);

# =============================================================================

class DMR_OP_QUICKDIRTYCOLORS(bpy.types.Operator):
    """Tooltip"""
    bl_idname = "dmr.quick_n_dirty"
    bl_label = "Quick Dirty Vertex Colors"
    bl_description = "Creates new vertex color slot with dirty vertex colors"
    bl_options = {'REGISTER', 'UNDO'};
    
    def execute(self, context):
        bpy.ops.object.mode_set(mode = 'OBJECT');
        
        objs = [x for x in context.selected_objects]
        bpy.ops.object.select_all(action='DESELECT');
        oldactive = bpy.context.view_layer.objects.active;
        
        for obj in objs:
            if obj.type == 'MESH':
                # Get 'dirty' group
                vcolors = obj.data.vertex_colors;
                if 'dirty' not in vcolors.keys():
                    vcolors.new(name = 'dirty');
                vcolorgroup = vcolors['dirty'];
                vcolors.active_index = vcolors.keys().index('dirty');
                
                # Set dirt
                bpy.context.view_layer.objects.active = obj;
                bpy.ops.object.mode_set(mode = 'VERTEX_PAINT');
                oldselmode = bpy.context.object.data.use_paint_mask_vertex;
                bpy.context.object.data.use_paint_mask_vertex = True;
                selected = [x for x in obj.data.vertices if x.select];
                
                bpy.ops.paint.vert_select_all(action='SELECT');
                bpy.ops.paint.vertex_color_brightness_contrast(brightness=100); # Clear with White
                bpy.ops.paint.vertex_color_dirt(
                    blur_strength=1, blur_iterations=1, 
                    clean_angle=3.14159, dirt_angle=0, dirt_only=False, normalize=True)

                bpy.ops.paint.vert_select_all(action='DESELECT');
                
                for x in selected:
                    x.select = 1;
                bpy.context.object.data.use_paint_mask_vertex = oldselmode;
                bpy.ops.object.mode_set(mode = 'OBJECT');
        
        for obj in objs:
            obj.select_set(1);
        bpy.context.view_layer.objects.active = oldactive;
            
        return {'FINISHED'}
classlist.append(DMR_OP_QUICKDIRTYCOLORS);

# =============================================================================

def register():
    for c in classlist:
        bpy.utils.register_class(c)

def unregister():
    for c in classlist:
        bpy.utils.unregister_class(c)
