from pathlib import WindowsPath, PosixPath
from falcor import *

def render_graph_ILRSSFullResVer():
    g = RenderGraph('ILRSSFullResVer')
    g.create_pass('VBufferRaster', 'VBufferRaster', {'outputSize': 'Default', 'samplePattern': 'Center', 'sampleCount': 16, 'useAlphaTest': True, 'adjustShadingNormals': True, 'forceCullMode': False, 'cull': 'Back'})
    g.create_pass('PenumbraClassificationPass', 'PenumbraClassificationPass', {'outputSize': 'Default'})
    g.create_pass('IRTSSRasterPass', 'IRTSSRasterPass', {})
    g.add_edge('VBufferRaster.vbuffer', 'PenumbraClassificationPass.src')
    g.add_edge('PenumbraClassificationPass.penumbraIntensity', 'IRTSSRasterPass.PenumbraMask')
    g.mark_output('IRTSSRasterPass.output')
    return g

ILRSSFullResVer = render_graph_ILRSSFullResVer()
try: m.addGraph(ILRSSFullResVer)
except NameError: None
