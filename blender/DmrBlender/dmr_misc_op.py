import bpy

classlist = [];

# =============================================================================

class DMR_RESET3DCURSOR(bpy.types.Operator):
    bl_label = "Reset 3D Cursor"
    bl_idname = 'dmr.reset_3dcursor'
    bl_description = 'Resets 3D cursor to (0, 0, 0)';
    
    def execute(self, context):
        context.scene.cursor.location = (0.0, 0.0, 0.0);
        return {'FINISHED'}
classlist.append(DMR_RESET3DCURSOR);

# =============================================================================

class DMR_RESET3DCURSORX(bpy.types.Operator):
    bl_label = "Zero 3D Cursor X"
    bl_idname = 'dmr.zero_3dcursor_x'
    bl_description = 'Resets x coordinate of 3D Cursor';
    
    def execute(self, context):
        context.scene.cursor.location[0] = 0.0;
        return {'FINISHED'}
classlist.append(DMR_RESET3DCURSORX);

# =============================================================================

class DMR_EDITMODEWEIGHTS(bpy.types.Operator):
    bl_label = "Toggle Edit Mode Weights"
    bl_idname = 'dmr.toggle_editmode_weights'
    bl_description = 'Toggles Weight Display for Edit Mode';
    bl_options = {'REGISTER', 'UNDO'}
    
    def execute(self, context):
        bpy.context.scene.tool_settings.vertex_group_user = 'ALL';
        bpy.context.space_data.overlay.show_weight = not bpy.context.space_data.overlay.show_weight;
        
        return {'FINISHED'}
classlist.append(DMR_EDITMODEWEIGHTS);

# =============================================================================

class DMR_TOGGLEPOSE(bpy.types.Operator):
    bl_label = "Toggle Pose Mode"
    bl_idname = 'dmr.toggle_pose'
    bl_description = 'Toggles Pose Mode for all armatures';
    bl_options = {'REGISTER', 'UNDO'}
    
    def execute(self, context):
        checked = [];
        
        for o in context.scene.objects:
            if o.type == 'ARMATURE':
                if o.data in checked:
                    continue;
                checked.append(o.data);
                
                armature = o.data;
                if armature.pose_position == 'REST':
                    armature.pose_position = 'POSE';
                else:
                    armature.pose_position = 'REST'
        return {'FINISHED'}
classlist.append(DMR_TOGGLEPOSE);

# =============================================================================

class DMR_TOGGLEPOSEPARENT(bpy.types.Operator):
    bl_label = "Toggle Pose Mode Parent"
    bl_idname = 'dmr.toggle_pose_parent'
    bl_description = "Toggles Pose Mode for current armature or active object's parent armature";
    bl_options = {'REGISTER', 'UNDO'}
    
    def execute(self, context):
        active = bpy.context.active_object;
        armature = None;
        
        # Find Armature (of active or active's parent)
        if active:
            if active.type == 'ARMATURE': armature = active;
            elif active.parent:
                if active.parent.type == 'ARMATURE': armature = active.parent;
            elif active.type in ['MESH']:
                if active.modifiers:
                    for m in active.modifiers:
                        if m.type == 'ARMATURE':
                            if m.object and m.object.type == 'ARMATURE':
                                armature = m.object;
        
        if armature:
            if armature.data.pose_position == 'REST':
                armature.data.pose_position = 'POSE';
            else:
                armature.data.pose_position = 'REST';
        return {'FINISHED'}
classlist.append(DMR_TOGGLEPOSEPARENT);

# =============================================================================

class DMR_PLAYANIM(bpy.types.Operator):
    bl_label = "Play/Pause Animation"
    bl_idname = 'dmr.play_anim'
    bl_description = 'Toggles animation playback';
    
    def execute(self, context):
        bpy.ops.screen.animation_play();
        return {'FINISHED'}
classlist.append(DMR_PLAYANIM);

# =============================================================================

class DMR_IMGRELOAD(bpy.types.Operator):
    bl_label = "Reload All Images"
    bl_idname = 'dmr.image_reload'
    bl_description = 'Reloads all images from files';
    
    def execute(self, context):
        for image in bpy.data.images:
            image.reload()
        
        return {'FINISHED'}
classlist.append(DMR_IMGRELOAD);

# =============================================================================

class DMR_QuickAutoSmooth(bpy.types.Operator):
    """Tooltip"""
    bl_label = "Quick Auto Smooth"
    bl_idname = 'dmr.quick_auto_smooth'
    bl_description = "Turns on auto smooth and sets angle to 180 degrees for selected objects";
    bl_options = {'REGISTER', 'UNDO'}
    
    @classmethod
    def poll(cls, context):
        return (context.object is not None)
    
    def execute(self, context):
        for obj in context.selected_objects:
            if obj.type == 'MESH':
                obj.data.use_auto_smooth = 1;
                obj.data.auto_smooth_angle = 3.14159;
                for p in obj.data.polygons:
                    p.use_smooth = 1;
                        
        return {'FINISHED'}
classlist.append(DMR_QuickAutoSmooth);

# =============================================================================

class DMR_PlaybackRangeFromAction(bpy.types.Operator):
    """Tooltip"""
    bl_label = "Playback Range from Action"
    bl_idname = 'dmr.playback_range_from_action'
    bl_description = "Sets playback range to range of keyframes for action";
    bl_options = {'REGISTER', 'UNDO'}
    
    @classmethod
    def poll(cls, context):
        return (context.object is not None)
    
    def execute(self, context):
        obj = context.object;
        if obj:
            if obj.animation_data:
                action = obj.animation_data.action;
                framerange = action.frame_range;
                context.scene.frame_start = framerange[0]+1;
                context.scene.frame_end = framerange[1]-1;
                        
        return {'FINISHED'}
classlist.append(DMR_PlaybackRangeFromAction);

# =============================================================================

class DMR_ToggleMirror(bpy.types.Operator):
    """Tooltip"""
    bl_label = "Toggle Mirror Modifier"
    bl_idname = 'dmr.toggle_mirror_modifier'
    bl_description = "Toggles all mirror modifiers";
    bl_options = {'REGISTER', 'UNDO'}
    
    @classmethod
    def poll(cls, context):
        return (context.object is not None)
    
    def execute(self, context):
        for obj in bpy.data.objects:
            if obj.hide_viewport:
                continue;
            if obj.type == 'MESH':
                if obj.modifiers:
                    for m in obj.modifiers:
                        if m.type == 'MIRROR':
                            m.show_viewport = not m.show_viewport;
                    
                        
        return {'FINISHED'}
classlist.append(DMR_ToggleMirror);

# =============================================================================

class DMR_RenameNodeInput(bpy.types.Operator):
    bl_label = "Rename Node Input"
    bl_idname = 'dmr.rename_node_input'
    bl_options = {'REGISTER', 'UNDO'}
    
    ioindex : bpy.props.EnumProperty(
        name="Target Input",
        description="Name of input to rename",
        items=lambda s, context: [
            ( (str(i), '[%d]: %s' % (i, io.name), 'Rename input %d "%s"' % (i, io.name)) )
            for i, io in enumerate(context.active_node.inputs)
        ]);
    
    newname : bpy.props.StringProperty(
        name="New Name", description="New name of input", default='New Name');
    
    def invoke(self, context, event):
        if context.active_node == None:
            self.report({'WARNING'}, 'No active node');
            return {'FINISHED'}
        return context.window_manager.invoke_props_dialog(self);
    
    def execute(self, context):
        [x for x in context.active_node.inputs][int(self.ioindex)].name = self.newname;
        return {'FINISHED'}
classlist.append(DMR_RenameNodeInput);

# =============================================================================

class DMR_RenameNodeOutput(bpy.types.Operator):
    bl_label = "Rename Node Output"
    bl_idname = 'dmr.rename_node_output'
    bl_options = {'REGISTER', 'UNDO'}
    
    ioindex : bpy.props.EnumProperty(
        name="Target Output",
        description="Name of output to rename",
        items=lambda s, context: [
            ( (str(i), '[%d]: %s' % (i, io.name), 'Rename output %d "%s"' % (i, io.name)) )
            for i, io in enumerate(context.active_node.outputs)
        ]);
    
    newname : bpy.props.StringProperty(
        name="New Name", description="New name of output", default='New Name');
    
    def invoke(self, context, event):
        if context.active_node == None:
            self.report({'WARNING'}, 'No active node');
            return {'FINISHED'}
        return context.window_manager.invoke_props_dialog(self);
    
    def execute(self, context):
        [x for x in context.active_node.outputs][int(self.ioindex)].name = self.newname;
        return {'FINISHED'}
classlist.append(DMR_RenameNodeOutput);

# =============================================================================

def register():
    for c in classlist:
        bpy.utils.register_class(c)

def unregister():
    for c in classlist:
        bpy.utils.unregister_class(c)
