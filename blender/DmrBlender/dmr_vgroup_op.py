import bpy

from bpy.types import Header, Menu, Panel, UIList, Operator
from rna_prop_ui import PropertyPanel

classlist = [];

# =============================================================================

class DMR_SELECTBYWEIGHT(bpy.types.Operator):
    bl_label = "Select by Weight"
    bl_idname = 'dmr.select_by_weight'
    bl_description = 'Selects vertices in active vertex group by weight threshold';
    bl_options = {'REGISTER', 'UNDO'}
    
    threshold : bpy.props.FloatProperty(
        name = "Weight Threshold", 
        description = "Weight value to use for comparison",
        default = 0.7, precision = 4, min = 0.0, max = 1.0);
    
    compmode : bpy.props.BoolProperty(
        name = "Select Less Than", 
        description = "Select vertices less than the threshold",
        default = False);
    
    def invoke(self, context, event):
        wm = context.window_manager;
        return wm.invoke_props_dialog(self);
    
    def draw(self, context):
        layout = self.layout;
        layout.prop(self, "threshold");
        layout.prop(self, "compmode");
    
    def execute(self, context):
        object = bpy.context.active_object;
        vgroupindex = object.vertex_groups.active.index;
        
        compmode = 0;
        threshold = self.threshold;
        
        bpy.ops.object.mode_set(mode = 'OBJECT');
        
        # Greater Than
        if compmode == 0:
            for v in object.data.vertices:
                for vge in v.groups:
                    if vge.group == vgroupindex:
                        if vge.weight >= threshold:
                            v.select = True;
                        break;
        # Less Than
        else:
            for v in object.data.vertices:
                for vge in v.groups:
                    if vge.group == vgroupindex:
                        if vge.weight <= threshold:
                            v.select = True;
                        break;
        
        bpy.ops.object.mode_set(mode = 'EDIT')
        
        return {'FINISHED'}
classlist.append(DMR_SELECTBYWEIGHT);

# =============================================================================

class DMR_CLEARWEIGHTS(bpy.types.Operator):
    bl_label = "Clear Groups From Selected"
    bl_idname = 'dmr.clear_weights_from_selected'
    bl_description = 'Clears all vertex groups from selected vertices';
    bl_options = {'REGISTER', 'UNDO'}
    
    def execute(self, context):
        selectedObject = context.active_object;
        if selectedObject.type == 'MESH':
            lastobjectmode = bpy.context.active_object.mode;
            bpy.ops.object.mode_set(mode = 'OBJECT'); # Update selected
            
            vertexGroups = selectedObject.vertex_groups;
            
            # Remove Groups
            for v in selectedObject.data.vertices:
                if v.select:
                    utils.ClearVertexWeights(v, vertexGroups);
                
            bpy.ops.object.mode_set(mode = lastobjectmode); # Return to last mode
            
        return {'FINISHED'}
classlist.append(DMR_CLEARWEIGHTS);

# =============================================================================

class DMR_CLEANWEIGHTS(bpy.types.Operator):
    bl_label = "Clean Weights from Selected"
    bl_idname = 'dmr.clean_weights_from_selected'
    bl_description = 'Cleans weights from selected objects';
    bl_options = {'REGISTER', 'UNDO'}
    
    def execute(self, context):
        lastobjectmode = bpy.context.active_object.mode;
        bpy.ops.object.mode_set(mode = 'OBJECT'); # Update selected
        count = 0;
        
        for obj in context.selected_objects:
            if obj.type == 'MESH':
                vertexGroups = obj.vertex_groups;
                
                # Remove Groups
                for v in obj.data.vertices:
                    if v.select:
                        for g in v.groups:
                            # Pop vertex from group
                            if g.weight == 0:
                                vertexGroups[g.group].remove([v.index])
                                count += 1;
        
        self.report({'INFO'}, "Cleaned %s weights" % count);
        
        bpy.ops.object.mode_set(mode = lastobjectmode); # Return to last mode
            
        return {'FINISHED'}
classlist.append(DMR_CLEANWEIGHTS);

# =============================================================================

class DMR_REMOVEEMPTYGROUPS(bpy.types.Operator):
    bl_label = "Remove Empty Groups"
    bl_idname = 'dmr.remove_empty_groups'
    bl_description = 'Removes Vertex Groups with no weight data';
    bl_options = {'REGISTER', 'UNDO'}
    
    removeZero : bpy.props.BoolProperty(name = "Ignore Zero Weights", default = True);
    
    def invoke(self, context, event):
        wm = context.window_manager;
        return wm.invoke_props_dialog(self);
    
    def draw(self, context):
        layout = self.layout;
        layout.prop(self, "removeZero");
    
    def execute(self, context):
        for selectedObject in context.selected_objects:
            if selectedObject.type != 'MESH':
                continue;
                
            lastobjectmode = bpy.context.active_object.mode;
            bpy.ops.object.mode_set(mode = 'OBJECT'); # Update selected
            
            vertexGroups = selectedObject.vertex_groups;
            targetGroups = [v for v in vertexGroups];
            
            # Find and pop groups with vertex data
            for v in selectedObject.data.vertices:
                for g in v.groups:
                    realGroup = vertexGroups[g.group];
                    if realGroup in targetGroups:
                        if g.weight > 0 or not self.removeZero:
                            targetGroups.remove(realGroup);
                    
                if len(targetGroups) == 0:
                    break;
            
            # Remove Empty Groups
            count = len(targetGroups);
            if count == 0:
                self.report({'INFO'}, "No Empty Groups Found");
            else:
                for g in targetGroups:
                    vertexGroups.remove(g);
                self.report({'INFO'}, "Found and removed %d empty group(s)" % count);
            
            bpy.ops.object.mode_set(mode = lastobjectmode); # Return to last mode
            
        return {'FINISHED'}
classlist.append(DMR_REMOVEEMPTYGROUPS);

# =============================================================================

class DMR_REMOVERIGHTGROUPS(bpy.types.Operator):
    bl_label = "Remove Right Groups"
    bl_idname = 'dmr.remove_right_groups'
    bl_description = 'Removes vertex groups with the right mirror prefix';
    bl_options = {'REGISTER', 'UNDO'}
    
    def execute(self, context):
        obj = context.active_object;
        if not obj:
            self.info({'WARNING'}, 'No object selected');
            return {'FINISHED'}
        
        lastmode = bpy.context.active_object.mode;
        bpy.ops.object.mode_set(mode = 'OBJECT');
        
        vgroups = obj.vertex_groups;
        groupnames = [x for x in vgroups.keys()];
        lsuffixes = ['_l', '.l'];
        rsuffixes = ['_r', '.r'];
        
        activegroupname = vgroups[vgroups.active_index];
        
        # Check if any mirror groups exists
        for vg in vgroups:
            name = vg.name;
            if name[-2:] in lsuffixes:
                othername = name[0:-1] + 'r';
                if othername in groupnames:
                    groupnames.remove(othername);
                    if vgroups[othername].lock_weight:
                        continue;
                    vgroups.active_index = vgroups[othername].index;
                    bpy.ops.object.vertex_group_remove(all=False, all_unlocked=False);
        
        if activegroupname in groupnames:
            vgroups.active_index = vgroups[activegroupname].index;
        bpy.ops.object.mode_set(mode = lastmode);
        
        return {'FINISHED'}
classlist.append(DMR_REMOVERIGHTGROUPS);

# =============================================================================

class DMR_RemoveFromSelectedBones(bpy.types.Operator):
    bl_label = "Remove From Selected Bones"
    bl_idname = 'dmr.remove_from_selected_bones'
    bl_description = "Removes selected vertices from selected bones' groups.\n(Both a mesh and armature must be selected)";
    bl_options = {'REGISTER', 'UNDO'}

    @classmethod 
    def poll(self, context):
        active = context.active_object;
        if active:
            if active.type == 'MESH':
                if active.mode == 'EDIT' or active.mode == 'WEIGHT_PAINT':
                    return 1;
        return None;
    
    def execute(self, context):
        lastobjectmode = bpy.context.active_object.mode;
        bpy.ops.object.mode_set(mode = 'OBJECT'); # Update selected
        
        armature = [x for x in context.selected_objects if x.type == 'ARMATURE'];
        
        if len(armature) == 0:
            self.report({'WARNING'}, 'No armature selected');
            return {'FINISHED'};
        
        # Find bone names
        armature = armature[0];
        selectedbones = [];
        for b in armature.data.bones:
            if b.select:
                print(b.name)
                selectedbones.append(b.name);
        
        # Find selected vertices
        for obj in context.selected_objects:
            if obj.type == 'MESH':
                targetgroups = {x.index: x for x in obj.vertex_groups if x.name in selectedbones};
                verts = [x for x in obj.data.vertices if x.select];
                
                # Pop vertex from selected bone groups
                for v in verts:
                    for vge in v.groups:
                        if vge.group in targetgroups.keys():
                            targetgroups[vge.group].remove( [v.index] );
        
        bpy.ops.object.mode_set(mode = lastobjectmode); # Return to last mode
        return {'FINISHED'}
classlist.append(DMR_RemoveFromSelectedBones);

# =============================================================================

class DMR_ADDMISSINGMIRROR(bpy.types.Operator):
    bl_label = "Add Missing Mirror Groups"
    bl_idname = 'dmr.add_missing_group'
    bl_description = "Creates groups for those with a mirror name if they don't exist already";
    bl_options = {'REGISTER', 'UNDO'}
    
    def execute(self, context):
        leftmirrorsuffix = ['_l', '_L', '.l', '.L'];
        rightmirrorsuffix = ['_r', '_R', '.r', '.R'];
        
        hits = 0;
        
        lastmode = bpy.context.active_object.mode;
        bpy.ops.object.mode_set(mode = 'OBJECT');
        
        for obj in context.selected_objects:
            if obj.type != 'MESH':
                continue;
            
            groupkeys = obj.vertex_groups.keys();
            index = len( groupkeys );
            
            for vg in obj.vertex_groups:
                newname = "";
                
                if vg.name[-2:] in leftmirrorsuffix:
                    newname = vg.name[:-1] + "r";
                elif vg.name[-2:] in rightmirrorsuffix:
                    newname = vg.name[:-1] + "l";
                    
                if newname in groupkeys:
                    continue;
                
                if newname != "":
                    obj.vertex_groups.new(name=newname);
                    index += 1;
                    print("%s -> %s" % (vg.name, newname));
                    hits += 1;
        
        bpy.ops.object.mode_set(mode = lastmode);
        
        if hits == 0:
            self.report({'INFO'}, "No missing groups found");
        else:
            self.report({'INFO'}, "%d missing mirror groups added" % hits);
        
        return {'FINISHED'}
classlist.append(DMR_ADDMISSINGMIRROR);

# =============================================================================

class DMR_VGroupMoveToEnd(bpy.types.Operator):
    bl_label = "Move Vertex Group to End"
    bl_idname = 'dmr.vgroup_movetoend'
    bl_description = 'Moves active vertex group to end of vertex group list';
    bl_options = {'REGISTER', 'UNDO'}
    
    bottom : bpy.props.BoolProperty(name = "Bottom of List", default = 0);
    
    def execute(self, context):
        for selectedObject in context.selected_objects:
            if selectedObject.type != 'MESH':
                continue;
                
            lastobjectmode = bpy.context.active_object.mode;
            bpy.ops.object.mode_set(mode = 'OBJECT'); # Update selected
            
            vgroups = selectedObject.vertex_groups;
            if self.bottom:
                for i in range(0, vgroups.active.index):
                    bpy.ops.object.vertex_group_move(direction='DOWN');
            else:
                for i in range(0, vgroups.active.index):
                    bpy.ops.object.vertex_group_move(direction='UP');
            
            bpy.ops.object.mode_set(mode = lastobjectmode); # Return to last mode
            
        return {'FINISHED'}
classlist.append(DMR_VGroupMoveToEnd);

# =============================================================================

def register():
    for c in classlist:
        bpy.utils.register_class(c)

def unregister():
    for c in classlist:
        bpy.utils.unregister_class(c)
