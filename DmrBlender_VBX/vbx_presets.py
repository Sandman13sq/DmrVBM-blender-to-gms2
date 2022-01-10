import bpy
import os

try:
    from .vbx_func import *
except:
    from vbx_func import *

attribpresets = {
    '_Pos-Col-UV': [VBF_POS, VBF_RGB, VBF_TEX],
    '_Pos-Nor-Col-UV': [VBF_POS, VBF_NOR, VBF_RGB, VBF_TEX],
    '_Pos-Nor-Tan-Btn-Col-UV': [VBF_POS, VBF_NOR, VBF_TAN, VBF_BTN, VBF_RGB, VBF_TEX],
    '_Pos-Nor-Col-UV-Bon-Wei': [VBF_POS, VBF_NOR, VBF_RGB, VBF_TEX, VBF_BON, VBF_WEI],
    '_Pos-Nor-Tan-Btn-Col-UV-Bon-Wei': [VBF_POS, VBF_NOR, VBF_TAN, VBF_BTN, VBF_RGB, VBF_TEX, VBF_BON, VBF_WEI],
}

presetheader = 'import bpy\nop = bpy.context.active_operator\n\n'

def PresetPanic():
    print('> Generating presets...')
    
    paths = bpy.utils.preset_paths('operator/')
    p = None
    
    for p in bpy.utils.preset_paths('operator/'):
        if 'Roaming' in p:
            break
        
    if p:
        for opname in ['dmr.gm_export_vb', 'dmr.gm_export_vbx']:
            dir = p+opname+'/'
            try:
                os.mkdir(dir)
            except:
                ''
            
            rootpath = dir+'%s.py'
            def OutputToFile(out, fname):
                f = open(rootpath % fname, 'w')
                f.write(out)
                f.close()
            
            # Format Presets
            for name, format in attribpresets.items():
                format += [VBF_000] * (8-len(format))
                out = presetheader
                out += ''.join(['op.vbf%d = "%s"\n' % (i, k) for i, k in enumerate(format)])
                OutputToFile(out, name)
            
            # Y Flip
            out = presetheader
            out += 'op.forwardaxis = "-y"\n'
            OutputToFile(out, '_YFlip')

PresetPanic()
