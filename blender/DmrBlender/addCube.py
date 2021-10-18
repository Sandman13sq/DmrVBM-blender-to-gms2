import bpy
import sys

data = ['I hate cheese'];

class addCubeSample(bpy.types.Operator):
    bl_idname = 'mesh.add_cube_sample'
    bl_label = 'Add Cube'
    bl_options = {"REGISTER", "UNDO"}

    def execute(self, context):
        bpy.ops.mesh.primitive_cube_add()
        return {"FINISHED"}

def register() :
    bpy.utils.register_class(addCubeSample)

def unregister() :
    bpy.utils.unregister_class(addCubeSample)
