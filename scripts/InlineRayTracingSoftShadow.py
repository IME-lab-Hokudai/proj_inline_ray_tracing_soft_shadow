from pathlib import WindowsPath, PosixPath
from falcor import *

def render_graph_InlineRayTracingSoftShadow():
    g = RenderGraph('InlineRayTracingSoftShadow')
    g.create_pass('VBufferRaster', 'VBufferRaster', {'outputSize': 'Half', 'samplePattern': 'Center', 'sampleCount': 16, 'useAlphaTest': True, 'adjustShadingNormals': True, 'forceCullMode': False, 'cull': 'Back'})
    g.create_pass('PenumbraClassificationPass', 'PenumbraClassificationPass', {'outputSize': 'Half'})
    g.create_pass('IRTSSRasterPass', 'IRTSSRasterPass', {})
    g.add_edge('VBufferRaster.vbuffer', 'PenumbraClassificationPass.src')
    g.add_edge('PenumbraClassificationPass.upscaleDst', 'IRTSSRasterPass.PenumbraMask')
    g.mark_output('IRTSSRasterPass.output')
    return g

InlineRayTracingSoftShadow = render_graph_InlineRayTracingSoftShadow()
try: m.addGraph(InlineRayTracingSoftShadow)
except NameError: None
