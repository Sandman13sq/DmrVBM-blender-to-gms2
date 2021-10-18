import bpy
import struct

def FetchArmature(object):
    if object:
        if object.type == 'ARMATURE':
            return object;
        if object.parent:
            if object.parent.type == 'ARMATURE':
                return object.parent;
        if object.type in ['MESH']:
            if object.modifiers:
                for m in modifiers:
                    if m.type == 'ARMATURE':
                        if m.armature:
                            return m.armature;
    return None;

# Returns byte string of [length, char0, char1, ...]
def ByteString(name):
    out = struct.pack('<B', len(name) ); # Length of string
    for c in name: 
        out += struct.pack('b', ord(c));
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
 
 