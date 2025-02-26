add_plugin(TestInlineRayTracingPass)

target_sources(TestInlineRayTracingPass PRIVATE
    TestInlineRayTracingPass.cpp
    TestInlineRayTracingPass.h
	PhongWithInlineShadow.slang
)

target_copy_shaders(TestInlineRayTracingPass RenderPasses/TestInlineRayTracingPass)
target_source_group(TestInlineRayTracingPass "RenderPasses")
