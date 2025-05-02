add_plugin(UpscalePass)

target_sources(UpscalePass PRIVATE
    UpscalePass.cpp
    UpscalePass.h
	UpScale.cs.slang
)

target_copy_shaders(UpscalePass RenderPasses/UpscalePass)
target_source_group(UpscalePass "RenderPasses")
