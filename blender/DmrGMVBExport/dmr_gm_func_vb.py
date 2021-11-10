import bpy
import struct
import zlib
import sys
import mathutils

from bpy_extras.io_utils import ExportHelper
from struct import pack as Pack

PackString = lambda x: b'%c%s' % (len(x), str.encode(x));
PackVector = lambda f, v: struct.pack(f*len(v), *(v[:]));
PackMatrix = lambda f, m: b''.join( [struct.pack(f*4, *x) for x in m.copy().transposed()] );
QuatValid = lambda q: q if q.magnitude != 0.0 else [1.0, 0.0, 0.0, 0.00001];

# ================================================================================

VBXVERSION = 1;
FCODE = 'f';

MODLIST = [
    'MIRROR', 
    'SUBSURF', 
    'NORMAL_EDIT', 
    'SOLIDIFY',
    'WELD',
    'EDGE_SPLIT',
    'TRIANGULATE',
    'DATA_TRANSFER',
    'SHRINKWRAP',
    'MASK',
    'ARRAY'
];

# This is more for loading files outside of GMS
# If you don't mind longer load times for converting numbers to floats,
# get some more accuracy with doubles or save some space with binary16s
FloatChoiceItems = (
    ('f', 'Float (32bit) *GMS*', 'Write floating point data using floats (32 bits)\n***Use for Game Maker Studio***'),
    ('d', 'Double (64bit)', 'Write floating point data using doubles (64 bits)'),
    ('e', 'Binary16 (16bit)', 'Write floating point data using binary16 (16 bits)'),
);

VBF_000 = '000';
VBF_POS = 'POS';
VBF_TEX = 'TEX';
VBF_NOR = 'NOR';
VBF_TAN = 'TAN';
VBF_BTN = 'BTN';
VBF_COL = 'COL';
VBF_CO2 = 'CO2';
VBF_WEI = 'WEI';
VBF_BON = 'BON';
VBF_BOI = 'BOI';

VBFSize = {
    VBF_000: 0,
    VBF_POS: 3, 
    VBF_TEX: 2, 
    VBF_NOR: 3, 
    VBF_TAN: 3,
    VBF_BTN: 3,
    VBF_COL: 4, 
    VBF_CO2: 1, 
    VBF_WEI: 4, 
    VBF_BON: 4,
    VBF_BOI: 1,
    };

VBFItems = (
    (VBF_000, '---', 'No Data'),
    (VBF_POS, 'Position', '3 Floats'),
    (VBF_TEX, 'UVs', '2 Floats'),
    (VBF_NOR, 'Normal', '3 Floats'),
    (VBF_TAN, 'Tangents', '3 Floats'),
    (VBF_BTN, 'Bitangents', '3 Floats'),
    (VBF_COL, 'Color (RGBA)', '4 Floats'),
    (VBF_CO2, 'Color Bytes (RGBA)', '4 Bytes = Size of 1 Float in format 0xRRGGBBAA'),
    (VBF_BON, 'Bone Indices', '4 Floats (Use with Weights)'),
    (VBF_BOI, 'Bone Index Bytes', '4 Bytes = Size of 1 Float in format 0xWWZZYYZZ'),
    (VBF_WEI, 'Weights', '4 Floats'),
);

VBFType = {x[1]: x[0] for x in enumerate([
    VBF_000,
    VBF_POS,
    VBF_TEX,
    VBF_NOR,
    VBF_COL,
    VBF_CO2,
    VBF_WEI,
    VBF_BON,
    VBF_TAN,
    VBF_BTN,
    ])};

LayerChoiceItems = (
    ('render', 'Render Layer', 'Use the layer that will be rendered (camera icon is on)', 'RESTRICT_RENDER_OFF', 0),
    ('active', 'Active Layer', 'Use the layer that is active (highlighted)', 'RESTRICT_SELECT_OFF', 1),
);

MTY_VIEW = 'V';
MTY_RENDER = 'R';
MTY_OR = 'OR';
MTY_AND = 'AND';
MTY_ALL = 'ALL';

ModChoiceItems = (
    (MTY_VIEW, 'Viewport Only', 'Only export modifiers visible in viewports'), 
    (MTY_RENDER, 'Render Only', 'Only export modifiers visible in renders'), 
    (MTY_OR, 'Viewport or Render', 'Export modifiers if they are visible in viewport or renders'), 
    (MTY_AND, 'Viewport and Render', 'Export modifiers only if they are visible in viewport and renders'), 
    (MTY_ALL, 'All', 'Export all supported modifiers')
);

UpAxisItems = (
    ('+x', '+X Up', 'Export model(s) with +X Up axis'),
    ('+y', '+Y Up', 'Export model(s) with +Y Up axis'),
    ('+z', '+Z Up (Blender)', 'Export model(s) with +Z Up axis'),
    ('-x', '-X Up', 'Export model(s) with -X Up axis'),
    ('-y', '-Y Up (GM)', 'Export model(s) with -Y Up axis'),
    ('-z', '-Z Up', 'Export model(s) with -Z Up axis'),
);

ForwardAxisItems = (
    ('+x', '+X Forward', 'Export model(s) with +X Forward axis'),
    ('+y', '+Y Forward (Blender)', 'Export model(s) with +Y Forward axis'),
    ('+z', '+Z Forward (GM)', 'Export model(s) with +Z Forward axis'),
    ('-x', '-X Forward', 'Export model(s) with -X Forward axis'),
    ('-y', '-Y Forward', 'Export model(s) with -Y Forward axis'),
    ('-z', '-Z Forward', 'Export model(s) with -Z Forward axis'),
);

def GetVBData(sourceobj, format = [], settings = {}):
    context = bpy.context;
    
    armature = None;
    formatneedsbones = VBF_BON in format or VBF_WEI in format;
    formatneedsbones = formatneedsbones and not settings.get('applyarmature', 0);
    
    # Set source as active
    bpy.ops.object.select_all(action='DESELECT');
    bpy.context.view_layer.objects.active = sourceobj;
    sourceobj.select_set(True);
    # Duplicate source
    bpy.ops.object.duplicate(linked = 0, mode = 'TRANSLATION');
    obj = bpy.context.view_layer.objects.active;
    sourceobj.select_set(False);
    obj.select_set(True);
    bpy.context.view_layer.objects.active = obj;
    obj.name = sourceobj.name + '__temp';
    
    # Find armature
    for m in obj.modifiers:
        if m.type == 'ARMATURE':
            if m.object:
                armature = m.object;
                bpy.ops.object.modifier_move_to_index(modifier=m.name, index=len(obj.modifiers)-1)
    
    # Apply shape keys
    if obj.data.shape_keys:
        print("> Removing shape keys...");
        bpy.ops.object.shape_key_add(from_mix = True);
        shape_keys = obj.data.shape_keys.key_blocks;
        count = len(shape_keys);
        for i in range(0, count):
            obj.active_shape_key_index = 0;
            bpy.ops.object.shape_key_remove(all=False);
    
    # Apply modifiers
    maxsubdivisions = settings.get('maxsubdivisions', -1);
    modreq = settings.get('modifierpick', MTY_OR);
    if obj.modifiers != None:
        modifiers = obj.modifiers;
        for i, m in enumerate(modifiers):
            # Modifier requirements
            if modreq == MTY_VIEW:
                if not m.show_viewport:
                    bpy.ops.object.modifier_remove(modifier = m.name);
                    continue;
            elif modreq == MTY_RENDER:
                if not m.show_render:
                    bpy.ops.object.modifier_remove(modifier = m.name);
                    continue;
            elif modreq == MTY_OR:
                if not (m.show_viewport or m.show_render):
                    bpy.ops.object.modifier_remove(modifier = m.name);
                    continue;
            elif modreq == MTY_AND:
                if not (m.show_viewport and m.show_render):
                    bpy.ops.object.modifier_remove(modifier = m.name);
                    continue;
            
            # Subdivision maximum
            if m.type == 'SUBSURF':
                if maxsubdivisions >= 0:
                    m.levels = min(m.levels, maxsubdivisions);
            
            # Apply enabled modifiers
            if (m.name[0] != '!') and (m.type in MODLIST) \
            or (m.type == 'ARMATURE' and settings.get('applyarmature', 0)):
                bpy.ops.object.modifier_apply(modifier = m.name);
            # Ignore Modifier
            elif m.type != 'ARMATURE':
                bpy.ops.object.modifier_remove(modifier = m.name);
        
        minquads = modifiers.new('MinQuads', 'TRIANGULATE');
        minquads.min_vertices = 5;
        bpy.ops.object.modifier_apply(modifier = 'MinQuads');
    
    if not formatneedsbones:
        armature = None;
    
    # Apply Transforms
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True);
    bpy.ops.object.visual_transform_apply();
    
    for c in obj.constraints:
        obj.constraints.remove(c);
    
    yvec = mathutils.Vector((1.0, 1.0, 1.0));
    
    if settings.get('yflip', 0):
        yvec[1] *= -1.0;
    #bpy.ops.object.convert(target='MESH');
    
    obj.matrix_world = settings.get('matrix', mathutils.Matrix());
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True);
    
    # Calc data
    mesh = obj.data;
    mesh.calc_loop_triangles();
    usetris = (len(mesh.loop_triangles) > 0) and (not settings.get('edgesonly', False));
    if usetris:
        mesh.calc_normals_split();
        if mesh.uv_layers:
            mesh.calc_tangents();
    mesh.update();
    
    # Setup Object Data
    vertices = mesh.vertices;
    loops = mesh.loops;
    
    # Find active group for layer if exists, else create new and use it
    if not obj.vertex_groups:
        obj.vertex_groups.new();
    vgroups = obj.vertex_groups;
    
    if armature and vgroups:
        group_select_mode = 'BONE_DEFORM' if armature else 'ALL';
        bpy.ops.object.vertex_group_clean(group_select_mode=group_select_mode, limit=0, keep_single=True);
        bpy.ops.object.vertex_group_limit_total(group_select_mode=group_select_mode, limit=4);
    
    uvloops = mesh.uv_layers.active.data if mesh.uv_layers else mesh.uv_layers.new().data;
    if settings.get('uvlayerpick', 1):
        for lyr in mesh.uv_layers: # if use render
            if lyr.active_render: 
                uvloops = lyr.data;
    
    vcolors = mesh.vertex_colors.active.data if mesh.vertex_colors else mesh.vertex_colors.new().data;
    if settings.get('colorlayerpick', 1):
        for lyr in mesh.vertex_colors: # if use render
            if lyr.active_render: 
                vcolors = lyr.data;
    
    # Set up armature
    if armature:
        bones = armature.data.bones;
        grouptobone = {vg.index: bones.keys().index(vg.name) for vg in vgroups if vg.name in bones.keys()};
        validvgroups = [vg.index for vg in vgroups if vg.name in bones.keys()];
    else:
        grouptobone = {vg.index: vg.index for vg in vgroups};
        validvgroups = grouptobone.values();
    
    # Compose data
    out = { (m.name if m else '__null'): [b''] for m in obj.data.materials}; # {materialname: vertexdata[]};
    if not out:
        out = {'0': [b'']};
    materialnames = [m.name for m in obj.data.materials] if obj.data.materials else ['0'];
    materialcount = len(materialnames);
    
    stride = 0;
    for k in format:
        stride += VBFSize[k];
    
    vertexcount = 0;
    chunksize = 1024;
    
    vgesortfunc = lambda x: x.weight;
    
    # Triangles
    if usetris:
        for p in mesh.loop_triangles[:]: # For all mesh's triangles...
            p_loops = p.loops;
            p_vertices = p.vertices;
            p_normals = [
                mathutils.Vector((x[0], x[1], x[2]))
                for x in p.split_normals
                ];
            
            groupkey = materialnames[min(p.material_index, max(0, materialcount-1))];
            materialgroup = out[ groupkey ];
            if len(materialgroup[-1]) >= chunksize:
                materialgroup.append(b'');
            
            vertexcount += 3;
            
            for i in range(0, 3): # For each vertex index...
                l = p_loops[i];
                v = vertices[ p_vertices[i] ];
                
                for formatentry in format: # For each attribute in vertex format...
                    if formatentry == VBF_POS: # Position
                        #materialgroup.extend(v.co);
                        materialgroup[-1] += PackVector(FCODE, v.co*yvec);
                    
                    elif formatentry == VBF_NOR: # Normal
                        #materialgroup.extend(p_normals[i]);
                        materialgroup[-1] += PackVector(FCODE, p_normals[i]*yvec);
                    
                    elif formatentry == VBF_TAN: # Tangent
                        #materialgroup.extend(loops[l].tangent);
                        materialgroup[-1] += PackVector(FCODE, loops[l].tangent*yvec);
                    
                    elif formatentry == VBF_BTN: # Bitangent
                        #materialgroup.extend(loops[l].bitangent);
                        materialgroup[-1] += PackVector(FCODE, loops[l].bitangent*yvec);
                    
                    elif formatentry == VBF_TEX: # Texture
                        #materialgroup.extend((uvloops[l].uv[0], 1-uvloops[l].uv[1]));
                        materialgroup[-1] += PackVector(FCODE, (uvloops[l].uv[0], 1-uvloops[l].uv[1]));
                    
                    elif formatentry == VBF_COL: # Color
                        #materialgroup.extend(vcolors[l].color);
                        materialgroup[-1] += PackVector(FCODE, vcolors[l].color);
                    
                    elif formatentry == VBF_CO2: # Color
                        materialgroup[-1] += PackVector('B', [ int(x*255.0) for x in vcolors[l].color]);
                    
                    elif formatentry == VBF_BON or formatentry == VBF_BOI: # Bone
                        vgelements = [vge for vge in v.groups if vge.group in validvgroups];
                        vgelements.sort(reverse=True, key=vgesortfunc);
                        
                        vertbones = [grouptobone[vge.group] for vge in vgelements];
                        vertbones += [0] * (4-len(vertbones));
                        if formatentry == VBF_BON:
                            materialgroup[-1] += PackVector(FCODE, vertbones[:4]);
                        else:
                            materialgroup[-1] += PackVector('B', vertbones[:4]);
                    
                    elif formatentry == VBF_WEI: # Weight
                        vgelements = [vge for vge in v.groups if vge.group in validvgroups];
                        vgelements.sort(reverse=True, key=vgesortfunc);
                        
                        vertweights = [vge.weight for vge in vgelements];
                        vertweights += [0] * (4-len(vertweights));
                        vertweights = vertweights[:4];
                        weightmagnitude = sum(vertweights);
                        if weightmagnitude != 0:
                            materialgroup[-1] += PackVector(FCODE, [x/weightmagnitude for x in vertweights[:4]]);
                        else:
                            materialgroup[-1] += PackVector(FCODE, [x for x in vertweights[:4]]);
    # Edges
    else:
        for p in mesh.edges[:]: # For all mesh's edges...
            p_vertices = p.vertices;
            
            materialgroup = out[materialnames[0]];
            if len(materialgroup[-1]) >= chunksize:
                materialgroup.append(b'');
            
            vertexcount += 2;
            
            for i in range(0, 2): # For each vertex index...
                v = vertices[ p_vertices[i] ];
                normal = v.normal;
                
                for formatentry in format: # For each attribute in vertex format...
                    if formatentry == VBF_POS: # Position
                        materialgroup[-1] += PackVector(FCODE, v.co);
                    
                    elif formatentry == VBF_NOR: # Normal
                        materialgroup[-1] += PackVector(FCODE, normal);
                    
                    elif formatentry == VBF_TAN: # Tangent
                        materialgroup[-1] += PackVector(FCODE, normal);
                    
                    elif formatentry == VBF_BTN: # Bitangent
                        materialgroup[-1] += PackVector(FCODE, normal);
                    
                    elif formatentry == VBF_TEX: # Texture
                        materialgroup[-1] += PackVector(FCODE, (i, v.index/len(vertices)));
                    
                    elif formatentry == VBF_COL: # Color
                        materialgroup[-1] += PackVector(FCODE, [1.0]*4);
                    
                    elif formatentry == VBF_CO2: # Color
                        materialgroup[-1] += PackVector('B', [255]*4);
                    
                    elif formatentry == VBF_BON: # Bone
                        vertbones = [grouptobone[vge.group] for vge in v.groups if vge.group in validvgroups];
                        vertbones += [0] * (4-len(vertbones));
                        materialgroup[-1] += PackVector(FCODE, vertbones[:4]);
                    
                    elif formatentry == VBF_WEI: # Weight
                        vertweights = [vge.weight for vge in v.groups if vge.group in validvgroups];
                        vertweights += [0] * (4-len(vertweights));
                        weightmagnitude = sum(vertweights);
                        if weightmagnitude != 0:
                            materialgroup[-1] += PackVector(FCODE, [x/weightmagnitude for x in vertweights[:4]]);
                        else:
                            materialgroup[-1] += PackVector(FCODE, [x for x in vertweights[:4]]);
    
    for k in out.keys():
        out[k] = b''.join(out[k]);
    
    if 0:
        for name, data in out.items():
            print("\"%s\" (%d): " % (name, len(data) / stride));
            for i in range(0, len(data[:40]), stride):
                s = "".join(["%.2f, " % x for x in data[i:i+stride]]);
                print("< %s>" % s);
    
    bpy.context.view_layer.objects.active = sourceobj;
    sourceobj.select_set(1);
    
    return out;

def RemoveTempObjects():
    objects = bpy.data.objects;
    selected = [x for x in bpy.context.selected_objects if '__temp' not in x.name];
    
    if not bpy.context.active_object:
        selected[0].select_set(1);
        bpy.context.view_layer.objects.active = selected[0];
        lastactive = bpy.context.view_layer.objects.active;
        print(bpy.context.active_object.name)
    
    lastobjectmode = bpy.context.active_object.mode;
    lastactive = bpy.context.view_layer.objects.active;
    
    bpy.ops.object.mode_set(mode = 'OBJECT'); # Update selected
    bpy.ops.object.select_all(action='DESELECT');
    
    targets = [x for x in objects if '__temp' in x.name];
    if lastactive in targets:
        lastactive = None;
    
    for x in targets:
        x.select_set(1);
    
    bpy.ops.object.delete(use_global=False, confirm=False);
    
    # Restore State
    bpy.context.view_layer.objects.active = lastactive;
    for obj in selected:
        obj.select_set(1);
    if not lastactive:
        bpy.context.view_layer.objects.active = selected[0];
    else:
        bpy.ops.object.mode_set(mode = lastobjectmode);
    
