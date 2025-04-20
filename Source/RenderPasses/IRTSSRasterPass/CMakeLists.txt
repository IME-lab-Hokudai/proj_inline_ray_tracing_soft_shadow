add_plugin(IRTSSRasterPass)

target_sources(IRTSSRasterPass PRIVATE
    IRTSSRasterPass.cpp
    IRTSSRasterPass.h
	IRTSSRaster.slang
)

target_copy_shaders(IRTSSRasterPass RenderPasses/IRTSSRasterPass)
target_source_group(IRTSSRasterPass "RenderPasses")
