Shader "Suika/SuikaFur"
{
    Properties
    {
        // ==============================================
        // Fur Extra
        // ----------------------------------------------
        _NoiseTex ("Texture", 2D) = "white" {}
        _NoiseTex_UV ("Texture", Vector) = (1,1,0,0)
        _Threshold("Threshold", Float) = 0.0
        _FurLength("Fur Length", Float) = 0.3

        // ==============================================
        // Alpha Mode
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

            #pragma vertex vert
            #pragma fragment frag
            
            // Receive Shadow
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ CUTOUT BLEND

            // Include Suika Library
            #include "include/SuikaLitInput.hlsl"
            #include "include/SuikaLighting.hlsl"

            float4 _MainTex_ST;
            sampler2D _NoiseTex;
            float4 _NoiseTex_UV;
            half _Threshold;
            half _FUR_OFFSET;

            v2f vert (appdata v)
            {
                v2f o;
                // o.vertex = TransformObjectToHClip(v.vertex);
                o.positionWS = TransformObjectToWorld(v.vertex);
                half3 normalWS = TransformObjectToWorldNormal(v.normal);
                o.vertex = TransformWorldToHClip(o.positionWS);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.extuv = v.uv * _NoiseTex_UV.xy;
                o.viewDirWS = GetWorldSpaceViewDir(o.positionWS);
                // Normal Precomputation
                CalcTangentSpace(v, o.tspace0, o.tspace1, o.tspace2);
                // Shadow Coord
                VertexPositionInputs vertexInput = GetVertexPositionInputs(v.vertex.xyz);
                o.shadowCoord = GetShadowCoord(vertexInput);
                // GI Object Precomputation
                OUTPUT_LIGHTMAP_UV(v.lightmapUV, unity_LightmapST, o.lightmapUV);
                OUTPUT_SH(normalWS.xyz, o.vertexSH);

                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                // --------------------------------------------------------------------
                // Fur Surface Material
                // ====================================================================
                half3 noise = tex2D(_NoiseTex, i.extuv);
                // --------------------------------------------------------------------
                SuikaSurfaceData  surfaceData  = InitializeSuikaSurfaceData(i);
                SuikaMaterialData materialData = InitializeSuikaMaterialData(i);

                half3 irradiance = GlobalIllumination(surfaceData, materialData);

                // main Lights
                Light mainLight = GetMainLight(i);
                irradiance += PhysicalBasedLighting(surfaceData, materialData, mainLight);
                half4 shadowMask = unity_ProbesOcclusion;
                // Additional Lights
                uint additionalLightCount = GetAdditionalLightsCount();
                for (uint lightIndex = 0u; lightIndex < additionalLightCount; lightIndex++)
                {
                    Light light = GetAdditionalLight(lightIndex, i.positionWS, shadowMask);
                    irradiance += PhysicalBasedLighting(surfaceData, materialData, light);
                }
                Light light = GetAdditionalLight(0, i.positionWS, half4(1, 1, 1, 1));
                half4 debug = half4(materialData.metallic,materialData.metallic,materialData.metallic, 1.0);
                
                // Emission part
                irradiance += surfaceData.emission;
                return half4(irradiance, 1.0);
            }
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
            
            // Receive Shadow
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ CUTOUT BLEND

            // Include Suika Library
            #include "include/SuikaLitInput.hlsl"
            #include "include/SuikaLighting.hlsl"

            float4 _MainTex_ST;
            sampler2D _NoiseTex;
            float4 _NoiseTex_UV;
            half _Threshold;
            half _FUR_OFFSET;
            float _FurLength;

            v2f vert (appdata v)
            {
                v2f o;
                // o.vertex = TransformObjectToHClip(v.vertex);
                o.positionWS = TransformObjectToWorld(v.vertex);
                half3 normalWS = TransformObjectToWorldNormal(v.normal);
                
                half3 direction = half3(0,-1,0) * 0.3 + normalWS * (1. - 0.3);
                direction = lerp(normalWS, direction, _FUR_OFFSET);
                o.positionWS += direction * _FUR_OFFSET * _FurLength * v.color.r;
                // o.positionWS += normalWS * _FUR_OFFSET * 0.1f;

                o.vertex = TransformWorldToHClip(o.positionWS);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.extuv = v.uv * _NoiseTex_UV.xy;
                o.viewDirWS = GetWorldSpaceViewDir(o.positionWS);
                // Normal Precomputation
                CalcTangentSpace(v, o.tspace0, o.tspace1, o.tspace2);
                // Shadow Coord
                VertexPositionInputs vertexInput = GetVertexPositionInputs(v.vertex.xyz);
                o.shadowCoord = GetShadowCoord(vertexInput);
                // GI Object Precomputation
                OUTPUT_LIGHTMAP_UV(v.lightmapUV, unity_LightmapST, o.lightmapUV);
                OUTPUT_SH(normalWS.xyz, o.vertexSH);

                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                // --------------------------------------------------------------------
                SuikaSurfaceData  surfaceData  = InitializeSuikaSurfaceData(i);
                SuikaMaterialData materialData = InitializeSuikaMaterialData(i);

                // --------------------------------------------------------------------
                // Fur Surface Material
                // ====================================================================
                half3 noise = tex2D(_NoiseTex, i.extuv);
                half alpha = noise.rrr;
                alpha = step(_FUR_OFFSET*_FUR_OFFSET, alpha);


                half3 irradiance = GlobalIllumination(surfaceData, materialData);

                // main Lights
                Light mainLight = GetMainLight(i);
                irradiance += PhysicalBasedLighting(surfaceData, materialData, mainLight);
                half4 shadowMask = unity_ProbesOcclusion;
                // Additional Lights
                uint additionalLightCount = GetAdditionalLightsCount();
                for (uint lightIndex = 0u; lightIndex < additionalLightCount; lightIndex++)
                {
                    Light light = GetAdditionalLight(lightIndex, i.positionWS, shadowMask);
                    irradiance += PhysicalBasedLighting(surfaceData, materialData, light);
                }
                Light light = GetAdditionalLight(0, i.positionWS, half4(1, 1, 1, 1));
                half4 debug = half4(materialData.metallic,materialData.metallic,materialData.metallic, 1.0);
                
                // Emission part
                irradiance += surfaceData.emission;

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
