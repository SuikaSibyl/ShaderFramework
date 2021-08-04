#ifndef SUIKA_LIGHTING
#define SUIKA_LIGHTING

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/EntityLighting.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/ImageBasedLighting.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/BSDF.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Deprecated.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceData.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

#include "SuikaBRDF.hlsl"

///////////////////////////////////////////////////////////////////////////////
//                       Structure Definition                                //
///////////////////////////////////////////////////////////////////////////////
struct SuikaSurfaceData
{
    half3 normalWS;
    half3 viewDirWS;
    half3 bakedGI;
    half3 emission;
};

struct SuikaMaterialData
{
    half4 albedo;
    half  smoothness;
    half  metallic;
    half  roughness;
    half  alpha;

    half3 diffuse;
    half3 specular;
};

struct appdata
{
    float4 vertex : POSITION;
    float4 tangent : TANGENT;
    float3 normal : NORMAL;
    float3 color : COLOR;
    float2 uv : TEXCOORD0;
    float2 lightmapUV : TEXCOORD1;
};

struct v2f
{
    float2 uv : TEXCOORD0;
    DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 1);

    float4 vertex : SV_POSITION;
    
    float3 positionWS   : TEXCOORD2;
    float3 viewDirWS    : TEXCOORD3;
    float4 shadowCoord  : TEXCOORD4;
    float2 extuv        : TEXCOORD5;

    half3 tspace0 : TEXCOORD6;
    half3 tspace1 : TEXCOORD7;
    half3 tspace2 : TEXCOORD8;
};

///////////////////////////////////////////////////////////////////////////////
//                          Light Helpers                                    //
///////////////////////////////////////////////////////////////////////////////

Light GetMainLight(v2f i)
{
    float4 shadowCoord = TransformWorldToShadowCoord(i.positionWS);
    Light  mainLight = GetMainLight(i.shadowCoord);
    return mainLight;
}

// ------------------------------------
// Get Global Illumination
// ------------------------------------
half3 GlobalIllumination(
    SuikaSurfaceData surfaceData,
    SuikaMaterialData materialData)
{
    half occlusion= 1;
    half3 indirectDiffuse = surfaceData.bakedGI * occlusion;
    half3 irradiance = materialData.diffuse * indirectDiffuse;

    return irradiance;
}

///////////////////////////////////////////////////////////////////////////////
//                          Vertex Shader Functions                          //
///////////////////////////////////////////////////////////////////////////////

// ------------------------------------
// Get TBN matrix and send to fragment
// ------------------------------------
void CalcTangentSpace(appdata v, out half3 tspace0, out half3 tspace1, out half3 tspace2)
{
    // Clac TBN
    half3 wNormal = TransformObjectToWorldNormal(v.normal);
    half3 wTangent = TransformObjectToWorldDir(v.tangent.xyz);
    half tangentSign = v.tangent.w * unity_WorldTransformParams.w;
    // Cross({World Space} Normal, Tangent), Get Bitangent
    half3 wBitangent = cross(wNormal, wTangent) * tangentSign;
    tspace0 = half3(wTangent.x, wBitangent.x, wNormal.x);
    tspace1 = half3(wTangent.y, wBitangent.y, wNormal.y);
    tspace2 = half3(wTangent.z, wBitangent.z, wNormal.z);
}

// ------------------------------------
// Get V2F structure initialized as regular
// ------------------------------------
void RegularVertexInit(appdata v, out v2f o)
{
    // Clip Space Vertex
    o.vertex = TransformObjectToHClip(v.vertex);
    // World Space Vertex
    o.positionWS = TransformObjectToWorld(v.vertex);
    // Main Tex UV
    o.uv = TRANSFORM_TEX(v.uv, _MainTex);
    o.extuv = v.uv;
    // World Space View Direction
    o.viewDirWS = GetWorldSpaceViewDir(o.positionWS);
    // Normal Precomputation
    CalcTangentSpace(v, o.tspace0, o.tspace1, o.tspace2);
    // Shadow Coord
    VertexPositionInputs vertexInput = GetVertexPositionInputs(v.vertex.xyz);
    o.shadowCoord = GetShadowCoord(vertexInput);
    // GI Object Precomputation
    OUTPUT_LIGHTMAP_UV(v.lightmapUV, unity_LightmapST, o.lightmapUV);
    half3 normalWS = TransformObjectToWorldNormal(v.normal);
    OUTPUT_SH(normalWS.xyz, o.vertexSH);
}

///////////////////////////////////////////////////////////////////////////////
//                        Fragment Shader Functions                          //
///////////////////////////////////////////////////////////////////////////////

// ------------------------------------
// Get World Space Normal from Tangent space
// ------------------------------------
half3 NormalTangentToWorld(half3 tNormal, v2f i)
{
    half3 wNormal;
    wNormal.x = dot(i.tspace0, tNormal);
    wNormal.y = dot(i.tspace1, tNormal);
    wNormal.z = dot(i.tspace2, tNormal);
    return normalize(wNormal);
}

// ------------------------------------
// Get World Space Normal
// ------------------------------------
half3 WorldNormal(v2f i)
{
    half3 tNormal = normalize(UnpackNormal(tex2D(_NormalTex, i.uv)).xyz);
    half3 wNormal = NormalTangentToWorld(tNormal, i);
    return wNormal;
}

// ------------------------------------
// Initialize Surface Data (No BRDF-para)
// ------------------------------------
SuikaSurfaceData InitializeSuikaSurfaceData(v2f i)
{
    SuikaSurfaceData surfaceData;
    surfaceData.normalWS = WorldNormal(i);
    surfaceData.viewDirWS = normalize(i.viewDirWS);
    surfaceData.bakedGI = SAMPLE_GI(i.lightmapUV, i.vertexSH, surfaceData.normalWS);
    surfaceData.emission = tex2D(_GlowTex, i.uv).rgb;

    return surfaceData;
}

// ------------------------------------
// Initialize Material Data (BRDF-para)
// ------------------------------------
SuikaMaterialData InitializeSuikaMaterialData(v2f i)
{
    SuikaMaterialData materialData;
    materialData.albedo = tex2D(_MainTex, i.uv) * _BaseColor;
    materialData.alpha = materialData.albedo.a;

    // If use Cutout mode, do clip
    #if CUTOUT
        clip(materialData.albedo.a - _Cutoff);
        materialData.albedo.a = 1.0;
    #endif

    materialData.metallic = _Metallic;
    materialData.smoothness = _Smoothness;
    materialData.roughness = PerceptualSmoothnessToPerceptualRoughness(materialData.smoothness);
    materialData.roughness = max(PerceptualRoughnessToRoughness(materialData.roughness), HALF_MIN_SQRT);

    half oneMinusReflectivity = OneMinusReflectivityMetallic(materialData.metallic);
    materialData.diffuse = materialData.albedo * oneMinusReflectivity;
    materialData.specular = lerp(kDieletricSpec.rgb, materialData.albedo, materialData.metallic);

    return materialData;
}

half3 PhysicalBasedLighting(
    SuikaSurfaceData surfaceData,
    SuikaMaterialData materialData,
    Light light)
{
    // Get Radiance part
    // -----------------------------
    half NdotL = saturate(dot(surfaceData.normalWS, light.direction));
    half lightAttenuation = light.distanceAttenuation * light.shadowAttenuation;
    half3 radiance = light.color * lightAttenuation * NdotL;

    // Get BRDF part
    // -----------------------------
    // Diffuse Term
    half3 brdf = materialData.diffuse;
    // Specular Term
    half SpecularTerm = SpecularTermWithoutF(
        light.direction, surfaceData.viewDirWS, 
        surfaceData.normalWS, materialData.roughness);
    brdf += SpecularTerm * materialData.specular;
    
    // Return Irradiance, namely radiance x brdf
    // -----------------------------
    return radiance * brdf;
}

// ------------------------------------
// Standard Lit Irradiance
// ------------------------------------
half3 StandardLitIrradiance(
    SuikaSurfaceData surfaceData,
    SuikaMaterialData materialData,
    v2f i)
{
    // Init irradiance with GI
    // -----------------------------
    half3 irradiance = GlobalIllumination(surfaceData, materialData);

    // Update irradiance with Emission Lights
    // -----------------------------
    irradiance += surfaceData.emission;

    // Update irradiance with Main Light
    // -----------------------------
    Light mainLight = GetMainLight(i);
    irradiance += PhysicalBasedLighting(surfaceData, materialData, mainLight);

    // Update irradiance with Additional Lights
    // -----------------------------
    half4 shadowMask = unity_ProbesOcclusion;
    uint additionalLightCount = GetAdditionalLightsCount();
    for (uint lightIndex = 0u; lightIndex < additionalLightCount; lightIndex++)
    {
        Light light = GetAdditionalLight(lightIndex, i.positionWS, shadowMask);
        irradiance += PhysicalBasedLighting(surfaceData, materialData, light);
    }

    return irradiance;
}

// ------------------------------------
// BSDF Lighting
// ------------------------------------
half3 BSDFLighting(
    SuikaSurfaceData surfaceData,
    SuikaMaterialData materialData,
    Light light, half thickness)
{
    // Get Radiance part
    // -----------------------------
    half NdotL = saturate(dot(surfaceData.normalWS, light.direction));
    half lightAttenuation = light.distanceAttenuation;
    half3 radiance = light.color * lightAttenuation * thickness;

    // Get BSDF part
    // -----------------------------
    // Diffuse Term
    half3 bsdf = materialData.diffuse;

    half fLTDistortion = 0.0;
    half3 vLTLight = light.direction + surfaceData.normalWS * fLTDistortion;
    half iLTPower = 0.5;
    half fLTScale = 1.5;
    half  fLTDot = pow(saturate(dot(surfaceData.normalWS, -vLTLight)), iLTPower) * fLTScale;
    bsdf *= fLTScale;
    // bsdf = fLTDot;
    // Specular Term


    // Return Irradiance, namely radiance x brdf
    // -----------------------------
    return radiance * bsdf;
}

// ------------------------------------
// BSDF Lit Irradiance
// ------------------------------------
half3 BSDFIrradiance(
    SuikaSurfaceData surfaceData,
    SuikaMaterialData materialData,
    v2f i, half thickness)
{
    // Init irradiance with GI
    // -----------------------------
    half3 irradiance = half3(0, 0, 0);

    // Update irradiance with Main Light
    // -----------------------------
    Light mainLight = GetMainLight(i);
    irradiance += BSDFLighting(surfaceData, materialData, mainLight, thickness);

    // Update irradiance with Additional Lights
    // -----------------------------
    half4 shadowMask = unity_ProbesOcclusion;
    uint additionalLightCount = GetAdditionalLightsCount();
    for (uint lightIndex = 0u; lightIndex < additionalLightCount; lightIndex++)
    {
        Light light = GetAdditionalLight(lightIndex, i.positionWS, shadowMask);
        irradiance += BSDFLighting(surfaceData, materialData, light, thickness);
    }

    return irradiance;
}
#endif