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
        for o in context.scene.objects:
            if o.type == 'ARMATURE':
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

class DMR_FIXRIGHTBONESNAMES(bpy.types.Operator):
    """Tooltip"""
    bl_label = "Fix Right Bone Names"
    bl_idname = 'dmr.fix_right_bone_names'
    bl_description = "Corrects newly created right side bones' names to their left counterpart";
    bl_options = {'REGISTER', 'UNDO'}
    
    @classmethod
    def poll(cls, context):
        return (context.object is not None and
                context.object.type == 'ARMATURE' and
                context.object.data.is_editmode)
    
    def execute(self, context):
        active = bpy.context.view_layer.objects.active;
        if active:
            lastobjectmode = bpy.context.active_object.mode;
            bpy.ops.object.mode_set(mode = 'OBJECT'); # Update selected
            
            bones = active.data.bones;
            thresh = 0.01;
            leftbones = [b for b in bones if b.head_local[0] >= thresh];
            rightbones = [b for b in bones if b.head_local[0] <= -thresh];
            for b in rightbones:
                loc = b.head_local.copy();
                loc[0] *= -1;
                currdist = 100;
                currbone = None;
                for b2 in leftbones:
                    b2dist = (b2.head_local - loc).length;
                    if b2dist < currdist:
                        currbone = b2;
                        currdist = b2dist;
                        print('Currbone = %s (%s)' % (b2.name, b2dist))
                if currbone != None:
                    print('%s -> %s' % (b.name, currbone.name))
                    b.name = currbone.name[:-2] + '_r';
            bpy.ops.object.mode_set(mode = lastobjectmode);
                        
        return {'FINISHED'}
classlist.append(DMR_FIXRIGHTBONESNAMES);

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

def register():
    for c in classlist:
        bpy.utils.register_class(c)

def unregister():
    for c in classlist:
        bpy.utils.unregister_class(c)
