from pathlib import WindowsPath, PosixPath
from falcor import *

def render_graph_TestInlineRayTracing():
    g = RenderGraph('TestInlineRayTracing')
    g.create_pass('TestInlineRayTracingPass', 'TestInlineRayTracingPass', {})
    g.mark_output('TestInlineRayTracingPass.output')
    return g

TestInlineRayTracing = render_graph_TestInlineRayTracing()
try: m.addGraph(TestInlineRayTracing)
except NameError: None
