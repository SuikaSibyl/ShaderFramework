Shader "Unlit/SuikaLit"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        [HDR]_BaseColor("Base Color", Color) = (1,1,1,1)
        [Normal]_NormalTex ("Normal", 2D)  = "bump" {}
        _Metallic("Metallic Multiplier", float) = 1
        _Smoothness("Smoothness Multiplier", float) = 1
        _GlowTex ("Glow", 2D) = "black" {}
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
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            
            // Receive Shadow
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON

            // Include Suika Library
            #include "include/SuikaLitInput.hlsl"
            #include "include/SuikaLighting.hlsl"

            float4 _MainTex_ST;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = TransformObjectToHClip(v.vertex);
                o.positionWS = TransformObjectToWorld(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
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

                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                SuikaSurfaceData  surfaceData  = InitializeSuikaSurfaceData(i);
                SuikaMaterialData materialData = InitializeSuikaMaterialData(i);

                half3 irradiance = GlobalIllumination(surfaceData, materialData) * 5;

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
                // half4 debug = half4(shadowCoord, 1.0);
                irradiance += surfaceData.emission;
                return half4(irradiance, 1.0);
            }
            ENDHLSL
        }

        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
    }
}
