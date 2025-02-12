import Scene.Raster; // Imports defaultVS.

SamplerState gSampler;

cbuffer PerFrameCB
{
    float4 gColor;
};

VSOut vsMain(VSIn vIn)
{
    return defaultVS(vIn);
}

//// Schlick gives an approximation to Fresnel reflectance (see pg. 233 "Real-Time Rendering 3rd Ed.").
//// R0 = ( (n-1)/(n+1) )^2, where n is the index of refraction.
//float3 SchlickFresnel(float3 R0, float3 normal, float3 lightVec)
//{
//    float cosIncidentAngle = saturate(dot(normal, lightVec));

//    float f0 = 1.0f - cosIncidentAngle;
//    float3 reflectPercent = R0 + (1.0f - R0) * (f0 * f0 * f0 * f0 * f0);

//    return reflectPercent;
//}

//float3 BlinnPhong(float3 lightStrength, float3 lightVec, float3 normal, float3 toEye, BasicMaterialData mat)
//{
//    const float m = mat.Shininess * 256.0f;
//    float3 halfVec = normalize(toEye + lightVec);

//    float roughnessFactor = (m + 8.0f) * pow(max(dot(halfVec, normal), 0.0f), m) / 8.0f;
//    float3 fresnelFactor = SchlickFresnel(mat.FresnelR0, halfVec, lightVec);

//    float3 specAlbedo = fresnelFactor * roughnessFactor;

//    // Our spec formula goes outside [0,1] range, but we are
//    // doing LDR rendering.  So scale it down a bit.
//    specAlbedo = specAlbedo / (specAlbedo + 1.0f);

//    return (mat.DiffuseAlbedo.rgb + specAlbedo) * lightStrength;
//}

////---------------------------------------------------------------------------------------
//// Evaluates the lighting equation for directional lights.
////---------------------------------------------------------------------------------------
//float3 ComputeDirectionalLight(LightData lightData, BasicMaterialData mat, float3 normal, float3 toEye)
//{
//    // The light vector aims opposite the direction the light rays travel.
//    float3 lightVec = -lightData.dirW;

//    // Scale light down by Lambert's cosine law.
//    float ndotl = max(dot(lightVec, normal), 0.0f);
//    float3 lightStrength = lightData.intensity * ndotl;

//    return BlinnPhong(lightStrength, lightVec, normal, toEye, mat);
//}

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

    float3 litColor = (diffuseColor + specColor) * dirLightData.intensity + emissiveSample.rgb;

    return float4(litColor,1.0f);
}
