#ifndef SUIKA_COMMON
#define SUIKA_COMMON

// Receive Shadow
#pragma multi_compile _ _MAIN_LIGHT_SHADOWS
#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
#pragma multi_compile _ _SHADOWS_SOFT
#pragma multi_compile _ DIRLIGHTMAP_COMBINED
#pragma multi_compile _ LIGHTMAP_ON
#pragma multi_compile _ CUTOUT BLEND
#pragma multi_compile _RoughnessMetallic _SpecularGloss

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

///////////////////////////////////////////////////////////////////////////////
//                            Common Input                                   //
///////////////////////////////////////////////////////////////////////////////
half4 _BaseColor;

sampler2D _MainTex;     float4 _MainTex_ST;
sampler2D _NormalTex;
sampler2D _MaskTex;
sampler2D _GlowTex;

half _Metallic;
half _Smoothness;
half _Cutoff;

///////////////////////////////////////////////////////////////////////////////
//                       Structure Definition                                //
///////////////////////////////////////////////////////////////////////////////
struct SuikaSurfaceData
{
    half3 normalWS;
    half3 viewDirWS;
    half3 bakedGI;
    half3 emission;
    half  occlusion;
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

///////////////////////////////////////////////////////////////////////////////
//                          Vertex Data Initialization                       //
///////////////////////////////////////////////////////////////////////////////
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
// Get World Space Tangent
// ------------------------------------
half3 WorldTangent(v2f i)
{
    half3 wTangent;
    wTangent.x = i.tspace0.x;
    wTangent.y = i.tspace1.x;
    wTangent.z = i.tspace2.x;
    return normalize(wTangent);
}

// ------------------------------------
// Get World Space Bitangent
// ------------------------------------
half3 WorldBitangent(v2f i, half3 normalWS)
{
    half3 wBitangent;
    wBitangent.x = i.tspace0.y;
    wBitangent.y = i.tspace1.y;
    wBitangent.z = i.tspace2.y;
    wBitangent = normalize(wBitangent);
    half3 tmpTangent = cross(normalWS, wBitangent);
    wBitangent = cross(tmpTangent, normalWS);
    return normalize(wBitangent);
}

// ------------------------------------
// Get World Space Normal
// ------------------------------------
half4 WorldNormal(v2f i)
{
    half4 nortex = tex2D(_NormalTex, i.uv);
    half3 tNormal = normalize(UnpackNormal(nortex).xyz);
    half3 wNormal = NormalTangentToWorld(tNormal, i);
    return half4(wNormal, 1);
}

///////////////////////////////////////////////////////////////////////////////
//                        Fragment Data Initialization                       //
///////////////////////////////////////////////////////////////////////////////

// ------------------------------------
// Initialize Surface Data (No BRDF-para)
// ------------------------------------
SuikaSurfaceData InitializeSuikaSurfaceData(v2f i)
{
    SuikaSurfaceData surfaceData;
    half4 normalWS = WorldNormal(i);
    surfaceData.normalWS = normalWS.rgb;
    surfaceData.occlusion = 1;
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

    // Roughness-Metallic Workflow
    // ---------------------------------------
    #if _RoughnessMetallic
    materialData.metallic = _Metallic;
    materialData.smoothness = _Smoothness;
    materialData.roughness = PerceptualSmoothnessToPerceptualRoughness(materialData.smoothness);
    materialData.roughness = max(PerceptualRoughnessToRoughness(materialData.roughness), HALF_MIN_SQRT);

    half oneMinusReflectivity = OneMinusReflectivityMetallic(materialData.metallic);
    materialData.diffuse = materialData.albedo * oneMinusReflectivity;
    materialData.specular = lerp(kDieletricSpec.rgb, materialData.albedo, materialData.metallic);
    #endif

    // Specular-Gloss Workflow
    // ---------------------------------------
    #if _SpecularGloss
    half4 material = tex2D(_MaskTex, i.uv);
    materialData.metallic = 0;
    materialData.smoothness = material.a;
    materialData.roughness = PerceptualSmoothnessToPerceptualRoughness(materialData.smoothness);
    materialData.roughness = max(PerceptualRoughnessToRoughness(materialData.roughness), HALF_MIN_SQRT);
    materialData.diffuse = materialData.albedo;
    materialData.specular = material.rgb;
    #endif
    return materialData;
}

#endif
