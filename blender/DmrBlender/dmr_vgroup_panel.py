import bpy

from bpy.types import Header, Menu, Panel, UIList, Operator
from rna_prop_ui import PropertyPanel

classlist = [];

class Dmr_EditModeVertexGroups(bpy.types.Panel): # ------------------------------
    bl_label = "Vertex Groups"
    bl_idname = "DMR_PT_EditModeVertexGroups"
    bl_space_type = 'VIEW_3D'
    bl_region_type = 'UI'
    bl_category = "Edit" # Name of sidebar
    
    @classmethod 
    def poll(self, context):
        active = context.active_object;
        if active:
            if active.type == 'MESH':
                if active.mode == 'EDIT' or active.mode == 'WEIGHT_PAINT':
                    return 1;
        return None;
    
    def draw(self, context):
        active = context.active_object;
        
        layout = self.layout;
        layout.operator(
            'dmr.toggle_editmode_weights', icon = 'MOD_VERTEX_WEIGHT');
        
        rightexists = 0;
        buttonname = 'Add Right Groups';
        for name in active.vertex_groups.keys():
            if name[-2:] == '_r' or name[-2:] == '.r':
                rightexists = 1;
                buttonname = 'Remove Right Groups'
                break;
        row = layout.row(align = 1);
        row.operator('dmr.add_missing_group', text = "Add Right");
        row.operator('dmr.remove_right_groups', text = "Remove Right");
        row = layout.row(align = 1);
        op = row.operator('object.vertex_group_clean', text = "Clean");
        op.group_select_mode = 'ALL';
        op.limit = 0.001;
        op.keep_single = True;
        op = row.operator('object.vertex_group_limit_total', text = "Limit");
        op.group_select_mode = 'ALL';
        op.limit = 4;
        
        # Vertex Group Bar
        ob = context.object
        group = ob.vertex_groups.active
        
        rows = 3
        if group:
            rows = 5

        row = layout.row()
        row.template_list("MESH_UL_vgroups", "", ob, "vertex_groups", ob.vertex_groups, "active_index", rows=rows)

        col = row.column(align=True)

        col.operator("object.vertex_group_add", icon='ADD', text="")
        props = col.operator("object.vertex_group_remove", icon='REMOVE', text="")
        props.all_unlocked = props.all = False

        col.separator()

        col.menu("MESH_MT_vertex_group_context_menu", icon='DOWNARROW_HLT', text="")

        if group:
            col.separator()
            col.operator("object.vertex_group_move", icon='TRIA_UP', text="").direction = 'UP'
            col.operator("object.vertex_group_move", icon='TRIA_DOWN', text="").direction = 'DOWN'
            col.operator("dmr.vgroup_movetoend", icon='EMPTY_SINGLE_ARROW', text="");

        if (
            ob.vertex_groups and
            (ob.mode == 'EDIT' or
            (ob.mode == 'WEIGHT_PAINT' and ob.type == 'MESH' and ob.data.use_paint_mask_vertex))
            ):
            row = layout.row()

            sub = row.column(align=0)
            sub.operator("object.vertex_group_select", text="Select", icon='RESTRICT_SELECT_OFF')
            sub.operator("object.vertex_group_deselect", text="Deselect", icon='RESTRICT_SELECT_ON')
            
            sub = row.column(align=0)
            sub.operator("object.vertex_group_assign", text="Assign", icon='ADD')
            sub = sub.row(align=1);
            sub.operator("object.vertex_group_remove_from", text="Remove", icon='REMOVE')
            sub.operator("dmr.remove_from_selected_bones", text="", icon='BONE_DATA')
            sub.operator("object.vertex_group_remove_from", text="", icon='WORLD').use_all_groups=True
            
            layout.prop(context.tool_settings, "vertex_group_weight", text="Weight")

classlist.append(Dmr_EditModeVertexGroups);

class VIEW3D_MT_edit_mesh_VGMenu(bpy.types.Menu):
    bl_label = "Dmr Vertex Group Menu"
    
    def draw(self, context):
        layout = self.layout
        layout.operator("wm.open_mainfile")
        layout.operator("wm.save_as_mainfile")


# draw function for integration in menus
def menu_func(self, context):
    self.layout.menu("VIEW3D_MT_edit_mesh_VGMenu");
    #self.layout.separator();

#classlist.append(VIEW3D_MT_edit_mesh_VGMenu);

def register():
    for c in classlist:
        bpy.utils.register_class(c)
    #bpy.types.VIEW3D_MT_edit_mesh_context_menu.prepend(menu_func);

def unregister():
    for c in classlist:
        bpy.utils.unregister_class(c)
