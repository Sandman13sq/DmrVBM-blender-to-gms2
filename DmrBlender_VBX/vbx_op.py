import bpy
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

# Float type to use for Packing
# 'f' = float (32bit), 'd' = double (64bit), 'e' = binary16 (16bit)
FCODE = 'f'

PackString = lambda x: b'%c%s' % (len(x), str.encode(x))
PackVector = lambda f, v: struct.pack(f*len(v), *(v[:]))
PackMatrix = lambda f, m: b''.join( [struct.pack(f*4, *x) for x in m.copy().transposed()] )
QuatValid = lambda q: q if q.magnitude != 0.0 else [1.0, 0.0, 0.0, 0.00001]

def CompressAndWrite(self, out, path):
    outcompressed = zlib.compress(out)
    outlen = (len(out), len(outcompressed))
    
    file = open(path, 'wb')
    file.write(outcompressed)
    file.close()
    
    print("Data of size %.2fKB (%.2f%% of original size) written to \"%s\"" % 
            (outlen[1] / 1000, 100.0 * outlen[1] / outlen[0], path) )
    self.report({'INFO'}, 'VB data written to \"%s\"' % path)

def PrintStatus(msg, clear=1, buffersize=40):
    msg = msg + (' '*buffersize*clear)
    sys.stdout.write(msg + (chr(8) * len(msg) * clear))
    sys.stdout.flush()

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

# ------------------------------------------------------------------------------------------

classlist = []

class ExportVBSuper(bpy.types.Operator, ExportHelper):
    bl_options = {'PRESET'}
    
    applyarmature: bpy.props.BoolProperty(
        name="Apply Armature",
        description="Apply armature to meshes",
        default=True,
    )
    
    edgesonly: bpy.props.BoolProperty(
        name="Edges Only",
        description="Export mesh edges only (without triangulation).",
        default=False,
    )
    
    reversewinding: bpy.props.BoolProperty(
        name="Flip Normals",
        description="Flips normals of exported meshes",
        default=False,
    )
    
    maxsubdivisions : bpy.props.IntProperty(
        name="Max Subdivisions", default = 2, min = -1,
        description="Maximum number of subdivisions for Subdivision Surface modifier.\n(-1 for no limit)",
    )
    
    upaxis: bpy.props.EnumProperty(
        name="Up Axis", 
        description="Up Axis to use when Exporting",
        items = UpAxisItems, 
        default='+z',
    )
    
    forwardaxis: bpy.props.EnumProperty(
        name="Forward Axis", 
        description="Forward Axis to use when Exporting",
        items = ForwardAxisItems, 
        default='+y',
    )
    
    scale: bpy.props.FloatVectorProperty(
        name="Data Scale",
        description="Scale to Apply to Export",
        default=(1.0, 1.0, 1.0),
    )
    
    # Vertex Attributes
    VbfProp = lambda i,key: bpy.props.EnumProperty(name="Attribute %d" % i, 
        description='Data to write for each vertex', items=VBFItems, default=key)
    VClyrProp = lambda i: bpy.props.EnumProperty(name="Color Layer", 
        description='Color layer to reference', items=GetVCLayers, default=0)
    UVlyrProp = lambda i: bpy.props.EnumProperty(name="UV Layer", 
        description='UV layer to reference', items=GetUVLayers, default=0)
    vbf0 : VbfProp(0, VBF_POS)
    vbf1 : VbfProp(1, VBF_NOR)
    vbf2 : VbfProp(2, VBF_RGB)
    vbf3 : VbfProp(3, VBF_TEX)
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
    
    uvlayerpick: bpy.props.EnumProperty(
        name="Target UV Layer", 
        description="UV Layer to reference when exporting.",
        items = LayerChoiceItems, default='render',
    )
    
    colorlayerpick: bpy.props.EnumProperty(
        name="Target Color Layer", 
        description="Color Layer to reference when exporting.",
        items = LayerChoiceItems, default='render',
    )
    
    modifierpick: bpy.props.EnumProperty(
        name="Target Modifiers", 
        description="Requirements for modifers when exporting.",
        items = ModChoiceItems, 
        default='OR',
    )
    
    delimiter: bpy.props.StringProperty(
        name="Delimiter Char", 
        description="Grouping will ignore parts of names past this character",
        default='~',
    )
    
    @classmethod
    def poll(self, context):
        return context.selected_objects

# ---------------------------------------------------------------------------------------

def DrawCommonProps(self, context):
    layout = self.layout
    
    c = layout.column_flow(align=1)
    c.prop(self, 'applyarmature', text='Apply Armature')
    c.prop(self, 'edgesonly', text='Edges Only')
    c.prop(self, 'reversewinding', text='Flip Normals')
    c.prop(self, 'upaxis', text='Up Axis')
    c.prop(self, 'forwardaxis', text='Fwd Axis')
    
    r = c.row()
    r.prop(self, 'scale', text='Scale')
    c.prop(self, 'maxsubdivisions', text='Max Subdivisions')

# ---------------------------------------------------------------------------------------

def DrawAttributes(self, context):
    layout = self.layout
    
    b = layout.box()
    b = b.column_flow(align=1)
    r = b.row()
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
        elif vbfkey == VBF_TEX:
            split = c.split(factor=0.25)
            split.label(text='')
            split.prop(self, 'uvlyr%d' % i, text='Layer')
    
    rr = layout.row()
    c = rr.column(align=1)
    c.scale_x = 0.8
    c.label(text='UV Source:')
    c.label(text='Color Source:')
    c.label(text='Modifier Src:')
    c = rr.column(align=1)
    c.prop(self, 'uvlayerpick', text='')
    c.prop(self, 'colorlayerpick', text='')
    c.prop(self, 'modifierpick', text='')

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
            format.append(slot)
            vclayertarget.append(vctarget)
            uvlayertarget.append(uvtarget)
    
    return (format, vclayertarget, uvlayertarget)

# ---------------------------------------------------------------------------------------

def GetCorrectiveMatrix(self, context):
    mattran = mathutils.Matrix()
    u = self.upaxis
    f = self.forwardaxis
    uvec = mathutils.Vector( ((u=='+x')-(u=='-x'), (u=='+y')-(u=='-y'), (u=='+z')-(u=='-z')) )
    fvec = mathutils.Vector( ((f=='+x')-(f=='-x'), (f=='+y')-(f=='-y'), (f=='+z')-(f=='-z')) )
    rvec = fvec.cross(uvec)
    
    mattran = mathutils.Matrix()
    mattran[0][0:3] = rvec
    mattran[1][0:3] = fvec
    mattran[2][0:3] = uvec
    
    mattran = mathutils.Matrix.LocRotScale(None, None, self.scale) @ mattran
    
    return mattran

# ---------------------------------------------------------------------------------------

def FixName(name, delimiter):
    if delimiter in name:
        return name[:name.find(delimiter)]
    return name

# =============================================================================

class DMR_OP_ExportVB(ExportVBSuper, ExportHelper):
    """Exports selected objects as one compressed vertex buffer"""
    bl_idname = "dmr.gm_export_vb"
    bl_label = "Export VB"
    bl_options = {'PRESET'}
    
    # ExportHelper mixin class uses this
    filename_ext = ".vb"
    filter_glob: bpy.props.StringProperty(default="*.vb", options={'HIDDEN'}, maxlen=255)
    
    batchexport: bpy.props.EnumProperty(
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
        
        r = layout.column_flow(align=1)
        r.prop(self, 'batchexport', text='Batch Export')
        r.prop(self, 'delimiter', text='Delimiter')
        
        DrawCommonProps(self, context)
        DrawAttributes(self, context)

    def execute(self, context):
        path = self.filepath
        
        print('='*80)
        print('> Beginning ExportVB to rootpath: "%s"' % path)
        
        format, vclayertarget, uvlayertarget = ParseAttribFormat(self, context)
        mattran = GetCorrectiveMatrix(self, context)
        
        arealast = context.area.type
        context.area.type = "VIEW_3D"
        
        settings = {
            'format' : format,
            'edgesonly' : self.edgesonly,
            'applyarmature' : self.applyarmature,
            'uvlayerpick': self.uvlayerpick == 'render',
            'colorlayerpick': self.colorlayerpick == 'render',
            'matrix': mattran,
            'maxsubdivisions': self.maxsubdivisions,
            'reversewinding': self.reversewinding,
            'scale': self.scale,
        }
        
        RemoveTempObjects()
        active = bpy.context.view_layer.objects.active
        # Get list of selected objects
        objects = [x for x in context.selected_objects if x.type == 'MESH']
        if len(objects) == 0:
            self.report({'WARNING'}, 'No valid objects selected')
        
        bpy.context.view_layer.objects.active = objects[0]
        bpy.ops.object.mode_set(mode = 'OBJECT')
        
        # Single file
        if self.batchexport == 'none':
            out = b''
            for i, obj in enumerate(objects):
                data = GetVBData(obj, format, settings, uvlayertarget, vclayertarget)[0]
                
                for d in data.values():
                    out += d
            
            CompressAndWrite(self, out, path)
            self.report({'INFO'}, 'VB data written to \"%s\"' % path)
        # Batch Export
        else:
            rootpath = path[:path.rfind('.vb')] if '.vb' in path else path
            outgroups = {} # {groupname: vertexdata}
            
            for i, obj in enumerate(objects):
                vbdata = GetVBData(obj, format, settings, uvlayertarget, vclayertarget)[0]
                
                # By Object Name
                if self.batchexport == 'obj':
                    name = obj.name
                    name = FixName(name, self.delimiter)
                    outgroups[name] = outgroups.get(name, b'')
                    outgroups[name] += b''.join([x for x in vbdata.values()])
                # By Mesh Name
                elif self.batchexport == 'mesh':
                    name = obj.data.name
                    name = FixName(name, self.delimiter)
                    outgroups[name] = outgroups.get(name, b'')
                    outgroups[name] += b''.join([x for x in vbdata.values()])
                # By Material Name
                elif self.batchexport == 'mat':
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
        
        # Restore state
        RemoveTempObjects()
        for obj in objects: 
            obj.select_set(1)
        
        bpy.context.view_layer.objects.active = active
        
        context.area.type = arealast
        
        return {'FINISHED'}
classlist.append(DMR_OP_ExportVB)

# =============================================================================

class DMR_OP_ExportVBX(ExportVBSuper, bpy.types.Operator):
    """Exports selected objects as vbx data"""
    bl_idname = "dmr.gm_export_vbx"
    bl_label = "Export VBX"
    bl_options = {'PRESET'}

    # ExportHelper mixin class uses this
    filename_ext = ".vbx"
    filter_glob : bpy.props.StringProperty(default='*'+filename_ext, options={'HIDDEN'}, maxlen=255)
    
    batchexport: bpy.props.EnumProperty(
        name="Batch Export",
        description="Export selected objects as separate files.",
        items = (
            ('none', 'No Batching', 'All objects will be written to a single file'),
            ('obj', 'By Object Name', 'Objects will be written to "<filename><object_name>.vbx" by object'),
            ('mesh', 'By Mesh Name', 'Objects will be written to "<filename><mesh_name>.vbx" by mesh'),
            ('mat', 'By Material', 'Objects will be written to "<filename><material_name>.vbx" by material'),
            ('armature', 'By Parent Armature', 'Objects will be written to "<filename><armature_name>.vbx" by parent armature'),
            ('empty', 'By Parent Empty', 'Objects will be written to "<filename><emptyname>.vbx" by parent empty'),
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
    
    exportarmature : bpy.props.BoolProperty(
        name="Export Armature", default = True,
        description="Include any selected or related armature on export",
    )
    
    deformbonesonly: bpy.props.BoolProperty(
        name="Deform Bones Only", default=False,
        description='Only export bones with the "Deform" flag set.',
    )
    
    floattype : bpy.props.EnumProperty(
        name="Float Type", 
        description='Data type to export floats in for vertex attributes and bone matrices', 
        items=FloatChoiceItems, default='f'
    )
    
    def draw(self, context):
        layout = self.layout
        
        c = layout.column(align=1)
        c.prop(self, 'batchexport', text='Batch Export')
        c.prop(self, 'grouping', text='Grouping')
        c.prop(self, 'delimiter', text='Delimiter')
        
        r = layout.column_flow(align=1)
        r.prop(self, 'exportarmature', text='Export Armature')
        r.prop(self, 'deformbonesonly', text='Deform Bones Only')
        
        DrawCommonProps(self, context)
        DrawAttributes(self, context)
        
    def execute(self, context):
        path = self.filepath
        FCODE = self.floattype
        
        print('='*80)
        print('> Beginning ExportVBX to rootpath: "%s"' % path)
        
        format, vclayertarget, uvlayertarget = ParseAttribFormat(self, context)
        mattran = GetCorrectiveMatrix(self, context)
        
        settings = {
            'format' : format,
            'edgesonly' : self.edgesonly,
            'applyarmature' : self.applyarmature,
            'uvlayerpick': self.uvlayerpick == 'render',
            'colorlayerpick': self.colorlayerpick == 'render',
            'modifierpick': self.modifierpick,
            'maxsubdivisions': self.maxsubdivisions,
            'deformonly' : self.deformbonesonly,
            'matrix': mattran,
            'reversewinding': self.reversewinding,
            'scale': self.scale,
        }
        
        arealast = context.area.type
        context.area.type = "VIEW_3D"
        
        active = bpy.context.view_layer.objects.active
        activename = active.name if active else None
        
        RemoveTempObjects()
        
        # Get list of selected objects
        objects = [x for x in bpy.context.selected_objects if x.type == 'MESH']
        armatures = [x for x in bpy.context.selected_objects if x.type == 'ARMATURE']
        armatures += [x.parent for x in objects if (x.parent and x.parent.type == 'ARMATURE')]
        armatures += [
            m.object
            for x in objects if x.type == 'MESH'
            for m in x.modifiers if (m.type == 'ARMATURE' and m.object)
        ]
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
        
        bpy.context.view_layer.objects.active = objects[0]
        bpy.ops.object.mode_set(mode = 'OBJECT')
        
        # Header ============================================================
        
        # Make flag
        flag = 0
        if self.floattype == 'd':
            flag |= 1 << 0
        elif self.floattype == 'e':
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
            if armature and self.exportarmature:
                print('> Composing armature data...')
                
                workingarmature = armature.data.copy()
                workingobj = bpy.data.objects.new(armature.name+'__temp', workingarmature)
                
                # Apply matrix
                bpy.context.view_layer.active_layer_collection.collection.objects.link(workingobj)
                workingobj.select_set(True)
                bpy.context.view_layer.objects.active = workingobj
                workingobj.matrix_world = settings.get('matrix', mathutils.Matrix())
                bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
                
                bones = workingarmature.bones[:]
                if settings.get('deformonly', False):
                    bones = [b for b in workingarmature.bones if b.use_deform]
                
                # Write Data
                out_bone = b''
                
                out_bone += Pack('H', len(bones))
                out_bone += b''.join( [PackString(b.name) for b in bones] )
                out_bone += b''.join( [Pack('H', bones.index(b.parent) if b.parent else 0) for b in bones] )
                out_bone += b''.join( [PackMatrix('f',
                    (b.parent.matrix_local.inverted() @ b.matrix_local)
                    if b.parent else b.matrix_local) for b in bones] )
                out_bone += b''.join( [PackMatrix('f', mattran @ b.matrix_local.inverted()) for b in bones] )
                
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
            vbnumber = {}
            
            for obj in objlist:
                datapair = GetVBData(obj, format, settings, uvlayertarget, vclayertarget)
                data = datapair[0]
                vcounts = datapair[1]
                
                # Group by Object
                if self.grouping == 'OBJ':
                    name = obj.name
                    name = FixName(name, self.delimiter)
                    if sum( [len(x) for x in data.values()] ) >= 0:
                        vbgroups[name] = vbgroups.get(name, b'')
                        vbnumber[name] = vbnumber.get(name, 0)
                        for vbdata in data.values():
                            vbgroups[name] += vbdata
                        vbnumber[name] += sum(vcounts.values())
                # Group by Material
                elif self.grouping == 'MAT':
                    for name, vbdata in data.items():
                        name = FixName(name, self.delimiter)
                        if len(vbdata) > 0:
                            vbgroups[name] = vbgroups.get(name, b'')
                            vbnumber[name] = vbnumber.get(name, 0)
                            vbgroups[name] += vbdata
                            vbnumber[name] += vbnumber[name]
            return (vbgroups, vbnumber)
        
        def FinishVBX(vbgroups, vbnumbers, path=self.filepath):
            out_vb = b''
            out_vb += Pack('H', len(vbgroups)) # Number of groups
            out_vb += b''.join( [PackString(name) for name in vbgroups.keys()] ) # Group Names
            
            # Write groups
            for name, vb in vbgroups.items():
                out_vb += Pack('L', len(vb)) # Size of buffer
                out_vb += Pack('L', vbnumbers[name]) # Number of vertices
                out_vb += vb # Vertex Buffer
            
            # Output to file
            out = out_header + out_vb + out_bone
            CompressAndWrite(self, out, path)
        
        # No Batching
        if self.batchexport == 'none':
            vbgroups = {}
            vertexcount = 0
            
            vbgroups, vertexcount = GetVBGroupSorted(objects)
            FinishVBX(vbgroups, vertexcount)
        else:
            rootpath = path[:path.rfind(self.filename_ext)] if self.filename_ext in path else path
            outgroups = {} # {groupname: vertexdata}
            dooutexport = True
            
            # By Object Name
            if self.batchexport == 'obj':
                for obj in objects:
                    name = obj.name
                    name = FixName(name, self.delimiter)
                    datapair = GetVBData(obj, format, settings, uvlayertarget, vclayertarget)
                    data = datapair[0]
                    vertexcount = sum(datapair[1].values())
                    vbgroups = {name: b''.join([x for x in data.values()])}
                    outgroups[name] = (vbgroups, {name: vertexcount})
            # By Mesh Name
            elif self.batchexport == 'mesh':
                for obj in objects:
                    name = obj.data.name
                    name = FixName(name, self.delimiter)
                    datapair = GetVBData(obj, format, settings, uvlayertarget, vclayertarget)
                    data = datapair[0]
                    vertexcount = sum(datapair[1].values())
                    vbgroups = {name: b''.join([x for x in data.values()])}
                    outgroups[name] = (vbgroups, {name: vertexcount})
            # By Material Name
            elif self.batchexport == 'mat':
                for obj in objects:
                    datapair = GetVBData(obj, format, settings, uvlayertarget, vclayertarget)
                    data = datapair[0]
                    
                    for name, d in data.items():
                        name = FixName(name, self.delimiter)
                        vertexcount = datapair[1][name]
                        vbgroups = {name: b''.join([x for x in data.values()])}
                        if name not in outgroups.keys():
                            outgroups[name] = [vbgroups, [vertexcount]]
                        else:
                            for g in outgroups[name][0].values():
                                g += d
            # By Armature
            elif self.batchexport == 'armature':
                arms = [x for x in armatures if len(x.children) > 0]
                dooutexport = True
                print('> Arms: %s' % armatures)
                
                for armobj in arms:
                    name = armobj.name
                    name = FixName(name, self.delimiter)
                    print('> %s: %s' % (armobj.name, [x.name for x in armobj.children]) )
                    out_bone = ComposeBoneData(armobj)
                    vbgroups, vbnumbers = GetVBGroupSorted([x for x in armobj.children])
                    if sum(vbnumbers.values()) > 0:
                        FinishVBX(vbgroups, vbnumbers, rootpath + name + self.filename_ext)
                outgroups = {}
            
            # Export each data as individual files
            if dooutexport:
                for name, outgroup in outgroups.items():
                    FinishVBX(outgroup[0], outgroup[1], rootpath + name + self.filename_ext)
        
        # Restore State --------------------------------------------------------
        
        RemoveTempObjects()
        for obj in objects: 
            obj.select_set(1)
        
        if activename in [x.name for x in bpy.context.selected_objects]:
            bpy.context.view_layer.objects.active = bpy.data.objects[activename]
        
        context.area.type = arealast
        
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

