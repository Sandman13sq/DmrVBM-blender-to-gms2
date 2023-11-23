import bpy
import os
import struct
import zlib
import sys
import mathutils

from bpy_extras.io_utils import ExportHelper
from struct import pack as Pack

# Include
try:
    from .vbm_utils import *
    from .vbm_format import *
    from .vbm_exportlist import *
except:
    from vbm_utils import *
    from vbm_format import *
    from vbm_exportlist import *

# VBM spec:
"""
    'VBM' (3B)
    VBM version = 2 (1B)
    
    flags (1B)

    formatlength (1B)
    formatentry[formatlength]
        attributetype (1B)
        attributefloatsize (1B)

    vbcount (1I)
    vbnames[vbcount]
        namelength (1B)
        namechars[namelength]
            char (1B)
    vbdata[vbcount]
        vbcompressedsize (1L)
        vbnumvertices (1L)
        vbcompresseddata (vbcompressedsize B)

    bonecount (1I)
    bonenames[bonecount]
        namelength (1B)
        namechars[namelength]
            char (1B)
    parentindices[bonecount] 
        parentindex (1I)
    localmatrices[bonecount]
        mat4 (16f)
    inversemodelmatrices[bonecount]
        mat4 (16f)
"""

classlist = []

'# =========================================================================================================================='
'# OPERATORS'
'# =========================================================================================================================='

class ExportVBSuper(bpy.types.Operator, ExportHelper):
    bl_options = {'PRESET'}
    
    attribute_list_dialog : bpy.props.PointerProperty(
        name='Format', type=VBM_FormatDef_Format)
    
    format : bpy.props.StringProperty(name="Vertex Format", default="")
    
    def WriteFormat(self, context):
        if self.op_save_format:
            self.op_save_format = False
            format = context.scene.vbm.formats.FindItem(self.format)
            if not format:
                format = context.scene.vbm.formats.Add()
            format.CopyFromOther(self.attribute_list_dialog)
    op_save_format : bpy.props.BoolProperty(name="Save Format To Scene", default=False, update=WriteFormat)
    
    more_options: bpy.props.BoolProperty(
        name="More Options", default=False,
        description="Show more export options",
    )
    
    export_list: bpy.props.StringProperty(
        name='Export List',
        description='Export list to use for export. Leave empty to use Collection Name',
    )
    
    collection_name_items: bpy.props.CollectionProperty(type=VBM_StringItem)
    
    collection: bpy.props.StringProperty(
        name='Collection',
        description='Collection to export objects from. Leave empty to use Selected Objects',
    )
    
    delimiter_start: bpy.props.StringProperty(
        name="Delimiter Start", default="",
        description='Grouping will ignore parts of names before and including this character. \nEx: if delimiter_start = ".", "model_body.head" -> "head"',
    )
    
    delimiter_end: bpy.props.StringProperty(
        name="Delimiter End", default="",
        description='Grouping will ignore parts of names after and including this character. \nEx: if delimiter_end = ".", "model_body.head" -> "model_body"',
    )
    
    apply_armature: bpy.props.BoolProperty(
        name="Apply Armature", default=True,
        description="Apply armature to meshes",
    )
    
    deform_only: bpy.props.BoolProperty(
        name="Deform Bones Only", default=False,
        description='Only use bones with the "Deform" box checked for armature and weights',
    )
    
    export_hidden: bpy.props.BoolProperty(
        name="Export Hidden", default=False,
        description="Export hidden objects",
    )
    
    edges_only: bpy.props.BoolProperty(
        name="Edges Only", default=False,
        description="Export mesh edges only (without triangulation).",
    )
    
    reverse_winding: bpy.props.BoolProperty(
        name="Reverse Winding", default=False,
        description="Reverse winding order of exported meshes (Counter Clockwise to Clockwise and vice-versa)",
    )
    
    flip_normals: bpy.props.BoolProperty(
        name="Flip Normals", default=False,
        description="Flips normals of exported meshes",
    )
    
    flip_uvs: bpy.props.BoolProperty(
        name='Flip UVs', default=True,
        description='Flips Y Coordinate of UVs so that 0.0 is the top of the image and 1.0 is the bottom',
    )
    
    forward_axis: bpy.props.EnumProperty(
        name="Forward Axis", 
        description="Forward Axis to use when Exporting",
        items = Items_ForwardAxis, 
        default='+y',
    )
    
    up_axis: bpy.props.EnumProperty(
        name="Up Axis", 
        description="Up Axis to use when Exporting",
        items = Items_UpAxis, 
        default='+z',
    )
    
    uv_layer_target: bpy.props.EnumProperty(
        name="Target UV Layer", 
        description="UV Layer to reference when exporting.",
        items = Items_LayerChoice, default='render',
    )
    
    color_layer_target: bpy.props.EnumProperty(
        name="Target Color Layer", 
        description="Color Layer to reference when exporting.",
        items = Items_LayerChoice, default='render',
    )
    
    modifier_target: bpy.props.EnumProperty(
        name="Target Modifiers", 
        description="Requirements for modifers when exporting.",
        items = Items_ModChoice, 
        default='OR',
    )
    
    scale: bpy.props.FloatVectorProperty(
        name="Data Scale",
        description="Scale to Apply to Export",
        default=(1.0, 1.0, 1.0),
    )
    
    max_subdivisions : bpy.props.IntProperty(
        name="Max Subdivisions", default = 2, min = -1,
        description="Maximum number of subdivisions for Subdivision Surface modifier.\n(-1 for no limit)",
    )
    
    float_type : bpy.props.EnumProperty(
        name="Float Type", 
        description='Data type to export floats in for vertex attributes and bone matrices', 
        items=Items_FloatChoice, default='f'
    )
    
    vertex_group_default_weight : bpy.props.FloatProperty(
        name="Vertex Group Default Weight", default=0.0, soft_min=0.0, soft_max=1.0,
        description='Default weight for Vertex Group attribute when an object does not contain the selected group.',
    )
    
    def invoke(self, context, event):
        # Initialize Dialog Temporary Format
        attribute_list = self.attribute_list_dialog
        if attribute_list.size == 0:
            attribute_list.Add(VBF_POS, 3)
            attribute_list.Add(VBF_RGB, 4)
            attribute_list.Add(VBF_NOR, 3)
        
        # Find all collection names
        self.collection_name_items.clear()
        self.collection_name_items.add().name = ""
        targetcollections = [c for c in bpy.data.collections if context.scene.user_of_id(c)]
        for c in targetcollections:
            self.collection_name_items.add().name = c.name
        
        wm = context.window_manager.fileselect_add(self)
        return {'RUNNING_MODAL'}
    
    def DrawCollectionHeader(self, context, layout, vbm=False):
        c = layout.column_flow(align=1)
        
        r = c.row(align=1)
        r.prop_search(self, 'export_list', context.scene.vbm.export_lists, 'items', text='Export List')
        r = c.row(align=1)
        r.enabled = self.export_list == ""
        r.prop_search(self, 'collection', self, 'collection_name_items', text='Collection', icon='OUTLINER_COLLECTION')
        
        c.prop(self, 'batch_export', text='Batching')
        if vbm:
            c.prop(self, 'grouping', text='Grouping')
        
        r = c.row().row(align=1)
        r.prop(self, 'delimiter_start', text='Header')
        r.prop(self, 'delimiter_end', text='Delimiter')
    
    def DrawCommonProps(self, context):
        layout = self.layout
        
        c = layout.column_flow(align=1)
        
        r = c.row()
        r.prop(self, 'apply_armature', text='Apply Armature')
        r.prop(self, 'deform_only', text='Deform Only')
        
        b = c.box()
        r = b.row(align=1)
        r.alignment = 'CENTER'
        r.prop(self, 'more_options', text='== Show More Options ==', icon='PREFERENCES')
        
        if self.more_options:
            c = b.column_flow(align=1)
            
            c.prop(self, 'export_hidden', text='Export Hidden')
            c.prop(self, 'edges_only', text='Edges Only')
            c.prop(self, 'reverse_winding', text='Flip Normals')
            c.prop(self, 'flip_uvs', text='Flip UVs')
            
            c.prop(self, 'vertex_group_default_weight', text='Default Weight')
            
            rr = c.row()
            cc = rr.column(align=1)
            cc.scale_x = 0.8
            cc.label(text='Color Source:')
            cc.label(text='UV Source:')
            cc.label(text='Modifier Src:')
            cc = rr.column(align=1)
            cc.prop(self, 'color_layer_target', text='')
            cc.prop(self, 'uv_layer_target', text='')
            cc.prop(self, 'modifier_target', text='')
            
            r = c.row()
            r.prop(self, 'scale', text='Scale')
            rr = c.row().row(align=1)
            rr.prop(self, 'up_axis', text='')
            rr.prop(self, 'forward_axis', text='')
            c.prop(self, 'max_subdivisions', text='Max Subdivisions')
            c.prop(self, 'compression_level', text='Compression')
        
    def DrawAttributes(self, context):
        activeformat = context.scene.vbm.formats.FindItem(self.format, self.attribute_list_dialog)
        
        layout = self.layout
        
        b = layout.box()
        b = b.column_flow(align=1)
        r = b.row(align=1)
        r.prop_search(self, 'format', context.scene.vbm.formats, 'items', text="Format", icon='ZOOM_SELECTED', results_are_suggestions=False)
        
        rr = r.row(align=1)
        rr.enabled = activeformat == None
        rr.prop(self, 'op_save_format', text="", icon='ADD')
        
        activeformat.DrawPanel(context, b)
        
        items = activeformat.GetItems()
        
        stride = sum([att.GetByteSize() / 4.0 for att in items])
        sizestring = "".join(["%dB " % att.GetByteSize() for att in items])
        
        layout.label(text='= %d Floats (%dB) [%s]' % (stride, stride*4, sizestring))
        
        return 
        
        c = layout.box().column(align=1)
        netcolorbytes = sum([att.GetByteSize() for att in items if att.type in VBFByteType])
        
        for item in items:
            varname = VBFVarname[item.type]
            
            c.label(text="attribute vec%d %s;" % (item.size, varname))

# ---------------------------------------------------------------------------------

class VBM_OT_ExportVB(ExportVBSuper, ExportHelper):
    """Exports selected objects as one compressed vertex buffer"""
    bl_idname = "vbm.export_vb"
    bl_label = "Export VB"
    bl_options = {'PRESET'}
    
    # ExportHelper mixin class uses this
    filename_ext = ".vb"
    filter_glob: bpy.props.StringProperty(default="*.vb", options={'HIDDEN'}, maxlen=255)
    
    batch_export: bpy.props.EnumProperty(
        name="Batch Export",
        description="Export selected objects as separate files.",
        items = (
            ('NONE', 'No Batching', 'All objects will be written to a single file'),
            ('OBJECT', 'By Object Name', 'Objects will be written to "<filename><objectname>.vb" by object'),
            ('MESH', 'By Mesh Name', 'Objects will be written to "<filename><meshname>.vb" by mesh'),
            ('MATERIAL', 'By Material', 'Objects will be written to "<filename><materialname>.vb" by material'),
        ),
        default='NONE',
    )
    
    compression_level: bpy.props.IntProperty(
        name="Compression Level", default=0, min=-1, max=9,
        description="Level of zlib compression to apply to export.\n0 for no compression. -1 for zlib default compression",
    )
    
    def draw(self, context):
        layout = self.layout
        
        self.DrawCollectionHeader(context, layout, False)
        self.DrawCommonProps(context)
        self.DrawAttributes(context)

    def execute(self, context):
        path = os.path.realpath(bpy.path.abspath(self.filepath))
        
        if not os.path.exists(os.path.dirname(path)):
            self.report({'WARNING'}, 'Invalid path specified: "%s"' % path)
            return {'FINISHED'}
        
        context.scene.vbm.ExportVB(
            self.format if self.format else self.attribute_list_dialog,
            self.filepath,
            
            export_list=self.export_list,
            collection=self.collection,
            objects=context.selected_objects,
            
            delimiter_start=self.delimiter_start,
            delimiter_end=self.delimiter_end,
            compression_level=self.compression_level,
            batch=self.batch_export,
            export_hidden=self.export_hidden,
            
            flip_uvs=self.flip_uvs,
            max_subdivisions=self.max_subdivisions,
            modifier_target=self.modifier_target,
            apply_armature=self.apply_armature,
            deform_only=self.deform_only,
            edges_only=self.edges_only,
            flip_normals=self.flip_normals,
            reverse_winding=self.reverse_winding,
            matrix=GetCorrectiveMatrix(self, context)
        )
        
        return {'FINISHED'}
classlist.append(VBM_OT_ExportVB)

# ---------------------------------------------------------------------------------

class VBM_OT_ExportVBM(ExportVBSuper, bpy.types.Operator):
    """Exports selected objects as vbm data"""
    bl_idname = "vbm.export_vbm"
    bl_label = "Export VBM"
    bl_options = {'PRESET'}
    
    # ExportHelper mixin class uses this
    filename_ext = ".vbm"
    filter_glob : bpy.props.StringProperty(default='*'+filename_ext, options={'HIDDEN'}, maxlen=255)
    
    batch_export: bpy.props.EnumProperty(
        name="Batch Export",
        description="Export selected objects as separate files.",
        items = Items_VBMSort,
        default='NONE',
    )
    
    compression_level: bpy.props.IntProperty(
        name="Compression Level", default=-1, min=-1, max=9,
        description="Level of zlib compression to apply to export.\n0 for no compression. -1 for zlib default compression",
    )
    
    grouping : bpy.props.EnumProperty(
        name="Mesh Grouping",
        description="Choose to export vertices grouped by object or material",
        items=(
            ('OBJECT', "By Object", "Objects -> VBs"),
            ('MATERIAL', "By Material", "Materials -> VBs"),
        ),
        default='OBJECT',
    )
    
    export_armature : bpy.props.BoolProperty(
        name="Export Armature", default = True,
        description="Include any selected or related armature on export",
    )
    
    def draw(self, context):
        layout = self.layout
        
        self.DrawCollectionHeader(context, layout, True)
        
        r = layout.column_flow(align=1)
        r.prop(self, 'export_armature', text='Export Armature')
        
        self.DrawCommonProps(context)
        self.DrawAttributes(context)
        
    def execute(self, context):
        path = os.path.realpath(bpy.path.abspath(self.filepath))
        
        if not os.path.exists(os.path.dirname(path)):
            self.report({'WARNING'}, 'Invalid path specified: "%s"' % path)
            return {'FINISHED'}
        
        context.scene.vbm.ExportVBM(
            self.format if self.format else self.attribute_list_dialog,
            self.filepath,
            
            export_list=self.export_list,
            collection=self.collection,
            objects=context.selected_objects,
            
            delimiter_start=self.delimiter_start,
            delimiter_end=self.delimiter_end,
            compression_level=self.compression_level,
            batch=self.batch_export,
            export_hidden=self.export_hidden,
            
            grouping=self.grouping,
            export_armature=True,
            
            flip_uvs=self.flip_uvs,
            max_subdivisions=self.max_subdivisions,
            modifier_target=self.modifier_target,
            apply_armature=self.apply_armature,
            deform_only=self.deform_only,
            edges_only=self.edges_only,
            flip_normals=self.flip_normals,
            reverse_winding=self.reverse_winding,
            matrix=GetCorrectiveMatrix(self, context)
        )
        
        self.report({'INFO'}, 'VBM export complete')
        
        return {'FINISHED'}
classlist.append(VBM_OT_ExportVBM)

'# =========================================================================================================================='
'# PANELS'
'# =========================================================================================================================='

class VBM_PT_VBMExport(bpy.types.Panel):
    bl_label = 'VBM Export'
    bl_space_type = 'PROPERTIES'
    bl_region_type = 'WINDOW'
    bl_context = 'scene'
    
    def draw(self, context):
        layout = self.layout
        
        r = layout.row()
        split = r.split(factor=0.9)
        split.label(text='Vertex Buffer:')
        r.operator("vbm.export_vb", text='Export VB', icon='OBJECT_DATA').format = ""
        r.operator("vbm.export_vbm", text='Export VBM', icon='MOD_ARRAY').format = ""
        layout = self.layout
classlist.append(VBM_PT_VBMExport)

# ---------------------------------------------------------------------------------

class VBM_PT_VertexFormats(bpy.types.Panel):
    bl_label = 'VBM Vertex Formats'
    bl_space_type = 'PROPERTIES'
    bl_region_type = 'WINDOW'
    bl_context = 'scene'
    bl_parent_id = 'VBM_PT_VBMExport'
    
    def draw(self, context):
        layout = self.layout
        
        active = context.scene.vbm.formats
        
        r = layout.row()
        r.operator('vbm.format_import', icon='IMPORT', text="Import Format")
        r.operator('vbm.format_export', icon='EXPORT', text="Export Format")
        
        active.DrawPanel(context, layout)
classlist.append(VBM_PT_VertexFormats)

# ---------------------------------------------------------------------------------

class VBM_PT_VertexFormats_ActiveFormat(bpy.types.Panel):
    bl_label = 'VBM Active Format'
    bl_space_type = 'PROPERTIES'
    bl_region_type = 'WINDOW'
    bl_context = 'scene'
    bl_parent_id = 'VBM_PT_VertexFormats'
    
    def draw(self, context):
        layout = self.layout
        
        active = context.scene.vbm.formats.GetActive()
        
        if active:
            r = layout.row()
            r.label(text=active.name)
            r.prop(context.scene.vbm.formats, 'op_refresh_strings', text="Refresh Property Lists", toggle=True)
            
            active.DrawPanel(context, layout)
classlist.append(VBM_PT_VertexFormats_ActiveFormat)

# ---------------------------------------------------------------------------------

class VBM_PT_ExportList_List(bpy.types.Panel):
    bl_label = 'VBM Custom Export List'
    bl_space_type = 'PROPERTIES'
    bl_region_type = 'WINDOW'
    bl_context = 'scene'
    bl_parent_id = 'VBM_PT_VBMExport'
    bl_options = {'DEFAULT_CLOSED'}
    
    def draw(self, context):
        layout = self.layout
        
        active = context.scene.vbm.export_lists
        active.DrawPanel(context, layout)
classlist.append(VBM_PT_ExportList_List)

# ---------------------------------------------------------------------------------

class VBM_PT_ExportList_Active(bpy.types.Panel):
    bl_label = 'VBM Active Export List'
    bl_space_type = 'PROPERTIES'
    bl_region_type = 'WINDOW'
    bl_context = 'scene'
    bl_parent_id = 'VBM_PT_ExportList_List'
    bl_options = {'DEFAULT_CLOSED'}
    
    def draw(self, context):
        layout = self.layout
        
        active = context.scene.vbm.export_lists.GetActive()
        
        if active:
            r = layout.row()
            r.label(text=active.name)
            r.prop(context.scene.vbm, 'op_refresh_strings', text="Refresh Property Lists", toggle=True)
            
            c = active.DrawPanel(context, layout, 8)
            
            # List Control
            c.separator()
            c.prop(active, 'op_from_selected', text="", icon='RESTRICT_SELECT_OFF')
            c.separator()
            c.prop(active, 'op_flush', icon='LIBRARY_DATA_BROKEN', text="")
            c.operator("vbm.exportlist_entry_sort", icon='SORTSIZE', text="")
classlist.append(VBM_PT_ExportList_Active)

'# =========================================================================================================================='
'# MASTER'
'# =========================================================================================================================='

def ParseObjectLists(context, export_hidden, export_list, collection, selected_objects):
    objects = list(selected_objects)
    
    # Export List
    if export_list:
        print("> Export List: %s" % export_list)
        activelist = context.scene.vbm.export_lists.FindItem(export_list, None)
        objects = activelist.GetObjects() if activelist else []
    # Collection
    elif collection:
        print("> Collection: %s" % collection)
        objects = list(bpy.data.collections[collection].all_objects) if collection in bpy.data.collections.keys() else []
    # Other Objects
    else:
        print("> Selected Objects")
    
    targetobjects = [obj for obj in objects if (obj.type in VALIDOBJTYPES and (export_hidden or not obj.hide_get()))]
    
    return (objects, targetobjects)

# Returns tuple of (outbytes, outcounts)
# outbytes = {materialname: vertexbytedata}
# outcounts = {materialname: vertexcount}
def GetVBData(
    self,       # VBM_Master
    context,    # Active context
    sourceobj,  # Object to write data for
    format,     # Format item, or name of defined format
    
    flip_uvs=True,
    max_subdivisions=-1,
    modifier_target=MTY_OR,
    apply_armature=False,
    deform_only=True,
    bone_names=None,    # Controls indices for bone attributes
    edges_only=False,
    flip_normals=False,
    reverse_winding=False,
    matrix=mathutils.Matrix(),
    
    FCODE='f',
    
    color_default=(1.0, 1.0, 1.0, 1.0),
    weight_default=0.0,
    
    instancerun=False,
):
    # Functions
    def FixColorSpace(color, do_convert):
        return color if not do_convert else list(mathutils.Color(color[:3]).from_scene_linear_to_srgb())+[color[3]]
    
    def FixColorSpaceByte(color, do_convert):
        return color if not do_convert else [int(x*255.0) for x in FixColorSpace([x/255.0 for x in color], True)]
    
    def PrintStatus(msg, clear=1, buffersize=30):
        msg = msg + (' '*buffersize*clear)
        sys.stdout.write(msg + (chr(8) * len(msg) * clear))
        sys.stdout.flush()

    
    tstart = time.time()
    
    # Parse Format
    if format:
        if isinstance(format, str):
            format = context.scene.vbm.formats.FindItem(format, None)
            if not format:
                print("> Format \"%s\" does not exist!" % str(format))
                return ({}, {})
    
    if not format:
        print("> Format is invalid! %s" % str(format))
        return ({}, {})
    
    attributes = format.GetItems()
    
    attributetypes = [att.type for att in attributes]
    attributesizes = [att.size for att in attributes]
    gammacorrect = [att.convert_to_srgb for att in attributes]
    uvtargets = [att.layer for att in attributes]
    vctargets = [att.layer for att in attributes]
    vgrouptargets = [att.layer for att in attributes]
    paddingfloats = [att.padding_floats for att in attributes]
    paddingbytes = [att.padding_bytes for att in attributes]
    
    formatsize = len(attributes)
    
    process_bones = sum([1 for k in attributetypes if k in [VBF_BON, VBF_BOI, VBF_WEI, VBF_WEB]]) > 0
    process_tangents = sum([1 for k in attributetypes if k in [VBF_TAN, VBF_BTN]]) > 0
    
    if not instancerun:
        PrintStatus('> Composing data for \"%s\":' % sourceobj.name, 0)
    else:
        PrintStatus('> Composing data for instances of \"%s\":' % sourceobj.name, 0)
    
    # Create working data
    workingobj = sourceobj.copy()
    workingobj.name += '__temp'
    context.scene.collection.objects.link(workingobj)
    
    armature = sourceobj.find_armature()
    if armature:
        lastposestate = armature.data.pose_position
        armature.data.pose_position = 'POSE' if lastposestate else 'REST'
    
    # Handle modifiers
    modifiers = workingobj.modifiers
    if modifiers != None:
        for m in modifiers:
            # Skip Bang Modifiers
            if (m.name[0] == '!'):
                m.show_viewport = False
                continue
            
            # Modifier requirements
            vshow = m.show_viewport
            rshow = m.show_render
            if (
                (modifier_target == MTY_VIEW and not vshow) or 
                (modifier_target == MTY_RENDER and not rshow) or 
                (modifier_target == MTY_OR and not (vshow or rshow)) or 
                (modifier_target == MTY_AND and not (vshow and rshow))
                ):
                m.show_viewport = False
                continue
            
            if max_subdivisions >= 0 and m.type == 'SUBSURF':
                m.levels = min(m.levels, max_subdivisions)
            
            if m.type == 'ARMATURE':
                m.show_viewport = apply_armature
        
        if not edges_only:
            m = workingobj.modifiers.new(type='TRIANGULATE', name='VBM Triangulate')
            if m:
                m.min_vertices=4
                m.keep_custom_normals=True
                m.quad_method = 'BEAUTY'
    
    context.view_layer.update()
    
    dg = context.evaluated_depsgraph_get() #getting the dependency graph
    
    # Invoke to_mesh() for evaluated object.
    workingobj = workingobj.evaluated_get(dg)
    workingmesh = workingobj.evaluated_get(dg).to_mesh()
    workingvclayers = workingmesh.color_attributes if USE_ATTRIBUTES else workingmesh.vertex_colors
    workinguvlayers = workingmesh.uv_layers
    
    # Create missing data
    if USE_ATTRIBUTES:
        if len(workingvclayers) == 0:
            workingvclayers.new("New Layer", 'BYTE_COLOR', 'CORNER')
        if len(workinguvlayers) == 0:
            workinguvlayers.new()
    else:
        if len(workingvclayers) == 0:
            workingvclayers.new()
        if len(workinguvlayers) == 0:
            workinguvlayers.new()
    
    # Convert Point Data to Corner Data
    if USE_ATTRIBUTES:
        for lyr in workingvclayers:
            if lyr.domain == 'POINT':
                cornerdata = tuple([lyr.data[l.vertex_index].color for l in workingmesh.loops])
                name = lyr.name
                type = lyr.data_type
                workingvclayers.remove(lyr)
                for corner in enumerate(workingvclayers.new(name, type, 'CORNER').data):
                    corner.color = cornerdata[i]
        
    
    instancemats = []
    if instancerun:
        instancemats = [x.matrix_world.copy() for x in dg.object_instances if x.object.name == sourceobj.name]
    
    if not instancemats:
        if (
            sourceobj.instance_type == 'NONE' or
            (sourceobj.instance_type != 'NONE' and sourceobj.show_instancer_for_viewport)
            ):
            instancemats = [workingobj.matrix_world.copy()]
    
    # Data Preparation ===========================================================
    materialvbytes = {}
    materialvcounts = {}
    
    if instancemats:
        PrintStatus(' Setting up data...')
        
        matnames = tuple(x.name if x else "" for x in workingobj.data.materials)
        
        if flip_uvs:
            for uv in (uv for lyr in workinguvlayers for uv in lyr.data):
                uv.uv[1] = 1.0-uv.uv[1]
        
        def GetAttribLayers(layers, targets, is_color=False):
            targets = targets[:]
            if not targets:
                targets = [LYR_RENDER]
            targets += targets * len(attributetypes)
            
            out = []
            
            lyrnames = list(layers.keys())
            for i in range(0, formatsize):
                tar = targets[i]
                # Named layer
                if tar in lyrnames:
                    out += [lyrnames.index(tar)]
                # Selected layer
                elif tar == LYR_SELECT:
                    out += [layers.active_color_index if (USE_ATTRIBUTES and is_color) else layers.active_index]
                # Render layer
                else:
                    out += [layers.render_color_index if (USE_ATTRIBUTES and is_color) else [x.active_render for x in layers].index(True)]
            
            return (tuple(out), lyrnames)
        
        uvattriblyr, uvtargets = GetAttribLayers(workinguvlayers, uvtargets) # list of layer indices to use for attribute
        vcattriblyr, vctargets = GetAttribLayers(workingmesh.color_attributes if USE_ATTRIBUTES else workingvclayers, vctargets, True)
        
        targetvgroups = [
            workingobj.vertex_groups[vgname] if vgname in workingobj.vertex_groups.keys() else None
            for vgname in vgrouptargets
        ]
        
        voffset = 0
        loffset = 0
        
        vertexmeta = ()
        loopmeta = []
        targetpolys = ()
        
        vertcooriginal = {v: v.co for v in workingmesh.vertices}
        normalsign = -1.0 if flip_normals else 1.0
        
        loopnormaloriginal = {l: l.normal*normalsign for l in workingmesh.loops}
        
        # Matrix Loop -----------------------------------------------------------------------------------
        instanceindex = 0
        for instmatrix in instancemats:
            statusheader = ' ' if instanceindex == 0 else ' [%d]' % instanceindex
            
            # Vertices ------------------------------------------------------------------------
            PrintStatus(statusheader+'Setting up vertex data...')
            
            workingvertices = tuple(workingmesh.vertices)
            voffset = len(vertexmeta)
            for v in workingvertices:
                v.co = vertcooriginal[v]
            
            vgroups = workingobj.vertex_groups
            weightdefaults = (1,1,1,1) if len(vgroups) == 0 else (0,0,0,0)
            
            # Map Vertex Groups to Armature Indices
            validvgroups = tuple(vg.index for vg in vgroups)
            vgroupremap = {vg.index: vg.index for vg in vgroups}
            
            if armature:
                if not bone_names:
                    bone_names = tuple([b.name for b in armature.data.bones if (not deform_only or (deform_only and b.use_deform))])
                
                validvgroups = tuple([vg.index for vg in vgroups if vg.name in bone_names])
                vgroupremap = {vg.index: (bone_names.index(vg.name) if vg.name in bone_names else -1) for vg in vgroups}
            
            weightsortkey = lambda x: x.weight
            
            # "Fine. I'll do it myself."
            worldmat = matrix @ instmatrix
            loc, rot, sca = worldmat.decompose()
            
            if process_bones:
                def VEntry(v):
                    co = v.co.copy()
                    co.rotate(rot)
                    co *= sca
                    co += loc
                    
                    # Get VGEs
                    validvges = [vge for vge in v.groups if vge.group in validvgroups]
                    validvges.sort(key=weightsortkey, reverse=True)
                    validvges = validvges[:4]
                    
                    boneindices = tuple(vgroupremap[vge.group] for vge in validvges)
                    weights = tuple(vge.weight for vge in validvges)
                    wlength = sum(weights)
                    
                    if wlength > 0.0:
                        weights = tuple(x/wlength for x in weights)
                    
                    return (
                        tuple(co),
                        tuple( (weight_default if vg == None else 0 if vg.index not in [vge.group for vge in v.groups] else vg.weight(v.index) for vg in targetvgroups) ),
                        tuple(boneindices+(0,0,0,0))[:4], 
                        tuple([int(x) for x in boneindices+(0,0,0,0)])[:4], 
                        tuple(weights+weightdefaults)[:4],
                        tuple([max(0, min(1, int(x*255.0))) for x in weights+weightdefaults])[:4], 
                    )
            else:
                def VEntry(v):
                    co = v.co.copy()
                    co.rotate(rot)
                    co *= sca
                    co += loc
                    
                    return [
                        tuple(co),
                        tuple( (weight_default if vg == None else 0 if vg.index not in [vge.group for vge in v.groups] else vg.weight(v.index) for vg in targetvgroups) ),
                    ]
            
            vertices = {v.index:v for v in workingvertices}
            vertexmeta += tuple(
                tuple(VEntry(v))
                for v in workingvertices
            )
            
            # Loops ------------------------------------------------------------------------------
            PrintStatus(statusheader+'Setting up loop data...')
            
            '''
                LoopMeta for each loop:
                    normal,
                    tangent,
                    bitangent,
                    uvs[numuvlayers]
                        lyr: uv for loop
                    colors[numvclayers]
                        lyr: color for loop
                    colorbytes[numvclayers]
                        lyr: color for loop
            '''
            
            t = time.time()
            
            workingmesh.calc_loop_triangles()
            workingmesh.calc_normals_split()
            
            [l.normal.rotate(rot) for l in workingmesh.loops]
            for l in workingmesh.loops:
                l.normal *= sca
            
            if not edges_only and workingmesh.polygons and process_tangents:
                workingmesh.calc_tangents()
            workingmesh.update()
            
            # Size = Number of attributes that use colors
            targetlayers = set([lyr for i,lyr in enumerate(workingvclayers) if i in vcattriblyr])
            vclayers = tuple([
                tuple([lyr.data[i].color for i in range(0, len(lyr.data))]) if lyr in targetlayers else 0
                for lyr in workingvclayers
                ])
            
            # Size = Number of attributes that use uvs
            targetlayers = set([lyr for i,lyr in enumerate(workinguvlayers) if i in uvattriblyr])
            uvlayers = tuple([
                [lyr.data[i].uv for i in range(0, len(lyr.data))] if lyr in targetlayers else 0
                for lyr in workinguvlayers
                ])
            
            if process_tangents:
                loopmeta += [tuple((
                        tuple(l.normal.normalized()),
                        tuple(l.tangent),
                        tuple(l.bitangent),
                        tuple( (lyr[l.index] if lyr else (0,0) for lyr in uvlayers ) ),
                        tuple( (lyr[l.index] if lyr else (0,0,0,0) for lyr in vclayers ) ),
                        tuple( tuple(int(x*255.0) for x in lyr[l.index]) if lyr else (0,0,0,0) for lyr in vclayers ),
                        tuple( tuple(int(x*255.0) for x in lyr[l.index]) if lyr else (0,0) for lyr in uvlayers ),
                    ))
                    for l in workingmesh.loops
                ]
            else:
                loopmeta += [tuple((
                        tuple(l.normal.normalized()),
                        0,
                        0,
                        tuple( (lyr[l.index] if lyr else (0,0) for lyr in uvlayers ) ),
                        tuple( (lyr[l.index] if lyr else (0,0,0,0) for lyr in vclayers ) ),
                        tuple( tuple(int(x*255.0) for x in lyr[l.index]) if lyr else (0,0,0,0) for lyr in vclayers ),
                        tuple( tuple(int(x*255.0) for x in lyr[l.index]) if lyr else (0,0) for lyr in uvlayers ),
                    ))
                    for l in workingmesh.loops
                ]
            
            tt = time.time()-t
            
            # Poly data -----------------------------------------------------------------------------------------
            PrintStatus(statusheader+'Setting up poly data...')
            
            if workingmesh.polygons:
                if not edges_only: # Triangles
                    invertpoly = reverse_winding
                    for x in sca:
                        if x < 0.0:
                            invertpoly ^= 1
                    
                    looporder = (2, 1, 0) if invertpoly else (0, 1, 2)
                    
                    targetpolys += tuple(
                        (
                            3,
                            looporder,
                            p.material_index,
                            tuple(x+voffset for x in p.vertices),
                            tuple(x+loffset for x in p.loops)
                        )
                        for p in workingmesh.loop_triangles
                    )
                else: # Any N-gons
                    def LoopRepeat(p):
                        out = []
                        loopindices = p.loop_indices
                        count = p.loop_total
                        for i in range(0, count):
                            out.append(i)
                            out.append((i+1) % count)
                        return tuple(out)
                    targetpolys += tuple(
                        (
                            p.loop_total*2,
                            LoopRepeat(p),
                            p.material_index,
                            tuple(x+voffset for x in p.vertices), 
                            tuple(x+loffset for x in p.loop_indices)
                        )
                        for p in workingmesh.polygons
                    )
            else: # Only edges are present
                targetpolys += tuple(
                    (
                        0,
                        (0, 1),
                        0,
                        tuple(x+voffset for x in p.vertices),
                        tuple(x+voffset for x in p.vertices),
                    )
                    for p in workingmesh.edges
                )
            
            instanceindex += 1
            
        # End of matrix loop --------------------------------------------------
        if not loopmeta:
            loopmeta = tuple(
                (
                    tuple(v.normal*normalsign),
                    (0,0,0),
                    (0,0,0),
                    tuple( (0,0) for lyr in uvlayers),
                    tuple( (1,1,1,1) for lyr in vclayers),
                    tuple( (1,1,1,1) for lyr in vclayers),
                    tuple( (0,0) for lyr in uvlayers),
                )
                for v in workingmesh.vertices
            )
        
        vertexmeta = {i: x for i,x in enumerate(vertexmeta)}
        loopmeta = {i: x for i,x in enumerate(loopmeta)}
        
        # Iterate through data ------------------------------------------------------------------------------
        # Optimized to  h e l l
        
        PrintStatus(' Creating byte data...')
        
        # Triangles
        # Anything PER ATTRIBUTE is handled here
        
        def out_pos(out, attribindex, size): out.append(Pack(size*FCODE, *vmeta[0][:size]));
        def out_nor(out, attribindex, size): out.append(Pack(3*FCODE, *lmeta[0][:3]));
        def out_tan(out, attribindex, size): out.append(Pack(3*FCODE, *lmeta[1][:3]));
        def out_btn(out, attribindex, size): out.append(Pack(3*FCODE, *lmeta[2][:3]));
        def out_tex(out, attribindex, size): out.append(Pack(2*FCODE, *lmeta[3][uvattriblyr[attribindex]]));
        def out_col(out, attribindex, size): out.append(Pack(size*FCODE, *(FixColorSpace(lmeta[4][vcattriblyr[attribindex]], gammacorrect[attribindex]))[:size]));
        def out_rgb(out, attribindex, size): out.append(Pack(size*'B', *(FixColorSpaceByte(lmeta[5][vcattriblyr[attribindex]], gammacorrect[attribindex]))[:size]));
        def out_bon(out, attribindex, size): out.append(Pack(size*FCODE, *vmeta[2][:4][:size]));
        def out_boi(out, attribindex, size): out.append(Pack(size*'B', *vmeta[3][:size]));
        def out_wei(out, attribindex, size): out.append(Pack(size*FCODE, *vmeta[4][:4][:size]));
        def out_web(out, attribindex, size): out.append(Pack(size*'B', *vmeta[5][:size]));
        def out_gro(out, attribindex, size): out.append(Pack(FCODE, vmeta[1][attribindex]));
        def out_uvb(out, attribindex, size): out.append(Pack(size*'B', *lmeta[6][uvattriblyr[attribindex]][:size]));
        def out_pad(out, attribindex, size): out.append(Pack(size*FCODE, *paddingfloats[attribindex][:size]));
        def out_pab(out, attribindex, size): out.append(Pack(size*'B', *paddingbytes[attribindex][:size]));
        
        outwritemap = {
            VBF_POS: out_pos, 
            VBF_NOR: out_nor, 
            VBF_TAN: out_tan, 
            VBF_BTN: out_btn,
            VBF_UVS: out_tex, 
            VBF_COL: out_col, 
            VBF_RGB: out_rgb, 
            VBF_BON: out_bon, 
            VBF_BOI: out_boi, 
            VBF_WEI: out_wei, 
            VBF_WEB: out_web,
            VBF_GRO: out_gro,
            VBF_UVB: out_uvb,
            VBF_PAD: out_pad,
            VBF_PAB: out_pab,
        }
        
        format_enumerated = tuple(enumerate(attributetypes))
        
        t = time.time()
        
        # Write data
        for p in targetpolys:
            matkey = p[2]
            
            if matkey not in materialvbytes.keys():
                materialvbytes[matkey] = []
                materialvcounts[matkey] = 0
            materialvcounts[matkey] += p[0]
            outblock = []
            
            for li in p[1]:
                vmeta = vertexmeta[p[3][li]]
                lmeta = loopmeta[p[4][li]]
                
                [outwritemap[attribkey](outblock, attribindex, attributesizes[attribindex]) for attribindex, attribkey in format_enumerated]
            materialvbytes[matkey] += outblock
        
        t = time.time()-t
        
        PrintStatus(' Complete (%s Vertices, %.6f sec)' % (sum(materialvcounts.values()), time.time()-tstart) )
        PrintStatus('\n')
    else:
        PrintStatus(' Object is instancer and hidden. Moving to instances.')
        PrintStatus('\n')
    
    # Remove temp data
    workingobj.to_mesh_clear()
    #bpy.data.objects.remove(workingobj, do_unlink=True)
    
    if armature:
        armature.data.pose_position = lastposestate
    
    # Join byte blocks
    outvbytes = {}
    outvcounts = {}
    for i in materialvbytes.keys():
        if i in range(0, len(matnames)):
            name = matnames[i]
        else:
            name = '<no material>'
        
        if name not in outvbytes.keys():
            outvbytes[name] = b''
            outvcounts[name] = 0
        outvbytes[name] += b''.join(materialvbytes[i])
        outvcounts[name] += materialvcounts[i]
    
    # Instancing
    if sourceobj.instance_type != 'NONE':
        for inst in set([x.object.original for x in dg.object_instances if (x.parent and x.parent.original == sourceobj)]):
            instvbytes, instvcounts = GetVBData(
                self=self,
                context=context,
                sourceobj=inst, # Use instance as object
                format=format,
                
                flip_uvs=flip_uvs,
                max_subdivisions=max_subdivisions,
                modifier_target=modifier_target,
                apply_armature=apply_armature,
                deform_only=deform_only,
                edges_only=edges_only,
                flip_normals=flip_normals,
                reverse_winding=reverse_winding,
                matrix=matrix,
                
                FCODE=FCODE,
                
                color_default=color_default,
                weight_default=weight_default,
                
                instancerun=True,   # Set instance run flag
                )
            
            for k in instvbytes.keys():
                if k not in outvbytes:
                    outvbytes[k] = instvbytes[k]
                    outvcounts[k] = instvcounts[k]
                else:
                    outvbytes[k] += instvbytes[k]
                    outvcounts[k] += instvcounts[k]
    
    return (outvbytes, outvcounts)

# --------------------------------------------------------------------------------------

def ExportVB(
    self,   # VBM_Master
    format,
    filepath,
    
    export_list="",  # If empty string, uses collection
    collection="",  # If empty string, uses objects
    objects=[],
    
    delimiter_start="",
    delimiter_end="",
    compression_level=-1,
    batch='NONE',
    export_hidden=True,
    
    flip_uvs=True,
    max_subdivisions=-1,
    modifier_target=MTY_OR,
    apply_armature=True,
    deform_only=True,
    edges_only=False,
    flip_normals=False,
    reverse_winding=False,
    matrix=mathutils.Matrix()

):
    path = os.path.realpath(bpy.path.abspath(filepath))
    
    if not os.path.exists(os.path.dirname(path)):
        print('> Invalid path specified: "%s"' % path)
        return
    
    print('='*80)
    print('> Beginning ExportVB to root path: "%s"' % path)
    
    context = bpy.context
    
    RemoveTempObjects()
    
    # Get list of selected objects
    objects, targetobjects = ParseObjectLists(context, export_hidden, export_list, collection, objects)
    if len(targetobjects) == 0:
        print('> No valid objects selected.')
        return
    
    active = bpy.context.view_layer.objects.active
    activename = active.name if active else ''
    context.view_layer.objects.active = [x for x in bpy.data.objects if (x.visible_get())][0]
    bpy.ops.object.mode_set(mode = 'OBJECT')
    
    format = context.scene.vbm.formats.FindItem(format) if isinstance(format, str) else format
    
    try:
        # Single file ------------------------------------------------------------------
        if batch == 'NONE':
            out = b''
            for i, obj in enumerate(targetobjects):
                data = context.scene.vbm.GetVBData(
                    context, 
                    obj, 
                    format,
                    
                    flip_uvs=flip_uvs,
                    max_subdivisions=max_subdivisions,
                    modifier_target=modifier_target,
                    apply_armature=apply_armature,
                    deform_only=deform_only,
                    edges_only=edges_only,
                    flip_normals=flip_normals,
                    reverse_winding=reverse_winding,
                    matrix=matrix
                    )[0]
                
                for d in data.values():
                    out += d
            
            CompressAndWrite(out, compression_level, path)
            print("> VB data written to \"%s\"" % path)
        
        # Batch Export ------------------------------------------------------------------
        else:
            rootpath = path[:path.rfind(self.filename_ext)] if self.filename_ext in path else (path + "/")
            outgroups = {} # {groupname: vertexdata}
            vbkeys = []
            
            for obj in targetobjects:
                datapair = context.scene.vbm.GetVBData(
                    context, 
                    obj, 
                    format,
                    
                    flip_uvs=flip_uvs,
                    max_subdivisions=max_subdivisions,
                    modifier_target=modifier_target,
                    apply_armature=apply_armature,
                    deform_only=deform_only,
                    edges_only=edges_only,
                    flip_normals=flip_normals,
                    reverse_winding=reverse_winding,
                    matrix=matrix
                    )
                
                vbytes = datapair[0]
                vcounts = datapair[1]
                vertexcount = sum(datapair[1].values())
                
                # By Object or Mesh name
                if batchexport in ['OBJECT', 'MESH']:
                    if vertexcount:
                        k = obj.name if batchexport == 'OBJECT' else obj.data.name
                        name = FixName(k, delimiter_start, delimiter_end)
                        if name not in vbkeys:
                            vbkeys.append(name)
                            outgroups[name] = [b'', {name: 0}]
                        
                        outgroups[name][0] += b''.join([x for x in vbytes.values()])
                        outgroups[name][1][name] += vertexcount
                # By Material
                elif batchexport == 'MATERIAL':
                    for k, d in vbytes.items():
                        if vcounts[k]:
                            name = FixName(k, delimiter_start, delimiter_end)
                            if name not in vbkeys:
                                vbkeys.append(name)
                                outgroups[name] = [b'', {name: 0}]
                            
                            outgroups[name][0] += vbytes[k]
                            outgroups[name][1][name] += vcounts[k]
                
            # Export each data as individual files
            for name, outgroup in outgroups.items():
                out = outgroup[0]
                outcompressed = zlib.compress(out)
                outlen = (len(out), len(outcompressed))
                
                CompressAndWrite(out, compression_level, rootpath + name + self.filename_ext)
            print("> VB data written to \"%s\"" % rootpath)
    
    except Exception as e:
        raise e
    
    finally:
        # Restore State --------------------------------------------------------
        RemoveTempObjects()
        
        for obj in targetobjects:
            if obj:
                obj.select_set(True)
        
        if activename in [x.name for x in context.selected_objects]:
            context.view_layer.objects.active = bpy.data.objects[activename]

# --------------------------------------------------------------------------------------

def ExportVBM(
    self,   # VBM_Master
    format,
    filepath,
    
    export_list="",  # If empty string, uses collection
    collection="",  # If empty string, uses objects
    objects=[],
    
    delimiter_start="",
    delimiter_end="",
    compression_level=-1,
    batch='NONE',
    export_hidden=True,
    grouping='OBJECT',
    export_armature=True,
    
    flip_uvs=True,
    max_subdivisions=-1,
    modifier_target=MTY_OR,
    apply_armature=False,
    deform_only=True,
    edges_only=False,
    flip_normals=False,
    reverse_winding=False,
    matrix=mathutils.Matrix()
):
    
    path = os.path.realpath(bpy.path.abspath(filepath))
    
    if not os.path.exists(os.path.dirname(path)):
        self.report({'WARNING'}, 'Invalid path specified: "%s"' % path)
        return {'FINISHED'}
    
    print('='*80)
    print('> Beginning ExportVBM to rootpath: "%s"' % path)
    
    RemoveTempObjects()
    
    context = bpy.context
    
    # Get list of selected objects
    objects, targetobjects = ParseObjectLists(context, export_hidden, export_list, collection, objects)
    if len(targetobjects) == 0:
        print('> No valid objects selected.')
        return
    
    active = bpy.context.view_layer.objects.active
    activename = active.name if active else ''
    context.view_layer.objects.active = [x for x in bpy.data.objects if (x.visible_get())][0]
    bpy.ops.object.mode_set(mode = 'OBJECT')
    
    format = context.scene.vbm.formats.FindItem(format) if isinstance(format, str) else format
    
    # Find armature
    armatures = [x for x in objects if x.type == 'ARMATURE']
    armatures += [x.parent for x in objects if (x.parent and x.parent.type == 'ARMATURE')]
    armatures += [x.find_armature() for x in objects if x.find_armature()]
    armatures = list(set(armatures))
    
    armature = None
    bone_names = None
    for obj in objects:
        if obj.type == 'ARMATURE':
            armature = obj
            break
        elif obj.type in VALIDOBJTYPES:
            armature = obj.find_armature()
            if armature:
                break
    
    try:
        # Header ============================================================
        attributelist = format.GetItems()
        
        # Make flag
        flag = 0
        
        # Vertex Format
        out_format = b''
        out_format += Pack('B', len(attributelist)) # Format length
        for i,attribute in enumerate(attributelist):
            out_format += Pack('B', VBFTypeIndex[attribute.type]) # Attribute Type
            out_format += Pack('B', attribute.size) # Attribute Float Size
        
        out_header = b'VBM' + Pack('B', VBMVERSION)
        out_header += Pack('B', flag)
        out_header += out_format
        
        # Compose Bone Data =========================================================
        def ComposeBoneData(armature):
            bone_names = []
            if armature and export_armature:
                print('> Composing armature data...')
                
                sourceobj = armature
                
                # Create armature that copy source's transforms -------------------------------------------------
                bpy.ops.object.mode_set(mode='OBJECT')
                
                workingarmature = bpy.data.armatures.new(name=sourceobj.data.name + '__temp')
                workingobj = bpy.data.objects.new(sourceobj.name + '__temp', workingarmature)
                context.scene.collection.objects.link(workingobj)
                
                # Get bone transforms
                rigbonemeta = {
                    b.name: (
                        b.head_local.copy(), 
                        b.tail_local.copy(), 
                        b.AxisRollFromMatrix(b.matrix_local.to_3x3())[1],
                        b.use_connect
                        )
                        for b in sourceobj.data.bones if b.use_deform
                }
                
                boneparents = {b: p if p else None for b,p in ParseDeformParents(sourceobj).items()}
                
                bpy.ops.object.select_all(action='DESELECT')
                workingobj.select_set(True)
                
                context.view_layer.objects.active = workingobj
                bpy.ops.object.mode_set(mode='EDIT')
                
                editbones = workingobj.data.edit_bones
                
                # Create bones
                for bonename, meta in rigbonemeta.items():
                    if bonename not in editbones.keys():
                        editbones.new(name=bonename)
                    b = editbones[bonename]
                    b.head, b.tail, b.roll, b.use_connect = meta
                    
                for b in editbones:
                    if boneparents[b.name]:
                        b.parent = editbones[boneparents[b.name]]
                
                bpy.ops.object.mode_set(mode='OBJECT')
                
                # Write Data
                out_bone = b''
                
                bones = [b for b in workingarmature.bones if b.use_deform]
                bonemat = {b: (matrix @ b.matrix_local.copy()) for b in bones}
                
                out_bone += Pack('I', len(bones)) # Bone count
                out_bone += b''.join( [PackString(b.name) for b in bones] ) # Bone names
                out_bone += b''.join( [Pack('I', bones.index(b.parent) if b.parent else 0) for b in bones] ) # Bone parent index
                out_bone += b''.join( [ # local matrices
                    PackMatrix('f', (bonemat[b.parent].inverted() @ bonemat[b]) if b.parent else bonemat[b]) 
                    for b in bones
                    ] )
                out_bone += b''.join( [ # inverse matrices
                    PackMatrix('f', bonemat[b].inverted()) 
                    for b in bones
                    ] ) 
                
                bone_names = [b.name for b in bones]
                
                # Delete Temporary
                bpy.data.objects.remove(workingobj, do_unlink=True)
                bpy.data.armatures.remove(workingarmature, do_unlink=True)
                
            else:
                out_bone = Pack('I', 0) # Bone Count
            return (out_bone, bone_names)
        
        out_bone, bone_names = ComposeBoneData(armature)
        
        # Compose Vertex Buffer Data ================================================
        def GetVBGroupSorted(objlist, grouping):
            vbgroups = {}
            vbkeys = []
            vbnumber = {}
            
            for obj in objlist:
                datapair = context.scene.vbm.GetVBData(
                    context, 
                    obj, 
                    format,
                    
                    flip_uvs=flip_uvs,
                    max_subdivisions=max_subdivisions,
                    modifier_target=modifier_target,
                    apply_armature=apply_armature,
                    bone_names=bone_names,
                    deform_only=deform_only,
                    edges_only=edges_only,
                    flip_normals=flip_normals,
                    reverse_winding=reverse_winding,
                    matrix=matrix
                    )
                vbytes = datapair[0]
                vcounts = datapair[1]
                
                # Group by Object
                if grouping == 'OBJECT':
                    name = obj.name
                    name = FixName(name, delimiter_start, delimiter_end)
                    if sum( [len(x) for x in vbytes.values()] ) >= 0:
                        if name not in vbkeys:
                            vbkeys.append(name)
                            vbgroups[name] = b''
                            vbnumber[name] = 0
                        vbgroups[name] += b''.join(vbytes.values())
                        vbnumber[name] += sum(vcounts.values())
                # Group by Material
                elif grouping == 'MATERIAL':
                    for name, vbdata in vbytes.items():
                        vcount = vcounts[name]
                        name = FixName(name, delimiter_start, delimiter_end)
                        if len(vbdata) > 0:
                            if name not in vbkeys:
                                vbkeys.append(name)
                                vbgroups[name] = b''
                                vbnumber[name] = 0
                            vbgroups[name] += vbdata
                            vbnumber[name] += vcount
            
            return (vbgroups, vbnumber, vbkeys)
        
        def FinishVBM(vbgroups, vbnumbers, groupkeys, path=path):
            out_vb = b''
            out_vb += Pack('I', len(vbgroups)) # Number of groups
            out_vb += b''.join( [PackString(name) for name in groupkeys] ) # Group Names
            
            # Write groups
            for name in groupkeys:
                vb = vbgroups[name]
                out_vb += Pack('L', len(vb)) # Size of buffer
                out_vb += Pack('L', vbnumbers[name]) # Number of vertices
                out_vb += vb # Vertex Buffer
            
            # Output to file
            out = out_header + out_vb + out_bone
            CompressAndWrite(out, compression_level, path)
        
        # No Batching
        if batch == 'NONE':
            vbgroups = {}
            vbkeys = []
            vertexcount = 0
            
            vbgroups, vertexcount, vbkeys = GetVBGroupSorted(targetobjects, grouping)
            FinishVBM(vbgroups, vertexcount, vbkeys)
        
        else:
            rootpath = path[:path.rfind(self.filename_ext)] if self.filename_ext in path else (path + "/")
            outgroups = {} # {groupname: vertexdata}
            vbkeys = []
            individualexport = True
            
            # By Name
            if batch in ['OBJECT', 'MESH', 'MATERIAL']:
                for obj in targetobjects:
                    datapair = context.scene.vbm.GetVBData(
                        context, 
                        obj, 
                        format,
                        
                        flip_uvs=flip_uvs,
                        max_subdivisions=max_subdivisions,
                        modifier_target=modifier_target,
                        apply_armature=apply_armature,
                        bone_names=bone_names,
                        deform_only=deform_only,
                        edges_only=edges_only,
                        flip_normals=flip_normals,
                        reverse_winding=reverse_winding,
                        matrix=matrix
                    )
                    vbytes = datapair[0]
                    vcounts = datapair[1]
                    vertexcount = sum(datapair[1].values())
                    
                    # By Object or Mesh name
                    if batch in ['OBJECT', 'MESH']:
                        if vertexcount:
                            k = obj.name if batch == 'OBJECT' else obj.data.name
                            name = FixName(k, delimiter_start, delimiter_end)
                            if name not in vbkeys:
                                vbkeys.append(name)
                                outgroups[name] = [b'', {name: 0}]
                            
                            outgroups[name][0] += b''.join([x for x in vbytes.values()])
                            outgroups[name][1][name] += vertexcount
                    
                    # By Material
                    elif batch == 'MATERIAL':
                        for k, d in vbytes.items():
                            if vcounts[k]:
                                name = FixName(k, delimiter_start, delimiter_end)
                                if name not in vbkeys:
                                    vbkeys.append(name)
                                    outgroups[name] = [b'', {name: 0}]
                                
                                outgroups[name][0] += vbytes[k]
                                outgroups[name][1][name] += vcounts[k]
            
            # By Armature
            elif batch == 'ARMATURE':
                arms = [x for x in armatures if len(x.children) > 0]
                individualexport = True
                
                for armobj in arms:
                    name = armobj.name
                    name = FixName(name, delimiter_start, delimiter_end)
                    if name not in vbkeys:
                        vbkeys.append(name)
                    
                    children = [x for x in armobj.children if ((self.export_hidden and not x.hide_get()) or not self.hidden)]
                    out_bone = ComposeBoneData(armobj)
                    vbgroups, vbnumbers, groupnames = GetVBGroupSorted(children, grouping)
                    
                    if sum(vbnumbers.values()) > 0:
                        FinishVBM(vbgroups, vbnumbers, vbkeys, rootpath + name + self.filename_ext)
                outgroups = {}
            
            # Export each data as individual files
            if individualexport:
                for name, outgroup in outgroups.items():
                    FinishVBM({name: outgroup[0]}, outgroup[1], [name], rootpath + name + self.filename_ext)
    
    except Exception as e:
        raise e
    
    finally:
        # Restore State --------------------------------------------------------
        RemoveTempObjects()
        
        for obj in targetobjects:
            if obj:
                obj.select_set(True)
        
        if activename in [x.name for x in bpy.context.selected_objects]:
            context.view_layer.objects.active = bpy.data.objects[activename]
    
# --------------------------------------------------------------------------------------

class VBM_Master(bpy.types.PropertyGroup):
    formats : bpy.props.PointerProperty(type=VBM_FormatDef_FormatList)
    export_lists : bpy.props.PointerProperty(type=VBM_ExportList_List)
    
    vcnames : bpy.props.CollectionProperty(type=VBM_StringItem)
    uvnames : bpy.props.CollectionProperty(type=VBM_StringItem)
    vgnames : bpy.props.CollectionProperty(type=VBM_StringItem)
    objnames : bpy.props.CollectionProperty(type=VBM_StringItem)
    
    op_refresh_strings : bpy.props.BoolProperty(default=False, update=lambda s,c: s.Update(c))
    
    GetVBData = GetVBData
    ExportVB = ExportVB
    ExportVBM = ExportVBM
    
    def Add(self):
        item = self.items.add()
        self.size += 1
        return item
    
    def RefreshStringLists(self):
        self.vcnames.clear()
        self.uvnames.clear()
        self.vgnames.clear()
        self.objnames.clear()
        
        # Color Layers
        for x in (
            [LYR_GLOBAL, LYR_RENDER, LYR_SELECT] + 
            list(set([x for obj in bpy.data.objects if obj.type == 'MESH' for x in obj.data.color_attributes.keys()]))
        ):
            item = self.vcnames.add()
            item.name = x
        
        # UV Layers
        for x in (
            [LYR_GLOBAL, LYR_RENDER, LYR_SELECT] + 
            list(set([x for obj in bpy.data.objects if obj.type == 'MESH' for x in obj.data.uv_layers.keys()]))
        ):
            item = self.uvnames.add()
            item.name = x
        
        # Vertex Groups
        for x in list(set([x for obj in bpy.data.objects if obj.type == 'MESH' for x in obj.vertex_groups.keys()])):
            item = self.vgnames.add()
            item.name = x
        
        # Objects
        for x in list(set([x for x in bpy.data.objects if x.type == 'MESH'])):
            item = self.objnames.add()
            item.name = x.name
    
    def Update(self, context):
        # Refresh Lists
        if self.op_refresh_strings:
            self.op_refresh_strings = False
            self.RefreshStringLists()
classlist.append(VBM_Master)

'# =========================================================================================================================='
'# REGISTER'
'# =========================================================================================================================='

def register():
    for c in classlist:
        bpy.utils.register_class(c)
    
    bpy.types.Scene.vbm = bpy.props.PointerProperty(name="VBM Master", type=VBM_Master)

def unregister():
    for c in classlist[::-1]:
        bpy.utils.unregister_class(c)
    #del bpy.types.Scene.vbm_formats
    
