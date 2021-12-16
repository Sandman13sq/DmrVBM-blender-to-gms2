import bpy
import struct
import zlib
import sys
import mathutils

from bpy_extras.io_utils import ExportHelper
from struct import pack as Pack

from dmr_gm_func_vb import *

# Float type to use for Packing
# 'f' = float (32bit), 'd' = double (64bit), 'e' = binary16 (16bit)
FCODE = 'f';

PackString = lambda x: b'%c%s' % (len(x), str.encode(x));
PackVector = lambda f, v: struct.pack(f*len(v), *(v[:]));
PackMatrix = lambda f, m: b''.join( [struct.pack(f*4, *x) for x in m.copy().transposed()] );
QuatValid = lambda q: q if q.magnitude != 0.0 else [1.0, 0.0, 0.0, 0.00001];

# ------------------------------------------------------------------------------------------

classlist = [];

# =============================================================================

class DMR_OP_ExportVB(bpy.types.Operator, ExportHelper):
    """Exports selected objects as one compressed vertex buffer"""
    bl_idname = "dmr.gm_export_vb";
    bl_label = "Export VB";
    bl_options = {'PRESET'};
    
    # ExportHelper mixin class uses this
    filename_ext = ".vb";
    filter_glob: bpy.props.StringProperty(default="*.vb", options={'HIDDEN'}, maxlen=255);
    
    applyarmature: bpy.props.BoolProperty(
        name="Apply Armature",
        description="Apply armature to meshes",
        default=True,
    );
    
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
    );
    
    edgesonly: bpy.props.BoolProperty(
        name="Edges Only",
        description="Export mesh edges only (without triangulation).",
        default=False,
    );
    
    yflip: bpy.props.BoolProperty(
        name="Flip Y Axis",
        description="Flip mesh on Y Axis",
        default=False,
    );
    
    maxsubdivisions : bpy.props.IntProperty(
        name="Max Subdivisions", default = 2, min = -1,
        description="Maximum number of subdivisions for Subdivision Surface modifier.\n(-1 for no limit)",
    );
    
    upaxis: bpy.props.EnumProperty(
        name="Up Axis", 
        description="Up Axis to use when Exporting",
        items = UpAxisItems, 
        default='+z',
    );
    
    forwardaxis: bpy.props.EnumProperty(
        name="Forward Axis", 
        description="Forward Axis to use when Exporting",
        items = ForwardAxisItems, 
        default='+y',
    );
    
    # Vertex Attributes
    VbfProp = lambda i,key: bpy.props.EnumProperty(name="Attribute %d" % i, 
        description='Data to write for each vertex', items=VBFItems, default=key);
    VClyrProp = lambda i: bpy.props.EnumProperty(name="Color Layer", 
        description='Color layer to reference', items=GetVCLayers, default=0);
    UVlyrProp = lambda i: bpy.props.EnumProperty(name="UV Layer", 
        description='UV layer to reference', items=GetUVLayers, default=0);
    vbf0 : VbfProp(0, VBF_POS);
    vbf1 : VbfProp(1, VBF_NOR);
    vbf2 : VbfProp(2, VBF_CO2);
    vbf3 : VbfProp(3, VBF_TEX);
    vbf4 : VbfProp(4, VBF_000);
    vbf5 : VbfProp(5, VBF_000);
    vbf6 : VbfProp(6, VBF_000);
    vbf7 : VbfProp(7, VBF_000);
    
    vclyr0 : VClyrProp(0);
    vclyr1 : VClyrProp(1);
    vclyr2 : VClyrProp(2);
    vclyr3 : VClyrProp(3);
    vclyr4 : VClyrProp(4);
    vclyr5 : VClyrProp(5);
    vclyr6 : VClyrProp(6);
    vclyr7 : VClyrProp(7);
    
    uvlyr0 : UVlyrProp(0);
    uvlyr1 : UVlyrProp(1);
    uvlyr2 : UVlyrProp(2);
    uvlyr3 : UVlyrProp(3);
    uvlyr4 : UVlyrProp(4);
    uvlyr5 : UVlyrProp(5);
    uvlyr6 : UVlyrProp(6);
    uvlyr7 : UVlyrProp(7);
    
    uvlayerpick: bpy.props.EnumProperty(
        name="Target UV Layer", 
        description="UV Layer to reference when exporting.",
        items = LayerChoiceItems, 
        default='render',
    );
    
    colorlayerpick: bpy.props.EnumProperty(
        name="Target Color Layer", 
        description="Color Layer to reference when exporting.",
        items = LayerChoiceItems, 
        default='render',
    );
    
    modifierpick: bpy.props.EnumProperty(
        name="Target Modifiers", 
        description="Requirements for modifers when exporting.",
        items = ModChoiceItems, 
        default='OR',
    );
    
    def draw(self, context):
        layout = self.layout;
        
        r = layout.column_flow(align=1);
        r.prop(self, 'applyarmature', text='Apply Armature');
        r.prop(self, 'batchexport', text='Batch Export');
        r.prop(self, 'edgesonly', text='Edges Only');
        r.prop(self, 'yflip', text='Y Flip');
        r.prop(self, 'maxsubdivisions', text='Max Subdivisions');
        r.prop(self, 'upaxis', text='Up Axis');
        r.prop(self, 'forwardaxis', text='Forward Axis');
        
        b = layout.box();
        b = b.column_flow(align=1);
        r = b.row();
        r.alignment = 'CENTER';
        r.label(text='Vertex Attributes');
        
        # Draw attributes
        for i in range(0, 8):
            b.prop(self, 'vbf%d' % i, text='Attrib%d' % i);
            
            vbfkey = getattr(self, 'vbf%d' % i);
            
            if vbfkey == VBF_000:
                break;
            
            if vbfkey == VBF_COL or vbfkey == VBF_CO2:
                r = b.row();
                r.prop(self, 'vclyr%d' % i, text='vclyr%d' % i);
            elif vbfkey == VBF_TEX:
                r = b.row();
                r.prop(self, 'uvlyr%d' % i, text='uvlyr%d' % i);
        
        rr = layout.row();
        c = rr.column(align=1);
        c.scale_x = 0.8;
        c.label(text='UV Source:');
        c.label(text='Color Source:');
        c.label(text='Modifier Src:');
        c = rr.column(align=1);
        c.prop(self, 'uvlayerpick', text='');
        c.prop(self, 'colorlayerpick', text='');
        c.prop(self, 'modifierpick', text='');

    def execute(self, context):
        format = [];
        vclayertarget = [];
        uvlayertarget = [];
        
        for i in range(0, 8):
            slot = getattr(self, 'vbf%d' % i);
            vctarget = getattr(self, 'vclyr%d' % i);
            uvtarget = getattr(self, 'uvlyr%d' % i);
            
            print('%d: %s' % (i, (vctarget, uvtarget)))
            
            if slot != VBF_000:
                format.append(slot);
                vclayertarget.append(vctarget);
                uvlayertarget.append(uvtarget);
        
        mattran = mathutils.Matrix();
        u = self.upaxis;
        f = self.forwardaxis;
        uvec = mathutils.Vector( ((u=='+x')-(u=='-x'), (u=='+y')-(u=='-y'), (u=='+z')-(u=='-z')) );
        fvec = mathutils.Vector( ((f=='+x')-(f=='-x'), (f=='+y')-(f=='-y'), (f=='+z')-(f=='-z')) );
        rvec = fvec.cross(uvec);
        
        mattran = mathutils.Matrix();
        mattran[0][0:3] = rvec;
        mattran[1][0:3] = fvec;
        mattran[2][0:3] = uvec;
        
        settings = {
            'format' : format,
            'edgesonly' : self.edgesonly,
            'applyarmature' : self.applyarmature,
            'uvlayerpick': self.uvlayerpick == 'render',
            'colorlayerpick': self.colorlayerpick == 'render',
            'yflip': self.yflip,
            'matrix': mattran,
            'maxsubdivisions': self.maxsubdivisions,
        };
        
        FCODE = 'f';
        
        RemoveTempObjects();
        active = bpy.context.view_layer.objects.active;
        # Get list of selected objects
        objects = [x for x in context.selected_objects if x.type == 'MESH'];
        if len(objects) == 0:
            self.report({'WARNING'}, 'No valid objects selected');
        
        path = self.filepath;
        
        
        # Single file
        if self.batchexport == 'none':
            out = b'';
            for i, obj in enumerate(objects):
                print('> Composing data for \"%s\"...' % obj.name);
                data = GetVBData(obj, format, settings, uvlayertarget, vclayertarget);
                
                for d in data.values():
                    out += d;
            
            outcompressed = zlib.compress(out);
            outlen = (len(out), len(outcompressed));
            
            file = open(path, 'wb');
            file.write(outcompressed);
            file.close();
            
            print("VB data of size %.2fKB (%.2f%% of original size) written to \"%s\"" % 
                    (outlen[1] / 1000, 100.0 * outlen[1] / outlen[0], path) );
            self.report({'INFO'}, 'VB data written to \"%s\"' % path);
        # Batch Export
        else:
            rootpath = path;
            rootpath = rootpath[:rootpath.rfind('.vb')];
            if rootpath[-1] != '/' and rootpath[-1] != '\\':
                rootpath += '/';
                
            outgroups = {}; # {materialname: vertexdata}
            
            for i, obj in enumerate(objects):
                print('> Composing data for \"%s\"...' % obj.name);
                d = GetVBData(obj, format, settings, uvlayertarget, vclayertarget);
                
                # By Object Name
                if self.batchexport == 'obj':
                    name = obj.name;
                    if name not in outgroups.keys():
                        outgroups[name] = b'';
                    outgroups[name] += b''.join([x for x in d.values()]);
                # By Mesh Name
                elif self.batchexport == 'mesh':
                    name = obj.data.name;
                    if name not in outgroups.keys():
                        outgroups[name] = b'';
                    outgroups[name] += b''.join([x for x in d.values()]);
                # By Material Name
                elif self.batchexport == 'mat':
                    for name, d in data.items():
                        if name not in outgroups.keys():
                            outgroups[name] = b'';
                        outgroups[name] += b''.join([x for x in d.values()]);
            
            # Export each data as individual files
            for name, data in outgroups.items():
                out = data;
                outcompressed = zlib.compress(out);
                outlen = (len(out), len(outcompressed));
                
                path = rootpath + name + self.filename_ext;
                file = open(path, 'wb');
                file.write(outcompressed);
                file.close();
                print("VB data of size %.2fKB (%.2f%% of original size) written to \"%s\"" % 
                    (outlen[1] / 1000, 100.0 * outlen[1] / outlen[0], path) );
            self.report({'INFO'}, 'VB data written to \"%s\"' % rootpath);
        
        # Restore state
        RemoveTempObjects();
        for obj in objects: 
            obj.select_set(1);
        
        bpy.context.view_layer.objects.active = active;
        
        return {'FINISHED'}
classlist.append(DMR_OP_ExportVB);

# =============================================================================

class DMR_OP_ExportVBX(bpy.types.Operator, ExportHelper):
    """Exports selected objects as vbx data"""
    bl_idname = "dmr.gm_export_vbx";
    bl_label = "Export VBX";
    bl_options = {'PRESET'};

    # ExportHelper mixin class uses this
    filename_ext = ".vbx"
    filter_glob : bpy.props.StringProperty(default='*'+filename_ext, options={'HIDDEN'}, maxlen=255);
    
    grouping : bpy.props.EnumProperty(
        name="Mesh Grouping",
        description="Choose to export vertices grouped by object or material",
        items=(
            ('OBJ', "By Object", "Objects -> VBs"),
            ('MAT', "By Material", "Materials -> VBs"),
        ),
        default='OBJ',
    );
    
    applyarmature: bpy.props.BoolProperty(
        name="Apply Armature",
        description="Apply armature to meshes",
        default=False,
    );
    
    exportarmature : bpy.props.BoolProperty(
        name="Export Armature", default = True,
        description="Include any selected or related armature on export",
    );
    
    edgesonly: bpy.props.BoolProperty(
        name="Edges Only",
        description="Export mesh edges only (without triangulation).",
        default=False,
    );
    
    yflip: bpy.props.BoolProperty(
        name="Flip Y Axis",
        description="Flip mesh on Y Axis",
        default=False,
    );
    
    maxsubdivisions : bpy.props.IntProperty(
        name="Max Subdivisions", default = 2, min = -1,
        description="Maximum number of subdivisions for Subdivision Surface modifier.\n(-1 for no limit)",
    );
    
    floattype : bpy.props.EnumProperty(
        name="Float Type", 
        description='Data type to export floats in for vertex attributes and bone matrices', 
        items=FloatChoiceItems, default='f'
    );
    
    # Vertex Attributes
    VbfProp = lambda i,key: bpy.props.EnumProperty(name="Attribute %d" % i, 
        description='Data to write for each vertex', items=VBFItems, default=key);
    VClyrProp = lambda i: bpy.props.EnumProperty(name="Color Layer", 
        description='Color layer to reference', items=GetVCLayers, default=0);
    UVlyrProp = lambda i: bpy.props.EnumProperty(name="UV Layer", 
        description='UV layer to reference', items=GetUVLayers, default=0);
    vbf0 : VbfProp(0, VBF_POS);
    vbf1 : VbfProp(1, VBF_NOR);
    vbf2 : VbfProp(2, VBF_CO2);
    vbf3 : VbfProp(3, VBF_TEX);
    vbf4 : VbfProp(4, VBF_000);
    vbf5 : VbfProp(5, VBF_000);
    vbf6 : VbfProp(6, VBF_000);
    vbf7 : VbfProp(7, VBF_000);
    
    vclyr0 : VClyrProp(0);
    vclyr1 : VClyrProp(1);
    vclyr2 : VClyrProp(2);
    vclyr3 : VClyrProp(3);
    vclyr4 : VClyrProp(4);
    vclyr5 : VClyrProp(5);
    vclyr6 : VClyrProp(6);
    vclyr7 : VClyrProp(7);
    
    uvlyr0 : UVlyrProp(0);
    uvlyr1 : UVlyrProp(1);
    uvlyr2 : UVlyrProp(2);
    uvlyr3 : UVlyrProp(3);
    uvlyr4 : UVlyrProp(4);
    uvlyr5 : UVlyrProp(5);
    uvlyr6 : UVlyrProp(6);
    uvlyr7 : UVlyrProp(7);
    
    uvlayerpick: bpy.props.EnumProperty(
        name="Target UV Layer", 
        description="UV Layer to reference when exporting.",
        items = LayerChoiceItems, default='render',
    );
    
    colorlayerpick: bpy.props.EnumProperty(
        name="Target Color Layer", 
        description="Color Layer to reference when exporting.",
        items = LayerChoiceItems, default='render',
    );
    
    modifierpick: bpy.props.EnumProperty(
        name="Target Modifiers", 
        description="Requirements for modifers when exporting.",
        items = ModChoiceItems, 
        default='OR',
    );
    
    def draw(self, context):
        layout = self.layout;
        layout.prop(self, 'grouping', text='Grouping');
        
        r = layout.column_flow(align=1);
        r.prop(self, 'applyarmature', text='Apply Armature');
        r.prop(self, 'exportarmature', text='Export Armature');
        r.prop(self, 'edgesonly', text='Edges Only');
        r.prop(self, 'yflip', text='Y Flip');
        r.prop(self, 'maxsubdivisions', text='Max Subdivisions');
        
        b = layout.box();
        b = b.column_flow(align=1);
        # Draw attributes
        for i in range(0, 8):
            b.prop(self, 'vbf%d' % i, text='Attrib%d' % i);
            
            vbfkey = getattr(self, 'vbf%d' % i);
            
            if vbfkey == VBF_000:
                break;
            
            if vbfkey == VBF_COL or vbfkey == VBF_CO2:
                r = b.row();
                r.prop(self, 'vclyr%d' % i, text='vclyr%d' % i);
            elif vbfkey == VBF_TEX:
                r = b.row();
                r.prop(self, 'uvlyr%d' % i, text='uvlyr%d' % i);
        
        rr = layout.row();
        c = rr.column(align=1);
        c.scale_x = 0.8;
        c.label(text='UV Source:');
        c.label(text='Color Source:');
        c.label(text='Modifier Src:');
        c = rr.column(align=1);
        c.prop(self, 'uvlayerpick', text='');
        c.prop(self, 'colorlayerpick', text='');
        c.prop(self, 'modifierpick', text='');
        
    def execute(self, context):
        format = [];
        vclayertarget = [];
        uvlayertarget = [];
        
        for i in range(0, 8):
            slot = getattr(self, 'vbf%d' % i);
            vctarget = getattr(self, 'vclyr%d' % i);
            uvtarget = getattr(self, 'uvlyr%d' % i);
            
            print('%d: %s' % (i, (vctarget, uvtarget)))
            
            if slot != VBF_000:
                format.append(slot);
                vclayertarget.append(vctarget);
                uvlayertarget.append(uvtarget);
        
        settings = {
            'format' : format,
            'edgesonly' : self.edgesonly,
            'applyarmature' : self.applyarmature,
            'uvlayerpick': self.uvlayerpick == 'render',
            'colorlayerpick': self.colorlayerpick == 'render',
            'modifierpick': self.modifierpick,
            'maxsubdivisions': self.maxsubdivisions,
            'yflip' : self.yflip,
        };
        
        active = bpy.context.view_layer.objects.active;
        activename = active.name;
        
        path = self.filepath;
        FCODE = self.floattype;
        
        RemoveTempObjects();
        
        # Get list of selected objects
        objects = [x for x in context.selected_objects if x.type == 'MESH'];
        if len(objects) == 0:
            self.report({'WARNING'}, 'No valid objects selected');
        
        # Find armature
        armature = None;
        for obj in objects:
            if obj.type == 'ARMATURE':
                armature = obj;
                break;
            elif obj.type == 'MESH':
                for m in obj.modifiers:
                    if m.type == 'ARMATURE':
                        if m.object:
                            armature = m.object;
                            break;
        
        if not armature:
            self.report({'WARNING'}, 'No armature found in object selection or modifiers.');
        
        # Compose Vertex Buffer Data ================================================
        """
            vbcount (2B)
            vbnames[vbcount] ((1 + name length)B each)
            vbdata[vbcount]
                vbcompressedsize (4B)
                vbcompresseddata (vbcompressedsize B)
        """
        
        vbgroups = {};
        
        for obj in objects:
            print('> Composing data for \"%s\"...' % obj.name);
            data = GetVBData(obj, format, settings, uvlayertarget, vclayertarget);
            
            # Group by Object
            if self.grouping == 'OBJ':
                # No data
                if sum( [len(x) for x in data.values()] ) == 0:
                    continue;
                
                if obj.name not in vbgroups.keys():
                    vbgroups[obj.name] = b'';
                for vbdata in data.values():
                    vbgroups[obj.name] += vbdata;
            # Group by Material
            elif self.grouping == 'MAT':
                for name, vbdata in data.items():
                    if len(vbdata) == 0:
                        continue;
                    
                    if name not in vbgroups.keys():
                        vbgroups[name] = b'';
                    vbgroups[name] += vbdata;
        
        out_vb = b'';
        
        # Number of groups
        out_vb += Pack('H', len(vbgroups));
        # Group Names
        out_vb += b''.join( [PackString(name) for name in vbgroups.keys()] );
        
        # Write groups
        for name, vb in vbgroups.items():
            #chunk = struct.pack('<%s' % ('f' * len(vb)), *vb);
            chunk = vb;
            vbcompressed = zlib.compress(chunk);
            print('%s compressed size: %d' % (name, len(vbcompressed)));
            out_vb += Pack('L', len(vbcompressed));
            out_vb += vbcompressed;
        
        # Compose Bone Data =========================================================
        """
            bonecount (2B)
            bonenames[bonecount] ((1 + name length)B each)
            parentindices[bonecount] (2B)
            localmatrices[bonecount] (16f each)
            inversemodelmatrices[bonecount] (16f each)
        """
        
        if armature:
            bones = armature.data.bones[:];
            out_bone = b'';
            
            out_bone += Pack('H', len(bones));
            out_bone += b''.join( [PackString(b.name) for b in bones] );
            out_bone += b''.join( [Pack('H', bones.index(b.parent) if b.parent else 0) for b in bones] );
            out_bone += b''.join( [PackMatrix('f',
                (b.parent.matrix_local.inverted() @ b.matrix_local)
                if b.parent else b.matrix_local) for b in bones] );
            out_bone += b''.join( [PackMatrix('f', b.matrix_local.inverted()) for b in bones] );
        else:
            out_bone = Pack('H', 0);
        
        # Header ============================================================
        
        # Make flag
        flag = 0;
        if self.floattype == 'd':
            flag |= 1 << 0;
        elif self.floattype == 'e':
            flag |= 1 << 1;
        
        # Vertex Format
        out_format = b'';
        out_format += Pack('B', len(format)); # Format length
        for f in format:
            out_format += Pack('B', VBFType[f]); # Attribute Type
            out_format += Pack('B', VBFSize[f]); # Attribute Float Size
        
        out = b'VBX' + Pack('B', VBXVERSION) + Pack('B', flag) + out_format + out_vb + out_bone;
        outcompressed = zlib.compress(out);
        outlen = (len(out), len(outcompressed));
        
        file = open(path, 'wb');
        file.write(outcompressed);
        file.close();
        
        RemoveTempObjects();
        if activename in [x.name for x in bpy.context.selected_objects]:
            bpy.context.view_layer.objects.active = bpy.data.objects[activename];
        
        for obj in objects: obj.select_set(1);
        
        print('FCODE: %s' % FCODE);
        
        print("VB data of size %.2fKB (%.2f%% of original size) written to \"%s\"" % 
                (outlen[1] / 1000, 100.0 * outlen[1] / outlen[0], path) );
        self.report({'INFO'}, 'VBX data written to \"%s\"' % path);
        
        
        return {'FINISHED'};
classlist.append(DMR_OP_ExportVBX);

# =============================================================================

def register():
    print('='*80)
    for c in classlist:
        bpy.utils.register_class(c)

def unregister():
    for c in classlist:
        bpy.utils.unregister_class(c)
