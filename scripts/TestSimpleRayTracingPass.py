from pathlib import WindowsPath, PosixPath
from falcor import *

def render_graph_SimpleRayTracing():
    g = RenderGraph('SimpleRayTracing')
    g.create_pass('TestSimpleRayTracingPass', 'TestSimpleRayTracingPass', {})
    g.mark_output('TestSimpleRayTracingPass.output')
    return g

SimpleRayTracing = render_graph_SimpleRayTracing()
try: m.addGraph(SimpleRayTracing)
except NameError: None
