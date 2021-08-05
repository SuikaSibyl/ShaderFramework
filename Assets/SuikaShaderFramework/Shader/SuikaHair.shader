Shader "Suika/SuikaHair"
{
    Properties
    {

        // ==============================================
        // Common Input
        // ----------------------------------------------
        // Alpha Cutout Mode Setting, threshold is needed
        _MainTex ("Texture", 2D) = "white" {}
        [HDR]_BaseColor("Base Color", Color) = (1,1,1,1)
        [Normal]_NormalTex ("Normal", 2D)  = "bump" {}
        _Metallic("Metallic Multiplier", float) = 1
        _MaskTex ("Texture", 2D) = "white" {}
        _Smoothness("Smoothness Multiplier", float) = 1
        _GlowTex ("Glow", 2D) = "black" {}
        
        // ==============================================
        // Alpha Mode
        // ----------------------------------------------
        // Alpha Cutout Mode Setting, threshold is needed
        _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5
        // Blending Mode Setting
        [Enum(UnityEngine.Rendering.BlendMode)]
        _BlendSrc("Blend Source", int) = 0
        [Enum(UnityEngine.Rendering.BlendMode)]
        _BlendDst("Blend Dst", int) = 0
        [Enum(UnityEngine.Rendering.BlendOp)]
        _BlendOp("Blend Op", int) = 0
        // Blending state
        [HideInInspector] _Mode ("__mode", Float) = 0.0
        [HideInInspector] _Workflow ("__workflow", Float) = 0.0
        [HideInInspector] _BlendMode("__bmode", Float) = 0.0
        [HideInInspector] _ZWrite("__zw", Float) = 0.0
        [HideInInspector] _ZTest("__ztest", Float) = 4.0
        [HideInInspector] _CullMode("__cull", Float) = 2.0
    }
    SubShader
    {
        Tags 
        {
            "RenderPipeline"="UniversalPipeline"
            "RenderType"="Opaque" 
        }
        LOD 100

        Pass
        {
            BlendOp [_BlendOp]
            Blend [_BlendSrc] [_BlendDst]
            ZWrite[_ZWrite]
            ZTest[_ZTest]
            Cull[_CullMode]

            HLSLPROGRAM

            #pragma vertex VertexReguluarLit
            #pragma fragment frag

            // Include Suika Library
            #include "include/SuikaCommon.hlsl"
            #include "include/SuikaLitInput.hlsl"
            #include "include/SuikaLighting.hlsl"
            #include "include/SuikaRegularPass.hlsl"

            half4 frag (v2f i) : SV_Target
            {
                // Data Initialization
                SuikaSurfaceData  surfaceData  = InitializeSuikaSurfaceData(i);
                SuikaMaterialData materialData = InitializeSuikaMaterialData(i);

                half3 normal = WorldNormal(i);
                half3 tangent = WorldTangent(i);
                half3 bitangent = WorldBitangent(i);
                // Use the standard way to get irradiance
                half3 irradiance = HairIrradiance(surfaceData, materialData, i, normal);

                return half4(irradiance, 1.0);
            }

            ENDHLSL
        }

        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
    }
    CustomEditor "SuikaHairShaderGUI"
}
