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
//                          Light Helpers                                    //
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

    half3 diffuse;
};

struct SuikaBRDFData
{

};

struct appdata
{
    float4 vertex : POSITION;
    float4 tangent : TANGENT;
    float3 normal : NORMAL;
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

    half3 tspace0 : TEXCOORD6;
    half3 tspace1 : TEXCOORD7;
    half3 tspace2 : TEXCOORD8;
};

Light GetMainLight(v2f i)
{
    float4 shadowCoord = TransformWorldToShadowCoord(i.positionWS);
    Light  mainLight = GetMainLight(i.shadowCoord);
    return mainLight;
}

// ===========================================================
// Vertex Shader Functions
// ===========================================================
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

// ===========================================================
// Fragment Shader Functions
// ===========================================================

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

half3 WorldNormal(v2f i)
{
    half3 tNormal = normalize(UnpackNormal(tex2D(_NormalTex, i.uv)).xyz);
    half3 wNormal = NormalTangentToWorld(tNormal, i);
    return wNormal;
}

SuikaSurfaceData InitializeSuikaSurfaceData(v2f i)
{
    SuikaSurfaceData surfaceData;
    surfaceData.normalWS = WorldNormal(i);
    surfaceData.viewDirWS = normalize(i.viewDirWS);
    surfaceData.bakedGI = SAMPLE_GI(i.lightmapUV, i.vertexSH, surfaceData.normalWS);
    surfaceData.emission = tex2D(_GlowTex, i.uv).rgb;

    return surfaceData;
}

SuikaMaterialData InitializeSuikaMaterialData(v2f i)
{
    SuikaMaterialData materialData;
    materialData.albedo = tex2D(_MainTex, i.uv) * _BaseColor;
    materialData.metallic = _Metallic;
    materialData.smoothness = _Smoothness;
    materialData.roughness = 1 - materialData.smoothness;

    half oneMinusReflectivity = OneMinusReflectivityMetallic(materialData.metallic);
    materialData.diffuse = materialData.albedo * oneMinusReflectivity;

    return materialData;
}

half3 GlobalIllumination(
    SuikaSurfaceData surfaceData,
    SuikaMaterialData materialData)
{
    half occlusion= 1;
    half3 indirectDiffuse = surfaceData.bakedGI * occlusion;
    half3 irradiance = materialData.diffuse * indirectDiffuse;

    return irradiance;
}
half3 PhysicalBasedLighting(
    SuikaSurfaceData surfaceData,
    SuikaMaterialData materialData,
    Light light)
{
    // Get Radiance part
    half NdotL = saturate(dot(surfaceData.normalWS, light.direction));
    half lightAttenuation = light.distanceAttenuation * light.shadowAttenuation;
    half3 radiance = light.color * lightAttenuation * NdotL;

    // Get BRDF part
    half3 brdf = materialData.diffuse;
    
    // Specular Part
    // -----------------------------------
    // Calc D\F\G
    half3 Fresnel0 = half3(0.04, 0.04, 0.04);
          Fresnel0 = lerp(Fresnel0, materialData.albedo, materialData.metallic);
    
    half3   halfDir = 0.5 * (light.direction + surfaceData.viewDirWS);
    float   D = DistributionGGX(surfaceData.normalWS, halfDir, materialData.roughness);  
    half3   F = fresnelSchlick(max(dot(surfaceData.normalWS, surfaceData.viewDirWS), 0.0), Fresnel0);
    float   G = GeometrySmith(surfaceData.normalWS, surfaceData.viewDirWS, light.direction, materialData.roughness);       
    // Calc cook-torrance BRDF
    half3   nominator    = D * G * F;
    float   denominator  = 4.0 * max(dot(surfaceData.normalWS, surfaceData.viewDirWS), 0.0) * NdotL + 0.001; 
    half3   specularBRDF = nominator / denominator;  

    brdf += specularBRDF;
    
    // Return Irradiance, namely radiance x brdf
    return radiance * brdf;
}

#endif