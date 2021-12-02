import bpy

from bpy.types import Header, Menu, Panel, UIList, Operator
from rna_prop_ui import PropertyPanel

classlist = [];

class Dmr_EditModeVertexGroups(bpy.types.Panel): # ------------------------------
    bl_label = "Vertex Groups"
    bl_idname = "DMR_PT_EditModeVertexGroups"
    bl_space_type = 'VIEW_3D'
    bl_region_type = 'UI'
    bl_category = "Dmr Edit" # Name of sidebar
    
    @classmethod 
    def poll(self, context):
        active = context.active_object;
        if active:
            if active.type == 'MESH':
                return 1;
        return None;
    
    def draw(self, context):
        active = context.active_object;
        
        group_select_mode = 'ALL';
        if active \
        and 'ARMATURE' in [m.type for m in active.modifiers]:
            group_select_mode = 'BONE_DEFORM';
        
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
        sub = layout.column(align=1);
        row = sub.row(align = 1);
        row.operator('dmr.add_missing_group', text = "Add Right");
        row.operator('dmr.remove_right_groups', text = "Remove Right");
        row = sub.row(align = 1);
        r = row.row(align=1);
        r.scale_x = 0.8;
        op = r.operator('object.vertex_group_clean', text = "Clean");
        op.group_select_mode = group_select_mode;
        op.limit = 0.025;
        op.keep_single = True;
        op = r.operator('object.vertex_group_limit_total', text = "Limit");
        op.group_select_mode = group_select_mode;
        r = sub.row(align=1);
        op = r.operator('object.vertex_group_normalize_all', text = "Normalize All");
        op.group_select_mode = group_select_mode;
        op.lock_active = False;
        r.operator('dmr.remove_empty_groups', text='Remove Empty');
        
        if active.mode != 'EDIT' and active.mode != 'WEIGHT_PAINT':
            return;
        
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
            
            sub = layout.column(align=1);
            r = sub.row(align=1);
            r.prop(context.tool_settings, 'vertex_group_subset', text = '');
            r.prop(context.scene, "hiderightgroups", text='');
            activevert = [x for x in ob.data.vertices if x.select];
            if activevert:
                activevert = activevert[0];
                groups = activevert.groups[:];
                vgroups = ob.vertex_groups;
                toolsubset = context.tool_settings.vertex_group_subset;
                
                if context.scene.hiderightgroups:
                    targetright = ['.r', '_r', '.R', '_R'];
                    groups = [vge for vge in groups if vgroups[vge.group].name[-2:] not in targetright];
                
                m = [x for x in ob.modifiers if (x.type == 'ARMATURE' and x.object)];
                if m:
                    bonenames = [b.name for b in m[0].object.data.bones];
                    
                    if toolsubset == 'BONE_DEFORM':
                        groups = [vge for vge in groups if vgroups[vge.group].name in bonenames];
                    elif toolsubset == 'OTHER_DEFORM':
                        groups = [vge for vge in groups if vgroups[vge.group].name not in bonenames];
                    else:
                        groups.sort(key = lambda vge: vgroups[vge.group].name not in bonenames);
                
                for vge in groups:
                    r = sub.row(align=1);
                    r.operator('object.vertex_weight_set_active', text=vgroups[vge.group].name).weight_group=vge.group;
                    r.prop(vge, 'weight', text='');
                    r.operator('object.vertex_weight_paste', text='', icon='PASTEDOWN').weight_group=vge.group;
                    r.operator('object.vertex_weight_delete', text='', icon='X').weight_group=vge.group;

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
    
    bpy.types.Scene.hiderightgroups = bpy.props.BoolProperty(
        name="Hide Right Vertex Groups",
        description="Hides right vertex groups from displaying.",
        default=False,
    );
    
    #bpy.types.VIEW3D_MT_edit_mesh_context_menu.prepend(menu_func);

def unregister():
    for c in classlist:
        bpy.utils.unregister_class(c)
