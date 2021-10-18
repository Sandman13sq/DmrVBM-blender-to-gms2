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

class DMR_GM_ExportVB(bpy.types.Operator, ExportHelper):
    """Exports selected objects as one compressed vertex buffer"""
    bl_idname = "dmr.gm_export_vb";
    bl_label = "Export VB";
    
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
    vbf0 : VbfProp(0, VBF_POS);
    vbf1 : VbfProp(1, VBF_NOR);
    vbf2 : VbfProp(2, VBF_CO2);
    vbf3 : VbfProp(3, VBF_TEX);
    vbf4 : VbfProp(4, VBF_000);
    vbf5 : VbfProp(5, VBF_000);
    vbf6 : VbfProp(6, VBF_000);
    vbf7 : VbfProp(7, VBF_000);
    
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

    def execute(self, context):
        active = bpy.context.view_layer.objects.active;
        format = [];
        for x in '01234567':
            slot = getattr(self, 'vbf' + x);
            if slot != VBF_000:
                format.append(slot);
        
        settings = {
            'format' : format,
            'edgesonly' : self.edgesonly,
            'applyarmature' : 0,
            'uvlayerpick': self.uvlayerpick == 'render',
            'colorlayerpick': self.colorlayerpick == 'render',
            #'maxsubdivisions': self.maxsubdivisions,
            'yflip' : self.yflip,
        };
        
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
        };
        
        FCODE = 'f';
        
        # Get list of selected objects
        objects = [x for x in context.selected_objects if x.type == 'MESH'];
        if len(objects) == 0:
            self.report({'WARNING'}, 'No valid objects selected');
        
        path = self.filepath;
        
        # Single file
        if self.batchexport == 'none':
            out = b'';
            for obj in objects:
                print('> Composing data for \"%s\"...' % obj.name);
                data = GetVBData(obj, format, settings);
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
            outgroups = {}; # {materialname: vertexdata}
            
            for obj in objects:
                print('> Composing data for \"%s\"...' % obj.name);
                d = GetVBData(obj, format, settings);
                
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
        for obj in objects: 
            obj.select_set(1);
        
        bpy.context.view_layer.objects.active = active;
        
        return {'FINISHED'}
classlist.append(DMR_GM_ExportVB);

# =============================================================================

class DMR_GM_ExportVBX(bpy.types.Operator, ExportHelper):
    """Exports selected objects as vbx data"""
    bl_idname = "dmr.gm_export_vbx";
    bl_label = "Export VBX";

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
        default='MAT',
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
        name="Max Subdivisions", default = 1, min = -1,
        description="Maximum number of subdivisions for Subdivision Surface modifier.\n(-1 for no limit)",
    );
    
    floattype : bpy.props.EnumProperty(
        name="Float Type", 
        description='Data type to export floats in for vertex attributes and bone matrices', 
        items=FloatChoiceItems, 
        default='f'
    );
    
    # Vertex Attributes
    VbfProp = lambda i,key: bpy.props.EnumProperty(name="Attribute %d" % i, 
        description='Data to write for each vertex', items=VBFItems, default=key);
    vbf0 : VbfProp(0, VBF_POS);
    vbf1 : VbfProp(1, VBF_NOR);
    vbf2 : VbfProp(2, VBF_TAN);
    vbf3 : VbfProp(3, VBF_BTN);
    vbf4 : VbfProp(4, VBF_CO2);
    vbf5 : VbfProp(5, VBF_TEX);
    vbf6 : VbfProp(6, VBF_BON);
    vbf7 : VbfProp(7, VBF_WEI);
    
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

    def execute(self, context):
        active = bpy.context.view_layer.objects.active;
        format = [];
        for x in '01234567':
            slot = getattr(self, 'vbf' + x);
            if slot != VBF_000:
                format.append(slot);
        
        settings = {
            'format' : format,
            'edgesonly' : self.edgesonly,
            'applyarmature' : 0,
            'uvlayerpick': self.uvlayerpick == 'render',
            'colorlayerpick': self.colorlayerpick == 'render',
            'maxsubdivisions': self.maxsubdivisions,
            'yflip' : self.yflip,
        };
        
        path = self.filepath;
        FCODE = self.floattype;
        
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
            self.report({'WARNING'}, 'No armature found in object selection or modifiers. Aborting export.');
            return {'FINISHED'}
        
        # Compose Bone Data
        """
            bonecount (2B)
            bonenames[bonecount] ((1 + name length)B each)
            parentindices[bonecount] (2B)
            localmatrices[bonecount] (16f each)
            inversemodelmatrices[bonecount] (16f each)
        """
        
        bones = armature.data.bones[:];
        out_bone = b'';
        
        out_bone += Pack('H', len(bones));
        out_bone += b''.join( [PackString(b.name) for b in bones] );
        out_bone += b''.join( [Pack('H', bones.index(b.parent) if b.parent else 0) for b in bones] );
        out_bone += b''.join( [PackMatrix('f',
            (b.parent.matrix_local.inverted() @ b.matrix_local)
            if b.parent else b.matrix_local) for b in bones] );
        out_bone += b''.join( [PackMatrix('f', b.matrix_local.inverted()) for b in bones] );
        
        # Compose Vertex Buffer Data
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
            data = GetVBData(obj, format, settings);
            
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
            print('tell(): %d' % (4 + 1 + len(out_bone) + len(out_vb)));
            print('%s compressed size: %d' % (name, len(vbcompressed)));
            out_vb += Pack('L', len(vbcompressed));
            out_vb += vbcompressed;
        
        # Make flag
        flag = 0;
        if self.floattype == 'd':
            flag |= 1 << 0;
        elif self.floattype == 'e':
            flag |= 1 << 1;
        
        out = b'VBX' + Pack('B', VBXVERSION) + Pack('B', flag) + out_bone + out_vb;
        outcompressed = zlib.compress(out);
        outlen = (len(out), len(outcompressed));
        
        file = open(path, 'wb');
        file.write(outcompressed);
        file.close();
        
        bpy.context.view_layer.objects.active = active;
        for obj in objects: obj.select_set(1);
        
        print('FCODE: %s' % FCODE);
        
        print("VB data of size %.2fKB (%.2f%% of original size) written to \"%s\"" % 
                (outlen[1] / 1000, 100.0 * outlen[1] / outlen[0], path) );
        self.report({'INFO'}, 'VBX data written to \"%s\"' % path);
        
        
        return {'FINISHED'};
classlist.append(DMR_GM_ExportVBX);

# =============================================================================

def register():
    print('='*80)
    scene = bpy.context.scene;
    if not scene.get('dmr_vbexport', None):
        scene['dmr_vbexport'] = {
            'vbattrib0' : VBF_POS,
            'vbattrib1' : VBF_NOR,
            'vbattrib2' : VBF_CO2,
            'vbattrib3' : VBF_TEX,
            'vbattrib4' : VBF_000,
            'vbattrib5' : VBF_000,
            'vbattrib6' : VBF_000,
            'vbattrib7' : VBF_000,
            
            'vbxattrib0' : VBF_POS,
            'vbxattrib1' : VBF_NOR,
            'vbxattrib2' : VBF_TAN,
            'vbxattrib3' : VBF_BTN,
            'vbxattrib4' : VBF_CO2,
            'vbxattrib5' : VBF_TEX,
            'vbxattrib6' : VBF_BON,
            'vbxattrib7' : VBF_WEI,
            
            'lastvb' : None,
            'lastvbx' : None,
        };
    
    for c in classlist:
        bpy.utils.register_class(c)

def unregister():
    for c in classlist:
        bpy.utils.unregister_class(c)
