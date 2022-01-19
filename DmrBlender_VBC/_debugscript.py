# Used to load in all scripts from folder in blender
# Text Editor > Open this script > Run Script

import os
import sys
import bpy

# System Path
filesDir = os.path.dirname(bpy.context.space_data.text.filepath);

initFile = "__init__.py"
print('> Reading "%s" from "%s"' % (initFile, filesDir) );

if filesDir not in sys.path:
    sys.path.append(filesDir)

file = os.path.join(filesDir, initFile)

if 'DEBUG_MODE' not in sys.argv:
    sys.argv.append('DEBUG_MODE')

exec(compile(open(file).read(), initFile, 'exec'))

if 'DEBUG_MODE' in sys.argv:
    sys.argv.remove('DEBUG_MODE')
