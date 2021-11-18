import bpy

classlist = [];

class DmrToolsPanel_VertexColors(bpy.types.Panel): # ------------------------------
    bl_label = "Vertex Colors"
    bl_idname = "DMR_PT_VERTEXCOLORS"
    bl_space_type = 'VIEW_3D'
    bl_region_type = 'UI'
    bl_category = "Dmr Edit" # Name of sidebar
    bl_options = {'DEFAULT_CLOSED'}
    COMPAT_ENGINES = {'BLENDER_RENDER', 'BLENDER_EEVEE', 'BLENDER_WORKBENCH'}
    
    @classmethod 
    def poll(self, context):
        active = context.active_object;
        if active:
            if active.type == 'MESH':
                m = active.mode;
                if m == 'EDIT' or m == 'VERTEX_PAINT' or m == 'OBJECT':
                    return 1;
        return None;
    
    def draw(self, context):
        active = context.active_object;
        mode = active.mode;
        layout = self.layout;
        col = bpy.context.scene.editmodecolor;
        col255 = [x*255 for x in col[:3]];
        #colhex = '%02x%02x%02x' % (int(col[0]*255), int(col[1]*255), int(col[2]*255));
        #colhex = colhex.upper();
        
        if mode == 'EDIT' or mode == 'VERTEX_PAINT':
            colorarea = layout.row(align = 1);
            row = colorarea.row(align = 1);
            row.operator("dmr.set_vertex_color", icon='BRUSH_DATA', text="").mixamount = 1.0;
            row.scale_x = 2;
            row.scale_y = 2;
            row.prop(context.scene, "editmodecolor", text='');
            row.operator("dmr.pick_vertex_color", icon='EYEDROPPER', text="")
            
            row = layout.row(align = 1);
            row.operator("dmr.vc_clear_alpha", icon='MATSPHERE', text="Clear Alpha")
            
            row = layout.row(align = 1);
            row.label(text = '<%d, %d, %d>   A:%.2f' % (col255[0],col255[1],col255[2], col[3]) );
            #row.label(text = colhex );
        
        me = active.data;
        
        row = layout.row(align=1)
        col = row.column()
        col.template_list("MESH_UL_vcols", "vcols", me, "vertex_colors", me.vertex_colors, "active_index", rows=2);
        col = row.column(align=True)
        col.operator("mesh.vertex_color_add", icon='ADD', text="")
        col.operator("mesh.vertex_color_remove", icon='REMOVE', text="")

classlist.append(DmrToolsPanel_VertexColors);

def register():
    for c in classlist:
        bpy.utils.register_class(c)
    bpy.types.Scene.editmodecolor = bpy.props.FloatVectorProperty(
        name="Paint Color", subtype="COLOR", size=4, min=0.0, max=1.0,
        default=(1.0, 1.0, 1.0, 1.0)
    );

def unregister():
    for c in classlist:
        bpy.utils.unregister_class(c)
