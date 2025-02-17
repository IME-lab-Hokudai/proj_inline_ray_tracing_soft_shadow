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
#include "ShadowMapFirstPass.h"

extern "C" FALCOR_API_EXPORT void registerPlugin(Falcor::PluginRegistry& registry)
{
    registry.registerClass<RenderPass, ShadowMapFirstPass>();
}

namespace
{
const char kShaderFile[] = "RenderPasses/ShadowMapFirstPass/ShadowMapFirstPass.slang";

} // namespace

ShadowMapFirstPass::ShadowMapFirstPass(ref<Device> pDevice, const Properties& props) : RenderPass(pDevice)
{
    mpFbo = Fbo::create(mpDevice);
}

Properties ShadowMapFirstPass::getProperties() const
{
    return {};
}

RenderPassReflection ShadowMapFirstPass::reflect(const CompileData& compileData)
{
    // Define the required resources here
    RenderPassReflection reflector;
    uint2 sz(2048, 2048);//shadow map size
    //const uint2 sz = RenderPassHelpers::calculateIOSize(mOutputSizeSelection, mFixedOutputSize, compileData.defaultTexDims);
    reflector.addOutput("depth", "Depth buffer")
        .format(ResourceFormat::D32Float)
        .bindFlags(ResourceBindFlags::DepthStencil)
        .texture2D(sz.x, sz.y);
    return reflector;
}

void ShadowMapFirstPass::execute(RenderContext* pRenderContext, const RenderData& renderData)
{
    // Update frame dimension based on render pass output.
    auto pDepth = renderData.getTexture("depth");
    FALCOR_ASSERT(pDepth)
    // updateFrameDim(uint2(pDepth->getWidth(), pDepth->getHeight()));
    //  Clear depth buffer.
    pRenderContext->clearDsv(pDepth->getDSV().get(), 1.f, 0);
    mpFbo->attachDepthStencilTarget(pDepth);
    //mpFbo->getDepthStencilView()

    if (mpScene)
    {
        auto var = mpVars->getRootVar();
        var["PerFrameCB"]["gLightViewProjMat"] = lightViewProjMat;
        mpScene->rasterize(pRenderContext, mpGraphicsState.get(), mpVars.get(), mpRasterState, mpRasterState);
    }
}

void ShadowMapFirstPass::setScene(RenderContext* pRenderContext, const ref<Scene>& pScene)
{
    // Set new scene.
    mpScene = pScene;
    if (mpScene)
    {
        // program
        ProgramDesc desc;
        desc.addShaderModules(mpScene->getShaderModules());
        desc.addShaderLibrary(kShaderFile).vsEntry("vsMain"); // Vertex shader entry point
            //.psEntry("psMain"); // Pixel shader entry point;
        // desc.setShaderModel(ShaderModel::SM6_3);
        mpProgram = Program::create(mpDevice, desc, mpScene->getSceneDefines());
        mpVars = ProgramVars::create(mpDevice, mpProgram->getReflector());

        // rasterizer state
        RasterizerState::Desc rasterDesc;
        rasterDesc.setFillMode(RasterizerState::FillMode::Solid);
        rasterDesc.setCullMode(RasterizerState::CullMode::None);
        mpRasterState = RasterizerState::create(rasterDesc);

        // default depth stencil state
        DepthStencilState::Desc dsDesc;
        // dsDesc.setDepthFunc(ComparisonFunc::Greater);
        ref<DepthStencilState> pDsState = DepthStencilState::create(dsDesc);

        mpGraphicsState = GraphicsState::create(mpDevice);
        mpGraphicsState->setProgram(mpProgram);
        mpGraphicsState->setRasterizerState(mpRasterState);
        mpGraphicsState->setFbo(mpFbo);
        mpGraphicsState->setDepthStencilState(pDsState);

        //hardcode  get dir light 
        ref<Light> dirLight = mpScene->getLight(0);

        float3 sceneCenter = float3(0.0f, 0.0f, 0.0f);
        float sceneRadius = 10.0f;

        float3 lightDir = dirLight->getData().dirW;
        //float3 lightDir = float3(0.57735f, -0.57735f, 0.57735f);
        float3 lightPos = -sceneRadius * lightDir;
        float3 targetPos = sceneCenter;
        float3 lightUp = float3(0.0f, 1.0f, 0.0f);
        math::matrix<float,4,4> lightView = math::matrixFromLookAt(lightPos, targetPos, lightUp, math::Handedness::RightHanded);

        //Transform bounding sphere to light space.
        float3 sphereCenterLS;
        sphereCenterLS = math::transformPoint(lightView, targetPos);

        // Ortho frustum in light space encloses scene.
        float l = sphereCenterLS.x - sceneRadius;
        float b = sphereCenterLS.y - sceneRadius;
        float n = abs(sphereCenterLS.z + sceneRadius); //because right handed visible z is negative
        float r = sphereCenterLS.x + sceneRadius;
        float t = sphereCenterLS.y + sceneRadius;
        float f = abs(sphereCenterLS.z - sceneRadius); //because right handed visible z is negative

        math::matrix<float, 4, 4> lightProj = math::ortho(l, r, b, t, n, f);
        lightViewProjMat = math::mul(lightProj, lightView); // light perspective view project matrix
    }
}

void ShadowMapFirstPass::renderUI(Gui::Widgets& widget) {}
