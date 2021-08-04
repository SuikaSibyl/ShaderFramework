Shader "Suika/SuikaFur"
{
    Properties
    {
        // ==============================================
        // Fur Extra Specified
        // ----------------------------------------------
        _NoiseTex ("Texture", 2D) = "white" {}
        _NoiseTex_UV ("Texture", Vector) = (1,1,0,0)
        _Threshold("Threshold", Float) = 0.0
        _FurLength("Fur Length", Float) = 0.3

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
            Tags{ "LightMode" = "FurRendererBase"}
            Cull[_CullMode]

            HLSLPROGRAM

            #pragma vertex VertexReguluarLit
            #pragma fragment FragmentRegularLit

            // Include Suika Library
            #include "include/SuikaCommon.hlsl"
            #include "include/SuikaLitInput.hlsl"
            #include "include/SuikaLighting.hlsl"
            #include "include/SuikaRegularPass.hlsl"

            ENDHLSL
        }

        Pass
        {
            Tags{ "LightMode" = "FurRendererLayer"}
            BlendOp [_BlendOp]
            Blend [_BlendSrc] [_BlendDst]
            ZWrite[_ZWrite]
            ZTest[_ZTest]
            Cull[_CullMode]

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            // Include Suika Library
            #include "include/SuikaCommon.hlsl"
            #include "include/SuikaLitInput.hlsl"
            #include "include/SuikaLighting.hlsl"

            sampler2D _NoiseTex;
            float4 _NoiseTex_UV;
            half _Threshold;
            half _FUR_OFFSET;
            float _FurLength;

            v2f vert (appdata v)
            {
                v2f o;
                RegularVertexInit(v, o);
                // Have gravity influence the fur vertex
                // -------------------------------------
                half3 normalWS = TransformObjectToWorldNormal(v.normal);
                half3 direction = half3(0,-1,0) * 0.3 + normalWS * (1. - 0.3);
                direction = lerp(normalWS, direction, _FUR_OFFSET);
                o.positionWS += direction * _FUR_OFFSET * _FurLength * v.color.r;
                o.vertex = TransformWorldToHClip(o.positionWS);
                // Change Extra Map UV
                // -------------------------------------
                o.extuv = v.uv * _NoiseTex_UV.xy;

                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                // Data Initialization
                SuikaSurfaceData  surfaceData  = InitializeSuikaSurfaceData(i);
                SuikaMaterialData materialData = InitializeSuikaMaterialData(i);

                // Use the standard way to get irradiance
                half3 irradiance = StandardLitIrradiance(surfaceData, materialData, i);

                // Fur specified Influence
                half3 noise = tex2D(_NoiseTex, i.extuv);
                half alpha = noise.rrr;
                alpha = step(_FUR_OFFSET*_FUR_OFFSET, alpha);

                half occlusion =_FUR_OFFSET; //伽马转线性最精简版
                occlusion +=0.04 ;
                half Fresnel = 1-max(0,dot(surfaceData.normalWS,surfaceData.viewDirWS));//pow (1-max(0,dot(N,V)),2.2);
                half RimLight =Fresnel * occlusion; //AO的深度剔除 很重要
                RimLight *=RimLight;
                RimLight *=RimLight;
                irradiance += RimLight * 1;

                occlusion *= 0.2;
                occlusion +=0.9;

                irradiance *= alpha * occlusion;
                return half4(irradiance, alpha);
            }
            ENDHLSL
        }

        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
    }
    CustomEditor "SuikaLitFurShaderGUI"
}
