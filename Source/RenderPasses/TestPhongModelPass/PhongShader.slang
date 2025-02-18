import Scene.Raster; // Imports defaultVS.

SamplerState gSampler;
SamplerComparisonState gSamShadow;
Texture2D gShadowMap;

cbuffer PerFrameCB
{
    float4x4 gShadowTransform;//transform to shadow map texture space
};

VSOut vsMain(VSIn vIn)
{
    VSOut vsOut = defaultVS(vIn);
    vsOut.shadowPosH = mul(gShadowTransform, float4(vsOut.posW, 1.f));
    return vsOut;
}

//---------------------------------------------------------------------------------------
// Transforms a normal map sample to world space.
//---------------------------------------------------------------------------------------
float3 NormalSampleToWorldSpace(float3 normalMapSample, float3 unitNormalW, float3 tangentW)
{
    // Uncompress each component from [0,1] to [-1,1].
    float3 normalT = 2.0f * normalMapSample - 1.0f;

    // Build orthonormal basis.
    float3 N = unitNormalW;
    float3 T = normalize(tangentW - dot(tangentW, N) * N);
    float3 B = cross(N, T);

    float3x3 TBN = float3x3(T, B, N);

    // Transform from tangent space to world space.
    float3 bumpedNormalW = mul(normalT, TBN);

    return bumpedNormalW;
}

//---------------------------------------------------------------------------------------
// PCF for shadow mapping.
//---------------------------------------------------------------------------------------
// factor of 0 means point is in shadow, 1 means not in shadow
float CalcShadowFactor(float4 shadowPosH)
{
    // Complete projection by doing division by w.
    shadowPosH.xyz /= shadowPosH.w;

    // Depth in NDC space.
    float depth = shadowPosH.z - 0.001f;

    uint width, height, numMips;
    gShadowMap.GetDimensions(0, width, height, numMips);

    // Texel size.
    float dx = 1.0f / (float)width;

    float percentlit = 0.0f;
    const float2 offsets[9] =
    {
        float2(-dx, -dx),  float2(0.0f, -dx),  float2(dx, -dx),
                                float2(-dx, 0.0f), float2(0.0f, 0.0f), float2(dx, 0.0f),
                                float2(-dx, +dx),  float2(0.0f, +dx),  float2(dx, +dx)
    };

    [unroll]
    for (int i = 0; i < 9; ++i)
    {
        percentlit += gShadowMap.SampleCmpLevelZero(gSamShadow, shadowPosH.xy + offsets[i], depth).r;
    }

     return percentlit / 9.0f;
    //float sd = gShadowMap.Sample(gSampler, shadowPosH.xy).r;
    //if (sd <= depth) {
    //    return 0;
    //}
    //return 1;
}

float4 psMain(VSOut vsOut, uint triangleIndex: SV_PrimitiveID) : SV_TARGET
{
    float3 viewDir = normalize(gScene.camera.getPosition() - vsOut.posW);
    ShadingData shadingData = prepareShadingData(vsOut, triangleIndex, viewDir);
    BasicMaterialData baseColorMat = gScene.materials.getBasicMaterialData(vsOut.materialID);
    float4 baseColorSample = gScene.materials.sampleTexture(baseColorMat.texBaseColor, gSampler, vsOut.texC, 0.f);
    float4 emissiveSample = gScene.materials.sampleTexture(baseColorMat.texEmissive, gSampler, vsOut.texC, 0.f);
    float4 specularSample = gScene.materials.sampleTexture(baseColorMat.texSpecular, gSampler, vsOut.texC, 0.f);
    float3 normalSample = gScene.materials.sampleTexture(baseColorMat.texNormalMap, gSampler, vsOut.texC, 0.f).rgb;
    LightData dirLightData = gScene.getLight(0); // hardcode for test scene, dir light is index 0

    // The light vector aims opposite the direction the light rays travel.
    float3 lightVec = -dirLightData.dirW;

    // Interpolating normal can unnormalize it, so renormalize it.
    //vsOut.normalW = normalize(vsOut.normalW);

    // Scale light down by Lambert's cosine law.
    float3 normalSampleW = NormalSampleToWorldSpace(normalSample, normalize(vsOut.normalW), vsOut.tangentW.rgb);

    // Only the first light casts a shadow.
    float shadowFactor = CalcShadowFactor(vsOut.shadowPosH);

    //diffuse calculation
    float ndotl = max(dot(lightVec, normalSampleW), 0.0f);
    float3 diffuseColor = baseColorSample.rgb * ndotl;

    // specular calculation
    const float shininess = specularSample.r;
    const float m = shininess * 256.0f; 
    float3 halfVec = normalize(viewDir + lightVec);

    float roughnessFactor = (m + 8.0f) * pow(max(dot(halfVec, normalSampleW), 0.0f), m) / 8.0f;
    // float3 fresnelFactor = SchlickFresnel(mat.FresnelR0, halfVec, lightVec);
    float3 specColor = specularSample.rgb*roughnessFactor;

    // Our spec formula goes outside [0,1] range, but we are
    // doing LDR rendering.  So scale it down a bit.
    specColor = specColor / (specColor + 1.0f);

    float3 litColor = (diffuseColor + specColor) * dirLightData.intensity * shadowFactor + emissiveSample.rgb;

    return float4(litColor,1.0f);
}
