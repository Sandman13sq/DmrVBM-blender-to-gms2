import bpy
import struct

# Clear weights from vertex
def ClearVertexWeights(v, vertexGroups):
    for vge in v.groups:
        vertexGroups[vge.group].remove([v.index]);

# Set Vertex Weight. Creates groups where necessary
def SetVertexWeight(v, weight_value, groupname, vertexGroups):
    # Group exists
    if groupname in vertexGroups.keys():
        vertexGroups[groupname].add([v.index], weight_value, 'REPLACE');
    # Create new group and add
    else:
        vertexGroups.new(name = groupname).add([v.index], weight_value, 'ADD');

# Get object Mode
def GetViewMode():
    return bpy.context.active_object.mode;

# Set object Mode. Returns previously set mode
def SetViewMode(mode):
    previous_mode = bpy.context.active_object.mode;
    bpy.ops.object.mode_set(mode = mode);
    return previous_mode;

# Sets Active Object
def SetActiveObject(object):
    bpy.context.view_layer.objects.active = object;
    return object;

# Returns Active Object
def GetActiveObject(): 
    return bpy.context.view_layer.objects.active;

# Returns currently selected objects
def GetSelectedObjects(context):
    return context.selected_objects;

def PanelInEditMode():
    if bpy.context.active_object == None:
        return False;
    return (bpy.context.active_object.mode == 'EDIT') or (bpy.context.active_object.mode == 'WEIGHT_PAINT')

def FetchArmature(object):
    if object:
        if object.type == 'ARMATURE':
            return object;
        if object.parent:
            if object.parent.type == 'ARMATURE':
                return object.parent;
        if object.type in ['MESH']:
            if object.modifiers:
                for m in object.modifiers:
                    if m.type == 'ARMATURE':
                        if m.object:
                            return m.object;
    return None;

# Returns sparse matrix from 4x4 matrix
def MatToSparse(m):
    v = [];
    col = [];
    row = [];
    
    thresh = 0.001;
    thresh *= thresh;
    
    for i in range(0, 4):
        for j in range(0, 4):
            if m[i][j] * m[i][j] >= thresh:
                v.append(m[i][j]);
                col.append(j);
                row.append(i);
    row.append(i + 1);
    
    return [v, col, row];

# Returns 4x4 matrix from sparse matrix
def MatFromSparse(sparse):
    v = sparse[0];
    col = sparse[1];
    row = sparse[2];
    
    m = mathutils.Matrix.Translation((0.0, 0.0, 0.0));
    
    size = len(v);
    for i in range(0, size):
        m[row[i]][col[i]] = v[i];
    
    return m;

# Returns matrix as byte string in row-major (?)
def ByteMatrix(m):
    m = m.copy();
    m.transpose();
    return struct.pack('<16f', *m[0], *m[1], *m[2], *m[3]);

# Returns byte string of [length, char0, char1, ...]
def ByteString(name):
    out = struct.pack('<B', len(name) ); # Length of string
    for c in name: 
        out += struct.pack('b', ord(c));
    return out;

# Returns byte string of [nonzeros, val0, val1, ...]
def ByteMatrixSparse(sparse):
    v = sparse[0];
    col = sparse[1];
    row = sparse[2];
    size = len(v);
    
    # Writes numnonzeros, then row+col packed and its value
    out = struct.pack('<B', len(v)); # Number of nonzeros
    for i in range(0, size):
        colrowpacked = (row[i] << 4) | col[i]; # RRRRCCCC
        out += struct.pack('<Bf', colrowpacked, v[i]);
    return out;

# Returns duplicated object with modifiers and transforms applied
def DuplicateObject(source):
    # Set source as active
    bpy.ops.object.select_all(action='DESELECT');
    bpy.context.view_layer.objects.active = source;
    source.select_set(True);
    # Duplicate source
    bpy.ops.object.duplicate(linked = 0, mode = 'TRANSLATION');
    obj = bpy.context.view_layer.objects.active;
    source.select_set(False);
    obj.select_set(True);
    bpy.context.view_layer.objects.active = obj;
    obj.name = source.name + '__temp';
    
    return obj;