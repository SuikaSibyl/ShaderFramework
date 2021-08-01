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
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

///////////////////////////////////////////////////////////////////////////////
//                          Light Helpers                                    //
///////////////////////////////////////////////////////////////////////////////

// Abstraction over Light shading data.
struct Light
{
    half3   direction;
    half3   color;
    half    distanceAttenuation;
    half    shadowAttenuation;
};

///////////////////////////////////////////////////////////////////////////////
//                      Light Abstraction                                    //
///////////////////////////////////////////////////////////////////////////////

Light GetMainLight()
{
    Light light;
    light.direction = _MainLightPosition.xyz;
    light.distanceAttenuation = unity_LightData.z; // unity_LightData.z is 1 when not culled by the culling mask, otherwise 0.
    light.shadowAttenuation = 1.0;
    light.color = _MainLightColor.rgb;

    return light;
}

struct appdata
{
    float4 vertex : POSITION;
    float4 tangent : TANGENT;
    float3 normal : NORMAL;
    float2 uv : TEXCOORD0;
};

struct v2f
{
    float2 uv : TEXCOORD0;
    float4 vertex : SV_POSITION;
    
    // SHADOW_COORDS(1)
    float3 worldPos : TEXCOORD2;
    float3 worldNormal : TEXCOORD3;
    float3 worldViewDir : TEXCOORD4;
    float3 lightDir : TEXCOORD5;

    half3 tspace0 : TEXCOORD6;
    half3 tspace1 : TEXCOORD7;
    half3 tspace2 : TEXCOORD8;
};

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
    return wNormal;
}

half3 WorldNormal(v2f i)
{
    half3 tNormal = normalize(UnpackNormal(tex2D(_NormalTex, i.uv)).xyz);
    half3 wNormal = NormalTangentToWorld(tNormal, i);
    return wNormal;
}


#endif