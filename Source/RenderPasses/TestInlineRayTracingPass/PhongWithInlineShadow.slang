import Scene.Raster; // Imports defaultVS.
import Scene.RaytracingInline;
SamplerState gSampler;

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

    /*inline ray tracing*/
    Ray ray;
    ray.origin = vsOut.posW;
    // ray.dir = vsOut.posW + lightVec; // ray from fragment to light source
    ray.dir = lightVec; // ray from fragment to light source
    ray.tMin = 0.001;
    ray.tMax = 1000;

    SceneRayQuery<false> sceneRayQuery;
    float hitT;
    HitInfo hitInfo = sceneRayQuery.traceRay(ray, hitT, 4);
    if (hitInfo.isValid()) {//shadow ray hit something
        return float4(0, 0, 0, 1.0f);
    }

    return float4(litColor,1.0f);
}
