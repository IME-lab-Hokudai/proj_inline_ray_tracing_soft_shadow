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
#include "RayTracingShadow.h"

extern "C" FALCOR_API_EXPORT void registerPlugin(Falcor::PluginRegistry& registry)
{
    registry.registerClass<RenderPass, RayTracingShadow>();
}

namespace
{
const char kShaderFile[] = "RenderPasses/RayTracingShadow/RayTracingShadow.rt.slang";
const char kIntensityDst[] = "penumbraIntensity";
const char kOutputSize[] = "outputSize";
const char kFixedOutputSize[] = "fixedOutputSize";
} // namespace

RayTracingShadow::RayTracingShadow(ref<Device> pDevice, const Properties& props) : RenderPass(pDevice)
{
    for (const auto& [key, value] : props)
    {
        if (key == kOutputSize)
            mOutputSizeSelection = value;
        else if (key == kFixedOutputSize)
            mFixedOutputSize = value;
    }
}

Properties RayTracingShadow::getProperties() const
{
    Properties props;
    props[kOutputSize] = mOutputSizeSelection;
    if (mOutputSizeSelection == RenderPassHelpers::IOSize::Fixed)
        props[kFixedOutputSize] = mFixedOutputSize;
    return props;
}

RenderPassReflection RayTracingShadow::reflect(const CompileData& compileData)
{
    // Define the required resources here
    RenderPassReflection reflector;
    const uint2 sz = RenderPassHelpers::calculateIOSize(mOutputSizeSelection, mFixedOutputSize, compileData.defaultTexDims);
    reflector.addOutput(kIntensityDst, "Shadow intensity texture")
        .bindFlags(ResourceBindFlags::UnorderedAccess | ResourceBindFlags::ShaderResource)
        .format(ResourceFormat::R32Float)
        .texture2D(sz.x, sz.y);
    return reflector;
}

void RayTracingShadow::execute(RenderContext* pRenderContext, const RenderData& renderData)
{
    auto intensityBuffer = renderData.getTexture(kIntensityDst);

    if (mpScene)
    {
        auto var = mpRtVars->getRootVar();
        var["penumbraIntensity"] = intensityBuffer;
        var["PerFrameCB"]["viewportDims"] = uint2(intensityBuffer->getWidth(), intensityBuffer->getHeight());
        //var["PerFrameCB"]["sampleIndex"] = mSampleIndex++;
        mpScene->raytrace(pRenderContext, mpRtProgram.get(), mpRtVars, uint3(intensityBuffer->getWidth(), intensityBuffer->getHeight(), 1));
    }
}

void RayTracingShadow::renderUI(Gui::Widgets& widget)
{
    // Controls for output size.var["gScene"]
    // When output size requirements change, we'll trigger a graph recompile to update the render pass I/O sizes.
    if (widget.dropdown("Output size", mOutputSizeSelection))
        requestRecompile();
    if (mOutputSizeSelection == RenderPassHelpers::IOSize::Fixed)
    {
        if (widget.var("Size in pixels", mFixedOutputSize, 32u, 16384u))
            requestRecompile();
    }
}

void RayTracingShadow::setScene(RenderContext* pRenderContext, const ref<Scene>& pScene)
{
    // Set new scene.
    mpScene = pScene;
    if (mpScene)
    {
        // program
        ProgramDesc rtProgDesc;
        rtProgDesc.addShaderModules(mpScene->getShaderModules());
        rtProgDesc.addShaderLibrary(kShaderFile);
        rtProgDesc.setMaxTraceRecursionDepth(3); // 1 for calling TraceRay from RayGen, 1 for calling it from the
                                                 // primary-ray ClosestHit shader for reflections, 1 for reflection ray
                                                 // tracing a shadow ray
        rtProgDesc.setMaxPayloadSize(24);        // The largest ray payload struct (PrimaryRayData) is 24 bytes. The payload size
                                                 // should be set as small as possible for maximum performance.
        rtProgDesc.setMaxAttributeSize(8);
        // Add global type conformances.
        rtProgDesc.addTypeConformances(mpScene->getTypeConformances());

        ref<RtBindingTable> sbt = RtBindingTable::create(2, 2, mpScene->getGeometryCount());
        sbt->setRayGen(rtProgDesc.addRayGen("rayGen"));
        sbt->setMiss(0, rtProgDesc.addMiss("primaryMiss"));
        sbt->setMiss(1, rtProgDesc.addMiss("shadowMiss"));
        auto primary = rtProgDesc.addHitGroup("primaryClosestHit");
        auto shadow = rtProgDesc.addHitGroup("", "shadowAnyHit");
        // auto primary = rtProgDesc.addHitGroup("primaryClosestHit", "primaryAnyHit");
        sbt->setHitGroup(0, mpScene->getGeometryIDs(Scene::GeometryType::TriangleMesh), primary);
        sbt->setHitGroup(1, mpScene->getGeometryIDs(Scene::GeometryType::TriangleMesh), shadow);

        mpRtProgram = Program::create(mpDevice, rtProgDesc, mpScene->getSceneDefines());
        mpRtVars = RtProgramVars::create(mpDevice, mpRtProgram, sbt);
    }
}
