add_plugin(TestRenderPass)

target_sources(TestRenderPass PRIVATE
    TestRenderPass.cpp
    TestRenderPass.h
)

target_source_group(TestRenderPass "RenderPasses")
