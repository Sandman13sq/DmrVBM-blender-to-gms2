import bpy
import bmesh

from bpy.props import StringProperty, BoolProperty, EnumProperty

classlist = [];

class DMR_SculptMaskFromVGroup(bpy.types.Operator):
    bl_label = "Mask from Vertex Group"
    bl_idname = 'dmr.sculpt_mask_from_vgroup'
    bl_description = 'Masks out vertices in vertex group';
    bl_options = {'REGISTER', 'UNDO'};
    
    clearbefore: BoolProperty(
        name="Clear Before Mask",
        description="Clear present mask before masking group",
        default=True,
    );
    
    insidegroup: BoolProperty(
        name="Mask Group",
        description="Mask vertices inside of group to focus on those outside",
        default=False,
    );
    
    def execute(self, context):
        lastobjectmode = bpy.context.active_object.mode;
        bpy.ops.object.mode_set(mode = 'OBJECT'); # Update selected
        
        obj = context.object;
        mesh = obj.data;
        verts = mesh.vertices;
        vgroups = obj.vertex_groups;
        vgroupindex = vgroups.active.index;
        
        bm = bmesh.new();
        bm.from_mesh(mesh);
        
        if not bm.verts.layers.paint_mask:
            bm.verts.layers.paint_mask.new();
        masklayer = bm.verts.layers.paint_mask[0];
        
        maskvalue = 1.0 if self.insidegroup else 0.0;
        
        for bmvert, v in zip(bm.verts, verts):
            if vgroupindex in [g.group for g in v.groups]:
                bmvert[masklayer] = maskvalue;
            elif self.clearbefore:
                bmvert[masklayer] = 1.0 - maskvalue;
        
        bm.to_mesh(mesh);
        bm.clear();
        mesh.update();
        
        bpy.ops.object.mode_set(mode = lastobjectmode); # Return to last mode
        if lastobjectmode == 'SCULPT':
            bpy.context.scene.tool_settings.sculpt.show_mask = True;
        return {'FINISHED'}
classlist.append(DMR_SculptMaskFromVGroup);

# =============================================================================

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

def register():
    for c in classlist:
        bpy.utils.register_class(c)

def unregister():
    for c in classlist:
        bpy.utils.unregister_class(c)
