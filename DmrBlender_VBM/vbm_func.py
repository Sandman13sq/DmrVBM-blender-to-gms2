import bpy
import struct
import zlib
import sys
import mathutils
import time

import bmesh
import numpy

from bpy_extras.io_utils import ExportHelper
from struct import pack as Pack

PackString = lambda x: b'%c%s' % (len(x), str.encode(x))
PackVector = lambda f, v: struct.pack(f*len(v), *(v[:]))
PackMatrix = lambda f, m: b''.join( [struct.pack(f*4, *x) for x in m.copy().transposed()] )
QuatValid = lambda q: q if q.magnitude != 0.0 else [1.0, 0.0, 0.0, 0.00001]

def PrintStatus(msg, clear=1, buffersize=30):
    msg = msg + (' '*buffersize*clear)
    sys.stdout.write(msg + (chr(8) * len(msg) * clear))
    sys.stdout.flush()

# ================================================================================

VBMVERSION = 1
FCODE = 'f'

Items_FloatChoice = (
    ('f', 'Float (32bit) *GMS*', 'Write floating point data using floats (32 bits)\n***Use for Game Maker Studio***'),
    ('d', 'Double (64bit)', 'Write floating point data using doubles (64 bits)'),
    ('e', 'Binary16 (16bit)', 'Write floating point data using binary16 (16 bits)'),
)

VBF_000 = '0'
VBF_POS = 'POSITION'
VBF_UVS = 'UV'
VBF_NOR = 'NORMAL'
VBF_TAN = 'TANGENT'
VBF_BTN = 'BITANGENT'
VBF_COL = 'COLOR'
VBF_RGB = 'COLORBYTES'
VBF_BON = 'BONE'
VBF_BOI = 'BONEBYTES'
VBF_WEI = 'WEIGHT'
VBF_WEB = 'WEIGHTBYTES'
VBF_GRO = 'VERTEXGROUP'

VBFSize = {
    VBF_000: 0,
    VBF_POS: 3, 
    VBF_UVS: 2, 
    VBF_NOR: 3, 
    VBF_TAN: 3,
    VBF_BTN: 3,
    VBF_COL: 4, 
    VBF_RGB: 1, 
    VBF_BON: 4,
    VBF_BOI: 1,
    VBF_WEI: 4, 
    VBF_WEB: 4,
    VBF_GRO: 1,
    }

Items_VBF = (
    (VBF_000, '---', 'No Data', 'BLANK1', 0),
    (VBF_POS, 'Position', '3 Floats', 'VERTEXSEL', 1),
    (VBF_UVS, 'UVs', '2 Floats', 'UV', 2),
    (VBF_NOR, 'Normal', '3 Floats', 'NORMALS_VERTEX', 3),
    (VBF_TAN, 'Tangents', '3 Floats', 'NORMALS_VERTEX_FACE', 4),
    (VBF_BTN, 'Bitangents', '3 Floats', 'NORMALS_VERTEX_FACE', 5),
    (VBF_COL, 'Color (RGBA)', '4 Floats', 'COLOR', 6),
    (VBF_RGB, 'Color Bytes (RGBA)', '4 Bytes = Size of 1 Float in format 0xRRGGBBAA', 'RESTRICT_COLOR_OFF', 7),
    (VBF_BON, 'Bone Indices', '4 Floats (Use with Weights)', 'BONE_DATA', 8),
    (VBF_BOI, 'Bone Index Bytes', '4 Bytes = Size of 1 Float in format 0xWWZZYYXX', 'BONE_DATA', 9),
    (VBF_WEI, 'Weights', '4 Floats', 'MOD_VERTEX_WEIGHT', 10),
    (VBF_WEB, 'Weight Bytes', '4 Bytes = Size of 1 Float in format 0xWWZZYYXX', 'MOD_VERTEX_WEIGHT', 11),
    (VBF_GRO, 'Vertex Group', '1 Float', 'GROUP_VERTEX', 12),
)

VBFType = {x[1]: x[0] for x in enumerate([
    VBF_000,
    VBF_POS,
    VBF_UVS,
    VBF_NOR,
    VBF_COL,
    VBF_RGB,
    VBF_WEI,
    VBF_WEB,
    VBF_BON,
    VBF_BOI,
    VBF_TAN,
    VBF_BTN,
    VBF_GRO,
    ])}

Items_LayerChoice = (
    ('render', 'Render Layer', 'Use the layer that will be rendered (camera icon is on)', 'RESTRICT_RENDER_OFF', 0),
    ('active', 'Active Layer', 'Use the layer that is active (highlighted)', 'RESTRICT_SELECT_OFF', 1),
)

LYR_GLOBAL = '<GLOBAL>'
LYR_RENDER = '<RENDER>'
LYR_SELECT = '<SELECT>'

MTY_VIEW = 'VIEWPORT'
MTY_RENDER = 'RENDER'
MTY_OR = 'OR'
MTY_AND = 'AND'
MTY_ALL = 'ALL'

Items_ModChoice = (
    (MTY_VIEW, 'Viewport Only', 'Only export modifiers visible in viewports'), 
    (MTY_RENDER, 'Render Only', 'Only export modifiers visible in renders'), 
    (MTY_OR, 'Viewport or Render', 'Export modifiers if they are visible in viewport or renders'), 
    (MTY_AND, 'Viewport and Render', 'Export modifiers only if they are visible in viewport and renders'), 
    (MTY_ALL, 'All', 'Export all supported modifiers')
)

Items_UpAxis = (
    ('+x', '+X Up', 'Export model(s) with +X Up axis'),
    ('+y', '+Y Up', 'Export model(s) with +Y Up axis'),
    ('+z', '+Z Up', 'Export model(s) with +Z Up axis'),
    ('-x', '-X Up', 'Export model(s) with -X Up axis'),
    ('-y', '-Y Up', 'Export model(s) with -Y Up axis'),
    ('-z', '-Z Up', 'Export model(s) with -Z Up axis'),
)

Items_ForwardAxis = (
    ('+x', '+X Forward', 'Export model(s) with +X Forward axis'),
    ('+y', '+Y Forward', 'Export model(s) with +Y Forward axis'),
    ('+z', '+Z Forward', 'Export model(s) with +Z Forward axis'),
    ('-x', '-X Forward', 'Export model(s) with -X Forward axis'),
    ('-y', '-Y Forward', 'Export model(s) with -Y Forward axis'),
    ('-z', '-Z Forward', 'Export model(s) with -Z Forward axis'),
)

# ---------------------------------------------------------------------------------------

def Items_UVLayers(self, context):
    items = [
        (LYR_GLOBAL, '<UV Source>', 'Use setting "UV Source" in ==Show More Options==', 'PREFERENCES', 0),
        (LYR_RENDER, '<Render Layer>', 'Use Render Layer of object', 'RESTRICT_RENDER_OFF', 1),
        (LYR_SELECT, '<Selected Layer>', 'Use Selected Layer of object', 'RESTRICT_SELECT_OFF', 2),
    ]
    
    lyrnames = [
        lyr.name
        for obj in context.scene.objects if (obj and obj.type == 'MESH')
        for lyr in obj.data.uv_layers
    ]
    
    # Sort by number of entries
    lyrnames.sort(key=lambda x: lyrnames.count(x))
    lyrnames = list(set(lyrnames))
    
    items += [(name, name, 'Use "%s" layer for color data' % name, 'GROUP_UVS', i+3) for i,name in enumerate(lyrnames)]
    
    return items

# --------------------------------------------------------------------------------------------------

def Items_VCLayers(self, context):
    items = [
        (LYR_GLOBAL, '<Color Source>', 'Use setting "Color Source" in ==Show More Options==', 'PREFERENCES', 0),
        (LYR_RENDER, '<Render Layer>', 'Use Render Layer of object', 'RESTRICT_RENDER_OFF', 1),
        (LYR_SELECT, '<Selected Layer>', 'Use Selected Layer of object', 'RESTRICT_SELECT_OFF', 2),
    ]
    
    lyrnames = [
        lyr.name
        for obj in context.scene.objects if (obj and obj.type == 'MESH')
        for lyr in obj.data.vertex_colors
    ]
    
    # Sort by number of entries
    lyrnames.sort(key=lambda x: lyrnames.count(x))
    lyrnames = list(set(lyrnames))
    
    items += [(name, name, 'Use "%s" layer for color data' % name, 'GROUP_VCOL', i+3) for i,name in enumerate(lyrnames)]
    
    return items

# --------------------------------------------------------------------------------------------------

def Items_VertexGroups(self, context):
    names = [
        vg.name
        for obj in context.scene.objects if (obj and obj.type == 'MESH')
        for vg in obj.vertex_groups
    ]
    
    # Sort by number of entries
    names.sort(key=lambda x: names.count(x))
    names = list(set(names))
    
    items = [('---', '---', 'Null Group', 'NONE', 0)] + \
        [(name, name, 'Export vertices from group "%s"' % name, 'GROUP_VERTEX', i+1) for i,name in enumerate(names)]
    
    return items

# ==================================================================================================

def RemoveTempObjects():
    def RmvTmp(data):
        for obj in data:
            if '__temp' in obj.name:
                data.remove(obj)
    RmvTmp(bpy.data.objects)
    RmvTmp(bpy.data.meshes)
    RmvTmp(bpy.data.armatures)
    
def ComposeOutFlag(self):
    flag = 0
    if self.floattype == 'd':
        flag |= 1 << 0
    elif self.floattype == 'e':
        flag |= 1 << 1
    return Pack('B', flag)

def ComposeOutFormat(self, format = -1):
    if format == -1:
        format = self.format
    
    out_format = b''
    out_format += Pack('B', len(format)) # Format length
    for f in format:
        out_format += Pack('B', VBFType[f]) # Attribute Type
        out_format += Pack('B', VBFSize[f]) # Attribute Float Size
    return Pack('B', out_format)

# ==================================================================================================

# Returns tuple of (outbytes, outcounts)
# materialvbytes = {materialname: vertexbytedata}
# materialvcounts = {materialname: vertexcount}
def GetVBData(
    context, 
    sourceobj, 
    format = [], 
    settings = {}, 
    uvtargets = [LYR_GLOBAL], 
    vctargets = [LYR_GLOBAL], 
    instancerun=False
    ):
    
    tstart = time.time()
    
    format = tuple(format)
    formatsize = len(format)
    
    flipuvs = settings.get('flipuvs', True)
    maxsubdivisions = settings.get('maxsubdivisions', -1)
    modreq = settings.get('modifierpick', MTY_OR)
    applyarmature = settings.get('applyarmature', False)
    deformonly = settings.get('deformonly', False)
    edgesonly = settings.get('edgesonly', False)
    flipnormals = settings.get('flipnormals', False)
    reversewinding = settings.get('reversewinding', False)
    settingsmatrix = settings.get('matrix', mathutils.Matrix())
    FCODE = settings.get('floattype', 'f')
    colordefault = settings.get('defaultcolor', (1.0, 1.0, 1.0, 1.0))
    attribsizes = settings.get('attribsizes', [3]+[4]*7)
    vgrouptargets = settings.get('vgrouptargets', ['']*8)
    vgroupdefaultweight = settings.get('vgroupdefaultweight', 0.0)
    
    process_bones = True if sum([1 for k in format if k in [VBF_BON, VBF_BOI, VBF_WEI, VBF_WEB]]) > 0 else False
    process_tangents = True if sum([1 for k in format if k in [VBF_TAN, VBF_BTN]]) > 0 else False
    
    if not instancerun:
        PrintStatus('> Composing data for \"%s\":' % sourceobj.name, 0)
    else:
        PrintStatus('> Composing data for instances of \"%s\":' % sourceobj.name, 0)
    
    dupobj = sourceobj.copy()
    dupobj.name += '__temp'
    context.scene.collection.objects.link(dupobj)
    
    armature = sourceobj.find_armature()
    
    # Handle modifiers
    modifiers = dupobj.modifiers
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
                (modreq == MTY_VIEW and not vshow) or 
                (modreq == MTY_RENDER and not rshow) or 
                (modreq == MTY_OR and not (vshow or rshow)) or 
                (modreq == MTY_AND and not (vshow and rshow))
                ):
                m.show_viewport = False
                continue
            
            if maxsubdivisions >= 0 and m.type == 'SUBSURF':
                m.levels = min(m.levels, maxsubdivisions)
            
            if m.type == 'ARMATURE':
                m.show_viewport = applyarmature
        
        if not edgesonly:
            m = dupobj.modifiers.new(type='TRIANGULATE', name='VBM Triangulate')
            if m:
                m.min_vertices=4
                m.keep_custom_normals=True
    
    context.view_layer.update()
    
    dg = context.evaluated_depsgraph_get() #getting the dependency graph
    
    # Invoke to_mesh() for evaluated object.
    workingobj = dupobj.evaluated_get(dg)
    workingmesh = workingobj.evaluated_get(dg).to_mesh()
    
    # Create missing data
    if len(workingmesh.vertex_colors) == 0:
        workingmesh.vertex_colors.new()
    if len(workingmesh.uv_layers) == 0:
        workingmesh.uv_layers.new()
    
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
        
        matnames = tuple(x.name for x in workingobj.data.materials)
        
        if flipuvs:
            for uv in (uv for lyr in workingmesh.uv_layers for uv in lyr.data):
                uv.uv[1] = 1.0-uv.uv[1]
        
        def GetAttribLayers(layers, targets):
            targets = targets[:]
            if not targets:
                targets = [LYR_RENDER]
            targets += targets * len(format)
            
            out = []
            
            lyrnames = list(layers.keys())
            for i in range(0, formatsize):
                tar = targets[i]
                if tar in lyrnames:
                    out += [lyrnames.index(tar)]
                elif tar == LYR_SELECT:
                    out += [layers.active_index]
                else:
                    out += [[x.active_render for x in layers].index(True)]
            
            return (tuple(out), lyrnames)
        
        uvattriblyr, uvtargets = GetAttribLayers(workingmesh.uv_layers, uvtargets) # list of layer indices to use for attribute
        vcattriblyr, vctargets = GetAttribLayers(workingmesh.vertex_colors, vctargets)
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
        normalsign = -1.0 if flipnormals else 1.0
        
        loopnormaloriginal = {l: l.normal*normalsign for l in workingmesh.loops}
        
        # Matrix Loop -----------------------------------------------------------------------------------
        instanceindex = 0
        for matrix in instancemats:
            statusheader = ' ' if instanceindex == 0 else ' [%d]' % instanceindex
            
            # Vertices ------------------------------------------------------------------------
            PrintStatus(statusheader+'Setting up vertex data...')
            
            workingvertices = tuple(workingmesh.vertices)
            voffset = len(vertexmeta)
            for v in workingvertices:
                v.co = vertcooriginal[v]
            
            vgroups = workingobj.vertex_groups
            weightdefaults = (1,1,1,1) if len(vgroups) == 0 else (0,0,0,0)
            
            validvgroups = tuple(vg.index for vg in vgroups)
            vgremap = {vg.index: vg.index for vg in vgroups}
            
            if armature:
                bonenames = tuple([b.name for b in armature.data.bones if ((deformonly and b.use_deform) or not deformonly)])
                validvgroups = tuple([vg.index for vg in vgroups if vg.name in bonenames])
                vgremap = {vg.index: (bonenames.index(vg.name) if vg.name in bonenames else -1) for vg in vgroups}
            
            weightsortkey = lambda x: x.weight
            
            # "Fine. I'll do it myself."
            worldmat = settingsmatrix @ matrix
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
                    
                    boneindices = tuple(vgremap[vge.group] for vge in validvges)
                    weights = tuple(vge.weight for vge in validvges)
                    wlength = sum(weights)
                    
                    if wlength > 0.0:
                        weights = tuple(x/wlength for x in weights)
                    
                    return (
                        tuple(co),
                        tuple( (vg.weight(v.index) if vg != None else vgroupdefaultweight for vg in targetvgroups) ),
                        tuple(boneindices+(0,0,0,0))[:4], 
                        tuple([int(x) for x in boneindices+(0,0,0,0)])[:4], 
                        tuple(weights+weightdefaults)[:4],
                        tuple([int(x*255.0) for x in weights+weightdefaults])[:4], 
                    )
            else:
                def VEntry(v):
                    co = v.co.copy()
                    co.rotate(rot)
                    co *= sca
                    co += loc
                    
                    return [
                        tuple(co),
                        tuple( (vg.weight(v.index) if (vg != None and vg.index in [vge.group for vge in v.groups]) else vgroupdefaultweight for vg in targetvgroups) ),
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
            
            if not edgesonly and workingmesh.polygons and process_tangents:
                workingmesh.calc_tangents()
            workingmesh.update()
            
            targetlayers = set([lyr for i,lyr in enumerate(workingmesh.vertex_colors) if i in vcattriblyr])
            vclayers = tuple([
                [lyr.data[i].color for i in range(0, len(lyr.data))] if lyr in targetlayers else 0
                for lyr in workingmesh.vertex_colors
                ])
            targetlayers = set([lyr for i,lyr in enumerate(workingmesh.uv_layers) if i in uvattriblyr])
            uvlayers = tuple([
                [lyr.data[i].uv for i in range(0, len(lyr.data))] if lyr in targetlayers else 0
                for lyr in workingmesh.uv_layers
                ])
            
            if process_tangents:
                loopmeta += [tuple((
                        tuple(l.normal.normalized()),
                        tuple(l.tangent),
                        tuple(l.bitangent),
                        tuple( (lyr[l.index] if lyr else (0,0) for lyr in uvlayers ) ),
                        tuple( (lyr[l.index] if lyr else (0,0,0,0) for lyr in vclayers ) ),
                        tuple( tuple(int(x*255.0) for x in lyr[l.index]) if lyr else (0,0,0,0) for lyr in vclayers ),
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
                    ))
                    for l in workingmesh.loops
                ]
            
            tt = time.time()-t
            
            # Poly data -----------------------------------------------------------------------------------------
            PrintStatus(statusheader+'Setting up poly data...')
            
            if workingmesh.polygons:
                if not edgesonly: # Triangles
                    invertpoly = reversewinding
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
                )
                for v in workingmesh.vertices
            )
        
        vertexmeta = {i: x for i,x in enumerate(vertexmeta)}
        loopmeta = {i: x for i,x in enumerate(loopmeta)}
        
        # Iterate through data ------------------------------------------------------------------------------
        # Optimized to  h e l l
        
        PrintStatus(' Creating byte data...')
        
        # Triangles
        def out_pos(out, attribindex, size): out.append(Pack(size*FCODE, *vmeta[0][:size]));
        def out_nor(out, attribindex, size): out.append(Pack(3*FCODE, *lmeta[0][:3]));
        def out_tan(out, attribindex, size): out.append(Pack(3*FCODE, *lmeta[1][:3]));
        def out_btn(out, attribindex, size): out.append(Pack(3*FCODE, *lmeta[2][:3]));
        def out_tex(out, attribindex, size): out.append(Pack(2*FCODE, *lmeta[3][uvattriblyr[attribindex]]));
        def out_col(out, attribindex, size): out.append(Pack(size*FCODE, *lmeta[4][vcattriblyr[attribindex]][:size]));
        def out_rgb(out, attribindex, size): out.append(Pack(size*'B', *lmeta[5][vcattriblyr[attribindex]][:size]));
        def out_bon(out, attribindex, size): out.append(Pack(size*FCODE, *vmeta[2][:4][:size]));
        def out_boi(out, attribindex, size): out.append(Pack(size*'B', *vmeta[3][:size]));
        def out_wei(out, attribindex, size): out.append(Pack(size*FCODE, *vmeta[4][:4][:size]));
        def out_web(out, attribindex, size): out.append(Pack(size*'B', *vmeta[5][:size]));
        def out_gro(out, attribindex, size): out.append(Pack(FCODE, vmeta[1][attribindex]));
        
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
        }
        
        format_enumerated = tuple(enumerate(format))
        
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
                
                [outwritemap[attribkey](outblock, attribindex, attribsizes[attribindex]) for attribindex, attribkey in format_enumerated]
            materialvbytes[matkey] += outblock
        
        t = time.time()-t
        #print('%s:\t%.6f %.6f' % (workingobj.name, tt, t))
        
        PrintStatus(' Complete (%s Vertices, %.6f sec)' % (sum(materialvcounts.values()), time.time()-tstart) )
        PrintStatus('\n')
    else:
        PrintStatus(' Object is instancer and hidden. Moving to instances.')
        PrintStatus('\n')
    
    # Remove temp data
    workingobj.to_mesh_clear()
    bpy.data.objects.remove(dupobj)
    
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
                context=context,
                sourceobj=inst, 
                format=format, 
                settings=settings, 
                uvtargets=uvtargets,
                vctargets=vctargets, 
                instancerun=True
                )
            for k in instvbytes.keys():
                if k not in outvbytes:
                    outvbytes[k] = instvbytes[k]
                    outvcounts[k] = instvcounts[k]
                else:
                    outvbytes[k] += instvbytes[k]
                    outvcounts[k] += instvcounts[k]
    
    return (outvbytes, outvcounts)



