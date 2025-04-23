add_plugin(IRLSSNaiveImplement)

target_sources(IRLSSNaiveImplement PRIVATE
    IRLSSNaiveImplement.cpp
    IRLSSNaiveImplement.h
    IRLSSNaiveImplement.slang
)

target_copy_shaders(IRLSSNaiveImplement RenderPasses/IRLSSNaiveImplement)
target_source_group(IRLSSNaiveImplement "RenderPasses")
