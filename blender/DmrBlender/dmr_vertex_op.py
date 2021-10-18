import bpy
import bmesh

classlist = [];

# =============================================================================

# Source: https://blenderartists.org/t/i-want-to-move-a-vertices-to-normal-directon-of-origin-vertex-by-python/601077/3
class DMR_VERTALONGNORMAL(bpy.types.Operator):
    """Tooltip"""
    bl_idname = "dmr.vert_along_normal"
    bl_label = "Move Vertices along Normal"
    bl_description = 'Moves selected vertices along their normals';
    bl_options = {'REGISTER', 'UNDO'}

    factor : bpy.props.FloatProperty(
        name="Factor",
        min=-1000.0,
        max=1000.0, 
        soft_min=-10.0,
        soft_max=10.0
    )

    @classmethod
    def poll(cls, context):
        return (context.object is not None and
                context.object.type == 'MESH' and
                context.object.data.is_editmode)

    def execute(self, context):
        ob = bpy.context.object
        me = ob.data
        bm = bmesh.from_edit_mesh(me)
        
        for v in bm.verts:
            if v.select:
                v.co += v.normal * self.factor
                
        bmesh.update_edit_mesh(me, True, False);
        return {'FINISHED'}
classlist.append(DMR_VERTALONGNORMAL);

# =============================================================================

class DMR_SetEdgeCrease(bpy.types.Operator):
    """Tooltip"""
    bl_label = "Set Crease"
    bl_idname = 'dmr.set_crease'
    bl_description = "Sets edge crease value for selected edges";
    bl_options = {'REGISTER', 'UNDO'}
    
    crease : bpy.props.FloatProperty(
        name="Crease",
        min=-0.0,
        max=1.0, 
    )

    @classmethod
    def poll(cls, context):
        return (context.object is not None and
                context.object.type == 'MESH' and
                context.object.data.is_editmode)

    def execute(self, context):
        crease = self.crease;
        context = bpy.context;
        objs = [o for o in context.selected_objects if o.type == 'MESH'];
        
        lastobjectmode = bpy.context.active_object.mode;
        bpy.ops.object.mode_set(mode = 'OBJECT'); # Update selected
        
        for obj in objs:
            edges = [e for e in obj.data.edges if e.select]
            for e in edges:
                e.crease = crease;
        
        bpy.ops.object.mode_set(mode = lastobjectmode);
        
        return {'FINISHED'}
classlist.append(DMR_SetEdgeCrease);

# =============================================================================

class DMR_SELBYSHAREDMATERIAL(bpy.types.Operator):
    """Tooltip"""
    bl_label = "Select Objects by shared Material"
    bl_idname = 'dmr.select_by_material'
    bl_description = "Selects objects that contain the same material as the active object's active material";
    bl_options = {'REGISTER', 'UNDO'}
    
    @classmethod
    def poll(cls, context):
        return (context.object is not None and
                context.object.type == 'MESH' and
                context.object.data.is_editmode)
    
    def execute(self, context):
        active = bpy.context.view_layer.objects.active;
        if active:
            targetmat = active.active_material;
            if targetmat:
                for obj in bpy.data.objects:
                    if obj.type == 'MESH':
                        if not (obj.hide_viewport or obj.hide_select):
                            for m in obj.data.materials:
                                if m == targetmat:
                                    obj.select_set(1);
                                    break;
        return {'FINISHED'}
classlist.append(DMR_SELBYSHAREDMATERIAL);

# =============================================================================

class DMR_RESETSHAPEKEYSVERTEX(bpy.types.Operator):
    bl_label = "Reset Vertex Shape Keys"
    bl_idname = 'dmr.reset_vertex_shape_keys'
    bl_description = 'Sets shape key positions of selected vertices to "Basis" for all keys';
    
    def execute(self, context):
        oldactive = context.active_object;
        
        if len(context.selected_objects) == 0:
            self.report({'WARNING'}, "No objects selected");
            return {'FINISHED'}
        
        for obj in context.selected_objects:
            if obj.type == "MESH":
                # No Shape Keys exist for object
                if obj.data.shape_keys == None: continue;
                shape_keys = obj.data.shape_keys.key_blocks;
                if len(shape_keys) == 0: continue;
                
                keyindex = {};
                basis = shape_keys[0];
                bpy.context.view_layer.objects.active = obj;
                oldactivekey = obj.active_shape_key_index;
                
                for i in range(0, len(shape_keys)):
                    keyindex[ shape_keys[i].name ] = i;
                
                # For all keys...
                for sk in shape_keys:
                    obj.active_shape_key_index = keyindex[sk.name];
                    bpy.ops.mesh.blend_from_shape(shape = basis.name, add = False);
                
                obj.active_shape_key_index = oldactivekey;
                
        bpy.context.view_layer.objects.active = oldactive;
            
        return {'FINISHED'}
classlist.append(DMR_RESETSHAPEKEYSVERTEX);

# =============================================================================

class DMR_QuickVertexGroupTransfer(bpy.types.Operator):
    bl_label = "Quick Vertex Group Transfer"
    bl_idname = 'dmr.quick_group_transfer'
    bl_description = "Transfers weights of active object's vertices to selected object's vertices";
    
    def execute(self, context):
        oldactive = context.active_object;
        
        if len(context.selected_objects) == 0:
            self.report({'WARNING'}, "No objects selected");
            return {'FINISHED'}
        
        bpy.ops.object.data_transfer(
            use_freeze=False, data_type='VGROUP_WEIGHTS', use_create=True, 
            vert_mapping='POLYINTERP_NEAREST', 
            use_auto_transform=False, use_object_transform=False, use_max_distance=True, 
            max_distance=0.1, ray_radius=0.1, 
            layers_select_src='ALL', layers_select_dst='NAME', 
            mix_mode='REPLACE', mix_factor=1)
            
        return {'FINISHED'}
classlist.append(DMR_QuickVertexGroupTransfer);

# =============================================================================

def register():
    for c in classlist:
        bpy.utils.register_class(c)

def unregister():
    for c in classlist:
        bpy.utils.unregister_class(c)
