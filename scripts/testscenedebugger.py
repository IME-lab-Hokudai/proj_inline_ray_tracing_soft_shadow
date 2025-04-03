from pathlib import WindowsPath, PosixPath
from falcor import *

def render_graph_testscenedebugger():
    g = RenderGraph('testscenedebugger')
    g.create_pass('SceneDebugger', 'SceneDebugger', {'mode': 'FaceNormal', 'showVolumes': 1, 'useVBuffer': 0})
    g.create_pass('VBufferRaster', 'VBufferRaster', {'outputSize': 'Default', 'samplePattern': 'Center', 'sampleCount': 16, 'useAlphaTest': True, 'adjustShadingNormals': True, 'forceCullMode': False, 'cull': 'Back'})
    g.add_edge('VBufferRaster.vbuffer', 'SceneDebugger.vbuffer')
    g.mark_output('SceneDebugger.output')
    return g

testscenedebugger = render_graph_testscenedebugger()
try: m.addGraph(testscenedebugger)
except NameError: None
