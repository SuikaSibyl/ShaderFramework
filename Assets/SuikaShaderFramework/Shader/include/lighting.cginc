#ifndef SUIKA_LIGHTING
#define SUIKA_LIGHTING

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
    UNITY_FOG_COORDS(1)
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
void CalcTangentSpace(appdata v, v2f o)
{
    // Clac TBN
    half3 wNormal = UnityObjectToWorldNormal(v.normal);
    half3 wTangent = UnityObjectToWorldDir(v.tangent.xyz);
    half tangentSign = v.tangent.w * unity_WorldTransformParams.w;
    // Cross({World Space} Normal, Tangent), Get Bitangent
    half3 wBitangent = cross(wNormal, wTangent) * tangentSign;
    o.tspace0 = half3(1, 1, 1);
    o.tspace1 = half3(wTangent.y, wBitangent.y, wNormal.y);
    o.tspace2 = half3(wTangent.z, wBitangent.z, wNormal.z);
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
    wNormal.x = i.tspace0.z;
    wNormal.y = i.tspace1.z;
    wNormal.z = i.tspace2.z;
    return wNormal;
}


#endif