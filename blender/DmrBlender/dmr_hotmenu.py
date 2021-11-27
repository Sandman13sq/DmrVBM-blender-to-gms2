import bpy

classlist = [];

class Dmr_HotMenu(bpy.types.Panel): # ------------------------------
    bl_label = "Dmr Hot Menu"
    bl_idname = "DMR_PT_HOTMENU"
    bl_space_type = 'VIEW_3D'
    bl_region_type = 'UI'
    bl_category = "Item" # Name of sidebar
    
    def draw(self, context):
        active = bpy.context.active_object;
        layout = self.layout;
        rd = context.scene.render;
        row = layout.row(align = 0);
        row.scale_x = 2.0;
        row.scale_y = 1.0;
        row.alignment = 'CENTER';
        row.column().operator(
            'dmr.toggle_editmode_weights', icon = 'MOD_VERTEX_WEIGHT', text = '', 
            emboss=active.mode=='EDIT' if active else 0);
        
        c = row.row(align = 1);
        c.operator('dmr.reset_3dcursor', icon = 'PIVOT_CURSOR', text = '');
        c = c.column(align = 1)
        c.operator('dmr.zero_3dcursor_x', text = 'x');
        c.scale_x = 0.05;
        
        row.column().operator('dmr.toggle_pose', icon = 'ARMATURE_DATA', text = '');
        
        row.column().operator('dmr.image_reload', icon = 'IMAGE_DATA', text = '');
        
        row.column().operator('dmr.toggle_mirror_modifier', icon = 'MOD_MIRROR', text = '');
        
        row = layout.row(align = 0);
        row.scale_x = 2.0;
        row.scale_y = 1.0;
        row.alignment = 'CENTER';
        row.column().prop(rd, "use_simplify", text="Simplify");
        if context.object:
            row.column().prop(context.object, "show_wire", text="Wireframe")

classlist.append(Dmr_HotMenu);

def register():
    for c in classlist:
        bpy.utils.register_class(c)
    
    bpy.types.Scene.dmr_syncplaybackframes = bpy.props.BoolProperty(
        name="Sync Playback Frames to Action", default = 0
    );

def unregister():
    for c in classlist:
        bpy.utils.unregister_class(c)

