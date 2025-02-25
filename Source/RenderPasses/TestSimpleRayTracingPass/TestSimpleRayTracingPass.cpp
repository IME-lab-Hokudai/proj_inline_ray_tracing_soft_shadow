/***************************************************************************
 # Copyright (c) 2015-23, NVIDIA CORPORATION. All rights reserved.
 #
 # Redistribution and use in source and binary forms, with or without
 # modification, are permitted provided that the following conditions
 # are met:
 #  * Redistributions of source code must retain the above copyright
 #    notice, this list of conditions and the following disclaimer.
 #  * Redistributions in binary form must reproduce the above copyright
 #    notice, this list of conditions and the following disclaimer in the
 #    documentation and/or other materials provided with the distribution.
 #  * Neither the name of NVIDIA CORPORATION nor the names of its
 #    contributors may be used to endorse or promote products derived
 #    from this software without specific prior written permission.
 #
 # THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS "AS IS" AND ANY
 # EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 # IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 # PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 # CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 # EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 # PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 # PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 # OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 # (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 # OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 **************************************************************************/
#include "TestSimpleRayTracingPass.h"

extern "C" FALCOR_API_EXPORT void registerPlugin(Falcor::PluginRegistry& registry)
{
    registry.registerClass<RenderPass, TestSimpleRayTracingPass>();
}
namespace
{
const char kShaderFile[] = "RenderPasses/TestSimpleRayTracingPass/SimpleRayTracing.rt.slang";

} // namespace

TestSimpleRayTracingPass::TestSimpleRayTracingPass(ref<Device> pDevice, const Properties& props) : RenderPass(pDevice)
{
    //mpFbo = Fbo::create(mpDevice);
    /*Sampler::Desc samplerDesc;
    samplerDesc.setFilterMode(TextureFilteringMode::Linear, TextureFilteringMode::Linear, TextureFilteringMode::Linear);*/
}

Properties TestSimpleRayTracingPass::getProperties() const
{
    return {};
}

RenderPassReflection TestSimpleRayTracingPass::reflect(const CompileData& compileData)
{
    // Define the required resources here
    RenderPassReflection reflector;
    reflector.addOutput("output", "RT output").bindFlags(ResourceBindFlags::UnorderedAccess).format(ResourceFormat::RGBA32Float);
    return reflector;
}

void TestSimpleRayTracingPass::execute(RenderContext* pRenderContext, const RenderData& renderData)
{
    auto pTargetFbo = renderData.getTexture("output");
    const float4 clearColor(0, 0, 0, 1);
    pRenderContext->clearUAV(pTargetFbo->getUAV().get(), clearColor);

    if (mpScene)
    {
        auto var = mpRtVars->getRootVar();
        var["gOutput"] = pTargetFbo;
        var["PerFrameCB"]["viewportDims"] = uint2(pTargetFbo->getWidth(), pTargetFbo->getHeight());
        var["PerFrameCB"]["sampleIndex"] = mSampleIndex++;
        mpScene->raytrace(pRenderContext, mpRtProgram.get(), mpRtVars, uint3(pTargetFbo->getWidth(), pTargetFbo->getHeight(), 1));
    }
}

void TestSimpleRayTracingPass::renderUI(Gui::Widgets& widget) {}

void TestSimpleRayTracingPass::setScene(RenderContext* pRenderContext, const ref<Scene>& pScene)
{
    // Set new scene.
    mpScene = pScene;
    if (mpScene)
    {
        // program
        ProgramDesc rtProgDesc;
        rtProgDesc.addShaderModules(mpScene->getShaderModules());
        rtProgDesc.addShaderLibrary(kShaderFile);
        rtProgDesc.setMaxTraceRecursionDepth(3);// 1 for calling TraceRay from RayGen, 1 for calling it from the
                                                    // primary-ray ClosestHit shader for reflections, 1 for reflection ray
                                                    // tracing a shadow ray
        rtProgDesc.setMaxPayloadSize(24);        // The largest ray payload struct (PrimaryRayData) is 24 bytes. The payload size
                                                    // should be set as small as possible for maximum performance.
        rtProgDesc.setMaxAttributeSize(8);
        // Add global type conformances.
        rtProgDesc.addTypeConformances(mpScene->getTypeConformances());

        ref<RtBindingTable> sbt = RtBindingTable::create(1, 2, mpScene->getGeometryCount());
        sbt->setRayGen(rtProgDesc.addRayGen("rayGen"));
        sbt->setMiss(0, rtProgDesc.addMiss("primaryMiss"));
        auto primary = rtProgDesc.addHitGroup("primaryClosestHit");
        //auto primary = rtProgDesc.addHitGroup("primaryClosestHit", "primaryAnyHit");
        sbt->setHitGroup(0, mpScene->getGeometryIDs(Scene::GeometryType::TriangleMesh), primary);

        mpRtProgram = Program::create(mpDevice, rtProgDesc, mpScene->getSceneDefines());
        mpRtVars = RtProgramVars::create(mpDevice, mpRtProgram, sbt);
    }
}
