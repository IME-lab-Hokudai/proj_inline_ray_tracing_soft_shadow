add_plugin(TestSimpleRayTracingPass)

target_sources(TestSimpleRayTracingPass PRIVATE
    TestSimpleRayTracingPass.cpp
    TestSimpleRayTracingPass.h
	SimpleRayTracing.rt.slang
)

target_copy_shaders(TestSimpleRayTracingPass RenderPasses/TestSimpleRayTracingPass)
target_source_group(TestSimpleRayTracingPass "RenderPasses")
