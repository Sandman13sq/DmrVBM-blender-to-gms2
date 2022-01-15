import bpy
import os
import struct
import zlib
import sys
import mathutils

from bpy_extras.io_utils import ExportHelper
from struct import pack as Pack

try:
    from .vbx_func import *
except:
    from vbx_func import *

# VBX Format:
"""
    'VBX' (3B)
    VBX version (1B)
    flags (1B)
    
    formatlength (1B)
    formatentry[formatlength]
        attributetype (1B)
        attributefloatsize (1B)
    
    vbcount (2B)
    vbnames[vbcount] ((1 + name length)B each)
    vbdata[vbcount]
        vbcompressedsize (4B)
        vbcompresseddata (vbcompressedsize B)
    
    bonecount (2B)
    bonenames[bonecount] ((1 + name length)B each)
    parentindices[bonecount] (2B)
    localmatrices[bonecount] (16f each)
    inversemodelmatrices[bonecount] (16f each)
"""


EXPORTLISTHEADER = '<exportlist>'

# Float type to use for Packing
# 'f' = float (32bit), 'd' = double (64bit), 'e' = binary16 (16bit)
#FCODE = 'f'

PackString = lambda x: b'%c%s' % (len(x), str.encode(x))
PackVector = lambda f, v: struct.pack(f*len(v), *(v[:]))
PackMatrix = lambda f, m: b''.join( [struct.pack(f*4, *x) for x in m.copy().transposed()] )
QuatValid = lambda q: q if q.magnitude != 0.0 else [1.0, 0.0, 0.0, 0.00001]

# ---------------------------------------------------------------------------------------

def PrintStatus(msg, clear=1, buffersize=40):
    msg = msg + (' '*buffersize*clear)
    sys.stdout.write(msg + (chr(8) * len(msg) * clear))
    sys.stdout.flush()

# ---------------------------------------------------------------------------------------

def CompressAndWrite(self, out, path):
    outcompressed = zlib.compress(out, level=self.compression_level)
    outlen = (len(out), len(outcompressed))
    
    file = open(path, 'wb')
    file.write(outcompressed)
    file.close()
    
    print("Data of size %.2fKB (%.2f%% of original size) written to \"%s\"" % 
            (outlen[1] / 1000, 100.0 * outlen[1] / outlen[0], path) )
    #self.report({'INFO'}, 'VB data written to \"%s\"' % path)

# ---------------------------------------------------------------------------------------

def DrawCommonProps(self, context):
    layout = self.layout
    
    c = layout.column_flow(align=1)
    c.prop(self, 'apply_armature', text='Apply Armature')
    c.prop(self, 'deform_only', text='Deform Only', emboss=self.apply_armature)
    
    b = c.box()
    r = b.row(align=1)
    r.alignment = 'CENTER'
    r.prop(self, 'more_options', text='== Show More Options ==')
    
    if self.more_options:
        c = b.column_flow(align=1)
        
        c.prop(self, 'export_hidden', text='Export Hidden')
        c.prop(self, 'edges_only', text='Edges Only')
        c.prop(self, 'reverse_winding', text='Flip Normals')
        c.prop(self, 'flip_uvs', text='Flip UVs')
        
        r = c.row(align=1)
        r.prop(self, 'up_axis', text='')
        r.prop(self, 'forward_axis', text='')
        
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
        c.prop(self, 'max_subdivisions', text='Max Subdivisions')
        c.prop(self, 'compression_level', text='Compression')

# ---------------------------------------------------------------------------------------

def DrawAttributes(self, context):
    layout = self.layout
    
    b = layout.box()
    b = b.column_flow(align=1)
    r = b.row(align=1)
    r.alignment = 'CENTER'
    r.label(text='Vertex Attributes')
    
    # Draw attributes
    l = 0
    for i in range(0, 8):
        if getattr(self, 'vbf%d' % i) != VBF_000:
            l = i+2;
        
    for i in range(0, min(l, 8)):
        c = b.row().column(align=1)
        
        c.prop(self, 'vbf%d' % i, text='Attrib%d' % i)
        
        vbfkey = getattr(self, 'vbf%d' % i)
        
        if vbfkey == VBF_COL or vbfkey == VBF_RGB:
            split = c.split(factor=0.25)
            split.label(text='')
            split.prop(self, 'vclyr%d' % i, text='Layer')
        elif vbfkey == VBF_UVS:
            split = c.split(factor=0.25)
            split.label(text='')
            split.prop(self, 'uvlyr%d' % i, text='Layer')

# ---------------------------------------------------------------------------------------

def ParseAttribFormat(self, context):
    format = []
    vclayertarget = []
    uvlayertarget = []
    
    for i in range(0, 8):
        slot = getattr(self, 'vbf%d' % i)
        vctarget = getattr(self, 'vclyr%d' % i)
        uvtarget = getattr(self, 'uvlyr%d' % i)
        
        if slot != VBF_000:
            if vctarget == LYR_GLOBAL:
                vctarget = LYR_RENDER if self.color_layer_target == 'render' else LYR_SELECT
            if uvtarget == LYR_GLOBAL:
                uvtarget = LYR_RENDER if self.uv_layer_target == 'render' else LYR_SELECT
            
            format.append(slot)
            vclayertarget.append(vctarget)
            uvlayertarget.append(uvtarget)
    print('> Format:', format)
    return (format, vclayertarget, uvlayertarget)

# ---------------------------------------------------------------------------------------

def GetCorrectiveMatrix(self, context):
    mattran = mathutils.Matrix()
    u = self.up_axis
    f = self.forward_axis
    uvec = mathutils.Vector( ((u=='+x')-(u=='-x'), (u=='+y')-(u=='-y'), (u=='+z')-(u=='-z')) )
    fvec = mathutils.Vector( ((f=='+x')-(f=='-x'), (f=='+y')-(f=='-y'), (f=='+z')-(f=='-z')) )
    rvec = fvec.cross(uvec)
    
    # Create rotation
    mattran = mathutils.Matrix()
    mattran[0][0:3] = rvec
    mattran[1][0:3] = fvec
    mattran[2][0:3] = uvec
    
    # Create and apply scale
    mattran = mathutils.Matrix.LocRotScale(None, None, self.scale) @ mattran
    
    return mattran

# --------------------------------------------------------------------------------------------------

def Items_Collections(self, context):
    out = [('<selected>', '(Selected Objects)', 'Export selected objects', 'RESTRICT_SELECT_OFF', 0)]
    
    # Export Lists
    for i, x in enumerate(context.scene.vbx_exportlists):
        out += [(EXPORTLISTHEADER+'%s' % x.name, x.name, 'Export from export list "%s"' % x.name, 'PRESET', len(out))]
    
    # Iterate through scene collections
    def ColLoop(c, out, depth=0):
        out += [(c.name, '. '*depth+c.name, 'Export all objects in collection "%s"' % c.name, 'OUTLINER_COLLECTION', len(out))]
        
        for cc in c.children:
            ColLoop(cc, out, depth+1)
    ColLoop(context.scene.collection, out)
    return out

# ---------------------------------------------------------------------------------------

def CollectionToObjectList(self, context):
    name = self.collection_name
    
    print('> Collection = %s' % name.replace(EXPORTLISTHEADER, ''))
    
    objs = []
    alphasort = lambda x: x.name
    
    # Scene Collection
    if name == context.scene.collection.name:
        objs = sorted([x for x in context.scene.collection.all_objects], key=alphasort)
    # Export List
    elif name[:len(EXPORTLISTHEADER)] == EXPORTLISTHEADER:
        exportlistname = name[len(EXPORTLISTHEADER):]
        exportlists = list(context.scene.vbx_exportlists)
        listnames = [x.name for x in exportlists]
        if exportlistname in listnames:
            blendobjects = bpy.data.objects
            exportlist = exportlists[listnames.index(exportlistname)]
            objs = [blendobjects[x.objname] for x in exportlist.entries if x.objname in blendobjects.keys()]
    # Collections
    if not objs:
        if name in [x.name for x in bpy.data.collections]:
            objs = sorted([x for x in bpy.data.collections[name].all_objects], key=alphasort)
        # Selected Objects
        else:
            objs = sorted([x for x in context.selected_objects], key=alphasort)
    
    if not self.export_hidden:
        objs = [x for x in objs if not x.hide_get()]
    
    return objs

# ---------------------------------------------------------------------------------------

def FixName(name, delimiter):
    if delimiter in name:
        return name[:name.find(delimiter)]
    return name

# =============================================================================

classlist = []

class ExportVBSuper(bpy.types.Operator, ExportHelper):
    bl_options = {'PRESET'}
    
    more_options: bpy.props.BoolProperty(
        name="More Options", default=False,
        description="Show more export options",
    )
    
    collection_name: bpy.props.EnumProperty(
        name='Collection', default=0, items=Items_Collections,
        description='Collection to export objects from',
    )
    
    delimiter: bpy.props.StringProperty(
        name="Delimiter Char", default='.',
        description='Grouping will ignore parts of names past this character. \nEx: if delimiter = ".", "model_body.head" -> "model_body"',
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
    
    compression_level: bpy.props.IntProperty(
        name="Compression Level", default=-1, min=-1, max=9,
        description="Level of zlib compression to apply to export.\n0 for no compression. -1 for zlib default compression",
    )
    
    # Vertex Attributes
    VbfProp = lambda i,key: bpy.props.EnumProperty(name="Attribute %d" % i, 
        description='Data to write for each vertex', items=Items_VBF, default=key)
    VClyrProp = lambda i: bpy.props.EnumProperty(name="Color Layer", 
        description='Color layer to reference', items=Items_VCLayers, default=0)
    UVlyrProp = lambda i: bpy.props.EnumProperty(name="UV Layer", 
        description='UV layer to reference', items=Items_UVLayers, default=0)
    vbf0 : VbfProp(0, VBF_POS)
    vbf1 : VbfProp(1, VBF_000)
    vbf2 : VbfProp(2, VBF_RGB)
    vbf3 : VbfProp(3, VBF_UVS)
    vbf4 : VbfProp(4, VBF_000)
    vbf5 : VbfProp(5, VBF_000)
    vbf6 : VbfProp(6, VBF_000)
    vbf7 : VbfProp(7, VBF_000)
    
    vclyr0 : VClyrProp(0)
    vclyr1 : VClyrProp(1)
    vclyr2 : VClyrProp(2)
    vclyr3 : VClyrProp(3)
    vclyr4 : VClyrProp(4)
    vclyr5 : VClyrProp(5)
    vclyr6 : VClyrProp(6)
    vclyr7 : VClyrProp(7)
    
    uvlyr0 : UVlyrProp(0)
    uvlyr1 : UVlyrProp(1)
    uvlyr2 : UVlyrProp(2)
    uvlyr3 : UVlyrProp(3)
    uvlyr4 : UVlyrProp(4)
    uvlyr5 : UVlyrProp(5)
    uvlyr6 : UVlyrProp(6)
    uvlyr7 : UVlyrProp(7)

# =============================================================================

class DMR_OP_ExportVB(ExportVBSuper, ExportHelper):
    """Exports selected objects as one compressed vertex buffer"""
    bl_idname = "dmr.vbx_export_vb"
    bl_label = "Export VB"
    bl_options = {'PRESET'}
    
    # ExportHelper mixin class uses this
    filename_ext = ".vb"
    filter_glob: bpy.props.StringProperty(default="*.vb", options={'HIDDEN'}, maxlen=255)
    
    batch_export: bpy.props.EnumProperty(
        name="Batch Export",
        description="Export selected objects as separate files.",
        items = (
            ('none', 'No Batching', 'All objects will be written to a single file'),
            ('obj', 'By Object Name', 'Objects will be written to "<filename><objectname>.vb" by object'),
            ('mesh', 'By Mesh Name', 'Objects will be written to "<filename><meshname>.vb" by mesh'),
            ('mat', 'By Material', 'Objects will be written to "<filename><materialname>.vb" by material'),
        ),
        default='none',
    )
    
    def draw(self, context):
        layout = self.layout
        
        c = layout.column_flow(align=1)
        c.prop(self, 'collection_name', text='Collection')
        c.prop(self, 'batch_export', text='Batching')
        c.prop(self, 'delimiter', text='Delimiter')
        
        DrawCommonProps(self, context)
        DrawAttributes(self, context)

    def execute(self, context):
        path = self.filepath
        
        if not os.path.exists(os.path.dirname(path)):
            self.info({'WARNING'}, 'Invalid path specified: "%s"' % path)
            return {'FINISHED'}
        
        print('='*80)
        print('> Beginning ExportVB to rootpath: "%s"' % path)
        
        format, vclayertarget, uvlayertarget = ParseAttribFormat(self, context)
        mattran = GetCorrectiveMatrix(self, context)
        
        settings = {
            'format' : format,
            'edgesonly' : self.edges_only,
            'applyarmature' : self.apply_armature,
            'uvlayertarget': self.uv_layer_target == 'render',
            'colorlayertarget': self.color_layer_target == 'render',
            'matrix': mattran,
            'maxsubdivisions': self.max_subdivisions,
            'flipnormals': self.flip_normals,
            'reversewinding': self.reverse_winding,
            'flipuvs': self.flip_uvs,
            'floattype': self.float_type,
        }
        
        RemoveTempObjects()
        
        # Get list of selected objects
        objects = CollectionToObjectList(self, context)
        targetobjects = [x for x in objects if x.type == 'MESH']
        if len(targetobjects) == 0:
            self.report({'WARNING'}, 'No valid objects selected')
            return {'FINISHED'}
        
        active = bpy.context.view_layer.objects.active
        activename = active.name if active else ''
        
        context.view_layer.objects.active = [x for x in bpy.data.objects if (x.visible_get())][0]
        bpy.ops.object.mode_set(mode = 'OBJECT')
        
        batchexport = self.batch_export
        # Single file
        if batchexport == 'none':
            out = b''
            for i, obj in enumerate(targetobjects):
                data = GetVBData(context, obj, format, settings, uvlayertarget, vclayertarget)[0]
                
                for d in data.values():
                    out += d
            
            CompressAndWrite(self, out, path)
            self.report({'INFO'}, 'VB data written to \"%s\"' % path)
        # Batch Export
        else:
            rootpath = path[:path.rfind('.vb')] if '.vb' in path else path
            outgroups = {} # {groupname: vertexdata}
            
            for i, obj in enumerate(targetobjects):
                vbdata = GetVBData(context, obj, format, settings, uvlayertarget, vclayertarget)[0]
                
                # By Object Name
                if batchexport == 'obj':
                    name = obj.name
                    name = FixName(name, self.delimiter)
                    outgroups[name] = outgroups.get(name, b'')
                    outgroups[name] += b''.join([x for x in vbdata.values()])
                # By Mesh Name
                elif batchexport == 'mesh':
                    name = obj.data.name
                    name = FixName(name, self.delimiter)
                    outgroups[name] = outgroups.get(name, b'')
                    outgroups[name] += b''.join([x for x in vbdata.values()])
                # By Material Name
                elif batchexport == 'mat':
                    for name, d in vbdata.items():
                        name = FixName(name, self.delimiter)
                        outgroups[name] = outgroups.get(name, b'')
                        outgroups[name] += d
            
            # Export each data as individual files
            for name, data in outgroups.items():
                out = data
                outcompressed = zlib.compress(out)
                outlen = (len(out), len(outcompressed))
                
                CompressAndWrite(self, out, rootpath + name + self.filename_ext)
            self.report({'INFO'}, 'VB data written to \"%s\"' % rootpath)
        
        # Restore State --------------------------------------------------------
        RemoveTempObjects()
        
        if activename in [x.name for x in bpy.context.selected_objects]:
            context.view_layer.objects.active = bpy.data.objects[activename]
        
        return {'FINISHED'}
classlist.append(DMR_OP_ExportVB)

# =============================================================================

class DMR_OP_ExportVBX(ExportVBSuper, bpy.types.Operator):
    """Exports selected objects as vbx data"""
    bl_idname = "dmr.vbx_export_vbx"
    bl_label = "Export VBX"
    bl_options = {'PRESET'}

    # ExportHelper mixin class uses this
    filename_ext = ".vbx"
    filter_glob : bpy.props.StringProperty(default='*'+filename_ext, options={'HIDDEN'}, maxlen=255)
    
    batch_export: bpy.props.EnumProperty(
        name="Batch Export",
        description="Export selected objects as separate files.",
        items = (
            ('none', 'No Batching', 'All objects will be written to a single file'),
            ('obj', 'By Object Name', 'Objects will be written to "<filename><object_name>.vbx" by object'),
            ('mesh', 'By Mesh Name', 'Objects will be written to "<filename><mesh_name>.vbx" by mesh'),
            ('mat', 'By Material', 'Objects will be written to "<filename><material_name>.vbx" by material'),
            ('armature', 'By Parent Armature', 'Objects will be written to "<filename><armature_name>.vbx" by parent armature'),
            #('empty', 'By Parent Empty', 'Objects will be written to "<filename><emptyname>.vbx" by parent empty'),
        ),
        default='none',
    )
    
    grouping : bpy.props.EnumProperty(
        name="Mesh Grouping",
        description="Choose to export vertices grouped by object or material",
        items=(
            ('OBJ', "By Object", "Objects -> VBs"),
            ('MAT', "By Material", "Materials -> VBs"),
        ),
        default='OBJ',
    )
    
    export_armature : bpy.props.BoolProperty(
        name="Export Armature", default = True,
        description="Include any selected or related armature on export",
    )
    
    float_type : bpy.props.EnumProperty(
        name="Float Type", 
        description='Data type to export floats in for vertex attributes and bone matrices', 
        items=Items_FloatChoice, default='f'
    )
    
    def draw(self, context):
        layout = self.layout
        
        c = layout.column(align=1)
        c.prop(self, 'collection_name', text='Collection')
        c.prop(self, 'batch_export', text='Batching')
        c.prop(self, 'grouping', text='Grouping')
        c.prop(self, 'delimiter', text='Delimiter')
        
        r = layout.column_flow(align=1)
        r.prop(self, 'export_armature', text='Export Armature')
        r.prop(self, 'deform_only', text='Deform Bones Only')
        
        DrawCommonProps(self, context)
        DrawAttributes(self, context)
        
    def execute(self, context):
        path = self.filepath
        FCODE = self.float_type
        
        if not os.path.exists(os.path.dirname(path)):
            self.info({'WARNING'}, 'Invalid path specified: "%s"' % path)
            return {'FINISHED'}
        
        print('='*80)
        print('> Beginning ExportVBX to rootpath: "%s"' % path)
        
        format, vclayertarget, uvlayertarget = ParseAttribFormat(self, context)
        mattran = GetCorrectiveMatrix(self, context)
        
        settings = {
            'format' : format,
            'edgesonly' : self.edges_only,
            'applyarmature' : self.apply_armature,
            'modifierpick': self.modifier_target,
            'maxsubdivisions': self.max_subdivisions,
            'deformonly' : self.deform_only,
            'matrix': mattran,
            'flipnormals': self.flip_normals,
            'reversewinding': self.reverse_winding,
            'flipuvs': self.flip_uvs,
            'floattype': self.float_type,
        }
        
        RemoveTempObjects()
        
        # Get list of selected objects
        objects = CollectionToObjectList(self, context)
        targetobjects = [x for x in objects if x.type == 'MESH']
        if len(targetobjects) == 0:
            self.report({'WARNING'}, 'No valid objects selected')
            return {'FINISHED'}
        
        active = bpy.context.view_layer.objects.active
        activename = active.name if active else ''
        
        context.view_layer.objects.active = [x for x in bpy.data.objects if (x.visible_get())][0]
        
        armatures = [x for x in objects if x.type == 'ARMATURE']
        armatures += [x.parent for x in objects if (x.parent and x.parent.type == 'ARMATURE')]
        armatures += [x.find_armature() for x in objects if x.find_armature()]
        armatures = list(set(armatures))
        
        # Find armature
        armature = None
        for obj in objects:
            if obj.type == 'ARMATURE':
                armature = obj
                break
            elif obj.type == 'MESH':
                armature = obj.find_armature()
                if armature:
                    break
        
        # Header ============================================================
        
        # Make flag
        flag = 0
        if self.float_type == 'd':
            flag |= 1 << 0
        elif self.float_type == 'e':
            flag |= 1 << 1
        
        # Vertex Format
        out_format = b''
        out_format += Pack('B', len(format)) # Format length
        for f in format:
            out_format += Pack('B', VBFType[f]) # Attribute Type
            out_format += Pack('B', VBFSize[f]) # Attribute Float Size
        
        out_header = b'VBX' + Pack('B', VBXVERSION)
        out_header += Pack('B', flag)
        out_header += out_format
        
        # Compose Bone Data =========================================================
        """
            bonecount (2B)
            bonenames[bonecount] ((1 + name length)B each)
            parentindices[bonecount] (2B)
            localmatrices[bonecount] (16f each)
            inversemodelmatrices[bonecount] (16f each)
        """
        
        def ComposeBoneData(armature):
            if armature and self.export_armature:
                print('> Composing armature data...')
                
                workingarmature = armature.data.copy()
                workingobj = bpy.data.objects.new(armature.name+'__temp', workingarmature)
                settingsmatrix = settings.get('matrix', mathutils.Matrix())
                
                bones = workingarmature.bones[:]
                if settings.get('deformonly', False):
                    bones = [b for b in workingarmature.bones if b.use_deform]
                bonemat = {b: (settingsmatrix @ b.matrix_local.copy()) for b in bones}
                
                # Write Data
                out_bone = b''
                
                out_bone += Pack('H', len(bones))
                out_bone += b''.join( [PackString(b.name) for b in bones] )
                out_bone += b''.join( [Pack('H', bones.index(b.parent) if b.parent else 0) for b in bones] )
                out_bone += b''.join( [PackMatrix('f',
                    (bonemat[b.parent].inverted() @ bonemat[b])
                    if b.parent else bonemat[b]) for b in bones] )
                out_bone += b''.join( [PackMatrix('f', bonemat[b].inverted()) for b in bones] )
                
                # Delete Temporary
                bpy.data.objects.remove(workingobj)
                bpy.data.armatures.remove(workingarmature)
                
            else:
                out_bone = Pack('H', 0)
            return out_bone
        
        out_bone = ComposeBoneData(armature)
        
        # Compose Vertex Buffer Data ================================================
        """
            vbcount (2B)
            vbnames[vbcount] ((1 + name length)B each)
            vbdata[vbcount]
                vbsize (4B)
                vbvertexcount (4B)
                vbcompresseddata (vbsize B)
        """
        
        def GetVBGroupSorted(objlist):
            vbgroups = {}
            vbkeys = []
            vbnumber = {}
            
            grouping = self.grouping
            
            for obj in objlist:
                datapair = GetVBData(context, obj, format, settings, uvlayertarget, vclayertarget)
                data = datapair[0]
                vcounts = datapair[1]
                
                # Group by Object
                if grouping == 'OBJ':
                    name = obj.name
                    name = FixName(name, self.delimiter)
                    if name not in vbkeys:
                        vbkeys.append(name)
                    if sum( [len(x) for x in data.values()] ) >= 0:
                        vbgroups[name] = vbgroups.get(name, b'')
                        vbnumber[name] = vbnumber.get(name, 0)
                        for vbdata in data.values():
                            vbgroups[name] += vbdata
                        vbnumber[name] += sum(vcounts.values())
                # Group by Material
                elif grouping == 'MAT':
                    for name, vbdata in data.items():
                        name = FixName(name, self.delimiter)
                        if name not in vbkeys:
                            vbkeys.append(name)
                        if len(vbdata) > 0:
                            vbgroups[name] = vbgroups.get(name, b'')
                            vbnumber[name] = vbnumber.get(name, 0)
                            vbgroups[name] += vbdata
                            vbnumber[name] += vbnumber[name]
            
            return (vbgroups, vbnumber, vbkeys)
        
        def FinishVBX(vbgroups, vbnumbers, groupkeys, path=self.filepath):
            out_vb = b''
            out_vb += Pack('H', len(vbgroups)) # Number of groups
            out_vb += b''.join( [PackString(name) for name in groupkeys] ) # Group Names
            
            # Write groups
            for name in groupkeys:
                vb = vbgroups[name]
                out_vb += Pack('L', len(vb)) # Size of buffer
                out_vb += Pack('L', vbnumbers[name]) # Number of vertices
                out_vb += vb # Vertex Buffer
            
            # Output to file
            out = out_header + out_vb + out_bone
            CompressAndWrite(self, out, path)
        
        # No Batching
        batchexport = self.batch_export
        if batchexport == 'none':
            vbgroups = {}
            vbkeys = []
            vertexcount = 0
            
            vbgroups, vertexcount, vbkeys = GetVBGroupSorted(targetobjects)
            FinishVBX(vbgroups, vertexcount, vbkeys)
        else:
            rootpath = path[:path.rfind(self.filename_ext)] if self.filename_ext in path else path
            outgroups = {} # {groupname: vertexdata}
            dooutexport = True
            
            # By Object Name
            if batchexport == 'obj':
                for obj in targetobjects:
                    name = obj.name
                    name = FixName(name, self.delimiter)
                    if name not in vbkeys:
                        vbkeys.append(name)
                    datapair = GetVBData(context, obj, format, settings, uvlayertarget, vclayertarget)
                    data = datapair[0]
                    vertexcount = sum(datapair[1].values())
                    vbgroups = {name: b''.join([x for x in data.values()])}
                    outgroups[name] = (vbgroups, {name: vertexcount})
            # By Mesh Name
            elif batchexport == 'mesh':
                for obj in targetobjects:
                    name = obj.data.name
                    name = FixName(name, self.delimiter)
                    if name not in vbkeys:
                        vbkeys.append(name)
                    datapair = GetVBData(context, obj, format, settings, uvlayertarget, vclayertarget)
                    data = datapair[0]
                    vertexcount = sum(datapair[1].values())
                    vbgroups = {name: b''.join([x for x in data.values()])}
                    outgroups[name] = (vbgroups, {name: vertexcount})
            # By Material Name
            elif batchexport == 'mat':
                for obj in targetobjects:
                    datapair = GetVBData(context, obj, format, settings, uvlayertarget, vclayertarget)
                    data = datapair[0]
                    
                    for name, d in data.items():
                        name = FixName(name, self.delimiter)
                        if name not in vbkeys:
                            vbkeys.append(name)
                        vertexcount = datapair[1][name]
                        vbgroups = {name: b''.join([x for x in data.values()])}
                        if name not in outgroups.keys():
                            outgroups[name] = [vbgroups, [vertexcount]]
                        else:
                            for g in outgroups[name][0].values():
                                g += d
            # By Armature
            elif batchexport == 'armature':
                arms = [x for x in armatures if len(x.children) > 0]
                dooutexport = True
                print('> Arms: %s' % armatures)
                
                for armobj in arms:
                    name = armobj.name
                    name = FixName(name, self.delimiter)
                    if name not in vbkeys:
                        vbkeys.append(name)
                    print('> %s: %s' % (armobj.name, [x.name for x in armobj.children]) )
                    out_bone = ComposeBoneData(armobj)
                    vbgroups, vbnumbers = GetVBGroupSorted([x for x in armobj.children])
                    if sum(vbnumbers.values()) > 0:
                        FinishVBX(vbgroups, vbnumbers, vbkeys, rootpath + name + self.filename_ext)
                outgroups = {}
            
            # Export each data as individual files
            if dooutexport:
                for name, outgroup in outgroups.items():
                    FinishVBX(outgroup[0], outgroup[1], rootpath + name + self.filename_ext)
        
        # Restore State --------------------------------------------------------
        RemoveTempObjects()
        
        if activename in [x.name for x in bpy.context.selected_objects]:
            context.view_layer.objects.active = bpy.data.objects[activename]
        
        self.report({'INFO'}, 'VBX export complete')
        
        return {'FINISHED'}
classlist.append(DMR_OP_ExportVBX)

# =============================================================================

def register():
    for c in classlist:
        bpy.utils.register_class(c)

def unregister():
    for c in reversed(classlist):
        bpy.utils.unregister_class(c)

