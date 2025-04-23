import Scene.Raster; // Imports defaultVS.

SamplerState gSampler;

Texture2D<float32_t> penumbraMask;
cbuffer PerFrameCB
{
    
};

VSOut vsMain(VSIn vIn)
{
    VSOut vsOut = defaultVS(vIn);
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

float4 psMain(VSOut vsOut, uint triangleIndex: SV_PrimitiveID) : SV_TARGET
{
    float3 viewDir = normalize(gScene.camera.getPosition() - vsOut.posW);
    ShadingData shadingData = prepareShadingData(vsOut, triangleIndex, viewDir);
    BasicMaterialData baseColorMat = gScene.materials.getBasicMaterialData(vsOut.materialID);
    float4 baseColorSample = float4(0, 0, 0, 1);
    float4 emissiveSample = float4(0, 0, 0, 1);
    float4 specularSample = float4(0, 0, 0, 1);
    float3 normalSample;
    float3 normalSampleW;
    if (baseColorMat.texBaseColor.getMode() == TextureHandle::Mode::Texture) {
        baseColorSample = gScene.materials.sampleTexture(baseColorMat.texBaseColor, gSampler, vsOut.texC, 0.f);
        emissiveSample = gScene.materials.sampleTexture(baseColorMat.texEmissive, gSampler, vsOut.texC, 0.f);
        specularSample = gScene.materials.sampleTexture(baseColorMat.texSpecular, gSampler, vsOut.texC, 0.f);
        normalSample = gScene.materials.sampleTexture(baseColorMat.texNormalMap, gSampler, vsOut.texC, 0.f).rgb;
        normalSampleW = NormalSampleToWorldSpace(normalSample, normalize(vsOut.normalW), vsOut.tangentW.rgb);
    }
    else {
        baseColorSample = (float4)baseColorMat.baseColor;
        emissiveSample = float4(baseColorMat.emissive,1);
        specularSample = baseColorMat.specular;
        normalSample = normalize(vsOut.normalW);
        normalSampleW = normalSample;
    }

    LightData light = gScene.getLight(0);

    // The light vector aims opposite the direction the light rays travel.
    // float3 lightVec = -dirLightData.dirW;
    float3 lightPos = mul(light.transMat, float4(0, 0, 0, 1.f)).xyz;
    float3 toLightDir = lightPos - vsOut.posW;

    // Scale light down by Lambert's cosine law.
    //float3 normalSampleW = NormalSampleToWorldSpace(normalSample, normalize(vsOut.normalW), vsOut.tangentW.rgb);

    // diffuse calculation
    float ndotl = max(dot(toLightDir, normalSampleW), 0.0f);
    float3 diffuseColor = baseColorSample.rgb * ndotl;

    // specular calculation
    const float shininess = specularSample.r;
    const float m = shininess * 256.0f;
    float3 halfVec = normalize(viewDir + toLightDir);

    float roughnessFactor = (m + 8.0f) * pow(max(dot(halfVec, normalSampleW), 0.0f), m) / 8.0f;
    // float3 fresnelFactor = SchlickFresnel(mat.FresnelR0, halfVec, lightVec);
    float3 specColor = specularSample.rgb*roughnessFactor;

    // Our spec formula goes outside [0,1] range, but we are
    // doing LDR rendering.  So scale it down a bit.
    specColor = specColor / (specColor + 1.0f);

    // float3 litColor = (diffuseColor + specColor) * light.intensity  + emissiveSample.rgb;
    float3 litColor = baseColorSample.rgb*(1 - penumbraMask[vsOut.posH.xy]);
    return float4(litColor,1.0f);
    // return emissiveSample;
    //return baseColorSample;
}
