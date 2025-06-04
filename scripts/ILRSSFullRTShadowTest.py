from pathlib import WindowsPath, PosixPath
from falcor import *

def render_graph_IRLSSFullRTShadowTest():
    g = RenderGraph('IRLSSFullRTShadowTest')
    g.create_pass('RayTracingShadow', 'RayTracingShadow', {'outputSize': 'Full'})
    g.create_pass('IRTSSRasterPass', 'IRTSSRasterPass', {})
    g.add_edge('RayTracingShadow.penumbraIntensity', 'IRTSSRasterPass.PenumbraMask')
    g.mark_output('IRTSSRasterPass.output')
    return g

IRLSSFullRTShadowTest = render_graph_IRLSSFullRTShadowTest()
try: m.addGraph(IRLSSFullRTShadowTest)
except NameError: None
