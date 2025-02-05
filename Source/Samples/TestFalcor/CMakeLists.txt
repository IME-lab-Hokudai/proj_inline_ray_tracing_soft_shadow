add_falcor_executable(TestFalcor)

target_sources(TestFalcor PRIVATE
    TestFalcor.cpp
    TestFalcor.h
)

target_copy_shaders(TestFalcor Samples/TestFalcor)

target_source_group(TestFalcor "Samples")
