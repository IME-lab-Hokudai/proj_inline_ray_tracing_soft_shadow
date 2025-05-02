from pathlib import WindowsPath, PosixPath
from falcor import *

def render_graph_ILRSSUpscaleVer():
    g = RenderGraph('ILRSSUpscaleVer')
    g.create_pass('VBufferRaster', 'VBufferRaster', {'outputSize': 'Half', 'samplePattern': 'Center', 'sampleCount': 16, 'useAlphaTest': True, 'adjustShadingNormals': True, 'forceCullMode': False, 'cull': 'Back'})
    g.create_pass('PenumbraClassificationPass', 'PenumbraClassificationPass', {'outputSize': 'Half'})
    g.create_pass('UpscalePass', 'UpscalePass', {})
    g.create_pass('IRTSSRasterPass', 'IRTSSRasterPass', {})
    g.add_edge('VBufferRaster.vbuffer', 'PenumbraClassificationPass.src')
    g.add_edge('PenumbraClassificationPass.penumbraIntensity', 'UpscalePass.src')
    g.add_edge('UpscalePass.upscaleDst', 'IRTSSRasterPass.PenumbraMask')
    g.mark_output('IRTSSRasterPass.output')
    return g

ILRSSUpscaleVer = render_graph_ILRSSUpscaleVer()
try: m.addGraph(ILRSSUpscaleVer)
except NameError: None
