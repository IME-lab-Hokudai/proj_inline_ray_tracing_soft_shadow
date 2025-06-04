/***************************************************************************
 # Copyright (c) 2015-24, NVIDIA CORPORATION. All rights reserved.
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
import Scene.Raytracing;
import Utils.Sampling.TinyUniformSampleGenerator;
import Rendering.Lights.LightHelpers;

RWTexture2D<float32_t> penumbraIntensity; // shadow intensity
static const int kNumLightSamples = 32;
float3 getRectSampleOffset(uint index)
{
    float3 offsets[32] = {
        float3(-0.4375f, 0.0f, 0.3750f),
    float3(-0.3125f, 0.0f, 0.3750f),
    float3(-0.1875f, 0.0f, 0.3750f),
        float3(-0.0625f, 0.0f, 0.3750f),
    float3(0.0625f, 0.0f, 0.3750f),
    float3(0.1875f, 0.0f, 0.3750f),
        float3(0.3125f, 0.0f, 0.3750f),
    float3(0.4375f, 0.0f, 0.3750f),

        float3(-0.4375f, 0.0f, 0.1250f),
    float3(-0.3125f, 0.0f, 0.1250f),
    float3(-0.1875f, 0.0f, 0.1250f),
        float3(-0.0625f, 0.0f, 0.1250f),
    float3(0.0625f, 0.0f, 0.1250f),
    float3(0.1875f, 0.0f, 0.1250f),
        float3(0.3125f, 0.0f, 0.1250f),
    float3(0.4375f, 0.0f, 0.1250f),

        float3(-0.4375f, 0.0f, -0.1250f),
    float3(-0.3125f, 0.0f, -0.1250f),
    float3(-0.1875f, 0.0f, -0.1250f),
        float3(-0.0625f, 0.0f, -0.1250f),
    float3(0.0625f, 0.0f, -0.1250f),
    float3(0.1875f, 0.0f, -0.1250f),
        float3(0.3125f, 0.0f, -0.1250f),
    float3(0.4375f, 0.0f, -0.1250f),

        float3(-0.4375f, 0.0f, -0.3750f),
    float3(-0.3125f, 0.0f, -0.3750f),
    float3(-0.1875f, 0.0f, -0.3750f),
        float3(-0.0625f, 0.0f, -0.3750f),
    float3(0.0625f, 0.0f, -0.3750f),
    float3(0.1875f, 0.0f, -0.3750f),
        float3(0.3125f, 0.0f, -0.3750f),
    float3(0.4375f, 0.0f, -0.3750f),
    };
    return offsets[index];
}

cbuffer PerFrameCB
{
    //float4x4 invView;
    uint2 viewportDims;
    //float tanHalfFovY;
    uint sampleIndex;
    //bool useDOF;
};

struct PrimaryRayData
{
    float4 color;
    uint depth;
    float hitT;
};

struct ShadowRayData
{
    bool hit;
};

[shader("miss")]
void shadowMiss(inout ShadowRayData hitData)
{
    hitData.hit = false;
}

[shader("anyhit")]
void shadowAnyHit(inout ShadowRayData hitData, BuiltInTriangleIntersectionAttributes attribs)
{
    hitData.hit = true;
}

[shader("miss")]
void primaryMiss(inout PrimaryRayData hitData)
{
    uint3 launchIndex = DispatchRaysIndex();
    penumbraIntensity[launchIndex.xy] = 0;
}

bool traceShadowRay(RayDesc ray)
{
    ShadowRayData rayData;
    rayData.hit = true;
    TraceRay(gScene.rtAccel, RAY_FLAG_ACCEPT_FIRST_HIT_AND_END_SEARCH, 0xFF, 1 /* ray index 1 is shadow ray */, rayTypeCount, 1, ray, rayData);
    return rayData.hit;
}

[shader("closesthit")]
void primaryClosestHit(inout PrimaryRayData hitData, BuiltInTriangleIntersectionAttributes attribs)
{
    // Get the hit-point data.
    uint triangleIndex = PrimitiveIndex();

    // Prepare the shading data.
    const GeometryInstanceID instanceID = getGeometryInstanceID();
    VertexData v = getVertexData(instanceID, triangleIndex, attribs);

    uint3 launchIndex = DispatchRaysIndex();
    penumbraIntensity[launchIndex.xy] = 0;
    LightData light = gScene.getLight(0);
    if (light.type == (uint)LightType::Rect) {
        [unroll]
        for (int i = 0; i < kNumLightSamples; i++) {
            float3 lightPos = mul(light.transMat, float4(getRectSampleOffset(i), 1.f)).xyz;
            float3 toLightDir = lightPos - v.posW;
            RayDesc shadowRay = { v.posW, 0.001f, normalize(toLightDir), length(toLightDir) - 0.01};

            if (traceShadowRay(shadowRay)) {
                penumbraIntensity[launchIndex.xy] += 1;//increase blocked ray counter
            }
        }
    }
}

[shader("raygeneration")]
void rayGen()
{
    uint3 launchIndex = DispatchRaysIndex();

    RayDesc ray;
   
    ray = gScene.camera.computeRayPinhole(launchIndex.xy, viewportDims, false).toRayDesc();
    
    PrimaryRayData hitData;
    hitData.depth = 0;
    TraceRay(gScene.rtAccel, 0 /*rayFlags*/, 0xFF, 0 /* ray index 0 is primary ray*/, rayTypeCount, 0, ray, hitData);
    penumbraIntensity[launchIndex.xy] = penumbraIntensity[launchIndex.xy]/32.f;
}
