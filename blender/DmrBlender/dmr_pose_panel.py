import bpy
import sys

classlist = [];

class DmrToolsPanel_PoseNav(bpy.types.Panel): # ------------------------------
    bl_label = "Pose Navigation"
    bl_idname = "DMR_PT_POSENAV"
    bl_space_type = 'VIEW_3D'
    bl_region_type = 'UI'
    bl_category = "Pose" # Name of sidebar
    
    def draw(self, context):
        active = bpy.context.active_object;
        
        # Fetch Armature (of active or active's parent)
        am = active; # Starting object
        if am and am.type != 'ARMATURE':
            if am.parent and am.parent.type == 'ARMATURE': am = am.parent;
            elif am.type in ['MESH'] and am.modifiers:
                ammod = [x for x in am.modifiers if x.type == 'ARMATURE'];
                if ammod: am = ammod[0].object;
        armature = None if (am and am.type != 'ARMATURE') else am;
        
        ineditmode = armature.mode if armature else 0;
        objecttype = armature.type if armature else 'NULL';
        
        layout = self.layout;
        
        if objecttype == 'ARMATURE':
            section = layout.column();
            #section.prop(armature, "pose_position", expand=0)
            
            # Toggle Pose
            row = section.row();
            if armature.data.pose_position == 'POSE':
                row.operator('dmr.toggle_pose_parent', text='Rest Position', icon='POSE_HLT');
            else:
                row.operator('dmr.toggle_pose_parent', text='Pose Position', icon='ARMATURE_DATA');
            
            poselib = armature.pose_library;
            if poselib != None and poselib.pose_markers != None:
                # warning about poselib being in an invalid state
                if poselib.fcurves and not poselib.pose_markers:
                    section.label(icon='ERROR', text="Error: Potentially corrupt library, run 'Sanitize' operator to fix")
                
                row = row.row();
                row.scale_x = 0.7;
                row.prop(poselib.pose_markers, "active_index", text="");
                
                # Action Data
                section.template_ID(armature, "pose_library", new="poselib.new", unlink="poselib.unlink")
                if poselib.pose_markers.active != None:
                    poseindex = poselib.pose_markers.active_index;
                    poseactive = poselib.pose_markers.active;
                    
                    # list of poses in pose library
                    row = section.row()
                    row.template_list("UI_UL_list", "pose_markers", poselib, "pose_markers",
                                      poselib.pose_markers, "active_index", rows=5)
                    
                    # Selected Bones
                    #row = section.row();
                    row = row.column(align = 1);
                    row.operator("poselib.pose_add", icon='ADD', text="")
                    if poseactive is not None:
                        row.operator("poselib.pose_remove", icon='REMOVE', text="")
                    
                    row.operator("poselib.apply_pose", icon='ZOOM_SELECTED', text="").pose_index = poseindex;
                    row.operator("dmr.pose_replace", icon='GREASEPENCIL', text="").allbones = 0;
                    
                    # All
                    row = section.row(align=1);
                    row.operator("dmr.pose_apply", icon='ZOOM_SELECTED', text="Apply To All")
                    op = row.operator("dmr.pose_replace", icon='GREASEPENCIL', text="Write All").allbones = 1;
                    
                else:
                    row = section.row(align=1)
                    row.operator("poselib.pose_add", icon='ADD', text='Add Pose');
                    row.operator("poselib.action_sanitize", icon='HELP', text='Sanitize')
            else:
                layout.template_ID(active, "pose_library", new="poselib.new", unlink="poselib.unlink")
            
classlist.append(DmrToolsPanel_PoseNav);

# ==========================================================================

class DmrToolsPanel_BoneGroups(bpy.types.Panel): # ------------------------------
    bl_label = "Bone Groups"
    bl_idname = "DMR_PT_BONEGROUPS"
    bl_space_type = 'VIEW_3D'
    bl_region_type = 'UI'
    bl_category = "Pose" # Name of sidebar
    
    @classmethod
    def poll(cls, context):
        return (context.object is not None and
                context.object.type == 'ARMATURE' and
                context.object.mode in ['EDIT', 'POSE'])
    
    def draw(self, context):
        active = bpy.context.object;
        
        # Fetch Armature (of active or active's parent)
        am = active; # Starting object
        if am and am.type != 'ARMATURE':
            if am.parent and am.parent.type == 'ARMATURE': am = am.parent;
            elif am.type in ['MESH'] and am.modifiers:
                ammod = [x for x in am.modifiers if x.type == 'ARMATURE'];
                if ammod: am = ammod[0].object;
        armature = None if (am and am.type != 'ARMATURE') else am;
        
        ineditmode = armature.mode if armature else 0;
        objecttype = armature.type if armature else 'NULL';
        
        layout = self.layout;
        
        if objecttype == 'ARMATURE':
            section = layout.column();
            ob = active;
            pose = ob.pose;
            group = pose.bone_groups.active;

            row = layout.row();

            rows = 1;
            if group:
                rows = 4;
            row.template_list(
                "UI_UL_list", "bone_groups", pose,
                "bone_groups", pose.bone_groups,
                "active_index", rows=rows,
            );

            col = row.column(align=True)
            col.operator("pose.group_add", icon='ADD', text="")
            col.operator("pose.group_remove", icon='REMOVE', text="")
            col.menu("DATA_MT_bone_group_context_menu", icon='DOWNARROW_HLT', text="")
            if group:
                col.separator()
                col.operator("pose.group_move", icon='TRIA_UP', text="").direction = 'UP'
                col.operator("pose.group_move", icon='TRIA_DOWN', text="").direction = 'DOWN'

                split = layout.split()
                split.active = (ob.proxy is None)

                col = split.column()
                col.prop(group, "color_set")
                if group.color_set:
                    col = split.column()
                    sub = col.row(align=True)
                    sub.enabled = group.is_custom_color_set  # only custom colors are editable
                    sub.prop(group.colors, "normal", text="")
                    sub.prop(group.colors, "select", text="")
                    sub.prop(group.colors, "active", text="")

            c = layout.column()

            sub = c.row(align=True)
            sub.operator("pose.group_assign", text="Assign")
            # row.operator("pose.bone_group_remove_from", text="Remove")
            sub.operator("pose.group_unassign", text="Remove")

            sub = c.row(align=True)
            sub.operator("pose.group_select", text="Select")
            sub.operator("pose.group_deselect", text="Deselect")

            
classlist.append(DmrToolsPanel_BoneGroups);

# ==========================================================================

def register():
    for c in classlist:
        bpy.utils.register_class(c)

def unregister():
    for c in classlist:
        bpy.utils.unregister_class(c)
