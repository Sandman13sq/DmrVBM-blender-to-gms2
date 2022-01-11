import bpy

classlist = []

def GetExportListItems(self, context):
    return [
        (str(i), '%s' % (x.name), x.name)
        for i, x in enumerate(context.scene.vbx_exportlists)
    ]

def ActiveList(self, context):
    sc = context.scene
    try:
        return sc.vbx_exportlists and sc.vbx_exportlists[int(sc.vbx_exportlists_index)]
    except:
        return None

def UpdateListIndices(self, context):
    sc = context.scene
    for i, e in enumerate(sc.vbx_exportlists):
        e.index = i
    print(len(sc.vbx_exportlists))
    print(sc.vbx_exportlists_index)
    sc.vbx_exportlists_index = str(max(0, min(int(sc.vbx_exportlists_index), len(sc.vbx_exportlists)-1)))

# =====================================================================================

class DMR_OP_VBXExportList_AddList(bpy.types.Operator):
    bl_idname = "dmr.vbx_exportlist_list_add"
    bl_label = "Add Export List"
    bl_description = "Adds export list"
    bl_options = {'REGISTER', 'UNDO'}
    
    def execute(self, context):
        sc = context.scene
        
        activelist = ActiveList(self, context)
        newlist = sc.vbx_exportlists.add()
        
        # Copy from other list
        if activelist:
            listnames = [x.name for x in context.scene.vbx_exportlists]
            newlist.name = activelist.name
            dupindex = 0
            while (newlist.name in listnames):
                dupindex += 1
                newlist.name = activelist.name+'.'+str(dupindex).rjust(3, '0')
            
            for x in activelist.entries:
                newlist.entries.add().objname = x.objname
        # Fresh list
        else:
            newlist.name = 'New Export List'
        
        UpdateListIndices(self, context)
        
        sc.vbx_exportlists_index = str(newlist.index)
        
        return {'FINISHED'}
classlist.append(DMR_OP_VBXExportList_AddList)

# ---------------------------------------------------------------------------

class DMR_OP_VBXExportList_RemoveList(bpy.types.Operator):
    bl_idname = "dmr.vbx_exportlist_list_remove"
    bl_label = "Remove Export List"
    bl_description = "Removes export list"
    bl_options = {'REGISTER', 'UNDO'}
    
    @classmethod
    def poll(self, context):
        return ActiveList(self, context)
    
    def execute(self, context):
        sc = context.scene
        activelist = ActiveList(self, context)
        # Clamp BEFORE removing list
        sc.vbx_exportlists_index = str(max(0, min(int(sc.vbx_exportlists_index)-1, len(sc.vbx_exportlists)-1)))
        
        context.scene.vbx_exportlists.remove(activelist.index)
        UpdateListIndices(self, context)
        
        return {'FINISHED'}
classlist.append(DMR_OP_VBXExportList_RemoveList)

# ---------------------------------------------------------------------------

class DMR_OP_VBXExportList_AddEntry(bpy.types.Operator):
    bl_idname = "dmr.vbx_exportlist_entry_add"
    bl_label = "Add Entry to Export List"
    bl_description = "Adds entry to Export List"
    bl_options = {'REGISTER', 'UNDO'}
    
    @classmethod
    def poll(self, context):
        return ActiveList(self, context) != None
    
    def execute(self, context):
        exportlist = ActiveList(self, context)
        entry = exportlist.entries.add()
        if context.active_object:
            entry.objname = context.active_object.name
        exportlist.entryindex = len(exportlist.entries)-1
        return {'FINISHED'}
classlist.append(DMR_OP_VBXExportList_AddEntry)

# ---------------------------------------------------------------------------

class DMR_OP_VBXExportList_RemoveEntry(bpy.types.Operator):
    bl_idname = "dmr.vbx_exportlist_entry_remove"
    bl_label = "Remove Entry from Export List"
    bl_description = "Removes entry from export list"
    bl_options = {'REGISTER', 'UNDO'}
    
    @classmethod
    def poll(self, context):
        return ActiveList(self, context)
    
    def execute(self, context):
        exportlist = ActiveList(self, context)
        index = exportlist.entryindex
        if index in range(0, len(exportlist.entries)):
            exportlist.entries.remove(index)
        # Clamp index
        exportlist.entryindex = max(0, min(index, len(exportlist.entries)-1))
        
        return {'FINISHED'}
classlist.append(DMR_OP_VBXExportList_RemoveEntry)

# ---------------------------------------------------------------------------

class DMR_OP_VBXExportList_FromSelection(bpy.types.Operator):
    bl_idname = "dmr.vbx_exportlist_entry_fromselection"
    bl_label = "Add Selection to Export List"
    bl_description = "Adds selected objects to export list"
    bl_options = {'REGISTER', 'UNDO'}
    
    @classmethod
    def poll(self, context):
        return context.selected_objects and ActiveList(self, context)
    
    def execute(self, context):
        exportlist = ActiveList(self, context)
        for obj in context.selected_objects:
            if obj.name not in {x.objname for x in exportlist.entries}:
                exportlist.entries.add().objname = obj.name
        
        return {'FINISHED'}
classlist.append(DMR_OP_VBXExportList_FromSelection)

# ---------------------------------------------------------------------------

class DMR_OP_VBXExportList_MoveEntry(bpy.types.Operator):
    bl_idname = "dmr.vbx_exportlist_entry_move"
    bl_label = "Move Export List Entry"
    bl_description = "Moves entry up or down on list"
    bl_options = {'REGISTER', 'UNDO'}
    
    direction : bpy.props.EnumProperty(
        name="Direction",
        description='Direction to move layer',
        items=(
            ('UP', 'Up', 'Move vertex color layer up'),
            ('DOWN', 'Down', 'Move vertex color layer down'),
            ('TOP', 'Top', 'Move vertex color layer to top of list'),
            ('BOTTOM', 'Bottom', 'Move vertex color layer to bottom of list'),
        )
    )
    
    @classmethod
    def poll(self, context):
        return ActiveList(self, context)
    
    def execute(self, context):
        exportlist = ActiveList(self, context)
        entryindex = exportlist.entryindex
        newindex = entryindex
        n = len(exportlist.entries)
        
        if self.direction == 'UP':
            newindex = entryindex-1 if entryindex > 0 else n-1
        elif self.direction == 'DOWN':
            newindex = entryindex+1 if entryindex < n-1 else 0
        elif self.direction == 'TOP':
            newindex = 0
        elif self.direction == 'BOTTOM':
            newindex = n-1
        
        exportlist.entries.move(entryindex, newindex)
        exportlist.entryindex = newindex
        
        return {'FINISHED'}
classlist.append(DMR_OP_VBXExportList_MoveEntry)

# ---------------------------------------------------------------------------

class DMR_OP_VBXExportList_Clean(bpy.types.Operator):
    bl_idname = "dmr.vbx_exportlist_clean"
    bl_label = "Clean Export List"
    bl_description = "Removes missing objects from entry list"
    bl_options = {'REGISTER', 'UNDO'}
    
    @classmethod
    def poll(self, context):
        return ActiveList(self, context)
    
    def execute(self, context):
        exportlist = ActiveList(self, context)
        blendobjectnames = [x.name for x in bpy.data.objects]
        
        for e in reversed(exportlist.entries):
            if e.objname not in blendobjectnames:
                exportlist.entries.remove([x for x in exportlist.entries].index(e))
        # Clamp index
        exportlist.entryindex = max(0, min(exportlist.entryindex, len(exportlist.entries)-1))
        return {'FINISHED'}
classlist.append(DMR_OP_VBXExportList_Clean)

# =====================================================================================

class VBXExportListEntry(bpy.types.PropertyGroup):
    objname : bpy.props.StringProperty(
        name='Object Name', default='<Object Name>',
        description='Object to export'
        )
classlist.append(VBXExportListEntry)

# ---------------------------------------------------------------------------

class VBXExportList(bpy.types.PropertyGroup):
    entries : bpy.props.CollectionProperty(type=VBXExportListEntry)
    entryindex : bpy.props.IntProperty()
    index : bpy.props.IntProperty(default=0)
classlist.append(VBXExportList)

# =====================================================================================

class DMR_UL_VBXExportList(bpy.types.UIList):
    def draw_item(self, context, layout, data, item, icon, active_data, active_propname, index):
        r = layout.row(align=1)
        objects = bpy.data.objects
        if item.objname in objects:
            r.prop(item, "objname", text='[%d]' % index, icon=objects[item.objname].type+'_DATA')
        else:
            r.prop(item, "objname", text='(Missing)', icon='QUESTION')
        #r.label(text='  %s' % (item.objname))
classlist.append(DMR_UL_VBXExportList)

# =====================================================================================

class DMR_PT_VBXExportList(bpy.types.Panel):
    bl_label = 'VBX Custom Export List'
    bl_space_type = 'PROPERTIES'
    bl_region_type = 'WINDOW'
    bl_context = 'scene'
    
    def draw(self, context):
        layout = self.layout
        
        exportlists = context.scene.vbx_exportlists
        exportlist = ActiveList(self, context)
        
        if not exportlist:
            layout.operator('dmr.vbx_exportlist_list_add', icon='ADD', text="New List")
        else:
            c = layout.column(align=1)
            r = c.row(align=1)
            r.prop(context.scene, 'vbx_exportlists_index', text='', icon='PRESET', icon_only=1)
            r.prop(exportlist, 'name', text="")
            r = r.row(align=1)
            r.operator('dmr.vbx_exportlist_list_add', icon='ADD', text="")
            r.operator('dmr.vbx_exportlist_list_remove', icon='REMOVE', text="")
            
            # Export List
            if exportlist:
                row = layout.row()
                row.template_list(
                    "DMR_UL_VBXExportList", "", 
                    exportlist, "entries", 
                    exportlist, "entryindex", 
                    rows=5)
                
                col = row.column(align=True)

                col.operator("dmr.vbx_exportlist_entry_add", icon='ADD', text="")
                props = col.operator("dmr.vbx_exportlist_entry_remove", icon='REMOVE', text="")
                
                col.separator()
                col.operator("dmr.vbx_exportlist_entry_fromselection", icon='RESTRICT_SELECT_OFF', text="")
                col.operator("dmr.vbx_exportlist_clean", icon='HELP', text="")
                
                col.separator()
                col.operator("dmr.vbx_exportlist_entry_move", icon='TRIA_UP', text="").direction = 'UP'
                col.operator("dmr.vbx_exportlist_entry_move", icon='TRIA_DOWN', text="").direction = 'DOWN'
classlist.append(DMR_PT_VBXExportList)

# =====================================================================================

def register():
    for c in classlist:
        bpy.utils.register_class(c)
    
    bpy.types.Scene.vbx_exportlists = bpy.props.CollectionProperty(
        name='Export Lists', type=VBXExportList)
    bpy.types.Scene.vbx_exportlists_index = bpy.props.EnumProperty(
        name='Export List Index', default=0, items=GetExportListItems)

def unregister():
    for c in reversed(classlist):
        bpy.utils.unregister_class(c)
    del bpy.types.Scene.vbx_exportlists
    del bpy.types.Scene.vbx_exportlists_index
    
